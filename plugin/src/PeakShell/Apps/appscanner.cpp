#include "appscanner.hpp"

#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qloggingcategory.h>
#include <qprocess.h>
#include <qregularexpression.h>
#include <qstandardpaths.h>
#include <qtconcurrentrun.h>
#include <qtextstream.h>

namespace peakshell::apps {

using Qt::StringLiterals::operator""_s;

Q_LOGGING_CATEGORY(lcApps, "peakshell.apps", QtInfoMsg)

// Collects all application directories from XDG spec.
static QStringList appDirs() {
    QStringList dirs;
    const QString home = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    dirs << home + u"/applications"_s;
    const QStringList dataDirs = QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation);
    for (const QString& d : dataDirs) {
        const QString candidate = d + u"/applications"_s;
        if (!dirs.contains(candidate))
            dirs << candidate;
    }
    return dirs;
}

// Runs on a thread pool: scans desktop files and returns raw struct data
// (not QObjects, those must be constructed on the main thread).
struct RawEntry {
    QString name, genericName, comment, icon, exec, keywords;
    bool terminal;
};

static QList<RawEntry> scanDesktopFiles() {
    QList<RawEntry> results;
    QSet<QString> seen;

    for (const QString& dir : appDirs()) {
        const QDir d(dir);
        if (!d.exists())
            continue;
        const QStringList files = d.entryList({ u"*.desktop"_s }, QDir::Files, QDir::Name);
        for (const QString& filename : files) {
            if (seen.contains(filename))
                continue;
            seen.insert(filename);

            const QString path = d.filePath(filename);
            QFile f(path);
            if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
                continue;

            QTextStream in(&f);
            RawEntry e;
            bool inEntry = false, isApp = true, noDisplay = false, hidden = false;
            while (!in.atEnd()) {
                const QString line = in.readLine().trimmed();
                if (line == u"[Desktop Entry]"_s) { inEntry = true; continue; }
                if (line.startsWith(u'['))          { inEntry = false; continue; }
                if (!inEntry || !line.contains(u'=')) continue;

                const qsizetype sep = line.indexOf(u'=');
                const QString k = line.left(sep).trimmed();
                const QString v = line.sliced(sep + 1).trimmed();

                if (k == u"Type"_s && v != u"Application"_s) { isApp = false; break; }
                else if (k == u"NoDisplay"_s && v.toLower() == u"true"_s) { noDisplay = true; }
                else if (k == u"Hidden"_s   && v.toLower() == u"true"_s)  { hidden    = true; }
                else if (k == u"Terminal"_s && v.toLower() == u"true"_s)  { e.terminal = true; }
                else if (k == u"Name"_s && e.name.isEmpty()) { e.name = v; }
                else if (k == u"GenericName"_s) { e.genericName = v; }
                else if (k == u"Comment"_s)     { e.comment     = v; }
                else if (k == u"Icon"_s)        { e.icon        = v; }
                else if (k == u"Exec"_s)        { e.exec        = v; }
                else if (k == u"Keywords"_s)    { e.keywords    = v; }
            }

            if (!isApp || noDisplay || hidden || e.exec.isEmpty())
                continue;

            if (e.name.isEmpty())
                e.name = QFileInfo(path).baseName();

            static const QRegularExpression k_fc(u"%[fFuUdDnNvmkic]"_s);
            e.exec.remove(k_fc);
            e.exec = e.exec.simplified();

            results << e;
        }
    }

    std::ranges::sort(results, [](const RawEntry& a, const RawEntry& b) {
        return a.name.toLower() < b.name.toLower();
    });

    return results;
}

// --- AppEntry ----------------------------------------------------------------

AppEntry::AppEntry(QString name, QString genericName, QString comment,
                   QString icon, QString exec, QString keywords,
                   bool terminal, QObject* parent)
    : QObject(parent)
    , m_name(std::move(name))
    , m_genericName(std::move(genericName))
    , m_comment(std::move(comment))
    , m_icon(std::move(icon))
    , m_exec(std::move(exec))
    , m_keywords(std::move(keywords))
    , m_terminal(terminal) {}

QString AppEntry::name()        const { return m_name; }
QString AppEntry::genericName() const { return m_genericName; }
QString AppEntry::comment()     const { return m_comment; }
QString AppEntry::icon()        const { return m_icon; }
QString AppEntry::exec()        const { return m_exec; }
QString AppEntry::keywords()    const { return m_keywords; }
bool    AppEntry::terminal()    const { return m_terminal; }

// --- AppScanner --------------------------------------------------------------

AppScanner::AppScanner(QObject* parent)
    : QObject(parent) {
    scan();
}

bool AppScanner::loaded() const {
    return m_loaded;
}

QQmlListProperty<AppEntry> AppScanner::apps() {
    return { this, &m_apps };
}

void AppScanner::scan() {
    QtConcurrent::run(scanDesktopFiles).then(this, [this](QList<RawEntry> raw) {
        qDeleteAll(m_apps);
        m_apps.clear();
        m_apps.reserve(raw.size());
        for (const RawEntry& r : raw)
            m_apps << new AppEntry(r.name, r.genericName, r.comment, r.icon, r.exec, r.keywords, r.terminal, this);
        if (!m_loaded) {
            m_loaded = true;
            emit loadedChanged();
        }
        emit appsChanged();
        emit scanComplete();
    });
}

void AppScanner::launch(AppEntry* entry) {
    if (!entry || entry->exec().isEmpty())
        return;

    QString cmd = entry->exec();
    QStringList args;

    if (entry->terminal()) {
        // Prefer $TERMINAL, fall through common terminals.
        const QString term = qEnvironmentVariable("TERMINAL");
        const QStringList candidates = term.isEmpty()
            ? QStringList{ u"kitty"_s, u"alacritty"_s, u"wezterm"_s, u"foot"_s, u"xterm"_s }
            : QStringList{ term };

        for (const QString& t : candidates) {
            if (!QStandardPaths::findExecutable(t).isEmpty()) {
                QProcess::startDetached(t, { u"-e"_s, cmd });
                return;
            }
        }
        qCWarning(lcApps) << "launch: no terminal emulator found for" << entry->name();
        return;
    }

    QProcess::startDetached(u"sh"_s, { u"-c"_s, cmd + u" &"_s });
}

} // namespace peakshell::apps
