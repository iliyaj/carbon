#!/usr/bin/env bash
set -u

failures=0

pass() {
    printf 'PASS  %s\n' "$1"
}

fail() {
    printf 'FAIL  %s\n' "$1" >&2
    failures=$((failures + 1))
}

if [ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$(pwd)" ]; then
    pass "running from the Carbon repository root"
else
    fail "run this script from the Carbon repository root"
fi

origin_url="$(git remote get-url origin 2>/dev/null)"
case "$origin_url" in
    git@github.com:iliyaj/carbon.git | https://github.com/iliyaj/carbon.git)
        pass "origin targets iliyaj/carbon"
        ;;
    *)
        fail "origin does not target iliyaj/carbon"
        ;;
esac

if git check-ignore -q .config/hypr/user.env && git check-ignore -q .akira/STATUS.md; then
    pass "machine settings and Akira state are ignored"
else
    fail "expected private/local files are not ignored"
fi

hypr_errors="$(hyprctl configerrors 2>/dev/null)"
if [ "$?" -ne 0 ]; then
    fail "Hyprland is unavailable"
elif [ -n "$hypr_errors" ]; then
    fail "Hyprland reports configuration errors"
else
    pass "Hyprland configuration errors are empty"
fi

if systemctl --user is-active --quiet quickshell.service; then
    pass "quickshell.service is active"
else
    fail "quickshell.service is not active"
fi

if qs ipc call carbon ping >/dev/null 2>&1; then
    pass "Quickshell IPC is responsive"
else
    fail "Quickshell IPC did not respond"
fi

if systemctl --user is-active --quiet awww-daemon.service && awww query >/dev/null 2>&1; then
    pass "awww daemon is active and responsive"
else
    fail "awww daemon is not active and responsive"
fi

if systemctl --user is-active --quiet hypridle.service; then
    pass "hypridle.service is active"
else
    fail "hypridle.service is not active"
fi

if [ "$failures" -eq 0 ]; then
    printf '\nRelease runtime checks passed.\n'
    exit 0
fi

printf '\n%d release runtime check(s) failed.\n' "$failures" >&2
exit 1
