-- ============================================================================
-- RHM_HarvestHistoryFields.lua
-- Realistic Harvesting Mod - Farm Fields & Harvest by Field Overview Frame
-- ============================================================================
-- Technical architecture:
--   Inherits from GIANTS Engine 10 TabbedMenuFrameElement.
--   Displays comprehensive field-level production, yields, and losses across
--   all farm-owned land and completed contract operations.
-- ============================================================================

RHM_HarvestHistoryFields = {}
local HarvestHistoryFields_mt = Class(RHM_HarvestHistoryFields, TabbedMenuFrameElement)

function RHM_HarvestHistoryFields.new(l18n)
    local self = TabbedMenuFrameElement.new(nil, HarvestHistoryFields_mt)
    self.l18n = l18n
    self.fieldsData = {}
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
        local statusStr = f.isOwned and (g_i18n:getText("rhm_fields_owned") or "Owned") or (g_i18n:getText("rhm_fields_contract") or "Contract")
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

        table.insert(self.fieldsData, {
            field = fieldName,
            status = statusStr,
            area = string.format("%.2f ha", (hArea > 0 and hArea) or (f.nominalAreaHa or 0)),
            crop = cropDisplay,
            harvested = (harvL > 0) and string.format("%.1f t (%.0f L)", harvT, harvL) or "--",
            yield = (yieldTha > 0) and string.format("%.2f t/ha", yieldTha) or "--",
            loss = (bioVol > 0) and string.format("%.2f%%", lossPct) or "--",
            money = (money > 0) and moneyStr or "--",
            rank = (bioVol > 0) and string.format("[%s]", rank) or "--"
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

    local totalBioAll = totalHarvestL + totalLostL
    local overallLossPct = (totalBioAll > 0) and ((totalLostL / totalBioAll) * 100.0) or 0
    local overallHarvestTons = totalHarvestL * 0.00075
    local overallLostTons = totalLostL * 0.00075
    local overallYield = (totalHarvestedArea > 0.001) and (overallHarvestTons / totalHarvestedArea) or 0
    local overallRank = RHM_HarvestTracker.calculateEfficiencyRank(overallLossPct)

    -- Header Title & Count
    local totalFieldsCount = #fieldList
    if self.fieldsSummaryTitle then
        self.fieldsSummaryTitle:setText(g_i18n:getText("rhm_tab_fields") or "FARM FIELDS OVERVIEW")
    end
    if self.fieldsSummaryCountText then
        local countStr = string.format("%d %s  |  %.2f ha", totalFieldsCount, g_i18n:getText("rhm_col_field") or "Fields", totalNominalArea)
        self.fieldsSummaryCountText:setText(countStr)
    end

    -- CARD 1: Land & Status
    if self.fieldSummaryOwnedCount then self.fieldSummaryOwnedCount:setText(tostring(totalOwnedCount)) end
    if self.fieldSummaryTotalArea then self.fieldSummaryTotalArea:setText(string.format("%.2f ha", totalNominalArea)) end
    if self.fieldSummaryHarvestedArea then self.fieldSummaryHarvestedArea:setText(string.format("%.2f ha", totalHarvestedArea)) end
    if self.fieldSummaryContractCount then self.fieldSummaryContractCount:setText(tostring(totalContractCount)) end
    if self.fieldSummaryProgressText then
        local covPct = (totalNominalArea > 0.001) and ((totalHarvestedArea / totalNominalArea) * 100.0) or 0
        self.fieldSummaryProgressText:setText(string.format("%.1f%% %s", covPct, g_i18n:getText("rhm_status_completed") or "Done"))
    end

    -- CARD 2: Production & Yield
    if self.fieldSummaryTotalHarvest then self.fieldSummaryTotalHarvest:setText(string.format("%.1f t", overallHarvestTons)) end
    if self.fieldSummaryAvgYield then self.fieldSummaryAvgYield:setText(string.format("%.2f t/ha", overallYield)) end
    if self.fieldSummaryBestField then self.fieldSummaryBestField:setText(bestYieldField) end
    if self.fieldSummaryTopCrop then self.fieldSummaryTopCrop:setText(topCropName) end

    local totalSecs = math.floor(totalWorkSecs)
    local hrs = math.floor(totalSecs / 3600)
    local mins = math.floor((totalSecs % 3600) / 60)
    if self.fieldSummaryWorkDuration then
        self.fieldSummaryWorkDuration:setText(string.format("%02d:%02d", hrs, mins))
    end

    -- CARD 3: Losses & Quality Grade
    if self.fieldSummaryTotalLost then self.fieldSummaryTotalLost:setText(string.format("%.1f t", overallLostTons)) end
    if self.fieldSummaryAvgLossPct then self.fieldSummaryAvgLossPct:setText(string.format("%.2f%%", overallLossPct)) end

    local totalMoneyStr = "-$0"
    if g_i18n and g_i18n.formatMoney then
        totalMoneyStr = "-" .. g_i18n:formatMoney(totalMoney, nil, true, true)
    else
        totalMoneyStr = string.format("-$%.0f", totalMoney)
    end
    if self.fieldSummaryTotalMoney then self.fieldSummaryTotalMoney:setText(totalMoneyStr) end
    if self.fieldSummaryEfficiencyRank then self.fieldSummaryEfficiencyRank:setText(string.format("[%s]", overallRank)) end
    if self.fieldSummaryDominantCause then
        local rKey = "rhm_cause_speed"
        self.fieldSummaryDominantCause:setText((g_i18n and g_i18n:hasText(rKey) and g_i18n:getText(rKey)) or "Speed")
    end

    if #self.fieldsData == 0 then
        table.insert(self.fieldsData, {
            field = "--",
            status = "--",
            area = "--",
            crop = g_i18n:getText("rhm_fields_no_data") or "No Fields Recorded Yet",
            harvested = "--",
            yield = "--",
            loss = "--",
            money = "--",
            rank = "--"
        })
    end

    if self.fieldsTable then
        self.fieldsTable:reloadData()
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
    if rElem and rElem.setText then rElem:setText(item.rank or "--") end
end
