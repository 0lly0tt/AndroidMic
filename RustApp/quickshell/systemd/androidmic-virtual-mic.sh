#!/usr/bin/env bash
# Persistent Android Mic -> virtual PipeWire/PulseAudio microphone.
# Runs at each login (user systemd service). Idempotent.
#
Installed by install.sh as ~/.config/systemd/user/androidmic-virtual-mic.sh
set -u

# Wait for the PulseAudio socket to be ready.
for i in $(seq 1 30); do
  pactl info >/dev/null 2>&1 && break
  sleep 1
done
pactl info >/dev/null 2>&1 || { echo "pipewire/pulse not available"; exit 1; }

SINK="virtual_mic"
SOURCE="virtual_mic_source"

# 1) Null sink that AndroidMic "plays into". Its monitor = the mic.
if ! pactl list short sinks | grep -qE "^\S+\s+${SINK}\b"; then
  pactl load-module module-null-sink sink_name="${SINK}" sink_properties=device.description="Android Mic (phone)"
  echo "created sink: ${SINK}"
else
  echo "sink ${SINK} already present"
fi

# 2) Remap the sink's monitor into a named source (optional but clean).
if ! pactl list short sources | grep -qE "^\S+\s+${SOURCE}\b"; then
  pactl load-module module-remap-source master="${SINK}.monitor" source_name="${SOURCE}"
  echo "created source: ${SOURCE}"
else
  echo "source ${SOURCE} already present"
fi

# 3) Make the phone mic the default recording device.
pactl set-default-source "${SINK}.monitor"
echo "default source set to ${SINK}.monitor (${SOURCE})"