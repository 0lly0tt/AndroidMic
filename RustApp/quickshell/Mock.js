// Standalone mock backend used when `ANDROIDMIC_QS_MOCK=1` (or when no Rust
// daemon is reachable and `autoMock` is enabled).
//
// Without a Rust daemon this keeps every control live so the GUI can be
// developed, demoed and screenshot-tested in isolation. It mimics the daemon's
// protocol exactly, so swapping to the real backend is a config flip.
.pragma library
.import "Options.js" as Opt

function makeState() {
    return { t: "state", state: "Disconnected", ip: "", port: 0 }
}

// Produce a short pseudo-random waveform frame in the [-1, 1] range.
function waveFrame(phase, active) {
    var n = 24
    var out = []
    for (var i = 0; i < n; i++) {
        var t = phase + i * 0.35
        var base = Math.sin(t) * 0.5 + Math.sin(t * 2.1) * 0.25
        out.push(active ? (base + (Math.random() - 0.5) * 0.3) : base * 0.04)
    }
    return out
}

function fakeDevices() {
    return {
        hosts: ["alsa", "pipewire", "pulseaudio"],
        devices: [
            { id: "null-mic", name: "AudioNull / Null Mic" },
            { id: "vcable", name: "Virtual Cable / Monitor" },
            { id: "speakers", name: "Built-in Audio" }
        ],
        selected: "vcable"
    }
}

// Build an initial snapshot for the mock backend.
function initial() {
    return {
        state: makeState(),
        config: Opt.clone(Opt.defaultConfig),
        devices: fakeDevices()
    }
}

// Simulate processing a daemon command. Returns an array of messages to
// broadcast to the GUI (or null when nothing to broadcast).
function runCommand(state, msg) {
    var emitted = []
    if (!state) return null
    var cfg = state.config
    if (!cfg) return null
    var cmd = msg.cmd

    if (cmd === "connect") {
        if (!state.connected) {
            state.connected = true
            emitted.push({ t: "state", state: "Listening", ip: "0.0.0.0", port: cfg.port })
        }
    } else if (cmd === "stop") {
        state.connected = false
        emitted.push(makeState())
    } else if (cmd === "config") {
        if (msg.key in cfg) {
            cfg[msg.key] = msg.value
            emitted.push({ t: "config", config: Opt.clone(cfg) })
        }
    } else if (cmd === "device") {
        cfg.device_id = msg.value
        emitted.push({ t: "devices", hosts: state.hosts || [], devices: state.devices || [], selected: msg.value })
    } else if (cmd === "adapter") {
        cfg.ip = msg.value
        emitted.push({ t: "adapters", adapters: state.adapters, selected: msg.value })
    } else if (cmd === "refresh_devices") {
        var d = fakeDevices()
        state.devices = d.devices
        state.hosts = d.hosts
        emitted.push({ t: "devices", hosts: d.hosts, devices: d.devices, selected: cfg.device_id })
    }
    return emitted.length ? emitted : null
}