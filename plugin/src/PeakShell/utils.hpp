#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qstringlist.h>

namespace peakshell {

class Utils : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString version READ version CONSTANT)

public:
    [[nodiscard]] static QString version();

    // Expand ~ and $HOME in a path string.
    Q_INVOKABLE static QString expandHome(const QString& path);

    // Format a duration in seconds to a human-readable string (e.g. "1h 23m").
    Q_INVOKABLE static QString formatSeconds(qint64 seconds);

    // Send a POSIX signal to a process (default: SIGKILL = 9).
    Q_INVOKABLE static bool killProcess(qint64 pid, int signal = 9);

    // Launch a program detached without shell overhead.
    Q_INVOKABLE static bool execute(const QStringList& command);
    Q_INVOKABLE static bool execute(const QString& program, const QStringList& args = {});

    // Send a desktop notification via notify-send.
    Q_INVOKABLE static void notify(const QString& title, const QString& message, const QString& icon = {});

    // Resolve PipeWire client id to application name.
    Q_INVOKABLE static QString pipewireClientAppName(int clientId);
};

} // namespace peakshell
