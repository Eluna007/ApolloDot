pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../Common/functions/DockLayout.js" as DockLayout

PanelWindow {
    id: root

    required property string edge
    readonly property bool horizontal: edge === "bottom"
    readonly property real axisLength: horizontal ? width : height
    readonly property real availableLength: Math.max(80, axisLength - 32)
    readonly property real edgeOffset: 8
    readonly property var kinds: {
        const revision = DockService.revision;
        const result = [];
        for (let i = 0; i < DockService.model.count; ++i)
            result.push(DockService.model.get(i).kind);
        return result;
    }
    readonly property real magnification: DockService.magnification ? DockService.magnificationScale : 1
    readonly property var baseLayout: DockLayout.layout(kinds, DockService.iconSize, availableLength,
                                                        magnification, DockService.separatorSize, NaN)
    readonly property real scrollOffset: horizontal ? icons.contentX - icons.originX : icons.contentY
                                                      - icons.originY
    readonly property real pointerInBase: pointerAxis - (axisLength - Math.min(baseLayout.baseLength,
                                                                               availableLength)) / 2
                                          + scrollOffset
    readonly property var layout: DockLayout.layout(kinds, DockService.iconSize, availableLength,
                                                    magnification, DockService.separatorSize,
                                                    bandHover.hovered && !dragKey && !dropArea.containsDrag
                                                    ? pointerInBase : NaN)
    readonly property real bandLength: Math.min(availableLength, Math.max(96, layout.length))
    readonly property real bandThickness: baseLayout.size * magnification + 36
    readonly property real restingThickness: baseLayout.size + 22
    readonly property bool shown: !DockService.autoHide || revealed || DockService.externalDragActive
                                  || dragKey !== "" || popupKey !== ""
    readonly property bool interacting: bandHover.hovered || edgeHover.hovered || popup.hovered
                                        || dropArea.containsDrag || dragKey !== ""
                                        || DockService.externalDragActive
    property bool revealed: false
    property real pointerAxis: 0
    property string hoverKey: ""
    property string pendingPopupKey: ""
    property string popupKey: ""
    property bool contextMenu: false
    property real popupAxis: axisLength / 2
    property string dragKey: ""
    property bool dragCancelled: false
    property point dragPoint: Qt.point(0, 0)
    property point dropPoint: Qt.point(0, 0)
    property int insertion: -1
    readonly property var draggedEntry: {
        const revision = DockService.revision;
        return DockService.entryFor(dragKey);
    }
    readonly property bool removeOnRelease: !!draggedEntry && draggedEntry.pinned
                                            && DockLayout.removalDistance(edge, dragPoint.x, dragPoint.y,
                                                                          width, height, edgeOffset)
                                            > bandThickness + 48

    function updateInteraction() {
        if (interacting) {
            revealed = true;
            hideTimer.stop();
            closeTimer.stop();
        } else {
            if (revealed || popupKey)
                hideTimer.restart();
            if (popupKey)
                closeTimer.restart();
            hoverTimer.stop();
        }
    }
    function hoverEntry(key) {
        if (dragKey || DockService.externalDragActive || contextMenu)
            return;
        hoverKey = key;
        pendingPopupKey = key;
        hoverTimer.restart();
    }
    function showPopup(key, context) {
        hoverTimer.stop();
        popupAxis = pointerAxis;
        popupKey = key;
        contextMenu = context;
        if (context)
            content.forceActiveFocus();
    }
    function dismissPopup() {
        popupKey = "";
        contextMenu = false;
        hoverTimer.stop();
        updateInteraction();
    }
    function insertionAt(point) {
        const local = icons.mapFromItem(content, point.x, point.y);
        return DockLayout.insertionIndex(layout.slots, (horizontal ? local.x : local.y) + scrollOffset);
    }
    function moveDrag(key, point) {
        if (dragCancelled)
            return;
        if (dragKey !== key) {
            dragKey = key;
            dismissPopup();
            content.forceActiveFocus();
        }
        dragPoint = point;
        insertion = insertionAt(point);
        revealed = true;
    }
    function finishDrag(key, point) {
        if (dragCancelled || dragKey !== key) {
            cancelDrag();
            dragCancelled = false;
            return;
        }
        dragPoint = point;
        const entry = DockService.entryFor(key);
        if (removeOnRelease)
            DockService.unpin(key);
        else if (entry && DockLayout.removalDistance(edge, point.x, point.y, width, height, edgeOffset)
                 <= bandThickness + 24) {
            const target = insertionAt(point);
            if (entry.pinned)
                DockService.movePinned(key, target);
            else if (entry.desktopId)
                DockService.pin(entry.desktopId, target);
        }
        cancelDrag();
        dragCancelled = false;
    }
    function cancelDrag() {
        dragKey = "";
        insertion = -1;
        updateInteraction();
    }
    function scrollBy(amount) {
        if (horizontal)
            icons.contentX = Math.max(icons.originX, Math.min(icons.originX + Math.max(0, icons.contentWidth
                                                                                       - icons.width),
                                                              icons.contentX + amount));
        else
            icons.contentY = Math.max(icons.originY, Math.min(icons.originY + Math.max(0, icons.contentHeight
                                                                                       - icons.height),
                                                              icons.contentY + amount));
    }

    // The surface supplies animation/drag space; only the visible interaction
    // regions accept input. Its exclusive zone is always the resting dock.
    implicitWidth: screen ? screen.width : 1280
    implicitHeight: screen ? screen.height : 720
    color: "transparent"
    anchors.left: horizontal || edge === "left"
    anchors.right: horizontal || edge === "right"
    anchors.top: !horizontal
    anchors.bottom: true
    exclusiveZone: DockService.autoHide ? 0 : restingThickness + edgeOffset
    WlrLayershell.namespace: "clavis-shell-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: dragKey || contextMenu ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onInteractingChanged: updateInteraction()
    onShownChanged: {
        if (!shown)
            dismissPopup();
    }

    Timer {
        id: hideTimer
        interval: 650
        onTriggered: {
            if (!root.interacting) {
                root.revealed = false;
                root.dismissPopup();
            }
        }
    }
    Timer {
        id: closeTimer
        interval: 350
        onTriggered: {
            if (!root.interacting)
                root.dismissPopup();
        }
    }
    Timer {
        id: hoverTimer
        interval: 450
        onTriggered: {
            if (bandHover.hovered && !root.dragKey)
                root.showPopup(root.pendingPopupKey, false);
        }
    }
    Timer {
        interval: 40
        repeat: true
        running: (root.dragKey !== "" || dropArea.containsDrag) && root.layout.overflow
        onTriggered: {
            const position = root.dragKey ? root.dragPoint : root.dropPoint;
            const local = icons.mapFromItem(content, position.x, position.y);
            const coordinate = root.horizontal ? local.x : local.y;
            if (coordinate < 28)
                root.scrollBy(-12);
            else if (coordinate > root.bandLength - 28)
                root.scrollBy(12);
        }
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: event => {
            root.dragCancelled = true;
            root.cancelDrag();
            root.dismissPopup();
            event.accepted = true;
        }

        Item {
            id: edgeTrigger
            width: root.horizontal ? Math.max(96, Math.min(root.availableLength, root.baseLayout.baseLength)) :
                                     3
            height: root.horizontal ? 3 : Math.max(96, Math.min(root.availableLength,
                                                                root.baseLayout.baseLength))
            x: root.horizontal ? (parent.width - width) / 2 : root.edge === "left" ? 0 : parent.width - width
            y: root.horizontal ? parent.height - height : (parent.height - height) / 2
            HoverHandler {
                id: edgeHover
                onHoveredChanged: {
                    if (hovered)
                        root.revealed = true;
                }
            }
            DropArea {
                anchors.fill: parent
                onEntered: drag => {
                    if (drag.formats.indexOf("application/x-clavis-dock") >= 0 || drag.hasUrls) {
                        root.revealed = true;
                        drag.accepted = true;
                    } else {
                        drag.accepted = false;
                    }
                }
            }
        }

        Item {
            id: band
            width: root.horizontal ? root.bandLength : root.bandThickness
            height: root.horizontal ? root.bandThickness : root.bandLength
            x: root.horizontal ? (parent.width - width) / 2 : root.edge === "left" ? root.edgeOffset :
                                                                                     parent.width - width
                                                                                     - root.edgeOffset
            y: root.horizontal ? parent.height - height - root.edgeOffset : (parent.height - height) / 2
            opacity: root.shown ? 1 : 0
            visible: opacity > 0
            enabled: root.shown
            // Animate the centered tray with its slots, including app arrival
            // and removal; otherwise its origin would jump by half an icon.
            Behavior on width {
                enabled: root.horizontal
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: !root.horizontal
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            transform: Translate {
                x: root.horizontal ? 0 : root.shown ? 0 : root.edge === "left" ? -band.width
                                                                                 - root.edgeOffset :
                                                                                 band.width + root.edgeOffset
                y: root.horizontal && !root.shown ? band.height + root.edgeOffset : 0
                Behavior on x {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            HoverHandler {
                id: bandHover
                onPointChanged: root.pointerAxis = root.horizontal ? band.x + point.position.x : band.y
                                                                     + point.position.y
            }

            Rectangle {
                id: glass
                x: root.horizontal ? 0 : root.edge === "left" ? 0 : parent.width - width
                y: root.horizontal ? parent.height - height : 0
                width: root.horizontal ? parent.width : root.restingThickness
                height: root.horizontal ? root.restingThickness : parent.height
                radius: 20
                color: Appearance.applyAlpha(Appearance.colors.colSurfaceContainer, 0.9)
                border.color: Appearance.applyAlpha(Appearance.colors.colOutlineVariant, 0.65)
                border.width: 1
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: {
                        const entry = DockService.model.count ? DockService.model.get(0) : null;
                        if (entry)
                            root.showPopup(entry.key, true);
                        else
                            ControlCenterService.openSearch("general.dock");
                    }
                }
            }

            ListView {
                id: icons
                anchors.fill: parent
                orientation: root.horizontal ? ListView.Horizontal : ListView.Vertical
                model: DockService.model
                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                header: Item {
                    width: 12
                    height: 12
                }
                footer: Item {
                    width: 12
                    height: 12
                }
                cacheBuffer: 200

                delegate: DockItem {
                    id: dockItem
                    required property int index
                    required property string key
                    // Other roles bind through required properties on DockItem.
                    entryKey: key
                    edge: root.edge
                    property var lastSlot: ({
                                                span: 0,
                                                size: root.baseLayout.size
                                            })
                    readonly property var slot: root.layout.slots[index] || lastSlot
                    onSlotChanged: {
                        if (index >= 0)
                            lastSlot = slot;
                    }
                    width: root.horizontal ? slot.span * presence : icons.width
                    height: root.horizontal ? icons.height : slot.span * presence
                    iconSize: slot.size
                    dragged: root.dragKey === key
                    onPressStarted: root.dragCancelled = false
                    onHovered: key => root.hoverEntry(key)
                    onActivated: key => {
                        root.dragCancelled = false;
                        DockService.activate(key);
                        root.dismissPopup();
                    }
                    onContextRequested: key => root.showPopup(key, true)
                    onDragMoved: (key, position) => root.moveDrag(key, position)
                    onDragReleased: (key, position) => root.finishDrag(key, position)
                    onDragCancelled: {
                        root.cancelDrag();
                        root.dragCancelled = false;
                    }
                    ListView.onAdd: enterAnimation.start()
                    ListView.onRemove: exitAnimation.start()
                    NumberAnimation {
                        id: enterAnimation
                        target: dockItem
                        property: "presence"
                        from: 0
                        to: 1
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                    SequentialAnimation {
                        id: exitAnimation
                        PropertyAction {
                            target: dockItem
                            property: "ListView.delayRemove"
                            value: true
                        }
                        NumberAnimation {
                            target: dockItem
                            property: "presence"
                            to: 0
                            duration: 180
                            easing.type: Easing.InCubic
                        }
                        PropertyAction {
                            target: dockItem
                            property: "ListView.delayRemove"
                            value: false
                        }
                    }
                    Behavior on width {
                        enabled: root.horizontal && !exitAnimation.running
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on height {
                        enabled: !root.horizontal && !exitAnimation.running
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                ScrollBar.horizontal: StyledScrollBar {
                    visible: root.horizontal && root.layout.overflow
                }
                ScrollBar.vertical: StyledScrollBar {
                    visible: !root.horizontal && root.layout.overflow
                }
                WheelHandler {
                    onWheel: event => {
                        root.scrollBy(-(event.angleDelta.y || event.angleDelta.x));
                        event.accepted = true;
                    }
                }
            }

            DropArea {
                id: dropArea
                anchors.fill: parent
                onEntered: drag => {
                    // MIME contents are only guaranteed on drop for foreign
                    // clients. Validation happens before any pin is persisted.
                    drag.accepted = drag.formats.indexOf("application/x-clavis-dock") >= 0 || drag.hasUrls;
                    if (drag.accepted) {
                        root.dismissPopup();
                        root.revealed = true;
                        root.dropPoint = band.mapToItem(content, drag.x, drag.y);
                        root.insertion = root.insertionAt(root.dropPoint);
                    }
                }
                onPositionChanged: drag => {
                    root.dropPoint = band.mapToItem(content, drag.x, drag.y);
                    root.insertion = root.insertionAt(root.dropPoint);
                }
                onExited: root.insertion = -1
                onDropped: drop => {
                    const text = drop.getDataAsString("application/x-clavis-dock");
                    if (DockService.acceptDrop(text, drop.urls, root.insertion))
                        drop.accept(Qt.CopyAction);
                    root.insertion = -1;
                    root.updateInteraction();
                }
            }

            Rectangle {
                readonly property real coordinate: root.insertion < root.layout.slots.length && root.insertion
                                                   >= 0 ? root.layout.slots[root.insertion].start :
                                                          root.layout.length - 12
                visible: root.insertion >= 0 && !root.removeOnRelease && (root.dragKey !== ""
                                                                          || dropArea.containsDrag)
                x: root.horizontal ? coordinate - root.scrollOffset : root.edge === "left" ? 8 : parent.width
                                                                                             - root.restingThickness
                                                                                             + 8
                y: root.horizontal ? parent.height - root.restingThickness + 8 : coordinate
                                     - root.scrollOffset
                width: root.horizontal ? 3 : root.restingThickness - 16
                height: root.horizontal ? root.restingThickness - 16 : 3
                radius: 2
                color: Appearance.colors.colPrimary
            }

            Text {
                anchors.centerIn: glass
                visible: DockService.model.count === 0
                text: qsTr("Drop apps here")
                font.family: Fonts.ui
                font.pixelSize: 12
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        DockPreviewPopup {
            id: popup
            visible: root.popupKey !== "" && !!entry
            entryKey: root.popupKey
            maximumWidth: root.horizontal ? Math.max(0, root.width - 32) : Math.max(0, root.width
                                                                                    - root.bandThickness - 32)
            contextMenu: root.contextMenu
            x: root.horizontal ? Math.max(16, Math.min(root.width - width - 16, root.popupAxis - width / 2)) :
                                 root.edge === "left" ? root.bandThickness + 16 : root.width
                                                        - root.bandThickness - width - 16
            y: root.horizontal ? band.y - height - 8 : Math.max(16, Math.min(root.height - height - 16,
                                                                             root.popupAxis - height / 2))
            onDismissed: root.dismissPopup()
        }

        Item {
            id: dragGhost
            visible: root.dragKey !== "" && !!root.draggedEntry
            width: root.baseLayout.size
            height: width
            x: root.dragPoint.x - width / 2
            y: root.dragPoint.y - height / 2
            opacity: 0.85
            Image {
                anchors.fill: parent
                visible: !!root.draggedEntry && root.draggedEntry.kind === "app" && !root.draggedEntry.symbol
                source: visible ? ApplicationService.iconSource(root.draggedEntry.icon) : ""
                fillMode: Image.PreserveAspectFit
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: !!root.draggedEntry && (!!root.draggedEntry.symbol || root.draggedEntry.kind
                                                 === "separator")
                text: root.draggedEntry ? root.draggedEntry.kind === "separator" ? "space_bar" :
                                                                                   root.draggedEntry.symbol :
                                                                                   ""
                iconSize: root.baseLayout.size
                color: Appearance.colors.colPrimary
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 8
                width: removeLabel.implicitWidth + 16
                height: 28
                radius: 14
                visible: root.removeOnRelease
                color: Appearance.colors.colErrorContainer
                Text {
                    id: removeLabel
                    anchors.centerIn: parent
                    text: qsTr("Remove from Dock")
                    font.family: Fonts.ui
                    font.pixelSize: 12
                    color: Appearance.colors.colOnErrorContainer
                }
            }
        }
    }

    mask: Region {
        Region {
            item: root.shown ? band : null
        }
        Region {
            item: edgeTrigger
        }
        Region {
            item: popup.visible ? popup : null
        }
    }
    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: glass
        additionalBackgroundItems: popup.visible ? [popup] : []
        blurEnabled: root.shown
        radius: 20
    }
}
