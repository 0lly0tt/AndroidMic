#!/usr/bin/env bash
# Install + enable the AndroidMic user services for autostart:
#    * androidmic-daemon.service     -- the headless `--quickshell` daemon (socket)
#    * androidmic-virtual-mic.service — creates the virtual_mic null sink + source
#    * androidmic-default-source.service — sets virtual_mic.monitor as the default source
#
#  build the branch first, then:
#    ./install-systemd.sh                       # uses the built release binary
#    ./install-systemd.sh /path/to/androidmic   # explicit binary path
set -euo pipefail
cd "$(dirname "$0")"

UNITS="$PWD/systemd"
SVCDIR="$HOME/.config/systemd/user"
BIN_DEST="$HOME/.local/bin/android-mic"

BIN_SRC="${1:-$PWD/../target/release/android-mic}"

mkdir -p "$SVCDIR"

# ---- the binary (only the daemon needs it) ----
if [ -x "$BIN_SRC" ]; then
  mkdir -p "$HOME/.local/bin"
  cp -f "$BIN_SRC" "$BIN_DEST"
  chmod +x "$BIN_DEST"
  echo "installed binary -> $BIN_DEST"
else
  echo "note: no binary at $BIN_SRC; only the virtual-mic units are installed." >&2
  echo "  build it later with:  (cd ../ && cargo build --release)" >&2
fi

# ---- install units + helper script ----
cp -f "$UNITS/androidmic-daemon.service"         "$SVCDIR/androidmic-daemon.service"
cp -f "$UNITS/androidmic-virtual-mic.service"    "$SVCDIR/androidmic-virtual-mic.service"
cp -f "$UNITS/androidmic-default-source.service" "$SVCDIR/androidmic-default-source.service"
cp -f "$UNITS/androidmic-virtual-mic.sh"         "$SVCDIR/androidmic-virtual-mic.sh"
chmod +x "$SVCDIR/androidmic-virtual-mic.sh"

systemctl --user daemon-reload

# ---- enable (virtual-mic always; daemon only if we have a binary) ----
systemctl --user enable --now androidmic-virtual-mic.service >/dev/null 2>&1 || true
systemctl --user enable --now androidmic-default-source.service >/dev/null 2>&1 || true
if [ -x "$BIN_DEST" ]; then
  systemctl --user enable --now androidmic-daemon.service >/dev/null 2>&1 || true
fi

echo
echo "installed and enabled user services:"
ls -1 "$SVCDIR"/androidmic-*.service
echo
echo "virtual mic (androidmic-virtual-mic.service) auto-created at login."
echo "daemon:  journalctl --user -u androidmic-daemon.service -f"