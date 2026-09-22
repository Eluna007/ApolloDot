#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QUrl>
#include <QVariantMap>

class ApolloFileSystem : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(ApolloFileSystem)
    QML_SINGLETON

  public:
    explicit ApolloFileSystem(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap localUrlInfo(const QUrl &url) const;
};
