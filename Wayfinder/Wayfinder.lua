-- Author      : Wyomarus
-- Create Date : 9/7/2024 5:11:21 PM

local addonName, addon = ...
_G[addonName] = addon -- expose the addon table globally by name, for in-game inspection/debugging

-- Addon namespaces. Each carries a "$Info" key as a self-documenting description,
-- readable via /dump or /script in-game without needing to open the source.
addon.API = addon.API or {
    ["$Info"] = "API functions for the Wayfinder addon."
}

addon.Dependencies = addon.Dependencies or {
    ["$Info"] = "Libraries and other dependencies used by the Wayfinder addon."
}

addon.private = addon.private or {
    ["$Info"] = "Private functions and data for the Wayfinder addon."
}

addon.Constants = addon.Constants or {
    ["$Info"] = "Constants used by the Wayfinder addon."
}

local _p = addon.private

assert(LibStub, addonName .. " requires LibStub")

-- WoW: Forever beta had a bug where SavedVariables were written to disk correctly but not
-- reliably read back on /reload or client restart (confirmed independently of this addon:
-- https://github.com/ClassicWoWCommunity/forever-bugs/issues/34), which could silently
-- revert any WayfinderSettings value to its default. Fixed by Blizzard as of Forever beta
-- build 70009. Wayfinder.toc's LoadSavedVariablesFirst was and remains the correct setting
-- regardless; the code below is otherwise standard.
WayfinderSettings = WayfinderSettings or {}

--- Read a value from WayfinderSettings, applying and persisting the given default the
--- first time it's seen (i.e. when the key is nil). Centralizes the "read with a
--- default, write it back" pattern every module's persisted settings use.
--- @param key string The field name in WayfinderSettings.
--- @param default any
--- @return any value
local function getOrSetDefault(key, default)
    local value = WayfinderSettings[key]
    if value == nil then
        value = default
        WayfinderSettings[key] = default
    end
    return value
end
_p.getOrSetDefault = getOrSetDefault

-- Cache global references
local print = print
local format = string.format

-- Global helper functions

--- Bind a method to an object, returning a closure that captures the object as the
--- first argument so it can be called without it (i.e. obj:method() instead of
--- obj.method(obj)).
--- @param obj table
--- @param method function
--- @return function
local function bind(obj, method)
    assert(type(obj) == "table", "Expected obj to be a table")
    assert(type(method) == "function", "Expected method to be a function")

    return function(...)
        return method(obj, ...)
    end
end
_p.bind = bind

--- Re-sync the options panel's controls with the current settings. A no-op until
--- Settings.lua replaces it; modules call it whenever a setting changes, including
--- through paths other than the panel itself (a slash command, the addon compartment).
_p.refreshSettingsPanel = function() end

--- Print a table's key/value pairs to the default chat frame.
--- @param tbl table
local function printTable(tbl)
    assert(type(tbl) == "table", "Expected tbl to be a table")

    for key, value in pairs(tbl) do
        print(format("%s:", key), value)
    end
end
_p.printTable = printTable
