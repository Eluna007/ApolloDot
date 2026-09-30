import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    readonly property var nativeCornerStatus: NiriConfigService.snapshot.hotCorners || ({})
    readonly property var outputConflicts: nativeCornerStatus.outputConflicts || []
    readonly property var cornerOptions: [
        {
            value: "top-left",
            label: qsTr("Top left")
        },
        {
            value: "top-right",
            label: qsTr("Top right")
        },
        {
            value: "bottom-left",
            label: qsTr("Bottom left")
        },
        {
            value: "bottom-right",
            label: qsTr("Bottom right")
        }
    ]
    readonly property var actionOptions: [
        {
            value: "disabled",
            label: qsTr("Disabled")
        },
        {
            value: "overview",
            label: qsTr("Niri Overview")
        },
        {
            value: "dashboard:info",
            label: qsTr("Information")
        },
        {
            value: "dashboard:drawer",
            label: qsTr("Drawer")
        },
        {
            value: "dashboard:weather",
            label: qsTr("Weather")
        },
        {
            value: "quicksettings:settings",
            label: qsTr("Quick settings")
        },
        {
            value: "quicksettings:network",
            label: qsTr("Network")
        },
        {
            value: "quicksettings:bluetooth",
            label: qsTr("Bluetooth")
        },
        {
            value: "quicksettings:audio",
            label: qsTr("Audio output")
        },
        {
            value: "quicksettings:microphone",
            label: qsTr("Microphone")
        },
        {
            value: "quicksettings:idle",
            label: qsTr("Idle management")
        },
        {
            value: "quicksettings:night",
            label: qsTr("Night light")
        }
    ]

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2
    Component.onCompleted: NiriConfigService.refresh()

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Hot corners")
            description: qsTr(
                             "Let Clavis manage corner actions instead of the compositor's overview gesture.")
            integrationState: NiriConfigService.state("hot-corners")
            busy: NiriConfigService.busy
            blocked: root.outputConflicts.length > 0
            error: NiriConfigService.errorFeature === "hot-corners" ? NiriConfigService.error :
                                                                      NiriConfigService.configurationMessage
            onSetupRequested: NiriConfigService.setup("hot-corners")
        }

        Repeater {
            model: root.outputConflicts

            InlineStatusBanner {
                required property var modelData

                Layout.fillWidth: true
                tone: "warning"
                message: qsTr("Disable the compositor's hot corners for %1 in %2.").arg(
                             modelData.identifier).arg(modelData.source)
            }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: NiriConfigService.state("hot-corners") === "conflict" && root.outputConflicts.length
                     === 0
            tone: "warning"
            message: qsTr("Another compositor configuration enables hot corners: %1").arg(
                         root.nativeCornerStatus.globalSource || "")
        }

        SettingsSection {
            id: cornerSection

            Layout.fillWidth: true
            title: searchAnchor.title
            iconName: "open_in_full"
            enabled: NiriConfigService.ready("hot-corners")

            SettingsSearchAnchor {
                id: searchAnchor

                target: cornerSection
                declaration:
                    '{"id":"general.hot-corners.section.actions","route":"general.hot-corners","title":"Corner actions","context":"HotCornersPage","icon":"open_in_full","aliases":[]}'
            }

            Repeater {
                model: root.cornerOptions

                DisplayChoice {
                    required property var modelData

                    Layout.fillWidth: true
                    title: modelData.label
                    options: root.actionOptions
                    value: PersonalizationConfig.hotCornerActions[modelData.value]
                    onSelected: value => PersonalizationConfig.setHotCornerAction(modelData.value, value)
                }
            }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: NiriConfigService.ready("hot-corners") && NiriConfigService.errorFeature
                     === "hot-corners" && NiriConfigService.error !== ""
            tone: "error"
            message: NiriConfigService.error
        }
    }
}
