// AndroidMic Quickshell theme.
// Self-contained dark palette (Catppuccin Mocha flavoured) so the shell
// extension does not depend on Omarchy's `qs.Ui`/`qs.Commons` modules and can
// be dropped into any Quickshell host.
.pragma library

var palette = {
    bg: "#11111b",
    bgAlt: "#181825",
    surface: "#1e1e2e",
    surfaceAlt: "#313244",
    border: "#45475a",
    borderSoft: "#313244",
    primary: "#7aa2f7",
    primaryAlt: "#89b4fa",
    ok: "#a6e3a1",
    warn: "#f9e2af",
    err: "#f38ba8",
    magenta: "#cba6f7",
    text: "#cdd6f4",
    textDim: "#a6adc8",
    textFaint: "#7f849c"
}

// Convert a css color string to an rgba() string with the given alpha (0..1).
function withAlpha(color, alpha) {
    var c = Qt.color(color)
    return Qt.rgba(c.r, c.g, c.b, alpha)
}

function shade(color, factor) {
    // factor < 1 darkens (multiply), > 1 lightens
    var c = Qt.color(color)
    return Qt.rgba(Math.min(1, c.r * factor), Math.min(1, c.g * factor),
                   Math.min(1, c.b * factor), c.a)
}

// Human-readable label for a connection / theme / effect state.
function statusLabel(state) {
    switch (String(state || "")) {
    case "Listening": return "LISTENING"
    case "Connected": return "CONNECTED"
    case "WaitingOnStatus": return "WAITING"
    default: return "DISCONNECTED"
    }
}

function statusColor(state) {
    switch (String(state)) {
        case "Connected": return palette.ok
        case "Listening": return palette.warn
        default: return palette.textFaint
    }
}