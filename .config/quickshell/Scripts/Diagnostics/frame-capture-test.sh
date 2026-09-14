#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/frame-capture.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/carbon-frame-capture-test.XXXXXX")"
sleep_pid=""
export FRAME_CAPTURE_NOTIFY=0

cleanup() {
    if [ -n "$sleep_pid" ] && kill -0 "$sleep_pid" 2>/dev/null; then
        kill "$sleep_pid"
        wait "$sleep_pid" 2>/dev/null || true
    fi
    case "$test_root" in
        "${TMPDIR:-/tmp}"/carbon-frame-capture-test.*) rm -rf -- "$test_root" ;;
        *) printf 'refusing to remove unexpected test path: %s\n' "$test_root" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL  %s\n' "$1" >&2
    exit 1
}

expect_failure() {
    local output_file="$1"
    shift
    if "$@" > "$output_file" 2>&1; then
        fail "command unexpectedly succeeded: $*"
    fi
}

for command_name in ffmpeg ffprobe jq fc-match flock; do
    command -v "$command_name" >/dev/null || fail "$command_name is required"
done

fresh_root="$test_root/fresh"
expect_failure "$test_root/fresh-stop.log" env FRAME_CAPTURE_DIR="$fresh_root" "$helper" stop
[ -d "$fresh_root" ] || fail "stop did not create a fresh capture root"
[ -f "$fresh_root/lock" ] || fail "stop did not create the lock file"
grep -q '^no active capture$' "$test_root/fresh-stop.log" || fail "fresh stop returned the wrong error"

bundle="$fresh_root/20260101T000000Z"
mkdir "$bundle"
ffmpeg -hide_banner -loglevel error \
    -f lavfi -i "color=c=black:s=64x64:r=1:d=2" \
    -f lavfi -i "color=c=white:s=64x64:r=1:d=1" \
    -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p[v]" \
    -map "[v]" -c:v libx264 "$bundle/recording.mp4"
source_hash="$(sha256sum "$bundle/recording.mp4" | awk '{ print $1 }')"

FRAME_CAPTURE_DIR="$fresh_root" "$helper" sidecar "$bundle" >/dev/null
[ "$(wc -l < "$bundle/frames.csv")" -eq 4 ] || fail "sidecar does not contain three frames"
awk -F, '
    NR == 1 { valid = ($0 == "frame_index,pts_time,pts") }
    NR > 1 { valid = valid && ($1 == NR - 2) && ($2 == NR - 2 ".000000") }
    END { exit !valid }
' "$bundle/frames.csv" || fail "sidecar frame/PTS mapping is incorrect"

FRAME_CAPTURE_DIR="$fresh_root" "$helper" diff "$bundle" > "$test_root/diff.log"
awk -F, '
    NR == 1 { valid = ($0 == "frame_index,pts_time,mean_luma_difference") }
    NR == 2 { valid = valid && $1 == 1 && $2 == "1.000000" && $3 == 0 }
    NR == 3 { valid = valid && $1 == 2 && $2 == "2.000000" && $3 > 0 }
    END { exit !(valid && NR == 3) }
' "$bundle/frames-diff.csv" || fail "adjacent diff frame/PTS mapping is incorrect"
grep -q '^max adjacent diff: frame 2 at t 2.000000 ' "$test_root/diff.log" \
    || fail "maximum adjacent diff points to the wrong frame"

FRAME_CAPTURE_DIR="$fresh_root" "$helper" extract "$bundle" 1 2 >/dev/null
[ "$(find "$bundle/frames" -maxdepth 1 -type f -name 'f[0-9]*.png' -printf . | wc -c)" -eq 2 ] \
    || fail "valid extraction did not produce two frames"
FRAME_CAPTURE_DIR="$fresh_root" "$helper" sheet "$bundle" >/dev/null
[ -s "$bundle/contact-sheet.png" ] || fail "contact sheet was not created"
expect_failure "$test_root/range.log" env FRAME_CAPTURE_DIR="$fresh_root" "$helper" extract "$bundle" 1 5
grep -q '^last frame 5 is outside 0..2$' "$test_root/range.log" || fail "invalid range error is inaccurate"

[ "$(sha256sum "$bundle/recording.mp4" | awk '{ print $1 }')" = "$source_hash" ] \
    || fail "a derived command modified the source recording"

corrupt_bundle="$fresh_root/20260101T000001Z"
mkdir "$corrupt_bundle"
printf 'not an mp4\n' > "$corrupt_bundle/recording.mp4"
expect_failure "$test_root/corrupt.log" env FRAME_CAPTURE_DIR="$fresh_root" "$helper" sidecar "$corrupt_bundle"
[ ! -e "$corrupt_bundle/frames.csv" ] || fail "failed sidecar generation published an artifact"

incomplete_bundle="$fresh_root/99999999T999999Z"
mkdir "$incomplete_bundle"
FRAME_CAPTURE_DIR="$fresh_root" "$helper" status > "$test_root/status.log"
grep -q '99999999T999999Z: incomplete or unreadable capture' "$test_root/status.log" \
    || fail "status did not report the incomplete latest bundle"
if grep -q '^  lock$' "$test_root/status.log"; then
    fail "status listed its lock file as a bundle"
fi

sleep 30 &
sleep_pid=$!
printf '%s\n%s\n%s\n' "$sleep_pid" "$incomplete_bundle" "$(date +%s)" > "$fresh_root/active"
expect_failure "$test_root/stale.log" env FRAME_CAPTURE_DIR="$fresh_root" "$helper" stop
kill -0 "$sleep_pid" 2>/dev/null || fail "stale active state signalled an unrelated process"
[ ! -e "$fresh_root/active" ] || fail "stale active state was not cleared"

printf 'PASS  frame-capture synthetic regression checks\n'
