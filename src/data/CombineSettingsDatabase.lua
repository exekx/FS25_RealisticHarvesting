---@class CombineSettingsDatabase
CombineSettingsDatabase = {}

---Базові шаблони для груп культур
---Кожен параметр має: optimal (оптимум), min/max (діапазон), tolerance (допустиме відхилення)
local templates = {
    -- Середні зернові (пшениця, ячмінь)
    grain_medium = {
        fan = {optimal = 65, min = 50, max = 80, tolerance = 10},
        upperSieve = {optimal = 60, min = 50, max = 70, tolerance = 8},
        lowerSieve = {optimal = 70, min = 60, max = 80, tolerance = 8},
        rotor = {optimal = 75, min = 65, max = 85, tolerance = 8},
        feeder = {optimal = 50, min = 30, max = 70, tolerance = 15},
    },
    
    -- Легкі зернові (овес)
    grain_light = {
        fan = {optimal = 70, min = 55, max = 85, tolerance = 10},
        upperSieve = {optimal = 65, min = 55, max = 75, tolerance = 8},
        lowerSieve = {optimal = 75, min = 65, max = 85, tolerance = 8},
        rotor = {optimal = 80, min = 70, max = 90, tolerance = 8},
        feeder = {optimal = 55, min = 35, max = 75, tolerance = 15},
    },
    
    -- Легкі олійні (ріпак)
    oilseed_light = {
        fan = {optimal = 45, min = 30, max = 60, tolerance = 8},
        upperSieve = {optimal = 40, min = 30, max = 50, tolerance = 6},
        lowerSieve = {optimal = 50, min = 40, max = 60, tolerance = 6},
        rotor = {optimal = 60, min = 50, max = 70, tolerance = 8},
        feeder = {optimal = 40, min = 25, max = 55, tolerance = 12},
    },
    
    -- Важкі олійні (соняшник)
    oilseed_heavy = {
        fan = {optimal = 55, min = 40, max = 70, tolerance = 10},
        upperSieve = {optimal = 70, min = 60, max = 80, tolerance = 8},
        lowerSieve = {optimal = 80, min = 70, max = 90, tolerance = 8},
        rotor = {optimal = 65, min = 55, max = 75, tolerance = 8},
        feeder = {optimal = 60, min = 45, max = 75, tolerance = 12},
    },
    
    -- Кукурудза
    corn = {
        fan = {optimal = 85, min = 70, max = 95, tolerance = 8},
        upperSieve = {optimal = 80, min = 70, max = 90, tolerance = 8},
        lowerSieve = {optimal = 85, min = 75, max = 95, tolerance = 8},
        rotor = {optimal = 90, min = 80, max = 100, tolerance = 6},
        feeder = {optimal = 70, min = 55, max = 85, tolerance = 12},
    },
    
    -- Бобові (соя)
    legume = {
        fan = {optimal = 50, min = 35, max = 65, tolerance = 10},
        upperSieve = {optimal = 50, min = 40, max = 60, tolerance = 8},
        lowerSieve = {optimal = 60, min = 50, max = 70, tolerance = 8},
        rotor = {optimal = 55, min = 45, max = 65, tolerance = 8},
        feeder = {optimal = 35, min = 20, max = 50, tolerance = 12},
    },
    -- Рис
    rice = {
        fan = {optimal = 80, min = 70, max = 90, tolerance = 10},
        upperSieve = {optimal = 70, min = 60, max = 80, tolerance = 8},
        lowerSieve = {optimal = 70, min = 60, max = 80, tolerance = 8},
        rotor = {optimal = 85, min = 75, max = 95, tolerance = 8},
        feeder = {optimal = 60, min = 40, max = 80, tolerance = 15},
    },
}

---Прив'язка культур до шаблонів та fillType з гри
CombineSettingsDatabase.crops = {
    -- Зернові
    ["WHEAT"] = { name = "Пшениця", nameEN = "Wheat", template = templates.grain_medium, group = "grain", fillType = FillType.WHEAT },
    ["BARLEY"] = { name = "Ячмінь", nameEN = "Barley", template = templates.grain_medium, group = "grain", fillType = FillType.BARLEY },
    ["OAT"] = { name = "Овес", nameEN = "Oat", template = templates.grain_light, group = "grain", fillType = FillType.OAT },
    ["SORGHUM"] = { name = "Сорго", nameEN = "Sorghum", template = templates.grain_medium, group = "grain", fillType = FillType.SORGHUM },
    
    -- Рис
    ["RICE"] = { name = "Рис", nameEN = "Rice", template = templates.rice, group = "rice", fillType = FillType.RICE },
    ["RICE_LONG_GRAIN"] = { name = "Рис (довгозерний)", nameEN = "Rice (Long Grain)", template = templates.rice, group = "rice", fillType = FillType.RICE_LONG_GRAIN },
    
    -- Олійні
    ["CANOLA"] = { name = "Ріпак", nameEN = "Canola", template = templates.oilseed_light, group = "oilseed", fillType = FillType.CANOLA },
    ["SUNFLOWER"] = { name = "Соняшник", nameEN = "Sunflower", template = templates.oilseed_heavy, group = "oilseed", fillType = FillType.SUNFLOWER },
    
    -- Кукурудза
    ["CORN"] = { name = "Кукурудза", nameEN = "Corn", template = templates.corn, group = "corn", fillType = FillType.MAIZE },
    
    -- Бобові
    ["SOYBEAN"] = { name = "Соя", nameEN = "Soybean", template = templates.legume, group = "legume", fillType = FillType.SOYBEAN },
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
