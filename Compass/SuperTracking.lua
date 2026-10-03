-- SuperTracking manages the SuperTracking icon on the compass banner.

local _, addon = ...
local _p = addon.private
local api = addon.API

local bind = _p.bind

-- Cache global references
local deg = math.deg
local print = print
local GetUnitSpeed = GetUnitSpeed
-- Secret values are a retail 12.x feature; treat everything as readable on a client without them.
local issecretvalue = issecretvalue or function() return false end

local Enum = Enum

local Map = C_Map
local GetUserWaypoint = Map.GetUserWaypoint
local GetBestMapForUnit = Map.GetBestMapForUnit
local GetPlayerMapPosition = Map.GetPlayerMapPosition

local QuestLog = C_QuestLog
local QuestLogGetNextWaypoint = QuestLog.GetNextWaypoint
local RequestLoadQuestByID = QuestLog.RequestLoadQuestByID
local SetMapForQuestPOIs = QuestLog.SetMapForQuestPOIs
local GetQuestsOnMap = QuestLog.GetQuestsOnMap

local SuperTrack = C_SuperTrack
local IsSuperTrackingAnything = SuperTrack.IsSuperTrackingAnything
local GetHighestPrioritySuperTrackingType = SuperTrack.GetHighestPrioritySuperTrackingType
local GetSuperTrackedQuestID = SuperTrack.GetSuperTrackedQuestID
local GetSuperTrackedMapPin = SuperTrack.GetSuperTrackedMapPin
local GetSuperTrackedVignette = SuperTrack.GetSuperTrackedVignette

local GetVignettePosition = C_VignetteInfo.GetVignettePosition

local Navigation = C_Navigation
local GetNextWaypointForMap = Navigation.GetNextWaypointForMap

local AreaPoiInfo = C_AreaPoiInfo
local GetAreaPOIInfo = AreaPoiInfo.GetAreaPOIInfo

local TaxiMap = C_TaxiMap
local GetTaxiNodesForMap = TaxiMap.GetTaxiNodesForMap

local DeathInfo = C_DeathInfo
local GetCorpseMapPosition = DeathInfo.GetCorpseMapPosition

local hbd = LibStub("HereBeDragons-2.0")
assert(hbd, "HereBeDragons-2.0 is required by the Wayfinder SuperTracking module")
addon.Dependencies["HereBeDragons-2.0"] = hbd

local GetPlayerWorldPosition = bind(hbd, hbd.GetPlayerWorldPosition)
local GetWorldVector = bind(hbd, hbd.GetWorldVector)
local GetWorldCoordinatesFromZone = bind(hbd, hbd.GetWorldCoordinatesFromZone)

-- forward declarations
local trackingFunctions
local updateSuperTrackingIcon
local superTrackingElement
local updateSuperTrackingReadout
local updateMarkerFade

-- Within this many yards of the target (user-configurable; 0 = never), the marker and its
-- distance/ETA readout fade out. Wayfinder's destination can be a few yards off from where
-- Blizzard draws its in-world marker (e.g. a quest's map pin, when there's no navigation
-- waypoint while standing in the objective area), which barely matters from a distance but
-- makes the direction meaningless up close - it could point sideways or behind the player
-- while they're standing on the target. Blizzard's own marker is right there by then.
local hideDistance = _p.getOrSetDefault("hideDistance", 25)
-- Also fade out while standing inside the super-tracked quest's objective area (its "blob"
-- on the map), which is exactly where the quest's map pin - the fallback destination for
-- quests without a navigation waypoint - is least useful as a direction.
local hideInQuestArea = _p.getOrSetDefault("hideInQuestArea", true)

local IsInsideQuestBlob = C_Minimap.IsInsideQuestBlob

--- Whether the player is inside the objective area of the quest being super-tracked.
--- @return boolean
local function isInsideTrackedQuestArea()
    if GetHighestPrioritySuperTrackingType() ~= Enum.SuperTrackingType.Quest then return false end
    local questID = GetSuperTrackedQuestID()
    if not questID then return false end
    local inside = IsInsideQuestBlob(questID)
    return inside == true
end
-- How long, in seconds, the marker takes to fade fully out (or back in).
local MARKER_FADE_DURATION = 0.5

local markerAlpha = 1
local lastFadeTime = nil

local GetNavigationDistance = Navigation.GetDistance

--- Blizzard's own distance to its in-world navigation marker, which is exact, unlike the
--- distance computed from Wayfinder's destination coordinates.
--- @return number|nil distance In yards, or nil when there's no usable value.
local function getNavigationDistance()
    local distance = GetNavigationDistance()
    if distance and not issecretvalue(distance) and distance > 0 then
        return distance
    end
end

-- The navigation distance is refreshed on the same schedule Waypoint UI uses, so the two
-- addons' readouts change in step: every frame while the player is moving, and every
-- STILL_DISTANCE_INTERVAL seconds while they're standing still. (The compass itself still
-- updates every frame, since turning in place moves the marker.)
local STILL_DISTANCE_INTERVAL = 0.1
local isPlayerMoving = IsPlayerMoving()
local cachedNavigationDistance = nil
local lastNavigationDistanceTime = nil

--- The navigation distance, refreshed every frame while moving or every
--- STILL_DISTANCE_INTERVAL seconds while standing still.
--- @return number|nil distance In yards, or nil when there's no usable value.
local function getReadoutDistance()
    local now = GetTime()
    if isPlayerMoving or not lastNavigationDistanceTime
        or now - lastNavigationDistanceTime >= STILL_DISTANCE_INTERVAL then
        cachedNavigationDistance = getNavigationDistance()
        lastNavigationDistanceTime = now
    end
    return cachedNavigationDistance
end

local movementEvents = CreateFrame("Frame")
movementEvents:RegisterEvent("PLAYER_STARTED_MOVING")
movementEvents:RegisterEvent("PLAYER_STOPPED_MOVING")
movementEvents:RegisterEvent("PLAYER_IS_GLIDING_CHANGED")
movementEvents:RegisterEvent("SUPER_TRACKING_CHANGED")
movementEvents:SetScript("OnEvent", function(_, event)
    if event == "SUPER_TRACKING_CHANGED" then
        -- New target: don't show the old target's distance until the next refresh.
        lastNavigationDistanceTime = nil
    else
        isPlayerMoving = IsPlayerMoving()
    end
end)

--- Resolve the world-map coordinates of whatever is currently super-tracked.
--- Tries C_Navigation.GetNextWaypointForMap first, since that's the unified API
--- Blizzard's own navigation UI (Blizzard_QuestNavigation) uses for the current
--- super-tracked target regardless of type. Falls back to the per-type handlers
--- in trackingFunctions for anything that API doesn't cover.
local function superTrackingDestination()
    local map = GetBestMapForUnit("player")
    if map then
        local x, y = GetNextWaypointForMap(map)
        if x and y then
            return GetWorldCoordinatesFromZone(x, y, map)
        end
    end

    local trackingType = GetHighestPrioritySuperTrackingType()
    if not trackingType then return end

    local trackingFunction = trackingFunctions[trackingType]
    if not trackingFunction then return end

    return trackingFunction()
end

--- Callback for the SuperTracking element on the compass banner.
local function superTrackingCallback()
    if not IsSuperTrackingAnything() then
        updateSuperTrackingReadout(nil)
        return
    end

    updateSuperTrackingIcon()

    local playerX, playerY, instanceId = GetPlayerWorldPosition()
    if not (playerX and playerY and instanceId) then
        updateSuperTrackingReadout(nil)
        return
    end

    local destX, destY = superTrackingDestination()
    if not (destX and destY) then
        updateSuperTrackingReadout(nil)
        return
    end

    local angle, distance = GetWorldVector(instanceId, playerX, playerY, destX, destY)
    if not angle then
        updateSuperTrackingReadout(nil)
        return
    end

    distance = getReadoutDistance() or distance
    updateMarkerFade(
        (hideDistance > 0 and distance <= hideDistance)
        or (hideInQuestArea and isInsideTrackedQuestArea())
    )

    updateSuperTrackingReadout(distance)

    -- Returning no angle hides the marker once it's fully faded out; see hideDistance.
    if markerAlpha <= 0 then return end

    return 360 - deg(angle)
end

local function functionNotImplemented() end

-- GetNextWaypoint can legitimately return nothing until the quest's full data has
-- been requested and the active map for quest POIs has been set - normally done by
-- the quest log/map UI, which this addon never opens. RequestLoadQuestByID is async,
-- so only fire it once per quest and let the next update pick up the result.
local lastRequestedQuestID = nil

local function superTrackingQuest()
    local questID = GetSuperTrackedQuestID()
    if not questID then return nil, nil end

    if lastRequestedQuestID ~= questID then
        RequestLoadQuestByID(questID)
        lastRequestedQuestID = questID
    end

    local map = GetBestMapForUnit("player")
    if map then
        SetMapForQuestPOIs(map)
    end

    local mapID, x, y = QuestLogGetNextWaypoint(questID)
    if mapID and x and y then
        return GetWorldCoordinatesFromZone(x, y, mapID)
    end

    -- Fall back to the quest's map pin (the older POI system, used to place a single
    -- marker on the map/minimap) since GetNextWaypoint's pathing data may not exist
    -- for older quest content.
    if map then
        local quests = GetQuestsOnMap(map)
        if quests then
            for _, poi in ipairs(quests) do
                if poi.questID == questID then
                    return GetWorldCoordinatesFromZone(poi.x, poi.y, poi.mapID)
                end
            end
        end
    end

    return nil, nil
end

local function superTrackingUserWaypoint()
    local point = GetUserWaypoint()
    return GetWorldCoordinatesFromZone(point.position.x, point.position.y, point.uiMapID)
end

local function handleAreaPOI(map, typeId)
    local info = GetAreaPOIInfo(map, typeId)
    if not info then return end
    local x, y = info.position:GetXY()
    return GetWorldCoordinatesFromZone(x, y, map)
end

local function handleTaxiNode(map, typeId)
    local nodes = GetTaxiNodesForMap(map)
    for _, node in ipairs(nodes) do
        if node.nodeID == typeId then
            return GetWorldCoordinatesFromZone(node.position.x, node.position.y, map)
        end
    end
end

--- Get the world coordinates of the player's own corpse, if it's on their current map.
local function superTrackingCorpse()
    local map = GetBestMapForUnit("player")
    if not map then return end

    local position = GetCorpseMapPosition(map)
    if not position then return end

    local x, y = position:GetXY()
    return GetWorldCoordinatesFromZone(x, y, map)
end

--- Get the world coordinates of the super-tracked vignette (a rare, treasure, etc.), if
--- it's on the player's current map. GetVignettePosition only accepts a "secret" GUID from
--- untainted (Blizzard) code, so a secret GUID is skipped, and the call is guarded in
--- case the game refuses it anyway.
local function superTrackingVignette()
    local vignetteGUID = GetSuperTrackedVignette()
    if not vignetteGUID or issecretvalue(vignetteGUID) then return end

    local map = GetBestMapForUnit("player")
    if not map then return end

    local ok, position = pcall(GetVignettePosition, vignetteGUID, map)
    if not (ok and position) then return end

    local x, y = position:GetXY()
    if issecretvalue(x) or issecretvalue(y) then return end
    return GetWorldCoordinatesFromZone(x, y, map)
end

local mapPinTrackingFunctions = {
    [Enum.SuperTrackingMapPinType.AreaPOI] = handleAreaPOI,
    [Enum.SuperTrackingMapPinType.QuestOffer] = functionNotImplemented,
    [Enum.SuperTrackingMapPinType.TaxiNode] = handleTaxiNode,
    [Enum.SuperTrackingMapPinType.DigSite] = functionNotImplemented,
}

--- Get the world coordinates for the SuperTracking map pin.
--- @return number|nil, number|nil The x and y coordinates of the map pin.
local function superTrackingMapPin()
    local pinType, typeId = GetSuperTrackedMapPin()
    if not (pinType and typeId) then return end

    local map = GetBestMapForUnit("player")
    if not map then return end

    local mapPinTrackingFunction = mapPinTrackingFunctions[pinType]
    if not mapPinTrackingFunction then return end

    return mapPinTrackingFunction(map, typeId)
end

trackingFunctions = {
    [Enum.SuperTrackingType.Quest] = superTrackingQuest,
    [Enum.SuperTrackingType.UserWaypoint] = superTrackingUserWaypoint,
    [Enum.SuperTrackingType.Corpse] = superTrackingCorpse,
    [Enum.SuperTrackingType.Scenario] = functionNotImplemented,
    [Enum.SuperTrackingType.Content] = functionNotImplemented,
    [Enum.SuperTrackingType.PartyMember] = functionNotImplemented,
    [Enum.SuperTrackingType.MapPin] = superTrackingMapPin,
    [Enum.SuperTrackingType.Vignette] = superTrackingVignette,
}

-- SuperTrackedFrame belongs to the on-demand Blizzard_QuestNavigation module, so it may not
-- exist yet at addon load time. Its icon is also an atlas texture (Navigation-Tracked-Icon),
-- not a plain image file, so it has to be copied with GetAtlas/SetAtlas rather than
-- GetTexture/SetTexCoord.
local SuperTrackedFrame = SuperTrackedFrame
local superTrackingMarker = nil
local superTrackingDistanceText = nil
local superTrackingETAText = nil
local superTrackingIconAtlas = nil

local showTrackingDistance = _p.getOrSetDefault("showTrackingDistance", true)
local showTrackingETA = _p.getOrSetDefault("showTrackingETA", true)
local trackingEnabled = _p.getOrSetDefault("trackingEnabled", true)
-- Whether the marker turns to point sideways when it's pinned at the edge of the banner.
local rotateAtEdge = _p.getOrSetDefault("rotateAtEdge", true)

--- Apply whether the marker rotates when pinned at the banner's edge: only if the user
--- wants it, and never for a tombstone (corpse tracking), which has no inherent direction,
--- unlike the arrow/flag icons used for everything else.
local function applyRotateAtEdge()
    local trackingType = GetHighestPrioritySuperTrackingType()
    api.SetElementRotateWhenSticky(
        superTrackingElement,
        rotateAtEdge and trackingType ~= Enum.SuperTrackingType.Corpse
    )
end

--- Apply the live SuperTracking icon to our marker. Retries each update until
--- SuperTrackedFrame is available (starting SuperTracking is what creates it), and
--- re-applies whenever the atlas itself changes, since Blizzard uses a different icon
--- per tracking type (e.g. a tombstone for a corpse vs. a waypoint flag for a quest).
updateSuperTrackingIcon = function()
    local superTrackedIcon = SuperTrackedFrame and SuperTrackedFrame.Icon
    local atlas = superTrackedIcon and superTrackedIcon:GetAtlas()
    if not atlas or atlas == superTrackingIconAtlas then return end

    superTrackingMarker:SetAtlas(atlas, true)
    superTrackingIconAtlas = atlas

    applyRotateAtEdge()
end

--- Anchor the ETA text below the distance text when distance is shown, or directly
--- below the marker when it isn't, so disabling the distance readout doesn't leave a
--- blank gap above an otherwise still-enabled ETA line.
local function updateSuperTrackingETAAnchor()
    superTrackingETAText:ClearAllPoints()
    if showTrackingDistance then
        superTrackingETAText:SetPoint("TOP", superTrackingDistanceText, "BOTTOM", 0, -2)
    else
        superTrackingETAText:SetPoint("TOP", superTrackingMarker, "BOTTOM", 0, -2)
    end
end

--- Step the marker's fade toward fully out (arrived) or fully in, by however much time
--- has passed since the last update, fading the readout text along with it.
--- @param arrived boolean Whether the player is within hideDistance of the target.
updateMarkerFade = function(arrived)
    local now = GetTime()
    -- Capped so a long gap between updates (banner hidden, tracking off) doesn't skip the fade.
    local elapsed = lastFadeTime and math.min(now - lastFadeTime, 0.1) or 0
    lastFadeTime = now

    local step = elapsed / MARKER_FADE_DURATION
    if arrived then
        markerAlpha = math.max(0, markerAlpha - step)
    else
        markerAlpha = math.min(1, markerAlpha + step)
    end
    superTrackingMarker:SetAlpha(markerAlpha)
    superTrackingDistanceText:SetAlpha(markerAlpha)
    superTrackingETAText:SetAlpha(markerAlpha)
end

--- Create the SuperTracking marker for the compass banner
local function createSuperTrackingMarker(frame)
    if superTrackingMarker then return superTrackingMarker end

    -- The marker and its readout live on a child frame one level above the banner, so they
    -- draw over the compass labels (N, NE, E, ...), ticks and center line. Layers and
    -- sublevels alone can't do this: within a single frame, font strings (the labels) always
    -- draw above textures (the marker) in the same layer.
    local layer = CreateFrame("Frame", nil, frame)
    layer:SetAllPoints(frame)
    layer:SetFrameLevel(frame:GetFrameLevel() + 1)

    local marker = layer:CreateTexture(nil, "OVERLAY")
    marker:SetSize(25, 25)
    superTrackingMarker = marker

    local distanceText = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    distanceText:SetPoint("TOP", marker, "BOTTOM", 0, -2)
    distanceText:Hide()
    superTrackingDistanceText = distanceText

    local etaText = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    etaText:Hide()
    superTrackingETAText = etaText
    updateSuperTrackingETAAnchor()

    return marker
end

--- Format a distance the same way Waypoint UI does, so the two addons show identical
--- numbers side by side: round up to a whole yard, with thousands separators (e.g. "1,234").
--- @param distance number
--- @return string
local function formatDistance(distance)
    return BreakUpLargeNumbers(math.ceil(distance))
end

--- Format a countdown of seconds the same way Waypoint UI does, so the two addons read
--- the same side by side: hours, minutes and seconds, leaving out any part that's zero
--- (e.g. "45s", "2m", "2m 10s", "1h 15m 30s").
--- @param seconds number
--- @return string
local function formatETA(seconds)
    seconds = math.floor(seconds + 0.5)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    local parts = {}
    if hours > 0 then table.insert(parts, hours .. "h") end
    if minutes > 0 then table.insert(parts, minutes .. "m") end
    if secs > 0 then table.insert(parts, secs .. "s") end
    return table.concat(parts, " ")
end

-- ETA estimation. Rather than the player's raw movement speed (GetUnitSpeed), which counts
-- movement in any direction and is a "secret" value in combat, the ETA uses the player's
-- closing speed: how fast the distance to the target is actually shrinking, sampled about
-- once a second and smoothed with an exponential moving average. Sideways movement, going
-- around obstacles and moving away all count only for the progress they really make.
-- This mirrors the method Waypoint UI uses, so the two agree.
local ETA_SAMPLE_INTERVAL = 1 -- seconds between distance samples
local ETA_SMOOTHING = 0.2 -- weight of each new sample in the moving average
local ETA_MIN_PROGRESS = 0.25 -- yards; smaller changes are treated as noise
local ETA_MIN_SPEED = 0.5 -- yards per second; slower than this, no estimate
local ETA_MAX_SECONDS = 86400

local etaLastDistance = nil
local etaLastTime = nil
local etaAverageSpeed = nil
local etaSeconds = nil -- nil when there's no usable estimate

--- Forget all ETA samples, e.g. when the super-tracked target changes.
local function resetETA()
    etaLastDistance, etaLastTime, etaAverageSpeed, etaSeconds = nil, nil, nil, nil
end

--- Feed the current distance into the ETA estimate.
--- @param distance number Distance to the super-tracked target, in yards.
local function updateETA(distance)
    if distance <= 0 then
        resetETA()
        etaSeconds = 0
        return
    end

    local now = GetTime()
    if not etaLastDistance then
        etaLastDistance, etaLastTime = distance, now
        return
    end

    local elapsed = now - etaLastTime
    if elapsed < ETA_SAMPLE_INTERVAL then return end

    local progress = etaLastDistance - distance
    etaLastDistance, etaLastTime = distance, now

    -- Standing still or moving away: no estimate until progress resumes.
    if progress <= 0 then
        etaSeconds = nil
        return
    end
    if progress < ETA_MIN_PROGRESS then return end

    local closingSpeed = progress / elapsed
    etaAverageSpeed = etaAverageSpeed and (etaAverageSpeed + ETA_SMOOTHING * (closingSpeed - etaAverageSpeed))
        or closingSpeed

    if etaAverageSpeed <= ETA_MIN_SPEED then
        etaSeconds = nil
        return
    end

    etaSeconds = distance / etaAverageSpeed
    if etaSeconds > ETA_MAX_SECONDS then etaSeconds = nil end
end

local etaEvents = CreateFrame("Frame")
etaEvents:RegisterEvent("SUPER_TRACKING_CHANGED")
etaEvents:SetScript("OnEvent", resetETA)

--- Show the distance and/or ETA to the super-tracked target below the marker (ETA below
--- distance), or hide each independently when there's nothing to show or its readout is
--- turned off. Distance uses Blizzard's own localized IN_GAME_NAVIGATION_RANGE string
--- (the same one SuperTrackedFrame uses) rather than a hardcoded unit suffix, since the
--- label isn't the same in every locale.
--- @param distance number|nil Distance to the super-tracked target, in yards.
updateSuperTrackingReadout = function(distance)
    if distance then
        updateETA(distance)
    end

    if distance and showTrackingDistance then
        superTrackingDistanceText:SetText(IN_GAME_NAVIGATION_RANGE:format(formatDistance(distance)))
        superTrackingDistanceText:Show()
    else
        superTrackingDistanceText:Hide()
    end

    -- Like Waypoint UI, the ETA line only appears while there's an estimate to show.
    if distance and showTrackingETA and etaSeconds and etaSeconds >= 0.5 then
        superTrackingETAText:SetText(formatETA(etaSeconds))
        superTrackingETAText:Show()
    else
        superTrackingETAText:Hide()
    end
end

local date = date

-- SavedVariable: a rolling log of debug snapshots, written to disk on logout/reload,
-- so output can be read from the SavedVariables file instead of copy-pasting chat.
WayfinderDebug = WayfinderDebug or {}
local MAX_DEBUG_ENTRIES = 20

--- Join args into one line the same way multi-arg print() displays them, tolerating nils
--- and secret values (tostring() on a secret value throws, just like arithmetic does).
local function toLine(...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do
        local value = select(i, ...)
        parts[i] = issecretvalue(value) and "<secret>" or tostring(value)
    end
    return table.concat(parts, " ")
end

--- Gather diagnostic info about the SuperTracking chain, passing each line to `out`.
--- @param out function
local function collectSuperTrackingDebug(out)
    out("Wayfinder SuperTracking debug:")
    out(" IsSuperTrackingAnything:", IsSuperTrackingAnything())

    local playerX, playerY, instanceId = GetPlayerWorldPosition()
    out(" GetPlayerWorldPosition:", playerX, playerY, instanceId)

    -- tostring() on a secret value throws just like arithmetic does, so it has to be
    -- checked before printing rather than passed straight to out()/print().
    local speed = GetUnitSpeed("player")
    out(" GetUnitSpeed(player):", issecretvalue(speed) and "<secret>" or speed)
    out(" ETA (average closing speed, seconds):", etaAverageSpeed, etaSeconds)

    local map = GetBestMapForUnit("player")
    out(" GetBestMapForUnit:", map)
    if map then
        local x, y, waypointDescription = GetNextWaypointForMap(map)
        out(" GetNextWaypointForMap (x, y, description):", x, y, waypointDescription)
    end

    local trackingType = GetHighestPrioritySuperTrackingType()
    out(" GetHighestPrioritySuperTrackingType:", trackingType)

    if trackingType == Enum.SuperTrackingType.Quest then
        local questID = GetSuperTrackedQuestID()
        out(" GetSuperTrackedQuestID:", questID)
        if questID then
            RequestLoadQuestByID(questID)
            if map then SetMapForQuestPOIs(map) end
            local qMapID, qx, qy = QuestLogGetNextWaypoint(questID)
            out(" raw QuestLogGetNextWaypoint (mapID, x, y):", qMapID, qx, qy)

            if map then
                local quests = GetQuestsOnMap(map)
                out(" GetQuestsOnMap count:", quests and #quests)
                local found = false
                if quests then
                    for _, poi in ipairs(quests) do
                        if poi.questID == questID then
                            out(" GetQuestsOnMap match (mapID, x, y):", poi.mapID, poi.x, poi.y)
                            found = true
                        end
                    end
                end
                if not found then
                    out(" GetQuestsOnMap: no entry for this questID")
                end
            end
        end
    end

    local trackingFunction = trackingType and trackingFunctions[trackingType]
    out(" fallback trackingFunction found:", trackingFunction ~= nil)

    local ok, destX, destY = pcall(superTrackingDestination)
    out(" superTrackingDestination result (ok, destX, destY):", ok, destX, destY)

    if ok and destX and destY and playerX and playerY and instanceId then
        local angle, distance = GetWorldVector(instanceId, playerX, playerY, destX, destY)
        out(" GetWorldVector (angle, distance):", angle, distance)
        out(" player -> destination offset (dx, dy):", destX - playerX, destY - playerY)
    end

    -- Blizzard's own distance to its in-world navigation marker, for comparison with the
    -- distance Wayfinder computes above from map coordinates.
    out(" C_Navigation.GetDistance:", Navigation.GetDistance())
    out(" C_Navigation.GetTargetState:", Navigation.GetTargetState())

    local facing = GetPlayerFacing()
    out(" GetPlayerFacing (radians, degrees):", facing, facing and not issecretvalue(facing) and deg(facing))

    out(" SuperTrackedFrame exists:", SuperTrackedFrame ~= nil)
    local icon = SuperTrackedFrame and SuperTrackedFrame.Icon
    out(" SuperTrackedFrame.Icon atlas:", icon and icon:GetAtlas())
    out(" superTrackingIconAtlas (last applied):", superTrackingIconAtlas)

    -- Sanity check: round-trip the player's own position through HereBeDragons'
    -- zone conversion. If this doesn't roughly match GetPlayerWorldPosition, HBD
    -- doesn't know how to convert coordinates for this map at all, regardless of
    -- which Blizzard API supplies a destination.
    if map then
        local selfPos = GetPlayerMapPosition(map, "player")
        out(" GetPlayerMapPosition on current map:", selfPos and selfPos.x, selfPos and selfPos.y)
        if selfPos then
            local wx, wy, wi = GetWorldCoordinatesFromZone(selfPos.x, selfPos.y, map)
            out(" GetWorldCoordinatesFromZone round-trip (wx, wy, wi):", wx, wy, wi)
        end
    end

    -- Also try resolving a plain user waypoint directly, if one is set, since it
    -- doesn't depend on quest data at all.
    local ok2, wpX, wpY = pcall(superTrackingUserWaypoint)
    out(" superTrackingUserWaypoint result (ok, x, y):", ok2, wpX, wpY)
end

--- Print diagnostic info about the SuperTracking chain, to help debug why no marker is showing.
--- Also records the same output as one entry in the WayfinderDebug SavedVariable. Any error
--- partway through is recorded too, so an entry is always saved.
local function debugSuperTracking()
    local lines = {}
    local function out(...)
        local line = toLine(...)
        print(line)
        table.insert(lines, line)
    end

    local ok, err = pcall(collectSuperTrackingDebug, out)
    if not ok then
        out(" ERROR while collecting debug info:", err)
    end

    table.insert(WayfinderDebug, { time = date("%Y-%m-%d %H:%M:%S"), lines = lines })
    while #WayfinderDebug > MAX_DEBUG_ENTRIES do
        table.remove(WayfinderDebug, 1)
    end

    print("Compass: debug entry saved (" .. #WayfinderDebug .. " total). /reload or log out to flush to disk.")
end
api.DebugSuperTracking = debugSuperTracking

local isSticky = true

superTrackingElement = api.AddElementToBanner(
    "SuperTracking",
    superTrackingCallback,
    createSuperTrackingMarker,
    isSticky
)
api.SetElementEnabled(superTrackingElement, trackingEnabled)

-- _p.refreshSettingsPanel is a no-op until Settings.lua has loaded, so it's
-- safe to call unconditionally below - it's how the options panel's checkboxes stay in
-- sync when these are changed via a slash command instead of the panel itself.
api.SuperTracking = {
    Enable = function()
        api.SetElementEnabled(superTrackingElement, true)
        trackingEnabled = true
        WayfinderSettings.trackingEnabled = true
        _p.refreshSettingsPanel()
    end,
    Disable = function()
        api.SetElementEnabled(superTrackingElement, false)
        updateSuperTrackingReadout(nil)
        trackingEnabled = false
        WayfinderSettings.trackingEnabled = false
        _p.refreshSettingsPanel()
    end,
    IsEnabled = function() return trackingEnabled end,
    SetShowDistance = function(shown)
        showTrackingDistance = shown
        WayfinderSettings.showTrackingDistance = shown
        updateSuperTrackingETAAnchor()
        _p.refreshSettingsPanel()
    end,
    GetShowDistance = function() return showTrackingDistance end,
    SetShowETA = function(shown)
        showTrackingETA = shown
        WayfinderSettings.showTrackingETA = shown
        _p.refreshSettingsPanel()
    end,
    GetShowETA = function() return showTrackingETA end,
    SetHideDistance = function(yards)
        hideDistance = yards
        WayfinderSettings.hideDistance = yards
        _p.refreshSettingsPanel()
    end,
    GetHideDistance = function() return hideDistance end,
    SetHideInQuestArea = function(hide)
        hideInQuestArea = hide
        WayfinderSettings.hideInQuestArea = hide
        _p.refreshSettingsPanel()
    end,
    GetHideInQuestArea = function() return hideInQuestArea end,
    SetRotateAtEdge = function(rotate)
        rotateAtEdge = rotate
        WayfinderSettings.rotateAtEdge = rotate
        applyRotateAtEdge()
        _p.refreshSettingsPanel()
    end,
    GetRotateAtEdge = function() return rotateAtEdge end,
}
