#include "i18n_manager.h"

#include <QCoreApplication>
#include <QLocale>
#include <QTest>

class I18nManagerTest : public QObject {
    Q_OBJECT

  private slots:
    void resolvesLanguagePreferences_data();
    void resolvesLanguagePreferences();
    void switchesCatalogsWithoutChangingRegionalSettings();
};

void I18nManagerTest::resolvesLanguagePreferences_data()
{
    QTest::addColumn<QStringList>("preferences");
    QTest::addColumn<QString>("expected");
    QTest::newRow("english-variant") << QStringList{"en-GB"} << "en_US";
    // English is the only shipped catalog, so every other locale resolves to it.
    QTest::newRow("simplified") << QStringList{"zh_CN.UTF-8"} << "en_US";
    QTest::newRow("chinese-default") << QStringList{"zh"} << "en_US";
    QTest::newRow("singapore") << QStringList{"zh-SG"} << "en_US";
    QTest::newRow("taiwan") << QStringList{"zh-TW"} << "en_US";
    QTest::newRow("hong-kong") << QStringList{"zh_HK.UTF-8"} << "en_US";
    QTest::newRow("macao") << QStringList{"zh-MO"} << "en_US";
    QTest::newRow("hant") << QStringList{"zh-Hant-US"} << "en_US";
    QTest::newRow("hans-before-region") << QStringList{"zh-Hans-HK"} << "en_US";
    QTest::newRow("case-and-whitespace") << QStringList{" ZH-hant "} << "en_US";
    QTest::newRow("unsupported") << QStringList{"ja-JP", "fr-FR"} << "en_US";
    QTest::newRow("supported-secondary") << QStringList{"fr-FR", "ja-JP", "en-US"} << "en_US";
    QTest::newRow("first-supported") << QStringList{"zh-CN", "en-US"} << "en_US";
    QTest::newRow("empty") << QStringList{} << "en_US";
    QTest::newRow("posix") << QStringList{"C.UTF-8"} << "en_US";
    QTest::newRow("invalid") << QStringList{"unknown-hant"} << "en_US";
}

void I18nManagerTest::resolvesLanguagePreferences()
{
    QFETCH(QStringList, preferences);
    QFETCH(QString, expected);
    I18nManager manager;
    QCOMPARE(manager.preferredLanguage(preferences), expected);
    if (preferences.size() == 1)
        QCOMPARE(manager.normalizeLanguage(preferences.first()), expected);
}

void I18nManagerTest::switchesCatalogsWithoutChangingRegionalSettings()
{
    const QLocale originalLocale;
    const QLocale regionalLocale(QStringLiteral("de_DE"));
    QLocale::setDefault(regionalLocale);
    // Restore the process locale even if an assertion returns early.
    struct LocaleRestorer {
        QLocale locale;
        ~LocaleRestorer() { QLocale::setDefault(locale); }
    } restorer{originalLocale};

    I18nManager manager;
    const auto translate = [](const char *context, const char *source, int n = -1) {
        return QCoreApplication::translate(context, source, nullptr, n);
    };
    QVERIFY(manager.setLanguage(QStringLiteral("en-GB")));
    QCOMPARE(manager.language(), QStringLiteral("en_US"));
    QCOMPARE(translate("AccountPage", "Unknown"), QStringLiteral("Unknown"));
    QCOMPARE(translate("TimeUtils", "%n minute(s) ago", 1), QStringLiteral("1 minute ago"));
    QCOMPARE(translate("TimeUtils", "%n minute(s) ago", 2), QStringLiteral("2 minutes ago"));
    QCOMPARE(
        QCoreApplication::translate("SpotlightClipboardProvider", "%n file(s)", "clipboard file count", 2),
        QStringLiteral("2 files"));
    QCOMPARE(translate("UntranslatedContext", "English fallback"), QStringLiteral("English fallback"));
    QCOMPARE(QLocale().name(), regionalLocale.name());
    QCOMPARE(QLocale().toString(1234.5, 'f', 1), regionalLocale.toString(1234.5, 'f', 1));

    // A locale with no shipped catalog keeps the English one installed and
    // reports success rather than failing to load a catalog that is not built.
    QVERIFY(manager.setLanguage(QStringLiteral("zh-Hant")));
    QCOMPARE(manager.language(), QStringLiteral("en_US"));
    QCOMPARE(translate("AccountPage", "Unknown"), QStringLiteral("Unknown"));

    QVERIFY(manager.setLanguage(QStringLiteral("fr-FR")));
    QCOMPARE(manager.language(), QStringLiteral("en_US"));
    QVERIFY(manager.lastError().isEmpty());
    QCOMPARE(QLocale().name(), regionalLocale.name());
}

QTEST_GUILESS_MAIN(I18nManagerTest)
#include "i18n_manager_test.moc"
