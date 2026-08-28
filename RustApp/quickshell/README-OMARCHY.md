# AndroidMic on Omarchy — tray-less, bar-widget setup

This documents the **Omarchy-oriented** way to run AndroidMic: as a **headless
daemon** (no desktop window) controlled from a **system-bar widget** and a
**virtual-mic audio cable**. It is the result of reworking the stock app to fit
a minimal, always-in-the-bar desktop. It explains *what* changed, *why*, and
exactly how to reproduce the setup on any machine.

- What and why changed is explained below.
- For the bare commands, jump to **Build** and **Setup**.
- For OS-fit, build prerequisites and where it does *not* work, see the
  **Target OS & limitations** section.

---

## 1. Concept

The original AndroidMic PC app is a single always-open **desktop window** that
both shows the stream and holds all settings. On a bar-driven setup (Omarchy /
Quickshell desktops) that window is awkward: a small **always-visible button**
in the bar, connect/disconnect at a click, and settings kept out of the way is
a better fit.

The app is re-architectured into three parts that talk over a **local Unix
socket**:

```
┌───────────────┐   TCP/UDP/USB   ┌─────────────────────┐
│  Android app   │ ──────────────▶ │  android-mic daemon │  (headless, --quickshell)
└───────────────┘                 └──────────┬──────────┘
                                             │ plays into
                                    ┌────────▼─────────┐
                                    │ virtual_mic sink │  (null sink = PipeWire)
                                    └────────┬─────────┘
                                             │ monitor
                                    ┌────────▼─────────┐
                                    │ virtual_mic.monitor│ = the system mic
                                    └────────┬─────────┘
                                             │ socket (state/config/audio)
                                    ┌────────▼─────────┐
                                    │ Omarchy bar widget│ (button + panel)
                                    └──────────────────┘
```

| Piece | Role |
|-------|------|
| `android-mic --quickshell` | headless daemon: listens for the phone, plays the stream into the virtual mic, serves state/settings over a Unix socket. **No window, no tray icon.** |
| `virtual_mic` (PipeWire null sink) | the "virtual cable" — what AndroidMic plays into; its `.monitor` is the actual mic other applications record from. |
| Omarchy **bar-widget** | a mic button in the bar; clicking opens a panel with Connect/Disconnect, a live waveform, and the settings. This replaces the desktop window. |

Everything visible to the operator is now the **bar widget**. The daemon is
invisible in the background under a system service.

---

## 2. GUI differences vs. the original app

This is the main thing that changes. Both are functionally equivalent (same
stream, same settings), but the presentation and the control surface differ.

| Aspect | Original app | This Omarchy setup |
|--------|-------------|--------------------|
| **Shell** | a single cosmic/winit desktop window | no window at all — a **bar widget** + a headless background service |
| **Launch** | open a window at startup; close to exit | a button in the bar; the daemon is an always-running system service |
| **Connect / stop** | a Connect/Disconnect button inside the window | a small icon button; inside the popup panel Connect/Disconnect at the top |
| **Status** | a connection-state label/canvas in the window | a colored mic glyph (accent when streaming, dim when idle) + state text in the panel |
| **Waveform** | a wide canvas in the window | a slim animated bar strip inside the panel |
| **Settings** | a separate 500×600 settings window | a **panel** opened from the same button — sample-rate / channel / format pickers, "Use recommended format", auto-connect, network adapter, post-effect, theme |
| **System tray** | optional tray icon | **no tray icon** — the bar button is the single entry point |
| **Theme** | own light/dark/contrast theme | inherits the **Omarchy theme** (colors, fonts, icons) so it looks native |

Concretely, the stock app pops a full **main window** and a **settings window**.
This setup ships **no windows at all**: the equivalent controls live in the bar
widget's popup panel. The `run.sh` standalone variant keeps the two floating
windows (info + settings), but with the bar-widget they are not needed.

---

## 3. Target OS / where it works (and where it does not)

### Designed for
- **Omarchy** (an Arch-based, Hyprland + Quickshell + systemd-user shell).
- Any **systemd – user-session** Linux with PipeWire/PulseAudio.
- A **from-source build** of AndroidMic (the `--quickshell` flag and socket
  server are not in the packaged AppImage / snap).

### Requires
- **PipeWire or PulseAudio** (with `pactl`/`pw-cli`), and `systemd --user`.
- **Omarchy (or another Quickshell host)** with a **plugin loader** for the
  bar widget. Without a shell that can load Omarchy-style bar-widgets the
  standalone `run.sh` Quickshell windows are the alternative.

### Where it does **not** work
- **Windows / macOS** — `--quickshell` and the included systemd units are
  Linux-only. The original Windows GUI still works normally; the Linux window
  and the Quickshell path are separate builds.
- **without PipeWire/Pulse** — no `virtual_mic` can be created and no `pactl`
  exists, so `androidmic-virtual-mic.sh` exits (it waits for the audio socket).
- **systemd-user disabled** — the autostart units need `systemd --user`. On a
  non-systemd machine `android-mic --quickshell` must be started manually.
- **AppImage** — the prebuilt release does **not** contain `--quickshell`; a
  from-source build is required (next section).
- In **containers/sandboxes** the socket path (`$XDG_RUNTIME_DIR`) or the
  virtual-mic device may not be shareable.

---

## 4. Build from source

```sh
# clone + enter the Rust app
git clone https://github.com/teamclouday/AndroidMic
cd AndroidMic/RustApp

# build the release binary (includes the --quickshell code)
cargo build --release
# → target/release/android-mic
```

> **No extra system deps needed for Linux linking.** The tray/SNI (GTK /
  `libxdo`) is gone from this branch, so `cargo build --release` links clean on
  a plain Linux with only the Rust toolchain + PipeWire devs.

### (Optional) standalone Quickshell GUI
If the desktop has no bar-widget loader, the **standalone** dialog switcher can
be used instead:
```
./quickshell/run.sh
```
But with the **bar widget** (recommended) the shell loads `Panel.qml` itself —
no separate window is needed.

---

## 5. Setup

### 5.1 Install the three systemd user services

The repo bundles the units so a single installer sets everything (binary +
units + virtual-mic script):

```sh
cd RustApp/quickshell
./install-systemd.sh                 # uses target/release/android-mic
# or point at an explicit binary:
./install-systemd.sh /path/to/android-mic
```

This installs & enables (into `~/.config/systemd/user/`):

| unit | purpose | target |
|------|---------|--------|
| `androidmic-daemon.service` | headless `--quickshell` daemon (socket) | `graphical-session.target` |
| `androidmic-virtual-mic.service` | creates the `virtual_mic` null sink + `virtual_mic_source` (via `androidmic-virtual-mic.sh`) | `default.target` |
| `androidmic-default-source.service` | sets `virtual_mic.monitor` as the default record source | `default.target` |

Verify:

```sh
systemctl --user is-active androidmic-daemon androidmic-virtual-mic androidmic-default-source
# each should return: active
pactl list short sources | grep virtual_mic     # virtual_mic.monitor present
pactl get-default-source                          # virtual_mic.monitor
```

### 5.2 Install the Omarchy bar-widget

```sh
cd RustApp/quickshell
./install-omarchy.sh                # adds plugin id 'androidmic.quickshell'
```

or manually:

```sh
omarchy plugin add /path/to/RustApp/quickshell/omarchy
omarchy-shell shell rescanPlugins
omarchy plugin enable androidmic.quickshell --section right
```

A mic button (`󰍬`) appears in the right side of the bar. Clicking the **button**
(or pressing **Enter**) opens the panel: Connect/Disconnect, waveform, device /
sample-rate / format pickers, "Use recommended format", auto-connect, network
adapter, post-effect, theme.

> The panel QML is a single file, so it is easy to ship. After in-place edits
> to `.qml` files, **restart the shell** (or do a cold plugin reinstall) — hot
> reload can keep a stale QML cache for the same URL.

---

## 6. Wire the audio + select the right devices

### 6.1 The virtual mic (auto-created)

`androidmic-virtual-mic.sh` auto-creates at login:

```
null sink  virtual_mic            ← AndroidMic plays here ("Android" / virtual_mic)
source     virtual_mic.monitor    ← this is the *mic* applications read
source     virtual_mic_source     ← optional named alias of the monitor
default source = virtual_mic.monitor
```

The AndroidMic daemon **auto-selects `virtual_mic`** as its output, so it plays
the phone stream into the sink, and the monitor becomes the system mic.

### 6.2 In the Omarchy audio panel: speaker/output settings

The Omarchy audio panel (`omarchy.audio`) shows two lists: an **Output
(speakers)** and an **Input (mic)**.

- **Input**: set to **`virtual_mic` / "Android" (`virtual_mic.monitor`)**.
  That is the phone mic. Keep it here.
- **Output**: set to the **real speakers/headphones**. **Do NOT** set it to
  "android" (`virtual_mic`).

> Why: "android" **is** the `virtual_mic` null sink. Making it the *output*
> target routes every application that plays to the default into an empty sink,
> i.e. it becomes **silent** — effectively muting the machine. The null sink has
> no physical output, so "android as output" discards the sound. It only makes
> sense as the *input*.

Per-application (e.g. Discord, OBS, a recorder) set **"Android Mic (phone)"**
(`virtual_mic.monitor`) as the **input device**. The application then captures
the phone mic.

### 6.3 Transcribing agents (e.g. `pi-listen`)

An agent that transcribes (for instance `@codexstar/pi-listen`) captures the
**default PulseAudio source**, which is `virtual_mic.monitor`. Keep that as the
default (done by `androidmic-default-source.service`) and match the sample
rate/format between the Android app and the daemon (the default is 48 kHz /
i16 / mono). A rate or depth mismatch can drop the audio into silence.

---

## 7. About the missing tray icon

This branch deliberately ships **no system tray icon** — a tray icon would
duplicate the bar mic button. The bar widget is the intended single entry
point. If the original *tray* behaviour is preferred instead, the standalone
`run.sh` (info + settings windows) can be used and the SNI can be re-enabled in
the daemon; in this Omarchy-oriented layout the **bar widget only** is expected.

---

## 8. Files on the branch

| Path | Purpose |
|------|---------|
| `RustApp/quickshell/AndroidMic.qml` | standalone controller (socket client + dialogs) |
| `RustApp/quickshell/InfoWindow.qml`, `SettingsWindow.qml` | the dialogs (standalone GUI) |
| `RustApp/quickshell/shell.qml` | Quickshell entry (standalone) |
| `RustApp/quickshell/run.sh` | launch the standalone GUI live/mock |
| `RustApp/quickshell/omarchy/` | the **Omarchy bar-widget plugin** (`manifest.json`, `Panel.qml`, `Options.js`, `Mock.js`) |
| `RustApp/quickshell/install-omarchy.sh` | install/enable the bar widget |
| `RustApp/quickshell/install-systemd.sh` | install/enable the three systemd units |
| `RustApp/quickshell/systemd/androidmic-daemon.service` | headless daemon unit |
| `RustApp/quickshell/systemd/androidmic-virtual-mic.service` + `.sh` | creates the virtual sink/source |
| `RustApp/quickshell/systemd/androidmic-default-source.service` | makes it the default mic |
| `RustApp/src/quickshell.rs` | the daemon socket server + bridge |
| `RustApp/src/config.rs` | `--quickshell` CLI flag |
| `RustApp/src/ui/app.rs` | virtual-mic auto-select, socket state broadcast |

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| Bar button missing | plugin not enabled / shell not reloaded — `omarchy plugin enable androidmic.quickshell --section right`, then rescan. |
| "Unsupported output audio format" on connect | the device's native format differs. In the bar panel set **Device** to `virtual_mic`, then press **"Use recommended format"**. |
| analog app shows connected but no sound | check the *input* device is `virtual_mic.monitor` in the target application; check the default source with `pactl get-default-source`. |
| System output becomes silent | "android" was selected as the *output* — revert to the real speakers (see §6.2). |
| sample mismatch → silence after connect | align sample rate/format between the Android app and the daemon (48 kHz/i16/mono). |
| panel not updating after editing `.qml` | a cold shell reload is needed to clear the QML cache for the same URL. |

---

## 10. Manual run (no systemd)

Without systemd the setup can be brought up manually:

```sh
# 1) create the virtual mic once (idempotent):
RustApp/quickshell/systemd/androidmic-virtual-mic.sh

# 2) start the headless daemon:
RustApp/target/release/android-mic --quickshell &

# 3) the Omarchy bar widget (already loaded by the shell) then sees the daemon
#    over the socket. Click the mic button to connect / change settings.
```