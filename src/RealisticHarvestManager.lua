-- EN: Central manager for the Realistic Harvesting mod. Created once per mission and stored
--     as the global g_realisticHarvestManager. Coordinates all mod subsystems:
--     settings, HUD, calibration GUI, console commands, and input events.
-- UA: Центральний менеджер мода Realistic Harvesting. Створюється один раз за місію і зберігається
--     як глобальний g_realisticHarvestManager. Координує всі підсистеми мода:
--     налаштування, HUD, GUI калібрування, консольні команди та події вводу.
RealisticHarvestManager = {}
local RealisticHarvestManager_mt = Class(RealisticHarvestManager)

-- EN: Initializes all mod subsystems: settings, UI, HUD, calibration GUI, and console commands.
--     Creates the HUD and settings UI only on the game client (not dedicated server).
-- UA: Ініціалізує всі підсистеми мода: налаштування, UI, HUD, GUI калібрування і консольні команди.
--     Створює HUD і settings UI тільки на клієнті гри (не на виділеному сервері).
function RealisticHarvestManager.new(mission, modDirectory, modName)
    local self = setmetatable({}, RealisticHarvestManager_mt)

    self.mission = mission
    self.modDirectory = modDirectory
    self.modName = modName

    self.debug = RHM_Debug.isEnabled("Manager")

    -- EN: Initialize settings: the SettingsManager handles XML I/O, Settings holds all values.
    -- UA: Ініціалізуємо налаштування: SettingsManager обробляє XML, Settings зберігає значення.
    self.settingsManager = SettingsManager.new()
    self.settings = Settings.new(self.settingsManager)
    self.combineSettingsManager = CombineSettingsManager.new()

    self.savedCameraRotatableInfo = {} -- EN: Stores camera rotatability before cursor mode / UA: Зберігає стан камери до режиму курсора

    -- EN: Inject settings into the FS25 in-game settings menu (client only).
    --     Hooks onFrameOpen and updateButtons to ensure our controls appear in the right place.
    -- UA: Впроваджуємо налаштування в меню налаштувань FS25 (тільки клієнт).
    --     Підключаємо onFrameOpen і updateButtons щоб наші елементи з'являлись у правильному місці.
    if mission:getIsClient() and g_gui then
        self.settingsUI = SettingsUI.new(self.settings)

        local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
        if settingsPage then
            settingsPage.onFrameOpen = Utils.appendedFunction(settingsPage.onFrameOpen, function()
                self.settingsUI:inject()
                self.settingsUI:refreshUI()
            end)

            settingsPage.updateButtons = Utils.appendedFunction(settingsPage.updateButtons, function(frame)
                if self.settingsUI then
                    self.settingsUI:ensureResetButton(frame)
                end
            end)
        else
            Logging.error("RHM: InGameMenuSettingsFrame (pageSettings) not found!")
        end
    end

    -- EN: Console commands are always registered (server and client need them).
    -- UA: Консольні команди реєструються завжди (і сервер, і клієнт їх потребують).
    self.settingsGUI = SettingsGUI.new()
    self.settingsGUI:registerConsoleCommands()

    self.combineSettingsGUI = CombineSettingsGUI.new()

    -- EN: Load saved settings from XML before creating HUD (HUD reads settings in its constructor).
    -- UA: Завантажуємо збережені налаштування з XML перед створенням HUD (HUD читає налаштування в конструкторі).
    self.settings:load()

    -- EN: Create the draggable HUD overlay (client only, handles display of live data).
    -- UA: Створюємо перетягуваний HUD (тільки клієнт, відображає живі дані).
    if mission:getIsClient() then
        self.hud = DraggableHUD.new(self.modDirectory, self.settings)

        if not self.hud then
            Logging.error("RHM: Failed to create HUD instance!")
        end

        self.debug = true
        self.debugLogTimer = 0
        self.debugLogInterval = 1000 -- 1s interval
        print("RHM: Manager initialized (debug mode ON)")
    end

    -- EN: Create the visual calibration GUI (client only, for manual settings adjustment).
    -- UA: Створюємо візуальний GUI калібрування (тільки клієнт, для ручного регулювання).
    if mission:getIsClient() then
        self.calibrationGUI = CombineCalibrationGUI.new(modDirectory)
    end

    return self
end

-- EN: Toggles the calibration GUI open/closed for the given combine vehicle.
-- UA: Перемикає GUI калібрування відкритий/закритий для заданого комбайна.
function RealisticHarvestManager:toggleMenu(vehicle)
    if self.calibrationGUI then
        self.calibrationGUI:toggle(vehicle)
    end
end

-- EN: Called after the mission finishes loading. Initializes HUD overlay assets (textures, positions).
-- UA: Викликається після завершення завантаження місії. Ініціалізує ресурси HUD (текстури, позиції).
function RealisticHarvestManager:onMissionLoaded()
    if self.combineSettingsManager then
        self.combineSettingsManager:loadData()
    end
    if self.hud then
        self.hud:load()
    end
end

-- EN: Updates HUD and calibration GUI every frame.
-- UA: Оновлює HUD і GUI калібрування кожен кадр.
function RealisticHarvestManager:update(dt)
    -- EN: On client, automatically find the combine in the player's current vehicle hierarchy
    --     and set it as the active vehicle for the HUD.
    -- UA: На клієнті автоматично шукаємо комбайн в ієрархії поточного транспорту гравця
    --     і встановлюємо його як активний транспорт для HUD.
    if g_currentMission:getIsClient() and self.hud then
        local controlledVehicle = self:getControlledVehicle()
        local activeCombine = self:findCombineInHierarchy(controlledVehicle)
        
        if activeCombine ~= self.hud.vehicle then
            if self.debug then
                print(string.format("RHM: HUD vehicle changed from %s to %s", 
                    tostring(self.hud.vehicle and self.hud.vehicle:getFullName()), 
                    tostring(activeCombine and activeCombine:getFullName())))
            end
            self.hud:setVehicle(activeCombine)
        end
        
        self.hud:update(dt)
    end

    if self.calibrationGUI then
        self.calibrationGUI:update(dt)
    end

    -- EN: Optional: Periodic debug log dump.
    -- UA: Опціонально: періодичний дамб дебаг лога.
    if self.debug then
        self.debugLogTimer = self.debugLogTimer + dt
        if self.debugLogTimer >= self.debugLogInterval then
            self.debugLogTimer = 0
            -- print("RHM Manager Debug tick")
        end
    end
end

-- EN: Renders HUD overlays every frame.
-- UA: Рендерить HUD оверлеї кожен кадр.
function RealisticHarvestManager:draw()
    if self.hud then
        self.hud:draw()
    end
    if self.calibrationGUI then
        self.calibrationGUI:draw()
    end
end

-- EN: Helper to find a vehicle with the rhm_Combine specialization in the hierarchy.
--     Supports modular systems like NEXAT by searching parent, attacher, and implements.
-- UA: Допоміжна функція для пошуку транспорту зі спеціалізацією rhm_Combine в ієрархії.
--     Підтримує модульні системи як NEXAT, шукаючи в батьках, причепах та знаряддях.
function RealisticHarvestManager:findCombineInHierarchy(vehicle, visited)
    if not vehicle then return nil end
    visited = visited or {}
    if visited[vehicle] then return nil end
    visited[vehicle] = true

    -- 1. Check the explicit flag set in rhm_Combine:onLoad (Most reliable)
    if vehicle.isRealisticHarvester then
        return vehicle
    end

    -- 2. Check direct field (set in onLoad)
    if vehicle.spec_rhm_Combine then
        return vehicle
    end

    -- 3. Check via SpecializationManager
    local modName = self.modName or "FS25_RealisticHarvesting"
    local specName = modName .. ".rhm_Combine"
    local specEntry = g_specializationManager:getSpecializationByName(specName)
    if specEntry and specEntry.spec and vehicle.specializations then
        if SpecializationUtil.hasSpecialization(specEntry.spec, vehicle.specializations) then
            return vehicle
        end
    end

    -- Check attached implements
    if vehicle.getAttachedImplements then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            if implement.object then
                local combine = self:findCombineInHierarchy(implement.object, visited)
                if combine then
                    return combine
                end
            end
        end
    end

    -- Check attacher vehicle (upwards)
    if vehicle.getAttacherVehicle then
        local attacher = vehicle:getAttacherVehicle()
        if attacher then
            local combine = self:findCombineInHierarchy(attacher, visited)
            if combine then
                return combine
            end
        end
    end

    -- Check root vehicle (top-down)
    if vehicle.rootVehicle and vehicle.rootVehicle ~= vehicle then
        local combine = self:findCombineInHierarchy(vehicle.rootVehicle, visited)
        if combine then
            return combine
        end
    end

    return nil
end

-- EN: Captures mouse events for HUD drag-and-drop.
-- UA: Перехоплює події миші для перетягування HUD.
function RealisticHarvestManager:mouseEvent(posX, posY, isDown, isUp, button)
    if self.hud and self.hud:mouseEvent(posX, posY, isDown, isUp, button) then
        return true
    end
    if self.calibrationGUI and self.calibrationGUI:mouseEvent(posX, posY, isDown, isUp, button) then
        return true
    end
    return false
end

-- EN: Deletes all mod components and stops background processes.
-- UA: Видаляє всі компоненти мода і зупиняє фонові процеси.
function RealisticHarvestManager:delete()
    if self.hud then
        self.hud:delete()
        self.hud = nil
    end
end

-- EN: Helper to get the vehicle currently controlled by the player.
-- UA: Допоміжна функція для отримання транспорту, яким керує гравець.
function RealisticHarvestManager:getControlledVehicle()
    -- EN: Try standard FS25 paths for local controlled vehicle
    -- UA: Пробуємо стандартні шляхи FS25 для локально керованого транспорту
    if g_localPlayer and g_localPlayer:getCurrentVehicle() then
        return g_localPlayer:getCurrentVehicle()
    end

    if g_currentMission then
        if g_currentMission.controlledVehicle then
            return g_currentMission.controlledVehicle
        end
        if g_currentMission.hud and g_currentMission.hud.controlledVehicle then
            return g_currentMission.hud.controlledVehicle
        end
    end

    return nil
end

-- EN: Toggles the interactive mouse cursor for HUD manipulation.
-- UA: Перемикає інтерактивний курсор миші для маніпуляцій з HUD.
function RealisticHarvestManager:toggleCursor()
    if not self.hud then return end

    self.isCursorVisible = not self.isCursorVisible
    g_inputBinding:setShowMouseCursor(self.isCursorVisible)

    local vehicle = self:getControlledVehicle()

    if self.isCursorVisible then
        if g_currentMission then
            g_currentMission:showBlinkingWarning("RHM: HUD Cursor Enabled - Drag HUD to move", 3000)
        end
        if vehicle then
            RHMInputUtil.setCameraRotation(vehicle, false, self.savedCameraRotatableInfo)
        end
    else
        g_inputBinding:setShowMouseCursor(false)
        if vehicle then
            RHMInputUtil.setCameraRotation(vehicle, true, self.savedCameraRotatableInfo)
        end
    end
end

function RealisticHarvestManager:save()
    if self.combineSettingsManager then
        self.combineSettingsManager:saveData()
    end
end

function RealisticHarvestManager:onSaveSavegame(missionInfo)
    if g_realisticHarvestManager then
        g_realisticHarvestManager:save()
    end
end

FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, RealisticHarvestManager.onSaveSavegame)
