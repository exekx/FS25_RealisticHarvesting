-- ============================================================================
-- RHM_HarvestHistoryTrip.lua
-- Realistic Harvesting Mod - Field Trip Odometer Tab Frame
-- ============================================================================

RHM_HarvestHistoryTrip = {}
local HarvestHistoryTrip_mt = Class(RHM_HarvestHistoryTrip, TabbedMenuFrameElement)

function RHM_HarvestHistoryTrip.new(l18n)
    local self = TabbedMenuFrameElement.new(nil, HarvestHistoryTrip_mt)
    self.l18n = l18n
    return self
end

function RHM_HarvestHistoryTrip:initialize()
end

function RHM_HarvestHistoryTrip:onGuiSetupFinished()
    RHM_HarvestHistoryTrip:superClass().onGuiSetupFinished(self)
end

function RHM_HarvestHistoryTrip:onFrameOpen()
    RHM_HarvestHistoryTrip:superClass().onFrameOpen(self)
    self.refreshTimer = 0
    self:updateData()
end

function RHM_HarvestHistoryTrip:onFrameClose()
    RHM_HarvestHistoryTrip:superClass().onFrameClose(self)
    self.refreshTimer = 0
end

function RHM_HarvestHistoryTrip:update(dt)
    RHM_HarvestHistoryTrip:superClass().update(self, dt)
    self.refreshTimer = (self.refreshTimer or 0) + dt
    if self.refreshTimer >= 1000 then
        self.refreshTimer = 0
        self:updateData()
    end
end

function RHM_HarvestHistoryTrip:getActiveTrip()
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

    -- 1. If player is currently driving or sitting in a combine, track THIS specific combine!
    local activeCombine = RHM_HarvestTracker and RHM_HarvestTracker.findPlayerEnteredCombine and RHM_HarvestTracker.findPlayerEnteredCombine()
    if activeCombine then
        local trip = nil
        local machineKey = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(activeCombine)) or activeCombine.configFileName or "Harvester"

        -- First check if combine spec itself already holds its isolated trip
        if activeCombine.spec_rhm_Combine and activeCombine.spec_rhm_Combine.trip then
            trip = activeCombine.spec_rhm_Combine.trip
        end

        -- Second check persistent per-machine trip table
        if not trip and farm and farm.combineTrips and farm.combineTrips[machineKey] then
            trip = farm.combineTrips[machineKey]
        end

        -- Third check: fallback to farm.currentTrip ONLY if it belonged to THIS combine
        if (not trip or (trip.harvestedLiters or 0) <= 0) and farm and farm.currentTrip and (farm.currentTrip.harvestedLiters or 0) > 0 then
            if farm.currentTrip.lastMachineKey ~= nil and farm.currentTrip.lastMachineKey == machineKey then
                farm.combineTrips = farm.combineTrips or {}
                if not farm.combineTrips[machineKey] then
                    farm.combineTrips[machineKey] = {
                        fieldId = farm.currentTrip.fieldId or 0,
                        cropName = farm.currentTrip.cropName or "--",
                        fillTypeIndex = farm.currentTrip.fillTypeIndex or FillType.UNKNOWN,
                        harvestedAreaHa = farm.currentTrip.harvestedAreaHa or 0,
                        harvestedLiters = farm.currentTrip.harvestedLiters or 0,
                        harvestedMassKg = farm.currentTrip.harvestedMassKg or 0,
                        lostLiters = farm.currentTrip.lostLiters or 0,
                        lossMoney = farm.currentTrip.lossMoney or 0,
                        sessionDuration = farm.currentTrip.sessionDuration or 0,
                        avgSpeedSum = farm.currentTrip.avgSpeedSum or 0,
                        avgSpeedCount = farm.currentTrip.avgSpeedCount or 0,
                        avgLoadSum = farm.currentTrip.avgLoadSum or 0,
                        avgLoadCount = farm.currentTrip.avgLoadCount or 0,
                        efficiencyRank = farm.currentTrip.efficiencyRank or RHM_HarvestTracker.RANK_A,
                        reasons = {
                            speed = farm.currentTrip.reasons and farm.currentTrip.reasons.speed or 0,
                            moisture = farm.currentTrip.reasons and farm.currentTrip.reasons.moisture or 0,
                            wear = farm.currentTrip.reasons and farm.currentTrip.reasons.wear or 0,
                            slope = farm.currentTrip.reasons and farm.currentTrip.reasons.slope or 0
                        },
                        isActive = farm.currentTrip.isActive or false
                    }
                end
                trip = farm.combineTrips[machineKey]
            end
        end

        -- If still nil, fallback to spec.trip
        if not trip and activeCombine.spec_rhm_Combine and activeCombine.spec_rhm_Combine.trip then
            trip = activeCombine.spec_rhm_Combine.trip
        end

        -- Fourth check: create a fresh isolated trip for this combine if none exists
        if not trip then
            trip = {
                fieldId = 0,
                isContract = false,
                cropName = "--",
                fillTypeIndex = FillType.UNKNOWN,
                harvestedAreaHa = 0,
                harvestedLiters = 0,
                harvestedMassKg = 0,
                lostLiters = 0,
                lossMoney = 0,
                sessionDuration = 0,
                avgSpeedSum = 0,
                avgSpeedCount = 0,
                avgLoadSum = 0,
                avgLoadCount = 0,
                efficiencyRank = RHM_HarvestTracker.RANK_A,
                reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 },
                isActive = false
            }
            if farm then
                farm.combineTrips = farm.combineTrips or {}
                farm.combineTrips[machineKey] = trip
            end
        end

        if trip and activeCombine.spec_rhm_Combine then
            activeCombine.spec_rhm_Combine.trip = trip
        end
        return trip, activeCombine, farmId
    end

    -- 2. If player is not in a combine, check if there is an active combine in the fleet
    if farm and farm.combineTrips then
        for machineKey, mTrip in pairs(farm.combineTrips) do
            if mTrip.isActive or (mTrip.sessionDuration and mTrip.sessionDuration > 0) or (mTrip.harvestedLiters and mTrip.harvestedLiters > 0) then
                return mTrip, nil, farmId
            end
        end
    end

    -- 3. Fallback to farm's combined trip
    if farm and farm.currentTrip then
        return farm.currentTrip, nil, farmId
    end

    return nil, nil, farmId
end

function RHM_HarvestHistoryTrip:updateData()
    local trip, activeCombine, farmId = self:getActiveTrip()
    if not trip then return end

    -- Field & Crop
    local fieldId = trip.fieldId or 0
    local isAtYard = false
    if fieldId == 0 and activeCombine and activeCombine.rootNode then
        local wx, _, wz = getWorldTranslation(activeCombine.rootNode)
        local _, fId, fmlId = nil, 0, 0
        if RHM_HarvestTracker and RHM_HarvestTracker.getFieldAtWorldPosition then
            _, fId, fmlId = RHM_HarvestTracker.getFieldAtWorldPosition(wx, wz, activeCombine)
        end
        if fId and fId > 0 then
            fieldId = fId
        elseif fmlId and fmlId > 0 and g_farmlandManager and g_farmlandManager.getFarmlandOwner then
            if g_farmlandManager:getFarmlandOwner(fmlId) == farmId then
                isAtYard = true
            end
        end
    end

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    local masterId = fieldId
    local clusterMembers = nil
    if fieldId > 0 and tracker then
        masterId = (tracker.getMasterFieldId and tracker:getMasterFieldId(farmId, fieldId)) or fieldId
        clusterMembers = (tracker.getClusterMembers and tracker:getClusterMembers(farmId, masterId)) or nil
    end

    local isContract = (trip.isContract == true)
    if not isContract and fieldId > 0 and RHM_HarvestTracker and RHM_HarvestTracker.isContractField then
        isContract = RHM_HarvestTracker.isContractField(fieldId, farmId)
    end

    local contractTag = ""
    if isContract then
        local contractText = (g_i18n and g_i18n:hasText("rhm_contract_tag")) and g_i18n:getText("rhm_contract_tag") or "(Contract)"
        contractTag = " " .. contractText
    end

    local fieldStr = ""
    if fieldId > 0 then
        if clusterMembers and #clusterMembers > 1 then
            fieldStr = string.format("%d (%s)%s", masterId, table.concat(clusterMembers, ", "), contractTag)
        else
            fieldStr = tostring(fieldId) .. contractTag
        end
    elseif isAtYard then
        fieldStr = (g_i18n and g_i18n:getText("rhm_field_yard")) or "Yard / Base"
    else
        fieldStr = (g_i18n and g_i18n:getText("rhm_trip_no_field")) or "--"
    end
    local cropStr = trip.cropName or "--"
    if cropStr == "UNKNOWN" or cropStr == "--" then
        if activeCombine then
            local fillTypeIdx = nil
            if activeCombine.spec_rhm_Combine and activeCombine.spec_rhm_Combine.lastFillType and activeCombine.spec_rhm_Combine.lastFillType ~= FillType.UNKNOWN then
                fillTypeIdx = activeCombine.spec_rhm_Combine.lastFillType
            elseif activeCombine.spec_combine and activeCombine.spec_combine.lastValidInputFruitType then
                fillTypeIdx = activeCombine.spec_combine.lastValidInputFruitType
            end
            if fillTypeIdx and fillTypeIdx ~= FillType.UNKNOWN and g_fillTypeManager then
                local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIdx)
                if ft and ft.title then cropStr = ft.title end
            end
        end
    end
    if trip.fillTypeIndex and trip.fillTypeIndex ~= FillType.UNKNOWN and g_fillTypeManager then
        local ft = g_fillTypeManager:getFillTypeByIndex(trip.fillTypeIndex)
        if ft and ft.title then cropStr = ft.title end
    end
    if self.fieldNumberText then
        self.fieldNumberText:setText(fieldStr)
        if self.fieldNumberText.setTextSize then
            self.fieldNumberText:setTextSize((#fieldStr > 10) and 16 or 24)
        end
    end
    if self.cropTypeText then self.cropTypeText:setText(cropStr) end

    -- Status Band & Header Summary Box
    if self.tripSummaryHeaderTitle then
        local fieldLabel = (g_i18n and g_i18n:hasText("rhm_field_number")) and g_i18n:getText("rhm_field_number") or "FIELD"
        local statusLabel = ""
        local hasCutterOn = false
        if activeCombine then
            if activeCombine.spec_combine and activeCombine.spec_combine.attachedCutters then
                for cutter, _ in pairs(activeCombine.spec_combine.attachedCutters) do
                    if cutter.getIsTurnedOn and cutter:getIsTurnedOn() then
                        hasCutterOn = true
                        break
                    end
                end
            end
            if not hasCutterOn and activeCombine.getAttachedImplements then
                for _, impl in pairs(activeCombine:getAttachedImplements()) do
                    if impl.object and impl.object.getIsTurnedOn and impl.object:getIsTurnedOn() and impl.object.spec_cutter then
                        hasCutterOn = true
                        break
                    end
                end
            end
        end

        local speedKmh = (activeCombine and activeCombine.getLastSpeed and activeCombine:getLastSpeed()) or 0
        local isCutting = (trip.isActive == true) or (hasCutterOn and speedKmh > 0.5)

        if isCutting then
            statusLabel = (g_i18n and g_i18n:hasText("rhm_status_harvesting")) and g_i18n:getText("rhm_status_harvesting") or "ACTIVE"
        elseif speedKmh > 0.5 then
            statusLabel = (g_i18n and g_i18n:hasText("rhm_status_in_transit")) and g_i18n:getText("rhm_status_in_transit") or "IN TRANSIT"
        elseif isAtYard then
            statusLabel = (g_i18n and g_i18n:hasText("rhm_status_parked_yard")) and g_i18n:getText("rhm_status_parked_yard") or "STOPPED"
        else
            statusLabel = (g_i18n and g_i18n:hasText("rhm_status_on_field_stopped")) and g_i18n:getText("rhm_status_on_field_stopped") or "STOPPED"
        end
        self.tripSummaryHeaderTitle:setText(string.format("%s: %s   |   %s   ·   %s", fieldLabel, fieldStr, cropStr, statusLabel))
    end

    local sys = (RHM_UnitConverter and RHM_UnitConverter.getActiveSystem and RHM_UnitConverter.getActiveSystem()) or 1
    local isCropLossEnabled = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableCropLoss)

    -- Harvested Area & Volume
    local areaHa = trip.harvestedAreaHa or 0
    local harvestedL = trip.harvestedLiters or 0
    local cDensity = (RHM_UnitConverter and RHM_UnitConverter.getCropDensityTonsPerLiter and RHM_UnitConverter.getCropDensityTonsPerLiter(trip.fillTypeIndex or trip.cropName)) or 0.00075
    local harvestedTons = (trip.harvestedMassKg and trip.harvestedMassKg > 0) and (trip.harvestedMassKg / 1000.0) or (harvestedL * cDensity)
    local nominalArea = (fieldId > 0 and RHM_HarvestTracker and RHM_HarvestTracker.getFieldNominalAreaHa and RHM_HarvestTracker.getFieldNominalAreaHa(masterId, nil, nil, farmId)) or 0
    if self.harvestedAreaText then
        self.harvestedAreaText:setText(RHM_UnitConverter.formatArea(areaHa, sys))
    end
    if self.harvestedAreaSubText then
        if nominalArea > 0.01 then
            local progressPct = math.min(100.0, (areaHa / nominalArea) * 100.0)
            local nominalLabel = (g_i18n and g_i18n:hasText("rhm_fields_nominal_area")) and g_i18n:getText("rhm_fields_nominal_area") or "Nominal Area"
            self.harvestedAreaSubText:setText(string.format("%s: %s (%.1f%%)", nominalLabel, RHM_UnitConverter.formatArea(nominalArea, sys), progressPct))
        else
            local detailAreaKey = "rhm_detail_area"
            local areaDetailStr = (g_i18n and g_i18n:hasText(detailAreaKey)) and g_i18n:getText(detailAreaKey) or "effective harvested area"
            self.harvestedAreaSubText:setText(areaDetailStr)
        end
    end
    if self.harvestedVolumeText then
        self.harvestedVolumeText:setText(RHM_UnitConverter.formatMass(harvestedTons, sys, trip.fillTypeIndex, harvestedL))
    end
    if self.harvestedVolumeSubText then
        local detailCleanKey = "rhm_detail_clean_grain"
        local cleanGrainStr = (g_i18n and g_i18n:hasText(detailCleanKey)) and g_i18n:getText(detailCleanKey) or "clean grain"
        self.harvestedVolumeSubText:setText(string.format("%.0f L %s", harvestedL, cleanGrainStr))
    end

    -- Average Yield
    local avgYield = (areaHa > 0.01) and (harvestedTons / areaHa) or 0
    if self.avgYieldText then
        self.avgYieldText:setText(RHM_UnitConverter.formatYield(avgYield, sys, trip.fillTypeIndex))
    end

    -- Losses & Finances
    local lostL = isCropLossEnabled and (trip.lostLiters or 0) or 0
    local lostTons = 0
    if isCropLossEnabled and trip.harvestedLiters and trip.harvestedLiters > 0 and harvestedTons > 0 then
        lostTons = (lostL / trip.harvestedLiters) * harvestedTons
    elseif isCropLossEnabled then
        lostTons = lostL * cDensity
    end
    local totalBio = harvestedL + lostL
    local lossPct = (isCropLossEnabled and totalBio > 0) and ((lostL / totalBio) * 100.0) or 0

    if self.lossVolumeText then
        if isCropLossEnabled then
            self.lossVolumeText:setText(RHM_UnitConverter.formatMass(lostTons, sys, trip.fillTypeIndex, lostL))
            RHM_UIColors.applyTextColor(self.lossVolumeText, RHM_UIColors.getLossColor(lossPct))
        else
            self.lossVolumeText:setText("--")
            RHM_UIColors.applyTextColor(self.lossVolumeText, RHM_UIColors.GRAY)
        end
    end
    if self.lossVolumeSubText then
        if isCropLossEnabled then
            local detailLostKey = "rhm_detail_lost_grain"
            local lostGrainStr = (g_i18n and g_i18n:hasText(detailLostKey)) and g_i18n:getText(detailLostKey) or "grain lost"
            self.lossVolumeSubText:setText(string.format("%.0f L %s", lostL, lostGrainStr))
        else
            self.lossVolumeSubText:setText(g_i18n:getText("rhm_loss_disabled") or "Disabled")
        end
    end
    if self.lossPercentText then
        if isCropLossEnabled then
            self.lossPercentText:setText(string.format("%.2f%%", lossPct))
            RHM_UIColors.applyTextColor(self.lossPercentText, RHM_UIColors.getLossColor(lossPct))
        else
            self.lossPercentText:setText("OFF")
            RHM_UIColors.applyTextColor(self.lossPercentText, RHM_UIColors.GRAY)
        end
    end
    if self.lossRatingSubText then
        if isCropLossEnabled then
            local ratingKey = "rhm_rating_normal"
            if lossPct >= 4.5 then ratingKey = "rhm_rating_critical"
            elseif lossPct >= 3.0 then ratingKey = "rhm_rating_elevated"
            elseif lossPct >= 1.5 then ratingKey = "rhm_rating_moderate"
            end
            local ratingStr = (g_i18n and g_i18n:hasText(ratingKey)) and g_i18n:getText(ratingKey) or "< 1.5%"
            self.lossRatingSubText:setText(ratingStr)
        else
            self.lossRatingSubText:setText(g_i18n:getText("rhm_loss_disabled") or "Disabled")
        end
    end

    -- Loss Progress Bar (normalized width, untouched height)
    local lossBarCol = RHM_UIColors.getLossColor(lossPct)
    if self.lossBarFill and self.lossBarBg and self.lossBarBg.size then
        local bgW = self.lossBarBg.size[1] or (308 / 1920)
        local lossRatio = isCropLossEnabled and math.min(1.0, math.max(0.0, lossPct / 5.0)) or 0
        local fillW = math.max(0.002, lossRatio * bgW)
        self.lossBarFill:setSize(fillW, nil)
        self.lossBarFill:setImageColor(nil, lossBarCol[1], lossBarCol[2], lossBarCol[3], lossBarCol[4] or 1.0)
    end
    if self.lossPercentText then
        self.lossPercentText:setText(string.format("%.2f%%", lossPct))
        RHM_UIColors.applyTextColor(self.lossPercentText, lossBarCol)
    end

    local moneyVal = isCropLossEnabled and (trip.lossMoney or 0) or 0
    local moneyStr = "-$0"
    if g_i18n and g_i18n.formatMoney then
        moneyStr = "-" .. g_i18n:formatMoney(moneyVal, nil, true, true)
    else
        moneyStr = string.format("-$%.0f", moneyVal)
    end
    if self.lossMoneyText then
        self.lossMoneyText:setText(moneyStr)
        RHM_UIColors.applyTextColor(self.lossMoneyText, moneyVal > 0 and RHM_UIColors.RED or RHM_UIColors.WHITE)
    end

    -- Efficiency Rank & Emblem
    local rank = isCropLossEnabled and (trip.efficiencyRank or "A") or "A"
    local rankCol = RHM_UIColors.getRankColor(rank)
    if self.efficiencyRankBadge then
        self.efficiencyRankBadge:setText("[" .. rank .. "]")
        RHM_UIColors.applyTextColor(self.efficiencyRankBadge, rankCol)
    end

    local rankKey = "rhm_rank_desc_" .. string.lower(rank)
    local rankTitleKey = "rhm_rank_title_" .. string.lower(rank)
    local rankTitle = (g_i18n and g_i18n:hasText(rankTitleKey)) and g_i18n:getText(rankTitleKey) or ("Rank " .. rank)
    local rankDesc = (g_i18n and g_i18n:hasText(rankKey)) and g_i18n:getText(rankKey) or ""
    if not isCropLossEnabled then
        rankDesc = (g_i18n and g_i18n:hasText("rhm_loss_disabled_desc")) and g_i18n:getText("rhm_loss_disabled_desc") or "Loss simulation is disabled in mod settings."
    end
    if self.efficiencyRankTitle then
        self.efficiencyRankTitle:setText(rankTitle)
        RHM_UIColors.applyTextColor(self.efficiencyRankTitle, rankCol)
    end
    if self.efficiencyRankDesc then self.efficiencyRankDesc:setText(rankDesc) end

    -- Dominant Cause / Advice
    if self.dominantCauseText then
        local adviceKey = "rhm_advice_perfect"
        if not isCropLossEnabled then
            adviceKey = "rhm_cause_none"
        elseif lossPct >= 1.5 and trip.reasons then
            local r_reasons = trip.reasons
            local maxVal = math.max(r_reasons.speed or 0, r_reasons.settings or 0, r_reasons.moisture or 0, r_reasons.wear or 0, r_reasons.slope or 0)
            if maxVal > 0 then
                if maxVal == (r_reasons.speed or 0) then adviceKey = "rhm_advice_speed"
                elseif maxVal == (r_reasons.settings or 0) then adviceKey = "rhm_advice_settings"
                elseif maxVal == (r_reasons.moisture or 0) then adviceKey = "rhm_advice_moisture"
                elseif maxVal == (r_reasons.wear or 0) then adviceKey = "rhm_advice_wear"
                elseif maxVal == (r_reasons.slope or 0) then adviceKey = "rhm_advice_slope"
                end
            end
        end
        local adviceStr = (g_i18n and g_i18n:hasText(adviceKey)) and g_i18n:getText(adviceKey) or ""
        self.dominantCauseText:setText(adviceStr)
    end

    -- Fuel Telemetry
    local fuelL = trip.fuelUsedL or 0
    if self.fuelUsedText then
        self.fuelUsedText:setText(string.format("%.1f L", fuelL))
    end
    if self.fuelRateText then
        local lPerHa = (areaHa > 0.01) and (fuelL / areaHa) or 0
        local lPerTon = (harvestedTons > 0.01) and (fuelL / harvestedTons) or 0
        self.fuelRateText:setText(string.format("%.1f L/ha · %.1f L/t", lPerHa, lPerTon))
    end

    -- Averages & Duration
    local avgSpeed = (trip.avgSpeedCount and trip.avgSpeedCount > 0) and (trip.avgSpeedSum / trip.avgSpeedCount) or 0
    local avgLoad = (trip.avgLoadCount and trip.avgLoadCount > 0) and ((trip.avgLoadSum / trip.avgLoadCount) * 100.0) or 0
    local durSec = trip.sessionDuration or 0
    local durHours = math.floor(durSec / 3600)
    local durMin = math.floor((durSec % 3600) / 60)
    local durSecRem = math.floor(durSec % 60)
    local durStr = (durHours > 0) and string.format("%02d:%02d:%02d", durHours, durMin, durSecRem) or string.format("%02d:%02d", durMin, durSecRem)

    local loadRatio = math.min(1.0, math.max(0.0, avgLoad / 100.0))
    local loadCol = RHM_UIColors.getLoadColor(loadRatio)

    if self.avgSpeedText then
        self.avgSpeedText:setText(RHM_UnitConverter.formatSpeed(avgSpeed, sys))
    end
    if self.avgLoadText then
        self.avgLoadText:setText(string.format("%.0f%%", avgLoad))
        RHM_UIColors.applyTextColor(self.avgLoadText, loadCol)
    end
    local durElem = self.durationText or self.sessionDurationText
    if durElem then durElem:setText(durStr) end

    -- Engine Load Progress Bar (normalized width, untouched height)
    if self.loadBarFill and self.loadBarBg and self.loadBarBg.size then
        local bgW = self.loadBarBg.size[1] or (308 / 1920)
        local fillW = math.max(0.002, loadRatio * bgW)
        self.loadBarFill:setSize(fillW, nil)
        self.loadBarFill:setImageColor(nil, loadCol[1], loadCol[2], loadCol[3], loadCol[4] or 1.0)
    end

    -- Combine Model Name
    local modelName = (activeCombine and activeCombine.getName and activeCombine:getName())
                   or (activeCombine and activeCombine.getFullName and activeCombine:getFullName())
                   or "Harvester"
    if self.combineModelText then
        self.combineModelText:setText(modelName)
    end
    if self.tripSummaryHeaderMachine then
        self.tripSummaryHeaderMachine:setText(modelName)
    end

    -- Throughput
    local throughput = (durSec > 10) and (harvestedTons / (durSec / 3600.0)) or 0
    if self.avgThroughputText then
        self.avgThroughputText:setText(RHM_UnitConverter.formatProductivity(throughput, sys, trip.fillTypeIndex))
    end

    -- Machine Wear
    local wearVal = (activeCombine and activeCombine.getDamageAmount and activeCombine:getDamageAmount()) or 0
    local wearElem = self.wearDeltaText or self.machineWearText
    if wearElem then
        wearElem:setText(string.format("%.0f%%", wearVal * 100.0))
        RHM_UIColors.applyTextColor(wearElem, RHM_UIColors.getWearColor(wearVal))
    end

    -- Powertrain Status Guidance
    if self.powertrainStatusText then
        local msg = ""
        if avgLoad >= 98 then
            msg = (g_i18n and g_i18n:hasText("rhm_tut_overload_msg")) and g_i18n:getText("rhm_tut_overload_msg") or "Engine is operating near peak capacity."
        elseif lossPct >= 3.0 then
            msg = (g_i18n and g_i18n:hasText("rhm_tut_loss_msg")) and g_i18n:getText("rhm_tut_loss_msg") or "High crop loss detected behind sieves."
        elseif durSec < 15 then
            msg = (g_i18n and g_i18n:hasText("rhm_tut_welcome_msg")) and g_i18n:getText("rhm_tut_welcome_msg") or "Begin harvesting to collect trip telemetry."
        else
            msg = (g_i18n and g_i18n:hasText("rhm_advice_perfect")) and g_i18n:getText("rhm_advice_perfect") or "Harvesting efficiency is optimal."
        end
        self.powertrainStatusText:setText(msg)
    end

    -- Enable / disable Reset Trip button based on user permissions
    local canManage = true
    if g_currentMission and g_currentMission.isMultiplayer and g_currentMission.player and g_farmManager then
        local user = g_currentMission.userManager and g_currentMission.userManager:getUserByUserId(g_currentMission.player.userId)
        local realFarm = g_farmManager:getFarmById(farmId)
        if realFarm and user then
            canManage = (realFarm.ownerUserId == user.userId) 
                or (realFarm.isUserFarmManager and realFarm:isUserFarmManager(user.userId))
                or (realFarm.getIsUserFarmManager and realFarm:getIsUserFarmManager(user.userId))
                or (realFarm.isFarmManager and realFarm:isFarmManager(user.userId))
                or g_currentMission:getIsServer()
        end
    end
    if self.resetButton then self.resetButton:setDisabled(not canManage) end
end

function RHM_HarvestHistoryTrip:onClickResetTrip()
    local trip, activeCombine, farmId = self:getActiveTrip()

    local isMultiplayer = g_currentMission and g_currentMission.isMultiplayer
    local isDedicatedClient = isMultiplayer and not g_currentMission:getIsServer()

    if isDedicatedClient and g_client and g_client:getServerConnection() then
        g_client:getServerConnection():sendEvent(RHM_HarvestResetTripEvent.new(farmId))
    else
        local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
        if tracker then
            if activeCombine then
                tracker:resetTripForCombine(farmId, activeCombine, nil)
            else
                tracker:resetTrip(farmId, nil)
            end
        end
        if activeCombine and activeCombine.resetTrip then
            activeCombine:resetTrip()
        end
    end

    self:updateData()
end
