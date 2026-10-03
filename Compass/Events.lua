local _, addon = ...
local _p = addon.private

local function RegisterEvent(event, handler)
    local eventFrame = CreateFrame("EventFrame")
    eventFrame:RegisterEvent(event)
    eventFrame:SetScript("OnEvent", handler)
end

local IsInInstance = IsInInstance
local function OnZoneChangedNewArea()
    local isInInstance = IsInInstance()

    if not isInInstance then
        _p.enableCompassBanner()
    else
        _p.disableCompassBanner()
    end
end

RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneChangedNewArea)
