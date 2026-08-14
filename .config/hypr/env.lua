-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

-- Environment variables. Was hyprland/env.conf + custom/env.conf.

local lib = require("lib")

hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("GLFW_IM_MODULE", "ibus")
hl.env("INPUT_METHOD", "fcitx")
hl.env("QT_QPA_PLATFORM", "wayland")
-- Follow Carbon's GTK light/dark preference without pulling in Plasma Workspace.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_STYLE_OVERRIDE", "Breeze")

hl.env("AG_PROVIDERS", "/usr/share/accounts/providers/kde")
hl.env("AG_SERVICES", "/usr/share/accounts/services/kde")

hl.env("CARBON_VIRTUAL_ENV", lib.home .. "/.local/state/quickshell/.venv")
