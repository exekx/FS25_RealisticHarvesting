---@class CombineSettingsDatabase
CombineSettingsDatabase = {}

---Базові шаблони для груп культур
---Кожен параметр має: optimal (оптимум), min/max (діапазон), tolerance (допустиме відхилення)
local templates = {
    -- Середні зернові (пшениця, ячмінь)
    -- Wheat / Triticale / Rye / Spelt - High rotor (850 rpm), High fan (800 rpm)
    wheat = {
        fan = {optimal = 78, min = 65, max = 90, tolerance = 7},
        upperSieve = {optimal = 55, min = 40, max = 70, tolerance = 6},
        lowerSieve = {optimal = 45, min = 30, max = 60, tolerance = 6},
        rotor = {optimal = 80, min = 65, max = 95, tolerance = 6},
        feeder = {optimal = 50, min = 35, max = 65, tolerance = 10},
    },

    -- Barley - High rotor (900 rpm), High fan (800 rpm)
    barley = {
        fan = {optimal = 78, min = 65, max = 90, tolerance = 7},
        upperSieve = {optimal = 60, min = 45, max = 75, tolerance = 6},
        lowerSieve = {optimal = 50, min = 35, max = 65, tolerance = 6},
        rotor = {optimal = 85, min = 70, max = 100, tolerance = 6},
        feeder = {optimal = 50, min = 35, max = 65, tolerance = 10},
    },

    -- Oat - High rotor (800 rpm), High fan (800 rpm)
    oat = {
        fan = {optimal = 78, min = 65, max = 90, tolerance = 7},
        upperSieve = {optimal = 65, min = 50, max = 80, tolerance = 6},
        lowerSieve = {optimal = 55, min = 40, max = 70, tolerance = 6},
        rotor = {optimal = 75, min = 60, max = 90, tolerance = 6},
        feeder = {optimal = 55, min = 40, max = 70, tolerance = 10},
    },
    
    -- Легкі зернові (овес)
    -- Canola (Rape Seed) - Medium-Low rotor (500 rpm), High fan (700 rpm)
    canola = {
        fan = {optimal = 70, min = 55, max = 85, tolerance = 6},
        upperSieve = {optimal = 50, min = 35, max = 65, tolerance = 4},
        lowerSieve = {optimal = 40, min = 25, max = 55, tolerance = 4},
        rotor = {optimal = 50, min = 40, max = 60, tolerance = 6},
        feeder = {optimal = 45, min = 30, max = 60, tolerance = 8},
    },
    
    -- Легкі олійні (ріпак)
    -- Soya Bean - Medium rotor (550 rpm), High fan (750 rpm)
    soybean = {
        fan = {optimal = 75, min = 60, max = 90, tolerance = 7},
        upperSieve = {optimal = 55, min = 40, max = 70, tolerance = 6},
        lowerSieve = {optimal = 45, min = 30, max = 60, tolerance = 6},
        rotor = {optimal = 55, min = 45, max = 65, tolerance = 6},
        feeder = {optimal = 45, min = 30, max = 60, tolerance = 8},
    },
    
    -- Важкі олійні (соняшник)
    -- Sunflower - LOW rotor (320 rpm), Medium-High fan (700 rpm)
    sunflower = {
        fan = {optimal = 70, min = 55, max = 85, tolerance = 7},
        upperSieve = {optimal = 70, min = 55, max = 85, tolerance = 6},
        lowerSieve = {optimal = 60, min = 45, max = 75, tolerance = 6},
        rotor = {optimal = 32, min = 22, max = 42, tolerance = 5},
        feeder = {optimal = 60, min = 45, max = 75, tolerance = 10},
    },

    -- Sorghum - Medium-High rotor (640 rpm), High fan (750-800 rpm)
    sorghum = {
        fan = {optimal = 78, min = 65, max = 90, tolerance = 7},
        upperSieve = {optimal = 55, min = 40, max = 70, tolerance = 6},
        lowerSieve = {optimal = 50, min = 35, max = 65, tolerance = 6},
        rotor = {optimal = 64, min = 54, max = 74, tolerance = 6},
        feeder = {optimal = 50, min = 35, max = 65, tolerance = 10},
    },
    
    -- Кукурудза
    -- Maize (Corn) - LOW rotor (350 rpm), VERY High fan (920 rpm), Wide sieves
    corn = {
        fan = {optimal = 92, min = 80, max = 100, tolerance = 6},
        upperSieve = {optimal = 75, min = 60, max = 90, tolerance = 6},
        lowerSieve = {optimal = 65, min = 50, max = 80, tolerance = 6},
        rotor = {optimal = 35, min = 25, max = 45, tolerance = 5},
        feeder = {optimal = 70, min = 55, max = 85, tolerance = 10},
    },
    
    -- Бобові (соя)
    legume = {
        fan = {optimal = 50, min = 35, max = 65, tolerance = 7},
        upperSieve = {optimal = 50, min = 40, max = 60, tolerance = 6},
        lowerSieve = {optimal = 60, min = 50, max = 70, tolerance = 6},
        rotor = {optimal = 55, min = 45, max = 65, tolerance = 6},
        feeder = {optimal = 35, min = 20, max = 50, tolerance = 8},
    },
    -- Rice
    rice = {
        fan = {optimal = 80, min = 70, max = 90, tolerance = 7},
        upperSieve = {optimal = 70, min = 60, max = 80, tolerance = 6},
        lowerSieve = {optimal = 70, min = 60, max = 80, tolerance = 6},
        rotor = {optimal = 85, min = 75, max = 95, tolerance = 6},
        feeder = {optimal = 60, min = 40, max = 80, tolerance = 12}, -- Was 15
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

    -- Chickpea (Garbanzos) - Technical data: Rotor 300-500 (40%), Fan 800-1100 (95%)
    chickpea = {
        fan = {optimal = 95, min = 80, max = 110, tolerance = 8},
        upperSieve = {optimal = 75, min = 60, max = 90, tolerance = 5},
        lowerSieve = {optimal = 60, min = 45, max = 75, tolerance = 4},
        rotor = {optimal = 40, min = 30, max = 55, tolerance = 5},
        feeder = {optimal = 70, min = 55, max = 85, tolerance = 8},
    },

    -- Lentil (Lentejas) - Technical data: Rotor 300-500 (40%), Fan 700-850 (80%)
    lentil = {
        fan = {optimal = 80, min = 70, max = 90, tolerance = 7},
        upperSieve = {optimal = 65, min = 50, max = 80, tolerance = 6},
        lowerSieve = {optimal = 55, min = 40, max = 70, tolerance = 6},
        rotor = {optimal = 40, min = 30, max = 55, tolerance = 5},
        feeder = {optimal = 70, min = 55, max = 85, tolerance = 8},
    },

    -- Flax / Linseed - Medium rotor (700 rpm), High fan (800 rpm)
    flax = {
        fan = {optimal = 80, min = 65, max = 95, tolerance = 7},
        upperSieve = {optimal = 55, min = 40, max = 70, tolerance = 5},
        lowerSieve = {optimal = 45, min = 30, max = 60, tolerance = 5},
        rotor = {optimal = 70, min = 55, max = 85, tolerance = 6},
        feeder = {optimal = 45, min = 30, max = 60, tolerance = 8},
    },

    -- Mustard / Buckwheat - Medium rotor (500 rpm), Medium-Low fan (550 rpm)
    mustard = {
        fan = {optimal = 55, min = 40, max = 70, tolerance = 6},
        upperSieve = {optimal = 45, min = 35, max = 60, tolerance = 5},
        lowerSieve = {optimal = 35, min = 25, max = 50, tolerance = 5},
        rotor = {optimal = 50, min = 40, max = 65, tolerance = 6},
        feeder = {optimal = 40, min = 25, max = 55, tolerance = 8},
    },

    -- Clover - MAX rotor, MIN fan, very tight concave
    clover = {
        fan = {optimal = 20, min = 5, max = 40, tolerance = 5},
        upperSieve = {optimal = 35, min = 20, max = 50, tolerance = 5},
        lowerSieve = {optimal = 25, min = 15, max = 40, tolerance = 5},
        rotor = {optimal = 100, min = 90, max = 100, tolerance = 5},
        feeder = {optimal = 35, min = 20, max = 50, tolerance = 8},
    },

    -- Grass Seed - MAX rotor (920 rpm), High fan (800 rpm)
    grass_seed = {
        fan = {optimal = 80, min = 65, max = 95, tolerance = 7},
        upperSieve = {optimal = 40, min = 25, max = 55, tolerance = 5},
        lowerSieve = {optimal = 30, min = 20, max = 45, tolerance = 5},
        rotor = {optimal = 92, min = 80, max = 100, tolerance = 6},
        feeder = {optimal = 45, min = 30, max = 60, tolerance = 8},
    },
}
---@field machineParams table Active parameters per machine type
---@field machineParamLabels table L10n keys for parameter labels per machine type

---Active parameters per machine type (defines which sliders appear in GUI)
CombineSettingsDatabase.machineParams = {
    grain   = { "fan", "rotor", "upperSieve", "lowerSieve", "feeder" },
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
        feeder     = "rhm_ui_feeder_speed",
    },
    forage = {
        fan    = "rhm_ui_fan_speed",
        rotor  = "rhm_ui_drum_speed",    -- Drum, not Rotor
        feeder = "rhm_ui_feeder_speed",
    },
    root = {
        fan    = "rhm_ui_fan_speed",
        rotor  = "rhm_ui_roller_speed",  -- Roller/cleaning drum
        feeder = "rhm_ui_feeder_speed",
    },
    cotton = {
        fan    = "rhm_ui_fan_speed",
        rotor  = "rhm_ui_picker_speed",  -- Picker/spindle
        feeder = "rhm_ui_feeder_speed",
    },
}

---Get active parameter names for a machine type
---@param machineType string  "grain"|"forage"|"root"|"cotton"
---@return table params Ordered list of active parameter names
function CombineSettingsDatabase:getParamsForMachineType(machineType)
    return self.machineParams[machineType] or self.machineParams.grain
end

---Get l10n key for a parameter label given machine type
---@param machineType string
---@param paramName string
---@return string l10nKey
function CombineSettingsDatabase:getParamLabel(machineType, paramName)
    local labels = self.machineParamLabels[machineType]
    if labels and labels[paramName] then
        return labels[paramName]
    end
    return "rhm_ui_" .. paramName
end

-- FIX: Всі fillType огорнуті в умовний вираз для захисту від nil
-- якщо FillType.WHEAT == nil (DLC/мод не встановлений) -> повертаємо nil безпечно
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

---Отримати налаштування для культури за назвою
---@param cropName string Назва культури (наприклад "WHEAT")
---@return table|nil settings Таблиця з налаштуваннями або nil якщо не знайдено
function CombineSettingsDatabase:getSettingsForCrop(cropName)
    local crop = self.crops[cropName]
    if crop then
        return crop.template
    end
    return nil
end

---Отримати назву культури за fillType з гри
---@param fillType number FillType з гри
---@return string|nil cropName Назва культури або nil
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

---Отримати дані про культуру за назвою
---@param cropName string Назва культури
---@return table|nil cropData Повні дані про культуру
function CombineSettingsDatabase:getCropData(cropName)
    return self.crops[cropName]
end

---Отримати список всіх доступних культур
---@return table cropNames Масив назв культур
function CombineSettingsDatabase:getAllCropNames()
    local names = {}
    for cropName, _ in pairs(self.crops) do
        table.insert(names, cropName)
    end
    table.sort(names)
    return names
end

---Отримати список культур для конкретного типу машини
---@param machineType string "grain"|"forage"|"root"|"cotton"
---@return table cropNames Відсортований масив назв культур для цього типу
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

---Розрахувати передбачувані втрати врожаю для культури з поточними налаштуваннями
---@param cropName string Назва культури
---@param settings table Поточні налаштування {fan=N, rotor=N, ...}
---@return number totalPenalty Загальний штраф (%),  table warnings Список попереджень
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

---Перевірити чи налаштування в межах допустимого діапазону
---@param cropName string Назва культури
---@param paramName string Назва параметру (fan, upperSieve, etc)
---@param value number Значення параметру
---@return boolean isValid Чи значення в допустимому діапазоні
function CombineSettingsDatabase:isValueValid(cropName, paramName, value)
    local settings = self:getSettingsForCrop(cropName)
    if not settings or not settings[paramName] then
        return false
    end
    
    local param = settings[paramName]
    return value >= param.min and value <= param.max
end

print("[OK] CombineSettingsDatabase loaded with " .. #CombineSettingsDatabase:getAllCropNames() .. " crops")
