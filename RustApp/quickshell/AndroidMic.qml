import QtQuick
import Quickshell
import Quickshell.Io
import "Options.js" as Opt
import "Mock.js" as Mock

// AndroidMic controller.
//
// Live mode: Quickshell-side peer of the AndroidMic Rust daemon. It connects
// to the daemon's Unix socket (android-mic.qsock), shows the info/settings
// dialogs and sends every change back over the socket.
//
// Mock mode (ANDROIDMIC_QS_MOCK=1): runs a simulated backend so the GUI can
// be built, screenshotted and demoed without the daemon running.
Item {
    id: root

    // ---------- runtime state ----------
    property string connectionState: "Disconnected"
    property string connectionIp: ""
    property int connectionPort: 0

    property var config: Opt.clone(Opt.defaultConfig)
    property var devices: []
    property var adapters: []

    property var logs: []
    property var wave: []

    property bool infoVisible: false
    property bool settingsVisible: false
    property bool launcherVisible: false

    readonly property bool mock: root.envBool("ANDROIDMIC_QS_MOCK")
    property string instanceId: "main"
    readonly property string socketPath: root.runtimeDir() + "/android-mic.qsock"

    function envBool(name) { var v = Quickshell.env(name); return v === "1" || v === "true" }
    function runtimeDir() { var d = Quickshell.env("XDG_RUNTIME_DIR"); return d && d.length ? d : "/run/user/" + (Quickshell.env("UID") || "1000") }

    function logMessage(level, text) {
        var arr = root.logs.slice()
        arr.unshift({ level: level || "info", text: String(text || "") })
        while (arr.length > 120) arr.pop()
        root.logs = arr
    }

    function accumulateWave(data) {
        if (!data || !data.length) return
        var arr = root.wave.slice()
        for (var i = 0; i < data.length; i++) arr.push(Number(data[i]))
        while (arr.length > 160) arr.shift()
        root.wave = arr
    }

    // Route (mock) server output through the normal inbound path.
    function applyServerMessages(list) {
        if (!list) return
        for (var i = 0; i < list.length; i++) root.handleMessage(list[i])
    }

    // ---------- outbound commands ----------
    function sendCmd(cmd) {
        if (root.mock) { root.applyServerMessages(Mock.runCommand(root.mockState, { cmd: cmd })); return }
        sock.write(JSON.stringify({ cmd: cmd }) + "\n")
    }
    function sendConfig(key, value) {
        if (root.mock) { if (root.mockState) root.applyServerMessages(Mock.runCommand(root.mockState, { cmd: "config", key: key, value: value })); return }
        sock.write(JSON.stringify({ cmd: "config", key: key, value: value }) + "\n")
    }
    function sendDevice(id) {
        if (root.mock) { if (root.mockState) root.applyServerMessages(Mock.runCommand(root.mockState, { cmd: "device", value: id })); return }
        sock.write(JSON.stringify({ cmd: "device", value: id }) + "\n")
    }
    function openAbout() { root.infoVisible = true }

    // ---------- inbound ----------
    function handleLine(line) {
        var obj
        try { obj = JSON.parse(line) } catch (e) { return }
        root.handleMessage(obj)
    }

    function handleMessage(obj) {
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
            case "log":
                root.logMessage(obj.level, obj.text)
                break
            case "wave":
                root.accumulateWave(obj.data)
                break
            // NOTE: bar-panel is the only GUI. We intentionally do NOT open the
            // standalone floating windows on tray Open/Settings; the Omarchy
            // bar widget owns that. (Kept as a no-op so the standalone entry
            // remains available via its own buttons.)
        }
    }

    // ---------- socket ----------
    Socket {
        id: sock
        path: root.socketPath
        // Retry forever: the daemon may not be up yet (boot race) or may
        // have restarted while this window was open. Quickshell's Socket
        // does NOT retry on its own.
        parser: SplitParser { onRead: function(line) { root.handleLine(line) } }
        onConnectedChanged: {
            if (connected) {
                reconnectTimer.stop()
                root.logMessage("info", "connected to daemon")
                Qt.callLater(function() { root.infoVisible = true })
            } else if (!root.mock) {
                reconnectTimer.restart()
            }
        }
        Component.onCompleted: if (!root.mock) sock.connected = true
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: sock.connected = true
    }

    // ---------- mock backend ----------
    property var mockState: null
    property real mockPhase: 0

    function startMock() {
        if (root.mockState) return
        root.mockState = Mock.initial()
        var state = root.mockState.state
        root.connectionState = state.state
        root.config = root.mockState.config
        root.devices = root.mockState.devices.devices
        root.adapters = [
            { name: "eth0", ip: "10.0.0.5" },
            { name: "wlan0", ip: "192.168.1.50" }
        ]
        root.logMessage("info", "AndroidMic starting")
        root.logMessage("info", "mock backend active (no Rust daemon)")
        root.infoVisible = true
        root.launcherVisible = root.mock
    }

    Timer {
        id: mockTimer
        interval: 200
        repeat: true
        running: root.mock
        onTriggered: {
            root.mockPhase += 0.2
            if (root.connectionState === "Connected" || root.connectionState === "Listening")
                root.accumulateWave(Mock.waveFrame(root.mockPhase, true))
        }
    }

    // ---------- windows ----------
    InfoWindow {
        model: root
        onSettingsRequested: { root.settingsVisible = true }
    }
    SettingsWindow { model: root }
    LauncherWindow {
        model: root
        visible: root.launcherVisible
    }

    Component.onCompleted: {
        root.instanceId = Quickshell.env("ANDROIDMIC_QS_INSTANCE") || "main"
        if (root.mock) root.startMock()
    }
}