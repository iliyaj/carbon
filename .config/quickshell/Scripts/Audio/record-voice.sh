#!/usr/bin/env bash
# usage: record-voice.sh <mic-source> <monitor-source> <output.wav>
set -eu

if [ $# -ne 3 ]; then
    echo "usage: record-voice.sh <mic-source> <monitor-source> <output.wav>" >&2
    exit 2
fi

mkdir -p "$(dirname "$3")"
# Whisper works on 16 kHz mono, so PipeWire converts each source before the mix.
exec ffmpeg -hide_banner -nostdin -loglevel warning \
    -f pulse -sample_rate 16000 -channels 1 -i "$1" \
    -f pulse -sample_rate 16000 -channels 1 -i "$2" \
    -filter_complex amix=inputs=2:normalize=0 \
    -c:a pcm_s16le "$3"
