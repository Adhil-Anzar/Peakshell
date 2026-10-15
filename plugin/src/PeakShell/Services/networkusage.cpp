#include "networkusage.hpp"

#include <qbytearrayview.h>
#include <qfile.h>
#include <array>
#include <charconv>
#include <system_error>

namespace peakshell::services {

using Qt::StringLiterals::operator""_s;

NetworkUsage::NetworkUsage(QObject* parent)
    : TickingService(parent) {}

qreal NetworkUsage::downloadSpeed() const { return m_downloadSpeed; }
qreal NetworkUsage::uploadSpeed() const { return m_uploadSpeed; }
quint64 NetworkUsage::downloadTotal() const { return m_downloadTotal; }
quint64 NetworkUsage::uploadTotal() const { return m_uploadTotal; }
quint64 NetworkUsage::rxBytes() const { return m_rxBytes; }
quint64 NetworkUsage::txBytes() const { return m_txBytes; }

void NetworkUsage::tick() {
    QFile f(u"/proc/net/dev"_s);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }

    // Skip headers
    f.readLine();
    f.readLine();

    quint64 totalRx = 0;
    quint64 totalTx = 0;

    while (!f.atEnd()) {
        const QByteArray line = f.readLine();
        const qsizetype splitIdx = line.indexOf(':');
        if (splitIdx == -1) {
            continue;
        }

        const QByteArray iface = line.left(splitIdx).trimmed();
        if (iface == QByteArrayView("lo")) {
            continue;
        }

        const char* pos = line.constData() + splitIdx + 1;
        const char* const end = line.constData() + line.size();

        std::array<unsigned long long, 9> fields{};
        bool valid = true;
        for (unsigned long long& field : fields) {
            while (pos < end && (*pos == ' ' || *pos == '\t')) {
                ++pos;
            }

            const auto [next, ec] = std::from_chars(pos, end, field);
            if (ec != std::errc{}) {
                valid = false;
                break;
            }
            pos = next;
        }

        if (!valid) {
            continue;
        }

        totalRx += static_cast<quint64>(fields[0]);
        totalTx += static_cast<quint64>(fields[8]);
    }
    f.close();

    m_rxBytes = totalRx;
    m_txBytes = totalTx;

    if (!m_initialized) {
        m_prevRx = totalRx;
        m_prevTx = totalTx;
        m_timer.start();
        m_initialized = true;
        emit changed();
        return;
    }

    const qreal elapsed = static_cast<qreal>(m_timer.restart()) / 1000.0;
    const quint64 rxDelta = totalRx >= m_prevRx ? totalRx - m_prevRx : 0;
    const quint64 txDelta = totalTx >= m_prevTx ? totalTx - m_prevTx : 0;

    m_downloadTotal += rxDelta;
    m_uploadTotal += txDelta;

    if (elapsed > 0.0) {
        m_downloadSpeed = static_cast<qreal>(rxDelta) / elapsed;
        m_uploadSpeed = static_cast<qreal>(txDelta) / elapsed;
    }

    m_prevRx = totalRx;
    m_prevTx = totalTx;

    emit changed();
}

} // namespace peakshell::services
