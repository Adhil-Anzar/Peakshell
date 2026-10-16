#pragma once

#include <qobject.h>
#include <qset.h>

namespace peakshell::services {

// Base class for services that should only run while a QML object uses them.
// Call ref() from the consuming object and unref() when it goes away to
// avoid polling when nothing is listening.
class Service : public QObject {
    Q_OBJECT

public:
    explicit Service(QObject* parent = nullptr);

    void ref(QObject* sender);
    void unref(QObject* sender);

private:
    QSet<QObject*> m_refs;

    virtual void start() = 0;
    virtual void stop() = 0;
};

} // namespace peakshell::services
