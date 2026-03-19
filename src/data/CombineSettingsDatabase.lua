-- EN: Static database of optimal combine settings and crop profiles.
--     Stores parameter templates (fan, rotor, sieves, concave) for every supported crop type,
--     maps FS25 FillType enums to internal crop names, and defines which parameters are
--     active for each machine type (grain, forage, root, cotton).
--     NOTE: Grain combines use 'concave' (0-50mm clearance) instead of 'feeder'.
--           Forage/root/cotton harvesters still use 'feeder' (feed roll speed).
-- UA: Статична база даних оптимальних налаштувань комбайна та профілів культур.
--     Зберігає шаблони параметрів (вентилятор, ротор, решета, подача) для кожного типу культури,
--     відображає FillType enum FS25 на внутрішні назви культур, і визначає які параметри активні
--     для кожного типу машини (зернова, форажна, коренеплоди, бавовна).
CombineSettingsDatabase = {}

-- EN: Base templates for crop groups. Each parameter has: optimal, min, max, tolerance.
--     Values are expressed as percentages (0-100) representing the corresponding physical range.
-- UA: Базові шаблони для груп культур. Кожен параметр має: optimal, min, max, tolerance.
--     Значення виражені у відсотках (0-100) що представляють відповідний фізичний діапазон.
local templates = {
    -- EN: Standard grain cereals — Wheat/Rye/Spelt/Triticale. Rotor 560-850rpm (avg 56%), Fan 800rpm (56%), Chaffer 14mm (47%), Sieve 8mm (32%), Concave 25mm (50%).
    -- UA: Стандартні зернові — Пшениця/Жито/Спельта/Тритикале. Ротор 560-850об/хв (сер. 56%), Вентилятор 800об/хв (56%), Верх 14мм (47%), Низ 8мм (32%), Деко 25мм (50%).
    wheat = {
        fan = {optimal = 56, min = 40, max = 70, tolerance = 7},
        upperSieve = {optimal = 47, min = 35, max = 60, tolerance = 6},
        lowerSieve = {optimal = 32, min = 20, max = 45, tolerance = 6},
        rotor = {optimal = 56, min = 45, max = 70, tolerance = 6},
        concave = {optimal = 50, min = 35, max = 65, tolerance = 10},  -- 0-50mm: 50% = 25mm
    },

    -- Barley - Drum speed 640-900 (Avg 770 = 63%), Fan 800 (56%), Chaffer 14mm (47%), Sieve 8mm (32%)
    barley = {
        fan = {optimal = 56, min = 40, max = 70, tolerance = 7},
        upperSieve = {optimal = 47, min = 35, max = 60, tolerance = 6},
        lowerSieve = {optimal = 32, min = 20, max = 45, tolerance = 6},
        rotor = {optimal = 63, min = 50, max = 75, tolerance = 6},
        concave = {optimal = 50, min = 35, max = 65, tolerance = 10},
    },

    -- Oat - Drum speed 640-800 = 720 = 58%, Fan 700 = 44%, Chaffer 10mm = 33%, Sieve 6mm = 24%
    oat = {
        fan = {optimal = 44, min = 30, max = 60, tolerance = 7},
        upperSieve = {optimal = 33, min = 20, max = 50, tolerance = 6},
        lowerSieve = {optimal = 24, min = 15, max = 40, tolerance = 6},
        rotor = {optimal = 58, min = 45, max = 75, tolerance = 6},
        concave = {optimal = 50, min = 35, max = 65, tolerance = 10},
    },

    -- Canola (Rape Seed) - Drum speed 480-520 (Avg 500 = 33%), Fan 650 (39%), tight concave ~10mm (20%)
    canola = {
        fan = {optimal = 39, min = 25, max = 55, tolerance = 6},
        upperSieve = {optimal = 40, min = 25, max = 55, tolerance = 4},
        lowerSieve = {optimal = 25, min = 15, max = 40, tolerance = 4},
        rotor = {optimal = 33, min = 20, max = 45, tolerance = 6},
        concave = {optimal = 22, min = 10, max = 35, tolerance = 6},   -- tighter: ~11mm
    },

    -- Soya Bean - Drum speed 550 rpm (39%), Fan 850 rpm (61%), Chaffer 15mm (50%), Sieve 10mm (40%)
    soybean = {
        fan = {optimal = 61, min = 45, max = 75, tolerance = 7},
        upperSieve = {optimal = 50, min = 35, max = 65, tolerance = 6},
        lowerSieve = {optimal = 40, min = 25, max = 55, tolerance = 6},
        rotor = {optimal = 39, min = 25, max = 55, tolerance = 6},
        concave = {optimal = 45, min = 30, max = 60, tolerance = 8},   -- ~22mm
    },

    -- Sunflower - Drum speed 320 rpm (13%), Fan 700 rpm (44%), wide concave ~30mm (60%)
    sunflower = {
        fan = {optimal = 44, min = 30, max = 60, tolerance = 7},
        upperSieve = {optimal = 60, min = 45, max = 75, tolerance = 6},
        lowerSieve = {optimal = 45, min = 30, max = 60, tolerance = 6},
        rotor = {optimal = 13, min = 5, max = 25, tolerance = 5},
        concave = {optimal = 60, min = 45, max = 75, tolerance = 10},  -- wide: ~30mm
    },

    -- Sorghum - Drum speed 640 = 49%, Fan 700-800 = 750 = 50%, Chaffer 10mm = 33%, Sieve 8mm = 32%
    sorghum = {
        fan = {optimal = 50, min = 35, max = 65, tolerance = 7},
        upperSieve = {optimal = 33, min = 20, max = 45, tolerance = 6},
        lowerSieve = {optimal = 32, min = 20, max = 45, tolerance = 6},
        rotor = {optimal = 49, min = 35, max = 65, tolerance = 6},
        concave = {optimal = 50, min = 35, max = 65, tolerance = 10},
    },

    -- Maize (Corn) - Drum speed 320-400 (Avg 360 = 18%), Fan 900 (67%), Chaffer 18mm (60%), Sieve 12mm (48%), wide concave ~35mm (70%)
    corn = {
        fan = {optimal = 67, min = 50, max = 85, tolerance = 6},
        upperSieve = {optimal = 60, min = 45, max = 75, tolerance = 6},
        lowerSieve = {optimal = 48, min = 35, max = 65, tolerance = 6},
        rotor = {optimal = 18, min = 5, max = 30, tolerance = 5},
        concave = {optimal = 70, min = 55, max = 85, tolerance = 10},  -- wide: ~35mm
    },

    -- Beans/Peas - Drum speed 320-360 = 340 = 16%, Fan 800-950 = 875 = 64%, Chaffer 15mm = 50%, Sieve 10mm = 40%
    legume = {
        fan = {optimal = 64, min = 50, max = 80, tolerance = 7},
        upperSieve = {optimal = 50, min = 35, max = 65, tolerance = 6},
        lowerSieve = {optimal = 40, min = 25, max = 55, tolerance = 6},
        rotor = {optimal = 16, min = 5, max = 30, tolerance = 5},
        concave = {optimal = 45, min = 30, max = 60, tolerance = 8},
    },
    
    -- Rice - Drum speed 450-650 = 550 = 39%, Fan 700-850 = 775 = 53%, Chaffer 14mm = 47%, Sieve 8mm = 32%
    rice = {
        fan = {optimal = 53, min = 40, max = 70, tolerance = 7},
        upperSieve = {optimal = 47, min = 35, max = 60, tolerance = 6},
        lowerSieve = {optimal = 32, min = 20, max = 45, tolerance = 6},
        rotor = {optimal = 39, min = 25, max = 55, tolerance = 6},
        concave = {optimal = 50, min = 35, max = 65, tolerance = 10},
    },
    
    -- Коренеплоди важкі (Картопля, Буряк)
    -- Rotor = Cleaning System Speed, Fan = Airflow/Blower
    root_heavy = {
        fan = {optimal = 40, min = 20, max = 60, tolerance = 10}, -- Low air
        upperSieve = {optimal = 80, min = 60, max = 100, tolerance = 10}, -- Large grid
        lowerSieve = {optimal = 80, min = 60, max = 100, tolerance = 10},
        rotor = {optimal = 50, min = 30, max = 70, tolerance = 10}, -- Slow speed to prevent damage
        feeder = {optimal = 50, min = 30, max = 70, tolerance = 10},
    },
    
    -- Коренеплоди легкі / Овочі (Морква, Пастернак)
    root_light = {
        fan = {optimal = 50, min = 30, max = 70, tolerance = 10},
        upperSieve = {optimal = 70, min = 50, max = 90, tolerance = 10},
        lowerSieve = {optimal = 70, min = 50, max = 90, tolerance = 10},
        rotor = {optimal = 60, min = 40, max = 80, tolerance = 10},
        feeder = {optimal = 60, min = 40, max = 80, tolerance = 10},
    },

    -- Цибуля (потребує продувки)
    vegetable_sensitive = {
        fan = {optimal = 75, min = 55, max = 95, tolerance = 10}, -- High air for skins
        upperSieve = {optimal = 60, min = 40, max = 80, tolerance = 10},
        lowerSieve = {optimal = 60, min = 40, max = 80, tolerance = 10},
        rotor = {optimal = 55, min = 35, max = 75, tolerance = 10}, 
        feeder = {optimal = 55, min = 35, max = 75, tolerance = 10},
    },

    -- Зелень (Шпинат)
    leafy = {
        fan = {optimal = 30, min = 10, max = 50, tolerance = 10}, -- Low air (leaves fly away)
        upperSieve = {optimal = 50, min = 30, max = 70, tolerance = 10},
        lowerSieve = {optimal = 50, min = 30, max = 70, tolerance = 10},
        rotor = {optimal = 40, min = 20, max = 60, tolerance = 10}, -- Gentle
        feeder = {optimal = 40, min = 20, max = 60, tolerance = 10},
    },

    -- ============================
    -- FORAGE HARVESTER TEMPLATES
    -- (rotor = Drum RPM, fan = Intake Blower, feeder = Feed Roll)
    -- ============================
    forage_grass = {
        fan    = {optimal = 60, min = 40, max = 80, tolerance = 10},
        rotor  = {optimal = 65, min = 45, max = 85, tolerance = 10},
        feeder = {optimal = 55, min = 35, max = 75, tolerance = 10},
    },
    forage_grass_windrow = {
        fan    = {optimal = 55, min = 35, max = 75, tolerance = 10},
        rotor  = {optimal = 60, min = 40, max = 80, tolerance = 10},
        feeder = {optimal = 65, min = 45, max = 85, tolerance = 10},
    },
    forage_corn = {
        fan    = {optimal = 70, min = 50, max = 90, tolerance = 10},
        rotor  = {optimal = 80, min = 60, max = 100, tolerance = 10},
        feeder = {optimal = 70, min = 50, max = 90, tolerance = 10},
    },

    -- ============================
    -- ROOT HARVEST TEMPLATES
    -- (fan = Separation/Blower, rotor = Cleaning Roller Speed, feeder = Elevator/Chain Speed)
    -- ============================
    
    -- Картопля: низький обдув (щоб не здувало грунт на бруківку), повільний ролик (щоб не пошкодити),
    -- швидкий елеватор (картопля важка, треба витягнути)
    root_potato = {
        fan    = {optimal = 35, min = 15, max = 55, tolerance = 8},   -- Низький: земля прилипає, не дме
        rotor  = {optimal = 40, min = 20, max = 60, tolerance = 8},   -- Повільно: картопля м'яка, легко пошкодити
        feeder = {optimal = 70, min = 50, max = 90, tolerance = 8},   -- Швидко: важка, треба підняти
    },
    
    -- Цукровий буряк: важчий від картоплі, витримує більше
    root_sugarbeet = {
        fan    = {optimal = 40, min = 20, max = 60, tolerance = 8},
        rotor  = {optimal = 55, min = 35, max = 75, tolerance = 8},   -- Трохи швидше: буряк твердіший
        feeder = {optimal = 65, min = 45, max = 85, tolerance = 8},
    },
    
    -- Буряк (звичайний): між картоплею та цукровим
    root_beetroot = {
        fan    = {optimal = 38, min = 18, max = 58, tolerance = 8},
        rotor  = {optimal = 48, min = 28, max = 68, tolerance = 8},
        feeder = {optimal = 68, min = 48, max = 88, tolerance = 8},
    },
    
    -- Цибуля: ПОТРІБЕН СИЛЬНИЙ ОБДУВ для відокремлення шкірок та гички
    root_onion = {
        fan    = {optimal = 75, min = 55, max = 95, tolerance = 8},   -- Висока: відокремлює шкірку і листя
        rotor  = {optimal = 45, min = 25, max = 65, tolerance = 8},   -- Помірно: цибуля ніжна
        feeder = {optimal = 55, min = 35, max = 75, tolerance = 8},
    },
    
    -- Морква / Пастернак: коренеплоди в землі, потрібна обережна очистка
    root_carrot = {
        fan    = {optimal = 30, min = 10, max = 50, tolerance = 8},   -- Низький: морква легка, здується
        rotor  = {optimal = 35, min = 15, max = 55, tolerance = 8},   -- Дуже повільно: крихка коренева
        feeder = {optimal = 75, min = 55, max = 95, tolerance = 8},   -- Швидко: транспортувати нагору
    },
    
    -- Шпинат: найніжніша культура, листя легко пошкодити
    root_spinach = {
        fan    = {optimal = 20, min = 5,  max = 40, tolerance = 5},   -- Мінімальний: листя летить
        rotor  = {optimal = 25, min = 10, max = 45, tolerance = 5},   -- Дуже повільно: листя рветься
        feeder = {optimal = 60, min = 40, max = 80, tolerance = 8},   -- Помірно: деліка транспортування
    },
    
    -- Зелена квасоля: ніжна стручкова
    root_greenbean = {
        fan    = {optimal = 45, min = 25, max = 65, tolerance = 8},   -- Помірний: відокремити листя
        rotor  = {optimal = 38, min = 18, max = 58, tolerance = 8},   -- Повільно: стручки ламаються
        feeder = {optimal = 62, min = 42, max = 82, tolerance = 8},
    },

    -- Загальний fallback для root (якщо нова культура без власного шаблону)
    root_harvest = {
        fan    = {optimal = 45, min = 25, max = 65, tolerance = 10},
        rotor  = {optimal = 50, min = 30, max = 70, tolerance = 10},
        feeder = {optimal = 55, min = 35, max = 75, tolerance = 10},
    },

    -- Chickpea (Garbanzos) - Rotor 300-500 = 400 = 22%, Fan 800-1100 = 950 = 72%, Chaffer 14mm = 47%, Sieve 8mm = 32%
    chickpea = {
        fan = {optimal = 72, min = 55, max = 85, tolerance = 8},
        upperSieve = {optimal = 47, min = 35, max = 60, tolerance = 5},
        lowerSieve = {optimal = 32, min = 20, max = 45, tolerance = 4},
        rotor = {optimal = 22, min = 10, max = 35, tolerance = 5},
        concave = {optimal = 70, min = 55, max = 85, tolerance = 8},
    },

    -- Lentil (Lentejas) - Rotor 300-500 = 400 = 22%, Fan 700-850 = 775 = 53%, Chaffer 12.5mm = 42%, Sieve 5.5mm = 22%
    lentil = {
        fan = {optimal = 53, min = 40, max = 65, tolerance = 7},
        upperSieve = {optimal = 42, min = 30, max = 55, tolerance = 6},
        lowerSieve = {optimal = 22, min = 10, max = 35, tolerance = 6},
        rotor = {optimal = 22, min = 10, max = 35, tolerance = 5},
        concave = {optimal = 70, min = 55, max = 85, tolerance = 8},
    },

    -- Flax / Linseed - Drum speed 640-800 = 720 = 58%, Fan 600 = 33%, Chaffer 10mm = 33%, Sieve 4mm = 16%
    flax = {
        fan = {optimal = 33, min = 20, max = 50, tolerance = 7},
        upperSieve = {optimal = 33, min = 20, max = 50, tolerance = 5},
        lowerSieve = {optimal = 16, min = 5, max = 30, tolerance = 5},
        rotor = {optimal = 58, min = 45, max = 70, tolerance = 6},
        concave = {optimal = 20, min = 10, max = 35, tolerance = 6},   -- tight: ~10mm
    },

    -- Mustard / Buckwheat - Drum speed 480-520 = 500 = 33%, Fan 550 = 28%, Chaffer 17mm = 57%, Sieve 8mm = 32%
    mustard = {
        fan = {optimal = 28, min = 15, max = 45, tolerance = 6},
        upperSieve = {optimal = 57, min = 40, max = 75, tolerance = 5},
        lowerSieve = {optimal = 32, min = 20, max = 45, tolerance = 5},
        rotor = {optimal = 33, min = 20, max = 50, tolerance = 6},
        concave = {optimal = 20, min = 10, max = 35, tolerance = 6},
    },

    -- Clover - MAXIMUM Drum speed 1100 = 100%, MAX fan 1200 = 100%, Chaffer 4mm = 13%, Sieve 2mm = 8%
    clover = {
        fan = {optimal = 100, min = 85, max = 100, tolerance = 5},
        upperSieve = {optimal = 13, min = 5, max = 25, tolerance = 5},
        lowerSieve = {optimal = 8, min = 0, max = 20, tolerance = 5},
        rotor = {optimal = 100, min = 85, max = 100, tolerance = 5},
        concave = {optimal = 10, min = 0, max = 25, tolerance = 5},    -- very tight: ~5mm
    },

    -- Grass Seed - MAX Drum (Fine) 920 = 80%, Fan 650 = 39%, Chaffer 5mm = 17%, Sieve 3mm = 12%
    grass_seed = {
        fan = {optimal = 39, min = 25, max = 55, tolerance = 7},
        upperSieve = {optimal = 17, min = 5, max = 30, tolerance = 5},
        lowerSieve = {optimal = 12, min = 0, max = 25, tolerance = 5},
        rotor = {optimal = 80, min = 65, max = 95, tolerance = 6},
        concave = {optimal = 15, min = 5, max = 30, tolerance = 5},
    },

    -- ============================
    -- COTTON HARVESTER TEMPLATES
    -- ============================
    cotton_picker = {
        fan = {optimal = 80, min = 60, max = 100, tolerance = 10},
        rotor = {optimal = 70, min = 50, max = 90, tolerance = 10},
        feeder = {optimal = 60, min = 40, max = 80, tolerance = 10},
    },
}
-- EN: Active parameters per machine type. Defines which parameter sliders appear in the calibration GUI.
-- UA: Активні параметри для кожного типу машини. Визначає які повзунки параметрів відображаються в GUI калібрування.

---Active parameters per machine type (defines which sliders appear in GUI)
CombineSettingsDatabase.machineParams = {
    grain   = { "fan", "rotor", "upperSieve", "lowerSieve", "concave" },  -- concave = 0-50mm clearance
    forage  = { "fan", "rotor", "feeder" },
    root    = { "fan", "rotor", "feeder" },
    cotton  = { "fan", "rotor", "feeder" },
}

---L10n key overrides for parameter labels per machine type
---Falls back to generic "rhm_ui_<param>" if no override defined
CombineSettingsDatabase.machineParamLabels = {
    grain = {
        fan        = "rhm_ui_fan_speed",
        rotor      = "rhm_ui_rotor_speed",
        upperSieve = "rhm_ui_upper_sieve",
        lowerSieve = "rhm_ui_lower_sieve",
        concave    = "rhm_ui_concave_gap",  -- 0-50mm clearance
    },
    forage = {
        fan    = "rhm_ui_forage_fan",
        rotor  = "rhm_ui_forage_drum",
        feeder = "rhm_ui_forage_feeder",
    },
    root = {
        fan    = "rhm_ui_fan_speed",
        rotor  = "rhm_ui_root_roller",
        feeder = "rhm_ui_root_feeder",
    },
    cotton = {
        fan    = "rhm_ui_fan_speed",
        rotor  = "rhm_ui_picker_speed",  -- Picker/spindle
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
