import QtQuick
import QtTest
import "../../Common/functions/SpotlightLocalSearch.js" as Search

TestCase {
    name: "SpotlightLocalSearch"
    function labels() {
        return {
            apps: "Apps",
            settings: "Settings",
            actions: "Actions",
            wallpapers: "Wallpapers",
            more: "More",
            files: "Files",
            web: "Web"
        };
    }
    function test_empty_and_extensions_preserve_literal_query() {
        compare(Search.groupedResults({}, {}, " \t", labels()), []);
        const query = "  A/B 中文 & ?\"  ";
        const results = Search.groupedResults({}, {}, query, labels());
        compare(results.length, 2);
        compare(Search.activation(results, "extension:files", query), {
                    provider: "extension",
                    sourceId: "files",
                    query: query
                });
        compare(Search.activation(results, "extension:web", query).query, query);
        compare(Search.activation(results, "extension:web", "different"), null);
        compare(Search.activation(results, "eval:query", query), null);
    }
    function test_group_order_budgets_and_namespaced_identity() {
        const apps = [];
        for (let i = 0; i < 8; ++i)
            apps.push({
                          id: "app" + i,
                          title: "App " + i
                      });
        const matches = {
            apps: apps,
            settings: [
                {
                    id: "app0",
                    title: "Setting"
                }
            ],
            actions: [
                {
                    id: "open",
                    title: "Open"
                }
            ]
        };
        let rows = Search.groupedResults(matches, {}, "a", labels());
        compare(rows[0].id, "apps:app0");
        compare(rows[5].id, "more:apps");
        compare(rows[6].id, "settings:app0");
        compare(rows[7].id, "actions:open");
        compare(rows.filter(row => row.groupTitle).length, 3);
        rows = Search.groupedResults(matches, {
                                         apps: 10
                                     }, "a", labels());
        verify(!rows.some(row => row.id === "more:apps"));
        compare(rows[7].id, "apps:app7");
        compare(matches.apps.length, 8);
    }
    function test_catalog_localized_english_alias_and_deterministic_order() {
        const entries = [
                  {
                      id: "b",
                      title: "界面语言",
                      sourceTitle: "Interface language",
                      aliases: ["locale"]
                  },
                  {
                      id: "a",
                      title: "语言",
                      sourceTitle: "Language",
                      aliases: []
                  },
                  {
                      id: "c",
                      title: "外观",
                      sourceTitle: "Appearance",
                      aliases: []
                  }
              ];
        compare(Search.matchCatalog(entries, "语").map(e => e.id), ["a", "b"]);
        compare(Search.matchCatalog(entries, "Interface").map(e => e.id), ["b"]);
        compare(Search.matchCatalog(entries, "locale").map(e => e.id), ["b"]);
        compare(Search.matchCatalog(entries, "").length, 0);
        compare(Search.matchCatalog(entries, "$(shutdown)").length, 0);
    }
    function test_apps_keep_relevance_usage_and_stable_id() {
        const apps = [
                  {
                      id: "x",
                      name: "Browser",
                      icon: "x"
                  },
                  {
                      id: "y",
                      name: "Browser tools",
                      icon: "y"
                  }
              ];
        const history = {
            y: {
                launchCount: 1000,
                lastLaunchedAt: 1000
            }
        };
        compare(Search.appResults(apps, "browser", "most-used", history, 2000).map(e => e.id), ["x", "y"]);
        compare(Search.appResults(apps, "", "most-used", history, 2000).map(e => e.id), ["y", "x"]);
        compare(Search.appResults(apps, "", "name", history, 2000).map(e => e.id), ["x", "y"]);
        compare(apps[0].id, "x");
    }
    function test_wallpaper_existing_name_rules() {
        const basename = path => path.slice(path.lastIndexOf("/") + 1);
        const paths = ["/a/z-moon.png", "/b/moon.png", "/c/sun.png"];
        compare(Search.wallpaperPaths(paths, "MOON", basename), ["/b/moon.png", "/a/z-moon.png"]);
        compare(paths.length, 3);
    }
}
