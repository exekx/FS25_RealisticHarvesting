-- ============================================================================
-- RHM_Api.lua
-- Realistic Harvesting Mod - Official Public Integration API (FS25)
-- ============================================================================
-- EN: Dedicated, zero-friction public API providing third-party integration
--     (telemetry dashboards, auxiliary wear systems, automated drivers, in-cab displays)
--     direct, read-only access to combine telemetry, load models, moisture,
--     settings, and hardware tiers.
-- UA: Офіційний публічний API для легкої інтеграції сторонніх скриптів
--     (телеметрія, системи зносу, автопілоти, кастомні дисплеї).
--     Надає безпечний доступ тільки для читання (read-only) до телеметрії,
--     навантаження двигуна, вологості, налаштувань та рівнів електроніки.
-- ============================================================================

RHM_Api = {}
RHM_Api.VERSION = "1.6.3.0"
RHM_Api.listeners = {}

-- ============================================================================
-- 1. VEHICLE RESOLUTION & HIERARCHY TRAVERSAL
-- ============================================================================

---EN: Recursively resolves a combine harvester instance from any passed vehicle,
---    tractor (with trailed root crop harvester), or attached implement.
---    Falls back to current controlled vehicle if vehicle is nil.
---UA: Безпечно знаходить екземпляр комбайна з будь-якого переданого транспорту,
---    трактора (з причіпним комбайном) або жатки. Якщо nil — бере керовану техніку.
---@param vehicle table|nil
---@return table|nil combineVehicle
function RHM_Api.findCombine(vehicle)
    local target = vehicle
    if target == nil and g_currentMission ~= nil then
        target = g_currentMission.controlledVehicle
    end
    if target == nil then
        return nil
    end

    -- Fast-path: target itself is an RHM combine or harvester
    if target.spec_rhm_Combine ~= nil or target.spec_combine ~= nil or target.spec_forageHarvester ~= nil or target.spec_cottonHarvester ~= nil or target.spec_sugarCaneHarvester ~= nil then
        return target
    end

    -- Check root vehicle
    if target.rootVehicle ~= nil and target.rootVehicle ~= target and (target.rootVehicle.spec_rhm_Combine ~= nil or target.rootVehicle.spec_combine ~= nil or target.rootVehicle.spec_forageHarvester ~= nil or target.rootVehicle.spec_cottonHarvester ~= nil or target.rootVehicle.spec_sugarCaneHarvester ~= nil) then
        return target.rootVehicle
    end

    -- Helper for recursive depth search
    local visited = {}
    local function searchNode(node)
        if node == nil or visited[node] then
            return nil
        end
        visited[node] = true

        if node.spec_rhm_Combine ~= nil or node.spec_combine ~= nil or node.spec_forageHarvester ~= nil or node.spec_cottonHarvester ~= nil or node.spec_sugarCaneHarvester ~= nil then
            return node
        end

        -- Check implements attached to this vehicle
        if node.getAttachedImplements ~= nil then
            local implements = node:getAttachedImplements()
            if implements ~= nil then
                for _, implement in ipairs(implements) do
                    local found = searchNode(implement.object)
                    if found ~= nil then
                        return found
                    end
                end
            end
        end

        -- Check attacher vehicle (up the chain)
        if node.attacherVehicle ~= nil then
            local found = searchNode(node.attacherVehicle)
            if found ~= nil then
                return found
            end
        end

        return nil
    end

    return searchNode(target)
end

-- ============================================================================
-- 2. STATUS & HARDWARE IDENTIFICATION
-- ============================================================================

---EN: Returns true if the target vehicle is a functional combine managed by RHM.
---UA: Повертає true, якщо транспорт є активним комбайном під керуванням RHM.
---@param vehicle table|nil
---@return boolean
function RHM_Api.isRHMActive(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    return combine ~= nil and combine.spec_rhm_Combine ~= nil
end

---EN: Returns the active version string of Realistic Harvesting mod.
---UA: Повертає версію Realistic Harvesting.
---@return string
function RHM_Api.getVersion()
    return RHM_Api.VERSION
end

---EN: Returns the machine harvester category: "grain", "forage", "root", "cotton", "grape", "olive", or "unknown".
---UA: Повертає категорію комбайна: "grain", "forage", "root", "cotton", "grape", "olive" або "unknown".
---@param vehicle table|nil
---@return string|nil machineType ("grain", "forage", "root", "cotton", "grape", "olive") or nil if unmanaged
function RHM_Api.getMachineType(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.combineMemory then
        return combine.spec_rhm_Combine.combineMemory.machineType or "grain"
    end
    return nil
end

---EN: Returns true if target combine is a specialized grape harvester.
---UA: Повертає true, якщо комбайн є виноградозбиральним.
---@param vehicle table|nil
---@return boolean|nil
function RHM_Api.isGrapeHarvester(vehicle)
    local mType = RHM_Api.getMachineType(vehicle)
    if mType == nil then return nil end
    return mType == "grape"
end

---EN: Returns true if target combine is a specialized olive harvester.
---UA: Повертає true, якщо комбайн є оливкозбиральним.
---@param vehicle table|nil
---@return boolean|nil
function RHM_Api.isOliveHarvester(vehicle)
    local mType = RHM_Api.getMachineType(vehicle)
    if mType == nil then return nil end
    return mType == "olive"
end

---EN: Returns the installed electronic package level (1..4):
---    1: Mechanical, 2: Sensors, 3: Opti-Clean, 4: Opti-Harvest AI.
---UA: Повертає встановлений пакет електроніки (1..4).
---@param vehicle table|nil
---@return integer|nil packageLevel (1..4) or nil if unmanaged
function RHM_Api.getPackageLevel(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine then
        return combine.spec_rhm_Combine.packageLevel or 1
    end
    return nil
end

-- ============================================================================
-- 3. ENGINE LOAD & POWER BREAKDOWN (FOR WEAR & TELEMETRY)
-- ============================================================================

---EN: Returns real physical engine load percentage (0.0 to 150.0+ %).
---    Reflects true mechanical resistance and cylinder power demand.
---    Returns nil if the vehicle is not an RHM-managed combine harvester.
---UA: Повертає реальне фізичне навантаження (0.0 .. 150.0+ %).
---@param vehicle table|nil
---@return number|nil engineLoadPct or nil if unmanaged
function RHM_Api.getEngineLoad(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator:getEngineLoad() or 0.0
    end
    return nil
end

---EN: Returns normalized engine load factor strictly clamped between 0.0 and 1.0.
---    Essential for external damage, telemetry, and wear monitoring systems
---    that expect standard GIANTS 0.0..1.0 load domain.
---    Returns nil if the vehicle is not managed by RHM.
---UA: Повертає нормалізоване навантаження суворо від 0.0 до 1.0 (0% .. 100%).
---@param vehicle table|nil
---@return number|nil normalizedLoad (0.0 .. 1.0) or nil if unmanaged
function RHM_Api.getNormalizedEngineLoad(vehicle)
    local raw = RHM_Api.getEngineLoad(vehicle)
    if raw == nil then return nil end
    return math.max(0.0, math.min(1.0, raw / 100.0))
end

---EN: Returns user-configured target engine load percentage (e.g., 80%).
---UA: Повертає задане цільове навантаження у відсотках.
---@param vehicle table|nil
---@return number|nil targetLoadPct or nil if unmanaged
function RHM_Api.getTargetEngineLoad(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.combineMemory then
        local mem = combine.spec_rhm_Combine.combineMemory
        if mem.currentSettings and mem.currentSettings.targetEngineLoad then
            return mem.currentSettings.targetEngineLoad
        end
    end
    return nil
end

---EN: Returns physical power distribution table in Horsepower (HP):
---    { pTotal, effectiveHp, pBase, pHeader, pProcess, pSoil }.
---UA: Повертає розкладку потужностей у кінських силах (к.с.):
---    { pTotal, effectiveHp, pBase, pHeader, pProcess, pChopper, pSoil }.
---@param vehicle table|nil
---@return table|nil
function RHM_Api.getPowerBreakdown(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        local calc = combine.spec_rhm_Combine.loadCalculator
        return {
            pTotal      = calc.lastPowerTotal or 0.0,
            effectiveHp = calc.lastEffectiveHp or calc.lastPowerEngine or 0.0,
            pBase       = calc.lastPowerBase or 0.0,
            pHeader     = calc.lastPowerHeader or 0.0,
            pProcess    = calc.lastPowerProcess or 0.0,
            pChopper    = calc.lastPowerChopper or 0.0,
            pSoil       = calc.lastPowerSoil or 0.0
        }
    end
    return nil
end

---EN: Returns true if straw chopper is actively engaging and shredding crop residue.
---UA: Повертає true, якщо подрібнювач соломи активно подрібнює та розкидає солому.
---@param vehicle table|nil
---@return boolean|nil
function RHM_Api.isStrawChopperActive(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.isStrawChopperActive or false
    end
    return nil
end

---EN: Returns instantaneous straw chopper power consumption in horsepower (HP).
---UA: Повертає поточну потужність подрібнювача соломи в кінських силах (к.с.).
---@param vehicle table|nil
---@return number|nil chopperHp or nil if unmanaged
function RHM_Api.getChopperPowerHp(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.lastPowerChopper or 0.0
    end
    return nil
end

---EN: Returns true if the vehicle is a self-propelled or trailed forage harvester (silage chopper).
---UA: Повертає true, якщо транспортний засіб є кормозбиральним комбайном (силосорізкою).
---@param vehicle table|nil
---@return boolean|nil
function RHM_Api.isForageHarvester(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine then
        local spec = combine.spec_rhm_Combine
        local mType = (spec.combineMemory and spec.combineMemory.machineType) or spec.machineType or ""
        return mType == "forage"
    end
    return nil
end

---EN: Returns true if the attached harvesting tool is a grass/swath pickup header.
---UA: Повертає true, якщо підключене робоче знаряддя є підбирачем валків з землі.
---@param vehicle table|nil
---@return boolean|nil
function RHM_Api.isPickupActive(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.isPickup or false
    end
    return nil
end

---EN: Returns internal power distribution table for forage harvester stages in Horsepower (HP):
---    { feedPower, drumPower, blowerPower, totalProcessPower }.
---UA: Повертає розкладку потужностей механічних вузлів кормозбирального комбайна (к.с.):
---    { feedPower, drumPower, blowerPower, totalProcessPower }.
---@param vehicle table|nil
---@return table|nil
function RHM_Api.getForagePowerBreakdown(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        local calc = combine.spec_rhm_Combine.loadCalculator
        return {
            feedPower         = calc.lastPowerForageFeed or 0.0,
            drumPower         = calc.lastPowerForageDrum or 0.0,
            blowerPower       = calc.lastPowerForageBlower or 0.0,
            totalProcessPower = calc.lastPowerProcess or 0.0
        }
    end
    return nil
end

---EN: Returns instantaneous harvested fresh matter throughput in metric tonnes per hour (t/h).
---UA: Повертає поточну продуктивність збирання свіжої маси в тоннах за годину (т/год).
---@param vehicle table|nil
---@return number|nil freshMatterTph or nil if unmanaged
function RHM_Api.getFreshMatterThroughput(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator:getTonPerHour() or 0.0
    end
    return nil
end

---EN: Returns rated engine horsepower (HP) of the combine or motorized carrier (e.g. NEXAT).
---UA: Повертає номінальну потужність двигуна (к.с.) комбайна або тягача (наприклад, NEXAT).
---@param vehicle table|nil
---@return number|nil engineHp or nil if unmanaged
function RHM_Api.getEnginePowerHp(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator:getEnginePowerHp(combine) or 0.0
    end
    return nil
end

-- ============================================================================
-- 4. HARVESTING STATE & SPEED CONTROLLER
-- ============================================================================

---EN: Returns true if there is an active flow of crop biomass entering the thresher.
---UA: Повертає true, якщо через молотарку зараз іде активний потік культури.
---@param vehicle table|nil
---@return boolean|nil
function RHM_Api.isActivelyHarvesting(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.isActivelyHarvesting or false
    end
    return nil
end

---EN: Returns true if attached header/cutter is turned on and lowered in working position.
---UA: Повертає true, якщо жатка увімкнена та опущена в робоче положення.
---@param vehicle table|nil
---@return boolean|nil
function RHM_Api.isCutterActive(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.isCutterActive or false
    end
    return nil
end

---EN: Returns dynamic RHM recommended speed limit (km/h) computed by hydrostatic controller.
---UA: Повертає динамічний рекомендований ліміт швидкості (км/год).
---@param vehicle table|nil
---@return number|nil speedKmh or nil if unmanaged
function RHM_Api.getRecommendedSpeed(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator:getSpeedLimit() or 0.0
    end
    return nil
end

---EN: Returns header working width in meters.
---UA: Повертає робочу ширину жатки в метрах.
---@param vehicle table|nil
---@return number|nil widthMeters or nil if unmanaged
function RHM_Api.getWorkingWidth(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if not combine or not combine.spec_rhm_Combine then
        return nil
    end

    local function resolveObjWidth(obj)
        if not obj then return 0 end
        local w = 0
        if obj.getWorkingWidth then
            local raw = obj:getWorkingWidth()
            if raw and tonumber(raw) and tonumber(raw) > 0 then
                w = tonumber(raw)
            end
        end
        if w == 0 and obj.spec_cutter and obj.spec_cutter.workingWidth then
            local raw = obj.spec_cutter.workingWidth
            if raw and tonumber(raw) and tonumber(raw) > 0 then
                w = tonumber(raw)
            end
        end
        if w == 0 and obj.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
            local item = g_storeManager:getItemByXMLFilename(obj.configFileName)
            if item and item.specs and item.specs.workingWidth then
                local rawW = tostring(item.specs.workingWidth)
                local parsed = tonumber(string.match(rawW, "%d+%.?%d*"))
                if parsed and parsed > 0 then
                    w = parsed
                end
            end
        end
        if w == 0 and obj.xmlFile and obj.xmlFile.getValue then
            local rawW = obj.xmlFile:getValue("vehicle.storeData.specs.workingWidth")
            if rawW then
                local parsed = tonumber(string.match(tostring(rawW), "%d+%.?%d*"))
                if parsed and parsed > 0 then
                    w = parsed
                end
            end
        end
        if w == 0 and obj.spec_workArea and obj.spec_workArea.workAreas and MathUtil and getWorldTranslation then
            for _, wa in pairs(obj.spec_workArea.workAreas) do
                if wa.start and wa.width then
                    local sx, _, sz = getWorldTranslation(wa.start)
                    local wx, _, wz = getWorldTranslation(wa.width)
                    local areaWidth = MathUtil.vector2Length(wx - sx, wz - sz)
                    if areaWidth > w then w = areaWidth end
                end
            end
        end
        return w
    end

    local bestWidth = 0
    if combine.spec_combine and combine.spec_combine.attachedCutters then
        for cutter, _ in pairs(combine.spec_combine.attachedCutters) do
            local cw = resolveObjWidth(cutter)
            if cw > bestWidth then bestWidth = cw end
        end
    end
    if bestWidth == 0 and combine.getAttachedImplements then
        for _, imp in pairs(combine:getAttachedImplements()) do
            local obj = imp.object
            if obj then
                local cw = resolveObjWidth(obj)
                if cw > bestWidth then bestWidth = cw end
            end
        end
    end
    if bestWidth == 0 then
        bestWidth = resolveObjWidth(combine)
    end
    return bestWidth > 0 and bestWidth or 0.0
end

-- ============================================================================
-- 5. TELEMETRY, THROUGHPUT & YIELD
-- ============================================================================

---EN: Returns instantaneous processed throughput in metric tonnes per hour (t/h).
---UA: Повертає поточну продуктивність комбайна в тоннах за годину (т/год).
---@param vehicle table|nil
---@return number|nil tonPerHour or nil if unmanaged
function RHM_Api.getTonPerHour(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        local currentSpeed = (combine.getLastSpeed and combine:getLastSpeed()) or 0
        if currentSpeed < 0.5 then
            return 0.0
        end
        return combine.spec_rhm_Combine.loadCalculator:getTonPerHour() or 0.0
    end
    return nil
end

---EN: Returns instantaneous mass flow rate in active or specified unit system (kg/s, lbs/s, or bu/min).
---UA: Повертає миттєвий потік маси у вказаній або активній системі одиниць (кг/с, фунт/с або буш/хв).
---@param vehicle table|nil
---@param system number|nil Optional unit system (1=Metric, 2=Imperial, 3=Bushels)
---@return number|nil flowRate or nil if unmanaged
---@return string|nil unitSuffix or nil if unmanaged
function RHM_Api.getFlowRate(vehicle, system)
    local tph = RHM_Api.getTonPerHour(vehicle)
    if tph ~= nil and RHM_UnitConverter and RHM_UnitConverter.convertFlowRate then
        local combine = RHM_Api.findCombine(vehicle)
        local fruitType = combine and combine.spec_combine and combine.spec_combine.lastValidInputFruitType
        local lph = RHM_Api.getLitersPerHour(vehicle) or 0
        return RHM_UnitConverter.convertFlowRate(tph, system, fruitType, lph)
    end
    return nil, nil
end

---EN: Returns instantaneous processed throughput in liters per hour (L/h).
---UA: Повертає об'ємну продуктивність у літрах за годину (л/год).
---@param vehicle table|nil
---@return number|nil litersPerHour or nil if unmanaged
function RHM_Api.getLitersPerHour(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        local currentSpeed = (combine.getLastSpeed and combine:getLastSpeed()) or 0
        if currentSpeed < 0.5 then
            return 0.0
        end
        return combine.spec_rhm_Combine.loadCalculator:getLitersPerHour() or 0.0
    end
    return nil
end

---EN: Returns harvested area productivity rate in hectares per hour (ha/h).
---UA: Повертає продуктивність обробки площі в гектарах за годину (га/год).
---@param vehicle table|nil
---@return number|nil hectaresPerHour or nil if unmanaged
function RHM_Api.getHectaresPerHour(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        local currentSpeed = (combine.getLastSpeed and combine:getLastSpeed()) or 0
        if currentSpeed < 0.5 then
            return 0.0
        end
        return combine.spec_rhm_Combine.loadCalculator:getHectaresPerHour() or 0.0
    end
    return nil
end

---EN: Returns rolling field yield monitor in metric tonnes per hectare (t/ha).
---UA: Повертає середню врожайність поля в тоннах на гектар (т/га).
---@param vehicle table|nil
---@return number|nil yieldTonPerHa or nil if unmanaged
function RHM_Api.getYield(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.currentYield or 0.0
    end
    return nil
end

---EN: Returns last valid non-zero field yield in metric tonnes per hectare (t/ha).
---UA: Повертає останню валідну ненульову врожайність поля в тоннах на гектар (т/га).
---@param vehicle table|nil
---@return number|nil lastValidYield or nil if unmanaged
function RHM_Api.getLastValidYield(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.lastValidYield or 0.0
    end
    return nil
end

---EN: Returns total accumulated harvested mass for this session in kilograms (kg).
---UA: Повертає загальну накопичену зібрану масу за сесію в кілограмах (кг).
---@param vehicle table|nil
---@return number|nil massKg or nil if unmanaged
function RHM_Api.getTotalHarvestedMass(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.totalOutputMass or 0.0
    end
    return nil
end

---EN: Returns full synced telemetry data table (load, moisture, cropLoss, tonPerHour, yield, etc.).
---UA: Повертає повну синхронізовану таблицю живої телеметрії.
---@param vehicle table|nil
---@return table|nil
function RHM_Api.getTelemetry(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine then
        return combine.spec_rhm_Combine.data
    end
    return nil
end

-- ============================================================================
-- 6. CROP & MOISTURE SYSTEM
-- ============================================================================

---EN: Returns active crop name (e.g. "WHEAT", "BARLEY", "CORN").
---UA: Повертає назву поточної культури (наприклад, "WHEAT", "CORN").
---@param vehicle table|nil
---@return string|nil
function RHM_Api.getCurrentCrop(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.combineMemory then
        return combine.spec_rhm_Combine.combineMemory.currentCrop
    end
    return nil
end

---EN: Returns live moisture percentage of standing crop (0.0 to 100.0 %).
---UA: Повертає поточну вологість культури (%).
---@param vehicle table|nil
---@return number|nil moisturePct or nil if unmanaged
function RHM_Api.getMoisture(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.data then
        local m = combine.spec_rhm_Combine.data.moisture or 0.0
        if m <= 0.0 and RHM_MoistureAdapter and RHM_MoistureAdapter.getStandingCropMoisture then
            local fillType = combine.spec_rhm_Combine.lastFillType or (combine.spec_rhm_Combine.combineMemory and combine.spec_rhm_Combine.combineMemory.currentCrop)
            m = RHM_MoistureAdapter.getStandingCropMoisture(combine, fillType) or 0.0
        end
        return m
    end
    return nil
end

---EN: Returns upper moisture limit (%) before drying penalty applies for this crop.
---UA: Повертає гранично допустиму вологість культури (%).
---@param vehicle table|nil
---@return number|nil limitPct or nil if unmanaged or no active crop
function RHM_Api.getMoistureLimit(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if not combine or not combine.spec_rhm_Combine then
        return nil
    end
    local crop = RHM_Api.getCurrentCrop(combine)
    if crop and crop ~= "" and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getSettingsForCrop then
        local settings = RHM_CombineSettingsDatabase:getSettingsForCrop(crop)
        if settings and settings.moistureLimit then
            return settings.moistureLimit
        end
    end
    return nil
end

---EN: Returns true if current moisture exceeds acceptable threshing threshold.
---UA: Повертає true, якщо вологість перевищує норму.
---@param vehicle table|nil
---@return boolean|nil
function RHM_Api.isMoistureExceeded(vehicle)
    local m = RHM_Api.getMoisture(vehicle)
    local lim = RHM_Api.getMoistureLimit(vehicle)
    if m == nil or lim == nil then return nil end
    return m > lim
end

---EN: Returns current live weed infestation ratio at cutterbar (0.00 to 1.00).
---UA: Повертає поточний рівень забур'яненості на жатці (від 0.00 до 1.00).
---@param vehicle table|nil
---@return number|nil weedRatio or nil if unmanaged
function RHM_Api.getWeedRatio(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.data then
        return combine.spec_rhm_Combine.data.weedRatio or 0.0
    end
    return nil
end

-- ============================================================================
-- 7. CROP LOSSES
-- ============================================================================

---EN: Returns total crop loss percentage (0.0 to 50.0 %).
---UA: Повертає загальний відсоток втрат врожаю (0.0 .. 50.0 %).
---@param vehicle table|nil
---@return number|nil totalLossPct or nil if unmanaged
function RHM_Api.getTotalCropLoss(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.data then
        return combine.spec_rhm_Combine.data.cropLoss or 0.0
    end
    return nil
end

---EN: Returns crop loss percentage caused purely by engine & thresher overload.
---UA: Повертає втрати від фізичного перевантаження молотарки (%).
---@param vehicle table|nil
---@return number|nil overloadLossPct or nil if unmanaged
function RHM_Api.getOverloadLoss(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.cropLoss or 0.0
    end
    return nil
end

---EN: Returns crop loss percentage caused by misaligned operator threshing settings.
---UA: Повертає втрати від неточних налаштувань обмолоту (%).
---@param vehicle table|nil
---@return number|nil settingsLossPct or nil if unmanaged
function RHM_Api.getSettingsLoss(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.settingsLoss or 0.0
    end
    return nil
end

---EN: Returns mechanical wear crop loss breakdown: totalWearLoss (%), cutterWearLoss (%), combineWearLoss (%).
---UA: Повертає втрати від механічного зносу: загальні (%), від жатки (%), від молотарки (%).
---@param vehicle table|nil
---@return number|nil totalWearLoss, number|nil cutterWearLoss, number|nil combineWearLoss
function RHM_Api.getWearLoss(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        local calc = combine.spec_rhm_Combine.loadCalculator
        return calc.totalWearLoss or 0.0, calc.cutterWearLoss or 0.0, calc.combineWearLoss or 0.0
    end
    return nil, nil, nil
end

---EN: Returns instantaneous slope-induced crop loss percentage (%).
---UA: Повертає моментальні втрати від нахилу комбайна (%).
---@param vehicle table|nil
---@return number|nil slopeLossPct or nil if unmanaged
function RHM_Api.getSlopeLoss(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.slopeLoss or 0.0
    end
    return nil
end

---EN: Returns attached cutter mechanical damage amount (0.0 to 1.0).
---UA: Повертає рівень механічного зносу приєднаної жатки (0.0 .. 1.0).
---@param vehicle table|nil
---@return number|nil cutterDamage or nil if unmanaged
function RHM_Api.getCutterDamage(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.lastCutterDamage or 0.0
    end
    return nil
end

---EN: Returns combine harvester base chassis/thresher damage amount (0.0 to 1.0).
---UA: Повертає рівень механічного зносу самого комбайна/молотарки (0.0 .. 1.0).
---@param vehicle table|nil
---@return number|nil combineDamage or nil if unmanaged
function RHM_Api.getCombineDamage(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.lastCombineDamage or 0.0
    end
    if combine and combine.getDamageAmount then
        return combine:getDamageAmount() or 0.0
    end
    return nil
end

-- ============================================================================
-- 8. THRESHING SETTINGS & PRESETS
-- ============================================================================

---EN: Returns table of current operator threshing settings:
---    { drumSpeed, concaveGap, fanSpeed, upperSieve, lowerSieve, targetEngineLoad }.
---UA: Повертає поточні налаштування обмолоту.
---@param vehicle table|nil
---@return table|nil
function RHM_Api.getSettings(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.combineMemory then
        return combine.spec_rhm_Combine.combineMemory.currentSettings
    end
    return nil
end

---EN: Returns optimal factory preset settings for the active crop.
---EN: Returns optimal combine settings template for the current crop with live environmental adjustments.
---UA: Повертає рекомендовані налаштування для поточної культури з урахуванням живих поправок середовища.
---@param vehicle table|nil
---@return table|nil
function RHM_Api.getOptimalSettings(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    local crop = RHM_Api.getCurrentCrop(combine)
    if crop and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getSettingsForCrop then
        local context = nil
        if combine and combine.spec_rhm_Combine then
            local rhmSpec = combine.spec_rhm_Combine
            local dayTimeHours, isRaining = 12.0, false
            if RHM_MoistureAdapter and RHM_MoistureAdapter.getEnvironmentContext then
                dayTimeHours, isRaining = RHM_MoistureAdapter.getEnvironmentContext()
            end
            local m = (rhmSpec.data and rhmSpec.data.moisture) or 0
            if m <= 0 and RHM_MoistureAdapter and RHM_MoistureAdapter.getStandingCropMoisture then
                local fillType = rhmSpec.lastFillType or (rhmSpec.combineMemory and rhmSpec.combineMemory.currentCrop)
                m = RHM_MoistureAdapter.getStandingCropMoisture(combine, fillType) or 0
            end
            context = {
                machineType = rhmSpec.machineType or "grain",
                moisture = m,
                yield = (rhmSpec.data and rhmSpec.data.yield) or 0,
                isPickup = (rhmSpec.loadCalculator and rhmSpec.loadCalculator.isPickup) or false,
                fillType = rhmSpec.lastFillType,
                fruitType = rhmSpec.lastFruitType,
                dayTime = dayTimeHours,
                isRaining = isRaining,
            }
        end
        return RHM_CombineSettingsDatabase:getSettingsForCrop(crop, context)
    end
    return nil
end

---EN: Returns threshing efficiency coefficient (0.25 to 1.0) based on setting alignment.
---UA: Повертає коефіцієнт ефективності обмолоту (0.25 .. 1.0).
---@param vehicle table|nil
---@return number|nil efficiency or nil if unmanaged
function RHM_Api.getSettingsEfficiency(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator.settingsEfficiency or 1.0
    end
    return nil
end

---EN: Returns current setting control mode: "MANUAL" or "AUTO".
---UA: Повертає режим керування налаштуваннями: "MANUAL" або "AUTO".
---@param vehicle table|nil
---@return string|nil mode ("MANUAL", "AUTO") or nil if unmanaged
function RHM_Api.getSettingsMode(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.combineMemory then
        return combine.spec_rhm_Combine.combineMemory.mode or "MANUAL"
    end
    return nil
end

-- ============================================================================
-- 9. AI & AUTOMATION INTEGRATION
-- ============================================================================

---EN: Returns true if the combine is actively driven by an automated worker or navigation system.
---UA: Повертає true, якщо комбайн керується наймитом або системою автопілота.
---@param vehicle table|nil
---@return boolean|nil isAiActive or nil if unmanaged
function RHM_Api.isAiWorkerActive(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if not combine or not combine.spec_rhm_Combine then
        return nil
    end
    if rhm_Combine and rhm_Combine.isAiWorkerActive then
        return rhm_Combine.isAiWorkerActive(combine)
    end
    if combine.getIsAIActive then
        return combine:getIsAIActive()
    end
    return false
end

-- ============================================================================
-- 10. EVENT DISPATCHER & LISTENER SUBSCRIPTIONS
-- ============================================================================

---EN: Registers a callback listener for RHM events.
---    Supported events: "onOverload", "onCropChanged", "onSettingsChanged".
---UA: Реєструє функцію зворотного виклику (callback) на події RHM.
---@param eventName string
---@param callback function
function RHM_Api.registerEventListener(eventName, callback)
    if type(eventName) ~= "string" or type(callback) ~= "function" then
        return
    end
    RHM_Api.listeners[eventName] = RHM_Api.listeners[eventName] or {}
    table.insert(RHM_Api.listeners[eventName], callback)
end

---EN: Unregisters an existing callback listener.
---UA: Видаляє раніше зареєстрований callback.
---@param eventName string
---@param callback function
function RHM_Api.unregisterEventListener(eventName, callback)
    if RHM_Api.listeners[eventName] == nil then return end
    for i, fn in ipairs(RHM_Api.listeners[eventName]) do
        if fn == callback then
            table.remove(RHM_Api.listeners[eventName], i)
            break
        end
    end
end

---EN: Dispatches an internal event to registered listeners safely (pcall).
---UA: Безпечно розсилає подію зареєстрованим слухачам.
---@param eventName string
---@param ... any
function RHM_Api.dispatch(eventName, ...)
    local list = RHM_Api.listeners[eventName]
    if list == nil then return end
    for _, callback in ipairs(list) do
        local ok, err = pcall(callback, ...)
        if not ok then
            rhm_log(string.format("RHM [API Event Error] %s: %s", eventName, tostring(err)))
        end
    end
end

-- ============================================================================
-- 10. HARVEST TRACKER & FIELD TRIP TELEMETRY API
-- ============================================================================

---EN: Returns the singleton HarvestTracker instance.
---UA: Повертає синглтон-екземпляр трекера збору врожаю.
function RHM_Api.getHarvestTracker()
    return g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
end

---EN: Returns the active field trip odometer data for a given farm.
---UA: Повертає дані активного одометра поля для заданої ферми.
function RHM_Api.getFarmTrip(farmId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker then
        local farm = tracker:getFarmData(farmId or 1)
        return farm and farm.currentTrip
    end
    return nil
end

---EN: Returns the active field trip odometer data for a specific combine.
---UA: Повертає дані одометра поля для конкретного комбайна.
---@param vehicle table|nil
---@return table|nil trip
function RHM_Api.getCombineTrip(vehicle)
    local combine = RHM_Api.findCombine(vehicle)
    if not combine then return nil end
    if combine.spec_rhm_Combine and combine.spec_rhm_Combine.trip then
        return combine.spec_rhm_Combine.trip
    end
    local tracker = RHM_Api.getHarvestTracker()
    if tracker then
        local farmId = (combine.getOwnerFarmId and combine:getOwnerFarmId()) or 1
        local farm = tracker:getFarmData(farmId)
        if farm and farm.combineTrips then
            local machineKey = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(combine)) or combine.configFileName or (combine.getFullName and combine:getFullName()) or "Harvester"
            if farm.combineTrips[machineKey] then
                if combine.spec_rhm_Combine then
                    combine.spec_rhm_Combine.trip = farm.combineTrips[machineKey]
                end
                return farm.combineTrips[machineKey]
            end
        end
    end
    return nil
end

---EN: Resolves the combine harvester currently occupied or driven by the local player.
---UA: Визначає комбайн, в якому зараз сидить або яким керує локальний гравець.
---@return table|nil combine
function RHM_Api.findPlayerEnteredCombine()
    if RHM_HarvestTracker and RHM_HarvestTracker.findPlayerEnteredCombine then
        return RHM_HarvestTracker.findPlayerEnteredCombine()
    end
    return nil
end

---EN: Returns fleet statistics for all harvesters of a given farm.
---UA: Повертає статистику парку комбайнів для заданої ферми.
function RHM_Api.getFarmFleetStats(farmId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker then
        local farm = tracker:getFarmData(farmId or 1)
        return farm and farm.fleetStats
    end
    return nil
end

---EN: Returns whether a combine is rented via contract mission or leased from dealership.
---UA: Повертає, чи орендовано комбайн під контракт чи взято в лізинг у магазині.
function RHM_Api.getVehicleRentalState(vehicle)
    if RHM_HarvestTracker and RHM_HarvestTracker.getVehicleRentalState then
        return RHM_HarvestTracker.getVehicleRentalState(vehicle)
    end
    return false, false
end

---EN: Returns true if combine belongs to a contract mission.
---UA: Повертає true, якщо комбайн належить до контрактної місії.
function RHM_Api.isMissionCombine(vehicle)
    if RHM_HarvestTracker and RHM_HarvestTracker.isMissionCombine then
        return RHM_HarvestTracker.isMissionCombine(vehicle)
    end
    return false
end

---EN: Returns historical multi-season field harvest entries for a given farm.
---UA: Повертає історію збору врожаю за попередні сезони для заданої ферми.
function RHM_Api.getFarmHistory(farmId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker then
        local farm = tracker:getFarmData(farmId or 1)
        return farm and farm.seasonHistory
    end
    return nil
end

---EN: Calculates efficiency rank grade (A, B, C, D) from loss percentage.
---UA: Розраховує ранг ефективності (A, B, C, D) за відсотком втрат.
function RHM_Api.getEfficiencyRank(lossPct)
    return RHM_HarvestTracker.calculateEfficiencyRank(lossPct)
end

---EN: Requests a reset of the trip odometer for a given farm.
---UA: Запитує скидання одометра поля для заданої ферми.
function RHM_Api.resetFarmTrip(farmId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker then
        return tracker:resetTrip(farmId or 1, nil)
    end
    return false
end

---EN: Returns recorded precision GPS telemetry points for field yield & loss heatmap.
---UA: Повертає записані GPS-точки для теплової карти врожайності та втрат поля.
function RHM_Api.getFieldHeatmap(farmId, fieldId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker and fieldId and fieldId > 0 then
        local farm = tracker:getFarmData(farmId or 1)
        if farm and farm.fieldHeatmaps and farm.fieldHeatmaps[fieldId] then
            return farm.fieldHeatmaps[fieldId].points
        end
    end
    return nil
end

---EN: Returns list of recorded season years plus 'ALL' for a given farm.
---UA: Повертає список доступних сезонів та 'ALL' для заданої ферми.
function RHM_Api.getAvailableSeasons(farmId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker and tracker.getAvailableYears then
        return tracker:getAvailableYears(farmId or 1)
    end
    return { 1, "ALL" }
end

---EN: Returns comprehensive aggregate telemetry, harvest throughput, and finances for a specific season.
---UA: Повертає повний підсумок намолоту, площі, втрат та телеметрії для обраного сезону.
function RHM_Api.getFarmSeasonSummary(farmId, year)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker and tracker.getSeasonSummary then
        return tracker:getSeasonSummary(farmId or 1, year)
    end
    return nil
end

---EN: Returns all-time historical harvest totals and performance metrics across all seasons.
---UA: Повертає агреговані підсумки жнив за весь час (усі сезони разом) для заданої ферми.
function RHM_Api.getFarmAllTimeSummary(farmId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker and tracker.getSeasonSummary then
        return tracker:getSeasonSummary(farmId or 1, "ALL")
    end
    return nil
end

---EN: Checks if a given field is currently under an active contract/mission for the specified farm.
---UA: Перевіряє, чи виконуються зараз на полі контрактні роботи (місія) для вказаної ферми.
---@param fieldId number
---@param farmId number|nil
---@return boolean
function RHM_Api.isContractField(fieldId, farmId)
    if RHM_HarvestTracker and RHM_HarvestTracker.isContractField then
        return RHM_HarvestTracker.isContractField(fieldId, farmId)
    end
    return false
end

---EN: Returns list of owned farm fields and contract operations with cumulative harvest telemetry.
---UA: Повертає список полів ферми та контрактних місій із накопиченою телеметрією збору врожаю.
---@param farmId number|nil
---@return table
function RHM_Api.getFarmFields(farmId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker and tracker.getFarmFields then
        return tracker:getFarmFields(farmId or 1)
    end
    return {}
end

---EN: Returns cumulative harvest statistics for a specific field, including yield, losses, and loss reasons breakdown.
---UA: Повертає накопичену статистику збору врожаю для вказаного поля, включаючи врожайність, втрати та розбивку причин.
---@param fieldId number
---@param farmId number|nil
---@return table|nil
function RHM_Api.getFieldStats(fieldId, farmId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker and tracker.getFarmFields and fieldId and fieldId > 0 then
        local fields = tracker:getFarmFields(farmId or 1)
        for _, f in ipairs(fields) do
            if f.fieldId == fieldId then
                return f
            end
        end
    end
    return nil
end

---EN: Returns the dominant loss factor ("speed", "moisture", "wear", "slope") for a specific field.
---UA: Повертає домінуючий фактор втрат ("speed", "moisture", "wear", "slope") для вказаного поля.
---@param fieldId number
---@param farmId number|nil
---@return string|nil
function RHM_Api.getFieldDominantLossFactor(fieldId, farmId)
    local fStat = RHM_Api.getFieldStats(fieldId, farmId)
    if fStat and fStat.reasons and RHM_HarvestTracker and RHM_HarvestTracker.getDominantLossFactor then
        return RHM_HarvestTracker.getDominantLossFactor(fStat.reasons)
    end
    return nil
end

---EN: Resolves field, fieldId, and farmlandId for world coordinates (wx, wz).
---UA: Визначає поле, ID поля та ID ділянки для світових координат (wx, wz).
---@param wx number
---@param wz number
---@param vehicle table|nil
---@return table|nil field
---@return number fieldId
---@return number farmlandId
function RHM_Api.getFieldAtWorldPosition(wx, wz, vehicle)
    if RHM_HarvestTracker and RHM_HarvestTracker.getFieldAtWorldPosition then
        return RHM_HarvestTracker.getFieldAtWorldPosition(wx, wz, vehicle)
    end
    return nil, 0, 0
end

---EN: Returns total diesel fuel consumed (in liters) by a specific combine harvester during current trip.
---UA: Повертає загальну витрату дизельного пального (у літрах) конкретним комбайном за поточну сесію.
---@param vehicle table|nil
---@return number fuelUsedL
function RHM_Api.getCombineFuelUsed(vehicle)
    local trip = RHM_Api.getCombineTrip(vehicle)
    if trip then
        return trip.fuelUsedL or 0
    end
    return 0
end

---EN: Returns fuel consumption rates per hectare and per metric ton for a specific combine.
---UA: Повертає питому витрату пального на гектар (л/га) та на тонну (л/т) для комбайна.
---@param vehicle table|nil
---@return number lPerHa
---@return number lPerTon
function RHM_Api.getCombineFuelRate(vehicle)
    local trip = RHM_Api.getCombineTrip(vehicle)
    if trip then
        local fuelL = trip.fuelUsedL or 0
        local cDensity = (RHM_UnitConverter and RHM_UnitConverter.getCropDensityTonsPerLiter and RHM_UnitConverter.getCropDensityTonsPerLiter(trip.fillTypeIndex or trip.cropName)) or 0.00075
        local massTons = (trip.harvestedMassKg and trip.harvestedMassKg > 0) and (trip.harvestedMassKg / 1000.0) or ((trip.harvestedLiters or 0) * cDensity)
        local lPerHa = (areaHa > 0.01) and (fuelL / areaHa) or 0
        local lPerTon = (massTons > 0.01) and (fuelL / massTons) or 0
        return lPerHa, lPerTon
    end
    return 0, 0
end

---EN: Returns the master field ID and member list for any clustered / merged field.
---UA: Повертає майстер-номер поля та список об'єднаних контурів для заданого поля.
---@param fieldId number
---@param farmId number|nil
---@return number masterFieldId
---@return table members
function RHM_Api.getFieldCluster(fieldId, farmId)
    local tracker = RHM_Api.getHarvestTracker()
    if tracker and fieldId and fieldId > 0 then
        local farm = tracker:getFarmData(farmId or 1)
        if farm then
            local masterId = (farm.fieldClusterMembers and farm.fieldClusterMembers[fieldId]) or fieldId
            local members = (farm.fieldClusters and farm.fieldClusters[masterId] and farm.fieldClusters[masterId].members) or { [masterId] = true }
            local memberList = {}
            for mId, _ in pairs(members) do
                table.insert(memberList, mId)
            end
            table.sort(memberList)
            return masterId, memberList
        end
    end
    return fieldId or 0, { fieldId or 0 }
end

---EN: Returns authentic nominal area of a field in hectares (aggregated if part of a cluster).
---UA: Повертає номінальну площу поля в гектарах (об'єднану якщо це кластер).
---@param fieldId number
---@param farmId number|nil
---@return number nominalAreaHa
function RHM_Api.getFieldNominalArea(fieldId, farmId)
    if RHM_HarvestTracker and RHM_HarvestTracker.getFieldNominalAreaHa then
        return RHM_HarvestTracker.getFieldNominalAreaHa(fieldId, nil, nil, farmId) or 0
    end
    return 0
end

---EN: Returns economic ledger metrics (gross revenue, fuel expense, grain loss money, net operating margin) for a field.
---UA: Повертає фінансовий баланс поля (валовий дохід, витрати на пальне, вартість втрат, чистий операційний прибуток).
---@param fieldId number
---@param farmId number|nil
---@return table|nil ledger
function RHM_Api.getFieldEconomicLedger(fieldId, farmId)
    local fStat = RHM_Api.getFieldStats(fieldId, farmId)
    if fStat then
        return {
            grossRevenue = fStat.grossRevenue or 0,
            fuelExpense = fStat.fuelExpense or 0,
            fuelUsedL = fStat.fuelUsedL or 0,
            lossMoney = fStat.lossMoney or 0,
            netMargin = fStat.netMargin or 0
        }
    end
    return nil
end

-- ============================================================================
-- 10. UNIT SYSTEM & FORMATTING HELPERS
-- ============================================================================

---EN: Returns the currently active unit system (1=Metric, 2=Imperial, 3=Bushels).
---UA: Повертає поточно активну систему одиниць вимірювання (1=Метрична, 2=Імперська, 3=Бушелі).
---@return number
function RHM_Api.getUnitSystem()
    if RHM_UnitConverter and RHM_UnitConverter.getActiveSystem then
        return RHM_UnitConverter.getActiveSystem()
    end
    return 1
end

---EN: Formats a speed value with unit label ("km/h" or "mph").
---UA: Форматує швидкість з підписом одиниці ("км/год" або "миль/год").
function RHM_Api.formatSpeed(kmh, system)
    if RHM_UnitConverter and RHM_UnitConverter.formatSpeed then
        return RHM_UnitConverter.formatSpeed(kmh, system)
    end
    return string.format("%.1f km/h", kmh or 0)
end

---EN: Formats an area value with unit label ("ha" or "ac").
---UA: Форматує площу з підписом одиниці ("га" або "акр").
function RHM_Api.formatArea(hectares, system)
    if RHM_UnitConverter and RHM_UnitConverter.formatArea then
        return RHM_UnitConverter.formatArea(hectares, system)
    end
    return string.format("%.2f ha", hectares or 0)
end

---EN: Formats a yield value with unit label ("t/ha", "t/ac", or "bu/ac").
---UA: Форматує врожайність з підписом одиниці ("т/га", "т/акр" або "буш/акр").
function RHM_Api.formatYield(tPerHa, system, fruitType)
    if RHM_UnitConverter and RHM_UnitConverter.formatYield then
        return RHM_UnitConverter.formatYield(tPerHa, system, fruitType)
    end
    return string.format("%.2f t/ha", tPerHa or 0)
end

---EN: Formats a mass value with unit label ("t", "tn", or "bu").
---UA: Форматує масу з підписом одиниці ("т", "тон" або "буш").
function RHM_Api.formatMass(tonnes, system, fruitType, liters)
    if RHM_UnitConverter and RHM_UnitConverter.formatMass then
        return RHM_UnitConverter.formatMass(tonnes, system, fruitType, liters)
    end
    return string.format("%.1f t", tonnes or 0)
end

---EN: Formats a cutter/header width with unit label ("m" or "ft").
---UA: Форматує ширину жатки з підписом одиниці ("м" або "фут").
function RHM_Api.formatWidth(meters, system)
    if RHM_UnitConverter and RHM_UnitConverter.formatWidth then
        return RHM_UnitConverter.formatWidth(meters, system)
    end
    return string.format("%.1f m", meters or 0)
end

-- ============================================================================
-- 11. FEATURE TOGGLES & CONFIGURATION STATE
-- ============================================================================

---EN: Returns true if dynamic crop loss simulation is enabled in mod settings.
---UA: Повертає true, якщо симуляція втрат врожаю увімкнена в налаштуваннях.
---@return boolean
function RHM_Api.isCropLossEnabled()
    return (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableCropLoss ~= false) or false
end

---EN: Returns true if moisture difficulty simulation is enabled.
---UA: Повертає true, якщо симуляція вологості увімкнена.
---@return boolean
function RHM_Api.isMoistureEnabled()
    return (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableMoisture ~= false) or false
end

---EN: Returns true if dynamic motor speed limit enforcement is enabled.
---UA: Повертає true, якщо динамічне обмеження швидкості увімкнено.
---@return boolean
function RHM_Api.isSpeedLimitEnabled()
    return (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableSpeedLimit ~= false) or false
end

---EN: Returns true if mechanical wear loss simulation is enabled.
---UA: Повертає true, якщо додаткові втрати від зносу техніки увімкнені.
---@return boolean
function RHM_Api.isWearLossEnabled()
    return (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableWearLoss ~= false) or false
end

---EN: Returns true if slope loss simulation is enabled.
---UA: Повертає true, якщо симуляція втрат від нахилу рельєфу увімкнена.
---@return boolean
function RHM_Api.isSlopeLossEnabled()
    return (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableSlopeLoss ~= false) or false
end

---EN: Returns true if weed resistance on engine load is enabled.
---UA: Повертає true, якщо опір та додаткове навантаження від бур'янів увімкнені.
---@return boolean
function RHM_Api.isWeedLoadEnabled()
    return (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableWeedLoad ~= false) or false
end

---EN: Returns true if in-cab interactive mouse cursor mode is currently active.
---UA: Повертає true, якщо режим інтерактивного курсора миші в кабіні активний.
---@return boolean
function RHM_Api.isMouseCursorVisible()
    return (g_realisticHarvestManager and g_realisticHarvestManager.isCursorVisible == true) or false
end

---EN: Returns unified UI color palette database
---UA: Повертає базу єдиної кольорової палітри інтерфейсу
---@return table|nil
function RHM_Api.getUIColors()
    return RHM_UIColors
end

---EN: Returns active HUD display style (1=Compact 4 cells, 2=Yield Monitor 8 cells).
---UA: Повертає активний стиль відображення HUD (1=Компактний 4 комірки, 2=Монітор врожайності 8 комірок).
---@return number
function RHM_Api.getHudStyle()
    return (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.hudStyle) or 2
end

---EN: Sets active HUD display style (1=Compact 4 cells, 2=Yield Monitor 8 cells).
---UA: Встановлює активний стиль відображення HUD (1=Компактний 4 комірки, 2=Монітор врожайності 8 комірок).
---@param style number
function RHM_Api.setHudStyle(style)
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        g_realisticHarvestManager.settings:setHudStyle(style)
    end
end





