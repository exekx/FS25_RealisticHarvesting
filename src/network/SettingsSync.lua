---@class SettingsSync
-- Helper for synchronizing settings across network
SettingsSync = {}

---Send server settings to all clients
---@param settings Settings Server settings object
---Send server settings to all clients (or to server if we are client)
---@param settings Settings Server settings object
function SettingsSync:sendToClients(settings)
    if not g_currentMission:getIsServer() then
        -- If we are a client (admin), we send to server first
        self:sendToServer(settings)
        return
    end
    
    -- Create and broadcast event
    local event = SettingsSyncEvent.new(settings)
    g_server:broadcastEvent(event)
    
    -- print("RHM: Broadcasting server settings to all clients")
end

---Send settings update to server (from client admin)
---@param settings Settings Server settings object
function SettingsSync:sendToServer(settings)
    if g_currentMission:getIsServer() then
        return
    end
    
    if g_client == nil then
        print("RHM: [Sync] Error - g_client is nil")
        return
    end
    
    local connection = g_client:getServerConnection()
    if connection == nil then
        print("RHM: [Sync] Error - Server connection is nil")
        return
    end
    
    print(string.format("RHM: [Sync] Sending event to server via connection %s", tostring(connection)))
    local event = SettingsSyncEvent.new(settings)
    connection:sendEvent(event)
    
    print(string.format("RHM: [Sync] Event sent (Motor: %d, Loss: %d)", tostring(settings.difficultyMotor or 2), tostring(settings.difficultyLoss or 2)))
end

---Receive server settings from server (called by event)
---@param eventData table Event data
function SettingsSync:receiveFromServer(eventData)
    if g_currentMission:getIsServer() then
        return
    end
    
    -- Settings are updated in SettingsSyncEvent:run()
    -- This is just a helper method if needed
end
