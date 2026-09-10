-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

-- Per-app presentation policy. Match the `class` shown by `hyprctl clients`.
-- These apps still use Carbon's frame, but open floating instead of tiled.
local floating_classes = {
}

-- Skinned/widget-like apps draw their own complete interface and need no Carbon frame.
local self_decorated_classes = {
    "^[Qq]mmp$",
}

for _, class in ipairs(floating_classes) do
    hl.window_rule({ match = { class = class }, float = true })
end

for _, class in ipairs(self_decorated_classes) do
    local rule = {
        match = { class = class },
        float = true,
        decorate = false,
        rounding = 0,
        border_size = 0,
        no_shadow = true,
        no_anim = true,
    }
    if hl.plugin.hyprbars then rule["hyprbars:no_bar"] = true end
    hl.window_rule(rule)
end
