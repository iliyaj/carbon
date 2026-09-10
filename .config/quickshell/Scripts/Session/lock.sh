#!/usr/bin/env bash

# Carbon must stop live window captures before hyprlock takes the session lock.
set -u

set_carbon_lock_state() {
    qs ipc call carbon setScreenLocked "$1" >/dev/null 2>&1 || true
}

if pidof hyprlock >/dev/null; then
    set_carbon_lock_state true
    exit 0
fi

set_carbon_lock_state true
trap 'set_carbon_lock_state false' EXIT

state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}"
hyprlock -c "${state_dir}/quickshell/user/generated/hyprlock.conf"
