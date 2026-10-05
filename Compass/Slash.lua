-- Slash commands

local _, addon = ...
local _p = addon.private
local api = addon.API
local _C = addon.Constants

local print = print

local function ShowCompassBanner()
    _p.enableCompassBanner()
    print("Compass banner shown.")
end

local function HideCompassBanner()
    _p.disableCompassBanner()
    print("Compass banner hidden.")
end

local function LockCompassBanner()
    api.CompassBanner.Lock()
    print("Compass banner locked.")
end

local function UnlockCompassBanner()
    api.CompassBanner.Unlock()
    print("Compass banner unlocked. Drag it to reposition, then /compass lock to lock it back in place.")
end

local function ResetCompassBannerPosition()
    api.CompassBanner.ResetPosition()
    print("Compass banner position reset to default.")
end

local function OpenSettings()
    api.Settings.Open()
end

local function EnableCardinalPoints()
    api.CardinalPoints.Show()
    print("CardinalPoints enabled.")
end

local function DisableCardinalPoints()
    api.CardinalPoints.Hide()
    print("CardinalPoints disabled.")
end

local function EnableSuperTracking()
    api.SuperTracking.Enable()
    print("SuperTracking enabled.")
end

local function DisableSuperTracking()
    api.SuperTracking.Disable()
    print("SuperTracking disabled.")
end

local function DebugSuperTracking()
    api.DebugSuperTracking()
end

local function EnableTrackingDistance()
    api.SuperTracking.SetShowDistance(true)
    print("SuperTracking distance readout enabled.")
end

local function DisableTrackingDistance()
    api.SuperTracking.SetShowDistance(false)
    print("SuperTracking distance readout disabled.")
end

local function EnableTrackingETA()
    api.SuperTracking.SetShowETA(true)
    print("SuperTracking ETA readout enabled.")
end

local function DisableTrackingETA()
    api.SuperTracking.SetShowETA(false)
    print("SuperTracking ETA readout disabled.")
end

local function SetCompassDetail(arg)
    local DetailLevel = _C.CompassDetail
    local level = tonumber(arg)
    if not level or level < DetailLevel.None or level > DetailLevel.Pips or level % 1 ~= 0 then
        print("Usage: /compass detail <0-3>")
        print(" 0 - hide compass detail entirely")
        print(" 1 - cardinal directions only (N, E, S, W)")
        print(" 2 - cardinal and intercardinal directions")
        print(" 3 - cardinal, intercardinal, and a tick every 15 degrees (default)")
        return
    end

    api.CardinalPoints.SetDetail(level)
    print("Compass detail set to " .. level .. ".")
end

local function PrintUsage()
    print("Usage:")
    print("/compass show - Show the compass banner")
    print("/compass hide - Hide the compass banner")
    print("/compass lock - Lock the compass banner in place")
    print("/compass unlock - Unlock the compass banner so it can be dragged")
    print("/compass resetposition - Reset the compass banner to its default position")
    print("/compass settings - Open the Compass settings panel")
    print("/compass directions enable|disable - Show or hide the direction markers (N, NE, E...)")
    print("/compass detail <0-3> - Set how much compass detail is shown")
    print("/compass tracking enable|disable - Enable or disable SuperTracking")
    print("/compass distance enable|disable - Show or hide the SuperTracking distance readout")
    print("/compass eta enable|disable - Show or hide the SuperTracking ETA readout")
    print("/compass debug tracking - Print SuperTracking diagnostic info")
    print("/compass debug trace - Print a line each time the tracked destination changes (toggle)")
end

local commandHandlers = {
    show = ShowCompassBanner,
    hide = HideCompassBanner,
    lock = LockCompassBanner,
    unlock = UnlockCompassBanner,
    resetposition = ResetCompassBannerPosition,
    settings = OpenSettings,
    directions = {
        enable = EnableCardinalPoints,
        disable = DisableCardinalPoints,
    },
    detail = SetCompassDetail,
    tracking = {
        enable = EnableSuperTracking,
        disable = DisableSuperTracking,
    },
    distance = {
        enable = EnableTrackingDistance,
        disable = DisableTrackingDistance,
    },
    eta = {
        enable = EnableTrackingETA,
        disable = DisableTrackingETA,
    },
    debug = {
        tracking = DebugSuperTracking,
        trace = function()
            WayfinderSettings.trace = not WayfinderSettings.trace or nil
            print("Compass destination trace " .. (WayfinderSettings.trace and "on" or "off") .. ".")
        end,
    },
}
commandHandlers.compass = commandHandlers.directions -- its old name, from before the command was /compass

--- Dispatch a slash command: look up the first word in commandHandlers, then either
--- call it directly (with the rest of the message as its argument) or, if it maps to
--- a table instead, look up the second word in that table and call it with no argument.
--- @param msg string The text after "/compass" (or the original addon's "/wayfinder" or "/wf").
local function HandleSlashCommands(msg)
    local command, subcommand = msg:match("^(%S*)%s*(.-)$")
    local handler = commandHandlers[command]

    if type(handler) == "function" then
        handler(subcommand)
    elseif type(handler) == "table" then
        local subHandler = handler[subcommand]
        if type(subHandler) == "function" then
            subHandler()
        else
            PrintUsage()
        end
    else
        PrintUsage()
    end
end

local SlashCmdList = SlashCmdList
SlashCmdList["WAYFINDER"] = HandleSlashCommands
_G.SLASH_WAYFINDER1 = "/compass"
_G.SLASH_WAYFINDER2 = "/wayfinder" -- the original addon's commands still work
_G.SLASH_WAYFINDER3 = "/wf"
