# Carbon

Carbon is a stability-focused Hyprland desktop shell built with Quickshell, QML, and Qt. It provides a practical daily desktop environment with sensible defaults, reliable behavior, and an ongoing focus on bug fixes.

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
- `.config/fuzzel/` and `.config/kitty/` - application configs that load generated colors
- `systemd/user/` - portable shell, wallpaper-daemon, and opt-in diagnostic user units
- `requirements.txt` and `packages.arch` - pinned Python and Arch package inputs

## Release and security

The public repository starts with a fresh Git history so discarded private development history cannot be published accidentally. Machine facts belong in ignored `user.env`; runtime and generated state belong outside the checkout.

See [ATTRIBUTION.md](ATTRIBUTION.md) for upstream and third-party provenance. Publishing or pushing is never part of the automated checks in `scripts/check-release.sh`.

## Optional stall diagnostics

The desktop stall recorder is installed in a disabled state and never starts automatically. Start it temporarily when investigating an intermittent desktop problem:

```bash
systemctl --user start carbon-stall-recorder.service
```

It keeps a rolling 15-minute window of samples and writes a capture on its own whenever a probe fails, so a stall is preserved even if nobody is at the keyboard. `Super + \` forces a capture for problems that never trip a probe.

```bash
~/.config/quickshell/Scripts/Diagnostics/stall-recorder.sh capture
~/.config/quickshell/Scripts/Diagnostics/stall-recorder.sh status
systemctl --user stop carbon-stall-recorder.service
```

Samples and captures live in `$XDG_STATE_HOME/carbon/stall-recorder/`. Each capture holds the sample window, a system summary, per-thread state for the shell, and recent journals.

## License

Carbon is distributed under the [GNU General Public License v3.0](LICENSE). Components with additional notices or compatible licenses are listed in [ATTRIBUTION.md](ATTRIBUTION.md) and `LICENSES/`.
