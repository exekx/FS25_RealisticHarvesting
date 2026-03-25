-- EN: Manages per-combine settings memory including current crop detection, operating mode (AUTO/MANUAL),
--     and per-parameter settings (fan, rotor, sieves, feeder). Interfaces with RHM_ProfileManager for
--     global persistent profiles, and sends network events when settings change in multiplayer.
-- UA: Керує пам'яттю налаштувань для кожного комбайна: detectування поточної культури,
--     режим роботи (AUTO/MANUAL), і налаштування параметрів (вентилятор, ротор, решета, подача).
--     Взаємодіє з RHM_ProfileManager для глобальних збережених профілів, і надсилає мережеві події
--     при зміні налаштувань у мультиплеєрі.
RHM_CombineMemory = {}
local CombineMemory_mt = Class(RHM_CombineMemory)

-- EN: Creates a new RHM_CombineMemory instance tied to a specific combine vehicle.
--     Initializes all parameters to 50% and sets AUTO mode as default.
-- UA: Створює новий екземпляр RHM_CombineMemory, прив'язаний до конкретного комбайна.
--     Ініціалізує всі параметри до 50% та встановлює AUTO як режим за замовчуванням.
function RHM_CombineMemory.new(combine, machineType)
    local self = setmetatable({}, CombineMemory_mt)

    self.combine = combine
    self.machineType = machineType or "grain"

    self.currentProfile = nil -- EN: Name of the currently active profile / UA: Назва поточного активного профілю
    self.currentCrop = nil    -- EN: Currently detected crop name / UA: Поточна визначена культура

    -- EN: Dynamically initialize only the parameters for this machine type (not all 5 for every type).
    -- UA: Динамічно ініціалізуємо тільки параметри для цього типу машини (не всі 5 для кожного типу).
    self.currentSettings = {}
    local activeParams = RHM_CombineSettingsDatabase:getParamsForMachineType(self.machineType)
    for _, paramName in ipairs(activeParams) do
        self.currentSettings[paramName] = 50
    end
    self.currentSettings["targetEngineLoad"] = 95

    self.currentYieldCalibration = 1.0

    self.mode = "AUTO"            -- EN: Starts in AUTO mode by default / UA: За замовчуванням починає в AUTO режимі
    self.autoSwitchEnabled = true -- EN: Auto-applies optimal settings on crop change / UA: Автоматично застосовує оптимальні при зміні культури
    self.showWarnings = true      -- EN: Show warnings for incorrect settings / UA: Показувати попередження при неправильних налаштуваннях

    return self
end

-- EN: Saves the current settings as a global profile for the given crop in RHM_ProfileManager.
--     Profiles persist across sessions in the user's modSettings folder.
-- UA: Зберігає поточні налаштування як глобальний профіль для заданої культури в RHM_ProfileManager.
--     Профілі зберігаються між сесіями в папці modSettings користувача.
function RHM_CombineMemory:saveCurrentProfile(cropName)
    local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
    if pm then
        pm:saveProfile(cropName, self.currentSettings)
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: [OK] Profile saved globally: %s", cropName))
        return true
    end
    rhm_log("RHM [RHM_CombineMemory]: RHM: [!] Failed to save global profile: RHM_ProfileManager not found")
    return false
end

-- EN: Applies automatic or default settings for a specified crop.
--     AUTO mode adds a small random deviation around the optimal values (server-only randomness).
--     RESET mode (forceOptimal=false) sets all parameters to neutral 50%.
-- UA: Застосовує автоматичні або стандартні налаштування для заданої культури.
--     AUTO режим додає невелике випадкове відхилення від оптимальних значень (тільки на сервері).
--     Режим RESET (forceOptimal=false) встановлює всі параметри на нейтральні 50%.
function RHM_CombineMemory:autoConfigureForCrop(cropName, forceOptimal)
    if not cropName then
        rhm_log("RHM [RHM_CombineMemory]: RHM: [!] autoConfigureForCrop called with nil cropName, skipping")
        return false
    end

    local optimalSettings = RHM_CombineSettingsDatabase:getSettingsForCrop(cropName)

    if not optimalSettings then
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: [!] No settings found for crop: %s", cropName))
        -- EN: Crop is unknown but we still proceed with defaults.
        -- UA: Культура невідома, але продовжуємо зі значеннями за замовчуванням.
    end

    if forceOptimal and optimalSettings then
        -- EN: AUTO mode: sets exactly the 100% optimal values (Opti-Harvest Level 4 exclusive).
        -- UA: AUTO режим: встановлює рівно 100% оптимальні значення (ексклюзив для пакету Opti-Harvest 4 рівня).
        local activeParams = RHM_CombineSettingsDatabase:getParamsForMachineType(self.machineType)
        for _, pName in ipairs(activeParams) do
            if optimalSettings[pName] then
                self.currentSettings[pName] = optimalSettings[pName].optimal
            else
                self.currentSettings[pName] = 50
            end
        end

        self.mode = "AUTO"
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: [OK] Auto settings applied for: %s (forceOptimal=%s)", cropName, tostring(forceOptimal)))
    else
        -- EN: RESET mode: set all active params to the neutral 50% position.
        -- UA: Режим RESET: встановлюємо всі активні параметри на нейтральну позицію 50%.
        local activeParams = RHM_CombineSettingsDatabase:getParamsForMachineType(self.machineType)
        for _, pName in ipairs(activeParams) do
            self.currentSettings[pName] = 50
        end

        self.mode = "MANUAL"
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: [OK] Default settings (50%%) applied for: %s", cropName))
    end

    -- EN: Reset yield calibration when switching to a new crop without an existing profile.
    -- UA: Скидаємо калібрування врожайності при переключенні на нову культуру без існуючого профілю.
    local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
    if not pm or not pm:getProfile(cropName) then
        self.currentYieldCalibration = 1.0
    end

    self.currentCrop = cropName
    return true
end

-- EN: Sends a network request to the server to apply AUTO settings for the current crop.
--     In singleplayer, processes the event locally.
-- UA: Надсилає мережевий запит на сервер для застосування AUTO налаштувань для поточної культури.
--     В однокористувацькій грі обробляє подію локально.
function RHM_CombineMemory:requestAutoSettings()
    if not self.currentCrop then return end

    if g_client and self.combine then
        local event = RHM_CombineSettingsEvent.new(self.combine, "AUTO_SET", 1)
        if not g_server then
            g_client:getServerConnection():sendEvent(event)
        else
            event:run(nil) -- EN: Singleplayer: process locally / UA: Однокористувацька: обробляємо локально
        end
        rhm_log("RHM [RHM_CombineMemory]: RHM: [Sync] Requested AUTO settings from server")
    end
end

-- EN: Sends a network request to the server to reset all settings to 50%.
-- UA: Надсилає мережевий запит на сервер для скидання всіх налаштувань до 50%.
function RHM_CombineMemory:requestResetSettings()
    if not self.currentCrop then return end

    if g_client and self.combine then
        local event = RHM_CombineSettingsEvent.new(self.combine, "RESET_SET", 1)
        if not g_server then
            g_client:getServerConnection():sendEvent(event)
        else
            event:run(nil)
        end
        rhm_log("RHM [RHM_CombineMemory]: RHM: [Sync] Requested RESET settings from server")
    end
end

-- EN: Loads the global user-saved profile for the current crop from RHM_ProfileManager.
--     If in multiplayer (client), sends a RHM_CombineSettingsEvent with the full profile.
--     Returns false if no profile exists.
-- UA: Завантажує глобально збережений профіль користувача для поточної культури з RHM_ProfileManager.
--     У мультиплеєрі (клієнт) надсилає RHM_CombineSettingsEvent з повним профілем.
--     Повертає false якщо профіль відсутній.
function RHM_CombineMemory:loadUserPreset()
    if not self.currentCrop then return false end

    local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
    if not pm then return false end

    local profile = pm:getProfile(self.currentCrop)
    if profile then
        if g_client and self.combine then
            local event = RHM_CombineSettingsEvent.new(self.combine, "", 0, true, profile)
            if not g_server then
                g_client:getServerConnection():sendEvent(event)
            else
                local conn = g_currentMission and g_currentMission.player and g_currentMission.player.serverConnection or nil
                event:run(conn)
            end
        else
            -- EN: Direct application (single player without g_client). Dynamically apply all active params.
            -- UA: Пряме застосування (однокористувацька гра без g_client). Динамічно застосовуємо всі активні параметри.
            local activeParams = RHM_CombineSettingsDatabase:getParamsForMachineType(self.machineType)
            for _, paramName in ipairs(activeParams) do
                if profile[paramName] ~= nil then
                    self.currentSettings[paramName] = profile[paramName]
                end
            end
            self.currentSettings.targetEngineLoad = profile.targetEngineLoad or 95
            self.mode = "MANUAL"
            self.autoSwitchEnabled = false
        end
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: [OK] Global profile applied for %s", self.currentCrop))
        return true
    else
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: No global user preset found for %s", self.currentCrop))
        return false
    end
end

-- EN: Evaluates all current settings against the crop's optimal database values.
--     Returns separate efficiency (speed) and loss penalties, plus a warnings table.
--     Feeder/Rotor affect efficiency (throughput), Fan/Sieves affect crop loss (separation quality).
-- UA: Оцінює всі поточні налаштування відносно оптимальних значень бази даних для культури.
--     Повертає окремо штрафи за ефективність (швидкість) і втрати врожаю, плюс таблицю попереджень.
--     Подача/Ротор впливають на ефективність (пропускну здатність), Вентилятор/Решета — на втрати (якість очищення).
function RHM_CombineMemory:checkSettingsForCrop(cropName)
    local optimalSettings = RHM_CombineSettingsDatabase:getSettingsForCrop(cropName)

    if not optimalSettings then
        return 0, 0, {}
    end

    local warnings = {}
    local efficiencyScore = 0  -- EN: Impacts throughput/speed / UA: Впливає на пропускну здатність/швидкість
    local lossScore = 0        -- EN: Impacts direct crop loss / UA: Впливає на прямі втрати врожаю
    
    local effParamCount = 0
    local lossParamCount = 0

    for param, value in pairs(self.currentSettings) do
        if optimalSettings[param] then
            local optimal   = optimalSettings[param].optimal
            local tolerance = optimalSettings[param].tolerance
            local deviation = math.abs(value - optimal)

            local score = 0
            if deviation <= tolerance then
                -- EN: GREEN ZONE: linear curve from -0.5 (perfect center) to +0.5 (edge of tolerance).
                -- UA: ЗЕЛЕНА ЗОНА: лінійна крива від -0.5 (ідеальний центр) до +0.5 (межа допуску).
                score = (deviation / tolerance - 0.5) * 1.0
            else
                -- EN: RED ZONE: linear increase from +0.5, capped at 6.0 (extreme maladjustment).
                -- UA: ЧЕРВОНА ЗОНА: лінійне зростання від +0.5, обмежено до 6.0 (крайнє розрегулювання).
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

            -- EN: Route penalty to the appropriate physical effect based on parameter type.
            --     GRAIN: rotor/concave → efficiency (threshing) | fan/upperSieve/lowerSieve → loss (cleaning)
            --     FORAGE: all params → efficiency only (silage choppers have no grain to lose)
            --     ROOT: all params → efficiency only (no fan, no sieve losses)
            -- UA: Направляємо штраф до відповідного фізичного ефекту залежно від параметру.
            local isForage = (self.machineType == "forage")
            local isRoot   = (self.machineType == "root")

            if isForage or isRoot then
                -- EN: All params on forage/root affect only efficiency (no grain to lose)
                efficiencyScore = efficiencyScore + score
                effParamCount = effParamCount + 1
            elseif param == "rotor" or param == "concave" then
                -- EN: GRAIN: rotor/concave control threshing → primarily efficiency
                efficiencyScore = efficiencyScore + score
                effParamCount = effParamCount + 1
            elseif param == "fan" or param == "upperSieve" or param == "lowerSieve" then
                -- EN: GRAIN: fan/sieves control cleaning → primarily crop loss
                lossScore = lossScore + score
                lossParamCount = lossParamCount + 1
            else
                -- EN: Unknown param — split penalty evenly
                efficiencyScore = efficiencyScore + (score * 0.5)
                lossScore = lossScore + (score * 0.5)
                effParamCount = effParamCount + 0.5
                lossParamCount = lossParamCount + 0.5
            end
        end
    end

    -- EN: Normalize scores so that machines with fewer parameters (e.g., forage/root)
    --     can still reach the same max bonus and max penalty as 5-parameter grain combines.
    -- UA: Нормалізуємо бали, щоб машини з меншою кількістю параметрів (напр., форажні/бурякові)
    --     могли досягати тих же максимальних бонусів/штрафів, що й 5-параметрові зернові комбайни.
    if effParamCount > 0 then
        -- Grain combines have 2 efficiency params (feeder, rotor). We scale to 2.
        efficiencyScore = efficiencyScore * (2.0 / effParamCount)
    end
    
    if lossParamCount > 0 then
        -- Grain combines have 3 loss params (fan, upperSieve, lowerSieve). We scale to 3.
        lossScore = lossScore * (3.0 / lossParamCount)
    end

    -- EN: Clamp penalties to reasonable bounds.
    --     Efficiency: max bonus is -1.0%, max penalty is 20%.
    --     Loss: max bonus is -1.5%, max penalty is 20%.
    -- UA: Обмежуємо штрафи до розумних меж.
    --     Ефективність: максимальний бонус -1.0%, максимальний штраф 20%.
    --     Втрати: максимальний бонус -1.5%, максимальний штраф 20%.
    local efficiencyPenalty = math.max(-1.0, math.min(efficiencyScore, 20.0))
    local lossPenalty = math.max(-1.5, math.min(lossScore, 20.0))

    return efficiencyPenalty, lossPenalty, warnings
end

-- EN: Sets a single parameter value (0-100) and switches to MANUAL mode.
-- UA: Встановлює значення одного параметру (0-100) і перемикає в MANUAL режим.
function RHM_CombineMemory:setParameter(paramName, value)
    if self.currentSettings[paramName] ~= nil then
        if paramName == "targetEngineLoad" then
            self.currentSettings[paramName] = math.max(70, math.min(110, value))
            return true
        end
        self.currentSettings[paramName] = math.max(0, math.min(100, value))
        self.mode = "MANUAL" -- EN: Any manual change overrides AUTO mode / UA: Будь-яка ручна зміна скасовує AUTO режим
        return true
    end
    return false
end

-- EN: Switches operating mode to AUTO or MANUAL.
--     AUTO: applies optimal crop settings immediately if a crop is already detected.
--           on a dedicated server without a crop yet, marks pending AUTO and waits.
--     MANUAL: disables auto-configuration.
-- UA: Переключає режим роботи на AUTO або MANUAL.
--     AUTO: застосовує оптимальні налаштування для культури якщо вона вже визначена.
--           на виділеному сервері без культури — позначає очікуючий AUTO і чекає.
--     MANUAL: вимикає автоконфігурацію.
function RHM_CombineMemory:setMode(mode)
    if mode == "AUTO" then
        if self.currentCrop then
            self:autoConfigureForCrop(self.currentCrop, true)
        else
            -- EN: Dedicated server: crop not yet detected. Store mode for later when crop is first harvested.
            -- UA: Виділений сервер: культура ще не визначена. Зберігаємо режим до першого збору врожаю.
            self.mode = "AUTO"
            self.autoSwitchEnabled = true
            rhm_log("RHM [RHM_CombineMemory]: RHM: [AUTO] currentCrop is nil on DS, pending AUTO mode set. Will apply when crop detected.")
        end
    elseif mode == "MANUAL" then
        self.mode = "MANUAL"
    end
end

-- EN: Returns the number of profiles currently available.
--     Returns cached count (not iterated per-call for performance).
-- UA: Повертає кількість поточно доступних профілів.
--     Повертає кешоване значення (не перебирає кожен виклик для продуктивності).
function RHM_CombineMemory:getProfileCount()
    return self.profileCount or 0
end

-- EN: Returns an alphabetically sorted list of all saved profile names.
-- UA: Повертає алфавітно відсортований список всіх збережених назв профілів.
function RHM_CombineMemory:getProfileNames()
    local names = {}
    for profileName, _ in pairs(self.savedProfiles) do
        table.insert(names, profileName)
    end
    table.sort(names)
    return names
end

-- EN: Updates harvesting statistics for the current profile: total harvested and rolling average loss.
--     Uses the crop's actual fill type density from g_fillTypeManager for accurate mass calculation.
-- UA: Оновлює статистику збирання для поточного профілю: загальний збір і ковзаюче середнє втрат.
--     Використовує реальну густину типу врожаю з g_fillTypeManager для точного розрахунку маси.
function RHM_CombineMemory:updateStatistics(harvestedLiters, cropLoss, cropName)
    if self.currentProfile and self.savedProfiles[self.currentProfile] then
        local profile = self.savedProfiles[self.currentProfile]

        -- EN: Get density from fill type manager, fallback to 0.75 kg/L if not available.
        -- UA: Отримуємо густину з менеджера типів врожаю, запасний варіант 0.75 кг/л.
        local density = 0.75
        if cropName and g_fillTypeManager and RHM_CombineSettingsDatabase then
            local cropData = RHM_CombineSettingsDatabase:getCropData(cropName)
            if cropData and cropData.fillType then
                local fillTypeObj = g_fillTypeManager:getFillTypeByIndex(cropData.fillType)
                if fillTypeObj and fillTypeObj.massPerLiter and fillTypeObj.massPerLiter > 0 then
                    density = fillTypeObj.massPerLiter * 1000 -- EN: t/L → kg/L / UA: т/л → кг/л
                end
            end
        end

        local tons = harvestedLiters * density / 1000
        profile.stats.totalHarvested = profile.stats.totalHarvested + tons

        -- EN: Update rolling average loss (5% blend toward new value).
        -- UA: Оновлюємо ковзаюче середнє втрат (5% змішування до нового значення).
        if profile.stats.averageLoss == 0 then
            profile.stats.averageLoss = cropLoss
        else
            profile.stats.averageLoss = profile.stats.averageLoss * 0.95 + cropLoss * 0.05
        end
    end
end

-- EN: Switches to a new crop: saves the current crop's profile, sets the new crop,
--     then loads its profile or applies auto/default settings depending on mode.
-- UA: Переключається на нову культуру: зберігає профіль поточної культури, встановлює нову,
--     а потім завантажує її профіль або застосовує авто/стандартні налаштування залежно від режиму.
function RHM_CombineMemory:switchCrop(newCropName)
    if not newCropName or newCropName == self.currentCrop then
        return
    end

    if self.currentCrop then
        self:saveCurrentProfile(self.currentCrop)
    end

    self.currentCrop = newCropName

    local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
    if pm and pm:getProfile(newCropName) then
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: Switching to crop %s - Loading global profile", newCropName))
        self:loadUserPreset()
    else
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: Switching to crop %s - No profile, applying defaults", newCropName))
        if self.autoSwitchEnabled then
            self:autoConfigureForCrop(newCropName, true)
        else
            self:autoConfigureForCrop(newCropName, false)
        end
    end
end

-- ============================================================================
-- EN: GUI HELPER WRAPPERS — simplify interaction between GUI and memory.
-- UA: ОБГОРТКИ ДЛЯ GUI — спрощують взаємодію між GUI і пам'яттю.
-- ============================================================================

-- EN: Updates a single setting and sends a network event to the server in multiplayer.
--     Automatically switches to MANUAL mode and disables auto-switch.
-- UA: Оновлює одне налаштування і надсилає мережеву подію серверу в мультиплеєрі.
--     Автоматично переключається в MANUAL режим і вимикає автоперемикання.
function RHM_CombineMemory:updateSetting(param, value)
    local success = self:setParameter(param, value)
    if success then
        if param ~= "targetEngineLoad" then
            self.autoSwitchEnabled = false
            self.mode = "MANUAL"
        end

        if g_client and self.combine then
            local event = RHM_CombineSettingsEvent.new(self.combine, param, self.currentSettings[param], false, nil)
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

-- EN: Toggles the auto-switch mode flag. In multiplayer, sends a network event to the server.
--     In singleplayer, applies locally and immediately configures for the current crop if switching to AUTO.
-- UA: Перемикає прапорець режиму автоперемикання. У мультиплеєрі надсилає мережеву подію серверу.
--     В однокористувацькій грі застосовує локально і негайно налаштовує для поточної культури при переключенні в AUTO.
function RHM_CombineMemory:toggleAutoMode()
    if g_client and self.combine and not g_server then
        -- EN: Multiplayer client: send request to server.
        -- UA: Клієнт мультиплеєру: надсилаємо запит на сервер.
        local targetMode = not self.autoSwitchEnabled
        local event = RHM_CombineSettingsEvent.new(self.combine, "AUTO_MODE", targetMode and 1 or 0)
        g_client:getServerConnection():sendEvent(event)
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: [Sync] Sent AUTO mode request to server: %s", targetMode and "ON" or "OFF"))
    else
        -- EN: Singleplayer or server: apply immediately.
        -- UA: Однокористувацька або сервер: застосовуємо негайно.
        self.autoSwitchEnabled = not self.autoSwitchEnabled

        if self.autoSwitchEnabled then
            self.mode = "AUTO"
            if self.currentCrop then
                self:autoConfigureForCrop(self.currentCrop, true)
            end
        else
            self.mode = "MANUAL"
        end
        rhm_log(string.format("RHM [RHM_CombineMemory]: RHM: Auto Switch %s", self.autoSwitchEnabled and "ENABLED" or "DISABLED"))
    end
end

-- EN: Alias for saveCurrentProfile for backward compatibility with GUI code.
-- UA: Псевдонім для saveCurrentProfile для зворотної сумісності з кодом GUI.
function RHM_CombineMemory:saveProfile(cropName)
    return self:saveCurrentProfile(cropName)
end

rhm_log("RHM [RHM_CombineMemory]: [OK] RHM_CombineMemory class loaded")

