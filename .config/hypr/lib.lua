-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Carbon contributors

-- Shared helpers for the Hyprland Lua config.

local M = {}

function M.file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() end
    return f ~= nil
end

function M.first_existing(paths)
    for _, path in ipairs(paths) do
        if M.file_exists(path) then return path end
    end
    return nil
end

M.home = os.getenv("HOME")

local user_env = nil

local function load_user_env()
    if user_env then return user_env end
    user_env = {}
    local f = io.open(M.home .. "/.config/hypr/user.env", "r")
    if not f then return user_env end
    for line in f:lines() do
        local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if key and not line:match("^%s*#") then
            value = value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
            -- shell-style $HOME so one file can be read by both Lua and sh
            value = value:gsub("%$HOME", M.home):gsub("%${HOME}", M.home)
            user_env[key] = value
        end
    end
    f:close()
    return user_env
end

function M.setting(key, default)
    local value = load_user_env()[key]
    if value == nil or value == "" then return default end
    return value
end

function M.setting_number(key, default)
    return tonumber(M.setting(key, nil)) or default
end

function M.in_path(bin)
    for dir in (os.getenv("PATH") or ""):gmatch("[^:]+") do
        if M.file_exists(dir .. "/" .. bin) then return true end
    end
    return false
end

function M.first_installed(candidates)
    for _, c in ipairs(candidates) do
        local bin = type(c) == "table" and c.bin or c:match("^%S+")
        local cmd = type(c) == "table" and c.cmd or c
        if M.in_path(bin) then return cmd end
    end
    return nil
end

M.workspace_group_size = 10

function M.workspace_in_group(n)
    local current = hl.get_active_workspace().id
    local base = math.floor((current - 1) / M.workspace_group_size) * M.workspace_group_size
    return base + n
end

function M.toggle_floating()
    local window = hl.get_active_window()
    if not window then return end

    if window.floating then
        hl.dispatch(hl.dsp.window.float({ action = "toggle", window = window }))
        return
    end

    if window.fullscreen ~= 0 then
        local mode = window.fullscreen == 1 and "maximized" or "fullscreen"
        hl.dispatch(hl.dsp.window.fullscreen({ mode = mode, action = "unset", window = window }))
    end

    hl.dispatch(hl.dsp.window.float({ action = "toggle", window = window }))
    hl.dispatch(hl.dsp.window.resize({ x = 1100, y = 900, relative = false, window = window }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
end

return M
