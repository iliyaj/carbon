-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

-- Keybinds. Was hyprland/keybinds.conf + custom/keybinds.conf.

local lib = require("lib")
local home = lib.home

local qs_alive = "qs ipc call carbon ping"
local theme_tool = home .. "/.config/quickshell/Scripts/Colors/theme.py"

local terminal = lib.first_installed({
    "kitty -1", "foot", "alacritty", "wezterm", "konsole", "kgx", "uxterm", "xterm",
})
local terminal_editor = terminal and lib.in_path("nvim") and terminal .. " nvim" or nil
local file_manager = lib.first_installed({
    "dolphin", "nautilus", "nemo", "thunar", { bin = "yazi", cmd = "kitty -1 fish -c yazi" },
})
local code_editor = lib.first_installed({
    "code", "codium", "zed", "kate", "gnome-text-editor", "emacs",
}) or terminal_editor
local text_editor = lib.first_installed({ "kate", "gnome-text-editor", "emacs" }) or terminal_editor
local volume_mixer = lib.first_installed({ "pavucontrol-qt", "pavucontrol" })
local settings_app = lib.first_installed({
    { bin = "qs", cmd = "qs -p " .. home .. "/.config/quickshell/settings.qml" },
    "systemsettings", "gnome-control-center", "better-control",
})
if settings_app then settings_app = "XDG_CURRENT_DESKTOP=gnome " .. settings_app end
local task_manager = lib.first_installed({
    "gnome-system-monitor", "plasma-systemmonitor --page-name Processes",
    { bin = "btop", cmd = "kitty -1 fish -c btop" },
})

local missing_apps = {}
local function bind_app(keys, cmd, opts)
    if cmd then
        hl.bind(keys, hl.dsp.exec_cmd(cmd), opts)
    else
        table.insert(missing_apps, (opts and opts.description) or keys)
    end
end

local media_next = "playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"

--------------------------------------------------------------------------------
-- Shell
--------------------------------------------------------------------------------

-- These must stay first: Hyprland's global shortcut dispatcher carries the
-- Super press/release lifecycle to Quickshell, which decides whether to toggle.
hl.bind("SUPER + Super_L", hl.dsp.global("quickshell:overviewToggleRelease"),
    { description = "Shell: Toggle overview/launcher" })
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd(qs_alive .. " || pkill fuzzel || fuzzel"))

hl.bind("Super_L", hl.dsp.global("quickshell:workspaceNumber"),
    { ignore_mods = true, transparent = true })
hl.bind("Super_L", hl.dsp.global("quickshell:workspaceNumber"),
    { ignore_mods = true, transparent = true, release = true })

hl.bind("SUPER + V", hl.dsp.global("quickshell:overviewClipboardToggle"),
    { description = "Shell: Clipboard history >> clipboard" })
hl.bind("SUPER + Tab", hl.dsp.global("quickshell:overviewToggle"))
hl.bind("SUPER + A", hl.dsp.global("quickshell:sidebarLeftToggle"),
    { description = "Shell: Toggle left sidebar" })
hl.bind("SUPER + ALT + A", hl.dsp.global("quickshell:sidebarLeftToggleDetach"))
hl.bind("SUPER + B", hl.dsp.global("quickshell:sidebarLeftToggle"))
hl.bind("SUPER + O", hl.dsp.global("quickshell:sidebarLeftToggle"))
hl.bind("SUPER + N", hl.dsp.global("quickshell:sidebarRightToggle"),
    { description = "Shell: Toggle right sidebar" })
hl.bind("SUPER + Slash", hl.dsp.global("quickshell:cheatsheetToggle"),
    { description = "Shell: Toggle cheatsheet" })
hl.bind("SUPER + K", hl.dsp.global("quickshell:oskToggle"),
    { description = "Shell: Toggle on-screen keyboard" })
hl.bind("SUPER + M", hl.dsp.global("quickshell:mediaControlsToggle"),
    { description = "Shell: Toggle media controls" })
hl.bind("CTRL + ALT + Delete", hl.dsp.global("quickshell:sessionToggle"),
    { description = "Shell: Toggle session menu" })
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(qs_alive .. " || pkill wlogout || wlogout -p layer-shell"))
hl.bind("SHIFT + SUPER + ALT + Slash",
    hl.dsp.exec_cmd("qs -p " .. home .. "/.config/quickshell/welcome.qml"))

-- Brightness and volume, repeating and active while locked
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs ipc call brightness increment || brightnessctl s 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs ipc call brightness decrement || brightnessctl s 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"),
    { locked = true, repeating = true })

hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

hl.bind("CTRL + SUPER + T", hl.dsp.exec_cmd(theme_tool),
    { description = "Shell: Change wallpaper" })
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd("killall ags agsv1 gjs ydotool qs quickshell; qs &"),
    { description = "Shell: Restart widgets" })

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

hl.bind("SUPER + V", hl.dsp.exec_cmd(qs_alive ..
    " || pkill fuzzel || cliphist list | fuzzel --match-mode fzf --dmenu | cliphist decode | wl-copy"))
hl.bind("SUPER + Period", hl.dsp.exec_cmd(
    "pkill fuzzel || if command -v rofimoji >/dev/null; then " ..
    "rofimoji --selector fuzzel --action copy; else " ..
    "notify-send 'Emoji picker unavailable' 'Install rofimoji from Arch Extra'; fi"),
    { description = "Shell: Emoji >> clipboard" })

-- Screen snip used to be SUPER + SHIFT + S. Dropped 2026-08-01: the key now
-- belongs to "restore minimized window" below, which was double-bound with it
-- under .conf. Snipping is still on the bar's util button.

hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd(
    'grim -g "$(slurp $SLURP_ARGS)" "tmp.png" && tesseract "tmp.png" - | wl-copy && rm "tmp.png"'))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"),
    { description = "Utilities: Pick color (Hex) >> clipboard" })

hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"),
    { locked = true, description = "Utilities: Screenshot >> clipboard" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd(
    "mkdir -p $(xdg-user-dir PICTURES)/Screenshots && grim $(xdg-user-dir PICTURES)/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"),
    { locked = true, description = "Utilities: Screenshot >> clipboard & file" })

hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("qs ipc call recorder toggleRegion"),
    { description = "Utilities: Record region (no sound)" })
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd("qs ipc call recorder toggleFullscreen"),
    { description = "Utilities: Record screen (no sound)" })
hl.bind("SUPER + SHIFT + ALT + R", hl.dsp.exec_cmd("qs ipc call recorder toggleFullscreenAudio"),
    { description = "Utilities: Record screen (with sound)" })

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: Resize" })

local directions = {
    { key = "Left", dir = "left" },
    { key = "Right", dir = "right" },
    { key = "Up", dir = "up" },
    { key = "Down", dir = "down" },
}
for _, d in ipairs(directions) do
    hl.bind("SUPER + " .. d.key, hl.dsp.focus({ direction = d.dir }))
    hl.bind("SUPER + SHIFT + " .. d.key, hl.dsp.window.move({ direction = d.dir }))
end
hl.bind("SUPER + BracketLeft", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + BracketRight", hl.dsp.focus({ direction = "right" }))

hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"),
    { description = "Window: Forcefully zap a window" })

-- Split ratio
hl.bind("SUPER + Semicolon", hl.dsp.window.resize({ x = -80, y = 0 }), { repeating = true })
hl.bind("SUPER + Apostrophe", hl.dsp.window.resize({ x = 80, y = 0 }), { repeating = true })

hl.bind("SUPER + ALT + Space", lib.toggle_floating,
    { description = "Window: Float/Tile" })
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
    { description = "Window: Maximize" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
    { description = "Window: Fullscreen" })
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }),
    { description = "Window: Fullscreen spoof" })
hl.bind("SUPER + P", hl.dsp.window.pin(), { description = "Window: Pin" })

-- Send to workspace N within the current group of ten.
for i = 1, 10 do
    local key = (i == 10) and "0" or tostring(i)
    hl.bind("SUPER + ALT + " .. key, function()
        hl.dispatch(hl.dsp.window.move({ workspace = lib.workspace_in_group(i), follow = false }))
    end)
end

-- Send to workspace left/right, by scroll and by page key
for _, m in ipairs({
    { keys = "SUPER + SHIFT + mouse_down", ws = "r-1" },
    { keys = "SUPER + SHIFT + mouse_up", ws = "r+1" },
    { keys = "SUPER + ALT + mouse_down", ws = "-1" },
    { keys = "SUPER + ALT + mouse_up", ws = "+1" },
    { keys = "SUPER + ALT + Page_Down", ws = "+1" },
    { keys = "SUPER + ALT + Page_Up", ws = "-1" },
    { keys = "SUPER + SHIFT + Page_Down", ws = "r+1" },
    { keys = "SUPER + SHIFT + Page_Up", ws = "r-1" },
    { keys = "CTRL + SUPER + SHIFT + Right", ws = "r+1" },
    { keys = "CTRL + SUPER + SHIFT + Left", ws = "r-1" },
}) do
    hl.bind(m.keys, hl.dsp.window.move({ workspace = m.ws }))
end

hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special", follow = false }),
    { description = "Window: Send to scratchpad" })
hl.bind("CTRL + SUPER + S", hl.dsp.workspace.toggle_special())
hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
hl.bind("ALT + Tab", hl.dsp.window.bring_to_top())

--------------------------------------------------------------------------------
-- Workspace
--------------------------------------------------------------------------------

-- Focus workspace N within the current group of ten.
for i = 1, 10 do
    local key = (i == 10) and "0" or tostring(i)
    hl.bind("SUPER + " .. key, function()
        hl.dispatch(hl.dsp.focus({ workspace = lib.workspace_in_group(i) }))
    end)
end

for _, m in ipairs({
    { keys = "CTRL + SUPER + Right", ws = "r+1" },
    { keys = "CTRL + SUPER + Left", ws = "r-1" },
    { keys = "CTRL + SUPER + ALT + Right", ws = "m+1" },
    { keys = "CTRL + SUPER + ALT + Left", ws = "m-1" },
    { keys = "SUPER + Page_Down", ws = "+1" },
    { keys = "SUPER + Page_Up", ws = "-1" },
    { keys = "CTRL + SUPER + Page_Down", ws = "r+1" },
    { keys = "CTRL + SUPER + Page_Up", ws = "r-1" },
    { keys = "SUPER + mouse_up", ws = "+1" },
    { keys = "SUPER + mouse_down", ws = "-1" },
    { keys = "CTRL + SUPER + mouse_up", ws = "r+1" },
    { keys = "CTRL + SUPER + mouse_down", ws = "r-1" },
    { keys = "CTRL + SUPER + BracketLeft", ws = "-1" },
    { keys = "CTRL + SUPER + BracketRight", ws = "+1" },
    { keys = "CTRL + SUPER + Up", ws = "r-5" },
    { keys = "CTRL + SUPER + Down", ws = "r+5" },
}) do
    hl.bind(m.keys, hl.dsp.focus({ workspace = m.ws }))
end

hl.bind("SUPER + S", hl.dsp.workspace.toggle_special(),
    { description = "Workspace: Toggle scratchpad" })
hl.bind("SUPER + mouse:275", hl.dsp.workspace.toggle_special())

--------------------------------------------------------------------------------
-- Session
--------------------------------------------------------------------------------

-- hyprlock.conf is generated by theme.py into the state dir, so point hyprlock at it
local lock_cmd = "pidof hyprlock || hyprlock -c " .. home .. "/.local/state/quickshell/user/generated/hyprlock.conf"

hl.bind("SUPER + L", hl.dsp.exec_cmd(lock_cmd),
    { description = "Session: Lock" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd(lock_cmd))
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("sleep 0.1 && systemctl suspend || loginctl suspend"),
    { locked = true, description = "Session: Sleep" })
hl.bind("CTRL + SHIFT + ALT + SUPER + Delete",
    hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"))

--------------------------------------------------------------------------------
-- Screen
--------------------------------------------------------------------------------

local function adjust_zoom(delta)
    local current = hl.get_config("cursor:zoom_factor")
    local next = math.max(1.0, math.min(3.0, current + delta))
    hl.config({ cursor = { zoom_factor = next } })
end

hl.bind("SUPER + Minus", function() adjust_zoom(-0.1) end,
    { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + Equal", function() adjust_zoom(0.1) end,
    { repeating = true, description = "Screen: Zoom in" })

--------------------------------------------------------------------------------
-- Media
--------------------------------------------------------------------------------

hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(media_next),
    { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(media_next), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("SUPER + SHIFT + ALT + mouse:275", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("SUPER + SHIFT + ALT + mouse:276", hl.dsp.exec_cmd(media_next))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"),
    { locked = true, description = "Media: Previous track" })
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"),
    { locked = true, description = "Media: Play/pause media" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

--------------------------------------------------------------------------------
-- Apps
--------------------------------------------------------------------------------

bind_app("SUPER + Return", terminal, { description = "Apps: Terminal" })
bind_app("SUPER + T", terminal)
bind_app("CTRL + ALT + T", terminal)
bind_app("SUPER + E", file_manager, { description = "Apps: File manager" })
hl.bind("SUPER + W", hl.dsp.exec_cmd("firefox"), { description = "Apps: Browser" })
bind_app("SUPER + C", code_editor, { description = "Apps: Code editor" })
bind_app("SUPER + X", text_editor, { description = "Apps: Text editor" })
hl.bind("SUPER + Y", hl.dsp.exec_cmd("typora"), { description = "Apps: Typora (Markdown editor)" })
bind_app("CTRL + SUPER + V", volume_mixer, { description = "Apps: Volume mixer" })
bind_app("SUPER + I", settings_app, { description = "Apps: Settings app" })
bind_app("CTRL + SHIFT + Escape", task_manager, { description = "Apps: Task manager" })

-- Make window not amogus large
hl.bind("CTRL + SUPER + Backslash", hl.dsp.window.resize({ x = 640, y = 480, "exact" }))

--------------------------------------------------------------------------------
-- Testing
--------------------------------------------------------------------------------

-- Notification test scaffolding, carried across unchanged. These were hidden in
-- the .conf too. Candidates for deletion, but removing someone's binds is not
-- the migration's call to make.
local random_picture = "$(find ~/Pictures -type f | grep -v -i \"nipple\" | grep -v -i \"pussy\" | shuf -n 1)"

hl.bind("SUPER + ALT + f11", hl.dsp.exec_cmd([==[bash -c 'RANDOM_IMAGE=]] .. random_picture ..
    [==[; ACTION=$(notify-send "Test notification with body image" "This notification should contain your user account <b>image</b> and <a href=\"https://discord.com/app\">Discord</a> <b>icon</b>. Oh and here is a random image in your Pictures folder: <img src=\"$RANDOM_IMAGE\" alt=\"Testing image\"/>" -a "Hyprland keybind" -p -h "string:image-path:/var/lib/AccountsService/icons/$USER" -t 6000 -i "discord" -A "openImage=Open profile image" -A "action2=Open the random image" -A "action3=Useless button"); [[ $ACTION == *openImage ]] && xdg-open "/var/lib/AccountsService/icons/$USER"; [[ $ACTION == *action2 ]] && xdg-open \"$RANDOM_IMAGE\"']==]))

hl.bind("SUPER + ALT + f12", hl.dsp.exec_cmd([==[bash -c 'RANDOM_IMAGE=]] .. random_picture ..
    [==[; ACTION=$(notify-send "Test notification" "This notification should contain a random image in your <b>Pictures</b> folder and <a href=\"https://discord.com/app\">Discord</a> <b>icon</b>.\n<i>Flick right to dismiss!</i>" -a "Discord (fake)" -p -h "string:image-path:$RANDOM_IMAGE" -t 6000 -i "discord" -A "openImage=Open profile image" -A "action2=Useless button" -A "action3=Cry more"); [[ $ACTION == *openImage ]] && xdg-open "/var/lib/AccountsService/icons/$USER"']==]))

hl.bind("SUPER + ALT + Equal", hl.dsp.exec_cmd(
    "notify-send 'Urgent notification' 'Ah hell no' -u critical -a 'Hyprland keybind'"))

--------------------------------------------------------------------------------
-- User (was custom/keybinds.conf)
--------------------------------------------------------------------------------

hl.bind("CTRL + SUPER + Slash",
    hl.dsp.exec_cmd("xdg-open " .. home .. "/.config/carbon/config.json"),
    { description = "User: Edit shell config" })
hl.bind("CTRL + SUPER + ALT + Slash",
    hl.dsp.exec_cmd("xdg-open " .. home .. "/.config/hypr/keybinds.lua"),
    { description = "User: Edit extra keybinds" })

hl.bind("SUPER + R", hl.dsp.exec_cmd("spotify"), { description = "Media Apps: Spotify" })

-- Sole owner of SUPER + SHIFT + S since the Screen snip bind was dropped.
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "e+0" }),
    { description = "Window Management: Restore minimized window to current workspace" })

-- Report anything that could not be bound, once, at startup.
if #missing_apps > 0 then
    hl.on("hyprland.start", function()
        hl.notification.create({
            text = "Keybinds skipped, no candidate installed: " .. table.concat(missing_apps, "; "),
            duration = 10000,
        })
    end)
end
