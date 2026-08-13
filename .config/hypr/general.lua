-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

-- Look, feel, input and monitors. Was hyprland/general.conf + custom/general.conf.

local lib = require("lib")

hl.monitor({
    output   = lib.setting("MONITOR_OUTPUT", ""),
    mode     = lib.setting("MONITOR_MODE", "preferred"),
    position = lib.setting("MONITOR_POSITION", "auto"),
    scale    = lib.setting_number("MONITOR_SCALE", 1),
})

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, transform = 0 })

hl.config({
    general = {
        -- gaps_in counts on both neighbours, so 2 matches the 6px that gaps_out + border leaves at the screen edge
        gaps_in = 2,
        gaps_out = 5,
        gaps_workspaces = 50,

        border_size = 1,
        col = {
            active_border = "rgba(0DB7D4FF)",
            inactive_border = "rgba(31313600)",
        },
        resize_on_border = true,

        no_focus_fallback = true,

        allow_tearing = true,

        snap = {
            enabled = true,
        },
    },

    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = false,
    },

    decoration = {
        rounding = 18,

        blur = {
            enabled = true,
            xray = true,
            special = false,
            new_optimizations = true,
            size = 14,
            passes = 3,
            brightness = 1,
            noise = 0.01,
            contrast = 1,
            popups = true,
            popups_ignorealpha = 0.6,
            input_methods = true,
            input_methods_ignorealpha = 0.8,
        },

        shadow = {
            enabled = true,
            range = 30,
            offset = "0 2",
            render_power = 4,
            color = "rgba(00000010)",
        },

        dim_inactive = true,
        dim_strength = 0.025,
        dim_special = 0.07,
    },

    input = {
        kb_layout = "us",
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,

        follow_mouse = 1,

        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.5,
        },
    },

    gestures = {
        workspace_swipe_invert = false,
        workspace_swipe_distance = 700,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 1,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        enable_swallow = false,
        swallow_regex = "(foot|kitty|allacritty|Alacritty)",
        allow_session_lock_restore = true,
        initial_workspace_tracking = false,
        focus_on_activate = true,
    },

    binds = {
        scroll_event_delay = 0,
        hide_special_on_workspace_change = true,
    },

    cursor = {
        zoom_factor = 1,
        zoom_rigid = false,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    animations = {
        enabled = true,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- Curves
hl.curve("expressiveFastSpatial",    { type = "bezier", points = { {0.42, 1.67}, {0.21, 0.90} } })
hl.curve("expressiveSlowSpatial",    { type = "bezier", points = { {0.39, 1.29}, {0.35, 0.98} } })
hl.curve("expressiveDefaultSpatial", { type = "bezier", points = { {0.38, 1.21}, {0.22, 1.00} } })
hl.curve("emphasizedDecel",          { type = "bezier", points = { {0.05, 0.7},  {0.1, 1}     } })
hl.curve("emphasizedAccel",          { type = "bezier", points = { {0.3, 0},     {0.8, 0.15}  } })
hl.curve("standardDecel",            { type = "bezier", points = { {0, 0},       {0, 1}       } })
hl.curve("menu_decel",               { type = "bezier", points = { {0.1, 1},     {0, 1}       } })
hl.curve("menu_accel",               { type = "bezier", points = { {0.52, 0.03}, {0.72, 0.08} } })

-- Windows
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3,  bezier = "emphasizedDecel", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2,  bezier = "emphasizedAccel", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "emphasizedDecel" })
hl.animation({ leaf = "border",     enabled = true, speed = 10, bezier = "emphasizedDecel" })

-- Layers
hl.animation({ leaf = "layersIn",  enabled = true, speed = 2.7, bezier = "emphasizedDecel", style = "popin 93%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.4, bezier = "menu_accel",      style = "popin 94%" })

-- Fade
hl.animation({ leaf = "fadeIn",         enabled = false, speed = 1,   bezier = "default" })
hl.animation({ leaf = "fadeOut",        enabled = false, speed = 1,   bezier = "default" })
hl.animation({ leaf = "fadeLayersIn",   enabled = true,  speed = 0.5, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut",  enabled = true,  speed = 2.7, bezier = "menu_accel" })

-- Workspaces
hl.animation({ leaf = "workspaces",           enabled = true, speed = 7,   bezier = "menu_decel",      style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",   enabled = true, speed = 2.8, bezier = "emphasizedDecel", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut",  enabled = true, speed = 1.2, bezier = "emphasizedAccel", style = "slidevert" })
