---@class CombineSettingsGUI
---Простий текстовий інтерфейс для налаштувань комбайна (схожий на консольні команди)
CombineSettingsGUI = {}
local CombineSettingsGUI_mt = Class(CombineSettingsGUI)

function CombineSettingsGUI.new()
    local self = setmetatable({}, CombineSettingsGUI_mt)
    
    self.isOpen = false
    self.combineMemory = nil  -- Буде встановлено при відкритті
    self.currentVehicle = nil
    
    return self
end

---Відкриває меню налаштувань
---@param vehicle table Комбайн
function CombineSettingsGUI:open(vehicle)
    if not vehicle then
        print("RHM: Cannot open settings - not a valid combine")
        return false
    end
    
    -- Отримуємо spec (спробуємо обидва варіанти)
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
    
    -- Виводимо інформацію в консоль
    self:printStatus()
    
    return true
end

---Закриває меню
function CombineSettingsGUI:close()
    self.isOpen = false
    self.combineMemory = nil
    self.currentVehicle = nil
end

---Виводить поточний стан налаштувань в консоль
function CombineSettingsGUI:printStatus()
    if not self.combineMemory then
        return
    end
    
    local memory = self.combineMemory
    
    print("======================================================")
    print("[*] COMBINE SETTINGS MENU")
    print("======================================================")
    
    -- Режим
    print(string.format("Mode: %s", memory.mode))
    
    -- Поточна культура
    if memory.currentCrop then
        local cropData = CombineSettingsDatabase:getCropData(memory.currentCrop)
        local cropName = cropData and cropData.nameEN or memory.currentCrop
        print(string.format("Current Crop: %s", cropName))
    else
        print("Current Crop: NONE (start harvesting to detect)")
    end
    
    -- Поточний профіль
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
    
    -- Показуємо перевірку налаштувань
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
    
    -- Список профілів
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
    
    -- Допомога
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

---Встановлює режим AUTO
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

---Встановлює режим MANUAL
function CombineSettingsGUI:setModeManual()
    if not self.combineMemory then
        return
    end
    
    self.combineMemory:setMode("MANUAL")
    print("[OK] Mode set to MANUAL - You can now adjust settings")
    self:printStatus()
end

---Встановлює параметр
---@param paramName string Назва параметру
---@param value number Значення (0-100)
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

---Завантажує профіль
---@param profileName string Назва профілю
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

---Зберігає поточні налаштування як профіль
---@param profileName string Назва профілю
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

---Виводить список профілів
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
