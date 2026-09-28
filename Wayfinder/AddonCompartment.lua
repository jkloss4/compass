-- AddonCompartment registers Wayfinder in the minimap's Addon Compartment dropdown -
-- Blizzard's native, first-class alternative to a standalone minimap button, so there's
-- no need to hand-roll one. A click toggles the compass banner.

local _, addon = ...
local _p = addon.private
local api = addon.API

local GameTooltip = GameTooltip

-- These three functions must be plain globals, named exactly as declared by
-- Wayfinder.toc's AddonCompartmentFunc/-OnEnter/-OnLeave fields - Blizzard dispatches to
-- them by that name, so they can't be namespaced under addon.* like the rest of this
-- codebase.
function Wayfinder_OnAddonCompartmentClick()
    if api.CompassBanner.IsShown() then
        _p.disableCompassBanner()
    else
        _p.enableCompassBanner()
    end
end

function Wayfinder_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText("Wayfinder")
    local toggleLabel = api.CompassBanner.IsShown() and "Hide" or "Show"
    GameTooltip:AddLine(toggleLabel .. " compass banner", 1, 1, 1)
    GameTooltip:Show()
end

function Wayfinder_OnAddonCompartmentLeave()
    GameTooltip_Hide()
end
