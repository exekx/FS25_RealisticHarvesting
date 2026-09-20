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
        if VehicleMouseCursor._cursorGui ~= nil and VehicleMouseCursor._cursorGui.isOpen then
            VehicleMouseCursor._cursorGui:close()
        end
        VehicleMouseCursor._cursorOwned = false
    end
end

--- Called immediately when RHM Calibration GUI closes
function RHM_ModCompatibility.onCalibrationGUIClosed()
    -- State resumes automatically on the next frame as calibrationGUI.isOpen is now false.
end

return RHM_ModCompatibility
