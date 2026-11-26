-- EN: Central manager for the Realistic Harvesting mod. Created once per mission and stored
--     as the global g_realisticHarvestManager. Coordinates all mod subsystems:
--     settings, HUD, calibration GUI, console commands, and input events.
-- UA: Центральний менеджер мода Realistic Harvesting. Створюється один раз за місію і зберігається
--     як глобальний g_realisticHarvestManager. Координує всі підсистеми мода:
--     налаштування, HUD, GUI калібрування, консольні команди та події вводу.
RHM_RealisticHarvestManager = {}
local RealisticHarvestManager_mt = Class(RHM_RealisticHarvestManager)
local ATLAS_SIZE_1024 = {1024, 1024}

local function renderClearOverlaySlice(overlay, sx, sy, sw, sh, uvs, r, g, b, a)
    if sw <= 0 or sh <= 0 or uvs == nil then
        return
    end
    overlay:setPosition(sx, sy)
    overlay:setDimension(sw, sh)
    overlay:setUVs(uvs)
    overlay:setColor(r, g, b, a)
    overlay:render()
end

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

    -- EN: Initialize server-authoritative harvest tracker for trip odometer and fleet history
    -- UA: Ініціалізуємо серверний трекер збору врожаю для одометра поля та історії техніки
    if RHM_HarvestTracker then
        self.harvestTracker = RHM_HarvestTracker.new()
    end

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
        self:initClearIndicatorOverlay()
        self.calibrationGUI = RHMCombineCalibrationGUI.new(modDirectory)
        self:registerGlobalActionEvents()
    end

    return self
end

-- EN: Toggles the calibration GUI open/closed for the given combine vehicle.
--     Validates that target vehicle belongs to the currently entered player vehicle hierarchy.
-- UA: Перемикає GUI калібрування відкритий/закритий для заданого комбайна.
--     Перевіряє, що цільовий транспорт належить до ієрархії поточної машини гравця.
function RHM_RealisticHarvestManager:toggleMenu(vehicle)
    if not self.calibrationGUI then return end

    local controlled = self:getControlledVehicle()
    if not controlled then return end

    -- Verify vehicle belongs to the current controlled vehicle hierarchy
    local target = vehicle
    local controlledRoot = (controlled.getRootVehicle and controlled:getRootVehicle()) or controlled.rootVehicle or controlled
    local targetRoot = target and ((target.getRootVehicle and target:getRootVehicle()) or target.rootVehicle or target)
    if not targetRoot or targetRoot ~= controlledRoot then
        target = controlled
    end

    self.calibrationGUI:toggle(target)
end

-- EN: Toggles interactive mouse cursor mode for HUD interaction and camera suspension.
-- UA: Перемикає режим інтерактивного курсора миші для взаємодії з HUD та призупинення камери.
function RHM_RealisticHarvestManager:toggleMouseCursor(vehicle)
    if not self.mission or not self.mission:getIsClient() then return end

    -- If calibration tablet is open, cursor is already active and managed by it
    if self.calibrationGUI and self.calibrationGUI.isOpen then
        return
    end

    local now = g_time or 0
    if self.lastCursorToggleTime and (now - self.lastCursorToggleTime) < 250 then
        return
    end
    self.lastCursorToggleTime = now

    local targetVehicle = vehicle or self:getControlledVehicle()
    self:setMouseCursorVisible(not self.isCursorVisible, targetVehicle)
end

-- EN: Sets cursor visibility state and freezes or restores vehicle camera rotation.
-- UA: Встановлює стан видимості курсора та заморожує або відновлює обертання камери.
function RHM_RealisticHarvestManager:setMouseCursorVisible(visible, vehicle)
    if not self.mission or not self.mission:getIsClient() then return end

    local targetVehicle = vehicle or self:getControlledVehicle()
    self.isCursorVisible = visible == true
    self.lastCursorToggleTime = g_time or 0

    if g_inputBinding and g_inputBinding.setShowMouseCursor then
        g_inputBinding:setShowMouseCursor(self.isCursorVisible)
    end

    local camTarget = targetVehicle
    if camTarget and camTarget.spec_enterable then
        RHMInputUtil.setCameraRotation(camTarget, not self.isCursorVisible, self.savedCameraRotatableInfo)
    end
end

-- EN: Shows the fullscreen Harvest History and Trip Telemetry GUI.
-- UA: Відкриває повноекранне меню історії збору врожаю та одометра поля.
function RHM_RealisticHarvestManager:showHarvestHistoryGUI(targetVehicle)
    if not self.harvestHistoryGUI then
        self:loadHarvestHistoryGUI()
    end
    if self.harvestHistoryGUI then
        self.harvestHistoryGUI.callerVehicle = targetVehicle
    end
    if g_gui then
        if g_gui.currentGui == nil then
            g_gui:showGui("RHM_HarvestHistoryGUI")
        elseif g_gui.currentGuiName == "RHM_HarvestHistoryGUI" then
            g_gui:showGui("")
        end
    end
end

---EN: Registers global action events for the on-foot player context and general mission lifecycle.
---UA: Реєструє глобальні події дій для контексту пішого гравця та життєвого циклу місії.
function RHM_RealisticHarvestManager:registerGlobalActionEvents()
    if not (self.mission and self.mission:getIsClient()) then
        return
    end

    if not self._globalActionEventsHooked then
        self._globalActionEventsHooked = true

        -- Hook PlayerInputComponent for on-foot player context (FS25/FS22)
        if PlayerInputComponent and PlayerInputComponent.registerActionEvents then
            PlayerInputComponent.registerActionEvents = Utils.appendedFunction(
                PlayerInputComponent.registerActionEvents,
                function(inputComponent)
                    if not (inputComponent and inputComponent.player and inputComponent.player.isOwner) then
                        return
                    end
                    if not (g_inputBinding and InputAction and InputAction.RHM_OPEN_HARVEST_MENU) then
                        return
                    end

                    local contextName = PlayerInputComponent.INPUT_CONTEXT_NAME or "PLAYER"
                    g_inputBinding:beginActionEventsModification(contextName)
                    local _, eventId = g_inputBinding:registerActionEvent(
                        InputAction.RHM_OPEN_HARVEST_MENU,
                        self,
                        self.onGlobalActionOpenHarvestMenu,
                        false, -- triggerUp
                        true,  -- triggerDown
                        false, -- triggerAlways
                        true,  -- startActive
                        nil,
                        true
                    )
                    if eventId then
                        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
                        if g_i18n and g_i18n:hasText("input_RHM_OPEN_HARVEST_MENU") then
                            g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_RHM_OPEN_HARVEST_MENU"))
                        end
                        g_inputBinding:setActionEventTextVisibility(eventId, true)
                    end
                    if InputAction.RHM_CLEAR_CLOG then
                        local _, clearEventId = g_inputBinding:registerActionEvent(
                            InputAction.RHM_CLEAR_CLOG,
                            self,
                            self.onGlobalActionClearClog,
                            true,  -- triggerUp
                            true,  -- triggerDown
                            false, -- triggerAlways
                            true,  -- startActive
                            nil,
                            true
                        )
                        if clearEventId then
                            self._clearClogEventId = clearEventId
                            g_inputBinding:setActionEventTextPriority(clearEventId, GS_PRIO_VERY_HIGH)
                            if g_i18n and g_i18n:hasText("input_RHM_CLEAR_CLOG") then
                                g_inputBinding:setActionEventText(clearEventId, g_i18n:getText("input_RHM_CLEAR_CLOG"))
                            end
                            g_inputBinding:setActionEventTextVisibility(clearEventId, false)
                        end
                    end
                    g_inputBinding:endActionEventsModification()
                end
            )
        end

        -- Hook FSBaseMission.registerActionEvents as an additional mission-level registration fallback
        if FSBaseMission and FSBaseMission.registerActionEvents then
            FSBaseMission.registerActionEvents = Utils.appendedFunction(
                FSBaseMission.registerActionEvents,
                function(mission)
                    if not (mission and mission:getIsClient()) then return end
                    if not (g_inputBinding and InputAction and InputAction.RHM_OPEN_HARVEST_MENU) then
                        return
                    end
                    local _, eventId = g_inputBinding:registerActionEvent(
                        InputAction.RHM_OPEN_HARVEST_MENU,
                        self,
                        self.onGlobalActionOpenHarvestMenu,
                        false,
                        true,
                        false,
                        true,
                        nil,
                        true
                    )
                    if eventId then
                        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
                        if g_i18n and g_i18n:hasText("input_RHM_OPEN_HARVEST_MENU") then
                            g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_RHM_OPEN_HARVEST_MENU"))
                        end
                        g_inputBinding:setActionEventTextVisibility(eventId, true)
                    end
                end
            )
        end

        -- Ensure non-combine vehicle hooks (Enterable, Drivable, Vehicle) are applied
        if rhm_Combine and rhm_Combine.applyGlobalVehicleHooks then
            rhm_Combine.applyGlobalVehicleHooks()
        end
    end

    -- If player is already active on foot during post-load, ensure immediate binding
    if g_currentMission and g_currentMission.player and g_currentMission.player.isOwner and g_inputBinding and InputAction and InputAction.RHM_OPEN_HARVEST_MENU then
        local contextName = (PlayerInputComponent and PlayerInputComponent.INPUT_CONTEXT_NAME) or "PLAYER"
        g_inputBinding:beginActionEventsModification(contextName)
        local _, eventId = g_inputBinding:registerActionEvent(
            InputAction.RHM_OPEN_HARVEST_MENU,
            self,
            self.onGlobalActionOpenHarvestMenu,
            false,
            true,
            false,
            true,
            nil,
            true
        )
        if eventId then
            g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
            if g_i18n and g_i18n:hasText("input_RHM_OPEN_HARVEST_MENU") then
                g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_RHM_OPEN_HARVEST_MENU"))
            end
            g_inputBinding:setActionEventTextVisibility(eventId, true)
        end
        g_inputBinding:endActionEventsModification()
    end
end

---EN: Action event callback triggered when pressing Shift+J outside of a combine vehicle.
---UA: Зворотний виклик події дії при натисканні Shift+J поза комбайном.
function RHM_RealisticHarvestManager:onGlobalActionOpenHarvestMenu(actionName, inputValue, callbackState, isAnalog)
    local mgr = self
    if not (mgr and mgr.showHarvestHistoryGUI) then
        mgr = g_realisticHarvestManager
    end
    if mgr and mgr.showHarvestHistoryGUI then
        mgr:showHarvestHistoryGUI(nil)
    end
end

-- EN: Loads GUI profiles and XML frames for the native TabbedMenu harvest history dialog.
-- UA: Завантажує профілі та XML-фрейми для нативного діалогу журналу врожаю (TabbedMenu).
function RHM_RealisticHarvestManager:loadHarvestHistoryGUI()
    if not (g_gui and self.mission and self.mission:getIsClient()) then return end

    g_gui:loadProfiles(self.modDirectory .. "src/gui/guiProfiles.xml")

    local tripFrame = RHM_HarvestHistoryTrip.new(g_i18n)
    g_gui:loadGui(self.modDirectory .. "src/gui/frames/RHM_HarvestHistoryTrip.xml", "RHM_HarvestHistoryTrip", tripFrame, true)

    local fieldsFrame = RHM_HarvestHistoryFields.new(g_i18n)
    g_gui:loadGui(self.modDirectory .. "src/gui/frames/RHM_HarvestHistoryFields.xml", "RHM_HarvestHistoryFields", fieldsFrame, true)

    local fleetFrame = RHM_HarvestHistoryFleet.new(g_i18n)
    g_gui:loadGui(self.modDirectory .. "src/gui/frames/RHM_HarvestHistoryFleet.xml", "RHM_HarvestHistoryFleet", fleetFrame, true)

    local analyticsFrame = RHM_HarvestHistoryAnalytics.new(g_i18n)
    g_gui:loadGui(self.modDirectory .. "src/gui/frames/RHM_HarvestHistoryAnalytics.xml", "RHM_HarvestHistoryAnalytics", analyticsFrame, true)

    self.harvestHistoryGUI = RHM_HarvestHistoryGUI.new(g_messageCenter, g_i18n, g_inputBinding)
    g_gui:loadGui(self.modDirectory .. "src/gui/RHM_HarvestHistoryGUI.xml", "RHM_HarvestHistoryGUI", self.harvestHistoryGUI)
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
            if g_additionalSettingsManager.settingsPage.updateAlternating then
                g_additionalSettingsManager.settingsPage:updateAlternating()
            end
        end
    end

    local function onSettingsFrameOpen()
        RHMSettingsUI.inject(settings)
        RHMSettingsUI.refreshUI(settings)
        ensureAdditionalGameSettings()
    end

    -- 1. Hook InGameMenu.onMenuOpened (Global menu hook, completely immune to pageSettings shadowing)
    if InGameMenu and InGameMenu.onMenuOpened and not self._inGameMenuOpenedHooked then
        InGameMenu.onMenuOpened = Utils.appendedFunction(
            InGameMenu.onMenuOpened,
            function()
                RHMSettingsUI.inject(settings)
                RHMSettingsUI.refreshUI(settings)
                ensureAdditionalGameSettings()
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
    if self.mission:getIsServer() and self.harvestTracker then
        self.harvestTracker:onVehiclesChanged()
        g_messageCenter:subscribe(MessageType.VEHICLE_REMOVED, self.harvestTracker.onVehiclesChanged, self.harvestTracker)
    end

    if self.mission and self.mission:getIsClient() then
        RHMSettingsUI.inject(self.settings)
        RHMSettingsUI.refreshUI(self.settings)
    end

    if self.notificationManager then
        self.notificationManager:load()
    end
    if self.hud then
        self.hud:load()
    end

    if self.mission and self.mission:getIsClient() then
        self:loadHarvestHistoryGUI()
        self:registerGlobalActionEvents()
    end
end

-- EN: Resolves the active combine vehicle using canonical RHM_Api traversal.
-- UA: Знаходить активний комбайн через канонічний обхід RHM_Api.
local function findCombineInHierarchy(vehicle)
    if RHM_Api and RHM_Api.findCombine then
        return RHM_Api.findCombine(vehicle)
    end
    return vehicle
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
local function showWarningModal(l10nKey, fallbackText)
    local warnText = (g_i18n and l10nKey and g_i18n:hasText(l10nKey))
        and g_i18n:getText(l10nKey)
        or fallbackText
    if InfoDialog ~= nil and type(InfoDialog.show) == "function" then
        InfoDialog.show(warnText, nil, nil, DialogElement and DialogElement.TYPE_WARNING or nil)
    elseif g_gui ~= nil and type(g_gui.showInfoDialog) == "function" then
        g_gui:showInfoDialog({
            text = warnText,
            dialogType = DialogElement and DialogElement.TYPE_WARNING or nil,
            isCloseAllowed = true
        })
    end
end

function RHM_RealisticHarvestManager:update(dt)
    -- EN: Detect unofficial external runtime patches and mutually exclusive combine physics controllers
    -- UA: Виявляємо сторонні модифікації внутрішніх функцій у рантаймі та конфліктуючі контролери фізики комбайна
    if RHM_ModCompatibility and (not self._integrityWarned or not self._conflictWarned) then
        self._integrityCheckTimer = (self._integrityCheckTimer or 0) + (dt or 0)
        self._integrityCheckStage = self._integrityCheckStage or 0
        local shouldProbe = false
        local isInitialStage = false
        if self._integrityCheckStage == 0 and self._integrityCheckTimer >= 3500 then
            self._integrityCheckStage = 1
            shouldProbe = true
            isInitialStage = true
        elseif self._integrityCheckStage == 1 and self._integrityCheckTimer >= 12000 then
            self._integrityCheckStage = 2
            shouldProbe = true
        end

        if shouldProbe then
            if not self._integrityWarned and RHM_ModCompatibility.checkRuntimeIntegrity then
                local isTampered, tamperedList = RHM_ModCompatibility.checkRuntimeIntegrity()
                if isTampered and tamperedList then
                    if not self._integrityLogged then
                        self._integrityLogged = true
                        Logging.warning(
                            "RHM [Integrity]: External script modified internal RHM function(s): %s. "
                                .. "Unofficial overrides may cause inaccurate load, speed limiting, or crop losses.",
                            table.concat(tamperedList, ", ")
                        )
                    end
                    if self.mission and self.mission:getIsClient() then
                        self._integrityPendingModal = true
                    else
                        self._integrityWarned = true
                    end
                end
            end

            if isInitialStage and not self._conflictWarned and RHM_ModCompatibility.checkConflictingCombineMods then
                local hasConflict, conflictModName = RHM_ModCompatibility.checkConflictingCombineMods()
                if hasConflict then
                    if not self._conflictLogged then
                        self._conflictLogged = true
                        Logging.warning(
                            "RHM [Compatibility]: Conflicting combine physics controller detected (%s). "
                                .. "Running multiple combine load/speed controllers simultaneously may cause erratic speed limits or inaccurate telemetry. "
                                .. "Please keep only one enabled in this savegame.",
                            tostring(conflictModName)
                        )
                    end
                    if self.mission and self.mission:getIsClient() then
                        self._conflictPendingModal = true
                    else
                        self._conflictWarned = true
                    end
                end
            end
        end

        if self.mission and self.mission:getIsClient() and (self._integrityPendingModal or self._conflictPendingModal) then
            local isGuiVisible = g_gui and g_gui.getIsGuiVisible and g_gui:getIsGuiVisible()
            if not isGuiVisible then
                if self._integrityPendingModal then
                    self._integrityPendingModal = false
                    self._integrityWarned = true
                    showWarningModal(
                        "rhm_warn_external_physics_override",
                        "Warning: An external mod has modified internal Realistic Harvesting physics functions outside the official API. "
                            .. "This may cause inaccurate engine load, stuck speed limits, or incorrect crop losses. "
                            .. "Please disable unofficial third-party addons that patch this mod."
                    )
                elseif self._conflictPendingModal then
                    self._conflictPendingModal = false
                    self._conflictWarned = true
                    showWarningModal(
                        "rhm_warn_conflicting_combine_mod",
                        "Warning: Another combine realism or speed/load controller mod is loaded alongside Realistic Harvesting. "
                            .. "Running two combine physics controllers at the same time may cause conflicting speed limits, engine loads, and crop losses. "
                            .. "Please keep only one enabled in this savegame."
                    )
                end
            end
        end
    end

    -- EN: Server-side tracker ticks to broadcast stats to clients
    -- UA: Серверний трекер оновлює стан та транслює статистику клієнтам
    if self.harvestTracker then
        self.harvestTracker:update(dt)
    end

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
            self:setMouseCursorVisible(false)
        end
        return
    end

    local controlledVehicle = self:getControlledVehicle()
    if self.lastControlledVehicle ~= nil and self.lastControlledVehicle ~= controlledVehicle then
        if self.calibrationGUI and self.calibrationGUI.isOpen then
            self.calibrationGUI:close()
        end
        if self.isCursorVisible then
            self:setMouseCursorVisible(false, self.lastControlledVehicle)
        end
    end
    self.lastControlledVehicle = controlledVehicle

    if self.calibrationGUI then
        self.calibrationGUI:update(dt)
    end

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

    -- EN: On-foot proximity check & manual blockage clearing handler (Realistic Clogging Mode)
    -- UA: Перевірка відстані пішки та обробник ручного прочищення забитого комбайна
    if controlledVehicle == nil and self.settings and self.settings.cloggingMode == 3 then
        self:updateOnFootClogClearing(dt)
    else
        self.nearbyBlockedCombine = nil
        self.isHoldingClearClog = false
        if self._clearClogEventId and g_inputBinding and g_inputBinding.setActionEventTextVisibility then
            g_inputBinding:setActionEventTextVisibility(self._clearClogEventId, false)
        end
    end
end

function RHM_RealisticHarvestManager:onGlobalActionClearClog(actionName, inputValue, callbackState, isAnalog)
    local isDown = (inputValue or 0) > 0
    self.isHoldingClearClog = isDown
end

function RHM_RealisticHarvestManager:findNearbyBlockedCombine()
    local player = g_localPlayer or (g_currentMission and g_currentMission.player)
    local px, _, pz = nil, nil, nil
    if player and player.getPosition then
        px, _, pz = player:getPosition()
    elseif player and player.rootNode and entityExists(player.rootNode) then
        px, _, pz = getWorldTranslation(player.rootNode)
    end
    if px == nil then return nil end

    local vehicleList = (g_currentMission and g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles)
        or (g_currentMission and g_currentMission.vehicles)
    if vehicleList == nil then return nil end

    local bestVehicle = nil
    local bestDistSq = 18.0 -- ~4.25m proximity around header/feederhouse
    for _, v in ipairs(vehicleList) do
        local spec = v and v.spec_rhm_Combine
        if spec and spec.isRhmCombine == true and spec.data and spec.data.clogState == 3 then
            local refNode = v.rootNode or (v.components and v.components[1] and v.components[1].node)
            local offZ = 2.4
            if spec.currentCutter and spec.currentCutter.rootNode and entityExists(spec.currentCutter.rootNode) then
                refNode = spec.currentCutter.rootNode
                offZ = 0.0
            end
            if refNode and entityExists(refNode) then
                local tx, _, tz = localToWorld(refNode, 0, 0, offZ)
                local dx = px - tx
                local dz = pz - tz
                local dSq = dx * dx + dz * dz
                if dSq <= bestDistSq then
                    bestDistSq = dSq
                    bestVehicle = v
                end
            end
        end
    end
    return bestVehicle
end

function RHM_RealisticHarvestManager:updateOnFootClogClearing(dt)
    self._clogProximityTimer = (self._clogProximityTimer or 0) + (dt or 0)
    if self._clogProximityTimer >= 180 or self.isHoldingClearClog then
        self._clogProximityTimer = 0
        self.nearbyBlockedCombine = self:findNearbyBlockedCombine()
    end

    local target = self.nearbyBlockedCombine
    local hasTarget = (target ~= nil and target.spec_rhm_Combine ~= nil and target.spec_rhm_Combine.cloggingSystem ~= nil)

    if self._clearClogEventId and g_inputBinding and g_inputBinding.setActionEventTextVisibility then
        g_inputBinding:setActionEventTextVisibility(self._clearClogEventId, hasTarget)
    end

    if not hasTarget then
        self.isHoldingClearClog = false
        return
    end

    local spec = target.spec_rhm_Combine
    local sys = spec.cloggingSystem
    local completed = sys:processManualClearTick(target, dt or 0, self.isHoldingClearClog == true)

    -- Play manual clearing acoustic feedback while player actively clears
    if spec.samples and spec.samples.manualClear and g_soundManager then
        local vol = (self.settings and tonumber(self.settings.soundVolume)) or 1.0
        if self.isHoldingClearClog and vol > 0.01 then
            if not (g_soundManager.getIsSamplePlaying and g_soundManager:getIsSamplePlaying(spec.samples.manualClear)) then
                rhm_Combine.applySampleVolume(spec.samples.manualClear, vol, 1.0)
                g_soundManager:playSample(spec.samples.manualClear)
            end
            rhm_Combine.applySampleVolume(spec.samples.manualClear, vol, 1.0)
        else
            if g_soundManager.getIsSamplePlaying and g_soundManager:getIsSamplePlaying(spec.samples.manualClear) then
                g_soundManager:stopSample(spec.samples.manualClear)
            end
        end
    end

    if completed then
        self.isHoldingClearClog = false
        self.nearbyBlockedCombine = nil
        if spec.samples and spec.samples.manualClear and g_soundManager then
            g_soundManager:stopSample(spec.samples.manualClear)
        end
        if g_server ~= nil then
            sys:clearBlockage(target, true)
            rhm_Combine.syncCloggingData(target, spec)
            if spec.dataDirtyFlag and type(spec.dataDirtyFlag) == "number" then
                target:raiseDirtyFlags(spec.dataDirtyFlag)
            end
        elseif g_client and g_client:getServerConnection() then
            g_client:getServerConnection():sendEvent(RHM_ClogActionEvent.new(target, RHM_ClogActionEvent.ACTION_MANUAL_CLEAR_COMPLETE, true))
        end
        if g_currentMission and g_currentMission.showBlinkingWarning then
            local msg = (g_i18n and g_i18n:hasText("rhm_clog_cleared_msg") and g_i18n:getText("rhm_clog_cleared_msg")) or "Feeder cleared!"
            g_currentMission:showBlinkingWarning(msg, 2000)
        end
    end
end

function RHM_RealisticHarvestManager:initClearIndicatorOverlay()
    if self.clearIndicatorOverlay ~= nil or not self.modDirectory then
        return
    end

    local atlasPath = Utils.getFilename("textures/rhm_atlas.dds", self.modDirectory)
    self.clearIndicatorOverlay = Overlay.new(atlasPath, 0, 0, 1, 1)
    self.clearIndicatorUVs = {
        chassisTL       = GuiUtils.getUVs({780, 784, 12, 12}, ATLAS_SIZE_1024),
        chassisT        = GuiUtils.getUVs({792, 784, 40, 12}, ATLAS_SIZE_1024),
        chassisTR       = GuiUtils.getUVs({832, 784, 12, 12}, ATLAS_SIZE_1024),
        chassisL        = GuiUtils.getUVs({780, 796, 12, 40}, ATLAS_SIZE_1024),
        chassisC        = GuiUtils.getUVs({792, 796, 40, 40}, ATLAS_SIZE_1024),
        chassisR        = GuiUtils.getUVs({832, 796, 12, 40}, ATLAS_SIZE_1024),
        chassisBL       = GuiUtils.getUVs({780, 836, 12, 12}, ATLAS_SIZE_1024),
        chassisB        = GuiUtils.getUVs({792, 836, 40, 12}, ATLAS_SIZE_1024),
        chassisBR       = GuiUtils.getUVs({832, 836, 12, 12}, ATLAS_SIZE_1024),
        iconSlot        = GuiUtils.getUVs({860, 784, 44, 44}, ATLAS_SIZE_1024),
        iconRotor       = GuiUtils.getUVs({  0, 128, 128, 128}, ATLAS_SIZE_1024),
        pillStatusAlert = GuiUtils.getUVs({180, 668, 79, 21}, ATLAS_SIZE_1024),
        pillStatusOpt   = GuiUtils.getUVs({  4, 668, 79, 21}, ATLAS_SIZE_1024),
        pillValue       = GuiUtils.getUVs({268, 668, 110, 21}, ATLAS_SIZE_1024),
        sliderTrackWide = GuiUtils.getUVs({292, 624, 361, 10}, ATLAS_SIZE_1024),
        sliderFillCap   = GuiUtils.getUVs({904, 624,   4,  8}, ATLAS_SIZE_1024),
        sliderFillBody  = GuiUtils.getUVs({916, 624,   8,  8}, ATLAS_SIZE_1024),
    }
end

function RHM_RealisticHarvestManager:drawManualClearIndicator(combine)
    local spec = combine and combine.spec_rhm_Combine
    local sys = spec and spec.cloggingSystem
    if sys == nil then
        return
    end

    if self.clearIndicatorOverlay == nil then
        self:initClearIndicatorOverlay()
    end
    local overlay = self.clearIndicatorOverlay
    local uvs = self.clearIndicatorUVs
    if overlay == nil or uvs == nil then
        return
    end

    local prog = math.max(0.0, math.min(1.0, sys.manualClearProgress or 0.0))
    local isClearing = prog > 0.01

    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local uiScale = (g_gameSettings and g_gameSettings.getValue and g_gameSettings:getValue("uiScale")) or 1.0
    uiScale = math.max(0.65, math.min(1.35, uiScale))

    local pxW = 1.0 / screenW
    local pxH = 1.0 / screenH
    local refScale = (screenH / 1080.0) * uiScale

    local boxW = math.floor(468.0 * refScale + 0.5) * pxW
    local boxH = math.floor(80.0 * refScale + 0.5) * pxH
    local boxX = math.floor((0.5 - boxW * 0.5) * screenW + 0.5) * pxW
    local boxY = math.floor(0.185 * screenH + 0.5) * pxH

    -- 1. Rugged tablet mini-chassis (9-slice preserving crisp 12px bezel matching tablet_frame.dds)
    local cW = math.min(math.floor(12.0 * refScale + 0.5) * pxW, boxW * 0.35)
    local cH = math.min(math.floor(12.0 * refScale + 0.5) * pxH, boxH * 0.45)
    local midW = math.max(0, boxW - cW * 2.0)
    local midH = math.max(0, boxH - cH * 2.0)

    renderClearOverlaySlice(overlay, boxX, boxY, cW, cH, uvs.chassisBL, 1.0, 1.0, 1.0, 0.96)
    renderClearOverlaySlice(overlay, boxX + cW, boxY, midW, cH, uvs.chassisB, 1.0, 1.0, 1.0, 0.96)
    renderClearOverlaySlice(overlay, boxX + cW + midW, boxY, cW, cH, uvs.chassisBR, 1.0, 1.0, 1.0, 0.96)

    renderClearOverlaySlice(overlay, boxX, boxY + cH, cW, midH, uvs.chassisL, 1.0, 1.0, 1.0, 0.96)
    renderClearOverlaySlice(overlay, boxX + cW, boxY + cH, midW, midH, uvs.chassisC, 1.0, 1.0, 1.0, 0.96)
    renderClearOverlaySlice(overlay, boxX + cW + midW, boxY + cH, cW, midH, uvs.chassisR, 1.0, 1.0, 1.0, 0.96)

    renderClearOverlaySlice(overlay, boxX, boxY + cH + midH, cW, cH, uvs.chassisTL, 1.0, 1.0, 1.0, 0.96)
    renderClearOverlaySlice(overlay, boxX + cW, boxY + cH + midH, midW, cH, uvs.chassisT, 1.0, 1.0, 1.0, 0.96)
    renderClearOverlaySlice(overlay, boxX + cW + midW, boxY + cH + midH, cW, cH, uvs.chassisTR, 1.0, 1.0, 1.0, 0.96)

    local padX = math.floor(16.0 * refScale + 0.5) * pxW
    local padY = math.floor(14.0 * refScale + 0.5) * pxH

    -- 2. Left recessed icon slot + tinted rotor/cutter glyph
    local slotPx = math.floor(48.0 * refScale + 0.5)
    local slotW = slotPx * pxW
    local slotH = slotPx * pxH
    local slotX = boxX + padX
    local slotY = boxY + math.floor((boxH - slotH) * 0.5 * screenH + 0.5) * pxH
    renderClearOverlaySlice(overlay, slotX, slotY, slotW, slotH, uvs.iconSlot, 1.0, 1.0, 1.0, 1.0)

    local iconPx = math.floor(30.0 * refScale + 0.5)
    local iconW = iconPx * pxW
    local iconH = iconPx * pxH
    local iconX = slotX + math.floor((slotW - iconW) * 0.5 * screenW + 0.5) * pxW
    local iconY = slotY + math.floor((slotH - iconH) * 0.5 * screenH + 0.5) * pxH
    if isClearing then
        renderClearOverlaySlice(overlay, iconX, iconY, iconW, iconH, uvs.iconRotor, 0.52, 0.71, 0.0, 1.0)
    else
        renderClearOverlaySlice(overlay, iconX, iconY, iconW, iconH, uvs.iconRotor, 0.90, 0.59, 0.0, 1.0)
    end

    local contentLeft = slotX + slotW + math.floor(12.0 * refScale + 0.5) * pxW
    local contentRight = boxX + boxW - padX

    -- 3. Top-right tablet status badge (CLOG / CLEAR)
    local statusW = math.floor(76.0 * refScale + 0.5) * pxW
    local statusH = math.floor(20.0 * refScale + 0.5) * pxH
    local statusX = contentRight - statusW
    local statusY = boxY + boxH - padY - statusH
    local statusUV = isClearing and uvs.pillStatusOpt or uvs.pillStatusAlert
    renderClearOverlaySlice(overlay, statusX, statusY, statusW, statusH, statusUV, 1.0, 1.0, 1.0, 1.0)

    local statusKey = isClearing and "rhm_hud_clog_clear" or "rhm_hud_clog_jam"
    local statusFallback = isClearing and "CLEAR" or "CLOG"
    local statusLbl = (g_i18n and g_i18n:hasText(statusKey) and g_i18n:getText(statusKey)) or statusFallback

    local statusFont = 9.5 * refScale * pxH
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    if isClearing then
        setTextColor(0.56, 0.78, 0.04, 1.0)
    else
        setTextColor(0.95, 0.32, 0.32, 1.0)
    end
    renderText(statusX + statusW * 0.5, statusY + (statusH - statusFont * 0.72) * 0.5, statusFont, string.upper(statusLbl))

    -- 4. Prompt title & machine/cause subtitle
    local titleFont = 11.5 * refScale * pxH
    local subFont = 9.5 * refScale * pxH
    local promptText = (g_i18n and g_i18n:hasText("rhm_clog_onfoot_prompt") and g_i18n:getText("rhm_clog_onfoot_prompt"))
        or "Hold RShift+C to clear feeder"

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(0.96, 0.97, 0.98, 1.0)
    renderText(contentLeft, statusY + statusH * 0.42, titleFont, promptText)

    local combineName = (combine.getFullName and combine:getFullName()) or "Combine"
    local causeStr = (RHM_CloggingSystem and RHM_CloggingSystem.getCauseText and RHM_CloggingSystem.getCauseText(sys.clogCause)) or ""
    local subLine = (causeStr ~= "" and string.format("%s  -  %s", combineName, causeStr)) or combineName
    if string.len(subLine) > 40 then
        subLine = string.sub(subLine, 1, 38) .. ".."
    end
    setTextBold(false)
    setTextColor(0.62, 0.65, 0.69, 1.0)
    renderText(contentLeft, statusY - subFont * 0.85, subFont, subLine)

    -- 5. Bottom row: tablet recessed slider track + lime fill + value pill readout
    local valW = math.floor(60.0 * refScale + 0.5) * pxW
    local valH = math.floor(19.0 * refScale + 0.5) * pxH
    local valX = contentRight - valW
    local valY = boxY + padY
    renderClearOverlaySlice(overlay, valX, valY, valW, valH, uvs.pillValue, 1.0, 1.0, 1.0, 1.0)

    local valFont = 10.5 * refScale * pxH
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    if isClearing then
        setTextColor(0.10, 0.22, 0.02, 1.0)
    else
        setTextColor(0.08, 0.09, 0.10, 1.0)
    end
    renderText(valX + valW * 0.5, valY + (valH - valFont * 0.72) * 0.5, valFont, string.format("%d%%", math.floor(prog * 100.0 + 0.5)))

    local trackW = (valX - math.floor(8.0 * refScale + 0.5) * pxW) - contentLeft
    local trackH = math.floor(10.0 * refScale + 0.5) * pxH
    local trackY = valY + math.floor((valH - trackH) * 0.5 * screenH + 0.5) * pxH
    if trackW > 12 * pxW then
        renderClearOverlaySlice(overlay, contentLeft, trackY, trackW, trackH, uvs.sliderTrackWide, 1.0, 1.0, 1.0, 1.0)

        local fillPadX = math.floor(1.0 * refScale + 0.5) * pxW
        local fillPadY = math.floor(1.0 * refScale + 0.5) * pxH
        local maxFillW = math.max(0, trackW - fillPadX * 2.0)
        local fillW = maxFillW * prog
        if fillW >= 1.0 * pxW then
            local fillH = math.max(2 * pxH, trackH - fillPadY * 2.0)
            local capW = math.min(math.floor(4.0 * refScale + 0.5) * pxW, fillW)
            local fillY = trackY + fillPadY
            renderClearOverlaySlice(overlay, contentLeft + fillPadX, fillY, capW, fillH, uvs.sliderFillCap, 1.0, 1.0, 1.0, 1.0)
            if fillW > capW then
                renderClearOverlaySlice(overlay, contentLeft + fillPadX + capW, fillY, fillW - capW, fillH, uvs.sliderFillBody, 1.0, 1.0, 1.0, 1.0)
            end
        end
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

-- EN: Draws the telemetry HUD inside the base game HUD layer so external vehicle HUDs and dropdowns render on top.
-- UA: Малює телеметричний HUD на базовому шарі HUD гри, щоб зовнішні HUD та випадаючі списки рендерилися поверх нього.
function RHM_RealisticHarvestManager:drawHUDLayer()
    if not (self.mission and self.mission:getIsClient()) then
        return
    end
    if not (self.hud and self.lastActiveCombine and self.settings and self.settings.showHUD) then
        return
    end
    if self.hud.isDragging then
        return
    end
    local playerVehicle = self.lastControlledVehicle or self:getControlledVehicle()
    if not playerVehicle then
        return
    end
    self.hud:draw()
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

    -- EN: Render on-foot manual blockage clearing prompt & progress bar near feeder
    -- UA: Малюємо підказку та шкалу ручного прочищення біля жатки у пішому режимі
    if self.nearbyBlockedCombine then
        self:drawManualClearIndicator(self.nearbyBlockedCombine)
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

    -- Draw on top only while actively dragging or if base HUD layer hook did not run
    if self.settings and self.settings.showHUD then
        if self.hud.isDragging or not RHMDraggableHUD.controlledHudHooked then
            self.hud:draw()
        end
    end
end

-- EN: Cleans up all HUD and GUI resources on mission end.
-- UA: Очищає всі ресурси HUD і GUI при завершенні місії.
function RHM_RealisticHarvestManager:delete()
    if self.harvestTracker then g_messageCenter:unsubscribeAll(self.harvestTracker) end
    if self.notificationManager then
        self.notificationManager:delete()
        self.notificationManager = nil
        RHM_NotificationManager.INSTANCE = nil
    end
    if self.hud then
        self.hud:delete()
        self.hud = nil
    end
    if self.clearIndicatorOverlay then
        self.clearIndicatorOverlay:delete()
        self.clearIndicatorOverlay = nil
    end
    self.clearIndicatorUVs = nil
    if self.calibrationGUI then
        self.calibrationGUI:delete()
        self.calibrationGUI = nil
    end
end

-- EN: Routes mouse events to the calibration GUI first, then to the HUD (for dragging).
--     The GUI gets priority so it can capture events before the HUD.
-- UA: Направляє події миші спочатку до GUI калібрування, а потім до HUD (для перетягування).
--     GUI отримує пріоритет, щоб перехоплювати події до HUD.
function RHM_RealisticHarvestManager:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.mission:getIsClient() then
        return false
    end

    if g_gui and g_gui.getIsGuiVisible and g_gui:getIsGuiVisible() then
        return false
    end

    if self.notificationManager and self.notificationManager:mouseEvent(posX, posY, isDown, isUp, button) then
        return true
    end

    if self.calibrationGUI and self.calibrationGUI:mouseEvent(posX, posY, isDown, isUp, button) then
        return true
    end

    local controlled = self.lastControlledVehicle or self:getControlledVehicle()
    if self.hud then
        if self.lastActiveCombine and controlled then
            if self.hud:mouseEvent(posX, posY, isDown, isUp, button) then
                return true
            end
        elseif self.hud.isDragging then
            self.hud.isDragging = false
            self.hud.hasMoved = false
            self.hud.isNearDock = false
        end
    end

    -- EN: When standalone cursor mode is active:
    --     Toggle off on Middle Mouse Button (MMB / button 3).
    --     Do NOT capture or interfere with Right Mouse Button (RMB / button 2) to preserve clean compatibility with auxiliary menus and vehicle controls.
    -- UA: Коли автономний курсор активний:
    --     Вимикаємо на клік коліщатка (MMB / button 3).
    --     НЕ перехоплюємо та не чіпаємо ПКМ (RMB / button 2), щоб зберегти повну сумісність із зовнішніми меню та керуванням техніки.
    if self.isCursorVisible then
        local isMMB = (button == 3) or (Input and button == Input.MOUSE_BUTTON_MIDDLE)
        if isDown and isMMB then
            self:toggleMouseCursor()
            return true
        end

        local isLMB = (button == 1) or (Input and button == Input.MOUSE_BUTTON_LEFT)
        if isLMB and (isDown or isUp) then
            if RHM_ModCompatibility and RHM_ModCompatibility.isExternalHudBlockingMouse
                and RHM_ModCompatibility.isExternalHudBlockingMouse(posX, posY, self.lastActiveCombine or controlled) then
                return false
            end
            -- Consume LMB outside HUD so in-cab clicks don't trigger vehicle implements while cursor mode is active
            return true
        end
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
        if self.isCursorVisible then
            self:setMouseCursorVisible(false)
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
