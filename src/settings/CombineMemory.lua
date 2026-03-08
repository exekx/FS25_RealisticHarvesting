---@class CombineMemory
---Система пам'яті комбайна для збереження профілів налаштувань
CombineMemory = {}
local CombineMemory_mt = Class(CombineMemory)

---Створити новий екземпляр пам'яті комбайна
---@param combine table Посилання на комбайн
---@param machineType string|nil "grain"|"forage"|"root"|"cotton" — тип машини
---@return table self Новий екземпляр CombineMemory
function CombineMemory.new(combine, machineType)
    local self = setmetatable({}, CombineMemory_mt)
    
    self.combine = combine
    self.machineType = machineType or "grain"
    
    -- Поточний активний профіль
    self.currentProfile = nil
    self.currentCrop = nil
    
    -- Поточні налаштування (активний стан комбайна)
    -- Динамічно ініціалізуємо тільки параметри для цього типу машини
    self.currentSettings = {}
    local activeParams = CombineSettingsDatabase:getParamsForMachineType(self.machineType)
    for _, paramName in ipairs(activeParams) do
        self.currentSettings[paramName] = 50
    end
    
    -- Калібрування врожайності (множник 0.5 - 2.0)
    self.currentYieldCalibration = 1.0
    
    -- Режим роботи
    self.mode = "AUTO"  -- Starts in AUTO mode by default (User Request)
    
    -- Налаштування системи
    self.autoSwitchEnabled = true  -- Автоматичне перемикання при зміні культури
    self.showWarnings = true       -- Показувати попередження про неправильні налаштування
    
    -- Cached profile count removed
    
    return self
end

---Зберегти поточні налаштування як глобальний профіль
---@param cropName string Назва культури
---@return boolean success Чи успішно збережено
function CombineMemory:saveCurrentProfile(cropName)
    local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
    if pm then
        pm:saveProfile(cropName, self.currentSettings)
        print(string.format("RHM: [OK] Profile saved globally: %s", cropName))
        return true
    end
    print("RHM: [!] Failed to save global profile: ProfileManager not found")
    return false
end

-- (Removed local loadProfile and deleteProfile)

---Автоналаштування для культури
---@param cropName string Назва культури
---@param forceOptimal boolean|nil Якщо true - встановити оптимальні значення (Auto mode), інакше - дефолтні (50%)
---@return boolean success Чи успішно налаштовано
function CombineMemory:autoConfigureForCrop(cropName, forceOptimal)
    if not cropName then
        print("RHM: [!] autoConfigureForCrop called with nil cropName, skipping")
        return false
    end
    local optimalSettings = CombineSettingsDatabase:getSettingsForCrop(cropName)
    
    if not optimalSettings then
        print(string.format("RHM: [!] No settings found for crop: %s", cropName))
        -- Fallback to default 50% even if unknown
    end
    
    if forceOptimal and optimalSettings then
        -- AUTO режим: випадковий відхил 1-10 одиниць від оптимуму
        -- ВАЖЛИВО: На дедикованому сервері випадковість має бути тільки на сервері!
        
        local function getAutoValue(optimal)
            -- Якщо ми на сервері - генеруємо випадковість
            -- Якщо на клієнті - просто беремо оптимальне (воно скоро перекриється даними з сервера)
            local deviation = 0
            if (g_server ~= nil) then
                deviation = math.random(1, 10)
                local sign = math.random() > 0.5 and 1 or -1
                deviation = sign * deviation
            end
            
            local value = optimal + deviation
            return math.max(0, math.min(100, value))
        end

        -- Динамічно ітеруємо по активних параметрах для цього типу машини
        local activeParams = CombineSettingsDatabase:getParamsForMachineType(self.machineType)
        for _, pName in ipairs(activeParams) do
            if optimalSettings[pName] then
                self.currentSettings[pName] = getAutoValue(optimalSettings[pName].optimal)
            else
                self.currentSettings[pName] = 50 
            end
        end
        
        self.mode = "AUTO"
        print(string.format("RHM: [OK] Auto settings applied for: %s (forceOptimal=%s)", cropName, tostring(forceOptimal)))
    else
        -- Reset all active params to 50% (MANUAL MODE / RESET)
        local activeParams = CombineSettingsDatabase:getParamsForMachineType(self.machineType)
        for _, pName in ipairs(activeParams) do
            self.currentSettings[pName] = 50
        end
        
        self.mode = "MANUAL"
        print(string.format("RHM: [OK] Default settings (50%%) applied for: %s", cropName))
    end
    
    local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
    if not pm or not pm:getProfile(cropName) then
        self.currentYieldCalibration = 1.0
    end
    
    self.currentCrop = cropName
    return true
end

---Мережевий запит на встановлення AUTO режиму
function CombineMemory:requestAutoSettings()
    if not self.currentCrop then return end
    
    if g_client and self.combine then
        -- Надсилаємо команду серверу
        local event = CombineSettingsEvent.new(self.combine, "AUTO_SET", 1)
        if not g_server then
            g_client:getServerConnection():sendEvent(event)
        else
            -- В синглі просто викликаємо локально через event
            event:run(nil)
        end
        print("RHM: [Sync] Requested AUTO settings from server")
    end
end

---Мережевий запит на RESET (50%)
function CombineMemory:requestResetSettings()
    if not self.currentCrop then return end
    
    if g_client and self.combine then
        local event = CombineSettingsEvent.new(self.combine, "RESET_SET", 1)
        if not g_server then
            g_client:getServerConnection():sendEvent(event)
        else
            event:run(nil)
        end
        print("RHM: [Sync] Requested RESET settings from server")
    end
end

---Завантажити глобальний пресет користувача для поточної культури
function CombineMemory:loadUserPreset()
    if not self.currentCrop then return false end
    
    local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
    if not pm then return false end
    
    local profile = pm:getProfile(self.currentCrop)
    if profile then
        if g_client and self.combine then
            local event = CombineSettingsEvent.new(self.combine, "", 0, true, profile)
            if not g_server then
                g_client:getServerConnection():sendEvent(event)
            else
                local conn = g_currentMission and g_currentMission.player and g_currentMission.player.serverConnection or nil
                event:run(conn)
            end
        else
            self.currentSettings.fan = profile.fan
            self.currentSettings.rotor = profile.rotor
            self.currentSettings.upperSieve = profile.upperSieve
            self.currentSettings.lowerSieve = profile.lowerSieve
            self.currentSettings.feeder = profile.feeder
            self.mode = "MANUAL"
            self.autoSwitchEnabled = false
        end
        print(string.format("RHM: [OK] Global profile applied for %s", self.currentCrop))
        return true
    else
        print(string.format("RHM: No global user preset found for %s", self.currentCrop))
        return false
    end
end

---Перевірити чи поточні налаштування підходять для культури
---@param cropName string Назва культури
---@return number totalPenalty Загальний штраф (0-50%)
---Перевірити чи поточні налаштування підходять для культури і розділити їх на фізичні ефекти
---@param cropName string Назва культури
---@return number efficiencyPenalty Штраф до пропускної здатності (швидкості)
---@return number lossPenalty Прямі втрати врожаю (зерно в солому)
---@return table warnings Список попереджень
function CombineMemory:checkSettingsForCrop(cropName)
    local optimalSettings = CombineSettingsDatabase:getSettingsForCrop(cropName)
    
    if not optimalSettings then
        return 0, 0, {}
    end
    
    local warnings = {}
    local efficiencyScore = 0  -- Впливає на maxAvgMass (швидкість/навантаження)
    local lossScore = 0        -- Прямі втрати врожаю
    
    -- Перевіряємо кожен параметр
    for param, value in pairs(self.currentSettings) do
        if optimalSettings[param] then
            local optimal   = optimalSettings[param].optimal
            local tolerance = optimalSettings[param].tolerance
            local deviation = math.abs(value - optimal)
            
            local score = 0
            if deviation <= tolerance then
                -- GREEN ZONE: лінійна крива від -0.5 (ідеально) до +0.5 (на межі допуску)
                score = (deviation / tolerance - 0.5) * 1.0
            else
                -- RED ZONE: лінійне зростання від +0.5 (штраф)
                local excess = deviation - tolerance
                score = math.min(6.0, 0.5 + excess * 0.33)
                
                table.insert(warnings, {
                    param    = param,
                    current  = value,
                    optimal  = optimal,
                    deviation = deviation,
                    penalty  = score,
                })
            end
            
            -- РОЗПОДІЛ ЗА ФІЗИЧНИМ ВПЛИВОМ
            if param == "feeder" or param == "rotor" then
                -- Ці параметри відповідають за те, як легко маса проходить через комбайн.
                -- Якщо вони налаштовані погано, комбайну важко, він задихається (падає швидкість).
                efficiencyScore = efficiencyScore + score
            elseif param == "fan" or param == "upperSieve" or param == "lowerSieve" then
                -- Ці параметри відповідають за очистку. 
                -- Якщо вітер занадто сильний або решета закриті, зерно видуває в солому.
                lossScore = lossScore + score
            else
                -- Дефолтний fallback
                efficiencyScore = efficiencyScore + (score * 0.5)
                lossScore = lossScore + (score * 0.5)
            end
        end
    end
    
    -- МАСШТАБУВАННЯ ТА ОБМЕЖЕННЯ
    -- Раніше всі 5 параметрів могли дати -2.5% сумарно (5 * -0.5).
    -- Тепер Ефективність має макс -1.0% (2 параметри), а Втрати -1.5% (3 параметри).
    local efficiencyPenalty = math.max(-1.0, math.min(efficiencyScore, 20.0))
    local lossPenalty = math.max(-1.5, math.min(lossScore, 20.0))
    
    return efficiencyPenalty, lossPenalty, warnings
end
---@return boolean success Чи успішно встановлено
function CombineMemory:setParameter(paramName, value)
    if self.currentSettings[paramName] ~= nil then
        self.currentSettings[paramName] = math.max(0, math.min(100, value))
        self.mode = "MANUAL"  -- Автоматично переключаємо в ручний режим
        return true
    end
    return false
end

-- setYieldCalibration REMOVED (User Request)

---Перемкнути режим AUTO/MANUAL
---@param mode string "AUTO" або "MANUAL"
function CombineMemory:setMode(mode)
    if mode == "AUTO" then
        if self.currentCrop then
            -- Є поточна культура — налаштовуємо відразу
            self:autoConfigureForCrop(self.currentCrop, true)
        else
            -- FIX DS: культура ще не визначена (на DS між першим завантаженням та першим збиранням)
            -- Зберігаємо режим і autoSwitchEnabled, щоб switchCrop застосував AUTO коли знайде культуру
            self.mode = "AUTO"
            self.autoSwitchEnabled = true
            print("RHM: [AUTO] currentCrop is nil on DS, pending AUTO mode set. Will apply when crop detected.")
        end
    elseif mode == "MANUAL" then
        self.mode = "MANUAL"
    end
end

---Отримати кількість збережених профілів
---@return number count Кількість профілів
function CombineMemory:getProfileCount()
    -- FIX: Return cached count instead of iterating every call
    return self.profileCount or 0
end

---Отримати список назв профілів
---@return table names Масив назв профілів
function CombineMemory:getProfileNames()
    local names = {}
    for profileName, _ in pairs(self.savedProfiles) do
        table.insert(names, profileName)
    end
    table.sort(names)
    return names
end

---Оновити статистику для поточного профілю
---@param harvestedLiters number Кількість зібраного зерна в літрах
---@param cropLoss number Відсоток втрат
---@param cropName string|nil Назва культури (для визначення маси)
function CombineMemory:updateStatistics(harvestedLiters, cropLoss, cropName)
    if self.currentProfile and self.savedProfiles[self.currentProfile] then
        local profile = self.savedProfiles[self.currentProfile]
        
        -- FIX: Get density from g_fillTypeManager via CombineSettingsDatabase mapping
        -- instead of a duplicated hardcoded table
        local density = 0.75  -- fallback (kg/L)
        if cropName and g_fillTypeManager and CombineSettingsDatabase then
            local cropData = CombineSettingsDatabase:getCropData(cropName)
            if cropData and cropData.fillType then
                local fillTypeObj = g_fillTypeManager:getFillTypeByIndex(cropData.fillType)
                if fillTypeObj and fillTypeObj.massPerLiter and fillTypeObj.massPerLiter > 0 then
                    -- massPerLiter in FS25 is stored in t/L, convert to kg/L
                    density = fillTypeObj.massPerLiter * 1000
                end
            end
        end
        
        local tons = harvestedLiters * density / 1000
        
        profile.stats.totalHarvested = profile.stats.totalHarvested + tons
        
        -- Оновлюємо середні втрати (ковзаюче середнє)
        if profile.stats.averageLoss == 0 then
            profile.stats.averageLoss = cropLoss
        else
            -- Рухоме середнє для точності
            profile.stats.averageLoss = profile.stats.averageLoss * 0.95 + cropLoss * 0.05
        end
    end
end


---Switch to a different crop and load its settings
---@param newCropName string The name of the new crop
function CombineMemory:switchCrop(newCropName)
    if not newCropName or newCropName == self.currentCrop then
        return
    end
    
    -- Save current profile if we have a current crop
    if self.currentCrop then
        self:saveCurrentProfile(self.currentCrop)
    end
    
    self.currentCrop = newCropName
    
    -- Try to load existing global profile
    local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
    if pm and pm:getProfile(newCropName) then
        print(string.format("RHM: Switching to crop %s - Loading global profile", newCropName))
        self:loadUserPreset()
    else
        -- Or configure default/safe settings
        print(string.format("RHM: Switching to crop %s - No profile, applying defaults", newCropName))
        -- If auto switch enabled, use optimal safe settings, else neutral 50%
        if self.autoSwitchEnabled then
             self:autoConfigureForCrop(newCropName, true)
        else
             self:autoConfigureForCrop(newCropName, false)
        end
    end
end

-- ============================================================================
-- GUI HELPERS
-- ============================================================================

---Оновити налаштування (wrapper для GUI)
function CombineMemory:updateSetting(param, value)
    -- Встановлюємо через setParameter, який перемкне в MANUAL
    local success = self:setParameter(param, value)
    if success then
        self.autoSwitchEnabled = false
        self.mode = "MANUAL"
        
        if g_client and self.combine then
            local event = CombineSettingsEvent.new(self.combine, param, self.currentSettings[param], false, nil)
            if not g_server then
                g_client:getServerConnection():sendEvent(event)
            else
                local conn = g_currentMission and g_currentMission.player and g_currentMission.player.serverConnection or nil
                event:run(conn)
            end
        end
    end
    return success
end

---Перемкнути режим авто (wrapper для GUI)
function CombineMemory:toggleAutoMode()
    -- Якщо ми на клієнті в мультиплеєрі, надсилаємо запит на сервер
    if g_client and self.combine and not g_server then
        local targetMode = not self.autoSwitchEnabled
        local event = CombineSettingsEvent.new(self.combine, "AUTO_MODE", targetMode and 1 or 0)
        g_client:getServerConnection():sendEvent(event)
        print(string.format("RHM: [Sync] Sent AUTO mode request to server: %s", targetMode and "ON" or "OFF"))
    else
        -- Одиночна гра або ми сервер: застосовуємо відразу
        self.autoSwitchEnabled = not self.autoSwitchEnabled
        
        if self.autoSwitchEnabled then
            self.mode = "AUTO"
            if self.currentCrop then
                self:autoConfigureForCrop(self.currentCrop, true) -- Force optimal
            end
        else
            self.mode = "MANUAL"
        end
        print(string.format("RHM: Auto Switch %s", self.autoSwitchEnabled and "ENABLED" or "DISABLED"))
    end
end

---Зберегти профіль (wrapper для GUI)
function CombineMemory:saveProfile(cropName)
    return self:saveCurrentProfile(cropName)
end

print("[OK] CombineMemory class loaded")
