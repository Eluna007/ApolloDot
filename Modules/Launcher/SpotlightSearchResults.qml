import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root
    required property SpotlightStyle style
    required property var results
    required property int selectedIndex
    property string error: ""
    readonly property real rowsHeight: results.reduce((height, row) => height + style.resultRowHeight + (
                                                                           row.groupTitle ? 28 : 0) + (
                                                                           row.separator ? 12 : 0), 0) + (
                                           error ? 32 : 0)
    signal selectionRequested(int index)
    signal activationRequested(string id)

    Text {
        id: errorLabel
        width: parent.width
        height: visible ? 32 : 0
        visible: root.error !== ""
        text: root.error
        textFormat: Text.PlainText
        color: Appearance.colors.colError
        font.family: Fonts.ui
        font.pixelSize: 13
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
    ListView {
        id: list
        anchors.top: errorLabel.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        model: root.results
        currentIndex: root.selectedIndex
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        highlight: Item {}
        highlightMoveDuration: root.style.resultScrollDuration
        highlightMoveVelocity: -1
        ScrollBar.vertical: StyledScrollBar {}
        WheelScrollController {
            flickable: list
        }

        delegate: Item {
            id: row
            required property int index
            required property var modelData
            width: ListView.view.width
            height: root.style.resultRowHeight + header.height + separator.height
            Text {
                id: header
                x: 12
                width: parent.width - 24
                height: row.modelData.groupTitle ? 28 : 0
                visible: height > 0
                text: row.modelData.groupTitle || ""
                textFormat: Text.PlainText
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            Item {
                id: separator
                y: header.height
                width: parent.width
                height: row.modelData.separator ? 12 : 0
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    width: parent.width - 24
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                    visible: parent.height > 0
                }
            }
            Rectangle {
                id: surface
                y: header.height + separator.height
                width: parent.width
                height: root.style.resultRowHeight
                radius: Metrics.cornerM
                color: row.index === root.selectedIndex ? root.style.selectedColor : mouse.containsMouse
                                                          ? root.style.hoverColor : "transparent"
                Item {
                    id: icon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.style.resultIconSize
                    height: width
                    Image {
                        id: artwork
                        anchors.fill: parent
                        source: row.modelData.iconKind === "app" ? ApplicationService.iconSource(
                                                                       row.modelData.appIcon) :
                                                                   row.modelData.iconKind === "wallpaper"
                                                                   ? row.modelData.previewUrl : ""
                        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                        asynchronous: true
                        retainWhileLoading: false
                        currentFrame: 0
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !artwork.visible
                        text: row.modelData.symbol || "apps"
                        iconSize: 28
                        color: row.index === root.selectedIndex ? root.style.selectedContentColor :
                                                                  Appearance.colors.colOnSurfaceVariant
                    }
                }
                Column {
                    x: icon.x + icon.width + 12
                    width: parent.width - x - 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: parent.width
                        text: row.modelData.title
                        textFormat: Text.PlainText
                        font.family: Fonts.ui
                        font.pixelSize: 15
                        color: row.index === root.selectedIndex ? root.style.selectedContentColor :
                                                                  Appearance.colors.colOnSurface
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.subtitle || ""
                        textFormat: Text.PlainText
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        color: Appearance.colors.colOnSurfaceVariant
                        elide: Text.ElideMiddle
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: row.modelData.title
                    Accessible.description: row.modelData.subtitle || ""
                    onPressed: root.selectionRequested(row.index)
                    onClicked: root.activationRequested(row.modelData.id)
                    Accessible.onPressAction: root.activationRequested(row.modelData.id)
                }
            }
        }
    }
}
