#include "wallpaperaccent.hpp"

#include <qfuturewatcher.h>
#include <qimagereader.h>
#include <qmutex.h>
#include <qprocess.h>
#include <qstandardpaths.h>
#include <qstringlist.h>
#include <qtconcurrentrun.h>
#include <qurl.h>

#include <algorithm>
#include <array>
#include <cmath>

namespace peakshell::wallpapers {

using Qt::StringLiterals::operator""_s;

namespace {

constexpr int kSampleSize = 96;
constexpr int kHueBins = 36;

QString swatchKey(const QVariantList& swatches) {
    QStringList values;
    values.reserve(swatches.size());
    for (const QVariant& swatch : swatches)
        values << swatch.toString();
    return values.join(u","_s);
}

qreal probeVideoDuration(const QString& path) {
    const QString ffprobe = QStandardPaths::findExecutable(u"ffprobe"_s);
    if (ffprobe.isEmpty() || path.isEmpty())
        return -1.0;

    QProcess process;
    process.start(ffprobe, {
        u"-v"_s, u"error"_s,
        u"-show_entries"_s, u"format=duration"_s,
        u"-of"_s, u"default=noprint_wrappers=1:nokey=1"_s,
        path,
    });

    if (!process.waitForFinished(3000)) {
        process.kill();
        process.waitForFinished();
        return -1.0;
    }

    bool ok = false;
    const qreal duration = process.readAllStandardOutput().trimmed().toDouble(&ok);
    return ok ? duration : -1.0;
}

qreal videoDuration(const QString& path) {
    static QMutex mutex;
    static QHash<QString, qreal> durations;

    {
        const QMutexLocker locker(&mutex);
        if (durations.contains(path))
            return durations.value(path);
    }

    const qreal duration = probeVideoDuration(path);
    {
        const QMutexLocker locker(&mutex);
        durations.insert(path, duration);
    }
    return duration;
}

} // namespace

WallpaperAccent::WallpaperAccent(QObject* parent)
    : QObject(parent) {}

QString WallpaperAccent::color() const {
    return m_color;
}

void WallpaperAccent::update(const QString& path, const QString& type, const QVariantList& swatches,
                             bool cycle, int step, qreal frameTime) {
    const quint64 generation = ++m_generation;
    const QString key = path + u"\n"_s + type + u"\n"_s + swatchKey(swatches)
                      + u"\n"_s + (cycle ? u"1"_s : u"0"_s)
                      + u"\n"_s + QString::number(step)
                      + u"\n"_s + QString::number(frameTime, 'f', 3);

    if (m_cache.contains(key)) {
        applyResult(m_cache.value(key));
        return;
    }

    auto* watcher = new QFutureWatcher<QString>(this);
    QObject::connect(watcher, &QFutureWatcher<QString>::finished, this,
                     [this, watcher, generation, key] {
                         const QString result = watcher->result();
                         watcher->deleteLater();

                         if (!result.isEmpty()) {
                             if (m_cache.size() >= 64)
                                 m_cache.clear();
                             m_cache.insert(key, result);
                         }

                         if (generation != m_generation || result.isEmpty())
                             return;

                         applyResult(result);
                     });

    watcher->setFuture(QtConcurrent::run([path, type, swatches, cycle, step, frameTime] {
        return compute(path, type, swatches, cycle, step, frameTime);
    }));
}

void WallpaperAccent::applyResult(const QString& color) {
    if (color.isEmpty() || m_color == color)
        return;
    m_color = color;
    emit colorChanged();
}

QString WallpaperAccent::compute(const QString& path, const QString& type, const QVariantList& swatches,
                                 bool cycle, int step, qreal frameTime) {
    QColor accent;

    if (type == u"gradient"_s) {
        accent = cycle ? accentFromGradient(swatches, step) : accentFromSwatches(swatches);
    } else if (type == u"video"_s) {
        accent = accentFromVideo(localPath(path), cycle ? frameTime : 0.0);
    } else if (type == u"image"_s) {
        accent = accentFromImageFile(localPath(path));
    } else if (type == u"color"_s || type == u"pattern"_s) {
        accent = accentFromSwatches(swatches);
    }

    if (!accent.isValid() && !swatches.isEmpty())
        accent = accentFromSwatches(swatches);

    if (!accent.isValid() && !path.isEmpty() && type != u"video"_s)
        accent = accentFromImageFile(localPath(path));

    return accent.isValid() ? accent.name(QColor::HexRgb) : QString();
}

QColor WallpaperAccent::accentFromImageFile(const QString& path) {
    if (path.isEmpty())
        return {};

    QImageReader reader(path);
    reader.setAutoTransform(true);

    const QSize size = reader.size();
    if (size.isValid() && (size.width() > kSampleSize || size.height() > kSampleSize))
        reader.setScaledSize(size.scaled(kSampleSize, kSampleSize, Qt::KeepAspectRatio));

    return accentFromImage(reader.read());
}

QColor WallpaperAccent::accentFromImage(const QImage& image) {
    if (image.isNull())
        return {};

    QImage sample = image;
    if (sample.width() > kSampleSize || sample.height() > kSampleSize)
        sample = sample.scaled(kSampleSize, kSampleSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    if (sample.format() != QImage::Format_ARGB32)
        sample = sample.convertToFormat(QImage::Format_ARGB32);

    std::array<float, kHueBins> weights{};
    std::array<float, kHueBins> reds{};
    std::array<float, kHueBins> greens{};
    std::array<float, kHueBins> blues{};
    float totalWeight = 0.0F;

    for (int y = 0; y < sample.height(); ++y) {
        const auto* line = reinterpret_cast<const QRgb*>(sample.constScanLine(y));
        for (int x = 0; x < sample.width(); ++x) {
            const QRgb pixel = line[x];
            if (qAlpha(pixel) < 96)
                continue;

            const QColor color = QColor::fromRgb(pixel);
            const float saturation = color.hsvSaturationF();
            const float value = color.valueF();
            const float hue = color.hsvHueF();
            if (saturation < 0.18F || value < 0.08F || hue < 0.0F)
                continue;

            const int bin = std::min(kHueBins - 1, static_cast<int>(hue * kHueBins));
            const auto index = static_cast<std::size_t>(bin);
            const float weight = saturation * saturation * (0.35F + value);
            weights[index] += weight;
            reds[index] += color.redF() * weight;
            greens[index] += color.greenF() * weight;
            blues[index] += color.blueF() * weight;
            totalWeight += weight;
        }
    }

    if (totalWeight <= 0.0F)
        return {};

    int bestBin = 0;
    float bestScore = -1.0F;
    for (int i = 0; i < kHueBins; ++i) {
        const auto current = static_cast<std::size_t>(i);
        const auto prev1 = static_cast<std::size_t>((i + kHueBins - 1) % kHueBins);
        const auto next1 = static_cast<std::size_t>((i + 1) % kHueBins);
        const auto prev2 = static_cast<std::size_t>((i + kHueBins - 2) % kHueBins);
        const auto next2 = static_cast<std::size_t>((i + 2) % kHueBins);
        const float score = weights[current] + 0.5F * (weights[prev1] + weights[next1])
                          + 0.25F * (weights[prev2] + weights[next2]);
        if (score > bestScore) {
            bestScore = score;
            bestBin = i;
        }
    }

    const auto bestIndex = static_cast<std::size_t>(bestBin);
    if (weights[bestIndex] <= 0.0F)
        return {};

    const QColor color = QColor::fromRgbF(reds[bestIndex] / weights[bestIndex],
                                          greens[bestIndex] / weights[bestIndex],
                                          blues[bestIndex] / weights[bestIndex]);
    return normalizeAccent(color);
}

QColor WallpaperAccent::accentFromSwatches(const QVariantList& swatches) {
    QColor best;
    float bestScore = -1.0F;

    for (const QVariant& swatch : swatches) {
        const QColor color = QColor::fromString(swatch.toString());
        if (!color.isValid())
            continue;

        const float saturation = color.hsvSaturationF();
        if (saturation < 0.12F)
            continue;

        const float score = saturation * (0.25F + color.valueF());
        if (score > bestScore) {
            bestScore = score;
            best = color;
        }
    }

    return best.isValid() ? normalizeAccent(best) : QColor();
}

QColor WallpaperAccent::accentFromGradient(const QVariantList& swatches, int step) {
    QList<QColor> colors;
    colors.reserve(swatches.size());
    for (const QVariant& swatch : swatches) {
        const QColor color = normalizeAccent(QColor::fromString(swatch.toString()));
        if (color.isValid() && !colors.contains(color))
            colors.append(color);
    }

    if (colors.isEmpty())
        return {};

    const qsizetype index = static_cast<qsizetype>(step) % colors.size();
    return colors.at(index < 0 ? index + colors.size() : index);
}

QColor WallpaperAccent::accentFromVideo(const QString& path, qreal position) {
    const QString ffmpeg = QStandardPaths::findExecutable(u"ffmpeg"_s);
    if (ffmpeg.isEmpty() || path.isEmpty())
        return {};

    const qreal duration = videoDuration(path);
    qreal seek = position;
    if (duration > 0.0)
        seek = std::fmod(position, duration);
    if (seek < 0.0)
        seek = 0.0;

    const auto grabFrame = [&](qreal at) {
        QProcess process;
        process.start(ffmpeg, {
            u"-v"_s, u"error"_s,
            u"-nostdin"_s,
            u"-ss"_s, QString::number(at, 'f', 3),
            u"-i"_s, path,
            u"-frames:v"_s, u"1"_s,
            u"-vf"_s, u"scale=96:-1"_s,
            u"-f"_s, u"image2pipe"_s,
            u"-vcodec"_s, u"png"_s,
            u"-"_s,
        });

        if (!process.waitForFinished(5000)) {
            process.kill();
            process.waitForFinished();
            return QImage();
        }

        if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0)
            return QImage();

        return QImage::fromData(process.readAllStandardOutput(), "PNG");
    };

    QImage image = grabFrame(seek);
    if (image.isNull() && seek > 0.0)
        image = grabFrame(0.0);
    return accentFromImage(image);
}

QColor WallpaperAccent::normalizeAccent(const QColor& color) {
    if (!color.isValid())
        return {};

    const float hue = color.hsvHueF();
    if (hue < 0.0F)
        return {};

    const float saturation = std::clamp(color.hsvSaturationF(), 0.65F, 0.95F);
    const float value = std::clamp(color.valueF(), 0.60F, 0.86F);
    return QColor::fromHsvF(hue, saturation, value, 1.0F);
}

QString WallpaperAccent::localPath(const QString& path) {
    const QUrl url(path);
    return url.isLocalFile() ? url.toLocalFile() : path;
}

} // namespace peakshell::wallpapers
