---@class CombineSettingsDatabase
CombineSettingsDatabase = {}

---Базові шаблони для груп культур
---Кожен параметр має: optimal (оптимум), min/max (діапазон), tolerance (допустиме відхилення)
local templates = {
    -- Середні зернові (пшениця, ячмінь)
    grain_medium = {
        fan = {optimal = 65, min = 50, max = 80, tolerance = 7},  -- Was 10
        upperSieve = {optimal = 60, min = 50, max = 70, tolerance = 6}, -- Was 8
        lowerSieve = {optimal = 70, min = 60, max = 80, tolerance = 6}, -- Was 8
        rotor = {optimal = 75, min = 65, max = 85, tolerance = 6}, -- Was 8
        feeder = {optimal = 50, min = 30, max = 70, tolerance = 10},-- Was 15
    },
    
    -- Легкі зернові (овес)
    grain_light = {
        fan = {optimal = 70, min = 55, max = 85, tolerance = 7},
        upperSieve = {optimal = 65, min = 55, max = 75, tolerance = 6},
        lowerSieve = {optimal = 75, min = 65, max = 85, tolerance = 6},
        rotor = {optimal = 80, min = 70, max = 90, tolerance = 6},
        feeder = {optimal = 55, min = 35, max = 75, tolerance = 10},
    },
    
    -- Легкі олійні (ріпак)
    oilseed_light = {
        fan = {optimal = 45, min = 30, max = 60, tolerance = 6}, -- Was 8
        upperSieve = {optimal = 40, min = 30, max = 50, tolerance = 4}, -- Was 6
        lowerSieve = {optimal = 50, min = 40, max = 60, tolerance = 4}, -- Was 6
        rotor = {optimal = 60, min = 50, max = 70, tolerance = 6}, -- Was 8
        feeder = {optimal = 40, min = 25, max = 55, tolerance = 8}, -- Was 12
    },
    
    -- Важкі олійні (соняшник)
    oilseed_heavy = {
        fan = {optimal = 55, min = 40, max = 70, tolerance = 7}, -- Was 10
        upperSieve = {optimal = 70, min = 60, max = 80, tolerance = 6},
        lowerSieve = {optimal = 80, min = 70, max = 90, tolerance = 6},
        rotor = {optimal = 65, min = 55, max = 75, tolerance = 6},
        feeder = {optimal = 60, min = 45, max = 75, tolerance = 10},
    },
    
    -- Кукурудза
    corn = {
        fan = {optimal = 85, min = 70, max = 95, tolerance = 6}, -- Was 8
        upperSieve = {optimal = 80, min = 70, max = 90, tolerance = 6},
        lowerSieve = {optimal = 85, min = 75, max = 95, tolerance = 6},
        rotor = {optimal = 90, min = 80, max = 100, tolerance = 5}, -- Was 6
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
}
---Прив'язка культур до шаблонів та fillType з гри
-- FIX: Всі fillType огорнуті в умовний вираз для захисту від nil
-- якщо FillType.WHEAT == nil (DLC/мод не встановлений) -> повертаємо nil безпечно
local function safeFillType(ft)
    return (ft ~= nil and ft ~= 0) and ft or nil
end

CombineSettingsDatabase.crops = {
    -- Зернові
    ["WHEAT"]   = { name = "Пшениця",            nameEN = "Wheat",            template = templates.grain_medium,        group = "grain",       fillType = safeFillType(FillType.WHEAT) },
    ["BARLEY"]  = { name = "Ячмінь",             nameEN = "Barley",           template = templates.grain_medium,        group = "grain",       fillType = safeFillType(FillType.BARLEY) },
    ["OAT"]     = { name = "Овес",               nameEN = "Oat",              template = templates.grain_light,         group = "grain",       fillType = safeFillType(FillType.OAT) },
    ["SORGHUM"] = { name = "Сорго",              nameEN = "Sorghum",          template = templates.grain_medium,        group = "grain",       fillType = safeFillType(FillType.SORGHUM) },
    
    -- Рис
    ["RICE"]            = { name = "Рис",               nameEN = "Rice",             template = templates.rice,                group = "rice",        fillType = safeFillType(FillType.RICE) },
    ["RICE_LONG_GRAIN"] = { name = "Рис (довгозерний)", nameEN = "Rice (Long Grain)", template = templates.rice,               group = "rice",        fillType = safeFillType(FillType.RICE_LONG_GRAIN) },
    
    -- Олійні
    ["CANOLA"]    = { name = "Ріпак",             nameEN = "Canola",          template = templates.oilseed_light,       group = "oilseed",     fillType = safeFillType(FillType.CANOLA) },
    ["SUNFLOWER"] = { name = "Соняшник",          nameEN = "Sunflower",       template = templates.oilseed_heavy,       group = "oilseed",     fillType = safeFillType(FillType.SUNFLOWER) },
    
    -- Кукурудза
    ["CORN"] = { name = "Кукурудза", nameEN = "Corn", template = templates.corn, group = "corn", fillType = safeFillType(FillType.MAIZE) },
    
    -- Бобові
    ["SOYBEAN"]  = { name = "Соя",           nameEN = "Soybean",   template = templates.legume, group = "legume", fillType = safeFillType(FillType.SOYBEAN) },
    ["PEA"]      = { name = "Горох",         nameEN = "Peas",      template = templates.legume, group = "legume", fillType = safeFillType(FillType.PEA) },
    ["LENTIL"]   = { name = "Сочевиця",      nameEN = "Lentil",    template = templates.legume, group = "legume", fillType = nil },  -- Mod crop
    ["CHICKPEA"] = { name = "Нут",           nameEN = "Chickpea",  template = templates.legume, group = "legume", fillType = nil },  -- Mod crop

    -- Додаткові зернові (Mod crops) — fillType = nil (не стандартні в FS25)
    ["RYE"]       = { name = "Жито",     nameEN = "Rye",       template = templates.grain_medium, group = "grain_medium", fillType = nil },
    ["SPELT"]     = { name = "Спельта",  nameEN = "Spelt",     template = templates.grain_light,  group = "grain_light",  fillType = nil },
    ["TRITICALE"] = { name = "Тритикале",nameEN = "Triticale", template = templates.grain_medium, group = "grain_medium", fillType = nil },
    ["MILLET"]    = { name = "Просо",    nameEN = "Millet",    template = templates.grain_light,  group = "grain_light",  fillType = nil },
    ["BUCKWHEAT"] = { name = "Гречка",   nameEN = "Buckwheat", template = templates.grain_medium, group = "grain_medium", fillType = nil },
    
    -- Додаткові олійні (Mod crops)
    ["LINSEED"] = { name = "Льон",     nameEN = "Linseed/Flax", template = templates.oilseed_light, group = "oilseed_light", fillType = nil },
    ["MUSTARD"] = { name = "Гірчиця", nameEN = "Mustard",       template = templates.oilseed_light, group = "oilseed_light", fillType = nil },
    ["POPPY"]   = { name = "Мак",     nameEN = "Poppy",         template = templates.oilseed_light, group = "oilseed_light", fillType = nil },
    
    -- Волокнисті (Mod crops)
    ["HEMP"] = { name = "Коноплі (зерно)", nameEN = "Hemp", template = templates.oilseed_heavy, group = "oilseed_heavy", fillType = nil },
    
    -- Root & Veg
    ["POTATO"]    = { name = "Картопля",       nameEN = "Potato",    template = templates.root_heavy,        group = "root",      fillType = safeFillType(FillType.POTATO) },
    ["SUGARBEET"] = { name = "Цукровий Буряк", nameEN = "Sugarbeet", template = templates.root_heavy,        group = "root",      fillType = safeFillType(FillType.SUGARBEET) },
    ["BEETROOT"]  = { name = "Буряк",          nameEN = "Beetroot",  template = templates.root_heavy,        group = "root",      fillType = safeFillType(FillType.BEETROOT) },
    
    ["CARROT"]  = { name = "Морква",   nameEN = "Carrot",  template = templates.root_light,       group = "root",      fillType = safeFillType(FillType.CARROT) },
    ["PARSNIP"] = { name = "Пастернак",nameEN = "Parsnip", template = templates.root_light,       group = "root",      fillType = safeFillType(FillType.PARSNIP) },
    
    ["ONION"]    = { name = "Цибуля",        nameEN = "Onion",      template = templates.vegetable_sensitive, group = "vegetable", fillType = safeFillType(FillType.ONION) },
    ["SPINACH"]  = { name = "Шпинат",        nameEN = "Spinach",    template = templates.leafy,               group = "vegetable", fillType = safeFillType(FillType.SPINACH) },
    ["GREENBEAN"]= { name = "Зелена Квасоля",nameEN = "Green Bean", template = templates.legume,              group = "legume",    fillType = safeFillType(FillType.GREENBEAN) },
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
    -- Отримуємо назву fillType з гри
    if not g_fillTypeManager then
        return nil
    end
    
    local fillTypeObj = g_fillTypeManager:getFillTypeByIndex(fillType)
    if not fillTypeObj or not fillTypeObj.name then
        return nil
    end
    
    local fillTypeName = fillTypeObj.name
    
    -- Шукаємо crop за назвою fillType
    -- Маппінг: fillType.name -> cropName
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
        ["FLAX"] = "LINSEED", -- Alias
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
    }
    
    return fillTypeMapping[fillTypeName]
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
