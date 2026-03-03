---@class Settings
-- Система налаштувань для Realistic Harvest Manager
Settings = {}
local Settings_mt = Class(Settings)

-- Константи рівнів складності
Settings.DIFFICULTY_ARCADE = 1
Settings.DIFFICULTY_NORMAL = 2
Settings.DIFFICULTY_REALISTIC = 3

-- Power boost values (Modified per user request)
Settings.POWER_BOOST_ARCADE = 100     -- 100% boost (2x speed)
Settings.POWER_BOOST_NORMAL = 20      -- 20% boost
Settings.POWER_BOOST_REALISTIC = 0    -- 0% boost (True Realism)

-- Unit system constants
Settings.UNIT_METRIC = 1     -- km/h, t/h, ha
Settings.UNIT_IMPERIAL = 2   -- mph, ton/h, acres
Settings.UNIT_BUSHELS = 3    -- mph, bu/h, acres

function Settings.new(manager)
    local self = setmetatable({}, Settings_mt)
    self.manager = manager
    
    -- Difficulty settings (SPLIT)
    self.difficultyLoss = Settings.DIFFICULTY_NORMAL    -- Втрати
    self.difficultyMotor = Settings.DIFFICULTY_NORMAL   -- Потужність
    
    -- Feature toggles
    self.enableSpeedLimit = true
    self.enableCropLoss = true -- ENABLED BY DEFAULT NOW
    self.showHUD = true
    self.showYield = true
    self.showSpeedometer = true -- Shows Current / Recommended
    self.enableIndependentLaunch = true -- New: Separate Header Start (enabled by default)
    
    -- HUD Additional Toggles (Explicit defaults)
    self.showLoad = true
    self.showProductivity = true
    self.showCropLoss = true
    self.showSpeed = true -- Used in HUD instead of showSpeedometer sometimes (unified below)
    self.showLoadWarnings = true  -- New: toggle load warnings
    

    -- HUD settings
    self.hudOffsetX = 0
    self.hudOffsetY = 350
    self.hudPosX = nil  -- Позиція HUD по X (nil = авто)
    self.hudPosY = nil  -- Позиція HUD по Y (nil = авто)
    
    -- Unit system
    self.unitSystem = Settings.UNIT_METRIC
    
    Logging.info("RHM: Settings initialized (Split Difficulty)")
    
    return self
end

---Отримує поточний power boost залежно від налаштувань двигуна
---@return number Power boost (0-100)
function Settings:getPowerBoost()
    if self.difficultyMotor == Settings.DIFFICULTY_ARCADE then
        return Settings.POWER_BOOST_ARCADE
    elseif self.difficultyMotor == Settings.DIFFICULTY_REALISTIC then
        return Settings.POWER_BOOST_REALISTIC
    else
        return Settings.POWER_BOOST_NORMAL
    end
end

---Отримує множник втрат залежно від налаштувань втрат
---@return number Loss multiplier
function Settings:getLossMultiplier()
    if self.difficultyLoss == Settings.DIFFICULTY_ARCADE then
        return 0.5 -- Менші втрати
    elseif self.difficultyLoss == Settings.DIFFICULTY_REALISTIC then
        return 2.0 -- Більші втрати
    else
        return 1.0 -- Нормальні втрати
    end
end

---Отримує поточну систему одиниць вимірювання
---@return number Unit system (1=metric, 2=imperial, 3=bushels)
function Settings:getUnitSystem()
    return self.unitSystem or Settings.UNIT_METRIC
end

---Встановлює рівень складності втрат
function Settings:setDifficultyLoss(difficulty)
    if difficulty >= Settings.DIFFICULTY_ARCADE and difficulty <= Settings.DIFFICULTY_REALISTIC then
        self.difficultyLoss = difficulty
        Logging.info("RHM: Loss Difficulty changed to: %d", self.difficultyLoss)
    end
end

---Встановлює рівень складності двигуна
function Settings:setDifficultyMotor(difficulty)
    if difficulty >= Settings.DIFFICULTY_ARCADE and difficulty <= Settings.DIFFICULTY_REALISTIC then
        self.difficultyMotor = difficulty
        Logging.info("RHM: Motor Difficulty changed to: %d", self.difficultyMotor)
    end
end

---Застаріла функція (для сумісності)
---@param difficulty number Рівень складності (1-3)
function Settings:setDifficulty(difficulty)
    self:setDifficultyLoss(difficulty)
    self:setDifficultyMotor(difficulty)
end

---Отримує назву поточного рівня складності (Loss)
---@return string Назва рівня
function Settings:getDifficultyName()
    -- Return Combo string for console output
    local loss = "Normal"
    local motor = "Normal"
    
    if self.difficultyLoss == 1 then loss = "Arcade" elseif self.difficultyLoss == 3 then loss = "Real" end
    if self.difficultyMotor == 1 then motor = "Arcade" elseif self.difficultyMotor == 3 then motor = "Real" end
    
    return string.format("Loss:%s / Motor:%s", loss, motor)
end

---Перевіряє чи поточний гравець - адміністратор
---@return boolean True якщо адмін
function Settings:isAdmin()
    -- В одиночній грі завжди адмін
    if not g_currentMission.missionDynamicInfo.isMultiplayer then
        return true
    end
    
    -- В мультиплеєрі перевіряємо чи це сервер або master user
    if g_currentMission:getIsServer() then
        return true
    end
    
    -- Перевіряємо чи гравець має права адміністратора
    if g_currentMission.isMasterUser then
        return true
    end
    
    -- Note: userManager:getIsUserAdmin() не існує в FS25
    -- Для dedicated server тільки master user має права
    
    return false
end

---Перевіряє чи можна змінювати server-side налаштування
---@return boolean True якщо можна змінювати
function Settings:canChangeServerSettings()
    return self:isAdmin()
end

---Завантажує налаштування
function Settings:load()
    -- Legacy migration: if 'difficulty' exists in XML but not split ones, use it
    -- (This logic will be in SettingsManager usually, but we set defaults here)
    
    self.manager:loadSettings(self)
    
    -- Validation
    if type(self.difficultyLoss) ~= "number" then self.difficultyLoss = Settings.DIFFICULTY_NORMAL end
    if type(self.difficultyMotor) ~= "number" then self.difficultyMotor = Settings.DIFFICULTY_NORMAL end
end

---Зберігає налаштування
function Settings:save()
    self.manager:saveSettings(self)
    
    -- Broadcast server settings to clients if multiplayer and admin
    if g_currentMission.missionDynamicInfo.isMultiplayer and 
       self:isAdmin() and 
       SettingsSync then
        SettingsSync:sendToClients(self)
    end

end

---Скидання налаштувань до значень за замовчуванням
function Settings:resetToDefaults()
    self.difficultyLoss = Settings.DIFFICULTY_NORMAL
    self.difficultyMotor = Settings.DIFFICULTY_NORMAL
    self.enableSpeedLimit = true
    self.enableCropLoss = true
    self.showHUD = true
    self.showYield = true
    self.showLoad = true          -- Reset default
    self.showProductivity = true  -- Reset default
    self.showCropLoss = true      -- Reset default
    self.showSpeed = true         -- Reset default
    self.showSpeedometer = true
    self.showLoadWarnings = true   -- Reset default
    self.enableIndependentLaunch = true -- Default: enabled
    self.hudOffsetX = 0
    self.hudOffsetY = 350
    self.hudPosX = nil -- Reset to auto
    self.hudPosY = nil -- Reset to auto
    
    -- Зберігаємо
    self:save()
    
    print("RHM: Settings reset to defaults")
end
