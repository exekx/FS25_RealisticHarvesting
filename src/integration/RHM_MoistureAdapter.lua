-- EN: Soft Dependency Bridge for the external 'Moisture System' mod.
--     Safely safely fetches moisture data if the mod is present, returns 0 if missing.
-- UA: Безпечний місток (Адаптер) для зовнішнього моду 'Moisture System'.
--     Безпечно отримує дані про вологість, якщо мод встановлено, інакше повертає 0.

RHM_MoistureAdapter = {}
RHM_MoistureAdapter.isActive = false

---Checks if the MoistureSystem mod is loaded and active in the current mission.
function RHM_MoistureAdapter.initialize()
    if g_currentMission ~= nil and g_currentMission.MoistureSystem ~= nil then
        RHM_MoistureAdapter.isActive = true
        rhm_log("[OK] RHM_MoistureAdapter: External 'Moisture System' mod detected.")
    else
        RHM_MoistureAdapter.isActive = false
        rhm_log("[OK] RHM_MoistureAdapter: External 'Moisture System' mod not found. Moisture features disabled.")
    end
end

---Fetches the moisture level for a specific fill type in a specific vehicle.
---@param uniqueId number The unique ID of the object (e.g. vehicle)
---@param fillType number The FS25 fill type enum
---@return number Moisture percentage (0.0 to 100.0)
function RHM_MoistureAdapter.getObjectMoisture(uniqueId, fillType)
    if not RHM_MoistureAdapter.isActive or not uniqueId or not fillType then return 0 end
    
    -- Safe call
    local success, moisture = pcall(function()
        return g_currentMission.MoistureSystem:getObjectMoisture(uniqueId, fillType)
    end)
    
    if success and moisture then
        return moisture * 100 -- Convert 0-1 scale to percentage
    end
    
    return 0
end

---Fetches the moisture level at a specific world coordinate.
---@param x number X coordinate
---@param z number Z coordinate
---@return number Moisture percentage (0.0 to 100.0)
function RHM_MoistureAdapter.getMoistureAtPosition(x, z)
    if not RHM_MoistureAdapter.isActive or not x or not z then return 0 end
    
    local success, moisture = pcall(function()
        return g_currentMission.MoistureSystem:getMoistureAtPosition(x, z)
    end)
    
    if success and moisture then
        return moisture * 100 -- Convert 0-1 scale to percentage
    end
    
    return 0
end
