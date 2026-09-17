pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root
    required property SpotlightStyle style
    required property SpotlightTemplateController templateController
    required property SpotlightCurrencyController currencyController
    readonly property bool currencyMode: service.tool === "currency"
    readonly property var choices: currencyMode ? currencyController.choices : templateController.choices
    readonly property int candidateRowHeight: currencyMode ? 52 : 40
    property real availableHeight: 360
    property int selectedCandidate: 0
    signal inputFocusRequested
    readonly property var service: SpotlightToolService
    height: visible ? Math.min(Math.max(root.currencyMode ? 40 : 120, content.implicitHeight + 48),
                               root.currencyMode ? 360 : 320, Math.max(0, availableHeight)) : 0
    radius: style.resultRadius
    color: style.panelColor
    clip: true
    Text {
        id: currencyNote
        x: 20
        y: 8
        width: parent.width - 40
        visible: root.currencyMode
        text: {
            const value = root.service.result;
            if (!root.currencyMode || !root.service.canCopy || !value || !value.approximate)
                return "";
            return qsTr("Approximate · ECB · %1 · %2").arg(value.date).arg(value.cache === "stale" ? qsTr(
                                                                                                         "Older cached rate") :
                                                                                                     qsTr("Reference rate"));
        }
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: Fonts.ui
        font.pixelSize: 12
        color: Appearance.colors.colOnSurfaceVariant
    }
    StyledFlickable {
        anchors.fill: parent
        anchors.margins: 24
        anchors.topMargin: root.currencyMode ? 32 : 24
        anchors.bottomMargin: root.currencyMode ? 16 : 24
        contentWidth: width
        contentHeight: content.implicitHeight
        ScrollBar.vertical: StyledScrollBar {}
        ColumnLayout {
            id: content
            width: parent.width
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                visible: root.templateController.active
                Text {
                    Layout.fillWidth: true
                    text: root.templateController.timeMode && !root.templateController.choosingTime
                          ? root.templateController.direction : root.templateController.heading
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 16
                }
                ActionButton {
                    text: qsTr("Change source")
                    onClicked: {
                        root.templateController.changeSource();
                        root.inputFocusRequested();
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: root.templateController.timeMode && !root.templateController.choosingTime
                         && root.service.state === "empty"
                text: qsTr("Enter a time, for example 0930. Backspace on empty input changes the template.")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 14
            }
            ListView {
                id: templateList
                Layout.fillWidth: true
                Layout.preferredHeight: !visible ? 0 : root.currencyMode ? Math.min(Math.min(root.choices.length,
                                                                                             6) * root.candidateRowHeight,
                                                                                    Math.max(0,
                                                                                             root.availableHeight
                                                                                             - 48)) : Math.min(
                                                                               180, Math.max(72,
                                                                                             root.availableHeight
                                                                                             - 120))
                visible: root.choices.length > 0
                model: root.choices
                currentIndex: root.currencyMode ? root.currencyController.selected :
                                                  root.templateController.selected
                clip: true
                keyNavigationEnabled: false
                onCurrentIndexChanged: if (currentIndex >= 0)
                                           positionViewAtIndex(currentIndex, ListView.Contain)
                ScrollBar.vertical: StyledScrollBar {}
                delegate: Rectangle {
                    id: choiceRow
                    required property var modelData
                    required property int index
                    width: templateList.width
                    height: root.candidateRowHeight
                    radius: Appearance.rounding.small
                    color: index === templateList.currentIndex ? root.style.selectedColor : "transparent"
                    Text {
                        anchors.fill: parent
                        anchors.margins: root.currencyMode ? 14 : 8
                        verticalAlignment: Text.AlignVCenter
                        text: root.templateController.timeMode && !root.templateController.choosingSource ? (
                                                                                                                root.templateController.sourceZone
                                                                                                                || qsTr("Local time"))
                                                                                                            + " → " + choiceRow.modelData.text :
                                                                                                            choiceRow.modelData.text
                                                                                                            + (choiceRow.modelData.name
                                                                                                               !== choiceRow.modelData.text
                                                                                                               ? " · " + choiceRow.modelData.name :
                                                                                                                 "")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: root.currencyMode ? 16 : 14
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.currencyMode)
                                root.currencyController.choose(choiceRow.index);
                            else
                                root.templateController.choose(choiceRow.index);
                            root.inputFocusRequested();
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.currencyMode ? (root.currencyController.amountError || root.service.error || (
                                               root.currencyController.choosing && !root.choices.length ? qsTr(
                                                                                                              "No matching currencies") :
                                                                                                          "")) : root.service.state
                                          === "loading" ? qsTr("Calculating…") : root.service.state
                                                          === "empty" || root.service.state === "incomplete"
                                                          ? qsTr("Enter an expression to begin") :
                                                            root.service.state === "ambiguous" ? qsTr(
                                                                                                     "This time occurs twice. Choose a UTC offset.") :
                                                                                                 root.service.error
                visible: text.length > 0 && (!root.templateController.active || (root.service.state
                                                                                 !== "empty"
                                                                                 && root.service.state
                                                                                 !== "incomplete"))
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: root.service.state === "error" || root.service.state === "unavailable"
                       ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 16
            }
            Text {
                Layout.fillWidth: true
                visible: root.service.canCopy && !root.currencyMode
                text: root.service.canCopy ? root.service.result.answer : ""
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: 28
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: {
                    const value = root.service.result;
                    if (!root.service.canCopy || !value)
                        return "";
                    if (root.service.tool === "time")
                        return qsTr("From %1 · %2 · UTC%3\nDay difference: %4").arg(value.source.datetime).arg(
                                    value.source.zone).arg(value.source.offset).arg(value.dayDelta);
                    return "";
                }
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 14
            }
            Repeater {
                model: root.service.state === "ambiguous" && root.service.result ? root.service.result.candidates :
                                                                                   []
                delegate: ActionButton {
                    required property var modelData
                    required property int index
                    filled: index === root.selectedCandidate
                    text: "UTC" + modelData.offset
                    onClicked: {
                        root.service.confirmFold(modelData.fold);
                        root.inputFocusRequested();
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: !root.currencyMode && text.length > 0
                text: root.service.feedback || (root.service.canCopy ? qsTr("Enter to copy") : "")
                textFormat: Text.PlainText
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 14
            }
        }
    }
}
