-- EN: Integrates mod settings into the standard FS25 in-game settings menu (InGameMenu).
--     Injects server-side (admin-controlled) simulation settings and client-side HUD/display
--     settings into the generalSettingsLayout of the settings page. Also provides a
--     "Reset Settings" button in the footer.
-- UA: Інтегрує налаштування мода до стандартного меню налаштувань FS25 (InGameMenu).
--     EN: Injects server-side (admin-controlled) simulation settings and client-side
--     UA: Впроваджує серверні (контрольовані адміном) налаштування симуляції та клієнтські
--     EN: HUD/display settings into the generalSettingsLayout of the settings page.
--     UA: налаштування HUD/відображення в generalSettingsLayout сторінки налаштувань.
--     EN: Also provides a "Reset Settings" button in the footer.
--     UA: Також надає кнопку "Скинути налаштування" у футері.
SettingsUI = {}
local SettingsUI_mt = Class(SettingsUI)

function SettingsUI.new(settings)
    local self = setmetatable({}, SettingsUI_mt)
    self.settings = settings
    self.injected = false -- EN: Guard against double-injection / UA: Захист від подвійного впровадження
    return self
end

-- EN: Injects all mod settings into the game's settings menu.
--     Only runs once; subsequent calls are no-ops. Must be called after the menu is available.
-- UA: Впроваджує всі налаштування мода в меню налаштувань гри.
--     EN: Executes only once; subsequent calls do nothing. Must be called after the menu is available.
--     UA: Виконується тільки один раз; повторні виклики нічого не роблять. Має виклику після доступності меню.
function SettingsUI:inject()
    if self.injected then
        return
    end

    local page = g_gui.screenControllers[InGameMenu].pageSettings
    if not page then
        Logging.error("RHM: Settings page not found - cannot inject settings!")
        return
    end

    local layout = page.generalSettingsLayout
    if not layout then
        Logging.error("RHM: Settings layout not found!")
        return
    end

    -- EN: Inject "Simulation" section header into the settings layout.
    -- UA: Впроваджуємо заголовок секції "Симуляція" в розмітку налаштувань.
    local section = UIHelper.createSection(layout, "rhm_section_simulation")
    if not section then
        Logging.error("RHM: Failed to create settings section!")
        return
    end

    local isAdmin = self.settings:canChangeServerSettings()

    -- EN: Difficulty option labels (shared for both motor and loss options).
    -- UA: Підписи рівнів складності (спільні для параметрів двигуна і втрат).
    local diffOptions = {
        getTextSafe("rhm_diff_1"),
        getTextSafe("rhm_diff_2"),
        getTextSafe("rhm_diff_3")
    }

    -- EN: Motor difficulty — controls how hard it is to overload the combine engine.
    --     Disabled for non-admin players in multiplayer.
    -- UA: Складність двигуна — керує тим, наскільки легко перевантажити двигун комбайна.
    --     EN: Disabled for non-admin players in multiplayer.
--     UA: Вимкнено для гравців без прав адміна в мультиплеєрі.
    local diffMotorOpt = UIHelper.createMultiOption(
        layout,
        "rhm_diff_motor",
        "rhm_difficulty_motor",
        diffOptions,
        self.settings.difficultyMotor,
        function(val)
            if not self.settings:canChangeServerSettings() then return end
            self.settings.difficultyMotor = val
            self.settings:save()
            if g_currentMission.missionDynamicInfo.isMultiplayer and SettingsSync then
                SettingsSync:sendToClients(self.settings)
            end
        end
    )
    if diffMotorOpt.setDisabled then diffMotorOpt:setDisabled(not isAdmin) end
    self.difficultyMotorOption = diffMotorOpt

    -- EN: Loss difficulty — controls how severe crop losses are when settings are off.
    -- UA: Складність втрат — керує тим, наскільки серйозними є втрати врожаю при неправильних налаштуваннях.
    local diffLossOpt = UIHelper.createMultiOption(
        layout,
        "rhm_diff_loss",
        "rhm_difficulty_loss",
        diffOptions,
        self.settings.difficultyLoss,
        function(val)
            if not self.settings:canChangeServerSettings() then return end
            self.settings.difficultyLoss = val
            self.settings:save()
            if g_currentMission.missionDynamicInfo.isMultiplayer and SettingsSync then
                SettingsSync:sendToClients(self.settings)
            end
        end
    )
    if diffLossOpt.setDisabled then diffLossOpt:setDisabled(not isAdmin) end
    self.difficultyLossOption = diffLossOpt

    -- EN: Speed limit toggle — enables/disables the dynamic speed limiting feature.
    -- UA: Перемикач ліміту швидкості — вмикає/вимикає функцію динамічного обмеження швидкості.
    local speedLimitOpt = UIHelper.createBinaryOption(
        layout,
        "rhm_speedlimit",
        "rhm_speedlimit",
        self.settings.enableSpeedLimit,
        function(val)
            if not self.settings:canChangeServerSettings() then return end
            self.settings.enableSpeedLimit = val
            self.settings:save()
            if g_currentMission.missionDynamicInfo.isMultiplayer and SettingsSync then
                SettingsSync:sendToClients(self.settings)
            end
        end
    )
    if speedLimitOpt.setDisabled then
        speedLimitOpt:setDisabled(not isAdmin)
    end
    self.speedLimitOption = speedLimitOpt

    -- EN: Crop loss toggle — enables/disables the crop loss simulation feature.
    -- UA: Перемикач втрат врожаю — вмикає/вимикає симуляцію втрат врожаю.
    local cropLossOpt = UIHelper.createBinaryOption(
        layout,
        "rhm_croploss",
        "rhm_croploss",
        self.settings.enableCropLoss,
        function(val)
            if not self.settings:canChangeServerSettings() then return end
            self.settings.enableCropLoss = val
            self.settings:save()
            if g_currentMission.missionDynamicInfo.isMultiplayer and SettingsSync then
                SettingsSync:sendToClients(self.settings)
            end
        end
    )
    if cropLossOpt.setDisabled then
        cropLossOpt:setDisabled(not isAdmin)
    end
    self.cropLossOption = cropLossOpt

    -- EN: Inject "HUD & Display" section header.
    -- UA: Впроваджуємо заголовок секції "HUD та Відображення".
    UIHelper.createSection(layout, "rhm_section_visuals")

    -- EN: HUD main visibility toggle (client-side).
    -- UA: Головний перемикач видимості HUD (клієнтський).
    local hudOpt = UIHelper.createBinaryOption(
        layout, "rhm_hud", "rhm_hud",
        self.settings.showHUD,
        function(val)
            self.settings.showHUD = val
            self.settings:save()
        end
    )
    self.hudOption = hudOpt

    -- EN: Controls individual HUD row visibility (all client-side).
    -- UA: Керує видимістю окремих рядків HUD (всі клієнтські).
    local yieldOpt = UIHelper.createBinaryOption(layout, "rhm_show_yield", "rhm_show_yield", self.settings.showYield, function(val) self.settings.showYield = val; self.settings:save() end)
    self.yieldOption = yieldOpt

    local loadOpt = UIHelper.createBinaryOption(layout, "rhm_show_load", "rhm_show_load", self.settings.showLoad, function(val) self.settings.showLoad = val; self.settings:save() end)
    self.loadOption = loadOpt

    local speedOpt = UIHelper.createBinaryOption(layout, "rhm_show_speed", "rhm_show_speed", self.settings.showSpeed, function(val) self.settings.showSpeed = val; self.settings:save() end)
    self.speedOption = speedOpt

    local prodOpt = UIHelper.createBinaryOption(layout, "rhm_show_productivity", "rhm_show_productivity", self.settings.showProductivity, function(val) self.settings.showProductivity = val; self.settings:save() end)
    self.productivityOption = prodOpt

    -- EN: Controls HUD crop loss row visibility (distinct from the server enableCropLoss feature).
    -- UA: Керує видимістю рядку втрат врожаю у HUD (відрізняється від серверного enableCropLoss).
    local lossVisOpt = UIHelper.createBinaryOption(layout, "rhm_show_croploss", "rhm_show_croploss", self.settings.showCropLoss, function(val) self.settings.showCropLoss = val; self.settings:save() end)
    self.cropLossVisOption = lossVisOpt

    local loadWarnOpt = UIHelper.createBinaryOption(layout, "rhm_show_load_warn", "rhm_show_load_warn", self.settings.showLoadWarnings, function(val) self.settings.showLoadWarnings = val; self.settings:save() end)
    self.loadWarnOption = loadWarnOpt

    -- EN: Unit system selection: Metric, Imperial, or Bushels.
    -- UA: Вибір системи одиниць: Метрична, Американська або Бушелі.
    local unitOptions = {
        g_i18n:getText("rhm_unit_metric"),
        g_i18n:getText("rhm_unit_imperial"),
        g_i18n:getText("rhm_unit_bushels")
    }

    local unitOpt = UIHelper.createMultiOption(
        layout, "rhm_units", "rhm_units",
        unitOptions, self.settings.unitSystem,
        function(val)
            self.settings.unitSystem = val
            self.settings:save()
        end
    )
    self.unitSystemOption = unitOpt

    self.injected = true
    -- EN: Invalidate layout so new elements are properly positioned and visible.
    -- UA: Інвалідуємо розмітку щоб нові елементи були правильно розміщені і видимі.
    layout:invalidateLayout()
end

-- EN: Helper to safely retrieve localized text, falling back to the raw key if unavailable.
-- UA: Допоміжна функція для безпечного отримання локалізованого тексту, повертає ключ якщо немає.
function getTextSafe(key)
    local text = g_i18n:getText(key)
    if text == nil or text == "" then
        return key
    end
    return text
end

-- EN: Refreshes all injected UI elements to reflect the current settings state.
--     Called after settings are loaded from disk or reset to defaults.
-- UA: Оновлює всі впроваджені елементи UI для відображення поточного стану налаштувань.
--     EN: Called after loading settings from disk or resetting to default values.
--     UA: Викликається після завантаження налаштувань з диска або скидання до значень за замовчуванням.
function SettingsUI:refreshUI()
    if not self.injected then
        return
    end

    local isAdmin = self.settings:canChangeServerSettings()

    -- EN: Refresh server-side difficulty options.
    -- UA: Оновлюємо серверні параметри складності.
    if self.difficultyMotorOption and self.difficultyMotorOption.setState then
        self.difficultyMotorOption:setState(self.settings.difficultyMotor)
        if self.difficultyMotorOption.setDisabled then self.difficultyMotorOption:setDisabled(not isAdmin) end
    end
    if self.difficultyLossOption and self.difficultyLossOption.setState then
        self.difficultyLossOption:setState(self.settings.difficultyLoss)
        if self.difficultyLossOption.setDisabled then self.difficultyLossOption:setDisabled(not isAdmin) end
    end

    -- EN: Refresh client-side HUD visibility options.
    -- UA: Оновлюємо клієнтські параметри видимості HUD.
    if self.hudOption and self.hudOption.setIsChecked then self.hudOption:setIsChecked(self.settings.showHUD) end
    if self.yieldOption and self.yieldOption.setIsChecked then self.yieldOption:setIsChecked(self.settings.showYield) end
    if self.loadOption and self.loadOption.setIsChecked then self.loadOption:setIsChecked(self.settings.showLoad) end
    if self.speedOption and self.speedOption.setIsChecked then self.speedOption:setIsChecked(self.settings.showSpeed) end
    if self.productivityOption and self.productivityOption.setIsChecked then self.productivityOption:setIsChecked(self.settings.showProductivity) end
    if self.cropLossVisOption and self.cropLossVisOption.setIsChecked then self.cropLossVisOption:setIsChecked(self.settings.showCropLoss) end
    if self.loadWarnOption and self.loadWarnOption.setIsChecked then self.loadWarnOption:setIsChecked(self.settings.showLoadWarnings) end

    -- EN: Refresh server-side feature toggles.
    -- UA: Оновлюємо серверні перемикачі функцій.
    if self.speedLimitOption and self.speedLimitOption.setIsChecked then
        self.speedLimitOption:setIsChecked(self.settings.enableSpeedLimit)
        if self.speedLimitOption.setDisabled then self.speedLimitOption:setDisabled(not isAdmin) end
    end

    if self.cropLossOption and self.cropLossOption.setIsChecked then
        self.cropLossOption:setIsChecked(self.settings.enableCropLoss)
        if self.cropLossOption.setDisabled then self.cropLossOption:setDisabled(not isAdmin) end
    end

    if self.unitSystemOption and self.unitSystemOption.setState then
        self.unitSystemOption:setState(self.settings.unitSystem)
    end

    print("RHM: UI refreshed")
end

-- EN: Adds a "Reset Settings" button to the settings menu footer.
--     Only added once; duplicate adds are prevented. Uses the MENU_EXTRA_1 (X) input action.
-- UA: Додає кнопку "Скинути налаштування" до футеру меню налаштувань.
--     EN: Added only once; duplication is prevented. Uses MENU_EXTRA_1 (X) action.
--     UA: Додається тільки один раз; дублювання попереджається. Використовує дію MENU_EXTRA_1 (X).
function SettingsUI:ensureResetButton(settingsFrame)
    if not settingsFrame or not settingsFrame.menuButtonInfo then
        print("RHM: ensureResetButton - settingsFrame invalid")
        return
    end

    if not self._resetButton then
        self._resetButton = {
            inputAction = InputAction.MENU_EXTRA_1,
            text = g_i18n:getText("rhm_reset") or "Reset Settings",
            callback = function()
                print("RHM: Reset button clicked!")
                if g_realisticHarvestManager and g_realisticHarvestManager.settings then
                    g_realisticHarvestManager.settings:resetToDefaults()
                    if g_realisticHarvestManager.settingsUI then
                        g_realisticHarvestManager.settingsUI:refreshUI()
                    end

                    if g_realisticHarvestManager.hud then
                        local x, y = g_realisticHarvestManager.hud:getPosition()
                        g_realisticHarvestManager.hud:setPosition(x, y)
                    end
                end
            end,
            showWhenPaused = true
        }
    end

    -- EN: Check if button was already added to avoid duplicates.
    -- UA: Перевіряємо чи кнопка вже додана, щоб уникнути дублікатів.
    for _, btn in ipairs(settingsFrame.menuButtonInfo) do
        if btn == self._resetButton then
            print("RHM: Reset button already in menuButtonInfo")
            return
        end
    end

    table.insert(settingsFrame.menuButtonInfo, self._resetButton)
    settingsFrame:setMenuButtonInfoDirty()
    print("RHM: Reset button added to footer! (X key)")
end
