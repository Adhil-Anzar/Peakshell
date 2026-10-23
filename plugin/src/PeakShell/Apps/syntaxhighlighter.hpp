#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qvariantlist.h>
#include <qvariantmap.h>

#ifdef PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING
#include <KSyntaxHighlighting/Definition>
#include <KSyntaxHighlighting/Repository>
#include <KSyntaxHighlighting/Theme>
#endif

namespace peakshell::apps {

// Turns clipboard text into Qt rich-text HTML. A syntax definition is picked
// from an explicit MIME type first, then from lightweight content cues such as
// shebangs, JSON/XML structure, and common language keywords. Text that does
// not look like code is escaped and returned as plain (but whitespace-safe)
// rich text.
class SyntaxHighlighter : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit SyntaxHighlighter(QObject* parent = nullptr);

    Q_INVOKABLE QString highlight(const QString& text, const QString& mimeType,
                                  const QVariantMap& colors) const;

    // One HTML fragment per line. This lets the preview use a ListView and
    // only lay out/render the lines that are actually visible.
    Q_INVOKABLE QVariantList highlightLines(const QString& text, const QString& mimeType,
                                            const QVariantMap& colors) const;

    // Same as highlightLines(), but prefers the syntax definition associated
    // with the file name (for example .ts vs. a generic MIME type).
    Q_INVOKABLE QVariantList highlightFileLines(const QString& text, const QString& fileName,
                                                const QString& mimeType,
                                                const QVariantMap& colors) const;

private:
    QVariantList highlightLinesInternal(const QString& text, const QString& mimeType,
                                        const QString& fileName,
                                        const QVariantMap& colors) const;

#ifdef PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING
    [[nodiscard]] KSyntaxHighlighting::Definition detectDefinition(
        const QString& text, const QString& mimeType,
        const QString& fileName = {}) const;

    KSyntaxHighlighting::Repository m_repository;
    KSyntaxHighlighting::Theme m_theme;
#endif
};

} // namespace peakshell::apps
