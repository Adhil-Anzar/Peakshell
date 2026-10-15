#include "systemmonitor.hpp"

#include <qdir.h>
#include <qfile.h>
#include <qregularexpression.h>

namespace peakshell::services {

using Qt::StringLiterals::operator""_s;

SystemMonitor::SystemMonitor(QObject* parent)
    : TickingService(parent) {}

int SystemMonitor::cpuLoad() const { return m_cpuLoad; }
int SystemMonitor::cpuTemp() const { return m_cpuTemp; }
int SystemMonitor::gpuTemp() const { return m_gpuTemp; }

void SystemMonitor::tick() {
    refreshCpuLoad();
    refreshCpuTemp();
    refreshGpuTemp();
}

void SystemMonitor::refreshCpuLoad() {
    QFile f(u"/proc/stat"_s);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    const QByteArray data = f.readLine();
    f.close();

    // Format: cpu  user nice system idle iowait irq softirq steal
    const QList<QByteArray> parts = data.simplified().split(' ');
    if (parts.size() < 9 || parts[0] != "cpu")
        return;

    quint64 total = 0;
    quint64 idle  = 0;
    for (int i = 1; i <= 8; ++i) {
        const quint64 v = parts[i].toULongLong();
        total += v;
        if (i == 4 || i == 5) // idle + iowait
            idle += v;
    }

    const quint64 dt = total > m_lastTotal ? total - m_lastTotal : 0;
    const quint64 di = idle  > m_lastIdle  ? idle  - m_lastIdle  : 0;
    m_lastTotal = total;
    m_lastIdle  = idle;

    const int newLoad = static_cast<int>(dt > 0 ? (dt - di) * 100 / dt : 0);
    if (newLoad != m_cpuLoad) {
        m_cpuLoad = newLoad;
        emit cpuLoadChanged();
    }
}

void SystemMonitor::refreshCpuTemp() {
    // Prefer dedicated CPU hwmon chips.
    int t = readHwmonTemp({ u"coretemp"_s, u"k10temp"_s, u"zenpower"_s, u"legion_hwmon"_s });

    if (t == 0) {
        // Fallback: highest thermal zone temperature.
        const QDir tzDir(u"/sys/class/thermal"_s);
        const QStringList zones = tzDir.entryList({ u"thermal_zone*"_s }, QDir::Dirs);
        for (const QString& zone : zones) {
            QFile f(tzDir.filePath(zone + u"/temp"_s));
            if (!f.open(QIODevice::ReadOnly))
                continue;
            const int deg = f.readAll().trimmed().toInt() / 1000;
            f.close();
            if (deg > t)
                t = deg;
        }
    }

    if (t != m_cpuTemp) {
        m_cpuTemp = t;
        emit cpuTempChanged();
    }
}

void SystemMonitor::refreshGpuTemp() {
    // Try DRM card hwmon entries first (works for AMD, Intel).
    int t = 0;
    const QDir drmDir(u"/sys/class/drm"_s);
    const QStringList cards = drmDir.entryList({ u"card*"_s }, QDir::Dirs);
    for (const QString& card : cards) {
        const QDir hwDir(drmDir.filePath(card + u"/device/hwmon"_s));
        const QStringList hwmons = hwDir.entryList({ u"hwmon*"_s }, QDir::Dirs);
        for (const QString& hwmon : hwmons) {
            QFile f(hwDir.filePath(hwmon + u"/temp1_input"_s));
            if (!f.open(QIODevice::ReadOnly))
                continue;
            const int deg = f.readAll().trimmed().toInt() / 1000;
            f.close();
            if (deg > t)
                t = deg;
        }
    }

    if (t != m_gpuTemp) {
        m_gpuTemp = t;
        emit gpuTempChanged();
    }
}

// static
int SystemMonitor::readHwmonTemp(const QStringList& chipNames) {
    int best = 0;
    const QDir hwmonBase(u"/sys/class/hwmon"_s);
    const QStringList entries = hwmonBase.entryList({ u"hwmon*"_s }, QDir::Dirs);
    for (const QString& entry : entries) {
        const QString base = hwmonBase.filePath(entry);
        QFile nameFile(base + u"/name"_s);
        if (!nameFile.open(QIODevice::ReadOnly))
            continue;
        const QString chip = QString::fromLatin1(nameFile.readAll().trimmed());
        nameFile.close();
        if (!chipNames.contains(chip))
            continue;

        // Read all temp*_input files and take the maximum.
        const QDir chipDir(base);
        const QStringList inputs = chipDir.entryList({ u"temp*_input"_s }, QDir::Files);
        for (const QString& inp : inputs) {
            QFile f(chipDir.filePath(inp));
            if (!f.open(QIODevice::ReadOnly))
                continue;
            const int deg = f.readAll().trimmed().toInt() / 1000;
            f.close();
            if (deg > best)
                best = deg;
        }
    }
    return best;
}

} // namespace peakshell::services
