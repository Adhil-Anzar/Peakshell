#include "syntaxhighlighter.hpp"

#include <qcolor.h>
#include <qfileinfo.h>
#include <qjsondocument.h>
#include <qjsonparseerror.h>
#include <qlist.h>
#include <qregularexpression.h>
#include <qstringview.h>

#include <utility>

#ifdef PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING
#include <KSyntaxHighlighting/AbstractHighlighter>
#include <KSyntaxHighlighting/Format>
#include <KSyntaxHighlighting/State>
#endif

namespace peakshell::apps {

using Qt::StringLiterals::operator""_s;

namespace {

constexpr qsizetype kMaxHighlightLength = 200000;
constexpr qsizetype kMaxJsonLength = 500000;

struct SyntaxColors {
    QColor foreground;
    QColor muted;
    QColor accent;
    QColor accentSoft;
    QColor string;
    QColor danger;
};

QColor colorFromMap(const QVariantMap& colors, const QString& key, const QColor& fallback) {
    const QVariant value = colors.value(key);
    const QColor color = value.metaType().id() == QMetaType::QColor
        ? value.value<QColor>()
        : QColor::fromString(value.toString());
    return color.isValid() ? color : fallback;
}

SyntaxColors syntaxColorsFromMap(const QVariantMap& colors) {
    return {
        colorFromMap(colors, u"foreground"_s, QColor::fromString(u"#FFFFFFFF"_s)),
        colorFromMap(colors, u"muted"_s, QColor::fromString(u"#FFA0A0A0"_s)),
        colorFromMap(colors, u"accent"_s, QColor::fromString(u"#FF8C00BA"_s)),
        colorFromMap(colors, u"accentSoft"_s, QColor::fromString(u"#CC8800FF"_s)),
        colorFromMap(colors, u"string"_s, QColor::fromString(u"#FF21AB5F"_s)),
        colorFromMap(colors, u"danger"_s, QColor::fromString(u"#FFFF3333"_s)),
    };
}

QColor blendColors(const QColor& from, const QColor& to, float amount) {
    const float rest = 1.0F - amount;
    return QColor::fromRgbF(from.redF() * rest + to.redF() * amount,
                            from.greenF() * rest + to.greenF() * amount,
                            from.blueF() * rest + to.blueF() * amount,
                            from.alphaF() * rest + to.alphaF() * amount);
}

#ifdef PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING

QColor colorForStyle(KSyntaxHighlighting::Theme::TextStyle style, const SyntaxColors& colors) {
    using Style = KSyntaxHighlighting::Theme::TextStyle;
    switch (style) {
    case Style::Keyword:
    case Style::ControlFlow:
    case Style::Import:
    case Style::Preprocessor:
    case Style::Extension:
        return colors.accent;
    case Style::Function:
    case Style::BuiltIn:
        return colors.accentSoft;
    case Style::Variable:
        return blendColors(colors.foreground, colors.accentSoft, 0.25F);
    case Style::Operator:
        return colors.muted;
    case Style::String:
    case Style::VerbatimString:
    case Style::SpecialString:
    case Style::Char:
    case Style::SpecialChar:
    case Style::DecVal:
    case Style::BaseN:
    case Style::Float:
    case Style::Constant:
        return colors.string;
    case Style::Comment:
    case Style::Documentation:
    case Style::CommentVar:
    case Style::RegionMarker:
        return colors.muted;
    case Style::Alert:
    case Style::Error:
        return colors.danger;
    case Style::Warning:
        return blendColors(colors.danger, colors.string, 0.45F);
    case Style::Information:
    case Style::Annotation:
    case Style::Attribute:
        return colors.accentSoft;
    case Style::DataType:
        return blendColors(colors.accent, colors.accentSoft, 0.5F);
    case Style::Normal:
    case Style::Others:
        return colors.foreground;
    }
    return colors.foreground;
}

#endif

QString normalizeNewlines(const QString& text) {
    QString normalized = text;
    normalized.replace(u"\r\n"_s, u"\n"_s);
    normalized.replace(u'\r', u'\n');
    return normalized;
}

void appendEscapedChar(QString& out, QChar ch) {
    switch (ch.unicode()) {
    case u'&':
        out += u"&amp;"_s;
        break;
    case u'<':
        out += u"&lt;"_s;
        break;
    case u'>':
        out += u"&gt;"_s;
        break;
    case u'"':
        out += u"&quot;"_s;
        break;
    case u'\'':
        out += u"&#39;"_s;
        break;
    default:
        out += ch;
        break;
    }
}

void appendEscaped(QString& out, QStringView text) {
    for (const QChar ch : text)
        appendEscapedChar(out, ch);
}

QString plainLineHtml(QStringView text) {
    QString out;
    out.reserve(text.size() + 32);
    out += u"<span style=\"white-space: pre-wrap\">"_s;
    if (text.isEmpty())
        out += u"&#8203;"_s;
    else
        appendEscaped(out, text);
    out += u"</span>"_s;
    return out;
}

QString plainHtml(QStringView text) {
    QString out;
    out.reserve(text.size() + text.size() / 3 + 64);
    qsizetype start = 0;
    for (qsizetype i = 0; i <= text.size(); ++i) {
        if (i != text.size() && text.at(i) != u'\n')
            continue;
        if (start > 0)
            out += u"<br/>"_s;
        out += plainLineHtml(text.mid(start, i - start));
        start = i + 1;
    }
    return out;
}

QVariantList plainLines(const QString& text) {
    QVariantList lines;
    qsizetype start = 0;
    for (qsizetype i = 0; i <= text.size(); ++i) {
        if (i != text.size() && text.at(i) != u'\n')
            continue;
        lines.append(plainLineHtml(QStringView(text).mid(start, i - start)));
        start = i + 1;
    }
    return lines;
}

QVariantList toVariantList(const QStringList& lines) {
    QVariantList result;
    result.reserve(lines.size());
    for (const QString& line : lines)
        result.append(line);
    return result;
}

#ifdef PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING

class HtmlHighlighter final : public KSyntaxHighlighting::AbstractHighlighter {
public:
    HtmlHighlighter(const KSyntaxHighlighting::Theme& theme, const SyntaxColors& colors)
        : m_theme(theme), m_colors(colors) {}

    QString highlight(const QString& text, const KSyntaxHighlighting::Definition& definition) {
        const QStringList lines = highlightLines(text, definition);
        QString out;
        out.reserve(text.size() + text.size() / 3 + 64);
        for (qsizetype i = 0; i < lines.size(); ++i) {
            if (i > 0)
                out += u"<br/>"_s;
            out += lines.at(i);
        }
        return out;
    }

    QStringList highlightLines(const QString& text,
                               const KSyntaxHighlighting::Definition& definition) {
        setDefinition(definition);
        setTheme(m_theme);

        QStringList lines;
        lines.reserve(text.count(u'\n') + 1);

        KSyntaxHighlighting::State state;
        qsizetype start = 0;
        const qsizetype size = text.size();
        for (qsizetype i = 0; i <= size; ++i) {
            if (i != size && text.at(i) != u'\n')
                continue;

            const QStringView line = QStringView(text).mid(start, i - start);
            m_formats.clear();
            state = highlightLine(line, state);

            QString out;
            out.reserve(line.size() + line.size() / 3 + 32);
            out += u"<span style=\"white-space: pre-wrap\">"_s;
            appendLine(out, line);
            if (line.isEmpty())
                out += u"&#8203;"_s;
            out += u"</span>"_s;
            lines.append(out);
            start = i + 1;
        }

        return lines;
    }

protected:
    void applyFormat(int offset, int length, const KSyntaxHighlighting::Format& format) override {
        if (length <= 0)
            return;
        m_formats.append(Run{offset, length, format});
    }

private:
    struct Run {
        int offset;
        int length;
        KSyntaxHighlighting::Format format;
    };

    void appendLine(QString& out, QStringView line) {
        const qsizetype lineSize = line.size();
        qsizetype cursor = 0;
        for (const Run& run : std::as_const(m_formats)) {
            const qsizetype start = qBound<qsizetype>(
                0, static_cast<qsizetype>(run.offset), lineSize);
            const qsizetype end = qBound<qsizetype>(
                start, static_cast<qsizetype>(run.offset) + static_cast<qsizetype>(run.length),
                lineSize);

            if (start > cursor)
                appendEscaped(out, line.mid(cursor, start - cursor));
            appendFormatted(out, line.mid(start, end - start), run.format);
            if (end > cursor)
                cursor = end;
        }
        if (cursor < lineSize)
            appendEscaped(out, line.mid(cursor));
    }

    void appendFormatted(QString& out, QStringView text, const KSyntaxHighlighting::Format& format) {
        if (text.isEmpty())
            return;
        if (!format.isValid()) {
            appendEscaped(out, text);
            return;
        }

        QString style;
        const QColor color = colorForStyle(format.textStyle(), m_colors);
        if (color.isValid() && color != m_colors.foreground) {
            style += u"color:"_s;
            style += color.name(QColor::HexRgb);
            style += u";"_s;
        }
        if (format.isBold(m_theme))
            style += u"font-weight:600;"_s;
        if (format.isItalic(m_theme))
            style += u"font-style:italic;"_s;

        const bool underline = format.isUnderline(m_theme);
        const bool strike = format.isStrikeThrough(m_theme);
        if (underline || strike) {
            style += u"text-decoration:"_s;
            if (underline)
                style += u"underline"_s;
            if (strike) {
                if (underline)
                    style += u" "_s;
                style += u"line-through"_s;
            }
            style += u";"_s;
        }

        if (style.isEmpty()) {
            appendEscaped(out, text);
            return;
        }

        out += u"<span style=\""_s;
        out += style;
        out += u"\">"_s;
        appendEscaped(out, text);
        out += u"</span>"_s;
    }

    KSyntaxHighlighting::Theme m_theme;
    SyntaxColors m_colors;
    QList<Run> m_formats;
};

#endif

} // namespace

SyntaxHighlighter::SyntaxHighlighter(QObject* parent)
    : QObject(parent)
#ifdef PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING
    , m_repository()
    , m_theme(m_repository.defaultTheme(KSyntaxHighlighting::Repository::DarkTheme))
#endif
{}

QString SyntaxHighlighter::highlight(const QString& text, const QString& mimeType,
                                     const QVariantMap& colors) const {
    const QString normalized = normalizeNewlines(text);
    if (normalized.isEmpty())
        return {};

#ifdef PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING
    if (normalized.size() <= kMaxHighlightLength) {
        const KSyntaxHighlighting::Definition definition = detectDefinition(normalized, mimeType);
        if (definition.isValid()) {
            const SyntaxColors palette = syntaxColorsFromMap(colors);
            HtmlHighlighter highlighter(m_theme, palette);
            return highlighter.highlight(normalized, definition);
        }
    }
#else
    Q_UNUSED(colors)
#endif

    return plainHtml(QStringView(normalized));
}

QVariantList SyntaxHighlighter::highlightLines(const QString& text, const QString& mimeType,
                                               const QVariantMap& colors) const {
    return highlightLinesInternal(text, mimeType, QString(), colors);
}

QVariantList SyntaxHighlighter::highlightFileLines(const QString& text, const QString& fileName,
                                                   const QString& mimeType,
                                                   const QVariantMap& colors) const {
    return highlightLinesInternal(text, mimeType, fileName, colors);
}

QVariantList SyntaxHighlighter::highlightLinesInternal(const QString& text,
                                                       const QString& mimeType,
                                                       const QString& fileName,
                                                       const QVariantMap& colors) const {
    const QString normalized = normalizeNewlines(text);
    if (normalized.isEmpty())
        return {};

#ifdef PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING
    if (normalized.size() <= kMaxHighlightLength) {
        const KSyntaxHighlighting::Definition definition =
            detectDefinition(normalized, mimeType, fileName);
        if (definition.isValid()) {
            const SyntaxColors palette = syntaxColorsFromMap(colors);
            HtmlHighlighter highlighter(m_theme, palette);
            return toVariantList(highlighter.highlightLines(normalized, definition));
        }
    }
#else
    Q_UNUSED(colors)
    Q_UNUSED(fileName)
#endif

    return plainLines(normalized);
}

#ifdef PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING

KSyntaxHighlighting::Definition SyntaxHighlighter::detectDefinition(
    const QString& text, const QString& mimeType, const QString& fileName) const {
    auto definition = [this](const QString& name) {
        return m_repository.definitionForName(name);
    };

    if (!fileName.isEmpty()) {
        const QString baseName = QFileInfo(fileName).fileName();
        const KSyntaxHighlighting::Definition byName =
            m_repository.definitionForFileName(baseName);
        if (byName.isValid())
            return byName;
    }

    QString mime = mimeType;
    const qsizetype mimeEnd = mime.indexOf(u';');
    if (mimeEnd >= 0)
        mime.truncate(mimeEnd);
    mime = mime.trimmed().toLower();
    if (!mime.isEmpty() && mime != u"text/plain"_s) {
        const KSyntaxHighlighting::Definition byMime = m_repository.definitionForMimeType(mime);
        if (byMime.isValid())
            return byMime;
    }

    const QString trimmed = text.trimmed();
    if (trimmed.isEmpty())
        return {};

    // A shebang is the most reliable signal available to a clipboard snippet.
    static const QRegularExpression shebang(
        u"^#![^\\n]*"_s, QRegularExpression::MultilineOption);
    if (const auto match = shebang.match(trimmed); match.hasMatch()) {
        const QString line = match.captured(0).toLower();
        if (line.contains(u"python"_s))
            return definition(u"Python"_s);
        if (line.contains(u"ts-node"_s) || line.contains(u"deno"_s))
            return definition(u"TypeScript"_s);
        if (line.contains(u"node"_s) || line.contains(u"bun"_s))
            return definition(u"JavaScript"_s);
        if (line.contains(u"ruby"_s))
            return definition(u"Ruby"_s);
        if (line.contains(u"perl"_s))
            return definition(u"Perl"_s);
        if (line.contains(u"lua"_s))
            return definition(u"Lua"_s);
        if (line.contains(u"bash"_s) || line.contains(u"zsh"_s)
            || line.contains(u"sh"_s))
            return definition(u"Bash"_s);
    }

    if (trimmed.size() <= kMaxJsonLength
        && (trimmed.startsWith(u'{') || trimmed.startsWith(u'['))) {
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(trimmed.toUtf8(), &error);
        if (error.error == QJsonParseError::NoError && !document.isNull())
            return definition(u"JSON"_s);
    }

    static const QRegularExpression htmlTag(
        u"<\\/?[A-Za-z][A-Za-z0-9:-]*(?:\\s[^<>]*)?>"_s);
    if (trimmed.startsWith(u'<') && htmlTag.match(trimmed).hasMatch()) {
        static const QRegularExpression xmlDeclaration(
            u"^<\\?xml\\b|^<!DOCTYPE\\s+[^>]+\\[|xmlns(?::[A-Za-z]+)?\\s*="_s,
            QRegularExpression::CaseInsensitiveOption);
        static const QRegularExpression htmlRoot(
            u"<html(?:\\s|>)|^<!DOCTYPE\\s+html\\b"_s,
            QRegularExpression::CaseInsensitiveOption);
        if (htmlRoot.match(trimmed).hasMatch())
            return definition(u"HTML"_s);
        if (xmlDeclaration.match(trimmed).hasMatch())
            return definition(u"XML"_s);
        return definition(u"HTML"_s);
    }

    if (trimmed.startsWith(u"diff --git "_s)
        || (text.contains(u"\n@@ "_s) && text.contains(u"\n+++ "_s)))
        return definition(u"Diff"_s);

    static const QRegularExpression cmakeCall(
        u"^\\s*(?:cmake_minimum_required|project|add_executable|add_library|add_subdirectory|target_link_libraries|set)\\s*\\("_s,
        QRegularExpression::MultilineOption | QRegularExpression::CaseInsensitiveOption);
    if (cmakeCall.match(text).hasMatch())
        return definition(u"CMake"_s);

    static const QRegularExpression qmlImport(
        u"^\\s*import\\s+(?:QtQuick|QtQml|Quickshell|PeakShell)\\b"_s,
        QRegularExpression::MultilineOption);
    if (qmlImport.match(text).hasMatch())
        return definition(u"QML"_s);

    static const QRegularExpression sqlStart(
        u"^\\s*(?:SELECT|INSERT\\s+INTO|UPDATE|DELETE\\s+FROM|CREATE\\s+(?:TABLE|DATABASE|INDEX)|ALTER\\s+TABLE|DROP\\s+(?:TABLE|DATABASE))\\b"_s,
        QRegularExpression::MultilineOption | QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression sqlClause(
        u"\\b(?:FROM|INTO|SET|TABLE|WHERE|VALUES)\\b"_s,
        QRegularExpression::CaseInsensitiveOption);
    if (sqlStart.match(text).hasMatch() && sqlClause.match(text).hasMatch())
        return definition(u"SQL"_s);

    static const QRegularExpression rustCode(
        u"(?:^|\\n)\\s*(?:pub\\s+)?fn\\s+\\w+|\\buse\\s+std::|\\blet\\s+mut\\b|\\bimpl\\b|\\bprintln!\\s*\\(|\\bmatch\\s+\\w+\\s*\\{"_s);
    if (rustCode.match(text).hasMatch())
        return definition(u"Rust"_s);

    static const QRegularExpression csharpCode(
        u"\\busing\\s+System(?:\\.[A-Za-z0-9_.]+)?\\s*;|\\bConsole\\.(?:Write|Read)|\\bnamespace\\s+[A-Za-z0-9_.]+\\s*\\{"_s);
    if (csharpCode.match(text).hasMatch())
        return definition(u"C#"_s);

    static const QRegularExpression goCode(
        u"^\\s*package\\s+\\w+|\\bfunc\\s+\\w+\\s*\\(|:=|\\bfmt\\.(?:Print|Sprint)"_s,
        QRegularExpression::MultilineOption);
    if (goCode.match(text).hasMatch())
        return definition(u"Go"_s);

    static const QRegularExpression javaCode(
        u"\\bimport\\s+java\\.|\\bSystem\\.out\\.|\\bpublic\\s+static\\s+void\\s+main\\s*\\(|\\bpublic\\s+class\\s+\\w+"_s);
    if (javaCode.match(text).hasMatch())
        return definition(u"Java"_s);

    static const QRegularExpression pythonCode(
        u"^\\s*(?:async\\s+)?(?:def|class)\\s+\\w+|^\\s*(?:from\\s+[\\w.]+\\s+import|import\\s+[\\w.]+)|^\\s*if\\s+__name__\\s*==|\\bself\\.\\w+|\\bprint\\s*\\("_s,
        QRegularExpression::MultilineOption);
    if (pythonCode.match(text).hasMatch())
        return definition(u"Python"_s);

    static const QRegularExpression typescriptCode(
        u"^\\s*(?:export\\s+)?(?:interface|type|enum)\\s+\\w+|\\b(?:const|let)\\s+\\w+\\s*:\\s*[A-Za-z_$]|\\bimport\\s+type\\b|\\bas\\s+(?:const|string|number|unknown)\\b"_s,
        QRegularExpression::MultilineOption);
    if (typescriptCode.match(text).hasMatch())
        return definition(u"TypeScript"_s);

    static const QRegularExpression javascriptCode(
        u"\\bfunction\\s+\\w+\\s*\\(|\\b(?:const|let)\\s+\\w+\\s*=|=>|\\bconsole\\.log\\s*\\(|\\brequire\\s*\\(|\\bmodule\\.exports\\b|\\b(?:document|window)\\.|^\\s*export\\s+(?:default|const|function|class)\\b"_s,
        QRegularExpression::MultilineOption);
    if (javascriptCode.match(text).hasMatch())
        return definition(u"JavaScript"_s);

    static const QRegularExpression luaCode(
        u"^\\s*local\\s+\\w+\\s*=|\\bfunction\\s+\\w+\\s*\\([^)]*\\)\\s*$"_s,
        QRegularExpression::MultilineOption);
    static const QRegularExpression luaEnd(u"\\bend\\b"_s);
    if (luaCode.match(text).hasMatch() && luaEnd.match(text).hasMatch())
        return definition(u"Lua"_s);

    static const QRegularExpression rubyCode(
        u"^\\s*def\\s+\\w+[!?]?(?:\\s|\\(|$)|\\bputs\\b|\\brequire\\s+['\"]|\\bdo\\s*\\|"_s,
        QRegularExpression::MultilineOption);
    if (rubyCode.match(text).hasMatch())
        return definition(u"Ruby"_s);

    static const QRegularExpression perlCode(
        u"^\\s*use\\s+(?:strict|warnings)\\b|\\bmy\\s+[$@%]\\w+"_s,
        QRegularExpression::MultilineOption);
    if (perlCode.match(text).hasMatch())
        return definition(u"Perl"_s);

    static const QRegularExpression shellCode(
        u"^\\s*(?:export\\s+\\w+=|if\\s+\\[|for\\s+\\w+\\s+in\\b|while\\s+\\[|case\\s+\\w+\\s+in|set\\s+-[a-z]*e|echo\\s+)"_s,
        QRegularExpression::MultilineOption);
    if (shellCode.match(text).hasMatch()
        && (text.contains(u"$("_s) || text.contains(u"\nfi"_s)
            || text.contains(u"\ndone"_s) || text.contains(u"\nthen"_s)))
        return definition(u"Bash"_s);

    static const QRegularExpression yamlKey(
        u"^\\s*(?:-\\s+)?[A-Za-z_][\\w.-]*\\s*:"_s, QRegularExpression::MultilineOption);
    static const QRegularExpression yamlIndented(
        u"^\\s{2,}(?:-\\s+)?[A-Za-z_][\\w.-]*\\s*:"_s, QRegularExpression::MultilineOption);
    static const QRegularExpression yamlDash(
        u"^\\s*-\\s+\\S"_s, QRegularExpression::MultilineOption);
    int yamlKeys = 0;
    for (auto it = yamlKey.globalMatch(text); it.hasNext() && yamlKeys < 2; it.next())
        ++yamlKeys;
    if (yamlKeys >= 2 && !text.contains(u'{') && !text.contains(u'}')
        && !text.contains(u';')
        && (yamlIndented.match(text).hasMatch() || yamlDash.match(text).hasMatch()
            || trimmed.startsWith(u"---"_s)))
        return definition(u"YAML"_s);

    static const QRegularExpression tomlSection(
        u"^\\s*\\[[^\\]]+\\]\\s*$"_s, QRegularExpression::MultilineOption);
    static const QRegularExpression tomlKey(
        u"^\\s*[A-Za-z_][\\w.-]*\\s*=\\s*\\S"_s, QRegularExpression::MultilineOption);
    if (tomlSection.match(text).hasMatch() && tomlKey.match(text).hasMatch())
        return definition(u"TOML"_s);

    static const QRegularExpression cppCode(
        u"#\\s*include\\s*[<\"]|#\\s*define\\b|\\bstd::|\\busing\\s+namespace\\b|\\btemplate\\s*<|\\bcout\\s*<<|\\bcin\\s*>>|\\bclass\\s+\\w+\\s*(?:\\{|:)"_s);
    if (cppCode.match(text).hasMatch())
        return definition(u"C++"_s);

    static const QRegularExpression cCode(
        u"#\\s*include\\s*<|#\\s*define\\b|\\bint\\s+main\\s*\\(|\\bprintf\\s*\\(|\\bstruct\\s+\\w+\\s*\\{"_s);
    if (cCode.match(text).hasMatch())
        return definition(u"C"_s);

    static const QRegularExpression cssSelector(
        u"(?:^|\\n)\\s*[.#]?[A-Za-z][\\w-]*(?:\\s*[,>+~]\\s*[.#]?[A-Za-z][\\w-]*)*\\s*\\{"_s,
        QRegularExpression::MultilineOption);
    static const QRegularExpression cssProperty(u"\\b[a-z-]+\\s*:\\s*[^;{}]+;"_s);
    if (cssSelector.match(text).hasMatch() && cssProperty.match(text).hasMatch())
        return definition(u"CSS"_s);

    static const QRegularExpression markdown(
        u"^(?:#{1,6}\\s+\\S|```|~~~|(?:[-*+]|\\d+\\.)\\s+\\S)"_s,
        QRegularExpression::MultilineOption);
    if (markdown.match(text).hasMatch())
        return definition(u"Markdown"_s);

    return {};
}

#endif

} // namespace peakshell::apps
