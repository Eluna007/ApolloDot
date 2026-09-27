import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

TopBarPill {
    id: root

    property bool vertical: false
    backgroundVisible: false

    implicitHeight: vertical ? buttonRow.implicitHeight + 16 : Sizes.barPillThickness
    implicitWidth: vertical ? Sizes.barVisualThickness : buttonRow.implicitWidth + 16

    GridLayout {
        id: buttonRow

        anchors.centerIn: parent
        rowSpacing: 8
        columnSpacing: 8
        columns: root.vertical ? 1 : 3

        SidebarPillButton {
            viewName: "info"
            sidebarIconName: "notifications"
        }

        SidebarPillButton {
            viewName: "drawer"
            sidebarIconName: "widgets"
        }

        SidebarWeatherButton {
            vertical: root.vertical
        }
    }
}
