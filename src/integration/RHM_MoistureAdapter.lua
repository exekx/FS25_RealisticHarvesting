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
            pcall(function() ms:ensureObjectMoistureLoaded(vehicle) end)
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
