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

-- EN: Creates a new RHM_ProfileManager instance with empty profile tables.
-- UA: Створює новий екземпляр RHM_ProfileManager з порожніми таблицями профілів.
function RHM_ProfileManager.new()
    local self = setmetatable({}, ProfileManager_mt)
    self.profiles = {}
    self.namedProfiles = {}
    return self
end

-- EN: Returns the absolute path to the profiles XML file in the modSettings directory.
--     Creates the modSettings and mod-specific subdirectory if they do not exist yet.
-- UA: Повертає абсолютний шлях до XML-файлу профілів у директорії modSettings.
--     Створює директорії modSettings і підпапку мода, якщо вони ще не існують.
function RHM_ProfileManager:getXmlFilePath()
    local userPath = getUserProfileAppPath()
    if not userPath then
        rhm_log("RHM [RHMSettings]: RHM: ERROR - Cannot get user profile path for profiles")
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

-- EN: Loads all crop profiles and named profiles from the XML file into memory.
--     Returns false if the file does not exist yet (first launch).
-- UA: Завантажує всі профілі культур та іменовані збереження з XML-файлу в пам'ять.
--     Повертає false, якщо файл ще не існує (перший запуск).
function RHM_ProfileManager:loadProfiles()
    local xmlPath = self:getXmlFilePath()
    if not xmlPath or not fileExists(xmlPath) then
        return false
    end

    local xml = XMLFile.load("RHM_Profiles", xmlPath)
    if xml then
        self.profiles = {}
        self.namedProfiles = {}

        -- 1. Load Custom Named Profiles
        local namedTag = "realisticHarvestingProfiles.namedProfiles"
        local nIdx = 0
        while true do
            local key = string.format("%s.profile(%d)", namedTag, nIdx)
            if not xml:hasProperty(key) then
                break
            end

            local pName = xml:getString(key .. "#name")
            local cropName = xml:getString(key .. "#cropName")
            if pName and cropName then
                local entry = {
                    id = xml:getString(key .. "#id", tostring(nIdx + 1)),
                    name = pName,
                    cropName = cropName,
                    timestamp = xml:getInt(key .. "#timestamp", 0),
                    settings = {
                        fan = xml:getInt(key .. "#fan", 50),
                        rotor = xml:getInt(key .. "#rotor", 50),
                        upperSieve = xml:getInt(key .. "#upperSieve", 50),
                        lowerSieve = xml:getInt(key .. "#lowerSieve", 50),
                        feeder = xml:getInt(key .. "#feeder", 50),
                        targetEngineLoad = xml:getInt(key .. "#targetEngineLoad", 80),
                        -- Machine-specific parameters support
                        drumSpeed = xml:getInt(key .. "#drumSpeed", nil),
                        rollerSpeed = xml:getInt(key .. "#rollerSpeed", nil),
                        pickerSpeed = xml:getInt(key .. "#pickerSpeed", nil),
                        blowerSpeed = xml:getInt(key .. "#blowerSpeed", nil),
                        conveyorSpeed = xml:getInt(key .. "#conveyorSpeed", nil),
                    }
                }
                table.insert(self.namedProfiles, entry)
                -- Also mirror to crop profile map
                if not self.profiles[cropName] then
                    self.profiles[cropName] = entry.settings
                end
            end
            nIdx = nIdx + 1
        end

        -- 2. Load Legacy / Single Crop Profiles
        local i = 0
        while true do
            local key = string.format("%s.profile(%d)", self.XMLTAG, i)
            if not xml:hasProperty(key) then
                break
            end

            local cropName = xml:getString(key .. "#cropName")
            if cropName and not self.profiles[cropName] then
                local legacySettings = {
                    fan = xml:getInt(key .. "#fan", 50),
                    rotor = xml:getInt(key .. "#rotor", 50),
                    upperSieve = xml:getInt(key .. "#upperSieve", 50),
                    lowerSieve = xml:getInt(key .. "#lowerSieve", 50),
                    feeder = xml:getInt(key .. "#feeder", 50),
                    targetEngineLoad = xml:getInt(key .. "#targetEngineLoad", 80)
                }
                self.profiles[cropName] = legacySettings

                -- Migrate legacy profile to named profiles if none exist yet
                if nIdx == 0 then
                    table.insert(self.namedProfiles, {
                        id = tostring(i + 1),
                        name = cropName,
                        cropName = cropName,
                        timestamp = 0,
                        settings = legacySettings
                    })
                end
            end
            i = i + 1
        end

        xml:delete()
        rhm_log(string.format("RHM [RHMSettings]: RHM: Loaded %d named profiles and %d crop profiles from %s", #self.namedProfiles, i, xmlPath))
        return true
    end
    return false
end

-- EN: Saves all currently loaded profiles and named profiles back to the XML file on disk.
-- UA: Зберігає всі завантажені профілі та іменовані записи назад у XML-файл на диску.
function RHM_ProfileManager:saveProfiles()
    local xmlPath = self:getXmlFilePath()
    if not xmlPath then return false end

    local xml = XMLFile.create("RHM_Profiles", xmlPath, "realisticHarvestingProfiles")
    if xml then
        -- 1. Save Named Profiles
        local namedTag = "realisticHarvestingProfiles.namedProfiles"
        for nIdx, prof in ipairs(self.namedProfiles) do
            local key = string.format("%s.profile(%d)", namedTag, nIdx - 1)
            xml:setString(key .. "#id", tostring(prof.id or nIdx))
            xml:setString(key .. "#name", tostring(prof.name or prof.cropName))
            xml:setString(key .. "#cropName", tostring(prof.cropName or "UNKNOWN"))
            xml:setInt(key .. "#timestamp", tonumber(prof.timestamp) or 0)

            local s = prof.settings or {}
            xml:setInt(key .. "#fan", s.fan or 50)
            xml:setInt(key .. "#rotor", s.rotor or 50)
            xml:setInt(key .. "#upperSieve", s.upperSieve or 50)
            xml:setInt(key .. "#lowerSieve", s.lowerSieve or 50)
            xml:setInt(key .. "#feeder", s.feeder or 50)
            xml:setInt(key .. "#targetEngineLoad", s.targetEngineLoad or 80)

            if s.drumSpeed ~= nil then xml:setInt(key .. "#drumSpeed", s.drumSpeed) end
            if s.rollerSpeed ~= nil then xml:setInt(key .. "#rollerSpeed", s.rollerSpeed) end
            if s.pickerSpeed ~= nil then xml:setInt(key .. "#pickerSpeed", s.pickerSpeed) end
            if s.blowerSpeed ~= nil then xml:setInt(key .. "#blowerSpeed", s.blowerSpeed) end
            if s.conveyorSpeed ~= nil then xml:setInt(key .. "#conveyorSpeed", s.conveyorSpeed) end
        end

        -- 2. Save Legacy Crop Profiles for fallback
        local i = 0
        for cropName, settings in pairs(self.profiles) do
            local key = string.format("%s.profile(%d)", self.XMLTAG, i)
            xml:setString(key .. "#cropName", cropName)
            xml:setInt(key .. "#fan", settings.fan or 50)
            xml:setInt(key .. "#rotor", settings.rotor or 50)
            xml:setInt(key .. "#upperSieve", settings.upperSieve or 50)
            xml:setInt(key .. "#lowerSieve", settings.lowerSieve or 50)
            xml:setInt(key .. "#feeder", settings.feeder or 50)
            xml:setInt(key .. "#targetEngineLoad", settings.targetEngineLoad or 80)
            i = i + 1
        end

        xml:save()
        xml:delete()
        rhm_log(string.format("RHM [RHMSettings]: RHM: Saved %d named profiles and %d crop profiles to %s", #self.namedProfiles, i, xmlPath))
        return true
    end
    return false
end

-- EN: Returns all saved named profiles, optionally filtered by cropName.
-- UA: Повертає список збережених іменованих профілів, опціонально відфільтрованих за культурою.
function RHM_ProfileManager:getNamedProfiles(cropFilter)
    if not cropFilter or cropFilter == "" or cropFilter == "ALL" then
        return self.namedProfiles or {}
    end

    local filterUpper = string.upper(cropFilter)
    local filtered = {}
    for _, prof in ipairs(self.namedProfiles or {}) do
        if prof.cropName and string.upper(prof.cropName) == filterUpper then
            table.insert(filtered, prof)
        end
    end
    return filtered
end

-- EN: Saves or overwrites a named profile with custom player title and crop.
-- UA: Зберігає або перезаписує іменований профіль з назвою гравця та культурою.
function RHM_ProfileManager:saveNamedProfile(name, cropName, settings)
    if not cropName or not settings then return false end

    local cleanName = name and name:match("^%s*(.-)%s*$")
    if not cleanName or cleanName == "" then
        cleanName = tostring(cropName)
    end

    local settingsCopy = {}
    for k, v in pairs(settings) do
        settingsCopy[k] = v
    end

    -- Check if profile with identical custom name and crop already exists
    local existingIndex = nil
    for idx, prof in ipairs(self.namedProfiles) do
        if string.lower(prof.name or "") == string.lower(cleanName) and string.upper(prof.cropName or "") == string.upper(cropName) then
            existingIndex = idx
            break
        end
    end

    local entry = {
        id = tostring(math.floor(getTime() or 0)) .. "_" .. tostring(math.random(100, 999)),
        name = cleanName,
        cropName = cropName,
        timestamp = math.floor(getTime() or 0),
        settings = settingsCopy
    }

    if existingIndex then
        self.namedProfiles[existingIndex] = entry
    else
        table.insert(self.namedProfiles, 1, entry)
    end

    -- Update legacy per-crop map as well
    self.profiles[cropName] = settingsCopy

    self:saveProfiles()
    return true
end

-- EN: Deletes a named profile by its ID or index.
-- UA: Видаляє іменований профіль за його ID або індексом.
function RHM_ProfileManager:deleteNamedProfile(idOrIndex)
    if not idOrIndex then return false end

    local removeIdx = nil
    if type(idOrIndex) == "number" and self.namedProfiles[idOrIndex] then
        removeIdx = idOrIndex
    else
        for idx, prof in ipairs(self.namedProfiles) do
            if tostring(prof.id) == tostring(idOrIndex) then
                removeIdx = idx
                break
            end
        end
    end

    if removeIdx then
        table.remove(self.namedProfiles, removeIdx)
        self:saveProfiles()
        return true
    end
    return false
end

-- EN: Returns the profile for a specific crop name, or nil if none is saved.
-- UA: Повертає профіль для конкретної назви культури, або nil якщо профілю немає.
function RHM_ProfileManager:getProfile(cropName)
    if not cropName then return nil end
    local prof = self.profiles[cropName]
    if prof then return prof end

    local rawUpper = cropName:upper()
    prof = self.profiles[rawUpper]
    if prof then return prof end

    if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.cropAliases then
        local alias = RHM_CombineSettingsDatabase.cropAliases[cropName] or RHM_CombineSettingsDatabase.cropAliases[rawUpper]
        if alias then
            prof = self.profiles[alias] or self.profiles[alias:upper()]
            if prof then return prof end
        end
    end

    -- Fallback to first matching named profile
    for _, np in ipairs(self.namedProfiles or {}) do
        if np.cropName and (np.cropName:upper() == rawUpper) then
            return np.settings
        end
    end

    return nil
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
        targetEngineLoad = settings.targetEngineLoad or 80
    }

    self:saveProfiles()
    return true
end


