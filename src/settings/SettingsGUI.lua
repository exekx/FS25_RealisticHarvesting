---@class SettingsGUI
-- GUI для налаштувань Realistic Harvest Manager
SettingsGUI = {}
local SettingsGUI_mt = Class(SettingsGUI)

function SettingsGUI.new()
    local self = setmetatable({}, SettingsGUI_mt)
    return self
end

---Реєструє консольні команди для налаштувань
function SettingsGUI:registerConsoleCommands()
    -- Команда для зміни складності
    addConsoleCommand("rhmSetDifficulty", "Set difficulty (1=Arcade, 2=Normal, 3=Realistic)", "consoleCommandSetDifficulty", self)
    
    -- Команда для увімкнення/вимкнення обмеження швидкості
    addConsoleCommand("rhmToggleSpeedLimit", "Toggle speed limiting on/off", "consoleCommandToggleSpeedLimit", self)
    
    -- Команда для увімкнення/вимкнення втрат врожаю
    addConsoleCommand("rhmToggleCropLoss", "Toggle crop loss on/off", "consoleCommandToggleCropLoss", self)
    
    -- Команда для увімкнення/вимкнення HUD
    addConsoleCommand("rhmToggleHUD", "Toggle HUD on/off", "consoleCommandToggleHUD", self)
    
    -- Команда для показу поточних налаштувань
    addConsoleCommand("rhmShowSettings", "Show current settings", "consoleCommandShowSettings", self)
    
    -- Команда для зміни зміщення HUD
    addConsoleCommand("rhmSetHUDOffset", "Set HUD vertical offset (100-500)", "consoleCommandSetHUDOffset", self)
    
    -- Команди для переміщення HUD ліворуч/праворуч
    addConsoleCommand("rhmMoveHUDLeft", "Move HUD to the left by 10px", "consoleCommandMoveHUDLeft", self)
    addConsoleCommand("rhmMoveHUDRight", "Move HUD to the right by 10px", "consoleCommandMoveHUDRight", self)
    
    -- Команда для скидання налаштувань
    addConsoleCommand("rhmResetSettings", "Reset all settings to defaults", "consoleCommandResetSettings", self)
    
    -- === COMBINE SETTINGS COMMANDS ===
    addConsoleCommand("rhm_status", "Show combine settings status", "consoleCommandCombineStatus", self)
    addConsoleCommand("rhm_auto", "Set combine to AUTO mode", "consoleCommandCombineAuto", self)
    addConsoleCommand("rhm_manual", "Set combine to MANUAL mode", "consoleCommandCombineManual", self)
    addConsoleCommand("rhm_set", "Set combine parameter (usage: rhm_set <param> <value>)", "consoleCommandCombineSet", self)
    addConsoleCommand("rhm_load", "Load combine profile (usage: rhm_load <profile>)", "consoleCommandCombineLoad", self)
    addConsoleCommand("rhm_save", "Save combine profile (usage: rhm_save <name>)", "consoleCommandCombineSave", self)
    addConsoleCommand("rhm_profiles", "List all saved profiles", "consoleCommandCombineProfiles", self)
    
    -- Logging.info("RHM: Console commands registered")
end


function SettingsGUI:consoleCommandSetDifficulty(difficulty)
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end
    
    local settings = g_realisticHarvestManager.settings
    
    -- PERMISSION CHECK: Only admins can change server settings
    if not settings:canChangeServerSettings() then
        return "Error: Admin only - you cannot change server settings"
    end
    
    local diff = tonumber(difficulty)
    if not diff or diff < 1 or diff > 3 then
        Logging.warning("RHM: Invalid difficulty. Use 1 (Arcade), 2 (Normal), or 3 (Realistic)")
        return "Invalid difficulty. Use 1 (Arcade), 2 (Normal), or 3 (Realistic)"
    end
    
    settings:setDifficulty(diff)
    settings:save()
    return string.format("Difficulty set to: %s", settings:getDifficultyName())
end

function SettingsGUI:consoleCommandToggleSpeedLimit()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end
    
    local settings = g_realisticHarvestManager.settings
    
    -- PERMISSION CHECK: Only admins can change server settings
    if not settings:canChangeServerSettings() then
        return "Error: Admin only - you cannot change server settings"
    end
    
    settings.enableSpeedLimit = not settings.enableSpeedLimit
    settings:save()
    return string.format("Speed Limiting: %s", settings.enableSpeedLimit and "ON" or "OFF")
end

function SettingsGUI:consoleCommandToggleCropLoss()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end
    
    local settings = g_realisticHarvestManager.settings
    
    -- PERMISSION CHECK: Only admins can change server settings
    if not settings:canChangeServerSettings() then
        return "Error: Admin only - you cannot change server settings"
    end
    
    settings.enableCropLoss = not settings.enableCropLoss
    settings:save()
    return string.format("Crop Loss: %s", settings.enableCropLoss and "ON" or "OFF")
end

function SettingsGUI:consoleCommandToggleHUD()
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        local settings = g_realisticHarvestManager.settings
        settings.showHUD = not settings.showHUD
        settings:save()
        return string.format("HUD: %s", settings.showHUD and "ON" or "OFF")
    end
    
    return "Error: RHM not initialized"
end

function SettingsGUI:consoleCommandShowSettings()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end
    
    local settings = g_realisticHarvestManager.settings
    local userRole = settings:isAdmin() and "Administrator" or "User"
    
    local info = string.format(
        "=== RHM Settings ===\n" ..
        "Role: %s\n" ..
        "\n[Server Settings]\n" ..
        "Difficulty: %s\n" ..
        "Speed Limiting: %s\n" ..
        "Crop Loss: %s\n" ..
        "\n[Personal Settings]\n" ..
        "Show HUD: %s\n" ..
        "HUD Offset X: %d\n" ..
        "HUD Offset Y: %d\n" ..
        "Unit System: %s",
        userRole,
        settings:getDifficultyName(),
        settings.enableSpeedLimit and "ON" or "OFF",
        settings.enableCropLoss and "ON" or "OFF",
        settings.showHUD and "ON" or "OFF",
        settings.hudOffsetX or 0,
        settings.hudOffsetY,
        settings.unitSystem == 1 and "Metric" or (settings.unitSystem == 2 and "Imperial" or "Bushels")
    )
    print(info)
    return info
end

function SettingsGUI:consoleCommandSetHUDOffset(offset)
    local offsetY = tonumber(offset)
    if not offsetY or offsetY < 100 or offsetY > 500 then
        Logging.warning("RHM: Invalid HUD offset. Use value between 100 and 500")
        return "Invalid offset (use 100-500)"
    end
    
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        local settings = g_realisticHarvestManager.settings
        settings.hudOffsetY = offsetY
        settings:save()
        
        -- Оновити HUD якщо він активний
        if g_realisticHarvestManager.hud then
            g_realisticHarvestManager.hud.posY = offsetY / g_screenHeight
        end
        
        return string.format("HUD Offset Y set to: %d", offsetY)
    end
    
    return "Error: RHM not initialized"
end

function SettingsGUI:consoleCommandMoveHUDLeft()
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        local settings = g_realisticHarvestManager.settings
        settings.hudOffsetX = math.max(-200, settings.hudOffsetX - 10)
        settings:save()
        
        -- Позиція оновиться автоматично в HUD:draw() на наступному кадрі
        
        return string.format("HUD Offset X: %d (moved LEFT)", settings.hudOffsetX)
    end
    
    return "Error: RHM not initialized"
end

function SettingsGUI:consoleCommandMoveHUDRight()
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        local settings = g_realisticHarvestManager.settings
        settings.hudOffsetX = math.min(200, settings.hudOffsetX + 10)
        settings:save()
        
        -- Позиція оновиться автоматично в HUD:draw() на наступному кадрі
        
        return string.format("HUD Offset X: %d (moved RIGHT)", settings.hudOffsetX)
    end
    
    return "Error: RHM not initialized"
end

---Консольна команда для скидання налаштувань
function SettingsGUI:consoleCommandResetSettings()
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        g_realisticHarvestManager.settings:resetToDefaults()
        
        -- Оновлюємо UI якщо він ініціалізований
        if g_realisticHarvestManager.settingsUI then
            g_realisticHarvestManager.settingsUI:refreshUI()
        end
        
        return "RHM: Settings reset to defaults! UI refreshed. (Difficulty: Normal, Speed Limit: ON, Crop Loss: ON, HUD: ON)"
    end
    
    return "Error: RHM not initialized"
end

-- ============================================================================
-- COMBINE SETTINGS CONSOLE COMMANDS
-- ============================================================================

---Отримує поточний активний комбайн гравця
---@return table|nil vehicle Комбайн або nil
function SettingsGUI:getCurrentCombine()
    -- Отримуємо поточну техніку (з fallback методами)
    local vehicle = nil
    
    -- 1. Standard way
    if g_currentMission and g_currentMission.controlledVehicle then
        vehicle = g_currentMission.controlledVehicle
    -- 2. Local player fallback
    elseif g_localPlayer and g_localPlayer.getCurrentVehicle then
        vehicle = g_localPlayer:getCurrentVehicle()
    -- 3. Iterate entered vehicles (extreme fallback)
    elseif g_currentMission and g_currentMission.vehicles then
        for _, v in pairs(g_currentMission.vehicles) do
            if v.getIsEntered and v:getIsEntered() then
                vehicle = v
                break
            end
        end
    end
    
    if not vehicle then
        return nil
    end
    
    -- Перевіряємо чи є наш spec
    local specName = "spec_FS25_RealisticHarvesting.rhm_Combine"
    if vehicle[specName] or vehicle.spec_rhm_Combine then
        return vehicle
    end
    
    return nil
end

---Показує статус налаштувань комбайна
function SettingsGUI:consoleCommandCombineStatus()
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end
    
    if not g_realisticHarvestManager or not g_realisticHarvestManager.combineSettingsGUI then
        return "[X] Combine Settings GUI not initialized"
    end
    
    local gui = g_realisticHarvestManager.combineSettingsGUI
    gui:open(vehicle)  -- open() вже викликає printStatus()
    
    return ""
end

---Встановити AUTO режим
function SettingsGUI:consoleCommandCombineAuto()
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end
    
    if not g_realisticHarvestManager or not g_realisticHarvestManager.combineSettingsGUI then
        return "[X] Combine Settings GUI not initialized"
    end
    
    local gui = g_realisticHarvestManager.combineSettingsGUI
    gui:open(vehicle)
    gui:setModeAuto()
    
    return "[OK] Mode set to AUTO"
end

---Встановити MANUAL режим
function SettingsGUI:consoleCommandCombineManual()
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end
    
    if not g_realisticHarvestManager or not g_realisticHarvestManager.combineSettingsGUI then
        return "[X] Combine Settings GUI not initialized"
    end
    
    local gui = g_realisticHarvestManager.combineSettingsGUI
    gui:open(vehicle)
    gui:setModeManual()
    
    return "[OK] Mode set to MANUAL"
end

---Встановити параметр
function SettingsGUI:consoleCommandCombineSet(param, value)
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end
    
    if not param or not value then
        return "[X] Usage: rhm_set <param> <value>\\n   Valid params: fan, upperSieve, lowerSieve, rotor, feeder"
    end
    
    if not g_realisticHarvestManager or not g_realisticHarvestManager.combineSettingsGUI then
        return "[X] Combine Settings GUI not initialized"
    end
    
    local gui = g_realisticHarvestManager.combineSettingsGUI
    gui:open(vehicle)
    gui:setParameter(param, value)
    
    return string.format("[OK] %s set to %s%%", param, value)
end

---Завантажити профіль
function SettingsGUI:consoleCommandCombineLoad(profileName)
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end
    
    if not profileName then
        return "[X] Usage: rhm_load <profile>\\n   Use rhm_profiles to see available profiles"
    end
    
    if not g_realisticHarvestManager or not g_realisticHarvestManager.combineSettingsGUI then
        return "[X] Combine Settings GUI not initialized"
    end
    
    local gui = g_realisticHarvestManager.combineSettingsGUI
    gui:open(vehicle)
    gui:loadProfile(profileName)
    
    return string.format("[OK] Profile loaded: %s", profileName)
end

---Зберегти профіль
function SettingsGUI:consoleCommandCombineSave(profileName)
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end
    
    if not profileName then
        return "[X] Usage: rhm_save <name>"
    end
    
    if not g_realisticHarvestManager or not g_realisticHarvestManager.combineSettingsGUI then
        return "[X] Combine Settings GUI not initialized"
    end
    
    local gui = g_realisticHarvestManager.combineSettingsGUI
    gui:open(vehicle)
    gui:saveProfile(profileName)
    
    return string.format("[OK] Profile saved: %s", profileName)
end

---Показати всі профілі
function SettingsGUI:consoleCommandCombineProfiles()
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end
    
    if not g_realisticHarvestManager or not g_realisticHarvestManager.combineSettingsGUI then
        return "[X] Combine Settings GUI not initialized"
    end
    
    local gui = g_realisticHarvestManager.combineSettingsGUI
    gui:open(vehicle)
    gui:listProfiles()
    
    return "Profiles listed in console"
end

