import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

// A titled settings card. Children declared inside it are laid out
// vertically below a section header. Width fills its parent so the section
// (and its controls) align to the dialog field.
Item {
    id: root

    property string title: ""

    implicitHeight: content.implicitHeight + 30
    width: parent ? parent.width : 0

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.palette.surfaceAlt
        border.color: Theme.palette.borderSoft
        border.width: 1
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 9

        Text {
            text: root.title
            color: Theme.palette.textDim
            font.pixelSize: 11
            font.bold: true
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
            Layout.fillWidth: true
        }
    }

    default property alias children: content.data
}