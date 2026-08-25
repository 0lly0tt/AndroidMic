import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

// Theme-aware Button.
Button {
    id: control

    property color accent: Theme.palette.surfaceAlt
    property color fg: Theme.palette.text

    implicitWidth: Math.max(72, control.contentItem.implicitWidth + 24)
    implicitHeight: 30

    background: Rectangle {
        radius: 7
        color: control.down ? Theme.shade(control.accent, 0.85)
             : control.hovered ? Theme.shade(control.accent, 1.15)
             : control.accent
    }

    contentItem: Text {
        text: control.text
        color: control.enabled ? control.fg : Theme.palette.textFaint
        font.pixelSize: 12
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}