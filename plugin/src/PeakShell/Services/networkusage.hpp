#pragma once

#include <qqmlintegration.h>
#include <qelapsedtimer.h>

#include "tickingservice.hpp"

namespace peakshell::services {

class NetworkUsage : public TickingService {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(qreal downloadSpeed READ downloadSpeed NOTIFY changed)
    Q_PROPERTY(qreal uploadSpeed READ uploadSpeed NOTIFY changed)
    Q_PROPERTY(quint64 downloadTotal READ downloadTotal NOTIFY changed)
    Q_PROPERTY(quint64 uploadTotal READ uploadTotal NOTIFY changed)
    Q_PROPERTY(quint64 rxBytes READ rxBytes NOTIFY changed)
    Q_PROPERTY(quint64 txBytes READ txBytes NOTIFY changed)

public:
    explicit NetworkUsage(QObject* parent = nullptr);

    [[nodiscard]] qreal downloadSpeed() const;
    [[nodiscard]] qreal uploadSpeed() const;
    [[nodiscard]] quint64 downloadTotal() const;
    [[nodiscard]] quint64 uploadTotal() const;
    [[nodiscard]] quint64 rxBytes() const;
    [[nodiscard]] quint64 txBytes() const;

signals:
    void changed();

protected:
    void tick() override;

private:
    qreal m_downloadSpeed = 0.0;
    qreal m_uploadSpeed = 0.0;
    quint64 m_downloadTotal = 0;
    quint64 m_uploadTotal = 0;
    quint64 m_rxBytes = 0;
    quint64 m_txBytes = 0;

    quint64 m_prevRx = 0;
    quint64 m_prevTx = 0;
    QElapsedTimer m_timer;
    bool m_initialized = false;
};

} // namespace peakshell::services
