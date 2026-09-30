pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects
import qs.Common

// Drawer motion and circular SDF fillets adapted from Caelestia Shell.
// See licenses/README.md and licenses/caelestia-shell-GPL-3.0.txt.
Item {
    id: root

    required property var screen
    required property string edge
    required property bool expanded
    required property real targetWidth
    required property real targetHeight
    required property Item cutoutItem
    property bool peeking: false
    property bool cutoutVisible: false
    property color surfaceColor: Appearance.colors.colLayer0

    readonly property real thickness: 42
    readonly property real gap: 24
    readonly property real panelRadius: 24
    readonly property real seedLength: 220
    readonly property real filletRadius: 20
    // The panel's leading edge is only just beyond the waterline at peak.
    // The circular union adds a soft shoulder around this small exposure.
    readonly property real peekExposure: 2
    readonly property int openDuration: 500
    readonly property int closeDuration: 320
    readonly property int peekDuration: 220
    readonly property var openCurve: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var closeCurve: [0.4, 0, 0.2, 1, 1, 1]
    readonly property var peekCurve: [0.25, 0, 0.3, 1, 1, 1]

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
    property real heldWidth: Math.min(horizontal ? 640 : 240, availableChildWidth)
    property real heldHeight: Math.min(horizontal ? 240 : 640, availableChildHeight)
    property bool componentReady: false
    property real progress: 0
    readonly property real initialScale: Math.min(1, seedLength / (horizontal ? heldWidth : heldHeight))
    readonly property real childScale: initialScale + (1 - initialScale) * progress
    readonly property real childWidth: heldWidth * childScale
    readonly property real childHeight: heldHeight * childScale
    readonly property real childDepth: horizontal ? childHeight : childWidth
    readonly property real childLength: horizontal ? childWidth : childHeight
    readonly property real burial: filletRadius + 1
    // Keep the full layout intact: translate it out of the edge and scale the
    // foreground and SDF together. No independent text/parallax trajectory.
    readonly property real childOffset: thickness - childDepth - burial + (childDepth + gap + burial)
                                        * progress

    readonly property real layoutOffset: childOffset - thickness - ((horizontal ? heldHeight : heldWidth)
                                                                    - childDepth) / 2
    readonly property real childX: horizontal ? (width - childWidth) / 2 : edge === "left" ? childOffset :
                                                                                             width - childOffset
                                                                                             - childWidth
    readonly property real childY: !horizontal ? (height - childHeight) / 2 : edge === "top" ? childOffset :
                                                                                               height - childOffset
                                                                                               - childHeight
    readonly property real childRadius: Math.min(panelRadius, heldWidth / 2, heldHeight / 2) * childScale
    // Fill the corners facing a nearby edge, as in Caelestia, so the circular
    // union forms a concave shoulder without a convex crease underneath it.
    readonly property real facingRadius: Math.max(2 * childScale, childRadius * smoothStep(Math.abs(barDistance(
                                                                                                        childLength
                                                                                                        / 2, childOffset
                                                                                                        - thickness))
                                                                                           / filletRadius))
    readonly property real separation: Math.max(0, childOffset - thickness)
    // Beyond this gap the circular fillet cannot bridge the surfaces. Fading
    // its remaining lobes avoids a residual bump after the panel detaches.
    readonly property real blendRadius: filletRadius * (1 - smoothStep(separation / gap))
    readonly property real peekProgress: {
        const depth = horizontal ? heldHeight : heldWidth;
        const a = depth * (1 - initialScale);
        const b = depth * initialScale + gap + burial;
        return 2 * (burial + peekExposure) / (b + Math.sqrt(b * b + 4 * a * (burial + peekExposure)));
    }
    readonly property real contentOpacity: smoothStep((progress - peekProgress) / 0.3)
    readonly property bool contentInteractive: expanded && contentOpacity > 0.1
    readonly property bool surfaceHovered: surfaceHover.hovered
    readonly property alias mainItem: mainBar
    readonly property bool clockHovered: mainBar.clockHovered
    readonly property bool mainHovered: mainBar.hovered
    readonly property alias childBlurItem: visibleChildBounds
    readonly property alias cutoutBlurItem: cutoutBlur
    readonly property var blurItems: [mainBar]
    readonly property alias surfaceRegion: surfaceRegion

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

    function retarget() {
        if (!componentReady)
            return;
        updateSize();
        motion.stop();
        // Each leg starts at the current visible pose, including interrupted
        // opening/closing and the transition from peak to a real panel.
        const destination = expanded ? 1 : peeking ? peekProgress : 0;
        const peakOnly = !expanded && progress <= peekProgress + 0.001;
        motion.duration = expanded ? openDuration : peakOnly ? peekDuration : closeDuration;
        motion.easing.bezierCurve = expanded ? openCurve : peakOnly ? peekCurve : closeCurve;
        motion.to = destination;
        motion.start();
    }

    onExpandedChanged: Qt.callLater(retarget)
    onPeekingChanged: Qt.callLater(retarget)
    onPeekProgressChanged: {
        // A panel size transition can still be settling when dismissed into
        // peak. Keep the small exposure fixed as the held layout settles.
        if (componentReady && peeking && !expanded)
            Qt.callLater(retarget);
    }
    onTargetWidthChanged: Qt.callLater(updateSize)
    onTargetHeightChanged: Qt.callLater(updateSize)
    onAvailableChildWidthChanged: Qt.callLater(updateSize)
    onAvailableChildHeightChanged: Qt.callLater(updateSize)
    Component.onCompleted: {
        updateSize();
        progress = expanded ? 1 : peeking ? peekProgress : 0;
        componentReady = true;
        const regions = [panelRegion];
        for (let i = 0; i < joinStrips.count; ++i)
            regions.push((joinStrips.itemAt(i) as JoinStrip).region);
        surfaceRegion.regions = regions;
    }

    implicitWidth: horizontal ? Math.max(length, childWidth + filletRadius * 2) : Math.max(thickness,
                                                                                           childOffset
                                                                                           + childWidth
                                                                                           + filletRadius)
    implicitHeight: horizontal ? Math.max(thickness, childOffset + childHeight + filletRadius) : Math.max(
                                     length, childHeight + filletRadius * 2)

    NumberAnimation {
        id: motion
        target: root
        property: "progress"
        easing.type: Easing.BezierSpline
    }
    Behavior on heldWidth {
        enabled: root.componentReady && root.progress > 0
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on heldHeight {
        enabled: root.componentReady && root.progress > 0
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

    // Foreground and all transient regions are clipped to the inner bar edge.
    Item {
        id: viewport
        x: root.edge === "left" ? root.thickness : 0
        y: root.edge === "top" ? root.thickness : 0
        width: root.width - (root.horizontal ? 0 : root.thickness)
        height: root.height - (root.horizontal ? root.thickness : 0)
        HoverHandler {
            id: surfaceHover
            enabled: root.progress > 0
        }
    }

    Item {
        id: childBounds
        x: root.childX
        y: root.childY
        width: root.childWidth
        height: root.childHeight
    }

    Item {
        id: visibleChildBounds
        x: Math.max(viewport.x, childBounds.x)
        y: Math.max(viewport.y, childBounds.y)
        width: Math.max(0, Math.min(viewport.x + viewport.width, childBounds.x + childBounds.width) - x)
        height: Math.max(0, Math.min(viewport.y + viewport.height, childBounds.y + childBounds.height) - y)
        property real radius: root.childOffset >= root.thickness ? root.childRadius : 0
    }

    Region {
        id: panelRegion
        Region {
            item: root.progress > 0 ? childBounds : null
            radius: root.childRadius
        }
        Region {
            item: viewport
            intersection: Intersection.Intersect
        }
    }

    Item {
        id: cutoutBlur
        x: root.childX + root.cutoutItem.x * root.childScale
        y: root.childY + root.cutoutItem.y * root.childScale
        width: root.cutoutItem.width * root.childScale
        height: root.cutoutItem.height * root.childScale
        property real radius: root.cutoutItem.radius * root.childScale
        visible: root.cutoutVisible && root.contentOpacity > 0 && width > 0 && height > 0
    }

    // Rasterize only the small junction, not the whole panel. Each row uses
    // the same circular union as the shader; detached rows have zero width.
    // This keeps peak, shoulders, blur and pointer input on the visible shape.
    function barDistance(along, inward) {
        const ax = Math.abs(along) - length / 2 + thickness / 2;
        const ay = Math.abs(inward + thickness / 2);
        return Math.min(Math.max(ax, ay), 0) + Math.hypot(Math.max(ax, 0), Math.max(ay, 0)) - thickness / 2;
    }

    function junctionDistance(along, inward) {
        const relativeDepth = inward - (childOffset - thickness + childDepth / 2);
        const radius = relativeDepth < 0 ? facingRadius : childRadius;
        const ax = Math.abs(along) - root.childLength / 2 + radius;
        const ay = Math.abs(relativeDepth) - childDepth / 2 + radius;
        const panel = Math.min(Math.max(ax, ay), 0) + Math.hypot(Math.max(ax, 0), Math.max(ay, 0)) - radius;
        const k = junctionRadius(along);
        const bar = barDistance(along, inward);
        return Math.max(k, Math.min(bar, panel)) - Math.hypot(Math.max(k - bar, 0), Math.max(k - panel, 0));
    }

    function junctionRadius(along) {
        const t = Math.min(1, Math.abs(along) / (childLength / 2 + filletRadius));
        // Full fillets at contact, a broad soft peel as the gap opens.
        return blendRadius * (1 - smoothStep(separation / filletRadius) * t * t);
    }

    function junctionHalfWidth(depth) {
        if (progress <= 0 || blendRadius <= 0.01 || junctionDistance(0, depth) >= -0.8)
            return 0;
        let low = 0;
        let high = childLength / 2 + filletRadius * 2;
        for (let i = 0; i < 12; ++i) {
            const mid = (low + high) / 2;
            if (junctionDistance(mid, depth) < -0.8)
                low = mid;
            else
                high = mid;
        }
        return low;
    }

    readonly property real junctionDepth: Math.max(0, Math.min(childOffset + childDepth - thickness
                                                               + filletRadius, separation + filletRadius))
    Repeater {
        id: joinStrips
        model: 32
        delegate: JoinStrip {
            required property int index
            readonly property real start: root.junctionDepth * index / 32
            readonly property real end: root.junctionDepth * (index + 1) / 32
            readonly property real halfWidth: Math.min(root.junctionHalfWidth(start), root.junctionHalfWidth(
                                                           end))
            x: root.horizontal ? root.width / 2 - halfWidth : root.edge === "left" ? root.thickness + start :
                                                                                     root.width
                                                                                     - root.thickness - end
            y: !root.horizontal ? root.height / 2 - halfWidth : root.edge === "top" ? root.thickness + start :
                                                                                      root.height
                                                                                      - root.thickness - end
            width: root.horizontal ? halfWidth * 2 : end - start
            height: root.horizontal ? end - start : halfWidth * 2
            visible: halfWidth > 0
        }
    }
    component JoinStrip: Item {
        id: strip
        property Region region: Region {
            item: strip.visible ? strip : null
        }
    }
    Region {
        id: surfaceRegion
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
        property vector2d satelliteCenter: Qt.vector2d(root.childX + root.childWidth / 2 + 24, root.childY
                                                       + root.childHeight / 2 + 24)
        property vector2d satelliteSize: Qt.vector2d(root.childWidth, root.childHeight)
        property real satelliteRadius: root.childRadius
        property real facingRadius: root.facingRadius
        property real blendRadius: root.blendRadius
        property real filletRadius: root.filletRadius
        property vector2d inwardNormal: root.inwardNormal
        property real edgeSoftness: 0.8
        property vector4d cutoutRect: Qt.vector4d(cutoutBlur.x + 24, cutoutBlur.y + 24, cutoutBlur.visible
                                                  ? cutoutBlur.width : 0, cutoutBlur.height)
        property real cutoutRadius: cutoutBlur.radius
        fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/keystone/qsb/long_split.frag.qsb")
    }
}
