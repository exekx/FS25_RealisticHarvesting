-- ============================================================================
-- RHM_HarvestSyncInitialEvent.lua
-- Realistic Harvesting Mod - Initial Full Farm State Sync Event
-- ============================================================================
-- Technical architecture:
--   Transmits full farm telemetry data (currentTrip, fleetStats, seasonHistory,
--   farmSettings) to a client upon joining or farm switch.
--   Runs Server -> Client.
-- ============================================================================

RHM_HarvestSyncInitialEvent = {}
local HarvestSyncInitialEvent_mt = Class(RHM_HarvestSyncInitialEvent, Event)

InitEventClass(RHM_HarvestSyncInitialEvent, "RHM_HarvestSyncInitialEvent")

function RHM_HarvestSyncInitialEvent.emptyNew()
    return Event.new(HarvestSyncInitialEvent_mt)
end

function RHM_HarvestSyncInitialEvent.new(farmId, farmData)
    local self = RHM_HarvestSyncInitialEvent.emptyNew()
    self.farmId = farmId or 1
    self.farmData = farmData
    return self
end

function RHM_HarvestSyncInitialEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.farmId)

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    local farm = self.farmData or (tracker and tracker:getFarmData(self.farmId))
    if not farm then
        farm = tracker and tracker:createDefaultFarmData() or {}
    end

    -- Current Trip
    local trip = farm.currentTrip or {}
    streamWriteInt32(streamId, trip.fieldId or 0)
    streamWriteString(streamId, trip.cropName or "UNKNOWN")
    streamWriteInt32(streamId, trip.fillTypeIndex or FillType.UNKNOWN)
    streamWriteFloat32(streamId, trip.harvestedLiters or 0)
    streamWriteFloat32(streamId, trip.harvestedMassKg or 0)
    streamWriteFloat32(streamId, trip.harvestedAreaHa or 0)
    streamWriteFloat32(streamId, trip.lostLiters or 0)
    streamWriteFloat32(streamId, trip.lossMoney or 0)
    streamWriteFloat32(streamId, trip.sessionDuration or 0)
    streamWriteString(streamId, trip.efficiencyRank or "A")

    local reasons = trip.reasons or {}
    streamWriteFloat32(streamId, reasons.speed or 0)
    streamWriteFloat32(streamId, reasons.moisture or 0)
    streamWriteFloat32(streamId, reasons.wear or 0)
    streamWriteFloat32(streamId, reasons.slope or 0)

    -- Farm Settings
    local set = farm.farmSettings or {}
    streamWriteBool(streamId, set.aiSpeedLimiter ~= false)
    streamWriteFloat32(streamId, set.aiMaxLossPct or 2.0)
    streamWriteBool(streamId, set.volunteerCrops ~= false)
    streamWriteBool(streamId, set.autoResetOnFieldChange == true)

    -- Fleet Stats count & entries (capped at 30)
    local fleet = farm.fleetStats or {}
    local fleetList = {}
    for key, v in pairs(fleet) do
        table.insert(fleetList, { key = key, name = v.name or "Harvester", workSeconds = v.workSeconds or 0, totalHarvested = v.totalHarvested or 0, totalLost = v.totalLost or 0 })
        if #fleetList >= 30 then break end
    end
    streamWriteUInt16(streamId, #fleetList)
    for _, v in ipairs(fleetList) do
        streamWriteString(streamId, v.key)
        streamWriteString(streamId, v.name)
        streamWriteFloat32(streamId, v.workSeconds)
        streamWriteFloat32(streamId, v.totalHarvested)
        streamWriteFloat32(streamId, v.totalLost)
    end

    -- Season History count & entries (capped at 20)
    local history = farm.seasonHistory or {}
    local histCount = math.min(#history, 20)
    streamWriteUInt16(streamId, histCount)
    for i = 1, histCount do
        local h = history[i]
        streamWriteUInt16(streamId, h.year or 1)
        streamWriteInt32(streamId, h.fieldId or 0)
        streamWriteString(streamId, h.cropName or "UNKNOWN")
        streamWriteFloat32(streamId, h.harvested or 0)
        streamWriteFloat32(streamId, h.lost or 0)
        streamWriteFloat32(streamId, h.lossMoney or 0)
        streamWriteFloat32(streamId, h.areaHa or 0)
        streamWriteString(streamId, h.efficiencyRank or "A")
        streamWriteString(streamId, h.dominantReason or "speed")
    end
end

function RHM_HarvestSyncInitialEvent:readStream(streamId, connection)
    self.farmId = streamReadUInt8(streamId)

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if not tracker then return end
    local farm = tracker:getFarmData(self.farmId)

    -- Current Trip
    local trip = farm.currentTrip
    trip.fieldId = streamReadInt32(streamId)
    trip.cropName = streamReadString(streamId)
    trip.fillTypeIndex = streamReadInt32(streamId)
    trip.harvestedLiters = streamReadFloat32(streamId)
    trip.harvestedMassKg = streamReadFloat32(streamId)
    trip.harvestedAreaHa = streamReadFloat32(streamId)
    trip.lostLiters = streamReadFloat32(streamId)
    trip.lossMoney = streamReadFloat32(streamId)
    trip.sessionDuration = streamReadFloat32(streamId)
    trip.efficiencyRank = streamReadString(streamId)

    trip.reasons = trip.reasons or {}
    trip.reasons.speed = streamReadFloat32(streamId)
    trip.reasons.moisture = streamReadFloat32(streamId)
    trip.reasons.wear = streamReadFloat32(streamId)
    trip.reasons.slope = streamReadFloat32(streamId)

    -- Farm Settings
    local set = farm.farmSettings
    set.aiSpeedLimiter = streamReadBool(streamId)
    set.aiMaxLossPct = streamReadFloat32(streamId)
    set.volunteerCrops = streamReadBool(streamId)
    set.autoResetOnFieldChange = streamReadBool(streamId)

    -- Fleet Stats
    local fleetCount = streamReadUInt16(streamId)
    farm.fleetStats = {}
    for _ = 1, fleetCount do
        local key = streamReadString(streamId)
        local name = streamReadString(streamId)
        local workSeconds = streamReadFloat32(streamId)
        local totalHarvested = streamReadFloat32(streamId)
        local totalLost = streamReadFloat32(streamId)
        farm.fleetStats[key] = {
            name = name,
            workSeconds = workSeconds,
            totalHarvested = totalHarvested,
            totalLost = totalLost
        }
    end

    -- Season History
    local histCount = streamReadUInt16(streamId)
    farm.seasonHistory = {}
    for _ = 1, histCount do
        table.insert(farm.seasonHistory, {
            year = streamReadUInt16(streamId),
            fieldId = streamReadInt32(streamId),
            cropName = streamReadString(streamId),
            harvested = streamReadFloat32(streamId),
            lost = streamReadFloat32(streamId),
            lossMoney = streamReadFloat32(streamId),
            areaHa = streamReadFloat32(streamId),
            efficiencyRank = streamReadString(streamId),
            dominantReason = streamReadString(streamId)
        })
    end

    self:run(connection)
end

function RHM_HarvestSyncInitialEvent:run(connection)
    -- Notify GUI of fresh initial state if open
    if g_realisticHarvestManager and g_realisticHarvestManager.harvestHistoryGUI and g_realisticHarvestManager.harvestHistoryGUI.isOpen then
        g_realisticHarvestManager.harvestHistoryGUI:refreshCurrentPage()
    end
end
