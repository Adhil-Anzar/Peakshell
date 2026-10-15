#pragma once

#include <qqmlintegration.h>
#include <qstring.h>

#include "tickingservice.hpp"

namespace peakshell::services {

// Reads CPU usage + temperature and GPU temperature directly from /proc and
// /sys, replacing the bash monitorProc in SystemMonitor.qml.
class SystemMonitor : public TickingService {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int cpuLoad     READ cpuLoad     NOTIFY cpuLoadChanged)
    Q_PROPERTY(int cpuTemp     READ cpuTemp     NOTIFY cpuTempChanged)
    Q_PROPERTY(int gpuTemp     READ gpuTemp     NOTIFY gpuTempChanged)

public:
    explicit SystemMonitor(QObject* parent = nullptr);

    [[nodiscard]] int cpuLoad() const;
    [[nodiscard]] int cpuTemp() const;
    [[nodiscard]] int gpuTemp() const;

signals:
    void cpuLoadChanged();
    void cpuTempChanged();
    void gpuTempChanged();

protected:
    void tick() override;

private:
    void refreshCpuLoad();
    void refreshCpuTemp();
    void refreshGpuTemp();

    // Returns the highest temperature found across hwmon entries matching the
    // given chip names (e.g. "coretemp", "k10temp").
    [[nodiscard]] static int readHwmonTemp(const QStringList& chipNames);

    int m_cpuLoad = 0;
    int m_cpuTemp = 0;
    int m_gpuTemp = 0;

    quint64 m_lastTotal = 0;
    quint64 m_lastIdle  = 0;
};

} // namespace peakshell::services
