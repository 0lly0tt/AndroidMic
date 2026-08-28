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

Drop it into `~/.config/quickshell/` (as a named config sub-folder) or load it
as an Omarchy/Quickshell plugin; it only depends on stock `QtQuick`, `QtQuick.
Controls` and `Quickshell` modules.

## Omarchy bar-widget

> **You want the full step-by-step for an Omarchy setup (build, systemd,
> virtual mic, speaker/device wiring, OS-fit & limitations)? See
> [README-OMARCHY.md](README-OMARCHY.md).**

`omarchy/` is a **bar-widget plugin** for [Omarchy](https://omarchy.org): a
mic button in the bar that opens the stream status + audio settings in a
theme-native panel (waveform, connect/disconnect, settigs), talking to the
`android-mic --quickshell` daemon over the same socket. Install it with:

```sh
omarchy plugin add /path/to/RustApp/quickshell/omarchy   # or point the git URL at this folder
omarchy-shell shell rescanPlugins
omarchy plugin enable androidmic.quickshell --section right
```

or run the bundled helper:

```sh
./install-omarchy.sh
```

> The widget is a single self-contained `Panel.qml` (the Omarchy plugin loader
does not auto-discover sibling `.qml` files), so only `Options.js`/`Mock.js`
are cloned alongside it. After installing/editing, **restart the shell**
(immediately on next login) — a hot plugin reload can show a stale QML cache
error for a widget whose file changed at a previous load.

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

## systemd autostart

`install-systemd.sh` installs and enables three user units (into
`~/.config/systemd/user/`):

| unit | purpose |
|------|---------|
| `androidmic-daemon.service` | the headless `--quickshell` daemon (socket) — `graphical-session.target` |
| `androidmic-virtual-mic.service` | creates the `virtual_mic` null sink + `virtual_mic_source` (via `androidmic-virtual-mic.sh`) — `default.target` |
| `androidmic-default-source.service` | sets `virtual_mic.monitor` as the default record source — `default.target` |

```sh
./install-systemd.sh            # install binary + all three units, enable them
./install-systemd.sh /path/to/android-mic   # explicit binary path
```

The daemon unit needs a binary; the two virtual-mic units don't (they only need
`pactl`). If you leave the binary path default the script uses
`target/release/android-mic`.


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