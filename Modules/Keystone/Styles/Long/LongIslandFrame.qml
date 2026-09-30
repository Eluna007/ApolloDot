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
    required property real targetWidth
    required property real targetHeight
    required property Item childItem
    required property Item cutoutItem
    property bool peeking: false
    property bool cutoutVisible: false
    property color surfaceColor: Appearance.colors.colLayer0

    // One reversible timeline: submerged bulge -> emergence -> adhesion -> release.
    // All lengths are logical pixels; phase boundaries are normalized progress.
    readonly property real thickness: 42
    readonly property real gap: 24
    readonly property real peekWidth: 240
    readonly property real peekDepth: 10
    readonly property int peekDuration: 200
    readonly property int openDuration: 720
    readonly property int closeDuration: 420
    readonly property var peekEnterCurve: [0.2, 0, 0.18, 1, 1, 1]
    readonly property var peekExitCurve: [0.35, 0, 0.35, 1, 1, 1]
    readonly property var openCurve: [0.24, 0, 0.2, 1, 1, 1]
    readonly property var closeCurve: [0.32, 0, 0.28, 1, 1, 1]
    readonly property real reboundDistance: 8
    readonly property real peekStop: 0.18
    readonly property real emergenceEnd: 0.66
    readonly property real separationStart: 0.50
    readonly property real separationEnd: 0.76
    readonly property real releaseStart: 0.86
    readonly property real shoulderRadius: 16
    readonly property real neckWidth: 48
    readonly property real panelRadius: 24
    readonly property real seedDepth: 18
    readonly property real seedWidth: 64

    property real progress: 0
    property bool componentReady: false
    property real heldWidth: seedWidth
    property real heldHeight: seedDepth
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property vector2d inwardNormal: edge === "top" ? Qt.vector2d(0, 1) : edge === "bottom" ? Qt.vector2d(0,
                                                                                                                  -1) : edge
                                                                                                      === "left"
                                                                                                      ? Qt.vector2d(
                                                                                                            1, 0) : Qt.vector2d(
                                                                                                            -1, 0)
    readonly property real length: mainBar.contentLength
    readonly property real availableChildWidth: Math.max(24, screen.width - (horizontal ? 32 : thickness + gap
                                                                                          + 24))
    readonly property real availableChildHeight: Math.max(24, screen.height - (horizontal ? thickness + gap + 24 :
                                                                                            32))
    readonly property real emergence: stage(peekStop, emergenceEnd)
    readonly property real separation: gap * stage(separationStart, separationEnd)
    readonly property real release: stage(releaseStart, 1)
    // Let the already formed panel travel past its resting position and settle.
    // Keep phase progress bounded so opacity, size and neck release never rewind
    // during the rebound. Geometry, content, blur and input share this offset.
    readonly property real reboundPhase: Math.max(0, Math.min(1, (progress - emergenceEnd) / (1
                                                                                              - emergenceEnd)))

    readonly property real reboundOffset: reboundDistance * 16 * Math.pow(reboundPhase * (1 - reboundPhase),
                                                                          2)
    readonly property real bulgeHeight: peekDepth * stage(0, peekStop) * (1 - emergence)
    readonly property real childWidth: (horizontal ? seedWidth : seedDepth) * (1 - emergence) + heldWidth
                                       * emergence

    readonly property real childHeight: (horizontal ? seedDepth : seedWidth) * (1 - emergence) + heldHeight
                                        * emergence
    readonly property real childOffset: thickness - seedDepth * (1 - emergence) + separation + reboundOffset
    readonly property real childRadius: Math.min(childWidth / 2, childHeight / 2, panelRadius)
    readonly property real surfaceGap: Math.max(0, childOffset - thickness)
    readonly property real childAlong: horizontal ? childWidth : childHeight
    // Peel the broad contact down to a neck over the first few pixels of air.
    readonly property real neckRoot: Math.min(Math.max(0, childAlong / 2 - childRadius), neckWidth / 2 + childAlong
                                              * 0.4 * Math.exp(-surfaceGap / 3)) * (1 - release)
    readonly property real neckWaist: neckRoot - surfaceGap * 0.55 - seedDepth * release
    readonly property real contactBlend: shoulderRadius * emergence * (1 - smoothStep(surfaceGap / 4))
    // Text and cover art only appear once the panel has its final shape and has
    // cleared the bar. Reversing the timeline hides them before absorption.
    readonly property real contentOpacity: stage(emergenceEnd, separationEnd)
    readonly property bool contentInteractive: expanded && contentOpacity > 0.1
    readonly property bool peekHovered: bulgeHover.hovered || neckHover.hovered || childHover.hovered
    readonly property alias mainItem: mainBar
    readonly property bool clockHovered: mainBar.clockHovered
    readonly property bool mainHovered: mainBar.hovered
    readonly property alias childBlurItem: childBlur
    readonly property alias cutoutBlurItem: cutoutBlur
    readonly property alias extensionRegion: extensionRegion
    readonly property var blurItems: [mainBar]

    signal clockClicked(int button)
    signal mediaRequested

    function smoothStep(value) {
        const p = Math.max(0, Math.min(1, value));
        return p * p * (3 - 2 * p);
    }

    function stage(start, end) {
        return smoothStep((progress - start) / (end - start));
    }

    function bulgeAt(along) {
        const t = Math.min(1, Math.abs(along) / (peekWidth / 2));
        return bulgeHeight * Math.pow(1 - t * t, 3);
    }

    function neckAt(t) {
        const q = 2 * t - 1;
        return Math.max(0, neckRoot - (neckRoot - neckWaist) * Math.sqrt(Math.max(0, 1 - q * q)));
    }

    function updateSize() {
        if (!expanded)
            return;
        heldWidth = Math.max(24, Math.min(targetWidth, availableChildWidth));
        heldHeight = Math.max(24, Math.min(targetHeight, availableChildHeight));
    }

    function retarget() {
        if (!componentReady)
            return;
        updateSize();
        const destination = expanded ? 1 : peeking ? peekStop : 0;
        if (progressAnimation.running && progressAnimation.to === destination)
            return;
        progressAnimation.stop();
        const distance = Math.abs(destination - progress);
        if (distance < 0.00001)
            return;
        const onlyPeek = Math.max(progress, destination) <= peekStop;
        const opening = destination > progress;
        progressAnimation.duration = Math.max(16, onlyPeek ? peekDuration * distance / peekStop : (destination
                                                                                                   > progress
                                                                                                   ? openDuration :
                                                                                                     closeDuration)
                                                             * distance);
        progressAnimation.easing.bezierCurve = onlyPeek ? (opening ? peekEnterCurve : peekExitCurve) : (
                                                              opening ? openCurve : closeCurve);
        progressAnimation.to = destination;
        progressAnimation.start();
    }

    // Coalesce related mode/size bindings before selecting the next destination.
    onAvailableChildWidthChanged: Qt.callLater(updateSize)
    onAvailableChildHeightChanged: Qt.callLater(updateSize)
    onTargetWidthChanged: Qt.callLater(updateSize)
    onTargetHeightChanged: Qt.callLater(updateSize)
    onExpandedChanged: Qt.callLater(retarget)
    onPeekingChanged: Qt.callLater(retarget)
    Component.onCompleted: {
        updateSize();
        progress = expanded ? 1 : peeking ? peekStop : 0;
        componentReady = true;
        rebuildExtensionRegion();
    }

    readonly property real extent: Math.max(thickness + bulgeHeight, childOffset + (horizontal ? childHeight :
                                                                                                 childWidth))
    implicitWidth: horizontal ? Math.max(length, childWidth) : extent
    implicitHeight: horizontal ? extent : Math.max(length, childHeight)

    NumberAnimation {
        id: progressAnimation
        target: root
        property: "progress"
        easing.type: Easing.BezierSpline
    }
    Behavior on heldWidth {
        enabled: root.emergence > 0
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on heldHeight {
        enabled: root.emergence > 0
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
        visible: root.emergence > 0
        HoverHandler {
            id: childHover
        }
    }

    Item {
        id: cutoutBlur
        x: root.childItem.x + root.cutoutItem.x
        y: root.childItem.y + root.cutoutItem.y
        width: root.cutoutItem.width
        height: root.cutoutItem.height
        property real radius: root.cutoutItem.radius
        visible: root.cutoutVisible && root.contentOpacity > 0 && width > 0 && height > 0
    }

    // Everything outside the bar is constrained to its inward waterline.
    Item {
        id: inwardArea
        x: root.edge === "left" ? root.thickness : 0
        y: root.edge === "top" ? root.thickness : 0
        width: root.width - (root.horizontal ? 0 : root.thickness)
        height: root.height - (root.horizontal ? root.thickness : 0)
    }

    Item {
        id: bulgeHitArea
        x: root.horizontal ? root.width / 2 - width / 2 : root.edge === "left" ? root.thickness : root.width
                                                                                 - root.thickness - width
        y: !root.horizontal ? root.height / 2 - height / 2 : root.edge === "top" ? root.thickness :
                                                                                   root.height
                                                                                   - root.thickness - height
        width: root.horizontal ? root.peekWidth : root.bulgeHeight
        height: root.horizontal ? root.bulgeHeight : root.peekWidth
        HoverHandler {
            id: bulgeHover
            enabled: root.bulgeHeight > 0
        }
    }

    Item {
        id: neckHitArea
        x: root.horizontal ? root.width / 2 - width / 2 : root.edge === "left" ? root.thickness : root.width
                                                                                 - root.thickness - width
        y: !root.horizontal ? root.height / 2 - height / 2 : root.edge === "top" ? root.thickness :
                                                                                   root.height
                                                                                   - root.thickness - height
        width: root.horizontal ? root.neckRoot * 2 : root.surfaceGap
        height: root.horizontal ? root.surfaceGap : root.neckRoot * 2
        HoverHandler {
            id: neckHover
            enabled: root.surfaceGap > 0 && root.release < 1
        }
    }

    // Inscribed strips follow the same arch/neck equations as the shader.
    // They keep blur and input out of transparent space, including a split neck.
    Repeater {
        id: bulgeStrips
        model: 24
        delegate: SurfaceStrip {
            id: bulgeStrip
            required property int index
            readonly property real alongStart: -root.peekWidth / 2 + index * root.peekWidth / 24
            readonly property real depth: Math.min(root.bulgeAt(alongStart), root.bulgeAt(alongStart
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

    Repeater {
        id: neckStrips
        model: 12
        delegate: SurfaceStrip {
            id: neckStrip
            required property int index
            readonly property real halfWidth: Math.min(root.neckAt(index / 12), root.neckAt((index + 1) / 12))
            readonly property real offset: root.thickness + index * root.surfaceGap / 12
            x: root.horizontal ? root.width / 2 - halfWidth : root.edge === "left" ? offset : root.width
                                                                                     - offset - width
            y: !root.horizontal ? root.height / 2 - halfWidth : root.edge === "top" ? offset : root.height
                                                                                      - offset - height
            width: root.horizontal ? halfWidth * 2 : root.surfaceGap / 12
            height: root.horizontal ? root.surfaceGap / 12 : halfWidth * 2
            visible: root.surfaceGap > 0 && root.release < 1 && halfWidth > 0
        }
    }

    component SurfaceStrip: Item {
        id: strip
        property Region region: Region {
            item: strip.visible ? strip : null
        }
    }

    function rebuildExtensionRegion() {
        const regions = [bodyRegion];
        for (let i = 0; i < bulgeStrips.count; ++i)
            regions.push((bulgeStrips.itemAt(i) as SurfaceStrip).region);
        for (let i = 0; i < neckStrips.count; ++i)
            regions.push((neckStrips.itemAt(i) as SurfaceStrip).region);
        regions.push(waterlineClip);
        extensionRegion.regions = regions;
    }

    Region {
        id: extensionRegion
    }
    Region {
        id: bodyRegion
        item: childBlur.visible ? childBlur : null
        radius: root.childRadius
    }
    Region {
        id: waterlineClip
        item: inwardArea
        intersection: Intersection.Intersect
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
        property vector2d inwardNormal: root.inwardNormal
        property vector2d peakBulge: Qt.vector2d(root.peekWidth, root.bulgeHeight)
        property real bodyVisible: root.emergence > 0 ? 1 : 0
        property real contactBlend: root.contactBlend
        property vector4d neck: Qt.vector4d(root.surfaceGap, root.neckRoot, root.neckWaist, root.release < 1
                                            ? 1 : 0)
        property real edgeSoftness: 0.8
        property vector4d cutoutRect: Qt.vector4d(cutoutBlur.x + 24, cutoutBlur.y + 24, cutoutBlur.visible
                                                  ? cutoutBlur.width : 0, cutoutBlur.height)
        property real cutoutRadius: cutoutBlur.radius
        fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/keystone/qsb/long_split.frag.qsb")
    }
}
