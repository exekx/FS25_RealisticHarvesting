---@class LoadCalculator
-- Розраховує навантаження на двигун комбайна
LoadCalculator = {}
local LoadCalculator_mt = Class(LoadCalculator)

function LoadCalculator.new(modDirectory)
    local self = setmetatable({}, LoadCalculator_mt)
    
    self.debug = false -- TEMPORARY DEBUG ENABLED
    self.modDirectory = modDirectory or g_currentModDirectory  -- Зберігаємо modDirectory (with fallback)
    
    -- Коефіцієнти складності культур
    self.CROP_FACTORS = {}
    self:loadDefaultCropFactors()
    
    -- Дані для розрахунку середнього навантаження
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.avgTime = 1500  -- 1.5 секунди між вимірами
    self.distanceForMeasuring = 3  -- 3 метри
    
    -- Базова продуктивність (буде встановлена в onLoad)
    self.basePerfMass = 0  -- кг на секунду
    self.currentAvgMass = 0
    self.lastAvgMass = 0  -- Попереднє середнє (для розрахунку прискорення)
    self.rawAvgMass = 0  -- Сире (незгладжене) значення для аварійного гальмування
    
    -- Поточне навантаження
    self.engineLoad = 0
    self.speedLimit = 15  -- Поточний ліміт швидкості (км/год)
    self.genuineSpeedLimit = 15  -- Оригінальний ліміт з гри
    self.workingSpeedLimit = 0  -- Робочий ліміт (зберігається між сесіями збирання)
    self.lastCropType = nil  -- Остання культура (для детекції зміни)
    self.lastHarvestTime = 0  -- Час останнього збирання (для детекції тривалої паузи)
    
    -- Crop loss and productivity
    self.cropLoss = 0  -- Поточні втрати врожаю (%)
    self.tonPerHour = 0  -- Продуктивність в T/h
    self.litersPerHour = 0  -- Продуктивність в L/h
    self.totalOutputMass = 0  -- Загальна маса зібраного врожаю
    
    -- Накопичення для розрахунку T/h та L/h
    self.productivityMass = 0  -- Накопичена маса за поточний період (кг)
    self.productivityLiters = 0  -- Накопичений об'єм за поточний період (л)
    self.productivityTime = 0  -- Час накопичення (мс)
    self.productivityUpdateInterval = 3000  -- Оновлювати кожні 3 секунди
    
    -- Накопичувач для розрахунку навантаження
    self.loadAccumulatedMass = 0 -- кг
    
    -- Combine Settings System
    self.combineMemory = nil  -- Буде встановлено з rhm_Combine
    self.currentCrop = nil    -- Поточна культура для розрахунку settings loss
    
    print("RHM: LoadCalculator initialized")
    
    return self
end

---Завантажує стандартні коефіцієнти культур
function LoadCalculator:loadDefaultCropFactors()
    -- Fallback до базових значень
    -- 1.0 = Стандарт (Пшениця)
    self.CROP_FACTORS[FruitType.WHEAT] = 1.0
    self.CROP_FACTORS[FruitType.BARLEY] = 1.0 -- Barley same/slightly easier than wheat
    
    -- Кукурудза: Збільшено до 1.2 (було 0.85) для реалістичної швидкості 5-6 км/год
    -- Кукурудза містить багато маси і важка для обробки
    self.CROP_FACTORS[FruitType.MAIZE] = 1.2
    
    -- Соя: В таблиці 0.7 vs 0.8 Wheat -> легше. АЛЕ в FS25 вона дуже легка за вагою. 
    -- Щоб отримати реалістичну швидкість (6-7 км/год), треба підняти до 1.8
    self.CROP_FACTORS[FruitType.SOYBEAN] = 1.8
    
    -- Соняшник: Дуже легкий за масою (0.18 kg/m2). Треба фактор 2.0 для швидкості 9-10 км/год.
    self.CROP_FACTORS[FruitType.SUNFLOWER] = 2.0
    
    -- Ріпак: Легший за пшеницю, але густий. Фактор 1.3 -> ~7 км/год.
    self.CROP_FACTORS[FruitType.CANOLA] = 1.3
    
     -- Овес: Дуже легкий (0.57 l/m2), тому треба великий фактор (2.2), щоб не літати під 14 км/год
    self.CROP_FACTORS[FruitType.OAT] = 2.2
    
    -- Other cereals (standard extensions)
    if FruitType.RYE then self.CROP_FACTORS[FruitType.RYE] = 1.0 end
    if FruitType.SPELT then self.CROP_FACTORS[FruitType.SPELT] = 1.0 end
    if FruitType.TRITICALE then self.CROP_FACTORS[FruitType.TRITICALE] = 1.0 end
    if FruitType.MILLET then self.CROP_FACTORS[FruitType.MILLET] = 0.9 end
    
    -- Sorghum (mass similar to wheat but grain header use). 0.9 -> ~6-7 km/h
    if FruitType.SORGHUM then self.CROP_FACTORS[FruitType.SORGHUM] = 0.9 end
    
    -- Rice (Tough) - Factor 2.3 for ~4 km/h
    if FruitType.RICE then self.CROP_FACTORS[FruitType.RICE] = 2.3 end
    -- Rice Long - Factor 1.5 for ~5 km/h
    if FruitType.RICELONGGRAIN then self.CROP_FACTORS[FruitType.RICELONGGRAIN] = 1.5 end
    
    -- Pulses (Legumes harvested by grain combine or special header)
    -- PEA: lightweight grain, similar to soybean in handling → factor 1.2
    
    -- Root Crops (Massive Mass -> Low Factors)
    -- Root Crops (Massive Mass -> Low Factors)
    if FruitType.SUGARBEET then self.CROP_FACTORS[FruitType.SUGARBEET] = 0.35 end
    if FruitType.POTATO then self.CROP_FACTORS[FruitType.POTATO] = 0.40 end
    
    -- Vegetable Crops (High Volume -> Low Factors)
    -- Tuned for High Yield Maps (approx 10x standard)
    if FruitType.CARROT then self.CROP_FACTORS[FruitType.CARROT] = 0.30 end
    if FruitType.PARSNIP then self.CROP_FACTORS[FruitType.PARSNIP] = 0.30 end
    if FruitType.BEETROOT then self.CROP_FACTORS[FruitType.BEETROOT] = 0.30 end
    if FruitType.ONION then self.CROP_FACTORS[FruitType.ONION] = 0.30 end 
    
    -- Leafy / Tender Vegetables (light mass → need HIGH factor for realistic engine load)
    -- Spinach is very light (~0.02 kg/m2 fresh) but vegetable harvesters run slow speeds.
    -- Factor 3.0 ensures realistic engine load on low-basePerfMass vegetable harvesters.
    if FruitType.SPINACH then self.CROP_FACTORS[FruitType.SPINACH] = 3.0 end

    -- Pulses (harvested by standard or vegetable combine)
    if FruitType.PEA then self.CROP_FACTORS[FruitType.PEA] = 1.2 end        -- Similar to wheat
    if FruitType.GREENBEAN then self.CROP_FACTORS[FruitType.GREENBEAN] = 2.5 end -- Light, gentle harvest
    
    -- Special
    if FruitType.COTTON then self.CROP_FACTORS[FruitType.COTTON] = 3.0 end -- Light but slow
    if FruitType.SUGARCANE then self.CROP_FACTORS[FruitType.SUGARCANE] = 0.1 end -- Massive mass
    
    -- Other
    if FruitType.POPLAR then self.CROP_FACTORS[FruitType.POPLAR] = 0.2 end -- massive yield (6.6 l/m2)
    if FruitType.OILSEEDRADISH then self.CROP_FACTORS[FruitType.OILSEEDRADISH] = 0.5 end
    
    if FruitType.GRAPE then self.CROP_FACTORS[FruitType.GRAPE] = 0.5 end
    if FruitType.OLIVE then self.CROP_FACTORS[FruitType.OLIVE] = 0.5 end
end

---Встановлює базову продуктивність комбайна mass-based
---@param basePerfMass number Базова продуктивність в кг/с
function LoadCalculator:setBasePerformance(basePerfMass)
    self.basePerfMass = basePerfMass
    
    if self.debug then
        print(string.format("RHM: Base performance set to %.2f kg/s (%.1f t/h)", 
            self.basePerfMass, self.basePerfMass * 3.6))
    end
end

---Отримує базову продуктивність з потужності двигуна
---@param vehicle table Комбайн
---@return number Базова продуктивність в кг/сек
function LoadCalculator:getBasePerformanceFromPower(vehicle)
    -- NEW LOGIC: Calculate throughput based on Horsepower
    -- Approximation: 1 HP ~= 0.035 kg/s throughput for Grain
    -- Example: 790 HP (X9 1100) -> 27.65 kg/s -> ~100 t/h
    -- Example: 500 HP (S780) -> 17.5 kg/s -> ~63 t/h
    
    local coef = 0.035  -- Стандартний коефіцієнт для зернозбиральних комбайнів (kg/s per HP)
    local power = 0
    
    -- Визначаємо тип техніки за категорією
    local keyCategory = "vehicle.storeData.category"
    local category = vehicle.xmlFile:getValue(keyCategory)
    
    if category == "forageHarvesters" or category == "forageHarvesterCutters" then
        coef = 0.150  -- Кормозбиральні: ~150-200 t/h -> 0.15 kg/s per HP
    elseif category == "beetVehicles" or category == "beetHarvesting" then
        coef = 0.060  -- Бурякозбиральні: very high throughput
    elseif category == "potatoVehicles" then
        coef = 0.060  -- Картоплезбиральні
    elseif category == "cottonVehicles" then
        coef = 0.015  -- Бавовна (легка, повільна обробка)
    elseif category == "vegetableVehicles" then
        coef = 0.060  -- Овочева техніка (Adjusted for realistic load)
    end
    
    -- Спробувати отримати потужність з motorized spec
    if vehicle.spec_motorized and vehicle.spec_motorized.motor then
        power = vehicle.spec_motorized.motor.hp or 0
    end
    
    -- SMART DETECTION: If category didn't match specific types (still default 0.035), checks fillTypes AND Names
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
        
        -- 2. Check Vehicle Name / Filename (Fallback for windrowers/diggers like UR-205)
        if not isVegetable then
            local name = string.lower(vehicle:getFullName() or "")
            local xml = string.lower(vehicle.configFileName or "")
            
            if name:find("onion") or name:find("carrot") or name:find("vegetable") or 
               xml:find("onion") or xml:find("carrot") or xml:find("vegetable") or
               name:find("ur%-%d+") or name:find("umr") or name:find("keiler") or -- UR-205, UMR, Ropa Keiler
               xml:find("ur_") or xml:find("umr_") then
                isVegetable = true
                print(string.format("RHM: Smart Detection -> Found keyword in name/xml (%s), assuming Vegetable", name))
            end
        end
        
        if isVegetable then
            coef = 0.060 -- Standardized vegetable coeff
            print("RHM: Applied Vegetable Coef (0.060)")
        end
    end
    
    -- Debug entry
    -- print(string.format("RHM DEBUG: Checking power for %s. Initial power: %s", vehicle:getFullName(), tostring(power)))
    
    -- NEXAT FIX: Якщо це модуль (немає мотора), шукаємо двигун рекурсивно вгору по ієрархії
    if (not power or power == 0) then
        local function findVehicleWithEngine(v)
            if not v then return nil end
            
            -- Check current vehicle
            if v.spec_motorized and v.spec_motorized.motor and v.spec_motorized.motor.hp and v.spec_motorized.motor.hp > 0 then
                return v
            end
            
            -- Debug traversal
            -- print(string.format("RHM DEBUG: Search engine in %s (hasAttacher: %s, root: %s)", 
            --    v:getFullName(), tostring(v.getAttacherVehicle ~= nil), v.rootVehicle and v.rootVehicle:getFullName() or "nil"))

            -- Check attacher vehicle (upwards)
            if v.getAttacherVehicle then
                return findVehicleWithEngine(v:getAttacherVehicle())
            end
            
            -- FALLBACK: Check rootVehicle directly if recursion failed/ended
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
            -- print(string.format("RHM DEBUG: Found power in hierarchy (%s): %d HP", engineVeh:getFullName(), power))
        end
    end
    
    -- Якщо не знайшли, спробувати з XML
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
        -- Стандартний розрахунок: 1 HP ~= 0.035 kg/s throughput
        -- Для 1100 HP (NEXAT) це буде ~38.5 kg/s (~138 t/h)
        -- Для 500 HP це буде ~17.5 kg/s (~63 t/h)
        local basePerf = tonumber(power) * coef
        
        print(string.format("RHM DEBUG: BasePerf Mass computed for %s (cat: %s, coef: %.3f): %d hp -> %.2f kg/s (%.1f t/h)", 
            vehicle:getFullName(), category or "unknown", coef, power, basePerf, basePerf * 3.6))
        return basePerf
    end
    
    -- NEXAT POWER FIX: Якщо це NEXAT і power не знайдено, використовуємо 1100hp
    -- Debug показав що система не бачить двигун NEXAT (modular structure issue)
    if vehicle.configFileName and vehicle.configFileName:lower():find("nexat") then
        local basePerf = 1100 * coef  -- 1100hp * 0.035 = 38.5 kg/s
        print(string.format("RHM: NEXAT detected with power=0 - using hardcoded 1100 HP -> %.2f kg/s", basePerf))
        return basePerf
    end
    
    print("RHM: Warning - Could not determine combine power, using default basePerf")
    return 10.0  -- Default ~36 t/h
end

---Оновлює дані для розрахунку навантаження
---@param vehicle table Комбайн
---@param dt number Delta time в мс
---@param mass number Маса зібраного врожаю (кг) - НОВИЙ ПАРАМЕТР
function LoadCalculator:update(vehicle, dt, mass)
    -- Оновлюємо відстань
    self.totalDistance = self.totalDistance + vehicle.lastMovedDistance
    
    -- Оновлюємо масу (замість площі)
    self.loadAccumulatedMass = (self.loadAccumulatedMass or 0) + mass
    
    -- INSTANT REACTION FIX:
    -- Якщо почали збирати (mass > 0), а ліміт все ще максимальний - негайно обмежуємо
    -- Не чекаємо 1.5 секунди вимірювання
    if mass > 0 and self.speedLimit >= (self.genuineSpeedLimit - 0.1) then
         if self.workingSpeedLimit > 0 and self.workingSpeedLimit < 12 then
             self.speedLimit = self.workingSpeedLimit
         else
             self.speedLimit = 5.0 -- Консервативний старт
             self.workingSpeedLimit = 5.0
         end
         if self.debug then
            print("RHM: Instant start limit applied: " .. tostring(self.speedLimit))
         end
    end
    
    -- Оновлюємо час
    self.currentTime = self.currentTime + dt
    
    -- Перевіряємо чи час для нового виміру
    if self.currentTime > self.avgTime or self.totalDistance > self.distanceForMeasuring then
        self:calculateEngineLoad(vehicle)
        self:calculateSpeedLimit(vehicle)
        
        -- Скидаємо лічильники
        self.currentTime = 0
        self.loadAccumulatedMass = 0
        self.totalDistance = 0
    end
end

---Розраховує навантаження на двигун (Mass-based)
---@param vehicle table Комбайн
function LoadCalculator:calculateEngineLoad(vehicle)
    if self.currentTime <= 0 then
        return
    end
    
    -- Отримуємо коефіцієнт культури
    local cropFactor = 1.0
    local spec_combine = vehicle.spec_combine
    if spec_combine and spec_combine.lastValidInputFruitType then
        cropFactor = self.CROP_FACTORS[spec_combine.lastValidInputFruitType] or 1.0
    end
    
    -- PICKUP HEADER DETECTION: Check output fill type for grass
    -- Pickup headers have lastCuttersOutputFillType = GRASS but InputFruitType = 0
    -- Direct cutting has both Input and Output as GRASS
    if spec_combine and spec_combine.lastCuttersOutputFillType then
        local outputFill = spec_combine.lastCuttersOutputFillType
        if outputFill == FillType.GRASS or 
           outputFill == FillType.GRASS_WINDROW or
           outputFill == FillType.DRYGRASS_WINDROW then
            -- Only apply lighter cropFactor for pickup headers (Input=0)
            -- Direct cutting uses cropFactor from XML
            if spec_combine.lastValidInputFruitType == 0 then
                cropFactor = 0.35  -- Pickup = lighter crop, faster speed
            end
        end
    end
    
    -- Розраховуємо RAW середню масу за секунду (кг/с)
    -- currentTime в мс, тому 1000/currentTime для секунд
    -- Використовуємо accumulatedMass
    local rawAvgMass = (self.loadAccumulatedMass or 0) * (1000 / self.currentTime) * cropFactor
    
    -- ADAPTIVE SMOOTHING: більше згладжування при високому навантаженні
    local loadRatio = self.currentAvgMass / math.max(0.01, self.basePerfMass)
    local smoothFactor = 0.3 + 0.4 * math.min(1.0, loadRatio)
    smoothFactor = math.min(0.7, smoothFactor)  -- Max 70% smoothing
    
    -- Застосовуємо згладжування тільки якщо є попереднє значення
    local avgMass = rawAvgMass
    if self.currentAvgMass > (0.5 * self.basePerfMass) then
        avgMass = (1 - smoothFactor) * rawAvgMass + smoothFactor * self.currentAvgMass
    end
    
    -- Зберігаємо обидва значення для різних цілей
    self.lastAvgMass = self.currentAvgMass
    self.currentAvgMass = avgMass
    self.rawAvgMass = rawAvgMass  -- Для аварійного гальмування
    
    -- Отримуємо power boost для розрахунку навантаження
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    
    -- Максимальна допустима маса з урахуванням power boost
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass
    
    -- Розраховуємо навантаження відносно maxAvgMass
    if maxAvgMass > 0 then
        self.engineLoad = self.currentAvgMass / maxAvgMass
    else
        self.engineLoad = 0
    end
    
    if self.debug then
        print(string.format("RHM DEBUG: Load: %.1f%% (Raw: %.2f kg/s, Smooth: %.2f kg/s) | Base: %.2f kg/s | Max: %.2f kg/s", 
            self.engineLoad * 100, rawAvgMass, self.currentAvgMass, self.basePerfMass, maxAvgMass))
    end
end

---Розраховує обмеження швидкості
---@param vehicle table Комбайн
function LoadCalculator:calculateSpeedLimit(vehicle)
    -- Якщо не збираємо врожай (mass = 0), плавно відпускаємо ліміт
    if self.currentAvgMass == 0 then
        -- Зберігаємо workingSpeedLimit ТІЛЬКИ якщо він дійсно відображає
        -- навантажувальне обмеження (< 75% genuineSpeedLimit).
        -- Не зберігаємо якщо ми розігнались по краю — це не "робоча" швидкість.
        local saveThreshold = self.genuineSpeedLimit * 0.75
        if self.speedLimit < saveThreshold and self.speedLimit > 2 then
            self.workingSpeedLimit = self.speedLimit
        end
        -- Плавно відпускаємо ліміт (без стрибка до 15)
        if self.speedLimit < self.genuineSpeedLimit then
            self.speedLimit = math.min(self.genuineSpeedLimit, self.speedLimit + 0.6)
        end
        return
    end
    
    -- Детекція зміни культури або тривалої паузи
    local currentCropType = nil
    local spec_combine = vehicle.spec_combine
    if spec_combine and spec_combine.lastValidInputFruitType then
        currentCropType = spec_combine.lastValidInputFruitType
    end
    
    local currentTime = g_currentMission.time or 0
    local timeSinceLastHarvest = currentTime - self.lastHarvestTime
    
    -- Скидаємо при зміні культури або тривалій паузі (>30 сек)
    local longPause = timeSinceLastHarvest > 30000
    local cropChanged = (currentCropType and self.lastCropType and currentCropType ~= self.lastCropType)
    if cropChanged or longPause then
        self.workingSpeedLimit = 0
        self._firstHarvestDone = false  -- Reset conservative start для нового поля
    end
    
    self.lastCropType = currentCropType
    self.lastHarvestTime = currentTime
    
    -- CONSERVATIVE START: тільки при справжньому першому заїзді в культуру
    -- Використовуємо _firstHarvestDone (скидається тільки після 30с паузи, НЕ на кожному кінці рядка)
    if not self._firstHarvestDone then
        self._firstHarvestDone = true
        -- Якщо speedLimit ніколи не знижувався (genuineSpeedLimit) — застосовуємо старт
        if self.speedLimit >= self.genuineSpeedLimit then
            if self.workingSpeedLimit > 0 and self.workingSpeedLimit < 12 then
                self.speedLimit = self.workingSpeedLimit
            else
                self.speedLimit = 7.0
                self.workingSpeedLimit = 7.0
            end
        end
        -- Якщо speedLimit вже нижче genuineSpeedLimit — не чіпаємо
        -- (наприклад, плавний розгін на частковій секції ще не досяг 15)
    end
    
    -- Отримуємо поточну швидкість
    local avgSpeed = 1000 * self.totalDistance / self.currentTime  -- м/с
    
    -- Отримуємо power boost
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass
    
    -- Розраховуємо прискорення (derivative of smoothed value)
    local massAcc = 0
    if self.currentTime > 0 and self.lastAvgMass > 0 then
        massAcc = (self.currentAvgMass - self.lastAvgMass) / self.currentTime
    end
    
    -- === THREE-ZONE CONTROL SYSTEM ===
    local loadRatio = self.currentAvgMass / maxAvgMass
    local rawLoadRatio = (self.rawAvgMass or self.currentAvgMass) / maxAvgMass
    local newSpeedLimit = self.speedLimit
    local controlZone = "HOLD"
    
    -- === GRADUATED EMERGENCY BRAKE SYSTEM ===
    -- Чим вище навантаження, тим агресивніше гальмування
    local emergencyBrake = false
    local brakeRate = 0
    
    -- SPECIAL: Перший раз перевищили 100% - різко скидаємо швидкість
    -- Це запобігає "overshoot" (розгін → перевантаження → гальмування → цикл)
    if rawLoadRatio > 1.0 and rawLoadRatio <= 1.05 then
        -- Тільки що перевищили 100% - агресивний скид
        controlZone = "THRESHOLD_BRAKE"
        brakeRate = 2.5  -- -2.5 км/год (агресивно, щоб load впав)
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
        
    elseif rawLoadRatio > 1.5 then
        -- EXTREME: >150% load - максимальне гальмування
        controlZone = "EMERGENCY_EXTREME"
        brakeRate = 5.0  -- -5 км/год за раз
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
        
    elseif rawLoadRatio > 1.2 then
        -- CRITICAL: 120-150% load - сильне гальмування
        controlZone = "EMERGENCY_CRITICAL"
        brakeRate = 3.0  -- -3 км/год за раз
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
        
    elseif rawLoadRatio > 1.1 then
        -- HIGH: 110-120% load - помірне гальмування
        controlZone = "EMERGENCY_HIGH"
        brakeRate = 1.5  -- -1.5 км/год за раз
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
        
    elseif rawLoadRatio > 1.05 or loadRatio > 1.08 then
        -- MODERATE: 105-110% load - легке гальмування
        controlZone = "EMERGENCY_MODERATE"
        brakeRate = 1.0  -- -1 км/год за раз
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
    
    -- ZONE 1: DANGER (>108% smoothed OR >115% raw) - Standard brake
    elseif loadRatio > 1.08 or rawLoadRatio > 1.15 then
        controlZone = "DANGER"
        if rawLoadRatio > 1.15 then
            -- HARD brake (using raw value for immediate response)
            newSpeedLimit = math.max(2, math.min(self.speedLimit, avgSpeed * 3.6) - 15 * (rawLoadRatio - 1.0)^2)
        else
            -- Soft brake (using smoothed value)
            newSpeedLimit = math.max(2, math.min(self.speedLimit, avgSpeed * 3.6) - 8 * (loadRatio - 1.0)^2)
        end
    
    -- ZONE 2: CAUTION (85-108%) - Hold steady or gentle adjustment
    elseif loadRatio >= 0.85 and loadRatio <= 1.08 then
        controlZone = "CAUTION"
        -- В зоні обережності активно утримуємо швидкість
        if loadRatio > 1.00 then
            -- >100%: Легке гальмування (щоб не доводити до emergency)
            newSpeedLimit = math.max(2, self.speedLimit - 0.4)
        elseif loadRatio > 0.90 and self.speedLimit > avgSpeed * 3.6 then
            -- 90-100%: Якщо швидкість зростає (ззовні), обмежуємо
            newSpeedLimit = math.max(2, avgSpeed * 3.6 - 0.2)
        end
        -- else: <90% в CAUTION - тримаємо стабільно
    
    -- ZONE 3: SAFE (<85%) - Accelerate with prediction
    else
        controlZone = "SAFE"
        
        -- Check prediction before accelerating
        local predictLimitSet = false
        if massAcc > 0 then
            -- Adaptive prediction horizon (shorter at high load)
            local predictHorizon = 2500 + 500 * (1 - loadRatio)
            local predictAvgMass = self.currentAvgMass + massAcc * predictHorizon
            
            -- RAW PREDICTION CHECK
            local predictThreshold = 1.5
            
            if predictAvgMass > predictThreshold * maxAvgMass then
                -- Predictive brake
                newSpeedLimit = math.max(2, math.min(0.96 * self.speedLimit, avgSpeed * 3.6))
                predictLimitSet = true
                controlZone = "SAFE_PREDICT"
            end
        end
        
        -- If no prediction triggered, check for acceleration
        if not predictLimitSet then
            -- === SOFT CEILING: не перевищуємо "вивчений" робочий ліміт + буфер ===
            -- При частковій ширині жатки (мала маса) формула (maxMass/mass)^2.5 може дати
            -- величезне прискорення і розігнати до genuineSpeedLimit.
            -- Потім при повній жатці THRESHOLD_BRAKE різко скидає швидкість → неприємно.
            -- Рішення: дозволяємо розгін тільки до workingSpeedLimit + 2 км/год
            local softCeiling = self.genuineSpeedLimit  -- за замовч. — повна свобода
            if self.workingSpeedLimit > 0 then
                softCeiling = math.min(self.genuineSpeedLimit, self.workingSpeedLimit + 2.0)
            end
            
            if loadRatio > 0.70 and loadRatio < 0.80 then
                -- 70-80%: Обережний розгін (не хочемо перевищити 85%)
                local capacityRatio = (maxAvgMass - self.currentAvgMass) / maxAvgMass
                if capacityRatio > 0.25 then
                    local accelFactor = 0.05
                    -- Обмежуємо множник: при дуже малому navantazhenni формула вибухає
                    local massRatio = math.min(3.0, maxAvgMass / self.currentAvgMass)
                    newSpeedLimit = math.min(softCeiling,
                        self.speedLimit + accelFactor * massRatio^2)
                end
                
            elseif loadRatio <= 0.70 then
                -- <70%: Нормальний розгін (далеко від стелі)
                local capacityRatio = (maxAvgMass - self.currentAvgMass) / maxAvgMass
                local accelFactor = 0.08 + 0.05 * capacityRatio  -- 0.08-0.13 range
                -- Обмежуємо множник щоб уникнути вибухового зростання при дуже низькому load
                local massRatio = math.min(3.0, maxAvgMass / self.currentAvgMass)
                newSpeedLimit = math.min(softCeiling,
                    self.speedLimit + accelFactor * massRatio^2.5)
            end
            -- else: 80%+ в SAFE зоні - тримаємо (не розганяємо, не гальмуємо)
        end
    end
    
    -- === RATE LIMITING === (prevent jerky changes)
    -- Використовуємо різні ліміти залежно від зони
    local maxChange = 0.8  -- Default: 0.8 km/h change per update
    
    if emergencyBrake then
        -- В аварійних ситуаціях дозволяємо швидкі зміни
        maxChange = brakeRate  -- Використовуємо розрахований brakeRate
    elseif controlZone == "DANGER" then
        maxChange = 1.5  -- Швидші зміни в небезпечній зоні
    end
    
    newSpeedLimit = math.clamp(newSpeedLimit, 
        self.speedLimit - maxChange, 
        self.speedLimit + maxChange)
    
    self.speedLimit = newSpeedLimit
    
    if self.debug then
        print(string.format("RHM: [%s] Load: %.1f%% (Raw: %.1f%%) | Speed: %.1f→%.1f | Acc: %.4f", 
            controlZone, loadRatio * 100, rawLoadRatio * 100, 
            avgSpeed * 3.6, self.speedLimit, massAcc))
    end
end

---Отримує поточне навантаження на двигун
---@return number Навантаження в відсотках (0-100+)
function LoadCalculator:getEngineLoad()
    return self.engineLoad * 100
end

---Отримує поточний ліміт швидкості
---@return number Ліміт швидкості в км/год
function LoadCalculator:getSpeedLimit()
    return self.speedLimit or 0
end



---Встановлює оригінальне обмеження швидкості комбайна
---@param limit number Оригінальний ліміт в км/год
function LoadCalculator:setGenuineSpeedLimit(limit)
    self.genuineSpeedLimit = limit
    self.speedLimit = limit
end

---Скидає всі дані
function LoadCalculator:reset()
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.currentAvgMass = 0
    self.engineLoad = 0
    self.cropLoss = 0
    -- Скидаємо speedLimit до genuineSpeedLimit (коли не косимо)
    self.speedLimit = self.genuineSpeedLimit
    
    -- Скидаємо накопичення продуктивності
    self.productivityMass = 0
    self.productivityLiters = 0
    self.productivityTime = 0
    self.tonPerHour = 0
    self.litersPerHour = 0
    
    -- Скидаємо буфери врожайності та шуму
    self.yieldBuffer = {}
    self.currentYield = 0
    self.instantYield = 0
    
    if self.debug then
        print("RHM: LoadCalculator reset")
    end
end

---Розраховує втрати врожаю при перевантаженні
---@return number Втрати в відсотках (0-50)
function LoadCalculator:calculateCropLoss()
    -- Перевіряємо чи увімкнені втрати
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return 0
    end
    
    if not g_realisticHarvestManager.settings.enableCropLoss then
        return 0
    end
    
    -- НОВИЙ ПОРІГ: Втрати починаються з 95% навантаження
    if self.engineLoad > 0.95 then
        -- Розраховуємо overload відносно 95%
        local overload = self.engineLoad - 0.95  -- 0.0 при 95%, 0.05 при 100%, 0.25 при 120% і т.д.
        
        -- Отримуємо множник втрат залежно від складності
        local lossMultiplier = g_realisticHarvestManager.settings:getLossMultiplier()
        
        -- Прогресивна формула втрат:
        -- 95-100% load: Мінімальні втрати (0-2%)
        -- 100-120% load: Помірні втрати (2-15%)
        -- 120%+ load: Серйозні втрати (15-50%)
        -- 
        -- Формула: ((overload / 0.05)^1.5) * lossMultiplier * базовий_відсоток
        -- де 0.05 = діапазон від 95% до 100%
        local normalizedOverload = overload / 0.05  -- 0.0 при 95%, 1.0 при 100%, 5.0 при 120%
        local loss = (normalizedOverload^1.5) * lossMultiplier * 2.5  -- 2.5 = базовий % при 100% load
        
        self.cropLoss = math.min(loss, 50) -- Максимум 50% втрат
    else
        self.cropLoss = 0
    end
    
    return self.cropLoss
end

---Розраховує втрати від неправильних налаштувань комбайна
---@return number settingsLoss Втрати від налаштувань (0-50%)
function LoadCalculator:calculateSettingsLoss()
    -- Якщо немає memory або культури - втрат немає
    if not self.combineMemory or not self.currentCrop then
        return 0
    end
    
    -- Однакова математика для AUTO і MANUAL:
    -- AUTO отримує невеликий відхил від оптимуму (1-10 одиниць) при налаштуванні,
    -- тому матиме малі, але реальні втрати — "автомат не ідеальний"
    -- MANUAL дає гравцю можливість зробити і краще (якщо точно потрапить в оптимум)
    -- і гірше (якщо виставить неправильні значення)
    
    -- Отримуємо результат перевірки налаштувань (включаючи бонус)
    local netPenalty, _ = self.combineMemory:checkSettingsForCrop(self.currentCrop)
    
    -- netPenalty може бути від'ємним (бонус) або додатнім (штраф)
    -- Обмежуємо діапазон: Максимальний бонус -5%, Максимальний штраф 30%
    local settingsFactor = math.max(-5, math.min(netPenalty, 30))
    
    return settingsFactor
end

---Розраховує загальні втрати врожаю (базові + налаштування)
---@return number totalLoss Загальні втрати (0-50%)
function LoadCalculator:calculateTotalCropLoss()
    -- Базові втрати від перевантаження
    local baseLoss = self:calculateCropLoss()
    
    -- Втрати від налаштувань
    local settingsLoss = self:calculateSettingsLoss()
    
    -- TODO: В майбутньому додати:
    -- local moistureLoss = self:calculateMoistureLoss()
    -- local speedLoss = self:calculateSpeedLoss()
    
    -- Загальні втрати (сумуються)
    local totalLoss = baseLoss + settingsLoss
    
    -- Обмежуємо максимум
    totalLoss = math.min(totalLoss, 50)
    
    -- Зберігаємо для відображення в HUD
    self.cropLoss = totalLoss
    
    return totalLoss
end

---Отримує поточні втрати врожаю
---@return number Втрати в відсотках (0-50)
function LoadCalculator:getCropLoss()
    return self.cropLoss
end

---Отримує продуктивність в тоннах на годину
---@return number Продуктивність в T/h
function LoadCalculator:getTonPerHour()
    return self.tonPerHour
end

---Отримує продуктивність в літрах на годину (де факто volume flow)
---@return number Продуктивність в L/h
function LoadCalculator:getLitersPerHour()
    return self.litersPerHour or 0
end

---Оновлює продуктивність на основі зібраної маси та об'єму
---@param mass number Маса зібраного врожаю в кг
---@param liters number Обєм зібраного врожаю в л
---@param dt number Delta time в мс
function LoadCalculator:updateProductivity(mass, liters, dt)
    self.totalOutputMass = self.totalOutputMass + mass
    
    -- Накопичуємо масу, об'єм та час
    self.productivityMass = self.productivityMass + mass
    self.productivityLiters = (self.productivityLiters or 0) + liters
    self.productivityTime = self.productivityTime + dt
    
    -- Оновлюємо T/h та L/h кожні 3 секунди для стабільного значення
    -- АБО якщо це перший запуск (productivityTime малий але є маса)
    if self.productivityTime >= self.productivityUpdateInterval then
        if self.productivityTime > 0 then
            -- T/h = (Mass_kg / 1000) / (Time_ms / 3600000)
            local hours = self.productivityTime / 3600000
            self.tonPerHour = (self.productivityMass / 1000) / hours
            self.litersPerHour = (self.productivityLiters or 0) / hours
        end
        
        -- Reset counters with SMOOTHING (keep 20% to prevent drops)
        self.productivityMass = self.productivityMass * 0.2
        self.productivityLiters = (self.productivityLiters or 0) * 0.2
        self.productivityTime = self.productivityTime * 0.2
        
    elseif self.tonPerHour == 0 and self.productivityTime > 1000 and self.productivityMass > 0 then
        -- Швидкий старт
        local hours = self.productivityTime / 3600000
        self.tonPerHour = (self.productivityMass / 1000) / hours
        self.litersPerHour = (self.productivityLiters or 0) / hours
    end
end

---Оновлює продуктивність і ВРОЖАЙНІСТЬ
---@param mass number Маса (кг)
---@param liters number Об'єм (л)
---@param area number Площа (м2)
---@param dt number Час (мс)
function LoadCalculator:updateProductivityAndYield(mass, liters, area, dt)
    self:updateProductivity(mass, liters, dt) -- Call original logic
    
    if area <= 0.001 then
        self.instantYield = 0
        return
    end
    
    -- 1. Calculate raw yield (Metric: t/ha)
    -- (kg / m2) * 10 = t/ha
    local rawYield = (mass / area) * 10
    
    -- 2. Apply smoothing (Simple moving average)
    -- BUFFER: 20 ticks seems good (~10 frames if called every update, or less if updateProductivity is called less often)
    
    self.yieldBuffer = self.yieldBuffer or {}
    table.insert(self.yieldBuffer, rawYield)
    if #self.yieldBuffer > 30 then table.remove(self.yieldBuffer, 1) end
    
    local sum = 0
    for _, v in ipairs(self.yieldBuffer) do sum = sum + v end
    local smoothedYield = sum / #self.yieldBuffer
    
    -- 3. REMOVED Noise (+/- 5%) - User requested actual values
    -- Noise factor removed for stability
    
    -- Apply User Calibration
    local calibration = 1.0
    if self.combineMemory and self.combineMemory.currentYieldCalibration then
        calibration = self.combineMemory.currentYieldCalibration
    end
    
    self.currentYield = smoothedYield * calibration
end

---Встановити реальну врожайність з rhm_Combine (User Request)
---@param yieldTha number Врожайність в т/га
function LoadCalculator:setRealTimeYield(yieldTha)
    -- Apply smoothing (Simple moving average)
    self.yieldBuffer = self.yieldBuffer or {}
    table.insert(self.yieldBuffer, yieldTha)
    if #self.yieldBuffer > 20 then table.remove(self.yieldBuffer, 1) end
    
    local sum = 0
    for _, v in ipairs(self.yieldBuffer) do sum = sum + v end
    local smoothedYield = sum / #self.yieldBuffer

    -- No Calibration - Pure Real-time Yield (User Request)
    self.currentYield = smoothedYield
end

---Отримує форматований рядок врожайності
---@param unitSystem number (1=Metric, 2=Imperial, 3=Bushels)
---@return string, string (Value, Unit)
function LoadCalculator:getYieldText(unitSystem)
    -- BUGFIX: Removed duplicate T/h calculation that was causing jumps
    -- This method is now a PURE GETTER for Yield only
    
    local yield = self.currentYield or 0
    
    if yield < 0.1 then return "0.0", "t/ha" end
    
    if unitSystem == 2 then -- Imperial (UK/US tons per acre?) 
        -- 1 t/ha = 0.446 t/ac (approx short ton) or just use t/ac
        local t_ac = yield * 0.446
        return string.format("%.2f", t_ac), "t/ac"
        
    elseif unitSystem == 3 then -- Bushels (bu/ac)
        -- Standard conversion factor (avg for grains): ~15
        local bu_ac = yield * 15 
        return string.format("%.0f", bu_ac), "bu/ac"
        
    else -- Metric (t/ha)
        return string.format("%.1f", yield), "t/ha"
    end
end