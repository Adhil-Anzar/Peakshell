#pragma once

#include <qbytearray.h>
#include <qprocess.h>
#include <qqmlintegration.h>
#include <qstring.h>

#include "tickingservice.hpp"

namespace peakshell::services {

// Reads CPU usage + temperature, GPU load + temperature, and memory usage
// directly from /proc and /sys, replacing the bash monitorProc in
// SystemMonitor.qml.
//
// Metrics sysfs cannot provide (NVIDIA has no gpu_busy_percent and often no
// hwmon temp) come from a single long-lived `nvidia-smi` probe running in loop
// mode. The probe is fully asynchronous: the GUI thread never waits on it.
class SystemMonitor : public TickingService {
  Q_OBJECT
  QML_ELEMENT
  QML_SINGLETON

  Q_PROPERTY(int cpuLoad READ cpuLoad NOTIFY cpuLoadChanged)
  Q_PROPERTY(int cpuTemp READ cpuTemp NOTIFY cpuTempChanged)
  Q_PROPERTY(int gpuLoad READ gpuLoad NOTIFY gpuLoadChanged)
  Q_PROPERTY(int gpuTemp READ gpuTemp NOTIFY gpuTempChanged)
  Q_PROPERTY(int memUsage READ memUsage NOTIFY memUsageChanged)

public:
  explicit SystemMonitor(QObject *parent = nullptr);
  ~SystemMonitor() override;

  [[nodiscard]] int cpuLoad() const;
  [[nodiscard]] int cpuTemp() const;
  [[nodiscard]] int gpuLoad() const;
  [[nodiscard]] int gpuTemp() const;
  [[nodiscard]] int memUsage() const;

signals:
  void cpuLoadChanged();
  void cpuTempChanged();
  void gpuLoadChanged();
  void gpuTempChanged();
  void memUsageChanged();

protected:
  void tick() override;

private:
  void refreshCpuLoad();
  void refreshCpuTemp();
  void refreshGpuSysfs();
  void refreshMemory();

  void maybeStartGpuProbe();
  void startGpuProbe();
  void readGpuProbe();
  void onGpuProbeFinished(int exitCode, QProcess::ExitStatus status);
  void setGpuLoad(int load);
  void setGpuTemp(int temp);

  // Returns the highest temperature found across hwmon entries matching the
  // given chip names (e.g. "coretemp", "k10temp").
  [[nodiscard]] static int readHwmonTemp(const QStringList &chipNames);

  int m_cpuLoad = 0;
  int m_cpuTemp = 0;
  int m_gpuLoad = 0;
  int m_gpuTemp = 0;
  int m_memUsage = 0;

  quint64 m_lastTotal = 0;
  quint64 m_lastIdle = 0;

  // Sticky flags: once sysfs has reported a metric, it stays authoritative and
  // the nvidia-smi probe leaves that metric alone.
  bool m_sysfsLoadKnown = false;
  bool m_sysfsTempKnown = false;

  bool m_probeWanted = true;
  int m_probeFailures = 0;
  QProcess *m_probe = nullptr;
  QByteArray m_probeBuffer;
};

} // namespace peakshell::services
