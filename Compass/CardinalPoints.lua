-- CardinalPoints manages the cardinal, intercardinal, and fine-detail tick marks
-- on the compass banner, and the user's chosen level of detail for them.

local _, addon = ...
local _p = addon.private
local api = addon.API
local _C = addon.Constants

--- The tiers of compass detail, each one showing everything the previous tier does plus
--- more. Published on addon.Constants since Slash.lua's input validation needs it too.
_C.CompassDetail = {
    None = 0,
    Cardinals = 1,
    Intercardinals = 2,
    Pips = 3,
}
local DetailLevel = _C.CompassDetail

local DEFAULT_DETAIL = DetailLevel.Pips

local cardinalDirections = {
    { name = "N", angle = 0 },
    { name = "E", angle = 90 },
    { name = "S", angle = 180 },
    { name = "W", angle = 270 },
}

local intercardinalDirections = {
    { name = "NE", angle = 45 },
    { name = "SE", angle = 135 },
    { name = "SW", angle = 225 },
    { name = "NW", angle = 315 },
}

local function createLabel(frame, text, fontTemplate, alpha)
    local fontString = frame:CreateFontString(nil, "OVERLAY", fontTemplate)
    fontString:SetText(text)
    if alpha then
        fontString:SetAlpha(alpha)
    end
    return fontString
end

local CARDINAL_PIP_HEIGHT = 10
local INTERCARDINAL_PIP_HEIGHT = 6

local function createPip(frame, height)
    local pip = frame:CreateTexture(nil, "ARTWORK")
    pip:SetColorTexture(1, 1, 1, 0.5)
    pip:SetSize(2, height)
    return pip
end

--- Whether a tick at the given angle sits closer to a cardinal direction (N/E/S/W)
--- than to an intercardinal one (NE/SE/SW/NW), to grade its height accordingly.
local function isPipNearCardinal(angle)
    local offset = angle % 90
    local distToCardinal = math.min(offset, 90 - offset)
    local distToIntercardinal = math.abs(45 - offset)
    return distToCardinal < distToIntercardinal
end

--- Register a compass-banner element at a fixed absolute angle (it doesn't move with the player).
local function addFixedAngleElement(name, angle, createBannerMarker)
    return api.AddElementToBanner(
        name,
        function() return angle end,
        createBannerMarker,
        false
    )
end

local function setElementsEnabled(elementList, enabled)
    for _, element in ipairs(elementList) do
        api.SetElementEnabled(element, enabled)
    end
end

local cardinalElements = {}
for _, direction in ipairs(cardinalDirections) do
    local element = addFixedAngleElement(direction.name, direction.angle, function(frame)
        return createLabel(frame, direction.name, "GameFontNormalLarge")
    end)
    table.insert(cardinalElements, element)
end

local intercardinalElements = {}
for _, direction in ipairs(intercardinalDirections) do
    local element = addFixedAngleElement(direction.name, direction.angle, function(frame)
        return createLabel(frame, direction.name, "GameFontNormal", 0.8)
    end)
    table.insert(intercardinalElements, element)
end

-- One tick every 15 degrees, skipping the 8 positions already covered by a
-- cardinal or intercardinal label (the multiples of 45). Ticks nearer a cardinal
-- are taller, extending the same cardinal > intercardinal visual weighting down
-- to this level of detail.
local pipElements = {}
for angle = 0, 345, 15 do
    if angle % 45 ~= 0 then
        local height = isPipNearCardinal(angle) and CARDINAL_PIP_HEIGHT or INTERCARDINAL_PIP_HEIGHT
        local element = addFixedAngleElement("Pip" .. angle, angle, function(frame)
            return createPip(frame, height)
        end)
        table.insert(pipElements, element)
    end
end

--- Render a detail level without changing the remembered preference. Each tier shows
--- everything the one below it does, plus more.
--- @param level number One of the DetailLevel values.
local function applyDetail(level)
    setElementsEnabled(cardinalElements, level >= DetailLevel.Cardinals)
    setElementsEnabled(intercardinalElements, level >= DetailLevel.Intercardinals)
    setElementsEnabled(pipElements, level >= DetailLevel.Pips)
    api.SetCenterLineShown(level >= DetailLevel.Cardinals)
end

--- Set the user's preferred detail level: applies it now and remembers it for Show().
--- _p.refreshSettingsPanel is a no-op until Settings.lua has loaded, so it's safe to
--- call unconditionally - it's how the options panel's detail buttons stay in sync when
--- the detail level changes via a slash command instead of the panel itself.
--- @param level number
local function setDetail(level)
    applyDetail(level)
    WayfinderSettings.compassDetail = level
    _p.refreshSettingsPanel()
end

api.CardinalPoints = {
    Show = function() applyDetail(_p.getOrSetDefault("compassDetail", DEFAULT_DETAIL)) end,
    Hide = function() applyDetail(DetailLevel.None) end,
    SetDetail = setDetail,
    GetDetail = function() return WayfinderSettings.compassDetail end,
}

setDetail(_p.getOrSetDefault("compassDetail", DEFAULT_DETAIL))

-- Compass colors. Each part of the compass detail has a user-configurable color and
-- opacity; only colors the user has changed are saved (in WayfinderSettings.colors), so
-- everything else follows the defaults below.
local gold = NORMAL_FONT_COLOR
local COLOR_DEFAULTS = {
    cardinals = { r = gold.r, g = gold.g, b = gold.b, a = 1 },
    intercardinals = { r = gold.r, g = gold.g, b = gold.b, a = 0.8 },
    ticks = { r = 1, g = 1, b = 1, a = 0.5 },
    centerLine = { r = 1, g = 1, b = 1, a = 1 },
}

WayfinderSettings.colors = WayfinderSettings.colors or {}

--- @param key string One of the COLOR_DEFAULTS keys.
--- @return number r, number g, number b, number a
local function getColor(key)
    local color = WayfinderSettings.colors[key] or COLOR_DEFAULTS[key]
    return color.r, color.g, color.b, color.a
end

--- Apply the current colors to every compass label, tick and the center line.
local function applyColors()
    local r, g, b, a = getColor("cardinals")
    for _, element in ipairs(cardinalElements) do
        element.uiElement:SetTextColor(r, g, b)
        element.uiElement:SetAlpha(a)
    end

    r, g, b, a = getColor("intercardinals")
    for _, element in ipairs(intercardinalElements) do
        element.uiElement:SetTextColor(r, g, b)
        element.uiElement:SetAlpha(a)
    end

    r, g, b, a = getColor("ticks")
    for _, element in ipairs(pipElements) do
        element.uiElement:SetColorTexture(r, g, b, a)
    end

    addon.CompassBannerFrame.centerLine:SetColorTexture(getColor("centerLine"))
end

api.Colors = {
    Get = getColor,
    --- @param key string
    Set = function(key, r, g, b, a)
        WayfinderSettings.colors[key] = { r = r, g = g, b = b, a = a }
        applyColors()
        _p.refreshSettingsPanel()
    end,
    ResetAll = function()
        wipe(WayfinderSettings.colors)
        applyColors()
        _p.refreshSettingsPanel()
    end,
}

applyColors()
