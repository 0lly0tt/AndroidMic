#!/usr/bin/env bash
# Install + enable the AndroidMic headless daemon as an autostart user unit.
#
#  build the branch first, then:
#    ./install-systemd.sh                       # uses target/release/android-mic
#    ./install-systemd.sh /path/to/androidmic   # explicit binary path
set -euo pipefail
cd "$(dirname "$0")"

SERVICE="androidmic-daemon.service"
UNIT_SRC="$PWD/systemd/$SERVICE"
BIN_DEST="$HOME/.local/bin/android-mic"
UNIT_DEST="$HOME/.config/systemd/user/$SERVICE"

BIN_SRC="${1:-$PWD/../target/release/android-mic}"
if [ ! -x "$BIN_SRC" ]; then
  echo "error: no binary at $BIN_SRC" >&2
  echo "  build it first:  (cd ../ && cargo build --release)" >&2
  echo "  or pass a path:  $0 /path/to/android-mic" >&2
  exit 1
fi

# 1) Stable binary path (the unit references ~/.local/bin/android-mic).
mkdir -p "$HOME/.local/bin"
cp -f "$BIN_SRC" "$BIN_DEST"
chmod +x "$BIN_DEST"
echo "installed binary -> $BIN_DEST"

# 2) Install + validate the unit against its real path.
mkdir -p "$HOME/.config/systemd/user"
cp -f "$UNIT_SRC" "$UNIT_DEST"
"$BIN_DEST" --version >/dev/null 2>&1 || true   # (warm-up / sanity)

systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE"
systemctl --user --no-pager status "$SERVICE" | head -12 || true

echo
echo "done. The AndroidMic daemon now starts at login."
echo "See: journalctl --user -u $SERVICE -f"