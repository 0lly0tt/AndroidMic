import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

// A titled settings card. Children declared inside it are laid out
// vertically (honouring Layout.fillWidth) below a section header.
Item {
    id: root

    property string title: ""

    implicitWidth: 440
    implicitHeight: content.implicitHeight + 30

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