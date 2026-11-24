-- EN: Soft Dependency Bridge for environmental crop moisture data.
--     Safely fetches moisture data if a provider is present, returns crop-aware ambient fallback if missing.
-- UA: Безпечний місток (адаптер) для даних вологості врожаю.
--     Безпечно отримує дані про вологість за наявності провайдера, інакше рахує адаптивну вологість за культурою.

RHM_MoistureAdapter = {}
RHM_MoistureAdapter.isActive = false

---Resolves active external environmental moisture provider lazily.
---@return table|nil provider
function RHM_MoistureAdapter.getProvider()
    local ms = g_currentMission and g_currentMission.MoistureSystem
    RHM_MoistureAdapter.isActive = (ms ~= nil)
    return ms
end

---Resolves crop value / moisture range table from active provider environment without hardcoding mod names.
---@param ms table
---@return table|nil cropValueMap
function RHM_MoistureAdapter.getProviderCropValueMap(ms)
    if ms == nil then
        return nil
    end
    local env = (type(ms.getMoistureAtPosition) == "function") and getfenv(ms.getMoistureAtPosition) or nil
    return (env and env.CropValueMap) or CropValueMap
end

---Resolves numeric fillType index from fillType index, fillType name, or crop database alias.
---@param cropOrFillType number|string|nil
---@return number|nil fillTypeIdx
local function resolveFillTypeIndex(cropOrFillType)
    if type(cropOrFillType) == "number" and cropOrFillType > 0 and cropOrFillType ~= FillType.UNKNOWN then
        return cropOrFillType
    elseif type(cropOrFillType) == "string" and cropOrFillType ~= "" and cropOrFillType ~= "--" and cropOrFillType ~= "UNKNOWN"
        and g_fillTypeManager and g_fillTypeManager.getFillTypeIndexByName then
        local upper = cropOrFillType:upper()
        local idx = g_fillTypeManager:getFillTypeIndexByName(upper)
        if not idx and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName then
            local canonical = RHM_CombineSettingsDatabase:getCanonicalCropName(upper)
            if canonical and canonical ~= upper then
                idx = g_fillTypeManager:getFillTypeIndexByName(canonical)
            end
        end
        return idx
    end
    return nil
end

---Resolves upper acceptable harvest moisture limit (%) for a crop from active provider or RHM database.
---@param cropName string|nil
---@param fillTypeIndex number|nil
---@return number limitPct
function RHM_MoistureAdapter.getCropMoistureLimit(cropName, fillTypeIndex)
    local fillTypeIdx = resolveFillTypeIndex(fillTypeIndex) or resolveFillTypeIndex(cropName)

    local ms = RHM_MoistureAdapter.getProvider()
    if ms ~= nil and fillTypeIdx ~= nil then
        local cvm = RHM_MoistureAdapter.getProviderCropValueMap(ms)
        if cvm ~= nil and type(cvm.getIdealRange) == "function" then
            local _, idealMax = cvm.getIdealRange(fillTypeIdx)
            if idealMax == nil and type(ms.getBaseCropFillType) == "function" then
                local baseFt = ms:getBaseCropFillType(fillTypeIdx)
                if baseFt ~= nil then
                    _, idealMax = cvm.getIdealRange(baseFt)
                end
            end
            if type(idealMax) == "number" and idealMax > 0 then
                return (idealMax <= 1.0) and (idealMax * 100.0) or idealMax
            end
        end
    end

    local resolvedCrop = cropName
    if (not resolvedCrop or resolvedCrop == "" or resolvedCrop == "--" or resolvedCrop == "UNKNOWN")
        and fillTypeIdx ~= nil and g_fillTypeManager and g_fillTypeManager.getFillTypeNameByIndex then
        resolvedCrop = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIdx)
    end

    if type(resolvedCrop) == "string" and resolvedCrop ~= "" and resolvedCrop ~= "--" and resolvedCrop ~= "UNKNOWN"
        and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getSettingsForCrop then
        local settings = RHM_CombineSettingsDatabase:getSettingsForCrop(resolvedCrop, nil)
        if settings and settings.moistureLimit then
            return settings.moistureLimit
        end
    end

    return 14.0
end

---Checks if an environmental moisture provider is loaded and active in the current mission.
function RHM_MoistureAdapter.initialize()
    local ms = RHM_MoistureAdapter.getProvider()
    if ms ~= nil then
        rhm_log("[OK] RHM_MoistureAdapter: Environmental moisture provider detected.")
    else
        rhm_log("[OK] RHM_MoistureAdapter: Environmental moisture provider not found. Ambient simulation active.")
    end
end

---Fetches the moisture level for a specific fill type in a specific vehicle.
---@param vehicle table|number The vehicle instance or unique ID
---@param fillType number|string The FS25 fill type enum or name
---@return number|nil Moisture percentage (0.0 to 100.0) or nil if unavailable
function RHM_MoistureAdapter.getObjectMoisture(vehicle, fillType)
    local ms = RHM_MoistureAdapter.getProvider()
    if ms == nil or not vehicle then return nil end

    local uniqueId = nil
    if type(vehicle) == "table" then
        uniqueId = vehicle.uniqueId
    elseif type(vehicle) == "string" or type(vehicle) == "number" then
        uniqueId = vehicle
    end

    if uniqueId and ms.objectInfo then
        if ms.ensureObjectMoistureLoaded and type(vehicle) == "table" then
            ms:ensureObjectMoistureLoaded(vehicle)
        end

        local objectData = ms.objectInfo[uniqueId]
        if objectData then
            local fillTypeName = nil
            if type(fillType) == "number" and g_fillTypeManager then
                fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
            elseif type(fillType) == "string" then
                fillTypeName = fillType
            end

            if fillTypeName and objectData[fillTypeName] and objectData[fillTypeName].moisture then
                return objectData[fillTypeName].moisture * 100.0
            end

            -- Case-insensitive search across object entries
            if fillTypeName then
                local upper = fillTypeName:upper()
                for name, data in pairs(objectData) do
                    if name:upper() == upper and data and data.moisture then
                        return data.moisture * 100.0
                    end
                end
            end

            -- Fallback to first valid recorded moisture property for this vehicle
            for _, data in pairs(objectData) do
                if data and data.moisture and type(data.moisture) == "number" then
                    return data.moisture * 100.0
                end
            end
        end
    end

    -- Generic external interface probe fallback
    if ms.getObjectMoisture then
        local result = ms:getObjectMoisture(uniqueId, fillType)
        if result and type(result) == "number" then
            return (result <= 1.0) and (result * 100.0) or result
        end
    end

    return nil
end

---Fetches the moisture level at a specific world coordinate.
---@param x number X coordinate
---@param z number Z coordinate
---@return number|nil Moisture percentage (0.0 to 100.0) or nil if unavailable
function RHM_MoistureAdapter.getMoistureAtPosition(x, z)
    local ms = RHM_MoistureAdapter.getProvider()
    if ms == nil or not ms.getMoistureAtPosition or not x or not z then return nil end

    local result = ms:getMoistureAtPosition(x, z)

    if result and type(result) == "number" then
        return (result <= 1.0) and (result * 100.0) or result
    end

    return nil
end

---EN: Retrieves current environment daytime in hours (0.0 to 24.0) and precipitation status.
---UA: Отримує поточний час доби в годинах (0.0 - 24.0) та статус опадів (чи йде дощ).
---@return number dayTimeHours Current hour in mission time (default 12.0)
---@return boolean isRaining True if precipitation is currently active
function RHM_MoistureAdapter.getEnvironmentContext()
    local dayTimeHours = 12.0
    local isRaining = false
    if g_currentMission and g_currentMission.environment then
        if g_currentMission.environment.dayTime then
            dayTimeHours = g_currentMission.environment.dayTime / 3600000
        elseif g_currentMission.environment.currentHour then
            dayTimeHours = g_currentMission.environment.currentHour + (g_currentMission.environment.currentMinute or 0) / 60
        end
        if g_currentMission.environment.weather then
            isRaining = g_currentMission.environment.weather:getIsRaining()
        end
    end
    return dayTimeHours, isRaining
end

---EN: Calculates ambient diurnal standing crop moisture anchored to the crop's equilibrium moisture limit.
---    Peak dew at 03:00 (+dewSwing), dry sun at 15:00 (-drySwing), min (limit + 8)% during rain.
---UA: Розраховує добову фонову вологість культури відносно її рівноважного порогу вологості.
---@param dayTimeHours number|nil Time of day in hours (0.0 - 24.0). If nil, auto-queried.
---@param isRaining boolean|nil Rain status. If nil, auto-queried.
---@param cropMoistureLimit number|nil Crop acceptable moisture limit (%)
---@return number moisturePct Ambient moisture percentage
function RHM_MoistureAdapter.calculateAmbientMoisture(dayTimeHours, isRaining, cropMoistureLimit)
    if dayTimeHours == nil or isRaining == nil then
        local envHours, envRain = RHM_MoistureAdapter.getEnvironmentContext()
        dayTimeHours = dayTimeHours or envHours
        if isRaining == nil then
            isRaining = envRain
        end
    end

    local limit = (type(cropMoistureLimit) == "number" and cropMoistureLimit > 0) and cropMoistureLimit or 14.0
    local diurnalFactor = math.cos((dayTimeHours - 3.0) * 0.2617993877991494)
    local baseMoisture = math.max(5.5, limit - 1.5)
    local dewSwing = (limit < 12.0) and 4.0 or 5.5
    local drySwing = (limit < 12.0) and 1.0 or 1.5
    if diurnalFactor > 0 then
        baseMoisture = baseMoisture + (diurnalFactor * dewSwing)
    else
        baseMoisture = baseMoisture + (diurnalFactor * drySwing)
    end

    if isRaining then
        baseMoisture = math.max(baseMoisture, math.min(30.0, limit + 8.0))
    end

    return baseMoisture
end

---EN: Resolves live sampling coordinates (world X, Z) at the active cutting bar center (with vehicle fallback).
---UA: Визначає поточні світові координати (X, Z) центру активної жатки (або самої машини).
---@param vehicle table|nil
---@return number|nil x
---@return number|nil z
---@return table|nil activeCutter
function RHM_MoistureAdapter.resolveSamplingPosition(vehicle)
    if not vehicle then
        return nil, nil, nil
    end

    local activeCutter = nil
    if rhm_Combine and rhm_Combine.getAllAttachedCutters then
        local spec = vehicle.spec_rhm_Combine
        local cutters = rhm_Combine.getAllAttachedCutters(vehicle, spec and spec._attachedCuttersBuffer)
        local fallbackCutter = nil
        for cutter, _ in pairs(cutters) do
            if cutter then
                if not fallbackCutter then
                    fallbackCutter = cutter
                end
                if cutter.getIsTurnedOn and cutter:getIsTurnedOn() then
                    activeCutter = cutter
                    break
                end
            end
        end
        if not activeCutter then
            activeCutter = fallbackCutter
        end
    end

    if activeCutter ~= nil then
        if activeCutter.spec_workArea and activeCutter.spec_workArea.workAreas then
            for _, wa in pairs(activeCutter.spec_workArea.workAreas) do
                if wa.start and wa.width and (not entityExists or (entityExists(wa.start) and entityExists(wa.width))) then
                    local sx, _, sz = getWorldTranslation(wa.start)
                    local wx, _, wz = getWorldTranslation(wa.width)
                    if wa.height and (not entityExists or entityExists(wa.height)) then
                        local hx, _, hz = getWorldTranslation(wa.height)
                        return (sx + wx + hx) / 3.0, (sz + wz + hz) / 3.0, activeCutter
                    end
                    return (sx + wx) * 0.5, (sz + wz) * 0.5, activeCutter
                end
            end
        end

        local cutterNode = (activeCutter.rootNode and (not entityExists or entityExists(activeCutter.rootNode)) and activeCutter.rootNode)
            or (activeCutter.components and activeCutter.components[1] and activeCutter.components[1].node)
        if cutterNode and (not entityExists or entityExists(cutterNode)) then
            local cx, _, cz = getWorldTranslation(cutterNode)
            return cx, cz, activeCutter
        end
    end

    local vehNode = (vehicle.components and vehicle.components[1] and vehicle.components[1].node) or vehicle.rootNode
    if vehNode and (not entityExists or entityExists(vehNode)) then
        local vx, _, vz = getWorldTranslation(vehNode)
        return vx, vz, activeCutter
    end

    return nil, nil, activeCutter
end

---EN: Resolves live field moisture (%) directly at the active cutter position from environmental moisture provider
---    or swath ground pile properties when using windrow/pickup headers.
---UA: Отримує живу вологість (%) безпосередньо у точці жатки від провайдера вологості або властивостей валка.
---@param vehicle table|nil
---@param fillType number|string|nil
---@return number|nil moisturePct
function RHM_MoistureAdapter.getLiveFieldMoisture(vehicle, fillType)
    local ms = RHM_MoistureAdapter.getProvider()
    if ms == nil or vehicle == nil then
        return nil
    end

    local cx, cz, activeCutter = RHM_MoistureAdapter.resolveSamplingPosition(vehicle)
    if cx == nil or cz == nil then
        return nil
    end

    if activeCutter ~= nil and ((activeCutter.spec_cutter and activeCutter.spec_cutter.useWindrow) or activeCutter.spec_pickup ~= nil) then
        local tracker = g_currentMission and g_currentMission.groundPropertyTracker
        if tracker ~= nil and type(tracker.getPilePropertiesAtPosition) == "function" then
            local fillTypeIdx = resolveFillTypeIndex(fillType)
            if not fillTypeIdx and activeCutter.spec_cutter and activeCutter.spec_cutter.currentInputFillType then
                fillTypeIdx = activeCutter.spec_cutter.currentInputFillType
            end
            if fillTypeIdx and fillTypeIdx ~= FillType.UNKNOWN then
                local props = tracker:getPilePropertiesAtPosition(cx, cz, fillTypeIdx)
                if props ~= nil and type(props.moisture) == "number" and props.moisture > 0 then
                    return (props.moisture <= 1.0) and (props.moisture * 100.0) or props.moisture
                end
            end
        end
    end

    local rawFieldMoisture = RHM_MoistureAdapter.getMoistureAtPosition(cx, cz)
    if rawFieldMoisture ~= nil and rawFieldMoisture > 0.1 then
        return rawFieldMoisture
    end

    return nil
end

---EN: Resolves standing crop moisture for a combine vehicle (active provider -> field position / object -> crop-aware diurnal fallback).
---UA: Визначає вологість незібраної культури для комбайна (провайдер -> позиція жатки / бункер -> адаптивна добова симуляція).
---@param vehicle table|nil Target combine vehicle
---@param fillType number|string|nil Target crop fill type or crop name
---@param preferFieldPosition boolean|nil When true, prioritizes live field moisture at header over tank average
---@return number moisturePct Calculated or measured moisture percentage
function RHM_MoistureAdapter.getStandingCropMoisture(vehicle, fillType, preferFieldPosition)
    local dayTimeHours, isRaining = RHM_MoistureAdapter.getEnvironmentContext()
    local ms = RHM_MoistureAdapter.getProvider()

    if preferFieldPosition == nil and vehicle ~= nil and rhm_Combine ~= nil and rhm_Combine.getIsCutterWorking ~= nil then
        preferFieldPosition = (rhm_Combine.getIsCutterWorking(vehicle) == true)
    end

    if ms ~= nil and vehicle ~= nil then
        if preferFieldPosition then
            -- 1. Active harvesting: live crop moisture directly under the cutting bar
            local rawFieldMoisture = RHM_MoistureAdapter.getLiveFieldMoisture(vehicle, fillType)
            if rawFieldMoisture and rawFieldMoisture > 0.1 then
                return rawFieldMoisture
            end

            -- 2. Fallback to vehicle/fillType registered moisture
            if fillType and fillType ~= FillType.UNKNOWN then
                local objM = RHM_MoistureAdapter.getObjectMoisture(vehicle, fillType)
                if objM and objM > 0 then
                    return objM
                end
            end
        else
            -- 1. Idle/transport: hopper/object moisture first, then live position moisture
            if fillType and fillType ~= FillType.UNKNOWN then
                local objM = RHM_MoistureAdapter.getObjectMoisture(vehicle, fillType)
                if objM and objM > 0 then
                    return objM
                end
            end

            local rawFieldMoisture = RHM_MoistureAdapter.getLiveFieldMoisture(vehicle, fillType)
            if rawFieldMoisture and rawFieldMoisture > 0.1 then
                return rawFieldMoisture
            end
        end
    end

    -- 3. Canonical crop-aware environmental diurnal simulation fallback
    local cropName = (type(fillType) == "string") and fillType or nil
    local fillTypeIdx = (type(fillType) == "number" and fillType ~= FillType.UNKNOWN and fillType > 0) and fillType or nil
    if vehicle and vehicle.spec_rhm_Combine then
        local rhmSpec = vehicle.spec_rhm_Combine
        if not fillTypeIdx and rhmSpec.lastFillType and rhmSpec.lastFillType ~= FillType.UNKNOWN and rhmSpec.lastFillType > 0 then
            fillTypeIdx = rhmSpec.lastFillType
        end
        if (not cropName or cropName == "" or cropName == "--") and rhmSpec.combineMemory then
            cropName = rhmSpec.combineMemory.currentCrop
        end
    end

    local cropLimit = RHM_MoistureAdapter.getCropMoistureLimit(cropName, fillTypeIdx)
    return RHM_MoistureAdapter.calculateAmbientMoisture(dayTimeHours, isRaining, cropLimit)
end
