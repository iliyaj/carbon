-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

-- Colours and window decoration. Was hyprland/colors.conf.
-- Loaded after general.lua so these border colours deliberately override the
-- ones set there. Hand-maintained: no generator writes this file.

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
