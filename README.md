# Carbon

Carbon is an opinionated Hyprland desktop shell built with Quickshell, QML, and Qt. It combines the compositor configuration and graphical shell needed for a cohesive daily desktop while keeping machine-specific values outside the public repository.

Carbon is an independently maintained fork of [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)'s **illogical-impulse**, originally created from a source snapshot. It does not automatically merge upstream changes; local features and modifications are developed directly in Carbon.

## What it includes

| Area | Features |
| --- | --- |
| Desktop navigation | Live workspace overview, fuzzy launcher, application drawer, dock, minimized-window restore, and cheatsheet |
| Shell surfaces | Configurable bar, system tray, notification popups, sidebars, session menu, screen corners, and on-screen display |
| Controls | Audio mixer, brightness, media, network and Bluetooth toggles, idle inhibition, game mode, screenshots, and recording |
| Personal tools | Calendar, todo list, translator, clipboard history, annotator, on-screen keyboard, and wallpaper-aware theming |
| Configuration | Material Design 3 palette generation, a settings application, safe per-machine monitor overrides, and live Quickshell reloads |

The shell is modular: `shell.qml` loads major surfaces through `LazyLoader`, while reusable state and system integrations live under `.config/quickshell/Services`.

## Supported system

Carbon currently supports **Arch Linux only** and is tested on a Wayland desktop with Hyprland 0.56's Lua configuration API and Arch's stable Quickshell package. Other distributions, compositors, Hyprland's retired hyprlang configuration format, and X11 are unsupported.

This repository configures the desktop session, not the base system. Once Git is installed, setup is:

```bash
git clone https://github.com/iliyaj/carbon.git ~/carbon
cd ~/carbon
./install.sh
```

Hyprland does not include a terminal. If necessary, press `Ctrl+Alt+F2`, log in at the text console, and run those commands there. See the [installation guide](INSTALL.md) for the Git bootstrap and troubleshooting.

## Useful keys

- `Super` - overview/launcher
- `Super+A` - application drawer and left sidebar
- `Super+N` - notifications and right sidebar
- `Super+/` - live keybind cheatsheet
- `Super+M` - media controls
- `Ctrl+Alt+Delete` - session menu

The cheatsheet reads Hyprland's live bind inventory and is the authoritative list after installation.

## Project layout

- `.config/hypr/` - modular Hyprland Lua configuration and safe machine override example
- `.config/quickshell/` - shell, settings app, QML modules, services, scripts, and bundled default wallpaper
- `.config/matugen/` - templates used by Carbon's Material color pipeline
- `systemd/user/` - portable Quickshell and wallpaper-daemon user units
- `requirements.txt` and `packages.arch` - pinned Python and Arch package inputs

## Release and security

The public repository starts with a fresh Git history so discarded private development history cannot be published accidentally. Machine facts belong in ignored `user.env`; runtime and generated state belong outside the checkout.

See [ATTRIBUTION.md](ATTRIBUTION.md) for upstream and third-party provenance. Publishing or pushing is never part of the automated checks in `scripts/check-release.sh`.

## License

Carbon is distributed under the [GNU General Public License v3.0](LICENSE). Components with additional notices or compatible licenses are listed in [ATTRIBUTION.md](ATTRIBUTION.md) and `LICENSES/`.
