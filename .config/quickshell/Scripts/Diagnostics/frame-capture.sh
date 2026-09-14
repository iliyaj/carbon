#!/usr/bin/env bash

set -euo pipefail

# Debug captures live in the user's video area (Videos/debug by default) so a
# caught stall opens from a familiar place instead of buried XDG state.
if [ -n "${XDG_VIDEOS_DIR:-}" ]; then
    video_dir="$XDG_VIDEOS_DIR"
else
    video_dir="$(xdg-user-dir VIDEOS 2>/dev/null || true)"
    [ -n "$video_dir" ] || video_dir="$HOME/Videos"
fi
state_root="${FRAME_CAPTURE_DIR:-$video_dir/debug}"
active_file="$state_root/active"
lock_file="$state_root/lock"

request_fps="${FRAME_CAPTURE_FPS:-60}"
monitor="${FRAME_CAPTURE_MONITOR:-current}"
extra_args="${FRAME_CAPTURE_EXTRA_ARGS:-}"
review_scale="${FRAME_CAPTURE_REVIEW_SCALE:-640}"
minimum_capture_seconds=2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'EOF'
Usage: frame-capture.sh <command> [arguments]

  start                        Start a constant-frame-rate screen capture in a new timestamped bundle
  stop                         Stop the active capture, write end metadata, then generate frames.csv and review.mp4
  toggle                       Start if no capture is active, stop if one is
  sidecar [bundle]             Write frames.csv mapping frame index to PTS
  review [bundle]              Write review.mp4 with a per-frame index and time label
  extract [bundle] FIRST LAST  Write labeled frames FIRST..LAST to frames/
  sheet [bundle]               Build contact-sheet.png from frames/
  diff [bundle]                Write frames-diff.csv with adjacent-frame luma difference
  status                       Show the active capture and the latest bundle summary

A bundle is a directory name in the state root or an absolute path; the latest
bundle is used when omitted. Frame indices are zero-based and match frames.csv.
Stop generates the sidecar and timestamped review immediately, so the new
bundle is frame-addressable without any further command.

Overrides: FRAME_CAPTURE_DIR (~/Videos/debug), FRAME_CAPTURE_FPS (60),
FRAME_CAPTURE_MONITOR (current), FRAME_CAPTURE_EXTRA_ARGS (raw wf-recorder
flags), FRAME_CAPTURE_REVIEW_SCALE (640).
EOF
}

die() {
    echo "$1" >&2
    if [ "${FRAME_CAPTURE_NOTIFY:-1}" = "1" ]; then
        notify "Frame capture failed" "$1"
    fi
    exit 1
}

require_commands() {
    local command_name
    for command_name in "$@"; do
        command -v "$command_name" >/dev/null || die "$command_name not found in PATH"
    done
}

acquire_lock() {
    # Hold for the entire command lifetime: stop finalization (metadata + review
    # encode) can run for seconds, and a rapid second keypress landing in that
    # window must queue behind it instead of starting a second recorder. The
    # kernel releases the fd automatically when the process exits.
    mkdir -p "$state_root" || die "cannot create capture root: $state_root"
    require_commands flock
    exec 9>>"$lock_file" || die "cannot open lock file: $lock_file"
    flock -w 30 9 || die "another frame-capture command is still running; wait and retry"
}

notify() {
    # Notifications are best-effort: a missing notifier must never fail a capture.
    command -v notify-send >/dev/null || return 0
    notify-send -a "Frame Capture" "$1" "$2" >/dev/null 2>&1 || true
}

resolve_bundle() {
    local ref="${1:-}"
    if [ -z "$ref" ]; then
        latest_bundle || die "no capture bundles in $state_root"
    elif [ -d "$ref" ]; then
        printf '%s\n' "$ref"
    elif [ -d "$state_root/$ref" ]; then
        printf '%s\n' "$state_root/$ref"
    else
        die "capture bundle not found: $ref"
    fi
}

latest_bundle() {
    local candidate latest=""
    for candidate in "$state_root"/*/; do
        [ -d "$candidate" ] || continue
        candidate="${candidate%/}"
        if [ -z "$latest" ] || [[ "$candidate" > "$latest" ]]; then
            latest="$candidate"
        fi
    done
    [ -n "$latest" ] || return 1
    printf '%s\n' "$latest"
}

process_start_ticks() {
    local pid="$1" stat_raw stat_rest
    local -a stat_fields
    [ -r "/proc/$pid/stat" ] || return 1
    stat_raw="$(<"/proc/$pid/stat")" || return 1
    stat_rest="${stat_raw##*) }"
    read -ra stat_fields <<< "$stat_rest"
    [ "${#stat_fields[@]}" -gt 19 ] || return 1
    printf '%s\n' "${stat_fields[19]}"
}

recorder_process_matches() {
    local pid="$1" bundle="$2" expected_start_ticks="${3:-}"
    local current_start_ticks command_name argument found_output=0
    [ -r "/proc/$pid/comm" ] && [ -r "/proc/$pid/cmdline" ] || return 1
    command_name="$(<"/proc/$pid/comm")"
    [ "$command_name" = "wf-recorder" ] || return 1

    current_start_ticks="$(process_start_ticks "$pid")" || return 1
    if [ -n "$expected_start_ticks" ]; then
        case "$expected_start_ticks" in *[!0-9]* | "") return 1 ;; esac
        [ "$current_start_ticks" = "$expected_start_ticks" ] || return 1
    fi

    while IFS= read -r -d '' argument; do
        if [ "$argument" = "$bundle/recording.mp4" ]; then
            found_output=1
            break
        fi
    done < "/proc/$pid/cmdline"
    [ "$found_output" -eq 1 ]
}

read_active_state() {
    local -a active_lines
    [ -s "$active_file" ] || return 1
    mapfile -t active_lines < "$active_file" || return 1
    [ "${#active_lines[@]}" -ge 3 ] || return 1
    active_pid="${active_lines[0]}"
    active_bundle="${active_lines[1]}"
    active_started_epoch="${active_lines[2]}"
    active_start_ticks="${active_lines[3]:-}"
    active_started_monotonic="${active_lines[4]:-}"
    case "$active_pid" in *[!0-9]* | "") return 1 ;; esac
    case "$active_started_epoch" in *[!0-9]* | "") return 1 ;; esac
    [ -n "$active_bundle" ] || return 1
}

media_file() {
    local file="$1/recording.mp4"
    if [ ! -s "$file" ]; then
        echo "no usable recording.mp4 in $1" >&2
        return 1
    fi
    printf '%s\n' "$file"
}

label_font() {
    fc-match -f '%{file}' "DejaVu Sans Mono"
}

current_monitor() {
    # wf-recorder has no non-interactive monitor listing here; hyprctl is the
    # only reliable source. Focused monitor first, else first non-disabled.
    hyprctl -j monitors 2>/dev/null \
        | jq -r '([.[] | select(.focused)] | .[0].name) // ([.[] | select(.disabled | not)] | .[0].name) // empty'
}

monotonic_seconds() {
    awk '{ printf "%.3f", $1 }' /proc/uptime
}

generate_sidecar() {
    local bundle="$1"
    local file temporary_file frame_count
    file="$(media_file "$bundle")" || return 1
    temporary_file="$bundle/.frames.csv.tmp.$$"
    if ! {
        printf '%s\n' "frame_index,pts_time,pts"
        ffprobe -v error -select_streams v -show_frames -show_entries frame=pts_time,pts -of csv=p=0 "$file" \
            | awk -F, '{ print NR - 1 "," $2 "," $1 }'
    } > "$temporary_file"; then
        rm -f "$temporary_file"
        die "failed to inspect frame timestamps in $file"
    fi
    frame_count=$(( $(wc -l < "$temporary_file") - 1 ))
    if [ "$frame_count" -lt 1 ]; then
        rm -f "$temporary_file"
        die "no video frames found in $file"
    fi
    mv "$temporary_file" "$bundle/frames.csv" || die "cannot publish $bundle/frames.csv"
    echo "wrote $bundle/frames.csv ($frame_count frames)"
}

probe_video() {
    local file="$1"
    ffprobe -v error -select_streams v:0 -count_frames \
        -show_entries stream=codec_name,width,height,r_frame_rate,avg_frame_rate,nb_read_frames,time_base \
        -show_entries format=duration -of json "$file" \
        | jq -er '(.streams[0] // error("video stream missing")) as $stream
            | [.format.duration, $stream.codec_name, $stream.width, $stream.height,
               $stream.r_frame_rate, $stream.avg_frame_rate, $stream.time_base,
               $stream.nb_read_frames]
            | map(if . == null then "N/A" else tostring end)
            | join("|")'
}

append_stream_metadata() {
    local bundle="$1" file="$2"
    local duration codec width height rate average_rate time_base frames metadata
    metadata="$(probe_video "$file")" || die "failed to inspect video stream in $file"
    IFS='|' read -r duration codec width height rate average_rate time_base frames <<< "$metadata"
    if [ "$frames" = "N/A" ] && [ -s "$bundle/frames.csv" ]; then
        frames=$(( $(wc -l < "$bundle/frames.csv") - 1 ))
    fi
    {
        printf 'video_duration_s=%s\n' "$duration"
        printf 'video_codec=%s\n' "$codec"
        printf 'video_width=%s\n' "$width"
        printf 'video_height=%s\n' "$height"
        printf 'video_nominal_rate=%s\n' "$rate"
        printf 'video_average_rate=%s\n' "$average_rate"
        printf 'video_time_base=%s\n' "$time_base"
        printf 'video_frame_count=%s\n' "$frames"
    } >> "$bundle/capture-meta.env"
}

summarize() {
    local bundle="$1"
    local file duration duration_label codec width height rate average_rate time_base frames metadata
    file="$(media_file "$bundle")" || return 1
    metadata="$(probe_video "$file")" || return 1
    IFS='|' read -r duration codec width height rate average_rate time_base frames <<< "$metadata"
    if [ "$frames" = "N/A" ] && [ -s "$bundle/frames.csv" ]; then
        frames=$(( $(wc -l < "$bundle/frames.csv") - 1 ))
    fi
    case "$frames" in *[!0-9]* | "" | 0) return 1 ;; esac
    duration_label="$duration"
    [ "$duration" = "N/A" ] || duration_label="${duration}s"
    echo "  $(basename "$bundle"): $codec ${width}x${height} rate=$rate frames=$frames duration=$duration_label"
}

create_bundle() {
    local base candidate suffix=0
    base="$state_root/$(date -u +%Y%m%dT%H%M%SZ)"
    candidate="$base"
    while [ -e "$candidate" ]; do
        suffix=$((suffix + 1))
        printf -v candidate '%s-%02d' "$base" "$suffix"
    done
    mkdir "$candidate" || die "cannot create capture bundle: $candidate"
    printf '%s\n' "$candidate"
}

process_cpu_seconds() {
    local pid="$1" stat_raw stat_rest ticks_per_second
    local -a stat_fields
    [ -r "/proc/$pid/stat" ] || return 1
    stat_raw="$(<"/proc/$pid/stat")" || return 1
    stat_rest="${stat_raw##*) }"
    read -ra stat_fields <<< "$stat_rest"
    [ "${#stat_fields[@]}" -gt 12 ] || return 1
    ticks_per_second="$(getconf CLK_TCK)" || return 1
    awk -v ticks="$(( ${stat_fields[11]} + ${stat_fields[12]} ))" -v hz="$ticks_per_second" \
        'BEGIN { printf "%.3f", ticks / hz }'
}

process_rss_kib() {
    local pid="$1"
    awk '/^VmRSS:/ { print $2; found = 1; exit } END { if (!found) exit 1 }' "/proc/$pid/status" 2>/dev/null
}

write_active_state() {
    local temporary_file="$state_root/.active.tmp.$$"
    if ! printf '%s\n%s\n%s\n%s\n%s\n' \
        "$1" "$2" "$3" "$4" "$5" > "$temporary_file"; then
        rm -f "$temporary_file"
        return 1
    fi
    mv "$temporary_file" "$active_file"
}

cmd_start() {
    require_commands wf-recorder ffprobe ffmpeg jq fc-match hyprctl
    case "$request_fps" in *[!0-9]* | "" | 0) die "FRAME_CAPTURE_FPS must be a positive integer" ;; esac

    if [ -s "$active_file" ]; then
        if read_active_state && recorder_process_matches "$active_pid" "$active_bundle" "$active_start_ticks"; then
            die "a capture is already active (pid $active_pid); stop it first"
        fi
        rm -f "$active_file"
    fi

    local bundle monitor_target
    bundle="$(create_bundle)" || die "failed to create a capture bundle"

    case "$monitor" in
        current)
            monitor_target="$(current_monitor)" || die "could not resolve the current Hyprland monitor"
            [ -n "$monitor_target" ] || die "could not resolve the current Hyprland monitor"
            ;;
        *) monitor_target="$monitor" ;;
    esac

    local started_wall started_epoch started_monotonic repo_commit pid start_ticks=""
    local attempt recorder_exit=0
    local -a monitor_args=() recorder_extra_args=()
    started_wall="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
    started_epoch="$(date +%s)"
    started_monotonic="$(monotonic_seconds)"
    repo_commit="$(git -C "$script_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    [ -n "$monitor_target" ] && monitor_args=(-o "$monitor_target")
    [ -z "$extra_args" ] || read -ra recorder_extra_args <<< "$extra_args"

    nohup wf-recorder -D -r "$request_fps" --pixel-format yuv420p \
        "${monitor_args[@]}" "${recorder_extra_args[@]}" \
        -f "$bundle/recording.mp4" \
        > "$bundle/capture-stdout.log" 2> "$bundle/capture-stderr.log" 9>&- &
    # 9>&- so the recorder does not inherit the lock fd and hold the flock
    # for the entire capture.
    pid=$!

    # Do not publish a PID until wf-recorder has exec'd and its output argument
    # matches this bundle. This prevents stale state from ever authorizing a
    # signal to an unrelated process after PID reuse.
    for attempt in {1..20}; do
        start_ticks="$(process_start_ticks "$pid" 2>/dev/null || true)"
        if [ -n "$start_ticks" ] && recorder_process_matches "$pid" "$bundle" "$start_ticks"; then
            break
        fi
        sleep 0.05
    done
    if [ -z "$start_ticks" ] || ! recorder_process_matches "$pid" "$bundle" "$start_ticks"; then
        wait "$pid" || recorder_exit=$?
        die "wf-recorder failed during startup; see $bundle/capture-stderr.log"
    fi

    if ! write_active_state "$pid" "$bundle" "$started_epoch" "$start_ticks" "$started_monotonic"; then
        kill -TERM "$pid" 2>/dev/null || true
        die "cannot publish active capture state: $active_file"
    fi

    if ! {
        printf 'capture_started_wallclock=%s\n' "$started_wall"
        printf 'capture_started_monotonic_s=%s\n' "$started_monotonic"
        printf 'capture_request_fps=%s\n' "$request_fps"
        printf 'capture_monitor=%s\n' "$monitor_target"
        printf 'capture_mode=internal\n'
        printf 'capture_commit=%s\n' "$repo_commit"
        printf 'capture_pid=%s\n' "$pid"
        printf 'capture_process_start_ticks=%s\n' "$start_ticks"
    } > "$bundle/capture-meta.env"; then
        kill -TERM "$pid" 2>/dev/null || true
        rm -f "$active_file"
        die "cannot write capture metadata: $bundle/capture-meta.env"
    fi

    echo "capturing to $bundle (pid $pid, ${monitor_target:-all monitors}, ${request_fps}fps CFR)"
    echo "stop with: $(basename "$0") stop"
    notify "Frame capture started" "$bundle"
}

cmd_stop() {
    [ -s "$active_file" ] || die "no active capture"
    local stopped_monotonic duration recorder_cpu recorder_rss recorder_cpu_pct
    local now_monotonic warmup_remaining
    read_active_state || {
        rm -f "$active_file"
        die "malformed active capture state was cleared"
    }
    if ! recorder_process_matches "$active_pid" "$active_bundle" "$active_start_ticks"; then
        rm -f "$active_file"
        die "stale active capture state was cleared without signalling pid $active_pid"
    fi

    # wf-recorder can finalize a packet-only, undecodable MP4 if stopped while
    # its capture pipeline is still warming up. Delay only an immediate toggle.
    if [[ "$active_started_monotonic" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        now_monotonic="$(monotonic_seconds)"
        warmup_remaining="$(awk -v start="$active_started_monotonic" -v now="$now_monotonic" \
            -v minimum="$minimum_capture_seconds" \
            'BEGIN { remaining = minimum - (now - start); if (remaining > 0) printf "%.3f", remaining }')"
        [ -z "$warmup_remaining" ] || sleep "$warmup_remaining"
    fi
    if ! recorder_process_matches "$active_pid" "$active_bundle" "$active_start_ticks"; then
        rm -f "$active_file"
        die "recorder exited during capture; stale active state was cleared"
    fi

    recorder_cpu="$(process_cpu_seconds "$active_pid" 2>/dev/null || echo unknown)"
    recorder_rss="$(process_rss_kib "$active_pid" 2>/dev/null || echo unknown)"

    kill -INT "$active_pid" 2>/dev/null || true
    local waited=0
    while recorder_process_matches "$active_pid" "$active_bundle" "$active_start_ticks" && [ "$waited" -lt 30 ]; do
        sleep 1
        waited=$((waited + 1))
        # A recorder killed right after start may not have reached its signal
        # handling path; escalate instead of waiting out the full 30s.
        if [ "$waited" -eq 5 ]; then
            echo "wf-recorder still alive after 5s; escalating to TERM" >&2
            kill -TERM "$active_pid" 2>/dev/null || true
        fi
    done
    if recorder_process_matches "$active_pid" "$active_bundle" "$active_start_ticks"; then
        echo "wf-recorder did not exit within 30s" >&2
        kill -KILL "$active_pid" 2>/dev/null || true
        for _ in {1..20}; do
            recorder_process_matches "$active_pid" "$active_bundle" "$active_start_ticks" || break
            sleep 0.05
        done
        if recorder_process_matches "$active_pid" "$active_bundle" "$active_start_ticks"; then
            die "wf-recorder could not be stopped; active state was preserved"
        fi
    fi
    rm -f "$active_file"

    stopped_monotonic="$(monotonic_seconds)"
    if [[ "$active_started_monotonic" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        duration="$(awk -v start="$active_started_monotonic" -v stop="$stopped_monotonic" \
            'BEGIN { printf "%.3f", stop - start }')"
    else
        duration="$(awk -v start="$active_started_epoch" 'BEGIN { printf "%.1f", systime() - start }')"
    fi
    if [ "$recorder_cpu" != "unknown" ]; then
        recorder_cpu_pct="$(awk -v cpu="$recorder_cpu" -v elapsed="$duration" \
            'BEGIN { if (elapsed > 0) printf "%.1f", cpu * 100 / elapsed; else print "unknown" }')"
    else
        recorder_cpu_pct=unknown
    fi

    {
        printf 'capture_stopped_wallclock=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
        printf 'capture_stopped_monotonic_s=%s\n' "$stopped_monotonic"
        printf 'capture_duration_s=%s\n' "$duration"
        printf 'capture_recorder_cpu_s=%s\n' "$recorder_cpu"
        printf 'capture_recorder_average_cpu_pct=%s\n' "$recorder_cpu_pct"
        printf 'capture_recorder_rss_kib_at_stop=%s\n' "$recorder_rss"
    } >> "$active_bundle/capture-meta.env"

    local file
    file="$(media_file "$active_bundle")" || die "capture stopped without a usable recording: $active_bundle"
    # Generate the index and timestamped review on stop rather than on demand,
    # so the capture just caught is immediately frame-addressable.
    generate_sidecar "$active_bundle"
    append_stream_metadata "$active_bundle" "$file"
    build_review "$active_bundle"

    echo "stopped capture: $active_bundle"
    summarize "$active_bundle" || die "failed to summarize capture: $active_bundle"
    notify "Frame capture stopped" "$active_bundle (review.mp4 ready)"
}

cmd_toggle() {
    # One key for the whole capture: start if idle, stop if already recording.
    if read_active_state && recorder_process_matches "$active_pid" "$active_bundle" "$active_start_ticks"; then
        cmd_stop
    else
        cmd_start
    fi
}

cmd_sidecar() {
    local bundle
    bundle="$(resolve_bundle "${1:-}")" || return 1
    generate_sidecar "$bundle"
}

build_review() {
    local bundle="$1" file font temporary_file
    file="$(media_file "$bundle")" || return 1
    font="$(label_font)" || die "could not resolve the review label font"
    [ -n "$font" ] || die "could not resolve the review label font"
    temporary_file="$bundle/.review.tmp.$$.mp4"
    if ! ffmpeg -hide_banner -loglevel error -i "$file" \
        -vf "drawtext=fontfile=$font:text='frame %{n}  t %{pts\:hms}':x=12:y=12:fontsize=34:fontcolor=white:box=1:boxcolor=black@0.65:boxborderw=8" \
        -c:v libx264 -preset veryfast -crf 20 \
        "$temporary_file" -y; then
        rm -f "$temporary_file"
        die "failed to build review copy"
    fi
    mv "$temporary_file" "$bundle/review.mp4" || die "cannot publish $bundle/review.mp4"
    echo "wrote $bundle/review.mp4"
}

cmd_review() {
    local bundle
    bundle="$(resolve_bundle "${1:-}")" || return 1
    build_review "$bundle"
}

cmd_extract() {
    [ $# -ge 2 ] && [ $# -le 3 ] || die "extract takes [bundle] FIRST LAST"
    local ref first last bundle file font count frame_count actual_count temporary_frames
    if [ $# -eq 2 ]; then
        ref=""
        first="$1"
        last="$2"
    else
        ref="$1"
        first="$2"
        last="$3"
    fi
    case "$first$last" in
        *[!0-9]* | "") die "frame indices must be non-negative integers: $first..$last" ;;
    esac
    bundle="$(resolve_bundle "$ref")" || return 1
    file="$(media_file "$bundle")" || return 1
    font="$(label_font)" || die "could not resolve the frame label font"
    [ -n "$font" ] || die "could not resolve the frame label font"
    count=$((last - first + 1))
    [ "$count" -ge 1 ] || die "invalid range: $first..$last"

    generate_sidecar "$bundle"
    frame_count="$(awk -F, 'END { print $1 + 1 }' "$bundle/frames.csv")"
    [ "$first" -lt "$frame_count" ] || die "first frame $first is outside 0..$((frame_count - 1))"
    [ "$last" -lt "$frame_count" ] || die "last frame $last is outside 0..$((frame_count - 1))"

    temporary_frames="$bundle/.frames.tmp.$$"
    mkdir "$temporary_frames" || die "cannot create temporary frame directory"
    if ! ffmpeg -hide_banner -loglevel error -i "$file" \
        -vf "select='between(n,$first,$last)',drawtext=fontfile=$font:text='frame %{eif\:n+$first\:d}  t %{pts\:hms}':x=8:y=8:fontsize=26:fontcolor=yellow:box=1:boxcolor=black@0.7:boxborderw=6" \
        -fps_mode passthrough \
        "$temporary_frames/f%04d.png" -y; then
        rm -rf "$temporary_frames"
        die "failed to extract frames"
    fi
    actual_count="$(find "$temporary_frames" -maxdepth 1 -type f -name 'f[0-9]*.png' -printf . | wc -c)"
    if [ "$actual_count" -ne "$count" ]; then
        rm -rf "$temporary_frames"
        die "extracted $actual_count frames, expected $count"
    fi
    mkdir -p "$bundle/frames"
    rm -f "$bundle/frames/"f[0-9]*.png
    mv "$temporary_frames/"f[0-9]*.png "$bundle/frames/"
    rmdir "$temporary_frames"

    echo "wrote $actual_count frames to $bundle/frames (indices $first..$last)"
    if [ "$count" -le 12 ]; then
        awk -F, -v a="$first" -v b="$last" 'NR > 1 && $1 >= a && $1 <= b { print "  frame " $1 "  t " $2 }' "$bundle/frames.csv"
    else
        echo "  full index -> PTS map: $bundle/frames.csv"
    fi
}

cmd_sheet() {
    local bundle frame_count cols rows temporary_file
    local -a frame_files
    bundle="$(resolve_bundle "${1:-}")" || return 1
    case "$review_scale" in *[!0-9]* | "" | 0) die "FRAME_CAPTURE_REVIEW_SCALE must be a positive integer" ;; esac
    shopt -s nullglob
    frame_files=("$bundle/frames/"f[0-9]*.png)
    shopt -u nullglob
    frame_count="${#frame_files[@]}"
    [ "$frame_count" -ge 1 ] || die "no extracted frames in $bundle; run extract first"
    read -r cols rows < <(awk -v n="$frame_count" \
        'BEGIN { cols = int(sqrt(n)); if (cols * cols < n) cols++; rows = int((n + cols - 1) / cols); print cols, rows }')
    temporary_file="$bundle/.contact-sheet.tmp.$$.png"
    if ! ffmpeg -hide_banner -loglevel error -i "$bundle/frames/f%04d.png" \
        -vf "scale=$review_scale:-1,tile=${cols}x${rows}" \
        "$temporary_file" -y; then
        rm -f "$temporary_file"
        die "failed to build contact sheet"
    fi
    mv "$temporary_file" "$bundle/contact-sheet.png" || die "cannot publish $bundle/contact-sheet.png"
    echo "wrote $bundle/contact-sheet.png (${cols}x${rows})"
}

cmd_diff() {
    local bundle file frame_count diff_count maximum temporary_values temporary_file
    local maximum_index maximum_pts maximum_value
    bundle="$(resolve_bundle "${1:-}")" || return 1
    file="$(media_file "$bundle")" || return 1
    generate_sidecar "$bundle"
    frame_count="$(awk -F, 'END { print $1 + 1 }' "$bundle/frames.csv")"
    [ "$frame_count" -ge 2 ] || die "at least two frames are required for an adjacent-frame diff"
    temporary_values="$bundle/.frames-diff-values.tmp.$$"
    temporary_file="$bundle/.frames-diff.tmp.$$"
    if ! ffmpeg -hide_banner -loglevel error -i "$file" \
        -vf "tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" \
        -f null - 2>/dev/null \
        | awk -F= '$1 == "lavfi.signalstats.YAVG" { print $2 }' > "$temporary_values"; then
        rm -f "$temporary_values"
        die "failed to compare adjacent frames in $file"
    fi
    diff_count="$(wc -l < "$temporary_values")"
    if [ "$diff_count" -ne "$((frame_count - 1))" ]; then
        rm -f "$temporary_values"
        die "computed $diff_count adjacent diffs, expected $((frame_count - 1))"
    fi
    {
        printf '%s\n' "frame_index,pts_time,mean_luma_difference"
        awk -F, '
            NR == FNR { if (FNR > 1) pts[$1] = $2; next }
            { frame_index = FNR; print frame_index "," pts[frame_index] "," $1 }
        ' "$bundle/frames.csv" "$temporary_values"
    } > "$temporary_file"
    rm -f "$temporary_values"
    mv "$temporary_file" "$bundle/frames-diff.csv" || die "cannot publish $bundle/frames-diff.csv"
    maximum="$(awk -F, 'NR == 2 || $3 > max { max = $3; frame = $1; pts = $2 } END { print frame "," pts "," max }' "$bundle/frames-diff.csv")"
    IFS=, read -r maximum_index maximum_pts maximum_value <<< "$maximum"
    printf 'max adjacent diff: frame %s at t %s (%s)\n' "$maximum_index" "$maximum_pts" "$maximum_value"
    echo "wrote $bundle/frames-diff.csv"
}

cmd_status() {
    if [ -s "$active_file" ]; then
        if ! read_active_state; then
            echo "malformed active state: $active_file"
        elif recorder_process_matches "$active_pid" "$active_bundle" "$active_start_ticks"; then
            echo "active capture (pid $active_pid, $(( $(date +%s) - active_started_epoch ))s elapsed): $active_bundle"
        else
            echo "stale active state (pid $active_pid does not match its recorder): $active_file"
        fi
    else
        echo "no active capture"
    fi
    echo
    echo "bundles in $state_root:"
    local candidate latest summary found=0
    for candidate in "$state_root"/*/; do
        [ -d "$candidate" ] || continue
        printf '  %s\n' "$(basename "${candidate%/}")"
        found=1
    done
    [ "$found" -eq 1 ] || echo "  (none)"
    latest="$(latest_bundle 2>/dev/null || true)"
    if [ -n "$latest" ]; then
        echo
        if summary="$(summarize "$latest" 2>/dev/null)"; then
            printf '%s\n' "$summary"
        else
            echo "  $(basename "$latest"): incomplete or unreadable capture"
        fi
    fi
}

case "${1:-}" in
    start) acquire_lock; cmd_start ;;
    stop) acquire_lock; cmd_stop ;;
    toggle) acquire_lock; cmd_toggle ;;
    sidecar) cmd_sidecar "${2:-}" ;;
    review) cmd_review "${2:-}" ;;
    extract) cmd_extract "${@:2}" ;;
    sheet) cmd_sheet "${2:-}" ;;
    diff) cmd_diff "${2:-}" ;;
    status) cmd_status ;;
    -h | --help | help) usage ;;
    *) usage >&2; exit 2 ;;
esac
