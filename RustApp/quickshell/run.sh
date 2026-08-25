#!/usr/bin/env bash
# Launch the AndroidMic Quickshell GUI.
#
#   ./run.sh          live (needs: android-mic --quickshell running)
#   ./run.sh --mock   simulated backend, no daemon needed
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-}" in
  --mock) export ANDROIDMIC_QS_MOCK=1 ;;
  -h|--help) echo "usage: $0 [--mock]"; exit 0 ;;
esac

exec quickshell -p "$PWD/shell.qml"