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
-- UA: Створює нову подію, що цілить на конкретний транспорт і несе дані зміни налаштувань.
function RHM_CombineSettingsEvent.new(vehicle, parameter, value, isFullProfile, fullSettings, cropName, mode, cropCalibrated, autoAccepted)
    local self = RHM_CombineSettingsEvent.emptyNew()
    self.vehicle = vehicle
    self.parameter = parameter or ""
    self.value = value or 0
    self.isFullProfile = isFullProfile == true
    self.fullSettings = fullSettings
    self.cropName = cropName or (parameter == "AUTO_SET" and vehicle and vehicle.spec_rhm_Combine and vehicle.spec_rhm_Combine.combineMemory.currentCrop) or ""
    self.mode = mode or ""
    self.cropCalibrated = cropCalibrated == true
    self.autoAccepted = autoAccepted == true
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
        self.cropCalibrated = streamReadBool(streamId)
        self.parameter = streamReadString(streamId)
        if self.parameter == "AUTO_SET" then self.autoAccepted = streamReadBool(streamId) end
    else
        -- EN: Single parameter mode: read parameter name and its value.
        -- UA: Режим одного параметру: зчитуємо назву параметру і його значення.
        self.parameter = streamReadString(streamId)
        self.value = streamReadInt16(streamId)
        if self.parameter == "CROP" or self.parameter == "CALIBRATE" or self.parameter == "AUTO_SET" then
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
        streamWriteBool(streamId, self.cropCalibrated == true)
        streamWriteString(streamId, self.parameter or "")
        if self.parameter == "AUTO_SET" then streamWriteBool(streamId, self.autoAccepted == true) end
    else
        -- EN: Write single parameter name and value.
        -- UA: Записуємо назву та значення одного параметру.
        streamWriteString(streamId, self.parameter)
        streamWriteInt16(streamId, self.value)
        if self.parameter == "CROP" or self.parameter == "CALIBRATE" or self.parameter == "AUTO_SET" then
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
        local autoAccepted = false
        if self.isFullProfile and self.parameter == "AI_PRESET" then
            local user = connection and not connection:getIsServer() and g_currentMission.userManager:getUserByConnection(connection)
            local farm = user and g_farmManager:getFarmForUniqueUserId(user:getUniqueUserId())
            local settings = g_realisticHarvestManager and g_realisticHarvestManager.settings
            local crop = mem.currentCrop
            local isProtected = mem.hasManualTuning and (not mem.manualTunedCrop or mem.manualTunedCrop == crop)
                or self.vehicle._rhmSettingsLoadedFromSavegame
                or ((mem.isCalibrated or (mem.calibratedCrops and mem.calibratedCrops[crop])) and mem.aiTunedCrop ~= crop)
            if farm and farm.farmId == self.vehicle:getOwnerFarmId() and crop and self.cropName == crop
                and rhm_Combine.isAiWorkerActive(self.vehicle) and (not settings or settings.aiHelperTuning ~= 3)
                and not isProtected then
                local profile = self.fullSettings
                for _, name in ipairs({ "fan", "rotor", "upperSieve", "lowerSieve", "feeder", "targetEngineLoad" }) do
                    if profile[name] ~= nil then
                        profile[name] = math.max(name == "targetEngineLoad" and 70 or 0, math.min(100, profile[name]))
                    end
                end
                -- Reuse the developer's helper profile path, including its electronics-tier mode.
                if mem:applyAiWorkerTuning(crop, nil, profile) then
                    self.vehicle.spec_rhm_Combine._lastAiTunedCrop = crop
                end
            end
        elseif self.isFullProfile then
            mem.aiTunedCrop = nil
            -- EN: Apply a complete user preset profile to the combine memory.
            -- UA: Застосовуємо повний профіль користувача до пам'яті комбайна.
            if self.fullSettings then
                if self.fullSettings.fan ~= nil then
                    mem.currentSettings.fan = math.max(0, math.min(100, self.fullSettings.fan))
                end
                if self.fullSettings.rotor ~= nil then
                    mem.currentSettings.rotor = math.max(0, math.min(100, self.fullSettings.rotor))
                end
                if self.fullSettings.upperSieve ~= nil then
                    mem.currentSettings.upperSieve = math.max(0, math.min(100, self.fullSettings.upperSieve))
                end
                if self.fullSettings.lowerSieve ~= nil then
                    mem.currentSettings.lowerSieve = math.max(0, math.min(100, self.fullSettings.lowerSieve))
                end
                if self.fullSettings.feeder ~= nil then
                    local fVal = math.max(0, math.min(100, self.fullSettings.feeder))
                    mem.currentSettings.feeder = fVal
                    mem.currentSettings.concave = fVal
                end
                if self.fullSettings.targetEngineLoad ~= nil then
                    mem.currentSettings.targetEngineLoad = math.max(70, math.min(100, self.fullSettings.targetEngineLoad))
                end
            end
            if self.cropName and self.cropName ~= "" and mem.currentCrop ~= self.cropName then
                mem:switchCrop(self.cropName)
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
            elseif self.parameter == "CALIBRATE" then
                -- Saving a local preset must not reapply a stale copy of the machine settings.
                if self.cropName ~= "" and self.cropName == mem.currentCrop then
                    mem.aiTunedCrop = nil
                    mem.isCalibrated = true
                    mem.calibratedCrops = mem.calibratedCrops or {}
                    mem.calibratedCrops[mem.currentCrop] = true
                end
            elseif self.parameter == "AUTO_SET" then
                -- EN: Client requested one-shot optimal calibration for current crop (Tier 4 exclusive).
                -- UA: Клієнт запросив разове оптимальне калібрування для поточної культури (тільки Тір 4).
                local spec = self.vehicle.spec_rhm_Combine
                local pkgLevel = spec and (spec.packageLevel or 1) or 1
                if pkgLevel >= 4 and mem.currentCrop and self.cropName == mem.currentCrop then
                    autoAccepted = mem:autoConfigureForCrop(mem.currentCrop, true) == true
                end
            elseif self.parameter == "RESET_SET" then
                -- EN: Client requested RESET — revert all settings to neutral 50%.
                -- UA: Клієнт запросив RESET — скидаємо всі налаштування до нейтральних 50%.
                mem.isCalibrated = false
                mem.hasManualTuning = false
                if mem.currentCrop and mem.currentCrop ~= "" and mem.calibratedCrops then
                    mem.calibratedCrops[mem.currentCrop] = nil
                end
                if mem.currentCrop then
                    mem:autoConfigureForCrop(mem.currentCrop, false)
                    rhm_log(string.format("RHM [Network]: RHM: [Sync] Server applied RESET to 50%% for %s", mem.currentCrop))
                end
            else
                -- EN: Apply a single parameter change (e.g. "fan" = 65).
                -- UA: Застосовуємо зміну одного параметру (наприклад "fan" = 65).
                mem:setParameter(self.parameter, self.value)
            end
        end

        -- EN: Include the requester in the accepted state, including server-calculated AUTO settings.
        local fullSettings = {
            fan = mem.currentSettings.fan,
            rotor = mem.currentSettings.rotor,
            upperSieve = mem.currentSettings.upperSieve,
            lowerSieve = mem.currentSettings.lowerSieve,
            feeder = mem.currentSettings.feeder or mem.currentSettings.concave or 50,
            targetEngineLoad = mem.currentSettings.targetEngineLoad
        }
        local calibrated = mem.calibratedCrops and mem.currentCrop and mem.calibratedCrops[mem.currentCrop] == true
        local state = RHM_CombineSettingsEvent.new(self.vehicle, "", 0, true, fullSettings,
            mem.currentCrop or "", nil, calibrated)
        if self.parameter == "AUTO_SET" and connection then
            -- Match the native request/response pattern: only the requester receives the result.
            g_server:broadcastEvent(state, nil, connection, self.vehicle)
            connection:sendEvent(RHM_CombineSettingsEvent.new(self.vehicle, "AUTO_SET", 0, true, fullSettings,
                mem.currentCrop or "", nil, calibrated, autoAccepted))
        else
            g_server:broadcastEvent(state, nil, nil, self.vehicle)
            if self.parameter == "AUTO_SET" and autoAccepted and g_currentMission:getIsClient() then
                mem:showAutoSettingsApplied()
            end
        end
        local spec = self.vehicle.spec_rhm_Combine
        if spec then
            local flag = (spec.settingsDirtyFlag and type(spec.settingsDirtyFlag) == "number" and spec.settingsDirtyFlag)
                      or (spec.dirtyFlag and type(spec.dirtyFlag) == "number" and spec.dirtyFlag)
            if flag then
                self.vehicle:raiseDirtyFlags(flag)
            end
        end

    else
        if not connection or not connection:getIsServer() then return end
        -- EN: Client execution branch - apply the values and update mode state
        -- UA: Гілка клієнта - застосовує значення та оновлює стан режиму
        if self.isFullProfile then
            if self.fullSettings then
                mem.currentSettings.fan = self.fullSettings.fan or mem.currentSettings.fan
                mem.currentSettings.rotor = self.fullSettings.rotor or mem.currentSettings.rotor
                mem.currentSettings.upperSieve = self.fullSettings.upperSieve or mem.currentSettings.upperSieve
                mem.currentSettings.lowerSieve = self.fullSettings.lowerSieve or mem.currentSettings.lowerSieve
                local fVal = self.fullSettings.feeder or mem.currentSettings.feeder or mem.currentSettings.concave
                mem.currentSettings.feeder = fVal
                mem.currentSettings.concave = fVal
                mem.currentSettings.targetEngineLoad = self.fullSettings.targetEngineLoad or mem.currentSettings.targetEngineLoad
            end
            mem.currentCrop = self.cropName ~= "" and self.cropName or nil
            if self.vehicle.spec_rhm_Combine.loadCalculator then
                self.vehicle.spec_rhm_Combine.loadCalculator.currentCrop = mem.currentCrop
            end
            mem.isCalibrated = self.cropCalibrated == true
            if not mem.isCalibrated then mem.hasManualTuning = false end
            if mem.currentCrop and mem.currentCrop ~= "" then
                mem.calibratedCrops = mem.calibratedCrops or {}
                mem.calibratedCrops[mem.currentCrop] = self.cropCalibrated == true or nil
            end
            if self.parameter == "AUTO_SET" and self.autoAccepted == true then
                mem:showAutoSettingsApplied()
            end
        elseif self.parameter == "CROP" then
            if self.cropName and self.cropName ~= "" then
                mem.currentCrop = self.cropName
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

