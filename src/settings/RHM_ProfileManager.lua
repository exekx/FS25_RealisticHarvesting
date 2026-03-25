-- EN: Manages global user crop profiles, persisted in the FS25 modSettings folder.
--     Profiles store per-crop combine settings (fan, rotor, sieves, feeder) that the player
--     has manually saved, and are reloaded across game sessions.
-- UA: Керує глобальними профілями налаштувань культур, збережених у папці modSettings FS25.
--     Профілі зберігають налаштування комбайна для кожної культури (вентилятор, ротор, решета, подача),
--     які гравець зберіг вручну, і перезавантажуються між ігровими сесіями.
RHM_ProfileManager = {}
local ProfileManager_mt = Class(RHM_ProfileManager)

-- EN: XML root tag path used within the profiles XML file.
-- UA: Шлях кореневого тегу XML, що використовується у файлі профілів.
RHM_ProfileManager.XMLTAG = "realisticHarvestingProfiles.profiles"

-- EN: Creates a new RHM_ProfileManager instance with an empty profiles table.
-- UA: Створює новий екземпляр RHM_ProfileManager з порожньою таблицею профілів.
function RHM_ProfileManager.new()
    local self = setmetatable({}, ProfileManager_mt)
    self.profiles = {}
    return self
end

-- EN: Returns the absolute path to the profiles XML file in the modSettings directory.
--     Creates the modSettings and mod-specific subdirectory if they do not exist yet.
-- UA: Повертає абсолютний шлях до XML-файлу профілів у директорії modSettings.
--     Створює директорії modSettings і підпапку мода, якщо вони ще не існують.
function RHM_ProfileManager:getXmlFilePath()
    local userPath = getUserProfileAppPath()
    if not userPath then
        RHM_Debug.log("RHMSettings", "RHM: ERROR - Cannot get user profile path for profiles")
        return nil
    end

    local modSettingsPath = userPath .. "modSettings"
    local rhmPath = modSettingsPath .. "/FS25_RealisticHarvesting"

    if not fileExists(modSettingsPath) then
        createFolder(modSettingsPath)
    end

    if not fileExists(rhmPath) then
        createFolder(rhmPath)
    end

    return rhmPath .. "/profiles.xml"
end

-- EN: Loads all crop profiles from the XML file into memory.
--     Returns false if the file does not exist yet (first launch).
-- UA: Завантажує всі профілі культур з XML-файлу в пам'ять.
--     Повертає false, якщо файл ще не існує (перший запуск).
function RHM_ProfileManager:loadProfiles()
    local xmlPath = self:getXmlFilePath()
    if not xmlPath or not fileExists(xmlPath) then
        return false
    end

    local xml = XMLFile.load("RHM_Profiles", xmlPath)
    if xml then
        self.profiles = {}
        local i = 0
        while true do
            local key = string.format("%s.profile(%d)", self.XMLTAG, i)
            if not xml:hasProperty(key) then
                break
            end

            -- EN: Read each profile entry by crop name.
            -- UA: Зчитуємо кожен запис профілю за назвою культури.
            local cropName = xml:getString(key .. "#cropName")
            if cropName then
                self.profiles[cropName] = {
                    fan = xml:getInt(key .. "#fan", 50),
                    rotor = xml:getInt(key .. "#rotor", 50),
                    upperSieve = xml:getInt(key .. "#upperSieve", 50),
                    lowerSieve = xml:getInt(key .. "#lowerSieve", 50),
                    feeder = xml:getInt(key .. "#feeder", 50),
                    targetEngineLoad = xml:getInt(key .. "#targetEngineLoad", 95)
                }
            end
            i = i + 1
        end
        xml:delete()
        RHM_Debug.log("RHMSettings", string.format("RHM: Loaded %d user crop profiles from %s", i, xmlPath))
        return true
    end
    return false
end

-- EN: Saves all currently loaded profiles back to the XML file on disk.
--     Called automatically after any profile change via saveProfile().
-- UA: Зберігає всі поточно завантажені профілі назад у XML-файл на диску.
--     Викликається автоматично після будь-якої зміни профілю через saveProfile().
function RHM_ProfileManager:saveProfiles()
    local xmlPath = self:getXmlFilePath()
    if not xmlPath then return false end

    local xml = XMLFile.create("RHM_Profiles", xmlPath, "realisticHarvestingProfiles")
    if xml then
        local i = 0
        for cropName, settings in pairs(self.profiles) do
            local key = string.format("%s.profile(%d)", self.XMLTAG, i)
            xml:setString(key .. "#cropName", cropName)
            xml:setInt(key .. "#fan", settings.fan or 50)
            xml:setInt(key .. "#rotor", settings.rotor or 50)
            xml:setInt(key .. "#upperSieve", settings.upperSieve or 50)
            xml:setInt(key .. "#lowerSieve", settings.lowerSieve or 50)
            xml:setInt(key .. "#feeder", settings.feeder or 50)
            xml:setInt(key .. "#targetEngineLoad", settings.targetEngineLoad or 95)
            i = i + 1
        end
        xml:save()
        xml:delete()
        RHM_Debug.log("RHMSettings", string.format("RHM: Saved %d user crop profiles to %s", i, xmlPath))
        return true
    end
    return false
end

-- EN: Returns the profile for a specific crop name, or nil if none is saved.
-- UA: Повертає профіль для конкретної назви культури, або nil якщо профілю немає.
function RHM_ProfileManager:getProfile(cropName)
    if not cropName then return nil end
    return self.profiles[cropName]
end

-- EN: Saves or overwrites a profile for a specific crop with the given settings.
--     Immediately persists the change to the XML file.
-- UA: Зберігає або перезаписує профіль для конкретної культури з заданими налаштуваннями.
--     Негайно зберігає зміну у XML-файл.
function RHM_ProfileManager:saveProfile(cropName, settings)
    if not cropName or not settings then return false end

    self.profiles[cropName] = {
        fan = settings.fan or 50,
        rotor = settings.rotor or 50,
        upperSieve = settings.upperSieve or 50,
        lowerSieve = settings.lowerSieve or 50,
        feeder = settings.feeder or 50,
        targetEngineLoad = settings.targetEngineLoad or 95
    }

    self:saveProfiles()
    return true
end


