-- ============================================================================
-- RHM_ModCompatibility.lua
-- Realistic Harvesting Mod - External Input & Overlay Compatibility Layer (FS25)
-- ============================================================================
-- Handles runtime compatibility and event mediation with auxiliary vehicle
-- interaction managers and mouse cursor overlays to ensure seamless UI priority.
-- ============================================================================

RHM_ModCompatibility = {}
RHM_ModCompatibility.isInitialized = false
RHM_ModCompatibility.isICHooked = false
RHM_ModCompatibility.isVMCHooked = false

local _integrityBaseline = nil

function RHM_ModCompatibility.registerIntegrityBaseline(entries)
    if _integrityBaseline ~= nil or type(entries) ~= "table" then
        return
    end
    _integrityBaseline = entries
end

function RHM_ModCompatibility.checkRuntimeIntegrity()
    if _integrityBaseline == nil then
        return false, nil
    end
    local modified = nil
    for _, entry in ipairs(_integrityBaseline) do
        if entry.tbl ~= nil and entry.fn ~= nil and entry.tbl[entry.key] ~= entry.fn then
            modified = modified or {}
            table.insert(modified, entry.name)
        end
    end
    if modified ~= nil and #modified > 0 then
        return true, modified
    end
    return false, nil
end

--- Detects mutually exclusive combine physics and speed controller specializations loaded alongside RHM.
---@return boolean isConflicting
---@return string|nil conflictSource
function RHM_ModCompatibility.checkConflictingCombineMods()
    if g_modIsLoaded ~= nil and g_modIsLoaded["FS25_RealisticCombine"] == true then
        return true, "FS25_RealisticCombine"
    end

    local env = (type(getfenv) == "function") and getfenv(0) or _G
    local rcl = env and env["RCLInstaller"]
    if type(rcl) == "table" and rcl.installed == true then
        return true, tostring(rcl.MOD_NAME or "RCLCombineAutomation")
    end

    if g_specializationManager ~= nil then
        local specs = (type(g_specializationManager.getSpecializations) == "function" and g_specializationManager:getSpecializations())
            or g_specializationManager.specializations
        if type(specs) == "table" then
            local suffix = ".RCLCombineAutomation"
            local suffixLen = #suffix
            for specName, _ in pairs(specs) do
                local nameStr = tostring(specName)
                if nameStr == "RCLCombineAutomation" or nameStr:sub(-suffixLen) == suffix then
                    return true, nameStr
                end
            end
        end
    end

    return false, nil
end

function RHM_ModCompatibility.init()
    if RHM_ModCompatibility.isInitialized then
        return
    end

    RHM_ModCompatibility.hookInteractiveControl()
    RHM_ModCompatibility.hookVehicleMouseCursor()

    RHM_ModCompatibility.isInitialized = true
    rhm_log("RHM [Compat]: Compatibility layer initialized.")
end

--- Hook interactive vehicle controller systems
function RHM_ModCompatibility.hookInteractiveControl()
    if RHM_ModCompatibility.isICHooked then
        return
    end

    if InteractiveControl ~= nil then
        if type(InteractiveControl.isIndoorActive) == "function" then
            InteractiveControl.isIndoorActive = Utils.overwrittenFunction(
                InteractiveControl.isIndoorActive,
                function(self, superFunc)
                    if g_realisticHarvestManager and g_realisticHarvestManager.calibrationGUI and g_realisticHarvestManager.calibrationGUI.isOpen then
                        return false
                    end
                    return superFunc(self)
                end
            )
        end

        if type(InteractiveControl.isInteractiveControlActivated) == "function" then
            InteractiveControl.isInteractiveControlActivated = Utils.overwrittenFunction(
                InteractiveControl.isInteractiveControlActivated,
                function(self, superFunc)
                    if g_realisticHarvestManager and g_realisticHarvestManager.calibrationGUI and g_realisticHarvestManager.calibrationGUI.isOpen then
                        return false
                    end
                    return superFunc(self)
                end
            )
        end

        if type(InteractiveControl.updateInteractiveController) == "function" then
            InteractiveControl.updateInteractiveController = Utils.overwrittenFunction(
                InteractiveControl.updateInteractiveController,
                function(self, superFunc, isIndoor, isOutdoor, hasInput)
                    if g_realisticHarvestManager and g_realisticHarvestManager.calibrationGUI and g_realisticHarvestManager.calibrationGUI.isOpen then
                        return superFunc(self, false, false, false)
                    end
                    return superFunc(self, isIndoor, isOutdoor, hasInput)
                end
            )
        end

        if type(InteractiveControl.setMissionActiveController) == "function" then
            InteractiveControl.setMissionActiveController = Utils.overwrittenFunction(
                InteractiveControl.setMissionActiveController,
                function(self, superFunc, activeController)
                    if g_realisticHarvestManager and g_realisticHarvestManager.calibrationGUI and g_realisticHarvestManager.calibrationGUI.isOpen then
                        return superFunc(self, nil)
                    end
                    return superFunc(self, activeController)
                end
            )
        end

        RHM_ModCompatibility.isICHooked = true
        rhm_log("RHM [Compat]: Successfully hooked interactive vehicle controller.")
    end

    if InteractiveControlManager ~= nil and type(InteractiveControlManager.onActionEventExecute) == "function" then
        InteractiveControlManager.onActionEventExecute = Utils.overwrittenFunction(
            InteractiveControlManager.onActionEventExecute,
            function(self, superFunc, ...)
                if g_realisticHarvestManager and g_realisticHarvestManager.calibrationGUI and g_realisticHarvestManager.calibrationGUI.isOpen then
                    return
                end
                return superFunc(self, ...)
            end
        )
    end
end

--- Hook vehicle mouse cursor overlay
function RHM_ModCompatibility.hookVehicleMouseCursor()
    if RHM_ModCompatibility.isVMCHooked then
        return
    end

    if VMC_CursorOverlayGui ~= nil then
        if type(VMC_CursorOverlayGui.open) == "function" then
            VMC_CursorOverlayGui.open = Utils.overwrittenFunction(
                VMC_CursorOverlayGui.open,
                function(self, superFunc, vehicle)
                    if g_realisticHarvestManager and g_realisticHarvestManager.calibrationGUI and g_realisticHarvestManager.calibrationGUI.isOpen then
                        return false
                    end
                    return superFunc(self, vehicle)
                end
            )
        end

        if type(VMC_CursorOverlayGui.mouseEvent) == "function" then
            VMC_CursorOverlayGui.mouseEvent = Utils.overwrittenFunction(
                VMC_CursorOverlayGui.mouseEvent,
                function(self, superFunc, posX, posY, isDown, isUp, button)
                    if g_realisticHarvestManager and g_realisticHarvestManager.calibrationGUI and g_realisticHarvestManager.calibrationGUI.isOpen then
                        return false
                    end
                    return superFunc(self, posX, posY, isDown, isUp, button)
                end
            )
        end

        if type(VMC_CursorOverlayGui.draw) == "function" then
            VMC_CursorOverlayGui.draw = Utils.overwrittenFunction(
                VMC_CursorOverlayGui.draw,
                function(self, superFunc, ...)
                    if g_realisticHarvestManager and g_realisticHarvestManager.calibrationGUI and g_realisticHarvestManager.calibrationGUI.isOpen then
                        return
                    end
                    return superFunc(self, ...)
                end
            )
        end

        RHM_ModCompatibility.isVMCHooked = true
        rhm_log("RHM [Compat]: Successfully hooked vehicle mouse cursor overlay.")
    end
end

--- Called immediately when RHM Calibration GUI opens
function RHM_ModCompatibility.onCalibrationGUIOpened()
    -- Ensure hooks are in place (in case auxiliary scripts loaded late)
    RHM_ModCompatibility.hookInteractiveControl()
    RHM_ModCompatibility.hookVehicleMouseCursor()

    -- 1. If IC manager is active, clear active controller and unregister exclusive click action event
    if g_currentMission and g_currentMission.interactiveControl then
        if type(g_currentMission.interactiveControl.setActiveInteractiveController) == "function" then
            g_currentMission.interactiveControl:setActiveInteractiveController(nil)
        end
        if type(g_currentMission.interactiveControl.unregisterActionEvents) == "function" then
            g_currentMission.interactiveControl:unregisterActionEvents()
        end
    end

    -- 2. If VehicleMouseCursor is active, close its fullscreen cursor overlay and drop ownership
    if VehicleMouseCursor ~= nil then
        if VehicleMouseCursor._cursorGui ~= nil and VehicleMouseCursor._cursorGui.isOpen and type(VehicleMouseCursor._cursorGui.close) == "function" then
            VehicleMouseCursor._cursorGui:close()
        end
        VehicleMouseCursor._cursorOwned = false
    end
end

--- Called immediately when RHM Calibration GUI closes
function RHM_ModCompatibility.onCalibrationGUIClosed()
    -- State resumes automatically on the next frame as calibrationGUI.isOpen is now false.
end

local function getExternalNamespace(modName, globalSymbol, fallbackFn)
    -- Index mod env directly (via __index metatable), avoiding rawget which bypasses parent engine globals in FS25
    if _G ~= nil then
        local modEnv = _G[modName]
        if type(modEnv) == "table" and modEnv[globalSymbol] ~= nil then
            return modEnv[globalSymbol]
        end
        if _G[globalSymbol] ~= nil then
            return _G[globalSymbol]
        end
    end
    if type(getfenv) == "function" then
        local rootEnv = getfenv(0)
        if rootEnv ~= nil then
            local modEnv = rootEnv[modName]
            if type(modEnv) == "table" and modEnv[globalSymbol] ~= nil then
                return modEnv[globalSymbol]
            end
            if rootEnv[globalSymbol] ~= nil then
                return rootEnv[globalSymbol]
            end
        end
        if type(fallbackFn) == "function" then
            local fnEnv = getfenv(fallbackFn)
            if fnEnv ~= nil and fnEnv[globalSymbol] ~= nil then
                return fnEnv[globalSymbol]
            end
        end
    end
    return nil
end

--- Returns true when an interactive external vehicle HUD or dropdown overlay covers (posX, posY),
--- so lower HUD layers yield mouse input without stealing clicks.
---@param posX number
---@param posY number
---@param vehicle table|nil
---@return boolean
function RHM_ModCompatibility.isExternalHudBlockingMouse(posX, posY, vehicle)
    if not posX or not posY then
        return false
    end

    local controlled = g_currentMission and g_currentMission.controlledVehicle
    local target = controlled or vehicle
    local cursorVisible = g_inputBinding and g_inputBinding.getShowMouseCursor and g_inputBinding:getShowMouseCursor()

    if cursorVisible then
        local adFn = (target and (target.startAutoDrive or target.getCanAdTakeControl))
            or (vehicle and (vehicle.startAutoDrive or vehicle.getCanAdTakeControl))
        local adNs = getExternalNamespace("FS25_AutoDrive", "AutoDrive", adFn)
        if type(adNs) == "table" and adNs.Hud ~= nil then
            if adNs.Hud.isMoving == true then
                return true
            end
            local isHudInputActive = (adNs.isMouseActiveForHud == nil) or adNs.isMouseActiveForHud()
            if isHudInputActive and type(adNs.Hud.isMouseOverHud) == "function" and adNs.Hud:isMouseOverHud(posX, posY) then
                return true
            end
            if isHudInputActive and adNs.pullDownListExpanded ~= nil and adNs.pullDownListExpanded ~= 0 then
                return true
            end
        end
    end

    if target ~= nil then
        if type(target.getIsMouseOverCpHud) == "function" and target:getIsMouseOverCpHud() then
            return true
        end
        local cpHud = (type(target.getCpHud) == "function" and target:getCpHud())
            or (target.spec_cpHud and target.spec_cpHud.hud)
        if cpHud ~= nil and type(cpHud.getIsOpen) == "function" and cpHud:getIsOpen() then
            if type(cpHud.isMouseOverArea) == "function" and cpHud:isMouseOverArea(posX, posY) then
                return true
            end
        end
    end

    return false
end

return RHM_ModCompatibility
