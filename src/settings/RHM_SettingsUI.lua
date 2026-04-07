-- EN: Shared callback table. ONE function handles ALL options, keyed by menuOption.id.
-- UA: Спільна таблиця callbacks. ОДНА функція обробляє ВСІ опції, ключ — menuOption.id.
RHMSettingsUI = {}
RHMSettingsUI.controls = {}
RHMSettingsUI.callbacks = {}
RHMSettingsUI._onChangeFns = {}   -- per-option lambdas, dispatched from shared callback
RHMSettingsUI.injected = false

-- EN: Shared option changed callback.
--     FS25 calls: target.rhmOnOptionChanged(target, state, menuOption)
-- UA: Спільний callback зміни опції.
function RHMSettingsUI.callbacks.rhmOnOptionChanged(self, state, menuOption)
    rhm_log("RHM [UI]: RHM: rhmOnOptionChanged id=" .. tostring(menuOption and menuOption.id) .. " state=" .. tostring(state))
    if menuOption and menuOption.id then
        local fn = RHMSettingsUI._onChangeFns[menuOption.id]
        if fn then fn(state) end
    end
end

local function updateFocusIds(element)
    if not element then return end
    element.focusId = FocusManager:serveAutoFocusId()
    for _, child in pairs(element.elements) do
        updateFocusIds(child)
    end
end

-- EN: Creates a multi-option row cloned from multiVolumeVoiceBox.
-- UA: Створює рядок multi-option клонований з multiVolumeVoiceBox.
local function addMultiRow(settingsPage, targetLayout, id, titleKey, tooltipKey, options, state, onChangeFn)
    local originalBox = settingsPage.multiVolumeVoiceBox
    if not originalBox then
        Logging.warning("RHM: multiVolumeVoiceBox not found, skipping: " .. id)
        return nil
    end

    targetLayout = targetLayout or settingsPage.gameSettingsLayout
    if not targetLayout then
        Logging.error("RHM: targetLayout not found for setting: " .. tostring(id))
        return nil
    end

    local box = originalBox:clone(targetLayout)
    box.id = "rhm_" .. id .. "_box"

    local opt = box.elements and box.elements[1]
    if not opt then
        Logging.error("RHM: box has no opt element for: " .. id)
        return nil
    end

    -- EN: Use the SAME callback name for ALL options, with opt.id used to dispatch.
    -- UA: Використовуємо ОДНЕ ім'я callback для ВСІХ опцій, opt.id використовується для диспетчеризації.
    opt.id = "rhm_" .. id
    opt.target = RHMSettingsUI.callbacks
    opt:setCallback("onClickCallback", "rhmOnOptionChanged")
    opt:setDisabled(false)

    -- EN: Store the per-option lambda so the shared callback can dispatch to it.
    RHMSettingsUI._onChangeFns["rhm_" .. id] = function(s) if onChangeFn then onChangeFn(s) end end

    local toolTip = opt.elements and opt.elements[1]
    if toolTip and toolTip.setText then
        toolTip:setText(g_i18n:hasText(tooltipKey) and g_i18n:getText(tooltipKey) or "")
    end

    local label = box.elements[2]
    if label and label.setText then
        label:setText(g_i18n:hasText(titleKey) and g_i18n:getText(titleKey) or titleKey)
    end

    opt:setTexts(options)
    opt:setState(state or 1)

    RHMSettingsUI.controls[id] = opt
    updateFocusIds(box)
    table.insert(settingsPage.controlsList, box)
    return opt
end

-- EN: Creates a binary (on/off) option row. Internally uses a multi-option with 2 values.
-- UA: Створює бінарний (вкл/викл) рядок. Всередині використовує multi-option з 2 значеннями.
local function addBinaryRow(settingsPage, targetLayout, id, titleKey, tooltipKey, currentState, onChangeFn)
    local offText = g_i18n:hasText("ui_off") and g_i18n:getText("ui_off") or "Off"
    local onText  = g_i18n:hasText("ui_on")  and g_i18n:getText("ui_on")  or "On"
    local state = currentState and 2 or 1
    local opt = addMultiRow(settingsPage, targetLayout, id, titleKey, tooltipKey, {offText, onText}, state, function(s)
        if onChangeFn then onChangeFn(s == 2) end
    end)
    return opt
end

-- EN: Creates a section header in the gameSettingsLayout, cloning an existing sectionHeader element.
--     Falls back to creating a TextElement with the correct profile if none is found.
-- UA: Створює заголовок секції в gameSettingsLayout, клонуючи існуючий sectionHeader.
local function addSection(settingsPage, titleKey, targetLayout)
    local layout = targetLayout or settingsPage.gameSettingsLayout
    local sectionTitle = nil

    for _, elem in ipairs(layout.elements) do
        if elem.name == "sectionHeader" then
            sectionTitle = elem:clone(layout)
            break
        end
    end

    if sectionTitle then
        sectionTitle:setText(g_i18n:hasText(titleKey) and g_i18n:getText(titleKey) or titleKey)
    else
        sectionTitle = TextElement.new()
        sectionTitle:applyProfile("fs25_settingsSectionHeader", true)
        sectionTitle:setText(g_i18n:hasText(titleKey) and g_i18n:getText(titleKey) or titleKey)
        sectionTitle.name = "sectionHeader"
        layout:addElement(sectionTitle)
    end

    sectionTitle.focusId = FocusManager:serveAutoFocusId()
    table.insert(settingsPage.controlsList, sectionTitle)
    return sectionTitle
end

-- EN: Main injection function. Called once from onMissionLoaded
-- UA: Головна функція ін'єкції. Викликається один раз з onMissionLoaded.
function RHMSettingsUI.inject(settings)
    if RHMSettingsUI.injected then return end

    local inGameMenu = g_gui.screenControllers[InGameMenu]
    if not inGameMenu then
        Logging.error("RHM: InGameMenu controller not found!")
        return
    end

    local settingsPage = inGameMenu.pageSettings
    if not settingsPage then
        Logging.error("RHM: pageSettings not found!")
        return
    end

    -- EN: CRITICAL – target object's name must match settingsPage.name so FocusManager registers our controls.
    -- UA: КРИТИЧНО – ім'я цільового об'єкту повинно відповідати settingsPage.name щоб FocusManager реєструвала наші елементи.
    RHMSettingsUI.callbacks.name = settingsPage.name

    local isAdmin = settings:canChangeServerSettings()

    -- EN: Target layouts (where options are injected in FS25 settings UI).
    -- UA: куди саме вставляти наші рядки в UI налаштувань.
    local gameLayout = settingsPage.gameSettingsLayout
    local generalLayout = settingsPage.generalSettingsLayout or settingsPage.generalLayout or gameLayout
    if not generalLayout then
        Logging.warning("RHM: generalSettingsLayout not found; using gameSettingsLayout as fallback.")
        generalLayout = gameLayout
    end

    -- === SECTION: Simulation ===
    addSection(settingsPage, "rhm_section_simulation", gameLayout)

    local diffOptions = {
        g_i18n:hasText("rhm_diff_1") and g_i18n:getText("rhm_diff_1") or "1",
        g_i18n:hasText("rhm_diff_2") and g_i18n:getText("rhm_diff_2") or "2",
        g_i18n:hasText("rhm_diff_3") and g_i18n:getText("rhm_diff_3") or "3",
    }

    local motorOpt = addMultiRow(settingsPage, gameLayout, "diff_motor", "rhm_difficulty_motor", "rhm_difficulty_motor_long",
        diffOptions, settings.difficultyMotor,
        function(val)
            if not settings:canChangeServerSettings() then return end
            settings.difficultyMotor = val; settings:save()
            if g_currentMission.missionDynamicInfo.isMultiplayer and RHM_SettingsSync then
                RHM_SettingsSync:sendToClients(settings)
            end
        end)
    if motorOpt and motorOpt.setDisabled then motorOpt:setDisabled(not isAdmin) end
    RHMSettingsUI.difficultyMotorOption = motorOpt

    local lossOpt = addMultiRow(settingsPage, gameLayout, "diff_loss", "rhm_difficulty_loss", "rhm_difficulty_loss_long",
        diffOptions, settings.difficultyLoss,
        function(val)
            if not settings:canChangeServerSettings() then return end
            settings.difficultyLoss = val; settings:save()
            if g_currentMission.missionDynamicInfo.isMultiplayer and RHM_SettingsSync then
                RHM_SettingsSync:sendToClients(settings)
            end
        end)
    if lossOpt and lossOpt.setDisabled then lossOpt:setDisabled(not isAdmin) end
    RHMSettingsUI.difficultyLossOption = lossOpt

    local speedOpt = addBinaryRow(settingsPage, gameLayout, "speedlimit", "rhm_speedlimit_short", "rhm_speedlimit_long",
        settings.enableSpeedLimit,
        function(val)
            if not settings:canChangeServerSettings() then return end
            settings.enableSpeedLimit = val; settings:save()
            if g_currentMission.missionDynamicInfo.isMultiplayer and RHM_SettingsSync then
                RHM_SettingsSync:sendToClients(settings)
            end
        end)
    if speedOpt and speedOpt.setDisabled then speedOpt:setDisabled(not isAdmin) end
    RHMSettingsUI.speedLimitOption = speedOpt

    local cropLossOpt = addBinaryRow(settingsPage, gameLayout, "croploss", "rhm_croploss_short", "rhm_croploss_long",
        settings.enableCropLoss,
        function(val)
            if not settings:canChangeServerSettings() then return end
            settings.enableCropLoss = val; settings:save()
            if g_currentMission.missionDynamicInfo.isMultiplayer and RHM_SettingsSync then
                RHM_SettingsSync:sendToClients(settings)
            end
        end)
    if cropLossOpt and cropLossOpt.setDisabled then cropLossOpt:setDisabled(not isAdmin) end
    RHMSettingsUI.cropLossOption = cropLossOpt

    if RHM_MoistureAdapter and RHM_MoistureAdapter.isActive then
        local moistureEnableOpt = addBinaryRow(settingsPage, gameLayout, "moisture_enable", "rhm_moisture_enable_short", "rhm_moisture_enable_long",
            settings.enableMoisture,
            function(val)
                if not settings:canChangeServerSettings() then return end
                settings.enableMoisture = val; settings:save()
                if g_currentMission.missionDynamicInfo.isMultiplayer and RHM_SettingsSync then
                    RHM_SettingsSync:sendToClients(settings)
                end
            end)
        if moistureEnableOpt and moistureEnableOpt.setDisabled then moistureEnableOpt:setDisabled(not isAdmin) end
        RHMSettingsUI.moistureEnableOption = moistureEnableOpt
    end

    -- === SECTION: Visuals / HUD ===
    addSection(settingsPage, "rhm_section_visuals", generalLayout)

    RHMSettingsUI.hudOption = addBinaryRow(settingsPage, generalLayout, "show_hud", "rhm_hud_short", "rhm_hud_long",
        settings.showHUD, function(val) settings.showHUD = val; settings:save() end)

    RHMSettingsUI.yieldOption = addBinaryRow(settingsPage, generalLayout, "show_yield", "rhm_show_yield_short", "rhm_show_yield_long",
        settings.showYield, function(val) settings.showYield = val; settings:save() end)

    RHMSettingsUI.loadOption = addBinaryRow(settingsPage, generalLayout, "show_load", "rhm_show_load_short", "rhm_show_load_long",
        settings.showLoad, function(val) settings.showLoad = val; settings:save() end)

    RHMSettingsUI.speedDisplayOption = addBinaryRow(settingsPage, generalLayout, "show_speed", "rhm_show_speed_short", "rhm_show_speed_long",
        settings.showSpeed, function(val) settings.showSpeed = val; settings:save() end)

    RHMSettingsUI.prodOption = addBinaryRow(settingsPage, generalLayout, "show_prod", "rhm_show_productivity_short", "rhm_show_productivity_long",
        settings.showProductivity, function(val) settings.showProductivity = val; settings:save() end)

    RHMSettingsUI.cropLossVisOption = addBinaryRow(settingsPage, generalLayout, "show_croploss", "rhm_show_croploss_short", "rhm_show_croploss_long",
        settings.showCropLoss, function(val) settings.showCropLoss = val; settings:save() end)

    if RHM_MoistureAdapter and RHM_MoistureAdapter.isActive then
        RHMSettingsUI.moistureVisOption = addBinaryRow(settingsPage, generalLayout, "show_moisture", "rhm_show_moisture_short", "rhm_show_moisture_long",
            settings.showMoisture, function(val) settings.showMoisture = val; settings:save() end)
    end

    RHMSettingsUI.loadWarnOption = addBinaryRow(settingsPage, generalLayout, "show_loadwarn", "rhm_show_load_warn_short", "rhm_show_load_warn_long",
        settings.showLoadWarnings, function(val) settings.showLoadWarnings = val; settings:save() end)

    local unitOptions = {
        g_i18n:hasText("rhm_unit_metric")   and g_i18n:getText("rhm_unit_metric")   or "Metric",
        g_i18n:hasText("rhm_unit_imperial") and g_i18n:getText("rhm_unit_imperial") or "Imperial",
        g_i18n:hasText("rhm_unit_bushels")  and g_i18n:getText("rhm_unit_bushels")  or "Bushels",
    }
    RHMSettingsUI.unitOption = addMultiRow(settingsPage, generalLayout, "units", "rhm_units_short", "rhm_units_long",
        unitOptions, settings.unitSystem,
        function(val) settings.unitSystem = val; settings:save() end)

    if settingsPage.gameSettingsLayout then
        settingsPage.gameSettingsLayout:invalidateLayout()
    end
    if generalLayout and generalLayout ~= settingsPage.gameSettingsLayout and generalLayout.invalidateLayout then
        generalLayout:invalidateLayout()
    end
    RHMSettingsUI.injected = true
    RHMSettingsUI._settings = settings

    rhm_log("RHM [UI]: RHM: Settings injected successfully")
end

-- EN: Refreshes all controls to reflect the current settings state (called on menu open).
-- UA: Оновлює всі елементи відповідно до поточного стану налаштувань (викликається при відкритті меню).
function RHMSettingsUI.refreshUI(settings)
    if not RHMSettingsUI.injected then return end
    settings = settings or RHMSettingsUI._settings
    if not settings then return end

    local isAdmin = settings:canChangeServerSettings()

    local function setOpt(opt, state, disabled)
        if opt and opt.setState then opt:setState(state) end
        if opt and opt.setDisabled then opt:setDisabled(disabled == true) end
    end

    setOpt(RHMSettingsUI.difficultyMotorOption, settings.difficultyMotor, not isAdmin)
    setOpt(RHMSettingsUI.difficultyLossOption,  settings.difficultyLoss,  not isAdmin)
    setOpt(RHMSettingsUI.speedLimitOption,      settings.enableSpeedLimit and 2 or 1, not isAdmin)
    setOpt(RHMSettingsUI.cropLossOption,        settings.enableCropLoss   and 2 or 1, not isAdmin)
    setOpt(RHMSettingsUI.moistureEnableOption,  settings.enableMoisture   and 2 or 1, not isAdmin)

    setOpt(RHMSettingsUI.hudOption,         settings.showHUD           and 2 or 1, false)
    setOpt(RHMSettingsUI.yieldOption,       settings.showYield         and 2 or 1, false)
    setOpt(RHMSettingsUI.loadOption,        settings.showLoad          and 2 or 1, false)
    setOpt(RHMSettingsUI.speedDisplayOption,settings.showSpeed         and 2 or 1, false)
    setOpt(RHMSettingsUI.prodOption,        settings.showProductivity  and 2 or 1, false)
    setOpt(RHMSettingsUI.cropLossVisOption, settings.showCropLoss      and 2 or 1, false)
    setOpt(RHMSettingsUI.moistureVisOption, settings.showMoisture      and 2 or 1, false)
    setOpt(RHMSettingsUI.loadWarnOption,    settings.showLoadWarnings  and 2 or 1, false)
    setOpt(RHMSettingsUI.unitOption,        settings.unitSystem,                    false)
end

-- EN: Adds a "Reset" footer button to the settings page (called on updateButtons).
-- UA: Додає кнопку "Скинути" у футер сторінки налаштувань (викликається на updateButtons).
function RHMSettingsUI.ensureResetButton(settingsFrame)
    if not settingsFrame or not settingsFrame.menuButtonInfo then return end

    if not RHMSettingsUI._resetButton then
        RHMSettingsUI._resetButton = {
            inputAction = InputAction.MENU_EXTRA_1,
            text = g_i18n:hasText("rhm_reset") and g_i18n:getText("rhm_reset") or "Reset RH",
            callback = function()
                rhm_log("RHM [UI]: RHM: Reset button clicked!")
                if g_realisticHarvestManager and g_realisticHarvestManager.settings then
                    g_realisticHarvestManager.settings:resetToDefaults()
                    RHMSettingsUI.refreshUI(g_realisticHarvestManager.settings)
                end
            end,
            showWhenPaused = true
        }
    end

    for _, btn in ipairs(settingsFrame.menuButtonInfo) do
        if btn == RHMSettingsUI._resetButton then return end
    end

    table.insert(settingsFrame.menuButtonInfo, RHMSettingsUI._resetButton)
    settingsFrame:setMenuButtonInfoDirty()
    rhm_log("RHM [UI]: RHM: Reset button added to footer! (X key)")
end
