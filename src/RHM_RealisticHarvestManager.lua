-- EN: Central manager for the Realistic Harvesting mod. Created once per mission and stored
--     as the global g_realisticHarvestManager. Coordinates all mod subsystems:
--     settings, HUD, calibration GUI, console commands, and input events.
-- UA: Центральний менеджер мода Realistic Harvesting. Створюється один раз за місію і зберігається
--     як глобальний g_realisticHarvestManager. Координує всі підсистеми мода:
--     налаштування, HUD, GUI калібрування, консольні команди та події вводу.
RHM_RealisticHarvestManager = {}
local RealisticHarvestManager_mt = Class(RHM_RealisticHarvestManager)

-- EN: Initializes all mod subsystems: settings, UI, HUD, calibration GUI, and console commands.
--     Creates the HUD and settings UI only on the game client (not dedicated server).
-- UA: Ініціалізує всі підсистеми мода: налаштування, UI, HUD, GUI калібрування і консольні команди.
--     Створює HUD і settings UI тільки на клієнті гри (не на виділеному сервері).
function RHM_RealisticHarvestManager.new(mission, modDirectory, modName)
    local self = setmetatable({}, RealisticHarvestManager_mt)

    self.mission = mission
    self.modDirectory = modDirectory
    self.modName = modName

    -- EN: Initialize settings: the RHMSettingsManager handles XML I/O, RHMSettings holds all values.
    -- UA: Ініціалізуємо налаштування: RHMSettingsManager обробляє XML, RHMSettings зберігає значення.
    self.settingsManager = RHMSettingsManager.new()
    self.settings = RHMSettings.new(self.settingsManager)

    self.savedCameraRotatableInfo = {} -- EN: Stores camera rotatability before cursor mode / UA: Зберігає стан камери до режиму курсора

    -- EN: PREPEND to class onFrameOpen so our elements are in the layout BEFORE the base game
    --     computes positions. appendedFunction runs too late (after the frame is already drawn).
    -- UA: PREPEND до класу onFrameOpen — наші елементи потрапляють в layout ДО того як гра
    --     рахує позиції. appendedFunction запускається занадто пізно (кадр вже намальований).
    if mission:getIsClient() and g_gui then
        local settings = self.settings
        InGameMenuSettingsFrame.onFrameOpen = Utils.prependedFunction(
            InGameMenuSettingsFrame.onFrameOpen,
            function(settingsPage)
                pcall(function()
                    RHMSettingsUI.inject(settings)
                    RHMSettingsUI.refreshUI(settings)
                end)
            end
        )
    end

    -- EN: Console commands are always registered (server and client need them).
    -- UA: Консольні команди реєструються завжди (і сервер, і клієнт їх потребують).
    self.settingsGUI = RHMSettingsGUI.new()
    self.settingsGUI:registerConsoleCommands()

    self.combineSettingsGUI = RHMCombineSettingsGUI.new()

    -- EN: Load saved settings from XML before creating HUD (HUD reads settings in its constructor).
    -- UA: Завантажуємо збережені налаштування з XML перед створенням HUD (HUD читає налаштування в конструкторі).
    self.settings:load()

    -- EN: Create the draggable HUD overlay (client only, handles display of live data).
    -- UA: Створюємо перетягуваний HUD (тільки клієнт, відображає живі дані).
    if mission:getIsClient() then
        self.hud = RHMDraggableHUD.new(self.modDirectory, self.settings)

        if not self.hud then
            Logging.error("RHM: Failed to create HUD instance!")
        end

        self.debugLogTimer = 0
        self.debugLogInterval = 10000  -- EN: 10s interval for debug info in logs / UA: 10сек інтервал для відладки в логах
    end

    -- EN: Create the visual calibration GUI (client only, for manual settings adjustment).
    -- UA: Створюємо візуальний GUI калібрування (тільки клієнт, для ручного регулювання).
    if mission:getIsClient() then
        self.calibrationGUI = RHMCombineCalibrationGUI.new(modDirectory)
    end

    if mission:getIsClient() and RHM_CropFactorTuning and RHM_CropFactorTuning.isEnabled and RHM_CropFactorTuning.isEnabled() then
        self.cropFactorTuneGUI = RHM_CropFactorTuningGui.new(modDirectory)
        RHM_CropFactorTuning.registerConsoleCommand()
    end

    return self
end

-- EN: Toggles the calibration GUI open/closed for the given combine vehicle.
-- UA: Перемикає GUI калібрування відкритий/закритий для заданого комбайна.
function RHM_RealisticHarvestManager:toggleMenu(vehicle)
    if self.calibrationGUI then
        self.calibrationGUI:toggle(vehicle)
    end
end

-- EN: Called after the mission finishes loading. Initializes HUD overlay assets (textures, positions).
-- UA: Викликається після завершення завантаження місії. Ініціалізує ресурси HUD (текстури, позиції).
function RHM_RealisticHarvestManager:onMissionLoaded()
    if self.hud then
        self.hud:load()
    end
end

-- EN: Recursively searches the vehicle hierarchy for the first vehicle with spec_rhm_Combine.
--     Used to find the combine when the player is controlling a tractor in a Nexat modular system.
-- UA: Рекурсивно шукає в ієрархії транспорту перший транспортний засіб з spec_rhm_Combine.
--     Використовується для пошуку комбайна коли гравець керує трактором у модульній системі Nexat.
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
function RHM_RealisticHarvestManager:getControlledVehicle()
    local vehicle = g_currentMission.controlledVehicle
    if vehicle then return vehicle end

    if g_localPlayer and g_localPlayer:getCurrentVehicle() then
        return g_localPlayer:getCurrentVehicle()
    end

    -- EN: Avoid scanning all vehicles every frame; cache last entered vehicle until it is no longer entered.
    -- UA: Не обходимо всі транспорти щокадру; кешуємо останній «увійшов» поки гравець у ньому.
    local cached = self._rhmEnteredVehicleCache
    if cached and cached.getIsEntered and cached:getIsEntered() then
        return cached
    end

    self._rhmEnteredVehicleCache = nil
    if g_currentMission.vehicles then
        for _, v in pairs(g_currentMission.vehicles) do
            if v.getIsEntered and v:getIsEntered() then
                self._rhmEnteredVehicleCache = v
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
function RHM_RealisticHarvestManager:update(dt)
    if self.calibrationGUI then
        self.calibrationGUI:update(dt)
    end

    if self.cropFactorTuneGUI then
        self.cropFactorTuneGUI:update(dt)
    end

    if self.hud then
        local vehicle = self:getControlledVehicle()
        local combineVehicle = nil

        if vehicle then
            -- EN: For modular systems (Nexat), search from the root vehicle of the train.
            -- UA: Для модульних систем (Nexat), шукаємо від кореневого транспортного засобу.
            local searchRoot = vehicle.rootVehicle or vehicle
            local now = g_time
            local throttleMs = 250
            if vehicle == self._rhmHudVehicleRef and searchRoot == self._rhmHudSearchRootRef
                and self.lastActiveCombine and (now - (self._rhmHudHierarchySearchTime or 0)) < throttleMs then
                combineVehicle = self.lastActiveCombine
            else
                combineVehicle = findCombineInHierarchy(searchRoot)
                self._rhmHudHierarchySearchTime = now
                self._rhmHudVehicleRef = vehicle
                self._rhmHudSearchRootRef = searchRoot
            end
        else
            self._rhmHudVehicleRef = nil
            self._rhmHudSearchRootRef = nil
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
function RHM_RealisticHarvestManager:draw()
    -- EN: Skip all drawing when any FS25 GUI screen is visible (e.g. ESC menu, map, settings).
    -- UA: Пропускаємо все малювання коли відкритий будь-який GUI екран FS25 (меню ESC, карта, налаштування).
    if g_gui:getIsGuiVisible() then
        return
    end

    if self.cropFactorTuneGUI then
        self.cropFactorTuneGUI:draw()
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
function RHM_RealisticHarvestManager:delete()
    if self.hud then
        self.hud:delete()
        self.hud = nil
    end
    if self.cropFactorTuneGUI then
        self.cropFactorTuneGUI:delete()
        self.cropFactorTuneGUI = nil
    end
    if self.calibrationGUI then
        self.calibrationGUI:delete()
    end
end

-- EN: Routes mouse events to the calibration GUI first, then to the HUD (for dragging).
--     The GUI gets priority so it can capture events before the HUD.
-- UA: Направляє події миші спочатку до GUI калібрування, а потім до HUD (для перетягування).
--     GUI отримує пріоритет, щоб перехоплювати події до HUD.
function RHM_RealisticHarvestManager:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.mission:getIsClient() then
        return
    end

    if self.cropFactorTuneGUI and self.cropFactorTuneGUI:mouseEvent(posX, posY, isDown, isUp, button) then
        return true
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
function RHM_RealisticHarvestManager:toggleCursor()
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


