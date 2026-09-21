pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets.common
import "../../Common/functions/DockLayout.js" as DockLayout

Item {
    id: root

    required property string entryKey
    required property real maximumWidth
    property real maximumHeight: 600
    property bool contextMenu: false
    property string edge: "bottom"
    readonly property string popupEdge: edge
    property real anchorOffset: width / 2
    readonly property var entry: {
        const revision = DockService.revision;
        return DockService.entryFor(root.entryKey);
    }
    readonly property var windows: {
        const revision = DockService.revision;
        return DockService.windowsFor(root.entryKey);
    }
    readonly property bool hovered: popupHover.hovered
    readonly property bool thumbnails: DockService.showThumbnails && DockService.supportsThumbnails
    property string previewConsumer: ""
    readonly property var captureTargets: !visible || contextMenu || !thumbnails
                                          || WindowPreviewService.suspended ? [] : windows.map(window
                                                                                               => String(
                                                                                                      window.id))
    onCaptureTargetsChanged: WindowPreviewService.setTargets(previewConsumer, captureTargets)
    Component.onCompleted: {
        previewConsumer = WindowPreviewService.createConsumer();
        WindowPreviewService.setTargets(previewConsumer, captureTargets);
    }
    Component.onDestruction: WindowPreviewService.release(previewConsumer)
    readonly property string entryName: entry ? String(entry.name || "") : ""
    readonly property bool canLaunch: !!entry && entry.kind === "app" && entry.available && String(
                                          entry.desktopId || "").length > 0
    readonly property bool canChangePin: !!entry && (entry.pinned || (DockService.contextPinning
                                                                      && canLaunch))

    readonly property var rowLayout: DockLayout.windowPreviewRow(windows.length, thumbnails
                                                                 ? DockService.previewSize * 1.6 + 16 : 220,
                                                                 maximumWidth)
    readonly property real contentMargin: contextMenu ? 6 : rowLayout.margin

    readonly property real tailSize: contextMenu ? 10 : 0
    readonly property real bodyX: contextMenu && edge === "left" ? tailSize : 0
    readonly property real bodyWidth: width - (edge === "bottom" ? 0 : tailSize)
    readonly property real bodyHeight: (contextMenu ? menuContent.height : windowRow.height) + contentMargin
                                       * 2

    readonly property color surfaceColor: BlurService.backgroundColor(Appearance.colors.colSurfaceContainer)
    readonly property color outlineColor: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.18)

    signal dismissed

    width: contextMenu ? Math.min(Math.max(0, maximumWidth), 280) : rowLayout.width
    height: bodyHeight + (edge === "bottom" ? tailSize : 0)

    HoverHandler {
        id: popupHover
    }

    // Draw the body and offset, rounded tail as one path: no rectangle border
    // running through the pointer, and no separately composited triangle seam.
    Canvas {
        id: bubble
        anchors.fill: parent
        antialiasing: true
        readonly property real pointerPosition: root.anchorOffset
        readonly property real tail: root.tailSize
        readonly property string edge: root.edge
        readonly property color fillColor: root.surfaceColor
        readonly property color lineColor: root.outlineColor
        onPointerPositionChanged: requestPaint()
        onTailChanged: requestPaint()
        onEdgeChanged: requestPaint()
        onFillColorChanged: requestPaint()
        onLineColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const x = root.bodyX + 0.5;
            const y = 0.5;
            const right = root.bodyX + root.bodyWidth - 0.5;
            const bottom = root.bodyHeight - 0.5;
            const radius = Math.max(0, Math.min(12, (right - x) / 2, (bottom - y) / 2));
            const horizontal = edge === "bottom";
            const extent = horizontal ? root.bodyWidth : root.bodyHeight;
            const tip = Math.max(26, Math.min(extent - 26, pointerPosition));
            ctx.beginPath();
            ctx.moveTo(x + radius, y);
            ctx.lineTo(right - radius, y);
            ctx.quadraticCurveTo(right, y, right, y + radius);
            if (tail > 0 && edge === "right") {
                ctx.lineTo(right, tip - 14);
                ctx.bezierCurveTo(right, tip - 7, right + tail, tip - 5, right + tail, tip);
                ctx.bezierCurveTo(right + tail, tip + 5, right, tip + 7, right, tip + 14);
            }
            ctx.lineTo(right, bottom - radius);
            ctx.quadraticCurveTo(right, bottom, right - radius, bottom);
            if (tail > 0 && horizontal) {
                ctx.lineTo(tip + 14, bottom);
                ctx.bezierCurveTo(tip + 7, bottom, tip + 5, bottom + tail, tip, bottom + tail);
                ctx.bezierCurveTo(tip - 5, bottom + tail, tip - 7, bottom, tip - 14, bottom);
            }
            ctx.lineTo(x + radius, bottom);
            ctx.quadraticCurveTo(x, bottom, x, bottom - radius);
            if (tail > 0 && edge === "left") {
                ctx.lineTo(x, tip + 14);
                ctx.bezierCurveTo(x, tip + 7, x - tail, tip + 5, x - tail, tip);
                ctx.bezierCurveTo(x - tail, tip - 5, x, tip - 7, x, tip - 14);
            }
            ctx.lineTo(x, y + radius);
            ctx.quadraticCurveTo(x, y, x + radius, y);
            ctx.closePath();
            ctx.fillStyle = fillColor;
            ctx.fill();
            ctx.strokeStyle = lineColor;
            ctx.lineWidth = 1;
            ctx.stroke();
        }
    }

    Row {
        id: windowRow
        visible: !root.contextMenu
        x: root.bodyX + root.contentMargin
        y: root.contentMargin
        spacing: root.rowLayout.gap
        Repeater {
            model: root.contextMenu ? [] : root.windows
            delegate: DockWindowCard {
                required property var modelData
                windowData: modelData
                applicationName: root.entryName
                applicationIcon: String(root.entry && root.entry.icon || "")
                width: root.rowLayout.cardWidth
                showThumbnail: root.thumbnails
                capture: {
                    const revision = WindowPreviewService.revision;
                    return root.visible && root.thumbnails ? WindowPreviewService.captureFor(modelData.id) :
                                                             null;
                }
                onActivated: {
                    DockService.focusWindow(modelData.id);
                    root.dismissed();
                }
                onCloseRequested: DockService.closeWindow(modelData.id)
            }
        }
    }

    Column {
        id: menuContent
        visible: root.contextMenu
        x: root.bodyX + root.contentMargin
        y: root.contentMargin
        width: Math.max(0, root.bodyWidth - root.contentMargin * 2)
        spacing: 4

        Text {
            width: parent.width - 16
            x: 8
            height: 32
            visible: root.windows.length === 0
            text: root.entry && root.entry.kind === "separator" ? qsTr("Separator") : root.entryName
            textFormat: Text.PlainText
            font.family: Fonts.ui
            font.pixelSize: 12
            color: Appearance.colors.colOnSurfaceVariant
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        Flickable {
            width: parent.width
            height: Math.min(contentHeight, Math.max(32, root.maximumHeight - actions.height - 40))
            visible: root.windows.length > 0
            contentHeight: windowMenu.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StyledScrollBar {}
            Column {
                id: windowMenu
                width: parent.width
                Repeater {
                    model: root.contextMenu ? root.windows : []
                    delegate: StyledMenuItem {
                        required property var modelData
                        width: windowMenu.width
                        implicitHeight: 32
                        leftPadding: 8
                        rightPadding: 8
                        text: String(modelData.title || root.entryName)
                        checkable: true
                        checked: !!modelData.isFocused
                        onTriggered: {
                            DockService.focusWindow(modelData.id);
                            root.dismissed();
                        }
                    }
                }
            }
        }
        Rectangle {
            x: 8
            width: Math.max(0, parent.width - 16)
            height: 1
            color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.16)
        }
        Text {
            width: parent.width - 16
            x: 8
            visible: !!root.entry && root.entry.kind === "app" && !root.entry.available
                     && root.windows.length === 0
            text: qsTr("Application is unavailable")
            font.family: Fonts.ui
            font.pixelSize: 12
            color: Appearance.colors.colOnSurfaceVariant
            wrapMode: Text.Wrap
        }
        Column {
            id: actions
            width: parent.width
            StyledMenuItem {
                width: parent.width
                implicitHeight: 32
                leftPadding: 8
                rightPadding: 8
                visible: root.canLaunch
                text: qsTr("Open application")
                onTriggered: {
                    if (!root.canLaunch)
                        return;
                    DockService.launch(root.entryKey);
                    root.dismissed();
                }
            }
            StyledMenuItem {
                width: parent.width
                implicitHeight: 32
                leftPadding: 8
                rightPadding: 8
                visible: root.canChangePin
                text: root.entry && root.entry.pinned ? qsTr("Remove from Dock") : qsTr("Pin to Dock")
                onTriggered: {
                    const entry = DockService.entryFor(root.entryKey);
                    if (!entry)
                        return;
                    if (entry.pinned)
                        DockService.unpin(root.entryKey);
                    else if (root.canChangePin)
                        DockService.pin(entry.desktopId);
                    root.dismissed();
                }
            }
            StyledMenuItem {
                width: parent.width
                implicitHeight: 32
                leftPadding: 8
                rightPadding: 8
                text: qsTr("Dock settings")
                onTriggered: {
                    ControlCenterService.openSearch("general.dock");
                    root.dismissed();
                }
            }
        }
    }
}
