-- Settings integrates Wayfinder's options into Blizzard's native addon Settings panel.
--
-- The options page is a canvas category built entirely from Wayfinder's own frames,
-- rather than a vertical layout of Blizzard's Settings.CreateCheckbox/CreateDropdown
-- controls. Those controls are pooled frames shared with Blizzard's own settings pages,
-- and initializing them runs addon code (e.g. a dropdown's options function) inside
-- Blizzard's code. That taints the recycled frame, and when it's later reused for a
-- Blizzard setting (e.g. Nameplates > Style), changing that setting runs tainted -
-- which broke the nameplate preview cast bar with "attempt to perform arithmetic on a
-- secret number value (execution tainted by 'Wayfinder')". Owning every frame on the
-- page keeps Wayfinder's code out of Blizzard's pooled controls entirely.

local _, addon = ...
local _p = addon.private
local api = addon.API
local _C = addon.Constants

local DetailLevel = _C.CompassDetail

local optionsFrame = CreateFrame("Frame")
-- Start hidden: a new frame is shown by default, so without this the Settings panel
-- displaying it for the first time isn't a hidden -> shown change, and OnShow (which
-- fills in the controls' current values) never fires.
optionsFrame:Hide()

local category = Settings.RegisterCanvasLayoutCategory(optionsFrame, "Wayfinder")
Settings.RegisterAddOnCategory(category)

api.Settings = {
    Open = function() Settings.OpenToCategory(category:GetID()) end,
}

local LEFT_MARGIN = 16
local INDENT = 24

-- Each refresher re-reads one control's value (and enabled state) from the live settings.
local refreshers = {}

local function refreshAll()
    for _, refresh in ipairs(refreshers) do
        refresh()
    end
end

local title = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", LEFT_MARGIN, -16)
title:SetText("Wayfinder")

-- The options are split into tabs, styled like BlizzMove's (Ace3) tab groups: tab buttons
-- sitting on top of a bordered pane, which holds one content frame per tab.
local pane = CreateFrame("Frame", nil, optionsFrame, "BackdropTemplate")
pane:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", LEFT_MARGIN - 6, -76)
pane:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -10, 10)
pane:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 5, bottom = 3 },
})
pane:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
pane:SetBackdropBorderColor(0.4, 0.4, 0.4)

local ACTIVE_TAB_TEXTURE = "Interface\\OptionsFrame\\UI-OptionsFrame-ActiveTab"
local INACTIVE_TAB_TEXTURE = "Interface\\OptionsFrame\\UI-OptionsFrame-InActiveTab"

--- Create the three pieces (left cap, stretching middle, right cap) of one tab look.
--- @param tab table
--- @param file string
--- @param offsetY number The selected look sits a little lower, overlapping the pane's border.
local function createTabPieces(tab, file, offsetY)
    local left = tab:CreateTexture(nil, "BORDER")
    left:SetTexture(file)
    left:SetTexCoord(0, 0.15625, 0, 1)
    left:SetSize(20, 24)
    left:SetPoint("BOTTOMLEFT", 0, offsetY)

    local right = tab:CreateTexture(nil, "BORDER")
    right:SetTexture(file)
    right:SetTexCoord(0.84375, 1, 0, 1)
    right:SetSize(20, 24)
    right:SetPoint("BOTTOMRIGHT", 0, offsetY)

    local middle = tab:CreateTexture(nil, "BORDER")
    middle:SetTexture(file)
    middle:SetTexCoord(0.15625, 0.84375, 0, 1)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

    return { left, middle, right }
end

--- Create a tab button with the given label.
--- @param text string
--- @return table tab
local function createTab(text)
    local tab = CreateFrame("Button", nil, optionsFrame)
    tab:SetHeight(24)
    tab.activePieces = createTabPieces(tab, ACTIVE_TAB_TEXTURE, -3)
    tab.inactivePieces = createTabPieces(tab, INACTIVE_TAB_TEXTURE, 0)

    local label = tab:CreateFontString(nil, "OVERLAY")
    tab:SetFontString(label)
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)
    tab:SetDisabledFontObject(GameFontHighlightSmall)
    tab:SetText(text)
    -- sized like Ace3 (BlizzMove) tabs: the text plus 4px, plus the two 20px caps
    tab:SetWidth(label:GetStringWidth() + 44)

    tab:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight", "ADD")
    local highlight = tab:GetHighlightTexture()
    highlight:ClearAllPoints()
    highlight:SetPoint("LEFT", tab, "LEFT", 10, -4)
    highlight:SetPoint("RIGHT", tab, "RIGHT", -10, -4)

    --- Show the tab as selected (raised, not clickable) or not.
    function tab:SetSelected(selected)
        for _, piece in ipairs(self.activePieces) do piece:SetShown(selected) end
        for _, piece in ipairs(self.inactivePieces) do piece:SetShown(not selected) end
        self:SetEnabled(not selected)
        label:ClearAllPoints()
        label:SetPoint("LEFT", 14, selected and -2 or -3)
        label:SetPoint("RIGHT", -12, selected and -2 or -3)
    end

    return tab
end

local tabs = {}
local tabContents = {}

--- Show one tab's content and mark it selected, hiding the rest.
--- @param index number
local function selectTab(index)
    for i, tab in ipairs(tabs) do
        tab:SetSelected(i == index)
        tabContents[i]:SetShown(i == index)
    end
end

-- The content frame controls are currently being added to, and the vertical offset from the
-- top of that frame where its next control goes: controls are laid out top to bottom.
local page = nil
local nextY = 0

--- Start a new tab: create its button and content frame, and add controls to it from now on.
--- @param text string
local function beginTab(text)
    local index = #tabs + 1
    local tab = createTab(text)
    if index == 1 then
        tab:SetPoint("BOTTOMLEFT", pane, "TOPLEFT", 6, -4)
    else
        tab:SetPoint("LEFT", tabs[index - 1], "RIGHT", -10, 0)
    end
    tab:SetScript("OnClick", function() selectTab(index) end)
    tabs[index] = tab

    local content = CreateFrame("Frame", nil, pane)
    content:SetAllPoints()
    content:Hide()
    tabContents[index] = content

    page = content
    nextY = 0
end

--- Anchor a region at the next free row, then move the row cursor below it.
--- @param region table
--- @param x number Horizontal offset from the left margin.
--- @param height number The region's height, to advance the cursor by.
--- @param gap number Space above the region.
local function placeNext(region, x, height, gap)
    nextY = nextY - gap
    region:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_MARGIN + x, nextY)
    nextY = nextY - height
end

--- Add a section header.
--- @param text string
local function addHeader(text)
    local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetText(text)
    placeNext(header, 0, 18, 20)
end

--- Add a checkbox, with a short gray description to its right.
--- @param label string
--- @param description string
--- @param getValue function
--- @param setValue function
--- @param isEnabled function|nil Returns whether the checkbox can currently be changed.
--- @param indent number|nil
local function addCheckbox(label, description, getValue, setValue, isEnabled, indent)
    local checkbox = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    checkbox:SetSize(26, 26)
    placeNext(checkbox, indent or 0, 26, 4)

    local text = checkbox.text or checkbox.Text
    text:SetFontObject("GameFontHighlight")
    text:SetText(label)

    local descriptionText = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    descriptionText:SetPoint("LEFT", text, "RIGHT", 10, 0)
    descriptionText:SetText(description)

    checkbox:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        refreshAll()
    end)

    table.insert(refreshers, function()
        checkbox:SetChecked(getValue() and true or false)
        local enabled = not isEnabled or isEnabled()
        checkbox:SetEnabled(enabled)
        text:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
    end)

    return checkbox
end

--- Add a push button, with a short gray description to its right.
--- @param label string
--- @param description string
--- @param onClick function
local function addButton(label, description, onClick)
    local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    button:SetSize(140, 22)
    button:SetText(label)
    placeNext(button, 4, 22, 8)
    button:SetScript("OnClick", function()
        onClick()
        refreshAll()
    end)

    local descriptionText = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    descriptionText:SetPoint("LEFT", button, "RIGHT", 10, 0)
    descriptionText:SetText(description)

    return button
end

--- Add a labeled dropdown for choosing a single value, with a short gray description to its
--- right. Uses Blizzard's standard dropdown (as ForeverQuestMark does); each option's
--- description is shown as its tooltip in the open menu.
--- @param label string
--- @param description string
--- @param options table A list of { value = any, label = string, description = string }.
--- @param getValue function
--- @param setValue function
local function addDropdown(label, description, options, getValue, setValue)
    local labelText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    labelText:SetText(label)
    -- the dropdown is taller than its label and centred on it, so leave extra room above
    -- and less below to keep it evenly spaced between the rows around it
    placeNext(labelText, 4, 16, 20)

    local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(180)
    dropdown:SetPoint("LEFT", labelText, "RIGHT", 12, 0)
    dropdown:SetupMenu(function(_, root)
        for _, option in ipairs(options) do
            local radio = root:CreateRadio(
                option.label,
                function() return getValue() == option.value end,
                function()
                    setValue(option.value)
                    refreshAll()
                end
            )
            radio:SetTooltip(function(tooltip)
                GameTooltip_SetTitle(tooltip, option.label)
                GameTooltip_AddNormalLine(tooltip, option.description)
            end)
        end
    end)

    local descriptionText = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    descriptionText:SetPoint("LEFT", dropdown, "RIGHT", 10, 0)
    descriptionText:SetText(description)

    table.insert(refreshers, function()
        dropdown:GenerateMenu()
    end)

    return dropdown
end

--- Add a labeled slider with its current value and a short gray description to its right.
--- Uses Blizzard's standard options slider (as ForeverQuestMark does), which has arrow
--- steppers built in that disable themselves at the minimum and maximum.
--- @param label string
--- @param description string
--- @param minValue number
--- @param maxValue number
--- @param step number
--- @param getValue function
--- @param setValue function
--- @param formatValue function Turns a value into the text shown next to the slider.
--- @param isEnabled function|nil Returns whether the slider can currently be changed.
--- @param indent number|nil
local function addSlider(label, description, minValue, maxValue, step, getValue, setValue, formatValue, isEnabled, indent)
    local labelText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    labelText:SetText(label)
    placeNext(labelText, (indent or 0) + 4, 20, 10)

    local slider = CreateFrame("Frame", nil, page, "MinimalSliderWithSteppersTemplate")
    slider:SetSize(170, 20)
    slider:SetPoint("LEFT", labelText, "RIGHT", 12, 0)

    local valueText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valueText:SetWidth(50)
    valueText:SetJustifyH("LEFT")

    local descriptionText = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    descriptionText:SetPoint("LEFT", valueText, "RIGHT", 4, 0)
    descriptionText:SetText(description)

    -- The template's value-changed callback also fires when the value is set from code, so
    -- `syncing` marks those refreshes to avoid saving them back as if the user had moved it.
    local syncing = false
    slider:Init(getValue() or minValue, minValue, maxValue, math.floor((maxValue - minValue) / step + 0.5), {})
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(formatValue(value))
        if not syncing then
            setValue(value)
        end
    end, slider)

    table.insert(refreshers, function()
        syncing = true
        slider:SetValue(getValue())
        syncing = false
        valueText:SetText(formatValue(getValue()))
        local enabled = not isEnabled or isEnabled()
        slider:SetEnabled(enabled)
        labelText:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
        valueText:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
    end)

    return slider
end

--- Add a color swatch that opens Blizzard's color picker (with opacity), with a label and
--- a short gray description to its right. Picking updates the color live; cancelling the
--- picker restores the color from before it was opened.
--- @param label string
--- @param description string
--- @param key string A key understood by api.Colors.
local function addColorSwatch(label, description, key)
    local swatch = CreateFrame("Button", nil, page)
    swatch:SetSize(22, 22)
    placeNext(swatch, 6, 22, 6)

    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.6, 0.6, 0.6, 1)

    local background = swatch:CreateTexture(nil, "BORDER")
    background:SetPoint("TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", -1, 1)
    background:SetColorTexture(0, 0, 0, 1)

    local color = swatch:CreateTexture(nil, "ARTWORK")
    color:SetPoint("TOPLEFT", 2, -2)
    color:SetPoint("BOTTOMRIGHT", -2, 2)

    swatch:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local labelText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    labelText:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
    labelText:SetText(label)

    local descriptionText = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    descriptionText:SetPoint("LEFT", labelText, "RIGHT", 10, 0)
    descriptionText:SetText(description)

    swatch:SetScript("OnClick", function()
        local r, g, b, a = api.Colors.Get(key)

        local function onColorChanged()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            api.Colors.Set(key, newR, newG, newB, ColorPickerFrame:GetColorAlpha())
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            opacity = a,
            hasOpacity = true,
            swatchFunc = onColorChanged,
            opacityFunc = onColorChanged,
            cancelFunc = function() api.Colors.Set(key, r, g, b, a) end,
        })
    end)

    table.insert(refreshers, function()
        color:SetColorTexture(api.Colors.Get(key))
    end)
end

beginTab("General")

addHeader("Compass banner")

addCheckbox(
    "Show compass banner", "Show or hide the compass banner.",
    api.CompassBanner.IsShown,
    function(shown)
        if shown then _p.enableCompassBanner() else _p.disableCompassBanner() end
    end
)

addCheckbox(
    "Lock position", "Lock the banner in place, or unlock it to drag to a new position.",
    api.CompassBanner.IsLocked,
    function(locked)
        if locked then api.CompassBanner.Lock() else api.CompassBanner.Unlock() end
    end,
    api.CompassBanner.IsShown,
    INDENT
)

addButton("Reset position", "Reset the compass banner to its default position.", function()
    api.CompassBanner.ResetPosition()
end)

addDropdown("Compass detail", "How much compass detail to show.", {
    { value = DetailLevel.None, label = "None", description = "Hide compass detail entirely." },
    { value = DetailLevel.Cardinals, label = "Cardinals", description = "Cardinal directions only (N, E, S, W)." },
    { value = DetailLevel.Intercardinals, label = "Intercardinals", description = "Cardinal and intercardinal directions." },
    { value = DetailLevel.Pips, label = "Pips", description = "Cardinal, intercardinal, and a tick every 15 degrees." },
}, api.CardinalPoints.GetDetail, api.CardinalPoints.SetDetail)

addHeader("SuperTracking")

addCheckbox(
    "Enable tracking", "Show a marker for whatever you're currently super-tracking.",
    api.SuperTracking.IsEnabled,
    function(enabled)
        if enabled then api.SuperTracking.Enable() else api.SuperTracking.Disable() end
    end
)

addCheckbox(
    "Show distance", "Show the distance to the super-tracked target.",
    api.SuperTracking.GetShowDistance, api.SuperTracking.SetShowDistance,
    api.SuperTracking.IsEnabled,
    INDENT
)

addCheckbox(
    "Show ETA", "Show an estimated time of arrival to the super-tracked target.",
    api.SuperTracking.GetShowETA, api.SuperTracking.SetShowETA,
    api.SuperTracking.IsEnabled,
    INDENT
)

addCheckbox(
    "Point at edge", "Turn the marker to point sideways when the target is out of view.",
    api.SuperTracking.GetRotateAtEdge, api.SuperTracking.SetRotateAtEdge,
    api.SuperTracking.IsEnabled,
    INDENT
)

addSlider(
    "Hide when within", "Fade out the marker this close to the target.",
    0, 100, 1,
    api.SuperTracking.GetHideDistance, api.SuperTracking.SetHideDistance,
    function(yards) return yards == 0 and "Never" or (yards .. " yds") end,
    api.SuperTracking.IsEnabled,
    INDENT
)

addCheckbox(
    "Hide inside quest area", "Fade out the marker inside the tracked quest's objective area.",
    api.SuperTracking.GetHideInQuestArea, api.SuperTracking.SetHideInQuestArea,
    api.SuperTracking.IsEnabled,
    INDENT
)

beginTab("Colors")

addHeader("Compass")

addColorSwatch("Cardinal letters", "N, E, S and W.", "cardinals")
addColorSwatch("Intercardinal letters", "NE, SE, SW and NW.", "intercardinals")
addColorSwatch("Tick marks", "The ticks every 15 degrees.", "ticks")
addColorSwatch("Center line", "The \"straight ahead\" line.", "centerLine")

addButton("Reset colors", "Restore the default compass colors.", function()
    api.Colors.ResetAll()
end)

selectTab(1)

optionsFrame:SetScript("OnShow", refreshAll)
refreshAll()

-- Keep the panel in sync when a setting changes some other way (slash command, addon
-- compartment, Events.lua auto-hiding the banner in instances) while it's open.
_p.refreshSettingsPanel = function()
    if optionsFrame:IsVisible() then
        refreshAll()
    end
end
