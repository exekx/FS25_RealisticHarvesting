-- ============================================================================
-- RHM_CloggingSystem.lua
-- Realistic Harvesting Mod - Harvester Clogging & Feeder Jam Simulation (FS25)
-- ============================================================================
-- Implements progressive feeder/drum clogging driven by real physical load,
-- crop surge, excessive moisture, heavy weeds, and calibration errors.
-- Zero table allocations inside update() to guarantee 0 GC overhead on ticks.
-- ============================================================================

RHM_CloggingSystem = {}
local RHM_CloggingSystem_mt = Class(RHM_CloggingSystem)

-- Clogging severity states
RHM_CloggingSystem.STATE_NORMAL      = 0
RHM_CloggingSystem.STATE_WARNING     = 1
RHM_CloggingSystem.STATE_SLIP_CLUTCH = 2
RHM_CloggingSystem.STATE_BLOCKED     = 3

-- Server mode presets
RHM_CloggingSystem.MODE_OFF       = 1
RHM_CloggingSystem.MODE_REVERSE   = 2
RHM_CloggingSystem.MODE_REALISTIC = 3

-- Trigger factors presets
RHM_CloggingSystem.FACTOR_OVERLOAD_ONLY = 1
RHM_CloggingSystem.FACTOR_ALL           = 2

-- AI worker handling presets
RHM_CloggingSystem.AI_AUTO_RECOVER = 1
RHM_CloggingSystem.AI_MANUAL       = 2
RHM_CloggingSystem.AI_OFF          = 3

-- Primary cause codes for UI / Tablet telemetry
RHM_CloggingSystem.CAUSE_NONE     = 0
RHM_CloggingSystem.CAUSE_OVERLOAD = 1
RHM_CloggingSystem.CAUSE_MOISTURE = 2
RHM_CloggingSystem.CAUSE_WEEDS    = 3
RHM_CloggingSystem.CAUSE_SETTINGS = 4
RHM_CloggingSystem.CAUSE_SURGE    = 5

local EXCLUDED_MACHINE_TYPES = {
    cotton = true,
    sugarcane = true,
    grape = true,
    olive = true
}

local SENSITIVITY_MULTIPLIERS = {
    [1] = 0.60, -- Low
    [2] = 1.00, -- Standard
    [3] = 1.50  -- High
}

local CAUSE_KEYS = {
    [0] = nil,
    [1] = "rhm_clog_cause_overload",
    [2] = "rhm_clog_cause_moisture",
    [3] = "rhm_clog_cause_weeds",
    [4] = "rhm_clog_cause_settings",
    [5] = "rhm_clog_cause_surge"
}

local CAUSE_FALLBACKS = {
    [0] = "",
    [1] = "Overload",
    [2] = "High Moisture",
    [3] = "Heavy Weeds",
    [4] = "Poor Calibration",
    [5] = "Mass Surge"
}

function RHM_CloggingSystem.new()
    local self = setmetatable({}, RHM_CloggingSystem_mt)
    self:reset()
    return self
end

function RHM_CloggingSystem:reset()
    self.clogLevel = 0.0                -- 0.0 to 100.0
    self.clogState = RHM_CloggingSystem.STATE_NORMAL
    self.clogCause = RHM_CloggingSystem.CAUSE_NONE
    self.clearedMassAccumLiters = 0.0   -- Estimated choked crop volume for optional ground drop

    self.isPlayerReversing = false
    self.reverseProgress = 0.0          -- 0.0 to 1.0
    self.manualClearProgress = 0.0      -- 0.0 to 1.0

    self.aiRecoverActive = false
    self.aiRecoverTimer = 0.0
    self.slipPushTimer = 0.0            -- Escalates SLIP_CLUTCH -> BLOCKED if operator keeps pushing forward
    self.reingestCooldownTimer = 0.0    -- Brief protection after clearing/dropping pile
    self.smoothedMassKgS = 0.0
    self.justHitSlipClutch = false
    self.justHitBlocked = false
end

function RHM_CloggingSystem:getState()
    return self.clogState or RHM_CloggingSystem.STATE_NORMAL
end

function RHM_CloggingSystem:getLevel()
    return self.clogLevel or 0.0
end

function RHM_CloggingSystem:getCauseCode()
    return self.clogCause or RHM_CloggingSystem.CAUSE_NONE
end

function RHM_CloggingSystem.getCauseText(causeCode)
    local code = causeCode or 0
    local key = CAUSE_KEYS[code]
    if key ~= nil and g_i18n ~= nil and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end
    return CAUSE_FALLBACKS[code] or ""
end

function RHM_CloggingSystem.isMachineSupported(machineType)
    if machineType == nil then
        return true
    end
    return EXCLUDED_MACHINE_TYPES[machineType] ~= true
end

function RHM_CloggingSystem:setPlayerReversing(vehicle, isReversing)
    self.isPlayerReversing = isReversing == true
    if not self.isPlayerReversing then
        self.reverseProgress = 0.0
    end
end

---EN: Deposits a small swath/windrow heap ahead of the cutter when clogDropPile is enabled (server only).
function RHM_CloggingSystem:dropClearedPile(vehicle)
    if g_server == nil or vehicle == nil then
        return
    end
    if DensityMapHeightUtil == nil or DensityMapHeightUtil.tipToGroundAroundLine == nil then
        return
    end

    local spec = vehicle.spec_rhm_Combine
    local liters = math.max(80.0, math.min(600.0, self.clearedMassAccumLiters or 180.0))
    local fillTypeIdx = FillType.STRAW
    if spec and spec.machineType == "forage" then
        fillTypeIdx = FillType.CHAFF
    elseif spec and spec.lastFillType and spec.lastFillType ~= FillType.UNKNOWN then
        local desc = g_fillTypeManager and g_fillTypeManager:getFillTypeByIndex(spec.lastFillType)
        if desc and DensityMapHeightUtil.getFillTypeToHeightTypeIndex and DensityMapHeightUtil.getFillTypeToHeightTypeIndex(spec.lastFillType) ~= nil then
            fillTypeIdx = spec.lastFillType
        end
    end

    if DensityMapHeightUtil.getFillTypeToHeightTypeIndex and DensityMapHeightUtil.getFillTypeToHeightTypeIndex(fillTypeIdx) == nil then
        fillTypeIdx = FillType.STRAW
    end

    local refNode = vehicle.rootNode or (vehicle.components and vehicle.components[1] and vehicle.components[1].node)
    if spec and spec.currentCutter and spec.currentCutter.rootNode then
        refNode = spec.currentCutter.rootNode
    end
    if refNode == nil or not entityExists(refNode) then
        return
    end

    local lx, ly, lz = localToWorld(refNode, -1.2, 0, 2.2)
    local rx, ry, rz = localToWorld(refNode, 1.2, 0, 2.2)
    if g_currentMission and g_currentMission.terrainRootNode then
        ly = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, lx, 0, lz)
        ry = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, rx, 0, rz)
    end

    local maxRadius = 2.0
    local minRadius = 0.5
    local dropped = DensityMapHeightUtil.tipToGroundAroundLine(vehicle, liters, fillTypeIdx, lx, ly, lz, rx, ry, rz, maxRadius, minRadius, nil, true, nil)
    if dropped and dropped > 0 then
        self.reingestCooldownTimer = 2.5
    end
end

function RHM_CloggingSystem:clearBlockage(vehicle, allowPileDrop)
    local hadClog = self.clogLevel > 5.0 or self.clogState >= RHM_CloggingSystem.STATE_SLIP_CLUTCH
    if allowPileDrop and hadClog then
        local settings = g_realisticHarvestManager and g_realisticHarvestManager.settings
        if settings and settings.clogDropPile == true then
            self:dropClearedPile(vehicle)
        end
    end

    self.clogLevel = 0.0
    self.clogState = RHM_CloggingSystem.STATE_NORMAL
    self.clogCause = RHM_CloggingSystem.CAUSE_NONE
    self.clearedMassAccumLiters = 0.0
    self.isPlayerReversing = false
    self.reverseProgress = 0.0
    self.manualClearProgress = 0.0
    self.aiRecoverActive = false
    self.aiRecoverTimer = 0.0
    self.slipPushTimer = 0.0
    self.reingestCooldownTimer = math.max(self.reingestCooldownTimer or 0.0, 1.5)
end

---EN: Returns true only when the thresher/feeder has hard-jammed at 100% (STATE_BLOCKED), halting crop intake simultaneously with full vehicle stop.
function RHM_CloggingSystem:isIntakeHalted()
    return (self.clogState == RHM_CloggingSystem.STATE_BLOCKED) or ((self.clogLevel or 0.0) >= 100.0)
end

---EN: Returns progressive speed multiplier for player (when clogAutoSlowdown is enabled) and AI workers as clogging builds up (>=65%).
function RHM_CloggingSystem:getSpeedMultiplier(isAiWorker, aiCloggingMode, clogAutoSlowdown)
    if self.clogState == RHM_CloggingSystem.STATE_BLOCKED or (self.clogLevel or 0.0) >= 100.0 or self.aiRecoverActive then
        return 0.0
    end
    local lvl = self.clogLevel or 0.0
    if isAiWorker and aiCloggingMode == RHM_CloggingSystem.AI_AUTO_RECOVER and lvl >= 78.0 then
        return 0.0
    end
    local autoSlow = (clogAutoSlowdown == true) or (isAiWorker and aiCloggingMode == RHM_CloggingSystem.AI_AUTO_RECOVER)
    if autoSlow and lvl >= 65.0 then
        local t = math.min(1.0, (lvl - 65.0) / 35.0)
        return 0.85 - (t * 0.35)
    end
    return 1.0
end

---EN: Server-side authoritative clogging physics update. Allocates zero tables.
function RHM_CloggingSystem:update(
    vehicle, dt, engineLoadPct, massKgS,
    moisturePct, moistureLimitPct, weedRatio, settingsEff,
    machineType, threshingType, isThreshing, isCutterOn, isMovingForward, speedKmh,
    isAiWorker, cloggingMode, clogSensitivity, clogFactors, aiCloggingMode, clogDropPile,
    isCutterTurnedOn
)
    self.justHitSlipClutch = false
    self.justHitBlocked = false

    local dtSec = math.min(0.25, math.max(0.0, (dt or 0) * 0.001))
    if dtSec <= 0.0 then
        return
    end

    if self.reingestCooldownTimer > 0.0 then
        self.reingestCooldownTimer = math.max(0.0, self.reingestCooldownTimer - dtSec)
    end

    -- Check feature enablement, supported machine type, external clogging compatibility, and AI immunity
    local extConflict = RHM_ModCompatibility and RHM_ModCompatibility.hasExternalCloggingMod == true
    local isDisabled = (cloggingMode == RHM_CloggingSystem.MODE_OFF)
        or (not RHM_CloggingSystem.isMachineSupported(machineType))
        or extConflict
        or (isAiWorker and aiCloggingMode == RHM_CloggingSystem.AI_OFF)

    if isDisabled then
        if self.clogLevel > 0.0 or self.clogState ~= RHM_CloggingSystem.STATE_NORMAL or self.aiRecoverActive then
            self:clearBlockage(vehicle, false)
        end
        return
    end

    -- Player holding RHM_REVERSE_FEEDER while stopped: direct server reverse progress for SP/host
    if self.isPlayerReversing and (speedKmh or 0) < 1.2 and self.clogLevel > 0.0 then
        local canClearHard = (cloggingMode == RHM_CloggingSystem.MODE_REVERSE)
        if self.clogState == RHM_CloggingSystem.STATE_BLOCKED and not canClearHard then
            -- Realistic mode: hard blockage stays locked at 100% until cleared manually on foot (RShift+C)
            return
        else
            local drainRate = (self.clogState == RHM_CloggingSystem.STATE_BLOCKED) and 6.5 or 9.5
            self.clogLevel = math.max(0.0, self.clogLevel - drainRate * dtSec)
            if self.clogLevel <= 4.0 then
                self:clearBlockage(vehicle, clogDropPile)
            elseif self.clogState == RHM_CloggingSystem.STATE_SLIP_CLUTCH and self.clogLevel < 50.0 then
                self.clogState = (self.clogLevel >= 35.0) and RHM_CloggingSystem.STATE_WARNING or RHM_CloggingSystem.STATE_NORMAL
                if self.clogLevel < 25.0 then
                    self.clogCause = RHM_CloggingSystem.CAUSE_NONE
                end
            end
        end
        return
    end

    -- AI Worker Auto-Recover execution (slows/halts briefly while reversing feeder automatically)
    if self.aiRecoverActive then
        if not isAiWorker or aiCloggingMode ~= RHM_CloggingSystem.AI_AUTO_RECOVER then
            self.aiRecoverActive = false
            self.aiRecoverTimer = 0.0
        else
            self.aiRecoverTimer = self.aiRecoverTimer + dtSec
            self.clogLevel = math.max(0.0, self.clogLevel - 10.0 * dtSec)
            if self.clogLevel <= 2.0 and self.aiRecoverTimer >= 3.5 then
                self:clearBlockage(vehicle, false)
                -- Restore combine threshing if it was turned off on hard blockage
                if vehicle and vehicle.setIsTurnedOn and vehicle.getIsTurnedOn and not vehicle:getIsTurnedOn() then
                    vehicle:setIsTurnedOn(true, true)
                end
            end
            return
        end
    end

    -- HARD_BLOCKAGE stays locked until cleared
    if self.clogState == RHM_CloggingSystem.STATE_BLOCKED then
        if isAiWorker and aiCloggingMode == RHM_CloggingSystem.AI_AUTO_RECOVER then
            self.aiRecoverActive = true
            self.aiRecoverTimer = 0.0
        elseif isAiWorker and aiCloggingMode == RHM_CloggingSystem.AI_MANUAL then
            if vehicle and vehicle.stopCurrentAIJob then
                vehicle:stopCurrentAIJob(AIMessageErrorBlockedByObject and AIMessageErrorBlockedByObject.new() or nil)
            end
        end
        return
    end

    local headerTurnedOn = (isCutterTurnedOn ~= nil) and (isCutterTurnedOn == true) or (isCutterOn == true)

    -- AI Auto-Recover proactive trigger before reaching hard blockage
    if isAiWorker and aiCloggingMode == RHM_CloggingSystem.AI_AUTO_RECOVER and self.clogLevel >= 78.0 then
        self.aiRecoverActive = true
        self.aiRecoverTimer = 0.0
        return
    end

    -- Smooth mass flow for surge detection
    local safeMass = math.max(0.0, massKgS or 0.0)
    local alphaMass = 1.0 - math.exp(-dtSec / 1.8)
    local prevMass = self.smoothedMassKgS
    self.smoothedMassKgS = prevMass + (safeMass - prevMass) * alphaMass

    local sensMult = SENSITIVITY_MULTIPLIERS[clogSensitivity or 2] or 1.0
    local load = math.max(0.0, engineLoadPct or 0.0)

    -- Machine type & threshing geometry factors
    local typeMult = 1.0
    if machineType == "forage" then
        typeMult = 1.12
    elseif machineType == "root" then
        typeMult = 0.85
    elseif machineType == "grain" then
        if threshingType == "rotor" then
            typeMult = 0.92
        elseif threshingType == "walker" then
            typeMult = 1.08
        end
    end

    local isActivelyFeeding = isThreshing and isCutterOn and isMovingForward and safeMass > 0.15 and self.reingestCooldownTimer <= 0.0

    local rateOverload = 0.0
    local rateMoisture = 0.0
    local rateWeeds = 0.0
    local rateSettings = 0.0
    local rateSurge = 0.0

    if isThreshing and isMovingForward and self.reingestCooldownTimer <= 0.0 then
        -- 1. Core Overload (deadband: load < 95% never triggers pure overload clog)
        if load >= 95.0 then
            local excessLoad = (load - 91.0) / 16.0
            rateOverload = (excessLoad ^ 1.25) * 4.5
        end

        -- 2. Environmental & Calibration factors (only when clogFactors == 2 and actively cutting crop)
        if clogFactors ~= RHM_CloggingSystem.FACTOR_OVERLOAD_ONLY and isActivelyFeeding then
            local loadWeight = math.min(1.85, math.max(0.55, (load - 35.0) / 40.0))

            -- Excess moisture beyond +1.5% margin (e.g. midnight dew >=16%) under >=50% load
            local mPct = moisturePct or 0.0
            local mLim = moistureLimitPct or 14.0
            local isDamp = load >= 50.0 and mPct > (mLim + 1.5)
            if isDamp then
                local mExcess = (mPct - (mLim + 1.5)) / 4.8
                rateMoisture = mExcess * 1.75 * loadWeight
            end

            -- Green weeds wrapping onto auger/drum (PF patchy weed fields average >5% across wide headers at >=45% load)
            local wRatio = weedRatio or 0.0
            local hasWeeds = load >= 45.0 and wRatio > 0.05
            if hasWeeds then
                local wExcess = (wRatio - 0.05) / 0.30
                rateWeeds = wExcess * 2.15 * loadWeight
            end

            -- Damp sap synergy: wet stems + green weed sap stick together even faster
            if isDamp and hasWeeds then
                rateWeeds = rateWeeds + 0.35 * loadWeight
            end

            -- Suboptimal machine calibration: proportional to slider exit from Green Zone (settingsClogRisk > 0)
            -- All sliders inside green zone -> settingsClogRisk == 0 -> 0% clog buildup.
            -- Small exit from green zone -> gentle buildup; extreme LOW/HIGH miscalibration -> strong buildup up to 100%.
            local calibRisk = 0.0
            if vehicle and vehicle.spec_rhm_Combine then
                local rhmSpec = vehicle.spec_rhm_Combine
                calibRisk = (rhmSpec.loadCalculator and rhmSpec.loadCalculator.settingsClogRisk)
                    or (rhmSpec.combineMemory and rhmSpec.combineMemory.settingsClogRisk)
                    or 0.0
            end
            if calibRisk <= 0.0 and (settingsEff or 1.0) < 0.99 then
                calibRisk = (1.0 - (settingsEff or 1.0)) * 4.5
            end
            if load >= 25.0 and calibRisk > 0.03 then
                rateSettings = calibRisk * 2.85 * loadWeight
            end

            -- Sudden mass slug surge (entering dense patch or heavy windrow at >=85% load)
            if load >= 85.0 and safeMass > 1.8 and prevMass > 0.5 and safeMass > (prevMass * 1.45) then
                rateSurge = math.min(3.5, (safeMass / prevMass - 1.45) * 3.0)
            end
        end
    end

    local rawPosRate = (rateOverload + rateMoisture + rateWeeds + rateSettings + rateSurge) * sensMult * typeMult
    if self.clogLevel >= 65.0 and isActivelyFeeding and (rawPosRate > 0.05 or load >= 82.0) then
        -- Active slip-clutch friction buildup: once feeder is in SLIP (>=65%) and player keeps pushing
        -- without fixing the underlying cause, buildup continues steadily toward 90% -> 100%
        rawPosRate = rawPosRate + (0.85 * sensMult)
    end

    local highLevelDamper = 1.0
    if self.clogLevel >= 75.0 then
        highLevelDamper = 0.85
    elseif self.clogLevel >= 65.0 then
        highLevelDamper = 0.90
    end
    local totalPosRate = rawPosRate * highLevelDamper

    if totalPosRate > 0.05 then
        self.clogLevel = math.min(100.0, self.clogLevel + totalPosRate * dtSec)
        self.clearedMassAccumLiters = math.min(600.0, self.clearedMassAccumLiters + math.max(1.0, safeMass * 1.2) * dtSec * 8.0)

        -- Determine dominant physical cause for HUD/Tablet diagnostics
        local maxRate = rateOverload
        local cause = RHM_CloggingSystem.CAUSE_OVERLOAD
        if rateMoisture > maxRate then
            maxRate = rateMoisture
            cause = RHM_CloggingSystem.CAUSE_MOISTURE
        end
        if rateWeeds > maxRate then
            maxRate = rateWeeds
            cause = RHM_CloggingSystem.CAUSE_WEEDS
        end
        if rateSettings > maxRate then
            maxRate = rateSettings
            cause = RHM_CloggingSystem.CAUSE_SETTINGS
        end
        if rateSurge > maxRate then
            cause = RHM_CloggingSystem.CAUSE_SURGE
        end
        if maxRate > 0.05 then
            self.clogCause = cause
        end
    else
        -- Safe operating envelope:
        -- 1) Combine OR header turned OFF -> completely frozen (0%/s)
        -- 2) Both combine AND header ON, not feeding new crop (empty purge) -> gradual digest (-1.4%/s below 65%, -0.75%/s at standstill 65..89%)
        -- 3) Actively harvesting in clean/light conditions (<65% clog) -> slow trickle down (-0.18..-0.45%/s)
        if self.clogLevel > 0.0 and isThreshing and headerTurnedOn then
            local decayRate = 0.0
            if not isActivelyFeeding then
                if self.clogLevel < 65.0 then
                    decayRate = 1.4
                elseif (speedKmh or 0) < 0.8 then
                    decayRate = 0.75
                end
            elseif self.clogLevel < 65.0 then
                local mLim = moistureLimitPct or 14.0
                local calibRiskNow = (vehicle and vehicle.spec_rhm_Combine and vehicle.spec_rhm_Combine.loadCalculator and vehicle.spec_rhm_Combine.loadCalculator.settingsClogRisk) or 0.0
                local cleanEnvelope = (weedRatio or 0.0) <= 0.04
                    and (moisturePct or 0.0) <= (mLim + 1.0)
                    and calibRiskNow <= 0.03
                if cleanEnvelope then
                    if load <= 70.0 then
                        decayRate = 0.45
                    elseif load <= 82.0 then
                        decayRate = 0.18
                    end
                end
            end
            if decayRate > 0.0 then
                self.clogLevel = math.max(0.0, self.clogLevel - decayRate * dtSec)
                if self.clogLevel <= 1.0 then
                    self.clogLevel = 0.0
                    self.clogCause = RHM_CloggingSystem.CAUSE_NONE
                    self.clearedMassAccumLiters = 0.0
                end
            end
        end
    end

    -- State transitions with clean hysteresis (35% Warning, 65% Slip Clutch, 100% Hard Blockage)
    if self.clogLevel >= 100.0 then
        self.clogLevel = 100.0
        self.clogState = RHM_CloggingSystem.STATE_BLOCKED
        self.justHitBlocked = true
        if vehicle and vehicle.setIsTurnedOn and vehicle.getIsTurnedOn and vehicle:getIsTurnedOn() then
            vehicle:setIsTurnedOn(false, true)
        end
    elseif self.clogLevel >= 65.0 or (self.clogState == RHM_CloggingSystem.STATE_SLIP_CLUTCH and self.clogLevel >= 50.0) then
        if self.clogState < RHM_CloggingSystem.STATE_SLIP_CLUTCH then
            self.justHitSlipClutch = true
        end
        self.clogState = RHM_CloggingSystem.STATE_SLIP_CLUTCH
        self.slipPushTimer = 0.0
    elseif self.clogLevel >= 35.0 or (self.clogState == RHM_CloggingSystem.STATE_WARNING and self.clogLevel >= 25.0) then
        self.clogState = RHM_CloggingSystem.STATE_WARNING
    else
        self.clogState = RHM_CloggingSystem.STATE_NORMAL
        if self.clogLevel < 5.0 then
            self.clogCause = RHM_CloggingSystem.CAUSE_NONE
        end
    end
end

---EN: Handles client-side hold progress when player holds RHM_CLEAR_CLOG on foot near header/feeder.
---Returns true when clearing finishes this tick.
function RHM_CloggingSystem:processManualClearTick(vehicle, dt, isHolding)
    if self.clogState ~= RHM_CloggingSystem.STATE_BLOCKED then
        self.manualClearProgress = 0.0
        return false
    end
    if not isHolding then
        self.manualClearProgress = math.max(0.0, (self.manualClearProgress or 0.0) - (dt * 0.001) * 0.25)
        return false
    end

    local durationSec = 10.0
    self.manualClearProgress = math.min(1.0, (self.manualClearProgress or 0.0) + (dt * 0.001) / durationSec)
    if self.manualClearProgress >= 1.0 then
        self.manualClearProgress = 0.0
        return true
    end
    return false
end
