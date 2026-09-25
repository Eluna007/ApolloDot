pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Apollo.Niri
import qs.Common
import "../Modules/Games/Chess/Model.js" as ChessModel

// Owns which game window is open and on which output, the save directory, and
// the chess.com ratings request. The two game windows are presentation only:
// they keep their board state themselves and persist it through FileView.
Singleton {
    id: root

    readonly property var games: ["apolloku", "chess"]

    // "apolloku", "chess", or "" for none. Opening one replaces the other so
    // the two never overlap.
    property string activeGame: ""
    property string targetScreenName: ""

    // Saves live next to config.json, where the standalone widgets kept them,
    // so an existing game and its stats carry over.
    readonly property string saveDir: Paths.configHome
    property bool storeReady: false

    readonly property string chessUsername: PersonalizationConfig.chessUsername
    readonly property bool ratingsEnabled: ChessModel.validUsername(root.chessUsername)
    property var chessStats: ChessModel.emptyChessStats()
    property bool ratingsTried: false
    property var ratingsRequest: null

    function isGame(name) {
        return root.games.indexOf(String(name || "")) !== -1;
    }

    // `screen` is optional: a click in a bar passes its own output, IPC opens
    // on the focused one.
    function open(name, screen) {
        if (!root.isGame(name))
            return false;

        screen = screen || Brightness.getScreenByName(Niri.currentOutput) || Quickshell.screens[0];
        if (!screen || !screen.name)
            return false;

        WidgetState.closeAllPopups();
        root.targetScreenName = screen.name;
        root.activeGame = name;
        return true;
    }

    function close() {
        if (root.activeGame === "")
            return false;

        root.activeGame = "";
        return true;
    }

    function toggle(name, screen) {
        if (!root.isGame(name))
            return false;

        return root.activeGame === name ? !root.close() : root.open(name, screen);
    }

    // The username is validated before it is put in the URL, so a hostile
    // config value cannot address a different endpoint.
    function fetchRatings() {
        if (!root.ratingsEnabled || root.ratingsRequest)
            return;

        const request = new XMLHttpRequest();
        root.ratingsRequest = request;
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE || root.ratingsRequest !== request)
                return;

            root.ratingsRequest = null;
            root.chessStats = request.status === 200 ? ChessModel.parseChessStats(request.responseText) :
                                                       ChessModel.emptyChessStats();
            root.ratingsTried = true;
        };
        request.open("GET", "https://api.chess.com/pub/player/" + root.chessUsername + "/stats");
        request.send();
    }

    onChessUsernameChanged: {
        root.ratingsRequest = null;
        root.chessStats = ChessModel.emptyChessStats();
        root.ratingsTried = false;
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.activeGame === "chess" && root.ratingsEnabled
        triggeredOnStart: true
        onTriggered: root.fetchRatings()
    }

    Process {
        command: ["mkdir", "-p", root.saveDir]
        running: true
        onExited: root.storeReady = true
    }

    IpcHandler {
        target: "games"

        function open(name: string): string {
            if (!root.isGame(name))
                return "INVALID_GAME";
            return root.open(name) ? "OPEN" : "UNAVAILABLE";
        }

        function toggle(name: string): string {
            if (!root.isGame(name))
                return "INVALID_GAME";
            return root.toggle(name) ? "OPEN" : "CLOSED";
        }

        function close(): string {
            return root.close() ? "CLOSED" : "NOT_OPEN";
        }
    }
}
