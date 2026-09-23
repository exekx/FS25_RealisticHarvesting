-- ============================================================================
-- RHM_HarvestHistoryFleet.lua
-- Realistic Harvesting Mod - Combine Fleet Telemetry & Season History Frame
-- ============================================================================

RHM_HarvestHistoryFleet = {}
local HarvestHistoryFleet_mt = Class(RHM_HarvestHistoryFleet, TabbedMenuFrameElement)

function RHM_HarvestHistoryFleet.new(l18n)
    local self = TabbedMenuFrameElement.new(nil, HarvestHistoryFleet_mt)
    self.l18n = l18n
    self.fleetData = {}
    self.historyData = {}
    self.selectedIndex = 1
    self.viewMode = "fleet" -- "fleet" or "history"
    return self
end

function RHM_HarvestHistoryFleet:initialize()
end

function RHM_HarvestHistoryFleet:onGuiSetupFinished()
    RHM_HarvestHistoryFleet:superClass().onGuiSetupFinished(self)

    if self.fleetTable then
        self.fleetTable:setDataSource(self)
        self.fleetTable:setDelegate(self)
    end

    if self.historyTable then
        self.historyTable:setDataSource(self)
        self.historyTable:setDelegate(self)
    end
end

function RHM_HarvestHistoryFleet:onFrameOpen()
    RHM_HarvestHistoryFleet:superClass().onFrameOpen(self)
    self:updateData()
end

function RHM_HarvestHistoryFleet:updateData()
    self:updateViewModeUI()
    if self.viewMode == "history" then
        self:updateHistoryData()
    else
        self:updateTables()
    end
end

function RHM_HarvestHistoryFleet:onFrameClose()
    RHM_HarvestHistoryFleet:superClass().onFrameClose(self)
end

function RHM_HarvestHistoryFleet:onClickSubTabFleet()
    self.viewMode = "fleet"
    self:updateViewModeUI()
    self:updateTables()
end

function RHM_HarvestHistoryFleet:onClickSubTabHistory()
    self.viewMode = "history"
    self:updateViewModeUI()
    self:updateHistoryData()
end

function RHM_HarvestHistoryFleet:updateViewModeUI()
    local isFleet = (self.viewMode == "fleet")
    if self.fleetPanel then self.fleetPanel:setVisible(isFleet) end
    if self.historyPanel then self.historyPanel:setVisible(not isFleet) end

    -- Visual button highlight feedback
    if self.btnSubTabFleet and self.btnSubTabHistory then
        if isFleet then
            self.btnSubTabFleet:setDisabled(false)
        else
            self.btnSubTabHistory:setDisabled(false)
        end
    end
end

-- ============================================================================
-- FLEET TELEMETRY DATA COLLECTION
-- ============================================================================

local function getActivePlayerFarmId()
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

local function isFarmVehicle(vehicle, farmId)
    if not vehicle then return false end

    local isMultiplayer = (g_currentMission and g_currentMission.isMultiplayer) or false
    -- In singleplayer, all player-operated / hired machines on the map belong to the fleet
    if not isMultiplayer then
        return true
    end

    local vFarmId = (vehicle.getOwnerFarmId and vehicle:getOwnerFarmId()) or 0
    if vFarmId == farmId then return true end

    -- Controlled vehicle (player currently inside or hired worker active)
    if vehicle.getIsControlled and vehicle:getIsControlled() then
        return true
    end

    -- Access handler permission check (covers contractors and shared fleet permissions in MP)
    if g_currentMission and g_currentMission.accessHandler and g_currentMission.accessHandler.canPlayerAccess then
        if g_currentMission.accessHandler:canPlayerAccess(vehicle) then
            return true
        end
    end

    return false
end

local function isHarvesterVehicle(vehicle)
    if not vehicle then return false end

    -- Avoid pure standalone cutterbars / headers
    if vehicle.spec_cutter ~= nil and vehicle.spec_motorized == nil and vehicle.spec_drivable == nil and vehicle.spec_fillUnit == nil then
        return false
    end

    -- 1. Direct specialization table check on vehicle
    if vehicle.spec_rhm_Combine ~= nil 
       or vehicle.spec_combine ~= nil 
       or vehicle.spec_forageHarvester ~= nil 
       or vehicle.spec_cottonHarvester ~= nil
       or vehicle.spec_sugarCaneHarvester ~= nil
       or vehicle.spec_grapeHarvester ~= nil
       or vehicle.spec_oliveHarvester ~= nil
       or vehicle.spec_woodHarvester ~= nil then
        return true, vehicle
    end

    -- 2. Base vehicle type specializations check
    if vehicle.specializations then
        if (Combine ~= nil and SpecializationUtil.hasSpecialization(Combine, vehicle.specializations))
           or (ForageHarvester ~= nil and SpecializationUtil.hasSpecialization(ForageHarvester, vehicle.specializations)) then
            return true, vehicle
        end
    end

    -- 3. Attached implements check (e.g. trailed potato/beet harvesters or modular units like NEXCO)
    if vehicle.getAttachedImplements then
        for _, impl in pairs(vehicle:getAttachedImplements()) do
            if impl.object and impl.object ~= vehicle then
                local isImpComb, target = isHarvesterVehicle(impl.object)
                if isImpComb then
                    return true, (target or impl.object)
                end
            end
        end
    end

    -- 4. Store category check (case-insensitive)
    if vehicle.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
        local item = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
        if item and item.categoryName then
            local cat = string.lower(tostring(item.categoryName))
            -- Exclude pure headers / cutterbars
            if not cat:find("cutter") and not cat:find("header") then
                if cat:find("combine") or cat:find("harvester") or cat:find("harvest") 
                   or cat:find("forage") or cat:find("beet") or cat:find("potato") 
                   or cat:find("cotton") or cat:find("grape") or cat:find("olive") 
                   or cat:find("cane") or cat:find("carrot") or cat:find("parsnip") then
                    return true, vehicle
                end
            end
        end
    end

    -- 5. Vehicle typeName check
    if vehicle.typeName then
        local tn = string.lower(tostring(vehicle.typeName))
        if not tn:find("cutter") and not tn:find("header") then
            if tn:find("combine") or tn:find("harvester") or tn:find("forage") then
                return true, vehicle
            end
        end
    end

    return false
end

local function resolveCutterWidth(obj)
    if not obj then return 0 end
    local w = 0
    if obj.spec_cutter and obj.spec_cutter.workingWidth and obj.spec_cutter.workingWidth > 0 then
        w = obj.spec_cutter.workingWidth
    elseif obj.getWorkingWidth then
        w = obj:getWorkingWidth() or 0
    end
    if w == 0 and obj.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
        local item = g_storeManager:getItemByXMLFilename(obj.configFileName)
        if item and item.specs and item.specs.workingWidth then
            local rawW = tostring(item.specs.workingWidth)
            local parsed = tonumber(string.match(rawW, "%d+%.?%d*"))
            if parsed and parsed > 0 then w = parsed end
        end
    end
    if w == 0 and obj.spec_workArea and obj.spec_workArea.workAreas then
        for _, wa in pairs(obj.spec_workArea.workAreas) do
            if wa.start and wa.width then
                local sx, _, sz = getWorldTranslation(wa.start)
                local wx, _, wz = getWorldTranslation(wa.width)
                local areaWidth = MathUtil.vector2Length(wx - sx, wz - sz)
                if areaWidth > w then w = areaWidth end
            end
        end
    end
    return w
end

local function getHarvesterWorkingWidth(targetHarv, vehicle)
    local widthM = 0
    local rhmSpec = targetHarv.spec_rhm_Combine or (vehicle and vehicle.spec_rhm_Combine)
    if rhmSpec and rhmSpec.loadCalculator and rhmSpec.loadCalculator.lastHeaderWidth and rhmSpec.loadCalculator.lastHeaderWidth > 0 then
        widthM = rhmSpec.loadCalculator.lastHeaderWidth
    end

    if widthM <= 0 and targetHarv.spec_combine and targetHarv.spec_combine.attachedCutters then
        for cutter, _ in pairs(targetHarv.spec_combine.attachedCutters) do
            local cw = resolveCutterWidth(cutter)
            if cw > widthM then widthM = cw end
        end
    end

    if widthM <= 0 and targetHarv.getAttachedImplements then
        for _, imp in pairs(targetHarv:getAttachedImplements()) do
            local obj = imp.object
            if obj then
                local cw = resolveCutterWidth(obj)
                if cw > widthM then widthM = cw end
                if obj.getAttachedImplements then
                    for _, subImp in pairs(obj:getAttachedImplements()) do
                        if subImp.object then
                            local scw = resolveCutterWidth(subImp.object)
                            if scw > widthM then widthM = scw end
                        end
                    end
                end
            end
        end
    end

    if widthM <= 0 and vehicle and vehicle.getAttachedImplements and vehicle ~= targetHarv then
        for _, imp in pairs(vehicle:getAttachedImplements()) do
            local obj = imp.object
            if obj then
                local cw = resolveCutterWidth(obj)
                if cw > widthM then widthM = cw end
            end
        end
    end

    if widthM <= 0 then
        widthM = resolveCutterWidth(targetHarv)
    end
    if widthM <= 0 and vehicle and vehicle ~= targetHarv then
        widthM = resolveCutterWidth(vehicle)
    end

    return widthM
end

local function getAllVehicles()
    local list = {}
    local seen = {}

    local function addFrom(source)
        if type(source) == "table" then
            for _, v in pairs(source) do
                if type(v) == "table" and not seen[v] then
                    if v.getOwnerFarmId or v.rootNode or v.typeName or v.isVehicle then
                        seen[v] = true
                        table.insert(list, v)
                    end
                end
            end
        end
    end

    if g_currentMission then
        if g_currentMission.vehicleSystem then
            if g_currentMission.vehicleSystem.getVehicles then
                addFrom(g_currentMission.vehicleSystem:getVehicles())
            elseif g_currentMission.vehicleSystem.vehicles then
                addFrom(g_currentMission.vehicleSystem.vehicles)
            end
        end
        if g_currentMission.vehicles then
            addFrom(g_currentMission.vehicles)
        end
        if g_currentMission.controlledVehicle then
            local cv = g_currentMission.controlledVehicle
            if not seen[cv] then
                seen[cv] = true
                table.insert(list, cv)
            end
        end
    end

    return list
end

function RHM_HarvestHistoryFleet:updateTables()
    local farmId = getActivePlayerFarmId()

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    local farm = tracker and tracker:getFarmData(farmId)
    local fleetStats = (farm and farm.fleetStats) or {}

    self.fleetData = {}
    local seenVehicles = {}
    local modelCount = {}

    -- Scan live vehicles in the world across FS25 vehicleSystem and mission tables
    local allVehicles = getAllVehicles()
    for _, vehicle in ipairs(allVehicles) do
        if vehicle and isFarmVehicle(vehicle, farmId) and not seenVehicles[vehicle] then
            local isCombine, targetHarv = isHarvesterVehicle(vehicle)
            targetHarv = targetHarv or vehicle
            if isCombine and not seenVehicles[targetHarv] then
                    seenVehicles[vehicle] = true
                    seenVehicles[targetHarv] = true
                    local baseName = targetHarv:getFullName() or targetHarv:getName() or vehicle:getFullName() or vehicle:getName() or "Harvester"
                    
                    -- Disambiguation for multiple vehicles of the same model
                    modelCount[baseName] = (modelCount[baseName] or 0) + 1
                    local license = (targetHarv.getLicensePlateText and targetHarv:getLicensePlateText())
                                 or (vehicle.getLicensePlateText and vehicle:getLicensePlateText())
                    local machineName = baseName
                    if license and license ~= "" then
                        machineName = string.format("%s (%s)", baseName, license)
                    elseif modelCount[baseName] > 1 then
                        machineName = string.format("%s #%d", baseName, modelCount[baseName])
                    end

                    -- Driver status
                    local driverStr = g_i18n:getText("rhm_driver_parked") or "Parked"
                    local isControlled = (vehicle.getIsControlled and vehicle:getIsControlled()) 
                                      or (targetHarv.getIsControlled and targetHarv:getIsControlled())
                    local isAiActive = false
                    if rhm_Combine and rhm_Combine.isAiWorkerActive then
                        isAiActive = rhm_Combine.isAiWorkerActive(vehicle) or rhm_Combine.isAiWorkerActive(targetHarv)
                    else
                        isAiActive = (vehicle.getIsAIActive and vehicle:getIsAIActive()) or (targetHarv.getIsAIActive and targetHarv:getIsAIActive())
                    end

                    if isAiActive then
                        local isCp = (vehicle.getIsCpActive and vehicle:getIsCpActive()) 
                                  or (vehicle.cp and (vehicle.cp.isDriving or vehicle.cp.isFieldWorkActive))
                                  or (targetHarv.getIsCpActive and targetHarv:getIsCpActive())
                        if isCp then
                            driverStr = g_i18n:getText("rhm_driver_cp_ai") or "AI (Courseplay)"
                        else
                            driverStr = g_i18n:getText("rhm_driver_hired_ai") or "AI Worker"
                        end
                    elseif isControlled then
                        driverStr = g_i18n:getText("rhm_driver_player") or "Player"
                    elseif (vehicle.getIsTurnedOn and vehicle:getIsTurnedOn()) or (targetHarv.getIsTurnedOn and targetHarv:getIsTurnedOn()) then
                        driverStr = g_i18n:getText("rhm_driver_idle_on") or "Running (Idle)"
                    end

                    -- Field location & status
                    local fieldStr = g_i18n:getText("rhm_field_yard") or "Yard / Base"
                    local onField = false
                    local checkNode = vehicle.rootNode or targetHarv.rootNode
                    if checkNode then
                        local wx, _, wz = getWorldTranslation(checkNode)
                        local fId = 0
                        if g_fieldManager then
                            local f = nil
                            if g_fieldManager.getFieldAtWorldPosition then
                                f = g_fieldManager:getFieldAtWorldPosition(wx, wz)
                            elseif g_fieldManager.getFieldByWorldPosition then
                                f = g_fieldManager:getFieldByWorldPosition(wx, wz)
                            end
                            if f and (f.fieldId or f.id) then
                                fId = f.fieldId or f.id
                            end
                        end
                        if fId == 0 and g_farmlandManager and g_farmlandManager.getFarmlandIdAtWorldPosition then
                            local farmLandId = g_farmlandManager:getFarmlandIdAtWorldPosition(wx, wz)
                            if farmLandId and farmLandId > 0 then fId = farmLandId end
                        end
                        if fId > 0 then
                            onField = true
                            fieldStr = string.format(g_i18n:getText("rhm_field_format") or "Field %d", fId)
                        end
                    end

                    local isTurnedOn = ((vehicle.getIsTurnedOn and vehicle:getIsTurnedOn()) or (targetHarv.getIsTurnedOn and targetHarv:getIsTurnedOn())) or false
                    local speedKmh = (vehicle.getLastSpeed and vehicle:getLastSpeed()) or (targetHarv.getLastSpeed and targetHarv:getLastSpeed()) or 0

                    -- Real-time Activity Status
                    local statusText = ""
                    local isCutting = false
                    local rhmSpec = targetHarv.spec_rhm_Combine or vehicle.spec_rhm_Combine
                    if rhmSpec and rhmSpec.lastRawArea and rhmSpec.lastRawArea > 0 then
                        isCutting = true
                    elseif targetHarv.spec_combine and targetHarv.spec_combine.lastArea and targetHarv.spec_combine.lastArea > 0 then
                        isCutting = true
                    elseif isTurnedOn and speedKmh > 0.5 and onField then
                        isCutting = true
                    end

                    if isCutting then
                        statusText = g_i18n:getText("rhm_status_harvesting") or "Harvesting"
                    elseif onField and isTurnedOn then
                        statusText = g_i18n:getText("rhm_status_on_field_idle") or "On Field (Idling)"
                    elseif onField and not isTurnedOn then
                        statusText = g_i18n:getText("rhm_status_on_field_stopped") or "On Field (Stopped)"
                    elseif not onField and speedKmh > 2.0 then
                        statusText = g_i18n:getText("rhm_status_in_transit") or "In Transit"
                    elseif isControlled then
                        statusText = g_i18n:getText("rhm_status_in_cab") or "Occupied"
                    else
                        statusText = g_i18n:getText("rhm_status_parked_yard") or "Parked at Base"
                    end

                    -- Crop type
                    local cropStr = "--"
                    local fillTypeIdx = FillType.UNKNOWN
                    if rhmSpec and rhmSpec.lastFillType and rhmSpec.lastFillType ~= FillType.UNKNOWN then
                        fillTypeIdx = rhmSpec.lastFillType
                    elseif targetHarv.spec_combine and targetHarv.spec_combine.lastValidInputFruitType then
                        fillTypeIdx = targetHarv.spec_combine.lastValidInputFruitType
                    end
                    if fillTypeIdx ~= FillType.UNKNOWN and g_fillTypeManager then
                        local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIdx)
                        if ft and ft.title then cropStr = ft.title end
                    end

                    -- Header working width
                    local widthM = getHarvesterWorkingWidth(targetHarv, vehicle)

                    -- Grain tank level (checks combine fill unit, then iterates all fill units)
                    local fillUnitIndex = (targetHarv.spec_combine and targetHarv.spec_combine.fillUnitIndex) or 1
                    local fillLevel = 0
                    local capacity = 0
                    if targetHarv.getFillUnits then
                        local fillUnits = targetHarv:getFillUnits()
                        if fillUnits then
                            for idx = 1, #fillUnits do
                                local cap = targetHarv:getFillUnitCapacity(idx) or 0
                                if cap > capacity then
                                    capacity = cap
                                    fillLevel = targetHarv:getFillUnitFillLevel(idx) or 0
                                end
                            end
                        end
                    elseif targetHarv.getFillUnitFillLevel and targetHarv.getFillUnitCapacity then
                        fillLevel = targetHarv:getFillUnitFillLevel(fillUnitIndex) or 0
                        capacity = targetHarv:getFillUnitCapacity(fillUnitIndex) or 0
                    end
                    local tankPct = (capacity > 0) and ((fillLevel / capacity) * 100.0) or 0

                    -- Telemetry metrics
                    local engineLoad = (rhmSpec and rhmSpec.loadCalculator and rhmSpec.loadCalculator.engineLoad) or 0
                    if engineLoad == 0 and vehicle.spec_motorized and vehicle.spec_motorized.motor then
                        if vehicle.spec_motorized.actualLoadPercentage then
                            engineLoad = vehicle.spec_motorized.actualLoadPercentage
                        elseif vehicle.spec_motorized.motor.lastMotorRpmPercentage then
                            engineLoad = vehicle.spec_motorized.motor.lastMotorRpmPercentage
                        end
                    end
                    local cropLoss = (rhmSpec and rhmSpec.loadCalculator and rhmSpec.loadCalculator.cropLoss) or 0
                    local tonPerHour = (rhmSpec and rhmSpec.loadCalculator and rhmSpec.loadCalculator:getTonPerHour()) or 0
                    local currentYield = (rhmSpec and rhmSpec.loadCalculator and rhmSpec.loadCalculator.currentYield) or 0
                    local damage = (vehicle.getDamageAmount and vehicle:getDamageAmount()) or 0

                    -- Tracker cumulative records
                    local machineKey = vehicle.configFileName or baseName
                    local stat = fleetStats[machineKey] or {}
                    local totalHarvestedL = stat.totalHarvested or 0
                    local totalLostL = stat.totalLost or 0
                    local totalBio = totalHarvestedL + totalLostL
                    local fleetLossPct = (totalBio > 0) and ((totalLostL / totalBio) * 100.0) or cropLoss
                    local rank = RHM_HarvestTracker.calculateEfficiencyRank(fleetLossPct)
                    local opHours = ((vehicle.operatingTime or 0) / 3600000.0)

                    table.insert(self.fleetData, {
                        vehicle = vehicle,
                        name = machineName,
                        field = fieldStr,
                        crop = cropStr,
                        driver = driverStr,
                        status = statusText,
                        cutterWidth = widthM,
                        fillLevel = fillLevel,
                        capacity = capacity,
                        tankPct = tankPct,
                        speed = speedKmh,
                        throughput = tonPerHour,
                        totalHarvestedL = totalHarvestedL,
                        totalLostL = totalLostL,
                        currentYield = currentYield,
                        hours = opHours,
                        engineLoad = engineLoad,
                        cropLoss = cropLoss,
                        rank = rank,
                        damage = damage
                    })
                end
            end
        end

    -- Incorporate offline stored fleet stats if machine was sold/despawned
    for mKey, v in pairs(fleetStats) do
        local mName = v.name or "Harvester"
        local alreadyListed = false
        for _, entry in ipairs(self.fleetData) do
            if entry.name:find(mName, 1, true) then alreadyListed = true; break end
        end

        if not alreadyListed then
            local totalBio = (v.totalHarvested or 0) + (v.totalLost or 0)
            local lossPct = (totalBio > 0) and (((v.totalLost or 0) / totalBio) * 100.0) or 0
            local rank = RHM_HarvestTracker.calculateEfficiencyRank(lossPct)

            table.insert(self.fleetData, {
                vehicle = nil,
                name = mName,
                field = "--",
                crop = "--",
                driver = g_i18n:getText("rhm_driver_parked") or "Stored",
                status = g_i18n:getText("rhm_status_parked_yard") or "Stored",
                cutterWidth = 0,
                fillLevel = 0,
                capacity = 0,
                tankPct = 0,
                speed = 0,
                throughput = 0,
                totalHarvestedL = v.totalHarvested or 0,
                totalLostL = v.totalLost or 0,
                currentYield = 0,
                hours = (v.workSeconds or 0) / 3600.0,
                engineLoad = 0,
                cropLoss = 0,
                rank = rank,
                damage = 0
            })
        end
    end

    table.sort(self.fleetData, function(a, b) return a.name < b.name end)

    if #self.fleetData == 0 then
        table.insert(self.fleetData, {
            name = (g_i18n and g_i18n:hasText("rhm_fleet_no_combines") and g_i18n:getText("rhm_fleet_no_combines")) or "No Harvesters Found",
            field = "--",
            crop = "--",
            driver = "--",
            status = "--",
            cutterWidth = 0,
            fillLevel = 0,
            capacity = 0,
            tankPct = 0,
            speed = 0,
            throughput = 0,
            totalHarvestedL = 0,
            totalLostL = 0,
            currentYield = 0,
            hours = 0,
            engineLoad = 0,
            cropLoss = 0,
            rank = "A",
            damage = 0
        })
    end

    -- Auto-select the combine the player is currently sitting in
    local playerCombine = RHM_HarvestTracker and RHM_HarvestTracker.findPlayerEnteredCombine and RHM_HarvestTracker.findPlayerEnteredCombine()
    local playerIndex = nil
    if playerCombine then
        local pName = playerCombine:getFullName() or ""
        for idx, entry in ipairs(self.fleetData) do
            if entry.vehicle == playerCombine or (entry.vehicle and playerCombine and entry.vehicle.rootVehicle == playerCombine.rootVehicle) or (pName ~= "" and entry.name:find(pName, 1, true)) then
                playerIndex = idx
                break
            end
        end
    end

    if playerIndex then
        self.selectedIndex = playerIndex
    elseif self.selectedIndex > #self.fleetData or self.selectedIndex < 1 then
        self.selectedIndex = 1
    end

    self:updateSelectedCardData()

    if self.fleetTable then
        self.fleetTable:reloadData()
    end
end

function RHM_HarvestHistoryFleet:updateSelectedCardData()
    local entry = self.fleetData[self.selectedIndex] or self.fleetData[1]
    if not entry then return end

    -- Machine Switcher Header
    local titleStr = string.format("[%d/%d]  %s", self.selectedIndex, #self.fleetData, entry.name)
    if self.selectedCombineTitle then self.selectedCombineTitle:setText(titleStr) end

    local countStr = string.format("%s: %d", g_i18n:getText("rhm_fleet_total_count") or "Harvesters", #self.fleetData)
    if self.fleetCountText then self.fleetCountText:setText(countStr) end

    -- CARD 1: Status & Field
    if self.card1FieldNumber then self.card1FieldNumber:setText(entry.field or "--") end
    if self.card1CropType then self.card1CropType:setText(entry.crop or "--") end
    if self.card1DriverText then self.card1DriverText:setText(entry.driver or "--") end
    if self.card1CutterWidth then
        if entry.cutterWidth and entry.cutterWidth > 0 then
            self.card1CutterWidth:setText(string.format("%.1f m", entry.cutterWidth))
        else
            self.card1CutterWidth:setText("--")
        end
    end
    if self.card1GrainTank then
        if entry.capacity and entry.capacity > 0 then
            self.card1GrainTank:setText(string.format("%.0f L (%.0f%%)", entry.fillLevel or 0, entry.tankPct or 0))
        else
            self.card1GrainTank:setText("--")
        end
    end

    -- CARD 2: Performance & Harvest
    if self.card2SpeedText then self.card2SpeedText:setText(string.format("%.1f km/h", entry.speed or 0)) end
    if self.card2ThroughputText then self.card2ThroughputText:setText(string.format("%.1f t/h", entry.throughput or 0)) end
    if self.card2HarvestedText then
        local harvTons = (entry.totalHarvestedL or 0) * 0.00075
        self.card2HarvestedText:setText(string.format("%.1f t (%.0f L)", harvTons, entry.totalHarvestedL or 0))
    end
    if self.card2YieldText then
        if entry.currentYield and entry.currentYield > 0.01 then
            self.card2YieldText:setText(string.format("%.2f t/ha", entry.currentYield))
        else
            self.card2YieldText:setText("--")
        end
    end
    if self.card2OperatingHours then
        self.card2OperatingHours:setText(string.format("%.1f h", entry.hours or 0))
    end

    -- CARD 3: Load & Losses
    if self.card3EngineLoad then self.card3EngineLoad:setText(string.format("%.0f%%", (entry.engineLoad or 0) * 100.0)) end
    if self.card3LossPct then self.card3LossPct:setText(string.format("%.2f%%", entry.cropLoss or 0)) end
    if self.card3LossVolume then
        local lostTons = (entry.totalLostL or 0) * 0.00075
        self.card3LossVolume:setText(string.format("%.1f t (%.0f L)", lostTons, entry.totalLostL or 0))
    end
    if self.card3RankText then
        local rank = entry.rank or "A"
        local rankTitleKey = "rhm_rank_title_" .. string.lower(rank)
        local rankTitle = (g_i18n and g_i18n:hasText(rankTitleKey)) and g_i18n:getText(rankTitleKey) or rank
        self.card3RankText:setText(string.format("[%s] %s", rank, rankTitle))
    end
    if self.card3WearText then
        self.card3WearText:setText(string.format("%.0f%%", (entry.damage or 0) * 100.0))
    end
end

function RHM_HarvestHistoryFleet:onClickPrevCombine()
    if #self.fleetData <= 1 then return end
    self.selectedIndex = self.selectedIndex - 1
    if self.selectedIndex < 1 then
        self.selectedIndex = #self.fleetData
    end
    self:updateSelectedCardData()
    if self.fleetTable and self.fleetTable.setSelectedIndex then
        self.fleetTable:setSelectedIndex(self.selectedIndex)
    end
end

function RHM_HarvestHistoryFleet:onClickNextCombine()
    if #self.fleetData <= 1 then return end
    self.selectedIndex = self.selectedIndex + 1
    if self.selectedIndex > #self.fleetData then
        self.selectedIndex = 1
    end
    self:updateSelectedCardData()
    if self.fleetTable and self.fleetTable.setSelectedIndex then
        self.fleetTable:setSelectedIndex(self.selectedIndex)
    end
end

-- ============================================================================
-- SEASON HISTORY DATA COLLECTION
-- ============================================================================

function RHM_HarvestHistoryFleet:updateHistoryData()
    local farmId = getActivePlayerFarmId()

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    local farm = tracker and tracker:getFarmData(farmId)
    local rawHistory = (farm and farm.seasonHistory) or {}

    self.historyData = {}
    local totalArea = 0
    local totalHarvestL = 0
    local totalLostL = 0
    local totalMoney = 0

    for _, rec in ipairs(rawHistory) do
        local area = rec.areaHa or 0
        local harvL = rec.harvested or 0
        local lostL = rec.lost or 0
        local money = rec.lossMoney or 0
        local harvT = harvL * 0.00075
        local yieldTha = (area > 0.001) and (harvT / area) or 0

        local bioVol = harvL + lostL
        local lossPct = (bioVol > 0) and ((lostL / bioVol) * 100.0) or 0

        totalArea = totalArea + area
        totalHarvestL = totalHarvestL + harvL
        totalLostL = totalLostL + lostL
        totalMoney = totalMoney + money

        local fieldLabel = "--"
        if rec.fieldId and rec.fieldId > 0 then
            fieldLabel = string.format(g_i18n:getText("rhm_field_format") or "Field %d", rec.fieldId)
        end

        local moneyStr = "-$0"
        if g_i18n and g_i18n.formatMoney then
            moneyStr = "-" .. g_i18n:formatMoney(money, nil, true, true)
        else
            moneyStr = string.format("-$%.0f", money)
        end

        table.insert(self.historyData, {
            year = string.format("Y%d", rec.year or 1),
            field = fieldLabel,
            crop = rec.cropName or "UNKNOWN",
            area = string.format("%.2f ha", area),
            harvested = string.format("%.1f t (%.0f L)", harvT, harvL),
            yield = string.format("%.2f t/ha", yieldTha),
            loss = string.format("%.2f%%", lossPct),
            money = moneyStr
        })
    end

    -- Update Summary Metrics Banner
    local totalBioAll = totalHarvestL + totalLostL
    local overallLossPct = (totalBioAll > 0) and ((totalLostL / totalBioAll) * 100.0) or 0
    local totalHarvestTons = totalHarvestL * 0.00075

    if self.histTotalAreaText then self.histTotalAreaText:setText(string.format("%.2f ha", totalArea)) end
    if self.histTotalHarvestText then self.histTotalHarvestText:setText(string.format("%.1f t", totalHarvestTons)) end
    if self.histAvgLossText then self.histAvgLossText:setText(string.format("%.2f%%", overallLossPct)) end

    local totalMoneyStr = "-$0"
    if g_i18n and g_i18n.formatMoney then
        totalMoneyStr = "-" .. g_i18n:formatMoney(totalMoney, nil, true, true)
    else
        totalMoneyStr = string.format("-$%.0f", totalMoney)
    end
    if self.histTotalMoneyText then self.histTotalMoneyText:setText(totalMoneyStr) end

    if #self.historyData == 0 then
        table.insert(self.historyData, {
            year = "--",
            field = "--",
            crop = g_i18n:getText("rhm_hist_empty") or "No Records Yet",
            area = "--",
            harvested = "--",
            yield = "--",
            loss = "--",
            money = "--"
        })
    end

    if self.historyTable then
        self.historyTable:reloadData()
    end
end

-- ============================================================================
-- SmoothList DataSource / Delegate Callbacks
-- ============================================================================

function RHM_HarvestHistoryFleet:getNumberOfSections()
    return 1
end

function RHM_HarvestHistoryFleet:getNumberOfItemsInSection(list, section)
    if list == self.historyTable then
        return #self.historyData
    end
    return #self.fleetData
end

function RHM_HarvestHistoryFleet:getTitleForSectionHeader(list, section)
    return ""
end

function RHM_HarvestHistoryFleet:populateCellForItemInSection(list, section, index, cell)
    if list == self.historyTable then
        local entry = self.historyData[index]
        if not entry then return end

        local yElem = cell:getDescendantByName("histYear")
        if yElem and yElem.setText then yElem:setText(entry.year) end

        local fElem = cell:getDescendantByName("histField")
        if fElem and fElem.setText then fElem:setText(entry.field) end

        local cElem = cell:getDescendantByName("histCrop")
        if cElem and cElem.setText then cElem:setText(entry.crop) end

        local aElem = cell:getDescendantByName("histArea")
        if aElem and aElem.setText then aElem:setText(entry.area) end

        local hElem = cell:getDescendantByName("histHarvested")
        if hElem and hElem.setText then hElem:setText(entry.harvested) end

        local ydElem = cell:getDescendantByName("histYield")
        if ydElem and ydElem.setText then ydElem:setText(entry.yield) end

        local lElem = cell:getDescendantByName("histLoss")
        if lElem and lElem.setText then lElem:setText(entry.loss) end

        local mElem = cell:getDescendantByName("histMoney")
        if mElem and mElem.setText then mElem:setText(entry.money) end
        return
    end

    -- Fleet Table Population
    local entry = self.fleetData[index]
    if not entry then return end

    local nameElem = cell:getDescendantByName("machineName")
    if nameElem and nameElem.setText then nameElem:setText(entry.name) end

    local fieldElem = cell:getDescendantByName("fieldStr")
    if fieldElem and fieldElem.setText then fieldElem:setText(entry.field or "--") end

    local statElem = cell:getDescendantByName("statusStr")
    if statElem and statElem.setText then statElem:setText(entry.status or "--") end

    local speedElem = cell:getDescendantByName("speedStr")
    if speedElem and speedElem.setText then
        speedElem:setText(string.format("%.1f km/h", entry.speed or 0))
    end

    local loadElem = cell:getDescendantByName("loadStr")
    if loadElem and loadElem.setText then
        loadElem:setText(string.format("%.0f%%", (entry.engineLoad or 0) * 100.0))
    end

    local lossElem = cell:getDescendantByName("lossStr")
    if lossElem and lossElem.setText then
        lossElem:setText(string.format("%.2f%%", entry.cropLoss or 0))
    end

    local tankElem = cell:getDescendantByName("tankStr")
    if tankElem and tankElem.setText then
        if entry.capacity and entry.capacity > 0 then
            tankElem:setText(string.format("%.0f L (%.0f%%)", entry.fillLevel or 0, entry.tankPct or 0))
        else
            tankElem:setText("--")
        end
    end
end

function RHM_HarvestHistoryFleet:onListSelectionChanged(list, section, index)
    if list == self.fleetTable and index and index >= 1 and index <= #self.fleetData then
        self.selectedIndex = index
        self:updateSelectedCardData()
    end
end
