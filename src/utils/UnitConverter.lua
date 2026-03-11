---@class UnitConverter
-- Utility for converting between metric and imperial units
UnitConverter = {}

-- Unit system constants
UnitConverter.SYSTEM_METRIC = 1
UnitConverter.SYSTEM_IMPERIAL = 2
UnitConverter.SYSTEM_BUSHELS = 3  -- Imperial with bushels

-- Conversion coefficients
UnitConverter.KMH_TO_MPH = 0.621371
UnitConverter.TONNE_TO_TON = 1.10231
UnitConverter.HECTARE_TO_ACRE = 2.47105

-- Bushel conversion coefficients (tonnes to bushels per hour)
-- Based on standard USDA bushel weights for each crop
UnitConverter.BUSHEL_COEFFICIENTS = {}

---Initialize bushel coefficients after FruitType is available
function UnitConverter.initBushelCoefficients()
    if not FruitType then
        return
    end
    
    UnitConverter.BUSHEL_COEFFICIENTS = {} -- Initialize here
    
    local function addCoef(name, val)
        if FruitType[name] then UnitConverter.BUSHEL_COEFFICIENTS[FruitType[name]] = val end
    end

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
    
    if rhm_Combine and rhm_Combine.debug then
        print("RHM: UnitConverter initialized")
    end
end

-- Default bushel coefficient (if crop not found)
UnitConverter.BUSHEL_DEFAULT = 36.76  -- Use wheat as default

---Convert speed based on unit system
---@param kmh number Speed in km/h
---@param system number Unit system (1=metric, 2=imperial, 3=bushels)
---@return number convertedValue
---@return string suffix
function UnitConverter.convertSpeed(kmh, system)
    if system == UnitConverter.SYSTEM_IMPERIAL or system == UnitConverter.SYSTEM_BUSHELS then
        return kmh * UnitConverter.KMH_TO_MPH, "mph"
    else
        return kmh, "km/h"
    end
end

---Convert productivity (mass per hour)
---@param tonnesPerHour number Productivity in t/h
---@param system number Unit system
---@param fruitType number|nil Current fruit type for bushel conversion (unused if liters provided)
---@param litersPerHour number|nil Productivity in l/h (optional, for accurate bushel conversion)
---@return number convertedValue
---@return string suffix
function UnitConverter.convertProductivity(tonnesPerHour, system, fruitType, litersPerHour)
    if system == UnitConverter.SYSTEM_BUSHELS then
        -- Preferred method: Convert directly from volume (liters) to bushels
        -- 1 US Bushel = 35.2391 Liters
        if litersPerHour and litersPerHour > 0 then
            return litersPerHour / 35.2391, "bu/h"
        end
        
        -- Fallback: Convert from mass using crop-specific coefficient
        local coefficient = UnitConverter.BUSHEL_DEFAULT
        if fruitType and UnitConverter.BUSHEL_COEFFICIENTS[fruitType] then
            coefficient = UnitConverter.BUSHEL_COEFFICIENTS[fruitType]
        end
        return tonnesPerHour * coefficient, "bu/h"
        
    elseif system == UnitConverter.SYSTEM_IMPERIAL then
        return tonnesPerHour * UnitConverter.TONNE_TO_TON, "ton/h"
    else
        return tonnesPerHour, "t/h"
    end
end

---Format area
---@param hectares number Area in hectares
---@param system number Unit system
---@return number convertedValue
---@return string suffix
function UnitConverter.convertArea(hectares, system)
    if system == UnitConverter.SYSTEM_IMPERIAL or system == UnitConverter.SYSTEM_BUSHELS then
        return hectares * UnitConverter.HECTARE_TO_ACRE, "ac"
    else
        return hectares, "ha"
    end
end

---Format speed with proper suffix
---@param kmh number Speed in km/h
---@param system number Unit system
---@return string Formatted string (e.g. "10.5 km/h" or "6.5 mph")
function UnitConverter.formatSpeed(kmh, system)
    local value, suffix = UnitConverter.convertSpeed(kmh, system)
    return string.format("%.1f %s", value, suffix)
end

---Format productivity
---@param tonnesPerHour number
---@param system number
---@param fruitType number|nil
---@param litersPerHour number|nil
---@return string
function UnitConverter.formatProductivity(tonnesPerHour, system, fruitType, litersPerHour)
    local value, suffix = UnitConverter.convertProductivity(tonnesPerHour, system, fruitType, litersPerHour)
    return string.format("%.1f %s", value, suffix)
end

---Format area
---@param hectares number
---@param system number
---@return string
function UnitConverter.formatArea(hectares, system)
    local value, suffix = UnitConverter.convertArea(hectares, system)
    return string.format("%.2f %s", value, suffix)
end

---Get unit system name
---@param system number
---@return string
function UnitConverter.getSystemName(system)
    if system == UnitConverter.SYSTEM_METRIC then
        return "Metric"
    elseif system == UnitConverter.SYSTEM_IMPERIAL then
        return "Imperial"
    elseif system == UnitConverter.SYSTEM_BUSHELS then
        return "Imperial (Bushels)"
    else
        return "Unknown"
    end
end

---Convert yield (t/ha)
---@param tPerHa number Yield in t/ha
---@param system number Unit system
---@param fruitType number|nil Current fruit type
---@return number convertedValue
---@return string suffix
function UnitConverter.convertYield(tPerHa, system, fruitType)
    if system == UnitConverter.SYSTEM_BUSHELS then
        -- Convert t/ha to bu/ac
        -- bu/ac = (t/ha * bu/t) / (ac/ha)
        -- ac/ha = 2.47105
        
        local buPerTonne = UnitConverter.BUSHEL_DEFAULT
        if fruitType and UnitConverter.BUSHEL_COEFFICIENTS[fruitType] then
            buPerTonne = UnitConverter.BUSHEL_COEFFICIENTS[fruitType]
        end
        
        local buPerHa = tPerHa * buPerTonne
        local buPerAc = buPerHa / UnitConverter.HECTARE_TO_ACRE
        
        return buPerAc, "bu/ac"
        
    elseif system == UnitConverter.SYSTEM_IMPERIAL then
        -- Convert t/ha to t/ac
        -- t/ac = t/ha / 2.47105
        return tPerHa / UnitConverter.HECTARE_TO_ACRE, "t/ac"
    else
        return tPerHa, "t/ha"
    end
end

---Format yield
---@param tPerHa number
---@param system number
---@param fruitType number|nil
---@return string
function UnitConverter.formatYield(tPerHa, system, fruitType)
    local value, suffix = UnitConverter.convertYield(tPerHa, system, fruitType)
    return string.format("%.1f %s", value, suffix)
end

-- ==========================================
-- PHYSICAL SETTINGS CONVERSION (UI LEVEL)
-- ==========================================

---@class PhysicalRange
---@field min number Minimum physical value (corresponds to 0%)
---@field max number Maximum physical value (corresponds to 100%)
---@field unit string The string suffix to display (e.g. "RPM", "mm")
---@field decimals number How many decimal places to show

---Universal physical ranges for combine settings mappings per machine type
UnitConverter.PHYSICAL_RANGES = {
    grain = {
        fan = { min = 300, max = 1200, unit = "RPM", decimals = 0 },
        rotor = { min = 200, max = 1100, unit = "RPM", decimals = 0 },
        upperSieve = { min = 0, max = 30, unit = "mm", decimals = 1 },
        lowerSieve = { min = 0, max = 25, unit = "mm", decimals = 1 },
        feeder = { min = 300, max = 800, unit = "RPM", decimals = 0 },
    },
    forage = {
        fan = { min = 800, max = 1500, unit = "RPM", decimals = 0 },    -- Intake Blower / Accelerator
        rotor = { min = 1000, max = 1200, unit = "RPM", decimals = 0 }, -- Chopping Drum
        feeder = { min = 200, max = 600, unit = "RPM", decimals = 0 },  -- Feed Rolls
    },
    root = {
        fan = { min = 400, max = 1000, unit = "RPM", decimals = 0 },    -- Blower / Separation
        rotor = { min = 100, max = 350, unit = "RPM", decimals = 0 },   -- Cleaning Rollers / Stars
        feeder = { min = 100, max = 400, unit = "RPM", decimals = 0 },  -- Sieve Belts / Elevator
    },
    cotton = {
        fan = { min = 2500, max = 4000, unit = "RPM", decimals = 0 },   -- Blower/Air system
        rotor = { min = 150, max = 250, unit = "RPM", decimals = 0 },   -- Spindle Drums
        feeder = { min = 100, max = 300, unit = "RPM", decimals = 0 },  -- Feeder
    }
}

---Helper to get range based on machineType
function UnitConverter.getPhysicalRange(paramName, machineType)
    machineType = machineType or "grain"
    local typeRanges = UnitConverter.PHYSICAL_RANGES[machineType]
    if typeRanges and typeRanges[paramName] then
        return typeRanges[paramName]
    end
    return nil
end

---Convert a backend percentage (0-100) to a physical unit value based on the parameter type
---@param paramName string The name of the parameter
---@param percentage number The backend value 0-100
---@param machineType string|nil The machine type ("grain", "forage", "root", "cotton")
---@return number physicalValue The mapped physical value
function UnitConverter.percentToPhysical(paramName, percentage, machineType)
    local range = UnitConverter.getPhysicalRange(paramName, machineType)
    if not range then
        return percentage -- Fallback to raw percentage if parameter is unknown
    end
    -- Clamp percentage to safely calculate
    local safePct = math.max(0, math.min(100, percentage))
    local span = range.max - range.min
    return range.min + (span * (safePct / 100))
end

---Convert a physical unit value back to a backend percentage (0-100)
---@param paramName string The name of the parameter
---@param physicalValue number The physical value (e.g., 750 RPM)
---@param machineType string|nil The machine type ("grain", "forage", "root", "cotton")
---@return number percentage The mapped 0-100 value
function UnitConverter.physicalToPercent(paramName, physicalValue, machineType)
    local range = UnitConverter.getPhysicalRange(paramName, machineType)
    if not range then
        return physicalValue -- Fallback
    end
    -- Clamp physical value
    local safeVal = math.max(range.min, math.min(range.max, physicalValue))
    local span = range.max - range.min
    if span <= 0 then return 0 end
    return ((safeVal - range.min) / span) * 100
end

---Formats a setting percentage into a string with its physical unit (e.g. "800 RPM")
---@param paramName string The name of the parameter
---@param percentage number The backend value 0-100
---@param machineType string|nil The machine type ("grain", "forage", "root", "cotton")
---@return string formattedString e.g. "800 RPM" or "14.5 mm" (or "50%" for fallback)
function UnitConverter.formatSetting(paramName, percentage, machineType)
    local range = UnitConverter.getPhysicalRange(paramName, machineType)
    if not range then
        return string.format("%.0f%%", percentage)
    end
    
    local physVal = UnitConverter.percentToPhysical(paramName, percentage, machineType)
    local fmt = "%." .. tostring(range.decimals) .. "f %s"
    return string.format(fmt, physVal, range.unit)
end
