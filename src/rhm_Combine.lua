---@class rhm_Combine
rhm_Combine = {}
rhm_Combine.debug = false

---Перевіряє чи машина підходить для цієї спеціалізації
---@param specializations table<string, table>
---@return boolean
function rhm_Combine.prerequisitesPresent(specializations)
    -- DEBUG: Виводимо всі specializations щоб побачити що має Nexat
    print("========================================")
    print("RHM: Checking prerequisites for vehicle")
    print("Available specializations:")
    for specName, specTable in pairs(specializations) do
        if type(specTable) == "table" and specTable.className then
            print("  - " .. specTable.className)
        end
    end
    
    -- Перевіряємо базову specialization Combine
    local hasCombine = SpecializationUtil.hasSpecialization(Combine, specializations)
    print("Has Combine: " .. tostring(hasCombine))
    
    -- Для Nexat: тимчасово спрощуємо перевірку
    -- Повертаємо true якщо просто є Combine
    print("Result: " .. tostring(hasCombine))
    print("========================================")
    
    return hasCombine
end

-- Реєстрація перевизначених функцій (ОБОВ'ЯЗКОВО перед registerEventListeners!)
function rhm_Combine.registerOverwrittenFunctions(vehicleType)
    print("RHM: Registering overwritten functions for rhm_Combine")
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "addCutterArea", rhm_Combine.addCutterArea)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getSpeedLimit", rhm_Combine.getSpeedLimit)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "startThreshing", rhm_Combine.startThreshing)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "stopThreshing", rhm_Combine.stopThreshing)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "verifyCombine", rhm_Combine.verifyCombine)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeTurnedOn", rhm_Combine.getCanBeTurnedOn)
end

---Реєстрація XML шляхів для savegame (КРИТИЧНО для збереження даних!)
---Без цього FS25 не знає які вузли XML записувати/читати для цієї спеціалізації
function rhm_Combine.registerXMLPaths(schema, basePath)
    -- Поточні налаштування комбайну
    local cur = basePath .. ".combineMemory.current"
    schema:register(XMLValueType.STRING, cur .. "#mode",         "Combine settings mode", "AUTO")
    schema:register(XMLValueType.STRING, cur .. "#currentCrop",  "Current crop", "")
    schema:register(XMLValueType.BOOL,   cur .. "#autoSwitch",   "Auto switch enabled", true)
    schema:register(XMLValueType.INT,    cur .. "#fan",          "Fan", 50)
    schema:register(XMLValueType.INT,    cur .. "#upperSieve",   "Upper sieve", 50)
    schema:register(XMLValueType.INT,    cur .. "#lowerSieve",   "Lower sieve", 50)
    schema:register(XMLValueType.INT,    cur .. "#rotor",        "Rotor", 50)
    schema:register(XMLValueType.INT,    cur .. "#feeder",       "Feeder", 50)
end

function rhm_Combine.registerSavegameXMLPaths(schema, basePath)
    rhm_Combine.registerXMLPaths(schema, basePath)
end

function rhm_Combine.registerEventListeners(vehicleType)
    print("RHM: Registering event listeners for rhm_Combine")
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", rhm_Combine)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", rhm_Combine)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", rhm_Combine)
    
    -- SAVEGAME: Збереження та завантаження стану
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", rhm_Combine)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", rhm_Combine)
    
    -- SAVEGAME XML: Enabled
    SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", rhm_Combine)
    SpecializationUtil.registerEventListener(vehicleType, "loadFromXMLFile", rhm_Combine)
    
    -- MULTIPLAYER: Синхронізація даних між сервером і клієнтом
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", rhm_Combine)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", rhm_Combine)
    
    -- INPUT: Реєструємо події введення
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", rhm_Combine)
end

-- Викликається при завантаженні комбайна
function rhm_Combine:onLoad(savegame)
    -- Створюємо spec для нашого моду
    -- Використовуємо пряму назву так як g_currentModName не доступний тут
    local specName = "spec_FS25_RealisticHarvesting.rhm_Combine"
    self.spec_rhm_Combine = self[specName]
    local spec = self.spec_rhm_Combine
    
    if not spec then
        Logging.error("RHM: Failed to initialize spec for combine: %s (specName: %s)", 
            tostring(self:getFullName()), tostring(specName))
        return
    end
    
    if rhm_Combine.debug then
        print(string.format("RHM: onLoad called for %s (has savegame: %s)", 
            tostring(self:getFullName()), tostring(savegame ~= nil)))
    end
    
    -- Створюємо LoadCalculator з modDirectory
    local modDir = g_realisticHarvestManager and g_realisticHarvestManager.modDirectory or g_currentModDirectory
    
    if not LoadCalculator then
        Logging.error("RHM: LoadCalculator class is missing! Check script loading order.")
        return
    end

    spec.loadCalculator = LoadCalculator.new(modDir)
    
    if not spec.loadCalculator then
        Logging.error("RHM: Failed to create LoadCalculator for combine: %s", self:getFullName())
        return
    end
    
    -- Отримуємо базову продуктивність з потужності двигуна
    local basePerf = spec.loadCalculator:getBasePerformanceFromPower(self)
    spec.loadCalculator:setBasePerformance(basePerf)
    
    -- === COMBINE SETTINGS SYSTEM ===
    -- Створюємо систему пам'яті для налаштувань комбайна
    spec.combineMemory = CombineMemory.new(self)
    
    -- Підключаємо memory до LoadCalculator для розрахунку settings loss
    spec.loadCalculator.combineMemory = spec.combineMemory
    
    print("RHM: [OK] Combine Settings System initialized")
    
    -- Ініціалізуємо дані для HUD
    spec.data = {
        speed = 0,
        load = 0,
        cropLoss = 0,
        tonPerHour = 0,
        recommendedSpeed = 0,  -- Буде оновлено в onUpdateTick на сервері та синхронізовано до клієнтів
        overloadLevel = 0      -- 0=норма, 1=HIGH(120%+), 2=CRITICAL(150%+) — синхронізується для показу warning
    }
    
    -- Лічильник для збереження площі з addCutterArea
    spec.lastArea = 0
    spec.lastLiters = 0  -- Літри зібраного врожаю
    
    -- Відстеження поточної жатки для визначення зміни
    spec.currentCutter = nil
    
    -- Прапорець чи активне обмеження швидкості
    spec.isSpeedLimitActive = false
    
    -- MULTIPLAYER: Dirty flag для синхронізації
    spec.dirtyFlag = self:getNextDirtyFlag()
    
    -- INPUT: Таблиця для подій введення
    spec.actionEvents = {}
    
    -- TEST: Прапорець для показу тестового повідомлення
    spec.testMessageShown = false
end

-- Перехоплюємо addCutterArea для отримання площі
-- Hook для addCutterArea щоб перехопити кількість зібраного
-- Argument 2 is actually 'realArea' (actual cut area), not liters!
function rhm_Combine:addCutterArea(superFunc, area, realArea, inputFruitType, outputFillType, strawRatio, strawGroundType, farmId, cutterLoad)
    -- Викликаємо оригінальну функцію СПЕРШУ, щоб отримати реальні дані
    local retLiters, retStrawLiters = superFunc(self, area, realArea, inputFruitType, outputFillType, strawRatio, strawGroundType, farmId, cutterLoad)
    
    local spec = self.spec_rhm_Combine
    if not spec or not spec.loadCalculator then
        return retLiters, retStrawLiters
    end
    
    -- Отримуємо lastMultiplier (для сумісності зі старою логікою)
    local multiplier = 1.0
    
    -- Зберігаємо РЕАЛЬНУ площу (realArea) якщо вона доступна, інакше area
    local areaForYield = realArea or area
    
    -- Зберігаємо площу для LoadCalculator (стара логіка)
    spec.lastArea = (spec.lastArea or 0) + (area * multiplier)
    
    -- Зберігаємо площу для Yield Monitor
    spec.lastRawArea = (spec.lastRawArea or 0) + areaForYield
    spec.lastMultiplier = multiplier
    
    -- Зберігаємо ЛІТРИ (результат жнив)
    if retLiters and retLiters > 0 then
        spec.lastLiters = (spec.lastLiters or 0) + retLiters
    end
    
    -- Зберігаємо тип культури та обробляємо зміну
    if outputFillType and outputFillType ~= FillType.UNKNOWN then
        spec.lastFillType = outputFillType
        
        -- === YIELD CALCULATION REMOVED ===
        -- Reason: Calculating yield per-slice (addCutterArea) is statistically wrong because
        -- it treats small slices (partial overlap) equally to large slices in the moving average buffer.
        -- We now rely on 'onUpdateTick' which aggregates Total Mass / Total Area for the frame,
        -- providing a mathematically correct weighted average.
        
        -- if (retLiters or 0) > 0 and areaForYield > 0.001 then
        --    ...
        -- end

        -- === CROP LOSS CALCULATION ===
        -- Визначаємо назву культури з fillType напряму через name
        local cropName = nil
        
        if g_fillTypeManager then
            local fillTypeObj = g_fillTypeManager:getFillTypeByIndex(outputFillType)
            if fillTypeObj and fillTypeObj.name then
                local fillTypeName = fillTypeObj.name
                
                -- Маппінг: fillType.name -> cropName (використовується в AUTO режимі)
                local fillTypeMapping = {
                    ["WHEAT"] = "WHEAT",
                    ["BARLEY"] = "BARLEY",
                    ["OAT"] = "OAT",
                    ["CANOLA"] = "CANOLA",
                    ["SUNFLOWER"] = "SUNFLOWER",
                    ["MAIZE"] = "CORN",  -- Кукурудза в грі називається MAIZE
                    ["SOYBEAN"] = "SOYBEAN",
                    ["SORGHUM"] = "SORGHUM",
                    ["RICE"] = "RICE",
                    ["RICE_LONG_GRAIN"] = "RICE_LONG_GRAIN",
                }
                
                cropName = fillTypeMapping[fillTypeName]
            end
        end
        
        if cropName then
            -- Оновлюємо поточну культуру в LoadCalculator
            spec.loadCalculator.currentCrop = cropName
            
            -- Перевіряємо чи змінилася культура
            if cropName ~= spec.combineMemory.currentCrop then
                -- DEBOUNCE: чекаємо 2 секунди перед перемикання
                -- Без цього жатка може детектувати різні культури кожен тік і створювати петлю
                local now = g_currentMission.time
                spec._lastCropSwitchTime = spec._lastCropSwitchTime or 0
                
                if (now - spec._lastCropSwitchTime) >= 2000 then
                    spec._lastCropSwitchTime = now
                    spec._pendingCrop = cropName  -- запам’ятовуємо нову культуру
                elseif spec._pendingCrop == cropName then
                    -- Підтверджено другий раз — перемикаємо
                    spec._pendingCrop = nil
                    print(string.format("RHM: [CROP] Detected crop: %s", cropName))
                    rhm_Combine.onCropTypeChanged(self, cropName)
                end
            else
                -- Культура не змінилась — скидаємо pending
                spec._pendingCrop = nil
            end
        end
    else
        -- Немає культури (не збираємо) — скидаємо pending
        spec._pendingCrop = nil
    end
    
    -- DEBUG: Uncomment to see values in console
    -- if (retLiters or 0) > 0 and areaForYield > 0 then
    --    local areaHa = areaForYield / 10000
    --    local yieldL_Ha = retLiters / areaHa
    --    print(string.format("RHM YIELD DEBUG: Liters=%.2f, Area=%.4f m2, Yield=%.0f L/ha", 
    --        retLiters, areaForYield, yieldL_Ha))
    -- end
    
    return retLiters, retStrawLiters
end

---Викликається при зміні типу культури
---@param newCropName string Нова назва культури
function rhm_Combine:onCropTypeChanged(newCropName)
    local spec = self.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return
    end
    
    -- Делегуємо switchCrop — він сам встановить currentCrop, збереже старий профіль
    -- і завантажить новий. НЕ встановлюємо currentCrop тут напряму!
    spec.combineMemory:switchCrop(newCropName)
    
    -- Синхронізуємо зміну культури та налаштувань для клієнтів у мультиплеєрі
    if self.isServer then
        self:raiseDirtyFlags(spec.dirtyFlag)
    end
end

-- Перевизначаємо getSpeedLimit для автоматичного обмеження швидкості
function rhm_Combine:getSpeedLimit(superFunc, onlyIfWorking)
    local spec = self.spec_rhm_Combine
    
    -- Викликаємо оригінальну функцію
    local limit, doCheckSpeedLimit = superFunc(self, onlyIfWorking)
    
    -- Якщо spec не ініціалізований, повертаємо оригінальний ліміт
    if not spec or not spec.loadCalculator then
        return limit, doCheckSpeedLimit
    end
    
    -- Перевіряємо чи комбайн працює
    if not self:getIsTurnedOn() then
        spec.isSpeedLimitActive = false
        return limit, doCheckSpeedLimit
    end
    
    -- CRITICAL FIX: Перевіряємо чи жатка ПРАЦЮЄ (не просто прикріплена)
    -- Якщо жатка піднята або не косить - НЕ обмежуємо швидкість
    local spec_combine = self.spec_combine
    local cutterIsWorking = false
    
    if spec_combine and spec_combine.attachedCutters then
        for cutter, _ in pairs(spec_combine.attachedCutters) do
            if cutter.spec_cutter then
                local spec_cutter = cutter.spec_cutter
                -- Жатка працює якщо: рух вперед, швидкість > 0.5, опущена (або дозволено косити піднятою)
                cutterIsWorking = self.movingDirection == spec_cutter.movingDirection 
                    and self:getLastSpeed() > 0.5 
                    and (spec_cutter.allowCuttingWhileRaised or cutter:getIsLowered(true))
                
                if cutterIsWorking then
                    break -- Знайшли працюючу жатку
                end
            end
        end
    end
    
    -- Якщо жатка НЕ працює - знімаємо обмеження відразу
    if not cutterIsWorking then
        spec.isSpeedLimitActive = false
        return limit, doCheckSpeedLimit
    end
    
    -- Перевіряємо чи увімкнено обмеження швидкості
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        if not g_realisticHarvestManager.settings.enableSpeedLimit then
            spec.isSpeedLimitActive = false
            return limit, doCheckSpeedLimit
        end
        
        -- В Arcade режимі НЕ обмежуємо швидкість (як у ванільній грі)
        if g_realisticHarvestManager.settings.difficultyMotor == 1 then -- DIFFICULTY_ARCADE
            spec.isSpeedLimitActive = false
            return limit, doCheckSpeedLimit
        end
    end
    
    -- Перевіряємо чи змінилася жатка
    if spec_combine and spec_combine.attachedCutters then
        local currentCutter = nil
        for cutter, _ in pairs(spec_combine.attachedCutters) do
            currentCutter = cutter
            break -- Беремо першу жатку
        end
        
        -- Якщо жатка змінилася, скидаємо genuineSpeedLimit
        if currentCutter ~= spec.currentCutter and currentCutter ~= nil then
            spec.currentCutter = currentCutter
            spec.loadCalculator.genuineSpeedLimit = 15 -- Скидаємо до початкового значення
            -- Logging.info("RHM: [getSpeedLimit] Cutter changed, resetting genuineSpeedLimit")
        end
    end
    
    -- Встановлюємо оригінальний ліміт в LoadCalculator ТІЛЬКИ ОДИН РАЗ
    -- Перевіряємо чи genuineSpeedLimit ще не ініціалізований (дорівнює початковому значенню 15)
    -- І перевіряємо що limit - це реальне число (не inf)
    if spec.loadCalculator.genuineSpeedLimit == 15 and limit ~= math.huge then
        -- Використовуємо 1.5x від ліміту гри, мінімум 18 км/год
        -- Це дозволяє комбайну їхати швидше на легких полях!
        local genuineLimit = math.max(1.5 * limit, 18.0)
        spec.loadCalculator:setGenuineSpeedLimit(genuineLimit)
        -- Logging.info("RHM: [getSpeedLimit] Initial genuine limit set to %.1f km/h (from game limit %.1f)", 
        --     genuineLimit, limit)
    end
    
    -- === MULTIPLAYER FIX ===
    -- На клієнті LoadCalculator НЕ оновлюється (тільки на сервері)
    -- Тому клієнт повинен використовувати синхронізоване значення spec.data.recommendedSpeed
    if not self.isServer then
        -- CLIENT: Use synced value from server
        if spec.data and spec.data.recommendedSpeed then
            local syncedLimit = spec.data.recommendedSpeed
            
            -- Apply synced limit if it's actively limiting (< genuineSpeedLimit)
            if syncedLimit < spec.loadCalculator.genuineSpeedLimit then
                spec.isSpeedLimitActive = true
                limit = syncedLimit
            else
                spec.isSpeedLimitActive = false
            end
        end
        
        return limit, doCheckSpeedLimit
    end
    
    -- === SERVER: Continue with normal LoadCalculator logic ===
    -- Отримуємо обмеження з LoadCalculator
    local calculatedLimit = spec.loadCalculator:getSpeedLimit()
    local engineLoad = spec.loadCalculator:getEngineLoad()
    
    -- Діагностика: логуємо розрахунки (рідше)
    if not self._speedLimitLogTime or (g_currentMission.time - self._speedLimitLogTime) > 2000 then
        -- Logging.info("RHM: [getSpeedLimit] Load: %.1f%%, Calc limit: %.1f, Orig limit: %.1f", 
        --     engineLoad, calculatedLimit, limit)
        self._speedLimitLogTime = g_currentMission.time
    end
    
    -- ЗАВЖДИ застосовуємо розрахований ліміт (не порівнюємо з оригінальним)
    -- Це дозволяє обмежувати швидкість навіть якщо вона менша за оригінальний ліміт гри
    if calculatedLimit < spec.loadCalculator.genuineSpeedLimit then
        spec.isSpeedLimitActive = true
        limit = calculatedLimit
        
        -- Логуємо тільки коли РЕАЛЬНО обмежуємо
        if not self._lastLimitLog or math.abs(self._lastLimitLog - limit) > 0.5 then
            -- Logging.info("RHM: [getSpeedLimit] *** LIMITING SPEED to %.1f km/h (load: %.1f%%) ***", 
            --     limit, engineLoad)
            self._lastLimitLog = limit
        end
    else
        spec.isSpeedLimitActive = false
    end
    
    return limit, doCheckSpeedLimit
end

-- Перевіряємо чи можна увімкнути комбайн
function rhm_Combine:getCanBeTurnedOn(superFunc)
    local spec_combine = self.spec_combine
    
    -- Якщо немає жаток, використовуємо стандартну логіку
    if spec_combine.numAttachedCutters <= 0 then
        return superFunc(self)
    end
    
    -- Перевіряємо кожну жатку
    for cutter, _ in pairs(spec_combine.attachedCutters) do
        if cutter ~= self and cutter.getCanBeTurnedOn ~= nil and not cutter:getCanBeTurnedOn() then
            -- Якщо хоч одна жатка не готова (наприклад складена), комбайн не запуститься
            return false
        end
    end

    return superFunc(self)
end

-- Запобігаємо автозапуску жатки при старті молотарки
-- ВАЖЛИВО: НЕ викликаємо superFunc, бо він запускає жатки автоматично!
function rhm_Combine:startThreshing(superFunc)
    local spec_combine = self.spec_combine
    
    -- Перевіряємо чи увімкнена функція роздільного запуску
    local isIndependentLaunchEnabled = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isIndependentLaunchEnabled = g_realisticHarvestManager.settings.enableIndependentLaunch
    end
    
    -- Логіка запуску жаток:
    -- - Якщо роздільний запуск ВИМКНЕНИЙ → запускаємо жатки завжди (класична поведінка)
    -- - Якщо роздільний запуск УВІМКНЕНИЙ → запускаємо ТІЛЬКИ для AI
    local isAIActive = self:getIsAIActive()
    local shouldStartCutters = (not isIndependentLaunchEnabled) or (isIndependentLaunchEnabled and isAIActive)
    
    if spec_combine.numAttachedCutters > 0 and shouldStartCutters then
        -- Запускаємо жатки (для AI завжди, для гравця - тільки якщо функція вимкнена)
        local allowLowering = not self:getIsAIActive() or not self.rootVehicle:getAIFieldWorkerIsTurning()
        
        for _, cutter in pairs(spec_combine.attachedCutters) do
            if allowLowering and cutter ~= self then
                local jointDescIndex = self:getAttacherJointIndexFromObject(cutter)
                self:setJointMoveDown(jointDescIndex, true, true)
            end
            
            cutter:setIsTurnedOn(true, true)
        end
    end
    
    -- Анімації та звуки молотарки (завжди)
    if spec_combine.threshingStartAnimation ~= nil and self.playAnimation ~= nil then
        self:playAnimation(spec_combine.threshingStartAnimation, spec_combine.threshingStartAnimationSpeedScale, self:getAnimationTime(spec_combine.threshingStartAnimation), true)
    end
    
    if self.isClient then
        g_soundManager:stopSample(spec_combine.samples.stop)
        g_soundManager:stopSample(spec_combine.samples.work)
        g_soundManager:playSample(spec_combine.samples.start)
        g_soundManager:playSample(spec_combine.samples.work, 0, spec_combine.samples.start)
    end
    
    SpecializationUtil.raiseEvent(self, "onStartThreshing")
end

-- Запобігаємо авто-вимкненню жатки при зупинці молотарки
function rhm_Combine:stopThreshing(superFunc)
    local spec_combine = self.spec_combine
    
    if self.isClient then
        g_soundManager:stopSample(spec_combine.samples.start)
        g_soundManager:stopSample(spec_combine.samples.work)
        g_soundManager:playSample(spec_combine.samples.stop)
    end
    
    self:setCombineIsFilling(false, false, true)
    local isFull = self:getCombineFillLevelPercentage() > 0.999
    if isFull and self.rootVehicle.setCruiseControlState ~= nil then
        self.rootVehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
    end
    
    -- НЕ вимикаємо жатки автоматично (гравець керує ними вручну)
    
    if spec_combine.threshingStartAnimation ~= nil and spec_combine.playAnimation ~= nil then
        self:playAnimation(spec_combine.threshingStartAnimation, -spec_combine.threshingStartAnimationSpeedScale, self:getAnimationTime(spec_combine.threshingStartAnimation), true)
    end
    
    SpecializationUtil.raiseEvent(self, "onStopThreshing")
end

-- Забороняємо харвестинг якщо комбайн вимкнений
-- Це запобігає збору врожаю коли увімкнена тільки жатка без комбайна
function rhm_Combine:verifyCombine(superFunc, fruitType, outputFillType)
    local isAIActive = self:getIsAIActive()
    
    -- Перевіряємо чи комбайн увімкнений (молотарка працює)
    if not self:getIsTurnedOn() and not isAIActive then
        return nil  -- Блокуємо харвестинг
    end
    
    return superFunc(self, fruitType, outputFillType)
end

---Check for safety warnings (Client Side)
function rhm_Combine:updateWarnings(dt)
    -- Only for active vehicle
    if not self:getIsActiveForInput(true) then
        return
    end

    local isCombineOn = self:getIsTurnedOn()
    local spec_combine = self.spec_combine
    
    -- Iterate attached cutters
    if spec_combine.attachedCutters then
        for cutter, _ in pairs(spec_combine.attachedCutters) do
            local isCutterOn = cutter:getIsTurnedOn()
            local isLowered = cutter:getIsLowered()
            
            -- CASE 1: Cutter ON but Thresher OFF (Critical)
            if isCutterOn and not isCombineOn then
                g_currentMission:showBlinkingWarning(g_i18n:getText("rhm_warning_turn_on_combine"), 2000)
                break -- Priority warning
            end
            
            -- CASE 2: Thresher ON but Cutter OFF and Lowered (Likely forgot to turn on)
            if isCombineOn and not isCutterOn and isLowered then
                g_currentMission:showBlinkingWarning(g_i18n:getText("rhm_warning_turn_on_cutter"), 2000)
                break
            end
        end
    end
end

-- Викликається періодично для оновлення логіки
function rhm_Combine:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if rhm_Combine.debug then
        print("RHM: rhm_Combine:onUpdateTick called")
    end
    
    -- Client Side Logic (Warnings)
    if self.isClient then
        rhm_Combine.updateWarnings(self, dt)
    end
    
    if not self.isServer then
        return
    end
    
    local spec = self.spec_rhm_Combine
    local spec_combine = self.spec_combine
    
    if not spec or not spec.loadCalculator then
        return
    end
    
    -- Перевіряємо чи комбайн працює
    if not self:getIsTurnedOn() or self.movingDirection == -1 then
        -- Комбайн не працює - скидаємо навантаження
        spec.loadCalculator:reset()
        if spec.data then
            spec.data.load = 0
        end
        spec.isSpeedLimitActive = false
        return
    end
    
    -- Перевіряємо чи жатка працює (Fix for Courseplay, which has weird movingDirection)
    local cutterIsTurnedOn = false  -- FIX: завжди скидаємо перед циклом
    for cutter, _ in pairs(spec_combine.attachedCutters) do
        if cutter.spec_cutter then
            local spec_cutter = cutter.spec_cutter
            -- Removed self.movingDirection == spec_cutter.movingDirection check since Courseplay can break it
            if cutter:getIsTurnedOn() 
                and self:getLastSpeed() > 0.5 
                and (spec_cutter.allowCuttingWhileRaised or cutter:getIsLowered(true)) then
                cutterIsTurnedOn = true
                break  -- FIX: знайшли працюючу — виходим
            end
        end
    end
    
    if not cutterIsTurnedOn then
        -- Жатка не працює - скидаємо індикатори, щоб вони не висіли
        spec.loadCalculator:reset() 
        if spec.data then
            spec.data.load = 0 
            spec.data.cropLoss = 0
            spec.data.tonPerHour = 0
            spec.data.litersPerHour = 0
            spec.data.yield = 0
            spec.data.recommendedSpeed = 0 -- Скидаємо рекомендовану швидкість, щоб не показувало "/ 3.8"
        end
        spec.isSpeedLimitActive = false
        
        -- СИНХРОНІЗАЦІЯ: Важливо оновити клієнтів, щоб у них теж зникли цифри
        self:raiseDirtyFlags(spec.dirtyFlag)
        
        return
    end
    
    -- Видалено: Застаріла автодетекція культур у onUpdateTick
    -- Тепер детекція відбувається виключно через addCutterArea (з 2-сек debounce),
    -- щоб уникнути конфліктів та хибного визначення після скидання бункера.
    
    -- Оновлюємо LoadCalculator
    -- Спершу розраховуємо масу, бо тепер вона головна!
    local massKg = 0
    local liters = spec.lastLiters or 0
    
    if liters > 0 then
        if spec.lastFillType and g_fillTypeManager then
            local fillType = g_fillTypeManager:getFillTypeByIndex(spec.lastFillType)
            if fillType and fillType.massPerLiter then
                -- ВАЖЛИВО: massPerLiter в грі зберігається в ТОННАХ на літр, тому множимо на 1000
                massKg = liters * fillType.massPerLiter * 1000
            else
                massKg = liters * 0.75 -- Fallback
            end
        else
            massKg = liters * 0.75 -- Fallback
        end
    end
    
    -- Використовуємо lastRawArea (реальна площа) для врожайності
    local areaForYield = spec.lastRawArea or spec.lastArea or 0 
    
    -- Передаємо МАСУ в LoadCalculator!
    spec.loadCalculator:update(self, dt, massKg)
    
    -- Оновлюємо продуктивність і врожайність
    if liters > 0 then
        -- Використовуємо нову функцію з area
        spec.loadCalculator:updateProductivityAndYield(massKg, liters, areaForYield, dt) 
    end
    
    -- ========================================================================
    -- PHYSICAL CROP LOSS - Видаляємо втрачене зерно з бункера
    -- ========================================================================
    if liters > 0 and self.isServer then
        -- Розраховуємо crop loss (включаючи втрати від налаштувань)
        local cropLoss = spec.loadCalculator:calculateTotalCropLoss()
        spec.combineMemory:updateStatistics(liters, cropLoss, spec.combineMemory.currentCrop)
        
        if cropLoss > 0 and g_realisticHarvestManager and g_realisticHarvestManager.settings then
            if g_realisticHarvestManager.settings.enableCropLoss then
                local lossRatio = cropLoss / 100
                local lostLiters = liters * lossRatio
                
                local fillUnitIndex = 1
                local spec_fillUnit = self.spec_fillUnit
                if spec_fillUnit and spec_fillUnit.fillUnits and spec_fillUnit.fillUnits[fillUnitIndex] then
                    self:addFillUnitFillLevel(
                        self:getOwnerFarmId(),
                        fillUnitIndex,
                        -lostLiters,
                        spec.lastFillType,
                        ToolType.UNDEFINED,
                        nil
                    )
                    
                    if rhm_Combine.debug or cropLoss > 10 then
                        print(string.format("RHM: [LOSS] Crop Loss Applied: %.1f L lost (%.1f%% of %.1f L harvest)",
                            lostLiters, cropLoss, liters))
                    end
                else
                    print("RHM: Warning - Could not find fill unit for crop loss removal")
                end
            end
        end
    end
    -- ========================================================================
    
    -- Скидаємо лічильники
    spec.lastArea = 0
    spec.lastRawArea = 0 -- Reset new counter
    spec.lastLiters = 0
    
    -- Оновлюємо дані для HUD
    if spec.data then
        spec.data.load = spec.loadCalculator:getEngineLoad()
        spec.data.cropLoss = spec.loadCalculator:calculateTotalCropLoss()
        spec.data.tonPerHour = spec.loadCalculator:getTonPerHour()
        spec.data.litersPerHour = spec.loadCalculator:getLitersPerHour() -- NEW: Volume flow
        spec.data.recommendedSpeed = spec.loadCalculator:getSpeedLimit()
        -- NEW: Yield Monitor Data
        spec.data.yield = spec.loadCalculator.currentYield or 0
    end
    
    -- ========================================================================
    -- AI / COURSEPLAY WORKAROUND (Server Side)
    -- ========================================================================
    -- Courseplay uses its own speed controller that bypasses getSpeedLimit().
    -- We must enforce the requested speed limit directly on the motor.
    if self.isServer and self:getIsAIActive() then
        if self.spec_motorized and self.spec_motorized.motor then
            local motor = self.spec_motorized.motor
            local currentLimit = spec.loadCalculator:getSpeedLimit()
            
            -- If the AI tries to drive faster than our dynamic limit, force the motor to slow down
            if motor.speedLimit > currentLimit then
                motor:setSpeedLimit(currentLimit)
            end
        end
    end
    -- ========================================================================
    
    -- === OVERLOAD WARNING ===
    -- Сервер визначає рівень: 0=норма, 1=HIGH(120%+), 2=CRITICAL(150%+)
    if self.isServer and spec.data then
        local load = spec.data.load
        if load >= 150 then
            spec.data.overloadLevel = 2
        elseif load >= 120 then
            spec.data.overloadLevel = 1
        else
            spec.data.overloadLevel = 0
        end
    end
    
    -- WARNING DISPLAY: показуємо завжди в того хто керує комбайном
    -- в SP: isServer=true і getIsControlled()=true — працює
    -- в DS client: isServer=false і overloadLevel приходить через stream — працює
    if spec.data and self:getIsControlled() then
        local level = spec.data.overloadLevel or 0
        local now = g_currentMission.time
        spec._lastOverloadWarn = spec._lastOverloadWarn or 0
        
        local warnInterval = nil
        local warnText = nil
        
        if level == 2 then
            warnInterval = 5000
            warnText = g_i18n:getText("rhm_warn_overload_critical")
        elseif level == 1 then
            warnInterval = 8000
            warnText = g_i18n:getText("rhm_warn_overload_high")
        else
            spec._lastOverloadWarn = 0
        end
        
        if warnText and (now - spec._lastOverloadWarn) >= warnInterval then
            spec._lastOverloadWarn = now
            g_currentMission:showBlinkingWarning(warnText, 3000)
        end
    end
    -- === END OVERLOAD WARNING ===
    
    -- MULTIPLAYER: Позначаємо що дані змінились для синхронізації
    self:raiseDirtyFlags(spec.dirtyFlag)
    
    if rhm_Combine.debug then
        print(string.format("RHM: Engine load updated: %.1f%%, Speed limit: %.1f km/h", 
            spec.data.load, spec.loadCalculator:getSpeedLimit()))
    end
end

-- Викликається кожен кадр коли гравець в комбайні
function rhm_Combine:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    -- ПРИМІТКА: HUD малюється централізовано в RealisticHarvestManager:draw()
    -- Ми використовуємо сканування ієрархії (getControlledVehicle -> root -> findCombine),
    -- тому немає потреби малювати тут, це викликає дублювання.
end

-- ============================================================================
-- SAVEGAME FUNCTIONS  
-- ============================================================================

---Збереження стану в savegame файл
---@param xmlFile XMLFile
---@param key string
function rhm_Combine:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_rhm_Combine
    if not spec or not spec.combineMemory then return end
    
    -- Поточні налаштування
    local cur = key .. ".combineMemory.current"
    xmlFile:setValue(cur .. "#mode",        spec.combineMemory.mode or "AUTO")
    xmlFile:setValue(cur .. "#autoSwitch",  spec.combineMemory.autoSwitchEnabled ~= false)
    if spec.combineMemory.currentCrop then
        xmlFile:setValue(cur .. "#currentCrop", spec.combineMemory.currentCrop)
    end
    xmlFile:setValue(cur .. "#fan",         spec.combineMemory.currentSettings.fan or 50)
    xmlFile:setValue(cur .. "#upperSieve",  spec.combineMemory.currentSettings.upperSieve or 50)
    xmlFile:setValue(cur .. "#lowerSieve",  spec.combineMemory.currentSettings.lowerSieve or 50)
    xmlFile:setValue(cur .. "#rotor",       spec.combineMemory.currentSettings.rotor or 50)
    xmlFile:setValue(cur .. "#feeder",      spec.combineMemory.currentSettings.feeder or 50)
    
    print(string.format("RHM: [SAVE] Saved combine state for %s", self:getName() or "?"))
end

---Завантаження стану з savegame файлу
---@param xmlFile XMLFile
---@param key string  
---@param resetVehicles table
function rhm_Combine:loadFromXMLFile(xmlFile, key, resetVehicles)
    local spec = self.spec_rhm_Combine
    if not spec or not spec.combineMemory then return end
    
    -- Поточні налаштування
    local cur = key .. ".combineMemory.current"
    spec.combineMemory.mode              = xmlFile:getValue(cur .. "#mode", "AUTO")
    spec.combineMemory.autoSwitchEnabled = xmlFile:getValue(cur .. "#autoSwitch", true)
    local savedCrop = xmlFile:getValue(cur .. "#currentCrop")
    spec.combineMemory.currentCrop = (savedCrop ~= "" and savedCrop) or nil
    spec.combineMemory.currentSettings.fan        = xmlFile:getValue(cur .. "#fan", 50)
    spec.combineMemory.currentSettings.upperSieve = xmlFile:getValue(cur .. "#upperSieve", 50)
    spec.combineMemory.currentSettings.lowerSieve = xmlFile:getValue(cur .. "#lowerSieve", 50)
    spec.combineMemory.currentSettings.rotor      = xmlFile:getValue(cur .. "#rotor", 50)
    spec.combineMemory.currentSettings.feeder     = xmlFile:getValue(cur .. "#feeder", 50)
    
    print(string.format("RHM: [LOAD] Loaded combine state for %s", self:getName() or "?"))
end

-- ============================================================================
-- MULTIPLAYER SYNCHRONIZATION
-- ============================================================================

---Початкова синхронізація: Сервер пише дані коли клієнт підключається
function rhm_Combine:onWriteStream(streamId, connection)
    local spec = self.spec_rhm_Combine
    if not spec or not spec.data then
        -- Пишемо нулі якщо немає даних
        streamWriteFloat32(streamId, 0)
        streamWriteFloat32(streamId, 0)
        streamWriteFloat32(streamId, 0)
        streamWriteFloat32(streamId, 0)
        streamWriteFloat32(streamId, 0)
        streamWriteFloat32(streamId, 0) -- yield
        streamWriteUInt8(streamId, 0)   -- overloadLevel
        -- CombineMemory: write defaults
        streamWriteUInt8(streamId, 50)  -- fan
        streamWriteUInt8(streamId, 50)  -- rotor
        streamWriteUInt8(streamId, 50)  -- upperSieve
        streamWriteUInt8(streamId, 50)  -- lowerSieve
        streamWriteUInt8(streamId, 50)  -- feeder
        streamWriteString(streamId, "AUTO")  -- mode
        streamWriteString(streamId, "")      -- currentCrop (empty = nil)
        return
    end
    
    -- HUD data
    streamWriteFloat32(streamId, spec.data.load or 0)
    streamWriteFloat32(streamId, spec.data.cropLoss or 0)
    streamWriteFloat32(streamId, spec.data.tonPerHour or 0)
    streamWriteFloat32(streamId, spec.data.litersPerHour or 0)
    streamWriteFloat32(streamId, spec.data.recommendedSpeed or 0)
    streamWriteFloat32(streamId, spec.data.yield or 0)
    streamWriteUInt8(streamId, spec.data.overloadLevel or 0)
    
    -- CombineMemory settings (FIX 4: sync on initial connect)
    local mem = spec.combineMemory
    if mem then
        streamWriteUInt8(streamId, mem.currentSettings.fan or 50)
        streamWriteUInt8(streamId, mem.currentSettings.rotor or 50)
        streamWriteUInt8(streamId, mem.currentSettings.upperSieve or 50)
        streamWriteUInt8(streamId, mem.currentSettings.lowerSieve or 50)
        streamWriteUInt8(streamId, mem.currentSettings.feeder or 50)
        streamWriteString(streamId, mem.mode or "AUTO")
        streamWriteString(streamId, mem.currentCrop or "")
    else
        streamWriteUInt8(streamId, 50)
        streamWriteUInt8(streamId, 50)
        streamWriteUInt8(streamId, 50)
        streamWriteUInt8(streamId, 50)
        streamWriteUInt8(streamId, 50)
        streamWriteString(streamId, "AUTO")
        streamWriteString(streamId, "")
    end
end

---Початкова синхронізація: Клієнт читає дані при підключенні
function rhm_Combine:onReadStream(streamId, connection)
    local spec = self.spec_rhm_Combine
    if not spec then
        -- Пропускаємо дані якщо немає spec
        streamReadFloat32(streamId)
        streamReadFloat32(streamId)
        streamReadFloat32(streamId)
        streamReadFloat32(streamId)
        streamReadFloat32(streamId)
        streamReadFloat32(streamId) -- yield
        streamReadUInt8(streamId)   -- overloadLevel
        -- CombineMemory defaults (skip)
        streamReadUInt8(streamId)
        streamReadUInt8(streamId)
        streamReadUInt8(streamId)
        streamReadUInt8(streamId)
        streamReadUInt8(streamId)
        streamReadString(streamId)
        streamReadString(streamId)
        return
    end
    
    if not spec.data then
        spec.data = {}
    end
    
    -- HUD data
    spec.data.load = streamReadFloat32(streamId)
    spec.data.cropLoss = streamReadFloat32(streamId)
    spec.data.tonPerHour = streamReadFloat32(streamId)
    spec.data.litersPerHour = streamReadFloat32(streamId)
    spec.data.recommendedSpeed = streamReadFloat32(streamId)
    spec.data.yield = streamReadFloat32(streamId)
    spec.data.overloadLevel = streamReadUInt8(streamId)
    
    -- CombineMemory settings (FIX 4: receive on initial connect)
    local fan = streamReadUInt8(streamId)
    local rotor = streamReadUInt8(streamId)
    local upperSieve = streamReadUInt8(streamId)
    local lowerSieve = streamReadUInt8(streamId)
    local feeder = streamReadUInt8(streamId)
    local mode = streamReadString(streamId)
    local currentCrop = streamReadString(streamId)
    
    -- Apply to combineMemory if available
    if spec.combineMemory then
        spec.combineMemory.currentSettings.fan = fan
        spec.combineMemory.currentSettings.rotor = rotor
        spec.combineMemory.currentSettings.upperSieve = upperSieve
        spec.combineMemory.currentSettings.lowerSieve = lowerSieve
        spec.combineMemory.currentSettings.feeder = feeder
        spec.combineMemory.mode = mode or "AUTO"
        spec.combineMemory.currentCrop = (currentCrop ~= "" and currentCrop) or nil
    end
end

---Постійна синхронізація: Клієнт читає оновлення від сервера
function rhm_Combine:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then  -- Клієнт читає від сервера
        local spec = self.spec_rhm_Combine
        if not spec then 
            return 
        end
        
        -- Перевіряємо чи є оновлення (dirtyFlag)
        local hasUpdate = streamReadBool(streamId)
        
        if hasUpdate then
            if not spec.data then
                spec.data = {}
            end
            
            -- HUD data
            spec.data.load = streamReadFloat32(streamId)
            spec.data.cropLoss = streamReadFloat32(streamId)
            spec.data.tonPerHour = streamReadFloat32(streamId)
            spec.data.litersPerHour = streamReadFloat32(streamId)
            spec.data.recommendedSpeed = streamReadFloat32(streamId)
            spec.data.yield = streamReadFloat32(streamId)
            spec.data.overloadLevel = streamReadUInt8(streamId)
            
            -- CombineMemory settings (FIX 4)
            local fan = streamReadUInt8(streamId)
            local rotor = streamReadUInt8(streamId)
            local upperSieve = streamReadUInt8(streamId)
            local lowerSieve = streamReadUInt8(streamId)
            local feeder = streamReadUInt8(streamId)
            local mode = streamReadString(streamId)
            local currentCrop = streamReadString(streamId)
            
            if spec.combineMemory then
                spec.combineMemory.currentSettings.fan = fan
                spec.combineMemory.currentSettings.rotor = rotor
                spec.combineMemory.currentSettings.upperSieve = upperSieve
                spec.combineMemory.currentSettings.lowerSieve = lowerSieve
                spec.combineMemory.currentSettings.feeder = feeder
                spec.combineMemory.mode = mode or "AUTO"
                spec.combineMemory.currentCrop = (currentCrop ~= "" and currentCrop) or nil
            end
        end
    end
end

---Постійна синхронізація: Сервер пише оновлення до клієнта
function rhm_Combine:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then  -- Сервер пише до клієнта
        local spec = self.spec_rhm_Combine
        if not spec then
            streamWriteBool(streamId, false)
            return
        end
        
        -- Перевіряємо чи є зміни
        local hasChanges = bitAND(dirtyMask, spec.dirtyFlag) ~= 0
        
        streamWriteBool(streamId, hasChanges)
        
        if hasChanges then
            -- HUD data
            local data = spec.data or {}
            streamWriteFloat32(streamId, data.load or 0)
            streamWriteFloat32(streamId, data.cropLoss or 0)
            streamWriteFloat32(streamId, data.tonPerHour or 0)
            streamWriteFloat32(streamId, data.litersPerHour or 0)
            streamWriteFloat32(streamId, data.recommendedSpeed or 0)
            streamWriteFloat32(streamId, data.yield or 0)
            streamWriteUInt8(streamId, data.overloadLevel or 0)
            
            -- CombineMemory settings (FIX 4)
            local mem = spec.combineMemory
            if mem then
                streamWriteUInt8(streamId, mem.currentSettings.fan or 50)
                streamWriteUInt8(streamId, mem.currentSettings.rotor or 50)
                streamWriteUInt8(streamId, mem.currentSettings.upperSieve or 50)
                streamWriteUInt8(streamId, mem.currentSettings.lowerSieve or 50)
                streamWriteUInt8(streamId, mem.currentSettings.feeder or 50)
                streamWriteString(streamId, mem.mode or "AUTO")
                streamWriteString(streamId, mem.currentCrop or "")
            else
                streamWriteUInt8(streamId, 50)
                streamWriteUInt8(streamId, 50)
                streamWriteUInt8(streamId, 50)
                streamWriteUInt8(streamId, 50)
                streamWriteUInt8(streamId, 50)
                streamWriteString(streamId, "AUTO")
                streamWriteString(streamId, "")
            end
        end
    end
end

-- ============================================================================
-- INPUT MANAGEMENT
-- ============================================================================

-- Реєстрація UserActionEvents при вході в техніку
function rhm_Combine:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_rhm_Combine
        self:clearActionEventsTable(spec.actionEvents)
        
        if isActiveForInputIgnoreSelection then
            -- Реєструємо дію Перемикання Курсора (RMB за замовчуванням)
            local _, eventId = self:addActionEvent(spec.actionEvents, InputAction.RHM_TOGGLE_CURSOR, self, rhm_Combine.actionToggleCursor, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
            
            -- Реєструємо дію Відкриття Меню (RShift+K)
            if InputAction.RHM_OPEN_MENU then
                local _, menuEventId = self:addActionEvent(spec.actionEvents, InputAction.RHM_OPEN_MENU, self, rhm_Combine.actionOpenMenu, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(menuEventId, GS_PRIO_HIGH)
            end
        end
    end
end

-- Callback для дії
function rhm_Combine:actionToggleCursor(actionName, inputValue, callbackState, isAnalog)
    if g_realisticHarvestManager then
        g_realisticHarvestManager:toggleCursor()
    end
end

function rhm_Combine:actionOpenMenu(actionName, inputValue, callbackState, isAnalog)
    if g_realisticHarvestManager then
        g_realisticHarvestManager:toggleMenu(self)
    end
end

-- ============================================================================
-- COMBINE SETTINGS SYSTEM
-- ============================================================================

---Обробка зміни типу культури (викликається при детекції нової культури)
---@param newCropName string Назва нової культури




