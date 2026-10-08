-- EN: Diagnostic tool for monitoring and troubleshooting harvest history telemetry.
--     Prints detailed debug output into log.txt every 5-10 seconds during active harvesting.
--     Temporary module for developer validation.
-- UA: Діагностичний інструмент для моніторингу та діагностики телеметрії історії врожаю.
--     Виводить детальні логи в log.txt кожні 5-10 секунд під час активного збирання.
--     Тимчасовий модуль для перевірки розробником.

RHM_DiagnosticTool = {}
RHM_DiagnosticTool.isPeriodicLoggingEnabled = false
RHM_DiagnosticTool.logIntervalMs = 5000 -- Strictly 5 seconds interval as requested
RHM_DiagnosticTool.timer = 0

---EN: Resolves active player farm ID reliably across FS25 singleplayer and dedicated server
---UA: Надійно визначає ID активної ферми гравця в FS25 (синглплеєр та мультиплеєр)
function RHM_DiagnosticTool:getFarmId()
    local farmId = 1
    if g_currentMission then
        if g_currentMission.player and g_currentMission.player.getFarmId then
            local pFarm = g_currentMission.player:getFarmId()
            if pFarm and pFarm ~= 0 and (not FarmManager or pFarm ~= FarmManager.SPECTATOR_FARM_ID) then
                farmId = pFarm
            end
        elseif g_currentMission.player and g_currentMission.player.farmId then
            local pFarm = g_currentMission.player.farmId
            if pFarm and pFarm ~= 0 and (not FarmManager or pFarm ~= FarmManager.SPECTATOR_FARM_ID) then
                farmId = pFarm
            end
        elseif g_currentMission.getFarmId then
            local mFarm = g_currentMission:getFarmId()
            if mFarm and mFarm ~= 0 and (not FarmManager or mFarm ~= FarmManager.SPECTATOR_FARM_ID) then
                farmId = mFarm
            end
        end
    end
    return tonumber(farmId) or 1
end

function RHM_DiagnosticTool:log(msg)
    print(string.format("Info: RHM_Diag: %s", tostring(msg)))
end

function RHM_DiagnosticTool:logWarning(msg)
    print(string.format("Warning: RHM_Diag: %s", tostring(msg)))
end

---EN: Console command handler to dump full harvest tracker state into log.txt
---UA: Обробник консольної команди для виводу повного стану трекера врожаю в log.txt
function RHM_DiagnosticTool:consoleDumpState()
    print("================================================================================")
    print("Info: RHM_Diag: [DIAGNOSTIC STATE DUMP - START]")
    print("================================================================================")

    local currentYear = 1
    if g_currentMission and g_currentMission.environment and g_currentMission.environment.currentYear then
        currentYear = g_currentMission.environment.currentYear
    end
    print(string.format("Info: RHM_Diag: Current Environment Year: %d", currentYear))

    local tracker = g_realisticHarvestTracker or (RHM_RealisticHarvestManager and RHM_RealisticHarvestManager.harvestTracker)
    if not tracker then
        print("Warning: RHM_Diag: HarvestTracker singleton not found!")
        return
    end

    local farmId = self:getFarmId()
    print(string.format("Info: RHM_Diag: Current Player Farm ID: %d", farmId))

    local farm = tracker:getFarmData(farmId)
    if not farm then
        print("Warning: RHM_Diag: Farm data not found for Farm ID: " .. tostring(farmId))
        return
    end

    -- 1. Current Trip
    local cTrip = farm.currentTrip
    if cTrip then
        print(string.format("Info: RHM_Diag: [Current Trip] Field: %d | Crop: %s | Harv: %.1f L | Area: %.2f ha | Active: %s | Contract: %s",
            cTrip.fieldId or 0,
            tostring(cTrip.cropName),
            cTrip.harvestedLiters or 0,
            cTrip.harvestedAreaHa or 0,
            tostring(cTrip.isActive),
            tostring(cTrip.isContract)))
    else
        print("Info: RHM_Diag: [Current Trip] None")
    end

    -- 2. Per-Combine Trips
    print("Info: RHM_Diag: --- Combine Trips (Machine Odometers) ---")
    local cCount = 0
    if farm.combineTrips then
        for mKey, mTr in pairs(farm.combineTrips) do
            cCount = cCount + 1
            print(string.format("Info: RHM_Diag:   [%d] Machine: %s | Field: %d | Crop: %s | Harv: %.1f L | Area: %.2f ha | Active: %s",
                cCount,
                tostring(mKey),
                mTr.fieldId or 0,
                tostring(mTr.cropName),
                mTr.harvestedLiters or 0,
                mTr.harvestedAreaHa or 0,
                tostring(mTr.isActive)))
        end
    end
    if cCount == 0 then
        print("Info: RHM_Diag:   (No combine trips in memory)")
    end

    -- 3. Field Stats (Running In-Progress Cumulative Data)
    print("Info: RHM_Diag: --- Farm Field Stats (Current Season & Active Fields) ---")
    local fCount = 0
    if farm.fieldStats then
        for fId, fStat in pairs(farm.fieldStats) do
            fCount = fCount + 1
            print(string.format("Info: RHM_Diag:   Field %d: Crop: %s | Year: %s | Harv: %.1f L (%.2f t) | Area: %.2f ha | Fuel: %.1f L | Ops: %d",
                fId,
                tostring(fStat.lastCrop or fStat.lastCropName),
                tostring(fStat.lastYear),
                fStat.harvestedLiters or 0,
                (fStat.harvestedMassKg or 0) * 0.001,
                fStat.harvestedAreaHa or 0,
                fStat.fuelUsedL or 0,
                fStat.operationsCount or 0))
        end
    end
    if fCount == 0 then
        print("Info: RHM_Diag:   (No field stats in memory)")
    end

    -- 4. Season History
    print(string.format("Info: RHM_Diag: --- Season History (Year %d) ---", currentYear))
    local sCount = 0
    if farm.seasonHistory then
        for idx, entry in ipairs(farm.seasonHistory) do
            if entry.year == currentYear then
                sCount = sCount + 1
                print(string.format("Info: RHM_Diag:   [%d] Field %d: Crop: %s | Harv: %.1f L | Area: %.2f ha | Lost: %.1f L | Rank: %s",
                    idx,
                    entry.fieldId or 0,
                    tostring(entry.cropName),
                    entry.harvested or 0,
                    entry.areaHa or 0,
                    entry.lost or 0,
                    tostring(entry.efficiencyRank)))
            end
        end
    end
    if sCount == 0 then
        print(string.format("Info: RHM_Diag:   (No archived history for Year %d)", currentYear))
    end

    print("================================================================================")
    print("Info: RHM_Diag: [DIAGNOSTIC STATE DUMP - END]")
    print("================================================================================")
end

---EN: Console command handler to reset all history for current farm
---UA: Обробник консольної команди для повного очищення історії поточної ферми
function RHM_DiagnosticTool:consoleClearHistory()
    local tracker = g_realisticHarvestTracker or (RHM_RealisticHarvestManager and RHM_RealisticHarvestManager.harvestTracker)
    if not tracker then
        print("Warning: RHM_Diag: HarvestTracker singleton not found!")
        return
    end

    local farmId = self:getFarmId()

    local farm = tracker:getFarmData(farmId)
    if farm then
        farm.currentTrip = {
            fieldId = 0,
            cropName = "--",
            fillTypeIndex = FillType.UNKNOWN,
            harvestedLiters = 0,
            harvestedMassKg = 0,
            harvestedAreaHa = 0,
            lostLiters = 0,
            lossMoney = 0,
            fuelUsedL = 0,
            sessionDuration = 0,
            avgSpeedSum = 0,
            avgSpeedCount = 0,
            avgLoadSum = 0,
            avgLoadCount = 0,
            efficiencyRank = "A",
            isActive = false,
            isContract = false,
            reasons = { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }
        }
        farm.combineTrips = {}
        farm.fieldStats = {}
        farm.seasonHistory = {}
        farm.yearlyStats = {}
        farm.fleetStats = {}
        tracker.isDirty = true
        print(string.format("Info: RHM_Diag: All harvest history data for Farm ID %d successfully CLEARED!", tonumber(farmId) or 1))
    end
end

---EN: Console command handler to toggle periodic 5-10s logging on or off
---UA: Обробник консольної команди для увімкнення/вимкнення періодичного логування
function RHM_DiagnosticTool:consoleTogglePeriodicLogging()
    self.isPeriodicLoggingEnabled = not self.isPeriodicLoggingEnabled
    print(string.format("Info: RHM_Diag: Periodic telemetry logging is now %s", self.isPeriodicLoggingEnabled and "ENABLED" or "DISABLED"))
end

---EN: Periodic update hook called from onMissionUpdate every frame
---UA: Періодичний хук оновлення, який викликається з onMissionUpdate кожного кадру
function RHM_DiagnosticTool:update(dt)
    if not self.isPeriodicLoggingEnabled then
        return
    end

    self.timer = (self.timer or 0) + (dt or 0)
    if self.timer < self.logIntervalMs then
        return
    end
    self.timer = 0

    if not g_currentMission then
        return
    end

    local farmId = self:getFarmId()
    local tracker = g_realisticHarvestTracker or (RHM_RealisticHarvestManager and RHM_RealisticHarvestManager.harvestTracker)
    local currentYear = (g_currentMission.environment and g_currentMission.environment.currentYear) or 1

    -- Discover combines on map
    local vehicles = (g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles)
        or (g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.getVehicles and g_currentMission.vehicleSystem:getVehicles())
        or g_currentMission.vehicles
        or {}
    local activeCombines = {}
    for _, veh in pairs(vehicles) do
        if type(veh) == "table" and veh.spec_rhm_Combine then
            local spec = veh.spec_rhm_Combine
            local isEntered = veh.getIsEntered and veh:getIsEntered()
            local isAI = (rhm_Combine and rhm_Combine.isAiWorkerActive and rhm_Combine.isAiWorkerActive(veh)) or (veh.getIsAIActive and veh:getIsAIActive()) or false
            local isCutting = false
            local cutterWidth = 0
            local cutterLowered = false
            local cutterTurnedOn = false
            local cutters = veh.spec_combine and veh.spec_combine.attachedCutters
            if cutters then
                for cutter, _ in pairs(cutters) do
                    if cutter.getWorkingWidth then
                        cutterWidth = cutter:getWorkingWidth() or cutterWidth
                    elseif cutter.spec_cutter and cutter.spec_cutter.workingWidth then
                        cutterWidth = cutter.spec_cutter.workingWidth or cutterWidth
                    end
                    if cutter.spec_cutter then
                        if cutter.getIsLowered then
                            cutterLowered = cutter:getIsLowered(true)
                        end
                        if cutter.getIsTurnedOn then
                            cutterTurnedOn = cutter:getIsTurnedOn()
                        end
                        if cutterLowered and cutterTurnedOn then
                            isCutting = true
                        end
                    end
                end
            end
            if cutterWidth == 0 and RHM_Api and RHM_Api.getWorkingWidth then
                cutterWidth = RHM_Api.getWorkingWidth(veh) or 0
            end
            if cutterWidth == 0 and spec.loadCalculator and spec.loadCalculator.lastHeaderWidth then
                cutterWidth = spec.loadCalculator.lastHeaderWidth
            end

            table.insert(activeCombines, {
                vehicle = veh,
                spec = spec,
                name = veh:getFullName() or veh:getName() or "Harvester",
                isEntered = isEntered,
                isAI = isAI,
                isCutting = isCutting,
                cutterWidth = cutterWidth,
                cutterLowered = cutterLowered,
                cutterTurnedOn = cutterTurnedOn,
                isActivelyHarvesting = spec.isActivelyHarvesting or false,
                currentCrop = (spec.loadCalculator and spec.loadCalculator.currentCrop) or (spec.combineMemory and spec.combineMemory.currentCrop) or "--",
                fieldId = (spec.trip and spec.trip.fieldId) or spec._lastDetectedFieldId or 0,
                speedKmh = veh:getLastSpeed() or 0,
                engineLoad = (veh.getMotorLoadPercentage and veh:getMotorLoadPercentage() * 100) or ((spec.lastEngineLoad or 0) * 100),
                trip = spec.trip
            })
        end
    end

    if #activeCombines == 0 then
        print(string.format("Info: RHM_Diag: [IDLE MONITOR] Season %d | Farm %d | No harvesters found on map", tonumber(currentYear) or 1, tonumber(farmId) or 1))
        return
    end

    -- Check if any combine is operating (cutting, harvesting, entered, AI, or motor running)
    local anyRunning = false
    for _, c in ipairs(activeCombines) do
        if c.isCutting or c.isActivelyHarvesting or c.isEntered or c.isAI or (c.vehicle.getIsMotorStarted and c.vehicle:getIsMotorStarted()) then
            anyRunning = true
            break
        end
    end

    if not anyRunning then
        print(string.format("Info: RHM_Diag: [IDLE MONITOR] Season %d | Farm %d | %d Harvesters detected on map (idle / stopped)", tonumber(currentYear) or 1, tonumber(farmId) or 1, #activeCombines))
        return
    end

    print("================================================================================")
    print(string.format("Info: RHM_Diag: [TELEMETRY SNAPSHOT | Season %d | Farm ID %d]", tonumber(currentYear) or 1, tonumber(farmId) or 1))
    print("================================================================================")

    for idx, c in ipairs(activeCombines) do
        local v = c.vehicle
        local spec = c.spec
        local calc = spec.loadCalculator
        local tph = (calc and calc:getTonPerHour()) or 0.0
        local moisture = (spec.data and spec.data.moisture) or (calc and calc.currentMoisture) or 0
        local totalLossPct = (spec.data and spec.data.cropLoss) or 0
        local lossBioL = (spec.trip and spec.trip.lostLiters) or 0
        local machineType = (spec.combineMemory and spec.combineMemory.machineType) or "grain"

        -- Compact idle check: if combine is parked and completely inactive, print 1 line to save console space
        local isIdle = (not c.isCutting)
            and (not c.isActivelyHarvesting)
            and (not c.isEntered)
            and (not c.isAI)
            and ((tonumber(c.speedKmh) or 0) < 0.5)
            and (tph < 0.1)

        if isIdle then
            print(string.format("Info: RHM_Diag: -> Harvester [%d] %s | Type: %s | Status: IDLE / PARKED (Yard)",
                idx, tostring(c.name or "Harvester"), tostring(machineType)))
        else
            -- 1. Identity & Driver
            local driver = c.isEntered and "PLAYER" or (c.isAI and "AI-WORKER" or "IDLE")
            local isEnteredText = c.isEntered and "YES" or "NO"
            print(string.format("Info: RHM_Diag: -> Harvester [%d] %s | Type: %s | Driver: %s (Player Seated: %s)",
                idx, tostring(c.name or "Harvester"), tostring(machineType), tostring(driver), isEnteredText))

            -- 2. Power Balance & Engine Physics
            local fuelUsageLh = 0
            local carrier = rhm_Combine and rhm_Combine.getMotorizedCarrier and rhm_Combine.getMotorizedCarrier(v)
            if carrier and carrier.spec_motorized then
                fuelUsageLh = carrier.spec_motorized.lastFuelUsage or 0
            end
            local effHp = (calc and calc.lastEffectiveHp) or (calc and calc:getEnginePowerHp(v)) or 0
            local speedLimit = (calc and calc.speedLimit) or 0
            local pTotal = (calc and calc.lastPowerTotal) or 0
            local pBase = (calc and calc.lastPowerBase) or 0
            local pHeader = (calc and calc.lastPowerHeader) or 0
            local pProcess = (calc and calc.lastPowerProcess) or 0
            local pChopper = (calc and calc.lastPowerChopper) or 0
            local pSoil = (calc and calc.lastPowerSoil) or 0

            print(string.format("Info: RHM_Diag:    Engine & Speed: Speed=%.1f km/h (Limit: %.1f km/h) | Load=%.0f%% | FuelRate=%.1f L/h | EffectivePower=%.0f HP",
                tonumber(c.speedKmh) or 0, tonumber(speedLimit) or 0, tonumber(c.engineLoad) or 0, tonumber(fuelUsageLh) or 0, tonumber(effHp) or 0))
            print(string.format("Info: RHM_Diag:    Power Balance: Total=%.1f HP [Base: %.1f HP | Header: %.1f HP | Thresh: %.1f HP | Chopper: %.1f HP | Soil: %.1f HP]",
                tonumber(pTotal) or 0, tonumber(pBase) or 0, tonumber(pHeader) or 0, tonumber(pProcess) or 0, tonumber(pChopper) or 0, tonumber(pSoil) or 0))

            -- 3. Header & Field Geometry
            local cutWidth = tonumber(c.cutterWidth) or 0
            if cutWidth == 0 and RHM_Api and RHM_Api.getWorkingWidth then cutWidth = RHM_Api.getWorkingWidth(v) or 0 end
            if cutWidth == 0 and calc and calc.lastHeaderWidth then cutWidth = calc.lastHeaderWidth end
            local cutState = string.format("Header: %.1fm [%s, %s]", cutWidth, c.cutterLowered and "DOWN" or "UP", c.cutterTurnedOn and "ON" or "OFF")
            local isContract = RHM_HarvestTracker and RHM_HarvestTracker.isContractField and RHM_HarvestTracker.isContractField(c.fieldId, farmId)
            local contractText = isContract and "CONTRACT/MISSION" or "OWNED"

            print(string.format("Info: RHM_Diag:    Field & Header: Field=%d (%s) | Crop=%s | %s | Throughput=%.1f t/h",
                tonumber(c.fieldId) or 0, contractText, tostring(c.currentCrop or "--"), tostring(cutState), tonumber(tph) or 0))

            -- 4. Environmental & Physical Conditions
            local weedPct = ((spec.data and spec.data.weedRatio) or (spec.currentWeedRatio or 0)) * 100
            local slopeAngle = (calc and calc.smoothedSlopeAngle) or 0
            local cutterDmg = ((calc and calc.lastCutterDamage) or 0) * 100
            local combineDmg = ((calc and calc.lastCombineDamage) or 0) * 100
            local weedNote = (weedPct <= 0.01) and " (Clean Field)" or ""
            print(string.format("Info: RHM_Diag:    Conditions: Moisture=%.1f%% | Weeds=%.1f%%%s | Slope=%.1f deg | KnifeWear=%.0f%% | CombineWear=%.0f%%",
                tonumber(moisture) or 0, tonumber(weedPct) or 0, weedNote, tonumber(slopeAngle) or 0, tonumber(cutterDmg) or 0, tonumber(combineDmg) or 0))

            -- 5. Mechanical Tuning Settings (Shift+K)
            local set = spec.combineMemory and spec.combineMemory.currentSettings
            local drumRpm = set and set.rotor or 50
            local concave = set and set.feeder or 50
            local fanRpm = set and set.fan or 50
            local upSieve = set and set.upperSieve or 50
            local lowSieve = set and set.lowerSieve or 50
            local isSwath = v.spec_combine and v.spec_combine.isSwathActive
            local strawMode = isSwath and "SWATH/WINDROW" or "CHOPPER/SPREAD"
            print(string.format("Info: RHM_Diag:    Tuning (Shift+K): Drum=%d%% | Concave=%d%% | Fan=%d%% | TopSieve=%d%% | BtmSieve=%d%% | Straw=%s",
                tonumber(drumRpm) or 0, tonumber(concave) or 0, tonumber(fanRpm) or 0, tonumber(upSieve) or 0, tonumber(lowSieve) or 0, strawMode))

            -- 6. Loss Breakdown
            local lossBreakdown = calc and calc:getLossBreakdown()
            local spdLoss = lossBreakdown and lossBreakdown.speedPct or 0
            local setLoss = lossBreakdown and lossBreakdown.settingsPct or 0
            local mstLoss = lossBreakdown and lossBreakdown.moisturePct or 0
            local wearLoss = lossBreakdown and lossBreakdown.wearPct or 0
            local slpLoss = lossBreakdown and lossBreakdown.slopePct or 0
            local spdNote = (spdLoss == 0 and (tonumber(c.engineLoad) or 0) <= 80) and " (Load <=80%)" or ""
            local slpNote = (slpLoss == 0 and (tonumber(slopeAngle) or 0) <= 4.0) and " (Slope <=4°)" or ""
            print(string.format("Info: RHM_Diag:    Loss Breakdown: Total=%.2f%% (%.1f L) | [Speed: %.2f%%%s | Settings: %.2f%% | Moisture: %.2f%% | Wear: %.2f%% | Slope: %.2f%%%s]",
                tonumber(totalLossPct) or 0, tonumber(lossBioL) or 0,
                tonumber(spdLoss) or 0, spdNote,
                tonumber(setLoss) or 0,
                tonumber(mstLoss) or 0,
                tonumber(wearLoss) or 0,
                tonumber(slpLoss) or 0, slpNote))

            -- 7. Machine Trip Odometer
            if c.trip then
                local t = c.trip
                local tMass = (t.harvestedMassKg and t.harvestedMassKg > 0) and (t.harvestedMassKg * 0.001) or 0
                local yieldTha = (t.harvestedAreaHa and t.harvestedAreaHa > 0.001) and (tMass / t.harvestedAreaHa) or 0
                local rank = t.efficiencyRank or "A"
                local masterId = (tracker and tracker.getMasterFieldId and tracker:getMasterFieldId(farmId, t.fieldId)) or t.fieldId
                local clusterInfo = ""
                if tracker and tracker.getClusterMembers then
                    local members = tracker:getClusterMembers(farmId, masterId)
                    if #members > 1 then
                        clusterInfo = string.format(" [Cluster: %s]", table.concat(members, ", "))
                    end
                end
                print(string.format("Info: RHM_Diag:    Machine Trip: Field=%d%s | Harv=%.0f L (%.2f t) | Area=%.2f ha | Yield=%.1f t/ha | Fuel=%.1f L | Dur=%.0f s | Rank=%s | Active=%s",
                    tonumber(masterId) or 0, clusterInfo, tonumber(t.harvestedLiters) or 0, tonumber(tMass) or 0, tonumber(t.harvestedAreaHa) or 0, tonumber(yieldTha) or 0, tonumber(t.fuelUsedL) or 0, tonumber(t.sessionDuration) or 0, tostring(rank), tostring(t.isActive)))
            end
        end
    end

    -- Cumulative farm field stats
    local farm = tracker and tracker:getFarmData(farmId)
    if farm and farm.fieldClusters and next(farm.fieldClusters) ~= nil then
        print("Info: RHM_Diag: --- Active Merged Field Clusters ---")
        for masterId, cl in pairs(farm.fieldClusters) do
            local mList = {}
            for mId, _ in pairs(cl.members or {}) do
                table.insert(mList, mId)
            end
            table.sort(mList)
            if #mList > 1 then
                print(string.format("Info: RHM_Diag:    Cluster Master Field %d -> Members: [%s]", masterId, table.concat(mList, ", ")))
            end
        end
    end
    if farm and farm.fieldStats then
        local fCount = 0
        print("Info: RHM_Diag: --- Farm Field Cumulative Stats (Season " .. tostring(currentYear) .. ") ---")
        for fId, fStat in pairs(farm.fieldStats) do
            if fStat.lastYear == currentYear and ((fStat.harvestedLiters or 0) > 0 or (fStat.harvestedAreaHa or 0) > 0) then
                fCount = fCount + 1
                local fMass = (fStat.harvestedMassKg and fStat.harvestedMassKg > 0) and (fStat.harvestedMassKg * 0.001) or 0
                local fYield = (fStat.harvestedAreaHa and fStat.harvestedAreaHa > 0.001) and (fMass / fStat.harvestedAreaHa) or 0
                local fPrice = 0.35
                local cName = fStat.lastCropName or fStat.lastCrop or "--"
                if g_currentMission.economyManager and g_fillTypeManager and cName ~= "--" then
                    local ftIdx = g_fillTypeManager:getFillTypeIndexByName(cName)
                    if ftIdx and ftIdx ~= FillType.UNKNOWN then
                        fPrice = g_currentMission.economyManager:getPricePerLiter(ftIdx) or fPrice
                    end
                end
                local gross = (fStat.harvestedLiters or 0) * fPrice
                local fuelExp = (fStat.fuelUsedL or 0) * 1.45
                local netMargin = gross - fuelExp
                local ops = fStat.operationsCount or 1

                print(string.format("Info: RHM_Diag:    Field %d Cumulative: Season %d | Crop=%s | Harv=%.0f L (%.2f t) | Area=%.2f ha | Yield=%.1f t/ha | Fuel=%.1f L | Ops=%d | NetMargin=+EUR %.0f",
                    tonumber(fId) or 0, tonumber(fStat.lastYear or currentYear) or 1, tostring(cName or "--"), tonumber(fStat.harvestedLiters) or 0, tonumber(fMass) or 0, tonumber(fStat.harvestedAreaHa) or 0, tonumber(fYield) or 0, tonumber(fStat.fuelUsedL) or 0, tonumber(ops) or 1, tonumber(netMargin) or 0))
            end
        end
        if fCount == 0 then
            print("Info: RHM_Diag:    (No active field entries accumulated yet for Season " .. tostring(currentYear) .. ")")
        end
    end

    print("================================================================================")
end

---EN: Diagnostic logging when the Farm Fields GUI finishes aggregating fields
---UA: Діагностичне логування після того, як GUI Farm Fields завершив агрегацію полів
function RHM_DiagnosticTool:logFieldsRender(seasonYear, rows, totalArea, totalMassT, totalMargin, topCropName, bestYieldField)
    if not self.isPeriodicLoggingEnabled then
        return
    end
    print(string.format("Info: RHM_Diag: [GUI RENDER] Season %d | %d rows rendered | Total Area: %.2f ha | Clean Harv: %.1f t | Net Margin: +EUR %.0f | Top Crop: %s | Best Yield: %s",
        tonumber(seasonYear) or 0,
        rows and #rows or 0,
        tonumber(totalArea) or 0,
        tonumber(totalMassT) or 0,
        tonumber(totalMargin) or 0,
        tostring(topCropName or "--"),
        tostring(bestYieldField or "--")))

    for idx, item in ipairs(rows) do
        print(string.format("Info: RHM_Diag:   [%d] Field %s | Status: %s | Area: %s | Crop: %s | Harv: %s | Yield: %s | Loss: %s | Margin: %s | Rank: %s",
            idx,
            tostring(item.field or item.fieldNumber or "--"),
            tostring(item.status or item.fieldStatus or "--"),
            tostring(item.area or item.fieldArea or "--"),
            tostring(item.crop or item.cropType or "--"),
            tostring(item.harvested or item.harvestedVolume or "--"),
            tostring(item.yield or item.averageYield or "--"),
            tostring(item.loss or item.cropLossPct or "--"),
            tostring(item.money or item.operatingMargin or "--"),
            tostring(item.rank or item.efficiencyRank or "--")))
    end
end

---EN: Registers console commands with GIANTS Engine
---UA: Реєструє консольні команди в GIANTS Engine
function RHM_DiagnosticTool:init()
    if addConsoleCommand then
        addConsoleCommand("rhmDump", "Prints full RHM harvest tracker state into log.txt", "consoleDumpState", self)
        addConsoleCommand("rhmClearHistory", "Clears all RHM harvest history for current farm", "consoleClearHistory", self)
        addConsoleCommand("rhmLogToggle", "Toggles periodic 5-second harvest telemetry logging", "consoleTogglePeriodicLogging", self)
        print("Info: RHM_Diag: Diagnostic commands registered: rhmDump, rhmClearHistory, rhmLogToggle")
    end
end
