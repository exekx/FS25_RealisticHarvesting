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
        feeder = 50,      -- Подавач 0-100%
    }
    
    -- Режим роботи
    self.mode = "MANUAL"  -- Starts in MANUAL mode by default
    
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
        -- Встановлюємо оптимальні значення (AUTO MODE)
        self.currentSettings.fan = optimalSettings.fan.optimal
        self.currentSettings.upperSieve = optimalSettings.upperSieve.optimal
        self.currentSettings.lowerSieve = optimalSettings.lowerSieve.optimal
        self.currentSettings.rotor = optimalSettings.rotor.optimal
        self.currentSettings.feeder = optimalSettings.feeder.optimal
        
        self.mode = "AUTO"
        print(string.format("RHM: [OK] Optimal settings applied for: %s (AUTO)", cropName))
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
    
    self.currentCrop = cropName
    
    -- Автоматично зберігаємо як профіль
    self:saveCurrentProfile(cropName)
    
    return true
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
    
    -- Перевіряємо кожен параметр
    for param, value in pairs(self.currentSettings) do
        if optimalSettings[param] then
            local optimal = optimalSettings[param].optimal
            local tolerance = optimalSettings[param].tolerance
            local deviation = math.abs(value - optimal)
            
            if deviation > tolerance then
                -- Поза межами толерантності
                local excess = deviation - tolerance
                local penalty = (excess / 10)^2 * 5
                totalPenalty = totalPenalty + penalty
                
                table.insert(warnings, {
                    param = param,
                    current = value,
                    optimal = optimal,
                    deviation = deviation,
                    penalty = penalty,
                })
            end
        end
    end
    
    return math.min(totalPenalty, 50), warnings
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
function CombineMemory:updateStatistics(harvestedLiters, cropLoss)
    if self.currentProfile and self.savedProfiles[self.currentProfile] then
        local profile = self.savedProfiles[self.currentProfile]
        
        -- Конвертуємо літри в тонни (приблизно, залежить від культури)
        local tons = harvestedLiters / 1000 * 0.75  -- Приблизна густина
        
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
