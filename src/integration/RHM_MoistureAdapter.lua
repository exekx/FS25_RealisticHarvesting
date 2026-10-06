-- EN: Soft Dependency Bridge for environmental crop moisture data.
--     Safely fetches moisture data if a provider is present, returns 0 if missing.
-- UA: Безпечний місток (адаптер) для даних вологості врожаю.
--     Безпечно отримує дані про вологість, якщо постачальник доступний, інакше повертає 0.

RHM_MoistureAdapter = {}
RHM_MoistureAdapter.isActive = false

---Checks if an environmental moisture provider is loaded and active in the current mission.
function RHM_MoistureAdapter.initialize()
    if g_currentMission ~= nil and g_currentMission.MoistureSystem ~= nil then
        RHM_MoistureAdapter.isActive = true
        rhm_log("[OK] RHM_MoistureAdapter: Environmental moisture provider detected.")
    else
        RHM_MoistureAdapter.isActive = false
        rhm_log("[OK] RHM_MoistureAdapter: Environmental moisture provider not found. Moisture features disabled.")
    end
end

---Fetches the moisture level for a specific fill type in a specific vehicle.
---@param vehicle table|number The vehicle instance or unique ID
---@param fillType number|string The FS25 fill type enum or name
---@return number|nil Moisture percentage (0.0 to 100.0) or nil if unavailable
function RHM_MoistureAdapter.getObjectMoisture(vehicle, fillType)
    if not RHM_MoistureAdapter.isActive or not vehicle then return nil end
    
    local ms = g_currentMission and g_currentMission.MoistureSystem
    if not ms then return nil end
    
    local uniqueId = nil
    if type(vehicle) == "table" then
        uniqueId = vehicle.uniqueId
    elseif type(vehicle) == "string" or type(vehicle) == "number" then
        uniqueId = vehicle
    end
    
    if uniqueId and ms.objectInfo then
        if ms.ensureObjectMoistureLoaded and type(vehicle) == "table" then
            local ok, err = pcall(function() ms:ensureObjectMoistureLoaded(vehicle) end)
            if not ok then
                rhm_log(string.format("RHM [Moisture Adapter Error] ensureObjectMoistureLoaded: %s", tostring(err)))
            end
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
        local success, result = pcall(function()
            return ms:getObjectMoisture(uniqueId, fillType)
        end)
        if success and result and type(result) == "number" then
            return (result <= 1.0) and (result * 100.0) or result
        elseif not success then
            rhm_log(string.format("RHM [Moisture Adapter Error] getObjectMoisture: %s", tostring(result)))
        end
    end
    
    return nil
end

---Fetches the moisture level at a specific world coordinate.
---@param x number X coordinate
---@param z number Z coordinate
---@return number|nil Moisture percentage (0.0 to 100.0) or nil if unavailable
function RHM_MoistureAdapter.getMoistureAtPosition(x, z)
    if not RHM_MoistureAdapter.isActive or not x or not z then return nil end
    
    local success, result = pcall(function()
        return g_currentMission.MoistureSystem:getMoistureAtPosition(x, z)
    end)
    
    if success and result and type(result) == "number" then
        return result * 100 -- Convert 0-1 scale to percentage
    elseif not success then
        rhm_log(string.format("RHM [Moisture Adapter Error] getMoistureAtPosition: %s", tostring(result)))
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

---EN: Calculates ambient diurnal standing crop moisture based on daylight hours and rain.
---    Uses harmonic diurnal curve: peak dew at 03:00 (+5.5%), dry sun at 15:00 (-1.5%), min 22% during rain.
---UA: Розраховує добову фонову вологість незібраного врожаю на основі часу доби та опадів.
---@param dayTimeHours number|nil Time of day in hours (0.0 - 24.0). If nil, auto-queried.
---@param isRaining boolean|nil Rain status. If nil, auto-queried.
---@return number moisturePct Ambient moisture percentage (approx 11.0% to 22.0+%)
function RHM_MoistureAdapter.calculateAmbientMoisture(dayTimeHours, isRaining)
    if dayTimeHours == nil or isRaining == nil then
        local envHours, envRain = RHM_MoistureAdapter.getEnvironmentContext()
        dayTimeHours = dayTimeHours or envHours
        if isRaining == nil then
            isRaining = envRain
        end
    end

    local diurnalFactor = math.cos((dayTimeHours - 3.0) * 0.2617993877991494)
    local baseMoisture = 12.5
    if diurnalFactor > 0 then
        baseMoisture = baseMoisture + (diurnalFactor * 5.5) -- Up to 18.0% at peak morning dew
    else
        baseMoisture = baseMoisture + (diurnalFactor * 1.5) -- Down to 11.0% in dry afternoon sun
    end

    if isRaining then
        baseMoisture = math.max(baseMoisture, 22.0)
    end

    return baseMoisture
end

---EN: Resolves standing crop moisture for a combine vehicle (active provider -> ground position -> diurnal fallback).
---UA: Визначає вологість незібраної культури для комбайна (провайдер -> позиція на полі -> добова симуляція).
---@param vehicle table|nil Target combine vehicle
---@param fillType number|string|nil Target crop fill type
---@return number moisturePct Calculated or measured moisture percentage
function RHM_MoistureAdapter.getStandingCropMoisture(vehicle, fillType)
    local dayTimeHours, isRaining = RHM_MoistureAdapter.getEnvironmentContext()

    if RHM_MoistureAdapter.isActive and vehicle then
        -- 1. Try vehicle/fillType registered moisture from external provider
        if fillType and fillType ~= FillType.UNKNOWN then
            local objM = RHM_MoistureAdapter.getObjectMoisture(vehicle, fillType)
            if objM and objM > 0 then
                return objM
            end
        end

        -- 2. Try world coordinate ground moisture at vehicle position
        if vehicle.components and vehicle.components[1] then
            local mx, _, mz = getWorldTranslation(vehicle.components[1].node)
            local rawSoilMoisture = RHM_MoistureAdapter.getMoistureAtPosition(mx, mz)
            if rawSoilMoisture and rawSoilMoisture > 0 then
                if isRaining then
                    return math.max(rawSoilMoisture, 22.0)
                else
                    local diurnalFactor = math.cos((dayTimeHours - 3.0) * 0.2617993877991494)
                    if diurnalFactor <= 0 then
                        local dryScale = 0.45 + (1.0 + diurnalFactor) * 0.20
                        return math.max(8.0, math.min(13.5, rawSoilMoisture * dryScale))
                    else
                        return math.max(12.0, math.min(25.0, rawSoilMoisture * (0.65 + diurnalFactor * 0.35)))
                    end
                end
            end
        end
    end

    -- 3. Canonical environmental diurnal simulation fallback
    return RHM_MoistureAdapter.calculateAmbientMoisture(dayTimeHours, isRaining)
end

