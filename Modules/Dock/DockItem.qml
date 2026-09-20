import QtQuick
import qs.Common
import qs.Components
import qs.Services

Item {
    id: root

    required property string entryKey
    required property string kind
    required property string name
    required property string icon
    required property string symbol
    required property bool pinned
    required property bool focused
    required property bool launching
    required property bool available
    required property int windowCount
    required property string edge
    required property real iconSize
    required property real restingIconSize
    property bool dragged: false
    property real presence: 1
    readonly property bool horizontal: edge === "bottom"
    property real bounce: 0
    property bool moved: false
    property point pressPoint
    property point grabOffset

    signal hovered(string key)
    signal pressStarted
    signal activated(string key)
    signal contextRequested(string key)
    signal dragMoved(string key, point position, point offset, real size)
    signal dragReleased(string key, point position)
    signal dragCancelled

    opacity: dragged ? 0 : presence

    Behavior on iconSize {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation on bounce {
        running: root.launching && DockService.launchBounce && root.kind === "app"
        loops: Animation.Infinite
        NumberAnimation {
            to: 19
            duration: 260
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            to: 0
            duration: 340
            easing.type: Easing.OutBounce
        }
        PauseAnimation {
            duration: 200
        }
        onStopped: root.bounce = 0
    }

    Item {
        id: artwork
        width: root.iconSize
        height: width
        x: root.horizontal ? (root.width - width) / 2 : root.edge === "left" ? 10 + root.bounce : root.width
                                                                               - width - 10 - root.bounce
        y: root.horizontal ? root.height - height - 12 - root.bounce : (root.height - height) / 2
        scale: pointer.pressed && !root.moved ? 0.92 : 0.94 + 0.06 * root.presence
        transform: Translate {
            x: root.horizontal ? 0 : (root.edge === "left" ? -1 : 1) * (1 - root.presence) * 6
            y: root.horizontal ? (1 - root.presence) * 6 : 0
        }
        opacity: root.available || root.windowCount > 0 || root.kind === "separator" ? 1 : 0.45
        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Image {
            anchors.fill: parent
            visible: root.kind === "app" && !root.symbol
            source: visible ? ApplicationService.iconSource(root.icon) : ""
            sourceSize: Qt.size(160, 160)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.kind === "app" && !!root.symbol
            text: root.symbol
            iconSize: root.iconSize * 0.82
            color: Appearance.colors.colPrimary
        }
    }

    Rectangle {
        visible: root.kind === "separator"
        anchors.centerIn: parent
        width: root.horizontal ? 2 : Math.min(32, root.width / 2)
        height: root.horizontal ? Math.min(32, root.height / 2) : 2
        radius: 1
        color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.4)
    }
    Rectangle {
        visible: root.kind === "app" && root.windowCount > 0 && DockService.showIndicators
        // Scale with the resting icons, so hover magnification does not pulse the dot.
        width: Math.round(Math.max(5, Math.min(8, root.restingIconSize / 8)))
        height: width
        radius: width / 2
        x: root.horizontal ? (root.width - width) / 2 : root.edge === "left" ? 8 - width : root.width - 8
        y: root.horizontal ? root.height - 10 : (root.height - height) / 2
        color: Appearance.applyAlpha(Appearance.colors.colOnSurface, root.focused ? 1 : 0.8)
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: root.kind === "separator" ? qsTr("Separator") : root.name
        Accessible.onPressAction: root.activated(root.entryKey)
        onEntered: root.hovered(root.entryKey)
        onPressed: mouse => {
            root.pressStarted();
            root.moved = false;
            root.pressPoint = root.mapToItem(null, mouse.x, mouse.y);
            const center = artwork.mapToItem(null, artwork.width / 2, artwork.height / 2);
            root.grabOffset = Qt.point(root.pressPoint.x - center.x, root.pressPoint.y - center.y);
        }
        onPositionChanged: mouse => {
            if (!(pressedButtons & Qt.LeftButton))
                return;
            const position = root.mapToItem(null, mouse.x, mouse.y);
            if (!root.moved && Math.hypot(position.x - root.pressPoint.x, position.y - root.pressPoint.y)
                    < 10)

                return;
            root.moved = true;
            root.dragMoved(root.entryKey, position, root.grabOffset, root.iconSize);
        }
        onReleased: mouse => {
            if (root.moved)
                root.dragReleased(root.entryKey, root.mapToItem(null, mouse.x, mouse.y));
        }
        onCanceled: {
            root.moved = true;
            root.dragCancelled();
        }
        onClicked: mouse => {
            if (root.moved)
                return;
            if (mouse.button === Qt.RightButton)
                root.contextRequested(root.entryKey);
            else
                root.activated(root.entryKey);
        }
        onPressAndHold: {
            if (!root.moved)
                root.contextRequested(root.entryKey);
        }
    }
}
