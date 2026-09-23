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
    self:updateData()
end

function RHM_HarvestHistoryTrip:onFrameClose()
    RHM_HarvestHistoryTrip:superClass().onFrameClose(self)
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
            return trip, activeCombine, farmId
        end
    end

    -- 2. If player is not in a combine, check if there is an active combine in the fleet
    if farm and farm.combineTrips then
        for machineKey, mTrip in pairs(farm.combineTrips) do
            if mTrip.isActive or (mTrip.sessionDuration and mTrip.sessionDuration > 0) then
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
    if fieldId == 0 and activeCombine and activeCombine.rootNode then
        pcall(function()
            local wx, _, wz = getWorldTranslation(activeCombine.rootNode)
            if g_fieldManager then
                local field = (g_fieldManager.getFieldAtWorldPosition and g_fieldManager:getFieldAtWorldPosition(wx, wz))
                           or (g_fieldManager.getFieldByWorldPosition and g_fieldManager:getFieldByWorldPosition(wx, wz))
                if field and (field.fieldId or field.id) then
                    fieldId = field.fieldId or field.id
                end
            end
            if fieldId == 0 and g_farmlandManager and g_farmlandManager.getFarmlandIdAtWorldPosition then
                local fid = g_farmlandManager:getFarmlandIdAtWorldPosition(wx, wz)
                if fid and fid > 0 then
                    fieldId = fid
                end
            end
        end)
    end

    local fieldStr = fieldId > 0 and tostring(fieldId) or (g_i18n and g_i18n:getText("rhm_trip_no_field") or "--")
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
    if self.fieldNumberText then self.fieldNumberText:setText(fieldStr) end
    if self.cropTypeText then self.cropTypeText:setText(cropStr) end

    -- Harvested Area & Volume
    local areaHa = trip.harvestedAreaHa or 0
    local harvestedL = trip.harvestedLiters or 0
    local harvestedTons = (trip.harvestedMassKg or 0) / 1000.0
    if self.harvestedAreaText then self.harvestedAreaText:setText(string.format("%.2f ha", areaHa)) end
    if self.harvestedVolumeText then
        self.harvestedVolumeText:setText(string.format("%.1f t  (%.0f L)", harvestedTons, harvestedL))
    end

    -- Average Yield
    local avgYield = (areaHa > 0.01) and (harvestedTons / areaHa) or 0
    if self.avgYieldText then self.avgYieldText:setText(string.format("%.2f t/ha", avgYield)) end

    -- Losses & Finances
    local lostL = trip.lostLiters or 0
    local lostTons = 0
    if trip.harvestedLiters and trip.harvestedLiters > 0 then
        lostTons = (lostL / trip.harvestedLiters) * harvestedTons
    end
    local totalBio = harvestedL + lostL
    local lossPct = (totalBio > 0) and ((lostL / totalBio) * 100.0) or 0

    if self.lossVolumeText then self.lossVolumeText:setText(string.format("%.1f t  (%.0f L)", lostTons, lostL)) end
    if self.lossPercentText then self.lossPercentText:setText(string.format("%.2f%%", lossPct)) end

    local moneyVal = trip.lossMoney or 0
    local moneyStr = "-$0"
    if g_i18n and g_i18n.formatMoney then
        moneyStr = "-" .. g_i18n:formatMoney(moneyVal, nil, true, true)
    else
        moneyStr = string.format("-$%.0f", moneyVal)
    end
    if self.lossMoneyText then self.lossMoneyText:setText(moneyStr) end

    -- Efficiency Rank
    local rank = trip.efficiencyRank or "A"
    local rankColor = {0.55, 0.72, 0.0, 1.0}
    if rank == "B" then rankColor = {0.80, 0.85, 0.20, 1.0}
    elseif rank == "C" then rankColor = {1.0, 0.60, 0.0, 1.0}
    elseif rank == "D" then rankColor = {0.95, 0.25, 0.20, 1.0}
    end
    if self.efficiencyRankBadge then self.efficiencyRankBadge:setText(string.format("[%s]", rank)) end

    local rankKey = "rhm_trip_rank_" .. string.lower(rank)
    local rankDesc = (g_i18n and g_i18n:hasText(rankKey)) and g_i18n:getText(rankKey) or rank
    if self.efficiencyRankDesc then self.efficiencyRankDesc:setText(rankDesc) end

    -- Averages & Duration
    local avgSpeed = (trip.avgSpeedCount and trip.avgSpeedCount > 0) and (trip.avgSpeedSum / trip.avgSpeedCount) or 0
    local avgLoad = (trip.avgLoadCount and trip.avgLoadCount > 0) and ((trip.avgLoadSum / trip.avgLoadCount) * 100.0) or 0
    local durSec = trip.sessionDuration or 0
    local durMin = math.floor(durSec / 60)
    local durSecRem = math.floor(durSec % 60)

    if self.avgSpeedText then self.avgSpeedText:setText(string.format("%.1f km/h", avgSpeed)) end
    if self.avgLoadText then self.avgLoadText:setText(string.format("%.0f%%", avgLoad)) end
    if self.sessionDurationText then self.sessionDurationText:setText(string.format("%02d:%02d", durMin, durSecRem)) end

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
