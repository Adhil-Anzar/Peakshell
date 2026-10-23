#pragma once

#include <memory>

#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qvariant.h>

namespace peakshell::apps {

// Asynchronous filesystem search for the launcher.
//
// The service always checks the XDG recent-files list (recently-used.xbel)
// and KDE's RecentDocuments first, then asks Baloo (when available) for
// indexed matches. Baloo queries are cancellable; a bounded home fallback
// keeps the feature usable without a Baloo index. The optional
// full-filesystem scan also covers hidden config paths that Baloo does not
// index; it is enabled from Settings and off by default because it is
// expensive.
class FileSearch : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool searching READ searching NOTIFY searchingChanged)

public:
    explicit FileSearch(QObject* parent = nullptr);
    ~FileSearch() override;

    [[nodiscard]] bool searching() const;

    // Starts a new search, cancelling any in-flight one. Emits
    // recentResultsReady() as soon as the (instant) recent list is matched,
    // followed by searchFinished() with recent + indexed results.
    Q_INVOKABLE void search(const QString& query);

    // Scope-aware variant used by launcher prefixes.
    //
    // scope "files" / "folders" restricts results to that kind and, when the
    // query is empty, lists the most recent entries instead of needing text.
    // An explicit scope also works when the matching settings toggle is off.
    // Any other scope behaves like search().
    Q_INVOKABLE void searchScoped(const QString& query, const QString& scope);

    // Cancels the current search and clears the loading state.
    Q_INVOKABLE void cancel();

signals:
    void searchingChanged();
    void recentResultsReady(const QString& query, const QVariantList& results);
    void searchFinished(const QString& query, const QVariantList& results);

private:
    struct Private;
    std::unique_ptr<Private> d;
};

} // namespace peakshell::apps
