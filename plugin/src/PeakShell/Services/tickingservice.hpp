#pragma once

#include <qtimer.h>

#include "service.hpp"

namespace peakshell::services {

// Base for services that need periodic polling.
// Polling only runs while at least one QML object holds a ref.
class TickingService : public Service {
    Q_OBJECT

    Q_PROPERTY(int updateInterval READ updateInterval WRITE setUpdateInterval
                   NOTIFY updateIntervalChanged)

public:
    explicit TickingService(QObject* parent = nullptr);
    ~TickingService() override = default;

    [[nodiscard]] int updateInterval() const;
    void setUpdateInterval(int ms);

signals:
    void updateIntervalChanged();

protected:
    virtual void tick() = 0;

private:
    void start() final;
    void stop() final;

    void applyInterval(int ms);

    QTimer* m_timer;
    int m_interval = 1000;
    bool m_running = false;
};

} // namespace peakshell::services
