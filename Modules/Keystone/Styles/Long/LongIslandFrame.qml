pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects
import qs.Common

Item {
    id: root

    required property var screen
    required property string edge
    required property bool expanded
    // Peak only deforms the resting bar edge. It must not drive the panel's
    // damped opening response, contraction pose, or SDF fusion strength.
    property bool peeking: false
    readonly property real peekWidth: 240
    readonly property real peekDepth: 8
    readonly property int peekDuration: 220
    readonly property var peekCurve: [0.25, 0, 0.3, 1, 1, 1]
    property real peekAmount: peeking && !expanded ? 1 : 0
    readonly property real peekHeight: peekDepth * peekAmount
    readonly property bool peekHovered: peekHover.hovered
    readonly property alias peekRegion: peekRegion
    readonly property vector2d inwardNormal: edge === "top" ? Qt.vector2d(0, 1) : edge === "bottom" ? Qt.vector2d(0,
                                                                                                                  -1) : edge
                                                                                                      === "left"
                                                                                                      ? Qt.vector2d(
                                                                                                            1, 0) : Qt.vector2d(
                                                                                                            -1, 0)

    Behavior on peekAmount {
        NumberAnimation {
            duration: root.peekDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.peekCurve
        }
    }
    required property real targetWidth
    required property real targetHeight
    required property Item childItem
    required property Item cutoutItem
    property bool cutoutVisible: false
    property color surfaceColor: Appearance.colors.colLayer0
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real length: mainBar.contentLength
    readonly property real availableChildWidth: Math.max(24, screen.width - (horizontal ? 32 : thickness + gap
                                                                                          + 24))
    readonly property real availableChildHeight: Math.max(24, screen.height - (horizontal ? thickness + gap + 24 :
                                                                                            32))
    readonly property real thickness: 42
    readonly property real gap: 24
    // Match the collapsed Pill surface. Only the child deforms; the status
    // bar and its clock remain fixed throughout the split and fusion.
    readonly property real pillWidth: horizontal ? 220 : 42
    readonly property real pillHeight: horizontal ? 42 : 220
    property real progress: 0
    property bool componentReady: false
    // Capture the visible pose when changing direction. Closing uses a single
    // contraction curve instead of playing the opening spring backwards.
    property bool closing: false
    property real legStart: 0
    property var legPose: ({
                               travel: 0,
                               along: 0,
                               inward: 0,
                               opacity: 0,
                               blend: 0
                           })
    readonly property real closingRemaining: smoothStep(progress / Math.max(0.0001, legStart))
    readonly property real openingCorrection: 1 - stage(legStart, Math.max(legStart + 0.0001, 1))
    property real heldWidth: pillWidth
    property real heldHeight: pillHeight
    // As in Spotlight, overlapping damped responses keep velocity through
    // emergence, separation and expansion instead of stopping at each pose.
    readonly property real travel: closing ? legPose.travel * closingRemaining : response(0, 6.4, 7.2) + (
                                                 legPose.travel - response(0, 6.4, 7.2, legStart))
                                             * openingCorrection
    readonly property real alongGrowth: closing ? legPose.along * closingRemaining : response(0.025, 6.8,
                                                                                              5.8) + (legPose.along
                                                                                                      - response(
                                                                                                          0.025, 6.8,
                                                                                                          5.8, legStart))
                                                  * openingCorrection
    readonly property real inwardGrowth: closing ? legPose.inward * closingRemaining : response(0.055, 6.4,
                                                                                                5.4) + (legPose.inward
                                                                                                        - response(
                                                                                                            0.055, 6.4,
                                                                                                            5.4, legStart))
                                                   * openingCorrection
    readonly property real childWidth: pillWidth + (heldWidth - pillWidth) * (horizontal ? alongGrowth :
                                                                                           inwardGrowth)
    readonly property real childHeight: pillHeight + (heldHeight - pillHeight) * (horizontal ? inwardGrowth :
                                                                                               alongGrowth)
    readonly property real childOffset: (thickness + gap) * travel
    readonly property real childRadius: Math.min(childWidth / 2, childHeight / 2, 21 + 3 * Math.min(1,
                                                                                                    inwardGrowth))
    readonly property real contentOpacity: closing ? legPose.opacity * closingRemaining : stage(0.12, 0.50) + (
                                                         legPose.opacity - smoothStep((legStart - 0.12)
                                                                                      / 0.38))
                                                     * openingCorrection
    readonly property bool contentInteractive: expanded && progress > 0.02
    readonly property real contentOffset: 10 * (1 - Math.min(1, inwardGrowth))
    readonly property real separation: Math.max(0, childOffset - thickness)
    // Expose the neck with the pill, then release it while both motion and
    // growth continue. The SDF itself determines when contact breaks.
    readonly property real blendRadius: closing ? legPose.blend * closingRemaining + 56 * Math.sin(Math.PI
                                                                                                   * closingRemaining)
                                                  * smoothStep(childOffset / thickness) : openingBlend(
                                                      progress, travel) + (legPose.blend - openingBlend(
                                                                               legStart, legPose.travel))
                                                  * openingCorrection
    readonly property alias mainItem: mainBar
    readonly property bool clockHovered: mainBar.clockHovered
    readonly property bool mainHovered: mainBar.hovered
    readonly property alias childBlurItem: childBlur
    readonly property alias cutoutBlurItem: cutoutBlur
    readonly property var blurItems: [mainBar, childBlur, neckBlur]

    signal clockClicked(int button)
    signal mediaRequested

    function smoothStep(value) {
        const p = Math.max(0, Math.min(1, value));
        return p * p * (3 - 2 * p);
    }

    function stage(start, end) {
        return smoothStep((progress - start) / (end - start));
    }

    // Zero initial velocity, a small natural overshoot, and an exact endpoint.
    // A decaying correction preserves the current pose when reopening midway.
    function response(delay, decay, frequency, position = progress) {
        const time = Math.max(0, Math.min(1, position) - delay);
        const end = 1 - delay;
        const phase = decay / frequency;
        const value = 1 - Math.exp(-decay * time) * (Math.cos(frequency * time) + phase * Math.sin(frequency
                                                                                                   * time));
        const terminal = 1 - Math.exp(-decay * end) * (Math.cos(frequency * end) + phase * Math.sin(frequency
                                                                                                    * end));
        return value / terminal;
    }

    function openingBlend(position, travelValue) {
        return 56 * smoothStep((thickness + gap) * travelValue / thickness) * (1 - smoothStep((position
                                                                                               - 0.25) / 0.40));
    }

    function updateSize() {
        if (!expanded)
            return;
        heldWidth = Math.min(targetWidth, availableChildWidth);
        heldHeight = Math.min(targetHeight, availableChildHeight);
    }

    // Coalesce layout changes so a collapsed target cannot replace the held
    // expanded size before the expanded binding has caught up in this turn.
    onAvailableChildWidthChanged: Qt.callLater(updateSize)
    onAvailableChildHeightChanged: Qt.callLater(updateSize)
    onTargetWidthChanged: Qt.callLater(updateSize)
    onTargetHeightChanged: Qt.callLater(updateSize)
    onExpandedChanged: {
        if (!componentReady)
            return;
        progressAnimation.stop();
        const pose = {
            travel,
            along: alongGrowth,
            inward: inwardGrowth,
            opacity: contentOpacity,
            blend: blendRadius
        };
        const start = progress;
        legPose = pose;
        legStart = start;
        closing = !expanded;
        Qt.callLater(updateSize);
        // Set timing before starting: a Behavior on a state-bound progress
        // can start with the previous state's duration during binding updates.
        progressAnimation.duration = expanded ? 580 : 210;
        progressAnimation.to = expanded ? 1 : 0;
        progressAnimation.start();
    }
    Component.onCompleted: {
        progress = expanded ? 1 : 0;
        updateSize();
        componentReady = true;
        const regions = [];
        for (let i = 0; i < peekStrips.count; ++i)
            regions.push((peekStrips.itemAt(i) as PeekStrip).region);
        peekRegion.regions = regions;
    }

    implicitWidth: horizontal ? Math.max(length, childWidth) : Math.max(thickness + peekHeight, childOffset
                                                                        + childWidth)
    implicitHeight: horizontal ? Math.max(thickness + peekHeight, childOffset + childHeight) : Math.max(length,
                                                                                                        childHeight)

    NumberAnimation {
        id: progressAnimation
        target: root
        property: "progress"
        // A clock for response()/smoothStep(), not a linear visual trajectory.
        easing.type: Easing.Linear
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
        id: peekHitArea
        x: root.horizontal ? root.width / 2 - width / 2 : root.edge === "left" ? root.thickness : root.width
                                                                                 - root.thickness - width
        y: !root.horizontal ? root.height / 2 - height / 2 : root.edge === "top" ? root.thickness :
                                                                                   root.height
                                                                                   - root.thickness - height
        width: root.horizontal ? root.peekWidth : root.peekHeight
        height: root.horizontal ? root.peekHeight : root.peekWidth
        HoverHandler {
            id: peekHover
            enabled: root.peekHeight > 0
        }
    }

    function peekHeightAt(along) {
        const t = Math.min(1, Math.abs(along) / (peekWidth / 2));
        return peekHeight * Math.pow(1 - t * t, 3);
    }

    // This region belongs only to peak. The panel keeps its original blur and
    // input regions, so editing peak cannot change the split/fusion geometry.
    Repeater {
        id: peekStrips
        model: 24
        delegate: PeekStrip {
            required property int index
            readonly property real alongStart: -root.peekWidth / 2 + index * root.peekWidth / 24
            readonly property real depth: Math.min(root.peekHeightAt(alongStart), root.peekHeightAt(alongStart
                                                                                                    + root.peekWidth
                                                                                                    / 24))
            x: root.horizontal ? root.width / 2 + alongStart : root.edge === "left" ? root.thickness :
                                                                                      root.width
                                                                                      - root.thickness - width
            y: !root.horizontal ? root.height / 2 + alongStart : root.edge === "top" ? root.thickness :
                                                                                       root.height
                                                                                       - root.thickness
                                                                                       - height
            width: root.horizontal ? root.peekWidth / 24 : depth
            height: root.horizontal ? depth : root.peekWidth / 24
            visible: depth > 0
        }
    }

    component PeekStrip: Item {
        id: strip
        property Region region: Region {
            item: strip.visible ? strip : null
        }
    }

    Region {
        id: peekRegion
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
        id: cutoutBlur
        // The fixed card and its hole move together; the growing child surface
        // reveals both by clipping, without a second, independent hole animation.
        x: root.childItem.x + root.cutoutItem.x
        y: root.childItem.y + root.cutoutItem.y
        width: root.cutoutItem.width
        height: root.cutoutItem.height
        property real radius: root.cutoutItem.radius
        visible: root.cutoutVisible && root.progress > 0 && width > 0 && height > 0
    }

    Item {
        // Only blur the interior of an actually connected neck. Detached
        // space is neither blurred nor included in the window input mask.
        id: neckBlur
        visible: root.separation > 0 && root.blendRadius > root.separation * 2.8
        x: root.horizontal ? root.width / 2 - 6 : root.edge === "left" ? root.thickness : root.width
                                                                         - root.childOffset
        y: !root.horizontal ? root.height / 2 - 6 : root.edge === "top" ? root.thickness : root.height
                                                                          - root.childOffset
        width: root.horizontal ? 12 : root.separation
        height: root.horizontal ? root.separation : 12
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
        property vector2d inwardNormal: root.inwardNormal
        property vector2d peakBulge: Qt.vector2d(root.peekWidth, root.peekHeight)
        property real edgeSoftness: 0.8
        property vector4d cutoutRect: Qt.vector4d(cutoutBlur.x + 24, cutoutBlur.y + 24, cutoutBlur.visible
                                                  ? cutoutBlur.width : 0, cutoutBlur.height)
        property real cutoutRadius: cutoutBlur.radius
        fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/keystone/qsb/long_split.frag.qsb")
    }
}
