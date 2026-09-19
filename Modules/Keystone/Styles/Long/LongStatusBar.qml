pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Modules.Keystone.ClockContent

Item {
    id: root

    required property var screen
    required property string edge
    readonly property string popupEdge: edge
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool clockHovered: clockHover.hovered
    readonly property bool hovered: mainHover.hovered
    readonly property alias clockItem: clock

    signal clockClicked(int button)
    signal mediaRequested

    HoverHandler {
        id: mainHover
    }

    ClockContent {
        id: clock
        anchors.centerIn: parent
        width: root.vertical ? 42 : 220
        height: root.vertical ? 220 : 42
        edge: root.edge
        player: MediaManager.active

        HoverHandler {
            id: clockHover
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => root.clockClicked(mouse.button)
        }
    }

    StatusLane {
        items: PersonalizationConfig.keystoneLongLeading
        x: root.vertical ? 0 : 16
        y: root.vertical ? 16 : 0
        width: root.vertical ? root.width : Math.max(0, clock.x - 28)
        height: root.vertical ? Math.max(0, clock.y - 28) : root.height
    }

    StatusLane {
        items: PersonalizationConfig.keystoneLongTrailing
        x: root.vertical ? 0 : clock.x + clock.width + 12
        y: root.vertical ? clock.y + clock.height + 12 : 0
        width: root.vertical ? root.width : Math.max(0, root.width - x - 16)
        height: root.vertical ? Math.max(0, root.height - y - 16) : root.height
        trailing: true
    }

    component StatusLane: Flickable {
        id: lane
        required property var items
        property bool trailing: false
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: root.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        contentWidth: root.vertical ? width : Math.max(width, itemsLayout.implicitWidth)
        contentHeight: root.vertical ? Math.max(height, itemsLayout.implicitHeight) : height

        GridLayout {
            id: itemsLayout
            x: root.vertical ? (lane.width - width) / 2 : lane.trailing ? Math.max(0, lane.width - width) : 0
            y: root.vertical ? (lane.trailing ? Math.max(0, lane.height - height) : 0) : (lane.height - height)
                               / 2
            columns: root.vertical ? 1 : Math.max(1, lane.items.length)
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: lane.items
                delegate: Loader {
                    id: statusLoader
                    required property string modelData
                    Layout.alignment: Qt.AlignCenter
                    sourceComponent: modelData === "workspaces" ? workspaces : status

                    Component {
                        id: workspaces
                        LongWorkspaces {
                            screen: root.screen
                            vertical: root.vertical
                        }
                    }

                    Component {
                        id: status
                        LongStatusItem {
                            itemId: statusLoader.modelData
                            ownerId: "keystone-long:" + String(root.screen ? root.screen.name : "default") + (
                                         lane.trailing ? ":trailing" : ":leading")
                            screen: root.screen
                            onMediaRequested: root.mediaRequested()
                        }
                    }
                }
            }
        }
    }
}
