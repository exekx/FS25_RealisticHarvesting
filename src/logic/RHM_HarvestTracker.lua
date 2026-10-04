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

    local function isTargetHarvester(veh)
        if not veh then return false end
        if veh.spec_rhm_Combine ~= nil 
           or veh.spec_combine ~= nil 
           or veh.spec_forageHarvester ~= nil 
           or veh.spec_cottonHarvester ~= nil
           or veh.spec_sugarCaneHarvester ~= nil
           or veh.spec_grapeHarvester ~= nil
           or veh.spec_oliveHarvester ~= nil
           or veh.spec_woodHarvester ~= nil then
            return true
        end
        if veh.specializations then
            if (Combine ~= nil and SpecializationUtil.hasSpecialization(Combine, veh.specializations))
               or (ForageHarvester ~= nil and SpecializationUtil.hasSpecialization(ForageHarvester, veh.specializations)) then
                return true
            end
        end
        return false
    end

    if controlled then
        local c = (RHM_Api and RHM_Api.findCombine and RHM_Api.findCombine(controlled))
        if c then return c end
        if isTargetHarvester(controlled) then return controlled end
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
                    if isTargetHarvester(v) then return v end
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

---EN: Checks if a combine or key corresponds to a mission/contract rental machine.
---UA: Перевіряє, чи є комбайн або назва орендованою технікою під контракт/місію.
function RHM_HarvestTracker.isMissionCombine(combine, name, key)
    if combine then
        if VehiclePropertyState ~= nil and combine.propertyState ~= nil and combine.propertyState == VehiclePropertyState.MISSION then
            return true
        end
        if combine.getIsMissionWork and combine:getIsMissionWork() then
            return true
        end
        if combine.isMissionWork or combine.isMissionVehicle then
            return true
        end
    end
    local n = tostring(name or (combine and combine.getFullName and combine:getFullName()) or (combine and combine.getName and combine:getName()) or "")
    if n:find("^MR%s") or n:find("^MR_") or n:find("%[MR%]") or n:find("^MR%d") then
        return true
    end
    local k = tostring(key or (combine and combine.configFileName) or "")
    if k:find("^MR%s") or k:find("^MR_") or k:find("%[MR%]") or k:find("^MR%d") then
        return true
    end
    return false
end

---EN: Prunes any orphaned contract/mission combines from farm fleet stats.
---UA: Очищає тимчасову контрактну/місійну техніку зі статистики парку ферми.
function RHM_HarvestTracker:pruneMissionFleetStats(farmId)
    local farm = self:getFarmData(farmId or 1)
    if farm and farm.fleetStats then
        local liveVehicles = (g_currentMission and g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.getVehicles and g_currentMission.vehicleSystem:getVehicles()) or (g_currentMission and g_currentMission.vehicles) or {}
        local missionKeys = {}
        for _, veh in pairs(liveVehicles) do
            if type(veh) == "table" and RHM_HarvestTracker.isMissionCombine(veh) then
                local k = veh.configFileName or (veh.getFullName and veh:getFullName())
                if k then missionKeys[k] = true end
                if veh.getFullName and veh:getFullName() then missionKeys[veh:getFullName()] = true end
            end
        end

        for key, v in pairs(farm.fleetStats) do
            if missionKeys[key] or missionKeys[v.name] or RHM_HarvestTracker.isMissionCombine(nil, v.name, key) then
                farm.fleetStats[key] = nil
                self.isDirty = true
            end
        end
    end
end

---EN: Returns the isolated trip odometer for a specific combine
---UA: Повертає ізольований одометр сесії для конкретного комбайна
function RHM_HarvestTracker:getCombineTrip(farmId, combine)
    if not combine then return nil end
    local farm = self:getFarmData(farmId or (combine.getOwnerFarmId and combine:getOwnerFarmId()) or 1)
    local machineKey = combine.configFileName or (combine.getFullName and combine:getFullName()) or "Harvester"
    if farm and farm.combineTrips and farm.combineTrips[machineKey] then
        local mTrip = farm.combineTrips[machineKey]
        if combine.spec_rhm_Combine then
            combine.spec_rhm_Combine.trip = mTrip
        end
        return mTrip
    end
    if combine.spec_rhm_Combine and combine.spec_rhm_Combine.trip then
        return combine.spec_rhm_Combine.trip
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
            isActive = false,
            lastMachineKey = nil
        },
        combineTrips = {},
        fleetStats = {},
        yearlyStats = {},
        seasonHistory = {},
        fieldHeatmaps = {},
        farmSettings = {
            aiSpeedLimiter = true,
            aiMaxLossPct = 2.0,
            volunteerCrops = true,
            autoResetOnFieldChange = true
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

---EN: Detects whether a given field is currently an active contract / mission for the specified farm.
---UA: Визначає, чи є дане поле активним контрактом (місією) для заданої ферми.
---@param fieldId number
---@param farmId number
---@return boolean isContract
function RHM_HarvestTracker.isContractField(fieldId, farmId)
    if not fieldId or fieldId <= 0 then return false end
    local farm = farmId or 1

    -- Farmland ownership check: if our farm owns the farmland, it is never a contract
    if g_farmlandManager then
        if g_farmlandManager.getFarmlandOwner then
            local owner = g_farmlandManager:getFarmlandOwner(fieldId)
            if owner == farm then
                return false
            end
        end
        if g_fieldManager and g_fieldManager.getFieldById then
            local field = g_fieldManager:getFieldById(fieldId)
            if field then
                local fmlId = field.farmlandId or (field.farmland and (field.farmland.id or field.farmland.farmlandId))
                if (not fmlId or fmlId == 0) and field.rootNode and field.rootNode ~= 0 and entityExists(field.rootNode) and g_farmlandManager.getFarmlandIdAtWorldPosition then
                    local wx, _, wz = getWorldTranslation(field.rootNode)
                    fmlId = g_farmlandManager:getFarmlandIdAtWorldPosition(wx, wz)
                end
                if fmlId and fmlId > 0 and g_farmlandManager.getFarmlandOwner and g_farmlandManager:getFarmlandOwner(fmlId) == farm then
                    return false
                end
            end
        end
    end

    -- Mission manager check for active harvest contracts accepted by this farm
    local mm = g_missionManager or (g_currentMission and g_currentMission.missionManager)
    if mm then
        local missions = nil
        if mm.getActiveMissions then
            missions = mm:getActiveMissions()
        elseif mm.getMissions then
            missions = mm:getMissions()
        elseif mm.missions then
            missions = mm.missions
        end

        if missions then
            for _, mission in pairs(missions) do
                local status = mission.status
                local isRunning = (MissionStatus and status == MissionStatus.RUNNING) or (status == 2)
                if isRunning and mission.farmId == farm then
                    local mField = mission.field
                    local mFieldId = mission.fieldId or (mField and ((mField.getId and mField:getId()) or mField.fieldId or mField.id))
                    if mFieldId == fieldId then
                        return true
                    end
                end
            end
        end
    end

    return false
end

---EN: Resolves the active field object, field ID, and farmland ID for any world position.
---    Maps farmlandId to authentic fields defined in g_fieldManager, distinguishing true fields
---    from non-field parcels (such as farmyards, base infrastructure, meadows, or forests).
---UA: Визначає об'єкт поля, ID поля та ID ділянки (farmland) для будь-якої світової координати.
---@param wx number World X coordinate
---@param wz number World Z coordinate
---@param vehicle table|nil Optional vehicle reference for helper/course/cutter inspection
---@return table|nil field Field object from g_fieldManager if located on a field, or nil
---@return number fieldId ID of the field (1..N), or 0 if on non-field terrain / yard
---@return number farmlandId ID of the underlying farmland parcel (0 if outside map/road)
function RHM_HarvestTracker.getFieldAtWorldPosition(wx, wz, vehicle)
    if not wx or not wz then return nil, 0, 0 end

    if CpFieldUtil and CpFieldUtil.getFieldIdAtWorldPosition then
        local cpFid = CpFieldUtil.getFieldIdAtWorldPosition(wx, wz)
        if cpFid and cpFid > 0 then
            local fmlId = (g_farmlandManager and g_farmlandManager.getFarmlandIdAtWorldPosition and g_farmlandManager:getFarmlandIdAtWorldPosition(wx, wz)) or cpFid
            local f = (g_fieldManager and g_fieldManager.getFieldById and g_fieldManager:getFieldById(cpFid))
            return f, cpFid, fmlId
        end
    end

    -- 1. Try engine direct methods if available in GIANTS Engine 10
    if g_fieldManager then
        local f = (g_fieldManager.getFieldAtWorldPosition and g_fieldManager:getFieldAtWorldPosition(wx, wz))
               or (g_fieldManager.getFieldByWorldPosition and g_fieldManager:getFieldByWorldPosition(wx, wz))
        if f then
            local fid = (f.getId and f:getId()) or f.fieldId or f.id or 0
            if fid > 0 then
                local fFarmland = (f.getFarmland and f:getFarmland()) or f.farmland
                local fmlId = (fFarmland and ((fFarmland.getId and fFarmland:getId()) or fFarmland.id))
                           or f.farmlandId or (f.farmland and (f.farmland.id or f.farmland.farmlandId)) or fid
                return f, fid, fmlId
            end
        end
    end

    -- 2. Determine farmland object and farmlandId at the given coordinate
    local farmland = nil
    local fmlId = 0
    if g_farmlandManager then
        if g_farmlandManager.getFarmlandAtWorldPosition then
            farmland = g_farmlandManager:getFarmlandAtWorldPosition(wx, wz)
        end
        if farmland then
            fmlId = (farmland.getId and farmland:getId()) or farmland.id or 0
        elseif g_farmlandManager.getFarmlandIdAtWorldPosition then
            fmlId = g_farmlandManager:getFarmlandIdAtWorldPosition(wx, wz) or 0
        end
    end

    -- 3. FS25 GIANTS Engine 10 native: check if farmland has an authentic Field object attached
    if farmland and farmland.getField then
        local f = farmland:getField()
        if f then
            local fid = (f.getId and f:getId()) or f.fieldId or f.id or 0
            if fid > 0 then
                return f, fid, fmlId
            end
        end
    end

    -- If position is outside map / outside any farmland, check attached implements (e.g. cutter ahead on field)
    if fmlId <= 0 and vehicle then
        local checkCutters = {}
        if vehicle.spec_combine and vehicle.spec_combine.attachedCutters then
            for c, _ in pairs(vehicle.spec_combine.attachedCutters) do
                table.insert(checkCutters, c)
            end
        end
        if vehicle.getAttachedImplements then
            for _, impl in pairs(vehicle:getAttachedImplements()) do
                if impl.object and impl.object.spec_cutter then
                    table.insert(checkCutters, impl.object)
                end
            end
        end
        for _, c in ipairs(checkCutters) do
            if c.rootNode then
                local cx, _, cz = getWorldTranslation(c.rootNode)
                local cf, cfid, cfml = RHM_HarvestTracker.getFieldAtWorldPosition(cx, cz, nil)
                if cfid and cfid > 0 then
                    return cf, cfid, cfml
                end
            end
        end
        return nil, 0, 0
    end

    -- 4. Match against registered fields in g_fieldManager
    if g_fieldManager then
        -- Check direct getFieldById with fmlId (in FS25 farmlandId often corresponds 1:1 to fieldId)
        if g_fieldManager.getFieldById and fmlId > 0 then
            local f = g_fieldManager:getFieldById(fmlId)
            if f then
                local fid = (f.getId and f:getId()) or f.fieldId or f.id or fmlId
                local fFarmland = (f.getFarmland and f:getFarmland()) or f.farmland
                local ffml = (fFarmland and ((fFarmland.getId and fFarmland:getId()) or fFarmland.id)) or f.farmlandId
                if not ffml or ffml == 0 or ffml == fmlId then
                    return f, fid, fmlId
                end
            end
        end

        local fieldList = nil
        if g_fieldManager.getFields then
            fieldList = g_fieldManager:getFields()
        end
        if not fieldList or (type(fieldList) == "table" and next(fieldList) == nil) then
            fieldList = g_fieldManager.fields or g_fieldManager.fieldList or g_fieldManager.idToField
        end

        local candidateFields = {}
        if fieldList then
            for _, f in pairs(fieldList) do
                local fid = (f.getId and f:getId()) or f.fieldId or f.id
                if fid and fid > 0 then
                    local fFarmland = (f.getFarmland and f:getFarmland()) or f.farmland
                    local ffml = (fFarmland and ((fFarmland.getId and fFarmland:getId()) or fFarmland.id)) or f.farmlandId
                    if (not ffml or ffml == 0) and g_farmlandManager and g_farmlandManager.getFarmlandIdAtWorldPosition then
                        if f.rootNode and f.rootNode ~= 0 and entityExists(f.rootNode) then
                            local fx, _, fz = getWorldTranslation(f.rootNode)
                            ffml = g_farmlandManager:getFarmlandIdAtWorldPosition(fx, fz)
                        elseif f.fieldPositionX and f.fieldPositionZ then
                            ffml = g_farmlandManager:getFarmlandIdAtWorldPosition(f.fieldPositionX, f.fieldPositionZ)
                        elseif f.posX and f.posZ then
                            ffml = g_farmlandManager:getFarmlandIdAtWorldPosition(f.posX, f.posZ)
                        end
                    end

                    -- Check if field belongs to this farmland parcel or shares 1:1 ID mapping
                    local isMatch = (ffml == fmlId)
                    if not isMatch and fid == fmlId then
                        isMatch = true
                    end

                    if isMatch then
                        table.insert(candidateFields, { field = f, id = fid })
                    end
                end
            end
        end

        if #candidateFields == 1 then
            return candidateFields[1].field, candidateFields[1].id, fmlId
        elseif #candidateFields > 1 then
            -- Multiple fields on same parcel: pick closest center
            local bestField = candidateFields[1].field
            local bestId = candidateFields[1].id
            local bestDistSq = math.huge
            for _, cand in ipairs(candidateFields) do
                local cx, cz = nil, nil
                local f = cand.field
                if f.rootNode and f.rootNode ~= 0 and entityExists(f.rootNode) then
                    cx, _, cz = getWorldTranslation(f.rootNode)
                elseif f.fieldPositionX and f.fieldPositionZ then
                    cx, cz = f.fieldPositionX, f.fieldPositionZ
                elseif f.posX and f.posZ then
                    cx, cz = f.posX, f.posZ
                end
                local distSq = 0
                if cx and cz then
                    distSq = (cx - wx)^2 + (cz - wz)^2
                end
                if distSq < bestDistSq then
                    bestDistSq = distSq
                    bestField = f
                    bestId = cand.id
                end
            end
            return bestField, bestId, fmlId
        end
    end

    -- Also check cutter node if combine is provided and fmlId did not find a field
    if vehicle and vehicle.spec_combine and vehicle.spec_combine.attachedCutters then
        for c, _ in pairs(vehicle.spec_combine.attachedCutters) do
            if c.rootNode then
                local cx, _, cz = getWorldTranslation(c.rootNode)
                if math.abs(cx - wx) > 0.5 or math.abs(cz - wz) > 0.5 then
                    local cf, cfid, cfml = RHM_HarvestTracker.getFieldAtWorldPosition(cx, cz, nil)
                    if cfid and cfid > 0 then
                        return cf, cfid, cfml
                    end
                end
            end
        end
    end

    -- Farmland exists (fmlId > 0), but no field is registered on it (e.g. farm yard, woods, empty meadows)
    return nil, 0, fmlId
end

---Processes a single harvesting simulation tick on the server
function RHM_HarvestTracker:onCombineHarvestTick(combine, farmId, liters, massKg, areaHa, fieldId, totalLossPct, lossReasons, speedKmh, loadRatio, dt)
    if not g_currentMission:getIsServer() then return end
    if liters <= 0 then return end

    local farm = self:getFarmData(farmId)
    local machineKey = combine.configFileName or (combine.getFullName and combine:getFullName()) or "Harvester"
    local trip = farm.currentTrip

    -- Maintain per-machine trip record
    farm.combineTrips = farm.combineTrips or {}
    if not farm.combineTrips[machineKey] then
        if trip and (trip.harvestedLiters or 0) > 0 and (trip.lastMachineKey == nil or trip.lastMachineKey == machineKey) then
            farm.combineTrips[machineKey] = {
                fieldId = trip.fieldId or 0,
                isContract = trip.isContract or false,
                cropName = trip.cropName or "--",
                fillTypeIndex = trip.fillTypeIndex or FillType.UNKNOWN,
                harvestedAreaHa = trip.harvestedAreaHa or 0,
                harvestedLiters = trip.harvestedLiters or 0,
                harvestedMassKg = trip.harvestedMassKg or 0,
                lostLiters = trip.lostLiters or 0,
                lossMoney = trip.lossMoney or 0,
                sessionDuration = trip.sessionDuration or 0,
                avgSpeedSum = trip.avgSpeedSum or 0,
                avgSpeedCount = trip.avgSpeedCount or 0,
                avgLoadSum = trip.avgLoadSum or 0,
                avgLoadCount = trip.avgLoadCount or 0,
                efficiencyRank = trip.efficiencyRank or RHM_HarvestTracker.RANK_A,
                reasons = {
                    speed = trip.reasons and trip.reasons.speed or 0,
                    moisture = trip.reasons and trip.reasons.moisture or 0,
                    wear = trip.reasons and trip.reasons.wear or 0,
                    slope = trip.reasons and trip.reasons.slope or 0
                },
                isActive = true
            }
        else
            farm.combineTrips[machineKey] = {
                fieldId = 0,
                isContract = false,
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

    -- Auto-reset: Check for automatic field or crop transition for THIS specific combine
    local autoResetEnabled = farm.farmSettings.autoResetOnFieldChange ~= false
    if autoResetEnabled and mTrip then
        local currentFillType = (combine.spec_rhm_Combine and combine.spec_rhm_Combine.lastFillType) or FillType.UNKNOWN
        local fieldChanged = (fieldId > 0 and mTrip.fieldId > 0 and mTrip.fieldId ~= fieldId and ((mTrip.harvestedLiters or 0) > 50 or (mTrip.harvestedAreaHa or 0) > 0.01))
        local cropChanged = (currentFillType ~= FillType.UNKNOWN and mTrip.fillTypeIndex ~= FillType.UNKNOWN and mTrip.fillTypeIndex ~= currentFillType and (mTrip.harvestedLiters or 0) > 50)

        if fieldChanged or cropChanged then
            self:archiveAndResetCombineTrip(farmId, machineKey, combine)
            mTrip = farm.combineTrips[machineKey]
            trip = farm.currentTrip
        end
    end

    if updateFarmTrip then
        trip.lastMachineKey = machineKey
    end

    local isContract = RHM_HarvestTracker.isContractField(fieldId, farmId)
    if fieldId > 0 then
        if updateFarmTrip then
            trip.fieldId = fieldId
            trip.isContract = isContract
        end
        mTrip.fieldId = fieldId
        mTrip.isContract = isContract
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

    -- Update fleet statistics for this combine (only farm-owned combines, never contract/mission rentals)
    if not RHM_HarvestTracker.isMissionCombine(combine) then
        local machineKey = combine.configFileName or (combine.getFullName and combine:getFullName()) or "Harvester"
        if not farm.fleetStats[machineKey] then
            farm.fleetStats[machineKey] = {
                name = (combine.getFullName and combine:getFullName()) or machineKey or "Harvester",
                workSeconds = 0,
                totalHarvested = 0,
                totalLost = 0
            }
        end
        local fleetEntry = farm.fleetStats[machineKey]
        fleetEntry.workSeconds = fleetEntry.workSeconds + (dt * 0.001)
        fleetEntry.totalHarvested = fleetEntry.totalHarvested + liters
        fleetEntry.totalLost = fleetEntry.totalLost + lostLiters
    end

    -- Year-by-Year Season Aggregation (continuous tracking across game years)
    local currentYear = 1
    if g_currentMission and g_currentMission.environment and g_currentMission.environment.currentYear then
        currentYear = g_currentMission.environment.currentYear
    end
    farm.yearlyStats = farm.yearlyStats or {}
    if not farm.yearlyStats[currentYear] then
        farm.yearlyStats[currentYear] = {
            year = currentYear,
            harvestedLiters = 0,
            harvestedMassKg = 0,
            harvestedAreaHa = 0,
            lostLiters = 0,
            lossMoney = 0,
            sessionDuration = 0,
            avgSpeedSum = 0,
            avgSpeedCount = 0,
            avgLoadSum = 0,
            avgLoadCount = 0,
            fieldOperations = 0,
            reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
            cropVolumes = {}
        }
    end
    local yStat = farm.yearlyStats[currentYear]
    yStat.harvestedLiters = yStat.harvestedLiters + liters
    yStat.harvestedMassKg = yStat.harvestedMassKg + massKg
    yStat.harvestedAreaHa = yStat.harvestedAreaHa + areaHa
    yStat.sessionDuration = yStat.sessionDuration + (dt * 0.001)
    yStat.lostLiters = yStat.lostLiters + lostLiters
    yStat.lossMoney = yStat.lossMoney + lossMoneyThisTick

    if speedKmh and speedKmh > 0.5 then
        yStat.avgSpeedSum = yStat.avgSpeedSum + speedKmh
        yStat.avgSpeedCount = yStat.avgSpeedCount + 1
    end
    if loadRatio and loadRatio > 0.05 then
        yStat.avgLoadSum = yStat.avgLoadSum + loadRatio
        yStat.avgLoadCount = yStat.avgLoadCount + 1
    end

    if lossReasons and lostLiters > 0 then
        local sumPcts = (lossReasons.speedPct or 0) + (lossReasons.moisturePct or 0) + (lossReasons.wearPct or 0) + (lossReasons.slopePct or 0)
        if sumPcts > 0.001 then
            yStat.reasons.speed = yStat.reasons.speed + (lostLiters * ((lossReasons.speedPct or 0) / sumPcts))
            yStat.reasons.moisture = yStat.reasons.moisture + (lostLiters * ((lossReasons.moisturePct or 0) / sumPcts))
            yStat.reasons.wear = yStat.reasons.wear + (lostLiters * ((lossReasons.wearPct or 0) / sumPcts))
            yStat.reasons.slope = yStat.reasons.slope + (lostLiters * ((lossReasons.slopePct or 0) / sumPcts))
        else
            yStat.reasons.speed = yStat.reasons.speed + lostLiters
        end
    end

    local activeCropName = (trip and trip.cropName) or (mTrip and mTrip.cropName)
    if activeCropName and activeCropName ~= "UNKNOWN" and activeCropName ~= "--" and activeCropName ~= "" then
        yStat.cropVolumes = yStat.cropVolumes or {}
        yStat.cropVolumes[activeCropName] = (yStat.cropVolumes[activeCropName] or 0) + liters
    end

    -- Field-by-Field Farm Statistics Accumulation
    if fieldId > 0 then
        farm.fieldStats = farm.fieldStats or {}
        if not farm.fieldStats[fieldId] then
            farm.fieldStats[fieldId] = {
                fieldId = fieldId,
                harvestedLiters = 0,
                harvestedMassKg = 0,
                harvestedAreaHa = 0,
                lostLiters = 0,
                lossMoney = 0,
                sessionDuration = 0,
                avgSpeedSum = 0,
                avgSpeedCount = 0,
                avgLoadSum = 0,
                avgLoadCount = 0,
                isContract = isContract,
                lastCrop = activeCropName or "--",
                operationsCount = 0,
                lastYear = currentYear,
                reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
                cropVolumes = {}
            }
        end
        local fStat = farm.fieldStats[fieldId]
        fStat.harvestedLiters = (fStat.harvestedLiters or 0) + liters
        fStat.harvestedMassKg = (fStat.harvestedMassKg or 0) + massKg
        fStat.harvestedAreaHa = (fStat.harvestedAreaHa or 0) + areaHa
        fStat.sessionDuration = (fStat.sessionDuration or 0) + (dt * 0.001)
        fStat.lostLiters = (fStat.lostLiters or 0) + lostLiters
        fStat.lossMoney = (fStat.lossMoney or 0) + lossMoneyThisTick
        fStat.isContract = (fStat.isContract == true) or isContract
        fStat.lastYear = currentYear
        fStat.reasons = fStat.reasons or { speed = 0, moisture = 0, wear = 0, slope = 0 }
        if lossReasons and lostLiters > 0 then
            local sumPcts = (lossReasons.speedPct or 0) + (lossReasons.moisturePct or 0) + (lossReasons.wearPct or 0) + (lossReasons.slopePct or 0)
            if sumPcts > 0.001 then
                fStat.reasons.speed = (fStat.reasons.speed or 0) + (lostLiters * ((lossReasons.speedPct or 0) / sumPcts))
                fStat.reasons.moisture = (fStat.reasons.moisture or 0) + (lostLiters * ((lossReasons.moisturePct or 0) / sumPcts))
                fStat.reasons.wear = (fStat.reasons.wear or 0) + (lostLiters * ((lossReasons.wearPct or 0) / sumPcts))
                fStat.reasons.slope = (fStat.reasons.slope or 0) + (lostLiters * ((lossReasons.slopePct or 0) / sumPcts))
            else
                fStat.reasons.speed = (fStat.reasons.speed or 0) + lostLiters
            end
        end
        if activeCropName and activeCropName ~= "UNKNOWN" and activeCropName ~= "--" and activeCropName ~= "" then
            fStat.lastCrop = activeCropName
            fStat.lastCropName = activeCropName
            fStat.cropVolumes = fStat.cropVolumes or {}
            fStat.cropVolumes[activeCropName] = (fStat.cropVolumes[activeCropName] or 0) + liters
        end
        if speedKmh and speedKmh > 0.5 then
            fStat.avgSpeedSum = (fStat.avgSpeedSum or 0) + speedKmh
            fStat.avgSpeedCount = (fStat.avgSpeedCount or 0) + 1
        end
        if loadRatio and loadRatio > 0.05 then
            fStat.avgLoadSum = (fStat.avgLoadSum or 0) + loadRatio
            fStat.avgLoadCount = (fStat.avgLoadCount or 0) + 1
        end
    end

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

        farm.yearlyStats = farm.yearlyStats or {}
        if not farm.yearlyStats[currentYear] then
            farm.yearlyStats[currentYear] = {
                year = currentYear,
                harvestedLiters = 0,
                harvestedMassKg = 0,
                harvestedAreaHa = 0,
                lostLiters = 0,
                lossMoney = 0,
                sessionDuration = 0,
                avgSpeedSum = 0,
                avgSpeedCount = 0,
                avgLoadSum = 0,
                avgLoadCount = 0,
                fieldOperations = 0,
                reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
                cropVolumes = {}
            }
        end
        farm.yearlyStats[currentYear].fieldOperations = (farm.yearlyStats[currentYear].fieldOperations or 0) + 1

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

---EN: Archives a specific combine's trip to season history and resets its odometer
---UA: Архівує сесію конкретного комбайна в історію сезону та скидає його одометр
function RHM_HarvestTracker:archiveAndResetCombineTrip(farmId, machineKey, combine)
    if not farmId or not machineKey then return false end
    local farm = self:getFarmData(farmId)
    local mTrip = farm.combineTrips and farm.combineTrips[machineKey]
    if not mTrip then return false end

    -- Archive only if there is meaningful harvest data (> 50 L or > 0.01 ha)
    if (mTrip.harvestedLiters and mTrip.harvestedLiters > 50) or (mTrip.harvestedAreaHa and mTrip.harvestedAreaHa > 0.01) then
        local currentYear = 1
        if g_currentMission and g_currentMission.environment and g_currentMission.environment.currentYear then
            currentYear = g_currentMission.environment.currentYear
        end

        farm.yearlyStats = farm.yearlyStats or {}
        if not farm.yearlyStats[currentYear] then
            farm.yearlyStats[currentYear] = {
                year = currentYear,
                harvestedLiters = 0,
                harvestedMassKg = 0,
                harvestedAreaHa = 0,
                lostLiters = 0,
                lossMoney = 0,
                sessionDuration = 0,
                avgSpeedSum = 0,
                avgSpeedCount = 0,
                avgLoadSum = 0,
                avgLoadCount = 0,
                fieldOperations = 0,
                reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
                cropVolumes = {}
            }
        end
        farm.yearlyStats[currentYear].fieldOperations = (farm.yearlyStats[currentYear].fieldOperations or 0) + 1

        local totalBio = (mTrip.harvestedLiters or 0) + (mTrip.lostLiters or 0)
        local lossPct = (totalBio > 0) and (((mTrip.lostLiters or 0) / totalBio) * 100.0) or 0
        local record = {
            year = currentYear,
            fieldId = mTrip.fieldId or 0,
            isContract = (mTrip.isContract == true),
            cropName = mTrip.cropName or "UNKNOWN",
            harvested = mTrip.harvestedLiters or 0,
            lost = mTrip.lostLiters or 0,
            lossMoney = mTrip.lossMoney or 0,
            areaHa = mTrip.harvestedAreaHa or 0,
            efficiencyRank = mTrip.efficiencyRank or "A",
            dominantReason = RHM_HarvestTracker.getDominantLossFactor(mTrip.reasons),
            machineName = (combine and combine.getFullName and combine:getFullName()) or machineKey,
            timestamp = (getDate and getDate("%Y-%m-%d %H:%M:%S")) or (g_currentMission and g_currentMission.time) or 0
        }
        table.insert(farm.seasonHistory, 1, record)
        if #farm.seasonHistory > 50 then
            table.remove(farm.seasonHistory)
        end

        if mTrip.fieldId and mTrip.fieldId > 0 and farm.fieldStats and farm.fieldStats[mTrip.fieldId] then
            farm.fieldStats[mTrip.fieldId].operationsCount = (farm.fieldStats[mTrip.fieldId].operationsCount or 0) + 1
        end

        rhm_log(string.format("RHM [Tracker]: Auto-archived field session for %s: field=%d, contract=%s, crop=%s, harvest=%.0f L, area=%.2f ha",
            tostring(record.machineName), record.fieldId, tostring(record.isContract), tostring(record.cropName), record.harvested, record.areaHa))
    end

    -- Reset per-machine trip record
    mTrip.harvestedLiters = 0
    mTrip.harvestedMassKg = 0
    mTrip.harvestedAreaHa = 0
    mTrip.lostLiters = 0
    mTrip.lossMoney = 0
    mTrip.sessionDuration = 0
    mTrip.avgSpeedSum = 0
    mTrip.avgSpeedCount = 0
    mTrip.avgLoadSum = 0
    mTrip.avgLoadCount = 0
    mTrip.efficiencyRank = RHM_HarvestTracker.RANK_A
    mTrip.reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 }
    mTrip.isActive = false
    mTrip.fieldId = 0
    mTrip.isContract = false
    mTrip.cropName = "--"
    mTrip.fillTypeIndex = FillType.UNKNOWN

    if combine and combine.spec_rhm_Combine then
        combine.spec_rhm_Combine.trip = mTrip
        combine.spec_rhm_Combine.fieldDepartureTimer = 0
    end

    -- If farm.currentTrip belongs to this machine, also reset farm.currentTrip
    if farm.currentTrip and (farm.currentTrip.lastMachineKey == nil or farm.currentTrip.lastMachineKey == machineKey) then
        farm.currentTrip.harvestedLiters = 0
        farm.currentTrip.harvestedMassKg = 0
        farm.currentTrip.harvestedAreaHa = 0
        farm.currentTrip.lostLiters = 0
        farm.currentTrip.lossMoney = 0
        farm.currentTrip.sessionDuration = 0
        farm.currentTrip.avgSpeedSum = 0
        farm.currentTrip.avgSpeedCount = 0
        farm.currentTrip.avgLoadSum = 0
        farm.currentTrip.avgLoadCount = 0
        farm.currentTrip.efficiencyRank = RHM_HarvestTracker.RANK_A
        farm.currentTrip.reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 }
        farm.currentTrip.isActive = false
        farm.currentTrip.fieldId = 0
        farm.currentTrip.isContract = false
        farm.currentTrip.cropName = "--"
        farm.currentTrip.fillTypeIndex = FillType.UNKNOWN
        farm.currentTrip.lastMachineKey = nil
    end

    self.isDirty = true
    return true
end



---EN: Returns list of available recorded years plus 'ALL' for multi-season navigation
---UA: Повертає список доступних років збору плюс 'ALL' для навігації по сезонах
function RHM_HarvestTracker:getAvailableYears(farmId)
    local farm = self:getFarmData(farmId)
    local yearsMap = {}
    local currentYear = 1
    if g_currentMission and g_currentMission.environment and g_currentMission.environment.currentYear then
        currentYear = g_currentMission.environment.currentYear
    end
    yearsMap[currentYear] = true

    if farm.yearlyStats then
        for y, _ in pairs(farm.yearlyStats) do
            if type(y) == "number" then
                yearsMap[y] = true
            end
        end
    end

    if farm.seasonHistory then
        for _, rec in ipairs(farm.seasonHistory) do
            if rec.year and type(rec.year) == "number" then
                yearsMap[rec.year] = true
            end
        end
    end

    local yearsList = {}
    for y, _ in pairs(yearsMap) do
        table.insert(yearsList, y)
    end
    table.sort(yearsList)

    -- Append ALL-TIME as the final aggregation option
    table.insert(yearsList, "ALL")
    return yearsList
end

---EN: Returns comprehensive aggregate telemetry and financial summary for a specific year or all seasons
---UA: Повертає повний підсумок телеметрії, площ, намолоту та фінансів для обраного року або за весь час
function RHM_HarvestTracker:getSeasonSummary(farmId, targetYear)
    local farm = self:getFarmData(farmId)
    local isAllTime = (targetYear == "ALL" or targetYear == nil)

    local currentYear = 1
    if g_currentMission and g_currentMission.environment and g_currentMission.environment.currentYear then
        currentYear = g_currentMission.environment.currentYear
    end

    local summary = {
        year = targetYear or "ALL",
        isAllTime = isAllTime,
        isCurrent = (not isAllTime and tonumber(targetYear) == currentYear),
        harvestedLiters = 0,
        harvestedMassKg = 0,
        harvestedAreaHa = 0,
        lostLiters = 0,
        lossMoney = 0,
        sessionDuration = 0,
        avgSpeedSum = 0,
        avgSpeedCount = 0,
        avgLoadSum = 0,
        avgLoadCount = 0,
        fieldOperations = 0,
        reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
        cropVolumes = {}
    }

    local function mergeStat(stat)
        if not stat then return end
        summary.harvestedLiters = summary.harvestedLiters + (stat.harvestedLiters or 0)
        summary.harvestedMassKg = summary.harvestedMassKg + (stat.harvestedMassKg or ((stat.harvestedLiters or 0) * 0.75))
        summary.harvestedAreaHa = summary.harvestedAreaHa + (stat.harvestedAreaHa or 0)
        summary.lostLiters = summary.lostLiters + (stat.lostLiters or 0)
        summary.lossMoney = summary.lossMoney + (stat.lossMoney or 0)
        summary.sessionDuration = summary.sessionDuration + (stat.sessionDuration or 0)
        summary.avgSpeedSum = summary.avgSpeedSum + (stat.avgSpeedSum or 0)
        summary.avgSpeedCount = summary.avgSpeedCount + (stat.avgSpeedCount or 0)
        summary.avgLoadSum = summary.avgLoadSum + (stat.avgLoadSum or 0)
        summary.avgLoadCount = summary.avgLoadCount + (stat.avgLoadCount or 0)
        summary.fieldOperations = summary.fieldOperations + (stat.fieldOperations or 0)

        if stat.reasons then
            summary.reasons.speed = summary.reasons.speed + (stat.reasons.speed or 0)
            summary.reasons.moisture = summary.reasons.moisture + (stat.reasons.moisture or 0)
            summary.reasons.wear = summary.reasons.wear + (stat.reasons.wear or 0)
            summary.reasons.slope = summary.reasons.slope + (stat.reasons.slope or 0)
        end

        if stat.cropVolumes then
            for cName, vol in pairs(stat.cropVolumes) do
                summary.cropVolumes[cName] = (summary.cropVolumes[cName] or 0) + vol
            end
        end
    end

    if isAllTime then
        if farm.yearlyStats then
            for _, stat in pairs(farm.yearlyStats) do
                mergeStat(stat)
            end
        end

        -- Legacy savegame bootstrap: if yearlyStats was empty, extract totals from seasonHistory
        if summary.harvestedLiters <= 0 and farm.seasonHistory and #farm.seasonHistory > 0 then
            for _, rec in ipairs(farm.seasonHistory) do
                summary.harvestedLiters = summary.harvestedLiters + (rec.harvested or 0)
                summary.harvestedMassKg = summary.harvestedMassKg + ((rec.harvested or 0) * 0.75)
                summary.harvestedAreaHa = summary.harvestedAreaHa + (rec.areaHa or 0)
                summary.lostLiters = summary.lostLiters + (rec.lost or 0)
                summary.lossMoney = summary.lossMoney + (rec.lossMoney or 0)
                summary.fieldOperations = summary.fieldOperations + 1
                if rec.cropName and rec.cropName ~= "UNKNOWN" and rec.cropName ~= "--" then
                    summary.cropVolumes[rec.cropName] = (summary.cropVolumes[rec.cropName] or 0) + (rec.harvested or 0)
                end
            end
        end
    else
        local y = tonumber(targetYear) or 1
        if farm.yearlyStats and farm.yearlyStats[y] then
            mergeStat(farm.yearlyStats[y])
        end

        -- Legacy bootstrap or operation count verification from seasonHistory
        if farm.seasonHistory then
            local count = 0
            for _, rec in ipairs(farm.seasonHistory) do
                if rec.year == y then
                    count = count + 1
                    if not farm.yearlyStats or not farm.yearlyStats[y] then
                        summary.harvestedLiters = summary.harvestedLiters + (rec.harvested or 0)
                        summary.harvestedMassKg = summary.harvestedMassKg + ((rec.harvested or 0) * 0.75)
                        summary.harvestedAreaHa = summary.harvestedAreaHa + (rec.areaHa or 0)
                        summary.lostLiters = summary.lostLiters + (rec.lost or 0)
                        summary.lossMoney = summary.lossMoney + (rec.lossMoney or 0)
                        if rec.cropName and rec.cropName ~= "UNKNOWN" and rec.cropName ~= "--" then
                            summary.cropVolumes[rec.cropName] = (summary.cropVolumes[rec.cropName] or 0) + (rec.harvested or 0)
                        end
                    end
                end
            end
            if summary.fieldOperations == 0 or count > summary.fieldOperations then
                summary.fieldOperations = count
            end
        end
    end

    -- Derived calculated values
    summary.harvestedTons = (summary.harvestedMassKg or 0) * 0.001
    if summary.harvestedTons <= 0 and summary.harvestedLiters > 0 then
        summary.harvestedTons = summary.harvestedLiters * 0.00075
    end

    summary.lostTons = (summary.lostLiters or 0) * 0.00075
    summary.avgYield = (summary.harvestedAreaHa > 0.01) and (summary.harvestedTons / summary.harvestedAreaHa) or 0

    local workHours = (summary.sessionDuration or 0) / 3600.0
    summary.throughput = (workHours > 0.01) and (summary.harvestedTons / workHours) or 0

    local totalBio = summary.harvestedLiters + summary.lostLiters
    summary.lossPct = (totalBio > 0) and ((summary.lostLiters / totalBio) * 100.0) or 0

    summary.efficiencyRank = RHM_HarvestTracker.calculateEfficiencyRank(summary.lossPct)
    summary.dominantReason = RHM_HarvestTracker.getDominantLossFactor(summary.reasons)

    summary.avgSpeed = (summary.avgSpeedCount > 0) and (summary.avgSpeedSum / summary.avgSpeedCount) or 0
    summary.avgLoad = (summary.avgLoadCount > 0) and ((summary.avgLoadSum / summary.avgLoadCount) * 100.0) or 0

    -- Sort top crops by harvested volume
    local sortedCrops = {}
    for cName, vol in pairs(summary.cropVolumes) do
        table.insert(sortedCrops, { name = cName, liters = vol })
    end
    table.sort(sortedCrops, function(a, b) return a.liters > b.liters end)

    local cropTitles = {}
    for i = 1, math.min(#sortedCrops, 3) do
        local cName = sortedCrops[i].name
        local title = cName
        if g_fillTypeManager then
            local ft = g_fillTypeManager:getFillTypeByName(cName)
            if ft and ft.title and ft.title ~= "" then
                title = ft.title
            end
        end
        table.insert(cropTitles, title)
    end
    summary.topCropsText = (#cropTitles > 0) and table.concat(cropTitles, ", ") or "--"

    return summary
end

---EN: Queries all farm fields (both owned land and active/completed contract fields) with production metrics.
---UA: Отримує повний список полів ферми (власні угіддя та контрактні роботи) з метриками врожайності.
---@param farmId number
---@return table fieldList
function RHM_HarvestTracker:getFarmFields(farmId)
    local farm = self:getFarmData(farmId)
    local result = {}
    local seen = {}

    -- 1. Query owned farmlands from FarmlandManager
    local ownedFarmlands = {}
    if g_farmlandManager then
        if g_farmlandManager.getOwnedFarmlandIdsByFarmId then
            local ids = g_farmlandManager:getOwnedFarmlandIdsByFarmId(farmId)
            if ids then
                for _, id in pairs(ids) do
                    if type(id) == "number" and id > 0 then
                        ownedFarmlands[id] = true
                    end
                end
            end
        end
        if g_farmlandManager.farmlands then
            for fmlId, fml in pairs(g_farmlandManager.farmlands) do
                local owner = fml.ownerFarmId
                if (not owner or owner == 0) and g_farmlandManager.getFarmlandOwner then
                    owner = g_farmlandManager:getFarmlandOwner(fmlId)
                end
                if owner == farmId then
                    ownedFarmlands[fmlId] = true
                end
            end
        end
        if next(ownedFarmlands) == nil and g_farmlandManager.getFarmlandOwner then
            for fmlId = 1, 255 do
                if g_farmlandManager:getFarmlandOwner(fmlId) == farmId then
                    ownedFarmlands[fmlId] = true
                end
            end
        end
    end

    -- Helper to resolve farmland ID for any field object
    local function resolveFarmlandId(field)
        if not field then return 0 end
        if field.farmlandId and type(field.farmlandId) == "number" and field.farmlandId > 0 then
            return field.farmlandId
        end
        local fl = (field.getFarmland and field:getFarmland()) or field.farmland
        if fl then
            local flid = (fl.getId and fl:getId()) or fl.id or fl.farmlandId
            if flid and type(flid) == "number" and flid > 0 then
                return flid
            end
        end
        if g_farmlandManager and g_farmlandManager.getFarmlandIdAtWorldPosition then
            if field.rootNode and field.rootNode ~= 0 and entityExists(field.rootNode) then
                local wx, _, wz = getWorldTranslation(field.rootNode)
                local fid = g_farmlandManager:getFarmlandIdAtWorldPosition(wx, wz)
                if fid and fid > 0 then return fid end
            end
            if field.fieldPositionX and field.fieldPositionZ then
                local fid = g_farmlandManager:getFarmlandIdAtWorldPosition(field.fieldPositionX, field.fieldPositionZ)
                if fid and fid > 0 then return fid end
            end
            if field.posX and field.posZ then
                local fid = g_farmlandManager:getFarmlandIdAtWorldPosition(field.posX, field.posZ)
                if fid and fid > 0 then return fid end
            end
            if field.mapMarker and field.mapMarker ~= 0 and entityExists(field.mapMarker) then
                local wx, _, wz = getWorldTranslation(field.mapMarker)
                local fid = g_farmlandManager:getFarmlandIdAtWorldPosition(wx, wz)
                if fid and fid > 0 then return fid end
            end
        end
        local fid = (field.getId and field:getId()) or field.fieldId or field.id
        if fid and fid > 0 and ownedFarmlands[fid] then
            return fid
        end
        return 0
    end

    -- Helper to calculate nominal area in hectares
    local function resolveFieldAreaHa(field, fmlId)
        local aHa = 0
        if field then
            if field.areaInHa and field.areaInHa > 0 then
                aHa = field.areaInHa
            elseif field.fieldArea and field.fieldArea > 0 then
                aHa = (field.fieldArea > 100) and (field.fieldArea / 10000.0) or field.fieldArea
            elseif field.area and field.area > 0 then
                aHa = (field.area > 100) and (field.area / 10000.0) or field.area
            elseif field.getArea then
                local a = field:getArea() or 0
                aHa = (a > 100) and (a / 10000.0) or a
            end
        end
        if aHa <= 0 and fmlId and fmlId > 0 and g_farmlandManager then
            if g_farmlandManager.getFarmlandArea then
                aHa = g_farmlandManager:getFarmlandArea(fmlId) or 0
            end
            if aHa <= 0 and g_farmlandManager.farmlands and g_farmlandManager.farmlands[fmlId] then
                local fl = g_farmlandManager.farmlands[fmlId]
                aHa = fl.areaInHa or fl.area or (fl.totalArea and fl.totalArea / 10000.0) or 0
            end
        end
        return aHa
    end

    -- 2. Query fields from game engine FieldManager
    local fieldList = nil
    if g_fieldManager then
        if g_fieldManager.getFields then
            fieldList = g_fieldManager:getFields()
        end
        if not fieldList or (type(fieldList) == "table" and next(fieldList) == nil) then
            fieldList = g_fieldManager.fields or g_fieldManager.fieldList or g_fieldManager.idToField
        end
        if not fieldList or (type(fieldList) == "table" and next(fieldList) == nil) then
            if g_fieldManager.getFieldById then
                fieldList = {}
                for id = 1, 255 do
                    local f = g_fieldManager:getFieldById(id)
                    if f then
                        table.insert(fieldList, f)
                    end
                end
            end
        end
    end

    if fieldList then
        for _, field in pairs(fieldList) do
            local fid = (field.getId and field:getId()) or field.fieldId or field.id
            if fid and fid > 0 then
                local fmlId = resolveFarmlandId(field)
                local isOwned = (fmlId > 0 and ownedFarmlands[fmlId] == true)
                             or (fid > 0 and ownedFarmlands[fid] == true)
                             or (fmlId > 0 and g_farmlandManager and g_farmlandManager.getFarmlandOwner and g_farmlandManager:getFarmlandOwner(fmlId) == farmId)

                if isOwned then
                    seen[fid] = true
                    local areaHa = resolveFieldAreaHa(field, fmlId)
                    local fStat = farm.fieldStats and farm.fieldStats[fid]

                    local totalHArea = (fStat and fStat.harvestedAreaHa) or 0
                    local totalHLiters = (fStat and fStat.harvestedLiters) or 0
                    local totalHMass = (fStat and fStat.harvestedMassKg) or 0
                    local totalLostL = (fStat and fStat.lostLiters) or 0
                    local totalMoney = (fStat and fStat.lossMoney) or 0
                    local totalDuration = (fStat and fStat.sessionDuration) or 0

                    local cropName = (fStat and (fStat.lastCropName or fStat.lastCrop)) or "--"
                    if cropName == "--" and farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.cropName and farm.currentTrip.cropName ~= "--" and farm.currentTrip.cropName ~= "UNKNOWN" then
                        cropName = farm.currentTrip.cropName
                    end
                    if cropName == "--" then
                        local cx, cz = nil, nil
                        if field.rootNode and field.rootNode ~= 0 and entityExists(field.rootNode) then
                            cx, _, cz = getWorldTranslation(field.rootNode)
                        elseif field.fieldPositionX and field.fieldPositionZ then
                            cx, cz = field.fieldPositionX, field.fieldPositionZ
                        elseif field.posX and field.posZ then
                            cx, cz = field.posX, field.posZ
                        end
                        if cx and cz and FSDensityMapUtil and FSDensityMapUtil.getFieldFruitTypeAtWorldPos then
                            local fruitType = FSDensityMapUtil.getFieldFruitTypeAtWorldPos(cx, cz)
                            if fruitType and fruitType ~= FruitType.UNKNOWN and g_fruitTypeManager then
                                local ftIdx = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(fruitType)
                                if ftIdx and ftIdx ~= FillType.UNKNOWN and g_fillTypeManager then
                                    local ftDesc = g_fillTypeManager:getFillTypeByIndex(ftIdx)
                                    if ftDesc and ftDesc.title and ftDesc.title ~= "" then
                                        cropName = ftDesc.title
                                    end
                                end
                            end
                        end
                    end

                    local fReasons = (fStat and fStat.reasons) or { speed = 0, moisture = 0, wear = 0, slope = 0 }
                    local ops = (fStat and fStat.operationsCount) or 0
                    if ops == 0 and (totalHLiters > 50 or totalHArea > 0.01) then
                        ops = 1
                    end

                    table.insert(result, {
                        fieldId = fid,
                        isOwned = true,
                        isContract = false,
                        nominalAreaHa = areaHa,
                        harvestedAreaHa = totalHArea,
                        harvestedLiters = totalHLiters,
                        harvestedMassKg = totalHMass,
                        lostLiters = totalLostL,
                        lossMoney = totalMoney,
                        sessionDuration = totalDuration,
                        lastCrop = cropName,
                        cropVolumes = (fStat and fStat.cropVolumes) or {},
                        operationsCount = ops,
                        lastYear = (fStat and fStat.lastYear) or 1,
                        reasons = fReasons
                    })
                end
            end
        end
    end

    -- 3. Any owned farmland that wasn't matched to an engine field object (e.g. bought parcels, custom plots)
    for fmlId, _ in pairs(ownedFarmlands) do
        if not seen[fmlId] then
            local fStat = farm.fieldStats and farm.fieldStats[fmlId]
            local totalHLiters = (fStat and fStat.harvestedLiters) or 0
            local totalHArea = (fStat and fStat.harvestedAreaHa) or 0
            local totalHMass = (fStat and fStat.harvestedMassKg) or 0
            local totalLostL = (fStat and fStat.lostLiters) or 0
            local totalMoney = (fStat and fStat.lossMoney) or 0
            local totalDuration = (fStat and fStat.sessionDuration) or 0

            -- Check if this farmland corresponds to a real registered engine field (e.g. Field 5 with grass)
            local isRealField = false
            local fieldObj = nil
            if g_fieldManager and g_fieldManager.getFieldById then
                fieldObj = g_fieldManager:getFieldById(fmlId)
                if fieldObj then
                    isRealField = true
                end
            end
            if not isRealField and fieldList then
                for _, f in pairs(fieldList) do
                    local fid = f.fieldId or f.id
                    if fid == fmlId then
                        isRealField = true
                        fieldObj = f
                        break
                    end
                end
            end

            -- Include if it is an actual registered field OR if the player actively harvested a custom plot!
            -- Unharvested non-field parcels (e.g. farm base yard 44, woods 63, empty meadows 39) are excluded.
            if isRealField or totalHLiters > 50 or totalHArea > 0.05 then
                seen[fmlId] = true
                local areaHa = resolveFieldAreaHa(fieldObj, fmlId)

                local cropName = (fStat and (fStat.lastCropName or fStat.lastCrop)) or "--"
                if cropName == "--" and farm.currentTrip and farm.currentTrip.fieldId == fmlId and farm.currentTrip.cropName and farm.currentTrip.cropName ~= "--" and farm.currentTrip.cropName ~= "UNKNOWN" then
                    cropName = farm.currentTrip.cropName
                end
                if cropName == "--" then
                    local cx, cz = nil, nil
                    if fieldObj then
                        if fieldObj.rootNode and fieldObj.rootNode ~= 0 and entityExists(fieldObj.rootNode) then
                            cx, _, cz = getWorldTranslation(fieldObj.rootNode)
                        elseif fieldObj.fieldPositionX and fieldObj.fieldPositionZ then
                            cx, cz = fieldObj.fieldPositionX, fieldObj.fieldPositionZ
                        elseif fieldObj.posX and fieldObj.posZ then
                            cx, cz = fieldObj.posX, fieldObj.posZ
                        end
                    end
                    if (not cx or not cz) and g_farmlandManager and g_farmlandManager.getFarmlandCenter then
                        cx, cz = g_farmlandManager:getFarmlandCenter(fmlId)
                    end
                    if cx and cz and FSDensityMapUtil and FSDensityMapUtil.getFieldFruitTypeAtWorldPos then
                        local fruitType = FSDensityMapUtil.getFieldFruitTypeAtWorldPos(cx, cz)
                        if fruitType and fruitType ~= FruitType.UNKNOWN and g_fruitTypeManager then
                            local ftIdx = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(fruitType)
                            if ftIdx and ftIdx ~= FillType.UNKNOWN and g_fillTypeManager then
                                local ftDesc = g_fillTypeManager:getFillTypeByIndex(ftIdx)
                                if ftDesc and ftDesc.title and ftDesc.title ~= "" then
                                    cropName = ftDesc.title
                                end
                            end
                        end
                    end
                end

                local fReasons = (fStat and fStat.reasons) or { speed = 0, moisture = 0, wear = 0, slope = 0 }
                local ops = (fStat and fStat.operationsCount) or 0
                if ops == 0 and (totalHLiters > 50 or totalHArea > 0.01) then
                    ops = 1
                end

                table.insert(result, {
                    fieldId = fmlId,
                    isOwned = true,
                    isContract = false,
                    nominalAreaHa = areaHa,
                    harvestedAreaHa = totalHArea,
                    harvestedLiters = totalHLiters,
                    harvestedMassKg = totalHMass,
                    lostLiters = totalLostL,
                    lossMoney = totalMoney,
                    sessionDuration = totalDuration,
                    lastCrop = cropName,
                    cropVolumes = (fStat and fStat.cropVolumes) or {},
                    operationsCount = ops,
                    lastYear = (fStat and fStat.lastYear) or 1,
                    reasons = fReasons
                })
            end
        end
    end

    -- 4. Add recorded fields from fieldStats that are contract missions or recorded external field operations
    if farm.fieldStats then
        local toRemove = nil
        for fid, fStat in pairs(farm.fieldStats) do
            if not seen[fid] then
                local totalHLiters = (fStat.harvestedLiters or 0)
                local totalHArea = (fStat.harvestedAreaHa or 0)
                local totalHMass = (fStat.harvestedMassKg or 0)
                local totalLostL = (fStat.lostLiters or 0)
                local totalMoney = (fStat.lossMoney or 0)
                local totalDuration = (fStat.sessionDuration or 0)
                local isNowContract = RHM_HarvestTracker.isContractField(fid, farmId)
                local isContract = (fStat.isContract == true) or isNowContract

                -- Filter out stray accidental cuts on unowned non-contract land (e.g. 2 liters cut on field 10)
                if isContract or totalHLiters > 50 or totalHArea > 0.05 then
                    seen[fid] = true

                    local cropName = (fStat.lastCropName or fStat.lastCrop) or "--"
                    if cropName == "--" and farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.cropName and farm.currentTrip.cropName ~= "--" and farm.currentTrip.cropName ~= "UNKNOWN" then
                        cropName = farm.currentTrip.cropName
                    end

                    local fReasons = fStat.reasons or { speed = 0, moisture = 0, wear = 0, slope = 0 }

                    -- Resolve authentic nominal area for contract/external field from fieldManager!
                    local areaHa = 0
                    if g_fieldManager and g_fieldManager.getFieldById then
                        local fObj = g_fieldManager:getFieldById(fid)
                        if fObj then
                            areaHa = resolveFieldAreaHa(fObj, nil)
                        end
                    end
                    if areaHa <= 0 then
                        areaHa = fStat.harvestedAreaHa or 0
                    end

                    local ops = fStat.operationsCount or 0
                    if ops == 0 and (totalHLiters > 50 or totalHArea > 0.01) then
                        ops = 1
                    end

                    table.insert(result, {
                        fieldId = fid,
                        isOwned = false,
                        isContract = isContract,
                        nominalAreaHa = areaHa,
                        harvestedAreaHa = totalHArea,
                        harvestedLiters = totalHLiters,
                        harvestedMassKg = totalHMass,
                        lostLiters = totalLostL,
                        lossMoney = totalMoney,
                        sessionDuration = totalDuration,
                        lastCrop = cropName,
                        cropVolumes = fStat.cropVolumes or {},
                        operationsCount = ops,
                        lastYear = fStat.lastYear or 1,
                        reasons = fReasons
                    })
                else
                    toRemove = toRemove or {}
                    table.insert(toRemove, fid)
                end
            end
        end
        if toRemove then
            for _, fid in ipairs(toRemove) do
                farm.fieldStats[fid] = nil
            end
        end
    end

    -- 5. Add active running contract fields from missionManager if any
    if g_missionManager and g_missionManager.missions then
        for _, mission in pairs(g_missionManager.missions) do
            if mission and mission.status == MissionStatus.RUNNING and mission.farmId == farmId then
                local fid = 0
                if mission.field and (mission.field.fieldId or mission.field.id) then
                    fid = mission.field.fieldId or mission.field.id
                elseif mission.fieldId then
                    fid = mission.fieldId
                end
                if fid > 0 and not seen[fid] then
                    seen[fid] = true
                    local liveHarvL = (farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.harvestedLiters) or 0
                    local liveHarvMass = (farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.harvestedMassKg) or 0
                    local liveAreaHa = (farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.harvestedAreaHa) or 0
                    local liveLostL = (farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.lostLiters) or 0
                    local liveMoney = (farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.lossMoney) or 0
                    local liveDuration = (farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.sessionDuration) or 0

                    local cropName = "--"
                    if mission.fillType and g_fillTypeManager then
                        local ft = g_fillTypeManager:getFillTypeByIndex(mission.fillType)
                        if ft and ft.name then cropName = ft.name end
                    end
                    if cropName == "--" and farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.cropName and farm.currentTrip.cropName ~= "--" and farm.currentTrip.cropName ~= "UNKNOWN" then
                        cropName = farm.currentTrip.cropName
                    end

                    local liveReasons = (farm.currentTrip and farm.currentTrip.fieldId == fid and farm.currentTrip.reasons) or nil
                    local fReasons = {
                        speed = (liveReasons and liveReasons.speed) or 0,
                        moisture = (liveReasons and liveReasons.moisture) or 0,
                        wear = (liveReasons and liveReasons.wear) or 0,
                        slope = (liveReasons and liveReasons.slope) or 0
                    }

                    table.insert(result, {
                        fieldId = fid,
                        isOwned = false,
                        isContract = true,
                        nominalAreaHa = (mission.field and resolveFieldAreaHa(mission.field, fid)) or 0,
                        harvestedAreaHa = liveAreaHa,
                        harvestedLiters = liveHarvL,
                        harvestedMassKg = liveHarvMass,
                        lostLiters = liveLostL,
                        lossMoney = liveMoney,
                        sessionDuration = liveDuration,
                        lastCrop = cropName,
                        cropVolumes = {},
                        operationsCount = (liveHarvL > 0 and 1) or 0,
                        lastYear = 1,
                        reasons = fReasons
                    })
                end
            end
        end
    end

    table.sort(result, function(a, b) return (a.fieldId or 0) < (b.fieldId or 0) end)
    return result
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
        local machineKey = combine.configFileName or (combine.getFullName and combine:getFullName()) or "Harvester"
        self:archiveAndResetCombineTrip(farmId, machineKey, combine)
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
        setXMLInt(xmlFile, tripKey .. "#fillTypeIndex", trip.fillTypeIndex or FillType.UNKNOWN)
        setXMLFloat(xmlFile, tripKey .. "#harvested", trip.harvestedLiters or 0)
        setXMLFloat(xmlFile, tripKey .. "#harvestedMass", trip.harvestedMassKg or 0)
        setXMLFloat(xmlFile, tripKey .. "#harvestedArea", trip.harvestedAreaHa or 0)
        setXMLFloat(xmlFile, tripKey .. "#lost", trip.lostLiters or 0)
        setXMLFloat(xmlFile, tripKey .. "#lossMoney", trip.lossMoney or 0)
        setXMLFloat(xmlFile, tripKey .. "#duration", trip.sessionDuration or 0)
        setXMLFloat(xmlFile, tripKey .. "#avgSpeedSum", trip.avgSpeedSum or 0)
        setXMLInt(xmlFile, tripKey .. "#avgSpeedCount", trip.avgSpeedCount or 0)
        setXMLFloat(xmlFile, tripKey .. "#avgLoadSum", trip.avgLoadSum or 0)
        setXMLInt(xmlFile, tripKey .. "#avgLoadCount", trip.avgLoadCount or 0)
        setXMLString(xmlFile, tripKey .. "#efficiencyRank", trip.efficiencyRank or "A")
        setXMLBool(xmlFile, tripKey .. "#isActive", trip.isActive == true)
        setXMLBool(xmlFile, tripKey .. "#isContract", trip.isContract == true)
        if trip.lastMachineKey then
            setXMLString(xmlFile, tripKey .. "#lastMachineKey", trip.lastMachineKey)
        end

        setXMLFloat(xmlFile, tripKey .. ".reasons#speed", trip.reasons.speed or 0)
        setXMLFloat(xmlFile, tripKey .. ".reasons#moisture", trip.reasons.moisture or 0)
        setXMLFloat(xmlFile, tripKey .. ".reasons#wear", trip.reasons.wear or 0)
        setXMLFloat(xmlFile, tripKey .. ".reasons#slope", trip.reasons.slope or 0)

        -- Per-Combine Trip Odometers
        local combineTripsKey = farmKey .. ".combineTrips"
        local cIdx = 0
        if farm.combineTrips then
            for machineKey, mTrip in pairs(farm.combineTrips) do
                local mKey = string.format("%s.combine(%d)", combineTripsKey, cIdx)
                setXMLString(xmlFile, mKey .. "#machineKey", machineKey)
                setXMLInt(xmlFile, mKey .. "#fieldId", mTrip.fieldId or 0)
                setXMLString(xmlFile, mKey .. "#cropName", mTrip.cropName or "--")
                setXMLInt(xmlFile, mKey .. "#fillTypeIndex", mTrip.fillTypeIndex or FillType.UNKNOWN)
                setXMLFloat(xmlFile, mKey .. "#harvested", mTrip.harvestedLiters or 0)
                setXMLFloat(xmlFile, mKey .. "#harvestedMass", mTrip.harvestedMassKg or 0)
                setXMLFloat(xmlFile, mKey .. "#harvestedArea", mTrip.harvestedAreaHa or 0)
                setXMLFloat(xmlFile, mKey .. "#lost", mTrip.lostLiters or 0)
                setXMLFloat(xmlFile, mKey .. "#lossMoney", mTrip.lossMoney or 0)
                setXMLFloat(xmlFile, mKey .. "#duration", mTrip.sessionDuration or 0)
                setXMLFloat(xmlFile, mKey .. "#avgSpeedSum", mTrip.avgSpeedSum or 0)
                setXMLInt(xmlFile, mKey .. "#avgSpeedCount", mTrip.avgSpeedCount or 0)
                setXMLFloat(xmlFile, mKey .. "#avgLoadSum", mTrip.avgLoadSum or 0)
                setXMLInt(xmlFile, mKey .. "#avgLoadCount", mTrip.avgLoadCount or 0)
                setXMLString(xmlFile, mKey .. "#efficiencyRank", mTrip.efficiencyRank or "A")
                setXMLBool(xmlFile, mKey .. "#isActive", mTrip.isActive == true)
                setXMLBool(xmlFile, mKey .. "#isContract", mTrip.isContract == true)

                if mTrip.reasons then
                    setXMLFloat(xmlFile, mKey .. ".reasons#speed", mTrip.reasons.speed or 0)
                    setXMLFloat(xmlFile, mKey .. ".reasons#moisture", mTrip.reasons.moisture or 0)
                    setXMLFloat(xmlFile, mKey .. ".reasons#wear", mTrip.reasons.wear or 0)
                    setXMLFloat(xmlFile, mKey .. ".reasons#slope", mTrip.reasons.slope or 0)
                end
                cIdx = cIdx + 1
            end
        end

        -- Farm Settings
        local setKey = farmKey .. ".farmSettings"
        setXMLBool(xmlFile, setKey .. "#aiSpeedLimiter", farm.farmSettings.aiSpeedLimiter)
        setXMLFloat(xmlFile, setKey .. "#aiMaxLossPct", farm.farmSettings.aiMaxLossPct)
        setXMLBool(xmlFile, setKey .. "#volunteerCrops", farm.farmSettings.volunteerCrops)
        setXMLBool(xmlFile, setKey .. "#autoResetOnFieldChange", farm.farmSettings.autoResetOnFieldChange)

        -- Fleet Stats (exclude contract/mission combines)
        local fleetKey = farmKey .. ".fleetStats"
        local vIdx = 0
        for key, v in pairs(farm.fleetStats) do
            if not RHM_HarvestTracker.isMissionCombine(nil, v.name, key) then
                local vKey = string.format("%s.vehicle(%d)", fleetKey, vIdx)
                setXMLString(xmlFile, vKey .. "#key", key)
                setXMLString(xmlFile, vKey .. "#name", v.name or "Harvester")
                setXMLFloat(xmlFile, vKey .. "#workHours", (v.workSeconds or 0) / 3600.0)
                setXMLFloat(xmlFile, vKey .. "#totalHarvested", v.totalHarvested or 0)
                setXMLFloat(xmlFile, vKey .. "#totalLost", v.totalLost or 0)
                vIdx = vIdx + 1
            end
        end

        -- Yearly Statistics (per-season continuous aggregate)
        local yearKey = farmKey .. ".yearlyStats"
        local yIdx = 0
        if farm.yearlyStats then
            for y, yStat in pairs(farm.yearlyStats) do
                local sKey = string.format("%s.season(%d)", yearKey, yIdx)
                setXMLInt(xmlFile, sKey .. "#year", yStat.year or y or 1)
                setXMLFloat(xmlFile, sKey .. "#harvested", yStat.harvestedLiters or 0)
                setXMLFloat(xmlFile, sKey .. "#harvestedMass", yStat.harvestedMassKg or 0)
                setXMLFloat(xmlFile, sKey .. "#harvestedArea", yStat.harvestedAreaHa or 0)
                setXMLFloat(xmlFile, sKey .. "#lost", yStat.lostLiters or 0)
                setXMLFloat(xmlFile, sKey .. "#lossMoney", yStat.lossMoney or 0)
                setXMLFloat(xmlFile, sKey .. "#duration", yStat.sessionDuration or 0)
                setXMLFloat(xmlFile, sKey .. "#avgSpeedSum", yStat.avgSpeedSum or 0)
                setXMLInt(xmlFile, sKey .. "#avgSpeedCount", yStat.avgSpeedCount or 0)
                setXMLFloat(xmlFile, sKey .. "#avgLoadSum", yStat.avgLoadSum or 0)
                setXMLInt(xmlFile, sKey .. "#avgLoadCount", yStat.avgLoadCount or 0)
                setXMLInt(xmlFile, sKey .. "#fieldOperations", yStat.fieldOperations or 0)

                if yStat.reasons then
                    setXMLFloat(xmlFile, sKey .. ".reasons#speed", yStat.reasons.speed or 0)
                    setXMLFloat(xmlFile, sKey .. ".reasons#moisture", yStat.reasons.moisture or 0)
                    setXMLFloat(xmlFile, sKey .. ".reasons#wear", yStat.reasons.wear or 0)
                    setXMLFloat(xmlFile, sKey .. ".reasons#slope", yStat.reasons.slope or 0)
                end

                if yStat.cropVolumes then
                    local cIdx = 0
                    for cName, cLit in pairs(yStat.cropVolumes) do
                        local cKey = string.format("%s.crops.crop(%d)", sKey, cIdx)
                        setXMLString(xmlFile, cKey .. "#name", cName)
                        setXMLFloat(xmlFile, cKey .. "#liters", cLit)
                        cIdx = cIdx + 1
                    end
                end
                yIdx = yIdx + 1
            end
        end

        -- Field Statistics (per-field cumulative)
        local fieldsKey = farmKey .. ".fieldStats"
        local fIdx = 0
        if farm.fieldStats then
            for fieldId, fStat in pairs(farm.fieldStats) do
                local fKey = string.format("%s.field(%d)", fieldsKey, fIdx)
                setXMLInt(xmlFile, fKey .. "#fieldId", fieldId or fStat.fieldId or 0)
                setXMLFloat(xmlFile, fKey .. "#harvested", fStat.harvestedLiters or 0)
                setXMLFloat(xmlFile, fKey .. "#harvestedMass", fStat.harvestedMassKg or 0)
                setXMLFloat(xmlFile, fKey .. "#harvestedArea", fStat.harvestedAreaHa or 0)
                setXMLFloat(xmlFile, fKey .. "#duration", fStat.sessionDuration or 0)
                setXMLFloat(xmlFile, fKey .. "#lost", fStat.lostLiters or 0)
                setXMLFloat(xmlFile, fKey .. "#lossMoney", fStat.lossMoney or 0)
                setXMLInt(xmlFile, fKey .. "#operationsCount", fStat.operationsCount or 0)
                setXMLBool(xmlFile, fKey .. "#isContract", fStat.isContract == true)
                setXMLString(xmlFile, fKey .. "#lastCropName", fStat.lastCropName or fStat.lastCrop or "--")
                setXMLFloat(xmlFile, fKey .. "#avgSpeedSum", fStat.avgSpeedSum or 0)
                setXMLInt(xmlFile, fKey .. "#avgSpeedCount", fStat.avgSpeedCount or 0)
                setXMLFloat(xmlFile, fKey .. "#avgLoadSum", fStat.avgLoadSum or 0)
                setXMLInt(xmlFile, fKey .. "#avgLoadCount", fStat.avgLoadCount or 0)
                setXMLInt(xmlFile, fKey .. "#lastYear", fStat.lastYear or 1)
                local r = fStat.reasons or {}
                setXMLFloat(xmlFile, fKey .. "#reasonSpeed", r.speed or 0)
                setXMLFloat(xmlFile, fKey .. "#reasonMoisture", r.moisture or 0)
                setXMLFloat(xmlFile, fKey .. "#reasonWear", r.wear or 0)
                setXMLFloat(xmlFile, fKey .. "#reasonSlope", r.slope or 0)
                fIdx = fIdx + 1
            end
        end

        -- Season History (archive)
        local histKey = farmKey .. ".seasonHistory"
        for hIdx, entry in ipairs(farm.seasonHistory) do
            local eKey = string.format("%s.entry(%d)", histKey, hIdx - 1)
            setXMLInt(xmlFile, eKey .. "#year", entry.year or 1)
            setXMLInt(xmlFile, eKey .. "#fieldId", entry.fieldId or 0)
            setXMLBool(xmlFile, eKey .. "#isContract", entry.isContract == true)
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
            farm.currentTrip.fillTypeIndex = getXMLInt(xmlFile, tripKey .. "#fillTypeIndex") or FillType.UNKNOWN
            farm.currentTrip.harvestedLiters = getXMLFloat(xmlFile, tripKey .. "#harvested") or 0
            farm.currentTrip.harvestedMassKg = getXMLFloat(xmlFile, tripKey .. "#harvestedMass") or 0
            farm.currentTrip.harvestedAreaHa = getXMLFloat(xmlFile, tripKey .. "#harvestedArea") or 0
            farm.currentTrip.lostLiters = getXMLFloat(xmlFile, tripKey .. "#lost") or 0
            farm.currentTrip.lossMoney = getXMLFloat(xmlFile, tripKey .. "#lossMoney") or 0
            farm.currentTrip.sessionDuration = getXMLFloat(xmlFile, tripKey .. "#duration") or 0
            farm.currentTrip.avgSpeedSum = getXMLFloat(xmlFile, tripKey .. "#avgSpeedSum") or 0
            farm.currentTrip.avgSpeedCount = getXMLInt(xmlFile, tripKey .. "#avgSpeedCount") or 0
            farm.currentTrip.avgLoadSum = getXMLFloat(xmlFile, tripKey .. "#avgLoadSum") or 0
            farm.currentTrip.avgLoadCount = getXMLInt(xmlFile, tripKey .. "#avgLoadCount") or 0
            farm.currentTrip.efficiencyRank = getXMLString(xmlFile, tripKey .. "#efficiencyRank") or "A"
            local isAct = getXMLBool(xmlFile, tripKey .. "#isActive")
            if isAct ~= nil then farm.currentTrip.isActive = isAct end
            farm.currentTrip.isContract = getXMLBool(xmlFile, tripKey .. "#isContract") or false
            farm.currentTrip.lastMachineKey = getXMLString(xmlFile, tripKey .. "#lastMachineKey")

            farm.currentTrip.reasons.speed = getXMLFloat(xmlFile, tripKey .. ".reasons#speed") or 0
            farm.currentTrip.reasons.moisture = getXMLFloat(xmlFile, tripKey .. ".reasons#moisture") or 0
            farm.currentTrip.reasons.wear = getXMLFloat(xmlFile, tripKey .. ".reasons#wear") or 0
            farm.currentTrip.reasons.slope = getXMLFloat(xmlFile, tripKey .. ".reasons#slope") or 0

            local totalBio = farm.currentTrip.harvestedLiters + farm.currentTrip.lostLiters
            local lossPct = (totalBio > 0) and ((farm.currentTrip.lostLiters / totalBio) * 100.0) or 0
            farm.currentTrip.efficiencyRank = RHM_HarvestTracker.calculateEfficiencyRank(lossPct)
        end

        -- Per-Combine Trip Odometers
        local combineTripsKey = farmKey .. ".combineTrips"
        farm.combineTrips = farm.combineTrips or {}
        local cIdx = 0
        while true do
            local mKey = string.format("%s.combine(%d)", combineTripsKey, cIdx)
            if not hasXMLProperty(xmlFile, mKey) then break end
            local machineKey = getXMLString(xmlFile, mKey .. "#machineKey")
            if machineKey and machineKey ~= "" then
                local mTrip = {
                    fieldId = getXMLInt(xmlFile, mKey .. "#fieldId") or 0,
                    cropName = getXMLString(xmlFile, mKey .. "#cropName") or "--",
                    fillTypeIndex = getXMLInt(xmlFile, mKey .. "#fillTypeIndex") or FillType.UNKNOWN,
                    harvestedLiters = getXMLFloat(xmlFile, mKey .. "#harvested") or 0,
                    harvestedMassKg = getXMLFloat(xmlFile, mKey .. "#harvestedMass") or 0,
                    harvestedAreaHa = getXMLFloat(xmlFile, mKey .. "#harvestedArea") or 0,
                    lostLiters = getXMLFloat(xmlFile, mKey .. "#lost") or 0,
                    lossMoney = getXMLFloat(xmlFile, mKey .. "#lossMoney") or 0,
                    sessionDuration = getXMLFloat(xmlFile, mKey .. "#duration") or 0,
                    avgSpeedSum = getXMLFloat(xmlFile, mKey .. "#avgSpeedSum") or 0,
                    avgSpeedCount = getXMLInt(xmlFile, mKey .. "#avgSpeedCount") or 0,
                    avgLoadSum = getXMLFloat(xmlFile, mKey .. "#avgLoadSum") or 0,
                    avgLoadCount = getXMLInt(xmlFile, mKey .. "#avgLoadCount") or 0,
                    efficiencyRank = getXMLString(xmlFile, mKey .. "#efficiencyRank") or "A",
                    isActive = getXMLBool(xmlFile, mKey .. "#isActive") or false,
                    isContract = getXMLBool(xmlFile, mKey .. "#isContract") or false,
                    reasons = {
                        speed = getXMLFloat(xmlFile, mKey .. ".reasons#speed") or 0,
                        moisture = getXMLFloat(xmlFile, mKey .. ".reasons#moisture") or 0,
                        wear = getXMLFloat(xmlFile, mKey .. ".reasons#wear") or 0,
                        slope = getXMLFloat(xmlFile, mKey .. ".reasons#slope") or 0
                    }
                }
                farm.combineTrips[machineKey] = mTrip
            end
            cIdx = cIdx + 1
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

            -- Skip contract / mission rental vehicles from savegame fleet
            if not RHM_HarvestTracker.isMissionCombine(nil, name, key) then
                farm.fleetStats[key] = {
                    name = name,
                    workSeconds = workHours * 3600.0,
                    totalHarvested = totHarvest,
                    totalLost = totLost
                }
            end
            vIdx = vIdx + 1
        end

        -- Yearly Statistics
        local yearKey = farmKey .. ".yearlyStats"
        local yIdx = 0
        farm.yearlyStats = farm.yearlyStats or {}
        while true do
            local sKey = string.format("%s.season(%d)", yearKey, yIdx)
            if not hasXMLProperty(xmlFile, sKey) then break end
            local y = getXMLInt(xmlFile, sKey .. "#year") or 1
            local stat = {
                year = y,
                harvestedLiters = getXMLFloat(xmlFile, sKey .. "#harvested") or 0,
                harvestedMassKg = getXMLFloat(xmlFile, sKey .. "#harvestedMass") or 0,
                harvestedAreaHa = getXMLFloat(xmlFile, sKey .. "#harvestedArea") or 0,
                lostLiters = getXMLFloat(xmlFile, sKey .. "#lost") or 0,
                lossMoney = getXMLFloat(xmlFile, sKey .. "#lossMoney") or 0,
                sessionDuration = getXMLFloat(xmlFile, sKey .. "#duration") or 0,
                avgSpeedSum = getXMLFloat(xmlFile, sKey .. "#avgSpeedSum") or 0,
                avgSpeedCount = getXMLInt(xmlFile, sKey .. "#avgSpeedCount") or 0,
                avgLoadSum = getXMLFloat(xmlFile, sKey .. "#avgLoadSum") or 0,
                avgLoadCount = getXMLInt(xmlFile, sKey .. "#avgLoadCount") or 0,
                fieldOperations = getXMLInt(xmlFile, sKey .. "#fieldOperations") or 0,
                reasons = {
                    speed = getXMLFloat(xmlFile, sKey .. ".reasons#speed") or 0,
                    moisture = getXMLFloat(xmlFile, sKey .. ".reasons#moisture") or 0,
                    wear = getXMLFloat(xmlFile, sKey .. ".reasons#wear") or 0,
                    slope = getXMLFloat(xmlFile, sKey .. ".reasons#slope") or 0
                },
                cropVolumes = {}
            }

            local cIdx = 0
            while true do
                local cKey = string.format("%s.crops.crop(%d)", sKey, cIdx)
                if not hasXMLProperty(xmlFile, cKey) then break end
                local cName = getXMLString(xmlFile, cKey .. "#name")
                local cLit = getXMLFloat(xmlFile, cKey .. "#liters") or 0
                if cName and cName ~= "" then
                    stat.cropVolumes[cName] = cLit
                end
                cIdx = cIdx + 1
            end

            farm.yearlyStats[y] = stat
            yIdx = yIdx + 1
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
                isContract = getXMLBool(xmlFile, eKey .. "#isContract") or false,
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

        -- Field Stats
        local fieldsKey = farmKey .. ".fieldStats"
        local fIdx = 0
        farm.fieldStats = farm.fieldStats or {}
        while true do
            local fKey = string.format("%s.field(%d)", fieldsKey, fIdx)
            if not hasXMLProperty(xmlFile, fKey) then break end
            local fId = getXMLInt(xmlFile, fKey .. "#fieldId") or 0
            if fId > 0 then
                farm.fieldStats[fId] = {
                    fieldId = fId,
                    harvestedLiters = getXMLFloat(xmlFile, fKey .. "#harvested") or 0,
                    harvestedMassKg = getXMLFloat(xmlFile, fKey .. "#harvestedMass") or 0,
                    harvestedAreaHa = getXMLFloat(xmlFile, fKey .. "#harvestedArea") or 0,
                    sessionDuration = getXMLFloat(xmlFile, fKey .. "#duration") or 0,
                    lostLiters = getXMLFloat(xmlFile, fKey .. "#lost") or 0,
                    lossMoney = getXMLFloat(xmlFile, fKey .. "#lossMoney") or 0,
                    operationsCount = getXMLInt(xmlFile, fKey .. "#operationsCount") or 0,
                    isContract = getXMLBool(xmlFile, fKey .. "#isContract") or false,
                    lastCropName = getXMLString(xmlFile, fKey .. "#lastCropName") or "--",
                    lastCrop = getXMLString(xmlFile, fKey .. "#lastCropName") or "--",
                    avgSpeedSum = getXMLFloat(xmlFile, fKey .. "#avgSpeedSum") or 0,
                    avgSpeedCount = getXMLInt(xmlFile, fKey .. "#avgSpeedCount") or 0,
                    avgLoadSum = getXMLFloat(xmlFile, fKey .. "#avgLoadSum") or 0,
                    avgLoadCount = getXMLInt(xmlFile, fKey .. "#avgLoadCount") or 0,
                    lastYear = getXMLInt(xmlFile, fKey .. "#lastYear") or 1,
                    reasons = {
                        speed = getXMLFloat(xmlFile, fKey .. "#reasonSpeed") or 0,
                        moisture = getXMLFloat(xmlFile, fKey .. "#reasonMoisture") or 0,
                        wear = getXMLFloat(xmlFile, fKey .. "#reasonWear") or 0,
                        slope = getXMLFloat(xmlFile, fKey .. "#reasonSlope") or 0
                    },
                    cropVolumes = {}
                }
            end
            fIdx = fIdx + 1
        end

        -- Bootstrap fieldStats from seasonHistory if fieldStats was empty (backward compatibility)
        if next(farm.fieldStats) == nil and farm.seasonHistory and #farm.seasonHistory > 0 then
            for _, entry in ipairs(farm.seasonHistory) do
                local fId = entry.fieldId or 0
                if fId > 0 then
                    local fStat = farm.fieldStats[fId]
                    if not fStat then
                        fStat = {
                            fieldId = fId,
                            harvestedLiters = 0,
                            harvestedMassKg = 0,
                            harvestedAreaHa = 0,
                            sessionDuration = 0,
                            lostLiters = 0,
                            lossMoney = 0,
                            operationsCount = 0,
                            isContract = (entry.isContract == true),
                            lastCropName = entry.cropName or "--",
                            lastCrop = entry.cropName or "--",
                            avgSpeedSum = 0,
                            avgSpeedCount = 0,
                            avgLoadSum = 0,
                            avgLoadCount = 0,
                            lastYear = entry.year or 1,
                            reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
                            cropVolumes = {}
                        }
                        farm.fieldStats[fId] = fStat
                    end
                    fStat.harvestedLiters = fStat.harvestedLiters + (entry.harvested or 0)
                    fStat.harvestedMassKg = fStat.harvestedMassKg + ((entry.harvested or 0) * 0.75)
                    fStat.harvestedAreaHa = fStat.harvestedAreaHa + (entry.areaHa or 0)
                    fStat.lostLiters = fStat.lostLiters + (entry.lost or 0)
                    fStat.lossMoney = fStat.lossMoney + (entry.lossMoney or 0)
                    fStat.operationsCount = fStat.operationsCount + 1
                    fStat.reasons = fStat.reasons or { speed = 0, moisture = 0, wear = 0, slope = 0 }
                    if entry.dominantReason and (entry.lost or 0) > 0 then
                        local dKey = entry.dominantReason
                        if fStat.reasons[dKey] ~= nil then
                            fStat.reasons[dKey] = fStat.reasons[dKey] + entry.lost
                        else
                            fStat.reasons.speed = fStat.reasons.speed + entry.lost
                        end
                    end
                    if entry.cropName and entry.cropName ~= "UNKNOWN" and entry.cropName ~= "--" then
                        fStat.lastCropName = entry.cropName
                    end
                end
            end
        end

        farmIndex = farmIndex + 1
    end

    -- Re-link existing vehicles on the map to their loaded persistent trip odometers
    if g_currentMission then
        local vehicles = (g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles) or g_currentMission.vehicles
        if vehicles then
            for _, vehicle in pairs(vehicles) do
                if vehicle and type(vehicle) == "table" and vehicle.spec_rhm_Combine then
                    local farmId = (vehicle.getOwnerFarmId and vehicle:getOwnerFarmId()) or 1
                    local farm = self.farms[farmId]
                    if farm and farm.combineTrips then
                        local machineKey = vehicle.configFileName or (vehicle.getFullName and vehicle:getFullName()) or "Harvester"
                        if farm.combineTrips[machineKey] then
                            vehicle.spec_rhm_Combine.trip = farm.combineTrips[machineKey]
                        elseif farm.currentTrip and (farm.currentTrip.harvestedLiters or 0) > 0 and (farm.currentTrip.lastMachineKey == nil or farm.currentTrip.lastMachineKey == machineKey) then
                            farm.combineTrips[machineKey] = {
                                fieldId = farm.currentTrip.fieldId or 0,
                                cropName = farm.currentTrip.cropName or "--",
                                fillTypeIndex = farm.currentTrip.fillTypeIndex or FillType.UNKNOWN,
                                harvestedAreaHa = farm.currentTrip.harvestedAreaHa or 0,
                                harvestedLiters = farm.currentTrip.harvestedLiters or 0,
                                harvestedMassKg = farm.currentTrip.harvestedMassKg or 0,
                                lostLiters = farm.currentTrip.lostLiters or 0,
                                lossMoney = farm.currentTrip.lossMoney or 0,
                                sessionDuration = farm.currentTrip.sessionDuration or 0,
                                avgSpeedSum = farm.currentTrip.avgSpeedSum or 0,
                                avgSpeedCount = farm.currentTrip.avgSpeedCount or 0,
                                avgLoadSum = farm.currentTrip.avgLoadSum or 0,
                                avgLoadCount = farm.currentTrip.avgLoadCount or 0,
                                efficiencyRank = farm.currentTrip.efficiencyRank or RHM_HarvestTracker.RANK_A,
                                reasons = {
                                    speed = farm.currentTrip.reasons and farm.currentTrip.reasons.speed or 0,
                                    moisture = farm.currentTrip.reasons and farm.currentTrip.reasons.moisture or 0,
                                    wear = farm.currentTrip.reasons and farm.currentTrip.reasons.wear or 0,
                                    slope = farm.currentTrip.reasons and farm.currentTrip.reasons.slope or 0
                                },
                                isActive = farm.currentTrip.isActive or false
                            }
                            vehicle.spec_rhm_Combine.trip = farm.combineTrips[machineKey]
                        end
                    end
                end
            end
        end
    end
end
