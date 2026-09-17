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
    property real availableHeight: 360
    property int selectedCandidate: 0
    signal inputFocusRequested
    readonly property var service: SpotlightToolService
    height: visible ? Math.min(Math.max(120, content.implicitHeight + 48), 320, Math.max(0, availableHeight)) :
                      0
    radius: style.resultRadius
    color: style.panelColor
    clip: true
    StyledFlickable {
        anchors.fill: parent
        anchors.margins: 24
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
                    text: root.templateController.currencyMode ? qsTr("Switch side") : qsTr("Change source")
                    onClicked: {
                        if (root.templateController.currencyMode)
                            root.templateController.unitSide = root.templateController.unitSide === "left"
                                    ? "right" : "left";
                        else
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
                Layout.preferredHeight: visible ? Math.min(root.templateController.currencyMode ? 120 : 180,
                                                           Math.max(72, root.availableHeight - 120)) : 0
                visible: root.templateController.choices.length > 0
                model: root.templateController.choices
                currentIndex: root.templateController.selected
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
                    height: 40
                    radius: Appearance.rounding.small
                    color: index === root.templateController.selected ? root.style.selectedColor :
                                                                        "transparent"
                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
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
                        font.pixelSize: 14
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.templateController.choose(choiceRow.index);
                            root.inputFocusRequested();
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.service.state === "loading" ? qsTr("Calculating…") : root.service.state === "empty"
                                                         || root.service.state === "incomplete" ? qsTr(
                                                                                                      "Enter an expression to begin") :
                                                                                                  root.service.state
                                                                                                  === "ambiguous"
                                                                                                  ? qsTr("This time occurs twice. Choose a UTC offset.") :
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
                visible: root.service.canCopy && !root.templateController.currencyMode
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
                    if (root.service.tool === "currency" && value.approximate)
                        return qsTr("Approximate · ECB · %1 · %2").arg(value.date).arg(value.cache
                                                                                       === "stale" ? qsTr(
                                                                                                         "Older cached rate") :
                                                                                                     qsTr("Reference rate"));
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
                text: root.service.feedback || (root.service.canCopy ? qsTr("Enter to copy") : "")
                textFormat: Text.PlainText
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 14
            }
        }
    }
}
