-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

-- Hyprland configuration entry point

require("env")
require("execs")
require("general")
require("rules")
require("colors")
require("app_rules")

require("keybinds")

local personal_config = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))
    .. "/carbon/personal/hyprland.lua"
if require("lib").file_exists(personal_config) then
    dofile(personal_config)
end
