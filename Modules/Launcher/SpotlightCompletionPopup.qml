pragma ComponentBehavior: Bound
import QtQuick
import qs.Common

Rectangle {
    id: root
    required property SpotlightCompletionController controller
    required property SpotlightStyle style
    property real availableHeight: 320
    height: visible ? Math.min(controller.choices.length * 38 + 12, Math.max(0, availableHeight)) : 0
    visible: controller.opened
    color: style.panelColor
    radius: Appearance.rounding.large
    border.color: Appearance.colors.colOutlineVariant
    clip: true
    ListView {
        anchors.fill: parent
        anchors.margins: 6
        model: root.controller.choices
        currentIndex: root.controller.selected
        keyNavigationEnabled: false
        highlightMoveDuration: 100
        delegate: Rectangle {
            id: candidateRow
            required property int index
            required property var modelData
            width: ListView.view.width
            height: 38
            radius: Appearance.rounding.small
            color: candidateRow.index === root.controller.selected ? root.style.selectedColor : "transparent"
            Text {
                anchors.fill: parent
                anchors.margins: 8
                text: candidateRow.modelData.name && candidateRow.modelData.name
                      !== candidateRow.modelData.text ? candidateRow.modelData.text + " · "
                                                        + candidateRow.modelData.name :
                                                        candidateRow.modelData.text
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.controller.selected = candidateRow.index;
                    root.controller.accept();
                }
            }
        }
    }
}
