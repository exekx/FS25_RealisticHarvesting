---@class CombineSettingsGUI
-- EN: Legacy console-based settings interface for the combine. Allows the player to view
--     combine settings status and control them through in-game console commands.
--     This is a secondary interface alongside the visual CombineCalibrationGUI.
-- UA: Консольний інтерфейс налаштувань комбайна (застарілий). Дозволяє гравцеві переглядати
--     стан налаштувань комбайна та керувати ними через консольні команди в грі.
--     Це допоміжний інтерфейс поруч з візуальним CombineCalibrationGUI.
CombineSettingsGUI = {}
local CombineSettingsGUI_mt = Class(CombineSettingsGUI)

-- EN: Creates a new GUI instance with no active vehicle or memory attached.
-- UA: Створює новий екземпляр GUI без прив'язаного транспорту або пам'яті.
function CombineSettingsGUI.new()
    local self = setmetatable({}, CombineSettingsGUI_mt)

    self.isOpen = false
    self.combineMemory = nil  -- EN: Set at open time / UA: Встановлюється при відкритті
    self.currentVehicle = nil

    return self
end

-- EN: Opens the settings interface for a specific combine vehicle.
--     Validates that the vehicle has the rhm_Combine spec and a CombineMemory instance.
-- UA: Відкриває інтерфейс налаштувань для конкретного комбайна.
--     Перевіряє, що транспорт має специфікацію rhm_Combine та екземпляр CombineMemory.
---@param vehicle table
function CombineSettingsGUI:open(vehicle)
    if not vehicle then
        print("RHM: Cannot open settings - not a valid combine")
        return false
    end

    -- EN: Support both direct spec access and namespaced access (mod-specific path).
    -- UA: Підтримка прямого доступу до spec та доступу через простір імен (шлях мода).
    local spec = vehicle.spec_rhm_Combine or vehicle["spec_FS25_RealisticHarvesting.rhm_Combine"]

    if not spec then
        print("RHM: Cannot open settings - not a valid combine")
        return false
    end

    if not spec.combineMemory then
        print("RHM: Cannot open settings - no memory system")
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
function CombineSettingsGUI:close()
    self.isOpen = false
    self.combineMemory = nil
    self.currentVehicle = nil
end

-- EN: Prints the full current combine settings status to the in-game console.
--     Shows mode, current crop, active settings values, any penalties, and available commands.
-- UA: Виводить повний поточний стан налаштувань комбайна у внутрішньоігрову консоль.
--     Показує режим, поточну культуру, значення налаштувань, штрафи та доступні команди.
function CombineSettingsGUI:printStatus()
    if not self.combineMemory then
        return
    end

    local memory = self.combineMemory

    print("======================================================")
    print("[*] COMBINE SETTINGS MENU")
    print("======================================================")

    -- EN: Operating mode: AUTO or MANUAL.
    -- UA: Режим роботи: AUTO або MANUAL.
    print(string.format("Mode: %s", memory.mode))

    -- EN: Currently harvested crop.
    -- UA: Поточна культура, що збирається.
    if memory.currentCrop then
        local cropData = CombineSettingsDatabase:getCropData(memory.currentCrop)
        local cropName = cropData and cropData.nameEN or memory.currentCrop
        print(string.format("Current Crop: %s", cropName))
    else
        print("Current Crop: NONE (start harvesting to detect)")
    end

    if memory.currentProfile then
        print(string.format("Active Profile: %s", memory.currentProfile))
    else
        print("Active Profile: NONE")
    end

    print("======================================================")
    print("[CURRENT SETTINGS]")
    print("======================================================")

    local settings = memory.currentSettings
    print(string.format("  Fan:         %3d%%", settings.fan))
    print(string.format("  Upper Sieve: %3d%%", settings.upperSieve))
    print(string.format("  Lower Sieve: %3d%%", settings.lowerSieve))
    print(string.format("  Rotor:       %3d%%", settings.rotor))
    print(string.format("  Feeder:      %3d%%", settings.feeder))

    -- EN: Evaluate settings against the current crop and show any loss penalties.
    -- UA: Оцінюємо налаштування для поточної культури і показуємо будь-які штрафи.
    if memory.currentCrop then
        local penalty, warnings = memory:checkSettingsForCrop(memory.currentCrop)

        if penalty > 0 then
            print("======================================================")
            print(string.format("[!] CROP LOSS: %.1f%%", penalty))
            print("======================================================")
            for _, warning in ipairs(warnings) do
                print(string.format("  [!] %s: Current=%d%%, Optimal=%d%%, Penalty=%.1f%%",
                    warning.param, warning.current, warning.optimal, warning.penalty))
            end
        else
            print("======================================================")
            print("[OK] SETTINGS OPTIMAL - No Crop Loss")
            print("======================================================")
        end
    end

    local profileCount = memory:getProfileCount()
    if profileCount > 0 then
        print("======================================================")
        print(string.format("[SAVED PROFILES: %d]", profileCount))
        print("======================================================")

        for profileName, profileData in pairs(memory.savedProfiles) do
            local activeMarker = (profileName == memory.currentProfile) and " [ACTIVE]" or ""
            print(string.format("  [#] %s%s - Used: %dx",
                profileName, activeMarker, profileData.stats.timesUsed))
        end
    else
        print("======================================================")
        print("[PROFILES] No profiles saved yet")
        print("======================================================")
    end

    -- EN: Show available console commands for controlling the combine.
    -- UA: Показуємо доступні консольні команди для управління комбайном.
    print("======================================================")
    print("[CONSOLE COMMANDS]")
    print("======================================================")
    print("  rhm_auto              - Enable AUTO mode")
    print("  rhm_manual            - Enable MANUAL mode")
    print("  rhm_set <param> <val> - Set parameter (fan, rotor, etc)")
    print("  rhm_load <profile>    - Load profile")
    print("  rhm_save <name>       - Save current as  profile")
    print("  rhm_status            - Show this menu again")
    print("  rhm_profiles          - List all profiles")
    print("======================================================")
end

-- EN: Activates AUTO mode — sets optimal settings for the currently detected crop.
-- UA: Активує режим AUTO — встановлює оптимальні налаштування для поточної визначеної культури.
function CombineSettingsGUI:setModeAuto()
    if not self.combineMemory then
        return
    end

    if self.combineMemory.currentCrop then
        self.combineMemory:setMode("AUTO")
        print("[OK] Mode set to AUTO")
        self:printStatus()
    else
        print("[!] Cannot set AUTO mode - no crop detected yet. Start harvesting first!")
    end
end

-- EN: Activates MANUAL mode — allows the player to manually adjust all settings.
-- UA: Активує режим MANUAL — дозволяє гравцеві вручну регулювати всі налаштування.
function CombineSettingsGUI:setModeManual()
    if not self.combineMemory then
        return
    end

    self.combineMemory:setMode("MANUAL")
    print("[OK] Mode set to MANUAL - You can now adjust settings")
    self:printStatus()
end

-- EN: Sets a single combine parameter to the specified value (0-100).
-- UA: Встановлює один параметр комбайна на задане значення (0-100).
---@param paramName string EN: Parameter name (fan, rotor, upperSieve, lowerSieve, feeder) / UA: Назва параметру
---@param value number EN: Target value (0-100) / UA: Цільове значення (0-100)
function CombineSettingsGUI:setParameter(paramName, value)
    if not self.combineMemory then
        return
    end

    local numValue = tonumber(value)
    if not numValue then
        print(string.format("[X] Invalid value: %s (must be a number)", tostring(value)))
        return
    end

    if self.combineMemory:setParameter(paramName, numValue) then
        print(string.format("[OK] %s set to %d%%", paramName, numValue))
        self:printStatus()
    else
        print(string.format("[X] Invalid parameter: %s", paramName))
        print("Valid parameters: fan, upperSieve, lowerSieve, rotor, feeder")
    end
end

-- EN: Loads a named profile from the combine memory (legacy method, profiles now in ProfileManager).
-- UA: Завантажує іменований профіль з пам'яті комбайна (застарілий метод, профілі тепер у ProfileManager).
---@param profileName string
function CombineSettingsGUI:loadProfile(profileName)
    if not self.combineMemory then
        return
    end

    if self.combineMemory:loadProfile(profileName) then
        print(string.format("[OK] Profile loaded: %s", profileName))
        self:printStatus()
    else
        print(string.format("[X] Profile not found: %s", profileName))
        self:listProfiles()
    end
end

-- EN: Saves the current settings as a named profile for the active crop.
-- UA: Зберігає поточні налаштування як іменований профіль для активної культури.
---@param profileName string
function CombineSettingsGUI:saveProfile(profileName)
    if not self.combineMemory then
        return
    end

    if not self.combineMemory.currentCrop then
        print("[X] Cannot save profile - no crop detected yet")
        return
    end

    self.combineMemory:saveCurrentProfile(self.combineMemory.currentCrop, profileName)
    print(string.format("[OK] Profile saved: %s", profileName))
    self:printStatus()
end

-- EN: Lists all saved profiles to the console.
-- UA: Виводить список всіх збережених профілів у консоль.
function CombineSettingsGUI:listProfiles()
    if not self.combineMemory then
        return
    end

    local profileCount = self.combineMemory:getProfileCount()

    print("======================================================")
    print(string.format("[ALL PROFILES: %d]", profileCount))
    print("======================================================")

    if profileCount == 0 then
        print("  No profiles saved")
    else
        for profileName, profileData in pairs(self.combineMemory.savedProfiles) do
            local activeMarker = (profileName == self.combineMemory.currentProfile) and " [ACTIVE]" or ""
            print(string.format("  [#] %s%s", profileName, activeMarker))
            print(string.format("     Crop: %s, Used: %dx, Last: %s",
                profileData.cropType,
                profileData.stats.timesUsed,
                profileData.stats.lastUsed or "Never"))
        end
    end

    print("======================================================")
end

print("[OK] CombineSettingsGUI loaded")
