#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>

namespace peakshell::services {

class SessionManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit SessionManager(QObject* parent = nullptr);

    Q_INVOKABLE void execute(const QString& actionId);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void switchUser();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void sleep();
    Q_INVOKABLE void hibernate();
    Q_INVOKABLE void shutdown();

private:
    void callLogindSession(const QString& method);
    static void runFallback(const QString& cmd);

    QString m_sessionPath;
};

} // namespace peakshell::services
