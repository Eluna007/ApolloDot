import QtQuick
import qs.Common
import qs.Services
import "../../Common/functions/SpotlightLocalSearch.js" as LocalSearch

Item {
    id: root
    property bool active: false
    property string query: ""
    property var results: []
    property var expandedGroups: ({})
    property string error: ""
    readonly property string language: Qt.uiLanguage
    signal modeRequested(string mode, string query)
    signal deferredRequested(string provider, string sourceId, string query)
    signal selectionIdRequested(string id)
    signal closeRequested

    function rebuild() {
        if (!active)
            return;
        if (!query.trim()) {
            results = [];
            return;
        }
        const apps = LocalSearch.appResults(ApplicationService.applications, query,
                                            UiPreferences.spotlightAppOrder, SpotlightAppUsage.records,
                                            Date.now()).map(entry => Object.assign({}, entry, {
                                                                                       iconKind: "app",
                                                                                       appIcon: entry.icon
                                                                                   }));
        const settings = LocalSearch.matchCatalog(SpotlightCatalog.settings.filter(SpotlightCatalog.available),
                                                  query).map(entry => ({
                                                      id: entry.id,
                                                      title: entry.title,
                                                      subtitle: qsTr("Settings · %1").arg(entry.breadcrumb),
                                                      iconKind: "symbol",
                                                      symbol: entry.icon
                                                  }));
        const actions = LocalSearch.matchCatalog(SpotlightCatalog.actions, query).map(entry => ({
            id: entry.id,
            title: entry.title,
            subtitle: SpotlightCatalog.available(entry) ? qsTr("Action · %1").arg(entry.description) : qsTr(
                                                              "Action · Currently unavailable"),
            iconKind: "symbol",
            symbol: entry.icon,
            available: SpotlightCatalog.available(entry)
        }));
        const wallpapers = LocalSearch.wallpaperPaths(WallpaperService.wallpapers, query,
                                                      WallpaperService.basename).map(path => ({
                                                          id: path,
                                                          title: WallpaperService.basename(path),
                                                          subtitle: WallpaperService.parentFolder(path),
                                                          iconKind: "wallpaper",
                                                          previewUrl: Paths.fileUrl(path),
                                                          symbol: "image"
                                                      }));
        results = LocalSearch.groupedResults({
                                                 apps: apps,
                                                 settings: settings,
                                                 actions: actions,
                                                 wallpapers: wallpapers
                                             }, expandedGroups, query, {
                                                 apps: qsTr("Apps"),
                                                 settings: qsTr("Settings"),
                                                 actions: qsTr("Actions"),
                                                 wallpapers: qsTr("Wallpapers"),
                                                 more: qsTr("Show more"),
                                                 files: qsTr("Search files for “%1”").arg(query),
                                                 web: qsTr("Search the web for “%1”").arg(query)
                                             });
    }
    function activate(id) {
        if (!active)
            return false;
        const request = LocalSearch.activation(results, id, query);
        if (!request)
            return false;
        error = "";
        switch (request.provider) {
        case "more":
            const next = Object.assign({}, expandedGroups);
            next[request.sourceId] = (next[request.sourceId] || LocalSearch.budgets[request.sourceId])
                    + LocalSearch.budgets[request.sourceId];
            const prior = new Set(results.map(row => row.id));
            expandedGroups = next;
            rebuild();
            const added = results.find(row => row.provider === request.sourceId && !prior.has(row.id));
            if (added)
                selectionIdRequested(added.id);
            return true;
        case "extension":
            if (request.sourceId === "files")
                modeRequested("files", request.query);
            else
                deferredRequested("web", "", request.query);
            return true;
        case "apps":
            if (SpotlightAppUsage.launch(request.sourceId)) {
                closeRequested();
                return true;
            }
            break;
        case "wallpapers":
            if (!WallpaperService.busy && WallpaperService.wallpapers.indexOf(request.sourceId) >= 0 && WallpaperService.setWallpaper(
                        request.sourceId)) {
                closeRequested();
                return true;
            }
            break;
        case "settings":
            if (SpotlightCatalog.available(SpotlightCatalog.setting(request.sourceId))) {
                deferredRequested("settings", request.sourceId, request.query);
                return true;
            }
            break;
        case "actions":
            const action = SpotlightCatalog.action(request.sourceId);
            if (!SpotlightCatalog.available(action))
                break;
            if (action.target === "spotlight") {
                const mode = action.method === "openMode" ? action.args[0] : action.method;
                modeRequested(mode, "");
            } else
                deferredRequested("actions", action.id, request.query);
            return true;
        }
        error = qsTr("This result is currently unavailable");
        return false;
    }
    onQueryChanged: {
        expandedGroups = ({});
        error = "";
        rebuild();
    }
    onActiveChanged: {
        if (active)
            expandedGroups = ({});
        rebuild();
    }
    onLanguageChanged: rebuild()
    Connections {
        target: ApplicationService
        function onApplicationsChanged() {
            root.rebuild();
        }
    }
    Connections {
        target: WallpaperService
        function onWallpapersChanged() {
            root.rebuild();
        }
        function onBusyChanged() {
            root.rebuild();
        }
    }
    Connections {
        target: SpotlightCatalog
        function onAvailabilityChanged() {
            root.rebuild();
        }
        function onSettingsChanged() {
            root.rebuild();
        }
        function onActionsChanged() {
            root.rebuild();
        }
        function onKeystoneAvailableChanged() {
            root.rebuild();
        }
    }
    Connections {
        target: UiPreferences
        function onSpotlightAppOrderChanged() {
            root.rebuild();
        }
    }
    Connections {
        target: SpotlightAppUsage
        function onReadyChanged() {
            root.rebuild();
        }
    }
}
