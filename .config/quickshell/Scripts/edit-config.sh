#!/usr/bin/env bash
# Opens a file in the user's default text editor.
# Usage: edit-config.sh <file> [terminal command]
# The default handler for text/plain is preferred over the handler for the
# file's own MIME type, since application/json is usually claimed by a browser.

set -euo pipefail

file="${1:?usage: edit-config.sh <file> [terminal]}"
terminal="${2:-}"

# Some config files are optional and may not exist yet, so give the editor something to open
[ -e "$file" ] || : >"$file"

find_desktop_file() {
    local id="$1" dir
    local -a dirs=()
    IFS=':' read -ra dirs <<<"${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for dir in "${dirs[@]}"; do
        [ -n "$dir" ] || continue
        # Desktop IDs may encode subdirectories as dashes, e.g. org.foo-bar.desktop
        if [ -f "$dir/applications/$id" ]; then
            printf '%s\n' "$dir/applications/$id"
            return 0
        fi
        local found
        found="$(find "$dir/applications" -name "$id" -type f -print -quit 2>/dev/null || true)"
        if [ -n "$found" ]; then
            printf '%s\n' "$found"
            return 0
        fi
    done
    return 1
}

desktop_entry_value() {
    # Reads a key from the [Desktop Entry] group only
    awk -v key="$2" '
        /^\[/ { in_main = ($0 == "[Desktop Entry]"); next }
        in_main && index($0, key "=") == 1 { sub("^" key "=", ""); print; exit }
    ' "$1"
}

# Expands an Exec= line into an argv array, substituting the file for field codes
exec_to_argv() {
    local exec_line="$1" file="$2" token substituted=0
    local -a argv=()
    # Word splitting here matches the desktop-entry spec closely enough for editors
    for token in $exec_line; do
        case "$token" in
            %f | %F | %u | %U)
                argv+=("$file")
                substituted=1
                ;;
            %*) ;;
            *) argv+=("$token") ;;
        esac
    done
    [ "$substituted" -eq 1 ] || argv+=("$file")
    printf '%s\0' "${argv[@]}"
}

run_in_terminal() {
    local -a argv=("$@")
    local -a term=()
    if [ -n "$terminal" ]; then
        read -ra term <<<"$terminal"
    else
        local candidate
        for candidate in kitty ghostty foot alacritty wezterm konsole gnome-terminal xterm; do
            if command -v "$candidate" >/dev/null 2>&1; then
                term=("$candidate")
                break
            fi
        done
    fi
    [ "${#term[@]}" -gt 0 ] || return 1
    command -v "${term[0]}" >/dev/null 2>&1 || return 1

    # gnome-terminal and friends take a single string after -e, so their command goes after --
    local separator="-e"
    case "$(basename "${term[0]}")" in
        gnome-terminal | tilix | ptyxis) separator="--" ;;
    esac
    setsid -f "${term[@]}" "$separator" "${argv[@]}" >/dev/null 2>&1 || true
}

launch_default_handler() {
    local id desktop exec_line terminal_flag
    id="$(xdg-mime query default text/plain 2>/dev/null | cut -d';' -f1)"
    [ -n "$id" ] || return 1
    desktop="$(find_desktop_file "$id")" || return 1
    exec_line="$(desktop_entry_value "$desktop" Exec)"
    [ -n "$exec_line" ] || return 1

    local -a argv=()
    mapfile -d '' -t argv < <(exec_to_argv "$exec_line" "$file")
    [ "${#argv[@]}" -gt 0 ] || return 1
    command -v "${argv[0]}" >/dev/null 2>&1 || return 1

    terminal_flag="$(desktop_entry_value "$desktop" Terminal)"
    if [ "${terminal_flag,,}" = "true" ]; then
        run_in_terminal "${argv[@]}" || return 1
    else
        setsid -f "${argv[@]}" >/dev/null 2>&1 || true
    fi
    # The editor is on its way, so never fall through to another launcher
    return 0
}

launch_env_editor() {
    local editor="${VISUAL:-${EDITOR:-}}"
    [ -n "$editor" ] || return 1
    local -a argv=()
    read -ra argv <<<"$editor"
    command -v "${argv[0]}" >/dev/null 2>&1 || return 1
    run_in_terminal "${argv[@]}" "$file" || return 1
    return 0
}

# nano is last because it is the one editor virtually every system ships
launch_known_terminal_editor() {
    local candidate
    for candidate in nvim vim hx helix micro nano vi; do
        if command -v "$candidate" >/dev/null 2>&1; then
            run_in_terminal "$candidate" "$file" && return 0
        fi
    done
    return 1
}

launch_known_gui_editor() {
    local candidate
    for candidate in zed zeditor code codium gnome-text-editor kate gedit mousepad pluma leafpad; do
        if command -v "$candidate" >/dev/null 2>&1; then
            setsid -f "$candidate" "$file" >/dev/null 2>&1 || true
            return 0
        fi
    done
    return 1
}

# Only reached when no editor exists at all, and likely to land in a browser
launch_generic_opener() {
    command -v xdg-open >/dev/null 2>&1 || return 1
    setsid -f xdg-open "$file" >/dev/null 2>&1 || true
    return 0
}

# Anyone who prefers a terminal editor has already been served by the two rungs
# above, so a GUI window is the better guess for whoever is left
launch_default_handler ||
    launch_env_editor ||
    launch_known_gui_editor ||
    launch_known_terminal_editor ||
    launch_generic_opener
