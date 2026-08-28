import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "Theme.js" as Theme
import "Options.js" as Opt

// SETTINGS SUB-DIALOG.
// Opened from the info dialog (or tray "Settings"). Mirrors the Rust app's
// settings window: audio format, connection, noise reduction, VAD, gain,
// dereverberation, a post effect, and app options.
FloatingWindow {
    id: root

    property var model: null
    readonly property var cfg: model ? model.config : null

    implicitWidth: 460
    implicitHeight: 560
    visible: model ? model.settingsVisible : false

    function close() {
        root.visible = false
        if (model) model.settingsVisible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.palette.bg
        border.color: Theme.palette.border
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "Settings — AndroidMic"
                    color: Theme.palette.text
                    font.pixelSize: 15
                    font.bold: true
                    Layout.fillWidth: true
                }
                QsButton { text: "Close"; onClicked: root.close() }
            }

            Flickable {
                id: sview
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: sview.width
                contentHeight: col.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: col
                    // Match the scrollable's viewport width (not the window
                    // width, which is larger than the inner column), so the
                    // sections and their controls align to the dialog field
                    // instead of overflowing horizontally.
                    width: sview.width
                    spacing: 10

                    // ---------------- audio format ----------------
                    Section {
                        title: "Audio format"
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Text { text: "Sample rate"; color: Theme.palette.textFaint; font.pixelSize: 12; Layout.preferredWidth: 66 }
                            Combo { Layout.fillWidth: true; sourceModel: Opt.sampleRates
                                selectedValue: root.cfg ? root.cfg.sample_rate : 44100
                                onPicked: function(v) { if (root.model) root.model.sendConfig("sample_rate", v) } }
                        }
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Text { text: "Channels"; color: Theme.palette.textFaint; font.pixelSize: 12; Layout.preferredWidth: 66 }
                            Combo { Layout.fillWidth: true; sourceModel: Opt.channelCounts; textRoleName: "label"; valueRoleName: "key"
                                selectedValue: root.cfg ? root.cfg.channel_count : 1
                                onPicked: function(v) { if (root.model) root.model.sendConfig("channel_count", v) } }
                        }
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Text { text: "Format"; color: Theme.palette.textFaint; font.pixelSize: 12; Layout.preferredWidth: 66 }
                            Combo { Layout.fillWidth: true; sourceModel: Opt.audioFormats; textRoleName: "label"; valueRoleName: "key"
                                selectedValue: root.cfg ? root.cfg.audio_format : "i16"
                                onPicked: function(v) { if (root.model) root.model.sendConfig("audio_format", v) } }
                        }
                        QsButton { Layout.alignment: Qt.AlignHCenter; text: "Use recommended format"
                            onClicked: if (root.model) root.model.sendCmd("use_recommended_format") }
                    }

                    // ---------------- connection ----------------
                    Section {
                        title: "Connection"
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Text { text: "Port"; color: Theme.palette.textFaint; font.pixelSize: 12; Layout.preferredWidth: 66 }
                            Field { Layout.fillWidth: true; text: root.cfg ? String(root.cfg.port) : "54345"
                                onEditCommitted: function(v) { if (root.model) root.model.sendConfig("port", Number(v)) } }
                        }
                        BoolRow { label: "Auto-connect"; key: "auto_connect"; model: root.model }
                    }

                    // ---------------- noise reduction ----------------
                    Section {
                        title: "Noise reduction"
                        BoolRow { label: "Enabled"; key: "denoise"; model: root.model }
                        RowLayout { Layout.fillWidth: true; visible: root.cfg && root.cfg.denoise; spacing: 8
                            Text { text: "Type"; color: Theme.palette.textFaint; font.pixelSize: 12; Layout.preferredWidth: 66 }
                            Combo { Layout.fillWidth: true; sourceModel: Opt.denoiseKinds; textRoleName: "label"; valueRoleName: "key"
                                selectedValue: root.cfg ? root.cfg.denoise_kind : "rnnoise"
                                onPicked: function(v) { if (root.model) root.model.sendConfig("denoise_kind", v) } }
                        }
                        RowLayout { Layout.fillWidth: true; visible: root.cfg && root.cfg.denoise && root.cfg.denoise_kind === "speexdsp"; spacing: 8
                            Text { text: "Gauge"; color: Theme.palette.textFaint; font.pixelSize: 12 }
                            Text { text: root.cfg ? String(root.cfg.speex_noise_suppress) + " db" : ""; color: Theme.palette.text; font.pixelSize: 12 }
                            ControlSlider { Layout.fillWidth: true; from: -100; to: 0; stepSize: 1
                                value: root.cfg ? root.cfg.speex_noise_suppress : -30
                                onValueChanged: if (root.model) root.model.sendConfig("speex_noise_suppress", Math.round(value)) }
                        }
                    }

                    // ---------------- VAD ----------------
                    Section {
                        title: "Voice Activity Detection (VAD)"
                        BoolRow { label: "Enabled"; key: "speex_vad_enabled"; model: root.model }
                        RowLayout { Layout.fillWidth: true; visible: root.cfg && root.cfg.speex_vad_enabled; spacing: 8
                            Text { text: "Level"; color: Theme.palette.textFaint; font.pixelSize: 12 }
                            ControlSlider { Layout.fillWidth: true; from: 0; to: 100; stepSize: 1
                                value: root.cfg ? root.cfg.speex_vad_threshold : 80
                                onValueChanged: if (root.model) root.model.sendConfig("speex_vad_threshold", Math.round(value)) }
                        }
                    }

                    // ---------------- gain control ----------------
                    Section {
                        title: "Gain control"
                        BoolRow { label: "Automatic Gain (AGC)"; key: "speex_agc_enabled"; model: root.model }
                        RowLayout { Layout.fillWidth: true; visible: root.cfg && root.cfg.speex_agc_enabled; spacing: 8
                            Text { text: "Target"; color: Theme.palette.textFaint; font.pixelSize: 12 }
                            ControlSlider { Layout.fillWidth: true; from: 8000; to: 65535; stepSize: 100
                                value: root.cfg ? root.cfg.speex_agc_target : 8000
                                onValueChanged: if (root.model) root.model.sendConfig("speex_agc_target", Math.round(value)) }
                        }
                        BoolRow { label: "Amplify"; key: "amplify"; model: root.model }
                        RowLayout { Layout.fillWidth: true; visible: root.cfg && root.cfg.amplify; spacing: 8
                            Text { text: "Level"; color: Theme.palette.textFaint; font.pixelSize: 12 }
                            ControlSlider { Layout.fillWidth: true; from: 0; to: 10; stepSize: 0.1
                                value: root.cfg ? root.cfg.amplify_value : 2
                                onValueChanged: if (root.model) root.model.sendConfig("amplify_value", Number(value.toFixed(2))) }
                        }
                    }

                    // ---------------- dereverberation ----------------
                    Section {
                        title: "Dereverberation"
                        BoolRow { label: "Enabled"; key: "speex_dereverb_enabled"; model: root.model }
                        RowLayout { Layout.fillWidth: true; visible: root.cfg && root.cfg.speex_dereverb_enabled; spacing: 8
                            Text { text: "Level"; color: Theme.palette.textFaint; font.pixelSize: 12 }
                            ControlSlider { Layout.fillWidth: true; from: 0; to: 1; stepSize: 0.05
                                value: root.cfg ? root.cfg.speex_dereverb_level : 0.5
                                onValueChanged: if (root.model) root.model.sendConfig("speex_dereverb_level", Number(value.toFixed(2))) }
                        }
                    }

                    // ---------------- audio effect ----------------
                    Section {
                        title: "Post audio effect"
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Text { text: "Effect"; color: Theme.palette.textFaint; font.pixelSize: 12; Layout.preferredWidth: 66 }
                            Combo { Layout.fillWidth: true; sourceModel: Opt.effects; textRoleName: "label"; valueRoleName: "key"
                                selectedValue: root.cfg ? root.cfg.post_effect : "none"
                                onPicked: function(v) { if (root.model) root.model.sendConfig("post_effect", v) } }
                        }
                        QsButton { Layout.alignment: Qt.AlignHCenter; text: "Reset noise settings"
                            onClicked: if (root.model) root.model.sendCmd("reset_denoise") }
                    }

                    // ---------------- app ----------------
                    Section {
                        title: "App"
                        BoolRow { label: "Start minimized"; key: "start_minimized"; model: root.model }
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Text { text: "Theme"; color: Theme.palette.textFaint; font.pixelSize: 12; Layout.preferredWidth: 66 }
                            Combo { Layout.fillWidth: true; sourceModel: Opt.themes; textRoleName: "label"; valueRoleName: "key"
                                selectedValue: root.cfg ? root.cfg.theme : "Dark"
                                onPicked: function(v) { if (root.model) root.model.sendConfig("theme", v) } }
                        }
                        QsButton { Layout.alignment: Qt.AlignHCenter; text: "About"
                            onClicked: if (root.model) root.model.openAbout() }
                    }
                }
            }
        }
    }
}