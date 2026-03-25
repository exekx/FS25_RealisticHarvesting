-- EN: Provides in-game console commands for controlling the Realistic Harvesting mod settings.
--     Includes commands for difficulty, feature toggles, HUD positioning, and combine settings.
--     Server-side (admin-only) settings are protected with permission checks.
-- UA: Надає консольні команди в грі для керування налаштуваннями мода Realistic Harvesting.
--     Включає команди для складності, перемикачів функцій, позиціонування HUD і налаштувань комбайна.
--     Серверні (тільки адмін) налаштування захищені перевіркою прав доступу.
RHMSettingsGUI = {}
local SettingsGUI_mt = Class(RHMSettingsGUI)

function RHMSettingsGUI.new()
    local self = setmetatable({}, SettingsGUI_mt)
    return self
end

-- EN: Registers all console commands for mod settings and combine control.
--     Called once during initialization. Commands appear in the FS25 console.
-- UA: Реєструє всі консольні команди для налаштувань мода і керування комбайном.
--     Викликається один раз під час ініціалізації. Команди з'являються в консолі FS25.
function RHMSettingsGUI:registerConsoleCommands()
    -- EN: Deprecated joint difficulty setter — kept for backward compatibility.
    -- UA: Застарілий спільний параметр складності — збережено для зворотної сумісності.
    addConsoleCommand("rhmSetDifficulty", "[Deprecated] Set both difficulties (1=Arcade, 2=Normal, 3=Realistic). Use rhmSetDifficultyMotor and rhmSetDifficultyLoss instead.", "consoleCommandSetDifficulty", self)

    -- EN: Separate difficulty commands for fine-grained control.
    -- UA: Окремі команди складності для детального керування.
    addConsoleCommand("rhmSetDifficultyMotor", "Set engine load difficulty (1=Arcade, 2=Normal, 3=Realistic)", "consoleCommandSetDifficultyMotor", self)
    addConsoleCommand("rhmSetDifficultyLoss", "Set crop loss difficulty (1=Arcade, 2=Normal, 3=Realistic)", "consoleCommandSetDifficultyLoss", self)

    addConsoleCommand("rhmToggleSpeedLimit", "Toggle speed limiting on/off", "consoleCommandToggleSpeedLimit", self)
    addConsoleCommand("rhmToggleCropLoss", "Toggle crop loss on/off", "consoleCommandToggleCropLoss", self)
    addConsoleCommand("rhmToggleHUD", "Toggle HUD on/off", "consoleCommandToggleHUD", self)
    addConsoleCommand("rhmShowSettings", "Show current settings", "consoleCommandShowSettings", self)

    -- EN: Deprecated HUD position commands — drag-and-drop replaced them.
    -- UA: Застарілі команди позиції HUD — замінені перетягуванням.
    addConsoleCommand("rhmSetHUDOffset", "Set HUD vertical offset (100-500)", "consoleCommandSetHUDOffset", self)
    addConsoleCommand("rhmMoveHUDLeft", "Move HUD to the left by 10px", "consoleCommandMoveHUDLeft", self)
    addConsoleCommand("rhmMoveHUDRight", "Move HUD to the right by 10px", "consoleCommandMoveHUDRight", self)

    addConsoleCommand("rhmResetSettings", "Reset all settings to defaults", "consoleCommandResetSettings", self)
    addConsoleCommand("rhmResetHUD", "Reset HUD position to default", "consoleCommandResetHUD", self)

    -- EN: Combine settings commands (require the player to be seated in a combine).
    -- UA: Команди налаштувань комбайна (потребують щоб гравець сидів у комбайні).
    addConsoleCommand("rhm_status", "Show combine settings status", "consoleCommandCombineStatus", self)
    addConsoleCommand("rhm_auto", "Set combine to AUTO mode", "consoleCommandCombineAuto", self)
    addConsoleCommand("rhm_manual", "Set combine to MANUAL mode", "consoleCommandCombineManual", self)
    addConsoleCommand("rhm_set", "Set combine parameter (usage: rhm_set <param> <value>)", "consoleCommandCombineSet", self)
    addConsoleCommand("rhm_load", "Load combine profile (usage: rhm_load <profile>)", "consoleCommandCombineLoad", self)
    addConsoleCommand("rhm_save", "Save combine profile (usage: rhm_save <name>)", "consoleCommandCombineSave", self)
    addConsoleCommand("rhm_profiles", "List all saved profiles", "consoleCommandCombineProfiles", self)
end

-- EN: [Deprecated] Sets both motor and loss difficulty to the same value.
--     Players should use rhmSetDifficultyMotor / rhmSetDifficultyLoss separately.
-- UA: [Застаріло] Встановлює складність двигуна та втрат на одне значення.
--     Гравцям слід використовувати rhmSetDifficultyMotor / rhmSetDifficultyLoss окремо.
function RHMSettingsGUI:consoleCommandSetDifficulty(difficulty)
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end

    local settings = g_realisticHarvestManager.settings

    if not settings:canChangeServerSettings() then
        return "Error: Admin only - you cannot change server settings"
    end

    local diff = tonumber(difficulty)
    if not diff or diff < 1 or diff > 3 then
        return "Invalid difficulty. Use 1 (Arcade), 2 (Normal), or 3 (Realistic). For separate control use rhmSetDifficultyMotor and rhmSetDifficultyLoss"
    end

    settings:setDifficulty(diff)  -- EN: Sets both Motor and Loss / UA: Встановлює і Motor і Loss
    settings:save()
    local names = {"Arcade", "Normal", "Realistic"}
    return string.format("[Deprecated] Both difficulties set to: %s. Consider using rhmSetDifficultyMotor / rhmSetDifficultyLoss", names[diff] or "?")
end

-- EN: Sets engine load (motor) difficulty independently. Admin only.
-- UA: Встановлює складність навантаження двигуна незалежно. Тільки для адміністратора.
function RHMSettingsGUI:consoleCommandSetDifficultyMotor(difficulty)
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end
    local settings = g_realisticHarvestManager.settings
    if not settings:canChangeServerSettings() then
        return "Error: Admin only"
    end
    local diff = tonumber(difficulty)
    if not diff or diff < 1 or diff > 3 then
        return "Invalid value. Use 1 (Arcade), 2 (Normal), or 3 (Realistic)"
    end
    settings.difficultyMotor = diff
    settings:save()
    local names = {"Arcade", "Normal", "Realistic"}
    return string.format("Difficulty Motor set to: %s", names[diff] or "?")
end

-- EN: Sets crop loss difficulty independently. Admin only.
-- UA: Встановлює складність втрат врожаю незалежно. Тільки для адміністратора.
function RHMSettingsGUI:consoleCommandSetDifficultyLoss(difficulty)
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end
    local settings = g_realisticHarvestManager.settings
    if not settings:canChangeServerSettings() then
        return "Error: Admin only"
    end
    local diff = tonumber(difficulty)
    if not diff or diff < 1 or diff > 3 then
        return "Invalid value. Use 1 (Arcade), 2 (Normal), or 3 (Realistic)"
    end
    settings.difficultyLoss = diff
    settings:save()
    local names = {"Arcade", "Normal", "Realistic"}
    return string.format("Difficulty Loss set to: %s", names[diff] or "?")
end

-- EN: Toggles the speed limiting feature on/off. Admin only (server-side setting).
-- UA: Перемикає функцію обмеження швидкості вкл/викл. Тільки адмін (серверне налаштування).
function RHMSettingsGUI:consoleCommandToggleSpeedLimit()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end

    local settings = g_realisticHarvestManager.settings

    if not settings:canChangeServerSettings() then
        return "Error: Admin only - you cannot change server settings"
    end

    settings.enableSpeedLimit = not settings.enableSpeedLimit
    settings:save()
    return string.format("Speed Limiting: %s", settings.enableSpeedLimit and "ON" or "OFF")
end

-- EN: Toggles crop loss simulation on/off. Admin only (server-side setting).
-- UA: Перемикає симуляцію втрат врожаю вкл/викл. Тільки адмін (серверне налаштування).
function RHMSettingsGUI:consoleCommandToggleCropLoss()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end

    local settings = g_realisticHarvestManager.settings

    if not settings:canChangeServerSettings() then
        return "Error: Admin only - you cannot change server settings"
    end

    settings.enableCropLoss = not settings.enableCropLoss
    settings:save()
    return string.format("Crop Loss: %s", settings.enableCropLoss and "ON" or "OFF")
end

-- EN: Toggles HUD visibility on/off. Client-side setting, doesn't need admin.
-- UA: Перемикає видимість HUD вкл/викл. Клієнтське налаштування, не потребує прав адміна.
function RHMSettingsGUI:consoleCommandToggleHUD()
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        local settings = g_realisticHarvestManager.settings
        settings.showHUD = not settings.showHUD
        settings:save()
        return string.format("HUD: %s", settings.showHUD and "ON" or "OFF")
    end

    return "Error: RHM not initialized"
end

-- EN: Prints a full summary of all current settings to the console.
-- UA: Виводить повний огляд всіх поточних налаштувань у консоль.
function RHMSettingsGUI:consoleCommandShowSettings()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then
        return "Error: RHM not initialized"
    end

    local settings = g_realisticHarvestManager.settings
    local userRole = settings:isAdmin() and "Administrator" or "User"

    local info = string.format(
        "=== RHM RHMSettings ===\n" ..
        "Role: %s\n" ..
        "\n[Server RHMSettings]\n" ..
        "Difficulty Motor: %s\n" ..
        "Difficulty Loss: %s\n" ..
        "Speed Limiting: %s\n" ..
        "Crop Loss: %s\n" ..
        "\n[Personal RHMSettings]\n" ..
        "Show HUD: %s\n" ..
        "HUD Offset X: %d\n" ..
        "HUD Offset Y: %d\n" ..
        "Unit System: %s",
        userRole,
        settings.getDifficultyMotorName and settings:getDifficultyMotorName() or tostring(settings.difficultyMotor),
        settings.getDifficultyLossName and settings:getDifficultyLossName() or tostring(settings.difficultyLoss),
        settings.enableSpeedLimit and "ON" or "OFF",
        settings.enableCropLoss and "ON" or "OFF",
        settings.showHUD and "ON" or "OFF",
        settings.hudOffsetX or 0,
        settings.hudOffsetY or 0,
        settings.unitSystem == 1 and "Metric" or (settings.unitSystem == 2 and "Imperial" or "Bushels")
    )
    rhm_log(info)
    return info
end

-- EN: [Deprecated] HUD offset commands replaced by drag-and-drop.
-- UA: [Застаріло] Команди зміщення HUD замінені перетягуванням.
function RHMSettingsGUI:consoleCommandSetHUDOffset(offset)
    return "WARNING: This command is deprecated. Please use Right Click to drag the HUD, or use rhmResetHUD to reset position."
end

function RHMSettingsGUI:consoleCommandMoveHUDLeft()
    return "WARNING: This command is deprecated. Please use Right Click to drag the HUD."
end

function RHMSettingsGUI:consoleCommandMoveHUDRight()
    return "WARNING: This command is deprecated. Please use Right Click to drag the HUD."
end

-- EN: Resets all settings to factory defaults and refreshes the UI and HUD position.
-- UA: Скидає всі налаштування до заводських значень та оновлює UI і позицію HUD.
function RHMSettingsGUI:consoleCommandResetSettings()
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        g_realisticHarvestManager.settings:resetToDefaults()

        if g_realisticHarvestManager.settingsUI then
            g_realisticHarvestManager.settingsUI:refreshUI()
        end

        if g_realisticHarvestManager.hud then
            local x, y = g_realisticHarvestManager.hud:getPosition()
            g_realisticHarvestManager.hud:setPosition(x, y)
        end

        return "RHM: RHMSettings reset to defaults! UI refreshed. HUD position reset."
    end

    return "Error: RHM not initialized"
end

-- EN: Resets the HUD position to its default auto-calculated position.
-- UA: Скидає позицію HUD до її автоматично розрахованої позиції за замовчуванням.
function RHMSettingsGUI:consoleCommandResetHUD()
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        local settings = g_realisticHarvestManager.settings
        settings.hudPosX = nil -- EN: nil = automatic placement / UA: nil = автоматичне позиціонування
        settings.hudPosY = nil
        settings:save()

        if g_realisticHarvestManager.hud then
            local x, y = g_realisticHarvestManager.hud:getPosition()
            g_realisticHarvestManager.hud:setPosition(x, y)
        end

        return "RHM: HUD position reset to default."
    end
    return "Error: RHM not initialized"
end

-- ============================================================================
-- EN: COMBINE SETTINGS CONSOLE COMMANDS — require the player to be seated in a combine.
-- UA: КОНСОЛЬНІ КОМАНДИ НАЛАШТУВАНЬ КОМБАЙНА — потребують щоб гравець сидів у комбайні.
-- ============================================================================

-- EN: Returns the current combine vehicle the player is seated in, or nil.
-- UA: Повертає поточний комбайн, в якому сидить гравець, або nil.
function RHMSettingsGUI:getCurrentCombine()
    local vehicle = nil

    if g_currentMission and g_currentMission.controlledVehicle then
        vehicle = g_currentMission.controlledVehicle
    elseif g_localPlayer and g_localPlayer.getCurrentVehicle then
        vehicle = g_localPlayer:getCurrentVehicle()
    elseif g_currentMission and g_currentMission.vehicles then
        -- EN: Iterate all mission vehicles as a last resort fallback.
        -- UA: Перебираємо всі транспортні засоби місії як останній резервний варіант.
        for _, v in pairs(g_currentMission.vehicles) do
            if v.getIsEntered and v:getIsEntered() then
                vehicle = v
                break
            end
        end
    end

    if not vehicle then return nil end

    local specName = "spec_FS25_RealisticHarvesting.rhm_Combine"
    if vehicle[specName] or vehicle.spec_rhm_Combine then
        return vehicle
    end

    return nil
end

-- EN: Prints combine settings status to the console without opening any GUI.
-- UA: Виводить стан налаштувань комбайна у консоль без відкриття GUI.
function RHMSettingsGUI:consoleCommandCombineStatus()
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return "[X] Combine Memory not found"
    end

    local mem = spec.combineMemory
    local settings = mem.currentSettings

    local info = string.format(
        "=== RHM Combine Status ===\n" ..
        "Crop:   %s\n" ..
        "Mode:   %s\n" ..
        "Fan:    %d%%\n" ..
        "Rotor:  %d%%\n" ..
        "Upper:  %d%%\n" ..
        "Lower:  %d%%\n" ..
        "Feeder: %d%%\n" ..
        "Profiles: %d saved",
        mem.currentCrop or "NONE",
        mem.mode or "UNKNOWN",
        settings.fan or 0,
        settings.rotor or 0,
        settings.upperSieve or 0,
        settings.lowerSieve or 0,
        settings.feeder or 0,
        mem:getProfileCount()
    )

    rhm_log(info)
    return info
end

-- EN: Activates AUTO mode for the current combine via the combine memory system.
-- UA: Активує AUTO режим для поточного комбайна через систему пам'яті комбайна.
function RHMSettingsGUI:consoleCommandCombineAuto()
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end

    if not g_realisticHarvestManager or not g_realisticHarvestManager.combineSettingsGUI then
        return "[X] Combine RHMSettings GUI not initialized"
    end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return "[X] Combine Memory not found"
    end

    spec.combineMemory:setMode("AUTO")
    return "[OK] Mode set to AUTO"
end

-- EN: Activates MANUAL mode for the current combine.
-- UA: Активує MANUAL режим для поточного комбайна.
function RHMSettingsGUI:consoleCommandCombineManual()
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return "[X] Combine Memory not found"
    end

    spec.combineMemory:setMode("MANUAL")
    return "[OK] Mode set to MANUAL"
end

-- EN: Sets a single combine parameter to the given value via console.
-- UA: Встановлює один параметр комбайна на задане значення через консоль.
function RHMSettingsGUI:consoleCommandCombineSet(param, value)
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end

    if not param or not value then
        return "[X] Usage: rhm_set <param> <value>\\n   Valid params: fan, upperSieve, lowerSieve, rotor, feeder"
    end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return "[X] Combine Memory not found"
    end

    local val = tonumber(value)
    if not val then
        return "[X] Value must be a number"
    end

    local success = spec.combineMemory:setParameter(param, val)
    if success then
        return string.format("[OK] %s set to %d%%", param, val)
    else
        return string.format("[X] Failed to set %s. Invalid parameter?", param)
    end
end

-- EN: Loads a saved profile by name into the current combine memory.
-- UA: Завантажує збережений профіль за назвою до пам'яті поточного комбайна.
function RHMSettingsGUI:consoleCommandCombineLoad(profileName)
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end

    if not profileName then
        return "[X] Usage: rhm_load <profile>\\n   Use rhm_profiles to see available profiles"
    end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return "[X] Combine Memory not found"
    end

    local success = spec.combineMemory:loadProfile(profileName)
    if success then
        return string.format("[OK] Profile loaded: %s", profileName)
    else
        return string.format("[X] Profile not found: %s", profileName)
    end
end

-- EN: Saves the current combine settings as a named profile for the active crop.
-- UA: Зберігає поточні налаштування комбайна як іменований профіль для активної культури.
function RHMSettingsGUI:consoleCommandCombineSave(profileName)
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end

    if not profileName then
        return "[X] Usage: rhm_save <name>"
    end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return "[X] Combine Memory not found"
    end

    local currentCrop = spec.combineMemory.currentCrop or "UNKNOWN"
    local success = spec.combineMemory:saveCurrentProfile(currentCrop, profileName)

    if success then
        return string.format("[OK] Profile saved: %s", profileName)
    else
        return "[X] Failed to save profile"
    end
end

-- EN: Lists all saved profiles for the current combine to the console.
-- UA: Виводить список всіх збережених профілів для поточного комбайна у консоль.
function RHMSettingsGUI:consoleCommandCombineProfiles()
    local vehicle = self:getCurrentCombine()
    if not vehicle then
        return "[X] You must be in a combine to use this command"
    end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        return "[X] Combine Memory not found"
    end

    local names = spec.combineMemory:getProfileNames()
    local info = "=== Saved Profiles ===\n"
    if #names == 0 then
        info = info .. "No profiles found."
    else
        for _, name in ipairs(names) do
            info = info .. "- " .. name .. "\n"
        end
    end

    rhm_log(info)
    return info
end

