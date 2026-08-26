# AndroidMic · Quickshell GUI

A self-contained [Quickshell](https://quickshell.io/) extension that replaces the
(main / settings) cosmic windows of the Linux AndroidMic app with a shell-native
GUI — so the app can live in your desktop **system tray** with the stream drawn
in a quick, beautiful panel instead of a clunky desktop window.

It has **two backends**, switching is a purely a flag:

| Mode | When | Data source |
|------|------|-------------|
| **Live** (default) | Rust daemon running | Unix socket `$XDG_RUNTIME_DIR/android-mic.qsock` |
| **Mock** | `ANDROIDMIC_QS_MOCK=1` | Built-in simulated backend (no Rust) |

The mock mode means the GUI can be developed, screenshotted and demoed without
building the heavyweight Rust binary at all.

## What it provides

- **Info dialog** (main information dialog, opened from the tray submenu).
  Live connection state pill, animated **waveform** of the incoming stream,
  connection mode / audio device / network adapter pickers and
  Connect / Stop / Disconnect + Settings buttons.
- **Settings sub-dialog** (opened from the info dialog or tray "Settings"):
  audio format (sample rate, channels, depth + "use recommended"), port,
  noise reduction / VAD / gain / dereverberation, post audio effect,
  start-minimized, theme, about. Mirrors the Rust app's settings window.
- **Launcher** (only when mock / no tray host): a small entry to summon the
  dialogs when there is no system tray to click.

The tray icon itself and the tray submenu (**Open**, **Settings**, **Connect**,
**Disconnect**, **Exit**) are owned by the Rust daemon (StatusNotifierItem), so
the app shows up in your desktop's tray. Rust and this GUI talk over a simple
newline-delimited JSON protocol on a Unix socket.

## Run

From a terminal inside this directory:

```sh
# Mock (no Rust daemon, for previewing / developing the GUI):
ANDROIDMIC_QS_MOCK=1 quickshell -p "$PWD/shell.qml"

# Live (AndroidMic daemon running on the same machine):
quickshell -p "$PWD/shell.qml"
```

The shell hot-reloads the `.qml`/`.js` files, so you can edit and watch live.

## Build the backend (no libxdo required)

Starting the tray + socket bridge for the live mode requires building the Rust
binary with the `--quickshell` flag. On Linux this no longer needs GTK or the
`xdo`/`libxdo` development library — the tray is a pure-D-Bus StatusNotifierItem:

```sh
cd RustApp
cargo build --release           # links clean, no libxdo needed
./target/release/android-mic --quickshell
```

## System tray is the GUI

The **system tray (StatusNotifierItem)** is the primary interface, `run.sh`
launches the floating info/settings windows that the tray **Open**/**Settings**
items summon. (The earlier Omarchy bar-widget was removed in favour of the
tray.) Drop it into `~/.config/quickshell/` (as a named config sub-folder) or
load it as a Quickshell plugin; it only depends on stock `QtQuick`, `QtQuick.
Controls` and `Quickshell` modules.

## Files

| File | Purpose |
|------|---------|
| `shell.qml` | Quickshell entry point — instantiates `AndroidMic` |
| `AndroidMic.qml` | controller: socket client, mock backend, state, opens dialogs |
| `InfoWindow.qml` | main information dialog |
| `SettingsWindow.qml` | settings sub-dialog |
| `LauncherWindow.qml` | mock / tray-less summon buttons |
| `WaveBars.qml` | live waveform |
| `Combo.qml` / `QsButton.qml` / `Toggle.qml` / `ControlSlider.qml` / `Field.qml` / `Section.qml` / `BoolRow.qml` | themed controls |
| `Theme.js` | palette |
| `Options.js` | setting options + default config |
| `Mock.js` | simulated backend |
| `res/app_icon.svg` | app icon |

## Wire protocol

The Rust daemon listens on a Unix socket and speaks newline-delimited JSON.

**Server → client (broadcast):**

| tag | meaning |
|-----|---------|
| `{"t":"state","state":..,"ip":..,"port":..}` | connection state (`Disconnected`/`Connected`/`Listening`) and endpoint |
| `{"t":"config","config":{...}}` | full config snapshot (see `Options.js.defaultConfig`) |
| `{"t":"devices","devices":[{"id","name"}]}` | output audio devices |
| `{"t":"adapters","adapters":[{"name","ip"}]}` | network adapters |
| `{"t":"log","level":..,"text":..}` | a log line |
| `{"t":"wave","data":[...]}` | a chunk of `[-1,1]` samples |
| `{"t":"open","which":"info"\|"settings"}` | ask the GUI to open a dialog (from tray) |

**Client → server (command):**

```json
{"cmd":"connect"}   {"cmd":"stop"}   {"cmd":"exit"}
{"cmd":"config","key":"sample_rate","value":48000}
{"cmd":"config","key":"connection_mode","value":"tcp"}
{"cmd":"device","value":"<output device id>"}
{"cmd":"adapter","value":"<ip>"}
{"cmd":"use_recommended_format"}
{"cmd":"reset_denoise"}
```

Config keys mirror the Rust `Config` struct: `connection_mode`, `ip`, `port`,
`sample_rate`, `channel_count` (1|2), `audio_format` (`u8`/`i16`/`i24`/`i32`/`f32`),
`device_id`, `start_minimized`, `auto_connect`, `denoise`, `denoise_kind`
(`rnnoise`/`speexdsp`), `speex_noise_suppress`, `speex_vad_enabled`,
`speex_vad_threshold`, `speex_agc_enabled`, `speex_agc_target`,
`speex_dereverb_enabled`, `speex_dereverb_level`, `theme`, `amplify`,
`amplify_value`, `post_effect` (`none`/`echo`/`reverb_intimate`/…).