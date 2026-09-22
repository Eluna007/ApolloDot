#include "apollo_build_info.h"

#include "apollo_release.h"

ApolloBuildInfo::ApolloBuildInfo(QObject *parent) : QObject(parent) {}

QString ApolloBuildInfo::release() const { return QStringLiteral(APOLLO_RELEASE); }

QString ApolloBuildInfo::commit() const { return QStringLiteral(APOLLO_COMMIT); }

QString ApolloBuildInfo::buildTime() const { return QStringLiteral(APOLLO_BUILD_TIME); }
