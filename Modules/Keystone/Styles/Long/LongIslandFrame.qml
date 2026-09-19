pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Services

Item {
    id: root

    required property var screen
    required property string edge
    required property bool expanded
    required property real targetWidth
    required property real targetHeight
    required property Item childItem
    required property Item cutoutItem
    property bool cutoutVisible: false
    property color surfaceColor: Appearance.colors.colLayer0
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real availableLength: horizontal ? screen.width : screen.height
    readonly property real length: Math.max(220, Math.min(horizontal ? 1120 : 920, availableLength - 32, Math.max(
                                                              740, availableLength * 0.84)))
    readonly property real availableChildWidth: Math.max(24, screen.width - (horizontal ? 32 : thickness + gap
                                                                                          + 24))
    readonly property real availableChildHeight: Math.max(24, screen.height - (horizontal ? thickness + gap + 24 :
                                                                                            32))
    readonly property real thickness: 42
    readonly property real gap: 18
    property real progress: expanded ? 1 : 0
    property real heldWidth: 220
    property real heldHeight: 42
    readonly property real growth: smoothStep((progress - 0.38) / 0.62)
    readonly property real childWidth: (horizontal ? 92 : 24) + (heldWidth - (horizontal ? 92 : 24)) * growth
    readonly property real childHeight: (horizontal ? 24 : 92) + (heldHeight - (horizontal ? 24 : 92))
                                        * growth
    readonly property real childOffset: 9 + (thickness + gap - 9) * smoothStep(progress / 0.68)
    readonly property real childRadius: Math.min(24, childWidth / 2, childHeight / 2)
    readonly property real contentOpacity: smoothStep((progress - 0.56) / 0.44)
    readonly property real blendRadius: 40 * Math.sin(Math.PI * smoothStep(Math.min(1, progress / 0.72)))
    readonly property alias mainItem: mainBar
    readonly property bool clockHovered: mainBar.clockHovered
    readonly property bool mainHovered: mainBar.hovered
    readonly property var blurItems: [mainBar, childBlur, neckBlur]

    signal clockClicked(int button)
    signal mediaRequested

    function smoothStep(value) {
        const p = Math.max(0, Math.min(1, value));
        return p * p * (3 - 2 * p);
    }

    function updateSize() {
        if (!expanded)
            return;
        heldWidth = Math.min(targetWidth, availableChildWidth);
        heldHeight = Math.min(targetHeight, availableChildHeight);
    }

    onAvailableChildWidthChanged: updateSize()
    onAvailableChildHeightChanged: updateSize()
    onTargetWidthChanged: updateSize()
    onTargetHeightChanged: updateSize()
    onExpandedChanged: {
        if (expanded)
            Qt.callLater(updateSize);
    }
    Component.onCompleted: updateSize()

    implicitWidth: horizontal ? Math.max(length, childWidth) : Math.max(thickness, childOffset + childWidth)
    implicitHeight: horizontal ? Math.max(thickness, childOffset + childHeight) : Math.max(length,
                                                                                           childHeight)

    Behavior on progress {
        NumberAnimation {
            duration: root.expanded ? 760 : 620
            easing.type: Easing.Linear
        }
    }
    Behavior on heldWidth {
        enabled: root.progress > 0.99
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on heldHeight {
        enabled: root.progress > 0.99
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    LongStatusBar {
        id: mainBar
        screen: root.screen
        edge: root.edge
        x: root.horizontal ? (root.width - width) / 2 : root.edge === "right" ? root.width - width : 0
        y: !root.horizontal ? (root.height - height) / 2 : root.edge === "bottom" ? root.height - height : 0
        width: root.horizontal ? root.length : root.thickness
        height: root.horizontal ? root.thickness : root.length
        property real radius: root.thickness / 2
        onClockClicked: button => root.clockClicked(button)
        onMediaRequested: root.mediaRequested()
        z: 2
    }

    Item {
        id: childBlur
        x: root.childItem.x
        y: root.childItem.y
        width: root.childWidth
        height: root.childHeight
        property real radius: root.childRadius
        visible: root.progress > 0
    }

    Item {
        // Only blur the interior of an actually connected neck. Detached
        // space is neither blurred nor included in the window input mask.
        id: neckBlur
        readonly property real separation: root.childOffset - root.thickness
        visible: separation > 0 && root.blendRadius > separation * 2.5
        x: root.horizontal ? root.width / 2 - 6 : root.edge === "left" ? root.thickness : root.width
                                                                         - root.childOffset
        y: !root.horizontal ? root.height / 2 - 6 : root.edge === "top" ? root.thickness : root.height
                                                                          - root.childOffset
        width: root.horizontal ? 12 : Math.max(0, separation)
        height: root.horizontal ? Math.max(0, separation) : 12
        property real radius: 0
    }

    Item {
        id: morphSurface
        x: -24
        y: -24
        width: root.width + 48
        height: root.height + 48
        // Render opaque once, then apply the configured alpha to the combined
        // surface and its shadow, preserving translucent shell backgrounds.
        opacity: root.surfaceColor.a
        layer.enabled: opacity < 1

        MorphShader {
            id: shadowSource
            fillColor: "black"
            visible: false
        }

        DropShadow {
            anchors.fill: shadowSource
            source: shadowSource
            horizontalOffset: root.edge === "left" ? 4 : root.edge === "right" ? -4 : 0
            verticalOffset: root.edge === "top" ? 4 : root.edge === "bottom" ? -4 : 0
            radius: 14
            samples: 29
            color: Appearance.colors.colShadow
            cached: false
        }

        MorphShader {}
    }

    component MorphShader: ShaderEffect {
        anchors.fill: parent
        property vector2d resolution: Qt.vector2d(width, height)
        property color fillColor: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 1)
        property vector2d mainCenter: Qt.vector2d(mainBar.x + mainBar.width / 2 + 24, mainBar.y
                                                  + mainBar.height / 2 + 24)
        property vector2d mainSize: Qt.vector2d(mainBar.width, mainBar.height)
        property real mainRadius: root.thickness / 2
        property vector2d satelliteCenter: Qt.vector2d(root.childItem.x + root.childWidth / 2 + 24,
                                                       root.childItem.y + root.childHeight / 2 + 24)
        property vector2d satelliteSize: Qt.vector2d(root.childWidth, root.childHeight)
        property real satelliteRadius: root.childRadius
        property real blendRadius: root.blendRadius
        property real edgeSoftness: 0.8
        property vector4d cutoutRect: Qt.vector4d(root.childItem.x + root.cutoutItem.x + 24, root.childItem.y
                                                  + root.cutoutItem.y + 24, root.cutoutVisible
                                                  && root.progress > 0.78 ? root.cutoutItem.width : 0,
                                                  root.cutoutItem.height)
        property real cutoutRadius: 24
        fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/keystone/qsb/long_morph.frag.qsb")
    }
}
