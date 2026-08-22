-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

local lib = require("lib")
local home = lib.home

local polkit_agent = lib.first_existing({
    "/usr/lib/polkit-kde-authentication-agent-1",
    "/usr/libexec/polkit-kde-authentication-agent-1",
    "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
    "/usr/libexec/polkit-gnome-authentication-agent-1",
})

local geoclue_agent = lib.first_existing({
    "/usr/lib/geoclue-2.0/demos/agent",
    "/usr/libexec/geoclue-2.0/demos/agent",
})

local compositor_services = {
    "awww-daemon.service",
    "quickshell.service",
    "hypridle.service",
}

if lib.in_path("nagame") and lib.file_exists(home .. "/.config/nagame/config.toml") then
    table.insert(compositor_services, "nagame.service")
end

local autostart = {
    "fcitx5",

    "gnome-keyring-daemon --start --components=secrets",

    "dbus-update-activation-environment --all",

    "easyeffects --gapplication-service",

    "wl-paste --type text --watch cliphist store",
    "wl-paste --type image --watch cliphist store",

    "hyprctl setcursor Bibata-Modern-Classic 24",

    "logid",
}

hl.on("hyprland.start", function()
    for _, cmd in ipairs(autostart) do
        hl.exec_cmd(cmd)
    end

    -- The start event's children receive Hyprland's live socket environment.
    local services = table.concat(compositor_services, " ")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE"
        .. " && { systemctl --user reset-failed " .. services .. " || :; }"
        .. " && systemctl --user restart " .. services)

    if polkit_agent then
        hl.exec_cmd(polkit_agent)
    else
        hl.notification.create({ text = "No polkit authentication agent found", duration = 8000 })
    end

    if geoclue_agent and lib.in_path("gammastep") then
        hl.exec_cmd(geoclue_agent)
        hl.exec_cmd("sleep 1 && gammastep")
    end
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop " .. table.concat(compositor_services, " "))
end)
