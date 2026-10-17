#include "utils.hpp"

#include <csignal>
#include <qdbusconnection.h>
#include <qdbusmessage.h>
#include <qdir.h>
#include <qhash.h>
#include <qprocess.h>
#include <qregularexpression.h>
#include <qvariant.h>

#ifndef PEAKSHELL_VERSION
#define PEAKSHELL_VERSION "dev"
#endif

namespace peakshell {

using Qt::StringLiterals::operator""_s;

static QHash<int, QString> s_pwClientCache;

QString Utils::version() {
    return QStringLiteral(PEAKSHELL_VERSION);
}

QString Utils::expandHome(const QString& path) {
    if (path.startsWith(u'~'))
        return QDir::homePath() + path.sliced(1);
    return path;
}

QString Utils::formatSeconds(qint64 seconds) {
    if (seconds <= 0)
        return {};
    const qint64 h = seconds / 3600;
    const qint64 m = (seconds % 3600) / 60;
    if (h > 0)
        return u"%1h %2m"_s.arg(h).arg(m);
    if (m > 0)
        return u"%1m"_s.arg(m);
    return u"%1s"_s.arg(seconds);
}

bool Utils::killProcess(qint64 pid, int signal) {
    if (pid <= 0)
        return false;
    return ::kill(static_cast<pid_t>(pid), signal) == 0;
}

bool Utils::execute(const QStringList& command) {
    if (command.isEmpty())
        return false;
    const QString program = command.first();
    const QStringList args = command.mid(1);
    return QProcess::startDetached(program, args);
}

bool Utils::execute(const QString& program, const QStringList& args) {
    if (program.isEmpty())
        return false;
    return QProcess::startDetached(program, args);
}

void Utils::notify(const QString& title, const QString& message, const QString& icon) {
    // Post straight to the notification server as PeakShell instead of spawning
    // notify-send, so the shell is credited as the caller rather than the tool.
    QDBusMessage call = QDBusMessage::createMethodCall(
        u"org.freedesktop.Notifications"_s,
        u"/org/freedesktop/Notifications"_s,
        u"org.freedesktop.Notifications"_s,
        u"Notify"_s);

    call << u"PeakShell"_s   // app_name
         << 0u               // replaces_id
         << icon             // app_icon
         << title            // summary
         << message          // body
         << QStringList{}    // actions
         << QVariantMap{}    // hints
         << -1;              // expire_timeout (server default)

    QDBusConnection::sessionBus().send(call);
}

QString Utils::pipewireClientAppName(int clientId) {
    if (clientId <= 0)
        return {};

    if (s_pwClientCache.contains(clientId))
        return s_pwClientCache.value(clientId);

    QProcess proc;
    proc.start(u"pw-cli"_s, { u"info"_s, QString::number(clientId) });
    if (!proc.waitForFinished(300)) {
        proc.kill();
        return {};
    }

    const QString output = QString::fromUtf8(proc.readAllStandardOutput());
    static const QRegularExpression re(u"application\\.name\\s*=\\s*\"([^\"]+)\""_s);
    const auto match = re.match(output);
    if (match.hasMatch()) {
        const QString name = match.captured(1);
        s_pwClientCache.insert(clientId, name);
        return name;
    }

    return {};
}

} // namespace peakshell
