#pragma once

#include <qimage.h>
#include <qlist.h>
#include <qobject.h>
#include <qprocess.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qtimer.h>
#include <qvariantlist.h>
#include <qvariantmap.h>

namespace peakshell::apps {

// Monitors the system clipboard, keeps a bounded text/image history, and
// exposes ranked fuzzy search to QML. Persisted to disk across reloads.
class ClipboardManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY historyChanged)

public:
    explicit ClipboardManager(QObject* parent = nullptr);

    [[nodiscard]] int count() const;

    // Empty query returns the whole history, newest first.
    Q_INVOKABLE QVariantList search(const QString& query) const;

    Q_INVOKABLE void copy(const QString& id);
    // Copies the entry, then injects a Ctrl+V into the focused window once the
    // panel has released the keyboard. No-op when no injection tool is present.
    Q_INVOKABLE void copyAndPaste(const QString& id);
    Q_INVOKABLE void remove(const QString& id);
    Q_INVOKABLE void clear();

    // Re-read the current clipboard (call when the panel opens).
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void ingestText(const QString& text);

signals:
    void historyChanged();

private:
    struct Entry {
        QString id;
        QString fingerprint;
        QString text;
        QString imagePath;
        QStringList paths;
        QString mime;
        qint64 timestamp = 0;
        bool isImage = false;
        bool isFile = false;
    };

    void onClipboardChanged();
    void addText(const QString& text);
    void addImage(const QImage& image);
    void addFiles(const QStringList& paths);
    void addEntry(Entry entry);
    void enforceLimit();
    void trimExcessFiles();
    // Wipes the live Wayland clipboard and ignores the matched payload on the
    // next poll, so a deleted/cleared item is not recaptured.
    void clearLiveClipboard(const QString& fingerprint);
    void load();
    void scheduleSave();
    void save();
    QString cacheDir() const;
    QString indexFile() const;
    QVariantMap toMap(const Entry& entry, double score) const;
    static QString summarize(const QString& text);

    void startPoller();
    void schedulePoll();
    void pollTick();
    void onPollFinished(int exitCode, QProcess::ExitStatus status);

    enum class PollState {
        Idle,
        Listing,
        Reading,
    };

    QList<Entry> m_entries;
    QTimer m_saveTimer;
    QString m_clearGuard;
    bool m_loaded = false;

    // Wayland capture via wl-paste: QClipboard only sees changes while a
    // shell window is focused. No-op when wl-clipboard is absent.
    QProcess* m_poll = nullptr;
    QTimer m_pollTimer;
    QTimer m_pollTimeout;
    QString m_wlPastePath;
    QString m_wtypePath;
    QString m_pendingTextMime;
    QString m_pendingImageMime;
    QString m_pendingFileMime;
    PollState m_pollState = PollState::Idle;
    bool m_wlPasteAvailable = false;
    bool m_readingImage = false;
    bool m_readingFile = false;
};

} // namespace peakshell::apps
