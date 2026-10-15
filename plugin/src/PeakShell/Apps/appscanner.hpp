#pragma once

#include <qlist.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qqmllist.h>
#include <qstring.h>

namespace peakshell::apps {

// Represents a single .desktop application entry.
class AppEntry : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("AppEntry instances are created by AppScanner")

    Q_PROPERTY(QString name        READ name        CONSTANT)
    Q_PROPERTY(QString genericName READ genericName CONSTANT)
    Q_PROPERTY(QString comment     READ comment     CONSTANT)
    Q_PROPERTY(QString icon        READ icon        CONSTANT)
    Q_PROPERTY(QString exec        READ exec        CONSTANT)
    Q_PROPERTY(QString keywords    READ keywords    CONSTANT)
    Q_PROPERTY(bool    terminal    READ terminal    CONSTANT)

public:
    explicit AppEntry(QString name, QString genericName, QString comment,
                      QString icon, QString exec, QString keywords,
                      bool terminal, QObject* parent = nullptr);

    [[nodiscard]] QString name()        const;
    [[nodiscard]] QString genericName() const;
    [[nodiscard]] QString comment()     const;
    [[nodiscard]] QString icon()        const;
    [[nodiscard]] QString exec()        const;
    [[nodiscard]] QString keywords()    const;
    [[nodiscard]] bool    terminal()    const;

private:
    QString m_name;
    QString m_genericName;
    QString m_comment;
    QString m_icon;
    QString m_exec;
    QString m_keywords;
    bool    m_terminal;
};

// Scans XDG application directories for .desktop files, exposes them to QML,
// and launches applications. Replaces the python3 Process in AppScanner.qml.
class AppScanner : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QQmlListProperty<peakshell::apps::AppEntry> apps READ apps NOTIFY appsChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)

public:
    explicit AppScanner(QObject* parent = nullptr);

    [[nodiscard]] QQmlListProperty<AppEntry> apps();
    [[nodiscard]] bool loaded() const;

    Q_INVOKABLE void scan();
    Q_INVOKABLE void launch(AppEntry* entry);

signals:
    void appsChanged();
    void loadedChanged();
    void scanComplete();

private:
    void onScanFinished(QList<AppEntry*> entries);

    QList<AppEntry*> m_apps;
    bool m_loaded = false;
};

} // namespace peakshell::apps
