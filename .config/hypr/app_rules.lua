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

-- Apps that always open on their own workspace, switching to it.
local workspace_classes = {
    ["^firefox$"] = "1",
    ["^[Gg]oogle-chrome$"] = "2",
    ["^code-oss$"] = "3",
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

for class, workspace in pairs(workspace_classes) do
    hl.window_rule({ match = { class = class }, workspace = workspace })
end
