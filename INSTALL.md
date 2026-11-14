# Installing Carbon

Carbon supports Arch Linux. Start with a working network connection and a normal user that can run `sudo`.

Hyprland does not include a terminal emulator. If you are already inside Hyprland without a terminal, press `Ctrl+Alt+F2` and log in at the text console. Carbon installs Kitty for future sessions.

## Install

The Archfit sidebar tab uses the QML module maintained in a separate `archfit-rust` checkout. Keep that checkout beside Carbon, with `../archfit-rust/quickshell/Archfit` available before running the installer. Carbon tracks a relative link to that module; Archfit owns its frontend source and backend service installation.

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

### Automatic note titles and tags

Notes save immediately and show a compact title, with the most recently updated files first. Click anywhere on a card to select it; only the chevron expands its text. The sparkle button regenerates the selected note's title and tags while retaining existing labels. Each card also has Copy, Open in default app, and Delete actions. To generate English titles and topic tags with OpenRouter, install Node.js 22.18 or newer (`sudo pacman -S --needed nodejs`), then create a private configuration file:

```bash
install -d -m 700 ~/.config/carbon
(umask 077; touch ~/.config/carbon/openrouter.json)
chmod 600 ~/.config/carbon/openrouter.json
nano ~/.config/carbon/openrouter.json
```

```json
{
  "apiKey": "your OpenRouter API key",
  "model": "google/gemini-2.5-flash-lite"
}
```

Each new note sends up to its first 12,000 characters to OpenRouter for two parallel requests: the configured model writes an English title, and `typesafe/jev-1.14` selects up to three topic tags. Tags are saved as an Obsidian-compatible YAML list. The shared topics are `ai`, `programming`, `zig`, `data`, `start_up`, `linux`, `video`, `blockchain`, `cryptography`, and `creativity`; notes without a clear match can have no tags.

The key stays in this local file; do not put it in Carbon's repository. Changes apply to the next saved note without restarting. Existing notes are not sent or rewritten automatically. Without a key or Node.js, notes keep a short title from their first line. Each request times out after 20 seconds; a successful title or tag result still saves if the other request fails. Copy always copies the note body.

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
