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
    self.workingSpeedLimit = 0  -- Ð Ð¾Ð±Ð¾Ñ‡Ð¸Ð¹ Ð»Ñ–Ð¼Ñ–Ñ‚ (Ð·Ð±ÐµÑ€Ñ–Ð³Ð°Ñ”Ñ‚ÑŒÑÑ Ð¼Ñ–Ð¶ ÑÐµÑÑ–ÑÐ¼Ð¸ Ð·Ð±Ð¸Ñ€Ð°Ð½Ð½Ñ)
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
        ["WHEAT"] = 1.0,
        ["BARLEY"] = 1.0,
        ["OAT"] = 1.5,           -- Ð‘ÑƒÐ»Ð¾ 2.2, ÑÐºÐ¸Ð´Ð°Ñ”Ð¼Ð¾ Ñ‰Ð¾Ð± Ð½Ðµ Ð¾Ð±Ð¼ÐµÐ¶ÑƒÐ²Ð°Ñ‚Ð¸ Ð´Ð¾ 14 ÐºÐ¼/Ð³Ð¾Ð´
        ["MAIZE"] = 1.2,
        ["CORN"] = 1.2,
        ["SOYBEAN"] = 1.4,       -- Ð‘ÑƒÐ»Ð¾ 1.8
        ["SUNFLOWER"] = 1.5,     -- Ð‘ÑƒÐ»Ð¾ 2.0
        ["CANOLA"] = 1.3,
        ["SORGHUM"] = 1.0,       -- Ð‘ÑƒÐ»Ð¾ 0.9
        
        -- Ð Ð¸Ñ Ð´ÑƒÐ¶Ðµ Ð²Ð°Ð¶ÐºÐ° ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð°, Ð°Ð»Ðµ Long Grain Ð¼Ð°Ñ” Ð²Ð¸ÑÐ¾ÐºÑƒ Ð±Ð°Ð·Ð¾Ð²Ñƒ Ð¼Ð°ÑÑƒ Ð² FS25
        ["RICE"] = 1.8,          -- Ð”Ð»Ñ ~4-5 ÐºÐ¼/Ð³Ð¾Ð´
        ["RICE_LONG_GRAIN"] = 0.5, -- Ð¤Ð°ÐºÑ‚Ð¾Ñ€ 1.0 Ð´Ð°Ð²Ð°Ð² 2 ÐºÐ¼/Ð³Ð¾Ð´. Ð—Ð¼ÐµÐ½ÑˆÑƒÑ”Ð¼Ð¾ Ð´Ð¾ 0.5 Ñ‰Ð¾Ð± Ð¾Ñ‚Ñ€Ð¸Ð¼Ð°Ñ‚Ð¸ ~4 ÐºÐ¼/Ð³Ð¾Ð´
        
        -- Ð‘Ð¾Ð±Ð¾Ð²Ñ–
        ["PEA"] = 1.0,
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
        ["RYE"] = 1.0,
        ["SPELT"] = 1.0,
        ["TRITICALE"] = 1.0,
        ["MILLET"] = 0.9,
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
        coef = 0.150  -- ÐšÐ¾Ñ€Ð¼Ð¾Ð·Ð±Ð¸Ñ€Ð°Ð»ÑŒÐ½Ñ–: ~150-200 t/h -> 0.15 kg/s per HP
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
    -- print(string.format("RHM DEBUG: Checking power for %s. Initial power: %s", vehicle:getFullName(), tostring(power)))
    
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
         if self.workingSpeedLimit > 0 and self.workingSpeedLimit < 12 then
             self.speedLimit = self.workingSpeedLimit
         else
             self.speedLimit = 5.0 -- ÐšÐ¾Ð½ÑÐµÑ€Ð²Ð°Ñ‚Ð¸Ð²Ð½Ð¸Ð¹ ÑÑ‚Ð°Ñ€Ñ‚
             self.workingSpeedLimit = 5.0
         end
         if self.debug then
            print("RHM: Instant start limit applied: " .. tostring(self.speedLimit))
         end
    end
    
    -- ÐžÐ½Ð¾Ð²Ð»ÑŽÑ”Ð¼Ð¾ Ñ‡Ð°Ñ
    self.currentTime = self.currentTime + dt
    
    -- ÐŸÐµÑ€ÐµÐ²Ñ–Ñ€ÑÑ”Ð¼Ð¾ Ñ‡Ð¸ Ñ‡Ð°Ñ Ð´Ð»Ñ Ð½Ð¾Ð²Ð¾Ð³Ð¾ Ð²Ð¸Ð¼Ñ–Ñ€Ñƒ
    if self.currentTime > self.avgTime or self.totalDistance > self.distanceForMeasuring then
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
    
    -- PICKUP HEADER DETECTION: Check output fill type for grass
    -- Pickup headers have lastCuttersOutputFillType = GRASS but InputFruitType = 0
    -- Direct cutting has both Input and Output as GRASS
    if spec_combine and spec_combine.lastCuttersOutputFillType then
        local outputFill = spec_combine.lastCuttersOutputFillType
        if outputFill == FillType.GRASS or 
           outputFill == FillType.GRASS_WINDROW or
           outputFill == FillType.DRYGRASS_WINDROW then
            -- Only apply lighter cropFactor for pickup headers (Input=0)
            -- Direct cutting uses cropFactor from XML
            if spec_combine.lastValidInputFruitType == 0 then
                cropFactor = 0.35  -- Pickup = lighter crop, faster speed
            end
        end
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
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass
    
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
function LoadCalculator:calculateSpeedLimit(vehicle)
    -- Ð¯ÐºÑ‰Ð¾ Ð½Ðµ Ð·Ð±Ð¸Ñ€Ð°Ñ”Ð¼Ð¾ Ð²Ñ€Ð¾Ð¶Ð°Ð¹ (mass = 0), Ð¿Ð»Ð°Ð²Ð½Ð¾ Ð²Ñ–Ð´Ð¿ÑƒÑÐºÐ°Ñ”Ð¼Ð¾ Ð»Ñ–Ð¼Ñ–Ñ‚
    if self.currentAvgMass == 0 then
        -- Ð—Ð±ÐµÑ€Ñ–Ð³Ð°Ñ”Ð¼Ð¾ workingSpeedLimit Ð¢Ð†Ð›Ð¬ÐšÐ˜ ÑÐºÑ‰Ð¾ Ð²Ñ–Ð½ Ð´Ñ–Ð¹ÑÐ½Ð¾ Ð²Ñ–Ð´Ð¾Ð±Ñ€Ð°Ð¶Ð°Ñ”
        -- Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÑƒÐ²Ð°Ð»ÑŒÐ½Ðµ Ð¾Ð±Ð¼ÐµÐ¶ÐµÐ½Ð½Ñ (< 75% genuineSpeedLimit).
        -- ÐÐµ Ð·Ð±ÐµÑ€Ñ–Ð³Ð°Ñ”Ð¼Ð¾ ÑÐºÑ‰Ð¾ Ð¼Ð¸ Ñ€Ð¾Ð·Ñ–Ð³Ð½Ð°Ð»Ð¸ÑÑŒ Ð¿Ð¾ ÐºÑ€Ð°ÑŽ â€” Ñ†Ðµ Ð½Ðµ "Ñ€Ð¾Ð±Ð¾Ñ‡Ð°" ÑˆÐ²Ð¸Ð´ÐºÑ–ÑÑ‚ÑŒ.
        local saveThreshold = self.genuineSpeedLimit * 0.75
        if self.speedLimit < saveThreshold and self.speedLimit > 2 then
            self.workingSpeedLimit = self.speedLimit
        end
        -- ÐŸÐ»Ð°Ð²Ð½Ð¾ Ð²Ñ–Ð´Ð¿ÑƒÑÐºÐ°Ñ”Ð¼Ð¾ Ð»Ñ–Ð¼Ñ–Ñ‚ (Ð±ÐµÐ· ÑÑ‚Ñ€Ð¸Ð±ÐºÐ° Ð´Ð¾ 15)
        if self.speedLimit < self.genuineSpeedLimit then
            self.speedLimit = math.min(self.genuineSpeedLimit, self.speedLimit + 0.6)
        end
        return
    end
    
    -- Ð”ÐµÑ‚ÐµÐºÑ†Ñ–Ñ Ð·Ð¼Ñ–Ð½Ð¸ ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð¸ Ð°Ð±Ð¾ Ñ‚Ñ€Ð¸Ð²Ð°Ð»Ð¾Ñ— Ð¿Ð°ÑƒÐ·Ð¸
    local currentCropType = nil
    local spec_combine = vehicle.spec_combine
    if spec_combine and spec_combine.lastValidInputFruitType then
        currentCropType = spec_combine.lastValidInputFruitType
    end
    
    local currentTime = g_currentMission.time or 0
    local timeSinceLastHarvest = currentTime - self.lastHarvestTime
    
    -- Ð¡ÐºÐ¸Ð´Ð°Ñ”Ð¼Ð¾ Ð¿Ñ€Ð¸ Ð·Ð¼Ñ–Ð½Ñ– ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð¸ Ð°Ð±Ð¾ Ñ‚Ñ€Ð¸Ð²Ð°Ð»Ñ–Ð¹ Ð¿Ð°ÑƒÐ·Ñ– (>30 ÑÐµÐº)
    local longPause = timeSinceLastHarvest > 30000
    local cropChanged = (currentCropType and self.lastCropType and currentCropType ~= self.lastCropType)
    if cropChanged or longPause then
        self.workingSpeedLimit = 0
        self._firstHarvestDone = false  -- Reset conservative start Ð´Ð»Ñ Ð½Ð¾Ð²Ð¾Ð³Ð¾ Ð¿Ð¾Ð»Ñ
    end
    
    self.lastCropType = currentCropType
    self.lastHarvestTime = currentTime
    
    -- CONSERVATIVE START: Ñ‚Ñ–Ð»ÑŒÐºÐ¸ Ð¿Ñ€Ð¸ ÑÐ¿Ñ€Ð°Ð²Ð¶Ð½ÑŒÐ¾Ð¼Ñƒ Ð¿ÐµÑ€ÑˆÐ¾Ð¼Ñƒ Ð·Ð°Ñ—Ð·Ð´Ñ– Ð² ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ñƒ
    -- Ð’Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÑ”Ð¼Ð¾ _firstHarvestDone (ÑÐºÐ¸Ð´Ð°Ñ”Ñ‚ÑŒÑÑ Ñ‚Ñ–Ð»ÑŒÐºÐ¸ Ð¿Ñ–ÑÐ»Ñ 30Ñ Ð¿Ð°ÑƒÐ·Ð¸, ÐÐ• Ð½Ð° ÐºÐ¾Ð¶Ð½Ð¾Ð¼Ñƒ ÐºÑ–Ð½Ñ†Ñ– Ñ€ÑÐ´ÐºÐ°)
    if not self._firstHarvestDone then
        self._firstHarvestDone = true
        -- Ð¯ÐºÑ‰Ð¾ speedLimit Ð½Ñ–ÐºÐ¾Ð»Ð¸ Ð½Ðµ Ð·Ð½Ð¸Ð¶ÑƒÐ²Ð°Ð²ÑÑ (genuineSpeedLimit) â€” Ð·Ð°ÑÑ‚Ð¾ÑÐ¾Ð²ÑƒÑ”Ð¼Ð¾ ÑÑ‚Ð°Ñ€Ñ‚
        if self.speedLimit >= self.genuineSpeedLimit then
            if self.workingSpeedLimit > 0 and self.workingSpeedLimit < 12 then
                self.speedLimit = self.workingSpeedLimit
            else
                self.speedLimit = 7.0
                self.workingSpeedLimit = 7.0
            end
        end
        -- Ð¯ÐºÑ‰Ð¾ speedLimit Ð²Ð¶Ðµ Ð½Ð¸Ð¶Ñ‡Ðµ genuineSpeedLimit â€” Ð½Ðµ Ñ‡Ñ–Ð¿Ð°Ñ”Ð¼Ð¾
        -- (Ð½Ð°Ð¿Ñ€Ð¸ÐºÐ»Ð°Ð´, Ð¿Ð»Ð°Ð²Ð½Ð¸Ð¹ Ñ€Ð¾Ð·Ð³Ñ–Ð½ Ð½Ð° Ñ‡Ð°ÑÑ‚ÐºÐ¾Ð²Ñ–Ð¹ ÑÐµÐºÑ†Ñ–Ñ— Ñ‰Ðµ Ð½Ðµ Ð´Ð¾ÑÑÐ³ 15)
    end
    
    -- ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ”Ð¼Ð¾ Ð¿Ð¾Ñ‚Ð¾Ñ‡Ð½Ñƒ ÑˆÐ²Ð¸Ð´ÐºÑ–ÑÑ‚ÑŒ
    local avgSpeed = 1000 * self.totalDistance / self.currentTime  -- Ð¼/Ñ
    
    -- ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ”Ð¼Ð¾ power boost
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass
    
    -- Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ”Ð¼Ð¾ Ð¿Ñ€Ð¸ÑÐºÐ¾Ñ€ÐµÐ½Ð½Ñ (derivative of smoothed value)
    local massAcc = 0
    if self.currentTime > 0 and self.lastAvgMass > 0 then
        massAcc = (self.currentAvgMass - self.lastAvgMass) / self.currentTime
    end
    
    -- === THREE-ZONE CONTROL SYSTEM ===
    local loadRatio = self.currentAvgMass / maxAvgMass
    local rawLoadRatio = (self.rawAvgMass or self.currentAvgMass) / maxAvgMass
    local newSpeedLimit = self.speedLimit
    local controlZone = "HOLD"
    
    -- === GRADUATED EMERGENCY BRAKE SYSTEM ===
    -- Ð§Ð¸Ð¼ Ð²Ð¸Ñ‰Ðµ Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ, Ñ‚Ð¸Ð¼ Ð°Ð³Ñ€ÐµÑÐ¸Ð²Ð½Ñ–ÑˆÐµ Ð³Ð°Ð»ÑŒÐ¼ÑƒÐ²Ð°Ð½Ð½Ñ
    local emergencyBrake = false
    local brakeRate = 0
    
    -- SPECIAL: ÐŸÐµÑ€ÑˆÐ¸Ð¹ Ñ€Ð°Ð· Ð¿ÐµÑ€ÐµÐ²Ð¸Ñ‰Ð¸Ð»Ð¸ 100% - Ñ€Ñ–Ð·ÐºÐ¾ ÑÐºÐ¸Ð´Ð°Ñ”Ð¼Ð¾ ÑˆÐ²Ð¸Ð´ÐºÑ–ÑÑ‚ÑŒ
    -- Ð¦Ðµ Ð·Ð°Ð¿Ð¾Ð±Ñ–Ð³Ð°Ñ” "overshoot" (Ñ€Ð¾Ð·Ð³Ñ–Ð½ â†’ Ð¿ÐµÑ€ÐµÐ²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ â†’ Ð³Ð°Ð»ÑŒÐ¼ÑƒÐ²Ð°Ð½Ð½Ñ â†’ Ñ†Ð¸ÐºÐ»)
    if rawLoadRatio > 1.0 and rawLoadRatio <= 1.05 then
        -- Ð¢Ñ–Ð»ÑŒÐºÐ¸ Ñ‰Ð¾ Ð¿ÐµÑ€ÐµÐ²Ð¸Ñ‰Ð¸Ð»Ð¸ 100% - Ð°Ð³Ñ€ÐµÑÐ¸Ð²Ð½Ð¸Ð¹ ÑÐºÐ¸Ð´
        controlZone = "THRESHOLD_BRAKE"
        brakeRate = 2.5  -- -2.5 ÐºÐ¼/Ð³Ð¾Ð´ (Ð°Ð³Ñ€ÐµÑÐ¸Ð²Ð½Ð¾, Ñ‰Ð¾Ð± load Ð²Ð¿Ð°Ð²)
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
        
    elseif rawLoadRatio > 1.5 then
        -- EXTREME: >150% load - Ð¼Ð°ÐºÑÐ¸Ð¼Ð°Ð»ÑŒÐ½Ðµ Ð³Ð°Ð»ÑŒÐ¼ÑƒÐ²Ð°Ð½Ð½Ñ
        controlZone = "EMERGENCY_EXTREME"
        brakeRate = 5.0  -- -5 ÐºÐ¼/Ð³Ð¾Ð´ Ð·Ð° Ñ€Ð°Ð·
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
        
    elseif rawLoadRatio > 1.2 then
        -- CRITICAL: 120-150% load - ÑÐ¸Ð»ÑŒÐ½Ðµ Ð³Ð°Ð»ÑŒÐ¼ÑƒÐ²Ð°Ð½Ð½Ñ
        controlZone = "EMERGENCY_CRITICAL"
        brakeRate = 3.0  -- -3 ÐºÐ¼/Ð³Ð¾Ð´ Ð·Ð° Ñ€Ð°Ð·
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
        
    elseif rawLoadRatio > 1.1 then
        -- HIGH: 110-120% load - Ð¿Ð¾Ð¼Ñ–Ñ€Ð½Ðµ Ð³Ð°Ð»ÑŒÐ¼ÑƒÐ²Ð°Ð½Ð½Ñ
        controlZone = "EMERGENCY_HIGH"
        brakeRate = 1.5  -- -1.5 ÐºÐ¼/Ð³Ð¾Ð´ Ð·Ð° Ñ€Ð°Ð·
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
        
    elseif rawLoadRatio > 1.05 or loadRatio > 1.08 then
        -- MODERATE: 105-110% load - Ð»ÐµÐ³ÐºÐµ Ð³Ð°Ð»ÑŒÐ¼ÑƒÐ²Ð°Ð½Ð½Ñ
        controlZone = "EMERGENCY_MODERATE"
        brakeRate = 1.0  -- -1 ÐºÐ¼/Ð³Ð¾Ð´ Ð·Ð° Ñ€Ð°Ð·
        emergencyBrake = true
        newSpeedLimit = math.max(2, self.speedLimit - brakeRate)
    
    -- ZONE 1: DANGER (>108% smoothed OR >115% raw) - Standard brake
    elseif loadRatio > 1.08 or rawLoadRatio > 1.15 then
        controlZone = "DANGER"
        if rawLoadRatio > 1.15 then
            -- HARD brake (using raw value for immediate response)
            newSpeedLimit = math.max(2, math.min(self.speedLimit, avgSpeed * 3.6) - 15 * (rawLoadRatio - 1.0)^2)
        else
            -- Soft brake (using smoothed value)
            newSpeedLimit = math.max(2, math.min(self.speedLimit, avgSpeed * 3.6) - 8 * (loadRatio - 1.0)^2)
        end
    
    -- ZONE 2: CAUTION (85-108%) - Hold steady or gentle adjustment
    elseif loadRatio >= 0.85 and loadRatio <= 1.08 then
        controlZone = "CAUTION"
        -- Ð’ Ð·Ð¾Ð½Ñ– Ð¾Ð±ÐµÑ€ÐµÐ¶Ð½Ð¾ÑÑ‚Ñ– Ð°ÐºÑ‚Ð¸Ð²Ð½Ð¾ ÑƒÑ‚Ñ€Ð¸Ð¼ÑƒÑ”Ð¼Ð¾ ÑˆÐ²Ð¸Ð´ÐºÑ–ÑÑ‚ÑŒ
        if loadRatio > 1.00 then
            -- >100%: Ð›ÐµÐ³ÐºÐµ Ð³Ð°Ð»ÑŒÐ¼ÑƒÐ²Ð°Ð½Ð½Ñ (Ñ‰Ð¾Ð± Ð½Ðµ Ð´Ð¾Ð²Ð¾Ð´Ð¸Ñ‚Ð¸ Ð´Ð¾ emergency)
            newSpeedLimit = math.max(2, self.speedLimit - 0.4)
        elseif loadRatio > 0.90 and self.speedLimit > avgSpeed * 3.6 then
            -- 90-100%: Ð¯ÐºÑ‰Ð¾ ÑˆÐ²Ð¸Ð´ÐºÑ–ÑÑ‚ÑŒ Ð·Ñ€Ð¾ÑÑ‚Ð°Ñ” (Ð·Ð·Ð¾Ð²Ð½Ñ–), Ð¾Ð±Ð¼ÐµÐ¶ÑƒÑ”Ð¼Ð¾
            newSpeedLimit = math.max(2, avgSpeed * 3.6 - 0.2)
        end
        -- else: <90% Ð² CAUTION - Ñ‚Ñ€Ð¸Ð¼Ð°Ñ”Ð¼Ð¾ ÑÑ‚Ð°Ð±Ñ–Ð»ÑŒÐ½Ð¾
    
    -- ZONE 3: SAFE (<85%) - Accelerate with prediction
    else
        controlZone = "SAFE"
        
        -- Check prediction before accelerating
        local predictLimitSet = false
        if massAcc > 0 then
            -- Adaptive prediction horizon (shorter at high load)
            local predictHorizon = 2500 + 500 * (1 - loadRatio)
            local predictAvgMass = self.currentAvgMass + massAcc * predictHorizon
            
            -- RAW PREDICTION CHECK
            local predictThreshold = 1.5
            
            if predictAvgMass > predictThreshold * maxAvgMass then
                -- Predictive brake
                newSpeedLimit = math.max(2, math.min(0.96 * self.speedLimit, avgSpeed * 3.6))
                predictLimitSet = true
                controlZone = "SAFE_PREDICT"
            end
        end
        
        -- If no prediction triggered, check for acceleration
        if not predictLimitSet then
            -- === SOFT CEILING: Ð½Ðµ Ð¿ÐµÑ€ÐµÐ²Ð¸Ñ‰ÑƒÑ”Ð¼Ð¾ "Ð²Ð¸Ð²Ñ‡ÐµÐ½Ð¸Ð¹" Ñ€Ð¾Ð±Ð¾Ñ‡Ð¸Ð¹ Ð»Ñ–Ð¼Ñ–Ñ‚ + Ð±ÑƒÑ„ÐµÑ€ ===
            -- ÐŸÑ€Ð¸ Ñ‡Ð°ÑÑ‚ÐºÐ¾Ð²Ñ–Ð¹ ÑˆÐ¸Ñ€Ð¸Ð½Ñ– Ð¶Ð°Ñ‚ÐºÐ¸ (Ð¼Ð°Ð»Ð° Ð¼Ð°ÑÐ°) Ñ„Ð¾Ñ€Ð¼ÑƒÐ»Ð° (maxMass/mass)^2.5 Ð¼Ð¾Ð¶Ðµ Ð´Ð°Ñ‚Ð¸
            -- Ð²ÐµÐ»Ð¸Ñ‡ÐµÐ·Ð½Ðµ Ð¿Ñ€Ð¸ÑÐºÐ¾Ñ€ÐµÐ½Ð½Ñ Ñ– Ñ€Ð¾Ð·Ñ–Ð³Ð½Ð°Ñ‚Ð¸ Ð´Ð¾ genuineSpeedLimit.
            -- ÐŸÐ¾Ñ‚Ñ–Ð¼ Ð¿Ñ€Ð¸ Ð¿Ð¾Ð²Ð½Ñ–Ð¹ Ð¶Ð°Ñ‚Ñ†Ñ– THRESHOLD_BRAKE Ñ€Ñ–Ð·ÐºÐ¾ ÑÐºÐ¸Ð´Ð°Ñ” ÑˆÐ²Ð¸Ð´ÐºÑ–ÑÑ‚ÑŒ â†’ Ð½ÐµÐ¿Ñ€Ð¸Ñ”Ð¼Ð½Ð¾.
            -- Ð Ñ–ÑˆÐµÐ½Ð½Ñ: Ð´Ð¾Ð·Ð²Ð¾Ð»ÑÑ”Ð¼Ð¾ Ñ€Ð¾Ð·Ð³Ñ–Ð½ Ñ‚Ñ–Ð»ÑŒÐºÐ¸ Ð´Ð¾ workingSpeedLimit + 2 ÐºÐ¼/Ð³Ð¾Ð´
            local softCeiling = self.genuineSpeedLimit  -- Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡. â€” Ð¿Ð¾Ð²Ð½Ð° ÑÐ²Ð¾Ð±Ð¾Ð´Ð°
            if self.workingSpeedLimit > 0 then
                softCeiling = math.min(self.genuineSpeedLimit, self.workingSpeedLimit + 2.0)
            end
            
            if loadRatio > 0.70 and loadRatio < 0.80 then
                -- 70-80%: ÐžÐ±ÐµÑ€ÐµÐ¶Ð½Ð¸Ð¹ Ñ€Ð¾Ð·Ð³Ñ–Ð½ (Ð½Ðµ Ñ…Ð¾Ñ‡ÐµÐ¼Ð¾ Ð¿ÐµÑ€ÐµÐ²Ð¸Ñ‰Ð¸Ñ‚Ð¸ 85%)
                local capacityRatio = (maxAvgMass - self.currentAvgMass) / maxAvgMass
                if capacityRatio > 0.25 then
                    local accelFactor = 0.05
                    -- ÐžÐ±Ð¼ÐµÐ¶ÑƒÑ”Ð¼Ð¾ Ð¼Ð½Ð¾Ð¶Ð½Ð¸Ðº: Ð¿Ñ€Ð¸ Ð´ÑƒÐ¶Ðµ Ð¼Ð°Ð»Ð¾Ð¼Ñƒ navantazhenni Ñ„Ð¾Ñ€Ð¼ÑƒÐ»Ð° Ð²Ð¸Ð±ÑƒÑ…Ð°Ñ”
                    local massRatio = math.min(3.0, maxAvgMass / self.currentAvgMass)
                    newSpeedLimit = math.min(softCeiling,
                        self.speedLimit + accelFactor * massRatio^2)
                end
                
            elseif loadRatio <= 0.70 then
                -- <70%: ÐÐ¾Ñ€Ð¼Ð°Ð»ÑŒÐ½Ð¸Ð¹ Ñ€Ð¾Ð·Ð³Ñ–Ð½ (Ð´Ð°Ð»ÐµÐºÐ¾ Ð²Ñ–Ð´ ÑÑ‚ÐµÐ»Ñ–)
                local capacityRatio = (maxAvgMass - self.currentAvgMass) / maxAvgMass
                local accelFactor = 0.08 + 0.05 * capacityRatio  -- 0.08-0.13 range
                -- ÐžÐ±Ð¼ÐµÐ¶ÑƒÑ”Ð¼Ð¾ Ð¼Ð½Ð¾Ð¶Ð½Ð¸Ðº Ñ‰Ð¾Ð± ÑƒÐ½Ð¸ÐºÐ½ÑƒÑ‚Ð¸ Ð²Ð¸Ð±ÑƒÑ…Ð¾Ð²Ð¾Ð³Ð¾ Ð·Ñ€Ð¾ÑÑ‚Ð°Ð½Ð½Ñ Ð¿Ñ€Ð¸ Ð´ÑƒÐ¶Ðµ Ð½Ð¸Ð·ÑŒÐºÐ¾Ð¼Ñƒ load
                local massRatio = math.min(3.0, maxAvgMass / self.currentAvgMass)
                newSpeedLimit = math.min(softCeiling,
                    self.speedLimit + accelFactor * massRatio^2.5)
            end
            -- else: 80%+ Ð² SAFE Ð·Ð¾Ð½Ñ– - Ñ‚Ñ€Ð¸Ð¼Ð°Ñ”Ð¼Ð¾ (Ð½Ðµ Ñ€Ð¾Ð·Ð³Ð°Ð½ÑÑ”Ð¼Ð¾, Ð½Ðµ Ð³Ð°Ð»ÑŒÐ¼ÑƒÑ”Ð¼Ð¾)
        end
    end
    
    -- === RATE LIMITING === (prevent jerky changes)
    -- Ð’Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÑ”Ð¼Ð¾ Ñ€Ñ–Ð·Ð½Ñ– Ð»Ñ–Ð¼Ñ–Ñ‚Ð¸ Ð·Ð°Ð»ÐµÐ¶Ð½Ð¾ Ð²Ñ–Ð´ Ð·Ð¾Ð½Ð¸
    local maxChange = 0.8  -- Default: 0.8 km/h change per update
    
    if emergencyBrake then
        -- Ð’ Ð°Ð²Ð°Ñ€Ñ–Ð¹Ð½Ð¸Ñ… ÑÐ¸Ñ‚ÑƒÐ°Ñ†Ñ–ÑÑ… Ð´Ð¾Ð·Ð²Ð¾Ð»ÑÑ”Ð¼Ð¾ ÑˆÐ²Ð¸Ð´ÐºÑ– Ð·Ð¼Ñ–Ð½Ð¸
        maxChange = brakeRate  -- Ð’Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÑ”Ð¼Ð¾ Ñ€Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²Ð°Ð½Ð¸Ð¹ brakeRate
    elseif controlZone == "DANGER" then
        maxChange = 1.5  -- Ð¨Ð²Ð¸Ð´ÑˆÑ– Ð·Ð¼Ñ–Ð½Ð¸ Ð² Ð½ÐµÐ±ÐµÐ·Ð¿ÐµÑ‡Ð½Ñ–Ð¹ Ð·Ð¾Ð½Ñ–
    end
    
    newSpeedLimit = math.clamp(newSpeedLimit, 
        self.speedLimit - maxChange, 
        self.speedLimit + maxChange)
    
    self.speedLimit = newSpeedLimit
    
    if self.debug then
        print(string.format("RHM: [%s] Load: %.1f%% (Raw: %.1f%%) | Speed: %.1fâ†’%.1f | Acc: %.4f", 
            controlZone, loadRatio * 100, rawLoadRatio * 100, 
            avgSpeed * 3.6, self.speedLimit, massAcc))
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

---Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ” Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð²Ñ€Ð¾Ð¶Ð°ÑŽ Ð¿Ñ€Ð¸ Ð¿ÐµÑ€ÐµÐ²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ–
---@return number Ð’Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð² Ð²Ñ–Ð´ÑÐ¾Ñ‚ÐºÐ°Ñ… (0-50)
function LoadCalculator:calculateCropLoss()
    -- ÐŸÐµÑ€ÐµÐ²Ñ–Ñ€ÑÑ”Ð¼Ð¾ Ñ‡Ð¸ ÑƒÐ²Ñ–Ð¼ÐºÐ½ÐµÐ½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return 0
    end
    
    if not g_realisticHarvestManager.settings.enableCropLoss then
        return 0
    end
    
    -- ÐÐžÐ’Ð˜Ð™ ÐŸÐžÐ Ð†Ð“: Ð’Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð¿Ð¾Ñ‡Ð¸Ð½Ð°ÑŽÑ‚ÑŒÑÑ Ð· 95% Ð½Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ
    if self.engineLoad > 0.95 then
        -- Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ”Ð¼Ð¾ overload Ð²Ñ–Ð´Ð½Ð¾ÑÐ½Ð¾ 95%
        local overload = self.engineLoad - 0.95  -- 0.0 Ð¿Ñ€Ð¸ 95%, 0.05 Ð¿Ñ€Ð¸ 100%, 0.25 Ð¿Ñ€Ð¸ 120% Ñ– Ñ‚.Ð´.
        
        -- ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ”Ð¼Ð¾ Ð¼Ð½Ð¾Ð¶Ð½Ð¸Ðº Ð²Ñ‚Ñ€Ð°Ñ‚ Ð·Ð°Ð»ÐµÐ¶Ð½Ð¾ Ð²Ñ–Ð´ ÑÐºÐ»Ð°Ð´Ð½Ð¾ÑÑ‚Ñ–
        local lossMultiplier = g_realisticHarvestManager.settings:getLossMultiplier()
        
        -- ÐŸÑ€Ð¾Ð³Ñ€ÐµÑÐ¸Ð²Ð½Ð° Ñ„Ð¾Ñ€Ð¼ÑƒÐ»Ð° Ð²Ñ‚Ñ€Ð°Ñ‚:
        -- 95-100% load: ÐœÑ–Ð½Ñ–Ð¼Ð°Ð»ÑŒÐ½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ (0-2%)
        -- 100-120% load: ÐŸÐ¾Ð¼Ñ–Ñ€Ð½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ (2-15%)
        -- 120%+ load: Ð¡ÐµÑ€Ð¹Ð¾Ð·Ð½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ (15-50%)
        -- 
        -- Ð¤Ð¾Ñ€Ð¼ÑƒÐ»Ð°: ((overload / 0.05)^1.5) * lossMultiplier * Ð±Ð°Ð·Ð¾Ð²Ð¸Ð¹_Ð²Ñ–Ð´ÑÐ¾Ñ‚Ð¾Ðº
        -- Ð´Ðµ 0.05 = Ð´Ñ–Ð°Ð¿Ð°Ð·Ð¾Ð½ Ð²Ñ–Ð´ 95% Ð´Ð¾ 100%
        local normalizedOverload = overload / 0.05  -- 0.0 Ð¿Ñ€Ð¸ 95%, 1.0 Ð¿Ñ€Ð¸ 100%, 5.0 Ð¿Ñ€Ð¸ 120%
        local loss = (normalizedOverload^1.5) * lossMultiplier * 2.5  -- 2.5 = Ð±Ð°Ð·Ð¾Ð²Ð¸Ð¹ % Ð¿Ñ€Ð¸ 100% load
        
        self.cropLoss = math.min(loss, 50) -- ÐœÐ°ÐºÑÐ¸Ð¼ÑƒÐ¼ 50% Ð²Ñ‚Ñ€Ð°Ñ‚
    else
        self.cropLoss = 0
    end
    
    return self.cropLoss
end

---Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ” Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð²Ñ–Ð´ Ð½ÐµÐ¿Ñ€Ð°Ð²Ð¸Ð»ÑŒÐ½Ð¸Ñ… Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½ÑŒ ÐºÐ¾Ð¼Ð±Ð°Ð¹Ð½Ð°
---@return number settingsLoss Ð’Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð²Ñ–Ð´ Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½ÑŒ (0-50%)
function LoadCalculator:calculateSettingsLoss()
    -- Ð¯ÐºÑ‰Ð¾ Ð½ÐµÐ¼Ð°Ñ” memory Ð°Ð±Ð¾ ÐºÑƒÐ»ÑŒÑ‚ÑƒÑ€Ð¸ - Ð²Ñ‚Ñ€Ð°Ñ‚ Ð½ÐµÐ¼Ð°Ñ”
    if not self.combineMemory or not self.currentCrop then
        return 0
    end
    
    -- ÐžÐ´Ð½Ð°ÐºÐ¾Ð²Ð° Ð¼Ð°Ñ‚ÐµÐ¼Ð°Ñ‚Ð¸ÐºÐ° Ð´Ð»Ñ AUTO Ñ– MANUAL:
    -- AUTO Ð¾Ñ‚Ñ€Ð¸Ð¼ÑƒÑ” Ð½ÐµÐ²ÐµÐ»Ð¸ÐºÐ¸Ð¹ Ð²Ñ–Ð´Ñ…Ð¸Ð» Ð²Ñ–Ð´ Ð¾Ð¿Ñ‚Ð¸Ð¼ÑƒÐ¼Ñƒ (1-10 Ð¾Ð´Ð¸Ð½Ð¸Ñ†ÑŒ) Ð¿Ñ€Ð¸ Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½Ð½Ñ–,
    -- Ñ‚Ð¾Ð¼Ñƒ Ð¼Ð°Ñ‚Ð¸Ð¼Ðµ Ð¼Ð°Ð»Ñ–, Ð°Ð»Ðµ Ñ€ÐµÐ°Ð»ÑŒÐ½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ â€” "Ð°Ð²Ñ‚Ð¾Ð¼Ð°Ñ‚ Ð½Ðµ Ñ–Ð´ÐµÐ°Ð»ÑŒÐ½Ð¸Ð¹"
    -- MANUAL Ð´Ð°Ñ” Ð³Ñ€Ð°Ð²Ñ†ÑŽ Ð¼Ð¾Ð¶Ð»Ð¸Ð²Ñ–ÑÑ‚ÑŒ Ð·Ñ€Ð¾Ð±Ð¸Ñ‚Ð¸ Ñ– ÐºÑ€Ð°Ñ‰Ðµ (ÑÐºÑ‰Ð¾ Ñ‚Ð¾Ñ‡Ð½Ð¾ Ð¿Ð¾Ñ‚Ñ€Ð°Ð¿Ð¸Ñ‚ÑŒ Ð² Ð¾Ð¿Ñ‚Ð¸Ð¼ÑƒÐ¼)
    -- Ñ– Ð³Ñ–Ñ€ÑˆÐµ (ÑÐºÑ‰Ð¾ Ð²Ð¸ÑÑ‚Ð°Ð²Ð¸Ñ‚ÑŒ Ð½ÐµÐ¿Ñ€Ð°Ð²Ð¸Ð»ÑŒÐ½Ñ– Ð·Ð½Ð°Ñ‡ÐµÐ½Ð½Ñ)
    
    -- ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ”Ð¼Ð¾ Ñ€ÐµÐ·ÑƒÐ»ÑŒÑ‚Ð°Ñ‚ Ð¿ÐµÑ€ÐµÐ²Ñ–Ñ€ÐºÐ¸ Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½ÑŒ (Ð²ÐºÐ»ÑŽÑ‡Ð°ÑŽÑ‡Ð¸ Ð±Ð¾Ð½ÑƒÑ)
    local netPenalty, _ = self.combineMemory:checkSettingsForCrop(self.currentCrop)
    
    -- netPenalty Ð¼Ð¾Ð¶Ðµ Ð±ÑƒÑ‚Ð¸ Ð²Ñ–Ð´'Ñ”Ð¼Ð½Ð¸Ð¼ (Ð±Ð¾Ð½ÑƒÑ) Ð°Ð±Ð¾ Ð´Ð¾Ð´Ð°Ñ‚Ð½Ñ–Ð¼ (ÑˆÑ‚Ñ€Ð°Ñ„)
    -- ÐžÐ±Ð¼ÐµÐ¶ÑƒÑ”Ð¼Ð¾ Ð´Ñ–Ð°Ð¿Ð°Ð·Ð¾Ð½: ÐœÐ°ÐºÑÐ¸Ð¼Ð°Ð»ÑŒÐ½Ð¸Ð¹ Ð±Ð¾Ð½ÑƒÑ -5%, ÐœÐ°ÐºÑÐ¸Ð¼Ð°Ð»ÑŒÐ½Ð¸Ð¹ ÑˆÑ‚Ñ€Ð°Ñ„ 30%
    local settingsFactor = math.max(-5, math.min(netPenalty, 30))
    
    return settingsFactor
end

---Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²ÑƒÑ” Ð·Ð°Ð³Ð°Ð»ÑŒÐ½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð²Ñ€Ð¾Ð¶Ð°ÑŽ (Ð±Ð°Ð·Ð¾Ð²Ñ– + Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½Ð½Ñ)
---@return number totalLoss Ð—Ð°Ð³Ð°Ð»ÑŒÐ½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ (0-50%)
function LoadCalculator:calculateTotalCropLoss()
    -- Ð‘Ð°Ð·Ð¾Ð²Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð²Ñ–Ð´ Ð¿ÐµÑ€ÐµÐ²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ
    local baseLoss = self:calculateCropLoss()
    
    -- Ð’Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð²Ñ–Ð´ Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½ÑŒ
    local settingsLoss = self:calculateSettingsLoss()
    
    -- TODO: Ð’ Ð¼Ð°Ð¹Ð±ÑƒÑ‚Ð½ÑŒÐ¾Ð¼Ñƒ Ð´Ð¾Ð´Ð°Ñ‚Ð¸:
    -- local moistureLoss = self:calculateMoistureLoss()
    -- local speedLoss = self:calculateSpeedLoss()
    
    -- Ð—Ð°Ð³Ð°Ð»ÑŒÐ½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ (ÑÑƒÐ¼ÑƒÑŽÑ‚ÑŒÑÑ)
    local totalLoss = baseLoss + settingsLoss
    
    -- ÐžÐ±Ð¼ÐµÐ¶ÑƒÑ”Ð¼Ð¾ Ð¼Ð°ÐºÑÐ¸Ð¼ÑƒÐ¼
    totalLoss = math.min(totalLoss, 50)
    
    -- Ð—Ð±ÐµÑ€Ñ–Ð³Ð°Ñ”Ð¼Ð¾ Ð´Ð»Ñ Ð²Ñ–Ð´Ð¾Ð±Ñ€Ð°Ð¶ÐµÐ½Ð½Ñ Ð² HUD
    self.cropLoss = totalLoss
    
    return totalLoss
end

---ÐžÑ‚Ñ€Ð¸Ð¼ÑƒÑ” Ð¿Ð¾Ñ‚Ð¾Ñ‡Ð½Ñ– Ð²Ñ‚Ñ€Ð°Ñ‚Ð¸ Ð²Ñ€Ð¾Ð¶Ð°ÑŽ
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
function LoadCalculator:updateProductivity(mass, liters, dt)
    self.totalOutputMass = self.totalOutputMass + mass
    
    -- ÐÐ°ÐºÐ¾Ð¿Ð¸Ñ‡ÑƒÑ”Ð¼Ð¾ Ð¼Ð°ÑÑƒ, Ð¾Ð±'Ñ”Ð¼ Ñ‚Ð° Ñ‡Ð°Ñ
    self.productivityMass = self.productivityMass + mass
    self.productivityLiters = (self.productivityLiters or 0) + liters
    self.productivityTime = self.productivityTime + dt
    
    -- ÐžÐ½Ð¾Ð²Ð»ÑŽÑ”Ð¼Ð¾ T/h Ñ‚Ð° L/h ÐºÐ¾Ð¶Ð½Ñ– 3 ÑÐµÐºÑƒÐ½Ð´Ð¸ Ð´Ð»Ñ ÑÑ‚Ð°Ð±Ñ–Ð»ÑŒÐ½Ð¾Ð³Ð¾ Ð·Ð½Ð°Ñ‡ÐµÐ½Ð½Ñ
    -- ÐÐ‘Ðž ÑÐºÑ‰Ð¾ Ñ†Ðµ Ð¿ÐµÑ€ÑˆÐ¸Ð¹ Ð·Ð°Ð¿ÑƒÑÐº (productivityTime Ð¼Ð°Ð»Ð¸Ð¹ Ð°Ð»Ðµ Ñ” Ð¼Ð°ÑÐ°)
    if self.productivityTime >= self.productivityUpdateInterval then
        if self.productivityTime > 0 then
            -- T/h = (Mass_kg / 1000) / (Time_ms / 3600000)
            local hours = self.productivityTime / 3600000
            self.tonPerHour = (self.productivityMass / 1000) / hours
            self.litersPerHour = (self.productivityLiters or 0) / hours
        end
        
        -- Reset counters with SMOOTHING (keep 20% to prevent drops)
        self.productivityMass = self.productivityMass * 0.2
        self.productivityLiters = (self.productivityLiters or 0) * 0.2
        self.productivityTime = self.productivityTime * 0.2
        
    elseif self.tonPerHour == 0 and self.productivityTime > 1000 and self.productivityMass > 0 then
        -- Ð¨Ð²Ð¸Ð´ÐºÐ¸Ð¹ ÑÑ‚Ð°Ñ€Ñ‚
        local hours = self.productivityTime / 3600000
        self.tonPerHour = (self.productivityMass / 1000) / hours
        self.litersPerHour = (self.productivityLiters or 0) / hours
    end
end

---ÐžÐ½Ð¾Ð²Ð»ÑŽÑ” Ð¿Ñ€Ð¾Ð´ÑƒÐºÑ‚Ð¸Ð²Ð½Ñ–ÑÑ‚ÑŒ Ñ– Ð’Ð ÐžÐ–ÐÐ™ÐÐ†Ð¡Ð¢Ð¬
---@param mass number ÐœÐ°ÑÐ° (ÐºÐ³)
---@param liters number ÐžÐ±'Ñ”Ð¼ (Ð»)
---@param area number ÐŸÐ»Ð¾Ñ‰Ð° (Ð¼2)
---@param dt number Ð§Ð°Ñ (Ð¼Ñ)
function LoadCalculator:updateProductivityAndYield(mass, liters, area, dt)
    self:updateProductivity(mass, liters, dt) -- Call original logic
    
    if area <= 0.0001 and mass <= 0.001 then
        self.instantYield = 0
        return
    end
    
    -- 1. Combine Asynchronous Data (Metric: t/ha)
    -- In FS25, addCutterArea and addFillUnitFillLevel are asynchronous.
    -- To prevent unweighted average errors (calculating mass/area per frame and averaging),
    -- we must store RAW mass and area, and calculate Sum(Mass) / Sum(Area).
    
    self.yieldBuffer = self.yieldBuffer or {}
    table.insert(self.yieldBuffer, {m = mass, a = area})
    if #self.yieldBuffer > 120 then table.remove(self.yieldBuffer, 1) end
    
    local sumMass = 0
    local sumArea = 0
    for _, v in ipairs(self.yieldBuffer) do 
        sumMass = sumMass + v.m
        sumArea = sumArea + v.a 
    end
    
    local smoothedYield = 0
    if sumArea > 0.1 then
        -- (kg / m2) * 10 = t/ha
        smoothedYield = (sumMass / sumArea) * 10
    
    end
    
    -- 3. REMOVED Noise (+/- 5%) - User requested actual values
    -- Noise factor removed for stability
    
    -- No Calibration - Pure Real-time Yield
    self.currentYield = smoothedYield
end

---Ð’ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ñ‚Ð¸ Ñ€ÐµÐ°Ð»ÑŒÐ½Ñƒ Ð²Ñ€Ð¾Ð¶Ð°Ð¹Ð½Ñ–ÑÑ‚ÑŒ Ð· rhm_Combine (User Request)
---@param yieldTha number Ð’Ñ€Ð¾Ð¶Ð°Ð¹Ð½Ñ–ÑÑ‚ÑŒ Ð² Ñ‚/Ð³Ð°
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
