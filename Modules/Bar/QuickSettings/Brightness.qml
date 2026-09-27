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
    readonly property var monitor: Brightness.getMonitorForScreen(screen)
    readonly property real brightnessValue: monitor ? monitor.brightness : Brightness.brightnessValue

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

        value: root.brightnessValue
        progressColor: Appearance.colors.colPrimary
        trackColor: Appearance.colors.colLayer2Hover
        handleColor: Appearance.colors.colOnSurface
        iconColor: Appearance.colors.colOnSurface
        icon: "brightness_medium"
    }

    Text {
        id: valueText
        visible: root.showValue
        text: Math.round(root.brightnessValue * 100) + "%"
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
            let newBri = root.brightnessValue;
            if (wheel.angleDelta.y > 0)
                newBri += step;
            else
                newBri -= step;
            Brightness.setBrightnessForScreen(root.screen, newBri);
            wheel.accepted = true;
        }
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: qsTr("Brightness: ") + Math.round(root.brightnessValue * 100) + qsTr("%\nScroll to adjust")
    }
}
