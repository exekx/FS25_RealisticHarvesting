-- ============================================================================
-- RHM_HarvestTracker.lua
-- Realistic Harvesting Mod - Server-Authoritative Field Trip & Fleet Tracker
-- ============================================================================
-- Technical architecture:
--   Tracks active field trip odometers, fleet statistics, multi-season history,
--   and farm-specific harvesting configuration.
--   Strictly server-authoritative in multiplayer/dedicated server environments.
--   Data is isolated by farmId and persisted to realisticHarvestingData.xml.
-- ============================================================================

RHM_HarvestTracker = {}
local HarvestTracker_mt = Class(RHM_HarvestTracker)

RHM_HarvestTracker.RANK_A = "A"
RHM_HarvestTracker.RANK_B = "B"
RHM_HarvestTracker.RANK_C = "C"
RHM_HarvestTracker.RANK_D = "D"

RHM_HarvestTracker.THRESHOLD_RANK_A = 1.5
RHM_HarvestTracker.THRESHOLD_RANK_B = 3.0
RHM_HarvestTracker.THRESHOLD_RANK_C = 4.5

function RHM_HarvestTracker.new()
    local self = setmetatable({}, HarvestTracker_mt)
    self.farms = {}
    self.timeSinceLastSync = 0
    self.syncInterval = 1000 -- 1 second interval for delta broadcast
    self.isDirty = false
    return self
end

local function hasFarmManagementRights(farmId, user)
    if not (g_currentMission and g_currentMission.isMultiplayer) then
        return true
    end
    if not user then return true end
    if g_farmManager then
        local realFarm = g_farmManager:getFarmById(farmId)
        if realFarm then
            if realFarm.ownerUserId and realFarm.ownerUserId == user.userId then
                return true
            end
            if realFarm.isUserFarmManager and realFarm:isUserFarmManager(user.userId) then
                return true
            end
            if realFarm.getIsUserFarmManager and realFarm:getIsUserFarmManager(user.userId) then
                return true
            end
            if realFarm.isFarmManager and realFarm:isFarmManager(user.userId) then
                return true
            end
        end
    end
    return false
end

---EN: Resolves the specific combine harvester the local player is currently seated in or operating.
---    Handles direct combine driving, AI worker driving while player is in cab, passenger seating,
---    and carrier / tractor hierarchies with attached combines.
---UA: Визначає конкретний комбайн, в кабіні якого сидить або яким керує гравець.
---    Коректно обробляє ручне керування, наймита в кабіні, пасажира та складні причіпні системи.
function RHM_HarvestTracker.findPlayerEnteredCombine()
    -- 1. Try g_realisticHarvestManager.lastActiveCombine (continuously tracked by HUD frame loop)
    if g_realisticHarvestManager and g_realisticHarvestManager.lastActiveCombine then
        local c = g_realisticHarvestManager.lastActiveCombine
        local isEntered = (c.getIsEntered and c:getIsEntered())
            or (c.rootVehicle and c.rootVehicle.getIsEntered and c.rootVehicle:getIsEntered())
            or (c.spec_enterable and c.spec_enterable.isEntered)
        if isEntered then
            return c
        end
    end

    -- 2. Try controlled vehicle from manager, local player, or mission
    local controlled = nil
    if g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
        controlled = g_realisticHarvestManager:getControlledVehicle()
    end
    if not controlled and g_currentMission then
        if g_currentMission.getControlledVehicle then
            controlled = g_currentMission:getControlledVehicle()
        elseif g_currentMission.controlledVehicle then
            controlled = g_currentMission.controlledVehicle
        end
    end
    if not controlled and g_localPlayer and g_localPlayer.getCurrentVehicle then
        controlled = g_localPlayer:getCurrentVehicle()
    end

    if controlled then
        local c = (RHM_Api and RHM_Api.findCombine and RHM_Api.findCombine(controlled))
        if c then return c end
        if controlled.spec_rhm_Combine or controlled.spec_combine then return controlled end
    end

    -- 3. Scan all vehicles on the map for player entry.
    -- In FS25, when an AI worker is driving, controlledVehicle may be nil,
    -- but vehicle:getIsEntered() is ALWAYS true for the vehicle cab occupied by the local player!
    local vehicles = nil
    if g_currentMission then
        if g_currentMission.vehicles then
            vehicles = g_currentMission.vehicles
        elseif g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.getVehicles then
            vehicles = g_currentMission.vehicleSystem:getVehicles()
        elseif g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles then
            vehicles = g_currentMission.vehicleSystem.vehicles
        end
    end

    if vehicles then
        for _, v in pairs(vehicles) do
            if v and type(v) == "table" then
                local isEntered = false
                if v.getIsEntered and v:getIsEntered() then
                    isEntered = true
                elseif v.spec_enterable and v.spec_enterable.isEntered then
                    isEntered = true
                elseif v.rootVehicle and v.rootVehicle ~= v and v.rootVehicle.getIsEntered and v.rootVehicle:getIsEntered() then
                    isEntered = true
                end

                if isEntered then
                    local c = (RHM_Api and RHM_Api.findCombine and RHM_Api.findCombine(v))
                    if c then return c end
                    if v.spec_rhm_Combine or v.spec_combine then return v end
                end
            end
        end
    end

    -- 4. If player is not entered in any vehicle, fallback to lastActiveCombine if valid
    if g_realisticHarvestManager and g_realisticHarvestManager.lastActiveCombine then
        return g_realisticHarvestManager.lastActiveCombine
    end

    return nil
end

---EN: Returns the isolated trip odometer for a specific combine
---UA: Повертає ізольований одометр сесії для конкретного комбайна
function RHM_HarvestTracker:getCombineTrip(farmId, combine)
    if not combine then return nil end
    if combine.spec_rhm_Combine and combine.spec_rhm_Combine.trip then
        return combine.spec_rhm_Combine.trip
    end
    local farm = self:getFarmData(farmId or 1)
    if farm and farm.combineTrips then
        local machineKey = combine.configFileName or (combine.getFullName and combine:getFullName()) or "Harvester"
        if farm.combineTrips[machineKey] then
            return farm.combineTrips[machineKey]
        end
    end
    return nil
end

---Creates a clean default data structure for a farm
function RHM_HarvestTracker:createDefaultFarmData()
    return {
        currentTrip = {
            fieldId = 0,
            cropName = "UNKNOWN",
            fillTypeIndex = FillType.UNKNOWN,
            harvestedLiters = 0,
            harvestedMassKg = 0,
            harvestedAreaHa = 0,
            lostLiters = 0,
            lossMoney = 0,
            reasons = {
                speed = 0,
                moisture = 0,
                wear = 0,
                slope = 0
            },
            sessionDuration = 0,
            avgSpeedSum = 0,
            avgSpeedCount = 0,
            avgLoadSum = 0,
            avgLoadCount = 0,
            efficiencyRank = RHM_HarvestTracker.RANK_A,
            isActive = false
        },
        fleetStats = {},
        seasonHistory = {},
        fieldHeatmaps = {},
        farmSettings = {
            aiSpeedLimiter = true,
            aiMaxLossPct = 2.0,
            volunteerCrops = true,
            autoResetOnFieldChange = false
        }
    }
end

---Returns the farm data table for the given farmId, initializing if necessary
function RHM_HarvestTracker:getFarmData(farmId)
    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        farmId = 1
    end
    if not self.farms[farmId] then
        self.farms[farmId] = self:createDefaultFarmData()
    end
    return self.farms[farmId]
end

---Calculates efficiency scorecard grade from total loss percentage
function RHM_HarvestTracker.calculateEfficiencyRank(lossPct)
    if lossPct == nil then return RHM_HarvestTracker.RANK_A end
    if lossPct < RHM_HarvestTracker.THRESHOLD_RANK_A then
        return RHM_HarvestTracker.RANK_A
    elseif lossPct < RHM_HarvestTracker.THRESHOLD_RANK_B then
        return RHM_HarvestTracker.RANK_B
    elseif lossPct < RHM_HarvestTracker.THRESHOLD_RANK_C then
        return RHM_HarvestTracker.RANK_C
    else
        return RHM_HarvestTracker.RANK_D
    end
end

---Determines the dominant root cause of loss based on accumulated volumes
function RHM_HarvestTracker.getDominantLossFactor(reasons)
    if not reasons then return "speed" end
    local maxVal = reasons.speed or 0
    local dominant = "speed"

    if (reasons.moisture or 0) > maxVal then
        maxVal = reasons.moisture
        dominant = "moisture"
    end
    if (reasons.wear or 0) > maxVal then
        maxVal = reasons.wear
        dominant = "wear"
    end
    if (reasons.slope or 0) > maxVal then
        maxVal = reasons.slope
        dominant = "slope"
    end

    return dominant
end

---Processes a single harvesting simulation tick on the server
function RHM_HarvestTracker:onCombineHarvestTick(combine, farmId, liters, massKg, areaHa, fieldId, totalLossPct, lossReasons, speedKmh, loadRatio, dt)
    if not g_currentMission:getIsServer() then return end
    if liters <= 0 then return end

    local farm = self:getFarmData(farmId)
    local machineKey = combine.configFileName or combine:getFullName() or "Harvester"
    local trip = farm.currentTrip

    -- Maintain per-machine trip record
    farm.combineTrips = farm.combineTrips or {}
    if not farm.combineTrips[machineKey] then
        farm.combineTrips[machineKey] = {
            fieldId = 0,
            cropName = "--",
            fillTypeIndex = FillType.UNKNOWN,
            harvestedAreaHa = 0,
            harvestedLiters = 0,
            harvestedMassKg = 0,
            lostLiters = 0,
            lossMoney = 0,
            sessionDuration = 0,
            avgSpeedSum = 0,
            avgSpeedCount = 0,
            avgLoadSum = 0,
            avgLoadCount = 0,
            efficiencyRank = RHM_HarvestTracker.RANK_A,
            reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
            isActive = true
        }
    end
    local mTrip = farm.combineTrips[machineKey]

    -- Check if player is currently in this combine
    local isPlayerInThisCombine = false
    if combine.getIsEntered and combine:getIsEntered() then
        isPlayerInThisCombine = true
    elseif combine.rootVehicle and combine.rootVehicle.getIsEntered and combine.rootVehicle:getIsEntered() then
        isPlayerInThisCombine = true
    elseif combine.spec_enterable and combine.spec_enterable.isEntered then
        isPlayerInThisCombine = true
    end

    -- If player is sitting in this combine, or no master machine set yet, or same machine, update farm.currentTrip
    local updateFarmTrip = isPlayerInThisCombine or (trip.lastMachineKey == nil) or (trip.lastMachineKey == machineKey)

    -- Auto-reset trip ONLY if the SAME combine moves to a new field (prevents multi-combine field hopping)
    if updateFarmTrip and farm.farmSettings.autoResetOnFieldChange and fieldId > 0 and trip.fieldId > 0 and trip.fieldId ~= fieldId and trip.harvestedLiters > 500 and (trip.lastMachineKey == nil or trip.lastMachineKey == machineKey) then
        self:archiveTripToHistory(farmId)
        trip = farm.currentTrip
    end
    if updateFarmTrip then
        trip.lastMachineKey = machineKey
    end

    if fieldId > 0 then
        if updateFarmTrip then trip.fieldId = fieldId end
        mTrip.fieldId = fieldId
    end

    -- Update crop type
    local fillTypeIndex = combine.spec_rhm_Combine and combine.spec_rhm_Combine.lastFillType or FillType.UNKNOWN
    if fillTypeIndex ~= FillType.UNKNOWN then
        if updateFarmTrip then trip.fillTypeIndex = fillTypeIndex end
        mTrip.fillTypeIndex = fillTypeIndex
        local desc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if desc and desc.name then
            if updateFarmTrip then trip.cropName = desc.name end
            mTrip.cropName = desc.name
        end
    end

    -- Accumulate harvest throughput
    if updateFarmTrip then
        trip.harvestedLiters = trip.harvestedLiters + liters
        trip.harvestedMassKg = trip.harvestedMassKg + massKg
        trip.harvestedAreaHa = trip.harvestedAreaHa + areaHa
        trip.sessionDuration = trip.sessionDuration + (dt * 0.001)
        trip.isActive = true
    end

    mTrip.harvestedLiters = mTrip.harvestedLiters + liters
    mTrip.harvestedMassKg = mTrip.harvestedMassKg + massKg
    mTrip.harvestedAreaHa = mTrip.harvestedAreaHa + areaHa
    mTrip.sessionDuration = mTrip.sessionDuration + (dt * 0.001)
    mTrip.isActive = true

    -- Calculate physical loss liters
    local wearLossPct = (lossReasons and lossReasons.wearPct) or 0
    local physicalLossPct = math.max(0, totalLossPct - wearLossPct)
    local lostLiters = liters * (physicalLossPct / 100.0)
    if updateFarmTrip then
        trip.lostLiters = trip.lostLiters + lostLiters
    end
    mTrip.lostLiters = mTrip.lostLiters + lostLiters

    -- Calculate financial loss value using economy manager price
    local pricePerLiter = 0.35 -- standard baseline fallback
    if g_currentMission and g_currentMission.economyManager and fillTypeIndex ~= FillType.UNKNOWN then
        if g_currentMission.economyManager.getPricePerLiter then
            pricePerLiter = g_currentMission.economyManager:getPricePerLiter(fillTypeIndex) or pricePerLiter
        elseif g_currentMission.economyManager.getCostPerLiter then
            pricePerLiter = g_currentMission.economyManager:getCostPerLiter(fillTypeIndex) or pricePerLiter
        end
    end
    if pricePerLiter <= 0 and fillTypeIndex ~= FillType.UNKNOWN then
        local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if ft and ft.pricePerLiter and ft.pricePerLiter > 0 then
            pricePerLiter = ft.pricePerLiter
        end
    end
    local lossMoneyThisTick = (lostLiters * pricePerLiter)
    if updateFarmTrip then
        trip.lossMoney = trip.lossMoney + lossMoneyThisTick
    end
    mTrip.lossMoney = mTrip.lossMoney + lossMoneyThisTick

    -- Partition loss reasons proportionally
    if lossReasons and lostLiters > 0 then
        local sumPcts = (lossReasons.speedPct or 0) + (lossReasons.moisturePct or 0) + (lossReasons.wearPct or 0) + (lossReasons.slopePct or 0)
        if sumPcts > 0.001 then
            local spdAdd = lostLiters * ((lossReasons.speedPct or 0) / sumPcts)
            local mstAdd = lostLiters * ((lossReasons.moisturePct or 0) / sumPcts)
            local wearAdd = lostLiters * ((lossReasons.wearPct or 0) / sumPcts)
            local slpAdd = lostLiters * ((lossReasons.slopePct or 0) / sumPcts)

            if updateFarmTrip then
                trip.reasons.speed = trip.reasons.speed + spdAdd
                trip.reasons.moisture = trip.reasons.moisture + mstAdd
                trip.reasons.wear = trip.reasons.wear + wearAdd
                trip.reasons.slope = trip.reasons.slope + slpAdd
            end

            mTrip.reasons.speed = mTrip.reasons.speed + spdAdd
            mTrip.reasons.moisture = mTrip.reasons.moisture + mstAdd
            mTrip.reasons.wear = mTrip.reasons.wear + wearAdd
            mTrip.reasons.slope = mTrip.reasons.slope + slpAdd
        else
            if updateFarmTrip then
                trip.reasons.speed = trip.reasons.speed + lostLiters
            end
            mTrip.reasons.speed = mTrip.reasons.speed + lostLiters
        end
    end

    -- Rolling averages for speed and load
    if speedKmh and speedKmh > 0.5 then
        if updateFarmTrip then
            trip.avgSpeedSum = trip.avgSpeedSum + speedKmh
            trip.avgSpeedCount = trip.avgSpeedCount + 1
        end
        mTrip.avgSpeedSum = mTrip.avgSpeedSum + speedKmh
        mTrip.avgSpeedCount = mTrip.avgSpeedCount + 1
    end
    if loadRatio and loadRatio > 0.05 then
        if updateFarmTrip then
            trip.avgLoadSum = trip.avgLoadSum + loadRatio
            trip.avgLoadCount = trip.avgLoadCount + 1
        end
        mTrip.avgLoadSum = mTrip.avgLoadSum + loadRatio
        mTrip.avgLoadCount = mTrip.avgLoadCount + 1
    end

    -- Update overall trip efficiency rank
    if updateFarmTrip then
        local totalBioVolume = trip.harvestedLiters + trip.lostLiters
        local overallLossPct = (totalBioVolume > 0) and ((trip.lostLiters / totalBioVolume) * 100.0) or 0
        trip.efficiencyRank = RHM_HarvestTracker.calculateEfficiencyRank(overallLossPct)
    end

    local mTotalBio = mTrip.harvestedLiters + mTrip.lostLiters
    local mLossPct = (mTotalBio > 0) and ((mTrip.lostLiters / mTotalBio) * 100.0) or 0
    mTrip.efficiencyRank = RHM_HarvestTracker.calculateEfficiencyRank(mLossPct)

    -- Mirror to combine instance directly if RHM-hooked
    if combine.spec_rhm_Combine then
        combine.spec_rhm_Combine.trip = mTrip
    end

    -- Update fleet statistics for this combine
    local machineKey = combine.configFileName or combine:getFullName()
    if not farm.fleetStats[machineKey] then
        farm.fleetStats[machineKey] = {
            name = combine:getFullName() or "Harvester",
            workSeconds = 0,
            totalHarvested = 0,
            totalLost = 0
        }
    end
    local fleetEntry = farm.fleetStats[machineKey]
    fleetEntry.workSeconds = fleetEntry.workSeconds + (dt * 0.001)
    fleetEntry.totalHarvested = fleetEntry.totalHarvested + liters
    fleetEntry.totalLost = fleetEntry.totalLost + lostLiters

    -- Precision Telemetry Sampling for Yield & Loss Map (O(1) ring buffer per field)
    if fieldId > 0 and combine.rootNode then
        farm.fieldHeatmaps = farm.fieldHeatmaps or {}
        farm.fieldHeatmaps[fieldId] = farm.fieldHeatmaps[fieldId] or { points = {}, head = 1, maxPoints = 800, sampleTimer = 0 }
        local hm = farm.fieldHeatmaps[fieldId]
        hm.sampleTimer = (hm.sampleTimer or 0) + dt
        if hm.sampleTimer >= 1500 then
            hm.sampleTimer = 0
            local wx, _, wz = getWorldTranslation(combine.rootNode)
            local yld = (combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator and combine.spec_rhm_Combine.loadCalculator.currentYield) or 0
            hm.points[hm.head] = {
                x = math.floor(wx * 10) * 0.1,
                z = math.floor(wz * 10) * 0.1,
                yield = math.floor(yld * 10) * 0.1,
                loss = math.floor(totalLossPct * 10) * 0.1
            }
            hm.head = (hm.head % (hm.maxPoints or 800)) + 1
        end
    end

    self.isDirty = true
end

---Periodic update on server to broadcast stats
function RHM_HarvestTracker:update(dt)
    if not g_currentMission:getIsServer() then return end

    self.timeSinceLastSync = self.timeSinceLastSync + dt
    if self.timeSinceLastSync >= self.syncInterval then
        if self.isDirty then
            self:broadcastUpdates()
            self.isDirty = false
        end
        self.timeSinceLastSync = 0
    end
end

---Archives the current active trip into season history and clears trip metrics
function RHM_HarvestTracker:archiveTripToHistory(farmId)
    local farm = self:getFarmData(farmId)
    local trip = farm.currentTrip

    if trip.harvestedLiters > 10 then
        local currentYear = 1
        if g_currentMission and g_currentMission.environment and g_currentMission.environment.currentYear then
            currentYear = g_currentMission.environment.currentYear
        end

        local totalBio = trip.harvestedLiters + trip.lostLiters
        local lossPct = (totalBio > 0) and ((trip.lostLiters / totalBio) * 100.0) or 0

        local record = {
            year = currentYear,
            fieldId = trip.fieldId,
            cropName = trip.cropName,
            harvested = trip.harvestedLiters,
            lost = trip.lostLiters,
            lossMoney = trip.lossMoney,
            areaHa = trip.harvestedAreaHa,
            efficiencyRank = trip.efficiencyRank,
            dominantReason = RHM_HarvestTracker.getDominantLossFactor(trip.reasons),
            timestamp = (getDate and getDate("%Y-%m-%d %H:%M:%S")) or (g_currentMission and g_currentMission.time) or 0
        }
        table.insert(farm.seasonHistory, 1, record)
        -- Limit history size to last 50 entries
        if #farm.seasonHistory > 50 then
            table.remove(farm.seasonHistory)
        end
    end

    -- Reset trip odometer
    farm.currentTrip = {
        fieldId = trip.fieldId,
        cropName = trip.cropName,
        fillTypeIndex = trip.fillTypeIndex,
        harvestedLiters = 0,
        harvestedMassKg = 0,
        harvestedAreaHa = 0,
        lostLiters = 0,
        lossMoney = 0,
        reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
        sessionDuration = 0,
        avgSpeedSum = 0,
        avgSpeedCount = 0,
        avgLoadSum = 0,
        avgLoadCount = 0,
        efficiencyRank = RHM_HarvestTracker.RANK_A,
        isActive = false
    }
    self.isDirty = true
end

---Requests a reset of current trip measurements
function RHM_HarvestTracker:resetTrip(farmId, user)
    if farmId == nil then return false end
    local farm = self:getFarmData(farmId)

    -- Check farm management rights
    if user and not hasFarmManagementRights(farmId, user) then
        return false
    end

    self:archiveTripToHistory(farmId)

    if g_currentMission:getIsServer() and g_server then
        -- Broadcast reset confirmation to clients
        g_server:broadcastEvent(RHM_HarvestResetTripEvent.new(farmId), nil, nil, nil)
    end
    return true
end

---EN: Resets trip odometer for a specific combine or entire farm
---UA: Скидає одометр сесії для конкретного комбайна або всієї ферми
function RHM_HarvestTracker:resetTripForCombine(farmId, combine, user)
    if farmId == nil then return false end
    if user and not hasFarmManagementRights(farmId, user) then
        return false
    end
    if combine then
        if combine.resetTrip then
            combine:resetTrip()
        end
        local farm = self:getFarmData(farmId)
        local machineKey = combine.configFileName or (combine.getFullName and combine:getFullName()) or "Harvester"
        if farm and farm.combineTrips then
            local mTrip = farm.combineTrips[machineKey]
            if mTrip then
                mTrip.harvestedLiters = 0
                mTrip.harvestedMassKg = 0
                mTrip.harvestedAreaHa = 0
                mTrip.lostLiters = 0
                mTrip.lossMoney = 0
                mTrip.reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 }
                mTrip.sessionDuration = 0
                mTrip.avgSpeedSum = 0
                mTrip.avgSpeedCount = 0
                mTrip.avgLoadSum = 0
                mTrip.avgLoadCount = 0
                mTrip.efficiencyRank = RHM_HarvestTracker.RANK_A
                mTrip.isActive = false
            end
        end
        if farm and farm.currentTrip and (farm.currentTrip.lastMachineKey == nil or farm.currentTrip.lastMachineKey == machineKey) then
            self:archiveTripToHistory(farmId)
            farm.currentTrip.harvestedLiters = 0
            farm.currentTrip.harvestedMassKg = 0
            farm.currentTrip.harvestedAreaHa = 0
            farm.currentTrip.lostLiters = 0
            farm.currentTrip.lossMoney = 0
            farm.currentTrip.reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 }
            farm.currentTrip.sessionDuration = 0
            farm.currentTrip.avgSpeedSum = 0
            farm.currentTrip.avgSpeedCount = 0
            farm.currentTrip.avgLoadSum = 0
            farm.currentTrip.avgLoadCount = 0
            farm.currentTrip.efficiencyRank = RHM_HarvestTracker.RANK_A
            farm.currentTrip.isActive = false
        end
        return true
    end
    return self:resetTrip(farmId, user)
end

---Updates farm settings
function RHM_HarvestTracker:updateFarmSettings(farmId, newSettings, user)
    if farmId == nil or newSettings == nil then return false end
    local farm = self:getFarmData(farmId)

    if user and not hasFarmManagementRights(farmId, user) then
        return false
    end

    if newSettings.aiSpeedLimiter ~= nil then farm.farmSettings.aiSpeedLimiter = newSettings.aiSpeedLimiter end
    if newSettings.aiMaxLossPct ~= nil then farm.farmSettings.aiMaxLossPct = newSettings.aiMaxLossPct end
    if newSettings.volunteerCrops ~= nil then farm.farmSettings.volunteerCrops = newSettings.volunteerCrops end
    if newSettings.autoResetOnFieldChange ~= nil then farm.farmSettings.autoResetOnFieldChange = newSettings.autoResetOnFieldChange end

    if g_currentMission:getIsServer() and g_server then
        g_server:broadcastEvent(RHM_HarvestFarmSettingsEvent.new(farmId, farm.farmSettings), nil, nil, nil)
    end
    return true
end

---Broadcasts updated trip stats to all connected clients
function RHM_HarvestTracker:broadcastUpdates()
    if not g_server then return end
    for farmId, farm in pairs(self.farms) do
        if farm.currentTrip and farm.currentTrip.isActive then
            g_server:broadcastEvent(RHM_HarvestUpdateStatsEvent.new(farmId, farm.currentTrip), nil, nil, nil)
        end
    end
end

-- ============================================================================
-- PERSISTENCE: Save & Load XML
-- ============================================================================

function RHM_HarvestTracker:saveToXMLFile(xmlFile, rootKey)
    local farmIndex = 0
    for farmId, farm in pairs(self.farms) do
        local farmKey = string.format("%s.farm(%d)", rootKey, farmIndex)
        setXMLInt(xmlFile, farmKey .. "#farmId", farmId)

        -- Current Trip
        local trip = farm.currentTrip
        local tripKey = farmKey .. ".currentTrip"
        setXMLInt(xmlFile, tripKey .. "#fieldId", trip.fieldId or 0)
        setXMLString(xmlFile, tripKey .. "#cropName", trip.cropName or "UNKNOWN")
        setXMLFloat(xmlFile, tripKey .. "#harvested", trip.harvestedLiters or 0)
        setXMLFloat(xmlFile, tripKey .. "#harvestedMass", trip.harvestedMassKg or 0)
        setXMLFloat(xmlFile, tripKey .. "#harvestedArea", trip.harvestedAreaHa or 0)
        setXMLFloat(xmlFile, tripKey .. "#lost", trip.lostLiters or 0)
        setXMLFloat(xmlFile, tripKey .. "#lossMoney", trip.lossMoney or 0)
        setXMLFloat(xmlFile, tripKey .. "#duration", trip.sessionDuration or 0)

        setXMLFloat(xmlFile, tripKey .. ".reasons#speed", trip.reasons.speed or 0)
        setXMLFloat(xmlFile, tripKey .. ".reasons#moisture", trip.reasons.moisture or 0)
        setXMLFloat(xmlFile, tripKey .. ".reasons#wear", trip.reasons.wear or 0)
        setXMLFloat(xmlFile, tripKey .. ".reasons#slope", trip.reasons.slope or 0)

        -- Farm Settings
        local setKey = farmKey .. ".farmSettings"
        setXMLBool(xmlFile, setKey .. "#aiSpeedLimiter", farm.farmSettings.aiSpeedLimiter)
        setXMLFloat(xmlFile, setKey .. "#aiMaxLossPct", farm.farmSettings.aiMaxLossPct)
        setXMLBool(xmlFile, setKey .. "#volunteerCrops", farm.farmSettings.volunteerCrops)
        setXMLBool(xmlFile, setKey .. "#autoResetOnFieldChange", farm.farmSettings.autoResetOnFieldChange)

        -- Fleet Stats
        local fleetKey = farmKey .. ".fleetStats"
        local vIdx = 0
        for key, v in pairs(farm.fleetStats) do
            local vKey = string.format("%s.vehicle(%d)", fleetKey, vIdx)
            setXMLString(xmlFile, vKey .. "#key", key)
            setXMLString(xmlFile, vKey .. "#name", v.name or "Harvester")
            setXMLFloat(xmlFile, vKey .. "#workHours", (v.workSeconds or 0) / 3600.0)
            setXMLFloat(xmlFile, vKey .. "#totalHarvested", v.totalHarvested or 0)
            setXMLFloat(xmlFile, vKey .. "#totalLost", v.totalLost or 0)
            vIdx = vIdx + 1
        end

        -- Season History (archive)
        local histKey = farmKey .. ".seasonHistory"
        for hIdx, entry in ipairs(farm.seasonHistory) do
            local eKey = string.format("%s.entry(%d)", histKey, hIdx - 1)
            setXMLInt(xmlFile, eKey .. "#year", entry.year or 1)
            setXMLInt(xmlFile, eKey .. "#fieldId", entry.fieldId or 0)
            setXMLString(xmlFile, eKey .. "#cropName", entry.cropName or "UNKNOWN")
            setXMLFloat(xmlFile, eKey .. "#harvested", entry.harvested or 0)
            setXMLFloat(xmlFile, eKey .. "#lost", entry.lost or 0)
            setXMLFloat(xmlFile, eKey .. "#lossMoney", entry.lossMoney or 0)
            setXMLFloat(xmlFile, eKey .. "#areaHa", entry.areaHa or 0)
            setXMLString(xmlFile, eKey .. "#efficiencyRank", entry.efficiencyRank or "A")
            setXMLString(xmlFile, eKey .. "#dominantReason", entry.dominantReason or "speed")
        end

        farmIndex = farmIndex + 1
    end
end

function RHM_HarvestTracker:loadFromXMLFile(xmlFile, rootKey)
    local farmIndex = 0
    while true do
        local farmKey = string.format("%s.farm(%d)", rootKey, farmIndex)
        if not hasXMLProperty(xmlFile, farmKey) then
            break
        end

        local farmId = getXMLInt(xmlFile, farmKey .. "#farmId") or 1
        local farm = self:getFarmData(farmId)

        -- Current Trip
        local tripKey = farmKey .. ".currentTrip"
        if hasXMLProperty(xmlFile, tripKey) then
            farm.currentTrip.fieldId = getXMLInt(xmlFile, tripKey .. "#fieldId") or 0
            farm.currentTrip.cropName = getXMLString(xmlFile, tripKey .. "#cropName") or "UNKNOWN"
            farm.currentTrip.harvestedLiters = getXMLFloat(xmlFile, tripKey .. "#harvested") or 0
            farm.currentTrip.harvestedMassKg = getXMLFloat(xmlFile, tripKey .. "#harvestedMass") or 0
            farm.currentTrip.harvestedAreaHa = getXMLFloat(xmlFile, tripKey .. "#harvestedArea") or 0
            farm.currentTrip.lostLiters = getXMLFloat(xmlFile, tripKey .. "#lost") or 0
            farm.currentTrip.lossMoney = getXMLFloat(xmlFile, tripKey .. "#lossMoney") or 0
            farm.currentTrip.sessionDuration = getXMLFloat(xmlFile, tripKey .. "#duration") or 0

            farm.currentTrip.reasons.speed = getXMLFloat(xmlFile, tripKey .. ".reasons#speed") or 0
            farm.currentTrip.reasons.moisture = getXMLFloat(xmlFile, tripKey .. ".reasons#moisture") or 0
            farm.currentTrip.reasons.wear = getXMLFloat(xmlFile, tripKey .. ".reasons#wear") or 0
            farm.currentTrip.reasons.slope = getXMLFloat(xmlFile, tripKey .. ".reasons#slope") or 0

            local totalBio = farm.currentTrip.harvestedLiters + farm.currentTrip.lostLiters
            local lossPct = (totalBio > 0) and ((farm.currentTrip.lostLiters / totalBio) * 100.0) or 0
            farm.currentTrip.efficiencyRank = RHM_HarvestTracker.calculateEfficiencyRank(lossPct)
        end

        -- Farm Settings
        local setKey = farmKey .. ".farmSettings"
        if hasXMLProperty(xmlFile, setKey) then
            local aiLim = getXMLBool(xmlFile, setKey .. "#aiSpeedLimiter")
            if aiLim ~= nil then farm.farmSettings.aiSpeedLimiter = aiLim end
            local aiLoss = getXMLFloat(xmlFile, setKey .. "#aiMaxLossPct")
            if aiLoss ~= nil then farm.farmSettings.aiMaxLossPct = aiLoss end
            local vol = getXMLBool(xmlFile, setKey .. "#volunteerCrops")
            if vol ~= nil then farm.farmSettings.volunteerCrops = vol end
            local autoRes = getXMLBool(xmlFile, setKey .. "#autoResetOnFieldChange")
            if autoRes ~= nil then farm.farmSettings.autoResetOnFieldChange = autoRes end
        end

        -- Fleet Stats
        local fleetKey = farmKey .. ".fleetStats"
        local vIdx = 0
        while true do
            local vKey = string.format("%s.vehicle(%d)", fleetKey, vIdx)
            if not hasXMLProperty(xmlFile, vKey) then break end
            local key = getXMLString(xmlFile, vKey .. "#key") or ("v" .. vIdx)
            local name = getXMLString(xmlFile, vKey .. "#name") or "Harvester"
            local workHours = getXMLFloat(xmlFile, vKey .. "#workHours") or 0
            local totHarvest = getXMLFloat(xmlFile, vKey .. "#totalHarvested") or 0
            local totLost = getXMLFloat(xmlFile, vKey .. "#totalLost") or 0

            farm.fleetStats[key] = {
                name = name,
                workSeconds = workHours * 3600.0,
                totalHarvested = totHarvest,
                totalLost = totLost
            }
            vIdx = vIdx + 1
        end

        -- Season History
        local histKey = farmKey .. ".seasonHistory"
        local hIdx = 0
        farm.seasonHistory = {}
        while true do
            local eKey = string.format("%s.entry(%d)", histKey, hIdx)
            if not hasXMLProperty(xmlFile, eKey) then break end
            table.insert(farm.seasonHistory, {
                year = getXMLInt(xmlFile, eKey .. "#year") or 1,
                fieldId = getXMLInt(xmlFile, eKey .. "#fieldId") or 0,
                cropName = getXMLString(xmlFile, eKey .. "#cropName") or "UNKNOWN",
                harvested = getXMLFloat(xmlFile, eKey .. "#harvested") or 0,
                lost = getXMLFloat(xmlFile, eKey .. "#lost") or 0,
                lossMoney = getXMLFloat(xmlFile, eKey .. "#lossMoney") or 0,
                areaHa = getXMLFloat(xmlFile, eKey .. "#areaHa") or 0,
                efficiencyRank = getXMLString(xmlFile, eKey .. "#efficiencyRank") or "A",
                dominantReason = getXMLString(xmlFile, eKey .. "#dominantReason") or "speed"
            })
            hIdx = hIdx + 1
        end

        farmIndex = farmIndex + 1
    end
end
