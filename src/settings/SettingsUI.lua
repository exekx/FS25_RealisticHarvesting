---@class SettingsUI
SettingsUI = {}
local SettingsUI_mt = Class(SettingsUI)

function SettingsUI.new(settings)
    local self = setmetatable({}, SettingsUI_mt)
    self.settings = settings
    self.injected = false
    return self
end

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
    
    -- Додаємо секцію "Simulation"
    local section = UIHelper.createSection(layout, "rhm_section_simulation")
    if not section then
        Logging.error("RHM: Failed to create settings section!")
        return
    end
    
    -- Перевіряємо права адміністратора
    local isAdmin = self.settings:canChangeServerSettings()
    
    -- === SERVER SETTINGS (тільки адмін може змінювати) ===
    -- === SERVER SETTINGS (visible to all, editable by admin only) ===
    
    -- Difficulty Motor (Throughput Capacity)
    local diffOptions = {
        getTextSafe("rhm_diff_1"),
        getTextSafe("rhm_diff_2"),
        getTextSafe("rhm_diff_3")
    }
    
    local diffMotorOpt = UIHelper.createMultiOption(
        layout,
        "rhm_diff_motor",
        "rhm_difficulty_motor", -- New key
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
    
    -- Difficulty Loss (Penalty)
    local diffLossOpt = UIHelper.createMultiOption(
        layout,
        "rhm_diff_loss",
        "rhm_difficulty_loss", -- New key
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
    
    -- Speed Limit (Binary)
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
    
    -- Crop Loss (Binary)
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
    
    -- === CLIENT SETTINGS (всі можуть змінювати) ===
    
    -- Додаємо секцію "HUD & Visuals"
    UIHelper.createSection(layout, "rhm_section_visuals")
    
    -- HUD (Binary)
    local hudOpt = UIHelper.createBinaryOption(
        layout,
        "rhm_hud",
        "rhm_hud",
        self.settings.showHUD,
        function(val)
            self.settings.showHUD = val
            self.settings:save()
        end
    )
    self.hudOption = hudOpt
    
    -- Yield Monitor (Binary)
    local yieldOpt = UIHelper.createBinaryOption(
        layout,
        "rhm_show_yield",
        "rhm_show_yield", -- Needs l10n
        self.settings.showYield,
        function(val)
            self.settings.showYield = val
            self.settings:save()
        end
    )
    self.yieldOption = yieldOpt
    
    -- Load Indicator (Binary)
    local loadOpt = UIHelper.createBinaryOption(
        layout,
        "rhm_show_load",
        "rhm_show_load", -- Use l10n key
        self.settings.showLoad,
        function(val)
            self.settings.showLoad = val
            self.settings:save()
        end
    )
    self.loadOption = loadOpt
    
    -- Speed Indicator (Binary)
    local speedOpt = UIHelper.createBinaryOption(
        layout,
        "rhm_show_speed",
        "rhm_show_speed", -- Use l10n key
        self.settings.showSpeed,
        function(val)
            self.settings.showSpeed = val
            self.settings:save()
        end
    )
    self.speedOption = speedOpt
    
    -- Productivity (Binary)
    local prodOpt = UIHelper.createBinaryOption(
        layout,
        "rhm_show_productivity",
        "rhm_show_productivity", -- Use l10n key
        self.settings.showProductivity,
        function(val)
            self.settings.showProductivity = val
            self.settings:save()
        end
    )
    self.productivityOption = prodOpt
    
    -- Crop Loss Visibility (Binary) - DIFFERENT FROM ENABLE CROP LOSS
    local lossVisOpt = UIHelper.createBinaryOption(
        layout,
        "rhm_show_croploss",
        "rhm_show_croploss", -- Use l10n key
        self.settings.showCropLoss,
        function(val)
            self.settings.showCropLoss = val
            self.settings:save()
        end
    )
    self.cropLossVisOption = lossVisOpt
    
    -- Unit System (Multi)
    local unitOptions = {
        g_i18n:getText("rhm_unit_metric"),
        g_i18n:getText("rhm_unit_imperial"),
        g_i18n:getText("rhm_unit_bushels")
    }
    
    local unitOpt = UIHelper.createMultiOption(
        layout,
        "rhm_units",
        "rhm_units",
        unitOptions,
        self.settings.unitSystem,
        function(val)
            self.settings.unitSystem = val
            self.settings:save()
        end
    )
    self.unitSystemOption = unitOpt
    
    self.injected = true
    -- Викликаємо invalidateLayout для правильного відображення елементів
    layout:invalidateLayout()
end


-- Допоміжна функція для безпечного отримання тексту
function getTextSafe(key)
    local text = g_i18n:getText(key)
    if text == nil or text == "" then
        return key
    end
    return text
end

---Оновлює UI елементи після зміни налаштувань
function SettingsUI:refreshUI()
    if not self.injected then
        return
    end
    
    -- Оновлюємо difficulty (Motor & Loss)
    if self.difficultyMotorOption and self.difficultyMotorOption.setState then
        self.difficultyMotorOption:setState(self.settings.difficultyMotor)
    end
    if self.difficultyLossOption and self.difficultyLossOption.setState then
        self.difficultyLossOption:setState(self.settings.difficultyLoss)
    end
    
    -- Оновлюємо HUD
    if self.hudOption and self.hudOption.setIsChecked then
        self.hudOption:setIsChecked(self.settings.showHUD)
    end
    
    -- Оновлюємо HUD Elements
    if self.yieldOption and self.yieldOption.setIsChecked then
        self.yieldOption:setIsChecked(self.settings.showYield)
    end
    if self.loadOption and self.loadOption.setIsChecked then
        self.loadOption:setIsChecked(self.settings.showLoad)
    end
    if self.speedOption and self.speedOption.setIsChecked then
        self.speedOption:setIsChecked(self.settings.showSpeed)
    end
    if self.productivityOption and self.productivityOption.setIsChecked then
        self.productivityOption:setIsChecked(self.settings.showProductivity)
    end
    if self.cropLossVisOption and self.cropLossVisOption.setIsChecked then
        self.cropLossVisOption:setIsChecked(self.settings.showCropLoss)
    end
    
    -- Оновлюємо Speed Limit (Global Setting)
    if self.speedLimitOption and self.speedLimitOption.setIsChecked then
        self.speedLimitOption:setIsChecked(self.settings.enableSpeedLimit)
    end
    
    -- Оновлюємо Crop Loss Enable (Global Setting)
    if self.cropLossOption and self.cropLossOption.setIsChecked then
        self.cropLossOption:setIsChecked(self.settings.enableCropLoss)
    end
    
    -- Оновлюємо Unit System
    if self.unitSystemOption and self.unitSystemOption.setState then
        self.unitSystemOption:setState(self.settings.unitSystem)
    end
    
    print("RHM: UI refreshed")
end

---Додає кнопку Reset в footer панель Settings меню (правильний підхід через menuButtonInfo)
function SettingsUI:ensureResetButton(settingsFrame)
    if not settingsFrame or not settingsFrame.menuButtonInfo then
        print("RHM: ensureResetButton - settingsFrame invalid")
        return
    end
    
    -- Створюємо кнопку тільки раз
    if not self._resetButton then
        self._resetButton = {
            inputAction = InputAction.MENU_EXTRA_1,  -- X key
            text = g_i18n:getText("rhm_reset") or "Reset Settings",
            callback = function()
                print("RHM: Reset button clicked!")
                if g_realisticHarvestManager and g_realisticHarvestManager.settings then
                    g_realisticHarvestManager.settings:resetToDefaults()
                    if g_realisticHarvestManager.settingsUI then
                        g_realisticHarvestManager.settingsUI:refreshUI()
                    end
                    
                    -- Force HUD position reset immediately
                    if g_realisticHarvestManager.hud then
                        -- Get default position (since settings are now nil)
                        local x, y = g_realisticHarvestManager.hud:getPosition()
                        g_realisticHarvestManager.hud:setPosition(x, y)
                    end
                end
            end,
            showWhenPaused = true
        }
    end
    
    -- Перевіряємо чи кнопка вже додана (уникаємо дублікатів)
    for _, btn in ipairs(settingsFrame.menuButtonInfo) do
        if btn == self._resetButton then
            print("RHM: Reset button already in menuButtonInfo")
            return
        end
    end
    
    -- Додаємо кнопку до footer панелі
    table.insert(settingsFrame.menuButtonInfo, self._resetButton)
    settingsFrame:setMenuButtonInfoDirty()
    print("RHM: Reset button added to footer! (X key)")
end
