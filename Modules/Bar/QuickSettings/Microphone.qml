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

        value: Volume.sourceMuted ? 0 : Volume.sourceVolume
        progressColor: (Volume.sourceMuted || Volume.sourceVolume <= 0) ? Appearance.colors.colError :
                                                                          Appearance.colors.colPrimary
        trackColor: Appearance.colors.colLayer2Hover
        handleColor: Appearance.colors.colOnSurface
        iconColor: (Volume.sourceMuted || Volume.sourceVolume <= 0) ? Appearance.colors.colError :
                                                                      Appearance.colors.colOnSurface
        icon: (Volume.sourceMuted || Volume.sourceVolume <= 0) ? "mic_off" : "mic"
    }

    Text {
        id: valueText
        visible: root.showValue
        text: Math.round(Volume.sourceVolume * 100) + "%"
        font.family: Fonts.numeric
        font.pixelSize: 12
        color: Appearance.colors.colOnSurface
        x: root.vertical ? (root.width - width) / 2 : 34
        y: root.vertical ? 32 : (root.height - height) / 2
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onWheel: wheel => {
            const step = 0.05;
            let newVol = Volume.sourceVolume;
            if (wheel.angleDelta.y > 0)
                newVol += step;
            else
                newVol -= step;
            Volume.setSourceVolume(newVol);
            wheel.accepted = true;
        }
        onClicked: {
            if (root.screen && root.screen.name)
                WidgetState.quickSettingsScreenName = root.screen.name;
            if (WidgetState.quickSettingsOpen && WidgetState.quickSettingsView === "microphone") {
                WidgetState.quickSettingsOpen = false;
            } else {
                WidgetState.quickSettingsView = "microphone";
                WidgetState.quickSettingsOpen = true;
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: (Volume.sourceMuted ? qsTr("Microphone: muted") : qsTr("Microphone: ") + Math.round(
                                        Volume.sourceVolume * 100) + "%") + qsTr(
                  "\nScroll to adjust; click to open microphone controls")
    }
}
