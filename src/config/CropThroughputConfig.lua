-- EN: Per-crop throughput curve config for Realistic Harvesting.
--     Reads cropThroughput.xml and derives a power-law throughput curve for each
--     crop from two real-world anchor points:
--
--         buPerHrMin  →  throughput a CLASS 6  (≈280 hp) combine achieves
--         buPerHrMax  →  throughput a CLASS 10 (≈750 hp) combine achieves
--
--     From those two points the module derives a per-crop power-law:
--
--         throughput_kg_s  =  A  *  hp ^ B
--
--     where B is calculated from the ratio of the anchor throughputs and the
--     ratio of the anchor HPs.  This means every combine HP between 280–750
--     lands exactly on the right curve — smaller machines hit the lower bound,
--     larger machines hit the upper bound, with realistic scaling in between.
--
--     Load priority:
--         1. <My Documents>/My Games/FarmingSimulator2025/
--                modSettings/FS25_RealisticHarvesting/cropThroughput.xml  (user override)
--         2. <ModDirectory>/cropThroughput.xml  (bundled default — works out of the box)
--
-- UA: Конфігурація кривої продуктивності по культурах для Realistic Harvesting.
--     Читає cropThroughput.xml та будує степеневу криву для кожної культури
--     з двох реальних опорних точок: мінімальна (280 к.с.) та максимальна (750 к.с.).

CropThroughputConfig = {}

-- EN: Loaded curve params per crop: cropKey → { coef=A, exp=B }
-- UA: Параметри кривої по культурах: назва → { coef=A, exp=B }
CropThroughputConfig._data   = {}
CropThroughputConfig._loaded = false
CropThroughputConfig._source = "none"   -- "user", "bundled", or "none"

-- ---------------------------------------------------------------------------
-- EN: AEM combine class HP anchor points.
--     Min = Class 6 lower end, Max = Class 10 / AF11 upper end.
-- UA: Опорні точки к.с. по класах AEM.
-- ---------------------------------------------------------------------------
local HP_MIN = 280.0   -- AEM Class 6 (e.g. JD S670, Case 7250)
local HP_MAX = 750.0   -- AEM Class 10 / AF11 (e.g. JD X9 1100, Case AF9240)
local REF_HP = 400.0   -- Reference HP used when only buPerHrRef is supplied

-- ---------------------------------------------------------------------------
-- EN: USDA standard test weights (lbs/bu) — authoritative conversion factors.
-- UA: Стандартна вага бушеля USDA (фунти/бу).
-- ---------------------------------------------------------------------------
local BUSHEL_LBS = {
    wheat      = 60,
    barley     = 48,
    oat        = 32,
    corn       = 56,
    soybean    = 60,
    canola     = 50,    -- rapeseed; close to 52 lbs, 50 is the common round figure
    sunflower  = 25,    -- hulled sunflower seed
    sorghum    = 56,
    rice       = 45,
    legume     = 60,    -- generic pulse/legume (peas, beans ≈ 60 lbs/bu)
    potato     = 60,
    sugarbeet  = 60,
    cotton     = 32,
}

local LBS_PER_KG = 2.20462

-- EN: Convert bu/hr to kg/s using USDA test weight.
-- UA: Конвертуємо бу/год в кг/с за вагою бушеля USDA.
local function buPerHrToKgPerSec(buPerHr, cropKey)
    local lbsPerBu = BUSHEL_LBS[cropKey] or 56
    return (buPerHr * lbsPerBu / LBS_PER_KG) / 3600.0
end

-- ---------------------------------------------------------------------------
-- EN: Resolve config XML path.
--     User's modSettings file takes priority; falls back to bundled default.
-- UA: Визначаємо шлях до XML.  Файл користувача має пріоритет; далі — вбудований.
-- ---------------------------------------------------------------------------
local function getConfigPath()
    -- EN: User override location.
    local userPath = getUserProfileAppPath()
                   .. "modSettings/FS25_RealisticHarvesting/cropThroughput.xml"
    if fileExists(userPath) then
        return userPath, "user"
    end
    -- EN: Bundled default shipped with the mod.
    local bundledPath = (g_currentModDirectory or "") .. "cropThroughput.xml"
    if fileExists(bundledPath) then
        return bundledPath, "bundled"
    end
    return nil, "none"
end

-- ---------------------------------------------------------------------------
-- EN: Derive power-law curve parameters from two anchor points.
--
--     throughput = A * hp^B
--
--     Solving from (HP_MIN, kgsMin) and (HP_MAX, kgsMax):
--         B = ln(kgsMax / kgsMin) / ln(HP_MAX / HP_MIN)
--         A = kgsMin / HP_MIN^B
--
-- UA: Виводимо параметри степеневої кривої з двох опорних точок.
-- ---------------------------------------------------------------------------
local function deriveCurve(kgsMin, kgsMax)
    -- EN: Guard against zero / negative throughput values in the XML.
    if kgsMin <= 0 or kgsMax <= 0 then return nil end

    local B = math.log(kgsMax / kgsMin) / math.log(HP_MAX / HP_MIN)
    local A = kgsMin / (HP_MIN ^ B)
    return { coef = A, exp = B }
end

-- ---------------------------------------------------------------------------
-- EN: Load and parse the crop throughput XML.
--     Called from main.lua after mission load (after UnitConverter.initBushelCoefficients).
-- UA: Завантажуємо та розбираємо XML продуктивності культур.
-- ---------------------------------------------------------------------------
function CropThroughputConfig.load()
    CropThroughputConfig._data   = {}
    CropThroughputConfig._loaded = false
    CropThroughputConfig._source = "none"

    local path, source = getConfigPath()
    if not path then
        Logging.info("[RHM] CropThroughputConfig: no config found, using built-in defaults.")
        return
    end

    local xmlFile = loadXMLFile("CropThroughputConfig", path)
    if not xmlFile then
        Logging.warning("[RHM] CropThroughputConfig: failed to parse " .. path)
        return
    end

    local count = 0
    local i = 0
    while true do
        local key = string.format("cropThroughput.crop(%d)", i)
        if not hasXMLProperty(xmlFile, key) then break end

        local name  = getXMLString(xmlFile, key .. "#name")
        local buMin = getXMLFloat (xmlFile, key .. "#buPerHrMin")
        local buMax = getXMLFloat (xmlFile, key .. "#buPerHrMax")
        local buRef = getXMLFloat (xmlFile, key .. "#buPerHrRef")

        if name then
            local cropKey = name:lower()

            if buMin and buMax and buMin > 0 and buMax > 0 then
                -- EN: Two-point anchor → derive per-crop power-law curve.
                -- UA: Дві опорні точки → виводимо криву степеневого закону для культури.
                local kgsMin = buPerHrToKgPerSec(buMin, cropKey)
                local kgsMax = buPerHrToKgPerSec(buMax, cropKey)
                local curve  = deriveCurve(kgsMin, kgsMax)
                if curve then
                    CropThroughputConfig._data[cropKey] = curve
                    count = count + 1
                end

            elseif buRef and buRef > 0 then
                -- EN: Single reference point at REF_HP (400hp) — use default exponent 0.75.
                --     This mode is supported for simple setups but the two-point form
                --     (buPerHrMin + buPerHrMax) is strongly recommended.
                -- UA: Одна еталонна точка при 400 к.с. — використовуємо показник 0.75.
                local kgsRef = buPerHrToKgPerSec(buRef, cropKey)
                local A = kgsRef / (REF_HP ^ 0.75)
                CropThroughputConfig._data[cropKey] = { coef = A, exp = 0.75 }
                count = count + 1
            end
        end

        i = i + 1
    end

    deleteXMLFile(xmlFile)
    CropThroughputConfig._loaded = true
    CropThroughputConfig._source = source

    Logging.info(string.format(
        "[RHM] CropThroughputConfig: loaded %d crops from %s config (%s)",
        count, source, path))
end

-- ---------------------------------------------------------------------------
-- EN: Return the power-law curve params {coef, exp} for a crop, or nil.
--     Called from LoadCalculator.getBasePerformanceFromPower().
--
--     Usage:
--         local p = CropThroughputConfig.getCurveParams(cropName)
--         if p then basePerf = p.coef * (hp ^ p.exp) end
--
-- UA: Повертає параметри кривої {coef, exp} для культури або nil.
-- ---------------------------------------------------------------------------
function CropThroughputConfig.getCurveParams(cropName)
    if not cropName then return nil end
    return CropThroughputConfig._data[cropName:lower()]
end

-- ---------------------------------------------------------------------------
-- EN: Debug helper — log predicted throughput at several HP points for one crop.
-- UA: Допоміжна функція для налагодження — виводить прогнозовану продуктивність.
-- ---------------------------------------------------------------------------
function CropThroughputConfig.debugCrop(cropName)
    local p = CropThroughputConfig.getCurveParams(cropName)
    if not p then
        print("[RHM] CropThroughputConfig: no curve for '" .. tostring(cropName) .. "'")
        return
    end
    local lbsPerBu = BUSHEL_LBS[cropName:lower()] or 56
    local kgPerBu  = lbsPerBu / LBS_PER_KG
    local function predict(hp)
        local kgs   = p.coef * (hp ^ p.exp)
        local buHr  = kgs * 3600 / kgPerBu
        return string.format("%4d hp → %6.1f bu/hr  (%5.2f kg/s)", hp, buHr, kgs)
    end
    print(string.format("[RHM] CropThroughputConfig '%s': coef=%.6f  exp=%.4f",
        cropName, p.coef, p.exp))
    for _, hp in ipairs({280, 320, 380, 450, 520, 600, 700, 750}) do
        print("  " .. predict(hp))
    end
end
