import QtQuick
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var screen: null
    property bool vertical: false
    readonly property bool showValue: PersonalizationConfig.barShowValues

    implicitHeight: vertical && showValue ? 46 : 28
    implicitWidth: vertical ? Math.max(28, showValue ? valueText.implicitWidth : 0) : 28 + (showValue
                                                                                            ? valueText.implicitWidth
                                                                                              + 6 : 0)

    ArcGauge {
        id: gauge
        width: 28
        height: 28
        x: root.vertical ? (root.width - width) / 2 : 0
        y: root.vertical ? 0 : (root.height - height) / 2

        value: Volume.sinkVolume
        progressColor: (Volume.sinkMuted || Volume.sinkVolume <= 0) ? Appearance.colors.colError :
                                                                      Appearance.colors.colPrimary
        trackColor: Appearance.colors.colLayer2Hover
        handleColor: Appearance.colors.colOnSurface
        iconColor: (Volume.sinkMuted || Volume.sinkVolume <= 0) ? Appearance.colors.colError :
                                                                  Appearance.colors.colOnSurface

        icon: {
            if (Volume.isHeadphone)
                return "headphones";
            if (Volume.sinkMuted || Volume.sinkVolume <= 0)
                return "volume_off";
            if (Volume.sinkVolume < 0.5)
                return "volume_down";
            return "volume_up";
        }
    }

    Text {
        id: valueText
        visible: root.showValue
        text: Math.round(Volume.sinkVolume * 100) + "%"
        font.family: Fonts.numeric
        font.pixelSize: 12
        color: Appearance.colors.colOnSurface
        x: root.vertical ? (root.width - width) / 2 : 34
        y: root.vertical ? 32 : (root.height - height) / 2
    }

    ActionButton {
        id: mouseArea
        anchors.fill: parent
        padding: 0
        contentItem: Item {}
        Accessible.name: tooltip.text

        WheelHandler {
            onWheel: wheel => {
                const step = 0.05;
                let newVol = Volume.sinkVolume;
                if (wheel.angleDelta.y > 0)
                    newVol += step;
                else
                    newVol -= step;
                Volume.setSinkVolume(newVol);
            }
        }
        onClicked: {
            if (root.screen && root.screen.name)
                WidgetState.quickSettingsScreenName = root.screen.name;
            if (WidgetState.quickSettingsOpen && WidgetState.quickSettingsView === "audio") {
                WidgetState.quickSettingsOpen = false;
            } else {
                WidgetState.quickSettingsView = "audio";
                WidgetState.quickSettingsOpen = true;
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: mouseArea.pointerHovered
        text: (Volume.sinkMuted ? qsTr("Volume: muted") : qsTr("Volume: ") + Math.round(Volume.sinkVolume
                                                                                        * 100) + "%") + qsTr(
                  "\nScroll to adjust; click to open sound")
    }
}
