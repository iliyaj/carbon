#!/usr/bin/env bash

set -u

state_root="${XDG_STATE_HOME:-$HOME/.local/state}/carbon/stall-recorder"
marker_log="$state_root/stress.tsv"
live_log="$state_root/live.tsv"
duration="${STRESS_DURATION:-20}"
window_count="${STRESS_WINDOW_COUNT:-8}"
settle_seconds="${STRESS_SETTLE:-8}"
notification_limit="${STRESS_NOTIFICATION_LIMIT:-150}"

scenarios="ipc windows workspaces notifications clipboard brightness search media"

usage() {
    cat <<'EOF'
Usage: stress-shell.sh <scenario|all|report|clean>

Scenarios, each targeting one suspected main-thread blocker:

  ipc            Hammer panel open/close over IPC
  windows        Rapid window churn, exercising per-window icon guessing
  workspaces     Rapid workspace switching
  notifications  Notification flood
  clipboard      Clipboard history flood
  brightness     Repeated brightness steps, exercising ddcutil over i2c
  search         Type into the launcher, exercising fuzzy scoring
  media          MPRIS play/pause churn

  all            Run every scenario in turn, settling between each
  report         Join the marker log against the recorder samples
  clean          Remove the marker log

The stall recorder must be running; every scenario is bracketed with a marker
so that report can attribute a stall to whatever was running at the time.
EOF
}

require_recorder() {
    if ! systemctl --user is-active --quiet carbon-stall-recorder.service; then
        printf 'The stall recorder is not running; start it first.\n' >&2
        exit 1
    fi
}

mark() {
    local phase="$1"
    local scenario="$2"

    mkdir -p "$state_root"
    if [ ! -s "$marker_log" ]; then
        printf 'timestamp\tphase\tscenario\n' > "$marker_log"
    fi
    printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')" "$phase" "$scenario" >> "$marker_log"
}

deadline() {
    printf '%s\n' "$(( $(date +%s) + duration ))"
}

scenario_ipc() {
    local ends
    ends="$(deadline)"
    while [ "$(date +%s)" -lt "$ends" ]; do
        for target in sidebarRight sidebarLeft overview mediaControls cheatsheet; do
            qs ipc call "$target" toggle >/dev/null 2>&1
        done
    done
    for target in sidebarRight sidebarLeft overview mediaControls cheatsheet; do
        qs ipc call "$target" close >/dev/null 2>&1
    done
}

scenario_windows() {
    local ends index pids=()
    ends="$(deadline)"
    while [ "$(date +%s)" -lt "$ends" ]; do
        pids=()
        for index in $(seq 1 "$window_count"); do
            kitty --class "carbon-stress-$index" sh -c 'sleep 600' >/dev/null 2>&1 &
            pids+=("$!")
        done
        sleep 3
        for pid in "${pids[@]}"; do
            kill "$pid" 2>/dev/null
        done
        sleep 1
    done
    pkill -f 'class carbon-stress' 2>/dev/null
}

scenario_workspaces() {
    local ends index
    ends="$(deadline)"
    while [ "$(date +%s)" -lt "$ends" ]; do
        for index in 1 2 3 4 5 6 7 8 9 10; do
            hyprctl dispatch workspace "$index" >/dev/null 2>&1
        done
    done
    hyprctl dispatch workspace 1 >/dev/null 2>&1
}

scenario_notifications() {
    local ends index=0
    ends="$(deadline)"
    while [ "$(date +%s)" -lt "$ends" ] && [ "$index" -lt "$notification_limit" ]; do
        index=$((index + 1))
        notify-send "Carbon stress $index" "Payload $(head -c 200 /dev/urandom | base64 | tr -d '\n')"
        sleep 0.05
    done
    printf 'Sent %d notifications; the shell retention cap prunes the backlog.\n' "$index"
}

scenario_clipboard() {
    local ends index=0
    ends="$(deadline)"
    while [ "$(date +%s)" -lt "$ends" ]; do
        index=$((index + 1))
        printf 'carbon stress clipboard entry %d %s\n' \
            "$index" "$(head -c 400 /dev/urandom | base64 | tr -d '\n')" | wl-copy
    done
}

scenario_brightness() {
    local ends
    ends="$(deadline)"
    while [ "$(date +%s)" -lt "$ends" ]; do
        qs ipc call brightness increment >/dev/null 2>&1
        qs ipc call brightness decrement >/dev/null 2>&1
    done
}

scenario_search() {
    local ends word
    if ! command -v wtype >/dev/null; then
        printf 'wtype is missing; skipping the search scenario.\n' >&2
        return 0
    fi
    ends="$(deadline)"
    while [ "$(date +%s)" -lt "$ends" ]; do
        qs ipc call overview open >/dev/null 2>&1
        sleep 0.4
        for word in fire term set code brow edit calc musi vide phot; do
            wtype "$word" 2>/dev/null
            sleep 0.15
            wtype -k BackSpace -k BackSpace -k BackSpace -k BackSpace 2>/dev/null
        done
        qs ipc call overview close >/dev/null 2>&1
        sleep 0.3
    done
    qs ipc call overview close >/dev/null 2>&1
}

scenario_media() {
    local ends
    ends="$(deadline)"
    while [ "$(date +%s)" -lt "$ends" ]; do
        qs ipc call mpris playPause >/dev/null 2>&1
        sleep 0.2
    done
}

run_scenario() {
    local scenario="$1"

    if ! printf '%s\n' $scenarios | grep -qx "$scenario"; then
        printf 'Unknown scenario: %s\n' "$scenario" >&2
        exit 2
    fi

    printf 'Running %s for %ss...\n' "$scenario" "$duration"
    mark start "$scenario"
    "scenario_$scenario"
    mark end "$scenario"
    printf 'Settling for %ss...\n' "$settle_seconds"
    sleep "$settle_seconds"
}

run_all() {
    local scenario
    for scenario in $scenarios; do
        run_scenario "$scenario"
    done
    printf '\n'
    report
}

report() {
    if [ ! -s "$marker_log" ] || [ ! -s "$live_log" ]; then
        printf 'Nothing to report; run a scenario while the recorder is active.\n' >&2
        exit 1
    fi

    awk -F'\t' '
        function epoch(stamp,   command, result) {
            command = "date -d \"" stamp "\" +%s%3N"
            command | getline result
            close(command)
            return result + 0
        }
        FILENAME == markers && FNR > 1 {
            if ($2 == "start") { start[$3] = epoch($1) }
            if ($2 == "end") { finish[$3] = epoch($1) }
            next
        }
        FNR == 1 { next }
        {
            sample = epoch($1)
            for (scenario in start) {
                if (sample >= start[scenario] && sample <= finish[scenario]) {
                    count[scenario]++
                    if ($13 + 0 > worst[scenario]) { worst[scenario] = $13 + 0 }
                    if ($12 != "ok") { bad[scenario]++ }
                    cpu[scenario] += $15 + 0
                    if ($16 + 0 > rss[scenario]) { rss[scenario] = $16 + 0 }
                }
            }
        }
        END {
            printf "%-15s %7s %7s %10s %9s %9s\n", "scenario", "samples", "failed", "worst_ms", "avg_cpu", "peak_rss"
            for (scenario in start) {
                if (count[scenario] == 0) { continue }
                printf "%-15s %7d %7d %10d %8.1f%% %7dM\n", scenario, count[scenario], bad[scenario] + 0, \
                    worst[scenario], cpu[scenario] / count[scenario], rss[scenario]
            }
        }
    ' markers="$marker_log" "$marker_log" "$live_log" | { read -r header; printf '%s\n' "$header"; sort -k4 -rn; }
}

case "${1:-}" in
    all)
        require_recorder
        run_all
        ;;
    report)
        report
        ;;
    clean)
        rm -f "$marker_log"
        ;;
    "" | -h | --help | help)
        usage
        ;;
    *)
        require_recorder
        run_scenario "$1"
        printf '\n'
        report
        ;;
esac
