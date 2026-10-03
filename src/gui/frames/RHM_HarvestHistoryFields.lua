-- ============================================================================
-- RHM_HarvestHistoryFields.lua
-- Realistic Harvesting Mod - Farm Fields & Harvest by Field Overview Frame
-- ============================================================================
-- Technical architecture:
--   Inherits from GIANTS Engine 10 TabbedMenuFrameElement.
--   Displays comprehensive field-level production, yields, and losses across
--   all farm-owned land and completed contract operations.
--   Supports dynamic selection: clicking any field updates cards to that field's
--   exact telemetry, metrics, and dominant root loss cause.
-- ============================================================================

RHM_HarvestHistoryFields = {}
local HarvestHistoryFields_mt = Class(RHM_HarvestHistoryFields, TabbedMenuFrameElement)

function RHM_HarvestHistoryFields.new(l18n)
    local self = TabbedMenuFrameElement.new(nil, HarvestHistoryFields_mt)
    self.l18n = l18n
    self.fieldsData = {}
    self.selectedIndex = 1
    return self
end

function RHM_HarvestHistoryFields:initialize()
    if self.fieldsTable then
        self.fieldsTable:setDataSource(self)
        self.fieldsTable:setDelegate(self)
    end
end

function RHM_HarvestHistoryFields:onGuiSetupFinished()
    RHM_HarvestHistoryFields:superClass().onGuiSetupFinished(self)
end

function RHM_HarvestHistoryFields:onFrameOpen()
    RHM_HarvestHistoryFields:superClass().onFrameOpen(self)
    self.selectedIndex = 1
    self:updateData()
end

function RHM_HarvestHistoryFields:onFrameClose()
    RHM_HarvestHistoryFields:superClass().onFrameClose(self)
end

function RHM_HarvestHistoryFields:getFarmId()
    local farmId = 1
    if g_currentMission then
        if g_currentMission.getFarmId then
            farmId = g_currentMission:getFarmId()
        elseif g_currentMission.player and g_currentMission.player.getFarmId then
            farmId = g_currentMission.player:getFarmId()
        elseif g_currentMission.player and g_currentMission.player.farmId then
            farmId = g_currentMission.player.farmId
        end
    end
    if farmId == nil or farmId == 0 or (FarmManager and farmId == FarmManager.SPECTATOR_FARM_ID) then
        farmId = 1
    end
    return farmId
end

function RHM_HarvestHistoryFields:updateData()
    local farmId = self:getFarmId()
    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if not tracker then return end

    local fieldList = tracker:getFarmFields(farmId)
    self.fieldsData = {}

    local totalOwnedCount = 0
    local totalContractCount = 0
    local totalNominalArea = 0
    local totalHarvestedArea = 0
    local totalHarvestL = 0
    local totalLostL = 0
    local totalMoney = 0
    local totalWorkSecs = 0

    local cropTotals = {}
    local bestYield = 0
    local bestYieldField = "--"

    local reasonSums = { speed = 0, moisture = 0, wear = 0, slope = 0 }
    local fieldItems = {}

    for _, f in ipairs(fieldList) do
        if f.isOwned then
            totalOwnedCount = totalOwnedCount + 1
            totalNominalArea = totalNominalArea + (f.nominalAreaHa or 0)
        elseif f.isContract then
            totalContractCount = totalContractCount + 1
        end

        local hArea = f.harvestedAreaHa or 0
        local harvL = f.harvestedLiters or 0
        local lostL = f.lostLiters or 0
        local money = f.lossMoney or 0
        local harvT = (f.harvestedMassKg and f.harvestedMassKg > 0) and (f.harvestedMassKg * 0.001) or (harvL * 0.00075)

        totalHarvestedArea = totalHarvestedArea + hArea
        totalHarvestL = totalHarvestL + harvL
        totalLostL = totalLostL + lostL
        totalMoney = totalMoney + money
        totalWorkSecs = totalWorkSecs + (f.sessionDuration or 0)

        if f.reasons then
            reasonSums.speed = reasonSums.speed + (f.reasons.speed or 0)
            reasonSums.moisture = reasonSums.moisture + (f.reasons.moisture or 0)
            reasonSums.wear = reasonSums.wear + (f.reasons.wear or 0)
            reasonSums.slope = reasonSums.slope + (f.reasons.slope or 0)
        end

        local yieldTha = (hArea > 0.001) and (harvT / hArea) or 0
        if yieldTha > bestYield and hArea >= 0.05 then
            bestYield = yieldTha
            bestYieldField = string.format("Field %d (%.1f t/ha)", f.fieldId, yieldTha)
        end

        if f.cropVolumes then
            for cName, cLiters in pairs(f.cropVolumes) do
                cropTotals[cName] = (cropTotals[cName] or 0) + cLiters
            end
        elseif f.lastCrop and f.lastCrop ~= "--" and harvL > 0 then
            cropTotals[f.lastCrop] = (cropTotals[f.lastCrop] or 0) + harvL
        end

        local bioVol = harvL + lostL
        local lossPct = (bioVol > 0) and ((lostL / bioVol) * 100.0) or 0
        local rank = RHM_HarvestTracker.calculateEfficiencyRank(lossPct)

        local fieldName = string.format(g_i18n:getText("rhm_field_format") or "Field %d", f.fieldId)
        local statusStr = ""
        if f.isOwned then
            statusStr = g_i18n:getText("rhm_fields_owned") or "Owned"
        elseif f.isContract then
            statusStr = g_i18n:getText("rhm_fields_contract") or "Contract"
        else
            statusStr = (g_i18n and g_i18n:hasText("rhm_fields_external") and g_i18n:getText("rhm_fields_external")) or "External"
        end
        if f.isContract then
            fieldName = fieldName .. " [" .. (g_i18n:getText("rhm_contract_tag") or "Contract") .. "]"
        end

        local cropDisplay = f.lastCrop or "--"
        if g_fillTypeManager and cropDisplay ~= "--" and cropDisplay ~= "UNKNOWN" then
            local ft = g_fillTypeManager:getFillTypeByName(cropDisplay)
            if ft and ft.title and ft.title ~= "" then
                cropDisplay = ft.title
            end
        end

        local moneyStr = "-$0"
        if g_i18n and g_i18n.formatMoney then
            moneyStr = "-" .. g_i18n:formatMoney(money, nil, true, true)
        else
            moneyStr = string.format("-$%.0f", money)
        end

        -- Field-specific dominant cause
        local fieldDominant = RHM_HarvestTracker.getDominantLossFactor(f.reasons)
        local fieldReasonKey = "rhm_cause_" .. tostring(fieldDominant or "speed")
        local sumReasons = (f.reasons and (f.reasons.speed + f.reasons.moisture + f.reasons.wear + f.reasons.slope)) or 0
        if lostL <= 0.001 and sumReasons <= 0.001 then
            fieldReasonKey = "rhm_cause_none"
        end
        local fieldDominantText = (g_i18n and g_i18n:hasText(fieldReasonKey) and g_i18n:getText(fieldReasonKey)) or fieldDominant or "Speed"

        table.insert(fieldItems, {
            isOverview = false,
            fieldId = f.fieldId,
            field = fieldName,
            status = statusStr,
            isOwned = f.isOwned,
            isContract = f.isContract,
            nominalAreaHa = f.nominalAreaHa or 0,
            harvestedAreaHa = hArea,
            area = string.format("%.2f ha", (f.nominalAreaHa and f.nominalAreaHa > 0 and f.nominalAreaHa) or hArea),
            crop = cropDisplay,
            harvestedLiters = harvL,
            harvestedTons = harvT,
            harvested = (harvL > 0) and string.format("%.1f t (%.0f L)", harvT, harvL) or "--",
            yieldTha = yieldTha,
            yield = (yieldTha > 0) and string.format("%.2f t/ha", yieldTha) or "--",
            lostLiters = lostL,
            lostTons = (lostL > 0) and (lostL * 0.00075) or 0,
            lossPct = lossPct,
            loss = (bioVol > 0) and string.format("%.2f%%", lossPct) or "--",
            money = (money > 0) and moneyStr or "--",
            rawMoney = money,
            rank = rank,
            rankDisplay = (bioVol > 0) and string.format("[%s]", rank) or "--",
            operationsCount = f.operationsCount or 1,
            sessionDuration = f.sessionDuration or 0,
            dominantCauseText = fieldDominantText,
            reasons = f.reasons or {}
        })
    end

    -- Dominant Farm Crop
    local topCropName = "--"
    local topCropVol = 0
    for cName, cVol in pairs(cropTotals) do
        if cVol > topCropVol then
            topCropVol = cVol
            topCropName = cName
        end
    end
    if g_fillTypeManager and topCropName ~= "--" then
        local ft = g_fillTypeManager:getFillTypeByName(topCropName)
        if ft and ft.title and ft.title ~= "" then
            topCropName = ft.title
        end
    end

    -- Fallback active trip reasons if farm accumulated reasonSums are still empty
    local farmData = tracker:getFarmData(farmId)
    if (reasonSums.speed + reasonSums.moisture + reasonSums.wear + reasonSums.slope) <= 0.001 and farmData and farmData.currentTrip and farmData.currentTrip.reasons then
        reasonSums.speed = reasonSums.speed + (farmData.currentTrip.reasons.speed or 0)
        reasonSums.moisture = reasonSums.moisture + (farmData.currentTrip.reasons.moisture or 0)
        reasonSums.wear = reasonSums.wear + (farmData.currentTrip.reasons.wear or 0)
        reasonSums.slope = reasonSums.slope + (farmData.currentTrip.reasons.slope or 0)
    end

    local totalBioAll = totalHarvestL + totalLostL
    local overallLossPct = (totalBioAll > 0) and ((totalLostL / totalBioAll) * 100.0) or 0
    local overallHarvestTons = totalHarvestL * 0.00075
    local overallLostTons = totalLostL * 0.00075
    local overallYield = (totalHarvestedArea > 0.001) and (overallHarvestTons / totalHarvestedArea) or 0
    local overallRank = RHM_HarvestTracker.calculateEfficiencyRank(overallLossPct)

    local totalMoneyStr = "-$0"
    if g_i18n and g_i18n.formatMoney then
        totalMoneyStr = "-" .. g_i18n:formatMoney(totalMoney, nil, true, true)
    else
        totalMoneyStr = string.format("-$%.0f", totalMoney)
    end

    local farmDominantFactor = RHM_HarvestTracker.getDominantLossFactor(reasonSums)
    local farmReasonKey = "rhm_cause_" .. tostring(farmDominantFactor or "speed")
    if (totalLostL <= 0.001) and (reasonSums.speed + reasonSums.moisture + reasonSums.wear + reasonSums.slope <= 0.001) then
        farmReasonKey = "rhm_cause_none"
    end
    local farmDominantText = (g_i18n and g_i18n:hasText(farmReasonKey) and g_i18n:getText(farmReasonKey)) or farmDominantFactor or "Speed"

    -- ROW 1: Farm Overview Summary Row
    local overviewItem = {
        isOverview = true,
        field = g_i18n:getText("rhm_fields_all_overview") or "[*] Farm Overview",
        status = string.format("%d %s", totalOwnedCount, g_i18n:getText("rhm_fields_owned") or "Owned"),
        area = string.format("%.2f ha", (totalNominalArea > 0 and totalNominalArea) or totalHarvestedArea),
        crop = topCropName,
        harvested = (totalHarvestL > 0) and string.format("%.1f t", overallHarvestTons) or "--",
        yield = (overallYield > 0) and string.format("%.2f t/ha", overallYield) or "--",
        loss = (totalBioAll > 0) and string.format("%.2f%%", overallLossPct) or "--",
        money = (totalMoney > 0) and totalMoneyStr or "--",
        rank = (totalBioAll > 0) and string.format("[%s]", overallRank) or "--",
        rankDisplay = (totalBioAll > 0) and string.format("[%s]", overallRank) or "--",
        totalFieldsCount = #fieldList,
        totalOwnedCount = totalOwnedCount,
        totalContractCount = totalContractCount,
        totalNominalArea = totalNominalArea,
        totalHarvestedArea = totalHarvestedArea,
        covPct = (totalNominalArea > 0.001) and ((totalHarvestedArea / totalNominalArea) * 100.0) or 0,
        overallHarvestTons = overallHarvestTons,
        overallYield = overallYield,
        bestYieldField = bestYieldField,
        topCropName = topCropName,
        totalWorkSecs = totalWorkSecs,
        overallLostTons = overallLostTons,
        overallLossPct = overallLossPct,
        totalMoneyStr = totalMoneyStr,
        overallRank = overallRank,
        dominantCauseText = farmDominantText
    }

    table.insert(self.fieldsData, overviewItem)
    for _, item in ipairs(fieldItems) do
        table.insert(self.fieldsData, item)
    end

    if #self.fieldsData == 1 and #fieldList == 0 then
        table.insert(self.fieldsData, {
            isOverview = false,
            field = "--",
            status = "--",
            area = "--",
            crop = g_i18n:getText("rhm_fields_no_data") or "No Fields Recorded Yet",
            harvested = "--",
            yield = "--",
            loss = "--",
            money = "--",
            rank = "--",
            rankDisplay = "--"
        })
    end

    self.selectedIndex = self.selectedIndex or 1
    if self.selectedIndex > #self.fieldsData then
        self.selectedIndex = 1
    end

    self:updateSelectedCardData()

    if self.fieldsTable then
        self.fieldsTable:reloadData()
        if self.fieldsTable.setSelectedIndex then
            self.fieldsTable:setSelectedIndex(self.selectedIndex)
        end
    end
end

function RHM_HarvestHistoryFields:updateSelectedCardData()
    local entry = self.fieldsData[self.selectedIndex] or self.fieldsData[1]
    if not entry then return end

    if entry.isOverview then
        -- --------------------------------------------------------------------
        -- FARM OVERVIEW CARDS
        -- --------------------------------------------------------------------
        if self.fieldsSummaryTitle then
            self.fieldsSummaryTitle:setText(g_i18n:getText("rhm_tab_fields") or "FARM FIELDS OVERVIEW")
        end
        if self.fieldsSummaryCountText then
            local countStr = string.format("%d %s  |  %.2f ha", entry.totalFieldsCount or 0, g_i18n:getText("rhm_col_field") or "Fields", entry.totalNominalArea or 0)
            self.fieldsSummaryCountText:setText(countStr)
        end

        -- CARD 1: Land & Status
        if self.fieldSummaryCard1Title then self.fieldSummaryCard1Title:setText(g_i18n:getText("rhm_card_field_land") or "FARMLAND & PROGRESS") end
        if self.fieldSummaryLabel1_1 then self.fieldSummaryLabel1_1:setText(g_i18n:getText("rhm_fields_total_owned") or "Owned Fields") end
        if self.fieldSummaryOwnedCount then self.fieldSummaryOwnedCount:setText(tostring(entry.totalOwnedCount or 0)) end
        if self.fieldSummaryLabel1_2 then self.fieldSummaryLabel1_2:setText(g_i18n:getText("rhm_hist_total_area") or "Total Area") end
        if self.fieldSummaryTotalArea then self.fieldSummaryTotalArea:setText(string.format("%.2f ha", entry.totalNominalArea or 0)) end
        if self.fieldSummaryLabel1_3 then self.fieldSummaryLabel1_3:setText((g_i18n and g_i18n:hasText("rhm_fields_harvested_area") and g_i18n:getText("rhm_fields_harvested_area")) or "Harvested Area") end
        if self.fieldSummaryHarvestedArea then self.fieldSummaryHarvestedArea:setText(string.format("%.2f ha", entry.totalHarvestedArea or 0)) end
        if self.fieldSummaryLabel1_4 then self.fieldSummaryLabel1_4:setText(g_i18n:getText("rhm_contract_tag") or "Contract") end
        if self.fieldSummaryContractCount then self.fieldSummaryContractCount:setText(tostring(entry.totalContractCount or 0)) end
        if self.fieldSummaryLabel1_5 then self.fieldSummaryLabel1_5:setText(g_i18n:getText("rhm_col_status") or "Status") end
        if self.fieldSummaryProgressText then
            local displayCov = math.min(100.0, entry.covPct or 0)
            self.fieldSummaryProgressText:setText(string.format("%.1f%% %s", displayCov, g_i18n:getText("rhm_status_completed") or "Done"))
        end

        -- CARD 2: Production & Yield
        if self.fieldSummaryCard2Title then self.fieldSummaryCard2Title:setText(g_i18n:getText("rhm_card_field_yield") or "PRODUCTION & YIELD") end
        if self.fieldSummaryLabel2_1 then self.fieldSummaryLabel2_1:setText(g_i18n:getText("rhm_clean_harvest") or "Clean Harvest") end
        if self.fieldSummaryTotalHarvest then self.fieldSummaryTotalHarvest:setText(string.format("%.1f t", entry.overallHarvestTons or 0)) end
        if self.fieldSummaryLabel2_2 then self.fieldSummaryLabel2_2:setText(g_i18n:getText("rhm_col_yield") or "Average Yield") end
        if self.fieldSummaryAvgYield then self.fieldSummaryAvgYield:setText(string.format("%.2f t/ha", entry.overallYield or 0)) end
        if self.fieldSummaryLabel2_3 then self.fieldSummaryLabel2_3:setText(g_i18n:getText("rhm_fields_best_yield") or "Best Field") end
        if self.fieldSummaryBestField then self.fieldSummaryBestField:setText(entry.bestYieldField or "--") end
        if self.fieldSummaryLabel2_4 then self.fieldSummaryLabel2_4:setText(g_i18n:getText("rhm_kpi_crop") or "Dominant Crop") end
        if self.fieldSummaryTopCrop then self.fieldSummaryTopCrop:setText(entry.topCropName or "--") end
        if self.fieldSummaryLabel2_5 then self.fieldSummaryLabel2_5:setText(g_i18n:getText("rhm_session_duration") or "Total Duration") end
        local totalSecs = math.floor(entry.totalWorkSecs or 0)
        local hrs = math.floor(totalSecs / 3600)
        local mins = math.floor((totalSecs % 3600) / 60)
        if self.fieldSummaryWorkDuration then
            self.fieldSummaryWorkDuration:setText(string.format("%02d:%02d", hrs, mins))
        end

        -- CARD 3: Losses & Quality Grade
        if self.fieldSummaryCard3Title then self.fieldSummaryCard3Title:setText(g_i18n:getText("rhm_card_field_losses") or "LOSSES & QUALITY") end
        if self.fieldSummaryLabel3_1 then self.fieldSummaryLabel3_1:setText(g_i18n:getText("rhm_loss_volume") or "Loss Volume") end
        if self.fieldSummaryTotalLost then self.fieldSummaryTotalLost:setText(string.format("%.1f t", entry.overallLostTons or 0)) end
        if self.fieldSummaryLabel3_2 then self.fieldSummaryLabel3_2:setText(g_i18n:getText("rhm_loss_share") or "Loss Share") end
        if self.fieldSummaryAvgLossPct then self.fieldSummaryAvgLossPct:setText(string.format("%.2f%%", entry.overallLossPct or 0)) end
        if self.fieldSummaryLabel3_3 then self.fieldSummaryLabel3_3:setText(g_i18n:getText("rhm_financial_loss") or "Financial Losses") end
        if self.fieldSummaryTotalMoney then self.fieldSummaryTotalMoney:setText(entry.totalMoneyStr or "-$0") end
        if self.fieldSummaryLabel3_4 then self.fieldSummaryLabel3_4:setText(g_i18n:getText("rhm_efficiency_index") or "Efficiency Class") end
        if self.fieldSummaryEfficiencyRank then self.fieldSummaryEfficiencyRank:setText(string.format("[%s]", entry.overallRank or "A")) end
        if self.fieldSummaryLabel3_5 then self.fieldSummaryLabel3_5:setText(g_i18n:getText("rhm_causes_title") or "Crop Loss Cause") end
        if self.fieldSummaryDominantCause then
            self.fieldSummaryDominantCause:setText(entry.dominantCauseText or "--")
        end
    else
        -- --------------------------------------------------------------------
        -- FIELD-SPECIFIC CARDS
        -- --------------------------------------------------------------------
        if self.fieldsSummaryTitle then
            local titleText = string.format("%s  |  %s", entry.field or "--", entry.crop or "--")
            self.fieldsSummaryTitle:setText(titleText)
        end
        if self.fieldsSummaryCountText then
            local subText = string.format("%s  |  %.2f ha", entry.status or "--", entry.nominalAreaHa or 0)
            self.fieldsSummaryCountText:setText(subText)
        end

        -- CARD 1: Field Land & Status
        if self.fieldSummaryCard1Title then self.fieldSummaryCard1Title:setText(g_i18n:getText("rhm_card_field_land") or "FIELD & LAND") end
        if self.fieldSummaryLabel1_1 then self.fieldSummaryLabel1_1:setText(g_i18n:getText("rhm_col_field") or "Field Number") end
        if self.fieldSummaryOwnedCount then self.fieldSummaryOwnedCount:setText(tostring(entry.fieldId or entry.field or "--")) end
        if self.fieldSummaryLabel1_2 then self.fieldSummaryLabel1_2:setText(g_i18n:getText("rhm_fields_nominal_area") or "Nominal Area") end
        if self.fieldSummaryTotalArea then self.fieldSummaryTotalArea:setText(string.format("%.2f ha", entry.nominalAreaHa or 0)) end
        if self.fieldSummaryLabel1_3 then self.fieldSummaryLabel1_3:setText((g_i18n and g_i18n:hasText("rhm_fields_harvested_area") and g_i18n:getText("rhm_fields_harvested_area")) or "Harvested Area") end
        if self.fieldSummaryHarvestedArea then self.fieldSummaryHarvestedArea:setText(string.format("%.2f ha", entry.harvestedAreaHa or 0)) end
        if self.fieldSummaryLabel1_4 then self.fieldSummaryLabel1_4:setText(g_i18n:getText("rhm_col_status") or "Ownership") end
        if self.fieldSummaryContractCount then self.fieldSummaryContractCount:setText(entry.status or "--") end
        if self.fieldSummaryLabel1_5 then self.fieldSummaryLabel1_5:setText(g_i18n:getText("rhm_col_status") or "Status") end
        if self.fieldSummaryProgressText then
            local cov = (entry.nominalAreaHa and entry.nominalAreaHa > 0.001) and (((entry.harvestedAreaHa or 0) / entry.nominalAreaHa) * 100.0) or 0
            local displayPct = math.min(100.0, cov)
            local statusTxt = (displayPct >= 95.0 and (g_i18n:getText("rhm_status_completed") or "Done")) or (g_i18n:getText("rhm_status_in_progress") or "In Progress")
            self.fieldSummaryProgressText:setText(string.format("%.1f%% %s", displayPct, statusTxt))
        end

        -- CARD 2: Field Production & Yield
        if self.fieldSummaryCard2Title then self.fieldSummaryCard2Title:setText(g_i18n:getText("rhm_card_field_yield") or "PRODUCTION & YIELD") end
        if self.fieldSummaryLabel2_1 then self.fieldSummaryLabel2_1:setText(g_i18n:getText("rhm_clean_harvest") or "Clean Harvest") end
        if self.fieldSummaryTotalHarvest then
            self.fieldSummaryTotalHarvest:setText((entry.harvestedTons and entry.harvestedTons > 0 and string.format("%.1f t", entry.harvestedTons)) or "--")
        end
        if self.fieldSummaryLabel2_2 then self.fieldSummaryLabel2_2:setText(g_i18n:getText("rhm_col_yield") or "Average Yield") end
        if self.fieldSummaryAvgYield then
            self.fieldSummaryAvgYield:setText((entry.yieldTha and entry.yieldTha > 0 and string.format("%.2f t/ha", entry.yieldTha)) or "--")
        end
        if self.fieldSummaryLabel2_3 then self.fieldSummaryLabel2_3:setText(g_i18n:getText("rhm_field_operations") or "Operations") end
        local ops = entry.operationsCount or 0
        if ops <= 0 and ((entry.harvestedLiters and entry.harvestedLiters > 50) or (entry.harvestedAreaHa and entry.harvestedAreaHa > 0.01)) then
            ops = 1
        end

        local opsText = "--"
        if ops > 0 then
            local suffix = "ops"
            local mod10 = ops % 10
            local mod100 = ops % 100
            if mod10 == 1 and mod100 ~= 11 then
                suffix = (g_i18n and g_i18n:hasText("rhm_ops_one") and g_i18n:getText("rhm_ops_one")) or "ops"
            elseif mod10 >= 2 and mod10 <= 4 and (mod100 < 10 or mod100 >= 20) then
                suffix = (g_i18n and g_i18n:hasText("rhm_ops_few") and g_i18n:getText("rhm_ops_few")) or "ops"
            else
                suffix = (g_i18n and g_i18n:hasText("rhm_ops_many") and g_i18n:getText("rhm_ops_many")) or "ops"
            end
            opsText = string.format("%d %s", ops, suffix)
        end
        if self.fieldSummaryBestField then
            self.fieldSummaryBestField:setText(opsText)
        end
        if self.fieldSummaryLabel2_4 then self.fieldSummaryLabel2_4:setText(g_i18n:getText("rhm_kpi_crop") or "Crop") end
        if self.fieldSummaryTopCrop then self.fieldSummaryTopCrop:setText(entry.crop or "--") end
        if self.fieldSummaryLabel2_5 then self.fieldSummaryLabel2_5:setText(g_i18n:getText("rhm_session_duration") or "Field Duration") end
        local totalSecs = math.floor(entry.sessionDuration or 0)
        local hrs = math.floor(totalSecs / 3600)
        local mins = math.floor((totalSecs % 3600) / 60)
        if self.fieldSummaryWorkDuration then
            self.fieldSummaryWorkDuration:setText(string.format("%02d:%02d", hrs, mins))
        end

        -- CARD 3: Field Losses & Efficiency
        if self.fieldSummaryCard3Title then self.fieldSummaryCard3Title:setText(g_i18n:getText("rhm_card_field_losses") or "LOSSES & QUALITY") end
        if self.fieldSummaryLabel3_1 then self.fieldSummaryLabel3_1:setText(g_i18n:getText("rhm_loss_volume") or "Loss Volume") end
        if self.fieldSummaryTotalLost then
            self.fieldSummaryTotalLost:setText(string.format("%.1f t", entry.lostTons or 0))
        end
        if self.fieldSummaryLabel3_2 then self.fieldSummaryLabel3_2:setText(g_i18n:getText("rhm_loss_share") or "Loss Share") end
        if self.fieldSummaryAvgLossPct then
            self.fieldSummaryAvgLossPct:setText(string.format("%.2f%%", entry.lossPct or 0))
        end
        if self.fieldSummaryLabel3_3 then self.fieldSummaryLabel3_3:setText(g_i18n:getText("rhm_financial_loss") or "Financial Losses") end
        if self.fieldSummaryTotalMoney then
            self.fieldSummaryTotalMoney:setText(entry.money or "-$0")
        end
        if self.fieldSummaryLabel3_4 then self.fieldSummaryLabel3_4:setText(g_i18n:getText("rhm_efficiency_index") or "Efficiency Class") end
        if self.fieldSummaryEfficiencyRank then
            self.fieldSummaryEfficiencyRank:setText((entry.rank and string.format("[%s]", entry.rank)) or "[A]")
        end
        if self.fieldSummaryLabel3_5 then self.fieldSummaryLabel3_5:setText(g_i18n:getText("rhm_causes_title") or "Crop Loss Cause") end
        if self.fieldSummaryDominantCause then
            self.fieldSummaryDominantCause:setText(entry.dominantCauseText or "--")
        end
    end
end

-- ============================================================================
-- SmoothList DataSource & Delegate Callbacks
-- ============================================================================
function RHM_HarvestHistoryFields:getNumberOfSections()
    return 1
end

function RHM_HarvestHistoryFields:getNumberOfItemsInSection(list, section)
    return #self.fieldsData
end

function RHM_HarvestHistoryFields:getTitleForSectionHeader(list, section)
    return ""
end

function RHM_HarvestHistoryFields:onListSelectionChanged(list, section, index)
    if list == self.fieldsTable and index and index >= 1 and index <= #self.fieldsData then
        self.selectedIndex = index
        self:updateSelectedCardData()
    end
end

function RHM_HarvestHistoryFields:populateCellForItemInSection(list, section, index, cell)
    local item = self.fieldsData[index]
    if not item then return end

    local fElem = cell:getDescendantByName("colField")
    if fElem and fElem.setText then fElem:setText(item.field or "--") end

    local sElem = cell:getDescendantByName("colStatus")
    if sElem and sElem.setText then sElem:setText(item.status or "--") end

    local aElem = cell:getDescendantByName("colArea")
    if aElem and aElem.setText then aElem:setText(item.area or "--") end

    local cElem = cell:getDescendantByName("colCrop")
    if cElem and cElem.setText then cElem:setText(item.crop or "--") end

    local hElem = cell:getDescendantByName("colHarvested")
    if hElem and hElem.setText then hElem:setText(item.harvested or "--") end

    local yElem = cell:getDescendantByName("colYield")
    if yElem and yElem.setText then yElem:setText(item.yield or "--") end

    local lElem = cell:getDescendantByName("colLoss")
    if lElem and lElem.setText then lElem:setText(item.loss or "--") end

    local mElem = cell:getDescendantByName("colMoney")
    if mElem and mElem.setText then mElem:setText(item.money or "--") end

    local rElem = cell:getDescendantByName("colRank")
    if rElem and rElem.setText then rElem:setText(item.rankDisplay or item.rank or "--") end
end
