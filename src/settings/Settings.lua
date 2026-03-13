-- EN: Global settings container for the Realistic Harvest Manager mod.
--     Stores difficulty levels, feature toggles, HUD visibility and position,
--     and the unit system preference. Settings are split into server-side (admin only)
--     and client-side (per-player) categories.
-- UA: Глобальний контейнер налаштувань для мода Realistic Harvest Manager.
--     Зберігає рівні складності, перемикачі функцій, видимість та позицію HUD,
--     і систему одиниць вимірювання. Налаштування поділяються на серверні (тільки для адміна)
--     та клієнтські (для кожного гравця окремо).
Settings = {}
local Settings_mt = Class(Settings)

-- EN: Difficulty level constants used for both motor and crop loss settings.
-- UA: Константи рівнів складності, які використовуються як для двигуна, так і для втрат врожаю.
Settings.DIFFICULTY_ARCADE = 1
Settings.DIFFICULTY_NORMAL = 2
Settings.DIFFICULTY_REALISTIC = 3

-- EN: Power boost values applied to the engine throughput calculation per difficulty level.
--     Higher boost = combine can harvest faster before triggering speed limits.
-- UA: Значення збільшення потужності, що застосовуються до розрахунку пропускної здатності двигуна.
--     Більший буст = комбайн може збирати швидше до досягнення обмежень швидкості.
Settings.POWER_BOOST_ARCADE = 100     -- EN: 100% boost (2x throughput) / UA: 100% буст (2x пропускна здатність)
Settings.POWER_BOOST_NORMAL = 20      -- EN: 20% boost (slightly forgiving) / UA: 20% буст (трохи прощаючий)
Settings.POWER_BOOST_REALISTIC = 0   -- EN: 0% boost (true-to-life physics) / UA: 0% буст (реалістична фізика)

-- EN: Unit system constants for speed, productivity, area, and yield display.
-- UA: Константи системи одиниць для відображення швидкості, продуктивності, площі та врожайності.
Settings.UNIT_METRIC = 1     -- EN: km/h, t/h, ha / UA: км/год, т/год, га
Settings.UNIT_IMPERIAL = 2   -- EN: mph, ton/h, acres / UA: миль/год, тон/год, акри
Settings.UNIT_BUSHELS = 3    -- EN: mph, bu/h, acres / UA: миль/год, бушелі/год, акри

-- EN: Creates and initializes a new Settings instance with default values.
-- UA: Створює та ініціалізує новий екземпляр Settings зі значеннями за замовчуванням.
function Settings.new(manager)
    local self = setmetatable({}, Settings_mt)
    self.manager = manager

    -- EN: Split difficulty system: loss difficulty and motor difficulty are independent.
    -- UA: Система роздільної складності: складність втрат та двигуна є незалежними.
    self.difficultyLoss = Settings.DIFFICULTY_NORMAL
    self.difficultyMotor = Settings.DIFFICULTY_NORMAL

    -- EN: Feature toggle flags (server-side, global for all players).
    -- UA: Прапорці перемикання функцій (серверні, глобальні для всіх гравців).
    self.enableSpeedLimit = true
    self.enableCropLoss = true
    self.showHUD = true
    self.showYield = true
    self.showSpeedometer = true
    self.enableIndependentLaunch = true -- EN: Separate header start enabled by default / UA: Окремий запуск жатки увімкнено за замовчуванням
    
    self.targetEngineLoad = 0.95 -- EN: Target load for Cruise Control (70%-110%) / UA: Цільове навантаження круїз-контролю

    -- EN: HUD visibility toggles (client-side, per-player).
    -- UA: Перемикачі видимості HUD (клієнтські, для кожного гравця).
    self.showLoad = true
    self.showProductivity = true
    self.showCropLoss = true
    self.showSpeed = true
    self.showLoadWarnings = true

    -- EN: HUD position (client-side). nil = automatic positioning.
    -- UA: Позиція HUD (клієнтська). nil = автоматичне позиціонування.
    self.hudOffsetX = 0
    self.hudOffsetY = 350
    self.hudPosX = nil
    self.hudPosY = nil

    -- EN: Display unit system preference (client-side).
    -- UA: Перевага системи одиниць відображення (клієнтська).
    self.unitSystem = Settings.UNIT_METRIC

    Logging.info("RHM: Settings initialized (Split Difficulty)")

    return self
end

-- EN: Returns the power boost percentage based on the current motor difficulty level.
--     Used by LoadCalculator to scale the maximum engine throughput.
-- UA: Повертає відсоток збільшення потужності залежно від поточного рівня складності двигуна.
--     Використовується LoadCalculator для масштабування максимальної пропускної здатності двигуна.
function Settings:getPowerBoost()
    if self.difficultyMotor == Settings.DIFFICULTY_ARCADE then
        return Settings.POWER_BOOST_ARCADE
    elseif self.difficultyMotor == Settings.DIFFICULTY_REALISTIC then
        return Settings.POWER_BOOST_REALISTIC
    else
        return Settings.POWER_BOOST_NORMAL
    end
end

-- EN: Returns the crop loss multiplier based on the current loss difficulty level.
--     Applied to the calculated crop loss percentage in LoadCalculator.
-- UA: Повертає множник втрат врожаю залежно від поточного рівня складності втрат.
--     Застосовується до розрахованого відсотка втрат в LoadCalculator.
function Settings:getLossMultiplier()
    if self.difficultyLoss == Settings.DIFFICULTY_ARCADE then
        return 0.5 -- EN: Reduced losses for casual play / UA: Зменшені втрати для казуальної гри
    elseif self.difficultyLoss == Settings.DIFFICULTY_REALISTIC then
        return 2.0 -- EN: Doubled losses for realism / UA: Подвоєні втрати для реалізму
    else
        return 1.0 -- EN: Normal losses / UA: Нормальні втрати
    end
end

-- EN: Returns the currently active unit system setting.
-- UA: Повертає поточно активну систему одиниць вимірювання.
function Settings:getUnitSystem()
    return self.unitSystem or Settings.UNIT_METRIC
end

-- EN: Sets the loss difficulty level. Must be in range [ARCADE, REALISTIC].
-- UA: Встановлює рівень складності втрат. Має бути в діапазоні [ARCADE, REALISTIC].
function Settings:setDifficultyLoss(difficulty)
    if difficulty >= Settings.DIFFICULTY_ARCADE and difficulty <= Settings.DIFFICULTY_REALISTIC then
        self.difficultyLoss = difficulty
        Logging.info("RHM: Loss Difficulty changed to: %d", self.difficultyLoss)
    end
end

-- EN: Sets the motor difficulty level. Must be in range [ARCADE, REALISTIC].
-- UA: Встановлює рівень складності двигуна. Має бути в діапазоні [ARCADE, REALISTIC].
function Settings:setDifficultyMotor(difficulty)
    if difficulty >= Settings.DIFFICULTY_ARCADE and difficulty <= Settings.DIFFICULTY_REALISTIC then
        self.difficultyMotor = difficulty
        Logging.info("RHM: Motor Difficulty changed to: %d", self.difficultyMotor)
    end
end

-- EN: Legacy method kept for backward compatibility. Sets both loss and motor difficulty.
-- UA: Застарілий метод для зворотної сумісності. Встановлює одночасно складність втрат і двигуна.
function Settings:setDifficulty(difficulty)
    self:setDifficultyLoss(difficulty)
    self:setDifficultyMotor(difficulty)
end

-- EN: Returns a human-readable string showing the current difficulty settings (for console output).
-- UA: Повертає зрозумілий рядок з поточними налаштуваннями складності (для виводу в консоль).
function Settings:getDifficultyName()
    local loss = "Normal"
    local motor = "Normal"

    if self.difficultyLoss == 1 then loss = "Arcade" elseif self.difficultyLoss == 3 then loss = "Real" end
    if self.difficultyMotor == 1 then motor = "Arcade" elseif self.difficultyMotor == 3 then motor = "Real" end

    return string.format("Loss:%s / Motor:%s", loss, motor)
end

-- EN: Returns true if the current player is an administrator (server or master user).
--     In single player, always returns true.
-- UA: Повертає true, якщо поточний гравець є адміністратором (сервер або майстер-користувач).
--     В однокористувацькій грі завжди повертає true.
function Settings:isAdmin()
    if not g_currentMission.missionDynamicInfo.isMultiplayer then
        return true
    end

    if g_currentMission:getIsServer() then
        return true
    end

    if g_currentMission.isMasterUser then
        return true
    end

    return false
end

-- EN: Returns true if the current player has permission to change server-side settings.
-- UA: Повертає true, якщо поточний гравець має дозвіл на зміну серверних налаштувань.
function Settings:canChangeServerSettings()
    return self:isAdmin()
end

-- EN: Loads settings from XML files via the SettingsManager. Validates types after loading.
-- UA: Завантажує налаштування з XML-файлів через SettingsManager. Перевіряє типи після завантаження.
function Settings:load()
    self.manager:loadSettings(self)

    -- EN: Ensure numeric types are valid after XML load (safeguard against corrupted saves).
    -- UA: Гарантуємо, що числові типи дійсні після завантаження XML (захист від пошкоджених збережень).
    if type(self.difficultyLoss) ~= "number" then self.difficultyLoss = Settings.DIFFICULTY_NORMAL end
    if type(self.difficultyMotor) ~= "number" then self.difficultyMotor = Settings.DIFFICULTY_NORMAL end
end

-- EN: Saves settings to XML files via the SettingsManager.
--     In multiplayer, if the caller is admin, broadcasts server settings to all clients.
-- UA: Зберігає налаштування у XML-файли через SettingsManager.
--     В мультиплеєрі, якщо викликач є адміном, транслює серверні налаштування всім клієнтам.
function Settings:save()
    self.manager:saveSettings(self)
end

function Settings:saveAndSync()
    self:save()
    if g_currentMission.missionDynamicInfo.isMultiplayer and
       self:isAdmin() and
       SettingsSync then
        SettingsSync:sendToClients(self)
    end
end

-- EN: Resets all settings to their factory default values and saves immediately.
-- UA: Скидає всі налаштування до заводських значень за замовчуванням і негайно зберігає.
function Settings:resetToDefaults()
    self.difficultyLoss = Settings.DIFFICULTY_NORMAL
    self.difficultyMotor = Settings.DIFFICULTY_NORMAL
    self.enableSpeedLimit = true
    self.enableCropLoss = true
    self.showHUD = true
    self.showYield = true
    self.showLoad = true
    self.showProductivity = true
    self.showCropLoss = true
    self.showSpeed = true
    self.showSpeedometer = true
    self.showLoadWarnings = true
    self.enableIndependentLaunch = true
    self.targetEngineLoad = 0.95
    self.hudOffsetX = 0
    self.hudOffsetY = 350
    self.hudPosX = nil -- EN: Reset to automatic HUD positioning / UA: Скидаємо на автоматичну позицію HUD
    self.hudPosY = nil

    self:saveAndSync()

    print("RHM: Settings reset to defaults")
end
