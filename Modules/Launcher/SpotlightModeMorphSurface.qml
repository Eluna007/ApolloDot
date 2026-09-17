pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    required property real railProgress
    required property real mainLeft
    required property real collapsedMainWidth
    required property real expandedMainWidth
    required property real shapeCenterY
    required property real shapeHeight
    required property real buttonDiameter
    required property real buttonGap
    required property real blurEdgeInset

    property color surfaceColor: Appearance.colors.colSurfaceContainerHigh
    property color shadowColor: Appearance.colors.colShadow
    property real shadowBlur: 0.72
    property real shadowVerticalOffset: 7
    readonly property var blurRegionItems: [mainBlurRegion, button0BlurRegion, button1BlurRegion,
        button2BlurRegion, button3BlurRegion, neck0BlurRegion, neck1BlurRegion, neck2BlurRegion,
        neck3BlurRegion]

    // The normalized key poses keep velocity through the connected chain.
    // Only the initial/final poses and the deliberate rebound have zero speed.
    readonly property var contractionKeys: [[0, 0], [0.16, 0.28], [0.28, 0.68], [0.40, 0.99], [0.50, 1.045],
        [0.68, 1.027], [1, 1]]
    readonly property var pitchTracks: [pitchTrack(0), pitchTrack(1), pitchTrack(2)]
    readonly property var growthTracks: [growthTrack(0), growthTrack(1), growthTrack(2), growthTrack(3)]
    // The last neck holds longer than the first two. These offsets apply to
    // release, not to the whole chain's emergence.
    readonly property var releaseDelays: [0, 0.045, 0.15]
    readonly property real mainWidth: interpolate(collapsedMainWidth, expandedMainWidth, sampleMotion(
                                                      contractionKeys, railProgress))
    readonly property real mainCenterX: mainLeft + mainWidth / 2
    readonly property real mainRight: mainLeft + mainWidth
    readonly property real expandedMainRight: mainLeft + expandedMainWidth
    readonly property vector4d mainShape: Qt.vector4d(mainCenterX, shapeCenterY, mainWidth, shapeHeight)
    readonly property var buttonShapes: [buttonShape(0), buttonShape(1), buttonShape(2), buttonShape(3)]

    function smoothstep(value) {
        const progress = Math.max(0, Math.min(1, value));
        return progress * progress * (3 - 2 * progress);
    }

    function stage(start, end) {
        return smoothstep((root.railProgress - start) / (end - start));
    }

    function interpolate(from, to, progress) {
        return from + (to - from) * progress;
    }

    // Shape-preserving cubic Hermite interpolation. Interior slopes stay
    // nonzero across key poses; adjacent stages cannot introduce a dwell.
    function motionSlope(keys, index) {
        if (index === 0 || index === keys.length - 1)
            return 0;
        const before = (keys[index][1] - keys[index - 1][1]) / (keys[index][0] - keys[index - 1][0]);
        const after = (keys[index + 1][1] - keys[index][1]) / (keys[index + 1][0] - keys[index][0]);
        return before * after <= 0 ? 0 : 2 * before * after / (before + after);
    }

    function sampleMotion(keys, progress) {
        const time = Math.max(0, Math.min(1, progress));
        for (let index = 0; index < keys.length - 1; ++index) {
            if (time > keys[index + 1][0])
                continue;
            const span = keys[index + 1][0] - keys[index][0];
            const t = (time - keys[index][0]) / span;
            const t2 = t * t;
            const t3 = t2 * t;
            return (2 * t3 - 3 * t2 + 1) * keys[index][1] + (t3 - 2 * t2 + t) * span * motionSlope(keys,
                                                                                                   index) + (
                        -2 * t3 + 3 * t2) * keys[index + 1][1] + (t3 - t2) * span * motionSlope(keys, index
                                                                                                + 1);
        }
        return keys[keys.length - 1][1];
    }

    function pitchTrack(index) {
        const pitch = 1 + root.buttonGap / root.buttonDiameter;
        const tailLag = index === 2 ? 0.03 : 0;
        const keys = [[0, 0], [0.16 + index * 0.025, 0], [0.28 + index * 0.025, 0.26], [0.42 + index * 0.025,
                                                                                        0.91], [0.55 + index
                                                                                                * 0.045 + tailLag
                                                                                                / 2, 1.04],
                      [0.66 + index * 0.055 + tailLag, 1.14], [0.76 + index * 0.075 + tailLag / 2, pitch
                                                               + 0.035], [index === 2 ? 1 : 0.86 + index * 0.07,
                                                                          pitch]];
        if (index < 2)
            keys.push([1, pitch]);
        return keys;
    }

    function growthTrack(index) {
        const start = index * 0.065;
        const emergenceSpan = 1 - start;
        // Keep the tapered chain's birth, then give each lobe its own crest
        // and settle. A normalized delay would compress these later phases.
        const keys = [[0, 0], [start + 0.10 * emergenceSpan, 0.03], [start + 0.20 * emergenceSpan, 0.23],
                      [start + 0.30 * emergenceSpan, 0.68], [start + 0.44 * emergenceSpan, 1], [0.58 + index
                                                                                                * 0.07, 1.04],
                      [index === 3 ? 1 : 0.76 + index * 0.08, 1]];
        if (index < 3)
            keys.push([1, 1]);
        return keys;
    }

    function buttonCenterX(index) {
        const diameter = root.buttonDiameter;
        const firstCenter = root.expandedMainRight + root.buttonGap + diameter / 2;
        let center = interpolate(root.mainRight - diameter * 0.42, firstCenter + diameter * 0.035, stage(0.10,
                                                                                                         0.44));
        center -= diameter * 0.035 * stage(0.40, 0.76);
        for (let pair = 1; pair <= index; ++pair)
            center += diameter * sampleMotion(root.pitchTracks[pair - 1], root.railProgress);
        return center;
    }

    function buttonShape(index) {
        const growth = sampleMotion(root.growthTracks[index], root.railProgress);
        const pull = Math.sin(Math.PI * stage(0.16 + index * 0.025, 0.64 + index * 0.08));
        const width = root.buttonDiameter * growth * (1 + 0.04 * pull);
        const height = root.buttonDiameter * growth * (1 - 0.025 * pull);
        return Qt.vector4d(buttonCenterX(index), root.shapeCenterY, width, height);
    }

    function buttonBlend(index) {
        const shape = root.buttonShapes[index];
        const delay = index === 0 ? 0 : root.releaseDelays[index - 1];
        const release = index === 0 ? stage(0.28, 0.46) : stage(0.50 + delay, 0.72 + delay);
        return Math.min(shape.z, shape.w, root.buttonDiameter * (index === 0 ? 0.48 : 0.25)) * (1 - release);
    }

    function iconProgress(index) {
        return stage(0.54 + index * 0.05, 0.78 + index * 0.055);
    }

    // A conservative blur-only rectangle inside the natural SDF neck. The
    // inscribed equal circles give a lower bound even for unequal capsules.
    // This never draws a bridge or blurs across an already detached gap.
    function neckBlurShape(index) {
        const shape = root.buttonShapes[index];
        const previous = index === 0 ? root.mainShape : root.buttonShapes[index - 1];
        const previousX = index === 0 ? root.mainRight - root.shapeHeight / 2 : previous.x;
        const radius = Math.min(shape.z, shape.w, previous.z, previous.w) / 2;
        const distance = Math.abs(shape.x - previousX);
        const reach = radius + buttonBlend(index) / 4;
        const halfHeight = Math.max(0, Math.min(radius, Math.sqrt(Math.max(0, reach * reach - distance * distance
                                                                           / 4))) - root.blurEdgeInset);
        return Qt.vector4d((previousX + shape.x) / 2, root.shapeCenterY, distance, halfHeight * 2);
    }

    ShaderEffect {
        id: surfaceSource

        anchors.fill: parent
        visible: false

        property vector2d resolution: Qt.vector2d(width, height)
        // Keep the intermediate texture opaque. MultiEffect's shadow mixing
        // otherwise changes the alpha/color of an already translucent fill.
        property color fillColor: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 1)
        property vector4d mainShape: root.mainShape
        property vector4d button0Shape: root.buttonShapes[0]
        property vector4d button1Shape: root.buttonShapes[1]
        property vector4d button2Shape: root.buttonShapes[2]
        property vector4d button3Shape: root.buttonShapes[3]
        property vector4d blends: Qt.vector4d(root.buttonBlend(0), root.buttonBlend(1), root.buttonBlend(2),
                                              root.buttonBlend(3))

        // A distinct resource URL for this uniform layout also invalidates
        // Qt's process-wide cache of the previous circle/bridge shader.
        fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/launcher/qsb/spotlight_mode_field.frag.qsb")
    }

    MultiEffect {
        anchors.fill: surfaceSource
        source: surfaceSource
        opacity: root.surfaceColor.a
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: root.shadowColor
        shadowBlur: root.shadowBlur
        shadowVerticalOffset: root.shadowVerticalOffset
        shadowHorizontalOffset: 0
    }

    component ShapeBlurRegion: Item {
        required property vector4d shape
        property real inset: root.blurEdgeInset
        x: shape.x - width / 2
        y: shape.y - height / 2
        width: Math.max(0, shape.z - inset * 2)
        height: Math.max(0, shape.w - inset * 2)
        property real radius: Math.min(width, height) / 2
        visible: width > 0 && height > 0
    }

    ShapeBlurRegion {
        id: mainBlurRegion
        shape: root.mainShape
    }

    ShapeBlurRegion {
        id: button0BlurRegion
        shape: root.buttonShapes[0]
    }

    ShapeBlurRegion {
        id: button1BlurRegion
        shape: root.buttonShapes[1]
    }

    ShapeBlurRegion {
        id: button2BlurRegion
        shape: root.buttonShapes[2]
    }

    ShapeBlurRegion {
        id: button3BlurRegion
        shape: root.buttonShapes[3]
    }

    ShapeBlurRegion {
        id: neck0BlurRegion
        shape: root.neckBlurShape(0)
        inset: 0
        radius: 0
    }

    ShapeBlurRegion {
        id: neck1BlurRegion
        shape: root.neckBlurShape(1)
        inset: 0
        radius: 0
    }

    ShapeBlurRegion {
        id: neck2BlurRegion
        shape: root.neckBlurShape(2)
        inset: 0
        radius: 0
    }

    ShapeBlurRegion {
        id: neck3BlurRegion
        shape: root.neckBlurShape(3)
        inset: 0
        radius: 0
    }
}
