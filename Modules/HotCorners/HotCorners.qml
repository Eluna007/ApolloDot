import QtQuick
import Quickshell
import Quickshell.Wayland
import Clavis.Niri
import qs.Common
import qs.Services

Item {
    id: root

    property bool locked: false
    signal triggered(string action, string screenName)

    // The compositor owns its native corners until the user explicitly sets
    // up the managed integration. Never compete with its overview gesture.
    Variants {
        model: NiriConfigService.ready("hot-corners") ? Quickshell.screens : []

        Scope {
            id: output

            required property var modelData

            Variants {
                model: PersonalizationConfig.hotCornerIds

                PanelWindow {
                    id: corner

                    required property string modelData
                    readonly property string action: PersonalizationConfig.hotCornerActions[modelData]
                                                     || "disabled"
                    readonly property bool blocked: !Niri.connected || root.locked || (Niri.inOverview
                                                                                       && action
                                                                                       !== "overview")
                                                    || WidgetState.sidebarHasPriority(screen ? screen.name :
                                                                                               "")
                    property bool latched: false

                    screen: output.modelData
                    implicitWidth: 4
                    implicitHeight: 4
                    color: "transparent"
                    visible: action !== "disabled"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "clavis-shell-hot-corner"
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                    anchors {
                        top: corner.modelData.startsWith("top-")
                        bottom: corner.modelData.startsWith("bottom-")
                        left: corner.modelData.endsWith("-left")
                        right: corner.modelData.endsWith("-right")
                    }

                    onBlockedChanged: {
                        if (blocked && (hover.containsMouse || dwell.running))
                            latched = true;
                        dwell.stop();
                        // Occlusion can clear containsMouse without pointer
                        // motion. Only a later unblocked exit rearms this corner.
                    }
                    onActionChanged: {
                        dwell.stop();
                        latched = latched || hover.containsMouse;
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: {
                            if (corner.blocked)
                                corner.latched = true;
                            else if (!corner.latched)
                                dwell.restart();
                        }
                        onExited: {
                            dwell.stop();
                            if (!corner.blocked)
                                corner.latched = false;
                        }
                    }

                    Timer {
                        id: dwell

                        interval: 300
                        onTriggered: {
                            if (hover.containsMouse && !corner.blocked && !corner.latched) {
                                corner.latched = true;
                                root.triggered(corner.action, corner.screen.name);
                            }
                        }
                    }
                }
            }
        }
    }
}
