---@class RealisticHarvestManager
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

        self.debugLogTimer = 0
        self.debugLogInterval = 10000  -- EN: 10s interval for debug info in logs / UA: 10сек інтервал для відладки в логах
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
---@param vehicle table
function RealisticHarvestManager:toggleMenu(vehicle)
    if self.calibrationGUI then
        self.calibrationGUI:toggle(vehicle)
    end
end

-- EN: Called after the mission finishes loading. Initializes HUD overlay assets (textures, positions).
-- UA: Викликається після завершення завантаження місії. Ініціалізує ресурси HUD (текстури, позиції).
function RealisticHarvestManager:onMissionLoaded()
    if self.hud then
        self.hud:load()
    end
end

-- EN: Recursively searches the vehicle hierarchy for the first vehicle with spec_rhm_Combine.
--     Used to find the combine when the player is controlling a tractor in a Nexat modular system.
-- UA: Рекурсивно шукає в ієрархії транспорту перший транспортний засіб з spec_rhm_Combine.
--     Використовується для пошуку комбайна коли гравець керує трактором у модульній системі Nexat.
---@param vehicle table
---@param checkedVehicles table|nil EN: Visited nodes (prevents infinite recursion) / UA: Відвідані вузли (запобігає нескінченній рекурсії)
---@return table|nil
local function findCombineInHierarchy(vehicle, checkedVehicles)
    if not vehicle then return nil end

    checkedVehicles = checkedVehicles or {}
    if checkedVehicles[vehicle] then return nil end
    checkedVehicles[vehicle] = true

    if vehicle.spec_rhm_Combine then return vehicle end

    -- EN: Search up through parent (rootVehicle, attacherVehicle) and down through children.
    -- UA: Шукаємо вгору через батьків (rootVehicle, attacherVehicle) і вниз через дочірні.
    if vehicle.rootVehicle and not checkedVehicles[vehicle.rootVehicle] then
        local found = findCombineInHierarchy(vehicle.rootVehicle, checkedVehicles)
        if found then return found end
    end

    if vehicle.attacherVehicle and not checkedVehicles[vehicle.attacherVehicle] then
        local found = findCombineInHierarchy(vehicle.attacherVehicle, checkedVehicles)
        if found then return found end
    end

    if vehicle.getAttachedImplements then
        local implements = vehicle:getAttachedImplements()
        if implements then
            for _, implement in ipairs(implements) do
                if implement.object and not checkedVehicles[implement.object] then
                    local found = findCombineInHierarchy(implement.object, checkedVehicles)
                    if found then return found end
                end
            end
        end
    end

    return nil
end

-- EN: Returns the vehicle currently controlled by the local player.
--     Falls back through multiple methods to handle various FS25 versions/states.
-- UA: Повертає транспортний засіб, яким зараз керує локальний гравець.
--     Перебирає кілька методів для підтримки різних версій/станів FS25.
---@return table|nil
function RealisticHarvestManager:getControlledVehicle()
    local vehicle = g_currentMission.controlledVehicle
    if vehicle then return vehicle end

    if g_localPlayer and g_localPlayer:getCurrentVehicle() then
        return g_localPlayer:getCurrentVehicle()
    end

    if g_currentMission.vehicles then
        for _, v in pairs(g_currentMission.vehicles) do
            if v.getIsEntered and v:getIsEntered() then
                return v
            end
        end
    end

    return nil
end

-- EN: Called every game frame. Updates the calibration GUI and HUD data.
--     Searches the player's vehicle hierarchy for a combine spec to track live data.
--     Only updates HUD when a combine is found and running.
-- UA: Викликається щоразу за кадр гри. Оновлює GUI калібрування і дані HUD.
--     Шукає в ієрархії транспорту гравця специфікацію комбайна для відстеження живих даних.
--     Оновлює HUD тільки коли знайдено і запущено комбайн.
---@param dt number EN: Delta time in milliseconds / UA: Дельта часу в мілісекундах
function RealisticHarvestManager:update(dt)
    if self.calibrationGUI then
        self.calibrationGUI:update(dt)
    end

    if self.hud then
        local vehicle = self:getControlledVehicle()
        local combineVehicle = nil

        if vehicle then
            -- EN: For modular systems (Nexat), search from the root vehicle of the train.
            -- UA: Для модульних систем (Nexat), шукаємо від кореневого транспортного засобу.
            local searchRoot = vehicle.rootVehicle or vehicle
            combineVehicle = findCombineInHierarchy(searchRoot)
        end

        self.lastActiveCombine = combineVehicle

        if combineVehicle and combineVehicle:getIsTurnedOn() then
            self.hud:setVehicle(combineVehicle)
            self.hud:update(dt)
        else
            self.hud:setVehicle(nil)
        end
    end
end

-- EN: Called every game frame to draw the HUD and calibration GUI.
--     Suppresses all drawing when any game menu is open, when the game HUD is hidden,
--     or when the player is not in a vehicle.
-- UA: Викликається щоразу за кадр для відображення HUD і GUI калібрування.
--     Пригнічує всі малювання коли відкрите будь-яке меню гри, коли HUD гри прихований,
--     або коли гравець не в транспортному засобі.
function RealisticHarvestManager:draw()
    -- EN: Skip all drawing when any FS25 GUI screen is visible (e.g. ESC menu, map, settings).
    -- UA: Пропускаємо все малювання коли відкритий будь-який GUI екран FS25 (меню ESC, карта, налаштування).
    if g_gui:getIsGuiVisible() then
        return
    end

    -- EN: Calibration GUI is drawn above the HUD independently.
    -- UA: GUI калібрування малюється поверх HUD незалежно.
    if self.calibrationGUI then
        self.calibrationGUI:draw()
    end

    -- EN: Respect third-party HUD hider mods by checking game HUD visibility.
    -- UA: Поважаємо сторонні моди приховування HUD, перевіряючи видимість HUD гри.
    if g_currentMission and g_currentMission.hud and not g_currentMission.hud:getIsVisible() then
        return
    end

    local combineVehicle = self.lastActiveCombine

    -- EN: Don't draw HUD if the player has exited the vehicle.
    -- UA: Не малюємо HUD якщо гравець вийшов з транспортного засобу.
    local playerVehicle = self:getControlledVehicle()
    if not playerVehicle then
        return
    end

    if self.hud and combineVehicle and combineVehicle:getIsTurnedOn() then
        if self.settings and self.settings.showHUD then
            self.hud:draw()
        end
    end
end

-- EN: Cleans up all HUD and GUI resources on mission end.
-- UA: Очищає всі ресурси HUD і GUI при завершенні місії.
function RealisticHarvestManager:delete()
    if self.hud then
        self.hud:delete()
        self.hud = nil
    end
    if self.calibrationGUI then
        self.calibrationGUI:delete()
    end
end

-- EN: Routes mouse events to the calibration GUI first, then to the HUD (for dragging).
--     The GUI gets priority so it can capture events before the HUD.
-- UA: Направляє події миші спочатку до GUI калібрування, а потім до HUD (для перетягування).
--     GUI отримує пріоритет, щоб перехоплювати події до HUD.
---@param posX number
---@param posY number
---@param isDown boolean
---@param isUp boolean
---@param button number
---@return boolean handled
function RealisticHarvestManager:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.mission:getIsClient() then
        return
    end

    if self.calibrationGUI and self.calibrationGUI:mouseEvent(posX, posY, isDown, isUp, button) then
        return true
    end

    if self.hud then
        return self.hud:mouseEvent(posX, posY, isDown, isUp, button)
    end

    return false
end

-- EN: Toggles mouse cursor visibility for HUD drag interaction.
--     Disables camera rotation while cursor is visible.
-- UA: Перемикає видимість курсора миші для взаємодії з перетягуванням HUD.
--     Вимикає обертання камери поки курсор видимий.
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
