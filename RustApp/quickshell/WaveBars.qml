import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

// Mirrored waveform display. `model` is the controller whose `wave` holds a
// rolling array of [-1,1] samples; the newest `bins` samples are drawn as
// bars around a centre line, producing the familiar mic visualiser.
Item {
    id: root

    property var model: null
    readonly property int bins: 64
    // Absolute peak cache so a short loud hit stays visible for a moment.
    property var peaks: (() => { var a = new Array(root.bins); for (var i=0;i<root.bins;i++) a[i]=0.0; return a })()

    implicitWidth: 480
    implicitHeight: 120

    onModelChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            ctx.reset()
            ctx.fillStyle = "transparent"
            ctx.fillRect(0, 0, w, h)

            var samples = root.model ? root.model.wave : []
            var visible = model && model.connectionState === "Connected" || model && model.connectionState === "Listening"

            var half = h / 2

            // decay previous peaks one notch so history fades.
            var x
            for (x = 0; x < root.bins; x++) root.peaks[x] = Math.max(0, root.peaks[x] - 0.04)

            var N = Math.min(samples.length, root.bins)
            var start = Math.max(0, samples.length - root.bins)
            var bw = w / root.bins
            var gap = bw * 0.35
            ctx.fillStyle = Theme.palette.primary
            for (x = 0; x < N; x++) {
                var s = Number(samples[start + x]) || 0
                var peak = Math.min(1, Math.abs(s))
                if (peak > root.peaks[x]) root.peaks[x] = peak
                var mag = visible ? Math.max(peak, root.peaks[x] * 0.6) : peak * 0.15
                var bh = mag * (half - 4)
                if (bh < 1) bh = 1
                var bx = x * bw + gap / 2
                ctx.globalAlpha = 0.55 + 0.45 * (mag)
                ctx.fillRect(bx, half - bh, bw - gap, bh * 2)
                ctx.globalAlpha = 1.0
            }
        }

        // Reload display every frame while running.
        Timer {
            interval: 32
            repeat: true
            running: root.model && (root.model.connectionState === "Connected" || root.model.connectionState === "Listening")
            onTriggered: canvas.requestPaint()
        }
        onWidthChanged: canvas.requestPaint()
    }
}