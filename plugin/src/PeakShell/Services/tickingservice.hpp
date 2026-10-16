#pragma once

#include <qobject.h>
#include <qtimer.h>

namespace peakshell::services {

// Base for services that need periodic polling.
class TickingService : public QObject {
  Q_OBJECT

  Q_PROPERTY(int updateInterval READ updateInterval WRITE setUpdateInterval
                 NOTIFY updateIntervalChanged)

public:
  explicit TickingService(QObject *parent = nullptr);
  ~TickingService() override = default;

  [[nodiscard]] int updateInterval() const;
  void setUpdateInterval(int ms);

signals:
  void updateIntervalChanged();

protected:
  virtual void tick() = 0;

private:
  void applyInterval(int ms);

  QTimer *m_timer;
  int m_interval = 500;
};

} // namespace peakshell::services
