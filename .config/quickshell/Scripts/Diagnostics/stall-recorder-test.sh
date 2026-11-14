#!/usr/bin/env bash
#
# Regression checks for stall-recorder classification and diagnostic captures.
#
# A probe client that cannot execute says nothing about desktop health. These
# checks drive the real recorder loop against fake `hyprctl`/`qs` clients and
# assert that only a probe which actually ran counts as a stall.

set -u

recorder="$(cd "$(dirname "$0")" && pwd)/stall-recorder.sh"
work_root="$(mktemp -d)"
trap 'rm -rf "$work_root"' EXIT

failures=0

check() {
    local label="$1" expected="$2" actual="$3"

    if [ "$expected" = "$actual" ]; then
        printf 'ok   %s\n' "$label"
    else
        printf 'FAIL %s: expected <%s>, got <%s>\n' "$label" "$expected" "$actual"
        failures=$((failures + 1))
    fi
}

check_contains() {
    local label="$1" needle="$2" haystack="$3"

    case "$haystack" in
        *"$needle"*) printf 'ok   %s\n' "$label" ;;
        *)
            printf 'FAIL %s: <%s> not found in <%s>\n' "$label" "$needle" "$haystack"
            failures=$((failures + 1))
            ;;
    esac
}

# The recorder spawns bare `hyprctl`, `qs`, and `notify-send` names.
fake_bin="$work_root/bin"
mkdir -p "$fake_bin"

write_client() {
    local name="$1" body="$2"

    printf '#!/usr/bin/env bash\n%s\n' "$body" > "$fake_bin/$name"
    chmod +x "$fake_bin/$name"
}

write_client hyprctl 'exit 0'
write_client notify-send 'printf "%s\n" "$*" >> "${NOTIFY_LOG:-/dev/null}"'
write_client systemctl 'if [[ "$*" == *MainPID* ]]; then printf "%s\n" "$RECORDER_TEST_SHELL_PID"; fi'
write_client perf 'printf "%s\n" "$*" >> "$PERF_LOG"
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) printf "test profile\n" > "$2"; shift 2 ;;
        --) shift; exec "$@" ;;
        *) shift ;;
    esac
done'

run_scenario() {
    local name="$1" seconds="$2"

    scenario_state="$work_root/$name/state"
    mkdir -p "$scenario_state"
    PATH="$fake_bin:$PATH" \
    XDG_STATE_HOME="$scenario_state" \
    NOTIFY_LOG="$work_root/$name.notify" \
    PERF_LOG="$work_root/$name.perf" \
    PROBE_COUNTER="$work_root/$name.probes" \
    RECORDER_TEST_SHELL_PID="$$" \
    STALL_RECORDER_DETAIL_SECONDS="${scenario_details:-0}" \
    STALL_RECORDER_INTERVAL_SECONDS=0.2 \
    STALL_RECORDER_STARTUP_GRACE_SECONDS=0 \
    STALL_RECORDER_AUTO_CAPTURE_GAP=600 \
    STALL_RECORDER_PROBE_TIMEOUT=1 \
        timeout "$seconds" "$recorder" run >/dev/null 2>&1

    scenario_root="$scenario_state/carbon/stall-recorder"
    scenario_samples="$scenario_root/live.tsv"
    scenario_captures="$(ls -1d "$scenario_root"/captures/*/ 2>/dev/null | wc -l)"
}

# Scenario: the shell is healthy.
write_client qs 'exit 0'
run_scenario healthy 3
check "healthy probes do not capture" "0" "$scenario_captures"
check "healthy samples are ok" "ok" \
    "$(awk -F'\t' 'NR>1 { s=$12 } END { print s }' "$scenario_samples")"

# Scenario: the probe client cannot load its libraries (package upgrade window).
write_client qs 'printf "%s\n" "qs: error while loading shared libraries: libQt6Qml.so.6: cannot open shared object file" >&2; exit 127'
run_scenario unavailable 5
check "unavailable probes do not capture" "0" "$scenario_captures"
check "unavailable probes are recorded" "unavailable" \
    "$(awk -F'\t' 'NR>1 { s=$12 } END { print s }' "$scenario_samples")"
check "unavailable probes do not accumulate stall time" "0.0" \
    "$(awk -F'\t' 'NR>1 { s=$14 } END { print s }' "$scenario_samples")"
check_contains "unavailable probes keep the client error" "cannot open shared object file" \
    "$(awk -F'\t' 'NR>1 { s=$21 } END { print s }' "$scenario_samples")"

# Scenario: the shell is gone (client ran, exited non-zero).
write_client qs 'printf "%s\n" "No running instances for \"/home/max/.config/quickshell/shell.qml\"" >&2; exit 255'
run_scenario error 5
check "failing probes capture" "1" "$scenario_captures"
check "failing probes are errors" "error" \
    "$(awk -F'\t' 'NR>1 { s=$12 } END { print s }' "$scenario_samples")"
check_contains "failing probes record the client error" "No running instances" \
    "$(awk -F'\t' 'NR>1 { s=$21 } END { print s }' "$scenario_samples")"
check "a failing probe accumulates stall time" "1" \
    "$(awk -F'\t' 'NR>1 { if ($14 + 0 > 0) n++ } END { print (n > 0 ? 1 : 0) }' "$scenario_samples")"

# Scenario: the shell never answers.
write_client qs 'sleep 5'
run_scenario timeout 5
check "unresponsive shells capture" "1" "$scenario_captures"
check "unresponsive shells are timeouts" "timeout" \
    "$(awk -F'\t' 'NR>1 { s=$12 } END { print s }' "$scenario_samples")"

# A first timeout must start profiling while the main loop continues to recovery.
write_client qs 'if [ "${1:-}" = log ]; then printf "test quickshell log\n"; exit 0; fi
count=$(cat "$PROBE_COUNTER" 2>/dev/null || printf 0)
printf "%s\n" "$((count + 1))" > "$PROBE_COUNTER"
if [ "$count" -eq 0 ]; then sleep 3; fi'
scenario_details=2
run_scenario recovery 6
capture_dir="$(find "$scenario_root/captures" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
check "a recovered stall captures once" "1" "$scenario_captures"
check "the selected shell pid reaches perf" "1" \
    "$(awk -v pid="$$" '$0 ~ "-p " pid "(,| |$)" { found=1 } END { print found+0 }' "$work_root/recovery.perf")"
check_contains "profiles request permitted user callchains" "--user-callchains" "$(cat "$work_root/recovery.perf")"
check_contains "profiles retain their completion status" "perf exit status: 0" "$(cat "$capture_dir/perf.log")"
check "thread timeline records the selected process" "1" \
    "$(awk -v pid="$$" '$1 == pid { found=1 } END { print found+0 }' "$capture_dir/threads.txt")"
check "initial samples retain the failure" "1" \
    "$(awk -F'\t' '$12 == "timeout" { found=1 } END { print found+0 }' "$capture_dir/samples.tsv")"
check "sampling continues through recovery" "ok" \
    "$(awk -F'\t' 'NR>1 { s=$12 } END { print s }' "$capture_dir/samples-after.tsv")"
check "completed captures have a marker" "1" "$(test -s "$capture_dir/complete.txt" && printf 1 || printf 0)"
check "captures have private directory permissions" "700" "$(stat -c %a "$capture_dir")"

# A profiler permission failure must leave an explicit reason and a usable capture.
write_client perf 'printf "profiling denied by kernel permissions\n" >&2; exit 1'
scenario_details=1
run_scenario denied 5
capture_dir="$(find "$scenario_root/captures" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
check_contains "profiling failures keep their reason" "profiling denied" "$(cat "$capture_dir/perf.log")"
check_contains "profiling failures keep their exit status" "perf exit status: 1" "$(cat "$capture_dir/perf.log")"
check "profiling failure still completes the capture" "1" "$(test -s "$capture_dir/complete.txt" && printf 1 || printf 0)"

# Concurrent manual captures need separate directories and one diagnostic worker.
manual_state="$work_root/manual/state"
mkdir -p "$manual_state"
run_manual() {
    PATH="$fake_bin:$PATH" XDG_STATE_HOME="$manual_state" \
    RECORDER_TEST_SHELL_PID="$$" STALL_RECORDER_DETAIL_SECONDS=2 \
    NOTIFY_LOG="$work_root/manual.notify" PERF_LOG="$work_root/manual.perf" \
        "$recorder" capture
}
run_manual > "$work_root/first-capture" &
first_capture_pid=$!
for ((attempt = 0; attempt < 60; attempt++)); do
    first_capture="$(head -n 1 "$work_root/first-capture")"
    [ ! -f "$first_capture/threads.txt" ] || break
    sleep 0.05
done
run_manual > "$work_root/second-capture"
wait "$first_capture_pid"
second_capture="$(head -n 1 "$work_root/second-capture")"
check "concurrent captures use separate directories" "1" "$(test "$first_capture" != "$second_capture" && printf 1 || printf 0)"
check_contains "concurrent capture explains skipped sampling" "already collecting" "$(cat "$second_capture/perf.log")"
check "the first concurrent capture finishes" "1" "$(test -s "$first_capture/complete.txt" && printf 1 || printf 0)"
check "the second concurrent capture finishes" "1" "$(test -s "$second_capture/complete.txt" && printf 1 || printf 0)"

if [ "$failures" -ne 0 ]; then
    printf '\n%d check(s) failed\n' "$failures"
    exit 1
fi
printf '\nall checks passed\n'
