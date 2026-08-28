import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Options.js" as Opt
import "Mock.js" as Mock

// AndroidMic Omarchy bar-widget.
//
// A bar button (mic glyph) that opens a panel with the live stream info
// (status, waveform, connect/disconnect) and audio settings. All audio
// settings are sent to the headless `android-mic --quickshell` daemon over
// the Unix socket, so the bar widget is a theme-native editor.
//
// Single-file on purpose: the Omarchy plugin loader does not auto-discover
// sibling .qml components, so everything except the JS option/mock helpers
// lives here.
Panel {
    id: root
    moduleName: "androidmic.quickshell"
    ipcTarget: "androidmic.quickshell"

    // ------------------------------------------------------------------
    // Controller state (socket client to android-mic --quickshell)
    // ------------------------------------------------------------------
    property string connectionState: "Disconnected"
    property string connectionIp: ""
    property int connectionPort: 0
    property var config: JSON.parse(JSON.stringify(Opt.defaultConfig))
    property var devices: []
    property var adapters: []
    property var wave: []
    property var peaks: (() => { var a = new Array(64); for (var i=0;i<64;i++) a[i]=0.0; return a })()

    readonly property bool streaming: connectionState === "Connected" || connectionState === "Listening"
    readonly property string stateLabel: connectionState === "Connected" ? "CONNECTED"
        : connectionState === "Listening" ? "LISTENING"
        : connectionState === "WaitingOnStatus" ? "WAITING" : "DISCONNECTED"

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/" + (Quickshell.env("UID") || "1000")) + "/android-mic.qsock"

    // mock waveform timer
    property real mockPhase: 0

    function sendCmd(cmd) {
        micSock.write(JSON.stringify({ cmd: cmd }) + "\n")
    }
    function sendConfig(key, value) {
        micSock.write(JSON.stringify({ cmd: "config", key: key, value: value }) + "\n")
    }
    function sendDevice(id) {
        micSock.write(JSON.stringify({ cmd: "device", value: id }) + "\n")
    }
    function accumulateWave(data) {
        if (!data || !data.length) return
        var arr = root.wave.slice()
        for (var i = 0; i < data.length; i++) arr.push(Number(data[i]))
        while (arr.length > 160) arr.shift()
        root.wave = arr
    }
    function handleLine(line) {
        var obj
        try { obj = JSON.parse(line) } catch (e) { return }
        switch (obj.t) {
            case "state":
                root.connectionState = String(obj.state || "Disconnected")
                root.connectionIp = String(obj.ip || "")
                root.connectionPort = Number(obj.port || 0)
                break
            case "config":
                if (obj.config) root.config = obj.config
                break
            case "devices":
                root.devices = obj.devices || []
                break
            case "adapters":
                root.adapters = (obj.adapters || []).map(function(a) {
                    return { text: a.name + " (" + a.ip + ")", ip: a.ip }
                })
                break
            case "wave":
                root.accumulateWave(obj.data)
                break
            case "open":
                // System-tray "Open" / "Settings" asked us to show the panel.
                if (String(obj.which || "") === "settings")
                    root.showSettings = true
                root.openPanel()
                break
        }
    }

    // The Panel base opens on root.open(); keep a named wrapper so socket /
    // tray listeners can summon a specific section.
    function openPanel() {
        root.open()
    }

    Socket {
        id: micSock
        path: root.socketPath
        connected: true
        parser: SplitParser { onRead: function(line) { root.handleLine(line) } }
    }

    // ------------------------------------------------------------------
    // Bar button
    // ------------------------------------------------------------------
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰍬"
        active: root.streaming
        tooltipText: "AndroidMic · " + root.stateLabel.toLowerCase()
        onPressed: function(b) {
            if (b === Qt.RightButton) root.close()
            else root.toggle()
        }
    }

    // ------------------------------------------------------------------
    // Panel popup
    // ------------------------------------------------------------------
    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(400))
        contentHeight: panel.fittedContentHeight(col.implicitHeight, Style.space(600))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }
        }

        Flickable {
            id: scroll
            anchors.fill: parent
            contentWidth: scroll.width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: col
                // The card has padding, so the scroll viewport is narrower
                // than panel.contentWidth. Bind col to the viewport width so
                // dropdown fields fit inside the dialog and keep their right
                // border visible (instead of overflowing past the card edge).
                width: scroll.width
                spacing: Style.space(12)
                // The card already insets its content by the popup padding, so
                // this Column spans the viewport (scroll.width) exactly and MUST
                // NOT add its own horizontal padding: a child sized to
                // parent.width would otherwise overflow past the card's right
                // edge and put each field's right border flush at the dialog's
                // rim instead of neatly inset. Vertical padding is harmless
                // (does not affect width) and keeps rows off the edges.
                topPadding: Style.space(14)
                bottomPadding: Style.space(14)

                // ---------- header / actions ----------
                RowLayout {
                    width: parent.width
                    spacing: Style.space(10)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: "AndroidMic"
                            color: Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.title
                            font.bold: true
                        }
                        Text {
                            text: root.streaming
                                ? (root.connectionIp + ":" + root.connectionPort)
                                : "Stream phone mic to this PC"
                            color: Color.foreground
                            opacity: 0.6
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideMiddle
                        }
                    }
                    Button {
                        text: root.streaming ? "Disconnect" : "Connect"
                        bordered: true
                        foreground: root.streaming ? Color.accent : Color.foreground
                        onClicked: root.sendCmd(root.streaming ? "stop" : "connect")
                    }
                }

                // ---------- waveform ----------
                Rectangle {
                    width: parent.width
                    height: Style.space(80)
                    radius: Math.max(3, Style.cornerRadius - 2)
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                    // The Timer / onCompleted below repaint this canvas on the
                    // waveform; it needs an id to be referenced.
                    Canvas {
                        id: canvas
                        anchors.fill: parent
                        anchors.margins: 8
                        onPaint: drawWave(this)
                    }
                    Timer {
                        interval: 32
                        repeat: true
                        running: root.streaming
                        onTriggered: canvas.requestPaint()
                    }
                    Component.onCompleted: Qt.callLater(function(){ canvas.requestPaint() })
                }

                // ---------- status row ----------
                RowLayout {
                    width: parent.width
                    spacing: Style.space(8)
                    Rectangle {
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: root.streaming ? Color.accent : Color.foreground
                        opacity: root.streaming ? 1 : 0.3
                    }
                    Text {
                        text: root.stateLabel + (root.connectionPort ? " · :" + root.connectionPort : "")
                        color: Color.foreground
                        opacity: 0.7
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        Layout.fillWidth: true
                    }
                }

                // ---------- quick settings ----------
                PanelSeparator { width: parent.width; foreground: Color.foreground }

                FontHeader { text: "AUDIO FORMAT" }
                // Output device: shows the virtual_mic etc. Without this the
                // daemon falls back to the default (speaker) device and fails
                // to start the stream. 'device' command updates config.device_id.
                DropdownRow {
                    label: "Device"
                    options: root.devices.map(function(d){ return { value: d.id, label: d.name } })
                    value: String(root.config.device_id || "")
                    onChanged: function(v) { root.sendDevice(v) }
                }
                DropdownRow {
                    label: "Sample rate"
                    options: Opt.sampleRates.map(function(s){ return { value: String(s), label: String(s) } })
                    value: String(root.config.sample_rate)
                    onChanged: function(v) { root.sendConfig("sample_rate", Number(v)) }
                }
                DropdownRow {
                    label: "Channels"
                    options: Opt.channelCounts.map(function(c){ return { value: String(c.key), label: c.label } })
                    value: String(root.config.channel_count)
                    onChanged: function(v) { root.sendConfig("channel_count", Number(v)) }
                }
                DropdownRow {
                    label: "Format"
                    options: Opt.audioFormats.map(function(f){ return { value: f.key, label: f.label } })
                    value: root.config.audio_format
                    onChanged: function(v) { root.sendConfig("audio_format", v) }
                }

                // Fix "Unsupported output audio format" errors at a click: the
                // daemon picks the format + rate actually supported by the device.
                Button {
                    width: parent.width
                    text: "Use recommended format"
                    bordered: true
                    foreground: Color.accent
                    onClicked: root.sendCmd("use_recommended_format")
                }

                FontHeader { text: "CONNECTION" }
                DropdownRow {
                    label: "Mode"
                    options: Opt.connectionModes.map(function(o){ return { value: o.key, label: o.label } })
                    value: root.config.connection_mode
                    onChanged: function(v) { root.sendConfig("connection_mode", v) }
                }
                ToggleRow {
                    label: "Auto-connect"
                    checked: root.config.auto_connect
                    onToggled: root.sendConfig("auto_connect", !root.config.auto_connect)
                }
                DropdownRow {
                    label: "Network"
                    visible: root.config.connection_mode === "tcp" || root.config.connection_mode === "udp"
                    options: root.adapters.map(function(a){ return { value: a.ip, label: a.text } })
                    value: String(root.config.ip || "")
                    onChanged: function(v) { root.sendConfig("ip", v) }
                }

                FontHeader { text: "POST-EFFECT" }
                DropdownRow {
                    label: "Effect"
                    options: Opt.effects.map(function(e){ return { value: e.key, label: e.label } })
                    value: root.config.post_effect
                    onChanged: function(v) { root.sendConfig("post_effect", v) }
                }

                FontHeader { text: "APP" }
                DropdownRow {
                    label: "Theme"
                    options: Opt.themes.map(function(t){ return { value: t.key, label: t.label } })
                    value: root.config.theme
                    onChanged: function(v) { root.sendConfig("theme", v) }
                }
                ToggleRow {
                    label: "Start minimized"
                    checked: root.config.start_minimized
                    onToggled: root.sendConfig("start_minimized", !root.config.start_minimized)
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // waveform painter
    // ------------------------------------------------------------------
    function drawWave(canvas) {
        var ctx = canvas.getContext("2d")
        var w = canvas.width
        var h = canvas.height
        ctx.reset()
        ctx.clearRect(0, 0, w, h)

        var samples = root.wave
        var active = root.streaming
        var half = h / 2
        var x
        for (x = 0; x < 64; x++) root.peaks[x] = Math.max(0, root.peaks[x] - 0.04)

        var N = Math.min(samples.length, 64)
        var start = Math.max(0, samples.length - 64)
        var bw = w / 64
        var gap = bw * 0.35
        var q = Qt.color(active ? (Color.accent || "#7aa2f7") : Color.foreground)

        for (x = 0; x < N; x++) {
            var s = Number(samples[start + x]) || 0
            var mag = active ? Math.min(1, Math.abs(s)) : Math.abs(s) * 0.15
            var bh = mag * (half - 4)
            if (bh < 1) bh = 1
            ctx.fillStyle = "rgba(" + Math.round(q.r*255) + "," + Math.round(q.g*255) + "," + Math.round(q.b*255) + "," + (0.55 + 0.45*mag) + ")"
            ctx.fillRect(x * bw + gap / 2, half - bh, bw - gap, bh * 2)
        }
    }

    // ------------------------------------------------------------------
    // inline components
    // ------------------------------------------------------------------
    component FontHeader: Text {
        color: Color.foreground
        opacity: 0.6
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.1
    }

    component DropdownRow: RowLayout {
        id: dro
        property string label: ""
        property var options: []
        property string value: ""
        signal changed(string v)
        width: parent ? parent.width : 320
        spacing: Style.space(8)
        // Label takes the leftover space; the field is its natural dropdown
        // width, so it reads as a distinct control on the right rather than
        // being pushed right up against the label.
        Text {
            text: dro.label
            color: Color.foreground
            opacity: 0.75
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            Layout.fillWidth: true
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        Dropdown {
            id: dd
            options: dro.options
            value: dro.value
            onChanged: function(v) { dro.changed(v) }
        }
    }

    component ToggleRow: RowLayout {
        id: trow
        property string label: ""
        property bool checked: false
        signal toggled
        width: parent ? parent.width : 320
        spacing: Style.space(8)
        Text {
            text: trow.label
            color: Color.foreground
            opacity: 0.75
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        ToggleSwitch {
            checked: trow.checked
            onToggled: trow.toggled()
        }
    }
}