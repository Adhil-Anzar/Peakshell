#include "tickingservice.hpp"

namespace peakshell::services {

TickingService::TickingService(QObject* parent)
    : QObject(parent)
    , m_timer(new QTimer(this)) {
    m_timer->setSingleShot(false);
    QObject::connect(m_timer, &QTimer::timeout, this, [this] { tick(); });
    m_timer->start(m_interval);
    // Run once immediately so the first read doesn't wait for the interval.
    QTimer::singleShot(0, this, [this] { tick(); });
}

int TickingService::updateInterval() const {
    return m_interval;
}

void TickingService::setUpdateInterval(int ms) {
    applyInterval(ms);
}

void TickingService::applyInterval(int ms) {
    if (ms <= 0 || ms == m_interval)
        return;
    m_interval = ms;
    m_timer->start(m_interval);
    emit updateIntervalChanged();
}

} // namespace peakshell::services
