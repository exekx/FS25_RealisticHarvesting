-- EN: Helper class for dispatching settings synchronization events over the network.
--     Provides methods to broadcast settings from server to all clients,
--     or to send an update from a client admin to the server.
-- UA: Допоміжний клас для відправлення подій синхронізації налаштувань по мережі.
--     Надає методи для трансляції налаштувань від сервера до всіх клієнтів,
--     або для надсилання оновлення від клієнта-адміністратора на сервер.
SettingsSync = {}

-- EN: Broadcasts server settings to all clients. If called from a client admin, sends to server first.
-- UA: Транслює серверні налаштування всім клієнтам. Якщо викликано від клієнта-адміна, спочатку надсилає на сервер.
function SettingsSync:sendToClients(settings)
    if not g_currentMission:getIsServer() then
        -- EN: We are a client (admin) — send the update to the server first.
        -- UA: Ми клієнт (адміністратор) — спочатку надсилаємо оновлення на сервер.
        self:sendToServer(settings)
        return
    end

    -- EN: We are the server — broadcast the event to all connected clients.
    -- UA: Ми сервер — транслюємо подію всім підключеним клієнтам.
    local event = SettingsSyncEvent.new(settings)
    g_server:broadcastEvent(event)
end

-- EN: Sends a settings update from a client admin to the server.
--     Only works if the caller is a client (not the server itself).
-- UA: Надсилає оновлення налаштувань від клієнта-адміністратора на сервер.
--     Працює тільки якщо викликано на клієнті (не на самому сервері).
function SettingsSync:sendToServer(settings)
    if g_currentMission:getIsServer() then
        return
    end

    if g_client == nil then
        RHM_Debug.log("Network", "RHM: [Sync] Error - g_client is nil")
        return
    end

    local connection = g_client:getServerConnection()
    if connection == nil then
        RHM_Debug.log("Network", "RHM: [Sync] Error - Server connection is nil")
        return
    end

    if RHM_Debug and RHM_Debug.isEnabled("Network") then
        RHM_Debug.log("Network", string.format("RHM: [Sync] Sending event to server via connection %s", tostring(connection)))
    end
    
    local event = SettingsSyncEvent.new(settings)
    connection:sendEvent(event)

    if RHM_Debug and RHM_Debug.isEnabled("Network") then
        RHM_Debug.log("Network", string.format("RHM: [Sync] Event sent (Motor: %d, Loss: %d)", tostring(settings.difficultyMotor or 2), tostring(settings.difficultyLoss or 2)))
    end
end

-- EN: Placeholder method called when the client receives settings from the server.
--     Actual application of values happens in SettingsSyncEvent:run().
-- UA: Метод-заглушка, що викликається коли клієнт отримує налаштування від сервера.
--     Фактичне застосування значень відбувається в SettingsSyncEvent:run().
function SettingsSync:receiveFromServer(eventData)
    if g_currentMission:getIsServer() then
        return
    end
end
