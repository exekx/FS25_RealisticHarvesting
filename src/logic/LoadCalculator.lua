---@class LoadCalculator
-- Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ” Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ Ð½Ð° Ð´Ð²Ð¸Ð³ÑƒÐ½ ÐºÐ¾Ð¼Ð±Ð°Ð¹Ð½Ð°
LoadCalculator = {}
local LoadCalculator_mt = Class(LoadCalculator)

function LoadCalculator.new(modDirectory)
    local self = setmetatable({}, LoadCalculator_mt)
    
    self.debug = false -- TEMPORARY DEBUG ENABLED
    self.modDirectory = modDirectory or g_currentModDirectory  -- Ð—Ð±ÐµÑ€Ñ–Ð³Ð°Ñ”Ð¼Ð¾ modDirectory (with fallback)
    
    -- ÐšÐ¾ÐµÑ„Ñ–Ñ†Ñ–Ñ”Ð½Ñ‚Ð¸ ÑÐºÐ»Ð°Ð´Ð½Ð¾ÑÑ‚Ñ– ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€
    self.CROP_FACTORS = {}
    self:loadDefaultCropFactors()
    
    -- Ð”Ð°Ð½Ñ– Ð´Ð»Ñ Ñ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½ÐºÑƒ ÑÐµÑ€ÐµÐ´Ð½ÑŒÐ¾Ð³Ð¾ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.avgTime = 1500  -- 1.5 ÑÐµÐºÑƒÐ½Ð´Ð¸ Ð¼Ñ–Ð¶ Ð²Ð¸Ð¼Ñ–Ñ€Ð°Ð¼Ð¸
    self.distanceForMeasuring = 3  -- 3 Ð¼ÐµÑ‚Ñ€Ð¸
    
    -- Ð‘Ð°Ð·Ð¾Ð²Ð° Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ (Ð±ÑƒÐ´Ðµ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð° Ð² onLoad)
    self.basePerfMass = 0  -- ÐºÐ³ Ð½Ð° ÑÐµÐºÑƒÐ½Ð´Ñƒ
    self.currentAvgMass = 0
    self.lastAvgMass = 0  -- ÐŸÐ¾Ð¿ÐµÑ€ÐµÐ´Ð½Ñ” ÑÐµÑ€ÐµÐ´Ð½Ñ” (Ð´Ð»Ñ Ñ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½ÐºÑƒ Ð¿Ñ€Ð¸ÑÐºÐ¾Ñ€ÐµÐ½Ð½Ñ)
    self.rawAvgMass = 0  -- Ð¡Ð¸Ñ€Ðµ (Ð½ÐµÐ·Ð³Ð»Ð°Ð´Ð¶ÐµÐ½Ðµ) Ð·Ð½Ð°Ñ‡ÐµÐ½Ð½Ñ Ð´Ð»Ñ Ð°Ð²Ð°Ñ€Ñ–Ð¹Ð½Ð¾Ð³Ð¾ Ð³Ð°Ð»ÑŒÐ¼ÑƒÐ²Ð°Ð½Ð½Ñ
    
    -- ÐŸÐ¾Ñ‚Ð¾Ñ‡Ð½Ðµ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ
    self.engineLoad = 0
    self.speedLimit = 15  -- ÐŸÐ¾Ñ‚Ð¾Ñ‡Ð½Ð¸Ð¹ Ð»Ñ–Ð¼Ñ–Ñ‚ ÑˆÐ²Ð¸Ð´ÐºÐ¾ÑÑ‚Ñ– (ÐºÐ¼/Ð³Ð¾Ð´)
    self.genuineSpeedLimit = 15  -- ÐžÑ€Ð¸Ð³Ñ–Ð½Ð°Ð»ÑŒÐ½Ð¸Ð¹ Ð»Ñ–Ð¼Ñ–Ñ‚ Ð· Ð³Ñ€Ð¸
    self.lastCropType = nil  -- ÐžÑÑ‚Ð°Ð½Ð½Ñ ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð° (Ð´Ð»Ñ Ð´ÐµÑ‚ÐµÐºÑ†Ñ–Ñ— Ð·Ð¼Ñ–Ð½Ð¸)
    self.lastHarvestTime = 0  -- Ð§Ð°Ñ Ð¾ÑÑ‚Ð°Ð½Ð½ÑŒÐ¾Ð³Ð¾ Ð·Ð±Ð¸Ñ€Ð°Ð½Ð½Ñ (Ð´Ð»Ñ Ð´ÐµÑ‚ÐµÐºÑ†Ñ–Ñ— Ñ‚Ñ€Ð¸Ð²Ð°Ð»Ð¾Ñ— Ð¿Ð°ÑƒÐ·Ð¸)
    
    -- Crop loss and productivity
    self.cropLoss = 0  -- ÐŸÐ¾Ñ‚Ð¾Ñ‡Ð½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð²Ñ€Ð¾Ð¶Ð°ÑŽ (%)
    self.tonPerHour = 0  -- ÐŸÑ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð² T/h
    self.litersPerHour = 0  -- ÐŸÑ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð² L/h
    self.totalOutputMass = 0  -- Ð—Ð°Ð³Ð°Ð»ÑŒÐ½Ð° Ð¼Ð°ÑÐ° Ð·Ñ–Ð±Ñ€Ð°Ð½Ð¾Ð³Ð¾ Ð²Ñ€Ð¾Ð¶Ð°ÑŽ
    
    -- ÐÐ°ÐºÐ¾Ð¿Ð¸Ñ‡ÐµÐ½Ð½Ñ Ð´Ð»Ñ Ñ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½ÐºÑƒ T/h Ñ‚Ð° L/h
    self.productivityMass = 0  -- ÐÐ°ÐºÐ¾Ð¿Ð¸Ñ‡ÐµÐ½Ð° Ð¼Ð°ÑÐ° Ð·Ð° Ð¿Ð¾Ñ‚Ð¾Ñ‡Ð½Ð¸Ð¹ Ð¿ÐµÑ€Ñ–Ð¾Ð´ (ÐºÐ³)
    self.productivityLiters = 0  -- ÐÐ°ÐºÐ¾Ð¿Ð¸Ñ‡ÐµÐ½Ð¸Ð¹ Ð¾Ð±'Ñ”Ð¼ Ð·Ð° Ð¿Ð¾Ñ‚Ð¾Ñ‡Ð½Ð¸Ð¹ Ð¿ÐµÑ€Ñ–Ð¾Ð´ (Ð»)
    self.productivityTime = 0  -- Ð§Ð°Ñ Ð½Ð°ÐºÐ¾Ð¿Ð¸Ñ‡ÐµÐ½Ð½Ñ (Ð¼Ñ)
    self.productivityUpdateInterval = 3000  -- ÐžÐ½Ð¾Ð²Ð»ÑŽÐ²Ð°Ñ‚Ð¸ ÐºÐ¾Ð¶Ð½Ñ– 3 ÑÐµÐºÑƒÐ½Ð´Ð¸
    
    -- ÐÐ°ÐºÐ¾Ð¿Ð¸Ñ‡ÑƒÐ²Ð°Ñ‡ Ð´Ð»Ñ Ñ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½ÐºÑƒ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ
    self.loadAccumulatedMass = 0 -- ÐºÐ³
    
    -- Combine Settings System
    self.combineMemory = nil  -- Ð‘ÑƒÐ´Ðµ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð¾ Ð· rhm_Combine
    self.currentCrop = nil    -- ÐŸÐ¾Ñ‚Ð¾Ñ‡Ð½Ð° ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð° Ð´Ð»Ñ Ñ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½ÐºÑƒ settings loss
    
    print("RHM: LoadCalculator initialized")
    
    return self
end

---Ð—Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÑƒÑ” ÑÑ‚Ð°Ð½Ð´Ð°Ñ€Ñ‚Ð½Ñ– ÐºÐ¾ÐµÑ„Ñ–Ñ†Ñ–Ñ”Ð½Ñ‚Ð¸ ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€
function LoadCalculator:loadDefaultCropFactors()
    -- Ð¦Ñ–Ð»ÑŒÐ¾Ð²Ñ– Ñ„Ð°ÐºÑ‚Ð¾Ñ€Ð¸ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ Ð´Ð»Ñ ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€ (Ð²Ñ–Ð´Ð½Ð¾ÑÐ½Ð¾ ÐŸÑˆÐµÐ½Ð¸Ñ†Ñ– = 1.0)
    -- ÐœÐµÐ½ÑˆÐ¸Ð¹ Ñ„Ð°ÐºÑ‚Ð¾Ñ€ = Ð»ÐµÐ³ÑˆÐ° ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð° = ÐºÐ¾Ð¼Ð±Ð°Ð¹Ð½ Ð¼Ð¾Ð¶Ðµ Ñ—Ñ…Ð°Ñ‚Ð¸ ÑˆÐ²Ð¸Ð´ÑˆÐµ
    local factorMap = {
        ["WHEAT"] = 1.447,      -- Target: 1350 bu/hr (@S780, 0.772 kg/L)
        ["BARLEY"] = 1.342,     -- Target: 1800 bu/hr
        ["OAT"] = 3.011,        -- Target: 1200 bu/hr (Small/light grain)
        ["MAIZE"] = 0.442,      -- Target: 5000 bu/hr (High throughput corn)
        ["CORN"] = 0.442,
        ["SOYBEAN"] = 1.184,    -- Target: 1750 bu/hr
        ["SUNFLOWER"] = 2.800,  -- Balanced: ~1200 bu/hr (Original realistic was 5.640 for 600bu/hr, but was too slow in-game)
        ["CANOLA"] = 2.391,     -- Target: 800 bu/hr
        ["SORGHUM"] = 1.085,    -- Target: 2000 bu/hr
        
        -- Ð Ð¸Ñ Ð´ÑƒÐ¶Ðµ Ð²Ð°Ð¶ÐºÐ° ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð°, Ð°Ð»Ðµ Long Grain Ð¼Ð°Ñ” Ð²Ð¸ÑÐ¾ÐºÑƒ Ð±Ð°Ð·Ð¾Ð²Ñƒ Ð¼Ð°ÑÑƒ Ð² FS25
        ["RICE"] = 1.939,       -- Target: 1000 bu/hr
        ["RICE_LONG_GRAIN"] = 1.939,
        
        -- Ð‘Ð¾Ð±Ð¾Ð²Ñ–
        ["PEA"] = 1.611,        -- Target: 1200 bu/hr
        ["LENTIL"] = 1.0,
        ["CHICKPEA"] = 1.0,
        
        -- ÐšÐ¾Ñ€ÐµÐ½ÐµÐ¿Ð»Ð¾Ð´Ð¸
        ["POTATO"] = 0.40,
        ["SUGARBEET"] = 0.30,    -- Ð‘Ð°Ð¶Ð°Ð½Ð¾ ÑˆÐ²Ð¸Ð´ÑˆÐµ 5-8 ÐºÐ¼/Ð³Ð¾Ð´
        ["BEETROOT"] = 0.30,
        ["CARROT"] = 0.25,       -- Ð‘Ñ–Ð»ÑŒÑˆ Ð¾Ð¿Ñ‚Ð¸Ð¼Ð°Ð»ÑŒÐ½Ð° ÑˆÐ²Ð¸Ð´ÐºÑ–ÑÑ‚ÑŒ
        ["PARSNIP"] = 0.25,
        ["ONION"] = 0.35,
        
        -- ÐžÐ²Ð¾Ñ‡Ñ– (Ð·ÐµÐ»ÐµÐ½Ñ–) - Ð´ÑƒÐ¶Ðµ Ð»ÐµÐ³ÐºÑ–, Ñ‚Ð¾Ð¼Ñƒ Ñ„Ð°ÐºÑ‚Ð¾Ñ€ Ð¼Ð°Ñ” Ð±ÑƒÑ‚Ð¸ Ð²Ð¸ÑÐ¾ÐºÐ¸Ð¼ Ñ‰Ð¾Ð± Ð·Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶Ð¸Ñ‚Ð¸ Ð´Ð²Ð¸Ð³ÑƒÐ½
        ["SPINACH"] = 3.5,       -- Ð”Ð»Ñ ÑÑƒÐ¿ÐµÑ€ Ð¿Ð¾Ð²Ñ–Ð»ÑŒÐ½Ð¾Ð³Ð¾ Ð·Ð±Ð¾Ñ€Ñƒ ~2-3 ÐºÐ¼/Ð³Ð¾Ð´
        ["GREENBEAN"] = 3.5,     -- Ð”Ð»Ñ ÑÑƒÐ¿ÐµÑ€ Ð¿Ð¾Ð²Ñ–Ð»ÑŒÐ½Ð¾Ð³Ð¾ Ð·Ð±Ð¾Ñ€Ñƒ ~2-3 ÐºÐ¼/Ð³Ð¾Ð´
        
        -- Ð†Ð½ÑˆÑ– Ð¼Ð¾Ð´ ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð¸
        ["COTTON"] = 1.5,
        ["SUGARCANE"] = 0.1,
        ["POPLAR"] = 0.2,
        ["OILSEED_RADISH"] = 0.5,
        ["GRAPE"] = 0.5,
        ["OLIVE"] = 0.5,
        ["RYE"] = 1.447,
        ["SPELT"] = 1.447,
        ["TRITICALE"] = 0.590,  -- Target: 400 t/hr (Silage)
        ["MILLET"] = 1.2,
        ["ALFALFA"] = 0.858,    -- Target: 262 t/hr (@JD9900)
        ["MINT"] = 1.348,       -- Target: 175 t/hr
    }

    -- Ð”Ð¸Ð½Ð°Ð¼Ñ–Ñ‡Ð½Ð¾ Ð¼Ð°Ð¿Ð¸Ð¼Ð¾ FruitType Enum Ð¿Ð¾ Ñ‚Ð¾Ñ‡Ð½Ð¸Ñ… Ñ€ÑÐ´ÐºÐ°Ñ…
    -- Ð¦Ðµ Ð·Ð°Ñ…Ð¸Ñ‰Ð°Ñ” Ð²Ñ–Ð´ nil ÐºÑ€Ð°ÑˆÑ–Ð² Ñ‚Ð° Ð²Ñ–Ð´ÑÑƒÑ‚Ð½Ð¾ÑÑ‚Ñ– Ð¼Ð¾Ð´/DLC ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€
    for key, value in pairs(FruitType) do
        -- ÐŸÐµÑ€ÐµÐ²Ñ–Ñ€ÑÑ”Ð¼Ð¾ Ñ‡Ð¸ Ñ” Ñ†ÐµÐ¹ ÐºÐ»ÑŽÑ‡ Ñƒ Ð½Ð°ÑˆÐ¾Ð¼Ñƒ ÑÐ»Ð¾Ð²Ð½Ð¸ÐºÑƒ
        local mappedFactor = factorMap[key]
        if mappedFactor then
            self.CROP_FACTORS[value] = mappedFactor
        elseif type(value) == "number" and not key:find("NUM_") then
            -- Ð¯ÐºÑ‰Ð¾ ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð¸ Ð½ÐµÐ¼Ð°Ñ” Ð² ÑÐ¿Ð¸ÑÐºÑƒ, Ð²Ð¾Ð½Ð° Ð¾Ñ‚Ñ€Ð¸Ð¼ÑƒÑ” 1.0 Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼
            -- ÐœÐ¸ Ð½Ðµ Ð·Ð°Ð¿Ð¾Ð²Ð½ÑŽÑ”Ð¼Ð¾ Ð²ÐµÑÑŒ Ð¼Ð°ÑÐ¸Ð² Ð¾Ð´Ð¸Ð½Ð¸Ñ†ÑÐ¼Ð¸ Ñ‰Ð¾Ð± Ð·ÐµÐºÐ¾Ð½Ð¾Ð¼Ð¸Ñ‚Ð¸ Ð¿Ð°Ð¼'ÑÑ‚ÑŒ, fallback to 1.0 Ð±ÑƒÐ´Ðµ Ð¿Ñ€Ð¸ Ð¾Ñ‚Ñ€Ð¸Ð¼Ð°Ð½Ð½Ñ–
        end
    end
end
---Ð’ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÑŽÑ” Ð±Ð°Ð·Ð¾Ð²Ñƒ Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ ÐºÐ¾Ð¼Ð±Ð°Ð¹Ð½Ð° mass-based
---@param basePerfMass number Ð‘Ð°Ð·Ð¾Ð²Ð° Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð² ÐºÐ³/Ñ
function LoadCalculator:setBasePerformance(basePerfMass)
    self.basePerfMass = basePerfMass
    
    if self.debug then
        print(string.format("RHM: Base performance set to %.2f kg/s (%.1f t/h)", 
            self.basePerfMass, self.basePerfMass * 3.6))
    end
end

---ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ” Ð±Ð°Ð·Ð¾Ð²Ñƒ Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð· Ð¿Ð¾Ñ‚ÑƒÐ¶Ð½Ð¾ÑÑ‚Ñ– Ð´Ð²Ð¸Ð³ÑƒÐ½Ð°
---@param vehicle table ÐšÐ¾Ð¼Ð±Ð°Ð¹Ð½
---@return number Ð‘Ð°Ð·Ð¾Ð²Ð° Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð² ÐºÐ³/ÑÐµÐº
function LoadCalculator:getBasePerformanceFromPower(vehicle)
    -- NEW LOGIC: Calculate throughput based on Horsepower
    -- Approximation: 1 HP ~= 0.035 kg/s throughput for Grain
    -- Example: 790 HP (X9 1100) -> 27.65 kg/s -> ~100 t/h
    -- Example: 500 HP (S780) -> 17.5 kg/s -> ~63 t/h
    
    local coef = 0.035  -- Ð¡Ñ‚Ð°Ð½Ð´Ð°Ñ€Ñ‚Ð½Ð¸Ð¹ ÐºÐ¾ÐµÑ„Ñ–Ñ†Ñ–Ñ”Ð½Ñ‚ Ð´Ð»Ñ Ð·ÐµÑ€Ð½Ð¾Ð·Ð±Ð¸Ñ€Ð°Ð»ÑŒÐ½Ð¸Ñ… ÐºÐ¾Ð¼Ð±Ð°Ð¹Ð½Ñ–Ð² (kg/s per HP)
    local power = 0
    
    -- Ð’Ð¸Ð·Ð½Ð°Ñ‡Ð°Ñ”Ð¼Ð¾ Ñ‚Ð¸Ð¿ Ñ‚ÐµÑ…Ð½Ñ–ÐºÐ¸ Ð·Ð° ÐºÐ°Ñ‚ÐµÐ³Ð¾Ñ€Ñ–Ñ”ÑŽ
    local keyCategory = "vehicle.storeData.category"
    local category = vehicle.xmlFile:getValue(keyCategory)
    
    if category == "forageHarvesters" or category == "forageHarvesterCutters" then
        coef = 0.051  -- Forage harvesters: calibrated to JD 9900 (956hp) ~400 t/hr corn silage (community data)
    elseif category == "beetVehicles" or category == "beetHarvesting" then
        coef = 0.060  -- Ð‘ÑƒÑ€ÑÐºÐ¾Ð·Ð±Ð¸Ñ€Ð°Ð»ÑŒÐ½Ñ–: very high throughput
    elseif category == "potatoVehicles" then
        coef = 0.060  -- ÐšÐ°Ñ€Ñ‚Ð¾Ð¿Ð»ÐµÐ·Ð±Ð¸Ñ€Ð°Ð»ÑŒÐ½Ñ–
    elseif category == "cottonVehicles" then
        coef = 0.015  -- Ð‘Ð°Ð²Ð¾Ð²Ð½Ð° (Ð»ÐµÐ³ÐºÐ°, Ð¿Ð¾Ð²Ñ–Ð»ÑŒÐ½Ð° Ð¾Ð±Ñ€Ð¾Ð±ÐºÐ°)
    elseif category == "vegetableVehicles" then
        coef = 0.060  -- ÐžÐ²Ð¾Ñ‡ÐµÐ²Ð° Ñ‚ÐµÑ…Ð½Ñ–ÐºÐ° (Adjusted for realistic load)
    end
    
    -- Ð¡Ð¿Ñ€Ð¾Ð±ÑƒÐ²Ð°Ñ‚Ð¸ Ð¾Ñ‚Ñ€Ð¸Ð¼Ð°Ñ‚Ð¸ Ð¿Ð¾Ñ‚ÑƒÐ¶Ð½Ñ–ÑÑ‚ÑŒ Ð· motorized spec
    if vehicle.spec_motorized and vehicle.spec_motorized.motor then
        power = vehicle.spec_motorized.motor.hp or 0
    end
    
    -- SMART DETECTION: If category didn't match specific types (still default 0.035), checks fillTypes AND Names
    if math.abs(coef - 0.035) < 0.001 then
        local isVegetable = false
        
        -- 1. Check FillTypes (if available)
        if vehicle.getFillUnitFillTypes and vehicle.spec_fillUnit then
            for _, fillUnit in ipairs(vehicle.spec_fillUnit.fillUnits) do
                 if fillUnit.supportedFillTypes then
                     for fillTypeIndex, _ in pairs(fillUnit.supportedFillTypes) do
                        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                        if fillType and fillType.name then
                            local name = string.upper(fillType.name)
                            if name == "ONION" or name == "CARROT" or name == "BEETROOT" or name == "PARSNIP" then
                                isVegetable = true
                                break
                            end
                        end
                     end
                 end
                 if isVegetable then break end
            end
        end
        
        -- 2. Check Vehicle Name / Filename (Fallback for windrowers/diggers like UR-205)
        if not isVegetable then
            local name = string.lower(vehicle:getFullName() or "")
            local xml = string.lower(vehicle.configFileName or "")
            
            if name:find("onion") or name:find("carrot") or name:find("vegetable") or 
               xml:find("onion") or xml:find("carrot") or xml:find("vegetable") or
               name:find("ur%-%d+") or name:find("umr") or name:find("keiler") or -- UR-205, UMR, Ropa Keiler
               xml:find("ur_") or xml:find("umr_") then
                isVegetable = true
                print(string.format("RHM: Smart Detection -> Found keyword in name/xml (%s), assuming Vegetable", name))
            end
        end
        
        if isVegetable then
            coef = 0.060 -- Standardized vegetable coeff
            print("RHM: Applied Vegetable Coef (0.060)")
        end
    end
    
    -- Debug entry
    -- print(string.format("RHM DEBUG: Checking power for %s (cat: %s). Initial power: %s", vehicle:getFullName(), category or "unknown", tostring(power)))
    
    -- NEXAT FIX: Ð¯ÐºÑ‰Ð¾ Ñ†Ðµ Ð¼Ð¾Ð´ÑƒÐ»ÑŒ (Ð½ÐµÐ¼Ð°Ñ” Ð¼Ð¾Ñ‚Ð¾Ñ€Ð°), ÑˆÑƒÐºÐ°Ñ”Ð¼Ð¾ Ð´Ð²Ð¸Ð³ÑƒÐ½ Ñ€ÐµÐºÑƒÑ€ÑÐ¸Ð²Ð½Ð¾ Ð²Ð³Ð¾Ñ€Ñƒ Ð¿Ð¾ Ñ–Ñ”Ñ€Ð°Ñ€Ñ…Ñ–Ñ—
    if (not power or power == 0) then
        local function findVehicleWithEngine(v)
            if not v then return nil end
            
            -- Check current vehicle
            if v.spec_motorized and v.spec_motorized.motor and v.spec_motorized.motor.hp and v.spec_motorized.motor.hp > 0 then
                return v
            end
            
            -- Debug traversal
            -- print(string.format("RHM DEBUG: Search engine in %s (hasAttacher: %s, root: %s)", 
            --    v:getFullName(), tostring(v.getAttacherVehicle ~= nil), v.rootVehicle and v.rootVehicle:getFullName() or "nil"))

            -- Check attacher vehicle (upwards)
            if v.getAttacherVehicle then
                return findVehicleWithEngine(v:getAttacherVehicle())
            end
            
            -- FALLBACK: Check rootVehicle directly if recursion failed/ended
            if v.rootVehicle and v.rootVehicle ~= v then
                 if v.rootVehicle.spec_motorized and v.rootVehicle.spec_motorized.motor and v.rootVehicle.spec_motorized.motor.hp > 0 then
                    return v.rootVehicle
                 end
            end

            return nil
        end
        
        local engineVeh = findVehicleWithEngine(vehicle)
        if engineVeh then
            power = engineVeh.spec_motorized.motor.hp or 0
            -- print(string.format("RHM DEBUG: Found power in hierarchy (%s): %d HP", engineVeh:getFullName(), power))
        end
    end
    
    -- Ð¯ÐºÑ‰Ð¾ Ð½Ðµ Ð·Ð½Ð°Ð¹ÑˆÐ»Ð¸, ÑÐ¿Ñ€Ð¾Ð±ÑƒÐ²Ð°Ñ‚Ð¸ Ð· XML
    if power == 0 then
        local key, motorId = ConfigurationUtil.getXMLConfigurationKey(
            vehicle.xmlFile, 
            vehicle.configurations.motor, 
            "vehicle.motorized.motorConfigurations.motorConfiguration", 
            "vehicle.motorized", 
            "motor"
        )
        local fallbackConfigKey = "vehicle.motorized.motorConfigurations.motorConfiguration(0)"
        local fallbackOldKey = "vehicle"
        
        if SpecializationUtil.hasSpecialization(Motorized, vehicle.specializations) then
            power = ConfigurationUtil.getConfigurationValue(
                vehicle.xmlFile, key, "", "#hp", nil, fallbackConfigKey, fallbackOldKey
            )
        end
    end
    
    if power and tonumber(power) > 0 then
        -- Ð¡Ñ‚Ð°Ð½Ð´Ð°Ñ€Ñ‚Ð½Ð¸Ð¹ Ñ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½Ð¾Ðº: 1 HP ~= 0.035 kg/s throughput
        -- Ð”Ð»Ñ 1100 HP (NEXAT) Ñ†Ðµ Ð±ÑƒÐ´Ðµ ~38.5 kg/s (~138 t/h)
        -- Ð”Ð»Ñ 500 HP Ñ†Ðµ Ð±ÑƒÐ´Ðµ ~17.5 kg/s (~63 t/h)
        local basePerf = tonumber(power) * coef
        
        print(string.format("RHM DEBUG: BasePerf Mass computed for %s (cat: %s, coef: %.3f): %d hp -> %.2f kg/s (%.1f t/h)", 
            vehicle:getFullName(), category or "unknown", coef, power, basePerf, basePerf * 3.6))
        return basePerf
    end
    
    -- NEXAT POWER FIX: Ð¯ÐºÑ‰Ð¾ Ñ†Ðµ NEXAT Ñ– power Ð½Ðµ Ð·Ð½Ð°Ð¹Ð´ÐµÐ½Ð¾, Ð²Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÑ”Ð¼Ð¾ 1100hp
    -- Debug Ð¿Ð¾ÐºÐ°Ð·Ð°Ð² Ñ‰Ð¾ ÑÐ¸ÑÑ‚ÐµÐ¼Ð° Ð½Ðµ Ð±Ð°Ñ‡Ð¸Ñ‚ÑŒ Ð´Ð²Ð¸Ð³ÑƒÐ½ NEXAT (modular structure issue)
    if vehicle.configFileName and vehicle.configFileName:lower():find("nexat") then
        local basePerf = 1100 * coef  -- 1100hp * 0.035 = 38.5 kg/s
        print(string.format("RHM: NEXAT detected with power=0 - using hardcoded 1100 HP -> %.2f kg/s", basePerf))
        return basePerf
    end
    
    print("RHM: Warning - Could not determine combine power, using default basePerf")
    return 10.0  -- Default ~36 t/h
end

---ÐžÐ½Ð¾Ð²Ð»ÑŽÑ” Ð´Ð°Ð½Ñ– Ð´Ð»Ñ Ñ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½ÐºÑƒ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ
---@param vehicle table ÐšÐ¾Ð¼Ð±Ð°Ð¹Ð½
---@param dt number Delta time Ð² Ð¼Ñ
---@param mass number ÐœÐ°ÑÐ° Ð·Ñ–Ð±Ñ€Ð°Ð½Ð¾Ð³Ð¾ Ð²Ñ€Ð¾Ð¶Ð°ÑŽ (ÐºÐ³) - ÐÐžÐ’Ð˜Ð™ ÐŸÐÐ ÐÐœÐ•Ð¢Ð 
function LoadCalculator:update(vehicle, dt, mass)
    -- ÐžÐ½Ð¾Ð²Ð»ÑŽÑ”Ð¼Ð¾ Ð²Ñ–Ð´ÑÑ‚Ð°Ð½ÑŒ
    self.totalDistance = self.totalDistance + vehicle.lastMovedDistance
    
    -- ÐžÐ½Ð¾Ð²Ð»ÑŽÑ”Ð¼Ð¾ Ð¼Ð°ÑÑƒ (Ð·Ð°Ð¼Ñ–ÑÑ‚ÑŒ Ð¿Ð»Ð¾Ñ‰Ñ–)
    self.loadAccumulatedMass = (self.loadAccumulatedMass or 0) + mass
    
    -- INSTANT REACTION FIX:
    -- Ð¯ÐºÑ‰Ð¾ Ð¿Ð¾Ñ‡Ð°Ð»Ð¸ Ð·Ð±Ð¸Ñ€Ð°Ñ‚Ð¸ (mass > 0), Ð° Ð»Ñ–Ð¼Ñ–Ñ‚ Ð²ÑÐµ Ñ‰Ðµ Ð¼Ð°ÐºÑÐ¸Ð¼Ð°Ð»ÑŒÐ½Ð¸Ð¹ - Ð½ÐµÐ³Ð°Ð¹Ð½Ð¾ Ð¾Ð±Ð¼ÐµÐ¶ÑƒÑ”Ð¼Ð¾
    -- ÐÐµ Ñ‡ÐµÐºÐ°Ñ”Ð¼Ð¾ 1.5 ÑÐµÐºÑƒÐ½Ð´Ð¸ Ð²Ð¸Ð¼Ñ–Ñ€ÑŽÐ²Ð°Ð½Ð½Ñ
    if mass > 0 and self.speedLimit >= (self.genuineSpeedLimit - 0.1) then
         self.speedLimit = 5.0 -- ÐšÐ¾Ð½ÑÐµÑ€Ð²Ð°Ñ‚Ð¸Ð²Ð½Ð¸Ð¹ ÑÑ‚Ð°Ñ€Ñ‚
         if self.debug then
            print("RHM: Instant start limit applied: " .. tostring(self.speedLimit))
         end
    end
    
    -- ÐžÐ½Ð¾Ð²Ð»ÑŽÑ”Ð¼Ð¾ Ñ‡Ð°Ñ
    self.currentTime = self.currentTime + dt
    
    -- ÐŸÐµÑ€ÐµÐ²Ñ–Ñ€ÑÑ”Ð¼Ð¾ Ñ‡Ð¸ Ñ‡Ð°Ñ Ð´Ð»Ñ Ð½Ð¾Ð²Ð¾Ð³Ð¾ Ð²Ð¸Ð¼Ñ–Ñ€Ñƒ
    -- ÐŸÐµÑ€ÐµÐ²Ñ–Ñ€Ñ Ñ”Ð¼Ð¾ Ñ‡Ð¸ Ñ‡Ð°Ñ  Ð´Ð»Ñ  Ð½Ð¾Ð²Ð¾Ð³Ð¾ Ð²Ð¸Ð¼Ñ–Ñ€Ñƒ
    if self.currentTime > self.avgTime or self.totalDistance > self.distanceForMeasuring then
        self:updateSettingsImpact() -- ?????? ?????? ????? ???????????
        self:calculateEngineLoad(vehicle)
        self:calculateSpeedLimit(vehicle)
        
        -- Ð¡ÐºÐ¸Ð´Ð°Ñ”Ð¼Ð¾ Ð»Ñ–Ñ‡Ð¸Ð»ÑŒÐ½Ð¸ÐºÐ¸
        self.currentTime = 0
        self.loadAccumulatedMass = 0
        self.totalDistance = 0
    end
end

---Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ” Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ Ð½Ð° Ð´Ð²Ð¸Ð³ÑƒÐ½ (Mass-based)
---@param vehicle table ÐšÐ¾Ð¼Ð±Ð°Ð¹Ð½
function LoadCalculator:calculateEngineLoad(vehicle)
    if self.currentTime <= 0 then
        return
    end
    
    -- ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ”Ð¼Ð¾ ÐºÐ¾ÐµÑ„Ñ–Ñ†Ñ–Ñ”Ð½Ñ‚ ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð¸
    local cropFactor = 1.0
    local spec_combine = vehicle.spec_combine
    if spec_combine and spec_combine.lastValidInputFruitType then
        cropFactor = self.CROP_FACTORS[spec_combine.lastValidInputFruitType] or 1.0
    end
    
    -- PICKUP / SWATH HEADER DETECTION
    -- When lastValidInputFruitType == 0, the machine is using a pickup header (no standing crop being cut).
    -- Pickup/swath work is mechanically easier than direct cut: no cutting resistance, pre-cut material.
    -- Suggested by community (RHM_CropFactorTuner.xlsx): multiply cropFactor by 0.75.
    -- Validated targets: Canola swath S780 ˜ 1,500 bu/hr, Wheat swath ˜ 2,000 bu/hr, Alfalfa JD9900 ˜ 275 t/hr.
    -- This also handles forage harvesters picking up corn silage / alfalfa / triticale windrows.
    if spec_combine and spec_combine.lastValidInputFruitType == 0 then
        cropFactor = cropFactor * 0.75  -- Pickup/swath is easier than direct cut
    end
    
    -- Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ”Ð¼Ð¾ RAW ÑÐµÑ€ÐµÐ´Ð½ÑŽ Ð¼Ð°ÑÑƒ Ð·Ð° ÑÐµÐºÑƒÐ½Ð´Ñƒ (ÐºÐ³/Ñ)
    -- currentTime Ð² Ð¼Ñ, Ñ‚Ð¾Ð¼Ñƒ 1000/currentTime Ð´Ð»Ñ ÑÐµÐºÑƒÐ½Ð´
    -- Ð’Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÑ”Ð¼Ð¾ accumulatedMass
    local rawAvgMass = (self.loadAccumulatedMass or 0) * (1000 / self.currentTime) * cropFactor
    
    -- ADAPTIVE SMOOTHING: Ð±Ñ–Ð»ÑŒÑˆÐµ Ð·Ð³Ð»Ð°Ð´Ð¶ÑƒÐ²Ð°Ð½Ð½Ñ Ð¿Ñ€Ð¸ Ð²Ð¸ÑÐ¾ÐºÐ¾Ð¼Ñƒ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ–
    local loadRatio = self.currentAvgMass / math.max(0.01, self.basePerfMass)
    local smoothFactor = 0.3 + 0.4 * math.min(1.0, loadRatio)
    smoothFactor = math.min(0.7, smoothFactor)  -- Max 70% smoothing
    
    -- Ð—Ð°ÑÑ‚Ð¾ÑÐ¾Ð²ÑƒÑ”Ð¼Ð¾ Ð·Ð³Ð»Ð°Ð´Ð¶ÑƒÐ²Ð°Ð½Ð½Ñ Ñ‚Ñ–Ð»ÑŒÐºÐ¸ ÑÐºÑ‰Ð¾ Ñ” Ð¿Ð¾Ð¿ÐµÑ€ÐµÐ´Ð½Ñ” Ð·Ð½Ð°Ñ‡ÐµÐ½Ð½Ñ
    local avgMass = rawAvgMass
    if self.currentAvgMass > (0.5 * self.basePerfMass) then
        avgMass = (1 - smoothFactor) * rawAvgMass + smoothFactor * self.currentAvgMass
    end
    
    -- Ð—Ð±ÐµÑ€Ñ–Ð³Ð°Ñ”Ð¼Ð¾ Ð¾Ð±Ð¸Ð´Ð²Ð° Ð·Ð½Ð°Ñ‡ÐµÐ½Ð½Ñ Ð´Ð»Ñ Ñ€Ñ–Ð·Ð½Ð¸Ñ… Ñ†Ñ–Ð»ÐµÐ¹
    self.lastAvgMass = self.currentAvgMass
    self.currentAvgMass = avgMass
    self.rawAvgMass = rawAvgMass  -- Ð”Ð»Ñ Ð°Ð²Ð°Ñ€Ñ–Ð¹Ð½Ð¾Ð³Ð¾ Ð³Ð°Ð»ÑŒÐ¼ÑƒÐ²Ð°Ð½Ð½Ñ
    
    -- ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ”Ð¼Ð¾ power boost Ð´Ð»Ñ Ñ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½ÐºÑƒ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    
    -- ÐœÐ°ÐºÑÐ¸Ð¼Ð°Ð»ÑŒÐ½Ð° Ð´Ð¾Ð¿ÑƒÑÑ‚Ð¸Ð¼Ð° Ð¼Ð°ÑÐ° Ð· ÑƒÑ€Ð°Ñ…ÑƒÐ²Ð°Ð½Ð½ÑÐ¼ power boost
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass * (self.settingsEfficiency or 1.0)
    
    -- Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ”Ð¼Ð¾ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ Ð²Ñ–Ð´Ð½Ð¾ÑÐ½Ð¾ maxAvgMass
    if maxAvgMass > 0 then
        self.engineLoad = self.currentAvgMass / maxAvgMass
    else
        self.engineLoad = 0
    end
    
    if self.debug then
        print(string.format("RHM DEBUG: Load: %.1f%% (Raw: %.2f kg/s, Smooth: %.2f kg/s) | Base: %.2f kg/s | Max: %.2f kg/s", 
            self.engineLoad * 100, rawAvgMass, self.currentAvgMass, self.basePerfMass, maxAvgMass))
    end
end

---Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ” Ð¾Ð±Ð¼ÐµÐ¶ÐµÐ½Ð½Ñ ÑˆÐ²Ð¸Ð´ÐºÐ¾ÑÑ‚Ñ–
---@param vehicle table ÐšÐ¾Ð¼Ð±Ð°Ð¹Ð½
---?????????? ????????? ????????? (Adaptive Target Loading)
---@param vehicle table ???????
function LoadCalculator:calculateSpeedLimit(vehicle)
    -- ???? ?? ???????? ?????? (mass = 0), ?????? ??????????? ????? ?? ?????????
    if self.currentAvgMass == 0 then
        if self.speedLimit < self.genuineSpeedLimit then
            -- ?????????? ??????????? ?????? ??? ???? (+1.0/?)
            self.speedLimit = math.min(self.genuineSpeedLimit, self.speedLimit + 1.0)
        end
        return
    end
    
    -- INSTANT REACTION FIX: ?????? ???? (????? ? ?????)
    -- ???? ?? ???? ??????? ???? (?????????, ?? ?????????) ? ?????? ???????? ?????? ??????,
    -- ? ????????? ??? ?? ????? ??????????? – ?? ??????? LERP. ??????? "?'??? ?? ???????"
    -- ?? ~5 ??/???, ????????? ??? ??????????. ?????????? ????????? ??? ?? ??? ????????? ?????????.
    if self.lastAvgMass == 0 and self.currentAvgMass > 5 and self.speedLimit > 8.0 then
         self.speedLimit = 5.0
         if self.debug then print("RHM: [INSTANT START PROTECT] Snapped to 5.0 km/h on row entry!") end
    end
    
    -- ???????? ????: ?????????????? ??????? ????????? (lastSpeedReal), ? ?? ????????? ???????. 
    -- ???? ??????????????? ??????? ?? ??????? 1.5 ???, ? ??????? ??????????? ?? 2 ??/???,
    -- ?????????? ?????? 2 ??/??? ? ???????? ???????? ??????? ?????????, ?????????? ? ??????.
    local currentSpeed = vehicle.lastSpeedReal * 3600 -- convert m/s to km/h
    
    -- ???? ??????? ????? ????????? (< 1 ??/???), ??? ???????????? ? (???????), 
    -- ?? ?? ?????? ??????? ?? ????????? 0. ?????????????? ???????? ????? ?? ?????? ????????.
    local speedKmh = math.max(1.0, currentSpeed)
    if currentSpeed < 1.0 and self.currentAvgMass > (self.basePerfMass * 0.1) then
        speedKmh = math.max(2.0, self.speedLimit)
    end
    
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass * (self.settingsEfficiency or 1.0)
    
    -- ?????????? ??????? ?? ????
    if maxAvgMass <= 0.01 then return end
    
    local loadRatio = self.currentAvgMass / maxAvgMass
    local rawLoadRatio = (self.rawAvgMass or self.currentAvgMass) / maxAvgMass
    
    -- PREDICTIVE TARGETING: Target 85% load (0.85)
    local targetLoad = 0.85
    local idealSpeed = self.genuineSpeedLimit
    
    if loadRatio > 0.05 then 
        -- ???????? throughput (mass) ????? ???????????? ?????????:
        -- New_Speed = Current_Speed * (Target_Load / Current_Load)
        idealSpeed = speedKmh * (targetLoad / loadRatio)
    end
    
    idealSpeed = math.min(self.genuineSpeedLimit, math.max(2.0, idealSpeed))
    
    -- LERP DAMPING LAYER
    local alpha = 0.1 -- Normal smoothing factor
    local controlZone = "NORMAL"
    
    -- ???????? ??????????? ??? ????? ????????? LERP ?? ??????? ????????? ???? (loadRatio)
    if rawLoadRatio > 1.25 then
        alpha = 1.0 -- Panic brake: INSTANT SNAP
        controlZone = "PANIC"
        -- ????????????? idealSpeed ???????? ????????? ???????, ??? ??????????? ????? ???????????
        -- ?????????????? self.speedLimit, ??? ??????? ?????? ????????? ???????? ????????? ??????,
        -- ? ?? ??????? (speedKmh), ??? ????? ????????
        local emergencyIdeal = math.min(speedKmh, self.speedLimit) * (targetLoad / rawLoadRatio)
        idealSpeed = math.min(idealSpeed, math.max(2.0, emergencyIdeal))
    elseif rawLoadRatio > 1.10 then
        alpha = 0.6 -- Hard brake: VERY FAST
        controlZone = "HARD_BRAKE"
        local hardbrakeIdeal = math.min(speedKmh, self.speedLimit) * (targetLoad / rawLoadRatio)
        idealSpeed = math.min(idealSpeed, math.max(2.0, hardbrakeIdeal))
    elseif loadRatio >= 0.85 and loadRatio <= 0.95 then
        -- DEADBAND: ???? ?? ???? ??????? ?? ??????? (85-95%),
        -- ???????? ????????? (??????????? ????? alpha), ??? ???????? ?????-????????
        alpha = 0.02
        controlZone = "LOCKED"
    elseif loadRatio < 0.85 then
        -- ?????? ?????? ???????:
        -- ?????? ??????? ????? ???????? ?????????? (alpha = 0.05), ????? ??
        -- ??????? ?? ???????? ???????? ????? ?????????? ???????????.
        if loadRatio < 0.50 then
            alpha = 0.40 -- ???? ??????? ?????? ?? ?????? ????????, ??? ????? ????????? ??????????
            controlZone = "ACCELERATING_FAST"
        elseif loadRatio < 0.75 then
            alpha = 0.25 -- ???????? ??????, ???????????????? ???? ???????????? ????? ??????? ?? ?????
            controlZone = "ACCELERATING_MED"
        else
            alpha = 0.15 -- ??????? ?????? ?? ???????
            controlZone = "ACCELERATING_SLOW"
        end
    end
    
    local diff = idealSpeed - self.speedLimit
    local maxStep = 1.0
    -- ?????? ?????????? ????? ??? ?????????? ???????????
    if controlZone == "PANIC" then maxStep = 10.0 end
    if controlZone == "HARD_BRAKE" then maxStep = 5.0 end
    
    local step = diff * alpha
    step = math.clamp(step, -maxStep, maxStep)
    
    self.speedLimit = self.speedLimit + step
    
    if self.debug then
        print(string.format("RHM: [%s] Load: %.1f%% | Speed: %.1f->%.1f (Ideal: %.1f) | Alpha: %.2f",
            controlZone, loadRatio * 100, speedKmh, self.speedLimit, idealSpeed, alpha))
    end
end

---ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ” Ð¿Ð¾Ñ‚Ð¾Ñ‡Ð½Ðµ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ Ð½Ð° Ð´Ð²Ð¸Ð³ÑƒÐ½
---@return number ÐÐ°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ Ð² Ð²Ñ–Ð´ÑÐ¾Ñ‚ÐºÐ°Ñ… (0-100+)
function LoadCalculator:getEngineLoad()
    return self.engineLoad * 100
end

---ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ” Ð¿Ð¾Ñ‚Ð¾Ñ‡Ð½Ð¸Ð¹ Ð»Ñ–Ð¼Ñ–Ñ‚ ÑˆÐ²Ð¸Ð´ÐºÐ¾ÑÑ‚Ñ–
---@return number Ð›Ñ–Ð¼Ñ–Ñ‚ ÑˆÐ²Ð¸Ð´ÐºÐ¾ÑÑ‚Ñ– Ð² ÐºÐ¼/Ð³Ð¾Ð´
function LoadCalculator:getSpeedLimit()
    return self.speedLimit or 0
end



---Ð’ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÑŽÑ” Ð¾Ñ€Ð¸Ð³Ñ–Ð½Ð°Ð»ÑŒÐ½Ðµ Ð¾Ð±Ð¼ÐµÐ¶ÐµÐ½Ð½Ñ ÑˆÐ²Ð¸Ð´ÐºÐ¾ÑÑ‚Ñ– ÐºÐ¾Ð¼Ð±Ð°Ð¹Ð½Ð°
---@param limit number ÐžÑ€Ð¸Ð³Ñ–Ð½Ð°Ð»ÑŒÐ½Ð¸Ð¹ Ð»Ñ–Ð¼Ñ–Ñ‚ Ð² ÐºÐ¼/Ð³Ð¾Ð´
function LoadCalculator:setGenuineSpeedLimit(limit)
    self.genuineSpeedLimit = limit
    self.speedLimit = limit
end

---Ð¡ÐºÐ¸Ð´Ð°Ñ” Ð²ÑÑ– Ð´Ð°Ð½Ñ–
function LoadCalculator:reset()
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.currentAvgMass = 0
    self.engineLoad = 0
    self.cropLoss = 0
    -- Ð¡ÐºÐ¸Ð´Ð°Ñ”Ð¼Ð¾ speedLimit Ð´Ð¾ genuineSpeedLimit (ÐºÐ¾Ð»Ð¸ Ð½Ðµ ÐºÐ¾ÑÐ¸Ð¼Ð¾)
    self.speedLimit = self.genuineSpeedLimit
    
    -- Ð¡ÐºÐ¸Ð´Ð°Ñ”Ð¼Ð¾ Ð½Ð°ÐºÐ¾Ð¿Ð¸Ñ‡ÐµÐ½Ð½Ñ Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ð¾ÑÑ‚Ñ–
    self.productivityMass = 0
    self.productivityLiters = 0
    self.productivityTime = 0
    self.tonPerHour = 0
    self.litersPerHour = 0
    
    -- Ð¡ÐºÐ¸Ð´Ð°Ñ”Ð¼Ð¾ Ð±ÑƒÑ„ÐµÑ€Ð¸ Ð²Ñ€Ð¾Ð¶Ð°Ð¹Ð½Ð¾ÑÑ‚Ñ– Ñ‚Ð° ÑˆÑƒÐ¼Ñƒ
    self.yieldBuffer = {}
    self.currentYield = 0
    self.instantYield = 0
    
    if self.debug then
        print("RHM: LoadCalculator reset")
    end
end

---?????????? ?????? ?????? ??? ??????????????
---@return number ?????? ? ????????? (0-50)
function LoadCalculator:calculateCropLoss()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return 0
    end
    
    if not g_realisticHarvestManager.settings.enableCropLoss then
        return 0
    end
    
    -- "OVERLOAD SHIELD": 
    -- ??????? ????? ????? = 95%.
    -- ??? ???? ???????????? ???????? (efficiency > 1.0, ?? 1.05), 
    -- ?? ??????? ??? ????? ?? ?????? (?? +5%). 
    -- ????? ????????? ??????? ????? ?????? ????? ???? ??? 100% ????????????, 
    -- ????????? ?????? ????????? ??? ???????? ???? (???????).
    local activeEfficiency = self.settingsEfficiency or 1.0
    local shieldBonus = math.max(0, activeEfficiency - 1.0)
    local lossThreshold = 0.95 + shieldBonus
    
    -- ?????? ???????????, ???? ?? ??????????? ?????
    if self.engineLoad > lossThreshold then
        -- overload = ???????? ??????????? ?????? 
        local overload = self.engineLoad - lossThreshold
        
        local lossMultiplier = g_realisticHarvestManager.settings:getLossMultiplier()
        
        -- ??????? ?????????:
        local loss = 0
        if overload <= 0.10 then
            -- ? +0% ?? +10% ??? ?????? ?????? ??????? ?? 4% ?????
            loss = overload * 40 * lossMultiplier
        elseif overload <= 0.20 then
            -- ? +10% ?? +20% ??? ?????? ????????????? (??? 4% ?? 12%)
            loss = (4.0 + (overload - 0.10) * 80) * lossMultiplier
        else
            -- ????? +20% ??? ?????? ?????? ?????? ???????????? (?? 50%)
            loss = (12.0 + (overload - 0.20) * 150) * lossMultiplier
        end
        
        self.cropLoss = math.min(loss, 50) -- ???????? 50% ?????
    else
        self.cropLoss = 0
    end
    
    return self.cropLoss
end

---Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ” Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð²Ñ–Ð´ Ð½ÐµÐ¿Ñ€Ð°Ð²Ð¸Ð»ÑŒÐ½Ð¸Ñ… Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½ÑŒ ÐºÐ¾Ð¼Ð±Ð°Ð¹Ð½Ð°
---??????? ????? ??????????? ???????? ?? ???????????? (????????? ?????????) ?? ????? ??????
function LoadCalculator:updateSettingsImpact()
    -- ?????? ???????? (??????????)
    self.settingsEfficiency = 1.0
    self.settingsLoss = 0
    
    if not self.combineMemory or not self.currentCrop then
        return
    end
    
    -- ????????? ????????? ?????????? ????????? ???????????
    local effPenalty, lossPenalty, _ = self.combineMemory:checkSettingsForCrop(self.currentCrop)
    
    -- 1. ???????????? (??????? ?? ????????? ???????? ????? maxAvgMass)
    if effPenalty < 0 then
        -- ???????? ???????????? ???????????? (?????)
        -- ???????????? effPenalty = -1.0 (2 ???????? ?????????). 
        -- ??????? ?? 5, ??? ???????? ???????? +5% ????? ?? ?????????.
        -- ?????????: -1.0 * 5 = -5.0. ???? 1.0 + (5 / 100) = 1.05.
        self.settingsEfficiency = 1.0 + (math.abs(effPenalty) * 5.0 / 100.0)
    else
        -- ?????? ???????????? ???????????? (?????)
        -- ???? ????? ????????? ??? ?????? ?????? ??????, ???????? ????? ??????? ????.
        self.settingsEfficiency = 1.0 - (effPenalty / 100.0)
    end
    
    -- 2. ?????? ?????? (????? ??????????? ??? ?? ?????????????)
    if lossPenalty < 0 then
        -- ???????????? ?? ?????? "???????" ?????????? ?????. ???????? ???????????? ????? 0% ?????????? ?????.
        self.settingsLoss = 0 
    else
        -- ???? ????? ????? ??????? ??? ?????? ???????, ????? ?????? ?? ????.
        self.settingsLoss = lossPenalty
    end
end
---@return number totalLoss ???????? ?????? (0-50%)
function LoadCalculator:calculateTotalCropLoss()
    -- ?????? ?????? ??? ?????????????? ???????
    local baseLoss = self:calculateCropLoss()
    
    -- ????? ?????? ??? ??????? ??????????? (????????? ?????)
    local settingsAddedLoss = self.settingsLoss or 0
    
    -- ???????? ?????? (?????????)
    local totalLoss = baseLoss + settingsAddedLoss
    
    -- ????????? ????????
    totalLoss = math.min(totalLoss, 50)
    
    -- ?????????? ??? ???????????? ? HUD
    self.cropLoss = totalLoss
    
    return totalLoss
end
---@return number Ð’Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð² Ð²Ñ–Ð´ÑÐ¾Ñ‚ÐºÐ°Ñ… (0-50)
function LoadCalculator:getCropLoss()
    return self.cropLoss
end

---ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ” Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð² Ñ‚Ð¾Ð½Ð½Ð°Ñ… Ð½Ð° Ð³Ð¾Ð´Ð¸Ð½Ñƒ
---@return number ÐŸÑ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð² T/h
function LoadCalculator:getTonPerHour()
    return self.tonPerHour
end

---ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ” Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð² Ð»Ñ–Ñ‚Ñ€Ð°Ñ… Ð½Ð° Ð³Ð¾Ð´Ð¸Ð½Ñƒ (Ð´Ðµ Ñ„Ð°ÐºÑ‚Ð¾ volume flow)
---@return number ÐŸÑ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð² L/h
function LoadCalculator:getLitersPerHour()
    return self.litersPerHour or 0
end

---ÐžÐ½Ð¾Ð²Ð»ÑŽÑ” Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ð½Ð° Ð¾ÑÐ½Ð¾Ð²Ñ– Ð·Ñ–Ð±Ñ€Ð°Ð½Ð¾Ñ— Ð¼Ð°ÑÐ¸ Ñ‚Ð° Ð¾Ð±'Ñ”Ð¼Ñƒ
---@param mass number ÐœÐ°ÑÐ° Ð·Ñ–Ð±Ñ€Ð°Ð½Ð¾Ð³Ð¾ Ð²Ñ€Ð¾Ð¶Ð°ÑŽ Ð² ÐºÐ³
---@param liters number ÐžÐ±Ñ”Ð¼ Ð·Ñ–Ð±Ñ€Ð°Ð½Ð¾Ð³Ð¾ Ð²Ñ€Ð¾Ð¶Ð°ÑŽ Ð² Ð»
---@param dt number Delta time Ð² Ð¼Ñ
---@param dt number Delta time in ms
---@param dt number Delta time in ms
function LoadCalculator:updateProductivity(mass, liters, dt)
    self.totalOutputMass = self.totalOutputMass + mass
    
    -- High Precision Sliding Window (Extended to 12s for stability)
    self.prodBuffer = self.prodBuffer or {}
    table.insert(self.prodBuffer, {m = mass, l = liters or 0, t = dt})
    
    self.currentBufferTime = (self.currentBufferTime or 0) + dt
    while #self.prodBuffer > 1 and self.currentBufferTime > 12000 do
        local old = table.remove(self.prodBuffer, 1)
        self.currentBufferTime = self.currentBufferTime - old.t
    end
    
    local sumMass = 0
    local sumLiters = 0
    local sumTime = 0
    for _, v in ipairs(self.prodBuffer) do
        sumMass = sumMass + v.m
        sumLiters = sumLiters + v.l
        sumTime = sumTime + v.t
    end
    
    if sumTime > 100 then
        local hours = sumTime / 3600000
        local rawTonPerHour = (sumMass / 1000) / hours
        self.litersPerHour = sumLiters / hours
        
        -- Damping (Smooth LERP)
        local alpha = 0.05
        if self.tonPerHour == 0 then self.tonPerHour = rawTonPerHour end
        self.tonPerHour = self.tonPerHour * (1 - alpha) + rawTonPerHour * alpha
    else
        self.tonPerHour = 0
        self.litersPerHour = 0
    end
end

---??????? ?????????????? ? ???????????
---@param mass number ???? (??)
---@param liters number ??'?? (?)
---@param area number ????? (?2)
---@param dt number ??? (??)
function LoadCalculator:updateProductivityAndYield(mass, liters, area, dt)
    self:updateProductivity(mass, liters, dt)
    
    if area <= 0.0001 and mass <= 0.001 then
        self.currentYield = self.currentYield or 0
        return
    end
    
    -- Long-term Yield Average (~90 seconds / 600 samples)
    self.yieldBuffer = self.yieldBuffer or {}
    table.insert(self.yieldBuffer, {m = mass, a = area})
    if #self.yieldBuffer > 600 then table.remove(self.yieldBuffer, 1) end
    
    local sumMass = 0
    local sumArea = 0
    for _, v in ipairs(self.yieldBuffer) do 
        sumMass = sumMass + v.m
        sumArea = sumArea + v.a 
    end
    
    if sumArea > 0.1 then
        local rawYield = (sumMass / sumArea) * 10
        
        -- Damping (Smooth LERP)
        local alpha = 0.03
        if not self.currentYield or self.currentYield == 0 then self.currentYield = rawYield end
        self.currentYield = self.currentYield * (1 - alpha) + rawYield * alpha
    end
end
function LoadCalculator:setRealTimeYield(yieldTha)
    -- Apply smoothing (Simple moving average)
    self.yieldBuffer = self.yieldBuffer or {}
    table.insert(self.yieldBuffer, yieldTha)
    if #self.yieldBuffer > 20 then table.remove(self.yieldBuffer, 1) end
    
    local sum = 0
    for _, v in ipairs(self.yieldBuffer) do sum = sum + v end
    local smoothedYield = sum / #self.yieldBuffer

    -- No Calibration - Pure Real-time Yield (User Request)
    self.currentYield = smoothedYield
end

---ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ” Ñ„Ð¾Ñ€Ð¼Ð°Ñ‚Ð¾Ð²Ð°Ð½Ð¸Ð¹ Ñ€ÑÐ´Ð¾Ðº Ð²Ñ€Ð¾Ð¶Ð°Ð¹Ð½Ð¾ÑÑ‚Ñ–
---@param unitSystem number (1=Metric, 2=Imperial, 3=Bushels)
---@return string, string (Value, Unit)
function LoadCalculator:getYieldText(unitSystem)
    -- BUGFIX: Removed duplicate T/h calculation that was causing jumps
    -- This method is now a PURE GETTER for Yield only
    
    local yield = self.currentYield or 0
    
    if yield < 0.1 then return "0.0", "t/ha" end
    
    if unitSystem == 2 then -- Imperial (UK/US tons per acre?) 
        -- 1 t/ha = 0.446 t/ac (approx short ton) or just use t/ac
        local t_ac = yield * 0.446
        return string.format("%.2f", t_ac), "t/ac"
        
    elseif unitSystem == 3 then -- Bushels (bu/ac)
        -- Standard conversion factor (avg for grains): ~15
        local bu_ac = yield * 15 
        return string.format("%.0f", bu_ac), "bu/ac"
        
    else -- Metric (t/ha)
        return string.format("%.1f", yield), "t/ha"
    end
end

