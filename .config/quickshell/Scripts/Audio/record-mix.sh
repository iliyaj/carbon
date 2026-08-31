#!/usr/bin/env bash
# usage: record-mix.sh <mic-source> <monitor-source> [wf-recorder args...]
set -u

if [ $# -lt 3 ]; then
    echo "usage: record-mix.sh <mic-source> <monitor-source> [wf-recorder arguments...]" >&2
    exit 2
fi

mic_source=$1
monitor_source=$2
shift 2

sink_name="carbon-recording-mix-$$" # wf-recorder takes only one --audio device
loaded_modules=()

cleanup() {
    local index
    for ((index = ${#loaded_modules[@]} - 1; index >= 0; index--)); do
        pactl unload-module "${loaded_modules[index]}" >/dev/null 2>&1
    done
}
trap cleanup EXIT

load_module() {
    local id
    id=$(pactl load-module "$@" 2>/dev/null) || return 1
    loaded_modules+=("$id")
}

if ! load_module module-null-sink sink_name="$sink_name" sink_properties=device.description=CarbonRecordingMix; then
    echo "record-mix: could not create the mixing sink" >&2
    exit 1
fi

mixed_streams=0
if load_module module-loopback source="$mic_source" sink="$sink_name" latency_msec=20; then
    mixed_streams=$((mixed_streams + 1))
else
    echo "record-mix: could not capture the microphone '$mic_source'" >&2
fi
if load_module module-loopback source="$monitor_source" sink="$sink_name" latency_msec=20; then
    mixed_streams=$((mixed_streams + 1))
else
    echo "record-mix: could not capture the desktop audio '$monitor_source'" >&2
fi

if [ "$mixed_streams" -eq 0 ]; then
    echo "record-mix: no audio stream could be captured" >&2
    exit 1
fi

wf-recorder "$@" --audio="$sink_name.monitor" &
recorder_pid=$!

forward_stop() { # so wf-recorder finalises the file
    kill -INT "$recorder_pid" 2>/dev/null
}
trap forward_stop INT TERM

wait "$recorder_pid"
status=$?
if [ "$status" -gt 128 ]; then
    wait "$recorder_pid"
    status=$?
fi
exit "$status"
