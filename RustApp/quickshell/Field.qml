import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

// Theme-aware single-line text field.
TextField {
    id: control

    property color fg: Theme.palette.text

    implicitWidth: 120
    implicitHeight: 30

    color: fg
    selectionColor: Theme.palette.primary
    selectedTextColor: Theme.palette.bg
    placeholderTextColor: Theme.palette.textFaint

    background: Rectangle {
        radius: 7
        color: Theme.palette.surface
        border.color: control.activeFocus ? Theme.palette.primary : Theme.palette.border
        border.width: 1
    }

    onEditingFinished: { if (length) Qt.callLater(function(){ editCommitted(text) }) }
    signal editCommitted(string value)
}