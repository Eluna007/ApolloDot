#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>

class ApolloBuildInfo : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(ApolloBuildInfo)
    QML_SINGLETON
    Q_PROPERTY(QString release READ release CONSTANT)
    Q_PROPERTY(QString commit READ commit CONSTANT)
    Q_PROPERTY(QString buildTime READ buildTime CONSTANT)

  public:
    explicit ApolloBuildInfo(QObject *parent = nullptr);

    QString release() const;
    QString commit() const;
    QString buildTime() const;
};
