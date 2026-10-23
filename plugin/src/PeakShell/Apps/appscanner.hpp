#pragma once

#include <string>

#include <qlist.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qqmllist.h>
#include <qstring.h>
#include <qvariant.h>
#include <qfilesystemwatcher.h>
#include <qhash.h>
#include <qsettings.h>
#include <qtimer.h>

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
    Q_PROPERTY(QString categories  READ categories  CONSTANT)
    Q_PROPERTY(bool    terminal    READ terminal    CONSTANT)

public:
    explicit AppEntry(QString name, QString genericName, QString comment,
                      QString icon, QString exec, QString keywords,
                      QString categories,
                      bool terminal, QObject* parent = nullptr);

    [[nodiscard]] QString name()        const;
    [[nodiscard]] QString genericName() const;
    [[nodiscard]] QString comment()     const;
    [[nodiscard]] QString icon()        const;
    [[nodiscard]] QString exec()        const;
    [[nodiscard]] QString keywords()    const;
    [[nodiscard]] QString categories()  const;
    [[nodiscard]] bool    terminal()    const;

    // Lowercase search fields are built once per desktop entry. Fuzzy
    // scoring runs on every keystroke, so re-lowercasing all fields for every
    // query is pure repeated work.
    [[nodiscard]] const std::string& nameLower()        const;
    [[nodiscard]] const std::string& genericNameLower() const;
    [[nodiscard]] const std::string& commentLower()     const;
    [[nodiscard]] const std::string& keywordsLower()    const;

private:
    QString m_name;
    QString m_genericName;
    QString m_comment;
    QString m_icon;
    QString m_exec;
    QString m_keywords;
    QString m_categories;
    bool    m_terminal;
    std::string m_nameLower;
    std::string m_genericNameLower;
    std::string m_commentLower;
    std::string m_keywordsLower;
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

    // OpenSearch-style unified search: fuzzy-matched apps + toggleable
    // `peakshell ipc call ii1qe <fn>` actions + exprtk calculator result +
    // smart web-search fallback, ranked exactly like OpenSearch
    // (fuzzy score, then ResultItem::matchScore boost ordering).
    // Returns a list of QVariantMap with keys:
    //   name, genericName, comment, icon, exec, keywords, categories,
    //   terminal(bool), kind ("app" | "ipc" | "calc" | "web"), ipcFunction,
    //   detail (extra pill text, e.g. calc expression), uid, score.
    // `uid` is a stable per-row identity for ScriptModel objectProp so list
    // reorder animations keep working across keystrokes.
    // Does NOT include "run in terminal" entries.
    Q_INVOKABLE QVariantList search(const QString& query);

    // Scope-aware variant used by launcher prefixes. Only the requested
    // result family is scored and built: "apps", "actions", "calc", or
    // "web". Empty/"all" keeps the unified global search behavior. This
    // avoids scanning every app and action only to filter the result list
    // in QML afterwards.
    Q_INVOKABLE QVariantList searchScoped(const QString& query, const QString& scope);

    // Executes one entry produced by search(). Calculator results are copied
    // to the clipboard; web results open the browser; ipc results invoke
    // `peakshell ipc call ii1qe <fn> [args...]`; app results launch normally.
    Q_INVOKABLE void activateResult(const QVariantMap& entry);

    // Copies arbitrary text to the clipboard (used for right-click copy).
    Q_INVOKABLE void copyToClipboard(const QString& text);

    // Clears all stored launch counts (frequency preference reset).
    Q_INVOKABLE void resetLaunchCounts();

signals:
    void appsChanged();
    void loadedChanged();
    void scanComplete();

private:
    void onScanFinished(QList<AppEntry*> entries);

    // Starts an async rescan on a thread-pool worker (never blocks the
    // calling thread). No-op safe to call while a scan is already running
    // (queues a follow-up instead).
    void doScan();
    void scheduleRescan();
    void onRescanTimeout();
    void updateWatches(const QStringList& desktopFiles);
    void recordLaunch(const QString& exec);

    QList<AppEntry*> m_apps;
    bool m_loaded = false;

    // Launch counts per app exec, persisted via QSettings and used to prefer
    // frequently launched apps in search ranking.
    QHash<QString, int> m_launchCounts;
    QSettings m_settings;

    // Tracks the .desktop application directories (and the files themselves)
    // so adds/deletes/edits refresh the internal list automatically.
    QFileSystemWatcher m_watcher;
    QTimer m_rescanTimer;
    bool m_scanActive = false;
    bool m_scanDirty = false;
};

} // namespace peakshell::apps
