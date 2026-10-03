-- Settings integrates Wayfinder's options into Blizzard's native addon Settings panel.
--
-- The options page is a canvas category built entirely from Wayfinder's own frames (by SettingsKit, in Blizzard's
-- settings style), rather than a vertical layout of Blizzard's Settings.CreateCheckbox/CreateDropdown controls.
-- Those controls are pooled frames shared with Blizzard's own settings pages, and initializing them runs addon code
-- (e.g. a dropdown's options function) inside Blizzard's code. That taints the recycled frame, and when it's later
-- reused for a Blizzard setting (e.g. Nameplates > Style), changing that setting runs tainted - which broke the
-- nameplate preview cast bar with "attempt to perform arithmetic on a secret number value (execution tainted by
-- 'Wayfinder')". Owning every frame on the page keeps Wayfinder's code out of Blizzard's pooled controls entirely.

local _, addon = ...
local _p = addon.private
local api = addon.API
local _C = addon.Constants
local Kit = addon.SettingsKit

local DetailLevel = _C.CompassDetail

local page = Kit.NewPage("Compass")
local general, colors = unpack(page:Tabs({ "General", "Colors" }))

-- General ----------------------------------------------------------------------------------------------

general:Header("Compass Banner")

general:Checkbox("Show Compass Banner",
    api.CompassBanner.IsShown,
    function(shown)
        if shown then _p.enableCompassBanner() else _p.disableCompassBanner() end
    end,
    "Show or hide the compass banner.")

general:Checkbox("Lock Position",
    api.CompassBanner.IsLocked,
    function(locked)
        if locked then api.CompassBanner.Lock() else api.CompassBanner.Unlock() end
    end,
    "Lock the banner in place, or unlock it to drag to a new position.",
    { indent = true, enabled = api.CompassBanner.IsShown })

general:Dropdown("Compass Detail", {
    { value = DetailLevel.None, label = "None", tooltip = "Hide compass detail entirely." },
    { value = DetailLevel.Cardinals, label = "Cardinals", tooltip = "Cardinal directions only (N, E, S, W)." },
    { value = DetailLevel.Intercardinals, label = "Intercardinals", tooltip = "Cardinal and intercardinal directions." },
    { value = DetailLevel.Pips, label = "Pips", tooltip = "Cardinal, intercardinal, and a tick every 15 degrees." },
}, api.CardinalPoints.GetDetail, api.CardinalPoints.SetDetail, "How much compass detail to show.")

general:Button("Reset Position", api.CompassBanner.ResetPosition,
    "Reset the compass banner to its default position.")

general:Header("Super Tracking")

local function TrackingEnabled() return api.SuperTracking.IsEnabled() end

general:Checkbox("Enable Tracking",
    api.SuperTracking.IsEnabled,
    function(enabled)
        if enabled then api.SuperTracking.Enable() else api.SuperTracking.Disable() end
    end,
    "Show a marker for whatever you're currently super-tracking.")

general:Checkbox("Show Distance", api.SuperTracking.GetShowDistance, api.SuperTracking.SetShowDistance,
    "Show the distance to the super-tracked target.", { indent = true, enabled = TrackingEnabled })

general:Checkbox("Show ETA", api.SuperTracking.GetShowETA, api.SuperTracking.SetShowETA,
    "Show an estimated time of arrival to the super-tracked target.", { indent = true, enabled = TrackingEnabled })

general:Checkbox("Point at Edge", api.SuperTracking.GetRotateAtEdge, api.SuperTracking.SetRotateAtEdge,
    "Turn the marker to point sideways when the target is out of view.", { indent = true, enabled = TrackingEnabled })

general:Slider("Hide When Within", 0, 100, 1,
    api.SuperTracking.GetHideDistance, api.SuperTracking.SetHideDistance,
    function(yards) return yards == 0 and "Never" or (yards .. " yds") end,
    "Fade out the marker this close to the target.", { indent = true, enabled = TrackingEnabled })

general:Checkbox("Hide Inside Quest Area", api.SuperTracking.GetHideInQuestArea, api.SuperTracking.SetHideInQuestArea,
    "Fade out the marker inside the tracked quest's objective area.", { indent = true, enabled = TrackingEnabled })

-- Colors -----------------------------------------------------------------------------------------------

colors:Header("Compass")

local function ColorRow(label, tooltip, key)
    colors:ColorSwatch(label,
        function() return api.Colors.Get(key) end,
        function(r, g, b, a) api.Colors.Set(key, r, g, b, a) end,
        tooltip, { hasOpacity = true })
end

ColorRow("Cardinal Letters", "N, E, S and W.", "cardinals")
ColorRow("Intercardinal Letters", "NE, SE, SW and NW.", "intercardinals")
ColorRow("Tick Marks", "The ticks every 15 degrees.", "ticks")
ColorRow("Center Line", "The \"straight ahead\" line.", "centerLine")

colors:Button("Reset Colors", api.Colors.ResetAll, "Restore the default compass colors.")

Kit.Register(page)

api.Settings = {
    Open = function() Kit.Open(page) end,
}

-- Keep the panel in sync when a setting changes some other way (slash command, addon compartment, Events.lua
-- auto-hiding the banner in instances) while it's open.
_p.refreshSettingsPanel = function()
    if page.frame:IsVisible() then
        page:Refresh()
    end
end
