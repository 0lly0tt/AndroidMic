import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "Theme.js" as Theme
import "Options.js" as Opt

// MAIN INFORMATION DIALOG.
// Opened from the system-tray submenu. Hosts the live stream controls and
// the waveform; the settings sub-dialog is opened with the gear button.
FloatingWindow {
    id: root

    property var model: null
    readonly property var cfg: model ? model.config : null

    color: "transparent"
    // The dialog is sized by its content; the outer Rectangle (below) sets its
    // own fixed width, so drive the window from that same geometry.
    width: 420
    height: contentColumn.implicitHeight + 36
    visible: model ? model.infoVisible : false

    function close() {
        root.visible = false
        if (model) model.infoVisible = false
    }

    signal settingsRequested()

    Rectangle {
        id: content
        width: 420
        height: contentColumn.implicitHeight + 36
        color: Theme.palette.bg
        radius: 14
        border.color: Theme.palette.border
        border.width: 1

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // ---------- header ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 30
                    height: 30
                    radius: 8
                    color: Theme.palette.surfaceAlt
                    Text {
                        anchors.centerIn: parent
                        text: "🎙"
                        color: Theme.palette.primary
                        font.pixelSize: 16
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "AndroidMic"
                        color: Theme.palette.text
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        text: root.model && root.model.connectionState === "Connected"
                            ? (root.model.connectionIp + ":" + root.model.connectionPort)
                            : "Stream phone mic to this PC"
                        color: Theme.palette.textFaint
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    color: Theme.withAlpha(Theme.statusColor(root.model ? root.model.connectionState : ""), 0.16)
                    radius: 9
                    implicitWidth: statusText.implicitWidth + 18
                    implicitHeight: 22
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: Theme.statusLabel(root.model ? root.model.connectionState : "")
                        color: Theme.statusColor(root.model ? root.model.connectionState : "")
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.1
                    }
                }
            }

            // ---------- waveform ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                color: Theme.palette.bgAlt
                radius: 10
                border.color: Theme.palette.borderSoft
                border.width: 1
                WaveBars {
                    anchors.fill: parent
                    anchors.margins: 8
                    model: root.model
                }
            }

            // ---------- connection ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: "Mode"; color: Theme.palette.textFaint; font.pixelSize: 11; Layout.preferredWidth: 56 }
                Combo {
                    Layout.fillWidth: true
                    sourceModel: Opt.connectionModes
                    textRoleName: "label"
                    valueRoleName: "key"
                    selectedValue: root.cfg ? root.cfg.connection_mode : "tcp"
                    onPicked: function(value) { if (root.model) root.model.sendConfig("connection_mode", value) }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.cfg && (root.cfg.connection_mode === "tcp" || root.cfg.connection_mode === "udp")
                Text { text: "Network"; color: Theme.palette.textFaint; font.pixelSize: 11; Layout.preferredWidth: 56 }
                Combo {
                    Layout.fillWidth: true
                    sourceModel: root.model ? root.model.adapters : []
                    textRoleName: "text"
                    valueRoleName: "ip"
                    selectedValue: root.cfg ? root.cfg.ip : ""
                    emptyText: "No adapter"
                    onPicked: function(value) { if (root.model) root.model.sendConfig("ip", value) }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: "Device"; color: Theme.palette.textFaint; font.pixelSize: 11; Layout.preferredWidth: 56 }
                Combo {
                    Layout.fillWidth: true
                    sourceModel: root.model ? root.model.devices : []
                    textRoleName: "name"
                    valueRoleName: "id"
                    selectedValue: root.cfg ? root.cfg.device_id : ""
                    emptyText: "No audio device"
                    onPicked: function(value) { if (root.model) root.model.sendDevice(value) }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                QsButton {
                    id: connectBtn
                    Layout.fillWidth: true
                    text: root.model && root.model.connectionState === "Connected" ? "Disconnect" : "Connect"
                    accent: root.model && root.model.connectionState === "Connected" ? Theme.palette.err : Theme.palette.primary
                    onClicked: root.model
                        && (root.model.connectionState === "Connected" || root.model.connectionState === "Listening"
                            ? root.model.sendCmd("stop") : root.model.sendCmd("connect"))
                }
                QsButton {
                    Layout.fillWidth: true
                    text: "Settings"
                    onClicked: root.settingsRequested()
                }
                QsButton {
                    Layout.fillWidth: true
                    text: "Close"
                    onClicked: root.close()
                }
            }
        }
    }
}