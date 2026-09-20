-- EN: Global settings container for the Realistic Harvest Manager mod.
--     Stores difficulty levels, feature toggles, HUD visibility and position,
--     and the unit system preference. RHMSettings are split into server-side (admin only)
--     and client-side (per-player) categories.
-- UA: Глобальний контейнер налаштувань для мода Realistic Harvest Manager.
--     Зберігає рівні складності, перемикачі функцій, видимість та позицію HUD,
--     і систему одиниць вимірювання. Налаштування поділяються на серверні (тільки для адміна)
--     та клієнтські (для кожного гравця окремо).
RHMSettings = {}
local Settings_mt = Class(RHMSettings)

-- EN: Difficulty level constants used for both motor and crop loss settings.
-- UA: Константи рівнів складності, які використовуються як для двигуна, так і для втрат врожаю.
RHMSettings.DIFFICULTY_ARCADE = 1
RHMSettings.DIFFICULTY_NORMAL = 2
RHMSettings.DIFFICULTY_REALISTIC = 3

-- EN: AI helper combine calibration behavior options.
-- UA: Опції поведінки калібрування комбайна помічниками.
RHMSettings.AI_TUNING_KEEP_PLAYER = 1   -- EN: Keep player settings / UA: Зберігати налаштування гравця
RHMSettings.AI_TUNING_ALWAYS_AUTO = 2   -- EN: Always auto-tune / UA: Завжди авто-підлаштовувати
RHMSettings.AI_TUNING_DISABLED = 3      -- EN: Disabled / UA: Вимкнено

-- EN: Power boost values applied to the engine throughput calculation per difficulty level.
--     Higher boost = combine can harvest faster before triggering speed limits.
-- UA: Значення збільшення потужності, що застосовуються до розрахунку пропускної здатності двигуна.
--     Більший буст = комбайн може збирати швидше до досягнення обмежень швидкості.
RHMSettings.POWER_BOOST_ARCADE = 100     -- EN: 100% boost (2x throughput) / UA: 100% буст (2x пропускна здатність)
RHMSettings.POWER_BOOST_NORMAL = 35      -- EN: 35% boost (calibrated gameplay sweet spot) / UA: 35% буст (відкалібрована комфортна гра)
RHMSettings.POWER_BOOST_REALISTIC = 0   -- EN: 0% boost (true-to-life physics) / UA: 0% буст (реалістична фізика)

-- EN: Unit system constants for speed, productivity, area, and yield display.
-- UA: Константи системи одиниць для відображення швидкості, продуктивності, площі та врожайності.
RHMSettings.UNIT_METRIC = 1     -- EN: km/h, t/h, ha / UA: км/год, т/год, га
RHMSettings.UNIT_IMPERIAL = 2   -- EN: mph, ton/h, acres / UA: миль/год, тон/год, акри
RHMSettings.UNIT_BUSHELS = 3    -- EN: mph, bu/h, acres / UA: миль/год, бушелі/год, акри

-- EN: Alarm buzzer mode constants.
-- UA: Константи режиму кабінного зумера перевантаження.
RHMSettings.ALARM_MODE_SMART = 1       -- EN: Smart 3-beep alert + pause / UA: Розумний сигнал (3 імпульси + пауза)
RHMSettings.ALARM_MODE_CONTINUOUS = 2  -- EN: Continuous beeping under overload / UA: Безперервний сигнал при перевантаженні
RHMSettings.ALARM_MODE_OFF = 3         -- EN: Disabled / UA: Вимкнено

-- EN: Creates and initializes a new RHMSettings instance with default values.
-- UA: Створює та ініціалізує новий екземпляр RHMSettings зі значеннями за замовчуванням.
function RHMSettings.new(manager)
    local self = setmetatable({}, Settings_mt)
    self.manager = manager

    -- EN: Split difficulty system: loss difficulty and motor difficulty are independent.
    -- UA: Система роздільної складності: складність втрат та двигуна є незалежними.
    self.difficultyLoss = RHMSettings.DIFFICULTY_NORMAL
    self.difficultyMotor = RHMSettings.DIFFICULTY_NORMAL
    self.aiHelperTuning = RHMSettings.AI_TUNING_KEEP_PLAYER

    -- EN: Feature toggle flags (server-side, global for all players).
    -- UA: Прапорці перемикання функцій (серверні, глобальні для всіх гравців).
    self.enableSpeedLimit = true
    self.enableCropLoss = true
    self.enableWearLoss = true
    self.enableMoisture = true
    self.enableIndependentLaunch = true -- EN: Separate header start enabled by default / UA: Окремий запуск жатки увімкнено за замовчуванням
    self.alarmMode = RHMSettings.ALARM_MODE_SMART -- EN: Alarm mode (1=Smart, 2=Continuous, 3=Off) / UA: Режим зумера
    self.enableAlarmSound = true        -- EN: Cabin overload buzzer alarm / UA: Кабінний зумер перевантаження
    self.soundVolume = 1.0              -- EN: Sound volume scale (0.0 to 1.0, 0% to 100%) / UA: Рівень гучності звуків (0.0 до 1.0, 0% до 100%)
    self.enableTutorials = true         -- EN: First-time onboarding tutorial hints / UA: Навчальні підказки для новачків

    -- EN: HUD visibility toggles (client-side, per-player).
    -- UA: Перемикачі видимості HUD (клієнтські, для кожного гравця).
    self.showHUD = true
    self.showLoad = true
    self.showProductivity = true
    self.showCropLoss = true
    self.showSpeed = true
    self.showMoisture = true

    -- EN: HUD position (client-side). nil = automatic positioning.
    -- UA: Позиція HUD (клієнтська). nil = автоматичне позиціонування.
    self.hudPosX = nil
    self.hudPosY = nil

    -- EN: Display unit system preference (client-side).
    -- UA: Перевага системи одиниць відображення (клієнтська).
    self.unitSystem = RHMSettings.UNIT_METRIC

    Logging.info("RHM: RHMSettings initialized (Split Difficulty)")

    return self
end

-- EN: Returns the power boost percentage based on the current motor difficulty level.
--     Used by RHM_LoadCalculator to scale the maximum engine throughput.
-- UA: Повертає відсоток збільшення потужності залежно від поточного рівня складності двигуна.
--     Використовується RHM_LoadCalculator для масштабування максимальної пропускної здатності двигуна.
function RHMSettings:getPowerBoost()
    if self.difficultyMotor == RHMSettings.DIFFICULTY_ARCADE then
        return RHMSettings.POWER_BOOST_ARCADE
    elseif self.difficultyMotor == RHMSettings.DIFFICULTY_REALISTIC then
        return RHMSettings.POWER_BOOST_REALISTIC
    else
        return RHMSettings.POWER_BOOST_NORMAL
    end
end

-- EN: Returns the crop loss multiplier based on the current loss difficulty level.
--     Applied to the calculated crop loss percentage in RHM_LoadCalculator.
-- UA: Повертає множник втрат врожаю залежно від поточного рівня складності втрат.
--     Застосовується до розрахованого відсотка втрат в RHM_LoadCalculator.
function RHMSettings:getLossMultiplier()
    if self.difficultyLoss == RHMSettings.DIFFICULTY_ARCADE then
        return 0.0 -- EN: Zero losses in Arcade mode / UA: Нульові втрати в режимі Аркада
    elseif self.difficultyLoss == RHMSettings.DIFFICULTY_REALISTIC then
        return 2.0 -- EN: Doubled losses for realism / UA: Подвоєні втрати для реалізму
    else
        return 1.0 -- EN: Normal losses / UA: Нормальні втрати
    end
end

-- EN: Returns the currently active unit system setting.
-- UA: Повертає поточно активну систему одиниць вимірювання.
function RHMSettings:getUnitSystem()
    return self.unitSystem or RHMSettings.UNIT_METRIC
end

-- EN: Sets the loss difficulty level. Must be in range [ARCADE, REALISTIC].
-- UA: Встановлює рівень складності втрат. Має бути в діапазоні [ARCADE, REALISTIC].
function RHMSettings:setDifficultyLoss(difficulty)
    if difficulty >= RHMSettings.DIFFICULTY_ARCADE and difficulty <= RHMSettings.DIFFICULTY_REALISTIC then
        self.difficultyLoss = difficulty
        Logging.info("RHM: Loss Difficulty changed to: %d", self.difficultyLoss)
    end
end

-- EN: Sets the motor difficulty level. Must be in range [ARCADE, REALISTIC].
-- UA: Встановлює рівень складності двигуна. Має бути в діапазоні [ARCADE, REALISTIC].
function RHMSettings:setDifficultyMotor(difficulty)
    if difficulty >= RHMSettings.DIFFICULTY_ARCADE and difficulty <= RHMSettings.DIFFICULTY_REALISTIC then
        self.difficultyMotor = difficulty
        Logging.info("RHM: Motor Difficulty changed to: %d", self.difficultyMotor)
    end
end



-- EN: Returns a human-readable string showing the current difficulty settings (for console output).
-- UA: Повертає зрозумілий рядок з поточними налаштуваннями складності (для виводу в консоль).
function RHMSettings:getDifficultyName()
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
function RHMSettings:isAdmin()
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
function RHMSettings:canChangeServerSettings()
    return self:isAdmin()
end

-- EN: Loads settings from XML files via the RHMSettingsManager. Validates types after loading.
-- UA: Завантажує налаштування з XML-файлів через RHMSettingsManager. Перевіряє типи після завантаження.
function RHMSettings:load()
    self.manager:loadSettings(self)

    -- EN: Ensure numeric types are valid after XML load (safeguard against corrupted saves).
    -- UA: Гарантуємо, що числові типи дійсні після завантаження XML (захист від пошкоджених збережень).
    if type(self.difficultyLoss) ~= "number" then self.difficultyLoss = RHMSettings.DIFFICULTY_NORMAL end
    if type(self.difficultyMotor) ~= "number" then self.difficultyMotor = RHMSettings.DIFFICULTY_NORMAL end
end

-- EN: Saves settings to XML files via the RHMSettingsManager.
--     In multiplayer, if the caller is admin, broadcasts server settings to all clients.
-- UA: Зберігає налаштування у XML-файли через RHMSettingsManager.
--     В мультиплеєрі, якщо викликач є адміном, транслює серверні налаштування всім клієнтам.
function RHMSettings:save()
    self.manager:saveSettings(self)
end

function RHMSettings:saveAndSync()
    self:save()
    if g_currentMission.missionDynamicInfo.isMultiplayer and
       self:isAdmin() and
       RHM_SettingsSync then
        RHM_SettingsSync:sendToClients(self)
    end
end

-- EN: Resets all settings to their factory default values and saves immediately.
-- UA: Скидає всі налаштування до заводських значень за замовчуванням і негайно зберігає.
function RHMSettings:resetToDefaults()
    self.difficultyLoss = RHMSettings.DIFFICULTY_NORMAL
    self.difficultyMotor = RHMSettings.DIFFICULTY_NORMAL
    self.aiHelperTuning = RHMSettings.AI_TUNING_KEEP_PLAYER
    self.enableSpeedLimit = true
    self.enableCropLoss = true
    self.enableWearLoss = true
    self.enableMoisture = true
    self.showHUD = true
    self.showLoad = true
    self.showProductivity = true
    self.showCropLoss = true
    self.showSpeed = true
    self.showMoisture = true
    self.enableIndependentLaunch = true
    self.enableTutorials = true
    self.alarmMode = RHMSettings.ALARM_MODE_SMART
    self.enableAlarmSound = true
    self.soundVolume = 1.0
    self.hudPosX = nil -- EN: Reset to automatic HUD positioning / UA: Скидаємо на автоматичну позицію HUD
    self.hudPosY = nil

    self:saveAndSync()

    rhm_log("RHM [RHMSettings]: RHM: RHMSettings reset to defaults")
end

---EN: Gets whether wear-based crop loss is enabled
---UA: Повертає чи увімкнено втрати від зносу техніки
function RHMSettings:getEnableWearLoss()
    return self.enableWearLoss ~= false
end

---EN: Sets whether wear-based crop loss is enabled
---UA: Встановлює чи увімкнено втрати від зносу техніки
function RHMSettings:setEnableWearLoss(enabled)
    self.enableWearLoss = enabled
    if self.save then
        self:save()
    end
end

---EN: Gets whether tutorial hints are enabled
---UA: Повертає чи увімкнено навчальні підказки
function RHMSettings:getEnableTutorials()
    return self.enableTutorials
end

---EN: Sets whether tutorial hints are enabled
---UA: Встановлює чи увімкнено навчальні підказки
function RHMSettings:setEnableTutorials(enabled)
    self.enableTutorials = enabled
    if self.save then
        self:save()
    end
end


