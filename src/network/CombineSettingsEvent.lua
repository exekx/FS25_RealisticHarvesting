-- EN: Network event for syncing combine settings changes (fan, rotor, sieve, concave/feeder) from
--     the client GUI to the server, and from the server back to all other clients.
--     Supports two modes: single-parameter update or full profile apply.
--     NOTE: The 5th slot in fullSettings is called "slot5" internally and maps to either
--           "concave" (grain) or "feeder" (forage/root/cotton) based on the machine type.
-- UA: Мережева подія для синхронізації змін налаштувань комбайна (вентилятор, ротор, решета, деко/подача)
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
        -- EN: Full profile mode: read all 5 parameter values + upgrade level.
        --     slot5 carries either "concave" (grain) or "feeder" (forage/root/cotton).
        -- UA: Режим повного профілю: зчитуємо всі 5 значень параметрів + рівень апгрейду.
        self.fullSettings = {}
        self.fullSettings.fan = streamReadUInt8(streamId)
        self.fullSettings.rotor = streamReadUInt8(streamId)
        self.fullSettings.upperSieve = streamReadUInt8(streamId)
        self.fullSettings.lowerSieve = streamReadUInt8(streamId)
        self.fullSettings.slot5 = streamReadUInt8(streamId)        -- concave or feeder
        self.fullSettings.targetEngineLoad = streamReadUInt8(streamId)
        self.fullSettings.upgradeLevel = streamReadUInt8(streamId)
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
        -- EN: Write all 5 parameter values + upgrade level for a full profile transfer.
        --     slot5 carries either "concave" (grain) or "feeder" (forage/root/cotton).
        -- UA: Записуємо всі 5 значень параметрів + рівень апгрейду для передачі повного профілю.
        streamWriteUInt8(streamId, self.fullSettings.fan or 50)
        streamWriteUInt8(streamId, self.fullSettings.rotor or 50)
        streamWriteUInt8(streamId, self.fullSettings.upperSieve or 50)
        streamWriteUInt8(streamId, self.fullSettings.lowerSieve or 50)
        streamWriteUInt8(streamId, self.fullSettings.slot5 or 50)   -- concave or feeder
        streamWriteUInt8(streamId, self.fullSettings.targetEngineLoad or 95)
        streamWriteUInt8(streamId, self.fullSettings.upgradeLevel or 0)
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

        -- EN: Helper: apply slot5 value to the correct key (concave for grain, feeder for others).
        -- UA: Допоміжна: застосовуємо значення slot5 до правильного ключа.
        local function applySlot5(memory, val)
            if memory.currentSettings.concave ~= nil then
                memory.currentSettings.concave = val  -- grain combines
            elseif memory.currentSettings.feeder ~= nil then
                memory.currentSettings.feeder = val   -- forage/root/cotton
            end
        end

        if g_server ~= nil then
            if self.isFullProfile then
                -- EN: Apply a complete user preset profile to the combine memory.
                -- UA: Застосовуємо повний профіль користувача до пам'яті комбайна.
                mem.currentSettings.fan = self.fullSettings.fan
                mem.currentSettings.rotor = self.fullSettings.rotor
                mem.currentSettings.upperSieve = self.fullSettings.upperSieve
                mem.currentSettings.lowerSieve = self.fullSettings.lowerSieve
                applySlot5(mem, self.fullSettings.slot5 or 50)
                mem.currentSettings.targetEngineLoad = self.fullSettings.targetEngineLoad
                if self.fullSettings.upgradeLevel then
                    mem.upgradeLevel = self.fullSettings.upgradeLevel
                end
                mem.autoSwitchEnabled = false
                mem.mode = "MANUAL"
                if RHM_Debug and RHM_Debug.isEnabled("Network") then
                    print("RHM: [Sync] Received full user profile settings via network")
                end
            else
                if self.parameter == "UPGRADE_LEVEL" then
                    -- EN: Client purchased an upgrade — update level on server and broadcast.
                    -- UA: Клієнт придбав апгрейд — оновлюємо рівень на сервері та транслюємо.
                    mem.upgradeLevel = math.max(mem.upgradeLevel or 0, math.floor(self.value))
                    if RHM_Debug and RHM_Debug.isEnabled("Network") then
                        print(string.format("RHM: [Sync] Upgrade level set to %d", mem.upgradeLevel))
                    end
                elseif self.parameter == "AUTO_SET" then
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
                        local maxVal = self.parameter == "targetEngineLoad" and 110 or 100
                        mem.currentSettings[self.parameter] = math.max(0, math.min(maxVal, self.value))
                        if self.parameter ~= "targetEngineLoad" then
                            mem.autoSwitchEnabled = false
                            mem.mode = "MANUAL"
                        end
                        if RHM_Debug and RHM_Debug.isEnabled("Network") then
                            print(string.format("RHM: [Sync] Received parameter update: %s = %d", self.parameter, self.value))
                        end
                    end
                end
            end

            -- EN: Server always broadcasts the full state so clients sync perfectly without duplicate calculations.
            --     slot5 carries concave (grain) or feeder (forage/root/cotton) dynamically.
            local fullSettings = {
                fan = mem.currentSettings.fan,
                rotor = mem.currentSettings.rotor,
                upperSieve = mem.currentSettings.upperSieve,
                lowerSieve = mem.currentSettings.lowerSieve,
                slot5 = mem.currentSettings.concave or mem.currentSettings.feeder or 50,
                targetEngineLoad = mem.currentSettings.targetEngineLoad,
                upgradeLevel = mem.upgradeLevel or 0,
            }
            g_server:broadcastEvent(CombineSettingsEvent.new(self.vehicle, "", 0, true, fullSettings), nil, connection, self.vehicle)
            local spec = self.vehicle.spec_rhm_Combine
            if spec and spec.settingsDirtyFlag then
                self.vehicle:raiseDirtyFlags(spec.settingsDirtyFlag)
            else
                self.vehicle:raiseDirtyFlags(spec.dirtyFlag)
            end

        else
            -- EN: Client execution branch - just apply the values without executing complex logic
            -- UA: Гілка клієнта - просто застосовує значення без обчислень
            if self.isFullProfile then
                mem.currentSettings.fan = self.fullSettings.fan
                mem.currentSettings.rotor = self.fullSettings.rotor
                mem.currentSettings.upperSieve = self.fullSettings.upperSieve
                mem.currentSettings.lowerSieve = self.fullSettings.lowerSieve
                applySlot5(mem, self.fullSettings.slot5 or 50)
                mem.currentSettings.targetEngineLoad = self.fullSettings.targetEngineLoad
                if self.fullSettings.upgradeLevel then
                    mem.upgradeLevel = self.fullSettings.upgradeLevel
                end
            elseif self.parameter == "UPGRADE_LEVEL" then
                mem.upgradeLevel = math.max(mem.upgradeLevel or 0, math.floor(self.value))
            elseif self.parameter == "AUTO_MODE" then
                mem.autoSwitchEnabled = (self.value == 1)
                mem.mode = mem.autoSwitchEnabled and "AUTO" or "MANUAL"
            elseif self.parameter ~= "AUTO_SET" and self.parameter ~= "RESET_SET" then
                if mem.currentSettings[self.parameter] ~= nil then
                    local maxVal = self.parameter == "targetEngineLoad" and 110 or 100
                    mem.currentSettings[self.parameter] = math.max(0, math.min(maxVal, self.value))
                    if self.parameter ~= "targetEngineLoad" then
                        mem.autoSwitchEnabled = false
                        mem.mode = "MANUAL"
                    end
                end
            end
        end
    end
end
