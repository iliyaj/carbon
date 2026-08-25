-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

-- Window, workspace and layer rules. Was hyprland/rules.conf + custom/rules.conf.

hl.window_rule({ match = { xwayland = true }, no_blur = true })

-- Modal dialogs should stay clear of the bar and remain reachable for keyboard or mouse input.
hl.window_rule({ match = { modal = true }, float = true, center = true })


for _, class in ipairs({
    "^(blueberry\\.py)$",
    "^(steam)$",
    "^(guifetch)$",
    ".*plasmawindowed.*",
    "kcm_.*",
    ".*bluedevilwizard",
}) do
    hl.window_rule({ match = { class = class }, float = true })
end

for _, title in ipairs({ ".*Welcome", "^(Carbon Settings)$" }) do
    hl.window_rule({ match = { title = title }, float = true })
end

for _, class in ipairs({
    "^(pavucontrol)$",
    "^(org.pulseaudio.pavucontrol)$",
    "^(nm-connection-editor)$",
}) do
    hl.window_rule({ match = { class = class }, float = true, size = "45% 45%", center = true })
end

for _, title in ipairs({
    "^(Open File)(.*)$",
    "^(Select a File)(.*)$",
    "^(Choose wallpaper)(.*)$",
    "^(Open Folder)(.*)$",
    "^(Save As)(.*)$",
    "^(Library)(.*)$",
    "^(File Upload)(.*)$",
    "^(Select project repo folder)$",
    "^(Open existing Akira project)$",
}) do
    hl.window_rule({ match = { title = title }, float = true, center = true })
end

-- DataGrip's XWayland dialogs auto-float but spawn unplaced; the main window tiles so it is unmatched
hl.window_rule({ match = { class = "^(jetbrains-datagrip)$", float = true }, center = true })

hl.window_rule({
    match = { class = "^(plasma-changeicons)$" },
    float = true,
    no_initial_focus = true,
    move = "999999 999999",
})

hl.window_rule({ match = { class = "^dev\\.warp\\.Warp$" }, tile = true })


hl.window_rule({
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
    keep_aspect_ratio = true,
    move = "73% 72%",
    size = "25% 25%",
    pin = true,
})

hl.window_rule({
    match = { class = "^(proton\\.vpn\\.app\\.gtk)$" },
    float = true,
    workspace = "10",
    size = "484 700",
    center = true,
    decorate = false,
    immediate = true,
})

hl.window_rule({ match = { title = ".*\\.exe" }, immediate = true })
hl.window_rule({ match = { class = "^(steam_app)" }, immediate = true })


hl.window_rule({ match = { float = false }, no_shadow = true })


hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })


local function no_anim(namespace)
    hl.layer_rule({ match = { namespace = namespace }, no_anim = true })
end

local function blurred(namespace, alpha)
    hl.layer_rule({ match = { namespace = namespace }, blur = true, ignore_alpha = alpha })
end

for _, ns in ipairs({
    "walker", "selection", "overview", "anyrun", "indicator.*", "osk",
    "hyprpicker", "noanim", "gtk4-layer-shell",
    "quickshell:overview", -- launchers need to be FAST
    "quickshell:onScreenDisplay", -- the close animation washes the translucent pill out
}) do
    no_anim(ns)
end

blurred("gtk-layer-shell", 0.0)
blurred("launcher", 0.5)
blurred("notifications", 0.69)
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true }) -- wlogout
hl.layer_rule({ match = { namespace = "sideleft.*" }, animation = "slide left" })
hl.layer_rule({ match = { namespace = "sideright.*" }, animation = "slide right" })
hl.layer_rule({ match = { namespace = "session[0-9]*" }, blur = true })

for _, ns in ipairs({
    "bar[0-9]*", "barcorner.*", "dock[0-9]*", "indicator.*", "overview[0-9]*",
    "cheatsheet[0-9]*", "sideright[0-9]*", "sideleft[0-9]*", "osk[0-9]*",
}) do
    blurred(ns, 0.6)
end

-- Quickshell
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true, blur_popups = true, ignore_alpha = 0.79 })
hl.layer_rule({ match = { namespace = "quickshell:bar" }, animation = "slide" })
hl.layer_rule({ match = { namespace = "quickshell:screenCorners" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "quickshell:sidebarRight" }, animation = "slide right" })
hl.layer_rule({ match = { namespace = "quickshell:sidebarLeft" }, animation = "slide left" })
hl.layer_rule({ match = { namespace = "quickshell:osk" }, animation = "slide bottom" })
hl.layer_rule({ match = { namespace = "quickshell:dock" }, animation = "slide bottom" })
hl.layer_rule({ match = { namespace = "quickshell:session" }, blur = true, no_anim = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "quickshell:notificationPopup" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "quickshell:onScreenDisplay" }, blur = false, blur_popups = false })
hl.layer_rule({ match = { namespace = "quickshell:backgroundWidgets" }, blur = true, ignore_alpha = 0.05 })

-- outfoxxed's shell
blurred("shell:bar", 0.0)
blurred("shell:notifications", 0.1)
