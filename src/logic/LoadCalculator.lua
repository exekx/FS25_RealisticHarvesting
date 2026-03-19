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
    self.CROP_FACTORS = {} -- By FruitType ID
    self.CROP_FACTORS_FT = {} -- By FillType ID
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
    self.genuineSpeedLimit = -1  -- EN: Genuine limits from game db / UA: Ліміт з гри
    self.lastCropType = nil  -- EN: Last crop / UA: Остання культура
    self.lastHarvestTime = 0  -- EN: Last harvest time / UA: Час останнього збирання
    
    -- Crop loss and productivity
    self.cropLoss = 0  -- EN: Current crop loss (%) / UA: Поточні втрати врожаю (%)
    self.headerLoss = 0 -- EN: Header/speed-related crop loss (%) / UA: Втрати від швидкості на жатці (%)
    self.tonPerHour = 0  -- EN: Yield in T/h / UA: Продуктивність в Т/год
    self.litersPerHour = 0  -- EN: Yield in L/h / UA: Продуктивність в Л/год
    self.totalOutputMass = 0  -- EN: Total harvested mass / UA: Загальна маса зібраного врожаю

    -- EN: Rotor plugging state machine.
    --     A plug occurs when engine load stays at 130%+ for 10 consecutive seconds.
    --     Once plugged, the combine is disabled for 12 seconds (clear time).
    -- UA: Стан машини забивання ротора.
    self.plugTimer = 0      -- EN: ms spent continuously at >=130% load / UA: мс безперервно при навантаженні >=130%
    self.isPlugged = false  -- EN: True while combine is clearing a plug / UA: True поки комбайн очищує засмічення
    self.pluggedTimer = 0   -- EN: ms remaining until plug is cleared / UA: мс що залишились до очищення засмічення

    -- EN: Time-of-day moisture factor (cached every 60s to avoid per-tick env queries).
    -- UA: Коефіцієнт вологості часу доби (кешується кожні 60с для уникнення запитів оточення кожен тік).
    self.moistureFactor = 1.0
    self.moistureLabel = ""   -- EN: Short label for HUD display / UA: Коротка мітка для HUD
    self._moistureUpdateTimer = 0

    -- EN: Session statistics — reset by the player via the Harvest Report panel.
    -- UA: Статистика сесії — скидається гравцем через панель звіту про збирання.
    self.session = {
        startTime   = 0,
        area        = 0,   -- ha
        mass        = 0,   -- tonnes
        loadSum     = 0,
        loadCount   = 0,
        lossSum     = 0,
        lossCount   = 0,
        hdrLossSum  = 0,
        hdrLossCount= 0,
        peakLoad    = 0,
        plugCount   = 0,
        active      = false,
    }
    
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
        ["WHEAT"] = 0.814,
        ["BARLEY"] = 0.869,
        ["OAT"] = 1.164,        -- EN: +25% / UA: +25%
        ["MAIZE"] = 0.572,      -- EN: -50% / UA: -50%
        ["CORN"] = 0.572,
        ["MAIZE_FORAGE"] = 0.572,
        ["MAIZE_SILAGE"] = 0.572,
        ["SOYBEAN"] = 1.788,    -- EN: -20% / UA: -20%
        ["SUNFLOWER"] = 2.324,
        ["CANOLA"] = 1.738,
        ["SORGHUM"] = 0.801,    -- EN: -20% / UA: -20%
        
        -- EN: Rice is a heavy crop / UA: Рис важка культура
        ["RICE"] = 1.303,
        ["RICE_LONG_GRAIN"] = 1.303,
        
        -- EN: Legumes / UA: Бобові
        ["PEA"] = 1.152,        -- EN: -20% / UA: -20%
        ["LENTIL"] = 1.152,
        ["CHICKPEA"] = 1.152,
        ["GREENBEAN"] = 2.240,  -- EN: -20% / UA: -20%
        
        -- EN: Root crops / UA: Коренеплоди
        ["POTATO"] = 0.600,     -- EN: Lighter / UA: Полегшено
        ["SUGARBEET"] = 0.920,  -- EN: +15% / UA: +15%
        ["BEETROOT"] = 1.050,   -- EN: +15% / UA: +15%
        ["CARROT"] = 0.323,     -- EN: -15% / UA: -15%
        ["PARSNIP"] = 0.400,    -- EN: Lighter / UA: Полегшено
        ["ONION"] = 0.600,      
        ["SPINACH"] = 2.880,    
        
        -- EN: Grass & Silage / UA: Трава та силос
        ["GRASS"] = 1.221,      -- EN: 1.5x Wheat / UA: 1.5x Пшениці
        ["DRYGRASS"] = 1.100,
        ["ALFALFA"] = 1.100,
        ["CLOVER"] = 1.100,
        ["MEADOW"] = 1.221,
        ["ONION_DIRTY"] = 0.700, -- EN: Dirty onions (Root crop) / UA: Брудна цибуля
        
        -- EN: Other / Mod crops / UA: Інші культури
        ["COTTON"] = 4.782,     -- EN: 2x heavier / UA: у 2 рази важча
        ["SUGARCANE"] = 0.654,
        ["POPLAR"] = 0.156,
        ["OILSEED_RADISH"] = 0.391,
        ["GRAPE"] = 0.391,
        ["OLIVE"] = 0.391,
        ["RYE"] = 0.814,
        ["SPELT"] = 0.814,
        ["TRITICALE"] = 0.461,
        ["MILLET"] = 0.976,
        ["MINT"] = 1.054,
    }

    -- EN: Dynamically mapping FruitType Enum
    for key, value in pairs(FruitType) do
        local mappedFactor = factorMap[key]
        if not mappedFactor then
            if key:find("_WINDROW") then
                mappedFactor = factorMap[key:gsub("_WINDROW", "")]
            elseif key:find("CUT_") then
                mappedFactor = factorMap[key:gsub("CUT_", "")]
            end
        end
        if mappedFactor then
            self.CROP_FACTORS[value] = mappedFactor
        elseif type(value) == "number" and not key:find("NUM_") then
            -- EN: Use Wheat as the base fallback for any unknown crops
            -- UA: Використовуємо Пшеницю як базовий фолбек для невідомих культур
            self.CROP_FACTORS[value] = factorMap["WHEAT"] or 0.8
        end
    end

    -- EN: Also map FillType Enum (Critical for Pickups and Mod Crops)
    -- UA: Також мапуємо FillType Enum (Критично для підбирачів та мод-культур)
    if g_fillTypeManager then
        for key, value in pairs(FillType) do
            local mappedFactor = factorMap[key]
            if not mappedFactor then
                if key:find("_WINDROW") then
                    mappedFactor = factorMap[key:gsub("_WINDROW", "")]
                elseif key:find("CUT_") then
                    mappedFactor = factorMap[key:gsub("CUT_", "")]
                elseif key == "ONION_DIRTY" then
                    mappedFactor = factorMap["ONION_DIRTY"] or factorMap["ONION"]
                elseif key == "MEADOW" then
                    mappedFactor = factorMap["GRASS"]
                end
            end
            if mappedFactor then
                self.CROP_FACTORS_FT[value] = mappedFactor
            end
        end
    end
end

---EN: Sets base performance mass / UA: Встановлює базову продуктивність (маса)
function LoadCalculator:setBasePerformance(basePerfMass)
    self.basePerfMass = basePerfMass
    
    if rhm_Combine and rhm_Combine.debug then
        print(string.format("RHM: Base performance set to %.2f kg/s (%.1f t/h)", 
            self.basePerfMass, self.basePerfMass * 3.6))
    end
end

---EN: Gets base performance from engine power / UA: Отримує базову продуктивність з потужності двигуна
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
        -- EN: Built-in throughput curve (exponent 0.75, reference 400hp) — used when no
        --     CropThroughputConfig override is present for this crop.
        --     Formula: basePerf = coef * (REF_HP^0.25) * (hp^0.75)
        -- UA: Вбудована крива пропускної здатності (показник 0.75, еталон 400 к.с.) —
        --     застосовується, коли немає перевизначення CropThroughputConfig для культури.
        local REF_HP = 400.0
        local hp = tonumber(power)
        local basePerf = coef * (REF_HP ^ 0.25) * (hp ^ 0.75)

        -- EN: CropThroughputConfig provides a per-crop power-law curve derived from two real-world
        --     anchor points (280 hp = AEM Class 6 min, 750 hp = AEM Class 10 max).
        --     When present, use  basePerf = A * hp^B  directly, which correctly places every
        --     machine HP between those anchors on the right calibrated curve.
        -- UA: CropThroughputConfig надає криву для кожної культури, виведену з двох реальних
        --     опорних точок (280 к.с. = мінімум Class 6, 750 к.с. = максимум Class 10).
        if CropThroughputConfig and CropThroughputConfig.getCurveParams then
            local cropName = self.combineMemory and self.combineMemory.currentCrop
            local params = CropThroughputConfig.getCurveParams(cropName)
            if params then
                basePerf = params.coef * (hp ^ params.exp)
            end
        end

        if rhm_Combine and rhm_Combine.debug then
            print(string.format("RHM DEBUG: BasePerf Mass computed for %s (cat: %s, coef: %.3f): %d hp -> %.2f kg/s (%.1f t/h)",
                vehicle:getFullName(), category or "unknown", coef, hp, basePerf, basePerf * 3.6))
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

-- ============================================================================
-- EN: Time-of-day moisture factor.
--     Morning dew and evening humidity increase effective crop resistance,
--     raising engine load and naturally slowing the machine down.
--     Dry afternoon window (10am-5pm) = 1.0 baseline.
--     Moisture label is set for HUD display when conditions are non-optimal.
-- UA: Коефіцієнт вологості часу доби.
-- ============================================================================
function LoadCalculator:updateMoistureFactor(dt)
    self._moistureUpdateTimer = (self._moistureUpdateTimer or 0) + dt
    if self._moistureUpdateTimer < 60000 then return end  -- EN: Update every 60s / UA: Оновлення кожні 60с
    self._moistureUpdateTimer = 0

    if not g_currentMission or not g_currentMission.environment then
        self.moistureFactor = 1.0
        self.moistureLabel = ""
        return
    end

    -- EN: dayTime is milliseconds since midnight. 24h = 86,400,000 ms.
    -- UA: dayTime — мілісекунди від опівночі. 24 год = 86 400 000 мс.
    local dayTime = g_currentMission.environment.currentDayTime or 0
    local hour = dayTime / 3600000  -- EN: Convert to fractional hours / UA: Перетворюємо в дробові години

    -- EN: Moisture windows (hour ranges):
    --   22:00-06:00 = Night dew      → +12% crop resistance
    --   06:00-09:00 = Morning dew    → +15% crop resistance (peak wet window)
    --   09:00-10:30 = Drying out     → +5%
    --   10:30-17:00 = Optimal window → 0% (factor 1.0)
    --   17:00-19:00 = Evening rise   → +5%
    --   19:00-22:00 = Evening dew    → +10%
    -- UA: Вікна вологості (діапазони годин):
    local factor, label
    if hour >= 6.0 and hour < 9.0 then
        factor = 1.15
        label  = "Morning Dew +15%"
    elseif hour >= 9.0 and hour < 10.5 then
        factor = 1.05
        label  = "Drying +5%"
    elseif hour >= 10.5 and hour < 17.0 then
        factor = 1.0
        label  = ""
    elseif hour >= 17.0 and hour < 19.0 then
        factor = 1.05
        label  = "Humidity +5%"
    elseif hour >= 19.0 and hour < 22.0 then
        factor = 1.10
        label  = "Eve. Dew +10%"
    else
        -- EN: Night (22:00-06:00) / UA: Ніч (22:00-06:00)
        factor = 1.12
        label  = "Night Dew +12%"
    end

    self.moistureFactor = factor
    self.moistureLabel  = label
end

-- ============================================================================
-- EN: Header loss — crop loss due to travel speed at the cutter bar.
--     Grain knocked off heads or shattered pods at high speed.
--     Conservative values: <1% up to 6 mph (9.7 km/h), escalating above 8 mph.
--     Crop-specific multipliers: canola/soybean are most vulnerable to shattering.
-- UA: Втрати на жатці — втрати врожаю через швидкість руху у зоні жатки.
-- ============================================================================
LoadCalculator.HEADER_LOSS_CROP_FACTORS = {
    canola    = 2.0,   -- EN: Pod shatter very sensitive / UA: Дуже чутливий до розтріскування стручків
    soybean   = 1.8,   -- EN: Pod shatter risk / UA: Ризик розтріскування стручків
    sunflower = 1.5,   -- EN: Head shatter / UA: Розтріскування кошика
    oat       = 1.2,   -- EN: Loose hull / UA: Слабкий лушпій
    rice      = 1.1,   -- EN: Shattering at tip / UA: Розтріскування на кінчику
    wheat     = 1.0,
    barley    = 1.0,
    sorghum   = 0.8,
    corn      = 0.25,  -- EN: Kernels well-protected in husk / UA: Зерна добре захищені в лушпинні
    legume    = 1.6,   -- EN: Bean/pea pod shatter / UA: Розтріскування стручків бобів/гороху
}

function LoadCalculator:calculateHeaderLoss(vehicle)
    if not vehicle then return 0 end

    -- EN: Header loss only applies when actively cutting (not forage — handled separately).
    -- UA: Втрати на жатці застосовуються лише при активному косінні (не форажні).
    if self.combineMemory and self.combineMemory.machineType == "forage" then
        self.headerLoss = 0
        return 0
    end

    local speed = vehicle:getLastSpeed()  -- EN: km/h / UA: км/год

    -- EN: 9.65 km/h = 6 mph (threshold where header loss begins).
    --     12.87 km/h = 8 mph (threshold where loss escalates sharply).
    -- UA: 9.65 км/год = 6 миль/год; 12.87 км/год = 8 миль/год.
    local THRESH_6MPH = 9.65
    if speed <= THRESH_6MPH then
        self.headerLoss = 0
        return 0
    end

    -- EN: Crop-specific shattering factor (defaults to wheat baseline = 1.0).
    -- UA: Коефіцієнт чутливості культури до обсипання (за замовчуванням пшениця = 1.0).
    local cropFactor = 1.0
    if self.combineMemory and self.combineMemory.currentCrop then
        local key = string.lower(self.combineMemory.currentCrop)
        -- EN: Strip suffixes like "_windrow", "_forage" etc. for lookup.
        -- UA: Обрізаємо суфікси типу "_windrow", "_forage" тощо для пошуку.
        for k, v in pairs(LoadCalculator.HEADER_LOSS_CROP_FACTORS) do
            if key == k or key:find(k, 1, true) then
                cropFactor = v
                break
            end
        end
    end

    -- EN: Gentle power-law curve. At 8 mph (12.87 km/h) wheat gets ~1.5%.
    --     Beyond 8 mph it escalates: at 10 mph (~16 km/h) wheat gets ~3.5%.
    --     All values capped at 8% to stay conservative.
    -- UA: М'яка крива степеневого закону. При 8 миль/год (12.87 км/год) пшениця дає ~1.5%.
    local excessSpeed = speed - THRESH_6MPH  -- EN: km/h above 6mph threshold
    local rawLoss = (excessSpeed ^ 1.35) * 0.28 * cropFactor
    self.headerLoss = math.min(8.0, rawLoss)
    return self.headerLoss
end

-- ============================================================================
-- EN: Plug state machine update. Called every tick from rhm_Combine:onUpdateTick.
--     Returns true if the plug state CHANGED this tick (for event/notification use).
-- UA: Оновлення стану засмічення ротора. Повертає true якщо стан змінився.
-- ============================================================================
function LoadCalculator:updatePlugState(dt)
    local changed = false
    if self.isPlugged then
        -- EN: Counting down clear timer.
        -- UA: Відлік таймера очищення.
        self.pluggedTimer = self.pluggedTimer - dt
        if self.pluggedTimer <= 0 then
            self.isPlugged    = false
            self.pluggedTimer = 0
            self.plugTimer    = 0
            changed = true
        end
    else
        -- EN: Check if engine load has been at 130%+ long enough to cause a plug.
        --     130% = engineLoad >= 1.30
        -- UA: Перевіряємо чи навантаження 130%+ тривало достатньо довго для засмічення.
        if self.engineLoad >= 1.30 then
            self.plugTimer = (self.plugTimer or 0) + dt
            if self.plugTimer >= 10000 then  -- EN: 10 seconds / UA: 10 секунд
                self.isPlugged    = true
                self.pluggedTimer = 12000   -- EN: 12 second clear time / UA: 12 секунд на очищення
                self.plugTimer    = 0
                self.session.plugCount = (self.session.plugCount or 0) + 1
                changed = true
            end
        else
            -- EN: Load dropped below threshold — reset the timer.
            -- UA: Навантаження впало нижче порогу — скидаємо таймер.
            self.plugTimer = 0
        end
    end
    return changed
end

-- ============================================================================
-- EN: Session tracking helpers.
-- UA: Допоміжні функції для відстеження статистики сесії.
-- ============================================================================
function LoadCalculator:startSession()
    self.session = {
        startTime    = g_currentMission and g_currentMission.time or 0,
        area         = 0,
        mass         = 0,
        loadSum      = 0,
        loadCount    = 0,
        lossSum      = 0,
        lossCount    = 0,
        hdrLossSum   = 0,
        hdrLossCount = 0,
        peakLoad     = 0,
        plugCount    = 0,
        active       = true,
    }
end

function LoadCalculator:resetSession()
    self:startSession()
end

function LoadCalculator:updateSession(massKg, areaM2, cropLoss, headerLoss)
    if not self.session or not self.session.active then return end
    local load = self.engineLoad * 100

    self.session.mass  = (self.session.mass  or 0) + massKg / 1000
    self.session.area  = (self.session.area  or 0) + areaM2 / 10000

    if load > 0 then
        self.session.loadSum   = (self.session.loadSum   or 0) + load
        self.session.loadCount = (self.session.loadCount or 0) + 1
        if load > (self.session.peakLoad or 0) then
            self.session.peakLoad = load
        end
    end
    if cropLoss > 0 then
        self.session.lossSum   = (self.session.lossSum   or 0) + cropLoss
        self.session.lossCount = (self.session.lossCount or 0) + 1
    end
    if headerLoss > 0 then
        self.session.hdrLossSum   = (self.session.hdrLossSum   or 0) + headerLoss
        self.session.hdrLossCount = (self.session.hdrLossCount or 0) + 1
    end
end

-- EN: Returns a formatted summary table for the Harvest Report panel.
-- UA: Повертає форматовану таблицю підсумків для панелі звіту про збирання.
function LoadCalculator:getSessionSummary(unitSystem)
    local s = self.session or {}
    local avgLoad   = s.loadCount   > 0 and (s.loadSum   / s.loadCount)    or 0
    local avgLoss   = s.lossCount   > 0 and (s.lossSum   / s.lossCount)    or 0
    local avgHdrLoss= s.hdrLossCount> 0 and (s.hdrLossSum/ s.hdrLossCount) or 0

    -- EN: Elapsed time in seconds (game time, not real time).
    -- UA: Час сесії в секундах (ігровий час, не реальний).
    local elapsed = 0
    if s.startTime and g_currentMission then
        elapsed = math.max(0, (g_currentMission.time - s.startTime) / 1000)
    end
    local elapsedMin = math.floor(elapsed / 60)

    -- EN: Session efficiency grade (starts at 100, penalties applied).
    -- UA: Оцінка ефективності сесії (починаємо з 100, застосовуємо штрафи).
    local score = 100
    score = score - avgLoss    * 5.0   -- EN: -5 pts per 1% avg threshing loss
    score = score - avgHdrLoss * 3.0   -- EN: -3 pts per 1% avg header loss
    score = score - (s.plugCount or 0) * 10  -- EN: -10 pts per plug
    if avgLoad > 0 and avgLoad < 70 then
        score = score - math.max(0, (70 - avgLoad) / 5) * 3  -- EN: Under-utilization penalty
    end
    score = math.max(0, math.min(100, score))

    local grade
    if     score >= 90 then grade = "A"
    elseif score >= 80 then grade = "B"
    elseif score >= 70 then grade = "C"
    elseif score >= 60 then grade = "D"
    else                    grade = "F"
    end
    -- EN: Add +/- modifier within each letter band
    local mod = score % 10
    if mod >= 7 then grade = grade .. "+"
    elseif mod < 3 and grade ~= "F" then grade = grade .. "-"
    end

    -- EN: Convert area + mass to active unit system.
    local areaStr, massStr
    if unitSystem == 2 or unitSystem == 3 then
        areaStr = string.format("%.1f ac", (s.area or 0) * 2.47105)
        massStr = string.format("%.1f t",  (s.mass or 0) * 1.10231)
    else
        areaStr = string.format("%.1f ha", s.area or 0)
        massStr = string.format("%.1f t",  s.mass or 0)
    end

    return {
        time        = string.format("%d min", elapsedMin),
        area        = areaStr,
        mass        = massStr,
        avgLoad     = string.format("%.0f%%", avgLoad),
        peakLoad    = string.format("%.0f%%", s.peakLoad or 0),
        avgLoss     = string.format("%.1f%%", avgLoss),
        avgHdrLoss  = string.format("%.1f%%", avgHdrLoss),
        plugs       = tostring(s.plugCount or 0),
        grade       = grade,
        score       = math.floor(score),
    }
end

---EN: Updates load calculation variables / UA: Оновлює дані для розрахунку навантаження
function LoadCalculator:update(vehicle, dt, mass)
    self.totalDistance = self.totalDistance + vehicle.lastMovedDistance
    self.loadAccumulatedMass = (self.loadAccumulatedMass or 0) + mass
    
    -- INSTANT REACTION FIX:
    -- EN: Only reset to 5 km/h if starting from idle (prevents reset loop during harvest)
    -- UA: Після простою скидаємо до 5 км/год (запобігає циклу скидання під час роботи)
    if mass > 0 and self.speedLimit >= (self.genuineSpeedLimit - 0.1) and self.genuineSpeedLimit > 0 
       and (self.lastAvgMass or 0) < 0.1 then
         self.speedLimit = 5.0
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
function LoadCalculator:calculateEngineLoad(vehicle)
    if self.currentTime <= 0 then
        return
    end
    
    -- EN: BASE CROP FACTOR / UA: БАЗОВИЙ КОЕФІЦІЄНТ КУЛЬТУРИ
    -- EN: Priority: 1. FruitType (Direct Cut), 2. FillType (Pickup/Windrow), 3. Wheat fallback
    local spec_combine = vehicle.spec_combine
    local rhmSpec = vehicle.spec_rhm_Combine
    
    local cropFactor = self.CROP_FACTORS[spec_combine.lastValidInputFruitType]
    
    -- Fallback to FillType (especially for Pickups/Root Crops)
    if not cropFactor and rhmSpec and rhmSpec.lastFillType then
        cropFactor = self.CROP_FACTORS_FT[rhmSpec.lastFillType]
    end
    
    -- Final fallback to Wheat
    if not cropFactor then
        cropFactor = self.CROP_FACTORS[FruitType.WHEAT] or 0.814
    end
    
    -- EN: INPUT DETECTION (PICKUP / CUTTER / FORAGE)
    local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(spec_combine.lastValidInputFruitType or 0)
    local currentFruitTypeName = "UNKNOWN"
    
    if fruitTypeDesc then
        currentFruitTypeName = string.upper(fruitTypeDesc.name)
    elseif rhmSpec and rhmSpec.lastFillType then
        -- Try to get name from fillType if fruitType is unknown
        local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(rhmSpec.lastFillType)
        if fillTypeDesc then
            currentFruitTypeName = string.upper(fillTypeDesc.name)
        end
    end
    local isPickup = false
    local isForageCutter = false
    
    -- EN: ROBUST DETECTION (Check attached implements) / UA: НАДІЙНА ДЕТЕКЦІЯ
    if vehicle.getAttachedImplements then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            local implObj = implement.object
            if implObj then
                local storeItem = g_storeManager:getItemByXMLFilename(implObj.configFileName)
                local cat = storeItem and storeItem.categoryName or ""
                
                -- EN: Detect Forage Harvester Header / UA: Силосна жатка
                if implObj.spec_forageHarvesterCutter ~= nil or implObj.spec_forageCutter ~= nil 
                   or cat == "forageHarvesterCutters" then
                    isForageCutter = true
                end

                -- EN: Detect WINDROW Pickup (not vegetable harvester!)
                -- UA: Визначаємо підбірач валків (не овочевий комбайн!)
                if implObj.spec_pickup ~= nil or cat == "pickups" or cat == "slasher" then
                    
                    -- EN: Check if this is a vegetable/root crop direct harvester
                    -- UA: Перевіряємо чи це прямий збирач овочів/коренеплодів
                    local isVegetableHarvester = false
                    
                    -- 1. Category check
                    if cat == "vegetableVehicles" or cat == "onionHarvesters" 
                       or cat == "rootCropHarvesters" then
                        isVegetableHarvester = true
                    end
                    
                    -- 2. FillType check
                    if not isVegetableHarvester and implObj.spec_fillUnit then
                        for _, fillUnit in ipairs(implObj.spec_fillUnit.fillUnits or {}) do
                            if fillUnit.supportedFillTypes then
                                for fillTypeIndex, _ in pairs(fillUnit.supportedFillTypes) do
                                    local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                                    if ft and ft.name then
                                        local ftName = string.upper(ft.name)
                                        if ftName == "ONION" or ftName == "ONION_DIRTY"
                                           or ftName == "CARROT" or ftName == "BEETROOT"
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
                    
                    -- 3. Filename fallback
                    if not isVegetableHarvester then
                        local xml = string.lower(implObj.configFileName or "")
                        if xml:find("onion") or xml:find("carrot") or xml:find("beetroot")
                           or xml:find("parsnip") or xml:find("ur_") or xml:find("umr_")
                           or xml:find("keiler") then
                            isVegetableHarvester = true
                        end
                    end
                    
                    if not isVegetableHarvester then
                        isPickup = true
                    end
                end
                
                if isPickup or isForageCutter then break end
            end
        end
    end

    -- EN: Fallback pickup detection: if input fruit type contains WINDROW or is UNKNOWN but area is processed
    if not isPickup then
        if currentFruitTypeName:find("WINDROW") or spec_combine.lastValidInputFruitType == 0 then
            isPickup = true
        end
    end

    -- EN: APPLY MULTIPLIERS / UA: ЗАСТОСУВАННЯ МНОЖНИКІВ
    self.isPickup = isPickup
    if isPickup then
        -- EN: Root crops & Vegetables should NOT be easier when picked up (already high volume)
        -- UA: Коренеплоди та овочі не повинні бути легшими при підбиранні
        local isRootOrVeg = currentFruitTypeName:find("ONION") 
                         or currentFruitTypeName:find("POTATO") 
                         or currentFruitTypeName:find("CARROT")
                         or currentFruitTypeName:find("PARSNIP")
                         or currentFruitTypeName:find("BEETROOT")
                         or currentFruitTypeName:find("SUGARBEET")
                         or currentFruitTypeName:find("SPINACH")
                         or currentFruitTypeName:find("GREENBEAN")
                         
        if not isRootOrVeg then
            cropFactor = cropFactor * 0.75  -- EN: Standard windrows (Wheat, Barley, etc.)
        end
    elseif isForageCutter then
        cropFactor = cropFactor * 0.80  -- EN: Forage harvesters (silage/direct cut) / UA: Кормозбиральні комбайни (силос/пряме косіння)
    end

    -- --- [RHM DEBUG: INFO LOG] ---
    if rhm_Combine and rhm_Combine.debug and self.lastCropType ~= spec_combine.lastValidInputFruitType then
        self.lastCropType = spec_combine.lastValidInputFruitType
        local mode = isPickup and "PICKUP" or (isForageCutter and "FORAGE_CUTTER" or "DIRECT_CUT")
        print(string.format("RHM DEBUG: [INPUT] %s (%s). Final Factor: %.3f", mode, currentFruitTypeName, cropFactor))
    end
    
    -- EN: Calculate RAW average mass intake per second / UA: Розраховуємо RAW середню масу за секунду (кг/с)
    -- EN: Uses accumulatedMass over the target distance/time / UA: Використовуємо accumulatedMass
    -- EN: Apply time-of-day moisture factor — wet crops require more power to thresh and separate.
    -- UA: Застосовуємо коефіцієнт вологості — вологі культури потребують більше потужності.
    local safeTime = math.max(100, self.currentTime) -- Protect against division by zero
    local rawAvgMass = (self.loadAccumulatedMass or 0) * (1000 / safeTime) * cropFactor * (self.moistureFactor or 1.0)
    
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
function LoadCalculator:calculateSpeedLimit(vehicle)
    if self.currentAvgMass == 0 then
        -- EN: If not harvesting, return to vanilla working speed / UA: Якщо не збираємо, повертаємось до ванільної робочої швидкості
        local target = self.genuineSpeedLimit > 0 and self.genuineSpeedLimit or 10.0
        if self.speedLimit > target then
            self.speedLimit = math.max(target, self.speedLimit - 0.5)
        elseif self.speedLimit < target then
            self.speedLimit = math.min(target, self.speedLimit + 0.5)
        end
        return
    end
    
    local powerBoost = 0
    local targetLoad = 0.95
    if self.combineMemory and self.combineMemory.currentSettings and self.combineMemory.currentSettings.targetEngineLoad then
        targetLoad = self.combineMemory.currentSettings.targetEngineLoad / 100.0
    end
    
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass * (self.settingsEfficiency or 1.0)
    if maxAvgMass <= 0.01 then return end
    
    local loadRatio = self.currentAvgMass / maxAvgMass

    -- EN: Calculate error between target and current load
    -- UA: Розраховуємо різницю між цільовим і реальним навантаженням
    local difference = targetLoad - loadRatio
    
    -- EN: Proportional adjustment: hard brake on overload, smooth acceleration on underload
    -- UA: Пропорційне регулювання: швидке гальмування при перевантаженні, плавний розгін
    local step = difference * 2.0
    if difference < 0 then
        step = difference * 5.0 -- EN: Panic brake / UA: Екстренне скидання швидкості при забиванні
    end
    
    -- EN: Limit speed jump to avoid jittering
    -- UA: Обмежуємо максимальний стрибок швидкості за один тік, щоб уникнути ривків
    step = math.max(-3.0, math.min(1.0, step))
    
    self.speedLimit = self.speedLimit + step

    -- EN: Clamp speed within safe bounds
    -- UA: Обмеження швидкості: не менше 2 км/год і не більше оригінального ліміту гри
    self.speedLimit = math.max(2.0, math.min(self.genuineSpeedLimit, self.speedLimit))
end

---EN: Returns current engine load factor / UA: Повертає поточне навантаження двигуна
function LoadCalculator:getEngineLoad()
    return self.engineLoad * 100
end

---EN: Returns calculated speed limit target / UA: Повертає остаточний ліміт швидкості
function LoadCalculator:getSpeedLimit()
    return self.speedLimit or 0
end

---EN: Caches base limit speed boundary / UA: Встановлює оригінальні межі ліміту
function LoadCalculator:setGenuineSpeedLimit(limit, maxCap)
    self.vanillaWorkingSpeed = limit
    self.genuineSpeedLimit = maxCap or limit
    self.speedLimit = limit
end

---EN: Fully resets accumulated internal data variables (does NOT reset session stats).
-- UA: Повністю очищує змінні бази даних (НЕ скидає статистику сесії).
function LoadCalculator:reset()
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.currentAvgMass = 0
    self.engineLoad = 0
    self.cropLoss = 0
    self.headerLoss = 0
    self.plugTimer = 0
    -- EN: Do NOT clear isPlugged or pluggedTimer here — they persist until the clear timer expires.
    self.speedLimit = self.vanillaWorkingSpeed or (self.genuineSpeedLimit > 0 and self.genuineSpeedLimit or 15)
    self.productivityMass = 0
    self.productivityLiters = 0
    self.productivityTime = 0
    self.tonPerHour = 0
    self.litersPerHour = 0
    
    self.prodBuffer = {}
    self.prodStartIndex = 1
    self.prodEndIndex = 0
    self.currentBufferTime = 0
    
    self.yieldBuffer = {}
    self.yieldStartIndex = 1
    self.yieldEndIndex = 0
    
    self.currentYield = 0
    self.instantYield = 0
end

---EN: Calculates settings-related quality losses / UA: Розраховує втрати врожаю
function LoadCalculator:calculateCropLoss()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then return 0 end
    if not g_realisticHarvestManager.settings.enableCropLoss then return 0 end

    -- EN: Forage harvesters (silage cutters) have no true loss mechanic — the only way
    --     crop is lost is if the spout discharge misses the trailer, which is an operator
    --     issue unrelated to machine settings. Exclude loss for forage machines entirely.
    -- UA: Кормозбиральні комбайни (силосоріза) не мають реального механізму втрат —
    --     втрати можливі тільки якщо розвантаження міне причіп (помилка оператора).
    if self.combineMemory and self.combineMemory.machineType == "forage" then
        self.cropLoss = 0
        return 0
    end
    
    local lossMultiplier = g_realisticHarvestManager.settings:getLossMultiplier()
    
    -- EN: Losses start smoothly from 80% engine load
    -- UA: Втрати починаються плавно з 80% завантаження
    if self.engineLoad > 0.80 then
        local overload = self.engineLoad - 0.80
        -- UA: Прогресивна крива (експонента): 
        -- При 80% (overload=0) -> 0% втрат
        -- При 90% (overload=0.1) -> 0.5% (мізерні втрати)
        -- При 100% (overload=0.2) -> 2.0% (допустимі втрати)
        -- При 110% (overload=0.3) -> 4.5% (пік продуктивності)
        -- При 130% (overload=0.5) -> 12.5% (величезні втрати)
        local rawLoss = (overload * overload) * 50
        
        -- UA: Різке зростання, якщо завантаження перевищило 110% (забита молотарка)
        if self.engineLoad > 1.10 then
            rawLoss = rawLoss + ((self.engineLoad - 1.10) * 100)
        end
        
        self.cropLoss = math.min(rawLoss * lossMultiplier, 50) 
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

function LoadCalculator:calculateTotalCropLoss()
    local baseLoss = self:calculateCropLoss()
    local settingsAddedLoss = self.settingsLoss or 0
    local totalLoss = baseLoss + settingsAddedLoss
    totalLoss = math.min(totalLoss, 50)
    self.cropLoss = totalLoss
    return totalLoss
end

---EN: Returns instantaneous processed metric tonnes per clock hour / UA: Перерахунок в тонни на годину
function LoadCalculator:getTonPerHour()
    return self.tonPerHour
end

---EN: Returns yield in L/h / UA: Розрахунок літрів на годину
function LoadCalculator:getLitersPerHour()
    return self.litersPerHour or 0
end

---EN: Updates sliding window rolling averages for metric evaluations / UA: Оновлює ковзні середні продуктивності
function LoadCalculator:updateProductivity(mass, liters, dt)
    self.totalOutputMass = self.totalOutputMass + mass
    
    self.prodBuffer = self.prodBuffer or {}
    self.prodStartIndex = self.prodStartIndex or 1
    self.prodEndIndex = self.prodEndIndex or 0
    
    self.prodEndIndex = self.prodEndIndex + 1
    self.prodBuffer[self.prodEndIndex] = {m = mass, l = liters or 0, t = dt}
    
    self.currentBufferTime = (self.currentBufferTime or 0) + dt
    while (self.prodEndIndex - self.prodStartIndex + 1) > 1 and self.currentBufferTime > 12000 do
        local old = self.prodBuffer[self.prodStartIndex]
        self.currentBufferTime = self.currentBufferTime - old.t
        self.prodBuffer[self.prodStartIndex] = nil -- free memory
        self.prodStartIndex = self.prodStartIndex + 1
    end
    
    local sumMass = 0
    local sumLiters = 0
    local sumTime = 0
    for i = self.prodStartIndex, self.prodEndIndex do
        local v = self.prodBuffer[i]
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
function LoadCalculator:updateProductivityAndYield(mass, liters, area, dt)
    self:updateProductivity(mass, liters, dt)
    if area <= 0.0001 and mass <= 0.001 then
        self.currentYield = self.currentYield or 0
        return
    end
    
    self.yieldBuffer = self.yieldBuffer or {}
    self.yieldStartIndex = self.yieldStartIndex or 1
    self.yieldEndIndex = self.yieldEndIndex or 0
    
    self.yieldEndIndex = self.yieldEndIndex + 1
    self.yieldBuffer[self.yieldEndIndex] = {m = mass, a = area}
    
    if (self.yieldEndIndex - self.yieldStartIndex + 1) > 600 then 
        self.yieldBuffer[self.yieldStartIndex] = nil
        self.yieldStartIndex = self.yieldStartIndex + 1
    end
    
    local sumMass = 0
    local sumArea = 0
    for i = self.yieldStartIndex, self.yieldEndIndex do 
        local v = self.yieldBuffer[i]
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
    self.yieldStartIndex = self.yieldStartIndex or 1
    self.yieldEndIndex = self.yieldEndIndex or 0
    
    self.yieldEndIndex = self.yieldEndIndex + 1
    self.yieldBuffer[self.yieldEndIndex] = yieldTha
    
    if (self.yieldEndIndex - self.yieldStartIndex + 1) > 20 then 
        self.yieldBuffer[self.yieldStartIndex] = nil
        self.yieldStartIndex = self.yieldStartIndex + 1
    end
    
    local sum = 0
    local count = self.yieldEndIndex - self.yieldStartIndex + 1
    for i = self.yieldStartIndex, self.yieldEndIndex do 
        sum = sum + self.yieldBuffer[i] 
    end
    self.currentYield = sum / count
end

---EN: Returns formatted yield string / UA: Отримує форматований рядок врожайності
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
