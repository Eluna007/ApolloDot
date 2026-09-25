import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

WidgetPanel {
    id: root

    property bool foreground: false
    readonly property bool isActive: root.foreground && WidgetState.quickSettingsView === "tailscale"
    readonly property bool controlsEnabled: TailscaleService.available && !TailscaleService.busy
                                            && !TailscaleService.needsOperator
    readonly property string stateMessage: {
        if (TailscaleService.lastError.length > 0)
            return TailscaleService.lastError;
        if (!TailscaleService.probed)
            return "";
        if (!TailscaleService.available)
            return qsTr("Tailscale is not installed");
        if (!TailscaleService.status.ok)
            return qsTr("The Tailscale daemon is not running. Start it with: systemctl enable --now tailscaled");
        if (TailscaleService.needsLogin)
            return TailscaleService.loggingIn ? qsTr("Finish logging in in your browser") : qsTr(
                                                    "Log in to connect this device to your tailnet");
        return "";
    }

    function osIcon(os) {
        switch (String(os || "").toLowerCase()) {
        case "android":
        case "ios":
            return "smartphone";
        case "macos":
        case "windows":
            return "laptop";
        case "linux":
        case "freebsd":
        case "openbsd":
            return "computer";
        default:
            return "devices";
        }
    }

    function peerSupportingText(peer) {
        const parts = [];
        if (peer.ipv4)
            parts.push(peer.ipv4);
        if (peer.os)
            parts.push(peer.os);
        parts.push(peer.online ? qsTr("Online") : qsTr("Offline"));
        return parts.join(" · ");
    }

    function updateLease() {
        if (root.isActive)
            TailscaleService.watch("quick-settings-tailscale");
        else
            TailscaleService.unwatch("quick-settings-tailscale");
    }

    title: qsTr("Tailscale")
    icon: "vpn_lock"
    showBackButton: true
    backAction: () => {
        return WidgetState.quickSettingsView = "settings";
    }
    onIsActiveChanged: updateLease()
    Component.onCompleted: updateLease()
    Component.onDestruction: TailscaleService.unwatch("quick-settings-tailscale")

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.small

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: TailscaleService.busy ? 4 : 0
            opacity: TailscaleService.busy ? 1 : 0
            indeterminate: true
            Material.accent: Appearance.colors.colPrimary

            Behavior on Layout.preferredHeight {
                ElementMoveAnimation {}
            }

            Behavior on opacity {
                ElementMoveAnimation {}
            }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.stateMessage.length > 0
            tone: TailscaleService.lastError.length > 0 ? "error" : "info"
            message: root.stateMessage
        }

        Repeater {
            model: TailscaleService.connected ? TailscaleService.status.health : []

            InlineStatusBanner {
                required property string modelData

                Layout.fillWidth: true
                tone: "warning"
                message: modelData
            }
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: tailscaleContent.implicitHeight

            ColumnLayout {
                id: tailscaleContent

                width: parent.width - Appearance.spacing.small
                spacing: Appearance.spacing.small

                // ── Access ──────────────────────────────────────────────
                SettingsSection {
                    Layout.fillWidth: true
                    visible: TailscaleService.needsOperator
                    title: qsTr("Access")

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "admin_panel_settings"
                        title: qsTr("Operator access")
                        supportingText: qsTr(
                                            "Let %1 change Tailscale without a password. You are asked for your password once.").arg(
                                            TailscaleService.userName)

                        trailing: ActionButton {
                            text: qsTr("Grant access")
                            enabled: !TailscaleService.busy
                            onClicked: TailscaleService.grantOperator()
                        }
                    }
                }

                SettingsSection {
                    Layout.fillWidth: true
                    visible: TailscaleService.needsLogin
                    title: qsTr("Account")

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "login"
                        title: qsTr("Log in")
                        supportingText: TailscaleService.status.authUrl !== "" ? TailscaleService.status.authUrl :
                                                                                 qsTr("Opens the login page in your browser")

                        trailing: ActionButton {
                            text: TailscaleService.status.authUrl !== "" ? qsTr("Open") : qsTr("Log in")
                            enabled: TailscaleService.status.authUrl !== "" || !TailscaleService.loggingIn
                            onClicked: TailscaleService.login()
                        }
                    }
                }

                // ── This device ─────────────────────────────────────────
                SettingsSection {
                    Layout.fillWidth: true
                    visible: TailscaleService.connected
                    title: qsTr("This device")
                    supportingText: TailscaleService.status.tailnetName

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "computer"
                        title: TailscaleService.displayName(TailscaleService.self)
                        supportingText: TailscaleService.self.dnsName || TailscaleService.self.ipv4
                        highlighted: true

                        trailing: CopyButton {
                            node: TailscaleService.self
                        }
                    }
                }

                // ── Exit node ───────────────────────────────────────────
                SettingsSection {
                    Layout.fillWidth: true
                    visible: TailscaleService.connected
                    title: qsTr("Exit node")
                    supportingText: TailscaleService.exitNodeOptions.length === 0 ? qsTr(
                                                                                        "No device in this tailnet offers itself as an exit node") :
                                                                                    ""

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "block"
                        title: qsTr("None")
                        supportingText: qsTr("Use this device's own internet connection")
                        interactive: root.controlsEnabled
                        highlighted: TailscaleService.currentExitNode === null
                        onClicked: TailscaleService.setExitNode("")

                        trailing: MaterialSymbol {
                            visible: TailscaleService.currentExitNode === null
                            text: "check"
                            iconSize: 20
                            color: Appearance.colors.colPrimary
                        }
                    }

                    Repeater {
                        model: TailscaleService.exitNodeOptions

                        SettingsRow {
                            required property var modelData

                            Layout.fillWidth: true
                            iconName: "public"
                            title: TailscaleService.displayName(modelData)
                            supportingText: root.peerSupportingText(modelData)
                            interactive: root.controlsEnabled && modelData.online && !modelData.exitNode
                            highlighted: modelData.exitNode
                            enabled: modelData.online || modelData.exitNode
                            onClicked: TailscaleService.setExitNode(modelData.ipv4 || modelData.ips[0] || "")

                            trailing: MaterialSymbol {
                                visible: modelData.exitNode
                                text: "check"
                                iconSize: 20
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "lan"
                        title: qsTr("Allow local network access")
                        supportingText: qsTr("Reach printers and other LAN devices while using an exit node")

                        trailing: StyledSwitch {
                            scale: 0.72
                            checked: TailscaleService.prefs.exitNodeAllowLan
                            enabled: root.controlsEnabled
                            Accessible.name: qsTr("Allow local network access")
                            onToggled: TailscaleService.setExitNodeAllowLan(checked)
                        }
                    }
                }

                // ── Settings ────────────────────────────────────────────
                SettingsSection {
                    Layout.fillWidth: true
                    visible: TailscaleService.available && TailscaleService.prefs.ok
                    title: qsTr("Settings")

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "shield"
                        title: qsTr("Shields up")
                        supportingText: qsTr("Block incoming connections from other devices")

                        trailing: StyledSwitch {
                            scale: 0.72
                            checked: TailscaleService.prefs.shieldsUp
                            enabled: root.controlsEnabled
                            Accessible.name: qsTr("Shields up")
                            onToggled: TailscaleService.setShieldsUp(checked)
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "dns"
                        title: qsTr("Use Tailscale DNS")
                        supportingText: qsTr("MagicDNS names and the tailnet's DNS settings")

                        trailing: StyledSwitch {
                            scale: 0.72
                            checked: TailscaleService.prefs.acceptDns
                            enabled: root.controlsEnabled
                            Accessible.name: qsTr("Use Tailscale DNS")
                            onToggled: TailscaleService.setAcceptDns(checked)
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "alt_route"
                        title: qsTr("Accept routes")
                        supportingText: qsTr("Use subnet routes advertised by other devices")

                        trailing: StyledSwitch {
                            scale: 0.72
                            checked: TailscaleService.prefs.acceptRoutes
                            enabled: root.controlsEnabled
                            Accessible.name: qsTr("Accept routes")
                            onToggled: TailscaleService.setAcceptRoutes(checked)
                        }
                    }
                }

                // ── Devices ─────────────────────────────────────────────
                SettingsSection {
                    Layout.fillWidth: true
                    visible: TailscaleService.connected
                    title: qsTr("Devices")
                    supportingText: qsTr("%1 of %n online", "", TailscaleService.peers.length).arg(
                                        TailscaleService.onlinePeerCount)

                    Repeater {
                        model: TailscaleService.peers

                        SettingsRow {
                            required property var modelData

                            Layout.fillWidth: true
                            iconName: root.osIcon(modelData.os)
                            title: TailscaleService.displayName(modelData)
                            supportingText: root.peerSupportingText(modelData)
                            highlighted: modelData.online
                            opacity: modelData.online ? 1 : 0.6

                            trailing: CopyButton {
                                node: modelData
                            }
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: TailscaleService.peers.length === 0
                        iconName: "devices_off"
                        title: qsTr("No other devices in this tailnet")
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.spacing.small
                }
            }
        }
    }

    headerTools: RowLayout {
        spacing: Appearance.spacing.xSmall

        IconButton {
            enabled: TailscaleService.available
            iconName: "refresh"
            iconSize: 21
            iconColor: Appearance.colors.colOnLayer2
            accessibleName: qsTr("Refresh Tailscale status")
            hoverStateLayerColor: Appearance.colors.colLayer2Hover
            pressedStateLayerColor: Appearance.colors.colLayer2Active
            onClicked: TailscaleService.refresh()
        }

        StyledSwitch {
            scale: 0.8
            checked: TailscaleService.connected
            enabled: TailscaleService.available && TailscaleService.status.ok && !TailscaleService.busy
                     && (TailscaleService.needsLogin || !TailscaleService.needsOperator)
            Accessible.name: qsTr("Tailscale switch")
            onToggled: {
                TailscaleService.toggle();
                // The switch follows the daemon, not the click.
                checked = Qt.binding(() => TailscaleService.connected);
            }
        }
    }

    component CopyButton: IconButton {
        id: copyButton

        required property var node

        visible: node.ipv4 !== "" || node.dnsName !== ""
        controlSize: 34
        iconName: "content_copy"
        iconSize: 18
        iconColor: Appearance.colors.colOnLayer2
        accessibleName: qsTr("Copy address")
        hoverStateLayerColor: Appearance.colors.colLayer3Hover
        pressedStateLayerColor: Appearance.colors.colLayer3Active
        onClicked: copyMenu.open()

        StyledMenu {
            id: copyMenu

            StyledMenuItem {
                visible: copyButton.node.ipv4 !== ""
                iconName: "tag"
                text: qsTr("Copy IP address")
                onTriggered: TailscaleService.copy(copyButton.node.ipv4)
            }

            StyledMenuItem {
                visible: copyButton.node.dnsName !== ""
                iconName: "dns"
                text: qsTr("Copy MagicDNS name")
                onTriggered: TailscaleService.copy(copyButton.node.dnsName)
            }
        }
    }
}
