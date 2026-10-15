#pragma once

#include <qfilesystemwatcher.h>
#include <qlist.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qqmllist.h>
#include <qstring.h>

namespace peakshell::wallpapers {

class WallpaperEntry : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("WallpaperEntry instances are created by WallpaperScanner")

    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString path READ path CONSTANT)
    Q_PROPERTY(QString type READ type CONSTANT)

public:
    explicit WallpaperEntry(QString name, QString path, QString type, QObject* parent = nullptr);

    [[nodiscard]] QString name() const;
    [[nodiscard]] QString path() const;
    [[nodiscard]] QString type() const;

private:
    QString m_name;
    QString m_path;
    QString m_type;
};

class WallpaperScanner : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QQmlListProperty<peakshell::wallpapers::WallpaperEntry> images READ images NOTIFY imagesChanged)
    Q_PROPERTY(QQmlListProperty<peakshell::wallpapers::WallpaperEntry> videos READ videos NOTIFY videosChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)

public:
    explicit WallpaperScanner(QObject* parent = nullptr);

    [[nodiscard]] QQmlListProperty<WallpaperEntry> images();
    [[nodiscard]] QQmlListProperty<WallpaperEntry> videos();
    [[nodiscard]] bool loaded() const;

    Q_INVOKABLE void scan();
    Q_INVOKABLE void saveState(const QString& path, const QString& name, const QString& type,
                               const QString& tab, bool muted, qreal volume);
    Q_INVOKABLE void loadState();

signals:
    void imagesChanged();
    void videosChanged();
    void loadedChanged();
    void stateLoaded(const QVariantMap& state);

private:
    void onDirectoryChanged();
    void populate(QList<WallpaperEntry*>& dest, const QFileInfoList& files, const QString& type);

    QFileSystemWatcher* m_watcher;
    QList<WallpaperEntry*> m_images;
    QList<WallpaperEntry*> m_videos;
    bool m_loaded = false;

    static const QStringList k_imageExts;
    static const QStringList k_videoExts;
    static QString stateFilePath();
    static QString wallpaperDir();
};

} // namespace peakshell::wallpapers
