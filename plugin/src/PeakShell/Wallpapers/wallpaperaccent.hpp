#pragma once

#include <qcolor.h>
#include <qhash.h>
#include <qimage.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qvariantlist.h>

namespace peakshell::wallpapers {

class WallpaperAccent : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString color READ color NOTIFY colorChanged)

public:
    explicit WallpaperAccent(QObject* parent = nullptr);

    [[nodiscard]] QString color() const;

    Q_INVOKABLE void update(const QString& path, const QString& type, const QVariantList& swatches,
                            bool cycle, int step, qreal frameTime);

signals:
    void colorChanged();

private:
    void applyResult(const QString& color);

    static QString compute(const QString& path, const QString& type, const QVariantList& swatches,
                           bool cycle, int step, qreal frameTime);
    static QColor accentFromImageFile(const QString& path);
    static QColor accentFromImage(const QImage& image);
    static QColor accentFromSwatches(const QVariantList& swatches);
    static QColor accentFromGradient(const QVariantList& swatches, int step);
    static QColor accentFromVideo(const QString& path, qreal position);
    static QColor normalizeAccent(const QColor& color);
    static QString localPath(const QString& path);

    QString m_color;
    quint64 m_generation = 0;
    QHash<QString, QString> m_cache;
};

} // namespace peakshell::wallpapers
