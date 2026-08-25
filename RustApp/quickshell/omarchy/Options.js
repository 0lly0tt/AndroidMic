// Settings option fixtures shared by the settings dialog and mock driver.
// Values use the canonical wire format defined in README.md (matching the
// Rust daemon's Config snapshot / set keys).
.pragma library

var connectionModes = [
    { key: "tcp", label: "WiFi / LAN (TCP)" },
    { key: "udp", label: "WiFi / LAN (UDP)" },
    { key: "adb", label: "USB ADB" },
    { key: "usb", label: "USB Serial" }
]

var sampleRates = [
    8000, 11025, 16000, 22050, 44100, 48000,
    88200, 96600, 176400, 192000, 352800, 384000
]

var channelCounts = [
    { key: 1, label: "Mono" },
    { key: 2, label: "Stereo" }
]

var audioFormats = [
    { key: "u8", label: "u8" },
    { key: "i16", label: "i16" },
    { key: "i24", label: "i24" },
    { key: "i32", label: "i32" },
    { key: "f32", label: "f32" }
]

var denoiseKinds = [
    { key: "rnnoise", label: "RNNoise" },
    { key: "speexdsp", label: "SpeexDSP" }
]

var effects = [
    { key: "none", label: "No Effect" },
    { key: "echo", label: "Echo" },
    { key: "reverb_intimate", label: "ReverbIntimate" },
    { key: "reverb_spacious", label: "ReverbSpacious" },
    { key: "spaceship", label: "Spaceship" },
    { key: "underwater", label: "Underwater" },
    { key: "pitch_up", label: "Chipmunk" },
    { key: "pitch_down", label: "Giant" },
    { key: "demon", label: "Demon" },
    { key: "walkie", label: "Walkie-Talkie" },
    { key: "popstar", label: "Pop Star" },
    { key: "robot", label: "Robot" }
]

var themes = [
    { key: "System", label: "System" },
    { key: "Dark", label: "Dark" },
    { key: "Light", label: "Light" },
    { key: "HighContrastDark", label: "HighContrastDark" },
    { key: "HighContrastLight", label: "HighContrastLight" }
]

// The full default configuration snapshot, mirroring Rust's `Config::default()`.
var defaultConfig = {
    connection_mode: "tcp",
    ip: "",
    port: 54345,
    sample_rate: 44100,
    channel_count: 1,
    audio_format: "i16",
    device_id: "",
    start_at_login: false,
    start_minimized: false,
    auto_connect: false,
    denoise: false,
    denoise_kind: "rnnoise",
    speex_noise_suppress: -30,
    speex_vad_enabled: false,
    speex_vad_threshold: 80,
    speex_agc_enabled: false,
    speex_agc_target: 8000,
    speex_dereverb_enabled: false,
    speex_dereverb_level: 0.5,
    theme: "Dark",
    amplify: false,
    amplify_value: 2.0,
    post_effect: "none"
}

// Deep-clone a plain object (defaults snapshot must not be shared/mutated).
function clone(obj) {
    return JSON.parse(JSON.stringify(obj || null))
}

function labelFor(list, key) {
    for (var i = 0; i < list.length; i++)
        if (String(list[i].key) === String(key)) return list[i].label
    return key
}

function keyFor(list, label) {
    for (var i = 0; i < list.length; i++)
        if (String(list[i].label) === String(label)) return list[i].key
    return label
}