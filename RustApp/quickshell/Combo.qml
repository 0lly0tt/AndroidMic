import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import "Theme.js" as Theme

// Theme-aware ComboBox for JS-array models of plain values or objects
// ({textRole: ..., valueRole: ...}). Emits `picked(value)` on activation.
ComboBox {
    id: control

    property color fg: Theme.palette.text
    property color fieldBg: Theme.palette.surfaceAlt
    property color fieldBorder: Theme.palette.border
    property string emptyText: "—"

    // Wire these to the live config/model state.
    property var sourceModel: []
    property string textRoleName: ""
    property string valueRoleName: ""
    // Value currently selected in the model backing this control.
    property var selectedValue: null
    signal picked(var value)

    model: sourceModel

    implicitWidth: 200
    implicitHeight: 30

    function syncIndex() {
        if (!sourceModel || !sourceModel.length) { currentIndex = -1; return }
        var idx = -1
        for (var i = 0; i < sourceModel.length; i++) {
            var v = valueRoleName ? sourceModel[i][valueRoleName] : sourceModel[i]
            if (String(v) === String(selectedValue)) { idx = i; break }
        }
        currentIndex = idx
    }
    onSourceModelChanged: syncIndex()
    onSelectedValueChanged: syncIndex()
    Component.onCompleted: syncIndex()

    onActivated: {
        if (sourceModel.length)
            picked(valueRoleName ? sourceModel[currentIndex][valueRoleName] : sourceModel[currentIndex])
    }

    background: Rectangle {
        implicitHeight: 30
        radius: 7
        color: control.enabled ? control.fieldBg : Theme.palette.surface
        border.color: control.pressed ? Theme.palette.primary : control.fieldBorder
        border.width: 1
    }

    contentItem: Text {
        text: control.currentIndex >= 0 && control.currentText ? control.currentText : control.emptyText
        color: control.currentIndex >= 0 ? control.fg : Theme.palette.textFaint
        font.pixelSize: 12
        leftPadding: 10
        rightPadding: 26
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Item {
        implicitWidth: 18
        implicitHeight: 30
        Rectangle {
            width: 8
            height: 8
            x: 5
            y: 11
            rotation: 45
            color: "transparent"
            border.color: control.enabled ? control.fg : Theme.palette.textFaint
            border.width: 1
        }
    }

    delegate: ItemDelegate {
        width: control.width
        implicitHeight: 30
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: control.textRoleName && modelData ? String(modelData[control.textRoleName])
                  : (modelData === undefined ? "" : String(modelData))
            color: control.highlightedIndex === index ? Theme.palette.primary : Theme.palette.text
            font.pixelSize: 12
            leftPadding: 10
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            color: control.highlightedIndex === index ? Theme.withAlpha(Theme.palette.primary, 0.15) : "transparent"
        }
    }

    popup: Popup {
        y: control.implicitHeight + 2
        width: control.width
        implicitHeight: contentItem.implicitHeight + 4
        padding: 2
        background: Rectangle {
            color: Theme.palette.surface
            radius: 8
            border.color: Theme.palette.border
            border.width: 1
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
        }
    }
}