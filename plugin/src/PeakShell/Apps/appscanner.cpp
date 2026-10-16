#include "appscanner.hpp"
#include "calculator.h"
#include "fuzzy/fuzzysearch.h"

#include <algorithm>
#include <cmath>
#include <qclipboard.h>
#include <qdesktopservices.h>
#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qguiapplication.h>
#include <qloggingcategory.h>
#include <qregularexpression.h>
#include <qstandardpaths.h>
#include <qtconcurrentrun.h>
#include <qtextstream.h>
#include <qurl.h>

#include <cerrno>
#include <csignal>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace peakshell::apps {

using Qt::StringLiterals::operator""_s;

Q_LOGGING_CATEGORY(lcApps, "peakshell.apps", QtInfoMsg)

// --- OpenSearch parity search ------------------------------------------------
// Scoring mirrors OpenSearch SearchFilters exactly:
//   score = partial_ratio(name) * 0.7 + ratio(generic) * 0.1
//         + ratio(comment) * 0.1 + ratio(keywords) * 0.1
//   keep entries with score > kFuzzyThreshold (57.0)
//   plus containment floors (tuning allowance) so exact short queries
//   always qualify and OpenSearch matchScore boosts decide the order
//   (name partial is length-capped so stub names can't outrank real matches)
// Final ordering mirrors ResultItem::matchScore prefix/containment boosts.
// Web fallback mirrors SearchFilters::googleSearch exponential curve.
// Calculator mirrors SearchFilters::calculate (exprtk, score 100).
// "Run in terminal" (executeTerminal) is intentionally NOT implemented.

namespace {

constexpr double kFuzzyThreshold = 57.0;
constexpr double kNameWeight = 0.7;
constexpr double kGenericWeight = 0.1;
constexpr double kCommentWeight = 0.1;
constexpr double kKeywordsWeight = 0.1;

constexpr int kWebInitCount = 8;
constexpr double kWebCurveMultiplier = 0.5;
constexpr double kCalcScore = 100.0;
// Direct textual evidence (either side contains the other) outranks the web
// fallback (which maxes out at threshold + 10 = 67.0).
constexpr double kContainFloor = kFuzzyThreshold + 12.0;
// Minimum candidate name length for the reverse containment floor below.
constexpr int kMinReverseNameLen = 3;

constexpr char kWebSearchName[] = "Search Google";
constexpr char kWebSearchIcon[] = "system-search";
constexpr char kWebSearchUrl[] = "https://www.google.com/search?q=";
constexpr char kCalcIcon[] = "accessories-calculator";

struct IpcAction {
    const char* function; // peakshell ipc call ii1qe <function>
    const char* name;
    const char* genericName;
    const char* comment;
    const char* keywords;
    const char* icon;
};

// All toggleable `ii1qe` IPC targets from Bar.qml.
constexpr IpcAction kIpcActions[] = {
    { "sound", "Sound", "Audio", "Toggle sound panel", "sound volume audio mixer speaker", "audio-volume-high" },
    { "overlay", "System Overlay", "Monitor", "Toggle system monitor overlay", "overlay system monitor stats cpu mem", "utilities-system-monitor" },
    { "nextWallpaper", "Next Wallpaper", "Wallpaper", "Switch to the next wallpaper", "wallpaper background next switch", "go-next" },
    { "launcher", "Launcher", "Search", "Toggle the app launcher", "launcher search apps", "system-search" },
    { "calendar", "Calendar", "Clock", "Toggle calendar panel", "calendar clock date time", "x-office-calendar" },
    { "bluetooth", "Bluetooth", "Devices", "Toggle bluetooth panel", "bluetooth bt devices", "bluetooth" },
    { "showWallpaper", "Show Wallpaper", "Wallpaper", "Show the wallpaper preview", "wallpaper background show preview", "preferences-desktop-wallpaper" },
    { "wifi", "Wi-Fi", "Network", "Toggle wifi panel", "wifi wi-fi network wireless internet", "network-wireless" },
    { "arch", "Arch Dashboard", "Menu", "Toggle Arch dashboard", "arch dashboard menu logo", "start-here" },
    { "shutdown", "Power Menu", "Session", "Toggle power menu", "shutdown power reboot logout suspend poweroff", "system-shutdown" },
    { "workspace", "Workspaces", "Overview", "Toggle workspaces panel", "workspace workspaces overview desktops", "view-grid" },
    { "previousWallpaper", "Previous Wallpaper", "Wallpaper", "Switch to the previous wallpaper", "wallpaper background previous back", "go-previous" },
};

inline std::string lowerStd(const QString& s) {
    return s.toLower().toStdString();
}

// Weighted OpenSearch fuzzy score for one candidate.
// Tuning fix: the name partial_ratio is capped by the name/query length
// ratio. partial_ratio trivially returns 100 for stub candidates (e.g. the
// single-letter app "R") whenever the query merely contains that letter,
// which would otherwise outrank genuine typo matches like "firefcx"->Firefox.
inline double fuzzyScore(const std::string& q, const QString& name,
                         const QString& genericName, const QString& comment,
                         const QString& keywords) {
    const double lenCap = q.empty() ? 1.0
        : std::min(1.0, static_cast<double>(name.length()) / static_cast<double>(q.length()));
    double score = FuzzySearch::getPartialMatch(q, lowerStd(name)) * lenCap * kNameWeight;
    score += FuzzySearch::getMatch(q, lowerStd(genericName)) * kGenericWeight;
    score += FuzzySearch::getMatch(q, lowerStd(comment)) * kCommentWeight;
    score += FuzzySearch::getMatch(q, lowerStd(keywords)) * kKeywordsWeight;
    return score;
}

// Mirrors ResultItem::matchScore(): prefix/containment boosts over the fuzzy score.
inline double matchSortKey(const QString& name, const QString& genericName,
                           const QString& keywords, const QString& query, double score) {
    if (name.startsWith(query, Qt::CaseInsensitive))
        return 1000.0 + score;
    if (genericName.startsWith(query, Qt::CaseInsensitive))
        return 900.0 + score;
    if (name.contains(query, Qt::CaseInsensitive))
        return 500.0 + score;
    if (genericName.contains(query, Qt::CaseInsensitive))
        return 400.0 + score;
    if (keywords.contains(query, Qt::CaseInsensitive))
        return 300.0 + score;
    return score;
}

// Mirrors SearchFilters::googleSearch scoring: short queries score ~0 and only
// outrank apps once the query is long enough to likely not be an app name.
inline double webFallbackScore(qsizetype queryLength) {
    const double over = static_cast<double>(qMax(qsizetype{0}, queryLength - kWebInitCount));
    const double grown = 100.0 * (1.0 - std::exp(-kWebCurveMultiplier * over));
    return qMin(kFuzzyThreshold + 10.0, grown);
}

inline QVariantMap makeMap(const QString& name, const QString& genericName,
                            const QString& comment, const QString& icon, const QString& exec,
                            const QString& keywords, bool terminal, const QString& kind,
                            const QString& ipcFunction, const QString& uid, double score) {
    QVariantMap m;
    m.insert(u"name"_s, name);
    m.insert(u"genericName"_s, genericName);
    m.insert(u"comment"_s, comment);
    m.insert(u"icon"_s, icon);
    m.insert(u"exec"_s, exec);
    m.insert(u"keywords"_s, keywords);
    m.insert(u"terminal"_s, terminal);
    m.insert(u"kind"_s, kind);
    m.insert(u"ipcFunction"_s, ipcFunction);
    m.insert(u"uid"_s, uid);
    m.insert(u"score"_s, score);
    return m;
}

// Fully detached spawn: classic double fork + setsid + stdio to /dev/null.
// The grandchild lands in a new session with no controlling terminal and is
// reparented to init, so the app never holds the shell's terminal/stdout and
// survives the parent (or its terminal) exiting. No zombies: the middle
// child is reaped here, the grandchild by init.
void spawnDetached(const QString& program, const QStringList& args) {
    if (program.isEmpty())
        return;

    // Encode argv before forking (no allocation between fork and exec).
    QByteArray prog = program.toUtf8();
    QList<QByteArray> argBytes;
    argBytes.reserve(args.size());
    for (const QString& a : args)
        argBytes.append(a.toUtf8());
    std::vector<char*> argv;
    argv.reserve(argBytes.size() + 2);
    argv.push_back(prog.data());
    for (QByteArray& b : argBytes)
        argv.push_back(b.data());
    argv.push_back(nullptr);

    const pid_t pid = ::fork();
    if (pid < 0) {
        qCWarning(lcApps) << "spawn: fork failed for" << program;
        return;
    }
    if (pid > 0) {
        int status = 0;
        while (::waitpid(pid, &status, 0) < 0 && errno == EINTR) {
        }
        return;
    }
    // First child: new session, then fork again so the grandchild can never
    // reacquire a controlling terminal.
    if (::setsid() < 0)
        ::_exit(127);
    const pid_t pid2 = ::fork();
    if (pid2 < 0)
        ::_exit(127);
    if (pid2 > 0)
        ::_exit(0);
    // Grandchild: detach stdio and drop the inherited SIGPIPE ignore (Qt sets
    // it process-wide; children should get the default disposition).
    const int devNull = ::open("/dev/null", O_RDWR);
    if (devNull >= 0) {
        ::dup2(devNull, STDIN_FILENO);
        ::dup2(devNull, STDOUT_FILENO);
        ::dup2(devNull, STDERR_FILENO);
        if (devNull > STDERR_FILENO)
            ::close(devNull);
    }
    std::signal(SIGPIPE, SIG_DFL);
    ::execvp(argv[0], argv.data());
    ::_exit(127);
}

void spawnShellDetached(const QString& shellCmd) {
    if (shellCmd.isEmpty())
        return;
    QString sh = QStandardPaths::findExecutable(u"sh"_s);
    if (sh.isEmpty())
        sh = u"/bin/sh"_s;
    spawnDetached(sh, { u"sh"_s, u"-c"_s, shellCmd });
}

void launchCommand(const QString& cmd, bool terminal, const QString& label) {
    if (cmd.isEmpty())
        return;
    if (terminal) {
        const QString term = qEnvironmentVariable("TERMINAL");
        const QStringList candidates = term.isEmpty()
            ? QStringList{ u"kitty"_s, u"alacritty"_s, u"wezterm"_s, u"foot"_s, u"xterm"_s }
            : QStringList{ term };
        for (const QString& t : candidates) {
            if (!QStandardPaths::findExecutable(t).isEmpty()) {
                spawnDetached(t, { u"-e"_s, cmd });
                return;
            }
        }
        qCWarning(lcApps) << "launch: no terminal emulator found for" << label;
        return;
    }
    spawnShellDetached(cmd);
}

void invokeIpc(const QString& function) {
    if (function.isEmpty())
        return;
    // peakshell(1) forwards `ipc call ...` to quickshell; fall back to
    // quickshell directly when the wrapper is not on PATH (dev sessions).
    const QStringList args{ u"ipc"_s, u"call"_s, u"ii1qe"_s, function };
    if (!QStandardPaths::findExecutable(u"peakshell"_s).isEmpty()) {
        spawnDetached(u"peakshell"_s, args);
        return;
    }
    spawnDetached(u"quickshell"_s, args);
}

} // namespace

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
    bool terminal = false;
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
    launchCommand(entry->exec(), entry->terminal(), entry->name());
}

QVariantList AppScanner::search(const QString& query) {
    const QString q = query.trimmed();
    if (q.isEmpty() || !m_loaded)
        return {};

    const QString qLower = q.toLower();
    const std::string qStd = qLower.toStdString();

    struct Scored {
        QVariantMap map;
        double key = 0.0;
    };
    QVector<Scored> acc;
    acc.reserve(m_apps.size() + 16);

    // 1. Fuzzy-matched applications (OpenSearch weights + threshold).
    // Tuning allowance: direct textual evidence in either direction (a field
    // containing the query, or the query containing the candidate name)
    // qualifies via the containment floor, so short exact queries like
    // "wifi" still recall "Wi-Fi". OpenSearch matchScore boosts below still
    // decide the final order.
    for (const AppEntry* app : std::as_const(m_apps)) {
        double score = fuzzyScore(qStd, app->name(), app->genericName(),
                                  app->comment(), app->keywords());
        if (app->name().contains(q, Qt::CaseInsensitive)
            || app->genericName().contains(q, Qt::CaseInsensitive)
            || app->comment().contains(q, Qt::CaseInsensitive)
            || app->keywords().contains(q, Qt::CaseInsensitive))
            score = qMax(score, kContainFloor);
        else if (app->name().length() >= kMinReverseNameLen
                 && q.contains(app->name(), Qt::CaseInsensitive))
            score = qMax(score, kContainFloor);
        if (score <= kFuzzyThreshold)
            continue;
        QVariantMap m = makeMap(app->name(), app->genericName(), app->comment(), app->icon(),
                                app->exec(), app->keywords(), app->terminal(), u"app"_s,
                                QString(), u"app:"_s + app->exec() + u"\n"_s + app->name(),
                                score);
        acc.append({ m, matchSortKey(app->name(), app->genericName(), app->keywords(), q, score) });
    }

    // 2. Toggleable ii1qe IPC actions, fuzzy-matched the same way
    // (plus the same containment floors as apps).
    for (const IpcAction& action : kIpcActions) {
        const QString name = QString::fromUtf8(action.name);
        const QString generic = QString::fromUtf8(action.genericName);
        const QString comment = QString::fromUtf8(action.comment);
        const QString keywords = QString::fromUtf8(action.keywords);
        const QString function = QString::fromUtf8(action.function);
        double score = fuzzyScore(qStd, name, generic, comment, keywords);
        if (name.contains(q, Qt::CaseInsensitive) || generic.contains(q, Qt::CaseInsensitive)
            || comment.contains(q, Qt::CaseInsensitive)
            || keywords.contains(q, Qt::CaseInsensitive))
            score = qMax(score, kContainFloor);
        else if (name.length() >= kMinReverseNameLen && q.contains(name, Qt::CaseInsensitive))
            score = qMax(score, kContainFloor);
        if (score <= kFuzzyThreshold)
            continue;
        QVariantMap m = makeMap(name, generic, comment, QString::fromUtf8(action.icon),
                                function, keywords, false, u"ipc"_s,
                                function, u"ipc:"_s + function, score);
        acc.append({ m, matchSortKey(name, generic, keywords, q, score) });
    }

    // 3. Exprtk calculator (OpenSearch SearchFilters::calculate parity).
    double calcValue = 0.0;
    if (tryEvaluateExpression(q, calcValue)) {
        const QString text = QString::number(calcValue);
        QVariantMap m = makeMap(text, QString(), QStringLiteral("Calculated for: \"%1\"").arg(q),
                                QString::fromUtf8(kCalcIcon), u"Ignored"_s, QString(), false,
                                u"calc"_s, QString(), u"calc"_s, kCalcScore);
        acc.append({ m, matchSortKey(text, QString(), QString(), q, kCalcScore) });
    }

    // 4. Smart web-search fallback: always present for non-empty queries, but
    // scored so short queries still prefer real apps while long non-app text
    // surfaces the browser entry near the top.
    {
        const double score = webFallbackScore(q.length());
        QVariantMap m = makeMap(QString::fromUtf8(kWebSearchName), QString(),
                                QStringLiteral("Search Google for \"%1\"").arg(q),
                                QString::fromUtf8(kWebSearchIcon),
                                QString::fromUtf8(kWebSearchUrl)
                                    + QString::fromUtf8(QUrl::toPercentEncoding(q)),
                                QString(), false, u"web"_s, QString(), u"web"_s, score);
        acc.append({ m, score });
    }

    std::sort(acc.begin(), acc.end(),
              [](const Scored& a, const Scored& b) { return a.key > b.key; });

    QVariantList out;
    out.reserve(acc.size());
    for (const Scored& s : std::as_const(acc))
        out.append(s.map);
    return out;
}

void AppScanner::activateResult(const QVariantMap& entry) {
    if (entry.isEmpty())
        return;
    const QString kind = entry.value(u"kind"_s, u"app"_s).toString();

    if (kind == u"calc"_s) {
        // Mirror OpenSearch Calculation handling: copy the result to clipboard.
        if (QClipboard* clipboard = QGuiApplication::clipboard())
            clipboard->setText(entry.value(u"name"_s).toString());
        return;
    }
    if (kind == u"web"_s) {
        const QUrl url(entry.value(u"exec"_s).toString());
        if (url.isValid())
            QDesktopServices::openUrl(url);
        return;
    }
    if (kind == u"ipc"_s) {
        invokeIpc(entry.value(u"ipcFunction"_s, entry.value(u"exec"_s)).toString());
        return;
    }
    launchCommand(entry.value(u"exec"_s).toString(),
                  entry.value(u"terminal"_s, false).toBool(),
                  entry.value(u"name"_s).toString());
}

} // namespace peakshell::apps
