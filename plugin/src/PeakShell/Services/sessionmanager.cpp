#include "sessionmanager.hpp"

#include <qdbusconnection.h>
#include <qdbuserror.h>
#include <qdbusmessage.h>
#include <qdbusreply.h>
#include <qloggingcategory.h>
#include <qprocess.h>

namespace {

Q_LOGGING_CATEGORY(lcSession, "peakshell.services.session", QtInfoMsg)

const QString k_loginService = QStringLiteral("org.freedesktop.login1");
const QString k_loginPath = QStringLiteral("/org/freedesktop/login1");
const QString k_loginIface = QStringLiteral("org.freedesktop.login1.Manager");
const QString k_sessionIface = QStringLiteral("org.freedesktop.login1.Session");

} // namespace

namespace peakshell::services {

using Qt::StringLiterals::operator""_s;

SessionManager::SessionManager(QObject* parent)
    : QObject(parent) {
    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        return;
    }

    auto sessionMsg = QDBusMessage::createMethodCall(k_loginService, k_loginPath, k_loginIface, u"GetSession"_s);
    sessionMsg.setArguments({ u"auto"_s });
    const QDBusReply<QDBusObjectPath> sessionReply = bus.call(sessionMsg);
    if (sessionReply.isValid()) {
        m_sessionPath = sessionReply.value().path();
    }
}

void SessionManager::execute(const QString& actionId) {
    const QString id = actionId.toLower().trimmed();
    if (id == u"logout"_s) {
        logout();
    } else if (id == u"switch"_s) {
        switchUser();
    } else if (id == u"reboot"_s) {
        reboot();
    } else if (id == u"sleep"_s || id == u"suspend"_s) {
        sleep();
    } else if (id == u"hibernate"_s) {
        hibernate();
    } else if (id == u"shutdown"_s || id == u"poweroff"_s) {
        shutdown();
    } else {
        qCWarning(lcSession) << "Unknown power action:" << actionId;
    }
}

void SessionManager::logout() {
    if (!m_sessionPath.isEmpty()) {
        callLogindSession(u"Terminate"_s);
    } else {
        runFallback(u"hyprctl dispatch exit"_s);
    }
}

void SessionManager::switchUser() {
    runFallback(u"command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"_s);
}

void SessionManager::reboot() {
    auto bus = QDBusConnection::systemBus();
    if (bus.isConnected()) {
        callLogindManager(u"Reboot"_s);
    } else {
        runFallback(u"systemctl reboot"_s);
    }
}

void SessionManager::sleep() {
    auto bus = QDBusConnection::systemBus();
    if (bus.isConnected()) {
        callLogindManager(u"Suspend"_s);
    } else {
        runFallback(u"systemctl suspend"_s);
    }
}

void SessionManager::hibernate() {
    auto bus = QDBusConnection::systemBus();
    if (bus.isConnected()) {
        callLogindManager(u"Hibernate"_s);
    } else {
        runFallback(u"systemctl hibernate"_s);
    }
}

void SessionManager::shutdown() {
    auto bus = QDBusConnection::systemBus();
    if (bus.isConnected()) {
        callLogindManager(u"PowerOff"_s);
    } else {
        runFallback(u"systemctl poweroff"_s);
    }
}

void SessionManager::callLogindManager(const QString& method) {
    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        return;
    }
    auto msg = QDBusMessage::createMethodCall(k_loginService, k_loginPath, k_loginIface, method);
    msg.setArguments({ true });
    bus.asyncCall(msg);
}

void SessionManager::callLogindSession(const QString& method) {
    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected() || m_sessionPath.isEmpty()) {
        return;
    }
    auto msg = QDBusMessage::createMethodCall(k_loginService, m_sessionPath, k_sessionIface, method);
    bus.asyncCall(msg);
}

void SessionManager::runFallback(const QString& cmd) {
    QProcess::startDetached(u"sh"_s, { u"-c"_s, cmd });
}

} // namespace peakshell::services
