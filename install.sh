#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Carbon contributors

set -euo pipefail

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"

backups=()

info() {
    printf '\n==> %s\n' "$1"
}

die() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

warn() {
    printf 'warning: %s\n' "$1" >&2
}

backup_path() {
    local target="$1"
    local backup="${target}.backup-${BACKUP_STAMP}"
    local suffix=1

    while [[ -e "$backup" || -L "$backup" ]]; do
        backup="${target}.backup-${BACKUP_STAMP}-${suffix}"
        ((suffix += 1))
    done

    printf '%s' "$backup"
}

link_config() {
    local source="$1"
    local target="$2"
    local resolved_source resolved_target backup

    mkdir -p -- "$(dirname -- "$target")"
    resolved_source="$(readlink -f -- "$source")"

    if [[ -L "$target" ]]; then
        resolved_target="$(readlink -f -- "$target" 2>/dev/null || true)"
        if [[ "$resolved_target" == "$resolved_source" ]]; then
            printf '    already linked: %s\n' "$target"
            return
        fi
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        backup="$(backup_path "$target")"
        mv -- "$target" "$backup"
        backups+=("$backup")
        printf '    backed up: %s -> %s\n' "$target" "$backup"
    fi

    ln -s -- "$source" "$target"
    printf '    linked: %s -> %s\n' "$target" "$source"
}

[[ -f /etc/arch-release ]] || die "Carbon currently supports Arch Linux only"
[[ "$(id -u)" -ne 0 ]] || die "run this installer as your normal user, not as root"
command -v sudo >/dev/null || die "sudo is required"
command -v pacman >/dev/null || die "pacman is required"

info "Installing Carbon packages"
mapfile -t packages < <(sed '/^#/d; /^$/d' "$REPO_DIR/packages.arch")
sudo pacman -Syu --needed -- "${packages[@]}"

info "Creating the Python environment"
venv_dir="$STATE_HOME/quickshell/.venv"
uv venv --allow-existing --python 3.12 "$venv_dir"
uv pip install --python "$venv_dir/bin/python" -r "$REPO_DIR/requirements.txt"

info "Installing Hyprbars for this user"
hyprpm_state="$(hyprpm list 2>&1 || true)"
if [[ "$hyprpm_state" == *"Repository hyprland-plugins"* ]]; then
    hyprpm_ready=true
    hyprpm update || hyprpm_ready=false
else
    hyprpm_ready=true
    hyprpm add https://github.com/hyprwm/hyprland-plugins || hyprpm_ready=false
fi

if [[ "$hyprpm_ready" == true ]]; then
    hyprpm enable hyprbars || warn "Hyprbars could not be enabled; Carbon will continue without window title bars"
else
    warn "Hyprbars could not be built; Carbon will continue without window title bars"
fi

info "Linking Carbon configuration"
link_config "$REPO_DIR/.config/hypr" "$CONFIG_HOME/hypr"
link_config "$REPO_DIR/.config/quickshell" "$CONFIG_HOME/quickshell"
link_config "$REPO_DIR/.config/matugen" "$CONFIG_HOME/matugen"
link_config "$REPO_DIR/systemd/user/quickshell.service" "$CONFIG_HOME/systemd/user/quickshell.service"
link_config "$REPO_DIR/systemd/user/awww-daemon.service" "$CONFIG_HOME/systemd/user/awww-daemon.service"

if [[ ! -e "$REPO_DIR/.config/hypr/user.env" ]]; then
    install -m 600 "$REPO_DIR/.config/hypr/user.env.example" "$REPO_DIR/.config/hypr/user.env"
    printf '    created: %s\n' "$REPO_DIR/.config/hypr/user.env"
fi

info "Enabling Carbon services"
systemctl --user daemon-reload
systemctl --user enable awww-daemon.service quickshell.service hypridle.service

if command -v hyprctl >/dev/null && hyprctl monitors >/dev/null 2>&1; then
    systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
    systemctl --user restart awww-daemon.service quickshell.service hypridle.service
    hyprpm reload || warn "Hyprbars could not be loaded"
    hyprctl reload
    info "Carbon is installed and running"
else
    info "Carbon is installed"
    printf 'Start or restart Hyprland to enter Carbon.\n'
fi

if ((${#backups[@]} > 0)); then
    printf '\nExisting configuration was kept at:\n'
    printf '  %s\n' "${backups[@]}"
fi

printf '\nUse Super+Return to open Kitty. Use Super+/ to view all keybinds.\n'
