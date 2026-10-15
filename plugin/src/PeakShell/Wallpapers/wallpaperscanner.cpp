#include "wallpaperscanner.hpp"

#include <qdir.h>
#include <qdiriterator.h>
#include <qfileinfo.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qloggingcategory.h>
#include <qurl.h>

namespace peakshell::wallpapers {

using Qt::StringLiterals::operator""_s;

Q_LOGGING_CATEGORY(lcWall, "peakshell.wallpapers", QtInfoMsg)

const QStringList WallpaperScanner::k_imageExts = {
    u"png"_s, u"jpg"_s, u"jpeg"_s, u"webp"_s, u"bmp"_s
};
const QStringList WallpaperScanner::k_videoExts = {
    u"mp4"_s, u"mkv"_s, u"webm"_s, u"mov"_s, u"m4v"_s, u"avi"_s
};

QString WallpaperScanner::wallpaperDir() {
    const QString dir = QDir::homePath() + u"/Pictures/Wallpapers"_s;
    QDir().mkpath(dir);
    return dir;
}

QString WallpaperScanner::stateFilePath() {
    const QString qsPath = QDir::homePath() + u"/.cache/quickshell/wallpaper_state.json"_s;
    if (QFile::exists(qsPath)) {
        return qsPath;
    }
    const QString psPath = QDir::homePath() + u"/.cache/peakshell/wallpaper_state.json"_s;
    if (QFile::exists(psPath)) {
        return psPath;
    }
    return qsPath;
}

// --- WallpaperEntry ----------------------------------------------------------

WallpaperEntry::WallpaperEntry(QString name, QString path, QString type, QObject* parent)
    : QObject(parent)
    , m_name(std::move(name))
    , m_path(std::move(path))
    , m_type(std::move(type)) {}

QString WallpaperEntry::name() const { return m_name; }
QString WallpaperEntry::path() const { return m_path; }
QString WallpaperEntry::type() const { return m_type; }

// --- WallpaperScanner --------------------------------------------------------

WallpaperScanner::WallpaperScanner(QObject* parent)
    : QObject(parent)
    , m_watcher(new QFileSystemWatcher(this)) {
    QObject::connect(m_watcher, &QFileSystemWatcher::directoryChanged,
                     this, &WallpaperScanner::onDirectoryChanged);
    QObject::connect(m_watcher, &QFileSystemWatcher::fileChanged,
                     this, [this](const QString&) { onDirectoryChanged(); });

    scan();
}

QQmlListProperty<WallpaperEntry> WallpaperScanner::images() {
    return { this, &m_images };
}

QQmlListProperty<WallpaperEntry> WallpaperScanner::videos() {
    return { this, &m_videos };
}

bool WallpaperScanner::loaded() const {
    return m_loaded;
}

void WallpaperScanner::scan() {
    const QString dir = wallpaperDir();

    if (!m_watcher->directories().contains(dir)) {
        m_watcher->addPath(dir);
    }

    qDeleteAll(m_images);
    m_images.clear();
    qDeleteAll(m_videos);
    m_videos.clear();

    QFileInfoList imageFiles, videoFiles;
    QDirIterator it(dir, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        const QString ext = it.fileInfo().suffix().toLower();
        if (k_imageExts.contains(ext))
            imageFiles << it.fileInfo();
        else if (k_videoExts.contains(ext))
            videoFiles << it.fileInfo();
    }

    auto byName = [](const QFileInfo& a, const QFileInfo& b) {
        return a.fileName() < b.fileName();
    };
    std::ranges::sort(imageFiles, byName);
    std::ranges::sort(videoFiles, byName);

    populate(m_images, imageFiles, u"image"_s);
    populate(m_videos, videoFiles, u"video"_s);

    if (!m_loaded) {
        m_loaded = true;
        emit loadedChanged();
    }
    emit imagesChanged();
    emit videosChanged();
}

void WallpaperScanner::populate(QList<WallpaperEntry*>& dest,
                                const QFileInfoList& files,
                                const QString& type) {
    dest.reserve(files.size());
    for (const QFileInfo& fi : files) {
        dest << new WallpaperEntry(
            fi.completeBaseName(),
            QUrl::fromLocalFile(fi.absoluteFilePath()).toString(),
            type,
            this
        );
    }
}

void WallpaperScanner::onDirectoryChanged() {
    scan();
}

void WallpaperScanner::saveState(const QString& path, const QString& name, const QString& type,
                                 const QString& tab, bool muted, qreal volume) {
    QJsonObject obj;
    obj[u"path"_s]   = path;
    obj[u"name"_s]   = name;
    obj[u"type"_s]   = type;
    obj[u"tab"_s]    = tab;
    obj[u"muted"_s]  = muted;
    obj[u"volume"_s] = volume;

    const QByteArray json = QJsonDocument(obj).toJson(QJsonDocument::Compact);

    const QStringList targets = {
        QDir::homePath() + u"/.cache/quickshell/wallpaper_state.json"_s,
        QDir::homePath() + u"/.cache/peakshell/wallpaper_state.json"_s
    };

    for (const QString& target : targets) {
        QDir().mkpath(QFileInfo(target).absolutePath());
        QFile f(target);
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            f.write(json);
        }
    }
}

void WallpaperScanner::loadState() {
    QFile f(stateFilePath());
    if (!f.open(QIODevice::ReadOnly)) {
        emit stateLoaded({});
        return;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();

    if (!doc.isObject()) {
        emit stateLoaded({});
        return;
    }

    emit stateLoaded(doc.object().toVariantMap());
}

} // namespace peakshell::wallpapers
