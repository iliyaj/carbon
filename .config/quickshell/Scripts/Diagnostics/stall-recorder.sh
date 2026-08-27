#!/usr/bin/env bash

set -u

state_root="${XDG_STATE_HOME:-$HOME/.local/state}/carbon/stall-recorder"
live_log="$state_root/live.tsv"
interval_seconds="${STALL_RECORDER_INTERVAL_SECONDS:-2}"
max_samples="${STALL_RECORDER_MAX_SAMPLES:-450}"
probe_timeout="${STALL_RECORDER_PROBE_TIMEOUT:-1}"
max_blocked_listed="${STALL_RECORDER_MAX_BLOCKED_LISTED:-6}"
max_captures="${STALL_RECORDER_MAX_CAPTURES:-40}"
auto_capture_gap="${STALL_RECORDER_AUTO_CAPTURE_GAP:-60}"
auto_capture="${STALL_RECORDER_AUTO_CAPTURE:-1}"

clock_ticks="$(getconf CLK_TCK)"
page_kib=$(( $(getconf PAGESIZE) / 1024 ))
whole_disk_pattern='^(nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+|mmcblk[0-9]+)$'

header_line=$'timestamp\tload1\tmem_available_kib\tcpu_some10\tmemory_some10\tdisk_inflight\tdisk_io_ms\tblocked_count\tblocked_tasks\thypr_state\thypr_ms\tcarbon_state\tcarbon_ms\tcarbon_stall_s\tqs_cpu_pct\tqs_rss_mib\tqs_main_state\tqs_main_wchan\tqs_blocked_threads'

usage() {
    cat <<'EOF'
Usage: stall-recorder.sh [run|capture|status]

  run      Continuously retain the latest 15 minutes of lightweight samples
  capture  Preserve the rolling samples and metrics after a stall
  status   Show the recorder service state and most recent sample

A capture is also taken automatically whenever a probe fails.
EOF
}

pressure_value() {
    local file="$1"
    local kind="$2"

    awk -v kind="$kind" '
        $1 == kind {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^avg10=/) {
                    sub(/^avg10=/, "", $i)
                    print $i
                    exit
                }
            }
        }
    ' "$file"
}

disk_totals() {
    awk -v pattern="$whole_disk_pattern" '
        $3 ~ pattern {
            inflight += $12
            io_ms += $13
        }
        END { printf "%d\t%d\n", inflight + 0, io_ms + 0 }
    ' /proc/diskstats
}

blocked_tasks() {
    ps -eLo stat=,wchan:24=,comm= | awk -v limit="$max_blocked_listed" '
        $1 ~ /^D/ {
            count++
            if (count <= limit) {
                names = names (names == "" ? "" : ",") $3 ":" $2
            }
        }
        END {
            if (count > limit) {
                names = names ",+" (count - limit) " more"
            }
            printf "%d\t%s\n", count + 0, (names == "" ? "-" : names)
        }
    '
}

shell_pid() {
    pgrep -x quickshell | head -n 1
}

shell_blocked_threads() {
    local pid="$1"

    awk '
        {
            rest = substr($0, index($0, ") ") + 2)
            split(rest, fields, " ")
            if (fields[1] ~ /^D/) { count++ }
        }
        END { print count + 0 }
    ' /proc/"$pid"/task/*/stat 2>/dev/null || printf '0\n'
}

probe() {
    local started finished result

    started="$(date +%s%3N)"
    if timeout "$probe_timeout" "$@" >/dev/null 2>&1; then
        result="ok"
    elif [ "$?" -eq 124 ]; then
        result="timeout"
    else
        result="error"
    fi
    finished="$(date +%s%3N)"
    printf '%s %d\n' "$result" "$((finished - started))"
}

write_header() {
    printf '%s\n' "$header_line" > "$live_log"
}

write_gap_marker() {
    local last_epoch now_epoch

    [ -s "$live_log" ] || return 0
    last_epoch="$(tail -n 1 "$live_log" | cut -f1)"
    last_epoch="$(date -d "$last_epoch" +%s 2>/dev/null)" || return 0
    now_epoch="$(date +%s)"
    if [ "$((now_epoch - last_epoch))" -le "$((interval_seconds * 2))" ]; then
        return 0
    fi

    printf '%s\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\trecorder-gap\t%d\t-\t-\t-\t-\t-\t-\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')" "$(( (now_epoch - last_epoch) * 1000 ))" >> "$live_log"
}

trim_log() {
    local temporary_log="$state_root/live.tsv.tmp.$$"

    {
        head -n 1 "$live_log"
        tail -n +2 "$live_log" | tail -n "$max_samples"
    } > "$temporary_log"
    mv "$temporary_log" "$live_log"
}

prune_captures() {
    local surplus

    surplus="$(ls -1d "$state_root"/captures/*/ 2>/dev/null | sort | head -n -"$max_captures")"
    [ -n "$surplus" ] || return 0
    printf '%s\n' "$surplus" | while read -r stale; do
        rm -rf "$stale"
    done
}

run_recorder() {
    local sample_number=0
    local timestamp load1 mem_available cpu_some memory_some
    local disk_inflight disk_io_ms disk_io_ms_previous=0 disk_io_delta
    local blocked_count blocked_names hypr_state hypr_ms carbon_state carbon_ms
    local stall_started_ms=0 carbon_stall_s
    local qs_pid="" qs_state qs_wchan qs_cpu qs_rss qs_blocked
    local qs_ticks_previous=0 qs_epoch_previous=0
    local now_ms last_capture_ms=0

    mkdir -p "$state_root"
    exec 9> "$state_root/recorder.lock"
    if ! flock -n 9; then
        printf 'The stall recorder is already running.\n' >&2
        exit 1
    fi

    if [ ! -s "$live_log" ] || [ "$(head -n 1 "$live_log")" != "$header_line" ]; then
        write_header
    else
        write_gap_marker
    fi

    IFS=$'\t' read -r _ disk_io_ms_previous < <(disk_totals)

    while true; do
        timestamp="$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')"
        now_ms="$(date +%s%3N)"
        read -r load1 _ < /proc/loadavg
        mem_available="$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)"
        cpu_some="$(pressure_value /proc/pressure/cpu some)"
        memory_some="$(pressure_value /proc/pressure/memory some)"

        IFS=$'\t' read -r disk_inflight disk_io_ms < <(disk_totals)
        disk_io_delta=$((disk_io_ms - disk_io_ms_previous))
        [ "$disk_io_delta" -ge 0 ] || disk_io_delta=0
        disk_io_ms_previous="$disk_io_ms"

        IFS=$'\t' read -r blocked_count blocked_names < <(blocked_tasks)

        qs_state="-"
        qs_wchan="-"
        qs_cpu="-"
        qs_rss="-"
        qs_blocked="-"
        if [ -z "$qs_pid" ] || [ ! -d "/proc/$qs_pid" ]; then
            qs_pid="$(shell_pid)"
            qs_ticks_previous=0
        fi
        if [ -n "$qs_pid" ] && [ -d "/proc/$qs_pid" ]; then
            local stat_raw stat_rest stat_fields ticks_now
            if stat_raw="$(cat "/proc/$qs_pid/stat" 2>/dev/null)"; then
                stat_rest="${stat_raw##*') '}"
                read -ra stat_fields <<< "$stat_rest"
                qs_state="${stat_fields[0]}"
                ticks_now=$(( ${stat_fields[11]} + ${stat_fields[12]} ))
                qs_rss=$(( ${stat_fields[21]} * page_kib / 1024 ))
                if [ "$qs_ticks_previous" -gt 0 ] && [ "$now_ms" -gt "$qs_epoch_previous" ]; then
                    qs_cpu="$(awk -v d="$((ticks_now - qs_ticks_previous))" -v ms="$((now_ms - qs_epoch_previous))" \
                        -v hz="$clock_ticks" 'BEGIN { printf "%.1f", d / hz * 100000 / ms }')"
                fi
                qs_ticks_previous="$ticks_now"
                qs_epoch_previous="$now_ms"
                qs_wchan="$(cat "/proc/$qs_pid/wchan" 2>/dev/null)"
                case "$qs_wchan" in
                    "" ) qs_wchan="-" ;;
                    0 ) qs_wchan="running" ;;
                esac
                qs_blocked="$(shell_blocked_threads "$qs_pid")"
            fi
        fi

        read -r hypr_state hypr_ms < <(probe hyprctl activeworkspace)
        read -r carbon_state carbon_ms < <(probe qs ipc call carbon ping)

        if [ "$carbon_state" = "ok" ] && [ "$hypr_state" = "ok" ]; then
            stall_started_ms=0
            carbon_stall_s="0.0"
        else
            [ "$stall_started_ms" -ne 0 ] || stall_started_ms="$now_ms"
            carbon_stall_s="$(awk -v ms="$(( $(date +%s%3N) - stall_started_ms ))" \
                'BEGIN { printf "%.1f", ms / 1000 }')"
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$timestamp" "$load1" "$mem_available" "$cpu_some" "$memory_some" \
            "$disk_inflight" "$disk_io_delta" "$blocked_count" "$blocked_names" \
            "$hypr_state" "$hypr_ms" "$carbon_state" "$carbon_ms" "$carbon_stall_s" \
            "$qs_cpu" "$qs_rss" "$qs_state" "$qs_wchan" "$qs_blocked" >> "$live_log"

        if [ "$auto_capture" = "1" ] && { [ "$carbon_state" != "ok" ] || [ "$hypr_state" != "ok" ]; } &&
            [ "$((now_ms - last_capture_ms))" -ge "$((auto_capture_gap * 1000))" ]; then
            last_capture_ms="$now_ms"
            capture_state "auto: $hypr_state/$carbon_state" >/dev/null 2>&1 &
        fi

        sample_number=$((sample_number + 1))
        if [ "$sample_number" -ge 30 ]; then
            trim_log
            sample_number=0
        fi
        sleep "$interval_seconds"
    done
}

capture_state() {
    local reason="${1:-manual}"
    local captured_at capture_dir qs_pid

    mkdir -p "$state_root/captures"
    captured_at="$(date +%Y%m%d-%H%M%S)"
    capture_dir="$state_root/captures/$captured_at"
    mkdir -p "$capture_dir"
    qs_pid="$(shell_pid)"

    if [ -f "$live_log" ]; then
        cp "$live_log" "$capture_dir/samples.tsv"
    fi

    {
        date --iso-8601=seconds
        printf 'Trigger: %s\n' "$reason"
        uptime
        free -h
        printf '\nPressure:\n'
        for pressure_file in /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io; do
            printf '%s\n' "$pressure_file"
            cat "$pressure_file"
        done
        printf '\nBlocked tasks:\n'
        ps -eLo pid=,stat=,wchan:24=,comm= | awk '$2 ~ /^D/'
        printf '\nQuickshell threads (pid %s):\n' "${qs_pid:-none}"
        if [ -n "$qs_pid" ]; then
            for task in /proc/"$qs_pid"/task/*; do
                [ -d "$task" ] || continue
                printf '%-8s %-6s %-20s %s\n' \
                    "$(basename "$task")" \
                    "$(awk '{ rest = substr($0, index($0, ") ") + 2); split(rest, f, " "); print f[1] }' "$task/stat" 2>/dev/null)" \
                    "$(cat "$task/comm" 2>/dev/null)" \
                    "$(cat "$task/wchan" 2>/dev/null)"
            done
        fi
        printf '\nDisk:\n'
        awk -v pattern="$whole_disk_pattern" '$3 ~ pattern' /proc/diskstats
        printf '\nFailed system services:\n'
        systemctl list-units --state=failed --no-pager --no-legend
        printf '\nFailed user services:\n'
        systemctl --user list-units --state=failed --no-pager --no-legend
        printf '\nBtrfs device errors:\n'
        btrfs device stats / 2>&1
    } > "$capture_dir/summary.txt" 2>&1

    journalctl --user --since "-15 minutes" --no-pager > "$capture_dir/journal-user.txt" 2>&1
    journalctl -k --since "-15 minutes" --no-pager > "$capture_dir/journal-kernel.txt" 2>&1

    prune_captures

    printf '%s\n' "$capture_dir"
    if command -v notify-send >/dev/null; then
        notify-send 'Desktop stall captured' "$capture_dir"
    fi
}

show_status() {
    systemctl --user status carbon-stall-recorder.service --no-pager || true
    if [ -f "$live_log" ]; then
        printf '\nMost recent sample:\n'
        head -n 1 "$live_log"
        tail -n 1 "$live_log"
    fi
}

case "${1:-run}" in
    run)
        run_recorder
        ;;
    capture)
        capture_state "manual"
        ;;
    status)
        show_status
        ;;
    -h | --help | help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
