# AndroidMic on Omarchy — tray-less, bar-widget setup

This documents the **Omarchy-oriented** way to run AndroidMic: as a **headless
daemon** (no desktop window) controlled from a **system-bar widget** and a
**virtual-mic audio cable**. It is the result of reworking the stock app to fit
a minimal, always-in-the-bar desktop. It explains *what* we changed, *why*, and
exactly how to reproduce it on your own machine.

- Why and what we changed is explained below.
- If you just want the commands, jump to **Quick install**.
- For OS-fit, build prerequisites and where it does *not* work, see the
  **Target OS & limitations** section.

---

## 1. Concept

The original AndroidMic PC app is a single always-open **desktop window** that
both shows the stream and holds all settings. On a bar-driven setup (Omarchy /
Quickshell desktops) that window is awkward: you want a small **always-visible
button** in the bar, connect/disconnect at a click, and settings out of the way.

We re-architected it into three moving parts that talk over a **local Unix
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
| `virtual_mic` (PipeWire null sink) | the "virtual cable" — what AndroidMic plays into; its `.monitor` is the actual mic other apps record from. |
| Omarchy **bar-widget** | a mic button in the bar; clicking opens a panel to Connect/Disconnect, see a live waveform, and edit settings. This replaces the desktop window. |

Everything the user "sees" is now the **bar widget**. The daemon is invisible
in the background under a system service.

---

## Why we changed what we did (session narrative)

| Step | What / why |
|------|-----------|
| **GUI via Quickshell, not the cosmic window** | Implicit `--quickshell` runs the app headless; a QML/Quickshell front-end (the bar widget) renders info + settings. Removes the big desktop window. |
| **`--quickshell` flag** | Added `--quickshell` to the CLI (`src/config.rs`). Launch the daemon only for the socket. |
| **Unix-socket IPC** | Added a socket server (`$XDG_RUNTIME_DIR/android-mic.qsock`) broadcasting newline-delimited JSON (config / state / devices / log / wave). The bar widget reads it; it sends back `connect`, `stop`, `config`, `device`, `use_recommended_format`. |
| **Remove the system-tray (SNI)** | The bar widget is the GUI. An extra tray icon just duplicated the button and confused the launcher. Dropped the SNI (and the `ksni`/GTK code). The daemon is **tray-less**. |
| **Virtual-mic auto-selection** | If no output device is configured, the daemon auto-picks a sink whose name contains `virtual` (or starts with `android`). So it plays into the virtual mic instead of your speaker. |
| **systemd autostart** | Three user units (`androidmic-daemon`, `androidmic-virtual-mic`, `androidmic-default-source`) make everything start at login and keep it idempotent. |
| **Device picker + "Use recommended format"** | The bar panel can pick the output device and request the daemon to match the device's supported format (fixes "Unsupported output audio format"). |

---

## 3. Target OS / where it works (and where it does not)

### Designed for
- **Omarchy** (an Arch-based, Hyprland + Quickshell + systemd-user shell).
- Any **systemd – user-session** Linux with PipeWire/PulseAudio.
- A **from-source build** of AndroidMic (the `--quickshell` flag and socket
  server are not in the packaged AppImage / snap).

### Requires
- **PipeWire or PulseAudio** (with a `pactl`/`pw-cli`), and `systemd --user`.
- **Omarchy (or another Quickshell host)** with the **plugin loader** for the
  bar widget. Without a shell that loads `omarchy` style bar-widgets you would
  instead use the standalone `run.sh` Quickshell windows.

### Where it does **not** work
- **Windows / macOS** — `--quickshell` and the included systemd units are
  Linux-only. The original Windows GUI still works normally; the Linux window
  and the Quickshell path are separate builds.
- **without PipeWire/Pulse** — there is no `virtual_mic` to create and no
  `pactl`, so `androidmic-virtual-mic.sh` will exit (it waits for the audio
  socket).
- **systemd-user disabled** — the autostart units need `systemd --user`. On a
  non-systemd machine you must start `android-mic --quickshell` manually.
- **AppImage** — the prebuilt release does **not** contain `--quickshell`; you
  must build from source (see next section).
- In **containers/sandboxes** the socket path (`$XDG_RUNTIME_DIR`) or the
  virtual-mic device may not be shareable.

---

## 4. Build from source

```sh
# clone + enter the Rust app
git clone https://github.com/teamclouday/AndroidMic
cd AndroidMic/RustApp

# build the release binary (this includes the --quickshell code)
cargo build --release
# → target/release/android-mic
```

> **No extra system deps needed for Linux linking.** The tray/SNI (GTK /
  `libxdo`) is gone from this branch, so `cargo build --release` links clean
  on a plain Linux with just the Rust toolchain + PipeWire devs.

### (Optional) install the Quickshell GUI (standalone dialog switcher)
If you want the info/settings windows (not the bar widget) you'd also run:
```
./quickshell/run.sh
```
But with the **bar widget** (recommended) the shell loads `Panel.qml` by
itself — no separate window.

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

A mic button (`󰍬`) appears in the right side of the bar. Click the **button**
(or press **Enter**) to open the panel: Connect/Disconnect, waveform, device /
sample-rate / format pickers, "Use recommended format", auto-connect, network
adapter, post-effect, theme.

> For a target (pod) shell: the panel QML is a single file so is easy to ship.
> After editing `.qml` files in place, **restart the shell** (or do a cold
> plugin re-install) — hot reload can keep a stale QML cache for the same URL.

---

## 6. Wire the audio + pick the right devices

### 6.1 The virtual mic (auto-created)

`androidmic-virtual-mic.sh` auto-creates at login:

```
null sink  virtual_mic            ← AndroidMic plays here ("Android" / virtual_mic)
source     virtual_mic.monitor    ← this is the *mic* apps read
source     virtual_mic_source     ← optional named alias of the monitor
default source = virtual_mic.monitor
```

The AndroidMic daemon **auto-selects `virtual_mic`** as its output, so it plays
the phone stream into the sink, and the monitor becomes the system mic.

### 6.2 The Omarchy panel: speaker/output settings

In the Omarchy audio panel (or via `omarchy.audio`) you'll see two device lists:
an **Output (speakers)** and an **Input (mic)**.

- **Input**: set it to **`virtual_mic` / "Android" `(virtual_mic.monitor)`**.
  That is the phone mic. **Keep it here.**
- **Output**: set it to your **real speakers/headphones**. **Do NOT** set it
  to "android" (`virtual_mic`).

> Why: "android" **is** the `virtual_mic` null sink. If you make it the
> *output* target, every app that plays to the default is routed into an empty
> sink and is **silent** — you effectively mute your machine. It only makes
> sense as the *input*. The null sink has no physical output, so "android as
> output" discards the sound.

Per-app: e.g. Discord / OBS / your recorder put **"Android Mic (phone)"**
(`virtual_mic.monitor`) as the **input device**. They then capture the phone
mic.

### 6.3 The `pi` coding agent (pi-listen) input

If you run an agent that transcribes (e.g. `@codexstar/pi-listen`), it captures
the **default PulseAudio source**, which is `virtual_mic.monitor`. Set that as
the default (done by `androidmic-default-source.service`) and choose the same
sample rate/format between the Android app and the daemon (48k / i16 / mono is
the default). A rate/depth mismatch can make it drop audio into silence.

---

## 7. I saw once for a "tray icon somewhere else"?…

This branch deliberately ships **no system tray icon** — the tray icon would
duplicate the bar mic button. If you also prefer the original *tray* behavior,
keep the standalone `run.sh` (info/settings windows) and enable the SNI in the
daemon again; but in this Omarchy oriented layout you want the **bar widget
only**.

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
| Bar button missing | plugin not enabled / shell not reloaded — `omarchy plugin enable androidmic.quickshell --section right`, rescan. |
| "Unsupported output audio format" on connect | The device's native format differs. Open the bar panel, set **Device** to `virtual_mic`, then **"Use recommended format"**. |
| loop the mic works for Android app but no sound | check the *input* device is `virtual_mic.monitor` in the target app; check default source with `pactl get-default-source`. |
| System output becomes silent | You set "android" as the *output* — revert to your speakers (see §6.2). |
| sample mismatch → silence after connect | Align sample rate/format between the Android app and daemon (48k/i16/mono). |
| panel not updating after editing a `.qml` file | needed a cold shell reload to clear the QML cache for the same URL. |

---

## 10. Manual run (no systemd)

If you avoid systemd, you can bring it up manually:

```sh
# 1) create the virtual mic once (idempotent):
RustApp/quickshell/systemd/androidmic-virtual-mic.sh

# 2) start the headless daemon:
RustApp/target/release/android-mic --quickshell &

# 3) the Omarchy bar widget (already loaded by the shell) now sees it over
#    the socket. Click the mic button to connect / change settings.
```