#!/usr/bin/env bash
# AndroidMic one-shot installer: headless daemon + virtual mic (systemd user
# units) and the Omarchy bar-widget plugin.
#
#   ./install.sh                            # binary from ../target/release
#   ./install.sh /path/to/android-mic       # explicit binary path
#
# What it does:
#   1. installs the built binary to ~/.local/bin/android-mic (if present)
#   2. installs + enables the three systemd user units (daemon, virtual mic,
#      default source)
#   3. installs + enables the Omarchy bar-widget plugin (best effort: skipped
#      with a note if omarchy-shell is not available, e.g. non-Omarchy setups)
#
# After running, make sure the backend is up:  journalctl --user -u androidmic-daemon -f
set -euo pipefail
cd "$(dirname "$0")"

UNITS="$PWD/systemd"
SVCDIR="$HOME/.config/systemd/user"
BIN_DEST="$HOME/.local/bin/android-mic"
BIN_SRC="${1:-$PWD/../target/release/android-mic}"

# ---- 1. the binary (only the daemon needs it) ----
if [ -x "$BIN_SRC" ]; then
  mkdir -p "$HOME/.local/bin"
  cp -f "$BIN_SRC" "$BIN_DEST"
  chmod +x "$BIN_DEST"
  echo "installed binary -> $BIN_DEST"
else
  echo "note: no binary at $BIN_SRC; skipping binary install." >&2
  echo "  build it with:  (cd ../ && cargo build --release)" >&2
fi

# ---- 2. systemd user units (autostart daemon + virtual mic) ----
mkdir -p "$SVCDIR"
cp -f "$UNITS/androidmic-daemon.service"         "$SVCDIR/androidmic-daemon.service"
cp -f "$UNITS/androidmic-virtual-mic.service"    "$SVCDIR/androidmic-virtual-mic.service"
cp -f "$UNITS/androidmic-default-source.service" "$SVCDIR/androidmic-default-source.service"
cp -f "$UNITS/androidmic-virtual-mic.sh"         "$SVCDIR/androidmic-virtual-mic.sh"
chmod +x "$SVCDIR/androidmic-virtual-mic.sh"
systemctl --user daemon-reload

systemctl --user enable --now androidmic-virtual-mic.service >/dev/null 2>&1 || true
systemctl --user enable --now androidmic-default-source.service >/dev/null 2>&1 || true
if [ -x "$BIN_DEST" ]; then
  systemctl --user enable --now androidmic-daemon.service >/dev/null 2>&1 || true
fi

echo "installed and enabled user services:"
ls -1 "$SVCDIR"/androidmic-*.service

# ---- 3. Omarchy bar-widget plugin ----
ID="androidmic.quickshell"
DEST="$HOME/.config/omarchy/plugins/$ID"
if command -v omarchy-shell >/dev/null 2>&1; then
  mkdir -p "$DEST"
  cp -f omarchy/manifest.json omarchy/Panel.qml omarchy/Options.js omarchy/Mock.js "$DEST"/
  omarchy plugin validate "$DEST" >/dev/null 2>&1 \
    && echo "plugin manifest validated" || echo "warning: plugin manifest validation failed" >&2
  omarchy-shell shell rescanPlugins 2>/dev/null || true
  sleep 1
  omarchy plugin enable "$ID" --section right 2>&1 || true
  echo "installed plugin -> $DEST"
  echo "the AndroidMic button appears in the bar after the shell reloads or on next login"
else
  echo "note: omarchy-shell not found — skipping bar-widget plugin install." >&2
fi

echo
echo "done. Useful commands:"
echo "  daemon:  journalctl --user -u androidmic-daemon.service -f"
echo "  reload:  omarchy restart shell"
