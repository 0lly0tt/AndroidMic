#!/usr/bin/env bash
# Install the AndroidMic Omarchy bar-widget plugin and enable it.
set -euo pipefail
cd "$(dirname "$0")"

ID="androidmic.quickshell"
DEST="$HOME/.config/omarchy/plugins/$ID"
SRC=omarchy

if ! command -v omarchy-shell >/dev/null 2>&1; then
  echo "error: omarchy-shell not found — is Omarchy installed?" >&2
  exit 1
fi

mkdir -p "$DEST"
cp "$SRC/manifest.json" "$SRC/Panel.qml" "$SRC/Options.js" "$SRC/Mock.js" "$DEST"/

echo "installed plugin files into $DEST"
omarchy plugin validate "$DEST" >/dev/null 2>&1 \
  && echo "manifest validated" || { echo "manifest validation failed"; exit 1; }

omarchy-shell shell rescanPlugins 2>/dev/null || true
sleep 1
omarchy plugin enable "$ID" --section right 2>&1 || true

echo
echo "done. The AndroidMic button will appear in the bar after the shell reloads"
echo "or on your next login. Make sure the backend is running:"
echo "  android-mic --quickshell"