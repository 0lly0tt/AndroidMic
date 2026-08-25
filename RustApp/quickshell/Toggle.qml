import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

// Theme-aware switch.
Item {
    id: root

    property bool on: false
    signal switched(bool value)

    implicitWidth: 40
    implicitHeight: 22

    function setOn(v) { root.on = !!v }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.on ? Theme.palette.primary : Theme.palette.surfaceAlt
        border.color: root.on ? Theme.palette.primary : Theme.palette.border
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Rectangle {
        width: 16
        height: 16
        radius: height / 2
        color: Theme.palette.text
        y: (parent.height - height) / 2
        x: root.on ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.on = !root.on
            root.toggled(root.on)
        }
    }
}