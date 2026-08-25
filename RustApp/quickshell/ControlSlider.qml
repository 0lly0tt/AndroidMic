import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

// Theme-aware slider.
Slider {
    id: control

    property color accent: Theme.palette.primary

    implicitWidth: 180
    implicitHeight: 22

    background: Rectangle {
        implicitWidth: 180
        implicitHeight: 4
        radius: 2
        color: Theme.palette.surfaceAlt
        y: control.height / 2 - implicitHeight / 2
        Rectangle {
            width: control.handlePosition * parent.width
            height: 4
            radius: 2
            color: control.accent
        }
    }

    handle: Rectangle {
        implicitWidth: 14
        implicitHeight: 14
        radius: 7
        color: control.pressed ? control.accent : Theme.palette.text
        border.color: Theme.palette.border
        y: control.height / 2 - implicitHeight / 2
        x: control.handlePosition * (control.width - implicitWidth)
    }
}