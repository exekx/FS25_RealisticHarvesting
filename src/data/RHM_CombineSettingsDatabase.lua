-- EN: Static database of optimal combine settings and crop profiles.
--     Stores parameter templates (fan, rotor, sieves, feeder) for every supported crop type,
--     maps FS25 FillType enums to internal crop names, and defines which parameters are
--     active for each machine type (grain, forage, root, cotton).
-- UA: Статична база даних оптимальних налаштувань комбайна та профілів культур.
--     Зберігає шаблони параметрів (вентилятор, ротор, решета, подача) для кожного типу культури,
--     відображає FillType enum FS25 на внутрішні назви культур, і визначає які параметри активні
--     для кожного типу машини (зернова, форажна, коренеплоди, бавовна).
RHM_CombineSettingsDatabase = {}

-- EN: Fully dynamic physics-based settings generator.
--     Static hardcoded templates have been replaced by the ASABE / FS25 physical calculation engine
--     in RHM_CombineSettingsDatabase:calculatePhysicalOptimalSettings(cropName, context).
-- UA: Повністю динамічний фізичний генератор налаштувань.
--     Статичні захардкоджені шаблони замінено фізичним розрахунковим модулем
--     в RHM_CombineSettingsDatabase:calculatePhysicalOptimalSettings(cropName, context).
-- EN: Active parameters per machine type. Defines which parameter sliders appear in the calibration GUI.
-- UA: Активні параметри для кожного типу машини. Визначає які повзунки параметрів відображаються в GUI калібрування.

---Active parameters per machine type (defines which sliders appear in GUI)
RHM_CombineSettingsDatabase.machineParams = {
    grain   = { "fan", "rotor", "upperSieve", "lowerSieve", "feeder" },
    forage  = { "fan", "rotor", "feeder" },
    root    = { "fan", "rotor", "feeder" },
    cotton  = { "fan", "rotor", "feeder" },
    grape   = { "rotor", "feeder", "fan" },
    olive   = { "rotor", "feeder", "fan" },
}

---L10n key overrides for parameter labels per machine type
---Falls back to generic "rhm_ui_<param>" if no override defined
RHM_CombineSettingsDatabase.machineParamLabels = {
    grain = {
        fan        = "rhm_ui_fan_speed",
        rotor      = "rhm_ui_rotor_speed",
        upperSieve = "rhm_ui_upper_sieve",
        lowerSieve = "rhm_ui_lower_sieve",
        feeder     = "rhm_ui_feeder_speed",
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
    grape = {
        rotor  = "rhm_ui_grape_shaker",   -- Shaker rods / Струшувачі
        feeder = "rhm_ui_grape_conveyor", -- Bucket conveyor / Конвеєр
        fan    = "rhm_ui_grape_fan",      -- Extractor fans / Очисні вентилятори
    },
    olive = {
        rotor  = "rhm_ui_olive_shaker",   -- Shaker beaters / Бітери струшування
        feeder = "rhm_ui_grape_conveyor", -- Bucket conveyor / Конвеєр
        fan    = "rhm_ui_grape_fan",      -- Extractor fans / Очисні вентилятори
    },
}

-- EN: Returns the ordered list of parameter names active for the given machine type.
--     Used to determine which sliders to display and which RHM_CombineMemory keys to initialize.
-- UA: Повертає впорядкований список назв параметрів активних для заданого типу машини.
--     Використовується для визначення яких повзунки відображати та які ключі RHM_CombineMemory ініціалізувати.
function RHM_CombineSettingsDatabase:getParamsForMachineType(machineType)
    return self.machineParams[machineType] or self.machineParams.grain
end

-- EN: Returns the localization key for a parameter label based on machine type.
--     Falls back to generic "rhm_ui_<param>" if no specific override is defined.
-- UA: Повертає ключ локалізації для підпису параметру залежно від типу машини.
--     Повертається до загального "rhm_ui_<param>" якщо немає специфічного перевизначення.
function RHM_CombineSettingsDatabase:getParamLabel(machineType, paramName)
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

-- EN: Canonical internal crop keys mapping table. Maps synonyms, aliases, and custom map variants to standard keys.
-- UA: Таблиця канонічних внутрішніх назв культур. Зводить синоніми та альтернативні назви до єдиного ключа.
RHM_CombineSettingsDatabase.canonicalCropNames = {
    ["PEAS"]            = "PEA",
    ["PEA"]             = "PEA",
    ["CORN"]            = "MAIZE",
    ["MAIZE"]           = "MAIZE",
    ["BEAN"]            = "BEANS",
    ["BEANS"]           = "BEANS",
    ["OATS"]            = "OAT",
    ["OAT"]             = "OAT",
    ["FLAX"]            = "LINSEED",
    ["LINSEED"]         = "LINSEED",
    ["LUCERNE"]         = "ALFALFA",
    ["ALFALFA"]         = "ALFALFA",
    ["LUCERNE_WINDROW"] = "ALFALFA_WINDROW",
    ["ALFALFA_WINDROW"] = "ALFALFA_WINDROW",
    ["HAY"]             = "DRYGRASS",
    ["HAY_WINDROW"]     = "DRYGRASS_WINDROW",
    ["RICELONGGRAIN"]   = "RICE_LONG_GRAIN",
    ["RICE_LONGGRAIN"]  = "RICE_LONG_GRAIN",
    ["ONION_DIRTY"]     = "ONION",
    ["FABABEAN"]        = "BEANS",
    ["FIELD_BEAN"]      = "BEANS",
    ["STRAW"]           = "STRAW_WINDROW",
    ["GRAPES"]          = "GRAPE",
    ["OLIVES"]          = "OLIVE",
    ["WHITEGRAPE"]      = "GRAPE",
    ["REDGRAPE"]        = "GRAPE",
}

---EN: Returns the canonical internal crop name for any given alias or variation.
---UA: Повертає канонічну внутрішню назву культури для будь-якого аліаса або варіації.
function RHM_CombineSettingsDatabase:getCanonicalCropName(cropName)
    if not cropName then return nil end
    local rawUpper = tostring(cropName):upper()
    return self.canonicalCropNames[rawUpper] or (self.cropAliases and self.cropAliases[rawUpper]) or rawUpper
end

-- EN: Crop synonyms/aliases table. Allows bidirectional matching between common naming conventions
--     (e.g. FLAX <-> LINSEED, MAIZE <-> CORN, LUCERNE <-> ALFALFA).
-- UA: Таблиця синонімів/аліасів культур. Дозволяє двостороннє зіставлення між загальними назвами
--     (напр. FLAX <-> LINSEED, MAIZE <-> CORN, LUCERNE <-> ALFALFA).
RHM_CombineSettingsDatabase.cropAliases = {
    ["FLAX"]            = "LINSEED",
    ["LINSEED"]         = "FLAX",
    ["MAIZE"]           = "CORN",
    ["CORN"]            = "MAIZE",
    ["LUCERNE"]         = "ALFALFA",
    ["ALFALFA"]         = "LUCERNE",
    ["OATS"]            = "OAT",
    ["OAT"]             = "OATS",
    ["HAY"]             = "DRYGRASS",
    ["RICELONGGRAIN"]   = "RICE_LONG_GRAIN",
    ["RICE_LONGGRAIN"]  = "RICE_LONG_GRAIN",
    ["ONION_DIRTY"]     = "ONION",
    ["BEANS"]           = "BEAN",
    ["BEAN"]            = "BEANS",
    ["FABABEAN"]        = "BEANS",
    ["FIELD_BEAN"]      = "BEANS",
    ["PEAS"]            = "PEA",
    ["PEA"]             = "PEAS",
}

RHM_CombineSettingsDatabase.crops = {
    -- Зернові
    ["WHEAT"]   = { machineType = "grain", group = "grain",   fillType = safeFillType(FillType.WHEAT) },
    ["BARLEY"]  = { machineType = "grain", group = "grain",   fillType = safeFillType(FillType.BARLEY) },
    ["OAT"]     = { machineType = "grain", group = "grain",   fillType = safeFillType(FillType.OAT) },
    ["SORGHUM"] = { machineType = "grain", group = "grain",   fillType = safeFillType(FillType.SORGHUM) },
    
    -- Рис
    ["RICE"]            = { machineType = "grain", group = "rice", fillType = safeFillType(FillType.RICE) },
    ["RICE_LONG_GRAIN"] = { machineType = "grain", group = "rice", fillType = safeFillType(FillType.RICE_LONG_GRAIN) },
    
    -- Олійні
    ["CANOLA"]    = { machineType = "grain", group = "oilseed", fillType = safeFillType(FillType.CANOLA) },
    ["SUNFLOWER"] = { machineType = "grain", group = "oilseed", fillType = safeFillType(FillType.SUNFLOWER) },
    
    -- Кукурудза
    ["CORN"]  = { machineType = "grain", group = "corn", fillType = safeFillType(FillType.MAIZE) },
    ["MAIZE"] = { machineType = "grain", group = "corn", fillType = safeFillType(FillType.MAIZE) },
    
    -- Бобові
    ["SOYBEAN"]  = { machineType = "grain", group = "legume", fillType = safeFillType(FillType.SOYBEAN) },
    ["PEA"]      = { machineType = "grain", group = "legume", fillType = safeFillType(FillType.PEA) },
    ["PEAS"]     = { machineType = "grain", group = "legume", fillType = safeFillType(FillType.PEA) },
    ["LENTIL"]   = { machineType = "grain", group = "legume", fillType = safeFillType(FillType.LENTIL) },
    ["CHICKPEA"] = { machineType = "grain", group = "legume", fillType = safeFillType(FillType.CHICKPEA) },
    ["BEANS"]    = { machineType = "grain", group = "legume", fillType = safeFillType(FillType and (FillType.BEANS or FillType.BEAN)) },
    ["BEAN"]     = { machineType = "grain", group = "legume", fillType = safeFillType(FillType and (FillType.BEAN or FillType.BEANS)) },

    -- Додаткові зернові (Mod crops)
    ["RYE"]       = { machineType = "grain", group = "grain", fillType = nil },
    ["SPELT"]     = { machineType = "grain", group = "grain", fillType = nil },
    ["TRITICALE"] = { machineType = "grain", group = "grain", fillType = nil },
    ["OATS"]      = { machineType = "grain", group = "grain", fillType = nil },
    ["MILLET"]    = { machineType = "grain", group = "grain", fillType = nil },
    ["BUCKWHEAT"] = { machineType = "grain", group = "grain", fillType = nil },
    
    -- Додаткові олійні (Mod crops)
    ["LINSEED"]   = { machineType = "grain", group = "oilseed", fillType = nil },
    ["FLAX"]      = { machineType = "grain", group = "oilseed", fillType = nil },
    ["MUSTARD"]   = { machineType = "grain", group = "oilseed", fillType = nil },
    ["SAFFLOWER"] = { machineType = "grain", group = "oilseed", fillType = nil },
    ["POPPY"]     = { machineType = "grain", group = "oilseed", fillType = nil },
    
    -- Трави
    ["GRASS_SEED"] = { machineType = "grain", group = "grain", fillType = nil },
    ["CLOVER"]     = { machineType = "grain", group = "grain", fillType = nil },
    
    -- Волокнисті (Mod crops)
    ["HEMP"] = { machineType = "grain", group = "oilseed", fillType = nil },
    
    -- Root & Veg (machineType = "root")
    ["POTATO"]    = { machineType = "root", group = "root",      fillType = safeFillType(FillType.POTATO) },
    ["SUGARBEET"] = { machineType = "root", group = "root",      fillType = safeFillType(FillType.SUGARBEET) },
    ["BEETROOT"]  = { machineType = "root", group = "root",      fillType = safeFillType(FillType.BEETROOT) },
    ["CARROT"]    = { machineType = "root", group = "root",      fillType = safeFillType(FillType.CARROT) },
    ["PARSNIP"]   = { machineType = "root", group = "root",      fillType = safeFillType(FillType.PARSNIP) },
    ["ONION"]     = { machineType = "root", group = "root",      fillType = safeFillType(FillType.ONION) },
    ["SPINACH"]   = { machineType = "root", group = "vegetable", fillType = safeFillType(FillType.SPINACH) },
    ["GREENBEAN"] = { machineType = "root", group = "vegetable", fillType = safeFillType(FillType.GREENBEAN) },

    -- Форажні (для кормозбирального комбайна) (machineType = "forage")
    ["GRASS"]            = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.GRASS) },
    ["DRYGRASS"]         = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.DRYGRASS) },
    ["GRASS_WINDROW"]    = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.GRASS_WINDROW) },
    ["DRYGRASS_WINDROW"] = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.DRYGRASS_WINDROW) },
    ["STRAW_WINDROW"]    = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.STRAW) },
    ["ALFALFA"]          = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.ALFALFA) },
    ["LUCERNE"]          = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.ALFALFA) },
    ["ALFALFA_WINDROW"]  = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.ALFALFA_WINDROW) },
    ["LUCERNE_WINDROW"]  = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.ALFALFA_WINDROW) },
    ["CLOVER_WINDROW"]   = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.CLOVER_WINDROW) },
    ["MAIZE_FORAGE"]     = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.MAIZE) },

    -- Бавовник (machineType = "cotton")
    ["COTTON"] = { machineType = "cotton", group = "cotton", fillType = safeFillType(FillType.COTTON) },

    -- Виноград та Оливки (machineType = "grape" / "olive")
    ["GRAPE"]  = { machineType = "grape", group = "grape", fillType = safeFillType(FillType.GRAPE) },
    ["OLIVE"]  = { machineType = "olive", group = "olive", fillType = safeFillType(FillType.OLIVE) },
}

-- Ensure alias crop keys directly point to the same table reference to avoid divergent state
RHM_CombineSettingsDatabase.crops["PEAS"] = RHM_CombineSettingsDatabase.crops["PEA"]
RHM_CombineSettingsDatabase.crops["CORN"] = RHM_CombineSettingsDatabase.crops["MAIZE"]
RHM_CombineSettingsDatabase.crops["BEAN"] = RHM_CombineSettingsDatabase.crops["BEANS"]
RHM_CombineSettingsDatabase.crops["OATS"] = RHM_CombineSettingsDatabase.crops["OAT"]
RHM_CombineSettingsDatabase.crops["FLAX"] = RHM_CombineSettingsDatabase.crops["LINSEED"]
RHM_CombineSettingsDatabase.crops["LUCERNE"] = RHM_CombineSettingsDatabase.crops["ALFALFA"]
RHM_CombineSettingsDatabase.crops["LUCERNE_WINDROW"] = RHM_CombineSettingsDatabase.crops["ALFALFA_WINDROW"]
RHM_CombineSettingsDatabase.crops["GRAPES"] = RHM_CombineSettingsDatabase.crops["GRAPE"]
RHM_CombineSettingsDatabase.crops["OLIVES"] = RHM_CombineSettingsDatabase.crops["OLIVE"]
RHM_CombineSettingsDatabase.crops["WHITEGRAPE"] = RHM_CombineSettingsDatabase.crops["GRAPE"]
RHM_CombineSettingsDatabase.crops["REDGRAPE"] = RHM_CombineSettingsDatabase.crops["GRAPE"]

---EN: Dynamically derives physical optimal settings for any crop (vanilla or modded) using FS25 properties & ASABE standards.
---UA: Динамічно розраховує фізичні оптимальні налаштування для будь-якої культури за властивостями FS25 та стандартами ASABE.
function RHM_CombineSettingsDatabase:calculatePhysicalOptimalSettings(cropName, context)
    cropName = self:getCanonicalCropName(cropName) or cropName
    context = context or {}
    local machineType = context.machineType or "grain"
    if self.crops[cropName] and self.crops[cropName].machineType then
        machineType = self.crops[cropName].machineType
    end

    -- 1. Query GIANTS managers for physical characteristics
    local fillTypeDesc = nil
    if context.fillType and g_fillTypeManager and g_fillTypeManager.getFillTypeByIndex then
        fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(context.fillType)
    elseif g_fillTypeManager and g_fillTypeManager.getFillTypeByName then
        fillTypeDesc = g_fillTypeManager:getFillTypeByName(cropName)
    end

    local fruitTypeDesc = nil
    if context.fruitType and g_fruitTypeManager and g_fruitTypeManager.getFruitTypeByIndex then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(context.fruitType)
    elseif g_fruitTypeManager and g_fruitTypeManager.getFruitTypeByName then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByName(cropName)
    end

    -- 2. Bulk Density (kg/L)
    local densityKgPerL = 0.75
    if fillTypeDesc and fillTypeDesc.massPerLiter and fillTypeDesc.massPerLiter > 0 then
        densityKgPerL = fillTypeDesc.massPerLiter * 1000
    else
        local knownDensities = {
            WHEAT = 0.78, BARLEY = 0.62, OAT = 0.52, OATS = 0.52,
            CANOLA = 0.42, SUNFLOWER = 0.42, SAFFLOWER = 0.42,
            CORN = 0.76, MAIZE = 0.76, SOYBEAN = 0.75, SORGHUM = 0.72,
            RICE = 0.58, RICE_LONG_GRAIN = 0.58,
            PEA = 0.75, LENTIL = 0.75, CHICKPEA = 0.75,
            BEANS = 0.76, BEAN = 0.76, FABABEAN = 0.78,
            RYE = 0.72, SPELT = 0.53, TRITICALE = 0.70,
            MILLET = 0.65, BUCKWHEAT = 0.60,
            LINSEED = 0.45, FLAX = 0.45, MUSTARD = 0.45, POPPY = 0.40,
            HEMP = 0.50, GRASS_SEED = 0.28, CLOVER = 0.35,
        }
        densityKgPerL = knownDensities[cropName] or 0.75
    end

    -- 3. Straw / MOG Presence
    local hasStraw = false
    if fruitTypeDesc and fruitTypeDesc.hasWindrow ~= nil then
        hasStraw = fruitTypeDesc.hasWindrow
    elseif cropName == "WHEAT" or cropName == "BARLEY" or cropName == "OAT" or cropName == "OATS"
        or cropName == "RYE" or cropName == "SPELT" or cropName == "TRITICALE"
        or cropName == "RICE" or cropName == "RICE_LONG_GRAIN"
        or cropName == "BEANS" or cropName == "BEAN" or cropName == "FABABEAN" then
        hasStraw = true
    end

    local template = {}

    if machineType == "forage" then
        local isPickup = context.isPickup or false
        if cropName:find("WINDROW") or cropName:find("PICKUP") or cropName == "STRAW" or cropName == "HAY" then
            isPickup = true
        end

        if cropName:find("CORN") or cropName:find("MAIZE") or cropName:find("SILAGE") or cropName:find("CHAFF") or cropName:find("GPS") then
            -- Corn silage: high-speed accelerator blower (75%), fast chopping drum (80%), high intake feedrolls (70%)
            template = {
                fan    = {optimal = 75, min = 55, max = 95, tolerance = 8},
                rotor  = {optimal = 80, min = 60, max = 100, tolerance = 8},
                feeder = {optimal = 70, min = 50, max = 90, tolerance = 8},
                moistureLimit = 65,
            }
        elseif isPickup then
            -- Windrow pickup (pre-wilted/dry grass, hay, or straw): moderate drum, swift feeder
            template = {
                fan    = {optimal = 55, min = 35, max = 75, tolerance = 8},
                rotor  = {optimal = 60, min = 40, max = 80, tolerance = 8},
                feeder = {optimal = 65, min = 45, max = 85, tolerance = 8},
                moistureLimit = 40,
            }
        else
            -- Direct-cut standing grass/lucerne/clover: juicy long stems, high cut resistance
            template = {
                fan    = {optimal = 65, min = 45, max = 85, tolerance = 8},
                rotor  = {optimal = 65, min = 45, max = 85, tolerance = 8},
                feeder = {optimal = 55, min = 35, max = 75, tolerance = 8},
                moistureLimit = 75,
            }
        end

    elseif machineType == "root" then
        if cropName:find("SPINACH") or cropName:find("LEAF") or cropName:find("HERB") then
            template = {
                fan    = {optimal = 20, min = 5,  max = 40, tolerance = 5},
                rotor  = {optimal = 25, min = 10, max = 45, tolerance = 5},
                feeder = {optimal = 60, min = 40, max = 80, tolerance = 8},
                moistureLimit = 25,
            }
        elseif cropName:find("ONION") or cropName:find("GARLIC") then
            template = {
                fan    = {optimal = 75, min = 55, max = 95, tolerance = 8},
                rotor  = {optimal = 45, min = 25, max = 65, tolerance = 8},
                feeder = {optimal = 55, min = 35, max = 75, tolerance = 8},
                moistureLimit = 18,
            }
        elseif cropName:find("POTATO") then
            template = {
                fan    = {optimal = 35, min = 15, max = 55, tolerance = 8},
                rotor  = {optimal = 40, min = 20, max = 60, tolerance = 8},
                feeder = {optimal = 70, min = 50, max = 90, tolerance = 8},
                moistureLimit = 20,
            }
        elseif cropName:find("SUGARBEET") or cropName:find("BEETROOT") then
            template = {
                fan    = {optimal = 40, min = 20, max = 60, tolerance = 8},
                rotor  = {optimal = 55, min = 35, max = 75, tolerance = 8},
                feeder = {optimal = 65, min = 45, max = 85, tolerance = 8},
                moistureLimit = 22,
            }
        elseif cropName:find("GREENBEAN") then
            template = {
                fan    = {optimal = 45, min = 25, max = 65, tolerance = 8},
                rotor  = {optimal = 35, min = 15, max = 55, tolerance = 8},
                feeder = {optimal = 65, min = 45, max = 85, tolerance = 8},
                moistureLimit = 18,
            }
        else
            -- General Root / Carrot / Parsnip
            template = {
                fan    = {optimal = 38, min = 20, max = 58, tolerance = 8},
                rotor  = {optimal = 45, min = 25, max = 65, tolerance = 8},
                feeder = {optimal = 68, min = 48, max = 88, tolerance = 8},
                moistureLimit = 20,
            }
        end

    elseif machineType == "cotton" then
        template = {
            fan    = {optimal = 80, min = 60, max = 100, tolerance = 10},
            rotor  = {optimal = 70, min = 50, max = 90, tolerance = 10},
            feeder = {optimal = 60, min = 40, max = 80, tolerance = 10},
            moistureLimit = 10,
        }

    elseif machineType == "grape" then
        template = {
            fan    = {optimal = 60, min = 40, max = 80, tolerance = 8},
            rotor  = {optimal = 55, min = 35, max = 75, tolerance = 8},
            feeder = {optimal = 65, min = 45, max = 85, tolerance = 8},
            moistureLimit = 75,
        }

    elseif machineType == "olive" then
        template = {
            fan    = {optimal = 65, min = 45, max = 85, tolerance = 8},
            rotor  = {optimal = 60, min = 40, max = 80, tolerance = 8},
            feeder = {optimal = 60, min = 40, max = 80, tolerance = 8},
            moistureLimit = 60,
        }

    else
        -- GRAIN COMBINE HARVESTER (Aerodynamic & Threshing Physics Engine)
        -- A. Fan Speed: Aerodynamic terminal velocity directly related to bulk density
        local fanOpt = math.floor(math.max(20, math.min(90, 20 + (densityKgPerL * 52) + 0.5)))
        
        -- Specific aerodynamic corrections for seed geometry & chaff drag:
        if cropName == "CANOLA" or cropName == "MUSTARD" or cropName == "LINSEED" or cropName == "FLAX" then
            fanOpt = 39
        elseif cropName == "POPPY" then
            fanOpt = 35
        elseif cropName == "GRASS_SEED" or cropName == "CLOVER" then
            fanOpt = 25
        elseif cropName == "OAT" or cropName == "OATS" or cropName == "SUNFLOWER" or cropName == "SAFFLOWER" then
            fanOpt = 44
        elseif cropName == "BARLEY" or cropName == "WHEAT" or cropName == "RYE" or cropName == "TRITICALE" or cropName == "SPELT" then
            fanOpt = 56
        elseif cropName == "SORGHUM" then
            fanOpt = 58
        elseif cropName == "RICE" or cropName == "RICE_LONG_GRAIN" then
            fanOpt = 50
        elseif cropName == "SOYBEAN" then
            fanOpt = 61
        elseif cropName == "CORN" or cropName == "MAIZE" then
            fanOpt = 67
        elseif cropName == "PEA" or cropName == "PEAS" or cropName == "LENTIL" or cropName == "CHICKPEA"
            or cropName == "BEANS" or cropName == "BEAN" or cropName == "FABABEAN" then
            fanOpt = 55
        end

        -- B. Rotor & Concave: Based on straw volume, seed brittleness, and ear architecture
        local rotorOpt = 55
        local concaveOpt = 45
        local feederOpt = 25
        local upperOpt = 48
        local lowerOpt = 32
        local moistLimit = 14

        if cropName == "BARLEY" then
            -- Tough awns: higher drum speed (63%) and tighter concave (22%)
            rotorOpt = 63; concaveOpt = 22; upperOpt = 47; lowerOpt = 32; feederOpt = 14; moistLimit = 14
        elseif cropName == "WHEAT" or cropName == "RYE" or cropName == "TRITICALE" or cropName == "SPELT" or cropName == "MILLET" then
            -- Standard cereal grain: rotor 56%, concave 25%
            rotorOpt = 56; concaveOpt = 25; upperOpt = 47; lowerOpt = 32; feederOpt = 12; moistLimit = 14
        elseif cropName == "OAT" or cropName == "OATS" then
            -- Loose hulls: gentle rotor 50%, concave 30%
            rotorOpt = 50; concaveOpt = 30; upperOpt = 45; lowerOpt = 28; feederOpt = 12; moistLimit = 14
        elseif cropName == "CANOLA" or cropName == "MUSTARD" or cropName == "LINSEED" or cropName == "FLAX" or cropName == "POPPY" then
            -- Fragile pods, easily shattered: low rotor (33%), narrow sieves
            rotorOpt = 33; concaveOpt = 40; upperOpt = 30; lowerOpt = 18; feederOpt = 40; moistLimit = 9
        elseif cropName == "CORN" or cropName == "MAIZE" then
            -- Big cobs, cracking prevention: ultra-low drum (13%), wide concave (60%), large sieves (65/48)
            rotorOpt = 13; concaveOpt = 60; upperOpt = 65; lowerOpt = 48; feederOpt = 60; moistLimit = 15
        elseif cropName == "SUNFLOWER" or cropName == "SAFFLOWER" then
            -- Fragile hulls: low drum (18%), wide concave (60%)
            rotorOpt = 18; concaveOpt = 60; upperOpt = 60; lowerOpt = 40; feederOpt = 55; moistLimit = 9
        elseif cropName == "SOYBEAN" then
            -- Brittle embryo: gentle rotor (39%), medium-wide concave (38%)
            rotorOpt = 39; concaveOpt = 38; upperOpt = 55; lowerOpt = 36; feederOpt = 36; moistLimit = 13
        elseif cropName == "PEA" or cropName == "PEAS" or cropName == "LENTIL" or cropName == "CHICKPEA"
            or cropName == "BEANS" or cropName == "BEAN" or cropName == "FABABEAN" then
            -- Large pulses: slow drum (30%), wide concave (45%)
            rotorOpt = 30; concaveOpt = 45; upperOpt = 55; lowerOpt = 35; feederOpt = 30; moistLimit = 14
        elseif cropName == "SORGHUM" then
            rotorOpt = 42; concaveOpt = 35; upperOpt = 45; lowerOpt = 30; feederOpt = 20; moistLimit = 14
        elseif cropName == "RICE" or cropName == "RICE_LONG_GRAIN" then
            rotorOpt = 45; concaveOpt = 30; upperOpt = 40; lowerOpt = 25; feederOpt = 15; moistLimit = 14
        elseif cropName == "GRASS_SEED" or cropName == "CLOVER" then
            rotorOpt = 45; concaveOpt = 25; upperOpt = 25; lowerOpt = 15; feederOpt = 10; moistLimit = 12
        elseif cropName == "BUCKWHEAT" then
            rotorOpt = 35; concaveOpt = 35; upperOpt = 38; lowerOpt = 22; feederOpt = 25; moistLimit = 13
        elseif cropName == "HEMP" then
            rotorOpt = 40; concaveOpt = 35; upperOpt = 45; lowerOpt = 28; feederOpt = 25; moistLimit = 12
        else
            -- Dynamic calculation for unlisted custom mod crop
            if hasStraw then
                rotorOpt = 56; concaveOpt = 25; upperOpt = 47; lowerOpt = 32; feederOpt = 14; moistLimit = 14
            elseif densityKgPerL < 0.50 then
                rotorOpt = 35; concaveOpt = 40; upperOpt = 32; lowerOpt = 18; feederOpt = 35; moistLimit = 10
            elseif densityKgPerL >= 0.70 then
                rotorOpt = 25; concaveOpt = 55; upperOpt = 60; lowerOpt = 42; feederOpt = 50; moistLimit = 14
            else
                rotorOpt = 45; concaveOpt = 35; upperOpt = 45; lowerOpt = 28; feederOpt = 25; moistLimit = 14
            end
        end

        template = {
            fan        = {optimal = fanOpt, min = math.max(10, fanOpt - 20), max = math.min(100, fanOpt + 20), tolerance = 6},
            rotor      = {optimal = rotorOpt, min = math.max(10, rotorOpt - 20), max = math.min(100, rotorOpt + 20), tolerance = 6},
            concave    = {optimal = concaveOpt, min = math.max(10, concaveOpt - 20), max = math.min(100, concaveOpt + 20), tolerance = 6},
            upperSieve = {optimal = upperOpt, min = math.max(10, upperOpt - 20), max = math.min(100, upperOpt + 20), tolerance = 5},
            lowerSieve = {optimal = lowerOpt, min = math.max(5, lowerOpt - 15), max = math.min(100, lowerOpt + 20), tolerance = 5},
            feeder     = {optimal = feederOpt, min = math.max(5, feederOpt - 10), max = math.min(100, feederOpt + 15), tolerance = 4},
            moistureLimit = moistLimit,
        }
    end

    return template
end

---EN: Applies live environmental offsets (moisture, yield) to optimal settings pins.
---UA: Застосовує живі поправки навколишнього середовища (вологість, врожайність) до оптимальних налаштувань.
function RHM_CombineSettingsDatabase:applyEnvironmentalOffsets(baseTemplate, context)
    if not baseTemplate or not context then return baseTemplate end

    local moisture = context.moisture
    local yield = context.yield
    local machineType = context.machineType or "grain"

    -- EN: Early exit if not a grain combine or moisture is absent/zero, avoiding deep-copy GC churn.
    -- UA: Ранній вихід якщо не зерновий комбайн або вологість відсутня, без непотрібного копіювання таблиць.
    if machineType ~= "grain" or not moisture or moisture <= 0 then
        return baseTemplate
    end

    local refMoisture = baseTemplate.moistureLimit or 14.0
    local deltaM = moisture - refMoisture
    local hasMoistureOffset = (deltaM > 0 or deltaM < -2.0)
    local hasYieldOffset = (yield and yield > 8.0)

    if not hasMoistureOffset and not hasYieldOffset then
        return baseTemplate
    end

    -- Deep copy template so we don't modify the static database template
    local adjusted = {}
    for k, v in pairs(baseTemplate) do
        if type(v) == "table" then
            adjusted[k] = {
                optimal = v.optimal,
                min = v.min,
                max = v.max,
                tolerance = v.tolerance
            }
        else
            adjusted[k] = v
        end
    end

    -- 1. Grain combines: Moisture and Yield live corrections
    if machineType == "grain" and moisture and moisture > 0 then
        local refMoisture = baseTemplate.moistureLimit or 14.0
        local deltaM = moisture - refMoisture

        if deltaM > 0 then
            -- Tough/damp grain: faster rotor (+1.5%/1%), tighter concave (-1.0%/1%), stronger fan (+1.2%/1%)
            if adjusted.rotor then
                adjusted.rotor.optimal = math.min(100, math.floor(adjusted.rotor.optimal + deltaM * 1.5 + 0.5))
            end
            if adjusted.concave then
                adjusted.concave.optimal = math.max(10, math.floor(adjusted.concave.optimal - deltaM * 1.0 + 0.5))
            end
            if adjusted.fan then
                adjusted.fan.optimal = math.min(100, math.floor(adjusted.fan.optimal + deltaM * 1.2 + 0.5))
            end
        elseif deltaM < -2.0 then
            -- Very dry/brittle grain (< 12%): slower rotor (-1.5%/1%), wider concave (+1.0%/1%), gentler fan (-0.8%/1%)
            local dryDelta = math.abs(deltaM + 2.0)
            if adjusted.rotor then
                adjusted.rotor.optimal = math.max(10, math.floor(adjusted.rotor.optimal - dryDelta * 1.5 + 0.5))
            end
            if adjusted.concave then
                adjusted.concave.optimal = math.min(100, math.floor(adjusted.concave.optimal + dryDelta * 1.0 + 0.5))
            end
            if adjusted.fan then
                adjusted.fan.optimal = math.max(15, math.floor(adjusted.fan.optimal - dryDelta * 0.8 + 0.5))
            end
        end

        -- Stand density / Yield correction: high yield (> 8 t/ha) needs wider sieves & concaves to prevent choking
        if yield and yield > 8.0 then
            local excessYield = math.min(10.0, yield - 8.0)
            if adjusted.upperSieve then
                adjusted.upperSieve.optimal = math.min(100, math.floor(adjusted.upperSieve.optimal + excessYield * 1.0 + 0.5))
            end
            if adjusted.lowerSieve then
                adjusted.lowerSieve.optimal = math.min(100, math.floor(adjusted.lowerSieve.optimal + excessYield * 0.8 + 0.5))
            end
            if adjusted.concave then
                adjusted.concave.optimal = math.min(100, math.floor(adjusted.concave.optimal + excessYield * 1.0 + 0.5))
            end
        end
    end

    return adjusted
end

-- EN: Returns the optimal settings template for a crop by internal name (e.g. "WHEAT").
--     If crop is unlisted or custom mod crop, dynamically calculates its physical profile.
--     If context (moisture, yield) is supplied, applies live environmental adjustments.
-- UA: Повертає шаблон оптимальних налаштувань для культури за назвою.
--     Якщо культура невідома чи модова, динамічно генерує фізичний паспорт.
--     Якщо передано контекст (вологість, врожайність), застосовує живі поправки.
function RHM_CombineSettingsDatabase:getSettingsForCrop(cropName, context)
    if not cropName then return nil end

    if not self._mapCropsInitialized then
        self:initMapCrops()
    end

    local rawUpper = cropName:upper()
    local canonical = self:getCanonicalCropName(rawUpper)
    local crop = self.crops[canonical] or self.crops[rawUpper] or self.crops[cropName]
    local baseTemplate = nil

    if crop then
        if not crop.template then
            crop.template = self:calculatePhysicalOptimalSettings(canonical, context)
        end
        baseTemplate = crop.template
    else
        -- Completely unknown or custom mod crop: dynamically derive physical template
        baseTemplate = self:calculatePhysicalOptimalSettings(canonical, context)
        local fillTypeIdx = (context and context.fillType) or (g_fillTypeManager and g_fillTypeManager.getFillTypeIndexByName and g_fillTypeManager:getFillTypeIndexByName(canonical))
        local resolvedTitle = self:resolveEngineCropTitle(canonical, context and context.fruitType, fillTypeIdx)
        resolvedTitle = resolvedTitle or self:getCropDisplayName(canonical)
        local newRecord = {
            name = resolvedTitle,
            nameEN = resolvedTitle,
            title = resolvedTitle,
            template = baseTemplate,
            machineType = (context and context.machineType) or "grain",
            group = "custom",
            fillType = (fillTypeIdx and fillTypeIdx > 0) and fillTypeIdx or nil,
        }
        self.crops[canonical] = newRecord
        self.crops[rawUpper] = newRecord
        rhm_log(string.format("RHM: [CROP DB] Dynamically generated physical profile for mod crop '%s' ('%s', machine: %s)", canonical, tostring(resolvedTitle), tostring(newRecord.machineType)))
    end

    if context and (context.moisture or context.yield) then
        return self:applyEnvironmentalOffsets(baseTemplate, context)
    end

    return baseTemplate
end

-- EN: Converts a game FillType integer to the internal crop name used in the database.
--     Prioritizes actively discovered map crops and alias preservation.
-- UA: Перетворює ціле число FillType гри на внутрішню назву культури у базі даних.
--     Пріоритезує активно виявлені культури карти та збереження аліасів.
function RHM_CombineSettingsDatabase:getCropNameFromFillType(fillType, inputFruitType)
    if not self._mapCropsInitialized then
        self:initMapCrops()
    end

    -- 1. Extract string key from FillType index (query engine fillTypeManager first)
    local fillTypeKey = nil
    if fillType and fillType ~= FillType.UNKNOWN and fillType ~= 0 then
        if g_fillTypeManager and g_fillTypeManager.getFillTypeNameByIndex then
            fillTypeKey = g_fillTypeManager:getFillTypeNameByIndex(fillType)
        end

        if not fillTypeKey then
            for k, v in pairs(FillType) do
                if v == fillType then
                    fillTypeKey = k
                    break
                end
            end
        end

        if fillTypeKey then
            fillTypeKey = fillTypeKey:upper()
        end
    end

    -- 2. Windrow & Straw priority check:
    --    Straw and windrows are collected materials from the ground. They are NEVER standing crops.
    --    Never allow inputFruitType (e.g. underlying alfalfa or weeds under the swath) to override them!
    if fillTypeKey == "STRAW" or fillTypeKey == "STRAW_WINDROW" then
        return "STRAW_WINDROW"
    elseif fillTypeKey == "GRASS_WINDROW" then
        return "GRASS_WINDROW"
    elseif fillTypeKey == "DRYGRASS_WINDROW" or fillTypeKey == "HAY_WINDROW" then
        return "DRYGRASS_WINDROW"
    elseif fillTypeKey == "ALFALFA_WINDROW" or fillTypeKey == "LUCERNE_WINDROW" then
        return "ALFALFA_WINDROW"
    elseif fillTypeKey == "CLOVER_WINDROW" then
        return "CLOVER_WINDROW"
    end

    -- 3. If fillType is generic (CHAFF / SILAGE / GPS) or missing/unknown, consult inputFruitType
    --    to identify what standing crop was chopped.
    local isGenericOrUnknown = (fillTypeKey == nil or fillTypeKey == "CHAFF" or fillTypeKey == "SILAGE" or fillTypeKey == "GPS")
    if isGenericOrUnknown and inputFruitType and inputFruitType ~= FillType.UNKNOWN and inputFruitType ~= 0 then
        if g_fruitTypeManager and g_fruitTypeManager.getFruitTypeByIndex then
            local fDesc = g_fruitTypeManager:getFruitTypeByIndex(inputFruitType)
            if fDesc and fDesc.name then
                local fNameUpper = fDesc.name:upper()
                local canonical = self:getCanonicalCropName(fNameUpper)

                -- EN: When chopped into forage/chaff, standing corn (MAIZE/CORN) is MAIZE_FORAGE, NOT grain MAIZE!
                -- UA: При подрібненні на сінаж/силос, кукурудза (MAIZE/CORN) — це MAIZE_FORAGE, а НЕ зернова кукурудза!
                if canonical == "MAIZE" or canonical == "CORN" or fNameUpper == "MAIZE" or fNameUpper == "CORN" then
                    return "MAIZE_FORAGE"
                end

                -- EN: Standing grass/meadow chopped into chaff -> GRASS
                -- UA: Стояча трава при прямому косінні на силос -> GRASS
                if canonical == "GRASS" or fNameUpper == "GRASS" or fNameUpper == "MEADOW" or fNameUpper == "TALLGRASS" then
                    return "GRASS"
                end

                -- EN: Lucerne / Alfalfa / Clover chopped into chaff
                -- UA: Люцерна / конюшина при подрібненні
                if canonical == "ALFALFA" or canonical == "LUCERNE" or fNameUpper == "ALFALFA" or fNameUpper == "LUCERNE" or fNameUpper == "CLOVER" then
                    return "ALFALFA"
                end

                -- EN: Whole-crop cereals (WHEAT, BARLEY, OAT, RYE, TRITICALE, etc.) chopped into GPS/CHAFF -> MAIZE_FORAGE
                -- UA: Зернові культури прямого скошування на силос (GPS) -> MAIZE_FORAGE
                if canonical == "WHEAT" or canonical == "BARLEY" or canonical == "OAT" or canonical == "RYE" or canonical == "TRITICALE" or canonical == "SPELT" or canonical == "MILLET" then
                    return "MAIZE_FORAGE"
                end

                if self.validMapCrops and (self.validMapCrops[canonical] or self.validMapCrops[fNameUpper]) then
                    return canonical
                end
                local alias = self.cropAliases and self.cropAliases[fNameUpper]
                if alias and self.validMapCrops and (self.validMapCrops[alias] or self.validMapCrops[self:getCanonicalCropName(alias)]) then
                    return self:getCanonicalCropName(alias)
                end
            end
        end
    end

    if not fillTypeKey then
        return nil
    end

    -- 4. If fillTypeKey is directly an active map crop, return canonical
    local canonicalFt = self:getCanonicalCropName(fillTypeKey)
    if self.validMapCrops and (self.validMapCrops[canonicalFt] or self.validMapCrops[fillTypeKey]) then
        return canonicalFt
    end

    -- 5. If fillTypeKey has an alias registered on the map, prefer canonical
    local directAlias = self.cropAliases and self.cropAliases[fillTypeKey]
    if directAlias and self.validMapCrops and (self.validMapCrops[directAlias] or self.validMapCrops[self:getCanonicalCropName(directAlias)]) then
        return self:getCanonicalCropName(directAlias)
    end

    -- 6. Standard fillType to internal crop mapping table (normalized to canonical keys)
    local fillTypeMapping = {
        ["WHEAT"] = "WHEAT",
        ["BARLEY"] = "BARLEY",
        ["OAT"] = "OAT",
        ["OATS"] = "OAT",
        ["CANOLA"] = "CANOLA",
        ["SUNFLOWER"] = "SUNFLOWER",
        ["MAIZE"] = "MAIZE",
        ["CORN"] = "MAIZE",
        ["SOYBEAN"] = "SOYBEAN",
        ["SORGHUM"] = "SORGHUM",
        ["RICE"] = "RICE",
        ["RICE_LONG_GRAIN"] = "RICE_LONG_GRAIN",
        ["RICELONGGRAIN"] = "RICE_LONG_GRAIN",
        ["RICE_LONGGRAIN"] = "RICE_LONG_GRAIN",

        -- FS25 New & Mod Crops
        ["PEA"] = "PEA",
        ["PEAS"] = "PEA",
        ["LENTIL"] = "LENTIL",
        ["CHICKPEA"] = "CHICKPEA",
        ["BEAN"] = "BEANS",
        ["BEANS"] = "BEANS",
        ["FABABEAN"] = "BEANS",
        ["FIELD_BEAN"] = "BEANS",

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
        ["HAY"] = "DRYGRASS",
        ["HAY_WINDROW"] = "DRYGRASS_WINDROW",
        ["TALLGRASS"] = "GRASS",
        ["GRASS_WINDROW"] = "GRASS_WINDROW",
        ["DRYGRASS_WINDROW"] = "DRYGRASS_WINDROW",
        ["STRAW"] = "STRAW_WINDROW",
        ["STRAW_WINDROW"] = "STRAW_WINDROW",
        ["SILAGE"] = "MAIZE_FORAGE",
        ["GPS"] = "MAIZE_FORAGE",
        ["ALFALFA"] = "ALFALFA",
        ["ALFALFA_WINDROW"] = "ALFALFA_WINDROW",
        ["LUCERNE"] = "ALFALFA",
        ["LUCERNE_WINDROW"] = "ALFALFA_WINDROW",
        ["CLOVER_WINDROW"] = "CLOVER_WINDROW",

        -- Cotton
        ["COTTON"] = "COTTON",
    }

    local matchedName = fillTypeMapping[fillTypeKey]

    -- If mapped name has an alias on current map, prefer the map's active fruit
    if matchedName and self.validMapCrops then
        local alias = self.cropAliases and self.cropAliases[matchedName]
        if alias and self.validMapCrops[alias] and not self.validMapCrops[matchedName] then
            matchedName = alias
        end
    end

    if not matchedName and fillTypeKey then
        if fillTypeKey:find("_WINDROW") then
            local baseType = fillTypeKey:gsub("_WINDROW", "")
            matchedName = fillTypeMapping[baseType] or baseType
        elseif fillTypeKey:find("CUT_") then
            local baseType = fillTypeKey:gsub("CUT_", "")
            matchedName = fillTypeMapping[baseType] or baseType
        end
    end

    if not matchedName and fillTypeKey then
        -- Dynamic fallback: register unmapped mod fillType directly as crop name
        matchedName = fillTypeKey
        rhm_log(string.format("RHM: [CROP DB] Dynamic crop auto-registered for FillType: '%s' (ID: %d)", tostring(fillTypeKey), fillType))
    end

    return self:getCanonicalCropName(matchedName) or matchedName
end

---EN: Resolves the official localized display name for a crop directly from the map/engine
---    (fillType.title, fruitType.fillType -> fillType.title, or l10n dictionary).
---UA: Отримує офіційну локалізовану назву культури безпосередньо з карти/рушія гри
---    (fillType.title, fruitType.fillType -> fillType.title, або словник l10n).
function RHM_CombineSettingsDatabase:resolveEngineCropTitle(cropName, fruitTypeIndex, fillTypeIndex)
    if not cropName and not fruitTypeIndex and not fillTypeIndex then
        return nil
    end

    local rawNameUpper = cropName and cropName:upper()
    local alias = rawNameUpper and self.cropAliases and self.cropAliases[rawNameUpper]

    local function isValidTitle(title)
        if not title or title == "" then return false end
        local tUpper = title:upper()
        if rawNameUpper and tUpper == rawNameUpper then return false end
        if alias and tUpper == alias:upper() then return false end
        return true
    end

    local function checkTitleStr(str)
        if not str or str == "" then return nil end
        if str:sub(1, 6) == "$l10n_" and g_i18n and g_i18n.hasText then
            local key = str:sub(7)
            if g_i18n:hasText(key) then
                local res = g_i18n:getText(key)
                if isValidTitle(res) then return res end
            end
        end
        if isValidTitle(str) then
            return str
        end
        return nil
    end

    -- 0. Check dedicated mod localization keys first (e.g. rhm_crop_straw_windrow, rhm_crop_grass_windrow, etc.)
    if rawNameUpper and g_i18n and g_i18n.hasText then
        local l10nKey = "rhm_crop_" .. rawNameUpper:lower()
        if g_i18n:hasText(l10nKey) then
            local res = g_i18n:getText(l10nKey)
            if isValidTitle(res) then return res end
        end
        if alias then
            local aKey = "rhm_crop_" .. alias:lower()
            if g_i18n:hasText(aKey) then
                local res = g_i18n:getText(aKey)
                if isValidTitle(res) then return res end
            end
        end
    end

    -- 1. Try explicit fillTypeIndex via g_fillTypeManager
    if fillTypeIndex and fillTypeIndex ~= FillType.UNKNOWN and g_fillTypeManager then
        local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if ft and ft.title then
            local res = checkTitleStr(ft.title)
            if res then return res end
        end
    end

    -- 2. Try fruitTypeIndex -> fruit.fillTypeIndex -> fillType.title
    if fruitTypeIndex and g_fruitTypeManager then
        local fruit = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
        if fruit then
            if fruit.fillTypeIndex and fruit.fillTypeIndex ~= FillType.UNKNOWN and g_fillTypeManager then
                local ft = g_fillTypeManager:getFillTypeByIndex(fruit.fillTypeIndex)
                if ft and ft.title then
                    local res = checkTitleStr(ft.title)
                    if res then return res end
                end
            end
            if fruit.title then
                local res = checkTitleStr(fruit.title)
                if res then return res end
            end
        end
    end

    -- 3. Try lookup by cropName in g_fillTypeManager (and alias)
    if rawNameUpper and g_fillTypeManager then
        if g_fillTypeManager.getFillTypeByName then
            local ft = g_fillTypeManager:getFillTypeByName(rawNameUpper)
            if ft and ft.title then
                local res = checkTitleStr(ft.title)
                if res then return res end
            end
            if alias then
                local ftAlias = g_fillTypeManager:getFillTypeByName(alias)
                if ftAlias and ftAlias.title then
                    local res = checkTitleStr(ftAlias.title)
                    if res then return res end
                end
            end
        end
        if g_fillTypeManager.getFillTypeIndexByName then
            local ftIdx = g_fillTypeManager:getFillTypeIndexByName(rawNameUpper)
            if ftIdx and ftIdx > 0 then
                local ft = g_fillTypeManager:getFillTypeByIndex(ftIdx)
                if ft and ft.title then
                    local res = checkTitleStr(ft.title)
                    if res then return res end
                end
            end
            if alias then
                local ftIdxAlias = g_fillTypeManager:getFillTypeIndexByName(alias)
                if ftIdxAlias and ftIdxAlias > 0 then
                    local ft = g_fillTypeManager:getFillTypeByIndex(ftIdxAlias)
                    if ft and ft.title then
                        local res = checkTitleStr(ft.title)
                        if res then return res end
                    end
                end
            end
        end
    end

    -- 4. Try lookup by cropName in g_fruitTypeManager (and alias)
    if rawNameUpper and g_fruitTypeManager and g_fruitTypeManager.getFruitTypeByName then
        local fruit = g_fruitTypeManager:getFruitTypeByName(rawNameUpper)
        if not fruit and alias then
            fruit = g_fruitTypeManager:getFruitTypeByName(alias)
        end
        if fruit then
            if fruit.fillTypeIndex and fruit.fillTypeIndex ~= FillType.UNKNOWN and g_fillTypeManager then
                local ft = g_fillTypeManager:getFillTypeByIndex(fruit.fillTypeIndex)
                if ft and ft.title then
                    local res = checkTitleStr(ft.title)
                    if res then return res end
                end
            end
            if fruit.title then
                local res = checkTitleStr(fruit.title)
                if res then return res end
            end
        end
    end

    -- 5. Try game and map l10n dictionary
    if rawNameUpper and g_i18n and g_i18n.hasText then
        local namesToCheck = { rawNameUpper }
        if alias then table.insert(namesToCheck, alias) end
        for _, n in ipairs(namesToCheck) do
            local low = n:lower()
            if g_i18n:hasText("fillType_" .. low) then
                local res = g_i18n:getText("fillType_" .. low)
                if isValidTitle(res) then return res end
            end
            if g_i18n:hasText("fruitType_" .. low) then
                local res = g_i18n:getText("fruitType_" .. low)
                if isValidTitle(res) then return res end
            end
        end
    end

    -- 6. Dynamic windrow fallback: if cropName ends in _WINDROW, resolve base crop and format
    if rawNameUpper and rawNameUpper:find("_WINDROW$") then
        local baseCrop = rawNameUpper:gsub("_WINDROW$", "")
        local baseTitle = self:resolveEngineCropTitle(baseCrop, fruitTypeIndex, fillTypeIndex)
        if baseTitle and baseTitle ~= "" then
            if g_i18n and g_i18n.hasText and g_i18n:hasText("rhm_windrow_format") then
                return string.format(g_i18n:getText("rhm_windrow_format"), baseTitle)
            end
            return baseTitle .. " (Windrow)"
        end
    end

    -- 7. Loose fallback: return whatever non-empty title was found in fillType or fruit
    if fillTypeIndex and fillTypeIndex ~= FillType.UNKNOWN and g_fillTypeManager then
        local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if ft and ft.title and ft.title ~= "" then
            return ft.title
        end
    end
    if rawNameUpper and g_fillTypeManager and g_fillTypeManager.getFillTypeByName then
        local ft = g_fillTypeManager:getFillTypeByName(rawNameUpper)
        if ft and ft.title and ft.title ~= "" then
            return ft.title
        end
    end
    if fruitTypeIndex and g_fruitTypeManager then
        local fruit = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
        if fruit and fruit.title and fruit.title ~= "" then
            return fruit.title
        end
    end

    return nil
end

---EN: Resolves the localized display name for a crop directly from the FS25 engine (fillType.title or fruitType.title).
---UA: Отримує локалізовану назву культури безпосередньо з рушія FS25 (fillType.title або fruitType.title).
function RHM_CombineSettingsDatabase:getCropDisplayName(cropName)
    if not cropName then return "" end

    if not self._mapCropsInitialized then
        self:initMapCrops()
    end

    local rawUpper = cropName:upper()
    local canonical = self:getCanonicalCropName(rawUpper)
    local cropData = self.crops[canonical] or self.crops[rawUpper] or self.crops[cropName]
    local alias = self.cropAliases and (self.cropAliases[cropName] or self.cropAliases[rawUpper] or self.cropAliases[canonical])
    local aliasData = alias and self.crops[alias]

    -- 0. Check stored localized title or name from initMapCrops if genuinely localized (not raw uppercase key)
    if cropData and cropData.title and cropData.title ~= "" and cropData.title:upper() ~= rawUpper and cropData.title:upper() ~= canonical then
        return cropData.title
    end
    if cropData and cropData.name and cropData.name ~= "" and cropData.name:upper() ~= rawUpper and cropData.name:upper() ~= canonical then
        return cropData.name
    end
    if aliasData and aliasData.title and aliasData.title ~= "" and aliasData.title:upper() ~= rawUpper and aliasData.title:upper() ~= canonical then
        return aliasData.title
    end
    if aliasData and aliasData.name and aliasData.name ~= "" and aliasData.name:upper() ~= rawUpper and aliasData.name:upper() ~= canonical then
        return aliasData.name
    end

    -- 1. Try resolving directly from engine (fillType / fruitType / l10n)
    local ftIdx = (cropData and cropData.fillType) or (aliasData and aliasData.fillType)
    local frIdx = (cropData and cropData.fruitType) or (aliasData and aliasData.fruitType)
    local engineTitle = self:resolveEngineCropTitle(canonical, frIdx, ftIdx)
                     or self:resolveEngineCropTitle(cropName, frIdx, ftIdx)
    if engineTitle and engineTitle ~= "" then
        -- Cache into crop record so subsequent calls are instant
        if cropData then
            cropData.title = engineTitle
            cropData.name = engineTitle
        end
        return engineTitle
    end

    -- 2. Clean formatted fallback string (e.g. "Peas", "Greenbean")
    local cleanName = canonical:gsub("_", " ")
    return cleanName:sub(1,1):upper() .. cleanName:sub(2):lower()
end

function RHM_CombineSettingsDatabase:getCropTitle(cropName)
    return self:getCropDisplayName(cropName)
end

-- EN: Returns the full crop data record (template, machineType, group, fillType, names).
-- UA: Повертає повний запис даних культури (шаблон, тип машини, група, fillType, назви).
function RHM_CombineSettingsDatabase:getCropData(cropName)
    if not cropName then return nil end
    if not self._mapCropsInitialized then
        self:initMapCrops()
    end
    local rawUpper = cropName:upper()
    local crop = self.crops[cropName] or self.crops[rawUpper]
    if crop then
        if not crop.template then
            crop.template = self:calculatePhysicalOptimalSettings(cropName)
        end
        -- Dynamic backward compatibility for external consumers expecting .name or .nameEN
        if not crop.name or crop.name:upper() == rawUpper then
            crop.name = self:getCropDisplayName(cropName)
            crop.nameEN = crop.name
            crop.title = crop.name
        end
    end
    return crop
end

-- EN: Returns a sorted list of all registered crop names in the database.
-- UA: Повертає відсортований список всіх зареєстрованих назв культур у базі даних.
function RHM_CombineSettingsDatabase:getAllCropNames()
    local names = {}
    for cropName, _ in pairs(self.crops) do
        table.insert(names, cropName)
    end
    table.sort(names)
    return names
end

---EN: Discovers and registers all harvestable crops from the active map via g_fruitTypeManager.
---UA: Виявляє та реєструє всі культури з поточної карти через g_fruitTypeManager.
function RHM_CombineSettingsDatabase:initMapCrops()
    if self._mapCropsInitialized then
        return
    end
    if not g_fruitTypeManager or not g_fruitTypeManager.getFruitTypes then
        return
    end

    local mapFruitTypes = g_fruitTypeManager:getFruitTypes()
    if not mapFruitTypes or #mapFruitTypes == 0 then
        return
    end

    self._mapCropsInitialized = true
    local validMapCrops = {}

    -- Build lookup sets of fruit indices by category if available
    local grainFruitIndices = {}
    local forageFruitIndices = {}
    if g_fruitTypeManager and g_fruitTypeManager.getFruitTypeIndicesByCategoryNames then
        local grainIndices = g_fruitTypeManager:getFruitTypeIndicesByCategoryNames("GRAINHEADER MAIZECUTTER")
        if grainIndices then
            for _, idx in ipairs(grainIndices) do
                grainFruitIndices[idx] = true
            end
        end
        local forageIndices = g_fruitTypeManager:getFruitTypeIndicesByCategoryNames("DIRECTCUTTER MOWER")
        if forageIndices then
            for _, idx in ipairs(forageIndices) do
                forageFruitIndices[idx] = true
            end
        end
    end

    -- Helper to classify machine type for unknown/mod crops
    local function detectMachineType(nameUpper, fruit)
        if nameUpper == "COTTON" then
            return "cotton"
        elseif nameUpper:find("GRAPE") then
            return "grape"
        elseif nameUpper:find("OLIVE") then
            return "olive"
        elseif nameUpper:find("WEED") or nameUpper:find("OILSEEDRADISH") or nameUpper:find("STONE") then
            return nil -- Not harvestable by standard combines
        elseif nameUpper:find("GREENRYE") or nameUpper:find("GREEN_RYE") or nameUpper:find("SILAGEMAIZE")
            or nameUpper:find("GRASS") or nameUpper:find("ALFALFA") or nameUpper:find("CLOVER")
            or nameUpper:find("SILAGE") or nameUpper:find("CHAFF") or nameUpper:find("FORAGE")
            or nameUpper:find("LUCERNE") or nameUpper:find("POPLAR") or nameUpper:find("MEADOW") then
            return "forage"
        elseif nameUpper:find("POTATO") or nameUpper:find("BEET") or nameUpper:find("CARROT")
            or nameUpper:find("PARSNIP") or nameUpper:find("ONION") or nameUpper:find("GARLIC")
            or nameUpper:find("SPINACH") or nameUpper:find("GREENBEAN") or nameUpper:find("GREEN_BEAN")
            or nameUpper:find("STRINGBEAN") or nameUpper:find("CABBAGE") or nameUpper:find("SUGARCANE") then
            return "root"
        end

        -- Check engine categories if available
        if fruit and fruit.index then
            if grainFruitIndices[fruit.index] then
                return "grain"
            elseif forageFruitIndices[fruit.index] and not grainFruitIndices[fruit.index] then
                return "forage"
            end
        end

        -- Straw producing crops are threshable grain crops
        if fruit and fruit.hasWindrow then
            return "grain"
        end

        return "grain"
    end

    for _, fruit in pairs(mapFruitTypes) do
        local rawName = fruit.name
        if rawName and rawName ~= "" then
            local nameUpper = rawName:upper()
            local canonical = self:getCanonicalCropName(nameUpper)
            local mType = detectMachineType(canonical, fruit) or detectMachineType(nameUpper, fruit)

            if mType ~= nil then
                validMapCrops[nameUpper] = true
                validMapCrops[canonical] = true

                local resolvedTitle = self:resolveEngineCropTitle(canonical, fruit.index, fruit.fillTypeIndex)
                                   or self:resolveEngineCropTitle(nameUpper, fruit.index, fruit.fillTypeIndex)
                resolvedTitle = resolvedTitle or (fruit.title and fruit.title ~= "" and fruit.title) or canonical

                local targetCrop = self.crops[canonical] or self.crops[nameUpper]
                if targetCrop then
                    if fruit.fillTypeIndex then
                        targetCrop.fillType = fruit.fillTypeIndex
                    end
                    if resolvedTitle and resolvedTitle ~= "" and resolvedTitle:upper() ~= canonical and resolvedTitle:upper() ~= nameUpper then
                        targetCrop.title = resolvedTitle
                        targetCrop.name = resolvedTitle
                    end
                    targetCrop.fruitType = fruit.index

                    self.crops[canonical] = targetCrop
                    self.crops[nameUpper] = targetCrop
                else
                    local context = {
                        machineType = mType,
                        fruitType = fruit.index,
                        fillType = fruit.fillTypeIndex
                    }
                    local template = self:calculatePhysicalOptimalSettings(canonical, context)
                    local newRecord = {
                        name = resolvedTitle,
                        nameEN = resolvedTitle,
                        title = resolvedTitle,
                        template = template,
                        machineType = mType,
                        group = "mapCustom",
                        fillType = fruit.fillTypeIndex,
                        fruitType = fruit.index
                    }
                    self.crops[canonical] = newRecord
                    self.crops[nameUpper] = newRecord
                    rhm_log(string.format("RHM: [MAP CROP] Auto-registered map fruit: '%s' ('%s') -> %s", nameUpper, tostring(resolvedTitle), mType))
                end

                -- Also link alias if defined in self.cropAliases (e.g. FLAX <-> LINSEED, MAIZE <-> CORN)
                local alias = self.cropAliases and (self.cropAliases[canonical] or self.cropAliases[nameUpper])
                if alias then
                    validMapCrops[alias] = true
                    if self.crops[alias] == nil then
                        self.crops[alias] = self.crops[canonical]
                    end
                end
            end
        end
    end

    -- Add standard forage windrows/chaff variants if base crop exists
    if validMapCrops["GRASS"] or validMapCrops["MEADOW"] then
        validMapCrops["GRASS_WINDROW"] = true
        validMapCrops["DRYGRASS_WINDROW"] = true
    end
    if validMapCrops["WHEAT"] or validMapCrops["BARLEY"] or validMapCrops["OAT"] then
        validMapCrops["STRAW_WINDROW"] = true
    end
    if validMapCrops["MAIZE"] then
        validMapCrops["MAIZE_FORAGE"] = true
    end
    if validMapCrops["ALFALFA"] or validMapCrops["LUCERNE"] then
        validMapCrops["ALFALFA_WINDROW"] = true
    end
    if validMapCrops["CLOVER"] then
        validMapCrops["CLOVER_WINDROW"] = true
    end

    -- Ensure standard forage and windrow fill types are linked when available in FS25
    if g_fillTypeManager and g_fillTypeManager.getFillTypeIndexByName then
        local windrowFillTypes = {
            STRAW_WINDROW    = "STRAW",
            GRASS_WINDROW    = "GRASS_WINDROW",
            DRYGRASS_WINDROW = "DRYGRASS_WINDROW",
            ALFALFA_WINDROW  = "ALFALFA_WINDROW",
            LUCERNE_WINDROW  = "ALFALFA_WINDROW",
            CLOVER_WINDROW   = "CLOVER_WINDROW",
            MAIZE_FORAGE     = "CHAFF"
        }
        for cropKey, ftName in pairs(windrowFillTypes) do
            local rec = self.crops[cropKey]
            if rec and (not rec.fillType or rec.fillType == 0) then
                local ftIdx = g_fillTypeManager:getFillTypeIndexByName(ftName)
                if ftIdx and ftIdx > 0 then
                    rec.fillType = ftIdx
                end
            end
        end
    end

    -- Pre-resolve titles for windrow & forage crops so they are localized immediately
    local specialCrops = {
        "STRAW_WINDROW",
        "GRASS_WINDROW",
        "DRYGRASS_WINDROW",
        "ALFALFA_WINDROW",
        "LUCERNE_WINDROW",
        "CLOVER_WINDROW",
        "MAIZE_FORAGE",
        "ALFALFA",
        "LUCERNE",
        "GRASS",
        "DRYGRASS"
    }
    for _, cKey in ipairs(specialCrops) do
        local rec = self.crops[cKey]
        if rec then
            local t = self:resolveEngineCropTitle(cKey, rec.fruitType, rec.fillType)
            if t and t ~= "" then
                rec.title = t
                rec.name = t
            end
        end
    end

    self.validMapCrops = validMapCrops
end

-- EN: Returns a sorted list of crop names that match the specified machine type and exist on the current map.
--     Optionally filters by the active vehicle's hopper/tank supported fill types if provided.
-- UA: Повертає відсортований список назв культур що відповідають типу машини та існують на поточній карті.
--     Опціонально фільтрує за підтримуваними типами в бункері комбайна якщо вказано техніку.
function RHM_CombineSettingsDatabase:getCropNamesForMachineType(machineType, vehicle)
    self:initMapCrops()

    -- Gather supported fillType indices from vehicle hopper/tank if available
    local supportedFillTypes = nil
    if vehicle and vehicle.getFillUnits then
        local fillUnits = vehicle:getFillUnits()
        if fillUnits and #fillUnits > 0 then
            for _, fu in ipairs(fillUnits) do
                if fu.supportedFillTypes and next(fu.supportedFillTypes) ~= nil then
                    supportedFillTypes = supportedFillTypes or {}
                    for ftIdx, isSupp in pairs(fu.supportedFillTypes) do
                        if isSupp then
                            supportedFillTypes[ftIdx] = true
                        end
                    end
                end
            end
        end
    end

    local names = {}
    local seenCanonical = {}
    local seenDisplayNames = {}

    local function tryAddCrop(cropName, cropData)
        if cropData.machineType ~= machineType then
            local isGrapeOlivePair = (machineType == "grape" or machineType == "olive") and (cropData.machineType == "grape" or cropData.machineType == "olive")
            if not isGrapeOlivePair then
                return
            end
        end
        local canonical = self:getCanonicalCropName(cropName)
        if self.validMapCrops and not (self.validMapCrops[cropName] or self.validMapCrops[canonical]) then
            return
        end

        local isSupported = true
        if supportedFillTypes and cropData.fillType then
            if not supportedFillTypes[cropData.fillType] then
                isSupported = false
            end
        end
        if not isSupported then
            return
        end

        if seenCanonical[canonical] then
            return
        end

        local displayName = self:getCropDisplayName(canonical):lower()
        if displayName ~= "" and seenDisplayNames[displayName] then
            return
        end

        seenCanonical[canonical] = true
        if displayName ~= "" then
            seenDisplayNames[displayName] = true
        end
        table.insert(names, canonical)
    end

    for cropName, cropData in pairs(self.crops) do
        tryAddCrop(cropName, cropData)
    end

    -- Fallback to all map crops of this machineType if vehicle hopper filter was empty
    if #names == 0 and supportedFillTypes ~= nil then
        seenCanonical = {}
        seenDisplayNames = {}
        for cropName, cropData in pairs(self.crops) do
            if cropData.machineType == machineType then
                local canonical = self:getCanonicalCropName(cropName)
                if not self.validMapCrops or self.validMapCrops[cropName] or self.validMapCrops[canonical] then
                    if not seenCanonical[canonical] then
                        local displayName = self:getCropDisplayName(canonical):lower()
                        if displayName == "" or not seenDisplayNames[displayName] then
                            seenCanonical[canonical] = true
                            if displayName ~= "" then
                                seenDisplayNames[displayName] = true
                            end
                            table.insert(names, canonical)
                        end
                    end
                end
            end
        end
    end

    -- Sort alphabetically by localized display name
    table.sort(names, function(a, b)
        local nameA = self:getCropDisplayName(a):lower()
        local nameB = self:getCropDisplayName(b):lower()
        return nameA < nameB
    end)

    return names
end

-- EN: Calculates a preview of total crop loss for arbitrary settings without applying them.
--     Used in the calibration GUI to show color-coded feedback before the player commits.
--     Loss = 0.15% per unit of deviation above tolerance, capped at 25%.
-- UA: Розраховує попередній перегляд загальних втрат врожаю для довільних налаштувань без їх застосування.
--     Використовується в GUI калібрування для кольорового зворотного зв'язку до підтвердження гравцем.
--     Втрати = 0.15% за одиницю відхилення понад допуск, обмежено до 25%.
function RHM_CombineSettingsDatabase:calcSettingsLossPreview(cropName, settings, context)
    local template = self:getSettingsForCrop(cropName, context)
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
function RHM_CombineSettingsDatabase:isValueValid(cropName, paramName, value, context)
    local settings = self:getSettingsForCrop(cropName, context)
    if not settings or not settings[paramName] then
        return false
    end
    
    local param = settings[paramName]
    return value >= param.min and value <= param.max
end

rhm_log("[OK] RHM_CombineSettingsDatabase loaded with " .. #RHM_CombineSettingsDatabase:getAllCropNames() .. " crops")

