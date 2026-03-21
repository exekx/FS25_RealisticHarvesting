-- EN: Static database of optimal combine settings and crop profiles.
--     Stores parameter templates for every supported crop type, maps FS25 FillType enums
--     to internal crop names, and defines which parameters are active for each machine type.
--     GRAIN:  rotor (RPM) | concave (mm) | upperSieve/Chaffer (mm) | lowerSieve/Sieve (mm) | fan (RPM)
--     FORAGE: chopLength (mm) | kernelProcessor (mm) | blower (mm gap)
--     ROOT:   rotor/CleaningRollers (RPM) | shakingIntensity (1-5) | feeder/Elevator (RPM)
--     COTTON: fan | rotor | feeder
-- UA: Статична база даних оптимальних налаштувань комбайна та профілів культур.
CombineSettingsDatabase = {}

-- EN: Base templates for crop groups. Each parameter has: optimal, min, max, tolerance.
--     Values are expressed as percentages (0-100) representing the corresponding physical range.
-- UA: Базові шаблони для груп культур. Кожен параметр має: optimal, min, max, tolerance.
--     Значення виражені у відсотках (0-100) що представляють відповідний фізичний діапазон.
--
-- GRAIN params: rotor (200-1000 RPM), concave (0-50 mm), upperSieve/Chaffer (0-30 mm),
--              lowerSieve/Sieve (0-30 mm), fan/CleaningFan (500-1400 RPM)
-- FORAGE params: chopLength (3-25 mm), kernelProcessor (0-5 mm), blower (0-6 mm)
-- ROOT params:   rotor/CleaningRollers (100-350 RPM), shakingIntensity (1-5), feeder/Elevator (100-400 RPM)
local templates = {
    -- ============================
    -- GRAIN COMBINE TEMPLATES
    -- Params: rotor | concave | upperSieve (Chaffer) | lowerSieve (Sieve) | fan (Cleaning Fan)
    -- Real ranges: Rotor 200-1000 RPM, Concave 0-50mm, Chaffer 0-30mm, Sieve 0-30mm, Fan 500-1400 RPM
    -- ============================

    -- Wheat/Rye/Spelt/Triticale
    -- Rotor: ~590 RPM → 49%, Concave: 12mm → 24%, Chaffer: 14mm → 47%, Sieve: 8mm → 27%, Fan: 740 RPM → 27%
    wheat = {
        rotor      = {optimal = 49, min = 35, max = 65, tolerance = 6},   -- ~590 RPM
        concave    = {optimal = 24, min = 10, max = 44, tolerance = 5},   -- 12 mm
        upperSieve = {optimal = 47, min = 30, max = 67, tolerance = 6},   -- 14 mm
        lowerSieve = {optimal = 27, min = 15, max = 47, tolerance = 6},   -- 8 mm
        fan        = {optimal = 27, min = 13, max = 47, tolerance = 7},   -- 740 RPM
    },

    -- Barley
    -- Rotor: ~640 RPM → 55%, Concave: 12mm → 24%, Chaffer: 14mm → 47%, Sieve: 7mm → 23%, Fan: 720 RPM → 24%
    barley = {
        rotor      = {optimal = 55, min = 40, max = 70, tolerance = 6},   -- ~640 RPM
        concave    = {optimal = 24, min = 10, max = 44, tolerance = 5},   -- 12 mm
        upperSieve = {optimal = 40, min = 25, max = 57, tolerance = 6},   -- 12 mm
        lowerSieve = {optimal = 23, min = 12, max = 40, tolerance = 6},   -- 7 mm
        fan        = {optimal = 24, min = 12, max = 44, tolerance = 7},   -- 720 RPM
    },

    -- Oat — lighter grain, lower fan, lower rotor
    -- Rotor: ~490 RPM → 36%, Concave: 10mm → 20%, Chaffer: 10mm → 33%, Sieve: 6mm → 20%, Fan: 650 RPM → 17%
    oat = {
        rotor      = {optimal = 36, min = 22, max = 55, tolerance = 6},   -- ~490 RPM
        concave    = {optimal = 20, min = 8,  max = 38, tolerance = 5},   -- 10 mm
        upperSieve = {optimal = 33, min = 18, max = 53, tolerance = 6},   -- 10 mm
        lowerSieve = {optimal = 20, min = 10, max = 37, tolerance = 6},   -- 6 mm
        fan        = {optimal = 17, min = 7,  max = 33, tolerance = 7},   -- 650 RPM
    },

    -- Canola (Rape Seed) — tiny seed, low rotor, tight concave
    -- Rotor: ~430 RPM → 29%, Concave: 8mm → 16%, Chaffer: 8mm → 27%, Sieve: 4mm → 13%, Fan: 650 RPM → 17%
    canola = {
        rotor      = {optimal = 29, min = 15, max = 45, tolerance = 6},   -- ~430 RPM
        concave    = {optimal = 16, min = 4,  max = 32, tolerance = 4},   -- 8 mm
        upperSieve = {optimal = 27, min = 12, max = 47, tolerance = 4},   -- 8 mm
        lowerSieve = {optimal = 13, min = 4,  max = 27, tolerance = 4},   -- 4 mm
        fan        = {optimal = 17, min = 7,  max = 30, tolerance = 5},   -- 650 RPM
    },

    -- Soybean — medium rotor, higher fan
    -- Rotor: ~390 RPM → 24%, Concave: 20mm → 40%, Chaffer: 15mm → 50%, Sieve: 10mm → 33%, Fan: 850 RPM → 39%
    soybean = {
        rotor      = {optimal = 24, min = 10, max = 40, tolerance = 6},   -- ~390 RPM
        concave    = {optimal = 40, min = 24, max = 56, tolerance = 6},   -- 20 mm
        upperSieve = {optimal = 50, min = 33, max = 67, tolerance = 6},   -- 15 mm
        lowerSieve = {optimal = 33, min = 20, max = 50, tolerance = 6},   -- 10 mm
        fan        = {optimal = 39, min = 24, max = 56, tolerance = 7},   -- 850 RPM
    },

    -- Sunflower — very low rotor, wide concave
    -- Rotor: ~270 RPM → 9%, Concave: 30mm → 60%, Chaffer: 25mm → 83%, Sieve: 18mm → 60%, Fan: 700 RPM → 22%
    sunflower = {
        rotor      = {optimal = 9,  min = 0,  max = 22, tolerance = 5},   -- ~270 RPM
        concave    = {optimal = 60, min = 44, max = 76, tolerance = 6},   -- 30 mm
        upperSieve = {optimal = 83, min = 67, max = 100, tolerance = 6},  -- 25 mm
        lowerSieve = {optimal = 60, min = 44, max = 76, tolerance = 6},   -- 18 mm
        fan        = {optimal = 22, min = 10, max = 38, tolerance = 7},   -- 700 RPM
    },

    -- Sorghum — medium settings
    -- Rotor: ~540 RPM → 43%, Concave: 18mm → 36%, Chaffer: 10mm → 33%, Sieve: 8mm → 27%, Fan: 750 RPM → 28%
    sorghum = {
        rotor      = {optimal = 43, min = 28, max = 60, tolerance = 6},   -- ~540 RPM
        concave    = {optimal = 36, min = 20, max = 52, tolerance = 5},   -- 18 mm
        upperSieve = {optimal = 33, min = 18, max = 50, tolerance = 6},   -- 10 mm
        lowerSieve = {optimal = 27, min = 15, max = 43, tolerance = 6},   -- 8 mm
        fan        = {optimal = 28, min = 15, max = 44, tolerance = 7},   -- 750 RPM
    },

    -- Corn (Maize) — low rotor, wide openings, high fan
    -- Rotor: ~340 RPM → 18%, Concave: 20mm → 40%, Chaffer: 18mm → 60%, Sieve: 12mm → 40%, Fan: 900 RPM → 44%
    corn = {
        rotor      = {optimal = 18, min = 5,  max = 34, tolerance = 5},   -- ~340 RPM
        concave    = {optimal = 40, min = 24, max = 56, tolerance = 5},   -- 20 mm
        upperSieve = {optimal = 60, min = 43, max = 77, tolerance = 6},   -- 18 mm
        lowerSieve = {optimal = 40, min = 27, max = 57, tolerance = 6},   -- 12 mm
        fan        = {optimal = 44, min = 28, max = 61, tolerance = 6},   -- 900 RPM
    },

    -- Legumes (Beans/Peas) — low rotor, medium-high fan
    -- Rotor: ~310 RPM → 14%, Concave: 20mm → 40%, Chaffer: 15mm → 50%, Sieve: 10mm → 33%, Fan: 875 RPM → 41%
    legume = {
        rotor      = {optimal = 14, min = 0,  max = 30, tolerance = 5},   -- ~310 RPM
        concave    = {optimal = 40, min = 24, max = 56, tolerance = 6},   -- 20 mm
        upperSieve = {optimal = 50, min = 33, max = 67, tolerance = 6},   -- 15 mm
        lowerSieve = {optimal = 33, min = 20, max = 50, tolerance = 6},   -- 10 mm
        fan        = {optimal = 41, min = 26, max = 58, tolerance = 7},   -- 875 RPM
    },

    -- Rice — medium rotor, medium settings
    -- Rotor: ~550 RPM → 44%, Concave: 12mm → 24%, Chaffer: 14mm → 47%, Sieve: 8mm → 27%, Fan: 775 RPM → 30%
    rice = {
        rotor      = {optimal = 44, min = 28, max = 60, tolerance = 6},   -- ~550 RPM
        concave    = {optimal = 24, min = 10, max = 40, tolerance = 5},   -- 12 mm
        upperSieve = {optimal = 47, min = 30, max = 63, tolerance = 6},   -- 14 mm
        lowerSieve = {optimal = 27, min = 15, max = 43, tolerance = 6},   -- 8 mm
        fan        = {optimal = 30, min = 17, max = 47, tolerance = 7},   -- 775 RPM
    },

    -- Chickpea — very low rotor, medium fan
    -- Rotor: ~390 RPM → 24%, Concave: 20mm → 40%, Chaffer: 14mm → 47%, Sieve: 8mm → 27%, Fan: 950 RPM → 50%
    chickpea = {
        rotor      = {optimal = 24, min = 10, max = 40, tolerance = 5},   -- ~390 RPM
        concave    = {optimal = 40, min = 24, max = 56, tolerance = 5},   -- 20 mm
        upperSieve = {optimal = 47, min = 30, max = 63, tolerance = 5},   -- 14 mm
        lowerSieve = {optimal = 27, min = 15, max = 43, tolerance = 4},   -- 8 mm
        fan        = {optimal = 50, min = 33, max = 67, tolerance = 7},   -- 950 RPM
    },

    -- Lentil — very low rotor, low-medium fan
    -- Rotor: ~390 RPM → 24%, Concave: 10mm → 20%, Chaffer: 12mm → 40%, Sieve: 5mm → 17%, Fan: 775 RPM → 30%
    lentil = {
        rotor      = {optimal = 24, min = 10, max = 40, tolerance = 5},   -- ~390 RPM
        concave    = {optimal = 20, min = 8,  max = 36, tolerance = 5},   -- 10 mm
        upperSieve = {optimal = 40, min = 23, max = 57, tolerance = 6},   -- 12 mm
        lowerSieve = {optimal = 17, min = 7,  max = 30, tolerance = 6},   -- 5 mm
        fan        = {optimal = 30, min = 17, max = 44, tolerance = 7},   -- 775 RPM
    },

    -- Flax / Linseed — medium rotor, tight openings
    -- Rotor: ~570 RPM → 46%, Concave: 8mm → 16%, Chaffer: 10mm → 33%, Sieve: 4mm → 13%, Fan: 600 RPM → 11%
    flax = {
        rotor      = {optimal = 46, min = 30, max = 63, tolerance = 6},   -- ~570 RPM
        concave    = {optimal = 16, min = 4,  max = 30, tolerance = 4},   -- 8 mm
        upperSieve = {optimal = 33, min = 18, max = 50, tolerance = 5},   -- 10 mm
        lowerSieve = {optimal = 13, min = 4,  max = 27, tolerance = 5},   -- 4 mm
        fan        = {optimal = 11, min = 3,  max = 25, tolerance = 5},   -- 600 RPM
    },

    -- Mustard / Buckwheat — low rotor, wide chaffer
    -- Rotor: ~430 RPM → 29%, Concave: 6mm → 12%, Chaffer: 17mm → 57%, Sieve: 8mm → 27%, Fan: 550 RPM → 6%
    mustard = {
        rotor      = {optimal = 29, min = 15, max = 45, tolerance = 6},   -- ~430 RPM
        concave    = {optimal = 12, min = 2,  max = 26, tolerance = 4},   -- 6 mm
        upperSieve = {optimal = 57, min = 40, max = 73, tolerance = 5},   -- 17 mm
        lowerSieve = {optimal = 27, min = 15, max = 43, tolerance = 5},   -- 8 mm
        fan        = {optimal = 6,  min = 0,  max = 20, tolerance = 5},   -- 550 RPM
    },

    -- Clover — max rotor, tiny openings
    -- Rotor: 1000 RPM → 100%, Concave: 2mm → 4%, Chaffer: 4mm → 13%, Sieve: 2mm → 7%, Fan: 1200 RPM → 78%
    clover = {
        rotor      = {optimal = 100, min = 88, max = 100, tolerance = 5},  -- 1000 RPM
        concave    = {optimal = 4,   min = 0,  max = 14,  tolerance = 3},  -- 2 mm
        upperSieve = {optimal = 13,  min = 3,  max = 23,  tolerance = 5},  -- 4 mm
        lowerSieve = {optimal = 7,   min = 0,  max = 17,  tolerance = 5},  -- 2 mm
        fan        = {optimal = 78,  min = 61, max = 100, tolerance = 5},  -- 1200 RPM
    },

    -- Grass Seed — high rotor, tight openings
    -- Rotor: ~780 RPM → 71%, Concave: 4mm → 8%, Chaffer: 5mm → 17%, Sieve: 3mm → 10%, Fan: 650 RPM → 17%
    grass_seed = {
        rotor      = {optimal = 71, min = 55, max = 87, tolerance = 6},   -- ~780 RPM
        concave    = {optimal = 8,  min = 0,  max = 18,  tolerance = 4},  -- 4 mm
        upperSieve = {optimal = 17, min = 5,  max = 30,  tolerance = 5},  -- 5 mm
        lowerSieve = {optimal = 10, min = 0,  max = 23,  tolerance = 5},  -- 3 mm
        fan        = {optimal = 17, min = 7,  max = 33,  tolerance = 7},  -- 650 RPM
    },

    -- ============================
    -- FORAGE HARVESTER TEMPLATES
    -- Params: chopLength (3-25 mm) | kernelProcessor (0-5 mm) | blower (0-6 mm gap)
    -- Optimal settings depend on crop moisture. No crop losses for forage harvesters.
    -- kernelProcessor only relevant for corn silage (improves digestibility).
    -- ============================

    -- Grass / Dry Grass — shorter chop for better fermentation, no kernel processor needed
    forage_grass = {
        chopLength      = {optimal = 27, min = 0,  max = 100, tolerance = 15},  -- ~6 mm (typical grass)
        kernelProcessor = {optimal = 0,  min = 0,  max = 100, tolerance = 50},  -- not needed for grass
        blower          = {optimal = 50, min = 20, max = 80,  tolerance = 15},  -- 3 mm gap (mid)
    },
    forage_grass_windrow = {
        chopLength      = {optimal = 18, min = 0,  max = 100, tolerance = 15},  -- ~5 mm (drier = shorter)
        kernelProcessor = {optimal = 0,  min = 0,  max = 100, tolerance = 50},  -- not needed
        blower          = {optimal = 50, min = 20, max = 80,  tolerance = 15},  -- 3 mm gap
    },

    -- Corn Silage — longer chop ok, kernel processor essential
    -- ChopLength: 8-12mm → ~36-50%, KernelProcessor: 2-3mm → 40-60%, Blower: 3mm → 50%
    forage_corn = {
        chopLength      = {optimal = 43, min = 13, max = 73, tolerance = 14},  -- ~9 mm
        kernelProcessor = {optimal = 50, min = 20, max = 80,  tolerance = 15},  -- ~2.5 mm gap (important!)
        blower          = {optimal = 50, min = 20, max = 80,  tolerance = 15},  -- 3 mm gap
    },

    -- ============================
    -- ROOT HARVEST TEMPLATES
    -- Params: rotor/CleaningRollers (100-350 RPM) | shakingIntensity (1-5) | feeder/Elevator (100-400 RPM)
    -- NO cleaning fan used on real potato/beet harvesters.
    -- Shaking Intensity: 1=gentle (soft soil), 5=aggressive (heavy clay).
    -- ============================

    -- Potato — gentle shaking (1-2), slow rollers, fast elevator
    -- Rollers: ~160 RPM → 24%, Shaking: 2 → 25%, Elevator: ~310 RPM → 71%
    root_potato = {
        rotor            = {optimal = 24, min = 6,  max = 45, tolerance = 8},   -- ~160 RPM (gentle)
        shakingIntensity = {optimal = 25, min = 0,  max = 50, tolerance = 12},  -- intensity 2
        feeder           = {optimal = 71, min = 50, max = 92, tolerance = 8},   -- ~310 RPM (fast)
    },

    -- Sugar Beet — moderate shaking (3), medium rollers
    -- Rollers: ~220 RPM → 48%, Shaking: 3 → 50%, Elevator: ~260 RPM → 54%
    root_sugarbeet = {
        rotor            = {optimal = 48, min = 24, max = 70, tolerance = 8},   -- ~220 RPM
        shakingIntensity = {optimal = 50, min = 25, max = 75, tolerance = 12},  -- intensity 3
        feeder           = {optimal = 54, min = 33, max = 75, tolerance = 8},   -- ~260 RPM
    },

    -- Beetroot — moderate (between potato and sugarbeet)
    root_beetroot = {
        rotor            = {optimal = 36, min = 14, max = 58, tolerance = 8},   -- ~190 RPM
        shakingIntensity = {optimal = 38, min = 12, max = 63, tolerance = 12},  -- intensity ~2.5
        feeder           = {optimal = 63, min = 42, max = 84, tolerance = 8},   -- ~285 RPM
    },

    -- Onion — moderate shaking, gentle rollers
    root_onion = {
        rotor            = {optimal = 30, min = 10, max = 52, tolerance = 8},   -- ~175 RPM (gentle)
        shakingIntensity = {optimal = 38, min = 12, max = 63, tolerance = 12},  -- intensity ~2.5
        feeder           = {optimal = 46, min = 25, max = 67, tolerance = 8},   -- ~235 RPM
    },

    -- Carrot / Parsnip — very gentle, slow rollers
    root_carrot = {
        rotor            = {optimal = 18, min = 3,  max = 36, tolerance = 7},   -- ~135 RPM (very slow)
        shakingIntensity = {optimal = 12, min = 0,  max = 38, tolerance = 10},  -- intensity 1-2
        feeder           = {optimal = 79, min = 58, max = 100, tolerance = 8},  -- ~325 RPM (fast)
    },

    -- Spinach — extremely gentle
    root_spinach = {
        rotor            = {optimal = 9,  min = 0,  max = 24, tolerance = 5},  -- ~115 RPM (very slow)
        shakingIntensity = {optimal = 0,  min = 0,  max = 25, tolerance = 8},  -- intensity 1 only
        feeder           = {optimal = 58, min = 38, max = 79, tolerance = 8},  -- ~265 RPM
    },

    -- Green Bean — gentle
    root_greenbean = {
        rotor            = {optimal = 24, min = 6,  max = 45, tolerance = 8},   -- ~160 RPM
        shakingIntensity = {optimal = 25, min = 0,  max = 50, tolerance = 10},  -- intensity 2
        feeder           = {optimal = 63, min = 42, max = 84, tolerance = 8},   -- ~285 RPM
    },

    -- Generic fallback for root
    root_harvest = {
        rotor            = {optimal = 36, min = 14, max = 58, tolerance = 10},
        shakingIntensity = {optimal = 38, min = 12, max = 63, tolerance = 12},
        feeder           = {optimal = 54, min = 33, max = 75, tolerance = 10},
    },

    -- ============================
    -- COTTON HARVESTER TEMPLATES
    -- ============================
    cotton_picker = {
        fan    = {optimal = 80, min = 60, max = 100, tolerance = 10},
        rotor  = {optimal = 70, min = 50, max = 90,  tolerance = 10},
        feeder = {optimal = 60, min = 40, max = 80,  tolerance = 10},
    },
}
-- EN: Active parameters per machine type. Defines which parameter sliders appear in the calibration GUI.
-- UA: Активні параметри для кожного типу машини. Визначає які повзунки параметрів відображаються в GUI калібрування.

---Active parameters per machine type (defines which sliders appear in GUI)
CombineSettingsDatabase.machineParams = {
    -- EN: GRAIN: Rotor → Concave → Chaffer (upper) → Sieve (lower) → Cleaning Fan
    -- UA: ЗЕРНОВІ: Ротор → Зазор підбарабання → Верхнє решето → Нижнє решето → Вентилятор
    grain  = { "rotor", "concave", "upperSieve", "lowerSieve", "fan" },
    -- EN: FORAGE: Chop Length → Kernel Processor → Blower Gap (no losses for forage)
    -- UA: ФОРАЖНІ: Довжина різки → Процесор зерна → Зазор вентилятора (немає втрат)
    forage = { "chopLength", "kernelProcessor", "blower" },
    -- EN: ROOT: Cleaning Rollers → Shaking Intensity → Elevator (no fan on real machines)
    -- UA: КОРЕНЕПЛОДИ: Очисні ролики → Інтенсивність струшування → Елеватор
    root   = { "rotor", "shakingIntensity", "feeder" },
    cotton = { "fan", "rotor", "feeder" },
}

---L10n key overrides for parameter labels per machine type
---Falls back to generic "rhm_ui_<param>" if no override defined
CombineSettingsDatabase.machineParamLabels = {
    grain = {
        rotor      = "rhm_ui_rotor_speed",
        concave    = "rhm_ui_concave",
        upperSieve = "rhm_ui_upper_sieve",
        lowerSieve = "rhm_ui_lower_sieve",
        fan        = "rhm_ui_fan_speed",
    },
    forage = {
        chopLength      = "rhm_ui_chop_length",
        kernelProcessor = "rhm_ui_kernel_processor",
        blower          = "rhm_ui_blower_gap",
    },
    root = {
        rotor            = "rhm_ui_root_roller",
        shakingIntensity = "rhm_ui_shaking_intensity",
        feeder           = "rhm_ui_root_feeder",
    },
    cotton = {
        fan    = "rhm_ui_fan_speed",
        rotor  = "rhm_ui_picker_speed",
        feeder = "rhm_ui_feeder_speed",
    },
}

-- EN: Returns the ordered list of parameter names active for the given machine type.
--     Used to determine which sliders to display and which CombineMemory keys to initialize.
-- UA: Повертає впорядкований список назв параметрів активних для заданого типу машини.
--     Використовується для визначення яких повзунки відображати та які ключі CombineMemory ініціалізувати.
function CombineSettingsDatabase:getParamsForMachineType(machineType)
    return self.machineParams[machineType] or self.machineParams.grain
end

-- EN: Returns the localization key for a parameter label based on machine type.
--     Falls back to generic "rhm_ui_<param>" if no specific override is defined.
-- UA: Повертає ключ локалізації для підпису параметру залежно від типу машини.
--     Повертається до загального "rhm_ui_<param>" якщо немає специфічного перевизначення.
function CombineSettingsDatabase:getParamLabel(machineType, paramName)
    local labels = self.machineParamLabels[machineType]
    if labels and labels[paramName] then
        return labels[paramName]
    end
    return "rhm_ui_" .. paramName
end

-- EN: Guard wrapper for FillType values — returns nil if the fill type is missing (DLC/mod not loaded).
-- UA: Захисна обгортка для значень FillType — повертає nil якщо тип врожаю відсутній (DLC/мод не завантажений).
local function safeFillType(ft)
    return (ft ~= nil and ft ~= 0) and ft or nil
end

CombineSettingsDatabase.crops = {
    -- Зернові
    ["WHEAT"]   = { name = "Пшениця",            nameEN = "Wheat",            template = templates.wheat,         machineType = "grain", group = "grain",       fillType = safeFillType(FillType.WHEAT) },
    ["BARLEY"]  = { name = "Ячмінь",             nameEN = "Barley",           template = templates.barley,        machineType = "grain", group = "grain",       fillType = safeFillType(FillType.BARLEY) },
    ["OAT"]     = { name = "Овес",               nameEN = "Oat",              template = templates.oat,           machineType = "grain", group = "grain",       fillType = safeFillType(FillType.OAT) },
    ["SORGHUM"] = { name = "Сорго",              nameEN = "Sorghum",          template = templates.sorghum,       machineType = "grain", group = "grain",       fillType = safeFillType(FillType.SORGHUM) },
    
    -- Рис
    ["RICE"]            = { name = "Рис",               nameEN = "Rice",             template = templates.rice,          machineType = "grain", group = "rice",        fillType = safeFillType(FillType.RICE) },
    ["RICE_LONG_GRAIN"] = { name = "Рис (довгозерний)", nameEN = "Rice (Long Grain)", template = templates.rice,          machineType = "grain", group = "rice",        fillType = safeFillType(FillType.RICE_LONG_GRAIN) },
    
    -- Олійні
    ["CANOLA"]    = { name = "Ріпак",             nameEN = "Canola",          template = templates.canola,        machineType = "grain", group = "oilseed",     fillType = safeFillType(FillType.CANOLA) },
    ["SUNFLOWER"] = { name = "Соняшник",          nameEN = "Sunflower",       template = templates.sunflower,     machineType = "grain", group = "oilseed",     fillType = safeFillType(FillType.SUNFLOWER) },
    
    -- Кукурудза
    ["CORN"] = { name = "Кукурудза", nameEN = "Corn", template = templates.corn,          machineType = "grain", group = "corn",        fillType = safeFillType(FillType.MAIZE) },
    
    -- Бобові
    ["SOYBEAN"]  = { name = "Соя",           nameEN = "Soybean",   template = templates.soybean,       machineType = "grain", group = "legume",      fillType = safeFillType(FillType.SOYBEAN) },
    ["PEA"]      = { name = "Горох",         nameEN = "Peas",      template = templates.legume,        machineType = "grain", group = "legume",      fillType = safeFillType(FillType.PEA) },
    ["LENTIL"]   = { name = "Сочевиця",      nameEN = "Lentil",    template = templates.lentil,        machineType = "grain", group = "legume",      fillType = safeFillType(FillType.LENTIL) },
    ["CHICKPEA"] = { name = "Нут",           nameEN = "Chickpea",  template = templates.chickpea,      machineType = "grain", group = "legume",      fillType = safeFillType(FillType.CHICKPEA) },

    -- Додаткові зернові (Mod crops)
    ["RYE"]       = { name = "Жито",     nameEN = "Rye",       template = templates.wheat,         machineType = "grain", group = "grain", fillType = nil },
    ["SPELT"]     = { name = "Спельта",  nameEN = "Spelt",     template = templates.wheat,         machineType = "grain", group = "grain", fillType = nil },
    ["TRITICALE"] = { name = "Тритикале",nameEN = "Triticale", template = templates.wheat,         machineType = "grain", group = "grain", fillType = nil },
    ["OATS"]      = { name = "Овес",     nameEN = "Oats",      template = templates.oat,           machineType = "grain", group = "grain", fillType = nil },
    ["MILLET"]    = { name = "Просо",    nameEN = "Millet",    template = templates.wheat,         machineType = "grain", group = "grain", fillType = nil },
    ["BUCKWHEAT"] = { name = "Гречка",   nameEN = "Buckwheat", template = templates.mustard,       machineType = "grain", group = "grain", fillType = nil },
    
    -- Додаткові олійні (Mod crops)
    ["LINSEED"] = { name = "Льон",     nameEN = "Linseed/Flax", template = templates.flax,          machineType = "grain", group = "oilseed", fillType = nil },
    ["FLAX"]    = { name = "Льон",     nameEN = "Flax",         template = templates.flax,          machineType = "grain", group = "oilseed", fillType = nil },
    ["MUSTARD"] = { name = "Гірчиця", nameEN = "Mustard",       template = templates.mustard,       machineType = "grain", group = "oilseed", fillType = nil },
    ["SAFFLOWER"] = { name = "Сафлор", nameEN = "Safflower",     template = templates.sunflower,     machineType = "grain", group = "oilseed", fillType = nil },
    ["POPPY"]   = { name = "Мак",     nameEN = "Poppy",         template = templates.mustard,       machineType = "grain", group = "oilseed", fillType = nil },
    
    -- Трави
    ["GRASS_SEED"] = { name = "Насіння трави", nameEN = "Grass Seed", template = templates.grass_seed, machineType = "grain", group = "grain", fillType = nil },
    ["CLOVER"]     = { name = "Клевер",        nameEN = "Clover",     template = templates.clover,     machineType = "grain", group = "grain", fillType = nil },
    
    -- Волокнисті (Mod crops)
    ["HEMP"] = { name = "Коноплі (зерно)", nameEN = "Hemp", template = templates.oilseed_heavy, machineType = "grain", group = "oilseed", fillType = nil },
    
    -- Root & Veg (machineType = "root") — кожна культура має власний шаблон
    ["POTATO"]    = { name = "Картопля",       nameEN = "Potato",    template = templates.root_potato,    machineType = "root", group = "root",      fillType = safeFillType(FillType.POTATO) },
    ["SUGARBEET"] = { name = "Цукровий Буряк", nameEN = "Sugarbeet", template = templates.root_sugarbeet, machineType = "root", group = "root",      fillType = safeFillType(FillType.SUGARBEET) },
    ["BEETROOT"]  = { name = "Буряк",          nameEN = "Beetroot",  template = templates.root_beetroot,  machineType = "root", group = "root",      fillType = safeFillType(FillType.BEETROOT) },
    ["CARROT"]    = { name = "Морква",          nameEN = "Carrot",    template = templates.root_carrot,    machineType = "root", group = "root",      fillType = safeFillType(FillType.CARROT) },
    ["PARSNIP"]   = { name = "Пастернак",       nameEN = "Parsnip",   template = templates.root_carrot,    machineType = "root", group = "root",      fillType = safeFillType(FillType.PARSNIP) },
    ["ONION"]     = { name = "Цибуля",          nameEN = "Onion",     template = templates.root_onion,     machineType = "root", group = "root",      fillType = safeFillType(FillType.ONION) },
    ["SPINACH"]   = { name = "Шпинат",          nameEN = "Spinach",   template = templates.root_spinach,   machineType = "root", group = "vegetable", fillType = safeFillType(FillType.SPINACH) },
    ["GREENBEAN"] = { name = "Зелена Квасоля",  nameEN = "Green Bean",template = templates.root_greenbean,  machineType = "root", group = "vegetable", fillType = safeFillType(FillType.GREENBEAN) },

    -- Форажні (для кормозбирального комбайна) (machineType = "forage")
    ["GRASS"]   = { name = "Трава",       nameEN = "Grass",        template = templates.forage_grass,  machineType = "forage", group = "forage", fillType = safeFillType(FillType.GRASS) },
    ["DRYGRASS"]= { name = "Суха Трава",  nameEN = "Dry Grass",    template = templates.forage_grass,  machineType = "forage", group = "forage", fillType = safeFillType(FillType.DRYGRASS) },
    ["GRASS_WINDROW"]   = { name = "Валок Трави",       nameEN = "Grass Windrow",        template = templates.forage_grass_windrow,  machineType = "forage", group = "forage", fillType = safeFillType(FillType.GRASS_WINDROW) },
    ["DRYGRASS_WINDROW"]= { name = "Валок Сухої Трави", nameEN = "Dry Grass Windrow",    template = templates.forage_grass_windrow,  machineType = "forage", group = "forage", fillType = safeFillType(FillType.DRYGRASS_WINDROW) },
    ["MAIZE_FORAGE"] = { name = "Кукурудза на силос", nameEN = "Corn Silage", template = templates.forage_corn, machineType = "forage", group = "forage", fillType = safeFillType(FillType.MAIZE) },

    -- Бавовник (machineType = "cotton")
    ["COTTON"] = { name = "Бавовник", nameEN = "Cotton", template = templates.cotton_picker, machineType = "cotton", group = "cotton", fillType = safeFillType(FillType.COTTON) },
}

-- EN: Returns the optimal settings template for a crop by internal name (e.g. "WHEAT").
--     Returns nil if the crop is not in the database (unknown mod crop).
-- UA: Повертає шаблон оптимальних налаштувань для культури за внутрішньою назвою (напр. "WHEAT").
--     Повертає nil якщо культура відсутня в базі даних (невідома культура мода).
function CombineSettingsDatabase:getSettingsForCrop(cropName)
    local crop = self.crops[cropName]
    if crop then
        return crop.template
    end
    return nil
end

-- EN: Converts a game FillType integer to the internal crop name used in the database.
--     Handles windrow variants (_WINDROW suffix) and cut variants (CUT_ prefix) via fallback logic.
-- UA: Перетворює ціле число FillType гри на внутрішню назву культури у базі даних.
--     Обробляє варіанти валків (_WINDROW суфікс) та зрізані варіанти (CUT_ префікс) через резервну логіку.
function CombineSettingsDatabase:getCropNameFromFillType(fillType)
    if not fillType or fillType == FillType.UNKNOWN then
        return nil
    end
    
    -- Отримуємо точний рядок-ключ з таблиці FillType (наприклад "RICE_LONG_GRAIN")
    local fillTypeKey = nil
    for k, v in pairs(FillType) do
        if v == fillType then
            fillTypeKey = k
            break
        end
    end
    
    if not fillTypeKey then
        return nil
    end
    
    -- Шукаємо crop за ключем FillType
    local fillTypeMapping = {
        ["WHEAT"] = "WHEAT",
        ["BARLEY"] = "BARLEY",
        ["OAT"] = "OAT",
        ["CANOLA"] = "CANOLA",
        ["SUNFLOWER"] = "SUNFLOWER",
        ["MAIZE"] = "CORN",
        ["SOYBEAN"] = "SOYBEAN",
        ["SORGHUM"] = "SORGHUM",
        ["RICE"] = "RICE",
        ["RICE_LONG_GRAIN"] = "RICE_LONG_GRAIN",
        ["RICELONGGRAIN"] = "RICE_LONG_GRAIN", -- Можливий варіант написання
        ["RICE_LONGGRAIN"] = "RICE_LONG_GRAIN", -- Ще один варіант
        
        -- FS25 New & Mod Crops
        ["PEA"] = "PEA",
        ["LENTIL"] = "LENTIL",
        ["CHICKPEA"] = "CHICKPEA",
        
        ["RYE"] = "RYE",
        ["SPELT"] = "SPELT",
        ["TRITICALE"] = "TRITICALE",
        ["MILLET"] = "MILLET",
        ["BUCKWHEAT"] = "BUCKWHEAT",
        
        ["LINSEED"] = "LINSEED",
        ["FLAX"] = "LINSEED",
        ["MUSTARD"] = "MUSTARD",
        ["POPPY"] = "POPPY",
        ["HEMP"] = "HEMP",
        
        -- Root/Veg
        ["POTATO"] = "POTATO",
        ["SUGARBEET"] = "SUGARBEET",
        ["BEETROOT"] = "BEETROOT",
        ["CARROT"] = "CARROT",
        ["PARSNIP"] = "PARSNIP",
        ["ONION"] = "ONION",
        ["ONION_DIRTY"] = "ONION",
        ["SPINACH"] = "SPINACH",
        ["GREENBEAN"] = "GREENBEAN",

        -- Forage outputs
        ["CHAFF"] = "MAIZE_FORAGE",
        ["GRASS"] = "GRASS",
        ["DRYGRASS"] = "DRYGRASS",
        ["TALLGRASS"] = "GRASS",
        ["GRASS_WINDROW"] = "GRASS_WINDROW",
        ["DRYGRASS_WINDROW"] = "DRYGRASS_WINDROW",
        ["SILAGE"] = "MAIZE_FORAGE",

        -- Cotton
        ["COTTON"] = "COTTON",
    }
    
    local matchedName = fillTypeMapping[fillTypeKey]
    
    if not matchedName and fillTypeKey then
        if fillTypeKey:find("_WINDROW") then
            local baseType = fillTypeKey:gsub("_WINDROW", "")
            matchedName = fillTypeMapping[baseType]
        elseif fillTypeKey:find("CUT_") then
            local baseType = fillTypeKey:gsub("CUT_", "")
            matchedName = fillTypeMapping[baseType]
        end
    end
    if not matchedName then
        print(string.format("RHM: [CROP DB] Unknown FillType KEY: '%s' (ID: %d)", tostring(fillTypeKey), fillType))
    end
    
    return matchedName
end

-- EN: Returns the full crop data record (template, machineType, group, fillType, names).
-- UA: Повертає повний запис даних культури (шаблон, тип машини, група, fillType, назви).
function CombineSettingsDatabase:getCropData(cropName)
    return self.crops[cropName]
end

-- EN: Returns a sorted list of all registered crop names in the database.
-- UA: Повертає відсортований список всіх зареєстрованих назв культур у базі даних.
function CombineSettingsDatabase:getAllCropNames()
    local names = {}
    for cropName, _ in pairs(self.crops) do
        table.insert(names, cropName)
    end
    table.sort(names)
    return names
end

-- EN: Returns a sorted list of crop names that match the specified machine type.
-- UA: Повертає відсортований список назв культур що відповідають заданому типу машини.
function CombineSettingsDatabase:getCropNamesForMachineType(machineType)
    local names = {}
    for cropName, cropData in pairs(self.crops) do
        if cropData.machineType == machineType then
            table.insert(names, cropName)
        end
    end
    table.sort(names)
    return names
end

-- EN: Calculates a preview of total crop loss for arbitrary settings without applying them.
--     Used in the calibration GUI to show color-coded feedback before the player commits.
--     Loss = 0.15% per unit of deviation above tolerance, capped at 25%.
-- UA: Розраховує попередній перегляд загальних втрат врожаю для довільних налаштувань без їх застосування.
--     Використовується в GUI калібрування для кольорового зворотного зв'язку до підтвердження гравцем.
--     Втрати = 0.15% за одиницю відхилення понад допуск, обмежено до 25%.
function CombineSettingsDatabase:calcSettingsLossPreview(cropName, settings)
    local template = self:getSettingsForCrop(cropName)
    if not template then return 0, {} end
    
    local totalPenalty = 0
    local warnings = {}
    
    for paramName, paramData in pairs(template) do
        local val = settings[paramName]
        if val and paramData.optimal then
            local diff = math.abs(val - paramData.optimal)
            local tol = paramData.tolerance or 5
            if diff > tol then
                local penalty = (diff - tol) * 0.15  -- 0.15% loss per unit above tolerance
                totalPenalty = totalPenalty + penalty
                table.insert(warnings, {
                    param = paramName,
                    current = val,
                    optimal = paramData.optimal,
                    diff = diff,
                    penalty = penalty,
                })
            end
        end
    end
    
    return math.min(totalPenalty, 25.0), warnings  -- cap at 25%
end

-- EN: Checks if a parameter value is within the allowed range (min-max) for the crop.
--     Values outside this range are physically unrealistic and blocked by the GUI.
-- UA: Перевіряє чи значення параметру знаходиться в допустимому діапазоні (min-max) для культури.
--     Значення поза цим діапазоном є фізично нереалістичними і блокуються GUI.
function CombineSettingsDatabase:isValueValid(cropName, paramName, value)
    local settings = self:getSettingsForCrop(cropName)
    if not settings or not settings[paramName] then
        return false
    end
    
    local param = settings[paramName]
    return value >= param.min and value <= param.max
end

print("[OK] CombineSettingsDatabase loaded with " .. #CombineSettingsDatabase:getAllCropNames() .. " crops")
