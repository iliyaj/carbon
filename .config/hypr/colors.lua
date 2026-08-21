-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

-- Colours and window decoration. Was hyprland/colors.conf. Loaded after general.lua so these border colours deliberately override the ones set there. 
-- Hand-maintained: no generator writes this file.

hl.config({
    general = {
        col = {
            active_border = "rgba(e2e2e239)",
            inactive_border = "rgba(91919130)",
        },
    },
    misc = {
        background_color = "rgba(131313FF)",
    },
})

hl.window_rule({
    match = { pin = true },
    border_color = "rgba(ffffffAA) rgba(ffffff77)",
})

local lib = require("lib")
local hyprbars = lib.setting("HYPRBARS_PLUGIN",
    "/var/cache/hyprpm/" .. (os.getenv("USER") or "") .. "/hyprland-plugins/hyprbars.so")
local config_home = os.getenv("XDG_CONFIG_HOME") or (lib.home .. "/.config")
local config_file = io.open(config_home .. "/carbon/config.json", "r")
local window_controls_enabled = false

if config_file then
    local config = config_file:read("*a")
    config_file:close()
    window_controls_enabled = config:match('"showWindowControls"%s*:%s*true') ~= nil
end

if window_controls_enabled and lib.file_exists(hyprbars) then hl.plugin.load(hyprbars) end

if hl.plugin.hyprbars then
    hl.config({
        plugin = {
            hyprbars = {
                bar_text_font = "Rubik, Geist, AR One Sans, Reddit Sans, Inter, Roboto, Ubuntu, Noto Sans, sans-serif",
                bar_height = 30,
                bar_padding = 10,
                bar_button_padding = 5,
                bar_precedence_over_border = true,
                bar_part_of_window = true,
                bar_color = "rgba(131313FF)",
                col = { text = "rgba(e2e2e2FF)" },
            },
        },
    })

    for _, button in ipairs({
        { icon = "󰅖", action = "hyprctl dispatch 'hl.dsp.window.close()'" },
        { icon = "󰖯", action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = [[maximized]], action = [[toggle]] })'" },
        { icon = "󰖰", action = "hyprctl dispatch 'hl.dsp.window.move({ workspace = [[special]], follow = false })'" },
        { icon = "󰖲", action = "hyprctl dispatch 'function() require([[lib]]).toggle_floating() end'" },
    }) do
        hl.plugin.hyprbars.add_button({
            bg_color = "rgba(00000000)",
            fg_color = "rgb(e2e2e2)",
            size = 22,
            icon = button.icon,
            action = button.action,
        })
    end
end
