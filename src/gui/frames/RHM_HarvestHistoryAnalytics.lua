-- ============================================================================
-- RHM_HarvestHistoryAnalytics.lua
-- Realistic Harvesting Mod - Loss Root Cause & Scorecard Frame
-- ============================================================================

RHM_HarvestHistoryAnalytics = {}
local HarvestHistoryAnalytics_mt = Class(RHM_HarvestHistoryAnalytics, TabbedMenuFrameElement)

function RHM_HarvestHistoryAnalytics.new(l18n)
    local self = TabbedMenuFrameElement.new(nil, HarvestHistoryAnalytics_mt)
    self.l18n = l18n
    return self
end

function RHM_HarvestHistoryAnalytics:initialize()
end

function RHM_HarvestHistoryAnalytics:onGuiSetupFinished()
    RHM_HarvestHistoryAnalytics:superClass().onGuiSetupFinished(self)
end

function RHM_HarvestHistoryAnalytics:onFrameOpen()
    RHM_HarvestHistoryAnalytics:superClass().onFrameOpen(self)
    self:updateData()
end

function RHM_HarvestHistoryAnalytics:onFrameClose()
    RHM_HarvestHistoryAnalytics:superClass().onFrameClose(self)
end

function RHM_HarvestHistoryAnalytics:getActiveTrip()
    local farmId = 1
    if g_currentMission then
        if g_currentMission.getFarmId then
            farmId = g_currentMission:getFarmId()
        elseif g_currentMission.player and g_currentMission.player.farmId then
            farmId = g_currentMission.player.farmId
        end
    end
    if farmId == nil or farmId == 0 or (FarmManager and farmId == FarmManager.SPECTATOR_FARM_ID) then
        farmId = 1
    end

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    local farm = tracker and tracker:getFarmData(farmId)

    local activeCombine = RHM_HarvestTracker and RHM_HarvestTracker.findPlayerEnteredCombine and RHM_HarvestTracker.findPlayerEnteredCombine()
    if activeCombine then
        local trip = nil
        if activeCombine.spec_rhm_Combine and activeCombine.spec_rhm_Combine.trip then
            trip = activeCombine.spec_rhm_Combine.trip
        end
        if farm and farm.combineTrips then
            local machineKey = activeCombine.configFileName or (activeCombine.getFullName and activeCombine:getFullName()) or "Harvester"
            if farm.combineTrips[machineKey] then
                trip = farm.combineTrips[machineKey]
            end
        end
        if trip then
            return trip
        end
    end

    if farm and farm.combineTrips then
        for machineKey, mTrip in pairs(farm.combineTrips) do
            if mTrip.isActive or (mTrip.sessionDuration and mTrip.sessionDuration > 0) then
                return mTrip
            end
        end
    end

    if farm and farm.currentTrip then
        return farm.currentTrip
    end

    return nil
end

function RHM_HarvestHistoryAnalytics:updateData()
    local trip = self:getActiveTrip()
    if not trip then return end

    local r = trip.reasons or { speed = 0, moisture = 0, wear = 0, slope = 0 }
    local totalLost = trip.lostLiters or 0
    local sumReasons = (r.speed or 0) + (r.moisture or 0) + (r.wear or 0) + (r.slope or 0)
    if sumReasons <= 0.001 then sumReasons = 1.0 end

    local speedPct = math.min(100, ((r.speed or 0) / sumReasons) * 100.0)
    local moisturePct = math.min(100, ((r.moisture or 0) / sumReasons) * 100.0)
    local wearPct = math.min(100, ((r.wear or 0) / sumReasons) * 100.0)
    local slopePct = math.min(100, ((r.slope or 0) / sumReasons) * 100.0)

    -- Update Values & Subtexts
    if self.speedValText then self.speedValText:setText(string.format("%.1f%% (%.0f L)", speedPct, r.speed or 0)) end
    if self.moistureValText then self.moistureValText:setText(string.format("%.1f%% (%.0f L)", moisturePct, r.moisture or 0)) end
    if self.wearValText then self.wearValText:setText(string.format("%.1f%% (%.0f L)", wearPct, r.wear or 0)) end
    if self.slopeValText then self.slopeValText:setText(string.format("%.1f%% (%.0f L)", slopePct, r.slope or 0)) end

    -- Update Progress Bar widths (proportional to background size)
    local function setBarFillWidth(fillElem, bgElem, pct)
        if fillElem and bgElem and bgElem.size then
            local bgW = bgElem.size[1] or (640 / 1920)
            local fillW = math.max(0.005, (pct / 100.0) * bgW)
            fillElem:setSize(fillW, nil)
        end
    end
    setBarFillWidth(self.speedBarFill, self.speedBarBg, speedPct)
    setBarFillWidth(self.moistureBarFill, self.moistureBarBg, moisturePct)
    setBarFillWidth(self.wearBarFill, self.wearBarBg, wearPct)
    setBarFillWidth(self.slopeBarFill, self.slopeBarBg, slopePct)

    -- Scorecard Badge
    local rank = trip.efficiencyRank or "A"
    if self.rankBadgeText then self.rankBadgeText:setText("[" .. rank .. "]") end

    local rankTitleKey = "rhm_rank_title_" .. string.lower(rank)
    local rankDescKey = "rhm_rank_desc_" .. string.lower(rank)
    if self.rankTitleText and g_i18n and g_i18n:hasText(rankTitleKey) then
        self.rankTitleText:setText(g_i18n:getText(rankTitleKey))
    end
    if self.rankDescText and g_i18n and g_i18n:hasText(rankDescKey) then
        self.rankDescText:setText(g_i18n:getText(rankDescKey))
    end

    -- Contextual Guidance
    local dominant = RHM_HarvestTracker.getDominantLossFactor(r)
    local adviceKey = "rhm_advice_" .. dominant
    if totalLost < 5 then
        adviceKey = "rhm_advice_perfect"
    end
    if self.adviceText and g_i18n and g_i18n:hasText(adviceKey) then
        self.adviceText:setText(g_i18n:getText(adviceKey))
    end
end
