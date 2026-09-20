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

    -- EN: Expose public API through manager instance
    -- UA: Надаємо доступ до публічного API через екземпляр менеджера
    self.api = RHM_Api

    self.savedCameraRotatableInfo = {} -- EN: Stores camera rotatability before cursor mode / UA: Зберігає стан камери до режиму курсора

    -- EN: Multi-layer settings hooking to guarantee reliable injection into the game settings menu.
    -- UA: Багаторівневе підключення до налаштувань для надійної ін'єкції в меню гри.
    self:setupSettingsHooks()

    -- EN: Console commands are always registered (server and client need them).
    -- UA: Консольні команди реєструються завжди (і сервер, і клієнт їх потребують).
    self.settingsGUI = RHMSettingsGUI.new()
    self.settingsGUI:registerConsoleCommands()

    -- EN: Load saved settings from XML before creating HUD (HUD reads settings in its constructor).
    -- UA: Завантажуємо збережені налаштування з XML перед створенням HUD (HUD читає налаштування в конструкторі).
    self.settings:load()

    -- EN: Create the draggable HUD overlay (client only, handles display of live data).
    -- UA: Створюємо перетягуваний HUD (тільки клієнт, відображає живі дані).
    if mission:getIsClient() then
        if RHM_NotificationManager then
            self.notificationManager = RHM_NotificationManager.new(modDirectory, self.settings)
            RHM_NotificationManager.INSTANCE = self.notificationManager
        end

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

    return self
end

-- EN: Toggles the calibration GUI open/closed for the given combine vehicle.
-- UA: Перемикає GUI калібрування відкритий/закритий для заданого комбайна.
function RHM_RealisticHarvestManager:toggleMenu(vehicle)
    if self.calibrationGUI then
        self.calibrationGUI:toggle(vehicle)
    end
end

-- EN: Toggles the small telemetry HUD overlay visibility and saves setting.
-- UA: Перемикає видимість малого телеметричного HUD та зберігає налаштування.
function RHM_RealisticHarvestManager:toggleHUD()
    if not self.settings then return end
    self.settings.showHUD = not self.settings.showHUD
    if self.settings.save then
        self.settings:save()
    end
    local stateStr = self.settings.showHUD and "ON" or "OFF"
    if g_i18n then
        if self.settings.showHUD and g_i18n:hasText("ui_on") then
            stateStr = g_i18n:getText("ui_on")
        elseif not self.settings.showHUD and g_i18n:hasText("ui_off") then
            stateStr = g_i18n:getText("ui_off")
        end
    end
    local msg = string.format("RHM HUD: %s", stateStr)
    if g_currentMission and g_currentMission.showBlinkingWarning then
        g_currentMission:showBlinkingWarning(msg, 2000)
    end
end

---EN: Sets up hooks for InGameMenu and SettingsFrame to inject RHM settings.
---    Uses a multi-layered hooking strategy (InGameMenu.onMenuOpened, class onFrameOpen,
---EN: Sets up hooks for InGameMenu and SettingsFrame to inject RHM settings.
---    Hooks InGameMenu.onMenuOpened (matching the resilient pattern of mods like AdditionalContracts)
---    and InGameMenuSettingsFrame.onFrameOpen (class-level).
---    Strictly avoids overriding pageSettings.onFrameOpen on the instance to prevent shadowing class methods
---    and breaking other mods like FS25_additionalGameSettings.
---UA: Налаштовує хуки для InGameMenu та SettingsFrame для ін'єкції налаштувань RHM.
---    Хукає InGameMenu.onMenuOpened (патерн як у AdditionalContracts) та InGameMenuSettingsFrame.onFrameOpen на рівні класу.
---    Суворо уникає перезапису pageSettings.onFrameOpen на рівні екземпляра, щоб не тінити методи класу
---    і не ламати сторонні моди, такі як FS25_additionalGameSettings.
function RHM_RealisticHarvestManager:setupSettingsHooks()
    if not (self.mission and self.mission:getIsClient() and g_gui) then
        return
    end

    local settings = self.settings

    local function ensureAdditionalGameSettings()
        if g_additionalSettingsManager and g_additionalSettingsManager.settingsPage then
            pcall(function()
                if g_additionalSettingsManager.settingsPage.updateAlternating then
                    g_additionalSettingsManager.settingsPage:updateAlternating()
                end
            end)
        end
    end

    local function onSettingsFrameOpen(settingsPage)
        pcall(function()
            RHMSettingsUI.inject(settings)
            RHMSettingsUI.refreshUI(settings)
            ensureAdditionalGameSettings()
        end)
    end

    -- 1. Hook InGameMenu.onMenuOpened (Global menu hook, completely immune to pageSettings shadowing)
    if InGameMenu and InGameMenu.onMenuOpened and not self._inGameMenuOpenedHooked then
        InGameMenu.onMenuOpened = Utils.appendedFunction(
            InGameMenu.onMenuOpened,
            function(menu)
                pcall(function()
                    RHMSettingsUI.inject(settings)
                    RHMSettingsUI.refreshUI(settings)
                    ensureAdditionalGameSettings()
                end)
            end
        )
        self._inGameMenuOpenedHooked = true
    end

    -- 2. Hook InGameMenuSettingsFrame.onFrameOpen (Class-level hook)
    if InGameMenuSettingsFrame and InGameMenuSettingsFrame.onFrameOpen and not self._settingsFrameClassHooked then
        InGameMenuSettingsFrame.onFrameOpen = Utils.prependedFunction(
            InGameMenuSettingsFrame.onFrameOpen,
            onSettingsFrameOpen
        )
        self._settingsFrameClassHooked = true
    end
end

-- EN: Called after the mission finishes loading. Initializes HUD overlay assets (textures, positions).
-- UA: Викликається після завершення завантаження місії. Ініціалізує ресурси HUD (текстури, позиції).
function RHM_RealisticHarvestManager:onMissionLoaded()
    self:setupSettingsHooks()

    if self.mission and self.mission:getIsClient() then
        pcall(function()
            RHMSettingsUI.inject(self.settings)
            RHMSettingsUI.refreshUI(self.settings)
        end)
    end

    if self.notificationManager then
        self.notificationManager:load()
    end
    if self.hud then
        self.hud:load()
    end
end

local SEARCH_CHECKED = {}

local function findCombineInHierarchyInternal(vehicle)
    if not vehicle or SEARCH_CHECKED[vehicle] then return nil end
    SEARCH_CHECKED[vehicle] = true

    if vehicle.spec_rhm_Combine then return vehicle end

    -- EN: Search up through parent (rootVehicle, attacherVehicle) and down through children.
    -- UA: Шукаємо вгору через батьків (rootVehicle, attacherVehicle) і вниз через дочірні.
    if vehicle.rootVehicle and not SEARCH_CHECKED[vehicle.rootVehicle] then
        local found = findCombineInHierarchyInternal(vehicle.rootVehicle)
        if found then return found end
    end

    if vehicle.attacherVehicle and not SEARCH_CHECKED[vehicle.attacherVehicle] then
        local found = findCombineInHierarchyInternal(vehicle.attacherVehicle)
        if found then return found end
    end

    if vehicle.getAttachedImplements then
        local implements = vehicle:getAttachedImplements()
        if implements then
            for _, implement in ipairs(implements) do
                if implement.object and not SEARCH_CHECKED[implement.object] then
                    local found = findCombineInHierarchyInternal(implement.object)
                    if found then return found end
                end
            end
        end
    end

    return nil
end

-- EN: Recursively searches the vehicle hierarchy for the first vehicle with spec_rhm_Combine.
--     Reuses a module-level table to eliminate garbage collection overhead.
-- UA: Рекурсивно шукає в ієрархії транспорту перший транспортний засіб з spec_rhm_Combine.
--     Перевикористовує таблицю на рівні модуля для усунення навантаження на GC.
local function findCombineInHierarchy(vehicle)
    if not vehicle then return nil end
    for k in pairs(SEARCH_CHECKED) do
        SEARCH_CHECKED[k] = nil
    end
    return findCombineInHierarchyInternal(vehicle)
end

-- EN: Returns the vehicle currently controlled by the local player.
--     Falls back through multiple methods to handle various FS25 versions/states.
-- UA: Повертає транспортний засіб, яким зараз керує локальний гравець.
--     Перебирає кілька методів для підтримки різних версій/станів FS25.
function RHM_RealisticHarvestManager:getControlledVehicle()
    if g_localPlayer and g_localPlayer.getCurrentVehicle then
        local v = g_localPlayer:getCurrentVehicle()
        if v then return v end
    end
    if g_currentMission then
        if g_currentMission.getControlledVehicle then
            local v = g_currentMission:getControlledVehicle()
            if v then return v end
        end
        if g_currentMission.controlledVehicle then
            return g_currentMission.controlledVehicle
        end
        if g_currentMission.player and g_currentMission.player.getCurrentVehicle then
            local v = g_currentMission.player:getCurrentVehicle()
            if v then return v end
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
    -- EN: Dedicated servers have no local client, HUD or UI. Skip client updates.
    -- UA: Виділені сервери не мають локального клієнта, HUD або UI. Пропускаємо клієнтські оновлення.
    if not self.mission:getIsClient() then
        return
    end

    -- EN: If any game GUI (ESC pause menu, shop, map) is open, cleanly close our calibration GUI
    -- UA: Якщо відкритий будь-який GUI гри (меню паузи ESC, магазин, карта), чисто закриваємо GUI калібрування
    if g_gui and g_gui.getIsGuiVisible and g_gui:getIsGuiVisible() then
        if self.calibrationGUI and self.calibrationGUI.isOpen then
            self.calibrationGUI:close()
        end
        if self.isCursorVisible then
            self.isCursorVisible = false
            if g_inputBinding and g_inputBinding.setShowMouseCursor then
                g_inputBinding:setShowMouseCursor(false)
            end
        end
        return
    end

    if self.calibrationGUI then
        self.calibrationGUI:update(dt)
    end

    local controlledVehicle = self:getControlledVehicle()
    self.lastControlledVehicle = controlledVehicle

    if self.hud then
        local vehicle = controlledVehicle
        local combineVehicle = nil

        if vehicle then
            -- EN: For modular systems (Nexat), search from the root vehicle of the train.
            -- UA: Для модульних систем (Nexat), шукаємо від кореневого транспортного засобу.
            local searchRoot = vehicle.rootVehicle or vehicle
            local now = g_time
            local throttleMs = 250
            
            -- EN: Cache optimization: only search hierarchy if vehicle changed or timeout expired (works for both combines and non-combines)
            -- UA: Оптимізація кешу: шукаємо ієрархію тільки якщо транспорт змінився або таймаут минув (працює як для комбайнів, так і для не-комбайнів)
            if vehicle == self._rhmHudVehicleRef and searchRoot == self._rhmHudSearchRootRef
                and (now - (self._rhmHudHierarchySearchTime or 0)) < throttleMs then
                combineVehicle = self.lastActiveCombine
            else
                combineVehicle = findCombineInHierarchy(searchRoot)
                self._rhmHudHierarchySearchTime = now
                self._rhmHudVehicleRef = vehicle
                self._rhmHudSearchRootRef = searchRoot
            end
        else
            -- EN: Clear cache when no vehicle controlled
            -- UA: Очищаємо кеш коли немає контрольованого транспорту
            self._rhmHudVehicleRef = nil
            self._rhmHudSearchRootRef = nil
        end

        self.lastActiveCombine = combineVehicle

        if combineVehicle then
            self.hud:setVehicle(combineVehicle)
            self.hud:update(dt)
        else
            self.hud:setVehicle(nil)
        end
    end

    if self.notificationManager then
        self.notificationManager:update(dt, self.lastActiveCombine)
    end
end

-- EN: Called every game frame to draw the HUD and calibration GUI.
--     Suppresses all drawing when any game menu is open, when the game HUD is hidden,
--     or when the player is not in a vehicle.
-- UA: Викликається щоразу за кадр для відображення HUD і GUI калібрування.
--     Пригнічує всі малювання коли відкрите будь-яке меню гри, коли HUD гри прихований,
--     або коли гравець не в транспортному засобі.
function RHM_RealisticHarvestManager:draw()
    if not self.mission:getIsClient() then
        return
    end

    -- EN: Skip all drawing when any FS25 GUI screen is visible (e.g. ESC menu, map, settings).
    -- UA: Пропускаємо все малювання коли відкритий будь-який GUI екран FS25 (меню ESC, карта, налаштування).
    if g_gui and g_gui.getIsGuiVisible and g_gui:getIsGuiVisible() then
        return
    end

    -- EN: Calibration GUI is drawn above the HUD independently.
    -- UA: GUI калібрування малюється поверх HUD незалежно.
    if self.calibrationGUI then
        self.calibrationGUI:draw()
    end

    -- EN: Respect third-party HUD hider mods by checking game HUD visibility.
    -- UA: Поважаємо сторонні моди приховування HUD, перевіряючи видимість HUD гри.
    if g_currentMission and g_currentMission.hud and g_currentMission.hud.getIsVisible and not g_currentMission.hud:getIsVisible() then
        return
    end

    -- EN: Notification and tutorial panel drawn independently over HUD
    -- UA: Панель сповіщень та підказок малюється незалежно поверх HUD
    if self.notificationManager then
        self.notificationManager:draw()
    end

    local combineVehicle = self.lastActiveCombine
    if not (self.hud and combineVehicle) then
        return
    end

    -- EN: Don't draw HUD if the player has exited the vehicle. Reuses cached vehicle from update() to avoid duplicate API calls.
    -- UA: Не малюємо HUD якщо гравець вийшов з транспортного засобу. Перевикористовує кеш з update() без повторних викликів API.
    local playerVehicle = self.lastControlledVehicle or self:getControlledVehicle()
    if not playerVehicle then
        return
    end

    if self.settings and self.settings.showHUD then
        self.hud:draw()
    end
end

-- EN: Cleans up all HUD and GUI resources on mission end.
-- UA: Очищає всі ресурси HUD і GUI при завершенні місії.
function RHM_RealisticHarvestManager:delete()
    if self.notificationManager then
        self.notificationManager:delete()
        self.notificationManager = nil
        RHM_NotificationManager.INSTANCE = nil
    end
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
function RHM_RealisticHarvestManager:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.mission:getIsClient() then
        return
    end

    if self.notificationManager and self.notificationManager:mouseEvent(posX, posY, isDown, isUp, button) then
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



-- EN: Key event handler. Allows pressing ESC to cleanly close calibration GUI.
-- UA: Обробник подій клавіатури. Дозволяє клавішею ESC чисто закривати GUI калібрування.
function RHM_RealisticHarvestManager:keyEvent(unicode, sym, modifier, isDown)
    if isDown and self.notificationManager and self.notificationManager:keyEvent(unicode, sym, modifier, isDown) then
        return true
    end

    if isDown and sym == Input.KEY_esc then
        if self.calibrationGUI and self.calibrationGUI.isOpen then
            self.calibrationGUI:close()
            return true
        end
    end
    return false
end

-- ============================================================================
-- EN: PUBLIC API FOR THIRD-PARTY MODS (DELEGATED TO RHM_Api)
-- UA: ПУБЛІЧНИЙ API ДЛЯ СТОРОННІХ МОДІВ (ДЕЛЕГУЄТЬСЯ ДО RHM_Api)
-- ============================================================================

---EN: Returns current feed-rate engine load (0 to 100+ %) for a given vehicle or active combine.
---UA: Повертає поточне навантаження двигуна від збирання (0 до 100+ %) для вказаного або активного комбайна.
---@param vehicle table|nil Optional vehicle object. If nil, uses currently controlled vehicle.
---@return number engineLoad Current load percentage (0.0 if not harvesting or not an RHM combine).
function RHM_RealisticHarvestManager:getEngineLoad(vehicle)
    if RHM_Api and RHM_Api.getEngineLoad then
        return RHM_Api.getEngineLoad(vehicle)
    end
    local target = vehicle or self:getControlledVehicle()
    if not target then return 0.0 end
    local combine = findCombineInHierarchy(target.rootVehicle or target)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator:getEngineLoad() or 0.0
    end
    return 0.0
end

---EN: Returns normalized engine load factor strictly clamped between 0.0 and 1.0 (for telemetry and wear integration).
---UA: Повертає нормалізоване навантаження двигуна від 0.0 до 1.0 (для інтеграції телеметрії та зносу).
---@param vehicle table|nil
---@return number normalizedLoad (0.0 .. 1.0)
function RHM_RealisticHarvestManager:getNormalizedEngineLoad(vehicle)
    if RHM_Api and RHM_Api.getNormalizedEngineLoad then
        return RHM_Api.getNormalizedEngineLoad(vehicle)
    end
    local raw = self:getEngineLoad(vehicle)
    return math.max(0.0, math.min(1.0, raw / 100.0))
end

---EN: Checks if a vehicle is an active combine managed by Realistic Harvesting.
---UA: Перевіряє чи є транспорт активним комбайном під керуванням Realistic Harvesting.
---@param vehicle table|nil
---@return boolean
function RHM_RealisticHarvestManager:isRHMActive(vehicle)
    if RHM_Api and RHM_Api.isRHMActive then
        return RHM_Api.isRHMActive(vehicle)
    end
    local target = vehicle or self:getControlledVehicle()
    if not target then return false end
    local combine = findCombineInHierarchy(target.rootVehicle or target)
    return (combine ~= nil and combine.spec_rhm_Combine ~= nil)
end

---EN: Returns live telemetry data table (load, moisture, cropLoss, tonPerHour, yield, etc.).
---UA: Повертає таблицю живої телеметрії (навантаження, вологість, втрати, продуктивність, врожайність тощо).
---@param vehicle table|nil
---@return table|nil
function RHM_RealisticHarvestManager:getVehicleData(vehicle)
    if RHM_Api and RHM_Api.getTelemetry then
        return RHM_Api.getTelemetry(vehicle)
    end
    local target = vehicle or self:getControlledVehicle()
    if not target then return nil end
    local combine = findCombineInHierarchy(target.rootVehicle or target)
    if combine and combine.spec_rhm_Combine then
        return combine.spec_rhm_Combine.data
    end
    return nil
end
