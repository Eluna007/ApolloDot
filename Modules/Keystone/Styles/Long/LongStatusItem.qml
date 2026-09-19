import QtQuick
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    required property string itemId
    required property var screen
    readonly property var player: MediaManager.active
    readonly property var monitor: Brightness.getMonitorForScreen(screen)
    readonly property real brightness: monitor ? monitor.brightness : Brightness.brightnessValue
    required property string ownerId
    readonly property string label: {
        const option = PersonalizationConfig.keystoneLongItemOptions.find(option => option.value
                                                                                    === root.itemId);
        return option ? option.label : "";
    }
    readonly property string iconName: {
        switch (itemId) {
        case "media":
            return player ? (player.isPlaying ? "play_arrow" : "pause") : "music_note";
        case "network":
            if (!NetworkService.connected)
                return "wifi_off";
            if (NetworkService.activeConnectionType === "ETHERNET")
                return "settings_ethernet";
            const strength = Number(NetworkService.signalStrength || 0);
            return strength >= 80 ? "signal_wifi_4_bar" : strength >= 60 ? "network_wifi_3_bar" : strength
                                                                           >= 40 ? "network_wifi_2_bar" :
                                                                                   strength >= 20
                                                                                   ? "network_wifi_1_bar" :
                                                                                     "signal_wifi_0_bar";
        case "bluetooth":
            return BluetoothService.connected ? "bluetooth_connected" : BluetoothService.enabled
                                                ? "bluetooth" : "bluetooth_disabled";
        case "battery":
            if (!PowerService.ready || !PowerService.present)
                return "battery_unknown";
            if (PowerService.charging)
                return "battery_charging_full";
            const level = PowerService.percentage;
            return level >= 0.95 ? "battery_full" : level >= 0.8 ? "battery_6_bar" : level >= 0.65
                                                                   ? "battery_5_bar" : level >= 0.5
                                                                     ? "battery_4_bar" : level >= 0.35
                                                                       ? "battery_3_bar" : level >= 0.2
                                                                         ? "battery_2_bar" : level >= 0.1
                                                                           ? "battery_1_bar" :
                                                                             "battery_alert";
        case "volume":
            return !Volume.outputAvailable || Volume.sinkMuted || Volume.sinkVolume <= 0 ? "volume_off" :
                                                                                           Volume.isHeadphone
                                                                                           ? "headphones" :
                                                                                             Volume.sinkVolume
                                                                                             < 0.5 ? "volume_down" :
                                                                                                     "volume_up";
        case "microphone":
            return !Volume.inputAvailable || Volume.sourceMuted ? "mic_off" : "mic";
        case "brightness":
            return "brightness_medium";
        default:
            return "monitor_heart";
        }
    }
    readonly property string tooltipText: {
        switch (itemId) {
        case "media":
            return player ? [player.trackTitle, player.trackArtist, player.identity].filter(value => !!value).join(
                                "\n") : qsTr("No media");
        case "network":
            return NetworkService.connected ? NetworkService.activeConnection || qsTr("Network connected") :
                                              qsTr("Network disconnected");
        case "bluetooth":
            return !BluetoothService.available ? qsTr("Bluetooth unavailable") : BluetoothService.connected
                                                 ? BluetoothService.connectedName : BluetoothService.enabled
                                                   ? qsTr("Bluetooth on") : qsTr("Bluetooth off");
        case "battery":
            if (!PowerService.ready)
                return qsTr("Detecting battery");
            if (!PowerService.present)
                return qsTr("No battery detected");
            const state = PowerService.full ? qsTr("Fully charged") : PowerService.charging ? qsTr("Charging") :
                                                                                              PowerService.discharging
                                                                                              ? qsTr("Discharging") :
                                                                                                qsTr("Plugged in");
            return qsTr("Battery: %1% · %2").arg(Math.round(PowerService.percentage * 100)).arg(state);
        case "brightness":
            return qsTr("Brightness: %1%\n%2\nScroll to adjust").arg(Math.round(brightness * 100)).arg(screen
                                                                                                       ? screen.name :
                                                                                                         "");
        case "volume":
            return !Volume.outputAvailable ? qsTr("No audio output") : (Volume.sinkMuted ? qsTr(
                                                                                               "Volume: muted\n%1").arg(
                                                                                               Volume.sinkName) :
                                                                                           qsTr("Volume: %1%\n%2").arg(
                                                                                               Math.round(
                                                                                                   Volume.sinkVolume
                                                                                                   * 100)).arg(
                                                                                               Volume.sinkName));
        case "microphone":
            return !Volume.inputAvailable ? qsTr("No audio input") : (Volume.sourceMuted ? qsTr(
                                                                                               "Microphone: muted\n%1").arg(
                                                                                               Volume.sourceName) :
                                                                                           qsTr("Microphone: %1%\n%2").arg(
                                                                                               Math.round(
                                                                                                   Volume.sourceVolume
                                                                                                   * 100)).arg(
                                                                                               Volume.sourceName));
        default:
            return [SystemMonitorService.statusText, qsTr(
                        "CPU: %1\nMemory: %2\nDisk: %3\nTemperature: %4").arg(Format.percent(
                                                                                  SystemMonitorService.cpu.usagePercent)).arg(
                        Format.percent(SystemMonitorService.memory.usagePercent)).arg(Format.percent(
                                                                                          Format.rootDisk(
                                                                                              SystemMonitorService.disks).usagePercent)).arg(
                        Format.temperature(Format.isNumber(
                                               SystemMonitorService.cpu.packageTemperatureCelsius)
                                           ? SystemMonitorService.cpu.packageTemperatureCelsius :
                                             SystemMonitorService.cpu.temperatureCelsius,
                                           UiPreferences.systemTemperatureUnit === "fahrenheit")),
                    SystemMonitorService.errorMessage, SystemMonitorService.actionError].filter(value => !
                                                                                                         !value).join(
                        "\n");
        }
    }

    signal mediaRequested

    function activate(button) {
        if (itemId === "media") {
            if (button === Qt.MiddleButton && player && player.canTogglePlaying)
                player.togglePlaying();
            else
                mediaRequested();
            return;
        }
        if (button === Qt.MiddleButton && itemId === "volume") {
            Volume.toggleSinkMute();
            return;
        }
        if (button === Qt.MiddleButton && itemId === "microphone") {
            Volume.toggleSourceMute();
            return;
        }
        if (itemId === "systemMonitor") {
            SystemMonitorService.openFullMonitor();
            return;
        }
        const view = itemId === "volume" ? "audio" : itemId;
        if (["network", "bluetooth", "audio", "microphone"].indexOf(view) < 0)
            return;
        if (screen)
            WidgetState.quickSettingsScreenName = screen.name;
        if (WidgetState.quickSettingsOpen && WidgetState.quickSettingsView === view)
            WidgetState.quickSettingsOpen = false;
        else {
            WidgetState.quickSettingsView = view;
            WidgetState.quickSettingsOpen = true;
        }
    }

    implicitWidth: 32
    implicitHeight: 32
    Accessible.role: itemId === "battery" || itemId === "brightness" ? Accessible.StaticText :
                                                                       Accessible.Button

    Accessible.name: label
    Accessible.description: tooltipText
    Accessible.onPressAction: activate(Qt.LeftButton)
    Component.onCompleted: {
        if (itemId === "systemMonitor")
            SystemMonitorService.setConsumerModules(ownerId, ["cpu", "memory", "disk"]);
    }
    Component.onDestruction: {
        if (itemId === "systemMonitor")
            SystemMonitorService.clearConsumer(ownerId);
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.iconName
        iconSize: 20
        fill: 1
        color: root.itemId === "battery" && PowerService.discharging && PowerService.percentage <= 0.15
               ? Appearance.colors.colError : pointer.containsMouse ? Appearance.colors.colPrimary :
                                                                      Appearance.colors.colOnSurface
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: root.itemId === "battery" || root.itemId === "brightness" ? Qt.ArrowCursor :
                                                                                 Qt.PointingHandCursor
        onClicked: mouse => root.activate(mouse.button)
        onWheel: wheel => {
            const delta = wheel.angleDelta.y || wheel.angleDelta.x;
            if (!delta)
                return;
            const step = delta > 0 ? 0.05 : -0.05;
            if (root.itemId === "volume" && Volume.outputAvailable)
                Volume.setSinkVolume(Volume.sinkVolume + step);
            else if (root.itemId === "microphone" && Volume.inputAvailable)
                Volume.setSourceVolume(Volume.sourceVolume + step);
            else if (root.itemId === "brightness")
                Brightness.setBrightnessForScreen(root.screen, root.brightness + step);
            else {
                wheel.accepted = false;
                return;
            }
            wheel.accepted = true;
        }
    }

    PopupToolTip {
        extraVisibleCondition: pointer.containsMouse
        text: root.tooltipText
        textFormat: Text.PlainText
    }
}
