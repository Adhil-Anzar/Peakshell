#include "systemmonitor.hpp"

#include <qdir.h>
#include <qfile.h>
#include <qprocess.h>
#include <qregularexpression.h>

namespace peakshell::services {

using Qt::StringLiterals::operator""_s;

SystemMonitor::SystemMonitor(QObject *parent) : TickingService(parent) {}

int SystemMonitor::cpuLoad() const { return m_cpuLoad; }
int SystemMonitor::cpuTemp() const { return m_cpuTemp; }
int SystemMonitor::gpuLoad() const { return m_gpuLoad; }
int SystemMonitor::gpuTemp() const { return m_gpuTemp; }
int SystemMonitor::memUsage() const { return m_memUsage; }

void SystemMonitor::tick() {
  refreshCpuLoad();
  refreshCpuTemp();
  refreshGpuLoad();
  refreshGpuTemp();
  refreshMemory();
}

void SystemMonitor::refreshCpuLoad() {
  QFile f(u"/proc/stat"_s);
  if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
    return;

  const QByteArray data = f.readLine();
  f.close();

  const QList<QByteArray> parts = data.simplified().split(' ');
  if (parts.size() < 9 || parts[0] != "cpu")
    return;

  quint64 total = 0;
  quint64 idle = 0;
  for (int i = 1; i <= 8; ++i) {
    const quint64 v = parts[i].toULongLong();
    total += v;
    if (i == 4 || i == 5) // idle + iowait
      idle += v;
  }

  const quint64 dt = total > m_lastTotal ? total - m_lastTotal : 0;
  const quint64 di = idle > m_lastIdle ? idle - m_lastIdle : 0;
  m_lastTotal = total;
  m_lastIdle = idle;

  const int newLoad = static_cast<int>(dt > 0 ? (dt - di) * 100 / dt : 0);
  if (newLoad != m_cpuLoad) {
    m_cpuLoad = newLoad;
    emit cpuLoadChanged();
  }
}

void SystemMonitor::refreshCpuTemp() {
  int t = readHwmonTemp(
      {u"coretemp"_s, u"k10temp"_s, u"zenpower"_s, u"legion_hwmon"_s});

  if (t == 0) {
    const QDir tzDir(u"/sys/class/thermal"_s);
    const QStringList zones = tzDir.entryList({u"thermal_zone*"_s}, QDir::Dirs);
    for (const QString &zone : zones) {
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

void SystemMonitor::refreshGpuLoad() {
  int load = 0;
  const QDir drmDir(u"/sys/class/drm"_s);
  const QStringList cards = drmDir.entryList({u"card*"_s}, QDir::Dirs);
  for (const QString &card : cards) {
    QFile f(drmDir.filePath(card + u"/device/gpu_busy_percent"_s));
    if (f.open(QIODevice::ReadOnly)) {
      const int val = f.readAll().trimmed().toInt();
      f.close();
      if (val > load)
        load = val;
    }
  }

  // Fallback for NVIDIA or cards without sysfs busy percent: query nvidia-smi
  if (load == 0) {
    QProcess process;
    process.start(u"nvidia-smi"_s, {u"--query-gpu=utilization.gpu"_s,
                                    u"--format=csv,noheader,nounits"_s});
    if (process.waitForFinished(500)) {
      const QString output =
          QString::fromLocal8Bit(process.readAllStandardOutput()).trimmed();
      bool ok = false;
      const int val = output.toInt(&ok);
      if (ok && val > load) {
        load = val;
      }
    }
  }

  if (load != m_gpuLoad) {
    m_gpuLoad = load;
    emit gpuLoadChanged();
  }
}

void SystemMonitor::refreshGpuTemp() {
  int t = 0;
  const QDir drmDir(u"/sys/class/drm"_s);
  const QStringList cards = drmDir.entryList({u"card*"_s}, QDir::Dirs);
  for (const QString &card : cards) {
    const QDir hwDir(drmDir.filePath(card + u"/device/hwmon"_s));
    const QStringList hwmons = hwDir.entryList({u"hwmon*"_s}, QDir::Dirs);
    for (const QString &hwmon : hwmons) {
      QFile f(hwDir.filePath(hwmon + u"/temp1_input"_s));
      if (!f.open(QIODevice::ReadOnly))
        continue;
      const int deg = f.readAll().trimmed().toInt() / 1000;
      f.close();
      if (deg > t)
        t = deg;
    }
  }

  if (t == 0) {
    t = readHwmonTemp({u"amdgpu"_s, u"nvidia"_s, u"nouveau"_s});
  }

  if (t == 0) {
    QProcess process;
    process.start(u"nvidia-smi"_s, {u"--query-gpu=temperature.gpu"_s,
                                    u"--format=csv,noheader,nounits"_s});
    if (process.waitForFinished(500)) {
      const QString output =
          QString::fromLocal8Bit(process.readAllStandardOutput()).trimmed();
      bool ok = false;
      const int val = output.toInt(&ok);
      if (ok && val > t) {
        t = val;
      }
    }
  }

  if (t != m_gpuTemp) {
    m_gpuTemp = t;
    emit gpuTempChanged();
  }
}

void SystemMonitor::refreshMemory() {
  QFile f(u"/proc/meminfo"_s);
  if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
    return;

  const QByteArray content = f.readAll();
  f.close();

  quint64 memTotal = 0;
  quint64 memAvailable = 0;
  quint64 memFree = 0;
  quint64 buffers = 0;
  quint64 cached = 0;

  const QList<QByteArray> lines = content.split('\n');
  for (const QByteArray &line : lines) {
    if (line.startsWith("MemTotal:")) {
      memTotal = line.mid(9).trimmed().split(' ')[0].toULongLong();
    } else if (line.startsWith("MemAvailable:")) {
      memAvailable = line.mid(13).trimmed().split(' ')[0].toULongLong();
    } else if (line.startsWith("MemFree:")) {
      memFree = line.mid(8).trimmed().split(' ')[0].toULongLong();
    } else if (line.startsWith("Buffers:")) {
      buffers = line.mid(8).trimmed().split(' ')[0].toULongLong();
    } else if (line.startsWith("Cached:")) {
      cached = line.mid(7).trimmed().split(' ')[0].toULongLong();
    }
  }

  if (memTotal > 0) {
    quint64 memUsed = 0;
    if (memAvailable > 0) {
      memUsed = memTotal > memAvailable ? memTotal - memAvailable : 0;
    } else {
      const quint64 nonFree = memFree + buffers + cached;
      memUsed = memTotal > nonFree ? memTotal - nonFree : 0;
    }

    const int usage = static_cast<int>((static_cast<double>(memUsed) * 100.0) /
                                           static_cast<double>(memTotal) +
                                       0.5);
    if (usage != m_memUsage) {
      m_memUsage = usage;
      emit memUsageChanged();
    }
  }
}

int SystemMonitor::readHwmonTemp(const QStringList &chipNames) {
  int best = 0;
  const QDir hwmonBase(u"/sys/class/hwmon"_s);
  const QStringList entries = hwmonBase.entryList({u"hwmon*"_s}, QDir::Dirs);
  for (const QString &entry : entries) {
    const QString base = hwmonBase.filePath(entry);
    QFile nameFile(base + u"/name"_s);
    if (!nameFile.open(QIODevice::ReadOnly))
      continue;
    const QString chip = QString::fromLatin1(nameFile.readAll().trimmed());
    nameFile.close();
    if (!chipNames.contains(chip))
      continue;

    const QDir chipDir(base);
    const QStringList inputs =
        chipDir.entryList({u"temp*_input"_s}, QDir::Files);
    for (const QString &inp : inputs) {
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
