import QtQuick

StyledFlickable {
    id: root

    property bool motionEnabled: true
    property bool refreshEnabled: false
    property bool refreshing: false
    property real refreshThreshold: 64
    property bool refreshTriggered: false
    property real manualPullDistance: 0
    property bool manualDragging: false
    readonly property bool gestureDragging: dragging || manualDragging
    readonly property real pullDistance: motionEnabled ? Math.max(0, -verticalOvershoot, manualPullDistance) :
                                                         0
    // One eased distance drives both content and its allocated space. Separate
    // delayed transforms let later cards collide with earlier ones during a pull.
    property real pullOffset: 104 * (1 - Math.exp(-pullDistance / 104))
    readonly property real sectionExpansion: pullOffset * 0.12
    readonly property real detailExpansion: pullOffset * 0.045
    property real refreshHeaderHeight: motionEnabled && (refreshEnabled || refreshing) ? 80
                                                                                         * indicatorProgress :
                                                                                         0
    readonly property real contentTopInset: refreshHeaderHeight + pullOffset * 0.25

    function gapFor(order, strength = 1) {
        return sectionExpansion * strength * (1 + Math.min(12, Math.max(0, order)) * 0.16);
    }

    Behavior on pullOffset {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    Behavior on refreshHeaderHeight {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }
    readonly property real indicatorProgress: refreshing ? 1 : Math.min(1, pullDistance / refreshThreshold)
    signal refreshRequested

    flickableDirection: Flickable.VerticalFlick
    boundsMovement: motionEnabled ? Flickable.StopAtBounds : Flickable.FollowBoundsBehavior

    // The gesture owns one request, even if a fast response arrives while the
    // pointer is still down. Wheel scrolling never requests a refresh.
    onGestureDraggingChanged: {
        if (gestureDragging)
            refreshTriggered = false;
    }
    onPullDistanceChanged: {
        if (gestureDragging && refreshEnabled && !refreshing && !refreshTriggered && pullDistance
                >= refreshThreshold) {
            refreshTriggered = true;
            refreshRequested();
        }
    }

    // This header lives in the scroll content. Consumers include contentTopInset
    // in both their content position and height, so it never covers a card.
    Item {
        width: root.width
        height: root.refreshHeaderHeight
        clip: true
        visible: height > 0

        MaterialLoadingIndicator {
            anchors.centerIn: parent
            scale: Math.min(1, parent.height / implicitHeight)
            opacity: scale
            running: root.refreshing && visible
            animationProgress: root.refreshing ? 0 : root.indicatorProgress * 0.25
            accessibleName: qsTr("Refreshing")
        }
    }
}
