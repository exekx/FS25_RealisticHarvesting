---@class CombineSettingsEvent
-- EN: Network event for syncing combine settings changes (fan, rotor, sieve, feeder) from
--     the client GUI to the server, and from the server back to all other clients.
--     Supports two modes: single-parameter update or full profile apply.
-- UA: Мережева подія для синхронізації змін налаштувань комбайна (вентилятор, ротор, решета, подача)
--     від GUI клієнта до сервера, і від сервера до всіх інших клієнтів.
--     Підтримує два режими: оновлення одного параметру або застосування повного профілю.
CombineSettingsEvent = {}
local CombineSettingsEvent_mt = Class(CombineSettingsEvent, Event)

InitEventClass(CombineSettingsEvent, "CombineSettingsEvent")

-- EN: Creates an empty event instance used during network deserialization.
-- UA: Створює порожній екземпляр події для мережевої десеріалізації.
function CombineSettingsEvent.emptyNew()
    local self = Event.new(CombineSettingsEvent_mt)
    return self
end

-- EN: Creates a new event targeting a specific vehicle and carrying setting change data.
-- UA: Створює нову подію, що цілить на конкретний транспорт і несе дані зміни налаштувань.
---@param vehicle table EN: Target combine vehicle / UA: Цільовий комбайн
---@param parameter string EN: Parameter name ("fan", "rotor", "AUTO_SET", "RESET_SET", "AUTO_MODE") / UA: Назва параметру
---@param value number EN: New parameter value (0-100) or mode flag (0/1) / UA: Нове значення (0-100) або прапорець режиму
---@param isFullProfile boolean EN: If true, sends a full settings profile / UA: Якщо true — надсилається повний профіль налаштувань
---@param fullSettings table|nil EN: Full settings table when isFullProfile = true / UA: Повна таблиця налаштувань при isFullProfile = true
function CombineSettingsEvent.new(vehicle, parameter, value, isFullProfile, fullSettings)
    local self = CombineSettingsEvent.emptyNew()
    self.vehicle = vehicle
    self.parameter = parameter or ""
    self.value = value or 0
    self.isFullProfile = isFullProfile == true
    self.fullSettings = fullSettings
    return self
end

-- EN: Deserializes event data from the network stream and immediately executes the event.
-- UA: Десеріалізує дані події з мережевого потоку і негайно виконує її.
function CombineSettingsEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isFullProfile = streamReadBool(streamId)

    if self.isFullProfile then
        -- EN: Full profile mode: read all 5 parameter values.
        -- UA: Режим повного профілю: зчитуємо всі 5 значень параметрів.
        self.fullSettings = {}
        self.fullSettings.fan = streamReadUInt8(streamId)
        self.fullSettings.rotor = streamReadUInt8(streamId)
        self.fullSettings.upperSieve = streamReadUInt8(streamId)
        self.fullSettings.lowerSieve = streamReadUInt8(streamId)
        self.fullSettings.feeder = streamReadUInt8(streamId)
    else
        -- EN: Single parameter mode: read parameter name and its value.
        -- UA: Режим одного параметру: зчитуємо назву параметру і його значення.
        self.parameter = streamReadString(streamId)
        self.value = streamReadInt16(streamId)
    end
    self:run(connection)
end

-- EN: Serializes event data into the network stream.
-- UA: Серіалізує дані події в мережевий потік.
function CombineSettingsEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isFullProfile)

    if self.isFullProfile then
        -- EN: Write all 5 parameter values for a full profile transfer.
        -- UA: Записуємо всі 5 значень параметрів для передачі повного профілю.
        streamWriteUInt8(streamId, self.fullSettings.fan or 50)
        streamWriteUInt8(streamId, self.fullSettings.rotor or 50)
        streamWriteUInt8(streamId, self.fullSettings.upperSieve or 50)
        streamWriteUInt8(streamId, self.fullSettings.lowerSieve or 50)
        streamWriteUInt8(streamId, self.fullSettings.feeder or 50)
    else
        -- EN: Write single parameter name and value.
        -- UA: Записуємо назву та значення одного параметру.
        streamWriteString(streamId, self.parameter)
        streamWriteInt16(streamId, self.value)
    end
end

-- EN: Applies the event payload to the target combine's CombineMemory on the server.
--     After applying, the server broadcasts the change to all other clients.
-- UA: Застосовує дані події до CombineMemory цільового комбайна на сервері.
--     Після застосування сервер транслює зміну всім іншим клієнтам.
function CombineSettingsEvent:run(connection)
    if self.vehicle and self.vehicle:getIsSynchronized() and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.combineMemory then
        local mem = self.vehicle.spec_rhm_Combine.combineMemory

        if self.isFullProfile then
            -- EN: Apply a complete user preset profile to the combine memory.
            -- UA: Застосовуємо повний профіль користувача до пам'яті комбайна.
            mem.currentSettings.fan = self.fullSettings.fan
            mem.currentSettings.rotor = self.fullSettings.rotor
            mem.currentSettings.upperSieve = self.fullSettings.upperSieve
            mem.currentSettings.lowerSieve = self.fullSettings.lowerSieve
            mem.currentSettings.feeder = self.fullSettings.feeder
            mem.autoSwitchEnabled = false
            mem.mode = "MANUAL"
            if RHM_Debug and RHM_Debug.isEnabled("Network") then
                print("RHM: [Sync] Received full user profile settings via network")
            end
        else
            if self.parameter == "AUTO_SET" then
                -- EN: Client requested AUTO mode — configure optimal settings for current crop.
                -- UA: Клієнт запросив AUTO режим — налаштовуємо оптимальні значення для поточної культури.
                mem.autoSwitchEnabled = true
                mem.mode = "AUTO"
                if mem.currentCrop then
                    mem:autoConfigureForCrop(mem.currentCrop, true)
                    if RHM_Debug and RHM_Debug.isEnabled("Network") then
                        print(string.format("RHM: [Sync] Server applied AUTO mode for %s", mem.currentCrop))
                    end
                end
            elseif self.parameter == "RESET_SET" then
                -- EN: Client requested RESET — revert all settings to neutral 50%.
                -- UA: Клієнт запросив RESET — скидаємо всі налаштування до нейтральних 50%.
                mem.autoSwitchEnabled = false
                mem.mode = "MANUAL"
                if mem.currentCrop then
                    mem:autoConfigureForCrop(mem.currentCrop, false)
                    if RHM_Debug and RHM_Debug.isEnabled("Network") then
                        print(string.format("RHM: [Sync] Server applied RESET to 50%% for %s", mem.currentCrop))
                    end
                end
            elseif self.parameter == "AUTO_MODE" then
                -- EN: Toggle the auto-switch behavior flag (1 = enabled, 0 = disabled).
                -- UA: Перемикаємо прапорець автоматичного перемикання (1 = увімкнено, 0 = вимкнено).
                mem.autoSwitchEnabled = (self.value == 1)
                mem.mode = mem.autoSwitchEnabled and "AUTO" or "MANUAL"
            else
                -- EN: Apply a single parameter change (e.g. "fan" = 65).
                -- UA: Застосовуємо зміну одного параметру (наприклад "fan" = 65).
                if mem.currentSettings[self.parameter] ~= nil then
                    mem.currentSettings[self.parameter] = math.max(0, math.min(100, self.value))
                    mem.autoSwitchEnabled = false
                    mem.mode = "MANUAL"
                    if RHM_Debug and RHM_Debug.isEnabled("Network") then
                        print(string.format("RHM: [Sync] Received parameter update: %s = %d", self.parameter, self.value))
                    end
                end
            end
        end

        -- EN: If we are the server, broadcast the change to all other clients and raise dirty flags.
        -- UA: Якщо ми сервер — транслюємо зміну всім іншим клієнтам і піднімаємо dirty flags.
        if g_server ~= nil then
            g_server:broadcastEvent(CombineSettingsEvent.new(self.vehicle, self.parameter, self.value, self.isFullProfile, self.fullSettings), nil, connection, self.vehicle)
            local spec = self.vehicle.spec_rhm_Combine
            if spec and spec.settingsDirtyFlag then
                self.vehicle:raiseDirtyFlags(spec.settingsDirtyFlag)
            else
                self.vehicle:raiseDirtyFlags(spec.dirtyFlag)
            end
        end
    end
end
