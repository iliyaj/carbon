#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Carbon contributors

set -euo pipefail

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"
readonly NAGAME_VERSION="0.0.1"
readonly NAGAME_TARGET="x86_64-unknown-linux-gnu"
readonly NAGAME_SHA256="d7eafa35decf572a1cf5af8ef4d24c208549220f3adafc44fad156bcec957791"

backups=()
nagame_tmp_dir=""

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

cleanup_nagame_tmp() {
    [[ -n "$nagame_tmp_dir" ]] || return 0
    case "$nagame_tmp_dir" in
        /tmp/carbon-nagame.*)
            if [[ -d "$nagame_tmp_dir" && ! -L "$nagame_tmp_dir" ]]; then
                find "$nagame_tmp_dir" -mindepth 1 -delete
                rmdir "$nagame_tmp_dir"
            fi
            ;;
        *)
            warn "refusing to remove unexpected temporary path: $nagame_tmp_dir"
            ;;
    esac
    nagame_tmp_dir=""
}

trap cleanup_nagame_tmp EXIT

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

install_nagame() {
    local asset="nagame-v${NAGAME_VERSION}-${NAGAME_TARGET}.tar.gz"
    local release_url="https://github.com/iliyaj/nagame/releases/download/v${NAGAME_VERSION}"
    local archive extracted version_output

    if [[ "$(uname -m)" != "x86_64" ]]; then
        warn "Nagame has no prebuilt binary for $(uname -m); skipping this optional integration"
        return
    fi

    nagame_tmp_dir="$(mktemp -d /tmp/carbon-nagame.XXXXXX)"
    archive="$nagame_tmp_dir/$asset"
    if ! curl --fail --location --retry 3 --show-error --output "$archive" "$release_url/$asset"; then
        warn "Nagame could not be downloaded; Carbon will continue without it"
        cleanup_nagame_tmp
        return
    fi

    if ! printf '%s  %s\n' "$NAGAME_SHA256" "$archive" | sha256sum --check --status; then
        die "Nagame download failed SHA-256 verification"
    fi

    tar -xzf "$archive" -C "$nagame_tmp_dir"
    extracted="$nagame_tmp_dir/nagame-v${NAGAME_VERSION}-${NAGAME_TARGET}"
    [[ -x "$extracted/nagame" ]] || die "Nagame release does not contain an executable binary"
    version_output="$("$extracted/nagame" --version)"
    [[ "$version_output" == "nagame $NAGAME_VERSION" ]] || die "unexpected Nagame version: $version_output"

    sudo install -Dm 0755 "$extracted/nagame" /usr/local/bin/nagame
    sudo install -Dm 0644 "$extracted/config.toml.example" /usr/local/share/nagame/config.toml.example
    sudo install -Dm 0644 "$extracted/nagame.service.example" /usr/local/lib/systemd/user/nagame.service
    sudo install -Dm 0644 "$extracted/README.md" /usr/local/share/doc/nagame/README.md
    sudo install -Dm 0644 "$extracted/INSTRUCTIONS.md" /usr/local/share/doc/nagame/INSTRUCTIONS.md
    sudo install -Dm 0644 "$extracted/LICENSE" /usr/local/share/licenses/nagame/LICENSE
    cleanup_nagame_tmp
    printf '    installed: Nagame %s (service remains disabled until configured)\n' "$NAGAME_VERSION"
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

info "Installing Nagame"
install_nagame

info "Linking Carbon configuration"
link_config "$REPO_DIR/.config/hypr" "$CONFIG_HOME/hypr"
link_config "$REPO_DIR/.config/quickshell" "$CONFIG_HOME/quickshell"
link_config "$REPO_DIR/.config/matugen" "$CONFIG_HOME/matugen"
link_config "$REPO_DIR/.config/fuzzel/fuzzel.ini" "$CONFIG_HOME/fuzzel/fuzzel.ini"
link_config "$REPO_DIR/.config/kitty/kitty.conf" "$CONFIG_HOME/kitty/kitty.conf"
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
    hyprctl reload
    info "Carbon is installed and running"
else
    info "Carbon is installed"
    printf 'Start or restart Hyprland to enter Carbon by typing "start-hyprland".\n'
fi

if ((${#backups[@]} > 0)); then
    printf '\nExisting configuration was kept at:\n'
    printf '  %s\n' "${backups[@]}"
fi

printf '\nUse Super+Return to open Kitty. Use Super+/ to view all keybinds.\n'
printf 'Nagame is installed but disabled; configure it only if you want automatic display profiles.\n'
