import QtQuick
import Quickshell

// AndroidMic Quickshell extension entry point.
//
// Install/run:
//   ANDROIDMIC_QS_MOCK=1 quickshell -p /path/to/RustApp/quickshell/shell.qml
//
// or (live) make sure the AndroidMic Rust daemon is running, then:
//   quickshell -p /path/to/RustApp/quickshell/shell.qml
AndroidMic {
    id: app
}