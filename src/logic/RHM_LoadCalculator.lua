-- EN: Physics-based engine load and speed limit calculator for combine harvesters.
--     Tracks cut area and harvested mass each tick to compute: engine load (%),
--     dynamic speed limit, productivity (t/h, L/h), yield (t/ha), and crop loss (%)
--     from combine settings deviation. Supports grain, forage, root, and cotton types.
-- UA: Фізичний калькулятор навантаження двигуна та ліміту швидкості для комбайнів.
--     Відстежує площу зрізу та масу врожаю кожен тік для розрахунку: навантаження (%),
--     динамічного ліміту швидкості, продуктивності (т/год, л/год), врожайності (т/га)
--     та втрат врожаю (%) від відхилення налаштувань. Підтримує зернові, форажні, коренеплоди, бавовну.
RHM_LoadCalculator = {}
local LoadCalculator_mt = Class(RHM_LoadCalculator)

function RHM_LoadCalculator.new(modDirectory)
    local self = setmetatable({}, LoadCalculator_mt)
    
    self.modDirectory = modDirectory or g_currentModDirectory
    
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
    self.speedLimit = 5.5  -- EN: Initial approach km/h limit / UA: Початковий ліміт швидкості входу
    self.genuineSpeedLimit = -1  -- EN: Genuine limits from game db / UA: Ліміт з гри
    self.lastCropType = nil  -- EN: Last crop / UA: Остання культура
    self.lastHarvestTime = 0  -- EN: Last harvest time / UA: Час останнього збирання
    
    -- Crop loss and productivity
    self.cropLoss = 0  -- EN: Current crop loss (%) / UA: Поточні втрати врожаю (%)
    self.cutterWearLoss = 0   -- EN: Loss from cutterbar knife wear (%) / UA: Втрати від зносу жатки (%)
    self.combineWearLoss = 0  -- EN: Loss from thresher wear (%) / UA: Втрати від зносу комбайна (%)
    self.totalWearLoss = 0    -- EN: Total mechanical wear loss (%) / UA: Сумарні втрати від зносу (%)
    self.lastCutterDamage = 0 -- EN: Cached cutter damage (0..1) / UA: Кешований знос жатки
    self.lastCombineDamage = 0 -- EN: Cached combine damage (0..1) / UA: Кешований знос комбайна
    self.tonPerHour = 0  -- EN: Yield in T/h / UA: Продуктивність в Т/год
    self.litersPerHour = 0  -- EN: Yield in L/h / UA: Продуктивність в Л/год
    self.hectaresPerHour = 0 -- EN: Area rate in ha/h / UA: Продуктивність в га/год
    self.totalOutputMass = 0  -- EN: Total harvested mass / UA: Загальна маса зібраного врожаю
    
    -- EN: Yield counters accumulation / UA: Накопичення продуктивності
    self.productivityMass = 0  -- EN: Accumulated mass (kg) / UA: Накопичена маса (кг)
    self.productivityLiters = 0  -- EN: Accumulated volume (L) / UA: Накопичений об'єм (л)
    self.productivityTime = 0  -- EN: Accumulation time (ms) / UA: Час накопичення (мс)
    self.productivityUpdateInterval = 3000  -- EN: Update interval (ms) / UA: Інтервал оновлення
    
    -- EN: Load accumulator / UA: Накопичувач навантаження
    self.loadAccumulatedMass = 0 -- kg
    self.harvestActiveTime = 0   -- EN: Duration of active harvesting (ms) / UA: Тривалість активного косіння (мс)
    self.underloadTimer = 0      -- EN: Sustained underload confirmation timer (ms) / UA: Таймер підтвердження низького навантаження
    self.idleHarvestTime = 0     -- EN: Time without crop flow (ms) / UA: Час без потоку культури
    self.lastUpdateInterval = 300
    
    -- Combine RHMSettings System
    self.combineMemory = nil  -- EN: Will be set by rhm_Combine / UA: Буде встановлено з rhm_Combine
    self.currentCrop = nil    -- EN: Current crop for loss calc / UA: Поточна культура для розрахунку втрат
    self.lastHarvestingSpeed = nil -- EN: Remembered stable harvesting speed / UA: Запам'ятована швидкість збирання
    self.cropHarvestingSpeeds = {} -- EN: Per-crop remembered harvesting speeds / UA: Запам'ятовані швидкості по культурах
    self.isActivelyHarvesting = false
    self.isStrawChopperActive = false -- EN: Whether straw chopper is actively engaging straw / UA: Чи активний подрібнювач соломи
    self.lastPowerChopper = 0     -- EN: Current straw chopper power consumption (HP) / UA: Споживання подрібнювача (к.с.)
    self.lastPowerForageFeed = 0   -- EN: Forage harvester feed rolls power (HP) / UA: Потужність живильних вальців (к.с.)
    self.lastPowerForageDrum = 0   -- EN: Forage cutterhead drum power (HP) / UA: Потужність подрібнювального барабана (к.с.)
    self.lastPowerForageBlower = 0 -- EN: Forage discharge accelerator power (HP) / UA: Потужність прискорювача викиду (к.с.)
    
    -- EN: Pre-allocated circular ring buffers for rolling metrics (zero runtime table allocations)
    -- UA: Попередньо виділені кільцеві буфери для ковзних метрик (без виділення пам'яті в рантаймі)
    local PROD_RING_SIZE = 180
    self.prodRingSize = PROD_RING_SIZE
    self.prodRingMass = {}
    self.prodRingLiters = {}
    self.prodRingTime = {}
    self.prodRingArea = {}
    for i = 1, PROD_RING_SIZE do
        self.prodRingMass[i] = 0
        self.prodRingLiters[i] = 0
        self.prodRingTime[i] = 0
        self.prodRingArea[i] = 0
    end
    self.prodRingHead = 1
    self.prodSumMass = 0
    self.prodSumLiters = 0
    self.prodSumTime = 0
    self.prodSumArea = 0

    local YIELD_RING_SIZE = 180
    self.yieldRingSize = YIELD_RING_SIZE
    self.yieldRingMass = {}
    self.yieldRingArea = {}
    for i = 1, YIELD_RING_SIZE do
        self.yieldRingMass[i] = 0
        self.yieldRingArea[i] = 0
    end
    self.yieldRingHead = 1
    self.yieldSumMass = 0
    self.yieldSumArea = 0

    self.debug = false  -- EN: Kept for compatibility, unused / UA: Залишено для сумісності, не використовується
    rhm_log("RHM [RHM_LoadCalculator]: RHM: RHM_LoadCalculator initialized")
    
    return self
end

---EN: Resolves engine horsepower (HP) from vehicle motorized spec, configuration, or carrier tractor (NEXAT/towed).
---UA: Визначає потужність двигуна (к.с.) зі специфікації, конфігурації техніки або тягового трактора (NEXAT/причіпні).
function RHM_LoadCalculator:getEnginePowerHp(vehicle)
    local motorConfigIndex = (vehicle.configurations and tonumber(vehicle.configurations.motor)) or 1
    if vehicle._rhm_engineHp and vehicle._rhm_engineHpConfig == motorConfigIndex and vehicle._rhm_engineHp > 0 then
        return vehicle._rhm_engineHp
    end

    -- 1. Check motorized spec on vehicle or root/attacher carrier (for trailed harvesters, tractor setups, or NEXAT)
    local motorObj = vehicle
    if not (vehicle.spec_motorized and vehicle.spec_motorized.motor) then
        local root = vehicle.rootVehicle or (vehicle.getRootVehicle and vehicle:getRootVehicle())
        if root and root.spec_motorized and root.spec_motorized.motor then
            motorObj = root
        else
            local attacher = vehicle.attacherVehicle or (vehicle.getAttacherVehicle and vehicle:getAttacherVehicle())
            if attacher and attacher.spec_motorized and attacher.spec_motorized.motor then
                motorObj = attacher
            end
        end
    end

    local carrierConfigIndex = (motorObj.configurations and tonumber(motorObj.configurations.motor)) or motorConfigIndex
    if motorObj._rhm_engineHp and motorObj._rhm_engineHpConfig == carrierConfigIndex and motorObj._rhm_engineHp > 0 then
        vehicle._rhm_engineHp = motorObj._rhm_engineHp
        vehicle._rhm_engineHpConfig = motorConfigIndex
        return motorObj._rhm_engineHp
    end

    local resolvedHp = nil

    -- 2. Check official GIANTS engine shop specification method (Motorized.getSpecValuePower)
    -- This correctly resolves encrypted DLC vehicles (e.g. NEXAT Pack) where XMLFile cannot inspect files.
    if Motorized and Motorized.getSpecValuePower and motorObj.spec_motorized and motorObj.configFileName and g_storeManager then
        local storeItem = g_storeManager:getItemByXMLFilename(motorObj.configFileName)
        if storeItem then
            local configs = motorObj.configurations or {}
            -- Try with returnValues = true (returns raw minPower, maxPower in HP)
            local okVal, p1, p2 = pcall(Motorized.getSpecValuePower, storeItem, motorObj, configs, nil, true)
            if okVal and p2 and tonumber(p2) and tonumber(p2) > 0 then
                resolvedHp = tonumber(p2)
            elseif okVal and p1 and tonumber(p1) and tonumber(p1) > 0 then
                resolvedHp = tonumber(p1)
            else
                -- Try with returnValues = false (returns formatted string, e.g. "809 kW / 1100 hp" or "1100 hp")
                local okStr, pStr = pcall(Motorized.getSpecValuePower, storeItem, motorObj, configs, nil, false)
                if okStr and type(pStr) == "string" then
                    local hpVal = pStr:match("(%d+[%d%,%.]*)%s*[Hh][Pp]") 
                               or pStr:match("(%d+[%d%,%.]*)%s*[Cc][Hh]")
                               or pStr:match("(%d+[%d%,%.]*)%s*л%.%s*с")
                               or pStr:match("(%d+[%d%,%.]*)%s*[Pp][Ss]")
                    if hpVal then
                        resolvedHp = tonumber(hpVal:gsub(",", "."))
                    else
                        local kwVal = pStr:match("(%d+[%d%,%.]*)%s*[Kk][Ww]") or pStr:match("(%d+[%d%,%.]*)%s*к[Вв][Тт]")
                        if kwVal then
                            resolvedHp = tonumber(kwVal:gsub(",", ".")) * 1.35962
                        end
                    end
                end
                if not okVal and not okStr then
                    rhm_log(string.format("RHM: Failed to inspect shop power specifications for %s: %s", tostring(motorObj:getName() or motorObj.configFileName), tostring(p1 or pStr)))
                end
            end
        end
    end

    -- 3. Check VehicleMotor runtime engine instance properties
    if not resolvedHp and motorObj.spec_motorized and motorObj.spec_motorized.motor then
        local motor = motorObj.spec_motorized.motor
        -- In GIANTS Engine 10 (FS25) VehicleMotor:new assigns self.maxMotorPower (in kW)
        if motor.maxMotorPower and tonumber(motor.maxMotorPower) and tonumber(motor.maxMotorPower) > 0 then
            resolvedHp = tonumber(motor.maxMotorPower) * 1.35962
        elseif motor.peakMotorPower and tonumber(motor.peakMotorPower) and tonumber(motor.peakMotorPower) > 0 then
            resolvedHp = tonumber(motor.peakMotorPower) * 1.35962
        elseif motor.motorPeakPower and tonumber(motor.motorPeakPower) and tonumber(motor.motorPeakPower) > 0 then
            resolvedHp = tonumber(motor.motorPeakPower) * 1.35962
        elseif motor.hp and tonumber(motor.hp) and tonumber(motor.hp) > 0 then
            resolvedHp = tonumber(motor.hp)
        elseif motor.motorPower and tonumber(motor.motorPower) and tonumber(motor.motorPower) > 0 then
            resolvedHp = tonumber(motor.motorPower) * 1.35962
        elseif motor.maxPower and tonumber(motor.maxPower) and tonumber(motor.maxPower) > 0 then
            resolvedHp = tonumber(motor.maxPower) * 1.35962
        end

        -- Check methods if variables were private
        if not resolvedHp then
            if motor.getMaxMotorPower then
                local kw = motor:getMaxMotorPower()
                if kw and tonumber(kw) and tonumber(kw) > 0 then resolvedHp = tonumber(kw) * 1.35962 end
            elseif motor.getPeakMotorPower then
                local kw = motor:getPeakMotorPower()
                if kw and tonumber(kw) and tonumber(kw) > 0 then resolvedHp = tonumber(kw) * 1.35962 end
            elseif motor.getHp then
                local hp = motor:getHp()
                if hp and tonumber(hp) and tonumber(hp) > 0 then resolvedHp = tonumber(hp) end
            end
        end
    end

    -- 4. Check in-memory spec_motorized.motorConfigurations table
    if not resolvedHp and motorObj.spec_motorized and motorObj.spec_motorized.motorConfigurations then
        local cfgs = motorObj.spec_motorized.motorConfigurations
        local cfg = cfgs[carrierConfigIndex] or cfgs[1]
        if cfg then
            if cfg.hp and tonumber(cfg.hp) and tonumber(cfg.hp) > 0 then
                resolvedHp = tonumber(cfg.hp)
            elseif cfg.maxMotorPower and tonumber(cfg.maxMotorPower) and tonumber(cfg.maxMotorPower) > 0 then
                resolvedHp = tonumber(cfg.maxMotorPower) * 1.35962
            elseif cfg.power and tonumber(cfg.power) and tonumber(cfg.power) > 0 then
                local p = tonumber(cfg.power)
                resolvedHp = (p > 900) and p or (p * 1.35962)
            end
        end
    end

    -- 5. Inspect vehicle XML configuration for engine power rating
    if not resolvedHp and motorObj.configFileName then
        local xmlFile = nil
        local schema = (Vehicle and Vehicle.xmlSchema) or nil
        if XMLFile and XMLFile.loadIfExists then
            xmlFile = XMLFile.loadIfExists("RHM_EngineHpCheck", motorObj.configFileName, schema)
        elseif loadXMLFile then
            xmlFile = loadXMLFile("RHM_EngineHpCheck", motorObj.configFileName)
        end

        if xmlFile then
            local hp = nil
            if xmlFile.getInt then
                hp = xmlFile:getInt(string.format("vehicle.motorized.motorConfigurations.motorConfiguration(%d)#hp", carrierConfigIndex - 1))
                if not hp or hp <= 0 then
                    hp = xmlFile:getInt("vehicle.motorized.motorConfigurations.motorConfiguration(0)#hp")
                end
                if not hp or hp <= 0 then
                    hp = xmlFile:getInt("vehicle.storeData.specs.power")
                end
            elseif xmlFile.getValue and XMLValueType then
                hp = xmlFile:getValue(string.format("vehicle.motorized.motorConfigurations.motorConfiguration(%d)#hp", carrierConfigIndex - 1), XMLValueType.INT)
                if not hp or hp <= 0 then
                    hp = xmlFile:getValue("vehicle.motorized.motorConfigurations.motorConfiguration(0)#hp", XMLValueType.INT)
                end
                if not hp or hp <= 0 then
                    hp = xmlFile:getValue("vehicle.storeData.specs.power", XMLValueType.INT)
                end
            elseif getXMLInt then
                hp = getXMLInt(xmlFile, string.format("vehicle.motorized.motorConfigurations.motorConfiguration(%d)#hp", carrierConfigIndex - 1))
                if not hp or hp <= 0 then
                    hp = getXMLInt(xmlFile, "vehicle.motorized.motorConfigurations.motorConfiguration(0)#hp")
                end
                if not hp or hp <= 0 then
                    hp = getXMLInt(xmlFile, "vehicle.storeData.specs.power")
                end
            end

            if xmlFile.delete then
                xmlFile:delete()
            elseif delete then
                delete(xmlFile)
            end

            if hp and tonumber(hp) and tonumber(hp) > 0 then
                resolvedHp = tonumber(hp)
            end
        end
    end

    -- 6. Direct storeItem.specs fallback
    if not resolvedHp and motorObj.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
        local storeItem = g_storeManager:getItemByXMLFilename(motorObj.configFileName)
        if storeItem and storeItem.specs then
            if storeItem.specs.power and tonumber(storeItem.specs.power) and tonumber(storeItem.specs.power) > 0 then
                resolvedHp = tonumber(storeItem.specs.power)
            elseif storeItem.specs.neededPower and tonumber(storeItem.specs.neededPower) and tonumber(storeItem.specs.neededPower) > 0 then
                resolvedHp = tonumber(storeItem.specs.neededPower)
            end
        end
    end

    -- 7. Signature recognition for known modular carrier platforms (NEXAT)
    -- Dual 550 HP engines = 1100 HP total system rating
    if not resolvedHp or resolvedHp <= 400 then
        local brandName = ""
        if motorObj.getBrandName then brandName = motorObj:getBrandName() or "" end
        local rawName = (motorObj.getName and motorObj:getName()) or ""
        local fullName = (motorObj.getFullName and motorObj:getFullName()) or ""
        local vehBrand = ""
        if vehicle.getBrandName then vehBrand = vehicle:getBrandName() or "" end
        local vehName = (vehicle.getName and vehicle:getName()) or ""
        local vehFull = (vehicle.getFullName and vehicle:getFullName()) or ""
        local sig = string.format("%s %s %s %s %s %s", brandName, rawName, fullName, vehBrand, vehName, vehFull):upper()
        if sig:find("NEXAT") or sig:find("NEXCO") then
            resolvedHp = 1100
        end
    end

    -- 8. Check basePerfMass back-calculation if cached
    if not resolvedHp and self.basePerfMass and self.basePerfMass > 0 then
        resolvedHp = math.max(150, self.basePerfMass * 3.6 * 5.2)
    end

    resolvedHp = resolvedHp or 400
    vehicle._rhm_engineHp = resolvedHp
    vehicle._rhm_engineHpConfig = motorConfigIndex
    motorObj._rhm_engineHp = resolvedHp
    motorObj._rhm_engineHpConfig = carrierConfigIndex

    rhm_log(string.format("RHM [RHM_LoadCalculator]: Detected engine power for %s: %.0f HP (config #%d)", 
        motorObj.getFullName and motorObj:getFullName() or "Harvester", resolvedHp, motorConfigIndex))

    return resolvedHp
end

local HEADER_OBJECTS_TO_SCAN = {}
local HEADER_SCANNED = {}

local function addHeaderScanObj(obj)
    if obj and not HEADER_SCANNED[obj] then
        HEADER_SCANNED[obj] = true
        table.insert(HEADER_OBJECTS_TO_SCAN, obj)
    end
end

---EN: Resolves attached cutter power requirements (HP) and properties dynamically from FS25 XML/specs.
---    Seamlessly supports standard combines, NEXAT modular systems, self-propelled harvesters with integrated
---    cutters (e.g. potato/carrot/cotton), and multi-implement tractor trains (front topper + rear harvester).
---UA: Динамічно визначає вимоги жатки до потужності (к.с.) та її властивості з XML/специфікацій FS25.
---    Повністю підтримує стандартні комбайни, модульні системи NEXAT, самохідні комбайни з вбудованими жатками
---    (картопля/морква/бавовна) та зв'язки знарядь на тракторі (передній гичкозрізувач + задній комбайн).
function RHM_LoadCalculator:getAttachedHeaderInfo(vehicle)
    local headerHp = 0
    local maxWorkingSpeed = nil
    local isCutterActive = false
    local isPickup = false
    local isForageCutter = false
    local cutterCount = 0

    if not vehicle then
        return headerHp, 10.0, isCutterActive, isPickup, isForageCutter, cutterCount
    end

    -- Find the motorized carrier / tractor if vehicle is attached (e.g. NEXAT, tractor with front/rear implements)
    local motorCarrier = nil
    if vehicle.spec_motorized and vehicle.spec_motorized.motor then
        motorCarrier = vehicle
    else
        local root = vehicle.rootVehicle or (vehicle.getRootVehicle and vehicle:getRootVehicle())
        if root and root.spec_motorized and root.spec_motorized.motor then
            motorCarrier = root
        else
            local attacher = vehicle.attacherVehicle or (vehicle.getAttacherVehicle and vehicle:getAttacherVehicle())
            if attacher and attacher.spec_motorized and attacher.spec_motorized.motor then
                motorCarrier = attacher
            end
        end
    end

    -- Collect all objects in the harvesting train (reusing pre-allocated tables to eliminate GC allocations):
    for k in pairs(HEADER_SCANNED) do HEADER_SCANNED[k] = nil end
    for i = #HEADER_OBJECTS_TO_SCAN, 1, -1 do HEADER_OBJECTS_TO_SCAN[i] = nil end

    addHeaderScanObj(vehicle)

    if vehicle.getAttachedImplements then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            addHeaderScanObj(implement.object)
        end
    end

    if motorCarrier and motorCarrier ~= vehicle then
        addHeaderScanObj(motorCarrier)
        if motorCarrier.getAttachedImplements then
            for _, implement in pairs(motorCarrier:getAttachedImplements()) do
                addHeaderScanObj(implement.object)
            end
        end
    end

    -- Traverse collected equipment
    for _, obj in ipairs(HEADER_OBJECTS_TO_SCAN) do
        local isCutter = (obj.spec_cutter ~= nil or obj.spec_forageHarvesterCutter ~= nil 
                       or obj.spec_forageCutter ~= nil or obj.spec_pickup ~= nil)

        -- In trailed setups, a separate harvester implement consumes PTO power.
        -- Must NOT be the vehicle running RHM itself.
        local isTrailedHarvester = (obj ~= motorCarrier and obj ~= vehicle and obj.spec_combine ~= nil)
        local isGrapeOrOliveMachine = (obj == vehicle and self.combineMemory and (self.combineMemory.machineType == "grape" or self.combineMemory.machineType == "olive"))

        if isCutter or isTrailedHarvester or isGrapeOrOliveMachine then
            cutterCount = cutterCount + 1

            -- Check active state
            if obj.getIsTurnedOn and obj:getIsTurnedOn() then
                isCutterActive = true
            elseif vehicle.getIsTurnedOn and vehicle:getIsTurnedOn() then
                isCutterActive = true
            elseif vehicle.spec_combine and vehicle.spec_combine.isThreshing then
                isCutterActive = true
            end

            local objItem = obj.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename and g_storeManager:getItemByXMLFilename(obj.configFileName)
            local objCat = (objItem and objItem.categoryName) or ""
            local objCatLower = tostring(objCat):lower()
            local objTypeName = (obj.typeName or (obj.type and obj.type.name) or ""):lower()

            if obj.spec_forageHarvesterCutter ~= nil or obj.spec_forageCutter ~= nil or objCatLower:find("forage") ~= nil or objTypeName:find("forage") ~= nil then
                isForageCutter = true
            end
            if obj.spec_pickup ~= nil or objCatLower:find("pickup") ~= nil or objTypeName:find("pickup") ~= nil then
                isPickup = true
            end

            -- Working speed limit of the header/tool
            -- CRITICAL FIX: NEVER call obj:getSpeedLimit(true) on the vehicle itself,
            -- because vehicle:getSpeedLimit is hooked by RHM and returns our own dynamic speedLimit (locking it to 5 km/h)!
            local limit = nil
            if obj ~= vehicle then
                if obj.spec_cutter and obj.spec_cutter.maxWorkingSpeed then
                    limit = obj.spec_cutter.maxWorkingSpeed
                elseif obj.speedLimit and obj.speedLimit > 0 and obj.speedLimit < 50 then
                    limit = obj.speedLimit
                elseif obj.getSpeedLimit then
                    limit = obj:getSpeedLimit(true)
                end
            else
                -- For self-propelled machines with integrated/built-in cutters (obj == vehicle):
                -- Use the genuine vanilla working speed captured before RHM limiting,
                -- or read directly from spec_cutter.maxWorkingSpeed or obj.speedLimit.
                if self.vanillaWorkingSpeed and self.vanillaWorkingSpeed > 0 then
                    limit = self.vanillaWorkingSpeed
                elseif self.genuineSpeedLimit and self.genuineSpeedLimit > 0 then
                    limit = self.genuineSpeedLimit
                elseif obj.spec_cutter and obj.spec_cutter.maxWorkingSpeed then
                    limit = obj.spec_cutter.maxWorkingSpeed
                elseif obj.speedLimit and obj.speedLimit > 0 and obj.speedLimit < 50 then
                    limit = obj.speedLimit
                end
            end

            if limit and limit > 0 and limit < 50 then
                if maxWorkingSpeed == nil then
                    maxWorkingSpeed = limit
                else
                    maxWorkingSpeed = math.min(maxWorkingSpeed, limit)
                end
            end

            -- Power consumption of the tool (HP)
            local ptoHp = 0
            if obj ~= motorCarrier then
                -- A: Check spec_powerConsumer
                if obj.spec_powerConsumer then
                    local pc = obj.spec_powerConsumer
                    local kw = pc.neededPtoPower or pc.neededMaxPtoPower or pc.neededMinPtoPower or pc.neededPower or 0
                    if kw and kw > 0 then
                        ptoHp = kw * 1.35962 -- kW to HP
                    end
                end
                -- B: Check getNeededPtoPower / getNeededPower methods
                if ptoHp == 0 then
                    if obj.getNeededPtoPower then
                        local kw = obj:getNeededPtoPower()
                        if kw and kw > 0 then ptoHp = kw * 1.35962 end
                    end
                end
                if ptoHp == 0 and obj.getNeededPower then
                    local kw = obj:getNeededPower()
                    if kw and kw > 0 then ptoHp = kw * 1.35962 end
                end
                -- C: Store item XML specs fallback
                if ptoHp == 0 and obj.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
                    local item = g_storeManager:getItemByXMLFilename(obj.configFileName)
                    if item and item.specs and item.specs.neededPower then
                        ptoHp = tonumber(item.specs.neededPower) or 0
                    end
                end
            end

            -- D: Enforce physical minimum power requirements based on working width and cutter type
            local width = 0
            if obj.getWorkingWidth then
                local w = obj:getWorkingWidth()
                if w and w > 0 then width = w end
            end
            if width == 0 and obj.spec_cutter and obj.spec_cutter.workingWidth then
                width = obj.spec_cutter.workingWidth
            end
            if width == 0 and obj.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
                local item = g_storeManager:getItemByXMLFilename(obj.configFileName)
                if item and item.specs and item.specs.workingWidth then
                    width = tonumber(item.specs.workingWidth) or width
                end
            end
            if width > 0 then
                self.lastHeaderWidth = width
            else
                width = 6.0
            end

            local minHpPerM = 7.5 -- Standard grain/draper cutter (7.5 HP/m - matches base engine PTO specifications)
            if isForageCutter then
                minHpPerM = 20.0 -- High-speed rotary forage cutter (~18-20 HP/m)
            elseif isPickup then
                minHpPerM = 15.0 -- Windrow pickup reel
            elseif isTrailedHarvester then
                minHpPerM = 25.0
            end

            local cropUpper = (self.currentCrop and string.upper(self.currentCrop)) or ""
            local fruitTypeIndex = vehicle.spec_combine and vehicle.spec_combine.lastValidInputFruitType
            if (not cropUpper or cropUpper == "" or cropUpper == "UNKNOWN") and fruitTypeIndex and fruitTypeIndex ~= 0 and g_fruitTypeManager then
                local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
                if fruitTypeDesc and fruitTypeDesc.name then
                    cropUpper = string.upper(fruitTypeDesc.name)
                end
            end

            if cropUpper:find("CORN") or cropUpper:find("MAIZE") then
                if not isForageCutter then
                    minHpPerM = 18.0 -- Chopping corn header with stalk shredders
                end
            elseif cropUpper:find("BEAN") or cropUpper:find("PEA") or cropUpper:find("SPINACH") then
                minHpPerM = 28.0 -- Vegetable pod stripper / spinach cutter
            elseif cropUpper:find("POTATO") or cropUpper:find("BEET") or cropUpper:find("CARROT") or cropUpper:find("PARSNIP")
                or cropUpper:find("ONION") or cropUpper:find("GARLIC") then
                minHpPerM = 22.0 -- Root intake & lifting knives / topper
            end

            ptoHp = math.max(ptoHp, width * minHpPerM)
            headerHp = headerHp + ptoHp
        end
    end

    -- If self-propelled machine with built-in cutter/shaker and no separate PTO consumer was registered:
    if headerHp == 0 and vehicle == motorCarrier and (vehicle.spec_cutter ~= nil or vehicle.getWorkingWidth ~= nil or vehicle.spec_combine ~= nil) then
        local width = 0
        if vehicle.getWorkingWidth then
            local w = vehicle:getWorkingWidth()
            if w and w > 0 then width = w end
        end
        if width == 0 and vehicle.spec_cutter and vehicle.spec_cutter.workingWidth then
            width = vehicle.spec_cutter.workingWidth
        end
        if width == 0 and vehicle.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
            local item = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
            if item and item.specs and item.specs.workingWidth then
                width = tonumber(item.specs.workingWidth) or width
            end
        end

        local cropUpper = (self.currentCrop and string.upper(self.currentCrop)) or ""
        local isGrapeOrOlive = (cropUpper:find("GRAPE") or cropUpper:find("OLIVE")
            or (self.combineMemory and (self.combineMemory.machineType == "grape" or self.combineMemory.machineType == "olive")))

        if width == 0 then
            width = isGrapeOrOlive and 2.5 or 3.0
        end

        local fruitTypeIndex = vehicle.spec_combine and vehicle.spec_combine.lastValidInputFruitType
        if (not cropUpper or cropUpper == "" or cropUpper == "UNKNOWN") and fruitTypeIndex and fruitTypeIndex ~= 0 and g_fruitTypeManager then
            local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
            if fruitTypeDesc and fruitTypeDesc.name then
                cropUpper = string.upper(fruitTypeDesc.name)
            end
        end

        local isStripper = (cropUpper:find("BEAN") or cropUpper:find("PEA") or cropUpper:find("SPINACH"))
        local hpPerMeter = 22.0
        if isStripper then
            hpPerMeter = 28.0
        elseif isGrapeOrOlive then
            hpPerMeter = 14.0 -- Shaker tunnel rods and extractor turbines (~35 HP total)
        end
        headerHp = width * hpPerMeter
        self.lastHeaderWidth = width

        if vehicle.getIsTurnedOn and vehicle:getIsTurnedOn() then
            isCutterActive = true
            cutterCount = math.max(1, cutterCount)
        end
    end

    maxWorkingSpeed = maxWorkingSpeed or self.vanillaWorkingSpeed or (self.genuineSpeedLimit > 0 and self.genuineSpeedLimit) or 10.0
    return headerHp, maxWorkingSpeed, isCutterActive, isPickup, isForageCutter, cutterCount
end

---EN: Dynamically calculates the physical specific processing energy (HP per t/h) based on FS25 crop traits.
---UA: Динамічно розраховує питому енергію обмолоту/подрібнення (к.с. на т/год) на основі властивостей культури з FS25.
function RHM_LoadCalculator:getCropSpecificEnergy(fruitTypeIndex, fillTypeIndex, machineType, isPickup, isForageCutter)
    machineType = machineType or "grain"

    local fruitTypeDesc = nil
    if g_fruitTypeManager and fruitTypeIndex and fruitTypeIndex ~= 0 and fruitTypeIndex ~= FruitType.UNKNOWN then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    end

    local fillTypeDesc = nil
    if g_fillTypeManager and fillTypeIndex and fillTypeIndex ~= 0 and fillTypeIndex ~= FillType.UNKNOWN then
        fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    end

    local cropName = "UNKNOWN"
    if fruitTypeDesc and fruitTypeDesc.name then
        cropName = string.upper(fruitTypeDesc.name)
    elseif fillTypeDesc and fillTypeDesc.name then
        cropName = string.upper(fillTypeDesc.name)
    elseif self.currentCrop then
        cropName = string.upper(self.currentCrop)
    end

    -- Bulk density (kg/L)
    local density = 0.75
    if fillTypeDesc and fillTypeDesc.massPerLiter and fillTypeDesc.massPerLiter > 0 then
        density = fillTypeDesc.massPerLiter * 1000
    end

    -- Does this crop generate straw/windrows in the thresher?
    local hasStraw = false
    if fruitTypeDesc and fruitTypeDesc.hasWindrow ~= nil then
        hasStraw = fruitTypeDesc.hasWindrow
    else
        hasStraw = (cropName == "WHEAT" or cropName == "BARLEY" or cropName == "OAT" or cropName == "OATS"
                 or cropName == "RYE" or cropName == "SPELT" or cropName == "TRITICALE" or cropName:find("RICE"))
    end

    local baseESpec = 6.0

    -- 1. FORAGE HARVESTERS (Chopping whole plant: corn silage, grass, poplar, etc.)
    if machineType == "forage" or isForageCutter then
        if cropName:find("POPLAR") or cropName:find("WOOD") then
            baseESpec = 9.5 -- Poplar wood chipping: high-resistance wood cutting drum
        elseif isPickup then
            -- Swath pickup headers (e.g. EasyFlow, Pick Up 300): pre-wilted windrow, cracker rolls disengaged
            if cropName:find("STRAW") or cropName:find("HAY") or cropName:find("DRYGRASS") then
                baseESpec = 1.05 -- Dry windrow pickup: brittle, easy shearing
            else
                baseESpec = 1.18 -- Wilted grass / alfalfa / clover / whole-crop windrow pickup (ASABE D497 ~1.1-1.3 kWh/t FM at 15-25mm LOC)
            end
        elseif cropName:find("MAIZE") or cropName:find("CORN") or cropName:find("SILAGE") or cropName:find("CHAFF") or cropName:find("GPS") then
            -- Standing whole corn silage or direct-cut sorghum: heavy woody stalk + active corn cracker roller mills (ASABE EP496)
            baseESpec = 2.10
        elseif cropName:find("GRASS") or cropName:find("MEADOW") or cropName:find("ALFALFA") or cropName:find("LUCERNE") or cropName:find("CLOVER") then
            -- Direct-cut standing fresh grass disc header (e.g. XDisc): tough elastic standing stems
            baseESpec = 2.60
        else
            baseESpec = 2.10 -- Universal direct-cut forage fallback
        end

    -- 2. ROOT & SPECIALIZED VEGETABLE HARVESTERS (Lifting, cleaning, pod stripping, stalk cutting)
    elseif machineType == "root" then
        if cropName:find("SUGARCANE") or cropName:find("CANE") then
            -- Sugarcane harvesters categorized as root vehicles in FS25
            baseESpec = 4.8
        elseif cropName:find("SPINACH") then
            -- Spinach: dense wet leafy biomass, Oxbo cutter bar
            baseESpec = 7.8
        elseif (cropName:find("GREEN") and (cropName:find("BEAN") or cropName:find("PEA")))
               or cropName:find("GREENBEANS") or cropName:find("GREENBEAN") then
            -- Fresh green beans: pod stripping reel through massive bush mass
            baseESpec = 14.5
        elseif cropName:find("PEA") or cropName:find("BEAN") or cropName:find("LENTIL") or cropName:find("LUPIN") then
            baseESpec = 14.0
        elseif cropName:find("POTATO") then
            -- Potatoes: heavy ridge lifting, soil separation sieves, haulm chopper
            baseESpec = 2.55
        elseif cropName:find("SUGARBEET") or cropName:find("BEET") then
            -- Sugar beets: round shape, squeeze wheels, heavy turbine cleaning
            baseESpec = 2.10
        elseif cropName:find("BEETROOT") or cropName:find("RED BEET") or cropName:find("REDBEET") then
            -- Red table beet: firm root, rubber pulling belts
            baseESpec = 2.40
        elseif cropName:find("CARROT") then
            -- Carrots: deep taproots, pulling belts, haulm cutters
            baseESpec = 1.65
        elseif cropName:find("PARSNIP") or cropName:find("RUTABAGA") or cropName:find("TURNIP") then
            -- Parsnips: tapered taproot, firm soil suction
            baseESpec = 2.10
        elseif cropName:find("ONION") then
            baseESpec = 2.20
        elseif cropName:find("GARLIC") then
            baseESpec = 2.30
        else
            baseESpec = 2.10 -- Universal root fallback
        end

    -- 3. COTTON HARVESTERS (Fluffy, low density lint picking & baling)
    elseif machineType == "cotton" or cropName:find("COTTON") then
        baseESpec = 55.0 -- High-speed spindle drums + on-board round/square bale chamber hydraulic compaction

    -- 4. SUGARCANE HARVESTERS
    elseif cropName:find("SUGARCANE") or cropName:find("CANE") then
        baseESpec = 4.8 -- Heavy stalk base cutter, dual billet chopper drums, high-power extractor fans

    -- 5. GRAPES & OLIVES (Specialized straddle harvesters)
    elseif machineType == "grape" or cropName:find("GRAPE") then
        baseESpec = 3.8 -- Shaker rod frequency, sorting belts, destemmer
    elseif machineType == "olive" or cropName:find("OLIVE") then
        baseESpec = 2.6 -- Olive shaker beaters, leaf blowers

    -- 6. GRAIN COMBINE HARVESTERS (Grain tank stream processing)
    else
        if isPickup then
            baseESpec = 2.2 -- Windrow pickup for grain combine
        elseif cropName:find("CORN") or cropName:find("MAIZE") then
            -- Corn for grain: cobs snapped on header, threshed in rotor with minimal MOG
            baseESpec = 3.8
        elseif cropName:find("ONION") or cropName:find("GARLIC") then
            baseESpec = 2.20 -- Trailed onion lifters running on tractor/grain spec
        elseif cropName:find("SUNFLOWER") then
            -- Sunflower: low density (0.35), massive head volume, stalk cutting
            baseESpec = 14.5
        elseif cropName:find("CANOLA") or cropName:find("RAPESEED") then
            baseESpec = 9.2
        elseif cropName:find("SOYBEAN") then
            baseESpec = 8.8
        elseif cropName:find("OAT") or cropName:find("OATS") then
            -- Oat: light seeds (0.50 kg/L) with heavy tough fibrous straw
            baseESpec = 9.5
        elseif cropName:find("POPPY") then
            baseESpec = 14.0
        elseif cropName:find("LINSEED") or cropName:find("FLAX") then
            baseESpec = 10.5
        elseif cropName:find("MUSTARD") then
            baseESpec = 10.0
        elseif cropName:find("HEMP") then
            baseESpec = 9.5
        elseif cropName:find("LENTIL") then
            baseESpec = 8.5
        elseif cropName:find("CHICKPEA") then
            baseESpec = 8.0
        elseif cropName:find("BUCKWHEAT") then
            baseESpec = 8.0
        elseif cropName:find("SPELT") then
            baseESpec = 5.4
        elseif cropName:find("MILLET") then
            baseESpec = 6.2
        elseif cropName:find("RICE") then
            if cropName:find("LONG") then
                baseESpec = 5.2 -- Rice Long Grain (US)
            else
                baseESpec = 6.5 -- Asian Rice (higher silica straw resistance)
            end
        elseif cropName:find("RYE") then
            baseESpec = 5.2
        elseif cropName:find("TRITICALE") then
            baseESpec = 5.2
        elseif cropName:find("BARLEY") then
            baseESpec = 5.0
        elseif cropName:find("PEA") then
            baseESpec = 5.2
        elseif cropName:find("SORGHUM") then
            baseESpec = 5.0
        elseif cropName:find("WHEAT") then
            baseESpec = 4.8
        elseif hasStraw then
            baseESpec = 5.0 -- Standard straw cereals
        else
            -- Universal dynamic fallback for custom or unclassified crops based on physical density
            if density < 0.50 then
                baseESpec = 12.0 -- Very light seed with high biomass
            elseif density < 0.70 then
                baseESpec = 9.0  -- Medium density oilseeds/legumes
            else
                baseESpec = 5.0  -- Dense grain
            end
        end
    end

    -- DYNAMIC YIELD & BIOMASS ADAPTATION:
    -- Resolves natural nominal crop yield baseline (t/ha) directly from FS25 engine data.
    -- Dynamically scales processing energy based on the physical Harvest Index of local field yield.
    local lpsqm = 0.85
    if fruitTypeDesc then
        if fruitTypeDesc.harvest and fruitTypeDesc.harvest.literPerSqm and fruitTypeDesc.harvest.literPerSqm > 0 then
            lpsqm = fruitTypeDesc.harvest.literPerSqm
        elseif fruitTypeDesc.literPerSqm and fruitTypeDesc.literPerSqm > 0 then
            lpsqm = fruitTypeDesc.literPerSqm
        elseif fruitTypeDesc.litersPerSqm and fruitTypeDesc.litersPerSqm > 0 then
            lpsqm = fruitTypeDesc.litersPerSqm
        end
    end

    -- Natural baseline yield in t/ha (average fertilized crop ~ 1.1x base literPerSqm)
    local yRef = math.max(1.0, lpsqm * 10.0 * density * 1.10)

    local actualYield = self.currentYield or 0
    if actualYield < 0.5 then
        actualYield = yRef
    end

    -- Agricultural Harvest Index curve:
    -- In grain combines, grain-to-straw ratio improves at high yields (alpha = 0.70).
    -- In root, vegetable, forage, and whole-crop harvesters, the entire mass is processed without straw dilution (alpha = 0.12).
    local alpha = 0.70
    local minFactor = 0.45
    if machineType == "root" then
        alpha = 0.12
        minFactor = 0.75
    elseif machineType == "forage" or machineType == "cotton" or machineType == "sugarcane" or machineType == "grape" or machineType == "olive" then
        alpha = 0.15
        minFactor = 0.75
    end

    local yieldRatio = yRef / actualYield
    local yieldFactor = math.pow(yieldRatio, alpha)
    yieldFactor = math.max(minFactor, math.min(1.25, yieldFactor))

    return baseESpec * yieldFactor
end



---EN: Sets base performance mass / UA: Встановлює базову продуктивність (маса)
function RHM_LoadCalculator:setBasePerformance(basePerfMass)
    self.basePerfMass = basePerfMass
    
    rhm_log(string.format("RHM [RHM_LoadCalculator]: RHM: Base performance set to %.2f kg/s (%.1f t/h)", 
        self.basePerfMass, self.basePerfMass * 3.6))
end

---EN: Calculates nominal base throughput capacity (kg/s) based on engine horsepower and machine type.
---UA: Розраховує номінальну базову пропускну здатність (кг/с) на основі потужності двигуна та типу машини.
function RHM_LoadCalculator:getBasePerformanceFromPower(vehicle)
    local hp = self:getEnginePowerHp(vehicle)
    local category = ""
    if vehicle.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
        local item = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
        if item and item.categoryName then
            category = tostring(item.categoryName):lower()
        end
    end
    if category == "" and vehicle.xmlFile then
        local rawCat = vehicle.xmlFile:getValue("vehicle.storeData.category")
        if type(rawCat) == "table" then
            category = table.concat(rawCat, " "):lower()
        elseif type(rawCat) == "string" then
            category = rawCat:lower()
        end
    end

    local rhmSpec = vehicle.spec_rhm_Combine
    local machineType = (rhmSpec and rhmSpec.combineMemory and rhmSpec.combineMemory.machineType) or (rhmSpec and rhmSpec.machineType) or ""

    local isForage = (machineType == "forage" or category:find("forage") ~= nil)
    local isRoot = (machineType == "root" or category:find("beet") ~= nil or category:find("potato") ~= nil or category:find("vegetable") ~= nil)
    local isCotton = (machineType == "cotton" or category:find("cotton") ~= nil)
    local isGrapeOrOlive = (machineType == "grape" or machineType == "olive" or category:find("grape") ~= nil or category:find("olive") ~= nil)

    -- Nominal throughput at 100% processing load (t/h)
    local nominalTph = 0
    if isForage then
        nominalTph = hp / 1.4 -- ~1.4 HP per t/h average for whole-crop / swath chopping
    elseif isRoot then
        nominalTph = hp / 0.75 -- ~0.75 HP per t/h
    elseif isCotton then
        nominalTph = hp / 18.0 -- ~18 HP per t/h for cotton
    elseif isGrapeOrOlive then
        nominalTph = hp / 3.2 -- ~3.2 HP per t/h for grape/olive picking & shaking
    else
        nominalTph = hp / 5.2 -- ~5.2 HP per t/h for grain
    end

    local nominalKgPerSec = (nominalTph * 1000) / 3600
    rhm_log(string.format("RHM [RHM_LoadCalculator]: Nominal base capacity for %s (%d HP): %.1f t/h (%.2f kg/s)", 
        vehicle:getFullName(), hp, nominalTph, nominalKgPerSec))
    return nominalKgPerSec
end

---EN: Updates load calculation variables / UA: Оновлює дані для розрахунку навантаження
function RHM_LoadCalculator:update(vehicle, dt, mass)
    -- EN: Safety check for vehicle parameter
    -- UA: Перевірка безпеки для параметра vehicle
    if not vehicle then
        return
    end
    
    self.totalDistance = self.totalDistance + (vehicle.lastMovedDistance or 0)
    self.loadAccumulatedMass = (self.loadAccumulatedMass or 0) + (mass or 0)
    
    local hasCropFlow = (mass and mass > 0) or ((self.currentAvgMass or 0) > 0.05)
    if hasCropFlow then
        self.harvestActiveTime = (self.harvestActiveTime or 0) + dt
        self.idleHarvestTime = 0
    else
        self.idleHarvestTime = (self.idleHarvestTime or 0) + dt
        if self.idleHarvestTime > 1500 then
            -- Reset entry grace period after 1.5s of no crop intake (e.g. at field turns/headlands)
            self.harvestActiveTime = 0
            self.underloadTimer = 0
        end
    end

    -- EN: Fast first reaction on entering crop from empty (300ms / 0.8m instead of 1500ms / 3m)
    -- UA: Швидка перша реакція при заході в загонку (300мс / 0.8м замість 1500мс / 3м)
    local targetInterval = self.avgTime
    local targetDistance = self.distanceForMeasuring
    if (self.harvestActiveTime or 0) < 1200 and (self.lastAvgMass or 0) < 0.1 then
        targetInterval = 300
        targetDistance = 0.8
    end
    
    self.currentTime = self.currentTime + dt
    if self.currentTime > targetInterval or self.totalDistance > targetDistance then
        self.lastUpdateInterval = self.currentTime
        self:updateSettingsImpact() -- EN: Recalculate settings penalty / UA: Перераховання штрафу налаштувань
        self:calculateEngineLoad(vehicle)
        self:calculateSpeedLimit(vehicle)
        
        -- EN: Reset tick accumulators / UA: Скидаємо лічильники
        self.currentTime = 0
        self.loadAccumulatedMass = 0
        self.totalDistance = 0
    end
end

---EN: Calculates Engine Load using the physical power-balance model: P_total = P_base + P_header(v) + P_process.
---UA: Розраховує навантаження на двигун за фізичною моделлю балансу потужностей: P_total = P_base + P_header(v) + P_process.
function RHM_LoadCalculator:calculateEngineLoad(vehicle)
    if self.currentTime <= 0 then
        return
    end
    
    local spec_combine = vehicle.spec_combine
    local rhmSpec = vehicle.spec_rhm_Combine
    
    if not spec_combine then
        rhm_log("RHM [RHM_LoadCalculator]: WARNING - vehicle.spec_combine is nil, using fallback values")
        self.engineLoad = 0
        return
    end

    -- Keep currentCrop synchronized from combine memory
    if self.combineMemory and self.combineMemory.currentCrop then
        self.currentCrop = self.combineMemory.currentCrop
    end

    local machineType = (rhmSpec and rhmSpec.combineMemory) and rhmSpec.combineMemory.machineType or "grain"

    -- 1. HEADER INFO & POWER CONSUMPTION (PTO)
    local headerHp, maxWorkingSpeed, isCutterActive, isPickup, isForageCutter, cutterCount = self:getAttachedHeaderInfo(vehicle)
    self.headerHp = headerHp
    self.maxWorkingSpeed = maxWorkingSpeed
    self.isCutterActive = isCutterActive
    self.isPickup = isPickup
    self.isForageCutter = isForageCutter

    -- Resolve fruit type and fill type for processing energy lookup
    local inputFruitType = spec_combine.lastValidInputFruitType or 0
    local outputFillType = (rhmSpec and rhmSpec.lastFillType) or 0

    -- Fallback pickup detection: WINDROW or fruitType 0
    if not isPickup then
        local fruitTypeDesc = g_fruitTypeManager and g_fruitTypeManager:getFruitTypeByIndex(inputFruitType)
        local fruitName = (fruitTypeDesc and fruitTypeDesc.name and string.upper(fruitTypeDesc.name)) or ""
        if fruitName:find("WINDROW") or inputFruitType == 0 then
            isPickup = true
            self.isPickup = true
        end
    end

    -- 2. SPECIFIC PROCESSING ENERGY (HP per t/h)
    local eSpec = self:getCropSpecificEnergy(inputFruitType, outputFillType, machineType, isPickup, isForageCutter)
    self.lastSpecificEnergy = eSpec

    if self.lastCropType ~= inputFruitType then
        self.lastCropType = inputFruitType
        local mode = isPickup and "PICKUP" or (isForageCutter and "FORAGE_CUTTER" or "DIRECT_CUT")
        rhm_log(string.format("RHM [RHM_LoadCalculator]: RHM: [INPUT] %s (Fruit: %d, Fill: %d, E_spec: %.2f HP/(t/h), Header: %.1f HP)", 
            mode, inputFruitType, outputFillType, eSpec, headerHp))
    end

    -- 3. MOISTURE FACTOR
    local moistureFactor = 1.0
    if rhmSpec and rhmSpec.data and rhmSpec.data.moisture and rhmSpec.data.moisture > 0 then
        local currentMoisture = rhmSpec.data.moisture
        local moistureLimit = 14 -- Default general limit
        
        if RHM_CombineSettingsDatabase and self.currentCrop then
            local cropSettings = RHM_CombineSettingsDatabase:getSettingsForCrop(self.currentCrop)
            if cropSettings and cropSettings.moistureLimit then
                moistureLimit = cropSettings.moistureLimit
            end
        end
        
        if machineType ~= "forage" and machineType ~= "root" then
            if currentMoisture > moistureLimit then
                local diff = currentMoisture - moistureLimit
                local penaltyPerPercent = 0.02 -- 2% difficulty per 1% moisture over limit
                if rhmSpec.packageLevel and rhmSpec.packageLevel >= 4 then
                    penaltyPerPercent = 0.01 -- Opti-Harvest reduces penalty by 50%
                end
                moistureFactor = 1.0 + (diff * penaltyPerPercent)
            end
        end
    end

    -- 4. RAW THROUGHPUT RATE (kg/s and t/h)
    local safeTime = math.max(100, self.currentTime)
    local rawKgPerSec = (self.loadAccumulatedMass or 0) * (1000 / safeTime)
    local rawTph = rawKgPerSec * 3.6

    -- Adaptive smoothing for mass flow
    -- Adaptive smoothing for mass flow
    local smoothFactor = 0.40
    local avgMass = rawKgPerSec
    if self.currentAvgMass > 0 then
        avgMass = (1 - smoothFactor) * rawKgPerSec + smoothFactor * self.currentAvgMass
    else
        -- Field entry: Feederhouse filling ramp (don't shock drum with 100% of raw mass on tick 1)
        avgMass = rawKgPerSec * 0.40
    end

    -- Feederhouse transport delay: physical crop transit from cutter bar to threshing rotor takes ~2.0 seconds
    if (self.harvestActiveTime or 0) < 2000 then
        local t = math.min(1.0, math.max(0.0, (self.harvestActiveTime or 0) / 2000.0))
        local entryRamp = 0.15 + 0.85 * (t * t * (3.0 - 2.0 * t))
        avgMass = avgMass * entryRamp
    end

    self.lastAvgMass = self.currentAvgMass
    self.currentAvgMass = avgMass
    self.rawAvgMass = rawKgPerSec

    local avgTph = avgMass * 3.6

    -- 5. AVAILABLE ENGINE HORSEPOWER
    local engineHp = self:getEnginePowerHp(vehicle)
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    local effectiveEngineHp = engineHp * (1 + 0.01 * powerBoost)

    -- 6. POWER BREAKDOWN (P_base, P_header, P_process, P_chopper, P_forage, P_soil)
    local pBase = 0
    local pHeader = 0
    local pProcess = 0
    local pChopper = 0
    local pForageFeed = 0
    local pForageDrum = 0
    local pForageBlower = 0
    local pSoil = 0

    local isActivelyHarvesting = (avgTph > 0.05) or (rawTph > 0.05)
    self.isActivelyHarvesting = isActivelyHarvesting

    if isCutterActive or isActivelyHarvesting then
        -- Base mechanical & driveline losses:
        -- Modern grain / forage combines: ~8% (efficient hydrostatic & variable transmissions)
        -- Heavy hydrostatic root crop harvesters: ~10%
        if machineType == "root" then
            pBase = effectiveEngineHp * 0.10
        else
            pBase = effectiveEngineHp * 0.08
        end

        -- Header power consumption (scales with ground speed)
        if headerHp > 0 then
            local currentSpeed = (vehicle and vehicle.getLastSpeed and vehicle:getLastSpeed()) or self.speedLimit or 7.0
            local refSpeed = math.max(1.0, maxWorkingSpeed or 10.0)
            local speedRatio = math.min(1.0, math.max(0.0, currentSpeed / refSpeed))
            local dullCutterFactor = 1.0 + 0.15 * math.max(0.0, math.min(1.0, self.lastCutterDamage or 0))
            pHeader = headerHp * (0.20 + 0.80 * speedRatio) * dullCutterFactor
        end
    end

    -- Straw chopper power consumption (grain combines with straw residue)
    -- When swath (windrow) is ACTIVE, straw bypasses chopper -> 0 HP.
    -- When swath is INACTIVE, chopper blades shred straw and spread it across working width.
    -- Calibrated to agricultural engineering test standards (DLG / ASABE EP496): ~1.10 - 1.40 HP per (t/h grain).
    local isStrawChopperActive = false
    if machineType == "grain" and spec_combine then
        local hasChopper = false
        if spec_combine.chopper ~= nil and spec_combine.chopper.isAvailable == true then
            hasChopper = true
        elseif spec_combine.strawChopperNode ~= nil or spec_combine.strawChopperEffect ~= nil or spec_combine.strawChopperAnim ~= nil then
            hasChopper = true
        elseif spec_combine.strawEffects ~= nil and #spec_combine.strawEffects > 0 then
            hasChopper = true
        end

        if hasChopper and spec_combine.isSwathActive == false then
            isStrawChopperActive = true
        end

        if isStrawChopperActive then
            if isActivelyHarvesting then
                local chopperSpecHp = 1.25
                local cropUpper = (self.currentCrop and string.upper(self.currentCrop)) or ""
                if cropUpper:find("OAT") or cropUpper:find("RYE") then
                    chopperSpecHp = 1.40
                elseif cropUpper:find("CANOLA") or cropUpper:find("SOYBEAN") then
                    chopperSpecHp = 0.90
                elseif cropUpper:find("CORN") or cropUpper:find("MAIZE") then
                    chopperSpecHp = 0.0 -- Corn stalk residue handled by header shredder
                end
                pChopper = avgTph * chopperSpecHp * moistureFactor
            elseif isCutterActive then
                -- Idle aerodynamic drag and drive friction of high-speed chopper rotor (~2500-3500 RPM)
                pChopper = math.max(1.5, effectiveEngineHp * 0.015)
            end
        end
    end
    self.isStrawChopperActive = isStrawChopperActive
    self.lastPowerChopper = pChopper

    if isActivelyHarvesting then
        -- Crop processing power: Threshing/chopping/cleaning scaled by settings efficiency
        local eff = math.max(0.25, self.settingsEfficiency or 1.0)
        pProcess = (avgTph * eSpec * moistureFactor) / eff

        -- Forage harvester stage power decomposition (ASABE S497 / EP496):
        -- 1. Feed rolls (intake compression): ~18%
        -- 2. Chopping drum / cutterhead (shearing): ~62%
        -- 3. Discharge blower / accelerator (kinetic ejection): ~20%
        if machineType == "forage" or isForageCutter then
            pForageFeed = pProcess * 0.18
            pForageDrum = pProcess * 0.62
            pForageBlower = pProcess * 0.20

            -- Swath pickup mechanical bottleneck / choking detection:
            -- In heavy swaths, pickup auger & feed rolls have an intake capacity limit.
            -- When fresh mass exceeds nominal feed capacity, intake resistance rises sharply.
            if isPickup then
                local pickupIntakeLimitTph = math.max(320.0, (effectiveEngineHp * 0.45) + 80.0)
                if avgTph > pickupIntakeLimitTph then
                    local surgeRatio = (avgTph - pickupIntakeLimitTph) / pickupIntakeLimitTph
                    local feedChokePenalty = pForageFeed * math.min(1.5, surgeRatio * 2.0)
                    pForageFeed = pForageFeed + feedChokePenalty
                    pProcess = pProcess + feedChokePenalty
                end
            end
        end

        -- Root harvesters: subsurface share soil cutting resistance (ножі-лемеші під землею)
        -- Only for subterranean root crops (carrots, parsnips, potatoes, sugar beets, onions).
        -- Surface vegetables (green beans, peas, spinach) do not cut underground!
        local cropUpper = (self.currentCrop and string.upper(self.currentCrop)) or ""
        local fruitTypeIndex = vehicle.spec_combine and vehicle.spec_combine.lastValidInputFruitType
        if (not cropUpper or cropUpper == "" or cropUpper == "UNKNOWN") and fruitTypeIndex and fruitTypeIndex ~= 0 and g_fruitTypeManager then
            local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
            if fruitTypeDesc and fruitTypeDesc.name then
                cropUpper = string.upper(fruitTypeDesc.name)
            end
        end

        local isSurfaceCrop = (cropUpper:find("BEAN") or cropUpper:find("PEA") or cropUpper:find("SPINACH"))
        if machineType == "root" and not isSurfaceCrop then
            local width = 0
            if vehicle.getWorkingWidth then
                local w = vehicle:getWorkingWidth()
                if w and w > 0 then width = w end
            end
            if width == 0 and vehicle.spec_cutter and vehicle.spec_cutter.workingWidth then
                width = vehicle.spec_cutter.workingWidth
            elseif width == 0 and vehicle.spec_combine and vehicle.spec_combine.attachedCutters then
                for cutter, _ in pairs(vehicle.spec_combine.attachedCutters) do
                    if cutter.getWorkingWidth then
                        local w = cutter:getWorkingWidth()
                        if w and w > 0 then width = w break end
                    end
                    if cutter.spec_cutter and cutter.spec_cutter.workingWidth then
                        width = cutter.spec_cutter.workingWidth
                        break
                    end
                end
            end
            if width == 0 then width = 3.0 end
            pSoil = width * 7.0 -- ~7 HP per meter of cutting width in soil
        end
    end

    local pTotal = 0
    if isActivelyHarvesting then
        pTotal = pBase + pHeader + pProcess + pChopper + pSoil
    elseif isCutterActive then
        -- Running empty (cutter spinning, no crop intake)
        pTotal = pBase + (pHeader * 0.25) + pChopper
    else
        pTotal = 0
    end

    -- 7. RESULTING ENGINE LOAD
    local isArcade = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isArcade = (g_realisticHarvestManager.settings.difficultyMotor == 1)
    end

    if isArcade then
        -- EN: In Arcade mode, engine load is completely removed (0.0%).
        -- UA: В режимі Аркада навантаження двигуна повністю прибране (0.0%).
        self.engineLoad = 0.0
        return
    else
        local loadRatio = pTotal / math.max(1.0, effectiveEngineHp)

        -- Smooth engineLoad transitions
        if not isActivelyHarvesting and not isCutterActive then
            self.engineLoad = 0
        elseif self.engineLoad == 0 then
            self.engineLoad = math.min(0.60, loadRatio)
        else
            local loadSmoothing = 0.35
            self.engineLoad = (1 - loadSmoothing) * loadRatio + loadSmoothing * self.engineLoad
        end
    end

    -- Store diagnostic telemetry
    self.lastPowerEngine = effectiveEngineHp
    self.lastPowerBase = pBase
    self.lastPowerHeader = pHeader
    self.lastPowerProcess = pProcess
    self.lastPowerChopper = pChopper
    self.lastPowerForageFeed = pForageFeed
    self.lastPowerForageDrum = pForageDrum
    self.lastPowerForageBlower = pForageBlower
    self.lastPowerSoil = pSoil
    self.lastPowerTotal = pTotal
    self.lastEffectiveHp = effectiveEngineHp

    -- Dispatch overload event to external API listeners if engine load reaches overload threshold (>= 100%)
    if self.engineLoad >= 1.0 and RHM_Api and RHM_Api.dispatch then
        local now = g_currentMission and g_currentMission.time or 0
        if not self._lastOverloadDispatchTime or (now - self._lastOverloadDispatchTime) > 3000 then
            self._lastOverloadDispatchTime = now
            RHM_Api.dispatch("onOverload", vehicle, self.engineLoad * 100, self.speedLimit)
        end
    end
end

---EN: Calculates Vehicle Speed Limit based on physical power load and target load.
---UA: Розраховує обмеження швидкості на основі навантаження двигуна та цільового навантаження.
function RHM_LoadCalculator:calculateSpeedLimit(vehicle)
    -- EN: Never calculate harvesting speed limit if vehicle is reversing
    -- UA: Ніколи не розраховуємо ліміт швидкості якщо техніка рухається назад
    if vehicle and (
        (vehicle.getIsDrivingBackward and vehicle:getIsDrivingBackward()) or
        (vehicle.getDrivingDirection and vehicle:getDrivingDirection() < 0) or
        (vehicle.movingDirection and vehicle.movingDirection < 0)
    ) then
        return
    end

    local isArcade = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isArcade = (g_realisticHarvestManager.settings.difficultyMotor == 1)
    end
    if isArcade then
        self.speedLimit = math.huge
        return
    end

    -- EN: Reuse maxWorkingSpeed calculated in calculateEngineLoad to avoid duplicate hierarchy/XML scans.
    -- UA: Перевикористовуємо maxWorkingSpeed з calculateEngineLoad без повторного сканування ієрархії/XML.
    local maxWorkingSpeed = self.maxWorkingSpeed
    if not maxWorkingSpeed then
        local _, mws = self:getAttachedHeaderInfo(vehicle)
        maxWorkingSpeed = mws or 10.0
    end
    local maxAllowedSpeed = self.genuineSpeedLimit
    if maxAllowedSpeed and maxAllowedSpeed > 0 then
        maxAllowedSpeed = math.min(maxAllowedSpeed, maxWorkingSpeed)
    else
        maxAllowedSpeed = maxWorkingSpeed
    end

    local minSpeed = 3.5
    if (self.combineMemory and self.combineMemory.machineType == "forage") or self.isForageCutter then
        minSpeed = 2.5
    end

    local dtSec = math.min(1.0, math.max(0.05, (self.lastUpdateInterval or 300) / 1000.0))

    -- If not harvesting, smoothly maintain an intelligent approach/entry speed.
    -- This prevents the combine from charging into the standing crop at high speed and choking the cylinder!
    if (self.currentAvgMass or 0) <= 0.01 and (self.tonPerHour or 0) <= 0.05 then
        local activeCrop = self.currentCrop or (self.combineMemory and self.combineMemory.currentCrop)
        local canonical = activeCrop and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(activeCrop) or activeCrop
        local remembered = (activeCrop and self.cropHarvestingSpeeds and (self.cropHarvestingSpeeds[canonical] or self.cropHarvestingSpeeds[activeCrop])) or self.lastHarvestingSpeed
        if (not remembered or remembered < 5.5) and self.speedLimit and self.speedLimit > 5.5 then
            remembered = self.speedLimit
        end
        local defaultEntry = 5.5
        if self.vanillaWorkingSpeed and self.vanillaWorkingSpeed < defaultEntry then
            defaultEntry = self.vanillaWorkingSpeed
        end
        local target = remembered or defaultEntry
        target = math.max(minSpeed, math.min(maxAllowedSpeed, target))

        -- Smooth hydrostatic easing towards target entry speed (tau = 0.8s)
        local blend = 1.0 - math.exp(-dtSec / 0.8)
        self.speedLimit = self.speedLimit + (target - self.speedLimit) * blend
        self.underloadTimer = 0
        return
    end

    -- Target engine load from combine settings or default to 88%
    local targetLoad = 0.88
    if self.combineMemory and self.combineMemory.currentSettings and self.combineMemory.currentSettings.targetEngineLoad then
        targetLoad = self.combineMemory.currentSettings.targetEngineLoad / 100.0
    end

    -- Current vehicle physical speed (km/h)
    local currentSpeed = (vehicle.getLastSpeed and vehicle:getLastSpeed()) or self.speedLimit or 7.0
    currentSpeed = math.max(0.5, currentSpeed)

    -- Effective engine horsepower & target power capability
    local effectiveHp = self.lastEffectiveHp or self:getEnginePowerHp(vehicle)
    local targetPowerHp = effectiveHp * targetLoad

    -- Fixed zero-speed power (transmission mechanical losses + subsurface soil friction + header baseline)
    local pBase = self.lastPowerBase or (effectiveHp * 0.08)
    local pSoil = self.lastPowerSoil or 0
    local pHeaderFixed = (self.headerHp or headerHp or 0) * 0.20
    local pFixed = pBase + pSoil + pHeaderFixed

    -- Power available for speed-dependent work (header rotation + crop processing)
    local pVariable = targetPowerHp - pFixed

    local vEquilibrium = minSpeed
    if pVariable > 0 then
        -- Header dynamic slope: HP per (km/h)
        local kHeader = ((self.headerHp or headerHp or 0) * 0.80) / math.max(1.0, maxWorkingSpeed)

        -- Crop processing & straw chopper power slope: HP per (km/h)
        local pProcess = self.lastPowerProcess or 0
        local pChopper = self.lastPowerChopper or 0
        local kCrop = (pProcess + pChopper) / currentSpeed
        if kCrop < 0.1 then
            kCrop = 0.1
        end

        local kTotal = kHeader + kCrop
        vEquilibrium = pVariable / kTotal
    end

    -- Clamp analytical target within physical bounds
    vEquilibrium = math.max(minSpeed, math.min(maxAllowedSpeed, vEquilibrium))

    -- ASYMMETRIC DUAL-LOOP CONTROLLER:
    -- Check if we are in the initial entry phase of a new pass (< 2.8s)
    local isEntry = (self.harvestActiveTime or 0) < 2800
    local isSurge = not isEntry and (self.rawAvgMass or 0) > ((self.currentAvgMass or 0) * 1.15) and (self.rawAvgMass or 0) > 0.5
    if self.isPickup and not isEntry and (self.rawAvgMass or 0) > ((self.currentAvgMass or 0) * 1.10) and (self.rawAvgMass or 0) > 0.4 then
        isSurge = true
    end

    local currentLimit = self.speedLimit or maxAllowedSpeed

    if isEntry then
        -- GENTLE ROW ENTRY:
        -- While entering standing crop, the feederhouse and drum are still filling up (~2.5s - 3.0s).
        -- The measured engine load during this filling phase is artificially low.
        -- NEVER accelerate above the approach speed during entry!
        -- ONLY allow smooth braking if the crop is unexpectedly dense/heavy and starts overloading.
        self.underloadTimer = 0
        if vEquilibrium < (currentLimit - 0.15) then
            local blend = 1.0 - math.exp(-dtSec / 0.6)
            self.speedLimit = currentLimit + (vEquilibrium - currentLimit) * blend
        else
            -- Hold the remembered approach/average speed steady — no surging into crop!
        end
    elseif isSurge or vEquilibrium < (currentLimit - 0.1) then
        -- BRAKING / OVERLOAD / SURGE:
        -- Reset underload confirmation timer immediately
        self.underloadTimer = 0

        -- Fast, decisive, smooth transition to target equilibrium (tau = 0.45s)
        -- Decisively prevents engine choking without harsh jarring steps
        local blend = 1.0 - math.exp(-dtSec / 0.45)
        self.speedLimit = currentLimit + (vEquilibrium - currentLimit) * blend
    elseif vEquilibrium > (currentLimit + 0.15) then
        -- ACCELERATION / UNDERLOAD:
        -- Accumulate confirmed underload time
        local dtMs = self.lastUpdateInterval or 300
        self.underloadTimer = (self.underloadTimer or 0) + dtMs

        -- Confirmation window: only accelerate if light crop has been sustained for >= 1.5 seconds
        if self.underloadTimer >= 1500 then
            -- Smooth, dignified acceleration (tau = 1.8s)
            local blend = 1.0 - math.exp(-dtSec / 1.8)
            self.speedLimit = currentLimit + (vEquilibrium - currentLimit) * blend
        end
    else
        -- Stable deadzone within +/- 0.15 km/h: hold steady!
        self.underloadTimer = 0
    end

    -- Rolling average of steady-state harvesting speed:
    -- Samples whenever vehicle is actively harvesting with steady crop flow across all harvester types (grain, forage, root, cotton)
    local hasCropFlow = ((self.currentAvgMass or 0) > 0.02) or ((self.tonPerHour or 0) > 0.1)
    if self.isActivelyHarvesting and not isEntry and hasCropFlow then
        local actualSpeed = (vehicle.getLastSpeed and vehicle:getLastSpeed()) or currentSpeed
        if actualSpeed >= minSpeed and actualSpeed <= maxAllowedSpeed then
            local activeCrop = self.currentCrop or (self.combineMemory and self.combineMemory.currentCrop)
            if activeCrop then
                local canonical = RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(activeCrop) or activeCrop
                self.cropHarvestingSpeeds = self.cropHarvestingSpeeds or {}
                local prevAvg = self.cropHarvestingSpeeds[canonical] or self.cropHarvestingSpeeds[activeCrop] or self.lastHarvestingSpeed
                if not prevAvg or prevAvg < minSpeed then
                    self.cropHarvestingSpeeds[activeCrop] = actualSpeed
                else
                    -- Smooth exponential moving average across ~2.5s of steady harvesting
                    local blend = 1.0 - math.exp(-dtSec / 2.5)
                    self.cropHarvestingSpeeds[activeCrop] = prevAvg + (actualSpeed - prevAvg) * blend
                end
                if canonical then
                    self.cropHarvestingSpeeds[canonical] = self.cropHarvestingSpeeds[activeCrop]
                end
                self.lastHarvestingSpeed = self.cropHarvestingSpeeds[activeCrop]
            end
        end
    end

    -- Final physical clamp
    if maxAllowedSpeed and maxAllowedSpeed > 0 then
        self.speedLimit = math.max(minSpeed, math.min(maxAllowedSpeed, self.speedLimit))
    else
        self.speedLimit = math.max(minSpeed, self.speedLimit)
    end

    -- AI SPEED LIMITER: Automatically slow down hired AI workers when loss exceeds farm limit
    if vehicle and rhm_Combine and rhm_Combine.isAiWorkerActive and rhm_Combine.isAiWorkerActive(vehicle) then
        local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
        if tracker then
            local farmId = vehicle.getOwnerFarmId and vehicle:getOwnerFarmId() or 1
            local farm = tracker:getFarmData(farmId)
            if farm and farm.farmSettings and farm.farmSettings.aiSpeedLimiter then
                local maxAllowedLoss = farm.farmSettings.aiMaxLossPct or 2.0
                local currentLoss = self.cropLoss or 0
                if currentLoss > maxAllowedLoss then
                    local excess = currentLoss - maxAllowedLoss
                    local brakeFactor = math.max(0.55, 1.0 - (excess * 0.12))
                    self.speedLimit = math.max(minSpeed, self.speedLimit * brakeFactor)
                end
            end
        end
    end
end

---EN: Returns current engine load factor / UA: Повертає поточне навантаження двигуна
function RHM_LoadCalculator:getEngineLoad()
    local isArcade = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isArcade = (g_realisticHarvestManager.settings.difficultyMotor == 1)
    end
    if isArcade then
        return 0.0
    end
    return self.engineLoad * 100
end

---EN: Returns calculated speed limit target / UA: Повертає остаточний ліміт швидкості
function RHM_LoadCalculator:getSpeedLimit()
    local isArcade = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isArcade = (g_realisticHarvestManager.settings.difficultyMotor == 1)
    end
    if isArcade then
        return math.huge
    end
    return self.speedLimit or 0
end

---EN: Caches base limit speed boundary / UA: Встановлює оригінальні межі ліміту
function RHM_LoadCalculator:setGenuineSpeedLimit(limit, maxCap)
    -- EN: Cache vanilla speed boundaries for the hydrostatic controller.
    -- UA: Кешуємо межі ванільної швидкості для гідростатичного контролера.
    self.vanillaWorkingSpeed = limit
    self.genuineSpeedLimit = maxCap or limit

    local maxLimit = maxCap or limit
    local defaultEntry = math.min(5.5, maxLimit)

    -- EN: Do NOT overwrite speedLimit if there is already a valid (lower) remembered or starting value.
    --     This lets the hydrostatic controller ramp up smoothly to the genuine limit via exp-curve,
    --     giving both AI workers and players a natural field-entry acceleration.
    -- UA: НЕ перезаписуємо speedLimit якщо вже є дійсне (менше) запам'ятане або стартове значення.
    --     Це дозволяє гідростатичному контролеру плавно розігнатись до genuineSpeedLimit по exp-кривій,
    --     забезпечуючи і наймитам, і гравцям природній розгін при вході в загінку.
    local activeCrop = self.currentCrop or (self.combineMemory and self.combineMemory.currentCrop)
    local canonical = activeCrop and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(activeCrop) or activeCrop
    local remembered = (activeCrop and self.cropHarvestingSpeeds and (self.cropHarvestingSpeeds[canonical] or self.cropHarvestingSpeeds[activeCrop])) or self.lastHarvestingSpeed
    if (not remembered or remembered < 5.5) and self.speedLimit and self.speedLimit > 5.5 then
        remembered = self.speedLimit
    end

    if remembered and remembered > 0 then
        self.speedLimit = math.min(maxLimit, remembered)
    elseif not self.speedLimit or self.speedLimit <= 0 then
        self.speedLimit = defaultEntry
    elseif self.speedLimit > maxLimit then
        self.speedLimit = maxLimit
    end
end

---EN: Fully resets accumulated internal data variables / UA: Повністю очищує змінні бази даних
function RHM_LoadCalculator:reset()
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.currentAvgMass = 0
    self.engineLoad = 0
    self.cropLoss = 0
    self.cutterWearLoss = 0
    self.combineWearLoss = 0
    self.totalWearLoss = 0
    local activeCrop = self.currentCrop or (self.combineMemory and self.combineMemory.currentCrop)
    local canonical = activeCrop and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(activeCrop) or activeCrop
    local remembered = (activeCrop and self.cropHarvestingSpeeds and (self.cropHarvestingSpeeds[canonical] or self.cropHarvestingSpeeds[activeCrop])) or self.lastHarvestingSpeed

    -- EN: If speedLimit was cruising at working speed, preserve it so header lifts don't collapse to 5.5
    -- UA: Якщо speedLimit вже мав робочу швидкість, зберігаємо її щоб підйом жатки на розвороті не скидав до 5.5
    if (not remembered or remembered < 5.5) and self.speedLimit and self.speedLimit > 5.5 then
        remembered = self.speedLimit
        self.lastHarvestingSpeed = remembered
        if activeCrop then
            self.cropHarvestingSpeeds = self.cropHarvestingSpeeds or {}
            self.cropHarvestingSpeeds[activeCrop] = remembered
            if canonical then self.cropHarvestingSpeeds[canonical] = remembered end
        end
    end

    local defaultEntry = 5.5
    if self.vanillaWorkingSpeed and self.vanillaWorkingSpeed < defaultEntry then
        defaultEntry = self.vanillaWorkingSpeed
    end
    self.speedLimit = remembered or defaultEntry
    -- NOTE: self.lastHarvestingSpeed and self.cropHarvestingSpeeds are intentionally PRESERVED across headland turns!
    self.productivityMass = 0
    self.productivityLiters = 0
    self.productivityTime = 0
    self.tonPerHour = 0
    self.litersPerHour = 0
    self.hectaresPerHour = 0
    
    self.prodRingHead = 1
    self.prodSumMass = 0
    self.prodSumLiters = 0
    self.prodSumTime = 0
    self.prodSumArea = 0
    if self.prodRingMass then
        for i = 1, (self.prodRingSize or 180) do
            self.prodRingMass[i] = 0
            self.prodRingLiters[i] = 0
            self.prodRingTime[i] = 0
            self.prodRingArea[i] = 0
        end
    end

    self.yieldRingHead = 1
    self.yieldSumMass = 0
    self.yieldSumArea = 0
    if self.yieldRingMass then
        for i = 1, (self.yieldRingSize or 180) do
            self.yieldRingMass[i] = 0
            self.yieldRingArea[i] = 0
        end
    end
    
    self.currentYield = 0
    self.instantYield = 0
    self.harvestActiveTime = 0
    self.underloadTimer = 0
    self.idleHarvestTime = 0
    self.isStrawChopperActive = false
    self.lastPowerChopper = 0
    self.lastPowerForageFeed = 0
    self.lastPowerForageDrum = 0
    self.lastPowerForageBlower = 0
end

---EN: Calculates engine load based crop losses / UA: Розраховує втрати врожаю від перевантаження
function RHM_LoadCalculator:calculateCropLoss()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then return 0 end
    if not g_realisticHarvestManager.settings.enableCropLoss then return 0 end
    
    -- EN: Forage harvesters collect whole biomass with zero grain loss.
    -- UA: Кормозбиральні комбайни подрібнюють всю біомасу, втрати зерна відсутні.
    local machineType = (self.combineMemory and self.combineMemory.machineType) or ""
    if machineType == "forage" or self.isForageCutter then
        self.cropLoss = 0
        return 0
    end
    
    local lossMultiplier = g_realisticHarvestManager.settings:getLossMultiplier()
    
    -- EN: Losses start smoothly from 80% engine load
    -- UA: Втрати починаються плавно з 80% завантаження за стандартами ISO 8210 / DIN 11390
    if self.engineLoad > 0.80 then
        local overload = self.engineLoad - 0.80
        -- UA: Прогресивна крива втрат (ISO 8210 / DIN 11390): 
        -- При 80% (overload=0) -> 0% втрат
        -- При 88% (overload=0.08) -> ~0.29% (номінальна робоча зона комбайна)
        -- При 95% (overload=0.15) -> ~1.01% (стандартний 1% поріг втрат DLG/ISO 8210)
        -- При 100% (overload=0.20) -> ~1.80% (номінальна межа потужності)
        -- При 110% (overload=0.30) -> ~4.05% (перевантаження сепаратора)
        -- При >110% -> лавиноподібне зростання втрат через забивання решіт
        local rawLoss = (overload * overload) * 45
        
        -- UA: Різке зростання, якщо завантаження перевищило 110% (забита молотарка)
        if self.engineLoad > 1.10 then
            rawLoss = rawLoss + ((self.engineLoad - 1.10) * 120)
        end
        
        -- FIELD ENTRY LOSS DAMPENER:
        -- When entering crop from empty, feederhouse and cleaning sieves are physically filling up.
        -- Suppress overload losses during the initial transit window while flow stabilizes across sieves.
        local activeTime = self.harvestActiveTime or 0
        local entryGrace = 0
        if activeTime > 1200 then
            local t = math.min(1.0, (activeTime - 1200) / 1800.0)
            entryGrace = t * t * (3.0 - 2.0 * t) -- Smoothstep S-curve
        end
        rawLoss = rawLoss * entryGrace
        
        self.cropLoss = math.min(rawLoss * lossMultiplier, 50) 
    else
        self.cropLoss = 0
    end
    return self.cropLoss
end

---EN: Calculates losses from inaccurate player threshing settings / UA: Розраховує втрати від неправильних налаштувань гравцем
function RHM_LoadCalculator:updateSettingsImpact()
    self.settingsEfficiency = 1.0
    self.settingsLoss = 0

    local isArcadeMotor = false
    local isArcadeLoss = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isArcadeMotor = (g_realisticHarvestManager.settings.difficultyMotor == 1)
        isArcadeLoss = (g_realisticHarvestManager.settings.difficultyLoss == 1)
    end

    if isArcadeMotor and isArcadeLoss then
        -- EN: In full Arcade mode, 100% combine efficiency and 0% settings loss
        -- UA: В повному режимі Аркада 100% ефективність комбайну та 0% втрат від налаштувань
        return
    end

    if self.combineMemory and self.combineMemory.currentCrop then
        self.currentCrop = self.combineMemory.currentCrop
    end
    if not self.combineMemory or not self.currentCrop then return end
    local effPenalty, lossPenalty, _ = self.combineMemory:checkSettingsForCrop(self.currentCrop)
    
    if not isArcadeMotor then
        local penalty = math.max(0.0, effPenalty or 0)
        self.settingsEfficiency = math.max(0.25, 1.0 - (penalty / 100.0))
    end
    
    -- EN: Forage harvesters (silage choppers) produce no grain losses — all crop goes to tank/trailer.
    -- UA: Силосні комбайни не мають втрат зерна — весь врожай йде в бак/причеп.
    local machineType = self.combineMemory.machineType
    if machineType == "forage" or isArcadeLoss then
        self.settingsLoss = 0
    else
        self.settingsLoss = math.max(0.0, lossPenalty or 0)
    end
end

---EN: Calculates crop loss contribution from cutterbar and thresher mechanical wear
---UA: Розраховує додаткові втрати врожаю від механічного зносу жатки та молотарки
function RHM_LoadCalculator:calculateWearLoss(vehicle)
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return 0, 0, 0
    end
    -- Check if wear loss calculation is enabled
    if g_realisticHarvestManager.settings.enableWearLoss == false then
        self.cutterWearLoss = 0
        self.combineWearLoss = 0
        self.totalWearLoss = 0
        return 0, 0, 0
    end

    local cutterDamage = 0
    local combineDamage = 0

    if vehicle then
        if vehicle.getDamageAmount then
            combineDamage = vehicle:getDamageAmount() or 0
        end

        -- Find attached cutter damage
        local spec_combine = vehicle.spec_combine
        local spec_cutter = vehicle.spec_cutter
        if spec_combine and spec_combine.attachedCutters then
            for cutter, _ in pairs(spec_combine.attachedCutters) do
                if cutter and cutter.getDamageAmount then
                    cutterDamage = math.max(cutterDamage, cutter:getDamageAmount() or 0)
                end
            end
        end
        -- If combine itself has cutter spec (self-propelled mower/cutter)
        if spec_cutter and vehicle.getDamageAmount then
            cutterDamage = math.max(cutterDamage, vehicle:getDamageAmount() or 0)
        end
    end

    self.lastCutterDamage = cutterDamage
    self.lastCombineDamage = combineDamage

    -- 1. Cutter Wear Loss:
    -- Deadzone: first 15% wear produces 0 loss (normal blade sharpness)
    -- Scaling: remaining wear (0.15 .. 1.00) produces up to 3.0% loss (blunt knives shattering grain)
    local cutterLoss = 0
    if cutterDamage > 0.15 then
        local effCutterDmg = (cutterDamage - 0.15) / 0.85
        cutterLoss = math.min(3.0, effCutterDmg * 3.0)
    end

    -- 2. Combine Thresher Wear Loss:
    -- Deadzone: first 20% wear produces 0 loss
    -- Scaling: remaining wear (0.20 .. 1.00) produces up to 3.0% loss (worn rasp bars, sieves, concave)
    local combineLoss = 0
    if combineDamage > 0.20 then
        local effCombineDmg = (combineDamage - 0.20) / 0.80
        combineLoss = math.min(3.0, effCombineDmg * 3.0)
    end

    -- 3. Total Wear Loss (capped at 6.0%)
    local totalWear = math.min(6.0, cutterLoss + combineLoss)

    self.cutterWearLoss = cutterLoss
    self.combineWearLoss = combineLoss
    self.totalWearLoss = totalWear

    return totalWear, cutterLoss, combineLoss
end

function RHM_LoadCalculator:calculateTotalCropLoss(vehicle)
    -- EN: In Arcade Loss mode, strictly 0% total loss
    -- UA: В режимі втрат Аркада 0% загальних втрат
    if g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.difficultyLoss == 1 then
        self.cropLoss = 0
        self.cutterWearLoss = 0
        self.combineWearLoss = 0
        self.totalWearLoss = 0
        return 0
    end

    -- EN: Forage and Cotton harvesters never have crop loss — bypass all calculations.
    -- UA: Силосні та бавовняні комбайни ніколи не мають втрат врожаю — пропускаємо всі розрахунки.
    if self.combineMemory and (self.combineMemory.machineType == "forage" or self.combineMemory.machineType == "cotton") then
        self.cropLoss = 0
        self.cutterWearLoss = 0
        self.combineWearLoss = 0
        self.totalWearLoss = 0
        return 0
    end
    if self.combineMemory and self.combineMemory.currentCrop then
        self.currentCrop = self.combineMemory.currentCrop
    end
    if not self.settingsLoss then
        self:updateSettingsImpact()
    end
    local baseLoss = self:calculateCropLoss()
    local settingsAddedLoss = self.settingsLoss or 0
    local wearLoss = 0
    if vehicle then
        wearLoss = self:calculateWearLoss(vehicle)
    else
        wearLoss = self.totalWearLoss or 0
    end

    -- 4. Slope Loss: Lateral tilt causes grain pooling on one side of cleaning shoe sieves
    local slopeLoss = 0
    if vehicle and vehicle.rootNode then
        local _, upY, _ = localDirectionToWorld(vehicle.rootNode, 0, 1, 0)
        upY = math.min(1.0, math.max(-1.0, upY))
        local angleDeg = math.deg(math.acos(upY))
        if angleDeg > 4.0 then
            slopeLoss = math.min(5.0, (angleDeg - 4.0) * 0.35)
        end
    end

    -- 5. Moisture & Dew Loss: High moisture causes straw matting and walker/rotor grain adhesion
    local moistureLoss = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableMoisture ~= false then
        local currentMoisture = self.currentMoisture or 0
        if currentMoisture == 0 and vehicle and vehicle.spec_rhm_Combine and vehicle.spec_rhm_Combine.data then
            currentMoisture = vehicle.spec_rhm_Combine.data.moisture or 0
        end

        if currentMoisture > 14.0 then
            -- Standard safe threshold: 14% moisture
            -- For every 1% above 14%, separator losses increase by 0.35% due to wet straw matting
            local excessMoisture = currentMoisture - 14.0
            moistureLoss = math.min(8.0, excessMoisture * 0.35)
        end

        -- Extra wet weather penalty if actively raining
        if g_currentMission and g_currentMission.environment and g_currentMission.environment.weather then
            if g_currentMission.environment.weather:getIsRaining() then
                moistureLoss = math.min(10.0, moistureLoss + 1.8)
            end
        end
    end

    self.baseLoss = baseLoss
    self.settingsAddedLoss = settingsAddedLoss
    self.wearLoss = wearLoss
    self.slopeLoss = slopeLoss
    self.moistureLoss = moistureLoss

    local totalLoss = baseLoss + settingsAddedLoss + wearLoss + slopeLoss + moistureLoss
    totalLoss = math.min(totalLoss, 50)
    self.cropLoss = totalLoss
    return totalLoss
end

---EN: Returns instantaneous breakdown of loss causes in percentage
---UA: Повертає моментальний розподіл причин втрат у відсотках
function RHM_LoadCalculator:getLossBreakdown()
    -- EN: Combine speed overload and improper concave/settings under thresher overload
    --     so all 4 UI scorecard categories are accurately represented.
    local thresherLoss = (self.baseLoss or 0) + (self.settingsAddedLoss or 0)
    return {
        speedPct = thresherLoss,
        moisturePct = self.moistureLoss or 0,
        wearPct = self.wearLoss or 0,
        slopePct = self.slopeLoss or 0
    }
end

---EN: Returns instantaneous processed metric tonnes per clock hour / UA: Перерахунок в тонни на годину
function RHM_LoadCalculator:getTonPerHour()
    return self.tonPerHour
end

---EN: Returns yield in L/h / UA: Розрахунок літрів на годину
function RHM_LoadCalculator:getLitersPerHour()
    return self.litersPerHour or 0
end

---EN: Returns calculated area rate in hectares per hour / UA: Повертає продуктивність у гектарах на годину
function RHM_LoadCalculator:getHectaresPerHour()
    return self.hectaresPerHour or 0
end

---EN: Updates sliding window rolling averages for metric evaluations (O(1) circular ring buffer)
---UA: Оновлює ковзні середні продуктивності (O(1) кільцевий буфер без виділення пам'яті)
function RHM_LoadCalculator:updateProductivity(mass, liters, dt, area)
    self.totalOutputMass = self.totalOutputMass + (mass or 0)
    
    if not self.prodRingMass then
        self.prodRingSize = 180
        self.prodRingMass = {}
        self.prodRingLiters = {}
        self.prodRingTime = {}
        self.prodRingArea = {}
        for i = 1, self.prodRingSize do
            self.prodRingMass[i] = 0
            self.prodRingLiters[i] = 0
            self.prodRingTime[i] = 0
            self.prodRingArea[i] = 0
        end
        self.prodRingHead = 1
        self.prodSumMass = 0
        self.prodSumLiters = 0
        self.prodSumTime = 0
        self.prodSumArea = 0
    end

    local head = self.prodRingHead
    local oldM = self.prodRingMass[head]
    local oldL = self.prodRingLiters[head]
    local oldT = self.prodRingTime[head]
    local oldA = self.prodRingArea[head]

    local m = mass or 0
    local l = liters or 0
    local t = dt or 0
    local a = area or 0

    self.prodSumMass = math.max(0, self.prodSumMass - oldM + m)
    self.prodSumLiters = math.max(0, self.prodSumLiters - oldL + l)
    self.prodSumTime = math.max(0, self.prodSumTime - oldT + t)
    self.prodSumArea = math.max(0, self.prodSumArea - oldA + a)

    self.prodRingMass[head] = m
    self.prodRingLiters[head] = l
    self.prodRingTime[head] = t
    self.prodRingArea[head] = a

    self.prodRingHead = (head % self.prodRingSize) + 1

    if self.prodSumTime > 100 then
        local hours = self.prodSumTime / 3600000
        local rawTonPerHour = (self.prodSumMass / 1000) / hours
        self.litersPerHour = self.prodSumLiters / hours
        local rawHectaresPerHour = (self.prodSumArea / 10000) / hours
        local alpha = 0.05
        if self.tonPerHour == 0 then self.tonPerHour = rawTonPerHour end
        self.tonPerHour = self.tonPerHour * (1 - alpha) + rawTonPerHour * alpha

        if self.hectaresPerHour == 0 then self.hectaresPerHour = rawHectaresPerHour end
        self.hectaresPerHour = self.hectaresPerHour * (1 - alpha) + rawHectaresPerHour * alpha
    else
        self.tonPerHour = 0
        self.litersPerHour = 0
        self.hectaresPerHour = 0
    end
end

---EN: Processes complete physical output block calculations (O(1) running sum, zero GC allocations)
---UA: Виконує розрахунки врожайності (O(1) ковзна сума, нуль алокацій у GC)
function RHM_LoadCalculator:updateProductivityAndYield(mass, liters, area, dt)
    self:updateProductivity(mass, liters, dt, area)
    if (area or 0) <= 0.0001 and (mass or 0) <= 0.001 then
        self.currentYield = self.currentYield or 0
        return
    end
    
    if not self.yieldRingMass then
        self.yieldRingSize = 180
        self.yieldRingMass = {}
        self.yieldRingArea = {}
        for i = 1, self.yieldRingSize do
            self.yieldRingMass[i] = 0
            self.yieldRingArea[i] = 0
        end
        self.yieldRingHead = 1
        self.yieldSumMass = 0
        self.yieldSumArea = 0
    end

    local head = self.yieldRingHead
    local oldM = self.yieldRingMass[head]
    local oldA = self.yieldRingArea[head]

    local m = mass or 0
    local a = area or 0

    self.yieldSumMass = math.max(0, self.yieldSumMass - oldM + m)
    self.yieldSumArea = math.max(0, self.yieldSumArea - oldA + a)

    self.yieldRingMass[head] = m
    self.yieldRingArea[head] = a

    self.yieldRingHead = (head % self.yieldRingSize) + 1

    if self.yieldSumArea > 0.1 then
        local rawYield = (self.yieldSumMass / self.yieldSumArea) * 10
        local alpha = 0.03
        if not self.currentYield or self.currentYield == 0 then self.currentYield = rawYield end
        self.currentYield = self.currentYield * (1 - alpha) + rawYield * alpha
    end
end

function RHM_LoadCalculator:setRealTimeYield(yieldTha)
    self.currentYield = yieldTha or 0
end

---EN: Returns formatted yield string / UA: Отримує форматований рядок врожайності
function RHM_LoadCalculator:getYieldText(unitSystem)
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


