import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property bool vertical: false
    readonly property bool showValue: PersonalizationConfig.barShowValues
    readonly property string temperatureText: WeatherPlugin.hasValidData ? Math.round(
                                                                               UiPreferences.weatherTemperature(
                                                                                   WeatherPlugin.currentTemperatureC))
                                                                           + "°" : "--°"
    readonly property int iconSize: 20
    readonly property int temperatureSize: 12
    readonly property int contentSpacing: 6
    readonly property int iconSlotWidth: 24
    readonly property real temperatureSlotWidth: Math.ceil(temperatureMetrics.width)
    readonly property real buttonWidth: root.iconSlotWidth + (root.showValue ? root.contentSpacing + root.temperatureSlotWidth :
                                                                               0) + 20
    readonly property int buttonHeight: Sizes.barControlCircleSize
    readonly property bool active: WidgetState.dashboardSidebarOpen && WidgetState.dashboardSidebarView
                                   === "weather"

    function toggleView() {
        if (root.active) {
            WidgetState.dashboardSidebarOpen = false;
            return;
        }
        WidgetState.dashboardSidebarView = "weather";
        WidgetState.dashboardSidebarOpen = true;
    }

    implicitWidth: root.vertical ? root.buttonHeight : root.buttonWidth
    implicitHeight: root.vertical && root.showValue ? Sizes.barWeatherVerticalPillHeight : root.buttonHeight

    TextMetrics {
        id: temperatureMetrics

        text: root.temperatureText
        font.family: Fonts.numeric
        font.pixelSize: root.temperatureSize
        font.bold: true
    }

    RippleButton {
        id: button

        anchors.fill: parent
        buttonRadius: height / 2
        containerColor: "transparent"
        rippleColor: Appearance.colors.colOnSurface
        stateLayerEnabled: false
        releaseAction: () => {
            return root.toggleView();
        }

        contentItem: Item {
            anchors.fill: parent

            GridLayout {
                anchors.centerIn: parent
                columns: root.vertical ? 1 : 2
                rowSpacing: root.vertical ? 2 : 0
                columnSpacing: root.vertical ? 0 : root.contentSpacing

                MaterialSymbol {
                    Layout.preferredWidth: root.vertical ? root.buttonHeight : root.iconSlotWidth
                    Layout.preferredHeight: root.vertical ? 20 : root.buttonHeight
                    Layout.alignment: Qt.AlignCenter
                    text: WeatherPlugin.currentIconName || "cloud"
                    iconSize: root.iconSize
                    fill: 0
                    color: Appearance.colors.colOnSurface
                }

                Text {
                    visible: root.showValue
                    Layout.preferredWidth: root.vertical ? root.buttonHeight : root.temperatureSlotWidth
                    Layout.preferredHeight: root.vertical ? 16 : root.buttonHeight
                    Layout.alignment: Qt.AlignCenter
                    text: root.temperatureText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Fonts.numeric
                    font.pixelSize: root.temperatureSize
                    font.bold: true
                    color: Appearance.colors.colOnSurface
                }
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: button.pointerHovered
        text: qsTr("Weather")
    }
}
