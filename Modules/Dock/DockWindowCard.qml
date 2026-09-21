pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Clavis.WindowPreview
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    required property var windowData
    property string applicationName: ""
    property string applicationIcon: ""
    property bool showThumbnail: false
    property WindowCaptureProbe capture: null
    readonly property string title: String(windowData && (windowData.title || windowData.appName
                                                          || windowData.appId) || applicationName)
    readonly property bool hasFrame: !!capture && capture.active && capture.frameCount > 0
    readonly property bool busy: !!capture && !hasFrame && capture.error === ""

    signal activated
    signal closeRequested

    height: showThumbnail ? 42 + (width - 8) / 1.6 : 58
    radius: Appearance.rounding.small
    color: windowData && windowData.isFocused ? Appearance.colors.colSecondaryContainer :
                                                Appearance.colors.colSurfaceContainerHigh

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: root.showThumbnail ? 34 : 50
            Layout.maximumHeight: Layout.preferredHeight
            spacing: 0
            RippleButton {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.fillHeight: true
                buttonRadius: Appearance.rounding.small
                Accessible.name: root.title
                onClicked: root.activated()
                contentItem: Text {
                    text: root.title
                    textFormat: Text.PlainText
                    font.family: Fonts.ui
                    font.pixelSize: 12
                    color: Appearance.colors.colOnSurface
                    wrapMode: root.showThumbnail ? Text.NoWrap : Text.Wrap
                    maximumLineCount: root.showThumbnail ? 1 : 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
            IconButton {
                controlSize: 28
                iconSize: 16
                iconName: "close"
                accessibleName: qsTr("Close window")
                onClicked: root.closeRequested()
            }
        }
        RippleButton {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            Layout.preferredHeight: (root.width - 8) / 1.6
            visible: root.showThumbnail
            padding: 0
            buttonRadius: Appearance.rounding.small
            Accessible.name: root.title
            onClicked: root.activated()
            contentItem: Item {
                CaptureImage {
                    anchors.fill: parent
                    capture: root.capture
                    visible: root.hasFrame
                }
                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 8
                    visible: !root.hasFrame && !root.busy
                    ThemeIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 32
                        height: 32
                        iconSource: ApplicationService.iconSource(root.applicationIcon)
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        width: parent.width
                        text: qsTr("Preview unavailable")
                        textFormat: Text.PlainText
                        font.family: Fonts.ui
                        font.pixelSize: 11
                        color: Appearance.colors.colOnSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
                InlineBusyIndicator {
                    anchors.centerIn: parent
                    busy: root.busy
                }
            }
        }
    }
}
