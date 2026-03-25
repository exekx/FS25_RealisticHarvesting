-- EN: Legacy console-based settings interface for the combine. Allows the player to view
--     combine settings status and control them through in-game console commands.
--     This is a secondary interface alongside the visual RHMCombineCalibrationGUI.
-- UA: Консольний інтерфейс налаштувань комбайна (застарілий). Дозволяє гравцеві переглядати
--     стан налаштувань комбайна та керувати ними через консольні команди в грі.
--     Це допоміжний інтерфейс поруч з візуальним RHMCombineCalibrationGUI.
RHMCombineSettingsGUI = {}
local CombineSettingsGUI_mt = Class(RHMCombineSettingsGUI)

-- EN: Creates a new GUI instance with no active vehicle or memory attached.
-- UA: Створює новий екземпляр GUI без прив'язаного транспорту або пам'яті.
function RHMCombineSettingsGUI.new()
    local self = setmetatable({}, CombineSettingsGUI_mt)

    self.isOpen = false
    self.combineMemory = nil  -- EN: Set at open time / UA: Встановлюється при відкритті
    self.currentVehicle = nil

    return self
end

-- EN: Opens the settings interface for a specific combine vehicle.
--     Validates that the vehicle has the rhm_Combine spec and a RHM_CombineMemory instance.
-- UA: Відкриває інтерфейс налаштувань для конкретного комбайна.
--     Перевіряє, що транспорт має специфікацію rhm_Combine та екземпляр RHM_CombineMemory.
function RHMCombineSettingsGUI:open(vehicle)
    if not vehicle then
        rhm_log("RHM [UI]: " .. "RHM: Cannot open settings - not a valid combine")
        return false
    end

    -- EN: Support both direct spec access and namespaced access (mod-specific path).
    -- UA: Підтримка прямого доступу до spec та доступу через простір імен (шлях мода).
    local spec = vehicle.spec_rhm_Combine or vehicle["spec_FS25_RealisticHarvesting.rhm_Combine"]

    if not spec then
        rhm_log("RHM [UI]: " .. "RHM: Cannot open settings - not a valid combine")
        return false
    end

    if not spec.combineMemory then
        rhm_log("RHM [UI]: " .. "RHM: Cannot open settings - no memory system")
        return false
    end

    self.isOpen = true
    self.combineMemory = spec.combineMemory
    self.currentVehicle = vehicle

    -- EN: Print current status to the in-game console for the player to read.
    -- UA: Виводимо поточний стан у внутрішньоігрову консоль для читання гравцем.
    self:printStatus()

    return true
end

-- EN: Closes the settings interface and detaches from the current vehicle.
-- UA: Закриває інтерфейс налаштувань та відключається від поточного транспорту.
function RHMCombineSettingsGUI:close()
    self.isOpen = false
    self.combineMemory = nil
    self.currentVehicle = nil
end

-- EN: Prints the full current combine settings status to the in-game console.
--     Shows mode, current crop, active settings values, any penalties, and available commands.
-- UA: Виводить повний поточний стан налаштувань комбайна у внутрішньоігрову консоль.
--     Показує режим, поточну культуру, значення налаштувань, штрафи та доступні команди.
function RHMCombineSettingsGUI:printStatus()
    if not self.combineMemory then
        return
    end

    local memory = self.combineMemory

    rhm_log("RHM [UI]: " .. "======================================================")
    rhm_log("RHM [UI]: " .. "[*] COMBINE SETTINGS MENU")
    rhm_log("RHM [UI]: " .. "======================================================")

    -- EN: Operating mode: AUTO or MANUAL.
    -- UA: Режим роботи: AUTO або MANUAL.
    rhm_log("RHM [UI]: " .. string.format("Mode: %s", memory.mode))

    -- EN: Currently harvested crop.
    -- UA: Поточна культура, що збирається.
    if memory.currentCrop then
        local cropData = RHM_CombineSettingsDatabase:getCropData(memory.currentCrop)
        local cropName = cropData and cropData.nameEN or memory.currentCrop
        rhm_log("RHM [UI]: " .. string.format("Current Crop: %s", cropName))
    else
        rhm_log("RHM [UI]: " .. "Current Crop: NONE (start harvesting to detect)")
    end

    if memory.currentProfile then
        rhm_log("RHM [UI]: " .. string.format("Active Profile: %s", memory.currentProfile))
    else
        rhm_log("RHM [UI]: " .. "Active Profile: NONE")
    end

    rhm_log("RHM [UI]: " .. "======================================================")
    rhm_log("RHM [UI]: " .. "[CURRENT SETTINGS]")
    rhm_log("RHM [UI]: " .. "======================================================")

    local settings = memory.currentSettings
    rhm_log("RHM [UI]: " .. string.format("  Fan:         %3d%%", settings.fan))
    rhm_log("RHM [UI]: " .. string.format("  Upper Sieve: %3d%%", settings.upperSieve))
    rhm_log("RHM [UI]: " .. string.format("  Lower Sieve: %3d%%", settings.lowerSieve))
    rhm_log("RHM [UI]: " .. string.format("  Rotor:       %3d%%", settings.rotor))
    rhm_log("RHM [UI]: " .. string.format("  Feeder:      %3d%%", settings.feeder))

    -- EN: Evaluate settings against the current crop and show any loss penalties.
    -- UA: Оцінюємо налаштування для поточної культури і показуємо будь-які штрафи.
    if memory.currentCrop then
        local penalty, warnings = memory:checkSettingsForCrop(memory.currentCrop)

        if penalty > 0 then
            rhm_log("RHM [UI]: " .. "======================================================")
            rhm_log("RHM [UI]: " .. string.format("[!] CROP LOSS: %.1f%%", penalty))
            rhm_log("RHM [UI]: " .. "======================================================")
            for _, warning in ipairs(warnings) do
                rhm_log("RHM [UI]: " .. string.format("  [!] %s: Current=%d%%, Optimal=%d%%, Penalty=%.1f%%",
                    warning.param, warning.current, warning.optimal, warning.penalty))
            end
        else
            rhm_log("RHM [UI]: " .. "======================================================")
            rhm_log("RHM [UI]: " .. "[OK] SETTINGS OPTIMAL - No Crop Loss")
            rhm_log("RHM [UI]: " .. "======================================================")
        end
    end

    local profileCount = memory:getProfileCount()
    if profileCount > 0 then
        rhm_log("RHM [UI]: " .. "======================================================")
        rhm_log("RHM [UI]: " .. string.format("[SAVED PROFILES: %d]", profileCount))
        rhm_log("RHM [UI]: " .. "======================================================")

        for profileName, profileData in pairs(memory.savedProfiles) do
            local activeMarker = (profileName == memory.currentProfile) and " [ACTIVE]" or ""
            rhm_log("RHM [UI]: " .. string.format("  [#] %s%s - Used: %dx",
                profileName, activeMarker, profileData.stats.timesUsed))
        end
    else
        rhm_log("RHM [UI]: " .. "======================================================")
        rhm_log("RHM [UI]: " .. "[PROFILES] No profiles saved yet")
        rhm_log("RHM [UI]: " .. "======================================================")
    end

    -- EN: Show available console commands for controlling the combine.
    -- UA: Показуємо доступні консольні команди для управління комбайном.
    rhm_log("RHM [UI]: " .. "======================================================")
    rhm_log("RHM [UI]: " .. "[CONSOLE COMMANDS]")
    rhm_log("RHM [UI]: " .. "======================================================")
    rhm_log("RHM [UI]: " .. "  rhm_auto              - Enable AUTO mode")
    rhm_log("RHM [UI]: " .. "  rhm_manual            - Enable MANUAL mode")
    rhm_log("RHM [UI]: " .. "  rhm_set <param> <val> - Set parameter (fan, rotor, etc)")
    rhm_log("RHM [UI]: " .. "  rhm_load <profile>    - Load profile")
    rhm_log("RHM [UI]: " .. "  rhm_save <name>       - Save current as  profile")
    rhm_log("RHM [UI]: " .. "  rhm_status            - Show this menu again")
    rhm_log("RHM [UI]: " .. "  rhm_profiles          - List all profiles")
    rhm_log("RHM [UI]: " .. "======================================================")
end

-- EN: Activates AUTO mode — sets optimal settings for the currently detected crop.
-- UA: Активує режим AUTO — встановлює оптимальні налаштування для поточної визначеної культури.
function RHMCombineSettingsGUI:setModeAuto()
    if not self.combineMemory then
        return
    end

    if self.combineMemory.currentCrop then
        self.combineMemory:setMode("AUTO")
        rhm_log("RHM [UI]: " .. "[OK] Mode set to AUTO")
        self:printStatus()
    else
        rhm_log("RHM [UI]: " .. "[!] Cannot set AUTO mode - no crop detected yet. Start harvesting first!")
    end
end

-- EN: Activates MANUAL mode — allows the player to manually adjust all settings.
-- UA: Активує режим MANUAL — дозволяє гравцеві вручну регулювати всі налаштування.
function RHMCombineSettingsGUI:setModeManual()
    if not self.combineMemory then
        return
    end

    self.combineMemory:setMode("MANUAL")
    rhm_log("RHM [UI]: " .. "[OK] Mode set to MANUAL - You can now adjust settings")
    self:printStatus()
end

-- EN: Sets a single combine parameter to the specified value (0-100).
-- UA: Встановлює один параметр комбайна на задане значення (0-100).
function RHMCombineSettingsGUI:setParameter(paramName, value)
    if not self.combineMemory then
        return
    end

    local numValue = tonumber(value)
    if not numValue then
        rhm_log("RHM [UI]: " .. string.format("[X] Invalid value: %s (must be a number)", tostring(value)))
        return
    end

    if self.combineMemory:setParameter(paramName, numValue) then
        rhm_log("RHM [UI]: " .. string.format("[OK] %s set to %d%%", paramName, numValue))
        self:printStatus()
    else
        rhm_log("RHM [UI]: " .. string.format("[X] Invalid parameter: %s", paramName))
        rhm_log("RHM [UI]: " .. "Valid parameters: fan, upperSieve, lowerSieve, rotor, feeder")
    end
end

-- EN: Loads a named profile from the combine memory (legacy method, profiles now in RHM_ProfileManager).
-- UA: Завантажує іменований профіль з пам'яті комбайна (застарілий метод, профілі тепер у RHM_ProfileManager).
function RHMCombineSettingsGUI:loadProfile(profileName)
    if not self.combineMemory then
        return
    end

    if self.combineMemory:loadProfile(profileName) then
        rhm_log("RHM [UI]: " .. string.format("[OK] Profile loaded: %s", profileName))
        self:printStatus()
    else
        rhm_log("RHM [UI]: " .. string.format("[X] Profile not found: %s", profileName))
        self:listProfiles()
    end
end

-- EN: Saves the current settings as a named profile for the active crop.
-- UA: Зберігає поточні налаштування як іменований профіль для активної культури.
function RHMCombineSettingsGUI:saveProfile(profileName)
    if not self.combineMemory then
        return
    end

    if not self.combineMemory.currentCrop then
        rhm_log("RHM [UI]: " .. "[X] Cannot save profile - no crop detected yet")
        return
    end

    self.combineMemory:saveCurrentProfile(self.combineMemory.currentCrop, profileName)
    rhm_log("RHM [UI]: " .. string.format("[OK] Profile saved: %s", profileName))
    self:printStatus()
end

-- EN: Lists all saved profiles to the console.
-- UA: Виводить список всіх збережених профілів у консоль.
function RHMCombineSettingsGUI:listProfiles()
    if not self.combineMemory then
        return
    end

    local profileCount = self.combineMemory:getProfileCount()

    rhm_log("RHM [UI]: " .. "======================================================")
    rhm_log("RHM [UI]: " .. string.format("[ALL PROFILES: %d]", profileCount))
    rhm_log("RHM [UI]: " .. "======================================================")

    if profileCount == 0 then
        rhm_log("RHM [UI]: " .. "  No profiles saved")
    else
        for profileName, profileData in pairs(self.combineMemory.savedProfiles) do
            local activeMarker = (profileName == self.combineMemory.currentProfile) and " [ACTIVE]" or ""
            rhm_log("RHM [UI]: " .. string.format("  [#] %s%s", profileName, activeMarker))
            rhm_log("RHM [UI]: " .. string.format("     Crop: %s, Used: %dx, Last: %s",
                profileData.cropType,
                profileData.stats.timesUsed,
                profileData.stats.lastUsed or "Never"))
        end
    end

    rhm_log("RHM [UI]: " .. "======================================================")
end

rhm_log("RHM [UI]: [OK] RHMCombineSettingsGUI loaded")


