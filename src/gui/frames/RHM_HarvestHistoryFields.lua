-- ============================================================================
-- RHM_HarvestHistoryFields.lua
-- Realistic Harvesting Mod - Farm Fields & Harvest by Field Overview Frame
-- ============================================================================
-- Technical architecture:
--   Inherits from GIANTS Engine 10 TabbedMenuFrameElement.
--   Displays comprehensive field-level production, yields, and losses across
--   all farm-owned land and completed contract operations.
--   Supports Season Navigation (< > buttons) for All-Time and per-season views.
--   Supports interactive table row selection: clicking any field updates cards
--   to that field's exact telemetry, metrics, and dominant root loss cause.
--   Applies dynamic context-sensitive coloring to money, losses, wear, and rank.
-- ============================================================================

RHM_HarvestHistoryFields = {}
local HarvestHistoryFields_mt = Class(RHM_HarvestHistoryFields, TabbedMenuFrameElement)

local COLOR_PROFIT   = RHM_UIColors.GREEN
local COLOR_LOSS     = RHM_UIColors.RED
local COLOR_WARN     = RHM_UIColors.ORANGE
local COLOR_NEUTRAL  = RHM_UIColors.WHITE
local COLOR_DIM      = RHM_UIColors.GRAY
local COLOR_YELLOW   = RHM_UIColors.YELLOW
local COLOR_CYAN     = RHM_UIColors.CYAN

local function getLossColor(lossPct)
    return RHM_UIColors.getLossColor(lossPct)
end

local function getMoneyColor(rawMoney)
    return RHM_UIColors.getMoneyColor(rawMoney)
end

local function getRankColor(rank)
    return RHM_UIColors.getRankColor(rank)
end

local function safeL10n(key, fallback)
    if g_i18n and g_i18n.hasText and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end
    return fallback or ""
end

function RHM_HarvestHistoryFields.new(l18n)
    local self = TabbedMenuFrameElement.new(nil, HarvestHistoryFields_mt)
    self.l18n = l18n
    self.fieldsData = {}
    self.fieldsFilterMode = "all" -- "all" (default), "owned", "contract"
    self.selectedIndex = 1
    self.selectedSeasonIndex = nil
    self.seasonYearList = { "ALL" }
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
    if self.fieldsTable then
        self.fieldsTable:setDataSource(self)
        self.fieldsTable:setDelegate(self)
    end
end

function RHM_HarvestHistoryFields:updateFilterUI()
    local mode = self.fieldsFilterMode or "all"
    if self.btnFilterAll and self.btnFilterAll.applyProfile then
        self.btnFilterAll:applyProfile(mode == "all" and "rhmSubTabFilterActive" or "rhmSubTabFilter")
        if self.btnFilterAll.setSelected then
            self.btnFilterAll:setSelected(mode == "all")
        end
    end
    if self.btnFilterOwned and self.btnFilterOwned.applyProfile then
        self.btnFilterOwned:applyProfile(mode == "owned" and "rhmSubTabFilterActive" or "rhmSubTabFilter")
        if self.btnFilterOwned.setSelected then
            self.btnFilterOwned:setSelected(mode == "owned")
        end
    end
    if self.btnFilterContract and self.btnFilterContract.applyProfile then
        self.btnFilterContract:applyProfile(mode == "contract" and "rhmSubTabFilterActive" or "rhmSubTabFilter")
        if self.btnFilterContract.setSelected then
            self.btnFilterContract:setSelected(mode == "contract")
        end
    end
end

function RHM_HarvestHistoryFields:onClickFilterAll()
    if self.fieldsFilterMode == "all" then return end
    self.fieldsFilterMode = "all"
    self.selectedIndex = 1
    self:updateFilterUI()
    self:updateData()
end

function RHM_HarvestHistoryFields:onClickFilterOwned()
    if self.fieldsFilterMode == "owned" then return end
    self.fieldsFilterMode = "owned"
    self.selectedIndex = 1
    self:updateFilterUI()
    self:updateData()
end

function RHM_HarvestHistoryFields:onClickFilterContract()
    if self.fieldsFilterMode == "contract" then return end
    self.fieldsFilterMode = "contract"
    self.selectedIndex = 1
    self:updateFilterUI()
    self:updateData()
end

function RHM_HarvestHistoryFields:onFrameOpen()
    RHM_HarvestHistoryFields:superClass().onFrameOpen(self)
    self.selectedIndex = 1
    local currentYear = 1
    if g_currentMission and g_currentMission.environment and g_currentMission.environment.currentYear then
        currentYear = g_currentMission.environment.currentYear
    end
    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    local farmId = self:getFarmId()
    self.seasonYearList = (tracker and tracker.getAvailableYears and tracker:getAvailableYears(farmId)) or { currentYear, "ALL" }
    self.selectedSeasonIndex = 1
    for idx, y in ipairs(self.seasonYearList) do
        if tonumber(y) == currentYear then
            self.selectedSeasonIndex = idx
            break
        end
    end
    self:updateFilterUI()
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

function RHM_HarvestHistoryFields:onClickPrevSeason()
    if not self.seasonYearList or #self.seasonYearList <= 1 then return end
    self.selectedSeasonIndex = self.selectedSeasonIndex - 1
    if self.selectedSeasonIndex < 1 then
        self.selectedSeasonIndex = #self.seasonYearList
    end
    self.selectedIndex = 1
    self:updateData()
end

function RHM_HarvestHistoryFields:onClickNextSeason()
    if not self.seasonYearList or #self.seasonYearList <= 1 then return end
    self.selectedSeasonIndex = self.selectedSeasonIndex + 1
    if self.selectedSeasonIndex > #self.seasonYearList then
        self.selectedSeasonIndex = 1
    end
    self.selectedIndex = 1
    self:updateData()
end

function RHM_HarvestHistoryFields:updateData()
    local farmId = self:getFarmId()
    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if not tracker then return end

    local sys = (RHM_UnitConverter and RHM_UnitConverter.getActiveSystem and RHM_UnitConverter.getActiveSystem()) or 1
    local isLossEnabled = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableCropLoss)

    local currentYear = 1
    if g_currentMission and g_currentMission.environment and g_currentMission.environment.currentYear then
        currentYear = g_currentMission.environment.currentYear
    end

    self.seasonYearList = (tracker.getAvailableYears and tracker:getAvailableYears(farmId)) or { currentYear, "ALL" }

    if self.selectedSeasonIndex == nil or self.selectedSeasonIndex < 1 or self.selectedSeasonIndex > #self.seasonYearList then
        self.selectedSeasonIndex = 1
        for idx, y in ipairs(self.seasonYearList) do
            if tonumber(y) == currentYear then
                self.selectedSeasonIndex = idx
                break
            end
        end
    end

    local selectedYear = self.seasonYearList[self.selectedSeasonIndex]
    local isAllTime = (selectedYear == "ALL")
    self.fieldsData = {}

    local titleStr = ""
    if isAllTime then
        titleStr = string.format("[%d/%d]  %s", self.selectedSeasonIndex, #self.seasonYearList, safeL10n("rhm_season_all_time", "All Seasons (All-Time)"))
    else
        local suffix = (tonumber(selectedYear) == currentYear) and (" " .. safeL10n("rhm_season_current_suffix", "[Current]")) or ""
        local sName = string.format(safeL10n("rhm_season_format", "Season %d (Year %d)"), tonumber(selectedYear), tonumber(selectedYear))
        titleStr = string.format("[%d/%d]  %s%s", self.selectedSeasonIndex, #self.seasonYearList, sName, suffix)
    end
    self.currentTitleStr = titleStr

    if isAllTime then
        -- ====================================================================
        -- ALL-TIME VIEW (Aggregated farm-owned fields & all-time history)
        -- ====================================================================
        local fieldList = tracker:getFarmFields(farmId)
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

        local reasonSums = { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }
        local totalGrossRev = 0
        local totalFuelExp = 0
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
            local cropDensity = (RHM_UnitConverter and RHM_UnitConverter.getCropDensityTonsPerLiter and RHM_UnitConverter.getCropDensityTonsPerLiter(f.lastCrop or f.cropType)) or 0.00075
            local harvT = (f.harvestedMassKg and f.harvestedMassKg > 0) and (f.harvestedMassKg * 0.001) or (harvL * cropDensity)

            totalHarvestedArea = totalHarvestedArea + hArea
            totalHarvestL = totalHarvestL + harvL
            totalLostL = totalLostL + lostL
            totalMoney = totalMoney + money
            totalWorkSecs = totalWorkSecs + (f.sessionDuration or 0)

            totalGrossRev = totalGrossRev + (f.grossRevenue or 0)
            totalFuelExp = totalFuelExp + (f.fuelExpense or 0)

            if f.reasons then
                reasonSums.speed = reasonSums.speed + (f.reasons.speed or 0)
                reasonSums.settings = (reasonSums.settings or 0) + (f.reasons.settings or 0)
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

            local fieldName = string.format(safeL10n("rhm_field_format", "Field %d"), f.fieldId)
            if f.clusterMembers and #f.clusterMembers > 1 then
                local memberListStr = table.concat(f.clusterMembers, ", ")
                fieldName = string.format("%s (%s)", string.format(safeL10n("rhm_field_format", "Field %d"), f.fieldId), memberListStr)
            end
            if f.isContract then
                fieldName = fieldName .. " [" .. safeL10n("rhm_contract_tag", "Contract") .. "]"
            end

            local hasNominal = (f.nominalAreaHa and f.nominalAreaHa > 0.001)
            local cov = hasNominal and (((hArea or 0) / f.nominalAreaHa) * 100.0) or 0
            local displayCov = math.min(100.0, cov)
            local statusStr = ""
            local statusCode = "OWNED"
            if hasNominal and displayCov >= 95.0 then
                statusStr = string.format("%.0f%% [%s]", displayCov, safeL10n("rhm_status_completed", "Completed"))
                statusCode = "COMPLETED"
            elseif hasNominal and displayCov > 0.5 then
                statusStr = string.format("%.0f%% [%s]", displayCov, safeL10n("rhm_status_in_progress", "In Progress"))
                statusCode = "IN_PROGRESS"
            elseif (hArea or 0) > 0.001 then
                statusStr = string.format("%.1f%% [%s]", displayCov, safeL10n("rhm_status_in_progress", "In Progress"))
                statusCode = "IN_PROGRESS"
            elseif f.isContract then
                statusStr = safeL10n("rhm_fields_contract", "Contract")
                statusCode = "CONTRACT"
            elseif f.isOwned then
                statusStr = safeL10n("rhm_fields_owned", "Owned")
                statusCode = "OWNED"
            else
                statusStr = safeL10n("rhm_fields_external", "External")
                statusCode = "EXTERNAL"
            end

            local cropDisplay = f.lastCrop or "--"
            if g_fillTypeManager and cropDisplay ~= "--" and cropDisplay ~= "UNKNOWN" then
                local ft = g_fillTypeManager:getFillTypeByName(cropDisplay)
                if ft and ft.title and ft.title ~= "" then
                    cropDisplay = ft.title
                end
            end

            local netMarg = f.netMargin or ((f.grossRevenue or 0) - (f.fuelExpense or 0) - money)
            local moneyStr = "$0"
            if g_i18n and g_i18n.formatMoney then
                if netMarg >= 0 then
                    moneyStr = "+" .. g_i18n:formatMoney(netMarg, nil, true, true)
                else
                    moneyStr = "-" .. g_i18n:formatMoney(math.abs(netMarg), nil, true, true)
                end
            else
                moneyStr = string.format("%s$%.0f", (netMarg >= 0 and "+" or "-"), math.abs(netMarg))
            end

            local fieldDominant = RHM_HarvestTracker.getDominantLossFactor(f.reasons)
            local fieldReasonKey = "rhm_cause_" .. tostring(fieldDominant or "speed")
            local sumReasons = (f.reasons and (f.reasons.speed + (f.reasons.settings or 0) + f.reasons.moisture + f.reasons.wear + f.reasons.slope)) or 0
            if (not isLossEnabled) or (lostL <= 0.001 and sumReasons <= 0.001) then
                fieldReasonKey = "rhm_cause_none"
            end
            local fieldDominantText = (g_i18n and g_i18n:hasText(fieldReasonKey) and g_i18n:getText(fieldReasonKey)) or fieldDominant or "Speed"

            table.insert(fieldItems, {
                isOverview = false,
                fieldId = f.fieldId,
                clusterMembers = f.clusterMembers,
                field = fieldName,
                status = statusStr,
                statusCode = statusCode,
                isOwned = f.isOwned,
                isContract = f.isContract,
                nominalAreaHa = f.nominalAreaHa or 0,
                harvestedAreaHa = hArea,
                area = RHM_UnitConverter.formatArea((f.nominalAreaHa and f.nominalAreaHa > 0 and f.nominalAreaHa) or hArea, sys),
                crop = cropDisplay,
                harvestedLiters = harvL,
                harvestedTons = harvT,
                harvested = (harvL > 0) and string.format("%s (%.0f L)", RHM_UnitConverter.formatMass(harvT, sys), harvL) or "--",
                yieldTha = yieldTha,
                yield = (yieldTha > 0) and RHM_UnitConverter.formatYield(yieldTha, sys) or "--",
                lostLiters = isLossEnabled and lostL or 0,
                lostTons = (isLossEnabled and lostL > 0) and (lostL * cropDensity) or 0,
                lossPct = isLossEnabled and lossPct or 0,
                loss = isLossEnabled and ((bioVol > 0) and string.format("%.2f%%", lossPct) or "--") or "OFF",
                money = moneyStr,
                rawMoney = netMarg,
                lossMoney = money,
                grossRevenue = f.grossRevenue or 0,
                fuelExpense = f.fuelExpense or 0,
                fuelUsedL = f.fuelUsedL or 0,
                rank = isLossEnabled and rank or "A",
                rankDisplay = isLossEnabled and ((bioVol > 0) and string.format("[%s]", rank) or "--") or "[A]",
                operationsCount = f.operationsCount or 1,
                sessionDuration = f.sessionDuration or 0,
                dominantCauseText = fieldDominantText,
                reasons = f.reasons or {}
            })
        end

        local filteredItems = {}
        local fNominalArea = 0
        local fHarvestedArea = 0
        local fHarvestL = 0
        local fHarvestTons = 0
        local fLostL = 0
        local fLostTons = 0
        local fMoney = 0
        local fGrossRev = 0
        local fFuelExp = 0
        local fWorkSecs = 0
        local fBestYield = 0
        local fBestYieldField = "--"
        local fCropTotals = {}
        local fReasonSums = { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }

        for _, item in ipairs(fieldItems) do
            local match = true
            if self.fieldsFilterMode == "owned" then
                match = (item.isOwned == true) or (not item.isContract)
            elseif self.fieldsFilterMode == "contract" then
                match = (item.isContract == true)
            end
            if match then
                table.insert(filteredItems, item)
                fNominalArea = fNominalArea + (item.nominalAreaHa or 0)
                fHarvestedArea = fHarvestedArea + (item.harvestedAreaHa or 0)
                fHarvestL = fHarvestL + (item.harvestedLiters or 0)
                fHarvestTons = fHarvestTons + (item.harvestedTons or 0)
                fLostL = fLostL + (item.lostLiters or 0)
                fLostTons = fLostTons + (item.lostTons or 0)
                fMoney = fMoney + (item.lossMoney or 0)
                fGrossRev = fGrossRev + (item.grossRevenue or 0)
                fFuelExp = fFuelExp + (item.fuelExpense or 0)
                fWorkSecs = fWorkSecs + (item.sessionDuration or 0)
                if (item.yieldTha or 0) > fBestYield and (item.harvestedAreaHa or 0) >= 0.05 then
                    fBestYield = item.yieldTha
                    fBestYieldField = string.format("Field %d (%.1f t/ha)", item.fieldId or 0, item.yieldTha)
                end
                if item.crop and item.crop ~= "--" and (item.harvestedLiters or 0) > 0 then
                    fCropTotals[item.crop] = (fCropTotals[item.crop] or 0) + item.harvestedLiters
                end
                if item.reasons then
                    fReasonSums.speed = fReasonSums.speed + (item.reasons.speed or 0)
                    fReasonSums.settings = (fReasonSums.settings or 0) + (item.reasons.settings or 0)
                    fReasonSums.moisture = fReasonSums.moisture + (item.reasons.moisture or 0)
                    fReasonSums.wear = fReasonSums.wear + (item.reasons.wear or 0)
                    fReasonSums.slope = fReasonSums.slope + (item.reasons.slope or 0)
                end
            end
        end

        local topCropName = "--"
        local topCropVol = 0
        for cName, cVol in pairs(fCropTotals) do
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

        local totalBioAll = fHarvestL + fLostL
        local overallLossPct = (isLossEnabled and totalBioAll > 0) and ((fLostL / totalBioAll) * 100.0) or 0
        local overallHarvestTons = (fHarvestTons > 0 and fHarvestTons) or (fHarvestL * 0.00075)
        local overallLostTons = isLossEnabled and ((fLostTons > 0 and fLostTons) or (fLostL * 0.00075)) or 0
        local overallYield = (fHarvestedArea > 0.001) and (overallHarvestTons / fHarvestedArea) or 0
        local overallRank = isLossEnabled and RHM_HarvestTracker.calculateEfficiencyRank(overallLossPct) or "A"

        local totalNetMargin = fGrossRev - fFuelExp - (isLossEnabled and fMoney or 0)
        local totalMoneyStr = "$0"
        if g_i18n and g_i18n.formatMoney then
            if totalNetMargin >= 0 then
                totalMoneyStr = "+" .. g_i18n:formatMoney(totalNetMargin, nil, true, true)
            else
                totalMoneyStr = "-" .. g_i18n:formatMoney(math.abs(totalNetMargin), nil, true, true)
            end
        else
            totalMoneyStr = string.format("%s$%.0f", (totalNetMargin >= 0 and "+" or "-"), math.abs(totalNetMargin))
        end

        local farmDominantFactor = RHM_HarvestTracker.getDominantLossFactor(fReasonSums)
        local farmReasonKey = "rhm_cause_" .. tostring(farmDominantFactor or "speed")
        if (not isLossEnabled) or ((fLostL <= 0.001) and (fReasonSums.speed + (fReasonSums.settings or 0) + fReasonSums.moisture + fReasonSums.wear + fReasonSums.slope <= 0.001)) then
            farmReasonKey = "rhm_cause_none"
        end
        local farmDominantText = (g_i18n and g_i18n:hasText(farmReasonKey) and g_i18n:getText(farmReasonKey)) or farmDominantFactor or "Speed"

        local effectiveArea = (fNominalArea > 0 and fNominalArea) or fHarvestedArea
        local overviewTitle = safeL10n("rhm_fields_all_overview", "[*] Farm Overview")
        local overviewStatus = string.format("%d %s", #filteredItems, safeL10n("rhm_col_field", "Fields"))
        local headerCountStr = ""

        if self.fieldsFilterMode == "owned" then
            overviewTitle = "[*] " .. safeL10n("rhm_filter_owned", "Owned Fields") .. " " .. safeL10n("rhm_fields_all_overview", "Overview")
            overviewStatus = string.format("%d %s", #filteredItems, safeL10n("rhm_fields_owned", "Owned"))
            headerCountStr = string.format("%d %s  |  %s", #filteredItems, safeL10n("rhm_filter_owned", "Owned"), RHM_UnitConverter.formatArea(effectiveArea, sys))
        elseif self.fieldsFilterMode == "contract" then
            overviewTitle = "[*] " .. safeL10n("rhm_filter_contracts", "Contracts") .. " " .. safeL10n("rhm_fields_all_overview", "Overview")
            overviewStatus = string.format("%d %s", #filteredItems, safeL10n("rhm_fields_contract", "Contract"))
            headerCountStr = string.format("%d %s  |  %s", #filteredItems, safeL10n("rhm_filter_contracts", "Contracts"), RHM_UnitConverter.formatArea(effectiveArea, sys))
        else
            headerCountStr = string.format("%d %s (%d %s | %d %s)  |  %s", #filteredItems, safeL10n("rhm_col_field", "Fields"), totalOwnedCount, safeL10n("rhm_fields_owned", "Owned"), totalContractCount, safeL10n("rhm_fields_contract", "Contract"), RHM_UnitConverter.formatArea(effectiveArea, sys))
        end

        local overviewItem = {
            isOverview = true,
            field = overviewTitle,
            status = overviewStatus,
            statusCode = "OVERVIEW",
            area = RHM_UnitConverter.formatArea(effectiveArea, sys),
            crop = topCropName,
            harvested = (fHarvestL > 0) and RHM_UnitConverter.formatMass(overallHarvestTons, sys) or "--",
            yield = (overallYield > 0) and RHM_UnitConverter.formatYield(overallYield, sys) or "--",
            loss = isLossEnabled and ((totalBioAll > 0) and string.format("%.2f%%", overallLossPct) or "--") or "OFF",
            money = totalMoneyStr,
            rawMoney = totalNetMargin,
            grossRevenue = fGrossRev,
            fuelExpense = fFuelExp,
            netMargin = totalNetMargin,
            rank = isLossEnabled and ((totalBioAll > 0) and string.format("[%s]", overallRank) or "--") or "[A]",
            rankDisplay = isLossEnabled and ((totalBioAll > 0) and string.format("[%s]", overallRank) or "--") or "[A]",
            totalFieldsCount = #filteredItems,
            totalOwnedCount = (self.fieldsFilterMode == "contract" and 0) or (self.fieldsFilterMode == "owned" and #filteredItems) or totalOwnedCount,
            totalContractCount = (self.fieldsFilterMode == "owned" and 0) or (self.fieldsFilterMode == "contract" and #filteredItems) or totalContractCount,
            totalNominalArea = fNominalArea,
            totalHarvestedArea = fHarvestedArea,
            covPct = (fNominalArea > 0.001) and ((fHarvestedArea / fNominalArea) * 100.0) or 0,
            overallHarvestTons = overallHarvestTons,
            overallYield = overallYield,
            bestYieldField = fBestYieldField,
            topCropName = topCropName,
            totalWorkSecs = fWorkSecs,
            overallLostTons = overallLostTons,
            overallLossPct = overallLossPct,
            totalMoneyStr = totalMoneyStr,
            overallRank = overallRank,
            dominantCauseText = farmDominantText,
            customHeaderCount = headerCountStr
        }

        table.insert(self.fieldsData, overviewItem)
        for _, item in ipairs(filteredItems) do
            table.insert(self.fieldsData, item)
        end
    else
        -- ====================================================================
        -- SPECIFIC SEASON VIEW (Filtered field records for the chosen season)
        -- ====================================================================
        local farm = tracker:getFarmData(farmId)
        local rawHistory = (farm and farm.seasonHistory) or {}
        local numYear = tonumber(selectedYear) or 1
        local summary = tracker.getSeasonSummary and tracker:getSeasonSummary(farmId, numYear)

        local sHarvestL = 0
        local sLostL = 0
        local sAreaHa = 0
        local sMoney = 0
        local sGrossRev = 0
        local sFuelExp = 0
        local sWorkSecs = 0
        local sBestYield = 0
        local sBestField = "--"
        local sCropTotals = {}
        local sFieldItems = {}
        local sOwnedCount = 0
        local sContractCount = 0

        local aggregatedMap = {}
        local groupOrder = {}

        -- 1. Aggregate archived trips from seasonHistory for this season
        for _, rec in ipairs(rawHistory) do
            if rec.year == numYear and rec.fieldId and rec.fieldId > 0 then
                local fId = rec.fieldId
                local masterFid = (tracker and tracker.getMasterFieldId and tracker:getMasterFieldId(farmId, fId)) or fId
                local cName = rec.cropName or "--"
                local isContract = (rec.isContract == true)
                local groupKey = string.format("%d_%s_%s", masterFid, string.upper(tostring(cName)), isContract and "1" or "0")

                local area = rec.areaHa or 0
                local harvL = rec.harvested or 0
                local lostL = isLossEnabled and (rec.lost or 0) or 0
                local money = isLossEnabled and (rec.lossMoney or 0) or 0
                local cDensity = (RHM_UnitConverter and RHM_UnitConverter.getCropDensityTonsPerLiter and RHM_UnitConverter.getCropDensityTonsPerLiter(cName)) or 0.00075
                local harvT = (rec.harvestedMassKg and rec.harvestedMassKg > 0) and (rec.harvestedMassKg * 0.001) or (harvL * cDensity)
                local fuelUsed = rec.fuelUsed or (rec.fuelUsedL or 0)

                local pricePerLiter = 0.35
                if g_currentMission and g_currentMission.economyManager and cName ~= "--" and g_fillTypeManager then
                    local ftIdx = g_fillTypeManager:getFillTypeIndexByName(cName)
                    if ftIdx and ftIdx ~= FillType.UNKNOWN and g_currentMission.economyManager.getPricePerLiter then
                        pricePerLiter = g_currentMission.economyManager:getPricePerLiter(ftIdx) or pricePerLiter
                    end
                end

                local fieldGross = harvL * pricePerLiter
                local fieldFuel = (fuelUsed > 0 and fuelUsed or (area * 18.0)) * 1.45

                if not aggregatedMap[groupKey] then
                    aggregatedMap[groupKey] = {
                        fieldId = masterFid,
                        cropName = cName,
                        isContract = isContract,
                        harvestedLiters = 0,
                        harvestedMassKg = 0,
                        harvestedTons = 0,
                        harvestedAreaHa = 0,
                        lostLiters = 0,
                        lossMoney = 0,
                        fuelUsedL = 0,
                        grossRevenue = 0,
                        fuelExpense = 0,
                        sessionDuration = 0,
                        operationsCount = 0,
                        reasons = { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }
                    }
                    table.insert(groupOrder, groupKey)
                end

                local agg = aggregatedMap[groupKey]
                agg.harvestedLiters = agg.harvestedLiters + harvL
                agg.harvestedMassKg = agg.harvestedMassKg + ((rec.harvestedMassKg and rec.harvestedMassKg > 0) and rec.harvestedMassKg or (harvT * 1000.0))
                agg.harvestedTons = agg.harvestedTons + harvT
                agg.harvestedAreaHa = agg.harvestedAreaHa + area
                agg.lostLiters = agg.lostLiters + lostL
                agg.lossMoney = agg.lossMoney + money
                agg.fuelUsedL = agg.fuelUsedL + fuelUsed
                agg.grossRevenue = agg.grossRevenue + fieldGross
                agg.fuelExpense = agg.fuelExpense + fieldFuel
                agg.sessionDuration = agg.sessionDuration + (rec.sessionDuration or 0)
                agg.operationsCount = agg.operationsCount + 1

                if rec.dominantReason then
                    local rk = tostring(rec.dominantReason)
                    if agg.reasons[rk] ~= nil then
                        agg.reasons[rk] = agg.reasons[rk] + lostL
                    else
                        agg.reasons.speed = agg.reasons.speed + lostL
                    end
                end
            end
        end

        -- 2. Merge active in-progress fields & cumulative stats from farm.fieldStats for current season
        if numYear == currentYear and farm and farm.fieldStats then
            for fId, fStat in pairs(farm.fieldStats) do
                local statYear = fStat.lastYear or currentYear
                if statYear == numYear then
                    local masterFid = (tracker and tracker.getMasterFieldId and tracker:getMasterFieldId(farmId, fId)) or fId
                    local cName = fStat.lastCropName or fStat.lastCrop or "--"
                    local isContract = (fStat.isContract == true) or RHM_HarvestTracker.isContractField(masterFid, farmId)
                    local groupKey = string.format("%d_%s_%s", masterFid, string.upper(tostring(cName)), isContract and "1" or "0")

                    local area = fStat.harvestedAreaHa or 0
                    local harvL = fStat.harvestedLiters or 0
                    local lostL = isLossEnabled and (fStat.lostLiters or 0) or 0
                    local money = isLossEnabled and (fStat.lossMoney or 0) or 0
                    local cDensity = (RHM_UnitConverter and RHM_UnitConverter.getCropDensityTonsPerLiter and RHM_UnitConverter.getCropDensityTonsPerLiter(cName)) or 0.00075
                    local harvT = (fStat.harvestedMassKg and fStat.harvestedMassKg > 0) and (fStat.harvestedMassKg * 0.001) or (harvL * cDensity)
                    local fuelUsed = fStat.fuelUsedL or (area * 18.0)

                    local pricePerLiter = 0.35
                    if g_currentMission and g_currentMission.economyManager and cName ~= "--" and g_fillTypeManager then
                        local ftIdx = g_fillTypeManager:getFillTypeIndexByName(cName)
                        if ftIdx and ftIdx ~= FillType.UNKNOWN and g_currentMission.economyManager.getPricePerLiter then
                            pricePerLiter = g_currentMission.economyManager:getPricePerLiter(ftIdx) or pricePerLiter
                        end
                    end
                    local fieldGross = harvL * pricePerLiter
                    local fieldFuel = (fuelUsed > 0 and fuelUsed or (area * 18.0)) * 1.45

                    -- Check if field is currently being actively harvested right now
                    local isActivelyWorking = (farm.currentTrip and farm.currentTrip.fieldId == fId and farm.currentTrip.isActive)

                    -- Threshold: owned/contract fields or active machines show immediately (> 0 L);
                    -- unowned stray plots require > 50 L to filter roadside grass cuts
                    local isOwned = not isContract
                    if g_fieldManager and g_fieldManager.getFieldById and g_farmlandManager and g_farmlandManager.getFarmlandOwner then
                        local fObj = g_fieldManager:getFieldById(fId)
                        local fmlId = (fObj and fObj.getFarmland and fObj:getFarmland() and fObj:getFarmland().id) or (fObj and fObj.farmlandId) or fId
                        if fmlId and fmlId > 0 then
                            local owner = g_farmlandManager:getFarmlandOwner(fmlId)
                            if owner and owner ~= 0 then
                                isOwned = (owner == farmId)
                            end
                        end
                    end

                    local shouldInclude = (isOwned or isContract or isActivelyWorking or harvL > 50 or area > 0.05)
                                          and (harvL > 0 or area > 0 or isActivelyWorking)

                    if aggregatedMap[groupKey] then
                        -- Field + Crop was already partially archived in seasonHistory;
                        -- fStat contains the running cumulative total (including archived trips + active harvest).
                        local agg = aggregatedMap[groupKey]
                        agg._fromFieldStats = true
                        if harvL > agg.harvestedLiters or area > agg.harvestedAreaHa then
                            agg.harvestedLiters = harvL
                            agg.harvestedMassKg = (fStat.harvestedMassKg and fStat.harvestedMassKg > 0) and fStat.harvestedMassKg or (harvT * 1000.0)
                            agg.harvestedTons = harvT
                            agg.harvestedAreaHa = area
                            agg.lostLiters = lostL
                            agg.lossMoney = money
                            agg.fuelUsedL = fuelUsed
                            agg.grossRevenue = fieldGross
                            agg.fuelExpense = fieldFuel
                            agg.sessionDuration = math.max(agg.sessionDuration, fStat.sessionDuration or 0)
                            agg.operationsCount = math.max(agg.operationsCount, fStat.operationsCount or 1)
                            if fStat.reasons then
                                agg.reasons = fStat.reasons
                            end
                        else
                            agg.operationsCount = math.max(agg.operationsCount, fStat.operationsCount or 1)
                        end
                    elseif shouldInclude then
                        -- Field is active in current season but has not yet been archived to seasonHistory (e.g. Field 6)
                        aggregatedMap[groupKey] = {
                            _fromFieldStats = true,
                            fieldId = fId,
                            cropName = cName,
                            isContract = isContract,
                            harvestedLiters = harvL,
                            harvestedMassKg = (fStat.harvestedMassKg and fStat.harvestedMassKg > 0) and fStat.harvestedMassKg or (harvT * 1000.0),
                            harvestedTons = harvT,
                            harvestedAreaHa = area,
                            lostLiters = lostL,
                            lossMoney = money,
                            fuelUsedL = fuelUsed,
                            grossRevenue = fieldGross,
                            fuelExpense = fieldFuel,
                            sessionDuration = fStat.sessionDuration or 0,
                            operationsCount = math.max(1, fStat.operationsCount or 0),
                            reasons = fStat.reasons or { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }
                        }
                        table.insert(groupOrder, groupKey)
                    end
                end
            end
        end


        -- 3. Construct formatted list items for each aggregated field & crop
        local seenUniqueFields = {}
        for _, groupKey in ipairs(groupOrder) do
            local agg = aggregatedMap[groupKey]
            if agg then
                local fId = agg.fieldId
                local cName = agg.cropName or "--"
                local isContract = agg.isContract
                local area = agg.harvestedAreaHa
                local harvL = agg.harvestedLiters
                local lostL = agg.lostLiters
                local money = agg.lossMoney
                local harvT = agg.harvestedTons
                local yieldTha = (area > 0.001) and (harvT / area) or 0

                local bioVol = harvL + lostL
                local lossPct = (bioVol > 0) and ((lostL / bioVol) * 100.0) or 0
                local rk = RHM_HarvestTracker.calculateEfficiencyRank(lossPct)

                local masterId = (tracker and tracker.getMasterFieldId and tracker:getMasterFieldId(farmId, fId)) or fId
                local members = (tracker and tracker.getClusterMembers and tracker:getClusterMembers(farmId, masterId)) or nil
                local fieldLabel = string.format(safeL10n("rhm_field_format", "Field %d"), masterId)
                if members and #members > 1 then
                    local memberListStr = table.concat(members, ", ")
                    fieldLabel = string.format("%s (%s)", string.format(safeL10n("rhm_field_format", "Field %d"), masterId), memberListStr)
                end
                if isContract then
                    fieldLabel = fieldLabel .. " [" .. safeL10n("rhm_contract_tag", "Contract") .. "]"
                end

                local cropDisplay = cName
                if g_fillTypeManager and cName ~= "--" and cName ~= "UNKNOWN" then
                    local ft = g_fillTypeManager:getFillTypeByName(cName)
                    if ft and ft.title and ft.title ~= "" then
                        cropDisplay = ft.title
                    end
                end
                if cropDisplay == cName and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
                    cropDisplay = RHM_CombineSettingsDatabase:getCropDisplayName(cName)
                end

                local netMarg = agg.grossRevenue - agg.fuelExpense - money
                local moneyStr = "$0"
                if g_i18n and g_i18n.formatMoney then
                    if netMarg >= 0 then
                        moneyStr = "+" .. g_i18n:formatMoney(netMarg, nil, true, true)
                    else
                        moneyStr = "-" .. g_i18n:formatMoney(math.abs(netMarg), nil, true, true)
                    end
                else
                    moneyStr = string.format("%s$%.0f", (netMarg >= 0 and "+" or "-"), math.abs(netMarg))
                end

                local dominantFactor = RHM_HarvestTracker.getDominantLossFactor(agg.reasons)
                local reasonKey = "rhm_cause_" .. tostring(dominantFactor or "speed")
                if (not isLossEnabled) or (lostL <= 0.001) then
                    reasonKey = "rhm_cause_none"
                end
                local dominantText = (g_i18n and g_i18n:hasText(reasonKey) and g_i18n:getText(reasonKey)) or dominantFactor or "Speed"

                local nominalArea = (RHM_HarvestTracker and RHM_HarvestTracker.getFieldNominalAreaHa and RHM_HarvestTracker.getFieldNominalAreaHa(masterId, nil, nil, farmId)) or area
                if not nominalArea or nominalArea <= 0.001 then
                    nominalArea = area
                end

                local hasNominal = (nominalArea and nominalArea > 0.001)
                local cov = hasNominal and ((area / nominalArea) * 100.0) or 0
                local displayCov = math.min(100.0, cov)
                local statusStr = ""
                local statusCode = "COMPLETED"
                if numYear == currentYear then
                    if hasNominal and displayCov >= 95.0 then
                        statusStr = string.format("%.0f%% [%s]", displayCov, safeL10n("rhm_status_completed", "Completed"))
                        statusCode = "COMPLETED"
                    elseif hasNominal and displayCov > 0.5 then
                        statusStr = string.format("%.0f%% [%s]", displayCov, safeL10n("rhm_status_in_progress", "In Progress"))
                        statusCode = "IN_PROGRESS"
                    elseif area > 0.001 then
                        statusStr = string.format("%.1f%% [%s]", displayCov, safeL10n("rhm_status_in_progress", "In Progress"))
                        statusCode = "IN_PROGRESS"
                    else
                        statusStr = isContract and safeL10n("rhm_fields_contract", "Contract") or safeL10n("rhm_fields_owned", "Owned")
                        statusCode = isContract and "CONTRACT" or "OWNED"
                    end
                else
                    if isContract then
                        statusStr = safeL10n("rhm_status_completed", "Completed")
                        statusCode = "COMPLETED"
                    elseif hasNominal and displayCov >= 95.0 then
                        statusStr = string.format("%.0f%% [%s]", displayCov, safeL10n("rhm_status_completed", "Completed"))
                        statusCode = "COMPLETED"
                    else
                        statusStr = safeL10n("rhm_status_completed", "Completed")
                        statusCode = "COMPLETED"
                    end
                end

                if not seenUniqueFields[masterId] then
                    seenUniqueFields[masterId] = true
                    if isContract then
                        sContractCount = sContractCount + 1
                    else
                        sOwnedCount = sOwnedCount + 1
                    end
                end

                table.insert(sFieldItems, {
                    isOverview = false,
                    fieldId = masterId,
                    clusterMembers = members,
                    field = fieldLabel,
                    status = statusStr,
                    statusCode = statusCode,
                    isOwned = not isContract,
                    isContract = isContract,
                    nominalAreaHa = nominalArea,
                    harvestedAreaHa = area,
                    area = RHM_UnitConverter.formatArea((nominalArea > 0 and nominalArea) or area, sys),
                    crop = cropDisplay,
                    rawCrop = cName,
                    harvestedLiters = harvL,
                    harvestedTons = harvT,
                    harvested = (harvL > 0) and string.format("%s (%.0f L)", RHM_UnitConverter.formatMass(harvT, sys), harvL) or "--",
                    yieldTha = yieldTha,
                    yield = (yieldTha > 0) and RHM_UnitConverter.formatYield(yieldTha, sys) or "--",
                    lostLiters = isLossEnabled and lostL or 0,
                    lostTons = (isLossEnabled and lostL > 0) and (lostL * (RHM_UnitConverter and RHM_UnitConverter.getCropDensityTonsPerLiter and RHM_UnitConverter.getCropDensityTonsPerLiter(cName) or 0.00075)) or 0,
                    lossPct = isLossEnabled and lossPct or 0,
                    loss = isLossEnabled and ((bioVol > 0) and string.format("%.2f%%", lossPct) or "--") or "OFF",
                    money = moneyStr,
                    rawMoney = netMarg,
                    lossMoney = money,
                    grossRevenue = agg.grossRevenue or 0,
                    fuelExpense = agg.fuelExpense or 0,
                    fuelUsedL = agg.fuelUsedL or 0,
                    rank = rk,
                    rankDisplay = string.format("[%s]", rk),
                    operationsCount = agg.operationsCount or 1,
                    sessionDuration = agg.sessionDuration or 0,
                    dominantCauseText = dominantText,
                    reasons = agg.reasons
                })
            end
        end

        table.sort(sFieldItems, function(a, b)
            if (a.fieldId or 0) ~= (b.fieldId or 0) then
                return (a.fieldId or 0) < (b.fieldId or 0)
            end
            return tostring(a.crop) < tostring(b.crop)
        end)

        local farmAllFields = (tracker.getFarmFields and tracker:getFarmFields(farmId)) or {}
        local farmTotalOwnedCount = 0
        local farmTotalOwnedArea = 0
        for _, f in ipairs(farmAllFields) do
            if f.isOwned then
                farmTotalOwnedCount = farmTotalOwnedCount + 1
                farmTotalOwnedArea = farmTotalOwnedArea + (f.nominalAreaHa or 0)
            end
        end

        local filteredItems = {}
        local fNominalArea = 0
        local fHarvestedArea = 0
        local fHarvestL = 0
        local fHarvTons = 0
        local fLostL = 0
        local fLostTons = 0
        local fMoney = 0
        local fGrossRev = 0
        local fFuelExp = 0
        local fWorkSecs = 0
        local fBestYield = 0
        local fBestField = "--"
        local fCropTotals = {}
        local seenNominalFields = {}

        for _, item in ipairs(sFieldItems) do
            local match = true
            if self.fieldsFilterMode == "owned" then
                match = (item.isOwned == true) or (not item.isContract)
            elseif self.fieldsFilterMode == "contract" then
                match = (item.isContract == true)
            end
            if match then
                table.insert(filteredItems, item)
                if item.fieldId and not seenNominalFields[item.fieldId] then
                    seenNominalFields[item.fieldId] = true
                    fNominalArea = fNominalArea + (item.nominalAreaHa or 0)
                end
                fHarvestedArea = fHarvestedArea + (item.harvestedAreaHa or 0)
                fHarvestL = fHarvestL + (item.harvestedLiters or 0)
                fHarvTons = fHarvTons + (item.harvestedTons or 0)
                fLostL = fLostL + (item.lostLiters or 0)
                fLostTons = fLostTons + (item.lostTons or 0)
                fMoney = fMoney + (item.lossMoney or 0)
                fGrossRev = fGrossRev + (item.grossRevenue or 0)
                fFuelExp = fFuelExp + (item.fuelExpense or 0)
                fWorkSecs = fWorkSecs + (item.sessionDuration or 0)
                if (item.yieldTha or 0) > fBestYield and (item.harvestedAreaHa or 0) >= 0.05 then
                    fBestYield = item.yieldTha
                    fBestField = string.format("Field %d (%.1f t/ha)", item.fieldId or 0, item.yieldTha)
                end
                if item.crop and item.crop ~= "--" and (item.harvestedLiters or 0) > 0 then
                    fCropTotals[item.crop] = (fCropTotals[item.crop] or 0) + item.harvestedLiters
                end
            end
        end

        local topCropName = "--"
        local topCropVol = 0
        for cName, cVol in pairs(fCropTotals) do
            if cVol > topCropVol then
                topCropVol = cVol
                topCropName = cName
            end
        end
        if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName and topCropName ~= "--" then
            topCropName = RHM_CombineSettingsDatabase:getCropDisplayName(topCropName)
        end

        local fTotalBio = fHarvestL + fLostL
        local fOverallLossPct = (isLossEnabled and fTotalBio > 0) and ((fLostL / fTotalBio) * 100.0) or 0
        local fOverallHarvTons = (fHarvTons > 0 and fHarvTons) or (fHarvestL * 0.00075)
        local fOverallLostTons = isLossEnabled and ((fLostTons > 0 and fLostTons) or (fLostL * 0.00075)) or 0
        local fOverallYield = (fHarvestedArea > 0.001) and (fOverallHarvTons / fHarvestedArea) or 0
        local fOverallRank = isLossEnabled and RHM_HarvestTracker.calculateEfficiencyRank(fOverallLossPct) or "A"

        local fNetMargin = fGrossRev - fFuelExp - (isLossEnabled and fMoney or 0)
        local sMoneyStr = "$0"
        if g_i18n and g_i18n.formatMoney then
            if fNetMargin >= 0 then
                sMoneyStr = "+" .. g_i18n:formatMoney(fNetMargin, nil, true, true)
            else
                sMoneyStr = "-" .. g_i18n:formatMoney(math.abs(fNetMargin), nil, true, true)
            end
        else
            sMoneyStr = string.format("%s$%.0f", (fNetMargin >= 0 and "+" or "-"), math.abs(fNetMargin))
        end

        local seasonDominant = (summary and summary.dominantReason) or "speed"
        local sReasonKey = "rhm_cause_" .. tostring(seasonDominant)
        if (not isLossEnabled) or (fLostL <= 0.001) then
            sReasonKey = "rhm_cause_none"
        end
        local sDominantText = (g_i18n and g_i18n:hasText(sReasonKey) and g_i18n:getText(sReasonKey)) or seasonDominant

        local totalFarmNominalArea = fNominalArea
        local totalFarmOwnedCount = sOwnedCount
        if numYear == currentYear and farmTotalOwnedArea > 0 then
            if self.fieldsFilterMode == "owned" or self.fieldsFilterMode == "all" then
                totalFarmNominalArea = math.max(fNominalArea, farmTotalOwnedArea)
                totalFarmOwnedCount = math.max(sOwnedCount, farmTotalOwnedCount)
            end
        end

        local effectiveArea = (totalFarmNominalArea > 0 and totalFarmNominalArea) or fHarvestedArea
        local overviewTitle = string.format("[*] Season %d Overview", numYear)
        local overviewStatus = string.format("%d %s", #filteredItems, safeL10n("rhm_col_field", "Fields"))
        local headerCountStr = ""

        if self.fieldsFilterMode == "owned" then
            overviewTitle = string.format("[*] S%d %s", numYear, safeL10n("rhm_filter_owned", "Owned Fields"))
            overviewStatus = string.format("%d %s", #filteredItems, safeL10n("rhm_fields_owned", "Owned"))
            headerCountStr = string.format("%d %s  |  %s", #filteredItems, safeL10n("rhm_filter_owned", "Owned"), RHM_UnitConverter.formatArea(effectiveArea, sys))
        elseif self.fieldsFilterMode == "contract" then
            overviewTitle = string.format("[*] S%d %s", numYear, safeL10n("rhm_filter_contracts", "Contracts"))
            overviewStatus = string.format("%d %s", #filteredItems, safeL10n("rhm_fields_contract", "Contract"))
            headerCountStr = string.format("%d %s  |  %s", #filteredItems, safeL10n("rhm_filter_contracts", "Contracts"), RHM_UnitConverter.formatArea(effectiveArea, sys))
        else
            headerCountStr = string.format("%d %s (%d %s | %d %s)  |  %s", #filteredItems, safeL10n("rhm_col_field", "Fields"), totalFarmOwnedCount, safeL10n("rhm_fields_owned", "Owned"), sContractCount, safeL10n("rhm_fields_contract", "Contract"), RHM_UnitConverter.formatArea(effectiveArea, sys))
        end

        local covPct = (totalFarmNominalArea > 0.001) and ((fHarvestedArea / totalFarmNominalArea) * 100.0) or 0
        if numYear < currentYear and fHarvestedArea >= (totalFarmNominalArea * 0.95) then
            covPct = 100.0
        end

        local seasonOverviewItem = {
            isOverview = true,
            field = overviewTitle,
            status = overviewStatus,
            statusCode = "OVERVIEW",
            area = RHM_UnitConverter.formatArea(effectiveArea, sys),
            crop = topCropName,
            harvested = (fHarvestL > 0) and RHM_UnitConverter.formatMass(fOverallHarvTons, sys) or "--",
            yield = (fOverallYield > 0) and RHM_UnitConverter.formatYield(fOverallYield, sys) or "--",
            loss = isLossEnabled and ((fTotalBio > 0) and string.format("%.2f%%", fOverallLossPct) or "--") or "OFF",
            money = sMoneyStr,
            rawMoney = fNetMargin,
            grossRevenue = fGrossRev,
            fuelExpense = fFuelExp,
            netMargin = fNetMargin,
            rank = string.format("[%s]", fOverallRank),
            rankDisplay = string.format("[%s]", fRank or fOverallRank),
            totalFieldsCount = #filteredItems,
            totalOwnedCount = (self.fieldsFilterMode == "contract" and 0) or totalFarmOwnedCount,
            totalContractCount = (self.fieldsFilterMode == "owned" and 0) or (self.fieldsFilterMode == "contract" and #filteredItems) or sContractCount,
            totalNominalArea = totalFarmNominalArea,
            totalHarvestedArea = fHarvestedArea,
            covPct = covPct,
            overallHarvestTons = fOverallHarvTons,
            overallYield = fOverallYield,
            bestYieldField = fBestField,
            topCropName = topCropName,
            totalWorkSecs = (fWorkSecs > 0 and fWorkSecs) or ((summary and summary.sessionDuration) or 0),
            overallLostTons = fOverallLostTons,
            overallLossPct = fOverallLossPct,
            totalMoneyStr = sMoneyStr,
            overallRank = fOverallRank,
            dominantCauseText = sDominantText,
            customHeaderCount = headerCountStr
        }

        table.insert(self.fieldsData, seasonOverviewItem)
        for _, item in ipairs(filteredItems) do
            table.insert(self.fieldsData, item)
        end

        if RHM_DiagnosticTool and RHM_DiagnosticTool.logFieldsRender then
            RHM_DiagnosticTool:logFieldsRender(numYear, filteredItems, fHarvestedArea, fOverallHarvTons, fNetMargin, topCropName, fBestField)
        end
    end

    if #self.fieldsData == 1 then
        table.insert(self.fieldsData, {
            isOverview = false,
            field = "--",
            status = "--",
            area = "--",
            crop = safeL10n("rhm_fields_no_data", "No Field Operations Recorded"),
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

    local sys = (RHM_UnitConverter and RHM_UnitConverter.getActiveSystem and RHM_UnitConverter.getActiveSystem()) or 1
    local isLossEnabled = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableCropLoss)

    if entry.isOverview then
        -- --------------------------------------------------------------------
        -- OVERVIEW CARDS (Season Total or Farm-Wide Total)
        -- --------------------------------------------------------------------
        if self.fieldsSummaryTitle then
            self.fieldsSummaryTitle:setText(self.currentTitleStr or g_i18n:getText("rhm_tab_fields") or "FARM FIELDS OVERVIEW")
        end
        if self.fieldsSummaryCountText then
            local countStr = entry.customHeaderCount or string.format("%d %s  |  %s", entry.totalFieldsCount or 0, g_i18n:getText("rhm_col_field") or "Fields", RHM_UnitConverter.formatArea(entry.totalNominalArea or entry.totalHarvestedArea or 0, sys))
            self.fieldsSummaryCountText:setText(countStr)
        end

        -- CARD 1: Farmland & Progress
        if self.fieldSummaryCard1Title then self.fieldSummaryCard1Title:setText(safeL10n("rhm_card_field_land", "FARMLAND & PROGRESS")) end
        if self.fieldSummaryLabel1_1 then self.fieldSummaryLabel1_1:setText(safeL10n("rhm_fields_total_owned", "Owned Fields")) end
        if self.fieldSummaryOwnedCount then self.fieldSummaryOwnedCount:setText(tostring(entry.totalOwnedCount or 0)) end
        if self.fieldSummaryLabel1_2 then self.fieldSummaryLabel1_2:setText(safeL10n("rhm_hist_total_area", "Total Area")) end
        if self.fieldSummaryTotalArea then self.fieldSummaryTotalArea:setText(RHM_UnitConverter.formatArea(entry.totalNominalArea or 0, sys)) end
        if self.fieldSummaryLabel1_3 then self.fieldSummaryLabel1_3:setText(safeL10n("rhm_col_area", "Harvested Area")) end
        if self.fieldSummaryHarvestedArea then self.fieldSummaryHarvestedArea:setText(RHM_UnitConverter.formatArea(entry.totalHarvestedArea or 0, sys)) end
        if self.fieldSummaryLabel1_4 then self.fieldSummaryLabel1_4:setText(safeL10n("rhm_contract_tag", "Contract")) end
        if self.fieldSummaryContractCount then self.fieldSummaryContractCount:setText(tostring(entry.totalContractCount or 0)) end
        if self.fieldSummaryLabel1_5 then self.fieldSummaryLabel1_5:setText(safeL10n("rhm_field_progress", "Harvest Progress")) end
        if self.fieldSummaryProgressText then
            local displayCov = math.min(100.0, entry.covPct or 0)
            local isDone = (displayCov >= 95.0)
            local statusTxt = isDone and safeL10n("rhm_status_completed", "Completed") or safeL10n("rhm_status_in_progress", "In Progress")
            self.fieldSummaryProgressText:setText(string.format("%.1f%% [%s]", displayCov, statusTxt))
            if self.fieldSummaryProgressText.setTextColor then
                if isDone then
                    self.fieldSummaryProgressText:setTextColor(COLOR_PROFIT[1], COLOR_PROFIT[2], COLOR_PROFIT[3], 1.0)
                elseif displayCov > 0.5 then
                    self.fieldSummaryProgressText:setTextColor(COLOR_YELLOW[1], COLOR_YELLOW[2], COLOR_YELLOW[3], 1.0)
                else
                    self.fieldSummaryProgressText:setTextColor(COLOR_NEUTRAL[1], COLOR_NEUTRAL[2], COLOR_NEUTRAL[3], 1.0)
                end
            end
        end

        -- CARD 2: Production & Yield
        if self.fieldSummaryCard2Title then self.fieldSummaryCard2Title:setText(safeL10n("rhm_card_field_yield", "PRODUCTION & YIELD")) end
        if self.fieldSummaryLabel2_1 then self.fieldSummaryLabel2_1:setText(safeL10n("rhm_clean_harvest", "Clean Harvest")) end
        if self.fieldSummaryTotalHarvest then self.fieldSummaryTotalHarvest:setText(RHM_UnitConverter.formatMass(entry.overallHarvestTons or 0, sys)) end
        if self.fieldSummaryLabel2_2 then self.fieldSummaryLabel2_2:setText(safeL10n("rhm_average_yield", "Average Yield")) end
        if self.fieldSummaryAvgYield then self.fieldSummaryAvgYield:setText(RHM_UnitConverter.formatYield(entry.overallYield or 0, sys)) end
        if self.fieldSummaryLabel2_3 then self.fieldSummaryLabel2_3:setText(safeL10n("rhm_fields_best_yield", "Best Field")) end
        if self.fieldSummaryBestField then self.fieldSummaryBestField:setText(entry.bestYieldField or "--") end
        if self.fieldSummaryLabel2_4 then self.fieldSummaryLabel2_4:setText(safeL10n("rhm_kpi_crop", "Dominant Crop")) end
        if self.fieldSummaryTopCrop then self.fieldSummaryTopCrop:setText(entry.topCropName or "--") end
        if self.fieldSummaryLabel2_5 then self.fieldSummaryLabel2_5:setText(safeL10n("rhm_session_duration", "Session Duration")) end
        local totalSecs = math.floor(entry.totalWorkSecs or 0)
        local hrs = math.floor(totalSecs / 3600)
        local mins = math.floor((totalSecs % 3600) / 60)
        if self.fieldSummaryWorkDuration then
            self.fieldSummaryWorkDuration:setText(string.format("%02d:%02d", hrs, mins))
        end

        -- CARD 3: Losses & Economic Ledger
        if self.fieldSummaryCard3Title then self.fieldSummaryCard3Title:setText(g_i18n:getText("rhm_card_field_losses") or "LOSSES & QUALITY") end
        if self.fieldSummaryLabel3_1 then self.fieldSummaryLabel3_1:setText(g_i18n:getText("rhm_loss_volume") or "Loss Volume") end
        if self.fieldSummaryTotalLost then
            if isLossEnabled then
                self.fieldSummaryTotalLost:setText(RHM_UnitConverter.formatMass(entry.overallLostTons or 0, sys))
                if self.fieldSummaryTotalLost.setTextColor then
                    local col = getLossColor(entry.overallLossPct or 0)
                    self.fieldSummaryTotalLost:setTextColor(col[1], col[2], col[3], col[4])
                end
            else
                self.fieldSummaryTotalLost:setText("--")
                if self.fieldSummaryTotalLost.setTextColor then
                    self.fieldSummaryTotalLost:setTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3], 1.0)
                end
            end
        end
        if self.fieldSummaryLabel3_2 then self.fieldSummaryLabel3_2:setText(g_i18n:getText("rhm_loss_share") or "Loss Share") end
        if self.fieldSummaryAvgLossPct then
            if isLossEnabled then
                self.fieldSummaryAvgLossPct:setText(string.format("%.2f%%", entry.overallLossPct or 0))
                if self.fieldSummaryAvgLossPct.setTextColor then
                    local col = getLossColor(entry.overallLossPct or 0)
                    self.fieldSummaryAvgLossPct:setTextColor(col[1], col[2], col[3], col[4])
                end
            else
                self.fieldSummaryAvgLossPct:setText("OFF")
                if self.fieldSummaryAvgLossPct.setTextColor then
                    self.fieldSummaryAvgLossPct:setTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3], 1.0)
                end
            end
        end
        if self.fieldSummaryLabel3_3 then self.fieldSummaryLabel3_3:setText(safeL10n("rhm_net_margin", "Net Operating Margin")) end
        if self.fieldSummaryTotalMoney then
            self.fieldSummaryTotalMoney:setText(entry.money or "$0")
            if self.fieldSummaryTotalMoney.setTextColor then
                local col = getMoneyColor(entry.rawMoney)
                self.fieldSummaryTotalMoney:setTextColor(col[1], col[2], col[3], col[4])
            end
        end
        if self.fieldSummaryLabel3_4 then self.fieldSummaryLabel3_4:setText(g_i18n:getText("rhm_efficiency_index") or "Efficiency Class") end
        if self.fieldSummaryEfficiencyRank then
            local rk = isLossEnabled and (entry.overallRank or "A") or "A"
            local cleanR = tostring(rk):gsub("%[", ""):gsub("%]", "")
            self.fieldSummaryEfficiencyRank:setText(string.format("[%s]", cleanR))
            if self.fieldSummaryEfficiencyRank.setTextColor then
                local col = getRankColor(cleanR)
                self.fieldSummaryEfficiencyRank:setTextColor(col[1], col[2], col[3], col[4])
            end
        end
        if self.fieldSummaryLabel3_5 then self.fieldSummaryLabel3_5:setText(g_i18n:getText("rhm_causes_title") or "Crop Loss Cause") end
        if self.fieldSummaryDominantCause then
            local causeTxt = entry.dominantCauseText or "--"
            self.fieldSummaryDominantCause:setText(causeTxt)
            if self.fieldSummaryDominantCause.setTextColor then
                if causeTxt == "--" or causeTxt == "None" or not isLossEnabled then
                    self.fieldSummaryDominantCause:setTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3], 1.0)
                else
                    self.fieldSummaryDominantCause:setTextColor(COLOR_WARN[1], COLOR_WARN[2], COLOR_WARN[3], 1.0)
                end
            end
        end
    else
        -- --------------------------------------------------------------------
        -- FIELD-SPECIFIC CARDS (Selected field breakdown)
        -- --------------------------------------------------------------------
        if self.fieldsSummaryTitle then
            self.fieldsSummaryTitle:setText(self.currentTitleStr or "--")
        end
        if self.fieldsSummaryCountText then
            local subText = string.format("%s  |  %s", entry.field or "--", entry.status or "--")
            self.fieldsSummaryCountText:setText(subText)
        end

        -- CARD 1: Field Land & Status
        if self.fieldSummaryCard1Title then
            local cardTitle = string.format("%s  |  %s", entry.field or "FIELD", entry.crop or "--")
            self.fieldSummaryCard1Title:setText(cardTitle)
        end
        if self.fieldSummaryLabel1_1 then self.fieldSummaryLabel1_1:setText(safeL10n("rhm_col_field", "Field Number")) end
        if self.fieldSummaryOwnedCount then
            local fieldNumStr = tostring(entry.fieldId or entry.field or "--")
            if entry.clusterMembers and #entry.clusterMembers > 1 then
                fieldNumStr = string.format("%d (%s)", entry.fieldId, table.concat(entry.clusterMembers, ", "))
            end
            self.fieldSummaryOwnedCount:setText(fieldNumStr)
            if self.fieldSummaryOwnedCount.setTextSize then
                self.fieldSummaryOwnedCount:setTextSize((#fieldNumStr > 10) and 15 or 24)
            end
        end
        if self.fieldSummaryLabel1_2 then self.fieldSummaryLabel1_2:setText(safeL10n("rhm_fields_nominal_area", "Nominal Area")) end
        if self.fieldSummaryTotalArea then self.fieldSummaryTotalArea:setText(RHM_UnitConverter.formatArea(entry.nominalAreaHa or 0, sys)) end
        if self.fieldSummaryLabel1_3 then self.fieldSummaryLabel1_3:setText(safeL10n("rhm_fields_harvested_area", "Harvested Area")) end
        if self.fieldSummaryHarvestedArea then self.fieldSummaryHarvestedArea:setText(RHM_UnitConverter.formatArea(entry.harvestedAreaHa or 0, sys)) end
        if self.fieldSummaryLabel1_4 then self.fieldSummaryLabel1_4:setText(safeL10n("rhm_fields_total_owned", "Ownership")) end
        if self.fieldSummaryContractCount then
            local ownershipStr = entry.isContract and safeL10n("rhm_fields_contract", "Contract") or safeL10n("rhm_fields_owned", "Owned")
            self.fieldSummaryContractCount:setText(ownershipStr)
        end
        if self.fieldSummaryLabel1_5 then self.fieldSummaryLabel1_5:setText(safeL10n("rhm_field_progress", "Harvest Progress")) end
        if self.fieldSummaryProgressText then
            local cov = (entry.nominalAreaHa and entry.nominalAreaHa > 0.001) and (((entry.harvestedAreaHa or 0) / entry.nominalAreaHa) * 100.0) or 0
            local displayPct = math.min(100.0, cov)
            local isCompleted = (entry.statusCode == "COMPLETED")
            local statusTxt = isCompleted and safeL10n("rhm_status_completed", "Completed") or safeL10n("rhm_status_in_progress", "In Progress")
            self.fieldSummaryProgressText:setText(string.format("%.1f%% [%s]", displayPct, statusTxt))
            if self.fieldSummaryProgressText.setTextColor then
                if isCompleted then
                    self.fieldSummaryProgressText:setTextColor(COLOR_PROFIT[1], COLOR_PROFIT[2], COLOR_PROFIT[3], 1.0)
                elseif displayPct < 0.5 then
                    self.fieldSummaryProgressText:setTextColor(COLOR_NEUTRAL[1], COLOR_NEUTRAL[2], COLOR_NEUTRAL[3], 1.0)
                else
                    self.fieldSummaryProgressText:setTextColor(COLOR_YELLOW[1], COLOR_YELLOW[2], COLOR_YELLOW[3], 1.0)
                end
            end
        end

        -- CARD 2: Field Production & Yield
        if self.fieldSummaryCard2Title then self.fieldSummaryCard2Title:setText(g_i18n:getText("rhm_card_field_yield") or "PRODUCTION & YIELD") end
        if self.fieldSummaryLabel2_1 then self.fieldSummaryLabel2_1:setText(g_i18n:getText("rhm_clean_harvest") or "Clean Harvest") end
        if self.fieldSummaryTotalHarvest then
            self.fieldSummaryTotalHarvest:setText((entry.harvestedTons and entry.harvestedTons > 0 and RHM_UnitConverter.formatMass(entry.harvestedTons, sys)) or "--")
        end
        if self.fieldSummaryLabel2_2 then self.fieldSummaryLabel2_2:setText(g_i18n:getText("rhm_col_yield") or "Average Yield") end
        if self.fieldSummaryAvgYield then
            self.fieldSummaryAvgYield:setText((entry.yieldTha and entry.yieldTha > 0 and RHM_UnitConverter.formatYield(entry.yieldTha, sys)) or "--")
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
            if isLossEnabled then
                self.fieldSummaryTotalLost:setText(RHM_UnitConverter.formatMass(entry.lostTons or 0, sys))
                if self.fieldSummaryTotalLost.setTextColor then
                    local col = getLossColor(entry.lossPct or 0)
                    self.fieldSummaryTotalLost:setTextColor(col[1], col[2], col[3], col[4])
                end
            else
                self.fieldSummaryTotalLost:setText("--")
                if self.fieldSummaryTotalLost.setTextColor then
                    self.fieldSummaryTotalLost:setTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3], 1.0)
                end
            end
        end
        if self.fieldSummaryLabel3_2 then self.fieldSummaryLabel3_2:setText(g_i18n:getText("rhm_loss_share") or "Loss Share") end
        if self.fieldSummaryAvgLossPct then
            if isLossEnabled then
                self.fieldSummaryAvgLossPct:setText(string.format("%.2f%%", entry.lossPct or 0))
                if self.fieldSummaryAvgLossPct.setTextColor then
                    local col = getLossColor(entry.lossPct or 0)
                    self.fieldSummaryAvgLossPct:setTextColor(col[1], col[2], col[3], col[4])
                end
            else
                self.fieldSummaryAvgLossPct:setText("OFF")
                if self.fieldSummaryAvgLossPct.setTextColor then
                    self.fieldSummaryAvgLossPct:setTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3], 1.0)
                end
            end
        end
        if self.fieldSummaryLabel3_3 then self.fieldSummaryLabel3_3:setText(safeL10n("rhm_net_margin", "Net Operating Margin")) end
        if self.fieldSummaryTotalMoney then
            self.fieldSummaryTotalMoney:setText(entry.money or "$0")
            if self.fieldSummaryTotalMoney.setTextColor then
                local col = getMoneyColor(entry.rawMoney)
                self.fieldSummaryTotalMoney:setTextColor(col[1], col[2], col[3], col[4])
            end
        end
        if self.fieldSummaryLabel3_4 then self.fieldSummaryLabel3_4:setText(g_i18n:getText("rhm_efficiency_index") or "Efficiency Class") end
        if self.fieldSummaryEfficiencyRank then
            local rk = isLossEnabled and (entry.rank or "A") or "A"
            local cleanR = tostring(rk):gsub("%[", ""):gsub("%]", "")
            self.fieldSummaryEfficiencyRank:setText(string.format("[%s]", cleanR))
            if self.fieldSummaryEfficiencyRank.setTextColor then
                local col = getRankColor(cleanR)
                self.fieldSummaryEfficiencyRank:setTextColor(col[1], col[2], col[3], col[4])
            end
        end
        if self.fieldSummaryLabel3_5 then self.fieldSummaryLabel3_5:setText(g_i18n:getText("rhm_causes_title") or "Crop Loss Cause") end
        if self.fieldSummaryDominantCause then
            local causeTxt = entry.dominantCauseText or "--"
            self.fieldSummaryDominantCause:setText(causeTxt)
            if self.fieldSummaryDominantCause.setTextColor then
                if causeTxt == "--" or causeTxt == "None" or not isLossEnabled then
                    self.fieldSummaryDominantCause:setTextColor(COLOR_DIM[1], COLOR_DIM[2], COLOR_DIM[3], 1.0)
                else
                    self.fieldSummaryDominantCause:setTextColor(COLOR_WARN[1], COLOR_WARN[2], COLOR_WARN[3], 1.0)
                end
            end
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

function RHM_HarvestHistoryFields:onClickListItem(list, section, index, cell)
    local idx = index
    if not idx and type(section) == "number" then idx = section end
    if not idx and type(list) == "number" then idx = list end
    if idx and idx >= 1 and idx <= #self.fieldsData then
        self.selectedIndex = idx
        self:updateSelectedCardData()
    end
end

function RHM_HarvestHistoryFields:onListSelectionChanged(list, section, index)
    local idx = index
    if not idx and type(section) == "number" then idx = section end
    if not idx and type(list) == "number" then idx = list end
    if idx and idx >= 1 and idx <= #self.fieldsData then
        self.selectedIndex = idx
        self:updateSelectedCardData()
    end
end

function RHM_HarvestHistoryFields:populateCellForItemInSection(list, section, index, cell)
    local item = self.fieldsData[index]
    if not item then return end

    local fElem = cell:getDescendantByName("colField")
    if fElem and fElem.setText then
        fElem:setText(item.field or "--")
        if fElem.setTextSize then
            fElem:setTextSize((item.clusterMembers and #item.clusterMembers > 1) and 12 or 14)
        end
    end

    local sElem = cell:getDescendantByName("colStatus")
    if sElem and sElem.setText then
        sElem:setText(item.status or "--")
        RHM_UIColors.applyTextColor(sElem, RHM_UIColors.getStatusColor(item.statusCode))
    end

    local aElem = cell:getDescendantByName("colArea")
    if aElem and aElem.setText then aElem:setText(item.area or "--") end

    local cElem = cell:getDescendantByName("colCrop")
    if cElem and cElem.setText then cElem:setText(item.crop or "--") end

    local hElem = cell:getDescendantByName("colHarvested")
    if hElem and hElem.setText then hElem:setText(item.harvested or "--") end

    local yElem = cell:getDescendantByName("colYield")
    if yElem and yElem.setText then yElem:setText(item.yield or "--") end

    local lElem = cell:getDescendantByName("colLoss")
    if lElem and lElem.setText then
        lElem:setText(item.loss or "--")
        if lElem.setTextColor then
            local col = getLossColor(item.lossPct)
            lElem:setTextColor(col[1], col[2], col[3], col[4])
        end
    end

    local mElem = cell:getDescendantByName("colMoney")
    if mElem and mElem.setText then
        mElem:setText(item.money or "--")
        if mElem.setTextColor then
            local col = getMoneyColor(item.rawMoney)
            mElem:setTextColor(col[1], col[2], col[3], col[4])
        end
    end

    local rElem = cell:getDescendantByName("colRank")
    if rElem and rElem.setText then
        rElem:setText(item.rankDisplay or item.rank or "--")
        if rElem.setTextColor then
            local col = getRankColor(item.rank)
            rElem:setTextColor(col[1], col[2], col[3], col[4])
        end
    end
end
