# Installing Carbon

Carbon supports Arch Linux. Start with a working network connection and a normal user that can run `sudo`.

Hyprland does not include a terminal emulator. If you are already inside Hyprland without a terminal, press `Ctrl+Alt+F2` and log in at the text console. Carbon installs Kitty for future sessions.

## Install

Git is the only tool needed before cloning. A minimal Arch installation can install it with:

```bash
sudo pacman -Syu --needed git
```

Then clone Carbon and run its installer:

```bash
git clone https://github.com/iliyaj/carbon.git ~/carbon
cd ~/carbon
./install.sh
```

The installer handles packages, the Python environment, configuration links, user services, safe machine defaults, and a checksum-verified Nagame binary. Existing Hyprland, Quickshell, Matugen, or Carbon service configuration is moved to a timestamped backup instead of being overwritten.

If you installed from a text console, run `start-hyprland` when the installer finishes. Inside Carbon, `Super+Return` opens Kitty and `Super+/` shows the keybinds.

## Optional configuration

Carbon works with the preferred mode of connected displays by default. To set monitor details or wallpaper paths for this machine, edit the ignored file:

```bash
nano ~/.config/hypr/user.env
```

`hypridle.conf` suspends after 30 minutes. Laptop users should review its power policy before relying on it.

### Nagame display profiles

The installer downloads the pinned Linux x86_64 binary from [Nagame's GitHub release](https://github.com/iliyaj/nagame/releases/tag/v0.0.3), verifies its SHA-256, and installs its example files. Nagame remains inactive until it has a profile for this machine.

To use it without a terminal, open **Carbon Settings → Display** and choose **Set up Nagame**. Nagame captures the connected displays and their current modes, position, scale, orientation, and adaptive-sync state into a private initial profile, validates it, and starts the service. Carbon starts configured Nagame automatically in later sessions.

Advanced users can still create named docked layouts, wallpapers, and activation commands manually. The installed example contains placeholders and is never copied over user configuration automatically. See [Nagame's instructions](https://github.com/iliyaj/nagame/blob/v0.0.3/INSTRUCTIONS.md) for the profile format.

## Verify or troubleshoot

Run the built-in checks after starting Carbon:

```bash
cd ~/carbon
./scripts/check-release.sh
```

If Quickshell fails, inspect it with:

```bash
journalctl --user -u quickshell.service -b --no-pager
```

Carbon configures the Hyprland desktop session; it does not install a display manager, graphics drivers, networking, user groups, or a base operating system. Some hardware and desktop integrations need the optional packages listed in [`packages.arch`](packages.arch).
