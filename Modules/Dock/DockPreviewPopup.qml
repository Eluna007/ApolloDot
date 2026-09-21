pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    required property string entryKey
    required property real maximumWidth
    property bool contextMenu: false
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
    readonly property var captureTargets: {
        if (!visible || !thumbnails || WindowPreviewService.suspended)
            return [];
        const left = windowStrip.contentX;
        const right = left + windowStrip.width;
        const ids = [];
        for (let i = 0; i < windows.length; ++i) {
            const start = i * (cardWidth + 6);
            if (start < right && start + cardWidth > left)
                ids.push(String(windows[i].id));
        }
        return ids;
    }
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

    readonly property real widthLimit: Math.max(0, maximumWidth)
    readonly property real contentMargin: Math.min(12, widthLimit / 4)
    readonly property real cardWidth: {
        const available = Math.max(0, widthLimit - contentMargin * 2);
        const gaps = Math.max(0, windows.length - 1) * 6;
        const fitted = (available - gaps) / Math.max(1, windows.length);
        const preferred = thumbnails ? DockService.previewSize * 1.6 + 8 : 220;
        return Math.min(available, Math.min(preferred, Math.max(thumbnails ? 160 : 130, fitted)));
    }

    signal dismissed

    width: Math.min(widthLimit, Math.max(240, windows.length * cardWidth + Math.max(0, windows.length - 1) * 6
                                         + contentMargin * 2))
    height: content.implicitHeight + contentMargin * 2
    clip: true
    radius: Appearance.rounding.large
    color: Appearance.colors.colSurfaceContainer
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    onEntryKeyChanged: windowStrip.contentX = 0

    HoverHandler {
        id: popupHover
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.contentMargin
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.entry && root.entry.kind === "separator" ? qsTr("Separator") : root.entryName
                textFormat: Text.PlainText
                font.family: Fonts.ui
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
                elide: Text.ElideRight
            }
            IconButton {
                visible: root.contextMenu
                controlSize: 28
                iconSize: 18
                iconName: "close"
                accessibleName: qsTr("Close menu")
                onClicked: root.dismissed()
            }
        }
        // Keep previews in one row, scrolling when further shrinking harms readability.
        Flickable {
            id: windowStrip
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: windowRow.implicitHeight + (contentWidth > width
                                                                ? stripScroll.implicitHeight : 0)
            visible: root.windows.length > 0
            contentWidth: windowRow.implicitWidth
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            function clampPosition() {
                contentX = Math.max(0, Math.min(Math.max(0, contentWidth - width), contentX));
            }

            onContentWidthChanged: clampPosition()
            onWidthChanged: clampPosition()
            ScrollBar.horizontal: StyledScrollBar {
                id: stripScroll
            }
            Row {
                id: windowRow
                spacing: 6
                Repeater {
                    model: root.windows
                    delegate: DockWindowCard {
                        required property var modelData
                        windowData: modelData
                        applicationName: root.entryName
                        applicationIcon: String(root.entry && root.entry.icon || "")
                        width: root.cardWidth
                        showThumbnail: root.thumbnails
                        capture: {
                            const revision = WindowPreviewService.revision;
                            return root.visible && root.thumbnails ? WindowPreviewService.captureFor(
                                                                         modelData.id) : null;
                        }
                        onActivated: {
                            DockService.focusWindow(modelData.id);
                            root.dismissed();
                        }
                        onCloseRequested: DockService.closeWindow(modelData.id)
                    }
                }
            }
            WheelHandler {
                target: null
                onWheel: event => {
                    const delta = event.pixelDelta.x || event.pixelDelta.y || event.angleDelta.x
                          || event.angleDelta.y;
                    windowStrip.contentX = Math.max(0, Math.min(windowStrip.contentWidth - windowStrip.width,
                                                                windowStrip.contentX - delta));
                    event.accepted = true;
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: !!root.entry && root.entry.kind === "app" && !root.entry.available
                     && root.windows.length === 0
            text: qsTr("Application is unavailable")
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Fonts.ui
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: root.contextMenu
            spacing: 0
            SettingsActionRow {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: Metrics.controlHeightM
                visible: root.canLaunch
                text: qsTr("Open application")
                iconName: "open_in_new"
                trailingIconName: ""
                onClicked: {
                    if (!root.canLaunch)
                        return;
                    DockService.launch(root.entryKey);
                    root.dismissed();
                }
            }
            SettingsActionRow {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: Metrics.controlHeightM
                visible: root.canChangePin
                text: root.entry && root.entry.pinned ? qsTr("Remove from Dock") : qsTr("Pin to Dock")
                iconName: root.entry && root.entry.pinned ? "keep_off" : "keep"
                trailingIconName: ""
                onClicked: {
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
            SettingsActionRow {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: Metrics.controlHeightM
                text: qsTr("Dock settings")
                iconName: "settings"
                trailingIconName: ""
                onClicked: {
                    ControlCenterService.openSearch("general.dock");
                    root.dismissed();
                }
            }
        }
    }
}
