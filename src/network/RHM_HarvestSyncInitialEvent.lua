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

    streamWriteFloat32(streamId, trip.avgSpeedSum or 0)
    streamWriteUInt32(streamId, trip.avgSpeedCount or 0)
    streamWriteFloat32(streamId, trip.avgLoadSum or 0)
    streamWriteUInt32(streamId, trip.avgLoadCount or 0)
    streamWriteBool(streamId, trip.isActive == true)
    streamWriteBool(streamId, trip.isContract == true)
    streamWriteString(streamId, trip.lastMachineKey or "")

    -- Farm Settings
    local set = farm.farmSettings or {}
    streamWriteBool(streamId, set.aiSpeedLimiter ~= false)
    streamWriteFloat32(streamId, set.aiMaxLossPct or 2.0)
    streamWriteBool(streamId, set.volunteerCrops ~= false)
    streamWriteBool(streamId, set.autoResetOnFieldChange == true)

    -- Fleet Stats count & entries (capped at 30, exclude contract/mission combines)
    local fleet = farm.fleetStats or {}
    local fleetList = {}
    for key, v in pairs(fleet) do
        if not (RHM_HarvestTracker and RHM_HarvestTracker.isMissionCombine and RHM_HarvestTracker.isMissionCombine(nil, v.name, key)) then
            table.insert(fleetList, { key = key, name = v.name or "Harvester", workSeconds = v.workSeconds or 0, totalHarvested = v.totalHarvested or 0, totalLost = v.totalLost or 0 })
            if #fleetList >= 30 then break end
        end
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
        streamWriteBool(streamId, h.isContract == true)
    end

    -- Yearly Stats count & entries (capped at 20)
    local yearlyList = {}
    if farm.yearlyStats then
        for _, yStat in pairs(farm.yearlyStats) do
            table.insert(yearlyList, yStat)
            if #yearlyList >= 20 then break end
        end
    end
    streamWriteUInt16(streamId, #yearlyList)
    for _, yStat in ipairs(yearlyList) do
        streamWriteUInt16(streamId, yStat.year or 1)
        streamWriteFloat32(streamId, yStat.harvestedLiters or 0)
        streamWriteFloat32(streamId, yStat.harvestedMassKg or 0)
        streamWriteFloat32(streamId, yStat.harvestedAreaHa or 0)
        streamWriteFloat32(streamId, yStat.lostLiters or 0)
        streamWriteFloat32(streamId, yStat.lossMoney or 0)
        streamWriteFloat32(streamId, yStat.sessionDuration or 0)
        streamWriteFloat32(streamId, yStat.avgSpeedSum or 0)
        streamWriteUInt32(streamId, yStat.avgSpeedCount or 0)
        streamWriteFloat32(streamId, yStat.avgLoadSum or 0)
        streamWriteUInt32(streamId, yStat.avgLoadCount or 0)
        streamWriteUInt16(streamId, yStat.fieldOperations or 0)
    end

    -- Combine Trips count & entries (capped at 20)
    local cList = {}
    if farm.combineTrips then
        for machineKey, mTrip in pairs(farm.combineTrips) do
            table.insert(cList, { machineKey = machineKey, trip = mTrip })
            if #cList >= 20 then break end
        end
    end
    streamWriteUInt16(streamId, #cList)
    for _, item in ipairs(cList) do
        local mTrip = item.trip
        streamWriteString(streamId, item.machineKey)
        streamWriteInt32(streamId, mTrip.fieldId or 0)
        streamWriteString(streamId, mTrip.cropName or "--")
        streamWriteInt32(streamId, mTrip.fillTypeIndex or FillType.UNKNOWN)
        streamWriteFloat32(streamId, mTrip.harvestedLiters or 0)
        streamWriteFloat32(streamId, mTrip.harvestedMassKg or 0)
        streamWriteFloat32(streamId, mTrip.harvestedAreaHa or 0)
        streamWriteFloat32(streamId, mTrip.lostLiters or 0)
        streamWriteFloat32(streamId, mTrip.lossMoney or 0)
        streamWriteFloat32(streamId, mTrip.sessionDuration or 0)
        streamWriteString(streamId, mTrip.efficiencyRank or "A")
        streamWriteFloat32(streamId, mTrip.avgSpeedSum or 0)
        streamWriteUInt32(streamId, mTrip.avgSpeedCount or 0)
        streamWriteFloat32(streamId, mTrip.avgLoadSum or 0)
        streamWriteUInt32(streamId, mTrip.avgLoadCount or 0)
        local mReasons = mTrip.reasons or {}
        streamWriteFloat32(streamId, mReasons.speed or 0)
        streamWriteFloat32(streamId, mReasons.moisture or 0)
        streamWriteFloat32(streamId, mReasons.wear or 0)
        streamWriteFloat32(streamId, mReasons.slope or 0)
        streamWriteBool(streamId, mTrip.isActive == true)
        streamWriteBool(streamId, mTrip.isContract == true)
    end

    -- Field Stats count & entries (capped at 50)
    local fList = {}
    if farm.fieldStats then
        for fId, fStat in pairs(farm.fieldStats) do
            table.insert(fList, fStat)
            if #fList >= 50 then break end
        end
    end
    streamWriteUInt16(streamId, #fList)
    for _, fStat in ipairs(fList) do
        streamWriteInt32(streamId, fStat.fieldId or 0)
        streamWriteFloat32(streamId, fStat.harvestedLiters or 0)
        streamWriteFloat32(streamId, fStat.harvestedMassKg or 0)
        streamWriteFloat32(streamId, fStat.harvestedAreaHa or 0)
        streamWriteFloat32(streamId, fStat.lostLiters or 0)
        streamWriteFloat32(streamId, fStat.lossMoney or 0)
        streamWriteUInt16(streamId, fStat.operationsCount or 0)
        streamWriteBool(streamId, fStat.isContract == true)
        streamWriteString(streamId, fStat.lastCropName or "--")
        local fReasons = fStat.reasons or {}
        streamWriteFloat32(streamId, fReasons.speed or 0)
        streamWriteFloat32(streamId, fReasons.moisture or 0)
        streamWriteFloat32(streamId, fReasons.wear or 0)
        streamWriteFloat32(streamId, fReasons.slope or 0)
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

    trip.avgSpeedSum = streamReadFloat32(streamId)
    trip.avgSpeedCount = streamReadUInt32(streamId)
    trip.avgLoadSum = streamReadFloat32(streamId)
    trip.avgLoadCount = streamReadUInt32(streamId)
    trip.isActive = streamReadBool(streamId)
    trip.isContract = streamReadBool(streamId)
    local lmk = streamReadString(streamId)
    if lmk and lmk ~= "" then
        trip.lastMachineKey = lmk
    end

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
        if not (RHM_HarvestTracker and RHM_HarvestTracker.isMissionCombine and RHM_HarvestTracker.isMissionCombine(nil, name, key)) then
            farm.fleetStats[key] = {
                name = name,
                workSeconds = workSeconds,
                totalHarvested = totalHarvested,
                totalLost = totalLost
            }
        end
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
            dominantReason = streamReadString(streamId),
            isContract = streamReadBool(streamId)
        })
    end

    -- Yearly Stats
    local yearlyCount = streamReadUInt16(streamId)
    farm.yearlyStats = farm.yearlyStats or {}
    for _ = 1, yearlyCount do
        local y = streamReadUInt16(streamId)
        farm.yearlyStats[y] = {
            year = y,
            harvestedLiters = streamReadFloat32(streamId),
            harvestedMassKg = streamReadFloat32(streamId),
            harvestedAreaHa = streamReadFloat32(streamId),
            lostLiters = streamReadFloat32(streamId),
            lossMoney = streamReadFloat32(streamId),
            sessionDuration = streamReadFloat32(streamId),
            avgSpeedSum = streamReadFloat32(streamId),
            avgSpeedCount = streamReadUInt32(streamId),
            avgLoadSum = streamReadFloat32(streamId),
            avgLoadCount = streamReadUInt32(streamId),
            fieldOperations = streamReadUInt16(streamId),
            reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
            cropVolumes = {}
        }
    end

    -- Combine Trips
    local combineCount = streamReadUInt16(streamId)
    farm.combineTrips = farm.combineTrips or {}
    for _ = 1, combineCount do
        local machineKey = streamReadString(streamId)
        local mTrip = {
            fieldId = streamReadInt32(streamId),
            cropName = streamReadString(streamId),
            fillTypeIndex = streamReadInt32(streamId),
            harvestedLiters = streamReadFloat32(streamId),
            harvestedMassKg = streamReadFloat32(streamId),
            harvestedAreaHa = streamReadFloat32(streamId),
            lostLiters = streamReadFloat32(streamId),
            lossMoney = streamReadFloat32(streamId),
            sessionDuration = streamReadFloat32(streamId),
            efficiencyRank = streamReadString(streamId),
            avgSpeedSum = streamReadFloat32(streamId),
            avgSpeedCount = streamReadUInt32(streamId),
            avgLoadSum = streamReadFloat32(streamId),
            avgLoadCount = streamReadUInt32(streamId),
            reasons = {
                speed = streamReadFloat32(streamId),
                moisture = streamReadFloat32(streamId),
                wear = streamReadFloat32(streamId),
                slope = streamReadFloat32(streamId)
            },
            isActive = streamReadBool(streamId),
            isContract = streamReadBool(streamId)
        }
        farm.combineTrips[machineKey] = mTrip
    end

    -- Field Stats
    local fCount = streamReadUInt16(streamId)
    farm.fieldStats = farm.fieldStats or {}
    for _ = 1, fCount do
        local fId = streamReadInt32(streamId)
        farm.fieldStats[fId] = {
            fieldId = fId,
            harvestedLiters = streamReadFloat32(streamId),
            harvestedMassKg = streamReadFloat32(streamId),
            harvestedAreaHa = streamReadFloat32(streamId),
            sessionDuration = 0,
            lostLiters = streamReadFloat32(streamId),
            lossMoney = streamReadFloat32(streamId),
            operationsCount = streamReadUInt16(streamId),
            isContract = streamReadBool(streamId),
            lastCropName = streamReadString(streamId),
            lastCrop = "--",
            avgSpeedSum = 0,
            avgSpeedCount = 0,
            avgLoadSum = 0,
            avgLoadCount = 0,
            lastYear = 1,
            reasons = {
                speed = streamReadFloat32(streamId),
                moisture = streamReadFloat32(streamId),
                wear = streamReadFloat32(streamId),
                slope = streamReadFloat32(streamId)
            },
            cropVolumes = {}
        }
    end

    -- Link client combine specs if vehicles already spawned
    if g_currentMission then
        local vehicles = (g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles) or g_currentMission.vehicles
        if vehicles then
            for _, vehicle in pairs(vehicles) do
                if vehicle and type(vehicle) == "table" and vehicle.spec_rhm_Combine then
                    local vFarmId = (vehicle.getOwnerFarmId and vehicle:getOwnerFarmId()) or 1
                    if vFarmId == self.farmId and farm.combineTrips then
                        local machineKey = vehicle.configFileName or (vehicle.getFullName and vehicle:getFullName()) or "Harvester"
                        if farm.combineTrips[machineKey] then
                            vehicle.spec_rhm_Combine.trip = farm.combineTrips[machineKey]
                        end
                    end
                end
            end
        end
    end

    self:run(connection)
end

function RHM_HarvestSyncInitialEvent:run(connection)
    -- Notify GUI of fresh initial state if open
    if g_realisticHarvestManager and g_realisticHarvestManager.harvestHistoryGUI and g_realisticHarvestManager.harvestHistoryGUI.isOpen then
        g_realisticHarvestManager.harvestHistoryGUI:refreshCurrentPage()
    end
end
