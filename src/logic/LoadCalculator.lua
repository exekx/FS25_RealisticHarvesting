---@class LoadCalculator
-- EN: Physics-based engine load and speed limit calculator for combine harvesters.
--     Tracks cut area and harvested mass each tick to compute: engine load (%),
--     dynamic speed limit, productivity (t/h, L/h), yield (t/ha), and crop loss (%)
--     from combine settings deviation. Supports grain, forage, root, and cotton types.
-- UA: Фізичний калькулятор навантаження двигуна та ліміту швидкості для комбайнів.
--     Відстежує площу зрізу та масу врожаю кожен тік для розрахунку: навантаження (%),
--     динамічного ліміту швидкості, продуктивності (т/год, л/год), врожайності (т/га)
--     та втрат врожаю (%) від відхилення налаштувань. Підтримує зернові, форажні, коренеплоди, бавовну.
LoadCalculator = {}
local LoadCalculator_mt = Class(LoadCalculator)

function LoadCalculator.new(modDirectory)
    local self = setmetatable({}, LoadCalculator_mt)
    
    self.modDirectory = modDirectory or g_currentModDirectory
    
    -- EN: Crop difficulty coefficients / UA: Коефіцієнти складності культур
    self.CROP_FACTORS = {}
    self:loadDefaultCropFactors()
    
    -- EN: average load calculation data / UA: Дані для розрахунку середнього навантаження
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.avgTime = 1500  -- EN: 1.5 seconds between measuring / UA: 1.5 секунди між вимірами
    self.distanceForMeasuring = 3  -- EN: 3 meters / UA: 3 метри
    
    -- EN: Base perf (will be set in onLoad) / UA: Базова продуктивність (оновиться в onLoad)
    self.basePerfMass = 0  -- EN: kg per second / UA: кг на секунду
    self.currentAvgMass = 0
    self.lastAvgMass = 0  -- EN: Prior average for acceleration / UA: Попереднє середнє для прискорення
    self.rawAvgMass = 0  -- EN: Raw unsmoothed value for braking / UA: Сире незгладжене для гальмування
    
    -- EN: Current Load Enum / UA: Поточне навантаження
    self.engineLoad = 0
    self.speedLimit = 15  -- EN: Current km/h limit / UA: Поточний ліміт км/год
    self.genuineSpeedLimit = 15  -- EN: Genuine limits from game db / UA: Ліміт з гри
    self.lastCropType = nil  -- EN: Last crop / UA: Остання культура
    self.lastHarvestTime = 0  -- EN: Last harvest time / UA: Час останнього збирання
    
    -- Crop loss and productivity
    self.cropLoss = 0  -- EN: Current crop loss (%) / UA: Поточні втрати врожаю (%)
    self.tonPerHour = 0  -- EN: Yield in T/h / UA: Продуктивність в Т/год
    self.litersPerHour = 0  -- EN: Yield in L/h / UA: Продуктивність в Л/год
    self.totalOutputMass = 0  -- EN: Total harvested mass / UA: Загальна маса зібраного врожаю
    
    -- EN: Yield counters accumulation / UA: Накопичення продуктивності
    self.productivityMass = 0  -- EN: Accumulated mass (kg) / UA: Накопичена маса (кг)
    self.productivityLiters = 0  -- EN: Accumulated volume (L) / UA: Накопичений об'єм (л)
    self.productivityTime = 0  -- EN: Accumulation time (ms) / UA: Час накопичення (мс)
    self.productivityUpdateInterval = 3000  -- EN: Update interval (ms) / UA: Інтервал оновлення
    
    -- EN: Load accumulator / UA: Накопичувач навантаження
    self.loadAccumulatedMass = 0 -- kg
    
    -- Combine Settings System
    self.combineMemory = nil  -- EN: Will be set by rhm_Combine / UA: Буде встановлено з rhm_Combine
    self.currentCrop = nil    -- EN: Current crop for loss calc / UA: Поточна культура для розрахунку втрат
    
    self.debug = RHM_Debug and RHM_Debug.isEnabled("LoadCalculator") or false
    if self.debug then
        print("RHM: LoadCalculator initialized")
    end
    
    return self
end

---EN: Loads default crop difficulty factors / UA: Завантажує стандартні коефіцієнти складності культур
function LoadCalculator:loadDefaultCropFactors()
    -- EN: Target load factors for crops / UA: Цільові фактори навантаження для культур
    -- EN: Lower factor = lighter crop = faster drive / UA: Менший фактор = легша культура = комбайн їде швидше
    local factorMap = {
        ["WHEAT"] = 1.043,      -- Target: 6 km/h @ 8.0 t/ha
        ["BARLEY"] = 1.112,     -- Target: 6 km/h @ 7.5 t/ha
        ["OAT"] = 1.192,        -- Target: 6 km/h @ 7.0 t/ha
        ["MAIZE"] = 1.465,      -- Target: 3.5 km/h @ 11.6 t/ha (Grain)
        ["CORN"] = 1.465,
        ["MAIZE_FORAGE"] = 1.465, -- EN: Silage Maize / UA: Кукурудза на силос
        ["MAIZE_SILAGE"] = 1.465,
        ["SOYBEAN"] = 2.860,    -- Target: 5 km/h @ 3.5 t/ha
        ["SUNFLOWER"] = 2.975,  -- Target: 5 km/h @ 4.0 t/ha
        ["CANOLA"] = 2.224,     -- Target: 5 km/h @ 4.5 t/ha
        ["SORGHUM"] = 1.283,    -- Target: 6 km/h @ 6.5 t/ha
        
        -- EN: Rice is a heavy crop / UA: Рис важка культура
        ["RICE"] = 2.085,       -- Target: 4 km/h @ 6.0 t/ha
        ["RICE_LONG_GRAIN"] = 2.085,
        
        -- EN: Legumes / UA: Бобові
        ["PEA"] = 3.575,        -- Target: 4 km/h @ 3.5 t/ha
        ["LENTIL"] = 3.575,     -- Derived from Pea
        ["CHICKPEA"] = 3.575,   -- Derived from Pea
        
        -- EN: Root crops / UA: Коренеплоди
        ["POTATO"] = 2.186,     -- Target: 4 km/h @ 35.0 t/ha
        ["SUGARBEET"] = 1.275,  -- Target: 4 km/h @ 60.0 t/ha
        ["BEETROOT"] = 2.295,   -- Target: 4 km/h @ 50.0 t/ha
        ["CARROT"] = 3.400,     -- Target: 3 km/h @ 45.0 t/ha
        ["PARSNIP"] = 4.371,    -- Target: 3 km/h @ 35.0 t/ha
        ["ONION"] = 3.825,      -- Target: 3 km/h @ 40.0 t/ha
        
        -- EN: Vegetables (Green) - very light / UA: Овочі (зелені) - дуже легкі
        ["SPINACH"] = 3.825,    -- Target: 4 km/h @ 15.0 t/ha
        ["GREENBEAN"] = 7.172,  -- Target: 4 km/h @ 8.0 t/ha
        
        -- EN: Other / Mod crops / UA: Інші мод культури
        ["COTTON"] = 3.060,     -- Target: 5 km/h @ 2.5 t/ha
        ["SUGARCANE"] = 0.837,  -- Target: 4 km/h @ 80.0 t/ha
        ["POPLAR"] = 0.200,     -- Base target
        ["OILSEED_RADISH"] = 0.500,
        ["GRAPE"] = 0.500,
        ["OLIVE"] = 0.500,
        ["RYE"] = 1.043,        -- Derived from Wheat
        ["SPELT"] = 1.043,      -- Derived from Wheat
        ["TRITICALE"] = 0.590,  -- Target: 400 t/hr (Silage)
        ["MILLET"] = 1.250,     -- Derived from Oat/Sorghum
        ["ALFALFA"] = 0.858,    -- Target: 262 t/hr (@JD9900)
        ["MINT"] = 1.348,       -- Target: 175 t/hr
    }

    -- EN: Dynamically mapping FruitType Enum / UA: Динамічне мапування FruitType Enum
    for key, value in pairs(FruitType) do
        local mappedFactor = factorMap[key]
        
        -- Automatically map _WINDROW types to their base crop if not explicitly defined
        if not mappedFactor and key:find("_WINDROW") then
            local baseCrop = key:gsub("_WINDROW", "")
            mappedFactor = factorMap[baseCrop]
        end
        -- Also handle CUT_ crops like CUT_CANOLA
        if not mappedFactor and key:find("CUT_") then
            local baseCrop = key:gsub("CUT_", "")
            mappedFactor = factorMap[baseCrop]
        end

        if mappedFactor then
            self.CROP_FACTORS[value] = mappedFactor
        elseif type(value) == "number" and not key:find("NUM_") then
            -- Fallback
        end
    end
end

---EN: Sets base performance mass / UA: Встановлює базову продуктивність (маса)
---@param basePerfMass number EN: Base performance (kg/s) / UA: Базова продуктивність (кг/с)
function LoadCalculator:setBasePerformance(basePerfMass)
    self.basePerfMass = basePerfMass
    
    if rhm_Combine and rhm_Combine.debug then
        print(string.format("RHM: Base performance set to %.2f kg/s (%.1f t/h)", 
            self.basePerfMass, self.basePerfMass * 3.6))
    end
end

---EN: Gets base performance from engine power / UA: Отримує базову продуктивність з потужності двигуна
---@param vehicle table EN: Combine Harvester / UA: Комбайн
---@return number EN: Base performance (kg/s) / UA: Базова продуктивність в кг/сек
function LoadCalculator:getBasePerformanceFromPower(vehicle)
    -- NEW LOGIC: Calculate throughput based on Horsepower
    -- Approximation: 1 HP ~= 0.035 kg/s throughput for Grain
    
    local coef = 0.035  -- EN: Standard coefficient for grain / UA: Стандартний коефіцієнт для зерна
    local power = 0
    
    local keyCategory = "vehicle.storeData.category"
    local category = vehicle.xmlFile:getValue(keyCategory)
    
    if category == "forageHarvesters" or category == "forageHarvesterCutters" then
        coef = 0.051  -- Forage harvesters: calibrated to JD 9900 (956hp) ~400 t/hr corn silage
    elseif category == "beetVehicles" or category == "beetHarvesting" then
        coef = 0.060  -- Beet harvesting
    elseif category == "potatoVehicles" then
        coef = 0.060  -- Potato harvesting
    elseif category == "cottonVehicles" then
        coef = 0.015  -- Cotton
    elseif category == "vegetableVehicles" then
        coef = 0.060  -- Vegetable harvesting
    end
    
    if vehicle.spec_motorized and vehicle.spec_motorized.motor then
        power = vehicle.spec_motorized.motor.hp or 0
    end
    
    -- SMART DETECTION: If category didn't match specific types
    if math.abs(coef - 0.035) < 0.001 then
        local isVegetable = false
        
        -- 1. Check FillTypes (if available)
        if vehicle.getFillUnitFillTypes and vehicle.spec_fillUnit then
            for _, fillUnit in ipairs(vehicle.spec_fillUnit.fillUnits) do
                 if fillUnit.supportedFillTypes then
                     for fillTypeIndex, _ in pairs(fillUnit.supportedFillTypes) do
                        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                        if fillType and fillType.name then
                            local name = string.upper(fillType.name)
                            if name == "ONION" or name == "CARROT" or name == "BEETROOT" or name == "PARSNIP" then
                                isVegetable = true
                                break
                            end
                        end
                     end
                 end
                 if isVegetable then break end
            end
        end
        
        -- 2. Check Vehicle Name / Filename
        if not isVegetable then
            local name = string.lower(vehicle:getFullName() or "")
            local xml = string.lower(vehicle.configFileName or "")
            
            if name:find("onion") or name:find("carrot") or name:find("vegetable") or 
               xml:find("onion") or xml:find("carrot") or xml:find("vegetable") or
               name:find("ur%-%d+") or name:find("umr") or name:find("keiler") or 
               xml:find("ur_") or xml:find("umr_") then
                isVegetable = true
            end
        end
        
        if isVegetable then
            coef = 0.060 -- EN: Standardized vegetable coefficient / UA: Стандартизований коефіцієнт для овочів
        end
    end
    
    -- NEXAT FIX (Module search)
    if (not power or power == 0) then
        local function findVehicleWithEngine(v)
            if not v then return nil end
            if v.spec_motorized and v.spec_motorized.motor and v.spec_motorized.motor.hp and v.spec_motorized.motor.hp > 0 then
                return v
            end
            if v.getAttacherVehicle then
                return findVehicleWithEngine(v:getAttacherVehicle())
            end
            if v.rootVehicle and v.rootVehicle ~= v then
                 if v.rootVehicle.spec_motorized and v.rootVehicle.spec_motorized.motor and v.rootVehicle.spec_motorized.motor.hp > 0 then
                    return v.rootVehicle
                 end
            end
            return nil
        end
        local engineVeh = findVehicleWithEngine(vehicle)
        if engineVeh then
            power = engineVeh.spec_motorized.motor.hp or 0
        end
    end
    
    if power == 0 then
        local key, motorId = ConfigurationUtil.getXMLConfigurationKey(
            vehicle.xmlFile, 
            vehicle.configurations.motor, 
            "vehicle.motorized.motorConfigurations.motorConfiguration", 
            "vehicle.motorized", 
            "motor"
        )
        local fallbackConfigKey = "vehicle.motorized.motorConfigurations.motorConfiguration(0)"
        local fallbackOldKey = "vehicle"
        
        if SpecializationUtil.hasSpecialization(Motorized, vehicle.specializations) then
            power = ConfigurationUtil.getConfigurationValue(
                vehicle.xmlFile, key, "", "#hp", nil, fallbackConfigKey, fallbackOldKey
            )
        end
    end
    
    if power and tonumber(power) > 0 then
        local basePerf = tonumber(power) * coef
        if rhm_Combine and rhm_Combine.debug then
            print(string.format("RHM DEBUG: BasePerf Mass computed for %s (cat: %s, coef: %.3f): %d hp -> %.2f kg/s (%.1f t/h)", 
                vehicle:getFullName(), category or "unknown", coef, power, basePerf, basePerf * 3.6))
        end
        return basePerf
    end
    
    -- NEXAT POWER FIX
    if vehicle.configFileName and vehicle.configFileName:lower():find("nexat") then
        local basePerf = 1100 * coef  
        return basePerf
    end
    
    return 10.0  -- Default ~36 t/h
end

---EN: Updates load calculation variables / UA: Оновлює дані для розрахунку навантаження
---@param mass number EN: Intake Mass (kg) / UA: Маса зібраного врожаю (кг)
function LoadCalculator:update(vehicle, dt, mass)
    self.totalDistance = self.totalDistance + vehicle.lastMovedDistance
    self.loadAccumulatedMass = (self.loadAccumulatedMass or 0) + mass
    
    -- INSTANT REACTION FIX:
    if mass > 0 and self.speedLimit >= (self.genuineSpeedLimit - 0.1) then
         self.speedLimit = 5.0 -- EN: Conservative start / UA: Консервативний старт
    end
    
    self.currentTime = self.currentTime + dt
    if self.currentTime > self.avgTime or self.totalDistance > self.distanceForMeasuring then
        self:updateSettingsImpact() -- EN: Recalculate settings penalty / UA: Перераховання штрафу налаштувань
        self:calculateEngineLoad(vehicle)
        self:calculateSpeedLimit(vehicle)
        
        -- EN: Reset tick accumulators / UA: Скидаємо лічильники
        self.currentTime = 0
        self.loadAccumulatedMass = 0
        self.totalDistance = 0
    end
end

---EN: Calculates Engine Load / UA: Розраховує навантаження на двигун
---@param vehicle table EN: Combine / UA: Комбайн
function LoadCalculator:calculateEngineLoad(vehicle)
    if self.currentTime <= 0 then
        return
    end
    
    local cropFactor = 1.0
    local spec_combine = vehicle.spec_combine
    if spec_combine and spec_combine.lastValidInputFruitType then
        cropFactor = self.CROP_FACTORS[spec_combine.lastValidInputFruitType] or 1.0
    end
    
    -- EN: INPUT DETECTION (PICKUP / CUTTER) / UA: ДЕТЕКЦІЯ ТИПУ ОБЛАДНАННЯ
    local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(spec_combine.lastValidInputFruitType)
    local currentFruitTypeName = string.upper(fruitTypeDesc and fruitTypeDesc.name or "UNKNOWN")
    local isPickup = (spec_combine and spec_combine.lastValidInputFruitType == 0)
    local isForageCutter = false

    -- EN: TECHNICAL DIAGNOSTICS & HEADER DETECTION / UA: ТЕХНІЧНА ДІАГНОСТИКА ТА ДЕТЕКЦІЯ ЖАТОК
    if not isPickup and vehicle.getAttachedImplements then
        -- Method 1: RHM Machine Type (Already detected in rhm_Combine.lua)
        local rhmSpec = vehicle.spec_rhm_Combine
        if rhmSpec and rhmSpec.machineType == "forage" then
             isForageCutter = true
        end

        for _, implement in pairs(vehicle:getAttachedImplements()) do
            local implObj = implement.object
            if implObj then
                local storeItem = g_storeManager:getItemByXMLFilename(implObj.configFileName)
                local cat = storeItem and storeItem.categoryName or ""
                
                -- Method 2: Specializations
                if implObj.spec_forageHarvesterCutter ~= nil or implObj.spec_forageCutter ~= nil then
                    isForageCutter = true
                end

                -- Method 3: Category
                if not isForageCutter and cat == "forageHarvesterCutters" then
                    isForageCutter = true
                end

                -- Method 4: allowedFillTypes
                if not isForageCutter and implObj.spec_cutter and implObj.spec_cutter.allowedFillTypes then
                    for fTypeIndex, allowed in pairs(implObj.spec_cutter.allowedFillTypes) do
                        if allowed then
                            local fDesc = g_fillTypeManager:getFillTypeByIndex(fTypeIndex)
                            local fName = string.upper(fDesc and fDesc.name or "UNKNOWN")
                            if fName:find("MAIZE") or fName:find("FORAGE") or fName:find("SILAGE") or fName:find("GRASS") then
                                isForageCutter = true
                                break
                            end
                        end
                    end
                end

                if isForageCutter then break end
            end
        end
    end

    -- EN: APPLY MULTIPLIERS / UA: ЗАСТОСУВАННЯ МНОЖНИКІВ
    if isPickup then
        cropFactor = cropFactor * 0.35  -- EN: Picking up windrows / UA: Підбір валків
    elseif isForageCutter then
        cropFactor = cropFactor * 0.75  -- EN: Forage harvesters (silage/direct cut) / UA: Кормозбиральні комбайни (силос/пряме косіння)
    end

    -- --- [RHM DEBUG: INFO LOG] ---
    if rhm_Combine and rhm_Combine.debug and self.lastCropType ~= spec_combine.lastValidInputFruitType then
        self.lastCropType = spec_combine.lastValidInputFruitType
        local mode = isPickup and "PICKUP" or (isForageCutter and "FORAGE_CUTTER" or "DIRECT_CUT")
        print(string.format("RHM DEBUG: [INPUT] %s (%s). Final Factor: %.3f", mode, currentFruitTypeName, cropFactor))
    end
    
    -- EN: Calculate RAW average mass intake per second / UA: Розраховуємо RAW середню масу за секунду (кг/с)
    -- EN: Uses accumulatedMass over the target distance/time / UA: Використовуємо accumulatedMass
    local rawAvgMass = (self.loadAccumulatedMass or 0) * (1000 / self.currentTime) * cropFactor
    
    -- ADAPTIVE SMOOTHING
    local loadRatio = self.currentAvgMass / math.max(0.01, self.basePerfMass)
    local smoothFactor = 0.3 + 0.4 * math.min(1.0, loadRatio)
    smoothFactor = math.min(0.7, smoothFactor)  -- Max 70% smoothing
    
    local avgMass = rawAvgMass
    if self.currentAvgMass > (0.5 * self.basePerfMass) then
        avgMass = (1 - smoothFactor) * rawAvgMass + smoothFactor * self.currentAvgMass
    end
    
    self.lastAvgMass = self.currentAvgMass
    self.currentAvgMass = avgMass
    self.rawAvgMass = rawAvgMass  
    
    -- EN: Fetch power boost for load calculation / UA: Отримуємо power boost для розрахунку навантаження
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass * (self.settingsEfficiency or 1.0)
    
    if maxAvgMass > 0 then
        self.engineLoad = self.currentAvgMass / maxAvgMass
    else
        self.engineLoad = 0
    end
end

---EN: Calculates Vehicle Speed Limit / UA: Розраховує обмеження швидкості
---@param vehicle table EN: Vehicle object / UA: Об'єкт транспортного засобу
function LoadCalculator:calculateSpeedLimit(vehicle)
    if self.currentAvgMass == 0 then
        if self.speedLimit < self.genuineSpeedLimit then
            self.speedLimit = math.min(self.genuineSpeedLimit, self.speedLimit + 1.0)
        end
        return
    end
    
    local currentSpeed = vehicle.lastSpeedReal * 3600 
    local speedKmh = math.max(1.0, currentSpeed)
    if currentSpeed < 1.0 and self.currentAvgMass > (self.basePerfMass * 0.1) then
        speedKmh = math.max(2.0, self.speedLimit)
    end
    
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass * (self.settingsEfficiency or 1.0)
    if maxAvgMass <= 0.01 then return end
    
    local loadRatio = self.currentAvgMass / maxAvgMass
    local rawLoadRatio = (self.rawAvgMass or self.currentAvgMass) / maxAvgMass
    
    local targetLoad = 0.85
    local idealSpeed = self.genuineSpeedLimit
    
    if loadRatio > 0.05 then 
        idealSpeed = speedKmh * (targetLoad / loadRatio)
    end
    idealSpeed = math.min(self.genuineSpeedLimit, math.max(2.0, idealSpeed))
    
    local alpha = 0.1 
    local controlZone = "NORMAL"
    
    if rawLoadRatio > 1.25 then
        alpha = 1.0 -- PANIC
        controlZone = "PANIC"
        local emergencyIdeal = math.min(speedKmh, self.speedLimit) * (targetLoad / rawLoadRatio)
        idealSpeed = math.min(idealSpeed, math.max(2.0, emergencyIdeal))
    elseif rawLoadRatio > 1.10 then
        alpha = 0.6 -- HARD BRAKE
        controlZone = "HARD_BRAKE"
        local hardbrakeIdeal = math.min(speedKmh, self.speedLimit) * (targetLoad / rawLoadRatio)
        idealSpeed = math.min(idealSpeed, math.max(2.0, hardbrakeIdeal))
    elseif loadRatio >= 0.85 and loadRatio <= 0.95 then
        alpha = 0.02 -- DEADBAND
        controlZone = "LOCKED"
    elseif loadRatio < 0.85 then
        if loadRatio < 0.50 then
            alpha = 0.40 -- FAST ACCEL
            controlZone = "ACCEL_FAST"
        elseif loadRatio < 0.75 then
            alpha = 0.25 
            controlZone = "ACCEL_MED"
        else
            alpha = 0.15 
            controlZone = "ACCEL_SLOW"
        end
    end
    
    local diff = idealSpeed - self.speedLimit
    local maxStep = 1.0
    if controlZone == "PANIC" then maxStep = 10.0 end
    if controlZone == "HARD_BRAKE" then maxStep = 5.0 end
    
    local step = diff * alpha
    step = math.clamp(step, -maxStep, maxStep)
    self.speedLimit = self.speedLimit + step
end

---EN: Returns current engine load factor / UA: Повертає поточне навантаження двигуна
---@return number EN: Percentage load (0-100+) / UA: Навантаження у відсотках (0-100+)
function LoadCalculator:getEngineLoad()
    return self.engineLoad * 100
end

---EN: Returns calculated speed limit target / UA: Повертає остаточний ліміт швидкості
---@return number EN: Target speed (km/h) / UA: Ліміт швидкості в км/год
function LoadCalculator:getSpeedLimit()
    return self.speedLimit or 0
end

---EN: Caches base limit speed boundary / UA: Встановлює оригінальні межі ліміту
---@param limit number EN: Original top limit / UA: Оригінальний ліміт швидкості
function LoadCalculator:setGenuineSpeedLimit(limit)
    self.genuineSpeedLimit = limit
    self.speedLimit = limit
end

---EN: Fully resets accumulated internal data variables / UA: Повністю очищує змінні бази даних
function LoadCalculator:reset()
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.currentAvgMass = 0
    self.engineLoad = 0
    self.cropLoss = 0
    self.speedLimit = self.genuineSpeedLimit
    self.productivityMass = 0
    self.productivityLiters = 0
    self.productivityTime = 0
    self.tonPerHour = 0
    self.litersPerHour = 0
    self.yieldBuffer = {}
    self.currentYield = 0
    self.instantYield = 0
end

---EN: Calculates settings-related quality losses / UA: Розраховує втрати врожаю
---@return number EN: Loss percent (0-50) / UA: Втрати у відсотках (0-50)
function LoadCalculator:calculateCropLoss()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then return 0 end
    if not g_realisticHarvestManager.settings.enableCropLoss then return 0 end
    
    local activeEfficiency = self.settingsEfficiency or 1.0
    local shieldBonus = math.max(0, activeEfficiency - 1.0)
    local lossThreshold = 0.95 + shieldBonus
    
    if self.engineLoad > lossThreshold then
        local overload = self.engineLoad - lossThreshold
        local lossMultiplier = g_realisticHarvestManager.settings:getLossMultiplier()
        local loss = 0
        if overload <= 0.10 then
            loss = overload * 40 * lossMultiplier
        elseif overload <= 0.20 then
            loss = (4.0 + (overload - 0.10) * 80) * lossMultiplier
        else
            loss = (12.0 + (overload - 0.20) * 150) * lossMultiplier
        end
        self.cropLoss = math.min(loss, 50) 
    else
        self.cropLoss = 0
    end
    return self.cropLoss
end

---EN: Calculates losses from inaccurate player threshing settings / UA: Розраховує втрати від неправильних налаштувань гравцем
function LoadCalculator:updateSettingsImpact()
    self.settingsEfficiency = 1.0
    self.settingsLoss = 0
    if not self.combineMemory or not self.currentCrop then return end
    local effPenalty, lossPenalty, _ = self.combineMemory:checkSettingsForCrop(self.currentCrop)
    
    if effPenalty < 0 then
        self.settingsEfficiency = 1.0 + (math.abs(effPenalty) * 5.0 / 100.0)
    else
        self.settingsEfficiency = 1.0 - (effPenalty / 100.0)
    end
    
    if lossPenalty < 0 then
        self.settingsLoss = 0 
    else
        self.settingsLoss = lossPenalty
    end
end

---@return number totalLoss EN: System Total Damage Result (0-50%) / UA: Підсумковий результат втрат
function LoadCalculator:calculateTotalCropLoss()
    local baseLoss = self:calculateCropLoss()
    local settingsAddedLoss = self.settingsLoss or 0
    local totalLoss = baseLoss + settingsAddedLoss
    totalLoss = math.min(totalLoss, 50)
    self.cropLoss = totalLoss
    return totalLoss
end

---EN: Returns instantaneous processed metric tonnes per clock hour / UA: Перерахунок в тонни на годину
---@return number EN: T/H Metric / UA: Тонни
function LoadCalculator:getTonPerHour()
    return self.tonPerHour
end

---EN: Returns yield in L/h / UA: Розрахунок літрів на годину
---@return number EN: L/H Volume / UA: Літраж
function LoadCalculator:getLitersPerHour()
    return self.litersPerHour or 0
end

---EN: Updates sliding window rolling averages for metric evaluations / UA: Оновлює ковзні середні продуктивності
---@param mass number EN: Active kg flow / UA: КГ врожаю
---@param liters number EN: Liter capacity / UA: Об'єм
function LoadCalculator:updateProductivity(mass, liters, dt)
    self.totalOutputMass = self.totalOutputMass + mass
    self.prodBuffer = self.prodBuffer or {}
    table.insert(self.prodBuffer, {m = mass, l = liters or 0, t = dt})
    
    self.currentBufferTime = (self.currentBufferTime or 0) + dt
    while #self.prodBuffer > 1 and self.currentBufferTime > 12000 do
        local old = table.remove(self.prodBuffer, 1)
        self.currentBufferTime = self.currentBufferTime - old.t
    end
    
    local sumMass = 0
    local sumLiters = 0
    local sumTime = 0
    for _, v in ipairs(self.prodBuffer) do
        sumMass = sumMass + v.m
        sumLiters = sumLiters + v.l
        sumTime = sumTime + v.t
    end
    
    if sumTime > 100 then
        local hours = sumTime / 3600000
        local rawTonPerHour = (sumMass / 1000) / hours
        self.litersPerHour = sumLiters / hours
        local alpha = 0.05
        if self.tonPerHour == 0 then self.tonPerHour = rawTonPerHour end
        self.tonPerHour = self.tonPerHour * (1 - alpha) + rawTonPerHour * alpha
    else
        self.tonPerHour = 0
        self.litersPerHour = 0
    end
end

---EN: Processes complete physical output block calculations / UA: Виконує розрахунки врожайності
---@param mass number EN: Kg Base / UA: Маса база
function LoadCalculator:updateProductivityAndYield(mass, liters, area, dt)
    self:updateProductivity(mass, liters, dt)
    if area <= 0.0001 and mass <= 0.001 then
        self.currentYield = self.currentYield or 0
        return
    end
    
    self.yieldBuffer = self.yieldBuffer or {}
    table.insert(self.yieldBuffer, {m = mass, a = area})
    if #self.yieldBuffer > 600 then table.remove(self.yieldBuffer, 1) end
    
    local sumMass = 0
    local sumArea = 0
    for _, v in ipairs(self.yieldBuffer) do 
        sumMass = sumMass + v.m
        sumArea = sumArea + v.a 
    end
    
    if sumArea > 0.1 then
        local rawYield = (sumMass / sumArea) * 10
        local alpha = 0.03
        if not self.currentYield or self.currentYield == 0 then self.currentYield = rawYield end
        self.currentYield = self.currentYield * (1 - alpha) + rawYield * alpha
    end
end

function LoadCalculator:setRealTimeYield(yieldTha)
    self.yieldBuffer = self.yieldBuffer or {}
    table.insert(self.yieldBuffer, yieldTha)
    if #self.yieldBuffer > 20 then table.remove(self.yieldBuffer, 1) end
    local sum = 0
    for _, v in ipairs(self.yieldBuffer) do sum = sum + v end
    self.currentYield = sum / #self.yieldBuffer
end

---EN: Returns formatted yield string / UA: Отримує форматований рядок врожайності
---@param unitSystem number (1=Metric, 2=Imperial, 3=Bushels)
---@return string, string (Value, Unit)
function LoadCalculator:getYieldText(unitSystem)
    local yield = self.currentYield or 0
    if yield < 0.1 then return "0.0", "t/ha" end
    
    if unitSystem == 2 then 
        return string.format("%.2f", yield * 0.446), "t/ac"
    elseif unitSystem == 3 then 
        return string.format("%.0f", yield * 15), "bu/ac"
    else 
        return string.format("%.1f", yield), "t/ha"
    end
end
