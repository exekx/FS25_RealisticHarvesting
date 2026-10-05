-- EN: Network event for syncing combine settings changes (fan, rotor, sieve, feeder) from
--     the client GUI to the server, and from the server back to all other clients.
--     Supports two modes: single-parameter update or full profile apply.
-- UA: Мережева подія для синхронізації змін налаштувань комбайна (вентилятор, ротор, решета, подача)
--     від GUI клієнта до сервера, і від сервера до всіх інших клієнтів.
--     Підтримує два режими: оновлення одного параметру або застосування повного профілю.
RHM_CombineSettingsEvent = {}
local CombineSettingsEvent_mt = Class(RHM_CombineSettingsEvent, Event)

InitEventClass(RHM_CombineSettingsEvent, "RHM_CombineSettingsEvent")

-- EN: Creates an empty event instance used during network deserialization.
-- UA: Створює порожній екземпляр події для мережевої десеріалізації.
function RHM_CombineSettingsEvent.emptyNew()
    local self = Event.new(CombineSettingsEvent_mt)
    return self
end

-- EN: Creates a new event targeting a specific vehicle and carrying setting change data.
-- EN: Creates a new event targeting a specific vehicle and carrying setting change data.
-- UA: Створює нову подію, що цілить на конкретний транспорт і несе дані зміни налаштувань.
function RHM_CombineSettingsEvent.new(vehicle, parameter, value, isFullProfile, fullSettings, cropName, mode)
    local self = RHM_CombineSettingsEvent.emptyNew()
    self.vehicle = vehicle
    self.parameter = parameter or ""
    self.value = value or 0
    self.isFullProfile = isFullProfile == true
    self.fullSettings = fullSettings
    self.cropName = cropName or ""
    self.mode = mode or ""
    return self
end

-- EN: Deserializes event data from the network stream and immediately executes the event.
-- UA: Десеріалізує дані події з мережевого потоку і негайно виконує її.
function RHM_CombineSettingsEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isFullProfile = streamReadBool(streamId)

    if self.isFullProfile then
        -- EN: Full profile mode: read all 6 parameter values, cropName, and mode.
        -- UA: Режим повного профілю: зчитуємо всі 6 значень параметрів, назву культури та режим.
        self.fullSettings = {}
        self.fullSettings.fan = streamReadUInt8(streamId)
        self.fullSettings.rotor = streamReadUInt8(streamId)
        self.fullSettings.upperSieve = streamReadUInt8(streamId)
        self.fullSettings.lowerSieve = streamReadUInt8(streamId)
        self.fullSettings.feeder = streamReadUInt8(streamId)
        self.fullSettings.targetEngineLoad = streamReadUInt8(streamId)
        self.cropName = streamReadString(streamId)
        self.mode = streamReadString(streamId)
    else
        -- EN: Single parameter mode: read parameter name and its value.
        -- UA: Режим одного параметру: зчитуємо назву параметру і його значення.
        self.parameter = streamReadString(streamId)
        self.value = streamReadInt16(streamId)
        if self.parameter == "CROP" then
            self.cropName = streamReadString(streamId)
        end
    end
    self:run(connection)
end

-- EN: Serializes event data into the network stream.
-- UA: Серіалізує дані події в мережевий потік.
function RHM_CombineSettingsEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isFullProfile)

    if self.isFullProfile then
        -- EN: Write all 6 parameter values, cropName, and mode for a full profile transfer.
        -- UA: Записуємо всі 6 значень параметрів, назву культури та режим для передачі повного профілю.
        local s = self.fullSettings or {}
        streamWriteUInt8(streamId, s.fan or 50)
        streamWriteUInt8(streamId, s.rotor or 50)
        streamWriteUInt8(streamId, s.upperSieve or 50)
        streamWriteUInt8(streamId, s.lowerSieve or 50)
        streamWriteUInt8(streamId, s.feeder or 50)
        streamWriteUInt8(streamId, s.targetEngineLoad or 80)
        streamWriteString(streamId, self.cropName or "")
        streamWriteString(streamId, self.mode or "")
    else
        -- EN: Write single parameter name and value.
        -- UA: Записуємо назву та значення одного параметру.
        streamWriteString(streamId, self.parameter)
        streamWriteInt16(streamId, self.value)
        if self.parameter == "CROP" then
            streamWriteString(streamId, self.cropName or "")
        end
    end
end

-- EN: Applies the event payload to the target combine's RHM_CombineMemory on the server.
--     After applying, the server broadcasts the change to all other clients.
-- UA: Застосовує дані події до RHM_CombineMemory цільового комбайна на сервері.
--     Після застосування сервер транслює зміну всім іншим клієнтам.
function RHM_CombineSettingsEvent:run(connection)
    -- EN: Safety checks for vehicle and components
    -- UA: Перевірки безпеки для транспорту та компонентів
    if not self.vehicle or (self.vehicle.getIsSynchronized and not self.vehicle:getIsSynchronized()) or self.vehicle.isDeleted then
        return
    end
    
    if not self.vehicle.spec_rhm_Combine or not self.vehicle.spec_rhm_Combine.combineMemory then
        return
    end
    
    local mem = self.vehicle.spec_rhm_Combine.combineMemory

    if g_server ~= nil then
        if self.isFullProfile then
            -- EN: Apply a complete user preset profile to the combine memory.
            -- UA: Застосовуємо повний профіль користувача до пам'яті комбайна.
            if self.fullSettings then
                mem.currentSettings.fan = self.fullSettings.fan or mem.currentSettings.fan
                mem.currentSettings.rotor = self.fullSettings.rotor or mem.currentSettings.rotor
                mem.currentSettings.upperSieve = self.fullSettings.upperSieve or mem.currentSettings.upperSieve
                mem.currentSettings.lowerSieve = self.fullSettings.lowerSieve or mem.currentSettings.lowerSieve
                mem.currentSettings.feeder = self.fullSettings.feeder or mem.currentSettings.feeder
                mem.currentSettings.targetEngineLoad = self.fullSettings.targetEngineLoad or mem.currentSettings.targetEngineLoad
            end
            if self.cropName and self.cropName ~= "" and mem.currentCrop ~= self.cropName then
                mem:switchCrop(self.cropName)
            end
            if self.mode and self.mode ~= "" then
                mem.mode = self.mode
                mem.autoSwitchEnabled = (self.mode == "AUTO")
            else
                mem.autoSwitchEnabled = false
                mem.mode = "MANUAL"
            end
            mem.isCalibrated = true
            mem.hasManualTuning = true
            if mem.currentCrop and mem.currentCrop ~= "" then
                mem.calibratedCrops = mem.calibratedCrops or {}
                mem.calibratedCrops[mem.currentCrop] = true
            end
            rhm_log("RHM [Network]: RHM: [Sync] Received full user profile settings via network")
        else
            if self.parameter == "CROP" then
                if self.cropName and self.cropName ~= "" then
                    mem:switchCrop(self.cropName)
                    rhm_log(string.format("RHM [Network]: RHM: [Sync] Server applied crop switch to %s", self.cropName))
                end
            elseif self.parameter == "AUTO_SET" then
                -- EN: Client requested AUTO mode — configure optimal settings for current crop (Tier 4 exclusive).
                -- UA: Клієнт запросив AUTO режим — налаштовуємо оптимальні значення для поточної культури (тільки Тір 4).
                local spec = self.vehicle.spec_rhm_Combine
                local pkgLevel = spec and (spec.packageLevel or 1) or 1
                if pkgLevel >= 4 then
                    mem.autoSwitchEnabled = true
                    mem.mode = "AUTO"
                    mem.isCalibrated = true
                    if mem.currentCrop and mem.currentCrop ~= "" then
                        mem.calibratedCrops = mem.calibratedCrops or {}
                        mem.calibratedCrops[mem.currentCrop] = true
                    end
                    if mem.currentCrop then
                        mem:autoConfigureForCrop(mem.currentCrop, true)
                        rhm_log(string.format("RHM [Network]: RHM: [Sync] Server applied AUTO mode for %s", mem.currentCrop))
                    end
                else
                    rhm_log(string.format("RHM [Network]: RHM: [!] Server rejected AUTO_SET: packageLevel %d < 4", pkgLevel))
                    mem.autoSwitchEnabled = false
                    mem.mode = "MANUAL"
                end
            elseif self.parameter == "RESET_SET" then
                -- EN: Client requested RESET — revert all settings to neutral 50%.
                -- UA: Клієнт запросив RESET — скидаємо всі налаштування до нейтральних 50%.
                mem.autoSwitchEnabled = false
                mem.mode = "MANUAL"
                mem.isCalibrated = false
                mem.hasManualTuning = false
                if mem.currentCrop and mem.currentCrop ~= "" and mem.calibratedCrops then
                    mem.calibratedCrops[mem.currentCrop] = nil
                end
                if mem.currentCrop then
                    mem:autoConfigureForCrop(mem.currentCrop, false)
                    rhm_log(string.format("RHM [Network]: RHM: [Sync] Server applied RESET to 50%% for %s", mem.currentCrop))
                end
            elseif self.parameter == "AUTO_MODE" then
                -- EN: Toggle the auto-switch behavior flag (Tier 4 exclusive).
                -- UA: Перемикаємо прапорець автоматичного перемикання (тільки Тір 4).
                local spec = self.vehicle.spec_rhm_Combine
                local pkgLevel = spec and (spec.packageLevel or 1) or 1
                if pkgLevel >= 4 then
                    mem.autoSwitchEnabled = (self.value == 1)
                    mem.mode = mem.autoSwitchEnabled and "AUTO" or "MANUAL"
                else
                    mem.autoSwitchEnabled = false
                    mem.mode = "MANUAL"
                end
            else
                -- EN: Apply a single parameter change (e.g. "fan" = 65).
                -- UA: Застосовуємо зміну одного параметру (наприклад "fan" = 65).
                if mem.currentSettings[self.parameter] ~= nil then
                    local minVal = self.parameter == "targetEngineLoad" and 70 or 0
                    local maxVal = 100
                    mem.currentSettings[self.parameter] = math.max(minVal, math.min(maxVal, self.value))
                    if self.parameter ~= "targetEngineLoad" then
                        mem.autoSwitchEnabled = false
                        mem.mode = "MANUAL"
                    end
                    mem.isCalibrated = true
                    mem.hasManualTuning = true
                    if mem.currentCrop and mem.currentCrop ~= "" then
                        mem.calibratedCrops = mem.calibratedCrops or {}
                        mem.calibratedCrops[mem.currentCrop] = true
                    end
                    rhm_log(string.format("RHM [Network]: RHM: [Sync] Received parameter update: %s = %d", self.parameter, self.value))
                end
            end
        end

        -- EN: Server always broadcasts the full state so clients sync perfectly without duplicate calculations.
        local fullSettings = {
            fan = mem.currentSettings.fan,
            rotor = mem.currentSettings.rotor,
            upperSieve = mem.currentSettings.upperSieve,
            lowerSieve = mem.currentSettings.lowerSieve,
            feeder = mem.currentSettings.feeder,
            targetEngineLoad = mem.currentSettings.targetEngineLoad
        }
        g_server:broadcastEvent(
            RHM_CombineSettingsEvent.new(
                self.vehicle,
                "",
                0,
                true,
                fullSettings,
                mem.currentCrop or "",
                mem.mode or "MANUAL"
            ),
            nil,
            connection,
            self.vehicle
        )
        local spec = self.vehicle.spec_rhm_Combine
        if spec then
            local flag = (spec.settingsDirtyFlag and type(spec.settingsDirtyFlag) == "number" and spec.settingsDirtyFlag)
                      or (spec.dirtyFlag and type(spec.dirtyFlag) == "number" and spec.dirtyFlag)
            if flag then
                self.vehicle:raiseDirtyFlags(flag)
            end
        end

    else
        -- EN: Client execution branch - apply the values and update mode state
        -- UA: Гілка клієнта - застосовує значення та оновлює стан режиму
        if self.isFullProfile then
            if self.fullSettings then
                mem.currentSettings.fan = self.fullSettings.fan or mem.currentSettings.fan
                mem.currentSettings.rotor = self.fullSettings.rotor or mem.currentSettings.rotor
                mem.currentSettings.upperSieve = self.fullSettings.upperSieve or mem.currentSettings.upperSieve
                mem.currentSettings.lowerSieve = self.fullSettings.lowerSieve or mem.currentSettings.lowerSieve
                mem.currentSettings.feeder = self.fullSettings.feeder or mem.currentSettings.feeder
                mem.currentSettings.targetEngineLoad = self.fullSettings.targetEngineLoad or mem.currentSettings.targetEngineLoad
            end
            if self.cropName and self.cropName ~= "" then
                mem.currentCrop = self.cropName
                if self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.loadCalculator then
                    self.vehicle.spec_rhm_Combine.loadCalculator.currentCrop = self.cropName
                end
            end
            if self.mode and self.mode ~= "" then
                mem.mode = self.mode
                mem.autoSwitchEnabled = (self.mode == "AUTO")
            else
                mem.autoSwitchEnabled = false
                mem.mode = "MANUAL"
            end
            mem.isCalibrated = true
            mem.hasManualTuning = true
            if mem.currentCrop and mem.currentCrop ~= "" then
                mem.calibratedCrops = mem.calibratedCrops or {}
                mem.calibratedCrops[mem.currentCrop] = true
            end
        elseif self.parameter == "CROP" then
            if self.cropName and self.cropName ~= "" then
                mem.currentCrop = self.cropName
            end
        elseif self.parameter == "AUTO_MODE" then
            local spec = self.vehicle.spec_rhm_Combine
            local pkgLevel = spec and (spec.packageLevel or 1) or 1
            if pkgLevel >= 4 then
                mem.autoSwitchEnabled = (self.value == 1)
                mem.mode = mem.autoSwitchEnabled and "AUTO" or "MANUAL"
            else
                mem.autoSwitchEnabled = false
                mem.mode = "MANUAL"
            end
        elseif self.parameter == "RESET_SET" then
            mem.isCalibrated = false
            mem.hasManualTuning = false
            if mem.currentCrop and mem.currentCrop ~= "" and mem.calibratedCrops then
                mem.calibratedCrops[mem.currentCrop] = nil
            end
        elseif self.parameter ~= "AUTO_SET" then
            if mem.currentSettings[self.parameter] ~= nil then
                local minVal = self.parameter == "targetEngineLoad" and 70 or 0
                local maxVal = 100
                mem.currentSettings[self.parameter] = math.max(minVal, math.min(maxVal, self.value))
                if self.parameter ~= "targetEngineLoad" then
                    mem.autoSwitchEnabled = false
                    mem.mode = "MANUAL"
                end
                mem.isCalibrated = true
                mem.hasManualTuning = true
                if mem.currentCrop and mem.currentCrop ~= "" then
                    mem.calibratedCrops = mem.calibratedCrops or {}
                    mem.calibratedCrops[mem.currentCrop] = true
                end
            end
        end
    end
end

