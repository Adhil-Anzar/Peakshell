#include "filesearch.hpp"
#include "fuzzy/fuzzysearch.h"
#include "../settings.hpp"

#include <algorithm>
#include <atomic>
#include <memory>
#include <utility>

#include <qatomic.h>
#include <qdatetime.h>
#include <qdir.h>
#include <qdiriterator.h>
#include <qelapsedtimer.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qfilesystemwatcher.h>
#include <qhash.h>
#include <qloggingcategory.h>
#include <qmimedatabase.h>
#include <qmimetype.h>
#include <qmutex.h>
#include <qpointer.h>
#include <qset.h>
#include <qstandardpaths.h>
#include <qstringlist.h>
#include <qtconcurrentrun.h>
#include <qtextstream.h>
#include <qthreadpool.h>
#include <qtimer.h>
#include <qurl.h>
#include <qxmlstream.h>

#ifdef PEAKSHELL_HAVE_BALOO
#include <Baloo/Query>
#include <Baloo/QueryRunnable>
#endif

namespace peakshell::apps {

using Qt::StringLiterals::operator""_s;

Q_LOGGING_CATEGORY(lcFileSearch, "peakshell.filesearch", QtInfoMsg)

namespace {

constexpr int kMaxRecentResults = 12;
constexpr int kMaxBackendResults = 40;
constexpr int kMaxRecentEntries = 1500;
constexpr double kFileFuzzyThreshold = 80.0;
constexpr int kFallbackMaxEntries = 50000;
constexpr int kFallbackBudgetMs = 900;
constexpr int kConfigMaxEntries = 30000;
constexpr int kConfigBudgetMs = 400;
constexpr int kConfigMaxDepth = 4;
constexpr int kFullFallbackMaxEntries = 250000;
constexpr int kFullFallbackBudgetMs = 2000;

struct RecentEntry {
    QString path;
    bool isDir = false;
    qint64 visited = 0;
};

struct Options {
    bool files = true;
    bool folders = true;
    bool fileFuzzy = true;
    bool folderFuzzy = true;
    bool fullFilesystem = false;
};

struct SearchState {
    quint64 generation = 0;
    QString query;
    QString queryLower;
    Options options;
    bool finished = false;
    QVariantList recentResults;
    QVariantList backendResults;
    QSet<QString> recentPaths;
    QStringList balooPaths;
    QSet<QString> balooSeen;
    std::shared_ptr<std::atomic_bool> cancelFlag;
};

// -- Recent-file sources ---------------------------------------------------

qint64 parseTimestamp(const QString& visited, const QString& modified,
                      const QFileInfo& info) {
    QDateTime dt = QDateTime::fromString(visited, Qt::ISODate);
    if (!dt.isValid())
        dt = QDateTime::fromString(modified, Qt::ISODate);
    if (dt.isValid())
        return dt.toMSecsSinceEpoch();
    return info.lastModified().toMSecsSinceEpoch();
}

void addOrUpdate(QHash<QString, RecentEntry>& entries, const QString& path,
                 qint64 visited, bool isDir) {
    if (path.isEmpty())
        return;
    const QString abs = QDir::cleanPath(path);
    if (abs.isEmpty() || abs == u"/"_s || abs == QDir::homePath())
        return;
    auto it = entries.find(abs);
    if (it == entries.end()) {
        entries.insert(abs, RecentEntry{ abs, isDir, visited });
        return;
    }
    it->isDir = it->isDir || isDir;
    if (visited > it->visited)
        it->visited = visited;
}

void loadXbel(const QString& path, QHash<QString, RecentEntry>& entries) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QXmlStreamReader xml(&file);
    while (!xml.atEnd()) {
        xml.readNext();
        if (!xml.isStartElement() || xml.name().toString() != u"bookmark"_s)
            continue;

        const QXmlStreamAttributes attrs = xml.attributes();
        const QString href = attrs.value(u"href"_s).toString();
        if (href.isEmpty())
            continue;

        QUrl url = QUrl::fromEncoded(href.toUtf8());
        if (!url.isLocalFile())
            continue;

        const QString local = url.toLocalFile();
        if (local.isEmpty())
            continue;

        QFileInfo info(local);
        if (!info.exists())
            continue;

        const qint64 visited = parseTimestamp(attrs.value(u"visited"_s).toString(),
                                              attrs.value(u"modified"_s).toString(),
                                              info);
        addOrUpdate(entries, info.absoluteFilePath(), visited, info.isDir());
        if (!info.isDir()) {
            // Files imply their parent folder: searching for "Documents"
            // should also surface a folder the user recently worked in.
            addOrUpdate(entries, info.absolutePath(), visited > 0 ? visited - 1 : 0, true);
        }
    }
}

void loadKdeRecent(QHash<QString, RecentEntry>& entries) {
    // KRecentDocument's older storage. Newer KDE releases may write the
    // XDG recently-used.xbel file instead, but supporting both is cheap.
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + u"/RecentDocuments"_s;
    QDir d(dir);
    if (!d.exists())
        return;

    QDirIterator it(dir, QStringList{ u"*.desktop"_s }, QDir::Files);
    while (it.hasNext()) {
        it.next();
        QFile file(it.filePath());
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            continue;

        QTextStream in(&file);
        QString url;
        while (!in.atEnd()) {
            const QString line = in.readLine().trimmed();
            if (line.startsWith(u"URL="_s)) {
                url = line.sliced(4).trimmed();
                break;
            }
        }
        if (url.isEmpty())
            continue;

        QUrl u = QUrl::fromEncoded(url.toUtf8());
        if (!u.isLocalFile())
            continue;

        QFileInfo info(u.toLocalFile());
        if (!info.exists())
            continue;

        const qint64 visited = it.fileInfo().lastModified().toMSecsSinceEpoch();
        addOrUpdate(entries, info.absoluteFilePath(), visited, info.isDir());
        if (!info.isDir())
            addOrUpdate(entries, info.absolutePath(), visited - 1, true);
    }
}

QList<RecentEntry> loadRecentEntries() {
    QHash<QString, RecentEntry> entries;
    const QString dataHome = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    loadXbel(dataHome + u"/recently-used.xbel"_s, entries);
    loadXbel(QDir::homePath() + u"/.recently-used.xbel"_s, entries);
    loadKdeRecent(entries);

    QList<RecentEntry> list = entries.values();
    std::stable_sort(list.begin(), list.end(), [](const RecentEntry& a, const RecentEntry& b) {
        return a.visited > b.visited;
    });
    if (list.size() > kMaxRecentEntries)
        list.resize(kMaxRecentEntries);
    return list;
}

// -- Matching --------------------------------------------------------------

double fuzzyNameScore(const QString& queryLower, const QString& nameLower) {
    const std::string q = queryLower.toStdString();
    const std::string n = nameLower.toStdString();
    // Cap the partial-ratio by the name/query length ratio. Without this a
    // one-letter candidate ("A") scores 100 against any long query because
    // its text appears somewhere in it (the same stub-name trap the app
    // search fixes with a length cap).
    const double lenCap = q.empty() ? 1.0
        : std::min(1.0, static_cast<double>(n.length()) / static_cast<double>(q.length()));
    return std::max(FuzzySearch::getPartialMatch(q, n) * lenCap,
                    FuzzySearch::getMatch(q, n));
}

double nameScore(const QString& queryLower, const QString& nameLower, bool fuzzy) {
    if (queryLower.isEmpty())
        return 0.0;
    if (nameLower == queryLower)
        return 1000.0;
    if (nameLower.startsWith(queryLower))
        return 900.0;
    if (nameLower.contains(queryLower))
        return 700.0;
    if (!fuzzy)
        return 0.0;
    const double score = fuzzyNameScore(queryLower, nameLower);
    return score >= kFileFuzzyThreshold ? score : 0.0;
}

bool literalMatch(const QString& queryLower, const QString& nameLower,
                  const QString& pathLower) {
    if (nameLower.contains(queryLower) || pathLower.contains(queryLower))
        return true;
    const QStringList tokens = queryLower.split(u' ', Qt::SkipEmptyParts);
    if (tokens.size() <= 1)
        return false;
    for (const QString& token : tokens) {
        if (!nameLower.contains(token) && !pathLower.contains(token))
            return false;
    }
    return true;
}

double matchScore(const QString& queryLower, const QString& nameLower,
                  const QString& pathLower, bool fuzzy) {
    double score = nameScore(queryLower, nameLower, fuzzy);
    if (score <= 0 && queryLower.length() >= 2 && pathLower.contains(queryLower))
        score = fuzzy ? 300.0 : 400.0;
    if (score <= 0 && !fuzzy && literalMatch(queryLower, nameLower, pathLower))
        score = 350.0;
    return score;
}

bool isHiddenPath(const QString& path) {
    const QString home = QDir::homePath();
    if (path.startsWith(home + u'/')) {
        const QString rel = path.sliced(home.size() + 1);
        for (const QString& part : rel.split(u'/', Qt::SkipEmptyParts)) {
            if (part.startsWith(u'.'))
                return true;
        }
        return false;
    }
    return path.contains(u"/."_s);
}

bool isHeavyDir(const QString& name) {
    static const QSet<QString> heavy = {
        u"node_modules"_s, u"build"_s, u"target"_s, u"__pycache__"_s,
        u"CMakeFiles"_s, u"cmake-build-debug"_s, u"cmake-build-release"_s,
        u"dist"_s, u"out"_s, u"venv"_s, u"Windows11"_s, u"winboat"_s,
        u"Games"_s,
    };
    return heavy.contains(name);
}

// Config roots contain a lot of browser/editor profile data. Those trees are
// large and rarely what someone is looking for by file name.
bool isHeavyConfigDir(const QString& name) {
    static const QSet<QString> heavy = {
        u"Code"_s, u"chromium"_s, u"google-chrome"_s, u"BraveSoftware"_s,
        u"mozilla"_s, u"thunderbird"_s, u"libreoffice"_s, u"discord"_s,
        u"Slack"_s, u"spotify"_s, u"obs-studio"_s, u"JetBrains"_s,
        u"Microsoft"_s, u"gcloud"_s,
    };
    return isHeavyDir(name) || heavy.contains(name);
}

// Pseudo-filesystems contain runtime state, not searchable documents, and
// walking them can be extremely slow or recursive.
bool isPseudoPath(const QString& path) {
    static const QStringList roots = {
        u"/proc"_s, u"/sys"_s, u"/dev"_s, u"/run"_s, u"/snap"_s,
    };
    for (const QString& root : roots) {
        if (path == root || path.startsWith(root + u'/'))
            return true;
    }
    return false;
}

// -- Result maps -----------------------------------------------------------

QString mimeIcon(const QFileInfo& info, QMimeDatabase& db) {
    const QMimeType type = db.mimeTypeForFile(info, QMimeDatabase::MatchExtension);
    const QString icon = type.iconName();
    return icon.isEmpty() ? u"text-x-generic"_s : icon;
}

QVariantMap makeResult(const QFileInfo& info, bool isDir, bool recent,
                       double score, QMimeDatabase& db) {
    const QString path = info.absoluteFilePath();
    QVariantMap m;
    m.insert(u"name"_s, info.fileName());
    m.insert(u"genericName"_s, isDir ? u"Folder"_s : u"File"_s);
    m.insert(u"comment"_s, info.absolutePath());
    m.insert(u"icon"_s, isDir ? u"folder"_s : mimeIcon(info, db));
    m.insert(u"exec"_s, path);
    m.insert(u"keywords"_s, isDir ? u"Folder"_s : info.suffix().toUpper());
    m.insert(u"terminal"_s, false);
    m.insert(u"kind"_s, isDir ? u"folder"_s : u"file"_s);
    m.insert(u"ipcFunction"_s, QString());
    m.insert(u"uid"_s, (isDir ? u"folder:"_s : u"file:"_s) + path);
    m.insert(u"score"_s, score);
    m.insert(u"detail"_s, recent ? u"Recent"_s : QString());
    return m;
}

QVariantList buildRecentResults(const QList<RecentEntry>& recent,
                                const QString& queryLower, const Options& options) {
    struct Scored {
        RecentEntry entry;
        double score = 0.0;
    };
    QList<Scored> matches;
    QMimeDatabase db;
    const bool allRecent = queryLower.isEmpty();
    for (const RecentEntry& entry : recent) {
        QFileInfo info(entry.path);
        if (!info.exists())
            continue;
        const bool isDir = info.isDir();
        if (isDir ? !options.folders : !options.files)
            continue;
        const QString name = info.fileName();
        if (name.isEmpty())
            continue;
        const bool fuzzy = isDir ? options.folderFuzzy : options.fileFuzzy;
        // An empty query is the scoped "/files" / "/folder" mode: list the
        // recent entries themselves, newest first.
        const double score = allRecent
            ? 0.0
            : matchScore(queryLower, name.toLower(),
                         info.absoluteFilePath().toLower(), fuzzy);
        if (!allRecent && score <= 0)
            continue;
        matches.append({ entry, score });
    }

    std::stable_sort(matches.begin(), matches.end(), [](const Scored& a, const Scored& b) {
        if (a.score > b.score)
            return true;
        if (a.score < b.score)
            return false;
        return a.entry.visited > b.entry.visited;
    });

    const int limit = qMin(kMaxRecentResults, static_cast<int>(matches.size()));
    QVariantList out;
    out.reserve(limit);
    for (int i = 0; i < limit; ++i) {
        const Scored& match = matches[i];
        QFileInfo info(match.entry.path);
        out.append(makeResult(info, info.isDir(), true, match.score, db));
    }
    return out;
}

QVariantList buildBackendResults(const QStringList& paths, const QSet<QString>& exclude,
                                 const QString& queryLower, const Options& options,
                                 int limit) {
    struct Scored {
        QString path;
        bool isDir = false;
        double score = 0.0;
        int order = 0;
    };
    QList<Scored> matches;
    QSet<QString> seen;
    QMimeDatabase db;
    for (int i = 0; i < paths.size(); ++i) {
        const QString& path = paths[i];
        if (exclude.contains(path) || seen.contains(path))
            continue;
        seen.insert(path);

        QFileInfo info(path);
        if (!info.exists() || isHiddenPath(path))
            continue;
        const bool isDir = info.isDir();
        if (isDir ? !options.folders : !options.files)
            continue;
        const QString name = info.fileName();
        if (name.isEmpty())
            continue;
        const bool fuzzy = isDir ? options.folderFuzzy : options.fileFuzzy;
        const double score = matchScore(queryLower, name.toLower(),
                                        info.absoluteFilePath().toLower(), fuzzy);
        if (score <= 0)
            continue;
        matches.append({ info.absoluteFilePath(), isDir, score, i });
    }

    std::stable_sort(matches.begin(), matches.end(), [](const Scored& a, const Scored& b) {
        if (a.score > b.score)
            return true;
        if (a.score < b.score)
            return false;
        return a.order < b.order;
    });

    const int count = qMin(limit, static_cast<int>(matches.size()));
    QVariantList out;
    out.reserve(count);
    for (int i = 0; i < count; ++i) {
        QFileInfo info(matches[i].path);
        out.append(makeResult(info, matches[i].isDir, false, matches[i].score, db));
    }
    return out;
}

struct FallbackHit {
    QString path;
    bool isDir = false;
    double score = 0.0;
};

// Baloo deliberately does not index hidden directories, so a file such as
// ~/.config/hypr/hyprpaper.conf is invisible to it. Config trees are small
// enough to inspect directly, but are still bounded by depth, entry count and
// a time budget so a huge profile directory cannot stall the search.
void scanConfigPaths(const QString& root, int maxDepth, const QString& queryLower,
                     const QSet<QString>& exclude, const Options& options,
                     int limit, QList<FallbackHit>& hits, QSet<QString>& seenPaths,
                     const std::shared_ptr<std::atomic_bool>& cancel) {
    if (!QFileInfo(root).isDir())
        return;

    struct Pending {
        QString path;
        int depth = 0;
    };
    QList<Pending> stack{ { root, 0 } };
    QSet<QString> visitedDirs;
    QElapsedTimer timer;
    timer.start();
    int visited = 0;

    while (!stack.isEmpty() && hits.size() < limit && visited < kConfigMaxEntries
           && timer.elapsed() < kConfigBudgetMs) {
        if (cancel->load(std::memory_order_relaxed))
            break;

        const Pending pending = stack.takeLast();
        if (visitedDirs.contains(pending.path))
            continue;
        visitedDirs.insert(pending.path);

        const QFileInfoList entries = QDir(pending.path).entryInfoList(
            QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot | QDir::Readable,
            QDir::Name);
        for (const QFileInfo& info : entries) {
            if (cancel->load(std::memory_order_relaxed))
                break;
            ++visited;

            if (info.isDir()) {
                if (pending.depth < maxDepth && !info.isSymLink()
                    && !info.fileName().startsWith(u'.')
                    && !isHeavyConfigDir(info.fileName()))
                    stack.append({ info.absoluteFilePath(), pending.depth + 1 });
            }

            const QString path = info.absoluteFilePath();
            if (exclude.contains(path) || seenPaths.contains(path))
                continue;
            const bool isDir = info.isDir();
            if (isDir ? !options.folders : !options.files)
                continue;
            const QString name = info.fileName();
            if (name.isEmpty())
                continue;
            const bool fuzzy = isDir ? options.folderFuzzy : options.fileFuzzy;
            const double score = matchScore(queryLower, name.toLower(), path.toLower(), fuzzy);
            if (score <= 0)
                continue;
            seenPaths.insert(path);
            hits.append({ path, isDir, score });
            if (hits.size() >= limit)
                break;
        }

        if (visited >= kConfigMaxEntries)
            break;
    }
}

QVariantList scanFallback(const QString& queryLower, const QSet<QString>& exclude,
                          const Options& options, int limit,
                          const std::shared_ptr<std::atomic_bool>& cancel) {
    QList<FallbackHit> hits;
    QSet<QString> seenPaths;
    QMimeDatabase db;

    // Hidden config paths are only searched in full-filesystem mode. Baloo
    // does not index them, so this is the expensive opt-in path that makes
    // files such as ~/.config/hypr/hyprpaper.conf discoverable.
    if (options.fullFilesystem) {
        const int configLimit = qMin(limit, 12);
        scanConfigPaths(QDir::homePath() + u"/.config"_s, kConfigMaxDepth,
                        queryLower, exclude, options, configLimit, hits, seenPaths, cancel);
        scanConfigPaths(QDir::homePath() + u"/.local/share/applications"_s, 2,
                        queryLower, exclude, options, configLimit, hits, seenPaths, cancel);
    }

    QStringList stack;
    if (options.fullFilesystem)
        stack = QStringList{ u"/"_s, QDir::homePath() };
    else
        stack = QStringList{ QDir::homePath() };
    QSet<QString> visitedDirs;
    QElapsedTimer timer;
    timer.start();
    int visited = 0;
    int cursor = 0;
    const int maxEntries = options.fullFilesystem ? kFullFallbackMaxEntries : kFallbackMaxEntries;
    const int budgetMs = options.fullFilesystem ? kFullFallbackBudgetMs : kFallbackBudgetMs;

    while ((options.fullFilesystem ? cursor < stack.size() : !stack.isEmpty())
           && visited < maxEntries && timer.elapsed() < budgetMs) {
        if (cancel->load(std::memory_order_relaxed))
            break;

        // Full filesystem mode walks breadth-first so every top-level
        // directory gets a chance before the budget runs out. The normal
        // home scan stays depth-first to reach project files quickly.
        const QString dirPath = options.fullFilesystem ? stack.at(cursor++) : stack.takeLast();
        if (visitedDirs.contains(dirPath) || isPseudoPath(dirPath))
            continue;
        visitedDirs.insert(dirPath);

        const QFileInfoList entries = QDir(dirPath).entryInfoList(
            QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot | QDir::Readable,
            QDir::Name);
        for (const QFileInfo& info : entries) {
            if (cancel->load(std::memory_order_relaxed))
                break;
            ++visited;

            if (info.isDir()) {
                if (!info.isSymLink() && !info.fileName().startsWith(u'.')
                    && !isHeavyDir(info.fileName())
                    && !isPseudoPath(info.absoluteFilePath()))
                    stack.append(info.absoluteFilePath());
            }

            const QString path = info.absoluteFilePath();
            if (exclude.contains(path) || seenPaths.contains(path))
                continue;
            const bool isDir = info.isDir();
            if (isDir ? !options.folders : !options.files)
                continue;
            const QString name = info.fileName();
            if (name.isEmpty() || name.startsWith(u'.'))
                continue;
            const bool fuzzy = isDir ? options.folderFuzzy : options.fileFuzzy;
            const double score = matchScore(queryLower, name.toLower(), path.toLower(), fuzzy);
            if (score > 0) {
                seenPaths.insert(path);
                hits.append({ path, isDir, score });
            }
        }
    }

    std::stable_sort(hits.begin(), hits.end(), [](const FallbackHit& a, const FallbackHit& b) {
        return a.score > b.score;
    });
    const int count = qMin(limit, static_cast<int>(hits.size()));
    QVariantList out;
    out.reserve(count);
    for (int i = 0; i < count; ++i) {
        QFileInfo info(hits[i].path);
        out.append(makeResult(info, hits[i].isDir, false, hits[i].score, db));
    }
    return out;
}

#ifdef PEAKSHELL_HAVE_BALOO
bool balooAvailable() {
    const QString db = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + u"/baloo/index"_s;
    return QFileInfo::exists(db);
}
#endif

} // namespace

struct FileSearch::Private {
    FileSearch* q = nullptr;

    QAtomicInteger<quint64> generation{ 0 };
    bool searching = false;
    std::shared_ptr<SearchState> current;

    QMutex recentMutex;
    QList<RecentEntry> recent;
    bool recentLoaded = false;
    QFileSystemWatcher watcher;
    QTimer reloadTimer;
    QString xbelPath;
    QString xbelParent;
    QString recentDocsPath;
    QPointer<QObject> balooRunnable;

    void init();
    void search(const QString& query);
    void searchScoped(const QString& query, const QString& scope);
    void cancel();
    void startBackend(const std::shared_ptr<SearchState>& state);
    void startBaloo(const std::shared_ptr<SearchState>& state);
    void startFallback(const std::shared_ptr<SearchState>& state);
    void startBackendBuild(const std::shared_ptr<SearchState>& state,
                           const QStringList& paths);
    void finish(const std::shared_ptr<SearchState>& state);
    void setSearching(bool value);
    void reloadRecent();
    QList<RecentEntry> recentSnapshot();
};

void FileSearch::Private::init() {
    reloadTimer.setSingleShot(true);
    reloadTimer.setInterval(500);
    QObject::connect(&reloadTimer, &QTimer::timeout, q, [this] { reloadRecent(); });

    const QString dataHome = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    xbelPath = dataHome + u"/recently-used.xbel"_s;
    xbelParent = dataHome;
    recentDocsPath = dataHome + u"/RecentDocuments"_s;

    if (QFileInfo::exists(xbelPath))
        watcher.addPath(xbelPath);
    else if (QDir(dataHome).exists())
        watcher.addPath(dataHome);
    if (QDir(recentDocsPath).exists())
        watcher.addPath(recentDocsPath);

    QObject::connect(&watcher, &QFileSystemWatcher::fileChanged, q,
                     [this](const QString& path) {
                         if (path == xbelPath && QFileInfo::exists(path)
                             && !watcher.files().contains(path))
                             watcher.addPath(path);
                         reloadTimer.start();
                     });
    QObject::connect(&watcher, &QFileSystemWatcher::directoryChanged, q,
                     [this](const QString& path) {
                         if (path == xbelParent) {
                             // Watched the parent because the file did not
                             // exist yet: switch to the file once it appears.
                             if (QFileInfo::exists(xbelPath)) {
                                 watcher.removePath(xbelParent);
                                 watcher.addPath(xbelPath);
                                 reloadTimer.start();
                             }
                             return;
                         }
                         if (path == recentDocsPath)
                             reloadTimer.start();
                     });

    reloadRecent();
}

void FileSearch::Private::search(const QString& query) {
    searchScoped(query, u"all"_s);
}

void FileSearch::Private::searchScoped(const QString& query, const QString& scope) {
    const QString queryText = query.trimmed();
    const QString scopeLower = scope.trimmed().toLower();

    const bool fileScope = scopeLower == u"files"_s || scopeLower == u"file"_s;
    const bool folderScope = scopeLower == u"folders"_s || scopeLower == u"folder"_s;
    const bool explicitScope = fileScope || folderScope;

    bool filesOn = Settings::fileSearchEnabled();
    bool foldersOn = Settings::folderSearchEnabled();
    if (fileScope) {
        // An explicit prefix is a direct request: honour it even when the
        // ambient launcher toggle is off, and only search that kind.
        filesOn = true;
        foldersOn = false;
    } else if (folderScope) {
        filesOn = false;
        foldersOn = true;
    }

    if (!filesOn && !foldersOn) {
        cancel();
        return;
    }
    // A general search needs text. A scoped one may be empty: "/files" and
    // "/folder" then list the recent entries.
    if (queryText.isEmpty() && !explicitScope) {
        cancel();
        return;
    }

    const quint64 gen = generation.fetchAndAddOrdered(1) + 1;
    if (current)
        current->cancelFlag->store(true, std::memory_order_relaxed);
#ifdef PEAKSHELL_HAVE_BALOO
    if (balooRunnable)
        static_cast<Baloo::QueryRunnable*>(balooRunnable.data())->stop();
#endif
    balooRunnable = nullptr;

    auto state = std::make_shared<SearchState>();
    state->generation = gen;
    state->query = queryText;
    state->queryLower = queryText.toLower();
    state->options = Options{ filesOn, foldersOn, Settings::fileFuzzyEnabled(),
                              Settings::folderFuzzyEnabled(),
                              Settings::fullFilesystemSearchEnabled() };
    state->cancelFlag = std::make_shared<std::atomic_bool>(false);
    current = state;

    setSearching(true);

    auto recentEntries = recentSnapshot();
    const QString queryLower = state->queryLower;
    const Options options = state->options;
    QtConcurrent::run([recentEntries = std::move(recentEntries), queryLower, options] {
        return buildRecentResults(recentEntries, queryLower, options);
    }).then(this->q, [this, state](QVariantList recentResults) {
        if (state->generation != generation.loadAcquire())
            return;
        state->recentResults = recentResults;
        for (const QVariant& value : std::as_const(recentResults)) {
            const QString path = value.toMap().value(u"exec"_s).toString();
            if (!path.isEmpty())
                state->recentPaths.insert(path);
        }
        emit this->q->recentResultsReady(state->query, recentResults);
        // Empty query is the recents view: there is nothing more to ask the
        // index for, and Baloo would otherwise return the whole database.
        if (state->queryLower.isEmpty()) {
            finish(state);
            return;
        }
        startBackend(state);
    });
}

void FileSearch::Private::cancel() {
    generation.fetchAndAddOrdered(1);
    if (current) {
        current->cancelFlag->store(true, std::memory_order_relaxed);
        current.reset();
    }
#ifdef PEAKSHELL_HAVE_BALOO
    if (balooRunnable)
        static_cast<Baloo::QueryRunnable*>(balooRunnable.data())->stop();
#endif
    balooRunnable = nullptr;
    setSearching(false);
}

void FileSearch::Private::startBackend(const std::shared_ptr<SearchState>& state) {
    if (state->queryLower.isEmpty()) {
        finish(state);
        return;
    }
#ifdef PEAKSHELL_HAVE_BALOO
    if (balooAvailable()) {
        startBaloo(state);
        return;
    }
#endif
    startFallback(state);
}

void FileSearch::Private::startBaloo(const std::shared_ptr<SearchState>& state) {
#ifdef PEAKSHELL_HAVE_BALOO
    Baloo::Query query;
    query.setSearchString(state->query);
    query.setLimit(200);
    query.setSortingOption(Baloo::Query::SortAuto);

    auto* runnable = new Baloo::QueryRunnable(query);
    // QueryRunnable is a QRunnable: the thread pool would otherwise delete it
    // as soon as run() returns, racing the queued finished() handler. Keep it
    // alive and delete it on the main thread after the signal is delivered.
    runnable->setAutoDelete(false);
    balooRunnable = runnable;

    QObject::connect(runnable, &Baloo::QueryRunnable::queryResult, q,
                     [this, state](Baloo::QueryRunnable*, const QString& path) {
                         if (state->generation != generation.loadAcquire())
                             return;
                         if (state->balooSeen.contains(path))
                             return;
                         state->balooSeen.insert(path);
                         state->balooPaths.append(path);
                     });
    QObject::connect(runnable, &Baloo::QueryRunnable::finished, q,
                     [this, state] {
                         if (state->generation != generation.loadAcquire())
                             return;
                         if (state->balooPaths.isEmpty())
                             startFallback(state);
                         else
                             startBackendBuild(state, state->balooPaths);
                     });
    // Lifespan is independent of this FileSearch instance: if it is destroyed
    // while a query is running, the runnable still cleans itself up.
    QObject::connect(runnable, &Baloo::QueryRunnable::finished, runnable,
                     [runnable] { runnable->deleteLater(); });

    QThreadPool::globalInstance()->start(runnable);
#else
    Q_UNUSED(state)
#endif
}

void FileSearch::Private::startFallback(const std::shared_ptr<SearchState>& state) {
    int remaining = kMaxBackendResults
        - static_cast<int>(state->recentResults.size())
        - static_cast<int>(state->backendResults.size());
    // In full-filesystem mode the local scan augments the index even when
    // Baloo already filled the normal result budget. The merged list is
    // trimmed by score below, so the extra scan cannot crowd out exact names.
    if (state->options.fullFilesystem)
        remaining = kMaxBackendResults;
    if (remaining <= 0) {
        finish(state);
        return;
    }
    const QSet<QString> exclude = state->recentPaths;
    const QString queryLower = state->queryLower;
    const Options options = state->options;
    const auto cancelFlag = state->cancelFlag;
    QtConcurrent::run([exclude, queryLower, options, remaining, cancelFlag] {
        return scanFallback(queryLower, exclude, options, remaining, cancelFlag);
    }).then(q, [this, state](QVariantList backend) {
        if (state->generation != generation.loadAcquire())
            return;
        // Merge indexed and local matches, deduplicate by uid, then rank by
        // score. This keeps an exact hidden-config match above unrelated
        // Baloo hits when full-filesystem mode is on.
        QList<QVariant> combined = state->backendResults;
        QSet<QString> seen;
        for (const QVariant& row : std::as_const(combined)) {
            const QString uid = row.toMap().value(u"uid"_s).toString();
            if (!uid.isEmpty())
                seen.insert(uid);
        }
        for (const QVariant& row : std::as_const(backend)) {
            const QString uid = row.toMap().value(u"uid"_s).toString();
            if (!uid.isEmpty() && seen.contains(uid))
                continue;
            combined.append(row);
            if (!uid.isEmpty())
                seen.insert(uid);
        }
        std::stable_sort(combined.begin(), combined.end(), [](const QVariant& a, const QVariant& b) {
            return a.toMap().value(u"score"_s).toDouble()
                > b.toMap().value(u"score"_s).toDouble();
        });
        if (combined.size() > kMaxBackendResults)
            combined.resize(kMaxBackendResults);
        state->backendResults = combined;
        finish(state);
    });
}

void FileSearch::Private::startBackendBuild(const std::shared_ptr<SearchState>& state,
                                            const QStringList& paths) {
    const int remaining = kMaxBackendResults - static_cast<int>(state->recentResults.size());
    if (remaining <= 0) {
        finish(state);
        return;
    }
    const QSet<QString> exclude = state->recentPaths;
    const QString queryLower = state->queryLower;
    const Options options = state->options;
    QtConcurrent::run([paths, exclude, queryLower, options, remaining] {
        return buildBackendResults(paths, exclude, queryLower, options, remaining);
    }).then(q, [this, state](QVariantList backend) {
        if (state->generation != generation.loadAcquire())
            return;
        state->backendResults = backend;
        // Baloo returned documents, but none survived our name/path match
        // (or they were all filtered). The local scanners can still find
        // hidden config files and other unindexed paths. Full-filesystem
        // mode deliberately augments every indexed result set.
        if (backend.isEmpty() || state->options.fullFilesystem)
            startFallback(state);
        else
            finish(state);
    });
}

void FileSearch::Private::finish(const std::shared_ptr<SearchState>& state) {
    if (state->finished)
        return;
    state->finished = true;
    if (state->generation != generation.loadAcquire())
        return;

    QVariantList all = state->recentResults;
    all += state->backendResults;
    emit q->searchFinished(state->query, all);

    if (current == state)
        current.reset();
    setSearching(false);
}

void FileSearch::Private::setSearching(bool value) {
    if (searching == value)
        return;
    searching = value;
    emit q->searchingChanged();
}

void FileSearch::Private::reloadRecent() {
    QtConcurrent::run(loadRecentEntries).then(q, [this](QList<RecentEntry> entries) {
        QMutexLocker locker(&recentMutex);
        recent = std::move(entries);
        recentLoaded = true;
    });
}

QList<RecentEntry> FileSearch::Private::recentSnapshot() {
    QMutexLocker locker(&recentMutex);
    if (!recentLoaded) {
        // The launcher can be instantiated lazily and searched immediately;
        // make sure the very first query still sees the recent list. This is
        // a one-off parse of a small XML file, and the async load above
        // usually wins the race long before the user opens the launcher.
        locker.unlock();
        QList<RecentEntry> entries = loadRecentEntries();
        locker.relock();
        if (!recentLoaded) {
            recent = std::move(entries);
            recentLoaded = true;
        }
    }
    return recent;
}

FileSearch::FileSearch(QObject* parent)
    : QObject(parent)
    , d(std::make_unique<Private>()) {
    d->q = this;
    d->init();
}

FileSearch::~FileSearch() {
    if (!d)
        return;
    d->generation.fetchAndAddOrdered(1);
    if (d->current)
        d->current->cancelFlag->store(true, std::memory_order_relaxed);
#ifdef PEAKSHELL_HAVE_BALOO
    if (d->balooRunnable)
        static_cast<Baloo::QueryRunnable*>(d->balooRunnable.data())->stop();
#endif
}

bool FileSearch::searching() const {
    return d->searching;
}

void FileSearch::search(const QString& query) {
    d->search(query);
}

void FileSearch::searchScoped(const QString& query, const QString& scope) {
    d->searchScoped(query, scope);
}

void FileSearch::cancel() {
    d->cancel();
}

} // namespace peakshell::apps
