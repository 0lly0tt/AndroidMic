import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

// A labelled boolean toggle row inside a settings section.
RowLayout {
    id: root

    property string label: ""
    property string key: ""
    property var model: null

    implicitHeight: 26
    spacing: 8
    Layout.fillWidth: true

    Text {
        text: root.label
        color: Theme.palette.text
        font.pixelSize: 12
        Layout.fillWidth: true
    }

    Toggle {
        on: root.model ? root.model.config[root.key] : false
        onSwitched: function(v) { if (root.model) root.model.sendConfig(root.key, v) }
    }
}