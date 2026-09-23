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
---@param uniqueId number The unique ID of the object (e.g. vehicle)
---@param fillType number The FS25 fill type enum
---@return number Moisture percentage (0.0 to 100.0)
function RHM_MoistureAdapter.getObjectMoisture(uniqueId, fillType)
    if not RHM_MoistureAdapter.isActive or not uniqueId or not fillType then return 0 end
    
    -- Safe call to external system with diagnostic logging on exception
    local success, result = pcall(function()
        return g_currentMission.MoistureSystem:getObjectMoisture(uniqueId, fillType)
    end)
    
    if success and result then
        return result * 100 -- Convert 0-1 scale to percentage
    elseif not success then
        rhm_log(string.format("RHM [Moisture Adapter Error] getObjectMoisture: %s", tostring(result)))
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
    
    if success and result then
        return result * 100 -- Convert 0-1 scale to percentage
    elseif not success then
        rhm_log(string.format("RHM [Moisture Adapter Error] getMoistureAtPosition: %s", tostring(result)))
    end
    
    return nil
end
