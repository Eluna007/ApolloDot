import QtQuick
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// A game launcher sitting in the tray pill beside the app icons. Styled like
// the overflow button next to it; the icon fills while its game is open.
RippleButton {
    id: root

    required property string game
    required property string iconName
    required property string label
    property var screen: null
    readonly property bool open: GameService.activeGame === root.game

    implicitWidth: 24
    implicitHeight: 24
    toggled: root.open
    buttonRadius: Appearance.rounding.full
    containerColor: "transparent"
    stateLayerColor: Appearance.colors.colSecondaryContainer
    pressedStateLayerColor: Appearance.colors.colSecondaryContainerActive
    rippleColor: Appearance.colors.colOnSecondaryContainer
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    releaseAction: () => GameService.toggle(root.game, root.screen)

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        text: root.iconName
        iconSize: 19
        fill: root.open ? 1 : 0
        color: root.open ? Appearance.colors.colPrimary : root.pointerHovered
                           ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: root.pointerHovered
        text: root.label
    }
}
