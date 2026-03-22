-- EN: Core FS25 vehicle specialization for the Realistic Harvesting mod.
--     Overrides key combine functions (addCutterArea, addFillUnitFillLevel, getSpeedLimit, etc.)
--     to integrate physics-based load calculation, crop-loss simulation, and combine settings.
--     Handles savegame serialization, multiplayer network streams, and input action registration.
--     Supports modular harvesting systems like NEXAT via hierarchy-aware input hooks.
-- UA: Основна спеціалізація транспортного засобу FS25 для мода Realistic Harvesting.
--     Перевизначає ключові функції комбайна (addCutterArea, addFillUnitFillLevel, getSpeedLimit тощо)
--     для інтеграції фізичного розрахунку навантаження, симуляції втрат врожаю та налаштувань комбайна.
--     Обробляє серіалізацію збереження, мережеві потоки мультиплеєра та реєстрацію дій вводу.
--     Підтримує модульні системи збирання як NEXAT через хуки вводу з урахуванням ієрархії.
rhm_Combine = {}
rhm_Combine.debug = false

-- EN: Checks if the vehicle has the base Combine specialization.
--     Returns true for all machines including modular systems like NEXAT.
-- UA: Перевіряє чи транспортний засіб має базову спеціалізацію Combine.
--     Повертає true для всіх машин, включаючи модульні системи на кшталт NEXAT.
function rhm_Combine.prerequisitesPresent(specializations)
    -- EN: Print all specialization class names for diagnostic logging.
    -- UA: Виводимо всі назви класів спеціалізацій для діагностичного логування.
    RHM_Debug.log("Combine", "========================================")
    RHM_Debug.log("Combine", "RHM: Checking prerequisites for vehicle")
    RHM_Debug.log("Combine", "Available specializations:")
    for specName, specTable in pairs(specializations) do
        if type(specTable) == "table" and specTable.className then
            RHM_Debug.log("Combine", "  - " .. specTable.className)
        end
    end
    
    -- Перевіряємо базову specialization Combine
    local hasCombine = SpecializationUtil.hasSpecialization(Combine, specializations)
    RHM_Debug.log("Combine", "Has Combine: " .. tostring(hasCombine))
    
    -- Для Nexat: тимчасово спрощуємо перевірку
    -- Повертаємо true якщо просто є Combine
    RHM_Debug.log("Combine", "Result: " .. tostring(hasCombine))
    RHM_Debug.log("Combine", "========================================")
    
    return hasCombine
end

-- EN: Registers rhm_Combine's overwritten (proxied) functions before event listeners.
--     These intercept combine core behaviors to inject our load and speed logic.
-- UA: Реєструє перевизначені (proxy) функції rhm_Combine до подій-прислухачів.
--     Ці функції перехоплюють основні поведінки комбайна для вбудованої логіки навантаження і швидкості.
function rhm_Combine.registerOverwrittenFunctions(vehicleType)
    RHM_Debug.log("Combine", "RHM: Registering overwritten functions for rhm_Combine")
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "addCutterArea", rhm_Combine.addCutterArea)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "addFillUnitFillLevel", rhm_Combine.addFillUnitFillLevel)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getSpeedLimit", rhm_Combine.getSpeedLimit)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "startThreshing", rhm_Combine.startThreshing)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "stopThreshing", rhm_Combine.stopThreshing)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "verifyCombine", rhm_Combine.verifyCombine)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeTurnedOn", rhm_Combine.getCanBeTurnedOn)
end

-- EN: Registers XML paths for vehicle config (shop/modDesc XML). Persists combine settings per-vehicle.
-- UA: Реєструє шляхи XML для конфігурації засобу (XML магазину/modDesc). Зберігає налаштування комбайна для кожного засобу.
function rhm_Combine.registerXMLPaths(schema, basePath)
    local cur = basePath .. ".combineMemory.current"
    schema:register(XMLValueType.STRING, cur .. "#mode",        "Combine settings mode", "AUTO")
    schema:register(XMLValueType.STRING, cur .. "#currentCrop", "Current crop", "")
    schema:register(XMLValueType.BOOL,   cur .. "#autoSwitch",  "Auto switch enabled", true)
    schema:register(XMLValueType.INT,    cur .. "#fan",         "Fan", 50)
    schema:register(XMLValueType.INT,    cur .. "#upperSieve",  "Upper sieve", 50)
    schema:register(XMLValueType.INT,    cur .. "#lowerSieve",  "Lower sieve", 50)
    schema:register(XMLValueType.INT,    cur .. "#rotor",       "Rotor", 50)
    schema:register(XMLValueType.INT,    cur .. "#feeder",      "Feeder", 50)
end

-- EN: Mirrors registerXMLPaths for the savegame vehicles.xml schema.
--     Called automatically by FS25 for every specialization when the savegame schema is registered.
-- UA: Дзеркально дублює registerXMLPaths для схеми vehicles.xml збереження.
--     Викликається автоматично FS25 для кожної спеціалізації при реєстрації схеми збереження.
function rhm_Combine.registerSavegameXMLPaths(schema, basePath)
    rhm_Combine.registerXMLPaths(schema, basePath)
end

-- EN: Registers event listeners for the spec's lifecycle hooks:
--     onLoad, onUpdateTick, onDraw, stream read/write, XML save/load, input actions.
--     Also registers savegame XML schema paths via Vehicle.xmlSchemaSavegame as a critical fix
--     for programmatically-added specializations that are otherwise missed.
-- UA: Реєструє подій-прислухачі для хуків життєвого циклу спец:
--     onLoad, onUpdateTick, onDraw, читання/запис потоків, XML збереження/завантаження, дії вводу.
--     Також реєструє шляхи XML схеми збереження через Vehicle.xmlSchemaSavegame як критичне виправлення
--     для спеціалізацій доданих програмно, які інакше пропускаються.
function rhm_Combine.registerEventListeners(vehicleType)
    RHM_Debug.log("Combine", "RHM: Registering event listeners for rhm_Combine")
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
    
    -- CRITICAL FIX: явна реєстрація схеми savegame_vehicles для програмно доданих спеціалізацій
    if Vehicle and Vehicle.xmlSchemaSavegame then
        local modName = g_currentModName 
            or (g_realisticHarvestManager and g_realisticHarvestManager.modName)
            or "FS25_RealisticHarvesting"
        
        -- EN: Registration path must match the game's internal structure: vehicles.vehicle(?).MODNAME.rhm_Combine
        -- UA: Шлях реєстрації має відповідати структурі гри: vehicles.vehicle(?).MODNAME.rhm_Combine
        local basePath = string.format("vehicles.vehicle(?).%s.rhm_Combine", modName)
        rhm_Combine.registerXMLPaths(Vehicle.xmlSchemaSavegame, basePath)
        
        if rhm_Combine.debug then
            RHM_Debug.log("Combine", string.format("RHM: Registered savegame XML schema paths via Vehicle.xmlSchemaSavegame (basePath: %s)", basePath))
        end
    end
end

-- EN: Global hook for non-combine vehicles in a modular system (e.g. NEXAT main tractor).
--     The standard rhm_Combine:onRegisterActionEvents only fires for vehicles that have spec_rhm_Combine.
--     For NEXAT, the player drives the main tractor which doesn't. We solve this by hooking
--     Vehicle.onRegisterActionEvents globally: if the vehicle doesn't have our spec but IS in
--     a hierarchy that contains one, we still register RHM_OPEN_MENU on it.
-- UA: Глобальний хук для транспортних засобів шо не є комбайнами в модульній системі (напр. головний трактор NEXAT).
--     Стандартний rhm_Combine:onRegisterActionEvents викликається лише для засобів з spec_rhm_Combine.
--     Для NEXAT гравець керує трактором який цього не має. Ми вирішуємо це хуком
--     глобального Vehicle.onRegisterActionEvents: якщо засіб не має нашої спец, але IE в ієрархії з нею, ми все одно реєструємо RHM_OPEN_MENU.

local function RHM_globalOnRegisterActionEvents(vehicle, isActiveForInput, isActiveForInputIgnoreSelection)
    -- Skip if this is already a combine with our spec (handled by rhm_Combine:onRegisterActionEvents)
    if vehicle.spec_rhm_Combine then
        return
    end
    
    -- Only register if the player is actively in this vehicle
    if not isActiveForInputIgnoreSelection then
        return
    end
    
    -- Only on client
    if not vehicle.isClient then
        return
    end
    
    -- Check if there's a combine with our spec in the hierarchy
    local function hasCombineInHierarchy(v, visited)
        if not v or visited[v] then return false end
        visited[v] = true
        if v.spec_rhm_Combine then return true end
        if v.rootVehicle and hasCombineInHierarchy(v.rootVehicle, visited) then return true end
        if v.attacherVehicle and hasCombineInHierarchy(v.attacherVehicle, visited) then return true end
        if v.getAttachedImplements then
            for _, impl in ipairs(v:getAttachedImplements() or {}) do
                if impl.object and hasCombineInHierarchy(impl.object, visited) then return true end
            end
        end
        return false
    end
    
    local searchRoot = vehicle.rootVehicle or vehicle
    if not hasCombineInHierarchy(searchRoot, {}) then
        return
    end
    
    -- Register RHM_OPEN_MENU for this NEXAT-style vehicle
    if not vehicle._rhmActionEvents then
        vehicle._rhmActionEvents = {}
    end
    vehicle:clearActionEventsTable(vehicle._rhmActionEvents)
    
    if InputAction.RHM_OPEN_MENU then
        local _, eventId = vehicle:addActionEvent(vehicle._rhmActionEvents, InputAction.RHM_OPEN_MENU, vehicle,
            function(self, ...)
                if g_realisticHarvestManager then
                    g_realisticHarvestManager:toggleMenu(self)
                end
            end, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
        -- RHM_Debug.log("Combine", "RHM: [NEXAT] Registered RHM_OPEN_MENU for non-combine vehicle: " .. tostring(vehicle:getFullName()))
    end
end

-- Apply global hook ONCE (guard against double-loading)
if not rhm_Combine._nexatHookApplied then
    rhm_Combine._nexatHookApplied = true
    Vehicle.onRegisterActionEvents = Utils.appendedFunction(
        Vehicle.onRegisterActionEvents,
        RHM_globalOnRegisterActionEvents
    )
    RHM_Debug.log("Combine", "RHM: [NEXAT] Global Vehicle.onRegisterActionEvents hook applied.")
end
-- ============================================================================

-- EN: Called when the combine vehicle is loaded. Creates and wires up all subsystems:
--     LoadCalculator, machineType detection, CombineMemory, HUD data table, dirty flags,
--     and network throttling. Loads settings from XML if savegame exists.
-- UA: Викликається при завантаженні комбайна. Створює і підключає всі підсистеми:
--     LoadCalculator, визначення типу машини, CombineMemory, таблиця даних HUD, прапорці "dirty",
--     і тротлінг мережі. Завантажує налаштування з XML якщо існує збереження.
function rhm_Combine:onLoad(savegame)
    -- Створюємо spec для нашого моду
    -- НЕ хардкодимо назву моду: при перейменуванні папки/моду specName зміниться
    local modName = g_currentModName 
        or (g_realisticHarvestManager and g_realisticHarvestManager.modName)
        or "FS25_RealisticHarvesting"
    local specName = string.format("spec_%s.rhm_Combine", modName)
    
    self.spec_rhm_Combine = self[specName]
    local spec = self.spec_rhm_Combine
    
    if not spec then
        Logging.error("RHM: Failed to initialize spec for combine: %s (specName: %s)", 
            tostring(self:getFullName()), tostring(specName))
        return
    end
    
    -- Синхронізація дебаг-прапорця з основним менеджером
    rhm_Combine.debug = RHM_Debug.isEnabled("Combine")
    
    if rhm_Combine.debug then
        RHM_Debug.log("Combine", string.format("RHM: onLoad called for %s (has savegame: %s)", 
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
    
    -- EN: Calculate base throughput from engine horsepower (set before machine type detection).
    -- UA: Розраховуємо базову пропускну здатність з потужності двигуна (встановлюється до визначення типу машини).
    local basePerf = spec.loadCalculator:getBasePerformanceFromPower(self)
    spec.loadCalculator:setBasePerformance(basePerf)
    
    -- EN: Get the RHM Package level from the store configuration (1=Standard, 4=Opti-Harvest)
    -- UA: Отримуємо рівень RHM Пакету з конфігурації магазину (1=Standard, 4=Opti-Harvest)
    local pkgLevel = 1
    if self.configurations and self.configurations["rhmPackage"] then
        pkgLevel = tonumber(self.configurations["rhmPackage"]) or 1
    end
    spec.packageLevel = pkgLevel
    if rhm_Combine.debug then
        RHM_Debug.log("Combine", string.format("RHM: Installed Package Level: %d", pkgLevel))
    end
    
    -- EN: Detect machine type from FS25 specialization signals (verified from log analysis).
    --     Grain:  allowThreshingDuringRain=false and strawEffects.n>0
    --     Root:   spec_fruitPreparer present OR (cutter present, no pipe)
    --     Forage: allowThreshingDuringRain=true AND pipe AND no cutter
    --     Cotton: grain spec but fill unit stores FillType.COTTON
    -- UA: Визначаємо тип машини за сигналами спеціалізацій FS25 (підтверджено аналізом логів).
    --     Зернова: allowThreshingDuringRain=false і strawEffects.n>0
    --     Коренеплід: є spec_fruitPreparer АБО (є cutter, немає pipe)
    --     Форажна: allowThreshingDuringRain=true І pipe І немає cutter
    --     Бавовна: spec зернової але fill unit зберігає FillType.COTTON

    local machineType = "grain"  -- safe default
    local sc = self.spec_combine

    if sc then
        -- EN: Detection Priorities:
        -- 1. Explicit harvester specializations (ForageHarvester / CottonPicker / RootHarvester)
        -- 2. Physical features (Straw effects = Grain combine)
        -- 3. Capability signals (Rain work + Pipe + No Cutter = Forage)
        
        local isForageHarvester = SpecializationUtil.hasSpecialization(ForageHarvester, self.specializations)
        -- EN: FS25 API: iterate fill units to check if any supports COTTON (getFillUnitIndexByFillType does not exist in FS25).
        -- UA: API FS25: ітеруємо fill units щоб перевірити чи будь-яка підтримує COTTON (getFillUnitIndexByFillType не існує в FS25).
        local isCottonHarvester = false
        if FillType.COTTON then
            local fillUnits = self:getFillUnits()
            if fillUnits then
                for _, fillUnit in ipairs(fillUnits) do
                    if fillUnit.supportedFillTypes and fillUnit.supportedFillTypes[FillType.COTTON] then
                        isCottonHarvester = true
                        break
                    end
                end
            end
        end
        local hasStrawEffects = sc.strawEffects and #sc.strawEffects > 0
        local canThreshInRain = sc.allowThreshingDuringRain

        if self.spec_fruitPreparer then
            -- Cleaning / dirt removal → Root harvester
            machineType = "root"
        elseif isForageHarvester then
            machineType = "forage"
        elseif isCottonHarvester then
            machineType = "cotton"
        elseif hasStrawEffects then
            -- Grain combine always has straw effects, regardless of rain capability
            machineType = "grain"
        elseif canThreshInRain then
            local hasPipe   = self.spec_pipe   ~= nil
            local hasCutter = self.spec_cutter ~= nil

            if hasPipe and not hasCutter then
                -- Forage harvester fallback (if spec check failed)
                machineType = "forage"
            elseif hasCutter and not hasPipe then
                -- Direct-cut vegetable harvester
                machineType = "root"
            else
                machineType = "root"
            end
        else
            -- Unknown: treat as grain
            machineType = "grain"
        end
    end

    spec.machineType = machineType
    RHM_Debug.log("Combine", string.format("RHM: [OK] Machine type detected: %s (pipe=%s, cutter=%s, rainOK=%s, fruitPrep=%s)",
        machineType,
        tostring(self.spec_pipe ~= nil),
        tostring(self.spec_cutter ~= nil),
        tostring(sc and sc.allowThreshingDuringRain),
        tostring(self.spec_fruitPreparer ~= nil)))


    -- EN: Create the combine memory system for current settings. Link it to LoadCalculator
    --     so that setting adjustments affect the live load and loss calculations.
    -- UA: Створюємо систему пам'яті для поточних налаштувань. Підключаємо до LoadCalculator
    --     щоб регулювання налаштувань впливало на поточні розрахунки навантаження і втрат.
    spec.combineMemory = CombineMemory.new(self, machineType)
    spec.loadCalculator.combineMemory = spec.combineMemory
    RHM_Debug.log("Combine", "RHM: [OK] Combine Settings System initialized")

    
    -- EN: HUD live data table — all fields are updated every tick on the server and synced to clients.
    -- UA: Таблиця живих даних HUD — всі поля оновлюються кожний тік на сервері і синхронізуються на клієнти.
    spec.data = {
        speed = 0,
        load = 0,
        cropLoss = 0,
        tonPerHour = 0,
        litersPerHour = 0,
        yield = 0,
        recommendedSpeed = 0,  -- EN: Updated by server tick, synced to clients / UA: Оновлюється сервером, синхронізується на клієнти
        overloadLevel = 0      -- EN: 0=normal, 1=HIGH (120%+), 2=CRITICAL (150%+) — synced for warning display / UA: 0=норма, 1=ВИСОКЕ (120%+), 2=КРИТИЧНЕ (150%+)
    }
    
    -- Лічильник для збереження площі з addCutterArea
    spec.lastArea = 0
    spec.lastLiters = 0  -- Літри зібраного врожаю
    
    -- Відстеження поточної жатки для визначення зміни
    spec.currentCutter = nil
    
    -- Прапорець чи активне обмеження швидкості
    spec.isSpeedLimitActive = false
    
    -- MULTIPLAYER: Dirty flags для роздільної синхронізації
    -- spec.dataDirtyFlag: часто оновлювана телеметрія (throttle)
    -- spec.settingsDirtyFlag: зміни налаштувань CombineMemory (тільки при зміні)
    spec.dataDirtyFlag = self:getNextDirtyFlag()
    spec.settingsDirtyFlag = self:getNextDirtyFlag()
    spec.dirtyFlag = spec.dataDirtyFlag -- Fallback if needed
    
    -- Тротлінг мережевих оновлень (MP/DS)
    spec.lastDataUpdateTime = 0
    spec.dataUpdateInterval = 200 -- 5 разів на секунду
    spec.lastSyncedData = {}
    
    -- INPUT: Таблиця для подій введення
    spec.actionEvents = {}
    
    -- TEST: Прапорець для показу тестового повідомлення
    spec.testMessageShown = false
end

-- EN: Override for addFillUnitFillLevel — tracks actual liters added to the bunker (hopper).
--     Only counts when actively cutting (lastRawArea > 0) to avoid counting offloading.
--     The fill type is captured for yield density lookup.
-- UA: Перевизначення addFillUnitFillLevel — відстежує фактичні літри додані до бункера (бункеру).
--     Рахує лише при активному косінні (lastRawArea > 0) щоб не рахувати вивантаження.
--     Тип врожаю захоплюється для пошуку густини врожаю.
function rhm_Combine:addFillUnitFillLevel(superFunc, ...)
    local r1, r2, r3, r4, r5, r6 = superFunc(self, ...)
    local actualAdded = r1 -- Base game returns actual delta as first arg
    
    local spec = self.spec_rhm_Combine
    if spec and actualAdded and type(actualAdded) == "number" and actualAdded > 0 then
        -- Рахуємо тільки якщо ми активно косимо (lastRawArea > 0)
        if spec.lastRawArea and spec.lastRawArea > 0 then
            spec.lastLiters = (spec.lastLiters or 0) + actualAdded
            
            local farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData = ...
            if fillTypeIndex and fillTypeIndex ~= FillType.UNKNOWN then
                 spec.lastFillType = fillTypeIndex
            end
        end
    end
    
    return r1, r2, r3, r4, r5, r6
end

-- EN: Override for addCutterArea — intercepts the raw (pixel-count) cutting area per tick.
--     Converts pixels to square meters using g_currentMission:getFruitPixelsToSqm().
--     Also captures fallback liters from the return value for forage harvesters without hoppers.
-- UA: Перевизначення addCutterArea — перехоплює сиру (піксельну) площу зрізу за тік.
--     Перетворює пікселі в квадратні метри з допомогою g_currentMission:getFruitPixelsToSqm().
--     Також зберігає запасні літри з поверненого значення для форажних комбайнів без бункера.
function rhm_Combine:addCutterArea(superFunc, ...)
    local area, realArea, inputFruitType, outputFillType, strawRatio, strawGroundType, farmId, cutterLoad = ...
    
    -- EN: Call super first to get the real data (liters, crop type) before we intercept.
    -- UA: Викликаємо super спочатку щоб отримати реальні дані (літри, тип культури) перед перехопленням.
    local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 = superFunc(self, ...)
    local retLiters = r1
    
    local spec = self.spec_rhm_Combine
    if not spec or not spec.loadCalculator then
        return r1, r2, r3, r4, r5, r6, r7, r8, r9, r10
    end
    
    -- EN: lastMultiplier kept for compatibility with older logic paths.
    -- UA: lastMultiplier збережено для сумісності зі старими логічними шляхами.
    local multiplier = 1.0
    
    -- EN: Convert 'area' (pixel-count) to real square metres using the mission's pixel-to-sqm ratio.
    --     This reliable formula works independently of map scale and Precision Farming bonuses.
    -- UA: Конвертуємо 'area' (кількість пікселів) у реальні квадратні метри використовуючи коефіцієнт місії.
    --     Ця надійна формула працює незалежно від масштабу карти і бонусів Precision Farming.
    local sqmMultiplier = 1.0
    if g_currentMission and type(g_currentMission.getFruitPixelsToSqm) == "function" then
        sqmMultiplier = g_currentMission:getFruitPixelsToSqm()
    end
    
    local areaForYield = area * sqmMultiplier
    
    -- EN: Accumulate area for LoadCalculator and yield monitor separately.
    -- UA: Накопичуємо площу окремо для LoadCalculator і монітора врожайності.
    spec.lastArea = (spec.lastArea or 0) + (areaForYield * multiplier)
    spec.lastRawArea = (spec.lastRawArea or 0) + areaForYield
    spec.lastMultiplier = multiplier
    
    -- EN: Save fallback liters from the return value for forage harvesters without hoppers.
    --     If there's a hopper, addFillUnitFillLevel will capture precise liters instead.
    -- UA: Зберігаємо запасні літри з поверненого значення для форажних комбайнів без бункера.
    --     Якщо бункер є, addFillUnitFillLevel перехопить точні літри натомість.
    if (retLiters or 0) > 0 then
        spec._fallbackLiters = (spec._fallbackLiters or 0) + retLiters
    end
    
    -- EN: Store crop type and handle change
    -- UA: Зберігаємо тип культури та обробляємо зміну
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

        -- EN: Determine crop name from CombineSettingsDatabase — full table including
        --     grain, roots (POTATO/ONION/CARROT), vegetables (SPINACH/GREENBEAN), and forage outputs.
        -- UA: Визначаємо назву культури через CombineSettingsDatabase — повна таблиця включаючи
        --     зернові, коренеплоди (POTATO/ONION/CARROT), овочі (SPINACH/GREENBEAN) та форажні виводи.
        local cropName = CombineSettingsDatabase:getCropNameFromFillType(outputFillType)
        
        -- EN: Fallback for forage harvesters: they output CHAFF but inputFruitType=MAIZE.
        --     getCropNameFromFillType(CHAFF) returns "MAIZE_FORAGE" usually, but try inputFruitType if not.
        -- UA: Резервний варіант для форажних комбайнів: вони виводять CHAFF але inputFruitType=MAIZE.
        --     getCropNameFromFillType(CHAFF) зазвичай повертає "MAIZE_FORAGE", але спробуємо inputFruitType якщо ні.
        if not cropName and inputFruitType and inputFruitType ~= FillType.UNKNOWN then
            cropName = CombineSettingsDatabase:getCropNameFromFillType(inputFruitType)
        end
        
        if cropName then
            -- EN: Update current crop in LoadCalculator.
            -- UA: Оновлюємо поточну культуру в LoadCalculator.
            spec.loadCalculator.currentCrop = cropName
            
            -- EN: Detect crop change with 2-second debounce to avoid thrash when header
            --     partially overlaps two crop types and flips between them each tick.
            -- UA: Визначаємо зміну культури з 2-секундним захистом від дребезгу щоб уникнути
            --     переключення коли жатка частково перекриває два типи культур і перемикає між ними кожен тік.
            if cropName ~= spec.combineMemory.currentCrop then
                -- DEBOUNCE: чекаємо 2 секунди перед перемикання
                -- Без цього жатка може детектувати різні культури кожен тік і створювати петлю
                local now = g_currentMission.time
                spec._lastCropSwitchTime = spec._lastCropSwitchTime or 0
                
                if spec._pendingCrop ~= cropName then
                    -- EN: New crop candidate detected / UA: Виявлено нового кандидата
                    spec._pendingCrop = cropName
                    spec._lastCropSwitchTime = now
                elseif (now - spec._lastCropSwitchTime) >= 2000 then
                    -- EN: Confirmed after 2 seconds / UA: Підтверджено після 2 секунд
                    spec._pendingCrop = nil
                    if rhm_Combine and rhm_Combine.debug then
                        RHM_Debug.log("Combine", string.format("RHM: [CROP] Detected crop: %s", cropName))
                    end
                    rhm_Combine.onCropTypeChanged(self, cropName)
                end
            else
                -- EN: Same crop, cancel any staged switch.
                -- UA: Та сама культура, скасовуємо заплановане перемикання.
                spec._pendingCrop = nil
            end
        end
    else
        -- EN: No crop coming through (not harvesting) — clear staged crop.
        -- UA: Не надходить культура (не збираємо) — очищаємо плановану культуру.
        spec._pendingCrop = nil
    end
    
    -- DEBUG: Uncomment to see values in console
    -- if (retLiters or 0) > 0 and areaForYield > 0 then
    --    local areaHa = areaForYield / 10000
    --    local yieldL_Ha = retLiters / areaHa
    --    RHM_Debug.log("Combine", string.format("RHM YIELD DEBUG: Liters=%.2f, Area=%.4f m2, Yield=%.0f L/ha", 
    --        retLiters, areaForYield, yieldL_Ha))
    -- end
    
    return r1, r2, r3, r4, r5, r6, r7, r8, r9, r10
end

-- EN: Called when the detected crop type changes. Delegates to CombineMemory:switchCrop which
--     saves the old profile, loads the new one, and triggers network sync.
--     Does NOT set currentCrop directly — switchCrop handles all state transitions.
-- UA: Викликається при зміні визначеного типу культури. Делегує до CombineMemory:switchCrop який
--     зберігає старий профіль, завантажує новий та запускає мережеву синхронізацію.
--     НЕ встановлює currentCrop напряму — switchCrop обробляє всі переходи стану.
function rhm_Combine:onCropTypeChanged(newCropName)
    local spec = self.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return
    end
    
    -- EN: Delegate to switchCrop — it sets currentCrop, saves old profile, loads new one.
    --     Do NOT set currentCrop here directly!
    -- UA: Делегуємо до switchCrop — він встановлює currentCrop, зберігає старий, завантажує новий.
    --     НЕ встановлювати currentCrop тут напряму!
    spec.combineMemory:switchCrop(newCropName)
    
    -- EN: Sync crop change and settings to clients in multiplayer.
    -- UA: Синхронізуємо зміну культури та налаштувань для клієнтів у мультиплеєрі.
    if self.isServer then
        self:raiseDirtyFlags(spec.dirtyFlag)
    end
end

-- EN: Override for getSpeedLimit. Returns a dynamically calculated speed cap from LoadCalculator
--     that maintains ~90% engine load target. Disabled on clients (uses synced recommendedSpeed).
--     Respects the Arcade difficulty mode (no speed limiting), the enableSpeedLimit setting,
--     and only activates when the cutter is actually lowered and working.
-- UA: Перевизначення getSpeedLimit. Повертає динамічний ліміт швидкості від LoadCalculator
--     який підтримує ~90% навантаження двигуна. Вимкнено на клієнтах (використовує synced recommendedSpeed).
--     Поважає режим складності Arcade (без обмеження швидкості), налаштування enableSpeedLimit,
--     та активується лише коли жатка реально опущена і працює.
function rhm_Combine:getSpeedLimit(superFunc, onlyIfWorking)
    local spec = self.spec_rhm_Combine
    
    -- EN: Call original to get the game's base speed limit and check flag.
    -- UA: Викликаємо оригінал щоб отримати базовий ліміт швидкості гри і прапорець перевірки.
    local limit, doCheckSpeedLimit = superFunc(self, onlyIfWorking)
    
    -- EN: If spec not initialized (vehicle loading), return original limit unchanged.
    -- UA: Якщо spec не ініціалізований (завантаження транспорту), повертаємо оригінальний ліміт без змін.
    if not spec or not spec.loadCalculator then
        return limit, doCheckSpeedLimit
    end
    
    -- EN: Skip speed limiting if the thresher is off.
    -- UA: Пропускаємо обмеження швидкості якщо молотарка вимкнена.
    if not self:getIsTurnedOn() then
        spec.isSpeedLimitActive = false
        return limit, doCheckSpeedLimit
    end
    
    -- EN: CRITICAL FIX: Check if the cutter is actually WORKING (not just attached).
    --     If the cutter is raised or not cutting — do NOT limit speed.
    --     Same check as onUpdateTick: isTurnedOn + speed > 0.5 + lowered (or allowCuttingWhileRaised).
    -- UA: КРИТИЧНЕ ВИПРАВЛЕННЯ: Перевіряємо чи жатка дійсно ПРАЦЮЄ (не просто прикріплена).
    --     Якщо жатка піднята або не косить — НЕ обмежуємо швидкість.
    --     Та ж перевірка що й у onUpdateTick: isTurnedOn + speed > 0.5 + опущена (або allowCuttingWhileRaised).
    local spec_combine = self.spec_combine
    local cutterIsWorking = false
    
    if spec_combine and spec_combine.attachedCutters then
        for cutter, _ in pairs(spec_combine.attachedCutters) do
            if cutter.spec_cutter then
                local spec_cutter = cutter.spec_cutter
                -- FIX: Use same check as onUpdateTick - do NOT check movingDirection,
                -- as Courseplay can set it differently. Only check isTurnedOn + speed + isLowered.
                cutterIsWorking = cutter:getIsTurnedOn()
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
    
    -- EN: Check if speed limiting is enabled in settings.
    -- UA: Перевіряємо чи увімкнено обмеження швидкості в налаштуваннях.
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        if not g_realisticHarvestManager.settings.enableSpeedLimit then
            spec.isSpeedLimitActive = false
            return limit, doCheckSpeedLimit
        end
        
        -- EN: In Arcade difficulty mode, don't limit speed (like vanilla game).
        -- UA: В режимі складності Arcade не обмежуємо швидкість (як у ванільній грі).
        if g_realisticHarvestManager.settings.difficultyMotor == 1 then -- DIFFICULTY_ARCADE
            spec.isSpeedLimitActive = false
            return limit, doCheckSpeedLimit
        end
    end
    
    -- EN: If the cutter changed, reset genuineSpeedLimit to recalibrate for the new header's speed range.
    -- UA: Якщо жатка змінилась, скидаємо genuineSpeedLimit для рекалібрування під новий діапазон швидкостей.
    if spec_combine and spec_combine.attachedCutters then
        local currentCutter = nil
        for cutter, _ in pairs(spec_combine.attachedCutters) do
            currentCutter = cutter
            break -- Беремо першу жатку
        end
        
        -- Якщо жатка змінилася, скидаємо genuineSpeedLimit
        if currentCutter ~= spec.currentCutter and currentCutter ~= nil then
            spec.currentCutter = currentCutter
            spec.loadCalculator.genuineSpeedLimit = -1 -- EN: Reset to initial value / UA: Скидаємо до початкового значення
        end
    end
    
    -- EN: Set genuineSpeedLimit ONCE from the game's max speed cap (1.5x game limit, min 18 km/h).
    --     This cap is the ceiling — our dynamic limit oscillates below it.
    -- UA: Встановлюємо genuineSpeedLimit ОДИН РАЗ з максимального ліміту гри (1.5x ліміту, мін. 18 км/год).
    --     Цей стеля — наш динамічний ліміт коливається нижче нього.
    if spec.loadCalculator.genuineSpeedLimit == -1 and limit ~= math.huge then
        -- EN: Use vanilla game limit as absolute cap (no speed bonus) / UA: Ванільний ліміт як абсолютна межа (без бонусів)
        spec.loadCalculator:setGenuineSpeedLimit(limit, limit)
    end
    
    -- EN: MULTIPLAYER FIX: LoadCalculator only runs on the server.
    --     Clients must use the synced spec.data.recommendedSpeed value.
    -- UA: ВИПРАВЛЕННЯ МУЛЬТИПЛЕЕРА: LoadCalculator оновлюється лише на сервері.
    --     Клієнти повинні використовувати синхронізоване значення spec.data.recommendedSpeed.
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
    
    -- EN: ALWAYS apply the calculated limit, BUT NEVER exceed vanilla game limits (ModHub requirement).
    --     This ensures root harvesters (like Dewulf) don't run at 11km/h when their base workspeed is 8km/h.
    -- UA: ЗАВЖДИ застосовуємо розрахований ліміт, АЛЕ НІКОЛИ не перевищуємо ванільні ліміти гри (вимога ModHub).
    --     Це гарантує, що коренезбиральні комбайни (як Dewulf) не їдуть 11 км/год, коли їх базова робоча швидкість 8 км/год.
    spec.isSpeedLimitActive = true
    
    -- MODHUB FIX: Cap speed to the game's actual base limit
    limit = math.min(limit, calculatedLimit)
    
    -- Логуємо тільки коли РЕАЛЬНО обмежуємо
    if not self._lastLimitLog or math.abs(self._lastLimitLog - limit) > 0.5 then
        -- Logging.info("RHM: [getSpeedLimit] *** LIMITING SPEED to %.1f km/h (load: %.1f%%) ***", 
        --     limit, engineLoad)
        self._lastLimitLog = limit
    end
    
    return limit, doCheckSpeedLimit
end

-- EN: Override for getCanBeTurnedOn. Blocks thresher start if any attached cutter is not ready
--     (e.g. a folded header that hasn't been unfolded). Falls back to vanilla logic if no cutters.
-- UA: Перевизначення getCanBeTurnedOn. Блокує запуск молотарки якщо будь-яка прикріплена жатка
--     не готова (напр. складена жатка що не розкладена). Повертається до ванільної логіки без жаток.
function rhm_Combine:getCanBeTurnedOn(superFunc)
    local spec_combine = self.spec_combine
    
    -- EN: No cutters attached — use vanilla logic.
    -- UA: Немає прикріплених жаток — використовуємо ванільну логіку.
    if spec_combine.numAttachedCutters <= 0 then
        return superFunc(self)
    end
    
    -- EN: Check each attached cutter — if any is not ready (e.g. folded), block thresher start.
    -- UA: Перевіряємо кожну прикріплену жатку — якщо хоча б одна не готова (напр. складена), блокуємо запуск.
    for cutter, _ in pairs(spec_combine.attachedCutters) do
        if cutter ~= self and cutter.getCanBeTurnedOn ~= nil then
            -- EN: Use pcall to prevent infinite loops if cutter's getCanBeTurnedOn invokes the combine
            -- UA: Використовуємо pcall щоб уникнути нескінченних циклів
            local success, canTurnOn = pcall(cutter.getCanBeTurnedOn, cutter)
            if success and not canTurnOn then
                return false
            end
        end
    end

    return superFunc(self)
end

-- EN: Override for startThreshing. Conditionally starts attached cutters based on settings.
--     If Independent Launch is enabled: cutters only auto-start for AI (not the player).
--     If Independent Launch is disabled: cutters always auto-start (classic vanilla behavior).
--     Always plays threshing animations and sounds regardless of cutter start logic.
-- UA: Перевизначення startThreshing. Умовно запускає прикріплені жатки залежно від налаштувань.
--     Якщо Незалежний Запуск увімкнений: жатки автоматично запускаються лише для AI (не для гравця).
--     Якщо Незалежний Запуск вимкнений: жатки завжди запускаються автоматично (класична ванільна поведінка).
--     Завжди відтворює анімації та звуки молотарки незалежно від логіки запуску жатки.
function rhm_Combine:startThreshing(superFunc)
    -- EN: INTENTIONAL OMISSION OF superFunc(self)
    --     We DO NOT call superFunc(self) here. The game's vanilla startThreshing method automatically
    --     forces all attached cutters to turn on (and lowers them) for the player.
    --     By omitting it and replicating the animations/sounds manually, we enable the "Independent Launch"
    --     feature which allows players to control the thresher and cutter separately.
    -- UA: СВІДОМИЙ ПРОПУСК superFunc(self)
    --     Ми НЕ викликаємо superFunc(self). Ванільний метод автоматично запускає і опускає всі жатки гравця.
    --     Пропускаючи його і відтворюючи анімації вручну, ми робимо можливим "Незалежний запуск".
    local spec_combine = self.spec_combine
    
    -- EN: Read Independent Launch setting from manager.
    -- UA: Читаємо налаштування Незалежного Запуску з менеджера.
    local isIndependentLaunchEnabled = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isIndependentLaunchEnabled = g_realisticHarvestManager.settings.enableIndependentLaunch
    end
    
    -- EN: Cutter start logic:
    --     - Independent launch OFF → always start cutters (vanilla behavior)
    --     - Independent launch ON  → only start for AI workers
    -- UA: Логіка запуску жатки:
    --     - Незалежний запуск ВИМКНЕНИЙ → завжди запускаємо жатки (ванільна поведінка)
    --     - Незалежний запуск УВІМКНЕНИЙ → запускаємо лише для AI
    local isAIActive = self:getIsAIActive()
    local shouldStartCutters = (not isIndependentLaunchEnabled) or (isIndependentLaunchEnabled and isAIActive)
    
    if spec_combine.numAttachedCutters > 0 and shouldStartCutters then
        -- EN: Start cutters — always for AI, for player only when Independent Launch is disabled.
        -- UA: Запускаємо жатки — завжди для AI, для гравця лише коли Незалежний Запуск вимкнений.
        local isTurning = type(self.rootVehicle.getAIFieldWorkerIsTurning) == "function" and self.rootVehicle:getAIFieldWorkerIsTurning()
        local allowLowering = not self:getIsAIActive() or not isTurning
        
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

-- EN: Override for stopThreshing. Stops threshing sounds/animations and disables fill mode.
--     Does NOT stop cutters automatically (player controls them independently via Independent Launch).
-- UA: Перевизначення stopThreshing. Зупиняє звуки/анімації молотарки та вимикає режим наповнення.
--     НЕ вимикає жатки автоматично (гравець керує ними незалежно через Незалежний Запуск).
function rhm_Combine:stopThreshing(superFunc)
    -- EN: INTENTIONAL OMISSION OF superFunc(self)
    --     Like startThreshing, we DO NOT call superFunc(self) here to prevent the base game from 
    --     automatically turning off the attached cutters when the thresher stops.
    -- UA: СВІДОМИЙ ПРОПУСК superFunc(self)
    --     Як і в startThreshing, ми НЕ викликаємо superFunc(self) щоб завадити базовій грі
    --     автоматично вимикати жатки при зупинці молотарки.
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
    
    -- EN: Do NOT stop cutters automatically — player controls them independently.
    -- UA: НЕ вимикаємо жатки автоматично — гравець керує ними незалежно.
    
    if spec_combine.threshingStartAnimation ~= nil and spec_combine.playAnimation ~= nil then
        self:playAnimation(spec_combine.threshingStartAnimation, -spec_combine.threshingStartAnimationSpeedScale, self:getAnimationTime(spec_combine.threshingStartAnimation), true)
    end
    
    SpecializationUtil.raiseEvent(self, "onStopThreshing")
end

-- EN: Override for verifyCombine. Blocks harvesting when the thresher is off
--     (prevents collecting crop when only the cutter is running without the thresher).
--     AI is exempt from this check.
-- UA: Перевизначення verifyCombine. Блокує збирання врожаю коли молотарка вимкнена
--     (запобігає збору культури коли увімкнена лише жатка без молотарки).
--     AI звільнений від цієї перевірки.
function rhm_Combine:verifyCombine(superFunc, fruitType, outputFillType)
    local isAIActive = self:getIsAIActive()
    
    -- EN: Block harvesting if thresher is off (unless AI is active).
    -- UA: Блокуємо збирання якщо молотарка вимкнена (якщо тільки AI не активний).
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

-- EN: Called on every game tick. Runs warning checks on client, load/yield/speed calculations on server.
--     Server side: detects if thresher or cutter is off and resets HUD data accordingly.
--     Passes harvested mass and area to LoadCalculator for physics-based engine load calculation.
-- UA: Викликається кожен тік гри. Запускає перевірки попереджень на клієнті, розрахунки навантаження/врожайності/швидкості на сервері.
--     Серверна сторона: визначає якщо молотарка або жатка вимкнена і скидає дані HUD відповідно.
--     Передає зібрану масу та площу до LoadCalculator для фізичного розрахунку навантаження двигуна.
function rhm_Combine:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    -- EN: Client-side: update safety warnings only.
    -- UA: Клієнтська сторона: лише оновлення попереджень безпеки.
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
    
    -- EN: Check if combine thresher is on and driving forward; reset load if not.
    -- UA: Перевіряємо чи молотарка увімкнена і рухається вперед; скидаємо навантаження якщо ні.
    if not self:getIsTurnedOn() or self.movingDirection == -1 then
        -- EN: Thresher off or reversing — reset load calculation.
        -- UA: Молотарка вимкнена або рухається назад — скидаємо розрахунок навантаження.
        spec.loadCalculator:reset()
        if spec.data then
            spec.data.load = 0
        end
        spec.isSpeedLimitActive = false
        return
    end
    
    -- EN: Check if the cutter is working. Uses same logic as getSpeedLimit:
    --     isTurnedOn AND speed > 0.5 AND lowered (or allowCuttingWhileRaised).
    --     Avoids movingDirection check that Courseplay can break.
    -- UA: Перевіряємо чи жатка працює. Використовує ту ж логіку що й getSpeedLimit:
    --     isTurnedOn І speed > 0.5 І опущена (або allowCuttingWhileRaised).
    --     Уникає перевірки movingDirection яку Courseplay може порушити.
    local cutterIsTurnedOn = false
    for cutter, _ in pairs(spec_combine.attachedCutters) do
        if cutter.spec_cutter then
            local spec_cutter = cutter.spec_cutter
            if cutter:getIsTurnedOn() 
                and self:getLastSpeed() > 0.5 
                and (spec_cutter.allowCuttingWhileRaised or cutter:getIsLowered(true)) then
                cutterIsTurnedOn = true
                break  -- EN: Found a working cutter — exit / UA: Знайшли працюючу — виходимо
            end
        end
    end
    
    if not cutterIsTurnedOn then
        -- EN: Cutter not working — reset indicators so they don't stay visible.
        -- UA: Жатка не працює — скидаємо індикатори щоб вони не висіли.
        spec.loadCalculator:reset() 
        if spec.data then
            spec.data.load = 0 
            spec.data.cropLoss = 0
            spec.data.tonPerHour = 0
            spec.data.litersPerHour = 0
            spec.data.yield = 0
        spec.data.recommendedSpeed = 0 -- EN: Hide "/ X.X" from speed display / UA: Приховуємо "/ X.X" з відображення швидкості
        end
        spec.isSpeedLimitActive = false
        
        -- EN: Sync reset to clients so their HUD clears too.
        -- UA: Синхронізуємо скидання на клієнти щоб їх HUD теж очистився.
        self:raiseDirtyFlags(spec.dataDirtyFlag)
        
        return
    end
    
    -- EN: Crop detection was moved to addCutterArea with 2s debounce.
    --     Removed from onUpdateTick to prevent detection conflicts after bunker dump (false positives).
    -- UA: Детекція культури перенесена в addCutterArea з 2-сек захистом від дребезгу.
    --     Видалено з onUpdateTick щоб уникнути конфліктів після скидання бункера (хибні позитиви).
    
    -- EN: Calculate harvested mass from liters + fillType density. Forage harvesters use fallback liters.
    -- UA: Розраховуємо зібрану масу з літрів + густини fillType. Форажні комбайни використовують запасні літри.
    local massKg = 0
    local liters = spec.lastLiters or 0
    
    -- EN: Fall back to liters captured by addCutterArea for forage harvesters (no hopper).
    -- UA: Використовуємо запасні літри з addCutterArea для форажних комбайнів (без бункера).
    if liters <= 0 and (spec._fallbackLiters or 0) > 0 then
        liters = spec._fallbackLiters
    end
    
    if liters > 0 then
        if spec.lastFillType and g_fillTypeManager then
            local fillType = g_fillTypeManager:getFillTypeByIndex(spec.lastFillType)
            if fillType and fillType.massPerLiter then
                -- EN: IMPORTANT: massPerLiter in FS25 is stored in TONS per liter, so multiply by 1000 to get kg.
                -- UA: ВАЖЛИВО: massPerLiter в FS25 зберігається в ТОННАХ на літр, тому множимо на 1000 щоб отримати кг.
                massKg = liters * fillType.massPerLiter * 1000
            else
                massKg = liters * 0.75 -- EN: Fallback density / UA: Запасна густота
            end
        else
            massKg = liters * 0.75 -- EN: Fallback density / UA: Запасна густота
        end
    end
    
    -- EN: Use lastRawArea (actual geometric area) for yield calculation.
    -- UA: Використовуємо lastRawArea (реальну геометричну площу) для розрахунку врожайності.
    local areaForYield = spec.lastRawArea or spec.lastArea or 0 
    
    -- EN: Pass accumulated MASS to LoadCalculator (not area) — mass is the main driver now.
    -- UA: Передаємо накопичену МАСУ в LoadCalculator (не площу) — маса тепер основний показник.
    spec.loadCalculator:update(self, dt, massKg)
    
    -- EN: Update productivity and yield rolling average. Called even when not cutting
    --     so the t/h display smoothly fades to 0 between passes.
    -- UA: Оновлюємо ковзне середнє продуктивності та врожайності. Викликається навіть без косіння
    --     щоб показник т/год плавно падав до 0 між проходами.
    spec.loadCalculator:updateProductivityAndYield(massKg, liters, areaForYield, dt) 
    
    -- EN: Apply physical crop loss: remove lost grain from the fill unit on the server.
    --     This makes crop loss visible as a real reduction in tank fill level.
    -- UA: Застосовуємо фізичні втрати врожаю: видаляємо втрачене зерно з fill unit на сервері.
    --     Це робить втрати врожаю видимими як реальне зменшення рівня наповнення бункера.
    if liters > 0 and self.isServer then
        -- EN: Calculate total crop loss including settings deviation penalty.
        -- UA: Розраховуємо загальні втрати врожаю включаючи штраф за відхилення налаштувань.
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
                    
                    if rhm_Combine.debug then
                        RHM_Debug.log("Combine", string.format("RHM: [LOSS] Crop Loss Applied: %.1f L lost (%.1f%% of %.1f L harvest)",
                            lostLiters, cropLoss, liters))
                    end
                else
                    RHM_Debug.log("Combine", "RHM: Warning - Could not find fill unit for crop loss removal")
                end
            end
        end
    end
    -- ========================================================================
    
    -- EN: Reset all per-tick accumulators after processing.
    -- UA: Скидаємо всі накопичувачі за тік після обробки.
    spec.lastArea = 0
    spec.lastRawArea = 0
    spec.lastLiters = 0
    spec._fallbackLiters = 0
    
    -- EN: Update HUD live data table from LoadCalculator outputs.
    -- UA: Оновлюємо таблицю живих даних HUD з виводів LoadCalculator.
    if spec.data then
        spec.data.load = spec.loadCalculator:getEngineLoad()
        spec.data.cropLoss = spec.loadCalculator:calculateTotalCropLoss()
        spec.data.tonPerHour = spec.loadCalculator:getTonPerHour()
        spec.data.litersPerHour = spec.loadCalculator:getLitersPerHour() -- NEW: Volume flow
        spec.data.recommendedSpeed = spec.loadCalculator:getSpeedLimit()
        -- NEW: Yield Monitor Data
        spec.data.yield = spec.loadCalculator.currentYield or 0
    end
    
    -- === AI / COURSEPLAY WORKAROUND (Server Side) ===
    -- Courseplay uses its own speed controller that bypasses getSpeedLimit().
    -- We must enforce the requested speed limit directly on the motor.
    -- FIX: Only apply if the cutter is actually working (cutterIsTurnedOn from above)
    if self.isServer and self:getIsAIActive() and cutterIsTurnedOn then
        if self.spec_motorized and self.spec_motorized.motor then
            local motor = self.spec_motorized.motor
            local currentLimit = spec.loadCalculator:getSpeedLimit()
            
            -- EN: ALWAYS apply the calculated limit (both up and down).
            --     Previously we only called setSpeedLimit when lowering, so after a heavy windrow
            --     the motor limit stayed at 1-2 km/h permanently (Courseplay speed-lock bug).
            --     Cap at genuineSpeedLimit so we never restore above the original ceiling.
            -- UA: ЗАВЖДИ застосовуємо розрахований ліміт (і вниз, і вгору).
            --     Раніше ми викликали setSpeedLimit лише при зниженні, тому після важких рядків
            --     ліміт мотора назавжди залишався на 1-2 км/год (баг блокування швидкості Courseplay).
            --     Обмежуємо genuineSpeedLimit щоб не перевищити оригінальну стелю.
            local ceiling = spec.loadCalculator.genuineSpeedLimit
            if ceiling and ceiling > 0 then
                currentLimit = math.min(currentLimit, ceiling)
            end
            motor:setSpeedLimit(currentLimit)
        end
    end
    
    -- EN: OVERLOAD WARNING: Server determines level (0=normal, 1=HIGH 120%+, 2=CRITICAL 150%+).
    --     Displayed to whoever controls the combine — in SP that's the server; in DS it flows via streams.
    -- UA: ПОПЕРЕДЖЕННЯ ПЕРЕВАНТАЖЕННЯ: Сервер визначає рівень (0=норма, 1=ВИСОК. 120%+, 2=КРИТИЧ. 150%+).
    --     Відображається тому хто керує комбайном — у SP це сервер; у DS приходить через потоки.
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
    -- FIX: деякі DLC/мод-транспорти (напр. NH 8040) можуть не мати getIsControlled
    local isControlled = type(self.getIsControlled) == "function" and self:getIsControlled()
    if spec.data and isControlled then
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
            if g_realisticHarvestManager.settings.showLoadWarnings then
                g_currentMission:showBlinkingWarning(warnText, 3000)
            end
        end
    end
    -- === END OVERLOAD WARNING ===
    
    -- EN: MULTIPLAYER: Throttled dirty flag raising — only sync when data has changed significantly
    --     or at least once per second. Sensitivity thresholds reduce network traffic.
    -- UA: МУЛЬТИПЛЕЕР: Тротлінговий підйом dirty flag — синхронізуємо лише коли дані суттєво змінились
    --     або принаймні раз на секунду. Пороги чутливості зменшують мережевий трафік.
    if self.isServer then
        local now = g_currentMission.time
        local interval = spec.dataUpdateInterval or 200
        
        -- Перевіряємо чи пройшло достатньо часу
        if (now - spec.lastDataUpdateTime) >= interval then
            local data = spec.data
            local last = spec.lastSyncedData
            
            -- Перевіряємо чи є "суттєві" зміни
            local hasSignificantChange = false
            if last.load == nil then
                hasSignificantChange = true
            else
                -- Пороги чутливості для зменшення трафіку
                if math.abs((data.load or 0) - (last.load or 0)) > 2.0 then hasSignificantChange = true
                elseif math.abs((data.cropLoss or 0) - (last.cropLoss or 0)) > 0.5 then hasSignificantChange = true
                elseif math.abs((data.recommendedSpeed or 0) - (last.recommendedSpeed or 0)) > 0.2 then hasSignificantChange = true
                elseif math.abs((data.yield or 0) - (last.yield or 0)) > 0.1 then hasSignificantChange = true
                elseif data.overloadLevel ~= last.overloadLevel then hasSignificantChange = true
                end
            end
            
            -- Також форсуємо оновлення раз на секунду
            if hasSignificantChange or (now - spec.lastDataUpdateTime) >= 1000 then
                spec.lastDataUpdateTime = now
                spec.lastSyncedData.load = data.load
                spec.lastSyncedData.cropLoss = data.cropLoss
                spec.lastSyncedData.recommendedSpeed = data.recommendedSpeed
                spec.lastSyncedData.yield = data.yield
                spec.lastSyncedData.overloadLevel = data.overloadLevel
                
                self:raiseDirtyFlags(spec.dataDirtyFlag)
            end
        end
    end
end

-- EN: Called every frame when the player is in the combine.
--     HUD is drawn centrally in RealisticHarvestManager:draw() via hierarchy scanning,
--     so we don't draw here to avoid duplication.
-- UA: Викликається кожен кадр коли гравець в комбайні.
--     HUD малюється централізовано в RealisticHarvestManager:draw() через сканування ієрархії,
--     тому тут не малюємо — щоб уникнути дублювання.
function rhm_Combine:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
end

-- ============================================================================
-- SAVEGAME FUNCTIONS  
-- ============================================================================

-- EN: Saves combine settings (mode, currentCrop, fan/rotor/sieve/feeder values) to the savegame XML file.
--     Uses pcall for each setValue so schema validation errors don't crash the save.
-- UA: Зберігає налаштування комбайна (режим, поточна культура, значення вентилятора/ротора/решета/подачі) у XML файл збереження.
--     Використовує pcall для кожного setValue щоб помилки валідації схеми не падали при збереженні.
function rhm_Combine:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_rhm_Combine
    if not spec or not spec.combineMemory then return end
    
    local cur = key .. ".combineMemory.current"
    local mem = spec.combineMemory
    local settings = mem.currentSettings
    
    -- EN: Use pcall for each setValue to prevent schema validation crashes.
    -- UA: pcall для кожного setValue щоб помилки схеми не падали.
    local function safeSet(path, value)
        local ok, err = pcall(function() xmlFile:setValue(path, value) end)
        if not ok then
            RHM_Debug.log("Combine", "RHM: [SAVE] Warning - could not set " .. tostring(path) .. ": " .. tostring(err))
        end
    end
    
    safeSet(cur .. "#mode",       mem.mode or "AUTO")
    safeSet(cur .. "#autoSwitch", mem.autoSwitchEnabled ~= false)
    safeSet(cur .. "#currentCrop", mem.currentCrop or "")
    safeSet(cur .. "#fan",        settings.fan or 50)
    safeSet(cur .. "#upperSieve", settings.upperSieve or 50)
    safeSet(cur .. "#lowerSieve", settings.lowerSieve or 50)
    safeSet(cur .. "#rotor",      settings.rotor or 50)
    safeSet(cur .. "#feeder",     settings.feeder or 50)
    
    RHM_Debug.log("Combine", string.format("RHM: [SAVE] Saved combine state for %s", self:getName() or "?"))
end

---Завантаження стану з savegame файлу
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
    
    RHM_Debug.log("Combine", string.format("RHM: [LOAD] Loaded combine state for %s", self:getName() or "?"))
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
    
    -- CombineMemory settings
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
        
        -- Читаємо прапорці оновлення
        local hasDataUpdate = streamReadBool(streamId)
        local hasSettingsUpdate = streamReadBool(streamId)
        
        if hasDataUpdate then
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
        end

        if hasSettingsUpdate then
            -- CombineMemory settings
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
        local hasDataUpdate = bitAND(dirtyMask, spec.dataDirtyFlag) ~= 0
        local hasSettingsUpdate = bitAND(dirtyMask, spec.settingsDirtyFlag) ~= 0
        
        streamWriteBool(streamId, hasDataUpdate)
        streamWriteBool(streamId, hasSettingsUpdate)
        
        if hasDataUpdate then
            -- HUD data
            local data = spec.data or {}
            streamWriteFloat32(streamId, data.load or 0)
            streamWriteFloat32(streamId, data.cropLoss or 0)
            streamWriteFloat32(streamId, data.tonPerHour or 0)
            streamWriteFloat32(streamId, data.litersPerHour or 0)
            streamWriteFloat32(streamId, data.recommendedSpeed or 0)
            streamWriteFloat32(streamId, data.yield or 0)
            streamWriteUInt8(streamId, data.overloadLevel or 0)
        end

        if hasSettingsUpdate then
            -- CombineMemory settings
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




