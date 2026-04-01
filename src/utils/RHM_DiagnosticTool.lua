-- EN: Diagnostic Tool for Realistic Harvesting Mod
--     Adds a console command 'rhm_inspect' to dump current vehicle's load calculation data.
-- UA: Інструмент діагностики для моду Realistic Harvesting
--     Додає консольну команду 'rhm_inspect' для виводу даних розрахунку навантаження поточного засобу.

RHM_DiagnosticTool = {}

function RHM_DiagnosticTool:consoleCommandInspect()
    local mission = g_currentMission
    if not mission then
        print("RHM: Mission not loaded.")
        return
    end

    local vehicle = nil
    if g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
        vehicle = g_realisticHarvestManager:getControlledVehicle()
    end
    
    if not vehicle then
        print("RHM: No vehicle currently controlled by the player.")
        return
    end

    local rhmSpec = vehicle.spec_rhm_Combine
    if not rhmSpec then
        print("RHM: The controlled vehicle (" .. tostring(vehicle:getFullName()) .. ") is not an RHM Combine.")
        return
    end
    
    local calc = rhmSpec.loadCalculator
    if not calc then
        print("RHM: The controlled vehicle does not have an active loadCalculator.")
        return
    end

    local spec_combine = vehicle.spec_combine

    print("=====================================================")
    print(" RHM DIAGNOSTIC INSPECTION")
    print("=====================================================")
    print(string.format("Vehicle: %s", vehicle:getFullName() or "Unknown"))
    
    -- Engine Power
    local power = 0
    if vehicle.spec_motorized and vehicle.spec_motorized.motor then
        power = vehicle.spec_motorized.motor.hp or 0
    end
    print(string.format("Engine Power: %.1f HP", power))
    
    -- Category and Machine Type
    local cat = vehicle.xmlFile:getValue("vehicle.storeData.category") or "unknown"
    local machineType = rhmSpec.machineType or "unknown"
    print(string.format("Category: %s | Detected machineType: %s", cat, machineType))

    -- Base Performance
    local basePerf = calc.basePerfMass or 0
    print(string.format("Base Performance: %.2f kg/s (%.1f t/h)", basePerf, basePerf * 3.6))

    -- Crop Information
    local inputFruitType = spec_combine and spec_combine.lastValidInputFruitType or 0
    local inputFruitName = "UNKNOWN"
    local fruitDesc = g_fruitTypeManager and g_fruitTypeManager:getFruitTypeByIndex(inputFruitType)
    if fruitDesc and fruitDesc.name then inputFruitName = fruitDesc.name end

    local outputFillType = rhmSpec.lastFillType or 0
    local outputFillName = "UNKNOWN"
    local fillDesc = g_fillTypeManager and g_fillTypeManager:getFillTypeByIndex(outputFillType)
    if fillDesc and fillDesc.name then outputFillName = fillDesc.name end

    print(string.format("Input FruitType: %d (%s) | Output FillType: %d (%s)", inputFruitType, inputFruitName, outputFillType, outputFillName))
    print(string.format("RHM Current Crop: %s", tostring(calc.currentCrop or "None")))

    -- Crop Factors
    local baseFactor = calc.CROP_FACTORS[inputFruitType] or "nil"
    if type(baseFactor) == "number" then baseFactor = string.format("%.3f", baseFactor) end
    local ftFactor = calc.CROP_FACTORS_FT[outputFillType] or "nil"
    if type(ftFactor) == "number" then ftFactor = string.format("%.3f", ftFactor) end
    
    print(string.format("Crop Factor Maps -> DirectCut (FruitType): %s | Pickup (FillType): %s", baseFactor, ftFactor))
    
    
    -- Modifiers
    local isPickup = tostring(calc.isPickup)
    -- Check implements for forage cutter and display attached tools
    local isForageCutter = false
    print("--- ATTACHED IMPLEMENTS ---")
    local hasCutter = false
    if vehicle.getAttachedImplements then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            local implObj = implement.object
            if implObj then
                local implName = implObj:getFullName() or "Unknown Implement"
                local implCat = "unknown"
                if implObj.xmlFile then
                    implCat = implObj.xmlFile:getValue("vehicle.storeData.category") or "unknown"
                end
                
                local isCutterStr = ""
                if implObj.spec_cutter or implObj.spec_forageHarvesterCutter or implObj.spec_forageCutter or implObj.spec_pickup then
                    hasCutter = true
                    isCutterStr = " (DETECTED AS CUTTER/HEADER)"
                end
                
                print(string.format(" - %s [Category: %s]%s", implName, implCat, isCutterStr))

                if implObj.spec_forageHarvesterCutter ~= nil or implObj.spec_forageCutter ~= nil then
                    isForageCutter = true
                end
            end
        end
    end
    if not hasCutter then
        print(" - None")
    end
    print(string.format("Active Modifiers -> isPickup: %s | isForageCutter: %s", isPickup, tostring(isForageCutter)))
    
    -- Live Metrics
    print("--- LIVE METRICS ---")
    print(string.format("Last Tick Area: %.3f m2", rhmSpec.lastRawArea or 0))
    print(string.format("Last Tick Liters: %.2f L", rhmSpec.lastLiters or 0))
    print(string.format("Engine Load: %.1f %%", calc:getEngineLoad()))
    print(string.format("Recommended Speed Limit: %.1f km/h", calc:getSpeedLimit()))
    print(string.format("Genuine Speed Limit: %.1f km/h", calc.genuineSpeedLimit or 0))
    print(string.format("Crop Loss: %.1f %%", calc.cropLoss or 0))
    print(string.format("Moisture: %.1f %%", rhmSpec.data and rhmSpec.data.moisture or 0))
    print("=====================================================")
    return "Inspection completed. See console for details."
end

-- Initialize Console Command
if not RHM_DiagnosticTool.initialized then
    addConsoleCommand("rhm_inspect", "Prints diagnostic info for the current RHM harvester.", "consoleCommandInspect", RHM_DiagnosticTool)
    RHM_DiagnosticTool.initialized = true
    rhm_log("RHM: Diagnostic Tool initialized. Type 'rhm_inspect' in console to use.")
end
