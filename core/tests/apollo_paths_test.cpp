#include "runtime/apollo_paths.h"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>

class ApolloPathsTest : public QObject {
    Q_OBJECT

  private slots:
    void honorsXdgAndExplicitOverrides();
    void usesPathKeyFallback();
    void rejectsUnsafeProfileNamesByFallingBack();
};

void ApolloPathsTest::honorsXdgAndExplicitOverrides()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    const QString root = temporary.path();
    for (const char *name : {
             "APOLLO_CONFIG_HOME",
             "APOLLO_DATA_HOME",
             "APOLLO_STATE_HOME",
             "APOLLO_CACHE_HOME",
             "APOLLO_RUNTIME_HOME",
         }) {
        qunsetenv(name);
    }
    qputenv("HOME", QFile::encodeName(QDir(root).filePath(QStringLiteral("home"))));
    qputenv("XDG_CONFIG_HOME", QFile::encodeName(QDir(root).filePath(QStringLiteral("config"))));
    qputenv("XDG_DATA_HOME", QFile::encodeName(QDir(root).filePath(QStringLiteral("data"))));
    qputenv("XDG_STATE_HOME", QFile::encodeName(QDir(root).filePath(QStringLiteral("state"))));
    qputenv("XDG_CACHE_HOME", QFile::encodeName(QDir(root).filePath(QStringLiteral("cache"))));
    qputenv("XDG_RUNTIME_DIR", QFile::encodeName(QDir(root).filePath(QStringLiteral("runtime"))));
    qputenv("APOLLO_PROFILE", "test-profile");
    qputenv("APOLLO_PROFILE_CONFIG_HOME",
            QFile::encodeName(QDir(root).filePath(QStringLiteral("profile-config"))));
    qputenv("APOLLO_PROFILE_HOME", QFile::encodeName(QDir(root).filePath(QStringLiteral("profile"))));
    qputenv("APOLLO_GENERATED_HOME", QFile::encodeName(QDir(root).filePath(QStringLiteral("generated"))));
    qputenv("APOLLO_KEY", QFile::encodeName(QDir(root).filePath(QStringLiteral("system-bin/key"))));

    QCOMPARE(qgetenv("XDG_CONFIG_HOME"), QFile::encodeName(QDir(root).filePath(QStringLiteral("config"))));

    const auto paths = Apollo::Runtime::ApolloPaths::fromEnvironment();
    QCOMPARE(paths.configHome(), QDir(root).filePath(QStringLiteral("config/apollo")));
    QCOMPARE(paths.dataHome(), QDir(root).filePath(QStringLiteral("data/apollo")));
    QCOMPARE(paths.stateHome(), QDir(root).filePath(QStringLiteral("state/apollo")));
    QCOMPARE(paths.cacheHome(), QDir(root).filePath(QStringLiteral("cache/apollo")));
    QCOMPARE(paths.runtimeHome(), QDir(root).filePath(QStringLiteral("runtime/apollo")));
    QCOMPARE(paths.profileName(), QStringLiteral("test-profile"));
    QCOMPARE(paths.profileConfigHome(), QDir(root).filePath(QStringLiteral("profile-config")));
    QCOMPARE(paths.profileHome(), QDir(root).filePath(QStringLiteral("profile")));
    QCOMPARE(paths.generatedHome(), QDir(root).filePath(QStringLiteral("generated")));
    QCOMPARE(paths.stableKey(), QDir(root).filePath(QStringLiteral("system-bin/key")));
}

void ApolloPathsTest::usesPathKeyFallback()
{
    qunsetenv("APOLLO_KEY");
    qputenv("APOLLO_BIN_HOME", "/tmp/obsolete-apollo-bin");

    const auto paths = Apollo::Runtime::ApolloPaths::fromEnvironment();
    QCOMPARE(paths.stableKey(), QStringLiteral("key"));
}

void ApolloPathsTest::rejectsUnsafeProfileNamesByFallingBack()
{
    qputenv("APOLLO_PROFILE", "../escape");
    qunsetenv("APOLLO_PROFILE_HOME");
    qunsetenv("APOLLO_PROFILE_CONFIG_HOME");
    qunsetenv("APOLLO_GENERATED_HOME");
    const auto paths = Apollo::Runtime::ApolloPaths::fromEnvironment();
    QCOMPARE(paths.profileName(), QStringLiteral("default"));
    QVERIFY(paths.profileHome().endsWith(QStringLiteral("/profiles/default")));

    qputenv("APOLLO_PROFILE", "bad\\name");
    QCOMPARE(Apollo::Runtime::ApolloPaths::fromEnvironment().profileName(), QStringLiteral("default"));
}

QTEST_MAIN(ApolloPathsTest)

#include "apollo_paths_test.moc"
