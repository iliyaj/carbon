# Carbon

Carbon is a stability-focused Hyprland desktop shell built with Quickshell, QML, and Qt. It provides a practical daily desktop environment with sensible defaults, reliable behavior, and an ongoing focus on bug fixes.

Carbon started as a fork of [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)'s **illogical-impulse**, created from a source snapshot, and is now maintained independently. It does not automatically merge upstream changes; local features and modifications are developed directly in Carbon.

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

Carbon currently supports **Arch Linux only** (by the way...) and is tested on a Wayland desktop with Hyprland 0.56's Lua configuration API and Arch's stable Quickshell package. Other distributions, compositors, Hyprland's retired hyprlang configuration format, and X11 are unsupported.

I develop and daily-drive Carbon on one machine: an x86 Intel Raptor Lake CPU with an integrated GPU and a beefy amount of RAM. It runs buttery smooth on my machine, but that might just mean that I tuned it to this hardware and my display. You could hit bugs I never see. I plan to test on AMD and Nvidia graphics and in a VM, but I haven't yet.

If you find it too buggy, I suggest using a more stable distro for daily driving. Ubuntu is great, but if you have a potato, MX Linux (xfce) is awesome for older hardware.

This project is very much experimental. I was thinking of calling it xCarbon but it might be copyrighted.

> [!WARNING]
> If you do like running experimental software then follow the steps below:

Install arch, then log in at the console. A minimal install is fine - Carbon installs hyprland, quickshell, kitty and the rest for you. You need a working network connection, since the installer pulls packages the whole way through. Run it as your normal user, not root.

Git is the only thing you need first:

```bash
sudo pacman -Syu --needed git
```

Then the setup is:

```bash
git clone https://github.com/iliyaj/carbon.git ~/carbon
cd ~/carbon
./install.sh
```

When it finishes, run `start-hyprland`. `Super+Return` opens a terminal, `Super+/` shows the keybinds.

If you're already in Hyprland with no terminal, press `Ctrl+Alt+F2` and log in there. Hyprland does not include a terminal.

See the [installation guide](INSTALL.md) for the Git bootstrap and troubleshooting.

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

## Releases

No releases yet. `main` is the project. If people show up wanting something stable to track, I'll start tagging.

`scripts/check-release.sh` only checks the repo. It never publishes or pushes anything.

## Security

Found a security issue? Tell me privately first, through [GitHub's private vulnerability reporting](https://github.com/iliyaj/carbon/security/advisories/new), not a public issue. Give me a chance to patch it before it's out there.

Anything specific to your machine goes in `user.env`, which is gitignored. Runtime and generated state stays out of the checkout.

## Attribution

Carbon is a fork, and it bundles other people's code. [ATTRIBUTION.md](ATTRIBUTION.md) says what came from where, and `LICENSES/` has the license texts.

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
