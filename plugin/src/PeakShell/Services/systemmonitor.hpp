#pragma once

#include <qqmlintegration.h>
#include <qstring.h>

#include "tickingservice.hpp"

namespace peakshell::services {

// Reads CPU usage + temperature, GPU load + temperature, and memory usage
// directly from /proc and /sys, replacing the bash monitorProc in
// SystemMonitor.qml.
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
  void refreshGpuLoad();
  void refreshGpuTemp();
  void refreshMemory();

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
};

} // namespace peakshell::services
