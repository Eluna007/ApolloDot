import QtQuick
import Quickshell
import qs.Services

// A single instance of each game, moved to the output it is opened on. One
// window per output would give every monitor its own board, all writing the
// same save file.
Scope {
    id: root

    readonly property var targetScreen: Brightness.getScreenByName(GameService.targetScreenName)
                                        || Quickshell.screens[0] || null

    ApollokuWindow {
        targetScreen: root.targetScreen
    }

    ChessWindow {
        targetScreen: root.targetScreen
    }
}
