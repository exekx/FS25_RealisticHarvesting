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
    return SpecializationUtil.hasSpecialization(Combine, specializations)
        or (ForageHarvester ~= nil and SpecializationUtil.hasSpecialization(ForageHarvester, specializations))
end

-- EN: Natively called by the engine during specialization registration.
--     Safely hooks the global savegame XML schema while it is fully accessible.
--     Fixes the "Path not registered" errors for dynamically added specs.
-- UA: Викликається рушієм нативно під час реєстрації спеціалізації.
--     Безпечно хукає глобальну XML схему збереження поки вона повністю доступна.
function rhm_Combine.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
    if schema ~= nil then
        local modName = g_currentModName or "FS25_RealisticHarvesting"
        local basePath = string.format("vehicles.vehicle(?).%s.rhm_Combine", modName)
        rhm_Combine.registerSavegameXMLPaths(schema, basePath)
        if type(schema.compile) == "function" then
            schema:compile()
        end
    end
end

-- EN: Registers rhm_Combine member functions on the Vehicle class.
-- UA: Реєструє функції-члени rhm_Combine на класі Vehicle.
function rhm_Combine.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "loadFromSavegame", rhm_Combine.loadFromSavegame)
end

-- EN: Registers rhm_Combine's overwritten (proxied) functions before event listeners.
--     These intercept combine core behaviors to inject our load and speed logic.
-- UA: Реєструє перевизначені (proxy) функції rhm_Combine до подій-прислухачів.
--     Ці функції перехоплюють основні поведінки комбайна для вбудованої логіки навантаження і швидкості.
function rhm_Combine.registerOverwrittenFunctions(vehicleType)
    rhm_log("RHM [Combine]: RHM: Registering overwritten functions for rhm_Combine")
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
    schema:register(XMLValueType.STRING, cur .. "#mode",            "Combine settings mode", "AUTO")
    schema:register(XMLValueType.STRING, cur .. "#currentCrop",     "Current crop", "")
    schema:register(XMLValueType.BOOL,   cur .. "#autoSwitch",      "Auto switch enabled", true)
    schema:register(XMLValueType.INT,    cur .. "#fan",             "Fan", 50)
    schema:register(XMLValueType.INT,    cur .. "#upperSieve",      "Upper sieve", 50)
    schema:register(XMLValueType.INT,    cur .. "#lowerSieve",      "Lower sieve", 50)
    schema:register(XMLValueType.INT,    cur .. "#rotor",           "Rotor", 50)
    schema:register(XMLValueType.INT,    cur .. "#feeder",          "Feeder", 50)
    schema:register(XMLValueType.INT,    cur .. "#targetEngineLoad", "Target engine load", 88)
    schema:register(XMLValueType.BOOL,   cur .. "#isCalibrated",    "Combine calibration status", true)
    schema:register(XMLValueType.STRING, cur .. "#calibratedCrops", "List of calibrated crops", "")
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
    rhm_log("RHM [Combine]: RHM: Registering event listeners for rhm_Combine")
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", rhm_Combine)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", rhm_Combine)
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

    -- LIFECYCLE: Видалення та вихід з техніки
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", rhm_Combine)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", rhm_Combine)
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
    
    -- Only register if the player is actively in this vehicle (even if an automated driver is active)
    local canRegister = isActiveForInputIgnoreSelection
        or vehicle.isActiveForInputIgnoreSelectionIgnoreAI
        or (vehicle.getIsEntered and vehicle:getIsEntered())

    if not canRegister then
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
    if InputAction.RHM_TOGGLE_HUD then
        local _, eventId = vehicle:addActionEvent(vehicle._rhmActionEvents, InputAction.RHM_TOGGLE_HUD, vehicle,
            function(self, ...)
                if g_realisticHarvestManager then
                    g_realisticHarvestManager:toggleHUD()
                end
            end, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
    end
end

-- Apply global hook ONCE (guard against double-loading)
if not rhm_Combine._nexatHookApplied then
    rhm_Combine._nexatHookApplied = true
    Vehicle.onRegisterActionEvents = Utils.appendedFunction(
        Vehicle.onRegisterActionEvents,
        RHM_globalOnRegisterActionEvents
    )
    rhm_log("RHM [Combine]: RHM: [NEXAT] Global Vehicle.onRegisterActionEvents hook applied.")
end

---EN: Safely gets or lazy-initializes RHM_CombineMemory to guarantee it is never nil.
---UA: Безпечно повертає або ліниво ініціалізує RHM_CombineMemory для гарантії захисту від nil.
function rhm_Combine.getOrInitCombineMemory(vehicle)
    if not vehicle then return nil end
    local spec = vehicle.spec_rhm_Combine
    if not spec then return nil end
    if not spec.combineMemory and RHM_CombineMemory then
        local mType = spec.machineType or "grain"
        spec.combineMemory = RHM_CombineMemory.new(vehicle, mType)
        if spec.loadCalculator then
            spec.loadCalculator.combineMemory = spec.combineMemory
        end
    end
    return spec.combineMemory
end
-- ============================================================================

-- EN: Called when the combine vehicle is loaded. Creates and wires up all subsystems:
--     RHM_LoadCalculator, machineType detection, RHM_CombineMemory, HUD data table, dirty flags,
--     and network throttling. Loads settings from XML if savegame exists.
-- UA: Викликається при завантаженні комбайна. Створює і підключає всі підсистеми:
--     RHM_LoadCalculator, визначення типу машини, RHM_CombineMemory, таблиця даних HUD, прапорці "dirty",
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

    spec.isRhmCombine = true
    
    -- Синхронізація дебаг-прапорця з основним менеджером — тепер просто rhm_log()
    rhm_log(string.format("RHM [Combine]: RHM: onLoad called for %s (has savegame: %s)", 
        tostring(self:getFullName()), tostring(savegame ~= nil)))
    
    -- Створюємо RHM_LoadCalculator з modDirectory
    local modDir = g_realisticHarvestManager and g_realisticHarvestManager.modDirectory or g_currentModDirectory
    
    if not RHM_LoadCalculator then
        Logging.error("RHM: RHM_LoadCalculator class is missing! Check script loading order.")
        return
    end

    spec.loadCalculator = RHM_LoadCalculator.new(modDir)
    
    if not spec.loadCalculator then
        Logging.error("RHM: Failed to create RHM_LoadCalculator for combine: %s", self:getFullName())
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
    rhm_log(string.format("RHM [Combine]: RHM: Installed Package Level: %d", pkgLevel))
    
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

    -- EN: 1. Check Store Item Category (Primary authority for machine classification)
    -- UA: 1. Перевіряємо категорію магазину (головний авторитет для класифікації техніки)
    local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
    local category = storeItem and storeItem.categoryName or ""
    local catLower = category:lower()
    local fullName = (self.getFullName and self:getFullName()) or ""
    local typeName = (self.typeName or (self.type and self.type.name) or ""):lower()

    if fullName:upper():find("NEXCO") or (self.configFileName and self.configFileName:lower():find("nexco")) then
        -- NEXAT NEXCO combine module is a grain combine harvester
        machineType = "grain"
    elseif category == "combines" or category == "combineVehicles" or category == "harvesters" then
        -- Grain combine harvesters: always grain, regardless of custom hopper fill types
        machineType = "grain"
    elseif category == "forageHarvesters" or category == "forageHarvesterVehicles" or category == "forageHarvesting" or catLower:find("forage") ~= nil or typeName:find("forage") ~= nil then
        machineType = "forage"
    elseif category == "cottonVehicles" or category == "cottonHarvesting" then
        machineType = "cotton"
    elseif category == "beetVehicles" or category == "beetHarvesting" 
       or category == "potatoVehicles" or category == "potatoHarvesting"
       or category == "vegetableVehicles" or category == "vegetableHarvesting"
       or category == "sugarCaneVehicles" or category == "sugarCaneHarvesting" then
        machineType = "root"
    elseif category == "grapeVehicles" or category == "grapeHarvesting" then
        if fullName:upper():find("OLIVE") or (self.configFileName and self.configFileName:lower():find("olive")) then
            machineType = "olive"
        else
            machineType = "grape"
        end
    elseif category == "oliveVehicles" or category == "oliveHarvesting" then
        machineType = "olive"
    else
        -- EN: 2. Fallback for unclassified / mod vehicles without standard store category
        -- UA: 2. Запасна перевірка для модової техніки без стандартної категорії магазину
        local hasGrainStraw = sc and sc.strawEffects and #sc.strawEffects > 0
        local isForageSpec = SpecializationUtil.hasSpecialization(ForageHarvester, self.specializations) or self.spec_forageHarvester ~= nil or typeName:find("forage") ~= nil
        local isFruitPrep = self.spec_fruitPreparer ~= nil

        if isForageSpec then
            machineType = "forage"
        elseif isFruitPrep then
            machineType = "root"
        elseif hasGrainStraw then
            machineType = "grain"
        else
            -- Check hopper/tank supported fill types
            local hasGrainFill = false
            local hasRootFill = false
            local hasCottonFill = false
            local hasGrapeFill = false
            local hasOliveFill = false
            local fillUnits = (type(self.getFillUnits) == "function" and self:getFillUnits()) 
                           or (self.spec_fillUnit and self.spec_fillUnit.fillUnits)
            if fillUnits then
                for _, fillUnit in ipairs(fillUnits) do
                    if fillUnit.supportedFillTypes then
                        for ftIndex, isSupp in pairs(fillUnit.supportedFillTypes) do
                            if isSupp then
                                local ft = g_fillTypeManager and g_fillTypeManager:getFillTypeByIndex(ftIndex)
                                if ft and ft.name then
                                    local name = string.upper(ft.name)
                                    if name == "WHEAT" or name == "BARLEY" or name == "OAT" or name == "CANOLA"
                                       or name == "SUNFLOWER" or name == "SOYBEAN" or name == "MAIZE" or name == "SORGHUM"
                                       or name == "RYE" or name == "TRITICALE" or name == "BUCKWHEAT" or name == "MILLET" then
                                        hasGrainFill = true
                                        break
                                    elseif name:find("POTATO") or name:find("BEET") or name:find("CARROT")
                                       or name:find("PARSNIP") or name:find("ONION") or name:find("GARLIC")
                                       or name:find("SPINACH") or name:find("GREENBEAN") or name:find("GREEN_BEAN")
                                       or name:find("SUGARCANE") or name:find("CABBAGE") then
                                        hasRootFill = true
                                    elseif name == "COTTON" then
                                        hasCottonFill = true
                                    elseif name:find("GRAPE") then
                                        hasGrapeFill = true
                                    elseif name:find("OLIVE") then
                                        hasOliveFill = true
                                    end
                                end
                            end
                        end
                    end
                    if hasGrainFill then break end
                end
            end

            if hasGrainFill then
                machineType = "grain"
            elseif hasCottonFill and not hasRootFill then
                machineType = "cotton"
            elseif hasRootFill then
                machineType = "root"
            elseif hasGrapeFill and not hasOliveFill then
                machineType = "grape"
            elseif hasOliveFill and not hasGrapeFill then
                machineType = "olive"
            elseif hasGrapeFill and hasOliveFill then
                if fullName:upper():find("OLIVE") or (self.configFileName and self.configFileName:lower():find("olive")) then
                    machineType = "olive"
                else
                    machineType = "grape"
                end
            elseif sc and sc.allowThreshingDuringRain and self.spec_pipe ~= nil and self.spec_cutter == nil then
                machineType = "forage"
            else
                machineType = "grain"
            end
        end
    end

    spec.machineType = machineType
    rhm_log(string.format("RHM [Combine]: RHM: [OK] Machine type detected: %s (pipe=%s, cutter=%s, rainOK=%s, fruitPrep=%s)",
        machineType,
        tostring(self.spec_pipe ~= nil),
        tostring(self.spec_cutter ~= nil),
        tostring(sc and sc.allowThreshingDuringRain),
        tostring(self.spec_fruitPreparer ~= nil)))

    -- EN: Create the combine memory system for current settings. Link it to RHM_LoadCalculator
    --     so that setting adjustments affect the live load and loss calculations.
    -- UA: Створюємо систему пам'яті для поточних налаштувань. Підключаємо до RHM_LoadCalculator
    --     щоб регулювання налаштувань впливало на поточні розрахунки навантаження і втрат.
    if not RHM_CombineMemory then
        Logging.error("RHM: RHM_CombineMemory class is missing! Check script loading order.")
        return
    end
    
    spec.combineMemory = RHM_CombineMemory.new(self, machineType)
    if not spec.combineMemory then
        Logging.error("RHM: Failed to create RHM_CombineMemory for combine: %s", self:getFullName())
        return
    end
    
    if spec.loadCalculator then
        spec.loadCalculator.combineMemory = spec.combineMemory
    end
    rhm_log("RHM [Combine]: RHM: [OK] Combine RHMSettings System initialized")

    
    -- EN: HUD live data table — all fields are updated every tick on the server and synced to clients.
    -- UA: Таблиця живих даних HUD — всі поля оновлюються кожний тік на сервері і синхронізуються на клієнти.
    spec.data = {
        speed = 0,
        load = 0,
        cropLoss = 0,
        tonPerHour = 0,
        litersPerHour = 0,
        hectaresPerHour = 0,
        yield = 0,
        recommendedSpeed = 0,  -- EN: Updated by server tick, synced to clients / UA: Оновлюється сервером, синхронізується на клієнти
        overloadLevel = 0,     -- EN: 0=normal, 1=HIGH (120%+), 2=CRITICAL (150%+) — synced for warning display / UA: 0=норма, 1=ВИСОКЕ (120%+), 2=КРИТИЧНЕ (150%+)
        moisture = 0           -- EN: Grain moisture (%) / UA: Вологість зерна (%)
    }
    
    -- Лічильник для збереження площі з addCutterArea
    spec.lastArea = 0
    spec.lastLiters = 0  -- Літри зібраного врожаю
    
    -- Відстеження поточної жатки для визначення зміни
    spec.currentCutter = nil
    spec._lastAiTunedCrop = nil
    spec._lastAiClientTunedCrop = nil
    
    -- Прапорець чи активне обмеження швидкості
    spec.isSpeedLimitActive = false
    
    -- MULTIPLAYER: Dirty flags для роздільної синхронізації
    -- spec.dataDirtyFlag: часто оновлювана телеметрія (throttle)
    -- spec.settingsDirtyFlag: зміни налаштувань RHM_CombineMemory (тільки при зміні)
    if type(self.getNextDirtyFlag) == "function" then
        spec.dataDirtyFlag = self:getNextDirtyFlag()
        spec.settingsDirtyFlag = self:getNextDirtyFlag()
    end
    spec.settingsDirtyFlag = spec.settingsDirtyFlag or spec.dataDirtyFlag
    spec.dirtyFlag = spec.dataDirtyFlag or spec.settingsDirtyFlag
    
    -- Тротлінг мережевих оновлень (MP/DS)
    spec.lastDataUpdateTime = 0
    spec.dataUpdateInterval = 200 -- 5 разів на секунду
    spec.lastSyncedData = {}
    
    -- INPUT: Таблиця для подій введення
    spec.actionEvents = {}
    
    -- TEST: Прапорець для показу тестового повідомлення
    spec.testMessageShown = false

    -- AUDIO: Звуки перевантаження та навантаження молотарки (клієнт)
    spec.samples = {}
    spec._rhmAlarmTimer = 1500

    if self.isClient then
        local modDir = (g_realisticHarvestManager and g_realisticHarvestManager.modDirectory)
                    or (g_currentModDirectory)
                    or ""
        local soundXmlPath = modDir .. "sounds/rhm_sounds.xml"
        local xmlSoundFile = loadXMLFile("rhmSounds", soundXmlPath)
        if xmlSoundFile ~= nil and xmlSoundFile ~= 0 then
            local soundManager = g_soundManager
            local audioGroup = AudioGroup.VEHICLE

            -- 1. Overload alarm buzzer (audible in both 1st and 3rd person)
            if soundManager.loadSample2DFromXML then
                spec.samples.overloadAlarm = soundManager:loadSample2DFromXML(xmlSoundFile, "sounds", "overloadAlarm", modDir, 1, audioGroup)
            end
            if spec.samples.overloadAlarm == nil then
                local components = self.components or { { node = self.rootNode } }
                spec.samples.overloadAlarm = soundManager:loadSampleFromXML(xmlSoundFile, "sounds", "overloadAlarm", modDir, components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
            end

            delete(xmlSoundFile)

            Logging.info("RHM [Sounds]: Initialized for %s (alarm=%s, group=%s)",
                tostring(self:getFullName()),
                tostring(spec.samples.overloadAlarm ~= nil),
                tostring(audioGroup))
        else
            Logging.warning("RHM [Sounds]: Could not open sound XML at: %s", tostring(soundXmlPath))
        end
    end

    -- EN: Restore saved combine settings from savegame if loading a saved game
    -- UA: Відновлюємо збережені налаштування комбайна з savegame при завантаженні збереження
    if savegame ~= nil then
        local ok, err = pcall(rhm_Combine.loadFromSavegame, self, savegame)
        if not ok then
            Logging.error("RHM: Error loading savegame for %s: %s", tostring(self:getFullName()), tostring(err))
        end
    end
end

-- EN: Post-load hook called after all vehicle components and attached implements are loaded.
--     Ensures savegame settings are restored if not already loaded during onLoad.
-- UA: Хук post-load, що викликається після завантаження всіх компонентів засобу та навісного обладнання.
--     Гарантує відновлення налаштувань збереження, якщо вони ще не були завантажені в onLoad.
function rhm_Combine:onPostLoad(savegame)
    if savegame ~= nil and not self._rhmSettingsLoadedFromSavegame then
        local ok, err = pcall(rhm_Combine.loadFromSavegame, self, savegame)
        if not ok then
            Logging.error("RHM: Error post-loading savegame for %s: %s", tostring(self:getFullName()), tostring(err))
        end
    end
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
        -- Рахуємо якщо ми активно косимо (lastRawArea > 0) або це увімкнений виноградо/оливкозбиральний комбайн
        local isGrapeOrOlive = (spec.machineType == "grape" or spec.machineType == "olive" 
            or (spec.combineMemory and (spec.combineMemory.machineType == "grape" or spec.combineMemory.machineType == "olive")))
        local isHarvestingActive = (spec.lastRawArea and spec.lastRawArea > 0) or (isGrapeOrOlive and self:getIsTurnedOn())
        if isHarvestingActive then
            -- EN: Cotton Harvester fix: Ignore massive instant internal transfers (e.g. spool unloading)
            -- UA: Фікс бавовняних комбайнів: ігноруємо масивні миттєві внутрішні переміщення (напр. розвантаження котушки)
            local isMassiveTransfer = false
            if actualAdded > 500 and spec.combineMemory and spec.combineMemory.machineType == "cotton" then
                isMassiveTransfer = true
            end
            
            if not isMassiveTransfer then
                spec.lastLiters = (spec.lastLiters or 0) + actualAdded
                
                local farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData = ...
                if fillTypeIndex and fillTypeIndex ~= FillType.UNKNOWN then
                     spec.lastFillType = fillTypeIndex
                end
                if fillUnitIndex then
                    spec.lastFillUnitIndex = fillUnitIndex
                end
            end
        end
    end
    
    return r1, r2, r3, r4, r5, r6
end

-- EN: Windrow pickup vs direct rotary/forage cutter — FS often reports GRASS_WINDROW fruit/fill even when
--     using a direct-cut header, which broke load factors (windrow is tuned separately from standing grass).
-- UA: Підбирач валка vs прямий рез — гра може давати GRASS_WINDROW і для стоячої трави.
function rhm_Combine.getForageFeedMode(vehicle)
    if not vehicle or not vehicle.getAttachedImplements then
        return "unknown"
    end
    local hasPickup = false
    local hasForageCutter = false
    for _, implement in pairs(vehicle:getAttachedImplements()) do
        local o = implement.object
        if o then
            local storeItem = g_storeManager:getItemByXMLFilename(o.configFileName)
            local cat = storeItem and storeItem.categoryName or ""
            if o.spec_forageHarvesterCutter ~= nil or o.spec_forageCutter ~= nil or cat == "forageHarvesterCutters" then
                hasForageCutter = true
            end
            if o.spec_pickup ~= nil or cat == "pickups" or cat == "slasher" then
                local isVegetableHarvester = false
                if cat == "vegetableVehicles" or cat == "onionHarvesters" or cat == "rootCropHarvesters" then
                    isVegetableHarvester = true
                end
                if not isVegetableHarvester and o.spec_fillUnit then
                    for _, fillUnit in ipairs(o.spec_fillUnit.fillUnits or {}) do
                        if fillUnit.supportedFillTypes then
                            for fillTypeIndex, _ in pairs(fillUnit.supportedFillTypes) do
                                local ft = g_fillTypeManager and g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                                if ft and ft.name then
                                    local ftName = string.upper(ft.name)
                                    if ftName == "ONION" or ftName == "ONION_DIRTY" or ftName == "CARROT" or ftName == "BEETROOT"
                                        or ftName == "PARSNIP" or ftName == "POTATO" then
                                        isVegetableHarvester = true
                                        break
                                    end
                                end
                            end
                        end
                        if isVegetableHarvester then break end
                    end
                end
                if not isVegetableHarvester then
                    local xml = string.lower(o.configFileName or "")
                    if xml:find("onion") or xml:find("carrot") or xml:find("beetroot") or xml:find("parsnip")
                        or xml:find("ur_") or xml:find("umr_") or xml:find("keiler") then
                        isVegetableHarvester = true
                    end
                end
                if not isVegetableHarvester then
                    hasPickup = true
                end
            end
        end
    end
    if hasPickup then
        return "pickup"
    end
    if hasForageCutter then
        return "direct"
    end
    -- EN: Some mod/vanilla headers only expose spec_cutter (no spec_forageHarvesterCutter).
    if vehicle.spec_rhm_Combine and vehicle.spec_rhm_Combine.combineMemory
        and vehicle.spec_rhm_Combine.combineMemory.machineType == "forage" then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            local o = implement.object
            if o and o.spec_cutter and not o.spec_pickup then
                return "direct"
            end
        end
    end
    return "unknown"
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
    --     Calculates physical cut area independently of environmental display scaling.
    -- UA: Конвертуємо 'area' (кількість пікселів) у реальні квадратні метри використовуючи коефіцієнт місії.
    --     Розраховує фізичну площу зрізу незалежно від масштабування інтерфейсу карти.
    -- EN: Pixel→m² factor is constant per mission; avoid calling native every harvest slice.
    -- UA: Коефіцієнт піксель→м² сталий для місії; не тягнемо натив на кожен зріз.
    local sqmMultiplier = 1.0
    local mission = g_currentMission
    if mission and type(mission.getFruitPixelsToSqm) == "function" then
        local cached = mission._rhmFruitPixelsToSqm
        if cached == nil then
            cached = mission:getFruitPixelsToSqm()
            mission._rhmFruitPixelsToSqm = cached
        end
        sqmMultiplier = cached or 1.0
    end
    
    local areaForYield = area * sqmMultiplier
    
    -- EN: Accumulate area for RHM_LoadCalculator and yield monitor separately.
    -- UA: Накопичуємо площу окремо для RHM_LoadCalculator і монітора врожайності.
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

        -- EN: Detect forage harvester feed mode (pickup vs direct cutter)
        -- UA: Визначаємо режим подачі форажного комбайна (підбирач чи прямий різ)
        local feedMode = rhm_Combine.getForageFeedMode(self)
        local isPickup = (feedMode == "pickup")

        -- EN: Determine crop name from RHM_CombineSettingsDatabase — full table including
        --     grain, roots (POTATO/ONION/CARROT), vegetables (SPINACH/GREENBEAN), and forage outputs.
        --     If harvesting windrows/straw or using a pickup header, never let ground fruit (e.g. underlying alfalfa)
        --     override the actual material collected.
        -- UA: Визначаємо назву культури через RHM_CombineSettingsDatabase.
        --     Якщо підбираємо валки/солому або жатка є підбирачем, ґрунтова культура під валком
        --     (напр. люцерна чи бур'ян) ніколи не повинна підміняти реальну зібрану солому.
        local effectiveInputFruitType = inputFruitType
        if isPickup or (outputFillType and (outputFillType == FillType.STRAW or outputFillType == FillType.GRASS_WINDROW or outputFillType == FillType.DRYGRASS_WINDROW)) then
            effectiveInputFruitType = nil
        end

        local cropName = RHM_CombineSettingsDatabase:getCropNameFromFillType(outputFillType, effectiveInputFruitType)

        -- EN: Forage harvester guard: Forage harvesters chop biomass and NEVER harvest grain MAIZE or grain CORN.
        -- UA: Захист для силосозбиральних комбайнів: вони рубають біомасу і НІКОЛИ не збирають зернову кукурудзу (MAIZE/CORN).
        local machineType = (spec.combineMemory and spec.combineMemory.machineType) or spec.machineType or "grain"
        if machineType == "forage" and (cropName == "MAIZE" or cropName == "CORN") then
            cropName = "MAIZE_FORAGE"
        end

        -- EN: CHAFF and SILAGE map to MAIZE_FORAGE in the DB — correct for corn silage but WRONG for
        --     direct grass/meadow silage (same output fill types in FS). That used factor ~0.30 and felt like
        --     unlimited speed (~15 km/h). Disambiguate using the combine's INPUT fruit from the cutter.
        -- UA: CHAFF/SILAGE у БД → MAIZE_FORAGE (кукурудза), але пряме косіння трави теж дає CHAFF — інакше фактор 0.3 і «літак».
        if cropName == "MAIZE_FORAGE" and effectiveInputFruitType and effectiveInputFruitType ~= FillType.UNKNOWN and effectiveInputFruitType ~= 0 then
            local inName = nil
            if g_fruitTypeManager then
                local fDesc = g_fruitTypeManager:getFruitTypeByIndex(effectiveInputFruitType)
                if fDesc and fDesc.name then
                    inName = string.upper(fDesc.name)
                end
            end
            if inName then
                if inName == "DRYGRASS" then
                    cropName = "DRYGRASS"
                elseif inName:find("WINDROW") then
                    if inName:find("DRY") then
                        cropName = "DRYGRASS_WINDROW"
                    else
                        cropName = "GRASS_WINDROW"
                    end
                elseif inName == "GRASS" or inName == "MEADOW" or inName == "TALLGRASS" or inName == "ALFALFA" or inName == "CLOVER" then
                    cropName = "GRASS"
                end
            else
                local alt = RHM_CombineSettingsDatabase:getCropNameFromFillType(effectiveInputFruitType)
                if alt == "GRASS" or alt == "DRYGRASS" or alt == "GRASS_WINDROW" or alt == "DRYGRASS_WINDROW" then
                    cropName = alt
                end
            end
        end
        
        -- EN: Fallback for forage harvesters: they output CHAFF but inputFruitType=MAIZE.
        --     getCropNameFromFillType(CHAFF) returns "MAIZE_FORAGE" usually, but try effectiveInputFruitType if not.
        -- UA: Резервний варіант для форажних комбайнів: вони виводять CHAFF але inputFruitType=MAIZE.
        --     getCropNameFromFillType(CHAFF) зазвичай повертає "MAIZE_FORAGE", але спробуємо effectiveInputFruitType якщо ні.
        if not cropName and effectiveInputFruitType and effectiveInputFruitType ~= FillType.UNKNOWN then
            cropName = RHM_CombineSettingsDatabase:getCropNameFromFillType(effectiveInputFruitType)
        end

        -- EN: Forage harvester feed mode disambiguation.
        --     FS25 reports outputFillType=GRASS_WINDROW for BOTH direct-cut grass AND pickup windrows.
        --     The key difference: direct-cut always has inputFruitType (e.g. GRASS), pickups have inputFruitType=nil.
        --     getForageFeedMode() can fail when pickup lacks spec_pickup, so we use inputFruitType as primary signal.
        -- UA: Визначення режиму подачі форажного комбайна.
        --     FS25 дає outputFillType=GRASS_WINDROW і для прямого різу трави, і для підбору валків.
        --     Ключова різниця: прямий різ завжди має inputFruitType (напр. GRASS), підбирач має inputFruitType=nil.
        --     getForageFeedMode() може помилитись коли підбирач не має spec_pickup, тому inputFruitType — головний сигнал.
        if cropName and spec.combineMemory and spec.combineMemory.machineType == "forage" then
            if cropName == "MAIZE" or cropName == "CORN" then
                cropName = "MAIZE_FORAGE"
            end
            local isPickupMode = isPickup or (effectiveInputFruitType == nil or effectiveInputFruitType == 0)
            
            if not isPickupMode then
                -- EN: Direct cut: force WINDROW → standing crop name so the heavier factor applies.
                --     FS25 often tags output as GRASS_WINDROW even for standing grass.
                -- UA: Прямий різ: примусово WINDROW → стояча культура для важчого коефіцієнта.
                if cropName == "GRASS_WINDROW" then
                    cropName = "GRASS"
                elseif cropName == "DRYGRASS_WINDROW" then
                    cropName = "DRYGRASS"
                end
            end
            -- EN: Pickup mode: cropName from getCropNameFromFillType(GRASS_WINDROW) is already correct
            --     ("GRASS_WINDROW" with factor 0.380, or "STRAW_WINDROW"). Do NOT override it.
            -- UA: Підбирач: cropName з getCropNameFromFillType вже правильний. НЕ перезаписуємо.
        end
        
        -- EN: HOPPER GROUND TRUTH:
        --     In FS25, a combine hopper can only hold ONE fill type at a time.
        --     If the hopper already contains grain (e.g. > 50 L of Sorghum), that is the authoritative
        --     crop being harvested. A momentary brush of a wide header against weeds or an adjacent field
        --     (e.g. brushing Field 28 Flax while harvesting Field 26 Sorghum) must NEVER override the active crop.
        -- UA: БЕЗУМОВНА ІСТИНА БУНКЕРА:
        --     У FS25 бункер комбайна може містити лише один тип врожаю.
        --     Якщо в бункері вже є зерно (> 50 л), це авторитетна культура збирання.
        --     Випадковий дотик краю широкої жатки до бур'янів чи сусіднього поля
        --     НІКОЛИ не повинен підміняти активну культуру.
        local fillUnitIndex = (self.spec_combine and self.spec_combine.fillUnitIndex) or 1
        local tankFillType = self:getFillUnitFillType(fillUnitIndex)
        local tankFillLevel = self:getFillUnitFillLevel(fillUnitIndex) or 0
        if (tankFillType == nil or tankFillType == FillType.UNKNOWN) and self.getFillUnitLastValidFillType then
            tankFillType = self:getFillUnitLastValidFillType(fillUnitIndex)
        end

        local tankCropName = nil
        if tankFillLevel > 50 and tankFillType and tankFillType ~= FillType.UNKNOWN then
            tankCropName = RHM_CombineSettingsDatabase:getCropNameFromFillType(tankFillType)
            if machineType == "forage" and (tankCropName == "MAIZE" or tankCropName == "CORN") then
                tankCropName = "MAIZE_FORAGE"
            end
        end

        if tankCropName then
            cropName = tankCropName
        end

        if cropName then
            -- EN: Update current crop in RHM_LoadCalculator.
            -- UA: Оновлюємо поточну культуру в RHM_LoadCalculator.
            spec.loadCalculator.currentCrop = cropName
            spec._lastHarvestTime = g_currentMission.time
            
            -- EN: Detect crop change with 2-second debounce to avoid thrash when header
            --     partially overlaps two crop types and flips between them each tick.
            -- UA: Визначаємо зміну культури з 2-секундним захистом від дребезгу щоб уникнути
            --     переключення коли жатка частково перекриває два типи культур і перемикає між ними кожен тік.
            local memory = spec.combineMemory or rhm_Combine.getOrInitCombineMemory(self)
            if memory and cropName ~= memory.currentCrop then
                if tankCropName then
                    -- EN: Hopper has grain -> instant authoritative switch without debounce delay!
                    -- UA: У бункері є зерно -> миттєве авторитетне перемикання без затримки дребезгу!
                    spec._pendingCrop = nil
                    rhm_log(string.format("RHM [Combine]: RHM: [CROP] Hopper contains %d L of %s -> instant sync active crop", math.floor(tankFillLevel), tankCropName))
                    rhm_Combine.onCropTypeChanged(self, tankCropName)
                else
                    -- EN: Empty hopper (or forage machine) -> 2-second debounce to prevent bouncing at borders
                    -- UA: Порожній бункер (або силосний комбайн) -> 2-секундний захист від перемикань на межах
                    local now = g_currentMission.time
                    spec._lastCropSwitchTime = spec._lastCropSwitchTime or 0
                    
                    if spec._pendingCrop ~= cropName then
                        -- EN: New crop candidate detected / UA: Виявлено нового кандидата
                        spec._pendingCrop = cropName
                        spec._lastCropSwitchTime = now
                    elseif (now - spec._lastCropSwitchTime) >= 2000 then
                        -- EN: Confirmed after 2 seconds / UA: Підтверджено після 2 секунд
                        spec._pendingCrop = nil
                        rhm_log(string.format("RHM [Combine]: RHM: [CROP] Detected crop: %s", cropName))
                        rhm_Combine.onCropTypeChanged(self, cropName)
                    end
                end
            else
                -- EN: Same crop, cancel any staged switch.
                -- UA: Та сама культура, скасовуємо заплановане перемикання.
                spec._pendingCrop = nil
            end
        end
    else
        -- EN: Only reset pending crop if harvesting has completely stopped for > 1500 ms.
        --     Do NOT reset on a single empty slice or micro-gap between plants!
        -- UA: Скидаємо плановану культуру тільки якщо збирання повністю припинилося на > 1500 мс.
        --     НЕ скидаємо на окремому порожньому зрізі чи мікро-паузі між стеблами!
        if g_currentMission and spec._lastHarvestTime and (g_currentMission.time - spec._lastHarvestTime > 1500) then
            spec._pendingCrop = nil
        end
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

-- EN: Called when the detected crop type changes. Delegates to RHM_CombineMemory:switchCrop which
--     updates the active crop and triggers network sync without altering physical settings.
--     Does NOT set currentCrop directly — switchCrop handles all state transitions.
---EN: Resolves the motorized carrier (self or root/attacher tractor) for modular machinery setups.
---UA: Визначає тяговий засіб (себе або кореневий/причіпний тягач) для модульних систем техніки.
function rhm_Combine.getMotorizedCarrier(vehicle)
    if not vehicle then return nil end
    if vehicle.spec_motorized and vehicle.spec_motorized.motor then
        return vehicle
    end
    local root = vehicle.rootVehicle or (vehicle.getRootVehicle and vehicle:getRootVehicle())
    if root and root.spec_motorized and root.spec_motorized.motor then
        return root
    end
    local attacher = vehicle.attacherVehicle or (vehicle.getAttacherVehicle and vehicle:getAttacherVehicle())
    if attacher and attacher.spec_motorized and attacher.spec_motorized.motor then
        return attacher
    end
    return vehicle
end

---EN: Checks if combine is currently driven by an automated worker or helper.
---UA: Перевіряє чи комбайном зараз керує наймит або автоматичний помічник.
function rhm_Combine.isAiWorkerActive(vehicle)
    if not vehicle then return false end
    if vehicle.getIsAIActive and vehicle:getIsAIActive() then
        return true
    end
    if vehicle.getIsCpActive and vehicle:getIsCpActive() then
        return true
    end
    if vehicle.cp and (vehicle.cp.isDriving or vehicle.cp.isFieldWorkActive) then
        return true
    end

    -- Check root or attacher carrier for modular/trailed combines (e.g. NEXAT carrier)
    local root = vehicle.rootVehicle or (vehicle.getRootVehicle and vehicle:getRootVehicle())
    if root and root ~= vehicle then
        if root.getIsAIActive and root:getIsAIActive() then return true end
        if root.getIsCpActive and root:getIsCpActive() then return true end
        if root.cp and (root.cp.isDriving or root.cp.isFieldWorkActive) then return true end
    end
    local attacher = vehicle.attacherVehicle or (vehicle.getAttacherVehicle and vehicle:getAttacherVehicle())
    if attacher and attacher ~= vehicle and attacher ~= root then
        if attacher.getIsAIActive and attacher:getIsAIActive() then return true end
        if attacher.getIsCpActive and attacher:getIsCpActive() then return true end
        if attacher.cp and (attacher.cp.isDriving or attacher.cp.isFieldWorkActive) then return true end
    end
    return false
end

-- EN: Called when the detected crop type changes. Delegates to RHM_CombineMemory:switchCrop which
--     updates the active crop and triggers network sync without altering physical settings.
--     Does NOT set currentCrop directly — switchCrop handles all state transitions.
-- UA: Викликається при зміні визначеного типу культури. Делегує до RHM_CombineMemory:switchCrop який
--     оновлює активну культуру та запускає мережеву синхронізацію без зміни фізичних налаштувань.
--     НЕ встановлює currentCrop напряму — switchCrop обробляє всі переходи стану.
function rhm_Combine:onCropTypeChanged(newCropName)
    local spec = self.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return
    end
    
    -- EN: Delegate to switchCrop — updates currentCrop without changing settings.
    -- UA: Делегуємо до switchCrop — оновлює currentCrop без зміни налаштувань.
    spec.combineMemory:switchCrop(newCropName)

    if spec.loadCalculator then
        spec.loadCalculator.currentCrop = newCropName
        local canonical = newCropName and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(newCropName) or newCropName
        local remembered = spec.loadCalculator.cropHarvestingSpeeds and (spec.loadCalculator.cropHarvestingSpeeds[canonical] or spec.loadCalculator.cropHarvestingSpeeds[newCropName])
        remembered = remembered or spec.loadCalculator.lastHarvestingSpeed or (spec.loadCalculator.speedLimit and spec.loadCalculator.speedLimit > 5.5 and spec.loadCalculator.speedLimit)
        if remembered and remembered > 0 then
            spec.loadCalculator.lastHarvestingSpeed = remembered
            spec.loadCalculator.speedLimit = remembered
            if spec.loadCalculator.cropHarvestingSpeeds then
                spec.loadCalculator.cropHarvestingSpeeds[canonical] = remembered
                spec.loadCalculator.cropHarvestingSpeeds[newCropName] = remembered
            end
        else
            local defaultEntry = 5.5
            if spec.loadCalculator.vanillaWorkingSpeed and spec.loadCalculator.vanillaWorkingSpeed < defaultEntry then
                defaultEntry = spec.loadCalculator.vanillaWorkingSpeed
            end
            if not spec.loadCalculator.speedLimit or spec.loadCalculator.speedLimit <= 0 then
                spec.loadCalculator.speedLimit = defaultEntry
            end
        end
    end

    -- EN: If an automated worker or helper is driving, auto-tune settings for this crop by tier
    -- UA: Якщо керує наймит або автоматичний помічник, автоматично калібруємо налаштування за рівнем обладнання
    if self.isServer and rhm_Combine.isAiWorkerActive(self) then
        spec._lastAiTunedCrop = newCropName
        spec.combineMemory:applyAiWorkerTuning(newCropName)
    end
    
    -- EN: Sync crop change and settings to clients in multiplayer.
    -- UA: Синхронізуємо зміну культури та налаштувань для клієнтів у мультиплеєрі.
    if self.isServer then
        if spec.settingsDirtyFlag and type(spec.settingsDirtyFlag) == "number" then
            self:raiseDirtyFlags(spec.settingsDirtyFlag)
        end
        if spec.dirtyFlag and type(spec.dirtyFlag) == "number" then
            self:raiseDirtyFlags(spec.dirtyFlag)
        end
    end
end

---EN: Checks if vehicle is driving or maneuvering in reverse. Harvesters NEVER harvest in reverse.
---UA: Перевіряє чи комбайн рухається або маневрує назад. Комбайни НІКОЛИ не збирають врожай заднім ходом.
function rhm_Combine.getIsVehicleReversing(vehicle)
    if not vehicle then
        return false
    end
    
    -- 1. Official Drivable query (reverser direction * moving direction)
    if vehicle.getIsDrivingBackward and vehicle:getIsDrivingBackward() then
        return true
    end
    if vehicle.getDrivingDirection and vehicle:getDrivingDirection() < 0 then
        return true
    end
    
    -- 2. Physical chassis moving direction (< 0 is reverse)
    if vehicle.movingDirection and vehicle.movingDirection < 0 then
        return true
    end
    
    -- 3. Hydrostatic / mechanical motor transmission direction
    if vehicle.spec_motorized and vehicle.spec_motorized.motor then
        local motor = vehicle.spec_motorized.motor
        if motor.currentDirection and motor.currentDirection < 0 then
            return true
        end
    end
    
    -- 4. User driving inputs (shuttle reverser / pedal / S key)
    local spec_drivable = vehicle.spec_drivable
    if spec_drivable then
        local revDir = spec_drivable.reverserDirection or 1
        local axis = spec_drivable.axisForward or 0
        if revDir < 0 and axis > 0.05 then
            return true
        elseif revDir > 0 and axis < -0.05 then
            return true
        end
    end

    -- 5. Carrier check for modular implements (e.g. NEXCO attached to NEXAT)
    if not (vehicle.spec_motorized and vehicle.spec_motorized.motor) and not vehicle.spec_drivable then
        local root = vehicle.rootVehicle or (vehicle.getRootVehicle and vehicle:getRootVehicle())
        if root and root ~= vehicle then
            if root.getIsDrivingBackward and root:getIsDrivingBackward() then return true end
            if root.getDrivingDirection and root:getDrivingDirection() < 0 then return true end
            if root.movingDirection and root.movingDirection < 0 then return true end
            if root.spec_motorized and root.spec_motorized.motor then
                local motor = root.spec_motorized.motor
                if motor.currentDirection and motor.currentDirection < 0 then return true end
            end
            if root.spec_drivable then
                local revDir = root.spec_drivable.reverserDirection or 1
                local axis = root.spec_drivable.axisForward or 0
                if revDir < 0 and axis > 0.05 then return true
                elseif revDir > 0 and axis < -0.05 then return true end
            end
        end
    end
    
    return false
end

-- EN: Override for getSpeedLimit. Returns a dynamically calculated speed cap from RHM_LoadCalculator
--     that maintains ~90% engine load target. Disabled on clients (uses synced recommendedSpeed).
--     Respects the Arcade difficulty mode (no speed limiting), the enableSpeedLimit setting,
--     and only activates when the cutter is actually lowered and working.
-- UA: Перевизначення getSpeedLimit. Повертає динамічний ліміт швидкості від RHM_LoadCalculator
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
    
    -- EN: If driving in reverse, harvesters NEVER harvest. Return vanilla limit immediately.
    --     Prevents transmission oscillation and jerking while backing up.
    -- UA: При русі заднім ходом комбайн НІКОЛИ не косить. Одразу повертаємо ванільний ліміт.
    --     Запобігає смиканню та розгойдуванню трансмісії при їзді назад.
    if rhm_Combine.getIsVehicleReversing(self) then
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
    local firstAttachedCutter = nil
    -- EN: Single pass: working check + first attached (for header-change detection).
    -- UA: Один прохід: перевірка роботи + перша жатка (для зміни хедера).
    if spec_combine and spec_combine.attachedCutters then
        for cutter, _ in pairs(spec_combine.attachedCutters) do
            if firstAttachedCutter == nil then
                firstAttachedCutter = cutter
            end
            if cutter.spec_cutter then
                local spec_cutter = cutter.spec_cutter
                if cutter:getIsTurnedOn()
                    and (spec_cutter.allowCuttingWhileRaised or cutter:getIsLowered(true)) then
                    cutterIsWorking = true
                    break
                end
            end
        end
    end
    
    -- EN: Support self-propelled machines where cutter is integrated directly on the vehicle (self.spec_cutter)
    -- UA: Підтримка самохідних машин де жатка вбудована безпосередньо в машину (self.spec_cutter)
    if not cutterIsWorking and self.spec_cutter then
        local spec_cutter = self.spec_cutter
        if self:getIsTurnedOn()
            and (spec_cutter.allowCuttingWhileRaised or self:getIsLowered(true)) then
            cutterIsWorking = true
        end
    end

    -- EN: Support self-propelled grape, olive, and straddle harvesters with integrated shaker tunnels
    -- UA: Підтримка самохідних виноградо- та оливкозбиральних комбайнів із вбудованими струшувачами
    if not cutterIsWorking and (spec.machineType == "grape" or spec.machineType == "olive"
        or (spec_combine and not next(spec_combine.attachedCutters) and self.spec_cutter == nil)) then
        if self:getIsTurnedOn() then
            cutterIsWorking = true
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
    if firstAttachedCutter ~= spec.currentCutter and firstAttachedCutter ~= nil then
        spec.currentCutter = firstAttachedCutter
        spec.loadCalculator.genuineSpeedLimit = -1 -- EN: Reset to initial value / UA: Скидаємо до початкового значення
    end
    
    -- EN: Set genuineSpeedLimit ONCE from the game's max speed cap (1.5x game limit, min 18 km/h).
    --     This cap is the ceiling — our dynamic limit oscillates below it.
    -- UA: Встановлюємо genuineSpeedLimit ОДИН РАЗ з максимального ліміту гри (1.5x ліміту, мін. 18 км/год).
    --     Цей стеля — наш динамічний ліміт коливається нижче нього.
    if spec.loadCalculator.genuineSpeedLimit == -1 and limit ~= math.huge then
        -- EN: Use vanilla game limit as absolute cap (no speed bonus) / UA: Ванільний ліміт як абсолютна межа (без бонусів)
        spec.loadCalculator:setGenuineSpeedLimit(limit, limit)
    end
    
    -- EN: MULTIPLAYER FIX: RHM_LoadCalculator only runs on the server.
    --     Clients must use the synced spec.data.recommendedSpeed value.
    -- UA: ВИПРАВЛЕННЯ МУЛЬТИПЛЕЕРА: RHM_LoadCalculator оновлюється лише на сервері.
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
    
    -- === SERVER: Continue with normal RHM_LoadCalculator logic ===
    -- Отримуємо обмеження з RHM_LoadCalculator
    local calculatedLimit = spec.loadCalculator:getSpeedLimit()
    local engineLoad = spec.loadCalculator:getEngineLoad()
    
    -- Діагностика: логуємо розрахунки (рідше)
    if not self._speedLimitLogTime or (g_currentMission.time - self._speedLimitLogTime) > 2000 then
        -- Logging.info("RHM: [getSpeedLimit] Load: %.1f%%, Calc limit: %.1f, Orig limit: %.1f", 
        --     engineLoad, calculatedLimit, limit)
        self._speedLimitLogTime = g_currentMission.time
    end
    
    -- EN: ALWAYS apply the calculated limit, BUT NEVER exceed vanilla game limits (ModHub requirement).
    --     This ensures specialized harvesters don't exceed their base operating speed.
    -- UA: ЗАВЖДИ застосовуємо розрахований ліміт, АЛЕ НІКОЛИ не перевищуємо ванільні ліміти гри (вимога ModHub).
    --     Це гарантує, що спеціалізовані комбайни не перевищують свою базову робочу швидкість.
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
    if not spec_combine then
        return superFunc(self)
    end
    
    -- EN: Check Independent Launch setting from manager.
    -- UA: Перевіряємо налаштування Незалежного Запуску.
    local isIndependentLaunchEnabled = true
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isIndependentLaunchEnabled = g_realisticHarvestManager.settings.enableIndependentLaunch
    end

    -- EN: If Independent Launch is enabled, combine thresher can turn on freely without waiting for cutter.
    -- UA: Якщо Незалежний Запуск увімкнений, комбайн може вільно запускати молотарку без блокування від жатки (Manual Attach).
    if isIndependentLaunchEnabled then
        return superFunc(self)
    end

    -- EN: No cutters attached — use vanilla logic.
    -- UA: Немає прикріплених жаток — використовуємо ванільну логіку.
    if spec_combine.numAttachedCutters <= 0 then
        return superFunc(self)
    end
    
    -- EN: If Independent Launch is disabled (classic combined mode), check each attached cutter.
    -- UA: Якщо Незалежний Запуск вимкнений, перевіряємо готовність прикріплених жаток.
    for cutter, _ in pairs(spec_combine.attachedCutters) do
        if cutter ~= self and cutter.getCanBeTurnedOn ~= nil then
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
    local spec_combine = self.spec_combine
    if not spec_combine then
        return superFunc(self)
    end
    
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
    local isAIActive = rhm_Combine.isAiWorkerActive(self)
    local shouldStartCutters = (not isIndependentLaunchEnabled) or (isIndependentLaunchEnabled and isAIActive)
    
    if spec_combine.numAttachedCutters > 0 and shouldStartCutters then
        -- EN: Start cutters — always for AI, for player only when Independent Launch is disabled.
        -- UA: Запускаємо жатки — завжди для AI, для гравця лише коли Незалежний Запуск вимкнений.
        local isTurning = type(self.rootVehicle.getAIFieldWorkerIsTurning) == "function" and self.rootVehicle:getAIFieldWorkerIsTurning()
        local allowLowering = not isAIActive or not isTurning
        
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
    local spec_combine = self.spec_combine
    if not spec_combine then
        return superFunc(self)
    end
    
    if self.isClient then
        g_soundManager:stopSample(spec_combine.samples.start)
        g_soundManager:stopSample(spec_combine.samples.work)
        g_soundManager:playSample(spec_combine.samples.stop)

        local spec_rhm = self.spec_rhm_Combine
        if spec_rhm and spec_rhm.samples then
            if spec_rhm.samples.overloadAlarm then
                pcall(function() g_soundManager:stopSample(spec_rhm.samples.overloadAlarm) end)
            end
        end
    end
    
    self:setCombineIsFilling(false, false, true)
    local isFull = self:getCombineFillLevelPercentage() > 0.999
    if isFull and self.rootVehicle.setCruiseControlState ~= nil then
        self.rootVehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
    end
    
    -- EN: Do NOT stop cutters automatically — player controls them independently.
    -- UA: НЕ вимикаємо жатки автоматично — гравець керує ними незалежно.
    
    if spec_combine.threshingStartAnimation ~= nil and self.playAnimation ~= nil then
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
    local isAIActive = rhm_Combine.isAiWorkerActive(self)
    
    -- EN: Block harvesting if thresher is off (unless AI is active, or vehicle has no turnOn mechanism e.g. hand tools).
    -- UA: Блокуємо збирання якщо молотарка вимкнена (якщо тільки AI не активний, або машина не має механізму вмикання як ручні інструменти).
    if self.spec_turnOnVehicle ~= nil and not self:getIsTurnedOn() and not isAIActive then
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

    local now = g_time
    if self._rhmLastWarningTime and (now - self._rhmLastWarningTime) < 3000 then
        return
    end

    local isCombineOn = self:getIsTurnedOn()
    local spec_combine = self.spec_combine
    if not spec_combine then
        return
    end
    
    -- Iterate attached cutters
    if spec_combine.attachedCutters then
        for cutter, _ in pairs(spec_combine.attachedCutters) do
            local isCutterOn = cutter:getIsTurnedOn()
            local isLowered = cutter:getIsLowered()
            
            -- CASE 1: Cutter ON but Thresher OFF (Critical)
            if isCutterOn and not isCombineOn then
                self._rhmLastWarningTime = now
                g_currentMission:showBlinkingWarning(g_i18n:getText("rhm_warning_turn_on_combine"), 2000)
                break -- Priority warning
            end
            
            -- CASE 2: Thresher ON but Cutter OFF and Lowered while moving (Likely forgot to turn on)
            local speed = (self.lastSpeedReal or 0) * 3600
            if isCombineOn and not isCutterOn and isLowered and speed > 1.0 then
                self._rhmLastWarningTime = now
                g_currentMission:showBlinkingWarning(g_i18n:getText("rhm_warning_turn_on_cutter"), 2000)
                break
            end
        end
    end
end

---Update audio feedback for engine/thresher load and crop loss (Client Side)
---EN: Plays the overload alarm sample with consistent cabin and exterior volume.
---UA: Програє звук зумера перевантаження з однаковою гучністю як у кабіні, так і ззовні.
function rhm_Combine.playAlarmSample(vehicle, spec, soundVolMultiplier)
    local alarmSample = spec.samples and spec.samples.overloadAlarm
    if not alarmSample then return end

    if soundVolMultiplier == nil and g_realisticHarvestManager and g_realisticHarvestManager.settings then
        soundVolMultiplier = g_realisticHarvestManager.settings.soundVolume
    end
    soundVolMultiplier = tonumber(soundVolMultiplier) or 1.0

    -- EN: If muted (0%), do not trigger playback
    -- UA: Якщо звук вимкнено (0%), не відтворюємо семпл
    if soundVolMultiplier <= 0.01 then
        return
    end

    -- EN: Consistent buzzer volume scaled by player's setting (0.0 to 1.0)
    -- UA: Стабільний рівень гучності зумера, масштабований налаштуванням гравця (0.0 до 1.0)
    local alarmVol = math.min(1.0, math.max(0.0, 0.85 * soundVolMultiplier))

    -- EN: Update all sample volume properties directly to prevent SoundManager resets
    -- UA: Безпосередньо оновлюємо всі параметри гучності в таблиці семпла, щоб уникнути скидання
    alarmSample.volume = alarmVol
    alarmSample.originalVolume = alarmVol
    alarmSample.volumeIndoor = alarmVol
    alarmSample.originalVolumeIndoor = alarmVol
    alarmSample.volumeOutdoor = alarmVol
    alarmSample.originalVolumeOutdoor = alarmVol
    alarmSample.volumeScale = soundVolMultiplier
    alarmSample.currentVolume = alarmVol
    alarmSample.targetVolume = alarmVol

    if g_soundManager and g_soundManager.setSampleVolume then
        pcall(function() g_soundManager:setSampleVolume(alarmSample, alarmVol) end)
    end
    if alarmSample.soundSample and type(setAudioSourceVolume) == "function" then
        pcall(function() setAudioSourceVolume(alarmSample.soundSample, alarmVol) end)
    end

    if g_soundManager and g_soundManager.stopSample then
        pcall(function() g_soundManager:stopSample(alarmSample) end)
    end

    pcall(function() g_soundManager:playSample(alarmSample) end)

    -- EN: Enforce channel volume directly on C++ audio source after playSample triggers
    -- UA: Закріплюємо гучність аудіоканалу прямо на рівні C++ аудіоджерела відразу після playSample
    if alarmSample.soundSample and type(setAudioSourceVolume) == "function" then
        pcall(function() setAudioSourceVolume(alarmSample.soundSample, alarmVol) end)
    end
    if g_soundManager and g_soundManager.setSampleVolume then
        pcall(function() g_soundManager:setSampleVolume(alarmSample, alarmVol) end)
    end
end

function rhm_Combine:updateSounds(dt)
    local spec = self.spec_rhm_Combine
    if not spec or not spec.samples then
        return
    end

    -- EN: Check if in full-screen GUI (Map, Shop, Settings, ESC menu, Calibration GUI) or paused
    -- UA: Перевіряємо чи відкрите повноекранне меню (Карта, Магазин, Налаштування, ESC, GUI калібрування) або пауза
    local isGuiVisible = (g_gui ~= nil and g_gui.getIsGuiVisible ~= nil and g_gui:getIsGuiVisible())
    local isPaused = (g_currentMission ~= nil and g_currentMission.isPaused)

    -- Check user settings
    local alarmMode = 1 -- 1 = Smart (3 beeps), 2 = Continuous, 3 = Off
    local soundVolMultiplier = 1.0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        local s = g_realisticHarvestManager.settings
        if s.alarmMode then
            alarmMode = s.alarmMode
        elseif s.enableAlarmSound == false then
            alarmMode = 3
        end
        if s.soundVolume ~= nil then
            soundVolMultiplier = tonumber(s.soundVolume) or 1.0
        end
    end

    -- Check if player is entered in or controlling this vehicle (or rootVehicle in modular rigs)
    local isPlayerEntered = (self.getIsEntered and self:getIsEntered())
                         or (self.getIsControlled and self:getIsControlled())
    if not isPlayerEntered and self.rootVehicle then
        isPlayerEntered = (self.rootVehicle.getIsEntered and self.rootVehicle:getIsEntered())
                       or (self.rootVehicle.getIsControlled and self.rootVehicle:getIsControlled())
    end

    local isTurnedOn = false
    if self.getIsTurnedOn then
        isTurnedOn = self:getIsTurnedOn()
    end
    if not isTurnedOn and self.spec_combine and self.spec_combine.isThreshing then
        isTurnedOn = true
    end
    if not isTurnedOn and self.rootVehicle and self.rootVehicle.getIsTurnedOn then
        isTurnedOn = self.rootVehicle:getIsTurnedOn()
    end

    -- If alarm disabled, muted (0%), player not in vehicle, combine turned off, game paused, or in any GUI/menu: stop active sounds
    if alarmMode == 3 or soundVolMultiplier <= 0.01 or not isPlayerEntered or not isTurnedOn or isGuiVisible or isPaused then
        if spec.samples.overloadAlarm then
            pcall(function() g_soundManager:stopSample(spec.samples.overloadAlarm) end)
            if spec.samples.overloadAlarm.soundSample and type(stopAudioSource) == "function" then
                pcall(function() stopAudioSource(spec.samples.overloadAlarm.soundSample) end)
            end
        end
        spec._rhmAlarmTimer = 1500
        spec._rhmAlarmBurstCount = 0
        spec._rhmAlarmPauseTimer = 0
        return
    end

    local load = (spec.data and spec.data.load) or 0
    local loss = (spec.data and spec.data.cropLoss) or 0

    -- Cabin Warning Alarm / Buzzer (Overload >= 105% or Crop Loss >= 5.0% with Tier 2+ loss sensors)
    local hasLossSensor = (spec.packageLevel or 1) >= 2
    local isLossAlarm = hasLossSensor and (loss >= 5.0)
    local isOverloadAlarm = (load >= 105)
    local isAlarmCondition = (isOverloadAlarm or isLossAlarm)

    if not isAlarmCondition then
        -- Hysteresis reset: clear pulse tracking once machine operates safely below 100% load & <4.0% loss
        if load < 100 and loss < 4.0 then
            spec._rhmAlarmBurstCount = 0
            spec._rhmAlarmPauseTimer = 0
            spec._rhmAlarmTimer = 1500
        end
        return
    end

    if not spec.samples.overloadAlarm then
        return
    end

    spec._rhmAlarmTimer = (spec._rhmAlarmTimer or 0) + dt

    if alarmMode == 1 then
        -- SMART MODE: 3 beeps burst, then 18-second pause reminder
        spec._rhmAlarmBurstCount = spec._rhmAlarmBurstCount or 0
        spec._rhmAlarmPauseTimer = spec._rhmAlarmPauseTimer or 0

        if spec._rhmAlarmPauseTimer > 0 then
            spec._rhmAlarmPauseTimer = spec._rhmAlarmPauseTimer - dt
            return
        end

        -- Interval between beeps in burst: 1800ms
        if spec._rhmAlarmTimer >= 1800 then
            spec._rhmAlarmTimer = 0
            spec._rhmAlarmBurstCount = spec._rhmAlarmBurstCount + 1

            rhm_Combine.playAlarmSample(self, spec, soundVolMultiplier)

            if spec._rhmAlarmBurstCount >= 3 then
                -- 3 beeps completed -> pause for 18 seconds before a single gentle reminder
                spec._rhmAlarmPauseTimer = 18000
                spec._rhmAlarmBurstCount = 2 -- next time, only 1 reminder beep
            end
        end
    elseif alarmMode == 2 then
        -- CONTINUOUS MODE: beeps every 2.4s as long as condition persists
        if spec._rhmAlarmTimer >= 2400 then
            spec._rhmAlarmTimer = 0
            rhm_Combine.playAlarmSample(self, spec, soundVolMultiplier)
        end
    end
end

-- EN: Called on every game tick. Runs warning checks on client, load/yield/speed calculations on server.
--     Server side: detects if thresher or cutter is off and resets HUD data accordingly.
--     Passes harvested mass and area to RHM_LoadCalculator for physics-based engine load calculation.
-- UA: Викликається кожен тік гри. Запускає перевірки попереджень на клієнті, розрахунки навантаження/врожайності/швидкості на сервері.
--     Серверна сторона: визначає якщо молотарка або жатка вимкнена і скидає дані HUD відповідно.
--     Передає зібрану масу та площу до RHM_LoadCalculator для фізичного розрахунку навантаження двигуна.
function rhm_Combine:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    -- EN: Client-side: update safety warnings and audio feedback.
    -- UA: Клієнтська сторона: оновлення попереджень безпеки та звуків.
    if self.isClient then
        rhm_Combine.updateWarnings(self, dt)
        rhm_Combine.updateSounds(self, dt)
    end
    
    if not self.isServer then
        return
    end
    
    local spec = self.spec_rhm_Combine
    local spec_combine = self.spec_combine
    
    if not spec or not spec.loadCalculator then
        return
    end
    
    -- EN: Check if driving in reverse. Harvesters NEVER harvest while reversing.
    -- UA: Перевірка руху заднім ходом. Комбайни НІКОЛИ не збирають врожай заднім ходом.
    local isReversing = rhm_Combine.getIsVehicleReversing(self)
    
    -- EN: Check if combine thresher is on and driving forward; reset load if not.
    -- UA: Перевіряємо чи молотарка увімкнена і рухається вперед; скидаємо навантаження якщо ні.
    if not self:getIsTurnedOn() or isReversing then
        -- EN: Thresher off or reversing — release motor limit and reset load calculation.
        -- UA: Молотарка вимкнена або рухається назад — відпускаємо ліміт мотора і скидаємо навантаження.
        if spec._rhmLastMotorSpeedLimit ~= nil then
            local motorObj = rhm_Combine.getMotorizedCarrier(self)
            if motorObj and motorObj.spec_motorized and motorObj.spec_motorized.motor then
                motorObj.spec_motorized.motor:setSpeedLimit(math.huge)
            end
            spec._rhmLastMotorSpeedLimit = nil
        end
        spec.loadCalculator:reset()
        if spec.data then
            spec.data.load = 0
            spec.data.cropLoss = 0
            spec.data.tonPerHour = 0
            spec.data.litersPerHour = 0
            spec.data.yield = 0
            spec.data.moisture = 0
            spec.data.recommendedSpeed = 0
            spec.data.targetSpeed = spec.loadCalculator:getSpeedLimit() or 0
        end
        spec.isSpeedLimitActive = false
        if spec.dataDirtyFlag and type(spec.dataDirtyFlag) == "number" then
            self:raiseDirtyFlags(spec.dataDirtyFlag)
        end
        return
    end
    
    -- EN: Check if the cutter is working. Evaluates:
    --     isTurnedOn AND speed > 0.5 AND lowered (or allowCuttingWhileRaised).
    --     Avoids directional flags that can become indeterminate during automated path following.
    -- UA: Перевіряємо чи жатка працює. Оцінює:
    --     isTurnedOn І speed > 0.5 І опущена (або allowCuttingWhileRaised).
    --     Уникає прапорців напрямку, які можуть бути невизначеними під час руху по траєкторії.
    local cutterIsTurnedOn = false
    for cutter, _ in pairs(spec_combine.attachedCutters) do
        if cutter.spec_cutter then
            local spec_cutter = cutter.spec_cutter
            if cutter:getIsTurnedOn() 
                and (spec_cutter.allowCuttingWhileRaised or cutter:getIsLowered(true)) then
                cutterIsTurnedOn = true
                break  -- EN: Found a working cutter — exit / UA: Знайшли працюючу — виходимо
            end
        end
    end
    
    -- EN: Fallback for self-propelled harvesters with integrated cutter (e.g. root/vegetable/specialized)
    -- UA: Перевірка для самохідних комбайнів із вбудованою жаткою
    if not cutterIsTurnedOn and self.spec_cutter then
        local spec_cutter = self.spec_cutter
        if self:getIsTurnedOn() 
            and (spec_cutter.allowCuttingWhileRaised or self:getIsLowered(true)) then
            cutterIsTurnedOn = true
        end
    end

    -- EN: Support self-propelled grape, olive, and straddle harvesters with integrated shaker tunnels
    -- UA: Підтримка самохідних виноградо- та оливкозбиральних комбайнів із вбудованими струшувачами
    if not cutterIsTurnedOn and (spec.machineType == "grape" or spec.machineType == "olive"
        or (spec_combine and not next(spec_combine.attachedCutters) and self.spec_cutter == nil)) then
        if self:getIsTurnedOn() then
            cutterIsTurnedOn = true
        end
    end
    
    if not cutterIsTurnedOn then
        -- EN: Preserve cruise speed before reset if active so headland turns don't wipe memory
        -- UA: Зберігаємо робочу швидкість перед скиданням щоб розвороти на краю поля не стирали пам'ять
        if spec.loadCalculator and spec.loadCalculator.speedLimit and spec.loadCalculator.speedLimit > 5.5 then
            local activeCrop = spec.loadCalculator.currentCrop or (spec.combineMemory and spec.combineMemory.currentCrop)
            local canonical = activeCrop and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(activeCrop) or activeCrop
            spec.loadCalculator.lastHarvestingSpeed = spec.loadCalculator.speedLimit
            if activeCrop then
                spec.loadCalculator.cropHarvestingSpeeds = spec.loadCalculator.cropHarvestingSpeeds or {}
                spec.loadCalculator.cropHarvestingSpeeds[activeCrop] = spec.loadCalculator.speedLimit
                if canonical then
                    spec.loadCalculator.cropHarvestingSpeeds[canonical] = spec.loadCalculator.speedLimit
                end
            end
        end

        -- EN: Cutter not working — release motor speed limit and reset indicators so they don't stay visible.
        -- UA: Жатка не працює — відпускаємо ліміт швидкості мотора та скидаємо індикатори щоб вони не висіли.
        if spec._rhmLastMotorSpeedLimit ~= nil then
            local motorObj = rhm_Combine.getMotorizedCarrier(self)
            if motorObj and motorObj.spec_motorized and motorObj.spec_motorized.motor then
                motorObj.spec_motorized.motor:setSpeedLimit(math.huge)
            end
            spec._rhmLastMotorSpeedLimit = nil
        end
        spec.loadCalculator:reset() 
        if spec.data then
            spec.data.load = 0 
            spec.data.cropLoss = 0
            spec.data.cutterWearLoss = 0
            spec.data.combineWearLoss = 0
            spec.data.totalWearLoss = 0
            spec.data.tonPerHour = 0
            spec.data.litersPerHour = 0
            spec.data.yield = 0
            spec.data.moisture = 0
            spec.data.recommendedSpeed = 0 -- EN: Hide "/ X.X" from speed display / UA: Приховуємо "/ X.X" з відображення швидкості
            spec.data.targetSpeed = spec.loadCalculator:getSpeedLimit() or 0
        end
        spec.isSpeedLimitActive = false
        
        -- EN: Sync reset to clients so their HUD clears too.
        -- UA: Синхронізуємо скидання на клієнти щоб їх HUD теж очистився.
        if spec.dataDirtyFlag and type(spec.dataDirtyFlag) == "number" then
            self:raiseDirtyFlags(spec.dataDirtyFlag)
        end
        
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
    --     ALSO DO THIS FOR COTTON HARVESTERS to bypass massive internal chamber volume transfers!
    -- UA: Використовуємо запасні літри з addCutterArea для форажних комбайнів (без бункера).
    --     ТАКОЖ ДЛЯ БАВОВНЯНИХ щоб обійти масивні внутрішні переміщення об'єму!
    local machineType = (spec.combineMemory and spec.combineMemory.machineType) or "grain"
    if machineType == "forage" or machineType == "cotton" then
        liters = spec._fallbackLiters or 0
    elseif liters <= 0 and (spec._fallbackLiters or 0) > 0 then
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
    
    -- EN: Pass accumulated MASS to RHM_LoadCalculator (not area) — mass is the main driver now.
    -- UA: Передаємо накопичену МАСУ в RHM_LoadCalculator (не площу) — маса тепер основний показник.
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
    local totalCropLossThisTick = spec.loadCalculator:calculateTotalCropLoss(self)

    if liters > 0 and self.isServer then
        -- EN: Calculate total crop loss including settings deviation penalty.
        -- UA: Розраховуємо загальні втрати врожаю включаючи штраф за відхилення налаштувань.
        local cropLoss = totalCropLossThisTick
        spec.combineMemory:updateStatistics(liters, cropLoss, spec.combineMemory.currentCrop)
        
        if cropLoss > 0 and g_realisticHarvestManager and g_realisticHarvestManager.settings then
            if g_realisticHarvestManager.settings.enableCropLoss then
                -- EN: Subtract only speed overload and settings loss physically from the tank.
                --     Mechanical wear loss is already reduced natively by FS25 GIANTS yield logic.
                -- UA: Віднімаємо з бункера лише фізичні втрати від перевантаження та налаштувань.
                --     Втрати від зносу вже нативно зменшені логікою врожайності FS25 GIANTS.
                local wearLossPct = (spec.loadCalculator and spec.loadCalculator.totalWearLoss) or 0
                local physicalLossPct = math.max(0, cropLoss - wearLossPct)
                local lossRatio = physicalLossPct / 100
                local lostLiters = liters * lossRatio
                
                local fillUnitIndex = spec.lastFillUnitIndex or (self.spec_combine and self.spec_combine.fillUnitIndex) or 1
                local spec_fillUnit = self.spec_fillUnit
                if lostLiters > 0.001 and spec_fillUnit and spec_fillUnit.fillUnits and spec_fillUnit.fillUnits[fillUnitIndex] then
                    self:addFillUnitFillLevel(
                        self:getOwnerFarmId(),
                        fillUnitIndex,
                        -lostLiters,
                        spec.lastFillType,
                        ToolType.UNDEFINED,
                        nil
                    )
                    
                    -- EN: Commented out to prevent massive console spam every update tick
                    -- UA: Закоментовано, щоб уникнути масового спаму в консолі кожен тік оновлення
                    -- rhm_log(string.format("RHM [Combine]: RHM: [LOSS] Crop Loss Applied: %.1f L lost (%.1f%% of %.1f L harvest)",
                    --    lostLiters, cropLoss, liters))
                else
                    -- rhm_log("RHM [Combine]: RHM: Warning - Could not find fill unit for crop loss removal")
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
    
    -- MOISTURE: Отримуємо дані з Moisture Adapter
    local moisture = 0
    if RHM_MoistureAdapter and RHM_MoistureAdapter.isActive and g_realisticHarvestManager.settings.enableMoisture then
        if cutterIsTurnedOn then
            local fillType = spec.lastFillType or FillType.UNKNOWN
            if fillType ~= FillType.UNKNOWN then
                moisture = RHM_MoistureAdapter.getObjectMoisture(self.components[1].node, fillType)
            end
            if moisture == 0 or moisture == nil then
                local mx, _, mz = getWorldTranslation(self.components[1].node)
                moisture = RHM_MoistureAdapter.getMoistureAtPosition(mx, mz)
            end
        end
    end

    -- EN: Update HUD live data table from RHM_LoadCalculator outputs.
    -- UA: Оновлюємо таблицю живих даних HUD з виводів RHM_LoadCalculator.
    if spec.data then
        spec.data.moisture = moisture or 0
        spec.data.load = spec.loadCalculator:getEngineLoad()
        spec.data.cropLoss = totalCropLossThisTick
        spec.data.cutterWearLoss = spec.loadCalculator.cutterWearLoss or 0
        spec.data.combineWearLoss = spec.loadCalculator.combineWearLoss or 0
        spec.data.totalWearLoss = spec.loadCalculator.totalWearLoss or 0
        spec.data.cutterDamage = spec.loadCalculator.lastCutterDamage or 0
        spec.data.combineDamage = spec.loadCalculator.lastCombineDamage or 0
        spec.data.tonPerHour = spec.loadCalculator:getTonPerHour()
        spec.data.litersPerHour = spec.loadCalculator:getLitersPerHour() -- NEW: Volume flow
        spec.data.hectaresPerHour = spec.loadCalculator:getHectaresPerHour() -- NEW: Area rate (ha/h)
        local isArcade = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.difficultyMotor == 1)
        if isArcade then
            spec.data.load = 0
            spec.data.recommendedSpeed = 0
            spec.data.targetSpeed = 0
        else
            spec.data.recommendedSpeed = spec.loadCalculator:getSpeedLimit()
            spec.data.targetSpeed = spec.data.recommendedSpeed
        end
        -- NEW: Yield Monitor Data
        spec.data.yield = spec.loadCalculator.currentYield or 0
        -- NEW: Straw Chopper Telemetry
        spec.data.isStrawChopperActive = (spec.loadCalculator and spec.loadCalculator.isStrawChopperActive) or false
        spec.data.chopperPowerHp = (spec.loadCalculator and spec.loadCalculator.lastPowerChopper) or 0
        -- NEW: Forage Harvester & Swath Pickup Telemetry
        spec.data.isForageHarvester = (machineType == "forage")
        spec.data.isPickup = (spec.loadCalculator and spec.loadCalculator.isPickup) or false
        spec.data.forageFeedPowerHp = (spec.loadCalculator and spec.loadCalculator.lastPowerForageFeed) or 0
        spec.data.forageDrumPowerHp = (spec.loadCalculator and spec.loadCalculator.lastPowerForageDrum) or 0
        spec.data.forageBlowerPowerHp = (spec.loadCalculator and spec.loadCalculator.lastPowerForageBlower) or 0
    end

    -- EN: Auto-trim active settings in background when Opti-Harvest AI (Level 4) is active in AUTO mode.
    -- UA: Фонове автопідлаштування налаштувань коли активний Opti-Harvest AI (4 рівень) в режимі AUTO.
    if spec.combineMemory and spec.combineMemory.updateAutoTrim and cutterIsTurnedOn then
        spec.combineMemory:updateAutoTrim(dt)
    end

    -- EN: Auto-tune settings when an automated worker operates the combine.
    --     Applies once upon starting or switching crop, preserving manual control when player drives.
    -- UA: Автоналаштування коли технікою керує автоматичний помічник.
    --     Застосовується один раз при старті або зміні культури, зберігаючи повністю ручне керування для гравця.
    if self.isServer and cutterIsTurnedOn then
        -- EN: Hopper sanity check: if the hopper contains grain of a different crop type than currentCrop,
        --     synchronize currentCrop immediately to ensure settings match what is in the tank.
        -- UA: Перевірка бункера: якщо в бункері вже є зерно іншого типу ніж currentCrop,
        --     негайно синхронізуємо currentCrop, щоб налаштування відповідали зерну в бункері.
        if spec.combineMemory then
            local fillUnitIndex = (self.spec_combine and self.spec_combine.fillUnitIndex) or 1
            local tankFillLevel = self:getFillUnitFillLevel(fillUnitIndex) or 0
            if tankFillLevel > 50 then
                local tankFillType = self:getFillUnitFillType(fillUnitIndex)
                if (tankFillType == nil or tankFillType == FillType.UNKNOWN) and self.getFillUnitLastValidFillType then
                    tankFillType = self:getFillUnitLastValidFillType(fillUnitIndex)
                end
                if tankFillType and tankFillType ~= FillType.UNKNOWN then
                    local tankCrop = RHM_CombineSettingsDatabase:getCropNameFromFillType(tankFillType)
                    if spec.combineMemory and spec.combineMemory.machineType == "forage" and (tankCrop == "MAIZE" or tankCrop == "CORN") then
                        tankCrop = "MAIZE_FORAGE"
                    end
                    if tankCrop and tankCrop ~= spec.combineMemory.currentCrop then
                        rhm_log(string.format("RHM [Combine]: RHM: [TICK] Hopper sync detected: %s (in tank: %d L) vs current %s", tankCrop, math.floor(tankFillLevel), tostring(spec.combineMemory.currentCrop)))
                        rhm_Combine.onCropTypeChanged(self, tankCrop)
                    end
                end
            end
        end

        local isAi = rhm_Combine.isAiWorkerActive(self)
        if isAi then
            local currentCrop = spec.combineMemory and spec.combineMemory.currentCrop
            if currentCrop and currentCrop ~= "" and spec._lastAiTunedCrop ~= currentCrop then
                spec._lastAiTunedCrop = currentCrop
                spec.combineMemory:applyAiWorkerTuning(currentCrop)
                if spec.settingsDirtyFlag and type(spec.settingsDirtyFlag) == "number" then
                    self:raiseDirtyFlags(spec.settingsDirtyFlag)
                end
            end
        else
            -- EN: Player is manually driving. Only reset tracking if the crop changed or combine is uncalibrated,
            --     so that already configured combine settings are not repeatedly re-evaluated.
            -- UA: Гравець керує вручну. Скидаємо трекінг тільки якщо змінилася культура або комбайн не налаштований,
            --     щоб уже налаштовані параметри не смикалися даремно.
            local currentCrop = spec.combineMemory and spec.combineMemory.currentCrop
            if spec._lastAiTunedCrop ~= currentCrop or not (spec.combineMemory and spec.combineMemory.isCalibrated) then
                spec._lastAiTunedCrop = nil
            end
        end
    end

    -- EN: Dedicated Server Profile Sync: If an automated worker is harvesting on a dedicated server,
    --     the client owning/controlling this combine automatically sends their locally saved crop preset (if any).
    -- UA: Синхронізація профілю для виділеного сервера: якщо автоматичний помічник збирає врожай на виділеному сервері,
    --     клієнт що володіє/керує цим комбайном автоматично надсилає свій локально збережений пресет культури (якщо є).
    if not self.isServer and self.isClient and cutterIsTurnedOn then
        local isAi = rhm_Combine.isAiWorkerActive(self)
        if isAi then
            local isMyVehicle = (self.getIsEntered and self:getIsEntered())
                or (self.getIsControlled and self:getIsControlled())
                or (g_currentMission and g_currentMission.player and self:getOwnerFarmId() == g_currentMission.player.farmId)
            if isMyVehicle then
                local currentCrop = spec.combineMemory and spec.combineMemory.currentCrop
                if currentCrop and currentCrop ~= "" and spec._lastAiClientTunedCrop ~= currentCrop then
                    spec._lastAiClientTunedCrop = currentCrop
                    -- EN: Only auto-send saved profile if combine is NOT already calibrated by player
                    -- UA: Автоматично надсилаємо збережений профіль тільки якщо комбайн ЩЕ НЕ налаштований гравцем
                    local isCalib = spec.combineMemory and (spec.combineMemory.isCalibrated or (spec.combineMemory.calibratedCrops and spec.combineMemory.calibratedCrops[currentCrop]))
                    if not isCalib then
                        local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
                        if pm and pm:getProfile(currentCrop) then
                            spec.combineMemory:loadUserPreset()
                        end
                    end
                end
            end
        else
            local currentCrop = spec.combineMemory and spec.combineMemory.currentCrop
            if spec._lastAiClientTunedCrop ~= currentCrop or not (spec.combineMemory and spec.combineMemory.isCalibrated) then
                spec._lastAiClientTunedCrop = nil
            end
        end
    end

    
    -- === SPEED LIMIT ENFORCEMENT (Server Side) ===
    -- Certain automated drivers and auxiliary controllers can bypass `getSpeedLimit()`.
    -- Enforce the dynamic cap directly on the motor for both:
    --  - AI vehicles
    --  - player-controlled vehicles (so in-cab cruise reacts to load)
    if self.isServer and cutterIsTurnedOn and not isReversing then
        local motorObj = rhm_Combine.getMotorizedCarrier(self)
        local isAI = rhm_Combine.isAiWorkerActive(self)
        local isPlayerControlled = (type(self.getIsControlled) == "function" and self:getIsControlled())
        if not isPlayerControlled and motorObj ~= self and type(motorObj.getIsControlled) == "function" then
            isPlayerControlled = motorObj:getIsControlled()
        end

        if isAI or isPlayerControlled then
            if motorObj and motorObj.spec_motorized and motorObj.spec_motorized.motor then
                local motor = motorObj.spec_motorized.motor
                local currentLimit = spec.loadCalculator:getSpeedLimit()

                local settings = g_realisticHarvestManager and g_realisticHarvestManager.settings
                local speedLimitEnabled = settings and settings.enableSpeedLimit
                local isArcade = settings and settings.difficultyMotor == 1 -- DIFFICULTY_ARCADE

                if (not speedLimitEnabled) or isArcade then
                    -- EN: In Arcade mode or when speed limiting is disabled, RHM never limits or touches the motor.
                    --     Restore unconstrained limit so modded harvesters can run at any speed (e.g. 100 km/h).
                    -- UA: В режимі Аркада або з вимкненим лімітом RHM взагалі не чіпає мотор.
                    --     Скидаємо обмеження, щоб комбайни з інших модів могли рухатися з будь-якою швидкістю (напр. 100 км/год).
                    if spec._rhmLastMotorSpeedLimit ~= nil then
                        motor:setSpeedLimit(math.huge)
                        spec._rhmLastMotorSpeedLimit = nil
                    end
                else
                    local ceiling = spec.loadCalculator.genuineSpeedLimit
                    if ceiling and ceiling > 0 then
                        currentLimit = math.min(currentLimit, ceiling)
                    end

                    if currentLimit and currentLimit > 0 and currentLimit ~= math.huge then
                        -- EN: Skip redundant motor updates when limit barely changes (getSpeedLimit/onTick fire often).
                        -- UA: Не шлемо в мотор той самий ліміт щотік — getSpeedLimit/onTick дуже часті.
                        local prev = spec._rhmLastMotorSpeedLimit
                        if prev == nil or math.abs(prev - currentLimit) >= 0.05 then
                            spec._rhmLastMotorSpeedLimit = currentLimit
                            motor:setSpeedLimit(currentLimit)
                        end
                    end
                end
            end
        end
    end
    
    -- EN: OVERLOAD LEVEL: Server calculates level for network sync (0=normal, 1=HIGH 120%+, 2=CRITICAL 150%+).
    -- UA: РІВЕНЬ ПЕРЕВАНТАЖЕННЯ: Сервер обраховує рівень для мережевої синхронізації.
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
                elseif math.abs((data.hectaresPerHour or 0) - (last.hectaresPerHour or 0)) > 0.05 then hasSignificantChange = true
                elseif data.overloadLevel ~= last.overloadLevel then hasSignificantChange = true
                elseif math.abs((data.moisture or 0) - (last.moisture or 0)) > 0.5 then hasSignificantChange = true
                end
            end
            
            -- Також форсуємо оновлення раз на секунду
            if hasSignificantChange or (now - spec.lastDataUpdateTime) >= 1000 then
                spec.lastDataUpdateTime = now
                spec.lastSyncedData.load = data.load
                spec.lastSyncedData.cropLoss = data.cropLoss
                spec.lastSyncedData.recommendedSpeed = data.recommendedSpeed
                spec.lastSyncedData.yield = data.yield
                spec.lastSyncedData.hectaresPerHour = data.hectaresPerHour
                spec.lastSyncedData.overloadLevel = data.overloadLevel
                spec.lastSyncedData.moisture = data.moisture
                
                if spec.dataDirtyFlag and type(spec.dataDirtyFlag) == "number" then
                    self:raiseDirtyFlags(spec.dataDirtyFlag)
                end
            end
        end
    end
end

-- EN: Called every frame when the player is in the combine.
--     HUD is drawn centrally in RHM_RealisticHarvestManager:draw() via hierarchy scanning,
--     so we don't draw here to avoid duplication.
-- UA: Викликається кожен кадр коли гравець в комбайні.
--     HUD малюється централізовано в RHM_RealisticHarvestManager:draw() через сканування ієрархії,
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
            rhm_log("RHM [Combine]: RHM: [SAVE] Warning - could not set " .. tostring(path) .. ": " .. tostring(err))
        end
    end
    
    safeSet(cur .. "#mode",       mem.mode or "MANUAL")
    safeSet(cur .. "#autoSwitch", mem.autoSwitchEnabled ~= false)
    safeSet(cur .. "#currentCrop", mem.currentCrop or "")
    safeSet(cur .. "#fan",        settings.fan or 50)
    safeSet(cur .. "#upperSieve", settings.upperSieve or 50)
    safeSet(cur .. "#lowerSieve", settings.lowerSieve or 50)
    safeSet(cur .. "#rotor",      settings.rotor or 50)
    safeSet(cur .. "#feeder",     settings.feeder or 50)
    safeSet(cur .. "#targetEngineLoad", settings.targetEngineLoad or 95)
    
    local isCalib = mem.isCalibrated == true or mem.hasManualTuning == true or (mem.calibratedCrops and mem.currentCrop and mem.calibratedCrops[mem.currentCrop] == true)
    safeSet(cur .. "#isCalibrated", isCalib)

    local calibList = {}
    if mem.calibratedCrops then
        for crop, flag in pairs(mem.calibratedCrops) do
            if flag then
                table.insert(calibList, crop)
            end
        end
    end
    if #calibList > 0 then
        safeSet(cur .. "#calibratedCrops", table.concat(calibList, " "))
    end
    
    rhm_log(string.format("RHM [Combine]: RHM: [SAVE] Saved combine state for %s: crop=%s, fan=%s, upper=%s, lower=%s, rotor=%s, feeder=%s, load=%s", 
        self:getName() or "?",
        tostring(mem.currentCrop),
        tostring(settings.fan),
        tostring(settings.upperSieve),
        tostring(settings.lowerSieve),
        tostring(settings.rotor),
        tostring(settings.feeder),
        tostring(settings.targetEngineLoad)))
end

---Завантаження стану з savegame
function rhm_Combine:loadFromSavegame(savegame)
    if not savegame or not savegame.xmlFile or not savegame.key then
        return false
    end
    if savegame.resetVehicles then
        return false
    end

    local spec = self.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return false
    end

    local xmlFile = savegame.xmlFile
    local modName = g_currentModName 
        or (g_realisticHarvestManager and g_realisticHarvestManager.modName)
        or "FS25_RealisticHarvesting"

    local candidateKeys = {
        savegame.key .. ".combineMemory.current",
        string.format("%s.%s.rhm_Combine.combineMemory.current", savegame.key, modName),
        string.format("%s.FS25_RealisticHarvesting.rhm_Combine.combineMemory.current", savegame.key),
        string.format("%s.rhm_Combine.combineMemory.current", savegame.key),
        string.format("%s.combineMemory.current", savegame.key),
    }

    local cur = nil
    for _, path in ipairs(candidateKeys) do
        if xmlFile:hasProperty(path) then
            cur = path
            break
        end
    end

    if not cur then
        rhm_log(string.format("RHM [Combine]: RHM: [LOAD] No saved combine settings found for %s in savegame (tested key: %s)",
            self:getFullName() or "?", tostring(candidateKeys[2])))
        return false
    end

    local function readInt(path, def)
        if not xmlFile:hasProperty(path) then
            return def
        end
        local val = nil
        if xmlFile.getInt then
            val = xmlFile:getInt(path)
        end
        if val == nil and XMLValueType and XMLValueType.INT then
            local ok, res = pcall(function() return xmlFile:getValue(path, XMLValueType.INT) end)
            if ok then val = res end
        end
        if val == nil then
            local ok, res = pcall(function() return xmlFile:getValue(path) end)
            if ok then val = res end
        end
        return (val ~= nil and tonumber(val)) or def
    end

    local function readString(path, def)
        if not xmlFile:hasProperty(path) then
            return def
        end
        local val = nil
        if xmlFile.getString then
            val = xmlFile:getString(path)
        end
        if val == nil and XMLValueType and XMLValueType.STRING then
            local ok, res = pcall(function() return xmlFile:getValue(path, XMLValueType.STRING) end)
            if ok then val = res end
        end
        if val == nil then
            local ok, res = pcall(function() return xmlFile:getValue(path) end)
            if ok then val = res end
        end
        return (val ~= nil and tostring(val)) or def
    end

    local function readBool(path, def)
        if not xmlFile:hasProperty(path) then
            return def
        end
        local val = nil
        if xmlFile.getBool then
            val = xmlFile:getBool(path)
        end
        if val == nil and XMLValueType and XMLValueType.BOOL then
            local ok, res = pcall(function() return xmlFile:getValue(path, XMLValueType.BOOL) end)
            if ok then val = res end
        end
        if val == nil then
            local ok, res = pcall(function() return xmlFile:getValue(path) end)
            if ok then val = res end
        end
        if val == nil then return def end
        if type(val) == "boolean" then return val end
        return tostring(val):lower() == "true"
    end

    local isTier4 = (spec.packageLevel or 1) >= 4
    local loadedMode = readString(cur .. "#mode", "MANUAL")
    local loadedAutoSwitch = readBool(cur .. "#autoSwitch", false)
    if isTier4 then
        spec.combineMemory.mode              = loadedMode
        spec.combineMemory.autoSwitchEnabled = loadedAutoSwitch
    else
        spec.combineMemory.mode              = "MANUAL"
        spec.combineMemory.autoSwitchEnabled = false
    end

    local savedCrop = readString(cur .. "#currentCrop", "")
    if savedCrop and savedCrop ~= "" then
        spec.combineMemory.currentCrop = savedCrop
        if spec.loadCalculator then
            spec.loadCalculator.currentCrop = savedCrop
        end
    end

    local curSettings = spec.combineMemory.currentSettings
    if curSettings then
        local loadedFan = readInt(cur .. "#fan", nil)
        local loadedUpper = readInt(cur .. "#upperSieve", nil)
        local loadedLower = readInt(cur .. "#lowerSieve", nil)
        local loadedRotor = readInt(cur .. "#rotor", nil)
        local loadedFeeder = readInt(cur .. "#feeder", nil)
        local loadedTargetLoad = readInt(cur .. "#targetEngineLoad", nil)
        
        if loadedFan ~= nil then curSettings.fan = loadedFan end
        if loadedUpper ~= nil then curSettings.upperSieve = loadedUpper end
        if loadedLower ~= nil then curSettings.lowerSieve = loadedLower end
        if loadedRotor ~= nil then curSettings.rotor = loadedRotor end
        if loadedFeeder ~= nil then curSettings.feeder = loadedFeeder end
        if loadedTargetLoad ~= nil then curSettings.targetEngineLoad = loadedTargetLoad end
    end

    local isCalibrated = readBool(cur .. "#isCalibrated", true)
    spec.combineMemory.isCalibrated = isCalibrated
    spec.combineMemory.hasManualTuning = isCalibrated
    spec.combineMemory.calibratedCrops = spec.combineMemory.calibratedCrops or {}

    if savedCrop and savedCrop ~= "" then
        spec.combineMemory.calibratedCrops[savedCrop] = isCalibrated
        spec._lastAiTunedCrop = savedCrop
        spec._lastAiClientTunedCrop = savedCrop
    end

    local savedCalibCropsStr = readString(cur .. "#calibratedCrops", "")
    if savedCalibCropsStr and savedCalibCropsStr ~= "" then
        for crop in string.gmatch(savedCalibCropsStr, "%S+") do
            spec.combineMemory.calibratedCrops[crop] = true
        end
    end

    self._rhmSettingsLoadedFromSavegame = true

    Logging.info(string.format("RHM: [SAVEGAME LOAD SUCCESS] %s: crop=%s, mode=%s, autoSwitch=%s, fan=%s, upper=%s, lower=%s, rotor=%s, feeder=%s, load=%s", 
        tostring(self:getFullName()),
        tostring(spec.combineMemory.currentCrop),
        tostring(spec.combineMemory.mode),
        tostring(spec.combineMemory.autoSwitchEnabled),
        tostring(curSettings and curSettings.fan),
        tostring(curSettings and curSettings.upperSieve),
        tostring(curSettings and curSettings.lowerSieve),
        tostring(curSettings and curSettings.rotor),
        tostring(curSettings and curSettings.feeder),
        tostring(curSettings and curSettings.targetEngineLoad)))

    return true
end

---Завантаження стану з savegame файлу (адаптер для сумісності)
function rhm_Combine:loadFromXMLFile(xmlFile, key, resetVehicles)
    return rhm_Combine.loadFromSavegame(self, {
        xmlFile = xmlFile,
        key = key,
        resetVehicles = resetVehicles
    })
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
        streamWriteFloat32(streamId, 0) -- hectaresPerHour
        streamWriteFloat32(streamId, 0)
        streamWriteFloat32(streamId, 0) -- yield
        streamWriteUInt8(streamId, 0)   -- overloadLevel
        streamWriteFloat32(streamId, 0) -- moisture
        -- RHM_CombineMemory: write defaults
        streamWriteUInt8(streamId, 50)  -- fan
        streamWriteUInt8(streamId, 50)  -- rotor
        streamWriteUInt8(streamId, 50)  -- upperSieve
        streamWriteUInt8(streamId, 50)  -- lowerSieve
        streamWriteUInt8(streamId, 50)  -- feeder
        streamWriteUInt8(streamId, 95)  -- targetEngineLoad
        streamWriteString(streamId, "AUTO")  -- mode
        streamWriteString(streamId, "")      -- currentCrop (empty = nil)
        return
    end
    
    -- HUD data
    streamWriteFloat32(streamId, spec.data.load or 0)
    streamWriteFloat32(streamId, spec.data.cropLoss or 0)
    streamWriteFloat32(streamId, spec.data.tonPerHour or 0)
    streamWriteFloat32(streamId, spec.data.litersPerHour or 0)
    streamWriteFloat32(streamId, spec.data.hectaresPerHour or 0)
    streamWriteFloat32(streamId, spec.data.recommendedSpeed or 0)
    streamWriteFloat32(streamId, spec.data.yield or 0)
    streamWriteUInt8(streamId, spec.data.overloadLevel or 0)
    streamWriteFloat32(streamId, spec.data.moisture or 0)
    
    -- RHM_CombineMemory settings (sync on initial connect)
    local mem = spec.combineMemory
    local isTier4 = (spec.packageLevel or 1) >= 4
    if mem then
        streamWriteUInt8(streamId, mem.currentSettings.fan or 50)
        streamWriteUInt8(streamId, mem.currentSettings.rotor or 50)
        streamWriteUInt8(streamId, mem.currentSettings.upperSieve or 50)
        streamWriteUInt8(streamId, mem.currentSettings.lowerSieve or 50)
        streamWriteUInt8(streamId, mem.currentSettings.feeder or 50)
        streamWriteUInt8(streamId, mem.currentSettings.targetEngineLoad or 95)
        streamWriteString(streamId, isTier4 and (mem.mode or "MANUAL") or "MANUAL")
        streamWriteString(streamId, mem.currentCrop or "")
    else
        streamWriteUInt8(streamId, 50)
        streamWriteUInt8(streamId, 50)
        streamWriteUInt8(streamId, 50)
        streamWriteUInt8(streamId, 50)
        streamWriteUInt8(streamId, 50)
        streamWriteUInt8(streamId, 95)
        streamWriteString(streamId, "MANUAL")
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
        streamReadFloat32(streamId) -- hectaresPerHour
        streamReadFloat32(streamId)
        streamReadFloat32(streamId) -- yield
        streamReadUInt8(streamId)   -- overloadLevel
        streamReadFloat32(streamId) -- moisture
        -- RHM_CombineMemory defaults (skip)
        streamReadUInt8(streamId)
        streamReadUInt8(streamId)
        streamReadUInt8(streamId)
        streamReadUInt8(streamId)
        streamReadUInt8(streamId)
        streamReadUInt8(streamId)   -- targetEngineLoad
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
    spec.data.hectaresPerHour = streamReadFloat32(streamId)
    spec.data.recommendedSpeed = streamReadFloat32(streamId)
    spec.data.yield = streamReadFloat32(streamId)
    spec.data.overloadLevel = streamReadUInt8(streamId)
    spec.data.moisture = streamReadFloat32(streamId)
    
    -- RHM_CombineMemory settings
    local fan = streamReadUInt8(streamId)
    local rotor = streamReadUInt8(streamId)
    local upperSieve = streamReadUInt8(streamId)
    local lowerSieve = streamReadUInt8(streamId)
    local feeder = streamReadUInt8(streamId)
    local targetEngineLoad = streamReadUInt8(streamId)
    local mode = streamReadString(streamId)
    local currentCrop = streamReadString(streamId)
    
    -- Apply to combineMemory if available
    if spec.combineMemory then
        spec.combineMemory.currentSettings.fan = fan
        spec.combineMemory.currentSettings.rotor = rotor
        spec.combineMemory.currentSettings.upperSieve = upperSieve
        spec.combineMemory.currentSettings.lowerSieve = lowerSieve
        spec.combineMemory.currentSettings.feeder = feeder
        spec.combineMemory.currentSettings.targetEngineLoad = targetEngineLoad or 95
        local isTier4 = (spec.packageLevel or 1) >= 4
        if isTier4 then
            spec.combineMemory.mode = mode or "MANUAL"
            spec.combineMemory.autoSwitchEnabled = (spec.combineMemory.mode == "AUTO")
        else
            spec.combineMemory.mode = "MANUAL"
            spec.combineMemory.autoSwitchEnabled = false
        end
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
            spec.data.hectaresPerHour = streamReadFloat32(streamId)
            spec.data.recommendedSpeed = streamReadFloat32(streamId)
            spec.data.yield = streamReadFloat32(streamId)
            spec.data.overloadLevel = streamReadUInt8(streamId)
            spec.data.moisture = streamReadFloat32(streamId)
        end

        if hasSettingsUpdate then
            -- RHM_CombineMemory settings
            local fan = streamReadUInt8(streamId)
            local rotor = streamReadUInt8(streamId)
            local upperSieve = streamReadUInt8(streamId)
            local lowerSieve = streamReadUInt8(streamId)
            local feeder = streamReadUInt8(streamId)
            local targetEngineLoad = streamReadUInt8(streamId)
            local mode = streamReadString(streamId)
            local currentCrop = streamReadString(streamId)
            
            if spec.combineMemory then
                spec.combineMemory.currentSettings.fan = fan
                spec.combineMemory.currentSettings.rotor = rotor
                spec.combineMemory.currentSettings.upperSieve = upperSieve
                spec.combineMemory.currentSettings.lowerSieve = lowerSieve
                spec.combineMemory.currentSettings.feeder = feeder
                spec.combineMemory.currentSettings.targetEngineLoad = targetEngineLoad or 95
                local isTier4 = (spec.packageLevel or 1) >= 4
                if isTier4 then
                    spec.combineMemory.mode = mode or "MANUAL"
                    spec.combineMemory.autoSwitchEnabled = (spec.combineMemory.mode == "AUTO")
                else
                    spec.combineMemory.mode = "MANUAL"
                    spec.combineMemory.autoSwitchEnabled = false
                end
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
            streamWriteFloat32(streamId, data.hectaresPerHour or 0)
            streamWriteFloat32(streamId, data.recommendedSpeed or 0)
            streamWriteFloat32(streamId, data.yield or 0)
            streamWriteUInt8(streamId, data.overloadLevel or 0)
            streamWriteFloat32(streamId, data.moisture or 0)
        end

        if hasSettingsUpdate then
            -- RHM_CombineMemory settings
            local mem = spec.combineMemory
            if mem then
                streamWriteUInt8(streamId, mem.currentSettings.fan or 50)
                streamWriteUInt8(streamId, mem.currentSettings.rotor or 50)
                streamWriteUInt8(streamId, mem.currentSettings.upperSieve or 50)
                streamWriteUInt8(streamId, mem.currentSettings.lowerSieve or 50)
                streamWriteUInt8(streamId, mem.currentSettings.feeder or 50)
                streamWriteUInt8(streamId, mem.currentSettings.targetEngineLoad or 95)
                local isTier4 = (spec.packageLevel or 1) >= 4
                streamWriteString(streamId, isTier4 and (mem.mode or "MANUAL") or "MANUAL")
                streamWriteString(streamId, mem.currentCrop or "")
            else
                streamWriteUInt8(streamId, 50)
                streamWriteUInt8(streamId, 50)
                streamWriteUInt8(streamId, 50)
                streamWriteUInt8(streamId, 50)
                streamWriteUInt8(streamId, 50)
                streamWriteUInt8(streamId, 95)
                streamWriteString(streamId, "MANUAL")
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
        
        -- EN: Allow registration when player is inside the combine, even while an automated worker is operating it.
        -- UA: Дозволяємо реєстрацію коли гравець у комбайні, навіть якщо ним керує автоматичний водій.
        local canRegister = isActiveForInputIgnoreSelection
            or self.isActiveForInputIgnoreSelectionIgnoreAI
            or (self.getIsEntered and self:getIsEntered())

        if canRegister then
            -- Реєструємо дію Відкриття Меню (RShift+K)
            if InputAction.RHM_OPEN_MENU then
                local _, menuEventId = self:addActionEvent(spec.actionEvents, InputAction.RHM_OPEN_MENU, self, rhm_Combine.actionOpenMenu, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(menuEventId, GS_PRIO_HIGH)
            end
            -- Реєструємо дію Перемикання HUD (RShift+H)
            if InputAction.RHM_TOGGLE_HUD then
                local _, hudEventId = self:addActionEvent(spec.actionEvents, InputAction.RHM_TOGGLE_HUD, self, rhm_Combine.actionToggleHUD, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(hudEventId, GS_PRIO_HIGH)
            end
        end
    end
end

function rhm_Combine:actionOpenMenu(actionName, inputValue, callbackState, isAnalog)
    if g_realisticHarvestManager then
        g_realisticHarvestManager:toggleMenu(self)
    end
end

function rhm_Combine:actionToggleHUD(actionName, inputValue, callbackState, isAnalog)
    if g_realisticHarvestManager then
        g_realisticHarvestManager:toggleHUD()
    end
end

-- EN: Clean up cursor, camera states, and audio when leaving the vehicle.
-- UA: Очищаємо стани курсора, камери та звуків при виході з транспортного засобу.
function rhm_Combine:onLeaveVehicle(wasEntered)
    if self.isClient then
        local spec_rhm = self.spec_rhm_Combine
        if spec_rhm and spec_rhm.samples then
            if spec_rhm.samples.overloadAlarm then
                pcall(function() g_soundManager:stopSample(spec_rhm.samples.overloadAlarm) end)
            end
        end

        if g_realisticHarvestManager then
            if g_realisticHarvestManager.calibrationGUI and g_realisticHarvestManager.calibrationGUI.isOpen then
                g_realisticHarvestManager.calibrationGUI:close()
            end
        end
        if self.spec_enterable and self.spec_enterable.cameras then
            for _, camera in pairs(self.spec_enterable.cameras) do
                camera.isRotatable = true
                camera.allowTranslation = true
                camera.allowZoom = true
                if camera.rotSpeed == 0 and camera._rhmSavedRotSpeed then
                    camera.rotSpeed = camera._rhmSavedRotSpeed
                    camera._rhmSavedRotSpeed = nil
                end
            end
        end
    end
end

-- EN: Clean up sound samples and resources when vehicle is deleted.
-- UA: Очищення звукових семплів та ресурсів при видаленні комбайна.
function rhm_Combine:onDelete()
    local spec = self.spec_rhm_Combine
    if spec and spec.samples then
        if spec.samples.overloadAlarm then
            pcall(function() g_soundManager:stopSample(spec.samples.overloadAlarm) end)
        end
        pcall(function() g_soundManager:deleteSamples(spec.samples) end)
        spec.samples = nil
    end
end







