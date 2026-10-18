#include "clipboardmanager.hpp"
#include "fuzzy/fuzzysearch.h"
#include "../settings.hpp"

#include <algorithm>
#include <utility>
#include <qbuffer.h>
#include <qclipboard.h>
#include <qcryptographichash.h>
#include <qdatetime.h>
#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qguiapplication.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qloggingcategory.h>
#include <qmimedata.h>
#include <qmimedatabase.h>
#include <qsavefile.h>
#include <qstandardpaths.h>
#include <qstringlist.h>
#include <qurl.h>
#include <quuid.h>
#include <qbytearray.h>

#ifdef Q_OS_LINUX
#include <csignal>
#include <sys/prctl.h>
#endif

namespace peakshell::apps {

using Qt::StringLiterals::operator""_s;

Q_LOGGING_CATEGORY(lcClip, "peakshell.clipboard", QtInfoMsg)

namespace {

constexpr double kFuzzyThreshold = 57.0;
constexpr double kContainFloor = 72.0;
constexpr double kNameWeight = 0.7;
constexpr double kTextWeight = 0.3;
constexpr int kSummaryLength = 120;
constexpr int kSaveDebounceMs = 400;
constexpr int kPasteDelayMs = 220;

inline std::string lowerStd(const QString& s) {
    return s.toLower().toStdString();
}

inline QString textFingerprint(const QString& text) {
    return u"t:"_s + text;
}

inline QString imageFingerprint(const QByteArray& png) {
    return u"i:"_s
        + QString::fromLatin1(QCryptographicHash::hash(png, QCryptographicHash::Sha1).toHex());
}

// Encodes an image to PNG bytes (used both for hashing and for storage).
inline QByteArray encodePng(const QImage& image) {
    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    image.save(&buffer, "PNG");
    buffer.close();
    return png;
}

inline QString humanSize(qint64 bytes) {
    static const char* const units[] = { "B", "KB", "MB", "GB", "TB" };
    double value = static_cast<double>(bytes);
    int unit = 0;
    while (value >= 1024.0 && unit < 4) {
        value /= 1024.0;
        ++unit;
    }
    if (unit == 0)
        return QString::number(bytes) + u" B"_s;
    return QString::number(value, 'f', value < 10.0 ? 1 : 0) + u" "_s + QLatin1String(units[unit]);
}

// Parses a text/uri-list payload, keeping only local file URIs.
inline QStringList filePathsFromUriList(const QByteArray& data) {
    QStringList paths;
    const QList<QByteArray> lines = data.split('\n');
    for (QByteArray line : lines) {
        line = line.trimmed();
        if (line.isEmpty() || line.startsWith('#'))
            continue;
        const QUrl url(QString::fromUtf8(line));
        if (!url.isLocalFile())
            continue;
        const QString local = url.toLocalFile();
        if (!local.isEmpty())
            paths << local;
    }
    return paths;
}

inline QString fileDisplayName(const QStringList& paths) {
    if (paths.isEmpty())
        return u"Files"_s;
    if (paths.size() == 1) {
        const QFileInfo info(paths.first());
        const QString name = info.fileName();
        return name.isEmpty() ? paths.first() : name;
    }
    return QString::number(paths.size()) + u" items"_s;
}

inline QString fileSizeLabel(const QStringList& paths) {
    if (paths.isEmpty())
        return QString();
    if (paths.size() == 1) {
        const QFileInfo info(paths.first());
        return info.isDir() ? u"Folder"_s : humanSize(info.size());
    }
    qint64 total = 0;
    bool any = false;
    for (const QString& path : paths) {
        const QFileInfo info(path);
        if (info.isFile()) {
            total += info.size();
            any = true;
        }
    }
    return any ? humanSize(total) : QString::number(paths.size()) + u" items"_s;
}

inline QString fileIcon(const QStringList& paths) {
    if (paths.size() != 1)
        return u"folder-documents"_s;
    const QFileInfo info(paths.first());
    if (info.isDir())
        return u"folder"_s;
    const QMimeType type = QMimeDatabase().mimeTypeForFile(paths.first(), QMimeDatabase::MatchExtension);
    const QString icon = type.iconName();
    return icon.isEmpty() ? u"text-x-generic"_s : icon;
}

inline QString fileHaystack(const QStringList& paths) {
    QString out = u"file"_s;
    for (const QString& path : paths) {
        out += u' ';
        out += QFileInfo(path).fileName();
    }
    return out;
}

} // namespace

ClipboardManager::ClipboardManager(QObject* parent)
    : QObject(parent) {
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(kSaveDebounceMs);
    connect(&m_saveTimer, &QTimer::timeout, this, &ClipboardManager::save);

    load();

    if (QClipboard* clipboard = QGuiApplication::clipboard())
        connect(clipboard, &QClipboard::dataChanged, this, &ClipboardManager::onClipboardChanged);

    m_wtypePath = QStandardPaths::findExecutable(u"wtype"_s);
    refresh();
    startPoller();
}

void ClipboardManager::startPoller() {
    m_wlPastePath = QStandardPaths::findExecutable(u"wl-paste"_s);
    if (m_wlPastePath.isEmpty())
        return;
    m_wlPasteAvailable = true;
    m_poll = new QProcess(this);
    connect(m_poll, &QProcess::finished, this, &ClipboardManager::onPollFinished);
    m_pollTimer.setSingleShot(true);
    m_pollTimer.setInterval(1000);
    connect(&m_pollTimer, &QTimer::timeout, this, &ClipboardManager::pollTick);
    // Safety net: a wedged clipboard owner must not stall the poller forever.
    m_pollTimeout.setSingleShot(true);
    m_pollTimeout.setInterval(3000);
    connect(&m_pollTimeout, &QTimer::timeout, this, [this] {
        if (m_poll && m_poll->state() != QProcess::NotRunning) {
            qCWarning(lcClip) << "clipboard: timed out reading the selection; dropping this capture";
            m_poll->kill();
        }
        finishPoll();
    });
    startWatcher();
}

// Watches the selection instead of probing it once a second: wl-paste runs the
// helper on every change and the helper prints one line per event, so reading
// the payload (the expensive half) only happens when something really changed.
void ClipboardManager::startWatcher() {
    if (m_watch)
        return;
    m_watch = new QProcess(this);
    m_watch->setProgram(m_wlPastePath);
    // Consumes stdin, so a large payload is never written into a dead pipe.
    m_watch->setArguments({u"--watch"_s, u"wc"_s, u"-c"_s});
#ifdef Q_OS_LINUX
    // The watcher idles between changes, so it never notices a closed pipe and
    // would survive the shell being killed (Qt destructors do not run then).
    m_watch->setChildProcessModifier([] { ::prctl(PR_SET_PDEATHSIG, SIGKILL); });
#endif
    connect(m_watch, &QProcess::readyReadStandardOutput, this,
            &ClipboardManager::onClipboardEvent);
    connect(m_watch, &QProcess::finished, this, &ClipboardManager::onWatcherFinished);
    connect(m_watch, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            qCWarning(lcClip) << "clipboard: failed to start" << m_wlPastePath;
            usePollTimer();
        }
    });
    m_watchMode = true;
    m_watch->start();
    // --watch only reports changes, so grab whatever is already on the clipboard.
    if (m_pollState == PollState::Idle)
        pollTick();
}

void ClipboardManager::onClipboardEvent() {
    // Always drain: an unread process keeps signalling without pausing.
    if (m_watch)
        m_watch->readAllStandardOutput();
    m_watchFailures = 0;
    m_pendingEvent = true;
    if (m_pollState == PollState::Idle)
        pollTick();
}

void ClipboardManager::onWatcherFinished(int exitCode, QProcess::ExitStatus status) {
    Q_UNUSED(exitCode)
    Q_UNUSED(status)
    if (m_watch) {
        m_watch->deleteLater();
        m_watch = nullptr;
    }
    if (!m_watchMode)
        return;
    if (++m_watchFailures > 3) {
        qCWarning(lcClip) << "clipboard: wl-paste --watch keeps exiting; falling back to polling";
        usePollTimer();
        return;
    }
    QTimer::singleShot(1000, this, [this] {
        if (m_watchMode)
            startWatcher();
    });
}

// Fallback for wl-clipboard builds without a working --watch.
void ClipboardManager::usePollTimer() {
    m_watchMode = false;
    if (m_watch) {
        m_watch->deleteLater();
        m_watch = nullptr;
    }
    if (m_wlPasteAvailable && !m_pollTimer.isActive())
        m_pollTimer.start();
}

// Ends the current poll and either picks up a change that arrived mid-poll or
// goes back to waiting (the 1s timer in fallback mode).
void ClipboardManager::finishPoll() {
    m_pollState = PollState::Idle;
    if (m_pendingEvent) {
        m_pendingEvent = false;
        pollTick();
        return;
    }
    schedulePoll();
}

void ClipboardManager::schedulePoll() {
    // While watching, the next poll is triggered by a selection change instead.
    if (!m_wlPasteAvailable || m_watchMode)
        return;
    if (!m_pollTimer.isActive())
        m_pollTimer.start();
}

void ClipboardManager::pollTick() {
    if (!m_wlPasteAvailable || m_pollState != PollState::Idle)
        return;
    m_pendingEvent = false;
    m_pollState = PollState::Listing;
    m_pendingTextMime.clear();
    m_pendingImageMime.clear();
    m_pendingFileMime.clear();
    m_pollTimeout.start();
    m_poll->start(m_wlPastePath, QStringList{ u"--list-types"_s });
}

void ClipboardManager::onPollFinished(int exitCode, QProcess::ExitStatus status) {
    m_pollTimeout.stop();
    const QByteArray data = m_poll->readAllStandardOutput();
    if (status != QProcess::NormalExit || exitCode != 0) {
        finishPoll();
        return;
    }

    if (m_pollState == PollState::Listing) {
        const QList<QByteArray> types = data.split('\n');
        for (QByteArray type : types) {
            type = type.trimmed();
            if (type.isEmpty())
                continue;
            if (type == "text/uri-list" && m_pendingFileMime.isEmpty()) {
                m_pendingFileMime = QString::fromLatin1(type);
            } else if (type.startsWith("image/") && m_pendingImageMime.isEmpty()) {
                m_pendingImageMime = QString::fromLatin1(type);
            } else if (m_pendingTextMime.isEmpty()
                       && (type.startsWith("text/plain") || type == "UTF8_STRING"
                           || type == "STRING" || type == "TEXT")) {
                m_pendingTextMime = QString::fromLatin1(type);
            }
        }
        if (!m_pendingFileMime.isEmpty()) {
            m_readingFile = true;
            m_readingImage = false;
            m_pollState = PollState::Reading;
            m_pollTimeout.start();
            m_poll->start(m_wlPastePath, QStringList{ u"--type"_s, m_pendingFileMime });
            return;
        }
        if (!m_pendingTextMime.isEmpty()) {
            m_readingImage = false;
            m_pollState = PollState::Reading;
            m_pollTimeout.start();
            m_poll->start(m_wlPastePath, QStringList{ u"--no-newline"_s, u"--type"_s, m_pendingTextMime });
            return;
        }
        if (!m_pendingImageMime.isEmpty()) {
            m_readingImage = true;
            m_pollState = PollState::Reading;
            m_pollTimeout.start();
            m_poll->start(m_wlPastePath, QStringList{ u"--type"_s, m_pendingImageMime });
            return;
        }
        finishPoll();
        return;
    }

    if (m_readingFile) {
        m_readingFile = false;
        const QStringList paths = filePathsFromUriList(data);
        if (!paths.isEmpty()) {
            addFiles(paths);
            m_pendingTextMime.clear();
            m_pendingImageMime.clear();
            m_pendingFileMime.clear();
            finishPoll();
            return;
        }
        // The uri-list held only remote links; fall back to the text payload.
        if (!m_pendingTextMime.isEmpty()) {
            m_pollState = PollState::Reading;
            m_pollTimeout.start();
            m_poll->start(m_wlPastePath, QStringList{ u"--no-newline"_s, u"--type"_s, m_pendingTextMime });
            return;
        }
        m_pendingTextMime.clear();
        m_pendingImageMime.clear();
        m_pendingFileMime.clear();
        finishPoll();
        return;
    }

    if (m_readingImage) {
        // Decoding the payload and re-encoding it to PNG is expensive (tens to
        // hundreds of ms for a screenshot) and happened once per poll. wl-paste
        // hands back identical bytes while the clipboard is unchanged, so skip
        // the work unless the payload actually differs.
        if (data != m_lastImagePayload) {
            QImage image;
            if (image.loadFromData(data)) {
                m_lastImagePayload = data;
                addImage(image);
            }
        }
    } else {
        addText(QString::fromUtf8(data));
    }
    m_readingImage = false;
    m_pendingTextMime.clear();
    m_pendingImageMime.clear();
    m_pendingFileMime.clear();
    finishPoll();
}

int ClipboardManager::count() const {
    return static_cast<int>(m_entries.size());
}

QString ClipboardManager::cacheDir() const {
    QString base = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation);
    if (base.isEmpty())
        base = QDir::homePath() + u"/.cache"_s;
    return base + u"/peakshell/clipboard"_s;
}

QString ClipboardManager::indexFile() const {
    return cacheDir() + u"/index.json"_s;
}

QString ClipboardManager::summarize(const QString& text) {
    const QString flat = text.simplified();
    if (flat.length() <= kSummaryLength)
        return flat;
    return flat.left(kSummaryLength - 1) + u"\u2026"_s;
}

void ClipboardManager::onClipboardChanged() {
    QClipboard* clipboard = QGuiApplication::clipboard();
    if (!clipboard)
        return;
    const QMimeData* mime = clipboard->mimeData();
    if (!mime)
        return;
    if (mime->hasImage()) {
        const QImage image = clipboard->image();
        if (!image.isNull()) {
            addImage(image);
            return;
        }
    }
    if (mime->hasUrls()) {
        QStringList paths;
        const QList<QUrl> urls = mime->urls();
        for (const QUrl& url : urls)
            if (url.isLocalFile())
                paths << url.toLocalFile();
        if (!paths.isEmpty()) {
            addFiles(paths);
            return;
        }
    }
    if (mime->hasText())
        addText(mime->text());
}

void ClipboardManager::addText(const QString& text) {
    // The live clipboard is no longer the image we may have cached.
    m_lastImagePayload.clear();
    if (text.isEmpty())
        return;
    const QString fingerprint = textFingerprint(text);
    if (!m_clearGuard.isEmpty() && fingerprint == m_clearGuard) {
        m_clearGuard.clear();
        return;
    }
    m_clearGuard.clear();
    for (qsizetype i = 0; i < m_entries.size(); ++i) {
        if (m_entries[i].fingerprint == fingerprint) {
            if (i == 0)
                return;
            Entry existing = m_entries.takeAt(i);
            existing.timestamp = QDateTime::currentMSecsSinceEpoch();
            m_entries.prepend(existing);
            scheduleSave();
            emit historyChanged();
            return;
        }
    }
    Entry entry;
    entry.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    entry.fingerprint = fingerprint;
    entry.text = text;
    entry.mime = u"text/plain"_s;
    entry.timestamp = QDateTime::currentMSecsSinceEpoch();
    addEntry(std::move(entry));
}

void ClipboardManager::addImage(const QImage& image) {
    if (image.isNull())
        return;
    const QByteArray png = encodePng(image);
    if (png.isEmpty())
        return;
    const QString fingerprint = imageFingerprint(png);
    if (!m_clearGuard.isEmpty() && fingerprint == m_clearGuard) {
        m_clearGuard.clear();
        return;
    }
    m_clearGuard.clear();
    for (qsizetype i = 0; i < m_entries.size(); ++i) {
        if (m_entries[i].fingerprint == fingerprint) {
            if (i == 0)
                return;
            Entry existing = m_entries.takeAt(i);
            existing.timestamp = QDateTime::currentMSecsSinceEpoch();
            m_entries.prepend(existing);
            scheduleSave();
            emit historyChanged();
            return;
        }
    }

    QDir().mkpath(cacheDir());
    Entry entry;
    entry.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    entry.fingerprint = fingerprint;
    entry.imagePath = cacheDir() + u"/"_s + entry.id + u".png"_s;
    entry.mime = u"image/png"_s;
    entry.timestamp = QDateTime::currentMSecsSinceEpoch();
    entry.isImage = true;

    QSaveFile file(entry.imagePath);
    if (!file.open(QIODevice::WriteOnly) || file.write(png) != png.size() || !file.commit()) {
        qCWarning(lcClip) << "clipboard: failed to write image" << entry.imagePath;
        return;
    }
    addEntry(std::move(entry));
}

void ClipboardManager::addFiles(const QStringList& paths) {
    // The live clipboard is no longer the image we may have cached.
    m_lastImagePayload.clear();
    if (paths.isEmpty())
        return;
    const QString fingerprint = u"f:"_s + paths.join(u'\n');
    if (!m_clearGuard.isEmpty() && fingerprint == m_clearGuard) {
        m_clearGuard.clear();
        return;
    }
    m_clearGuard.clear();
    for (qsizetype i = 0; i < m_entries.size(); ++i) {
        if (m_entries[i].fingerprint == fingerprint) {
            if (i == 0)
                return;
            Entry existing = m_entries.takeAt(i);
            existing.timestamp = QDateTime::currentMSecsSinceEpoch();
            m_entries.prepend(existing);
            scheduleSave();
            emit historyChanged();
            return;
        }
    }
    Entry entry;
    entry.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    entry.fingerprint = fingerprint;
    entry.paths = paths;
    entry.mime = u"text/uri-list"_s;
    entry.timestamp = QDateTime::currentMSecsSinceEpoch();
    entry.isFile = true;
    addEntry(std::move(entry));
}

void ClipboardManager::addEntry(Entry entry) {
    m_entries.prepend(std::move(entry));
    enforceLimit();
    scheduleSave();
    emit historyChanged();
}

void ClipboardManager::enforceLimit() {
    const int maxItems = qMax(1, peakshell::Settings::clipboardMaxItemCount());
    while (m_entries.size() > maxItems) {
        const Entry removed = m_entries.takeLast();
        if (removed.isImage && !removed.imagePath.isEmpty())
            QFile::remove(removed.imagePath);
    }
}

void ClipboardManager::scheduleSave() {
    m_saveTimer.start();
}

void ClipboardManager::save() {
    if (!m_loaded)
        return;
    QDir().mkpath(cacheDir());
    QJsonArray array;
    for (const Entry& entry : std::as_const(m_entries)) {
        QJsonObject obj;
        obj.insert(u"id"_s, entry.id);
        obj.insert(u"fingerprint"_s, entry.fingerprint);
        obj.insert(u"text"_s, entry.text);
        obj.insert(u"imagePath"_s, entry.imagePath);
        obj.insert(u"mime"_s, entry.mime);
        obj.insert(u"timestamp"_s, entry.timestamp);
        obj.insert(u"isImage"_s, entry.isImage);
        obj.insert(u"isFile"_s, entry.isFile);
        QJsonArray paths;
        for (const QString& path : entry.paths)
            paths.append(path);
        obj.insert(u"paths"_s, paths);
        array.append(obj);
    }
    QSaveFile file(indexFile());
    if (!file.open(QIODevice::WriteOnly)) {
        qCWarning(lcClip) << "clipboard: cannot open history file" << indexFile();
        return;
    }
    file.write(QJsonDocument(array).toJson(QJsonDocument::Compact));
    file.commit();
}

void ClipboardManager::load() {
    QFile file(indexFile());
    if (!file.exists()) {
        m_loaded = true;
        return;
    }
    if (!file.open(QIODevice::ReadOnly)) {
        m_loaded = true;
        return;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    if (!doc.isArray()) {
        m_loaded = true;
        return;
    }
    const QJsonArray array = doc.array();
    for (const QJsonValue value : array) {
        const QJsonObject obj = value.toObject();
        Entry entry;
        entry.id = obj.value(u"id"_s).toString();
        entry.fingerprint = obj.value(u"fingerprint"_s).toString();
        entry.text = obj.value(u"text"_s).toString();
        entry.imagePath = obj.value(u"imagePath"_s).toString();
        entry.mime = obj.value(u"mime"_s).toString();
        entry.timestamp = static_cast<qint64>(obj.value(u"timestamp"_s).toDouble());
        entry.isImage = obj.value(u"isImage"_s).toBool();
        entry.isFile = obj.value(u"isFile"_s).toBool();
        const QJsonArray paths = obj.value(u"paths"_s).toArray();
        for (const QJsonValue& path : paths)
            entry.paths.append(path.toString());
        if (entry.id.isEmpty())
            continue;
        if (entry.isImage && !QFile::exists(entry.imagePath))
            continue;
        if (entry.isFile && entry.paths.isEmpty())
            continue;
        if (!entry.isImage && !entry.isFile && entry.text.isEmpty())
            continue;
        if (entry.fingerprint.isEmpty()) {
            if (entry.isImage)
                entry.fingerprint = u"i:"_s + entry.id;
            else if (entry.isFile)
                entry.fingerprint = u"f:"_s + entry.paths.join(u'\n');
            else
                entry.fingerprint = u"t:"_s + entry.text;
        }
        m_entries.append(entry);
    }
    m_loaded = true;
    enforceLimit();
    trimExcessFiles();
}

void ClipboardManager::trimExcessFiles() {
    QDir dir(cacheDir());
    if (!dir.exists())
        return;
    QStringList kept;
    for (const Entry& entry : std::as_const(m_entries))
        if (!entry.imagePath.isEmpty())
            kept << QFileInfo(entry.imagePath).fileName();
    const QStringList files = dir.entryList(QStringList{ u"*.png"_s }, QDir::Files);
    for (const QString& name : files)
        if (!kept.contains(name))
            QFile::remove(dir.filePath(name));
}

QVariantMap ClipboardManager::toMap(const Entry& entry, double score) const {
    QVariantMap map;
    map.insert(u"id"_s, entry.id);
    map.insert(u"uid"_s, entry.id);
    map.insert(u"score"_s, score);
    map.insert(u"mime"_s, entry.mime);
    map.insert(u"text"_s, entry.text);
    map.insert(u"timestamp"_s, static_cast<qlonglong>(entry.timestamp));
    if (entry.isImage)
        map.insert(u"kind"_s, u"image"_s);
    else if (entry.isFile)
        map.insert(u"kind"_s, u"file"_s);
    else
        map.insert(u"kind"_s, u"text"_s);
    map.insert(u"time"_s, QDateTime::fromMSecsSinceEpoch(entry.timestamp).toString(u"yyyy-MM-dd HH:mm"_s));
    if (entry.isImage) {
        map.insert(u"name"_s, u"Image"_s);
        map.insert(u"comment"_s, entry.mime);
        map.insert(u"detail"_s, u"image/png"_s);
        map.insert(u"icon"_s, u"image-x-generic"_s);
        map.insert(u"imageSource"_s, QUrl::fromLocalFile(entry.imagePath).toString());
    } else if (entry.isFile) {
        QVariantList paths;
        paths.reserve(entry.paths.size());
        for (const QString& path : entry.paths)
            paths.append(path);
        const QString size = fileSizeLabel(entry.paths);
        map.insert(u"name"_s, fileDisplayName(entry.paths));
        map.insert(u"comment"_s, size);
        map.insert(u"detail"_s, size);
        map.insert(u"icon"_s, fileIcon(entry.paths));
        map.insert(u"imageSource"_s, QString());
        map.insert(u"paths"_s, paths);
        map.insert(u"text"_s, entry.paths.join(u'\n'));
    } else {
        map.insert(u"name"_s, summarize(entry.text));
        map.insert(u"comment"_s, QString::number(entry.text.length()) + u" chars"_s);
        map.insert(u"detail"_s, QString::number(entry.text.length()) + u" chars"_s);
        map.insert(u"icon"_s, u"text-x-generic"_s);
        map.insert(u"imageSource"_s, QString());
    }
    return map;
}

QVariantList ClipboardManager::search(const QString& query) const {
    const QString q = query.trimmed();
    const bool fuzzyOn = peakshell::Settings::clipboardFuzzyEnabled();

    QVariantList out;
    if (q.isEmpty()) {
        out.reserve(m_entries.size());
        for (const Entry& entry : m_entries)
            out.append(toMap(entry, 0.0));
        return out;
    }

    const std::string qStd = lowerStd(q);

    struct Scored {
        QVariantMap map;
        double key = 0.0;
    };
    QVector<Scored> acc;
    acc.reserve(m_entries.size());

    for (const Entry& entry : std::as_const(m_entries)) {
        const QString haystack = entry.isImage ? u"image png"_s
            : entry.isFile                    ? fileHaystack(entry.paths)
                                              : entry.text;
        const QString label = entry.isImage ? u"Image"_s
            : entry.isFile                  ? fileDisplayName(entry.paths)
                                            : summarize(entry.text);
        double score = FuzzySearch::getPartialMatch(qStd, lowerStd(label)) * kNameWeight;
        if (!entry.isImage)
            score += FuzzySearch::getMatch(qStd, lowerStd(haystack)) * kTextWeight;
        bool evidence = label.contains(q, Qt::CaseInsensitive)
            || (!entry.isImage && haystack.contains(q, Qt::CaseInsensitive));
        if (evidence)
            score = qMax(score, kContainFloor);
        if (score <= kFuzzyThreshold)
            continue;
        if (!fuzzyOn && !evidence)
            continue;
        double key = score;
        if (label.startsWith(q, Qt::CaseInsensitive))
            key += 300.0;
        else if (label.contains(q, Qt::CaseInsensitive))
            key += 150.0;
        acc.append(Scored{ toMap(entry, score), key });
    }

    std::stable_sort(acc.begin(), acc.end(),
                     [](const Scored& a, const Scored& b) { return a.key > b.key; });
    out.reserve(acc.size());
    for (const Scored& scored : std::as_const(acc))
        out.append(scored.map);
    return out;
}

void ClipboardManager::copy(const QString& id) {
    const auto it = std::find_if(m_entries.cbegin(), m_entries.cend(),
                                 [&id](const Entry& entry) { return entry.id == id; });
    if (it == m_entries.cend())
        return;
    QClipboard* clipboard = QGuiApplication::clipboard();
    if (!clipboard)
        return;
    if (it->isImage) {
        const QImage image(it->imagePath);
        if (!image.isNull())
            clipboard->setImage(image);
    } else if (it->isFile) {
        QList<QUrl> urls;
        QStringList plain;
        urls.reserve(it->paths.size());
        plain.reserve(it->paths.size());
        for (const QString& path : it->paths) {
            urls.append(QUrl::fromLocalFile(path));
            plain.append(path);
        }
        QMimeData* mime = new QMimeData();
        mime->setUrls(urls);
        mime->setText(plain.join(u'\n'));
        // Some file managers only honour the GNOME clipboard hint.
        QByteArray gnome = QByteArrayLiteral("copy");
        for (const QUrl& url : std::as_const(urls)) {
            gnome += '\n';
            gnome += url.toString().toUtf8();
        }
        mime->setData(QStringLiteral("x-special/gnome-copied-files"), gnome);
        clipboard->setMimeData(mime);
    } else {
        clipboard->setText(it->text);
    }
}

void ClipboardManager::copyAndPaste(const QString& id) {
    copy(id);
    if (m_wtypePath.isEmpty())
        return;
    // The panel closes synchronously; wait for the compositor to hand keyboard
    // focus back to the previous window before injecting the paste shortcut.
    const QString tool = m_wtypePath;
    QTimer::singleShot(kPasteDelayMs, this, [tool] {
        QProcess::startDetached(tool,
                                QStringList{ u"-M"_s, u"ctrl"_s, u"-k"_s, u"v"_s, u"-m"_s, u"ctrl"_s });
    });
}

void ClipboardManager::clearLiveClipboard(const QString& fingerprint) {
    // Guard against a poll that already read the old payload before we wiped
    // the clipboard: the next matching capture is dropped and the guard reset.
    m_clearGuard = fingerprint;
    // A recopied image must be re-evaluated even if its bytes match the cache.
    m_lastImagePayload.clear();
    if (QClipboard* clipboard = QGuiApplication::clipboard())
        clipboard->clear();
}

void ClipboardManager::remove(const QString& id) {
    for (qsizetype i = 0; i < m_entries.size(); ++i) {
        if (m_entries[i].id == id) {
            const Entry removed = m_entries.takeAt(i);
            if (removed.isImage && !removed.imagePath.isEmpty())
                QFile::remove(removed.imagePath);
            // The newest entry mirrors the live clipboard; deleting it must
            // clear the clipboard too, otherwise the poller recaptures it and
            // the item immediately reappears.
            if (i == 0)
                clearLiveClipboard(removed.fingerprint);
            scheduleSave();
            emit historyChanged();
            return;
        }
    }
}

void ClipboardManager::clear() {
    if (m_entries.isEmpty())
        return;
    clearLiveClipboard(m_entries.first().fingerprint);
    m_entries.clear();
    trimExcessFiles();
    scheduleSave();
    emit historyChanged();
}

void ClipboardManager::refresh() {
    onClipboardChanged();
}

void ClipboardManager::ingestText(const QString& text) {
    addText(text);
}

} // namespace peakshell::apps
