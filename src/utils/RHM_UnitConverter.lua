-- EN: Utility module for converting and formatting values between metric, imperial, and bushel unit systems.
--     Handles speed (km/h ↔ mph), productivity (t/h ↔ ton/h ↔ bu/h), area (ha ↔ ac),
--     yield (t/ha ↔ t/ac ↔ bu/ac), and physical unit display for combine settings (RPM, mm).
-- UA: Утилітний модуль для конвертування та форматування значень між метричною, американською та бушельною системами.
--     EN: Handles speed (km/h <-> mph), productivity (t/h <-> ton/h <-> bu/h),
--     UA: Обробляє швидкість (км/год <-> миль/год), продуктивність (т/год <-> тон/год <-> буш/год),
--     EN: area (ha <-> acres), yield (t/ha <-> t/acre <-> bu/acre), and physical combine setting units (RPM, mm).
--     UA: площу (га <-> акри), врожайність (т/га <-> т/акр <-> буш/акр) та фізичні одиниці налаштувань комбайна (RPM, мм).
RHM_UnitConverter = {}

-- EN: Unit system ID constants.
-- UA: Константи ідентифікаторів системи одиниць.
RHM_UnitConverter.SYSTEM_METRIC = 1
RHM_UnitConverter.SYSTEM_IMPERIAL = 2
RHM_UnitConverter.SYSTEM_BUSHELS = 3

-- EN: Base conversion factors between unit systems.
-- UA: Базові коефіцієнти конвертування між системами одиниць.
RHM_UnitConverter.KMH_TO_MPH = 0.621371
RHM_UnitConverter.TONNE_TO_TON = 1.10231
RHM_UnitConverter.HECTARE_TO_ACRE = 2.47105

-- EN: Table of crop-specific bushel coefficients (initialized lazily after mission load).
--     Key = FruitType ID, Value = bushels per tonne.
-- UA: Таблиця коефіцієнтів бушелів для кожної культури (ліниво ініціалізується після завантаження місії).
--     EN: Key = Crop type ID, Value = bushels per ton.
--     UA: Ключ = ID типу врожаю, Значення = бушелі на тонну.
RHM_UnitConverter.BUSHEL_COEFFICIENTS = {}

-- EN: Initializes bushel-per-tonne coefficients using standard USDA bushel weights.
--     Must be called after FruitType data is available (i.e. after mission load).
-- UA: Ініціалізує коефіцієнти бушелі/тонна, використовуючи стандартні ваги бушеля USDA.
--     EN: Must be called after FruitType data becomes available (i.e., after mission load).
--     UA: Має бути викликаний після того, як дані FruitType стануть доступні (тобто після завантаження місії).
function RHM_UnitConverter.initBushelCoefficients()
    if not FruitType then
        return
    end

    RHM_UnitConverter.BUSHEL_COEFFICIENTS = {}

    local function addCoef(name, val)
        if FruitType[name] then RHM_UnitConverter.BUSHEL_COEFFICIENTS[FruitType[name]] = val end
    end

    -- EN: Standard USDA bushel weights for each supported crop (bu/tonne).
    -- UA: Стандартні ваги бушелів USDA для кожної підтримуваної культури (буш/тонна).
    addCoef("WHEAT", 36.76)
    addCoef("BARLEY", 45.87)
    addCoef("OAT", 68.97)
    addCoef("RICE", 49.02)
    addCoef("RICELONGGRAIN", 49.02)
    addCoef("SORGHUM", 39.37)
    addCoef("SOYBEAN", 36.76)
    addCoef("CANOLA", 44.05)
    addCoef("SUNFLOWER", 88.50)
    addCoef("MAIZE", 39.37)
    addCoef("COTTON", 62.89)
    addCoef("SUGARBEET", 44.05)
    addCoef("POTATO", 36.76)
    addCoef("GRASS", 40.0)
    addCoef("DRYGRASS", 40.0)
end

-- EN: Default bushel coefficient used when a crop is not found in the coefficients table (wheat equivalent).
-- UA: Коефіцієнт бушеля за замовчуванням, якщо культура не знайдена в таблиці (еквівалент пшениці).
RHM_UnitConverter.BUSHEL_DEFAULT = 36.76

-- EN: Converts a speed value from km/h to the active unit system.
-- UA: Конвертує значення швидкості з км/год у поточну систему одиниць.
function RHM_UnitConverter.convertSpeed(kmh, system)
    if system == RHM_UnitConverter.SYSTEM_IMPERIAL or system == RHM_UnitConverter.SYSTEM_BUSHELS then
        return kmh * RHM_UnitConverter.KMH_TO_MPH, "mph"
    else
        return kmh, "km/h"
    end
end

-- EN: Converts productivity from tonnes/hour to the active unit system.
--     Preferred method uses liters/hour directly for bushel conversion (avoids density approximations).
-- UA: Конвертує продуктивність з тонн/год у поточну систему одиниць.
--     EN: Preferred method uses liters/h directly for bushel conversion (avoids density approximation).
--     UA: Переважний метод використовує літри/год напряму для бушельної конвертації (уникає наближення густини).
function RHM_UnitConverter.convertProductivity(tonnesPerHour, system, fruitType, litersPerHour)
    if system == RHM_UnitConverter.SYSTEM_BUSHELS then
        -- EN: Direct conversion from liters to bushels (1 US Bushel = 35.2391 L).
        -- UA: Пряма конвертація з літрів у бушелі (1 американський бушель = 35.2391 л).
        if litersPerHour and litersPerHour > 0 then
            return litersPerHour / 35.2391, "bu/h"
        end

        -- EN: Fallback: convert from mass using crop-specific bushel coefficient.
        -- UA: Резервний метод: конвертація з маси з використанням коефіцієнту бушеля для культури.
        local coefficient = RHM_UnitConverter.BUSHEL_DEFAULT
        if fruitType and RHM_UnitConverter.BUSHEL_COEFFICIENTS[fruitType] then
            coefficient = RHM_UnitConverter.BUSHEL_COEFFICIENTS[fruitType]
        end
        return tonnesPerHour * coefficient, "bu/h"

    elseif system == RHM_UnitConverter.SYSTEM_IMPERIAL then
        return tonnesPerHour * RHM_UnitConverter.TONNE_TO_TON, "ton/h"
    else
        return tonnesPerHour, "t/h"
    end
end

-- EN: Converts an area value from hectares to the active unit system.
-- UA: Конвертує значення площі з гектарів у поточну систему одиниць.
function RHM_UnitConverter.convertArea(hectares, system)
    if system == RHM_UnitConverter.SYSTEM_IMPERIAL or system == RHM_UnitConverter.SYSTEM_BUSHELS then
        return hectares * RHM_UnitConverter.HECTARE_TO_ACRE, "ac"
    else
        return hectares, "ha"
    end
end

-- EN: Formats a speed value with its unit suffix.
-- UA: Форматує значення швидкості з позначенням одиниці.
function RHM_UnitConverter.formatSpeed(kmh, system)
    local value, suffix = RHM_UnitConverter.convertSpeed(kmh, system)
    return string.format("%.1f %s", value, suffix)
end

-- EN: Formats a productivity value with its unit suffix.
-- UA: Форматує значення продуктивності з позначенням одиниці.
function RHM_UnitConverter.formatProductivity(tonnesPerHour, system, fruitType, litersPerHour)
    local value, suffix = RHM_UnitConverter.convertProductivity(tonnesPerHour, system, fruitType, litersPerHour)
    return string.format("%.1f %s", value, suffix)
end

-- EN: Formats an area value with its unit suffix.
-- UA: Форматує значення площі з позначенням одиниці.
function RHM_UnitConverter.formatArea(hectares, system)
    local value, suffix = RHM_UnitConverter.convertArea(hectares, system)
    return string.format("%.2f %s", value, suffix)
end

-- EN: Returns a human-readable name for the unit system.
-- UA: Повертає зрозумілу назву системи одиниць.
function RHM_UnitConverter.getSystemName(system)
    if system == RHM_UnitConverter.SYSTEM_METRIC then
        return "Metric"
    elseif system == RHM_UnitConverter.SYSTEM_IMPERIAL then
        return "Imperial"
    elseif system == RHM_UnitConverter.SYSTEM_BUSHELS then
        return "Imperial (Bushels)"
    else
        return "Unknown"
    end
end

-- EN: Converts a yield value from t/ha to the active unit system.
--     For bushels: t/ha → bu/ac using crop-specific bushel weight.
--     For imperial: t/ha → t/ac.
-- UA: Конвертує значення врожайності з т/га у поточну систему одиниць.
--     EN: For bushels: t/ha -> bu/acre using crop specific bushel weight.
--     UA: Для бушелів: т/га -> буш/акр з використанням ваги бушеля для культури.
--     EN: For US: t/ha -> t/acre.
--     UA: Для американської: т/га -> т/акр.
function RHM_UnitConverter.convertYield(tPerHa, system, fruitType)
    if system == RHM_UnitConverter.SYSTEM_BUSHELS then
        local buPerTonne = RHM_UnitConverter.BUSHEL_DEFAULT
        if fruitType and RHM_UnitConverter.BUSHEL_COEFFICIENTS[fruitType] then
            buPerTonne = RHM_UnitConverter.BUSHEL_COEFFICIENTS[fruitType]
        end

        local buPerHa = tPerHa * buPerTonne
        local buPerAc = buPerHa / RHM_UnitConverter.HECTARE_TO_ACRE

        return buPerAc, "bu/ac"

    elseif system == RHM_UnitConverter.SYSTEM_IMPERIAL then
        return tPerHa / RHM_UnitConverter.HECTARE_TO_ACRE, "t/ac"
    else
        return tPerHa, "t/ha"
    end
end

-- EN: Formats a yield value with its unit suffix.
-- UA: Форматує значення врожайності з позначенням одиниці.
function RHM_UnitConverter.formatYield(tPerHa, system, fruitType)
    local value, suffix = RHM_UnitConverter.convertYield(tPerHa, system, fruitType)
    return string.format("%.1f %s", value, suffix)
end

-- ===================================================================
-- EN: PHYSICAL SETTINGS DISPLAY — maps backend 0-100 range to real units (RPM, mm).
--     Used in the GUI to show realistic values instead of raw percentages.
-- UA: ВІДОБРАЖЕННЯ ФІЗИЧНИХ НАЛАШТУВАНЬ — відображає діапазон 0-100 у реальні одиниці (RPM, мм).
--     EN: Used in GUI to display realistic values instead of percentages.
--     UA: Використовується в GUI для відображення реалістичних значень замість відсотків.
-- ===================================================================

-- EN: Physical value ranges for each combine parameter, grouped by machine type.
--     These define the real-world operating range that the 0-100% backend maps to.
-- UA: Діапазони фізичних значень для кожного параметру комбайна, згруповані за типом машини.
--     EN: These define the real working range mapped by the 0-100% backend.
--     UA: Вони визначають реальний робочий діапазон, до якого відображується бекенд 0-100%.
RHM_UnitConverter.PHYSICAL_RANGES = {
    grain = {
        fan        = { min = 300,  max = 1200, unit = "RPM", decimals = 0, step = 10 },
        rotor      = { min = 200,  max = 1100, unit = "RPM", decimals = 0, step = 10 },
        upperSieve = { min = 0,    max = 30,   unit = "mm",  decimals = 0, step = 1  },
        lowerSieve = { min = 0,    max = 25,   unit = "mm",  decimals = 0, step = 1  },
        feeder     = { min = 0,    max = 50,   unit = "mm",  decimals = 0, step = 1  },
    },
    forage = {
        fan    = { min = 800,  max = 1500, unit = "RPM", decimals = 0, step = 10 }, -- EN: Intake blower / UA: Вентилятор подачі
        rotor  = { min = 1000, max = 1200, unit = "RPM", decimals = 0, step = 10 }, -- EN: Chopping drum / UA: Барабан подрібнення
        feeder = { min = 200,  max = 600,  unit = "RPM", decimals = 0, step = 10 }, -- EN: Feed rolls / UA: Подавальні ролики
    },
    root = {
        fan    = { min = 400, max = 1000, unit = "RPM", decimals = 0, step = 10 }, -- EN: Separation blower / UA: Відокремлювальний вентилятор
        rotor  = { min = 100, max = 350,  unit = "RPM", decimals = 0, step = 10 }, -- EN: Cleaning rollers / UA: Очищувальні ролики
        feeder = { min = 100, max = 400,  unit = "RPM", decimals = 0, step = 10 }, -- EN: Elevator belt / UA: Стрічка елеватора
    },
    cotton = {
        fan    = { min = 2500, max = 4000, unit = "RPM", decimals = 0, step = 10 }, -- EN: Air system blower / UA: Вентилятор повітряної системи
        rotor  = { min = 150,  max = 250,  unit = "RPM", decimals = 0, step = 10 }, -- EN: Spindle drums / UA: Барабани шпинделів
        feeder = { min = 100,  max = 300,  unit = "RPM", decimals = 0, step = 10 }, -- EN: Feeder / UA: Подача
    }
}

-- EN: Returns the physical range definition for a parameter and machine type combination.
-- UA: Повертає визначення фізичного діапазону для комбінації параметру та типу машини.
function RHM_UnitConverter.getPhysicalRange(paramName, machineType)
    machineType = machineType or "grain"
    local typeRanges = RHM_UnitConverter.PHYSICAL_RANGES[machineType]
    if typeRanges and typeRanges[paramName] then
        return typeRanges[paramName]
    end
    return nil
end

-- EN: Converts a backend percentage (0-100) to the real physical value for the given parameter.
--     Returns raw percentage as fallback if the parameter has no range definition.
-- UA: Конвертує бекенд-відсоток (0-100) у реальне фізичне значення для заданого параметру.
--     EN: Returns raw percentage as fallback if the parameter has no range definition.
--     UA: Повертає сирий відсоток як резервне значення, якщо параметр не має визначення діапазону.
function RHM_UnitConverter.percentToPhysical(paramName, percentage, machineType)
    local range = RHM_UnitConverter.getPhysicalRange(paramName, machineType)
    if not range then
        return percentage
    end
    local safePct = math.max(0, math.min(100, percentage))
    local span = range.max - range.min
    return range.min + (span * (safePct / 100))
end

-- EN: Converts a real physical value back to backend percentage (0-100).
-- UA: Конвертує реальне фізичне значення назад у бекенд-відсоток (0-100).
function RHM_UnitConverter.physicalToPercent(paramName, physicalValue, machineType)
    local range = RHM_UnitConverter.getPhysicalRange(paramName, machineType)
    if not range then
        return physicalValue
    end
    local safeVal = math.max(range.min, math.min(range.max, physicalValue))
    local span = range.max - range.min
    if span <= 0 then return 0 end
    return ((safeVal - range.min) / span) * 100
end

-- EN: Formats a backend percentage into a human-readable string with physical units.
--     Example: 50% fan → "750 RPM". Falls back to "50%" if no range defined.
-- UA: Форматує бекенд-відсоток у зрозумілий рядок з фізичними одиницями.
--     EN: Example: 50% fan -> "750 RPM". Fallback is "50%" if range missing.
--     UA: Приклад: 50% вентилятор -> "750 RPM". Резервне значення "50%" якщо діапазон не визначено.
function RHM_UnitConverter.formatSetting(paramName, percentage, machineType)
    local range = RHM_UnitConverter.getPhysicalRange(paramName, machineType)
    if not range then
        return string.format("%.0f%%", percentage)
    end

    local physVal = RHM_UnitConverter.percentToPhysical(paramName, percentage, machineType)
    
    -- EN: Apply rounding step if defined
    -- UA: Застосовуємо крок округлення, якщо він заданий
    if range.step and range.step > 0 then
        physVal = math.floor((physVal / range.step) + 0.5) * range.step
    end

    local fmt = "%." .. tostring(range.decimals) .. "f %s"
    return string.format(fmt, physVal, range.unit)
end

