import QtQuick
import QtQuick.Layouts
import Quickshell
import "Theme.js" as Theme

// A small entry button used when a system-tray host is unavailable (mock/demo)
// and to let users summon the dialogs without the tray submenu.
FloatingWindow {
    id: root

    property var model: null

    implicitWidth: 176
    implicitHeight: 46
    visible: root.model ? root.model.launcherVisible : false

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.palette.surface
        border.color: Theme.palette.border
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 6

            QsButton {
                Layout.fillWidth: true
                text: "Info"
                accent: Theme.palette.primary
                onClicked: root.model.infoVisible = true
            }
            QsButton {
                Layout.fillWidth: true
                text: "Settings"
                onClicked: root.model.settingsVisible = true
            }
        }
    }
}