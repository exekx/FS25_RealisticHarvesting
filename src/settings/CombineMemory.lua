---@class CombineMemory
---Система пам'яті комбайна для збереження профілів налаштувань
CombineMemory = {}
local CombineMemory_mt = Class(CombineMemory)

---Створити новий екземпляр пам'яті комбайна
---@param combine table Посилання на комбайн
---@return table self Новий екземпляр CombineMemory
function CombineMemory.new(combine)
    local self = setmetatable({}, CombineMemory_mt)
    
    self.combine = combine
    
    -- Збережені профілі для кожної культури
    -- Структура: [profileName] = {cropType, settings, stats, customized}
    self.savedProfiles = {}
    
    -- Поточний активний профіль
    self.currentProfile = nil
    self.currentCrop = nil
    
    -- Поточні налаштування (активний стан комбайна)
    self.currentSettings = {
        fan = 50,         -- Вентилятор 0-100%
        upperSieve = 50,  -- Верхнє сито 0-100%
        lowerSieve = 50,  -- Нижнє сито 0-100%
        rotor = 50,       -- Ротор 0-100%
        rotor = 50,       -- Ротор 0-100%
        feeder = 50,      -- Подавач 0-100%
    }
    
    -- Калібрування врожайності (множник 0.5 - 2.0)
    self.currentYieldCalibration = 1.0
    
    -- Режим роботи
    self.mode = "AUTO"  -- Starts in AUTO mode by default (User Request)
    
    -- Налаштування системи
    self.autoSwitchEnabled = true  -- Автоматичне перемикання при зміні культури
    self.showWarnings = true       -- Показувати попередження про неправильні налаштування
    
    return self
end

---Зберегти поточні налаштування як профіль
---@param cropName string Назва культури
---@param customName string|nil Кастомна назва профілю (опціонально)
---@return boolean success Чи успішно збережено
function CombineMemory:saveCurrentProfile(cropName, customName)
    local profileName = customName or cropName
    
    -- Копіюємо поточні налаштування
    local settingsCopy = {
        fan = self.currentSettings.fan,
        upperSieve = self.currentSettings.upperSieve,
        lowerSieve = self.currentSettings.lowerSieve,
        rotor = self.currentSettings.rotor,
        feeder = self.currentSettings.feeder,
        yieldCalibration = self.currentYieldCalibration or 1.0,
        mode = self.mode -- Save current mode
    }
    
    -- Зберігаємо або оновлюємо профіль
    if self.savedProfiles[profileName] then
        -- Оновлюємо існуючий профіль
        self.savedProfiles[profileName].settings = settingsCopy
        self.savedProfiles[profileName].stats.timesUsed = self.savedProfiles[profileName].stats.timesUsed + 1
        
        local timeStr = "Day 0 00:00"
        if g_currentMission and g_currentMission.environment then
            local env = g_currentMission.environment
            timeStr = string.format("Day %d %02d:%02d", env.currentDay or 0, env.currentHour or 0, env.currentMinute or 0)
        end
        self.savedProfiles[profileName].stats.lastUsed = timeStr
    else
        -- Створюємо новий профіль
        local timeStr = "Day 0 00:00"
        if g_currentMission and g_currentMission.environment then
            local env = g_currentMission.environment
            timeStr = string.format("Day %d %02d:%02d", env.currentDay or 0, env.currentHour or 0, env.currentMinute or 0)
        end
        
        self.savedProfiles[profileName] = {
            cropType = cropName,
            settings = settingsCopy,
            stats = {
                timesUsed = 1,
                lastUsed = timeStr,
                totalHarvested = 0,  -- В тоннах
                averageLoss = 0,     -- Середній crop loss %
            },
            customized = customName ~= nil,  -- Чи це кастомний профіль
        }
    end
    
    print(string.format("RHM: [OK] Profile saved: %s", profileName))
    return true
end

---Завантажити профіль
---@param profileName string Назва профілю
---@return boolean success Чи успішно завантажено
function CombineMemory:loadProfile(profileName)
    local profile = self.savedProfiles[profileName]
    
    if not profile then
        print(string.format("RHM: [!] Profile not found: %s", profileName))
        return false
    end
    
    -- Застосовуємо налаштування
    self.currentSettings.fan = profile.settings.fan
    self.currentSettings.upperSieve = profile.settings.upperSieve
    self.currentSettings.lowerSieve = profile.settings.lowerSieve
    self.currentSettings.rotor = profile.settings.rotor
    self.currentSettings.feeder = profile.settings.feeder
    
    -- Завантажуємо калібрування (або 1.0 якщо немає)
    self.currentYieldCalibration = profile.settings.yieldCalibration or 1.0
    
    -- Restore mode
    if profile.settings.mode then
        self.mode = profile.settings.mode
    else
        if profile.customized then
            self.mode = "MANUAL"
        else
            self.mode = "AUTO"
        end
    end
    
    self.currentProfile = profileName
    self.currentCrop = profile.cropType
    
    -- Оновлюємо статистику
    profile.stats.timesUsed = profile.stats.timesUsed + 1
    local timeStr = "Day 0 00:00"
    if g_currentMission and g_currentMission.environment then
        local env = g_currentMission.environment
        timeStr = string.format("Day %d %02d:%02d", env.currentDay or 0, env.currentHour or 0, env.currentMinute or 0)
    end
    profile.stats.lastUsed = timeStr
    
    print(string.format("RHM: [OK] Profile loaded: %s (used %d times)", profileName, profile.stats.timesUsed))
    return true
end

---Видалити профіль
---@param profileName string Назва профілю
---@return boolean success Чи успішно видалено
function CombineMemory:deleteProfile(profileName)
    if self.savedProfiles[profileName] then
        self.savedProfiles[profileName] = nil
        print(string.format("RHM: [DEL] Profile deleted: %s", profileName))
        return true
    end
    return false
end

---Автоналаштування для культури
---@param cropName string Назва культури
---@param forceOptimal boolean|nil Якщо true - встановити оптимальні значення (Auto mode), інакше - дефолтні (50%)
---@return boolean success Чи успішно налаштовано
function CombineMemory:autoConfigureForCrop(cropName, forceOptimal)
    local optimalSettings = CombineSettingsDatabase:getSettingsForCrop(cropName)
    
    if not optimalSettings then
        print(string.format("RHM: [!] No settings found for crop: %s", cropName))
        -- Fallback to default 50% even if unknown
    end
    
    if forceOptimal and optimalSettings then
        -- [CHANGED] User requested to revert AUTO to suboptimal/safe settings
        -- This means AUTO mode puts you in the Green Zone but not perfect
        
        local function getSuboptimalValue(optimal, tolerance)
            -- Випадково вибираємо сторону (+ або -)
            local sign = math.random() > 0.5 and 1 or -1
            -- Відходимо на 40-50% від толерантності (безпечно, штраф ~1.6%, без бонусу)
            local deviation = tolerance * (0.4 + math.random() * 0.1)
            local value = optimal + (sign * deviation)
            return math.floor(value + 0.5) -- Округляємо до цілого
        end

        self.currentSettings.fan = getSuboptimalValue(optimalSettings.fan.optimal, optimalSettings.fan.tolerance)
        self.currentSettings.upperSieve = getSuboptimalValue(optimalSettings.upperSieve.optimal, optimalSettings.upperSieve.tolerance)
        self.currentSettings.lowerSieve = getSuboptimalValue(optimalSettings.lowerSieve.optimal, optimalSettings.lowerSieve.tolerance)
        self.currentSettings.rotor = getSuboptimalValue(optimalSettings.rotor.optimal, optimalSettings.rotor.tolerance)
        self.currentSettings.feeder = getSuboptimalValue(optimalSettings.feeder.optimal, optimalSettings.feeder.tolerance)
        
        self.mode = "AUTO"
        print(string.format("RHM: [OK] Safe (suboptimal) settings applied for: %s (AUTO)", cropName))
    else
        -- Встановлюємо дефолтні значення (50%) (MANUAL MODE)
        -- Це змушує гравця налаштовувати вручну
        self.currentSettings.fan = 50
        self.currentSettings.upperSieve = 50
        self.currentSettings.lowerSieve = 50
        self.currentSettings.rotor = 50
        self.currentSettings.feeder = 50
        
        self.mode = "MANUAL"
        print(string.format("RHM: [OK] Default settings (50%%) applied for: %s (MANUAL)", cropName))
    end
    
    -- Скидаємо калібрування при автоналаштуванні? Ні, краще залишити поточне або 1.0
    -- Але якщо це нова культура, то 1.0
    if not self.savedProfiles[cropName] then
        self.currentYieldCalibration = 1.0
    end
    
    self.currentCrop = cropName
    
    -- [CHANGED] DO NOT Save as profile automatically in Auto Mode 
    -- This keeps the "User Preset" separate from Auto generated settings
    -- self:saveCurrentProfile(cropName) 
    
    return true
end

---Load the user's saved preset for the current crop
function CombineMemory:loadUserPreset()
    if not self.currentCrop then return false end
    
    if self.savedProfiles[self.currentCrop] then
        return self:loadProfile(self.currentCrop)
    else
        print(string.format("RHM: No user preset found for %s", self.currentCrop))
        return false
    end
end

---Перевірити чи поточні налаштування підходять для культури
---@param cropName string Назва культури
---@return number totalPenalty Загальний штраф (0-50%)
---@return table warnings Список попереджень
function CombineMemory:checkSettingsForCrop(cropName)
    local optimalSettings = CombineSettingsDatabase:getSettingsForCrop(cropName)
    
    if not optimalSettings then
        return 0, {}
    end
    
    local warnings = {}
    local totalPenalty = 0
    local totalBonus = 0
    
    -- Перевіряємо кожен параметр
    for param, value in pairs(self.currentSettings) do
        if optimalSettings[param] then
            local optimal = optimalSettings[param].optimal
            local tolerance = optimalSettings[param].tolerance
            local deviation = math.abs(value - optimal)
            
            if deviation <= tolerance then
                -- GREEN ZONE: Progressive Penalty Curve
                -- 0 deviation = 0 penalty (Perfect)
                -- Max tolerance deviation = 2% penalty (Good but not perfect)
                
                -- Formula: (deviation / tolerance)^2 * maxGreenZonePenalty
                local greenPenalty = (deviation / tolerance)^2 * 2.0
                totalPenalty = totalPenalty + greenPenalty
                
                -- SWEET SPOT BONUS
                -- If deviation is very small (< 1%), give a small bonus
                if deviation < 1.0 then
                    -- Accumulate potential bonus, but don't apply yet
                    totalBonus = totalBonus + 0.5 
                end
                
            else
                -- RED ZONE: Smooth Exponential Penalty
                -- Avoids "cliffs" but ramps up quickly
                -- Formula: 2.0 (green max) + (excess / 5)^1.5 * multiplier
                local excess = deviation - tolerance
                
                -- Old harsh formula: 10 + (excess/10)^2 * 5
                -- New smooth formula: Starts at 2.0 and curves up
                local redPenalty = 2.0 + (excess / 3.0)^1.6 * 4.0
                
                totalPenalty = totalPenalty + redPenalty
                
                -- ANTI-EXPLOIT: If any parameter is red, NO BONUS allowed!
                hasRedParameter = true
                
                table.insert(warnings, {
                    param = param,
                    current = value,
                    optimal = optimal,
                    deviation = deviation,
                    penalty = redPenalty,
                })
            end
        end
    end
    
    -- ANTI-EXPLOIT: Apply bonus ONLY if no parameters are in Red Zone
    if hasRedParameter then
        totalBonus = 0
    end
    
    -- Apply bonus to reduce penalty
    local finalResult = totalPenalty - totalBonus
    
    -- Return: 
    -- 1. Net Penalty (can be negative = bonus)
    -- 2. Warnings list
    return math.max(-5, math.min(finalResult, 100)), warnings
end

---Встановити значення параметру
---@param paramName string Назва параметру
---@param value number Нове значення (0-100)
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
    if mode == "AUTO" and self.currentCrop then
        -- Переключаємо в авто і налаштовуємо для поточної культури (OPTIMAL)
        self:autoConfigureForCrop(self.currentCrop, true)
    elseif mode == "MANUAL" then
        self.mode = "MANUAL"
    end
end

---Отримати кількість збережених профілів
---@return number count Кількість профілів
function CombineMemory:getProfileCount()
    local count = 0
    for _, _ in pairs(self.savedProfiles) do
        count = count + 1
    end
    return count
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
        
        -- Default density if lookup fails
        local density = 0.75 
        
        -- Try to get real density from game
        if cropName and g_fillTypeManager then
            -- Note: cropName here is our RHM name (e.g. "WHEAT"), we need FillType index
            -- Since we don't have easy mapping back, we rely on standard values or try to find it
            -- Loop safe? No.
            -- Better approach: use massPerLiter if passed, or approximate.
            -- Actually, let's assume standard densities for our known crops
            local densities = {
                WHEAT=0.78, BARLEY=0.70, OAT=0.50, CANOLA=0.68, SUNFLOWER=0.35,
                SOYBEAN=0.75, CORN=0.80, SORGHUM=0.75, RICE=0.60,
                ONION=0.55, POTATO=0.65, SUGARBEET=0.65, CARROT=0.58, BEETROOT=0.60, PARSNIP=0.58,
                SPINACH=0.35, PEA=0.81, GREENBEAN=0.50,
                RYE=0.72, SPELT=0.75, TRITICALE=0.70, MILLET=0.75, POPLAR=0.40
            }
            if densities[cropName] then density = densities[cropName] end
        end
        
        -- OR check if we can pass mass directly?
        -- For now, improving the estimate is better than 0.75 hardcoded.
        
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
    
    -- Try to load existing profile
    if self.savedProfiles[newCropName] then
        print(string.format("RHM: Switching to crop %s - Loading profile", newCropName))
        self:loadProfile(newCropName)
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
    end
    return success
end

---Перемкнути режим авто (wrapper для GUI)
function CombineMemory:toggleAutoMode()
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

---Зберегти профіль (wrapper для GUI)
function CombineMemory:saveProfile(cropName)
    return self:saveCurrentProfile(cropName)
end

print("[OK] CombineMemory class loaded")
