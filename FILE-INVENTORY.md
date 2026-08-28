# AndroidMic — File Inventory of the Omarchy Rework

This file lists every file that differs from the upstream original
(`teamclouday/AndroidMic`, `origin/main`) because of this project's Windows
desktop-GUI → headless-daemon + Quickshell bar-widget rework.

Two lists:

1. **Changed files** — files that existed in the original and were modified.
2. **New files** — files that did not exist in the original and were added.

Classification is by comparison with `git show origin/main:<path>`. For each
file a short note says *what it is* and *why it was changed/added*.

---

## A. Changed files (existed in the original, modified)

### Root
- **`.gitignore`** — Ignore rules. Added entries for the beads/Dolt files created
  by `bd init` (`.dolt/`, `*.db`, `.beads-credential-key`) so the tracker's
  internal database is not committed.
- **`README.md`** — Root readme. Updated so the documented install/setup reflects
  that the Linux desktop runs headless with the Omarchy bar widget as the GUI,
  and that the current Linux UI is not the original windowed UI.

### Build

- **`RustApp/Cargo.toml`** — Dependencies. Added `serde_json` for the Unix-socket
  JSON bridge (net change vs upstream; no crates removed).
- **`RustApp/Cargo.lock`** — Pin file. Regenerated to match the manifest change
  above (adds serde_json and its transitive dependencies).

### Rust source

- **`RustApp/src/lib.rs`** — Module registration. Added the Linux-only
  `quickshell` module that provides the Unix-socket JSON bridge shared by all
  headless features.
- **`RustApp/src/config.rs`** — Config/CLI. Added the hidden `--quickshell` flag
  selecting headless daemon mode (no window). This is the switch that turns the
  app into the socket-served service the bar widget talks to.
- **`RustApp/src/main.rs`** — Entry point. Wires the new `--quickshell` flag from
  the CLI parser down into the app run path.
- **`RustApp/src/ui/app.rs`** — Core app logic, the largest change. Adds
  headless mode: `no_main_window`, skips opening the main window, and connects
  the in-process command channel to the new socket. Adds socket-command handling
  (`connect`/`stop`/`exit`/`config`/`device`/`adapter`/etc.), state/config
  snapshots broadcast to the widget, auto-selection of the AndroidMic virtual
  mic when no device is configured, and removed the system-tray SNI (the bar
  widget is the only GUI).
- **`RustApp/src/ui/message.rs`** — Message types. Extended the app message enum
  with quickshell-specific commands so socket input maps cleanly onto the
  existing mpsc core.

---

## B. New files (did not exist in the original)

### Agent / tooling metadata

- **`AGENTS.md`** — Agent instructions for beads (bd) issue tracking that this
  project adopts. Tells the agent to use `bd` for task tracking.
- **`CLAUDE.md`** — Claude-code project instructions, mirroring the beads
  workflow.
- **`.claude/settings.json`** — IDE/tool hook configuration for the beads
  integration.
- **`.beads/`** — The beads issue tracker, initialized via `bd init`, used to
  track the rework's bugs (e.g. the widget layout bug). Contains ten new files:
  `.beads/.gitignore`, `.beads/README.md`, `.beads/config.yaml`, four git hooks
  (`.beads/hooks/post-checkout`, `post-merge`, `pre-commit`, `pre-push`,
  `prepare-commit-msg`), and `.beads/metadata.json`.
- **`.beads/issues.jsonl`** — Beads auto-export of open/closed issues for
  git-based viewers.

### Quickshell — standalone GUI (`RustApp/quickshell/`)

- **`shell.qml`** — The Quickshell application entry point that loads the
  standalone (windowed) info/settings dialogs. Used by the `run.sh` helper.
- **`AndroidMic.qml`** — Top-level component hosting the widget controller and
  the info/settings dialogs.
- **`InfoWindow.qml`** — Standalone information window (live stream, waveform,
  connect controls). One of the two dialogs; superseded by the bar widget but
  still runnable standalone.
- **`SettingsWindow.qml`** — Standalone settings dialog with the audio
  configuration editors.
- **`Section.qml`** — Layout helper for grouping a settings section's rows.
- **`LauncherWindow.qml`** — Entry launcher UI.
- **`Field.qml`** — Text-field control used by the settings dialogs.
- **`Combo.qml`** — Dropdown/select control used by the settings dialogs.
- **`Toggle.qml`** — Toggle control used by the settings dialogs.
- **`ControlSlider.qml`** — Slider control for the settings dialogs.
- **`BoolRow.qml`** — Reusable boolean-setting row (label + toggle).
- **`QsButton.qml`** — Button style shared by the standalone dialogs.
- **`WaveBars.qml`** — Waveform visualization canvas used by the info window.
- **`Theme.js`** — Theme color definitions for the Quickshell GUI.
- **`Options.js`** — Option lists + default config mirroring the Rust daemon's
  defaults, so the GUI renders real values before the first config message.
- **`Mock.js`** — Mock data/waveform generator for testing the GUI without a
  live daemon.
- **`README.md`** — Documents the Quickshell mode, the socket protocol, and how
  to run the standalone GUI.
- **`README-OMARCHY.md`** — The full Omarchy bar-widget guide (setup, operation,
  GUI differences, OS limitations, troubleshooting, known issues).
- **`res/app_icon.svg`** — Icon resource for the Quickshell GUI.
- **`run.sh`** — Helper that launches the standalone Quickshell GUI against the
  live daemon.

### Quickshell — Omarchy bar widget (`RustApp/quickshell/omarchy/`)

- **`manifest.json`** — Omarchy plugin manifest (id `androidmic.quickshell`,
  kind bar-widget) so the widget shows up/enables in the Omarchy plugin system.
- **`Panel.qml`** — The single self-contained bar-widget panel. Implements the
  bar mic button and the popup with live state, waveform, and audio settings,
  talking to the daemon over the socket. This is the only GUI used.
- **`Options.js`** — Option lists / default config mirror for the bar widget.
- **`Mock.js`** — Mock helpers for the bar widget's offline/development use.

### Quickshell — system integration (`RustApp/quickshell/`)

- **`install.sh`** — One-shot installer: installs the built binary to
  `~/.local/bin/android-mic`, copies the systemd user units below into the
  user's systemd dir and enables them, and installs/enables the bar-widget
  plugin into the user's Omarchy config (skipped when `omarchy-shell` is
  absent).
- **`systemd/androidmic-daemon.service`** — User unit that autostarts the
  headless `android-mic --quickshell` daemon tied to the graphical session.
- **`systemd/androidmic-virtual-mic.service`** — User unit that creates the
  `virtual_mic` PipeWire null-sink (the "Android" output device).
- **`systemd/androidmic-default-source.service`** — User unit that sets the
  default recording source to `virtual_mic.monitor`.
- **`systemd/androidmic-virtual-mic.sh`** — Script run by the units that creates
  the null sink / remap source and sets the default source.

### Rust new module

- **`RustApp/src/quickshell.rs`** — New Linux module implementing the Unix-socket
  server at `$XDG_RUNTIME_DIR/android-mic.qsock`. Owns the newline-delimited JSON
  protocol (state/config/devices/wave broadcasts + command consumption) shared
  by both the standalone GUI and the bar widget, plus serialization helpers.