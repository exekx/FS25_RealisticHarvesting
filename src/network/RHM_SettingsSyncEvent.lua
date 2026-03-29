-- EN: Network event used to synchronize server-side settings (difficulty, toggles) between server and all clients.
--     Sent by an admin client to the server, then the server rebroadcasts to all other clients.
-- UA: Мережева подія для синхронізації серверних налаштувань (складність, перемикачі) між сервером і клієнтами.
--     Надсилається клієнтом-адміністратором на сервер, після чого сервер ретранслює всім іншим клієнтам.
RHM_SettingsSyncEvent = {}
local SettingsSyncEvent_mt = Class(RHM_SettingsSyncEvent, Event)

InitEventClass(RHM_SettingsSyncEvent, "RHM_SettingsSyncEvent")

-- EN: Creates an empty event instance used during network deserialization.
-- UA: Створює порожній екземпляр події, який використовується при мережевій десеріалізації.
function RHM_SettingsSyncEvent.emptyNew()
    local self = Event.new(SettingsSyncEvent_mt)
    return self
end

-- EN: Creates a new event with current server settings to be sent over the network.
-- UA: Створює нову подію з поточними серверними налаштуваннями для передачі по мережі.
function RHM_SettingsSyncEvent.new(settings)
    local self = RHM_SettingsSyncEvent.emptyNew()

    -- EN: Copy the server-side settings that need to be synced (split difficulty fields used).
    -- UA: Копіюємо серверні налаштування, які потрібно синхронізувати (використовуються роздільні поля складності).
    self.difficultyMotor = settings.difficultyMotor or 2
    self.difficultyLoss = settings.difficultyLoss or 2
    self.enableSpeedLimit = settings.enableSpeedLimit
    self.enableCropLoss = settings.enableCropLoss
    self.enableIndependentLaunch = settings.enableIndependentLaunch

    return self
end

-- EN: Serializes event data into the network stream (server → client direction).
-- UA: Серіалізує дані події в мережевий потік (напрямок сервер → клієнт).
function RHM_SettingsSyncEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.difficultyMotor)
    streamWriteUInt8(streamId, self.difficultyLoss)
    streamWriteBool(streamId, self.enableSpeedLimit)
    streamWriteBool(streamId, self.enableCropLoss)
    streamWriteBool(streamId, self.enableIndependentLaunch)
end

-- EN: Deserializes event data from the network stream and immediately executes the event logic.
-- UA: Десеріалізує дані події з мережевого потоку і негайно виконує логіку події.
function RHM_SettingsSyncEvent:readStream(streamId, connection)
    self.difficultyMotor = streamReadUInt8(streamId)
    self.difficultyLoss = streamReadUInt8(streamId)
    self.enableSpeedLimit = streamReadBool(streamId)
    self.enableCropLoss = streamReadBool(streamId)
    self.enableIndependentLaunch = streamReadBool(streamId)

    self:run(connection)
end

-- EN: Executes the event logic depending on who received it (server or client).
--     Case 1: Server receives from admin client → applies, saves and rebroadcasts to all.
--     Case 2: Client receives from server → applies locally (read-only update).
-- UA: Виконує логіку події залежно від того, хто її отримав (сервер або клієнт).
--     Випадок 1: Сервер отримує від клієнта-адміна → застосовує, зберігає і ретранслює всім.
--     Випадок 2: Клієнт отримує від сервера → застосовує локально (тільки читання).
function RHM_SettingsSyncEvent:run(connection)
    -- EN: Case 1 — Server receives update from a client admin.
    -- UA: Випадок 1 — Сервер отримує оновлення від клієнта-адміністратора.
    if g_currentMission:getIsServer() then
        if connection:getIsServer() then
            return
        end

        local settings = g_realisticHarvestManager.settings
        if settings then
            rhm_log(string.format("RHM [Network]: RHM: [Sync] Server APPLYING settings - Motor: %d, Loss: %d, Speed: %s, CropLoss: %s, IndLaunch: %s",
                    self.difficultyMotor, self.difficultyLoss, tostring(self.enableSpeedLimit), tostring(self.enableCropLoss), tostring(self.enableIndependentLaunch)))

            -- EN: Apply the received split difficulty fields and feature flags.
            -- UA: Застосовуємо отримані розділені поля складності та прапорці функцій.
            settings.difficultyMotor = self.difficultyMotor
            settings.difficultyLoss = self.difficultyLoss
            settings.enableSpeedLimit = self.enableSpeedLimit
            settings.enableCropLoss = self.enableCropLoss
            settings.enableIndependentLaunch = self.enableIndependentLaunch

            -- EN: Persist updated settings to disk on the server WITHOUT broadcasting (direct manager call).
            -- UA: Зберігаємо оновлені налаштування на диск (прямий виклик менеджера без трансляції).
            if g_realisticHarvestManager.settingsManager then
                g_realisticHarvestManager.settingsManager:saveServerSettings(settings)
            end

            -- EN: Rebroadcast changes to all other connected clients.
            -- UA: Ретранслюємо зміни всім іншим підключеним клієнтам.
            g_server:broadcastEvent(self, nil, connection, nil)
        else
            rhm_log("RHM [Network]: RHM: [Sync] ERROR - g_realisticHarvestManager.settings is nil!")
        end
        return
    end

    -- EN: Case 2 — Client receives updated settings from the server.
    -- UA: Випадок 2 — Клієнт отримує оновлені налаштування від сервера.
    if g_realisticHarvestManager then
        local settings = g_realisticHarvestManager.settings
        if settings then
            -- EN: Apply split difficulty fields received from the server.
            -- UA: Застосовуємо роздільні поля складності, отримані від сервера.
            settings.difficultyMotor = self.difficultyMotor
            settings.difficultyLoss = self.difficultyLoss
            settings.enableSpeedLimit = self.enableSpeedLimit
            settings.enableCropLoss = self.enableCropLoss
            settings.enableIndependentLaunch = self.enableIndependentLaunch
            
            rhm_log(string.format("RHM [Network]: RHM: [Sync] Client received update - Motor: %d, Loss: %d, Speed: %s, CropLoss: %s, IndLaunch: %s",
                    self.difficultyMotor, self.difficultyLoss, tostring(self.enableSpeedLimit), tostring(self.enableCropLoss), tostring(self.enableIndependentLaunch)))
        end
    end
end
