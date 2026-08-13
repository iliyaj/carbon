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

The installer handles packages, the Python environment, configuration links, user services, and safe machine defaults. Existing Hyprland, Quickshell, Matugen, or Carbon service configuration is moved to a timestamped backup instead of being overwritten.

If you installed from a text console, run `start-hyprland` when the installer finishes. Inside Carbon, `Super+Return` opens Kitty and `Super+/` shows the keybinds.

## Optional configuration

Carbon works with the preferred mode of connected displays by default. To set monitor details or wallpaper paths for this machine, edit the ignored file:

```bash
nano ~/.config/hypr/user.env
```

`hypridle.conf` suspends after 30 minutes. Laptop users should review its power policy before relying on it.

The installer registers Hyprland's official plugin repository for the current user, builds Hyprbars, and enables it. Hyprpm plugin state is per user. If the optional build fails, Carbon continues without window title bars; rerun the installer or use:

```bash
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable hyprbars
hyprpm reload
hyprctl reload
```

After Hyprland is upgraded, rebuild the existing plugin for the new compositor version:

```bash
hyprpm update
hyprpm reload
hyprctl reload
```

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

Carbon configures the Hyprland desktop session; it does not install a display manager, graphics drivers, networking, user groups, or a base operating system. KDE/Kvantum color syncing and some hardware or desktop integrations need the optional packages listed in [`packages.arch`](packages.arch).
