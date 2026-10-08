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
            local machineKey = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(activeCombine)) or activeCombine.configFileName or "Harvester"
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
            if mTrip.isActive or (mTrip.sessionDuration and mTrip.sessionDuration > 0) or (mTrip.harvestedLiters and mTrip.harvestedLiters > 0) then
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

    local isLossEnabled = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableCropLoss)

    local r = trip.reasons or { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }
    local totalLost = isLossEnabled and (trip.lostLiters or 0) or 0
    local sumReasons = (r.speed or 0) + (r.settings or 0) + (r.moisture or 0) + (r.wear or 0) + (r.slope or 0)
    if sumReasons <= 0.001 then sumReasons = 1.0 end

    local speedPct = isLossEnabled and math.min(100, ((r.speed or 0) / sumReasons) * 100.0) or 0
    local settingsPct = isLossEnabled and math.min(100, ((r.settings or 0) / sumReasons) * 100.0) or 0
    local moisturePct = isLossEnabled and math.min(100, ((r.moisture or 0) / sumReasons) * 100.0) or 0
    local wearPct = isLossEnabled and math.min(100, ((r.wear or 0) / sumReasons) * 100.0) or 0
    local slopePct = isLossEnabled and math.min(100, ((r.slope or 0) / sumReasons) * 100.0) or 0

    -- Update Values & Subtexts
    local speedL = isLossEnabled and (r.speed or 0) or 0
    local settingsL = isLossEnabled and (r.settings or 0) or 0
    local moistL = isLossEnabled and (r.moisture or 0) or 0
    local wearL = isLossEnabled and (r.wear or 0) or 0
    local slopeL = isLossEnabled and (r.slope or 0) or 0

    if self.speedValText then self.speedValText:setText(string.format("%.1f%% (%.0f L)", speedPct, speedL)) end
    if self.settingsValText then self.settingsValText:setText(string.format("%.1f%% (%.0f L)", settingsPct, settingsL)) end
    if self.moistureValText then self.moistureValText:setText(string.format("%.1f%% (%.0f L)", moisturePct, moistL)) end
    if self.wearValText then self.wearValText:setText(string.format("%.1f%% (%.0f L)", wearPct, wearL)) end
    if self.slopeValText then self.slopeValText:setText(string.format("%.1f%% (%.0f L)", slopePct, slopeL)) end

    -- Update Progress Bar widths and colors (proportional to background size)
    local function updateCauseRow(valText, fillElem, bgElem, pct)
        if fillElem and bgElem and bgElem.size then
            local bgW = bgElem.size[1] or (640 / 1920)
            local fillW = math.max(0.005, (pct / 100.0) * bgW)
            fillElem:setSize(fillW, nil)
            local col = RHM_UIColors.getLossColor(pct)
            fillElem:setImageColor(nil, col[1], col[2], col[3], col[4] or 1.0)
            if valText then
                RHM_UIColors.applyTextColor(valText, pct > 0.05 and col or RHM_UIColors.WHITE)
            end
        end
    end
    updateCauseRow(self.speedValText, self.speedBarFill, self.speedBarBg, speedPct)
    updateCauseRow(self.settingsValText, self.settingsBarFill, self.settingsBarBg, settingsPct)
    updateCauseRow(self.moistureValText, self.moistureBarFill, self.moistureBarBg, moisturePct)
    updateCauseRow(self.wearValText, self.wearBarFill, self.wearBarBg, wearPct)
    updateCauseRow(self.slopeValText, self.slopeBarFill, self.slopeBarBg, slopePct)

    -- Scorecard Badge
    local rank = isLossEnabled and (trip.efficiencyRank or "A") or "A"
    local rankCol = RHM_UIColors and RHM_UIColors.getRankColor and RHM_UIColors.getRankColor(rank) or {0.61, 0.85, 0.15, 1.0}
    if self.rankBadgeText then
        self.rankBadgeText:setText("[" .. rank .. "]")
        if RHM_UIColors and RHM_UIColors.applyTextColor then
            RHM_UIColors.applyTextColor(self.rankBadgeText, rankCol)
        elseif self.rankBadgeText.setTextColor then
            self.rankBadgeText:setTextColor(rankCol[1], rankCol[2], rankCol[3], rankCol[4] or 1.0)
        end
    end

    local rankTitleKey = "rhm_rank_title_" .. string.lower(rank)
    local rankDescKey = "rhm_rank_desc_" .. string.lower(rank)
    if self.rankTitleText and g_i18n and g_i18n:hasText(rankTitleKey) then
        self.rankTitleText:setText(g_i18n:getText(rankTitleKey))
    end
    if self.rankDescText and g_i18n then
        if not isLossEnabled then
            local desc = g_i18n:hasText("rhm_loss_disabled_desc") and g_i18n:getText("rhm_loss_disabled_desc") or "Loss simulation is disabled in mod settings."
            self.rankDescText:setText(desc)
        elseif g_i18n:hasText(rankDescKey) then
            self.rankDescText:setText(g_i18n:getText(rankDescKey))
        end
    end

    -- Contextual Guidance
    local adviceKey = "rhm_advice_perfect"
    if not isLossEnabled then
        adviceKey = "rhm_cause_none"
    else
        local dominant = RHM_HarvestTracker.getDominantLossFactor(r)
        adviceKey = "rhm_advice_" .. dominant
        if totalLost < 5 then
            adviceKey = "rhm_advice_perfect"
        end
    end
    if self.adviceText and g_i18n and g_i18n:hasText(adviceKey) then
        self.adviceText:setText(g_i18n:getText(adviceKey))
    end
end
