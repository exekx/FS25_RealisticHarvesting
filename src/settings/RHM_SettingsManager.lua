-- EN: Handles persistence of mod settings using two separate XML files:
--     - Server settings (settings.xml): difficulty, speed limit, crop loss — shared for all players (admin-only change)
--     - Client settings (client.xml): HUD visibility, position, unit system — per-player preferences
--     Both files are stored in the FS25 modSettings/FS25_RealisticHarvesting folder for global access across saves.
-- UA: Відповідає за збереження налаштувань мода за допомогою двох окремих XML-файлів:
--     - Серверні налаштування (settings.xml): складність, ліміт швидкості, втрати врожаю — спільні для всіх гравців (зміна тільки адміном)
--     - Клієнтські налаштування (client.xml): видимість HUD, позиція, система одиниць — персональні переваги гравця
--     Обидва файли зберігаються в папці modSettings/FS25_RealisticHarvesting для доступу незалежно від карти.
RHMSettingsManager = {}
local SettingsManager_mt = Class(RHMSettingsManager)

RHMSettingsManager.MOD_NAME = g_currentModName
-- EN: XML root element tag used in both settings files.
-- UA: Назва кореневого тегу XML, що використовується у файлах налаштувань.
RHMSettingsManager.XMLTAG = "realisticHarvestManager"

-- EN: List of server-side setting keys (shared globally, admin-only write).
-- UA: Список ключів серверних налаштувань (глобальні, тільки адмін може змінювати).
RHMSettingsManager.SERVER_SETTINGS = {
    "difficultyMotor",
    "difficultyLoss",
    "aiHelperTuning",
    "enableSpeedLimit",
    "enableCropLoss",
    "enableWearLoss",
    "enableIndependentLaunch",
    "enableMoisture"
}

-- EN: List of client-side setting keys (personal, per-player, HUD-related).
-- UA: Список ключів клієнтських налаштувань (персональні, для кожного гравця, пов'язані з HUD).
RHMSettingsManager.CLIENT_SETTINGS = {
    "showHUD",
    "showYield",
    "showLoad",
    "showProductivity",
    "showCropLoss",
    "showSpeed",
    "showMoisture",
    "hudPosX",
    "hudPosY",
    "hudDocked",
    "unitSystem",
    "enableAlarmSound",
    "alarmMode",
    "soundVolume",
    "enableTutorials"
}

-- EN: Default configuration values used as fallback when no saved file exists.
-- UA: Значення конфігурації за замовчуванням, що використовуються якщо збережений файл відсутній.
RHMSettingsManager.defaultConfig = {
    difficultyMotor = 2,
    difficultyLoss = 2,
    aiHelperTuning = 1,
    showHUD = true,
    showYield = true,
    enableSpeedLimit = true,
    enableCropLoss = false,
    enableWearLoss = true,
    enableIndependentLaunch = true,
    enableMoisture = true,
    showMoisture = true,
    enableAlarmSound = true,
    alarmMode = 1,
    soundVolume = 1.0,
    enableTutorials = true,
    unitSystem = 1
}

-- EN: Creates a new RHMSettingsManager instance.
-- UA: Створює новий екземпляр RHMSettingsManager.
function RHMSettingsManager.new()
    return setmetatable({}, SettingsManager_mt)
end

-- EN: Returns the absolute path to the server settings XML file.
--     Creates required directories (modSettings and mod subfolder) if they don't exist.
-- UA: Повертає абсолютний шлях до XML-файлу серверних налаштувань.
--     Створює необхідні директорії (modSettings та підпапку мода), якщо вони не існують.
function RHMSettingsManager:getServerXmlFilePath()
    local userPath = getUserProfileAppPath()
    if not userPath then
        rhm_log("RHM [RHMSettings]: RHM: ERROR - Cannot get user profile path")
        return nil
    end

    local modSettingsPath = userPath .. "modSettings"
    local rhmPath = modSettingsPath .. "/FS25_RealisticHarvesting"

    if not fileExists(modSettingsPath) then
        createFolder(modSettingsPath)
        rhm_log(string.format("RHM [RHMSettings]: RHM: Created modSettings directory: %s", modSettingsPath))
    end

    if not fileExists(rhmPath) then
        createFolder(rhmPath)
        rhm_log(string.format("RHM [RHMSettings]: RHM: Created mod settings directory: %s", rhmPath))
    end

    return rhmPath .. "/settings.xml"
end

-- EN: Returns the absolute path to the client settings XML file (same folder as server file).
--     The client file is "client.xml" alongside "settings.xml".
-- UA: Повертає абсолютний шлях до XML-файлу клієнтських налаштувань (та сама папка, що й серверний файл).
--     Клієнтський файл — "client.xml" поруч з "settings.xml".
function RHMSettingsManager:getClientXmlFilePath()
    local serverPath = self:getServerXmlFilePath()
    if not serverPath then return nil end
    return serverPath:gsub("settings.xml$", "client.xml")
end

-- EN: Legacy method kept for backward compatibility. Returns the server XML path.
-- UA: Застарілий метод для зворотньої сумісності. Повертає шлях до серверного XML.
function RHMSettingsManager:getSavegameXmlFilePath()
    return self:getServerXmlFilePath()
end

-- EN: Loads server-side settings from the XML file into the settings object.
--     Falls back to defaults if the file doesn't exist or cannot be parsed.
--     Handles migration from legacy single "difficulty" field to split fields.
-- UA: Завантажує серверні налаштування з XML-файлу в об'єкт налаштувань.
--     Використовує значення за замовчуванням, якщо файл відсутній або не може бути прочитаний.
--     Обробляє міграцію з застарілого поля "difficulty" до роздільних полів.
function RHMSettingsManager:loadServerSettings(settingsObject)
    local xmlPath = self:getServerXmlFilePath()

    rhm_log(string.format("RHM [RHMSettings]: RHM: [Load] Attempting to load server settings from: %s", tostring(xmlPath)))
    rhm_log(string.format("RHM [RHMSettings]: RHM: [Load] File exists: %s", tostring(xmlPath and fileExists(xmlPath))))

    if xmlPath and fileExists(xmlPath) then
        local xml = XMLFile.load("RHM_ServerConfig", xmlPath)
        if xml then
            for _, key in ipairs(self.SERVER_SETTINGS) do
                local xmlKey = self.XMLTAG.."."..key
                if key == "difficultyMotor" or key == "difficultyLoss" or key == "aiHelperTuning" then
                    settingsObject[key] = xml:getInt(xmlKey, self.defaultConfig[key])
                else
                    settingsObject[key] = xml:getBool(xmlKey, self.defaultConfig[key])
                end
            end
            xml:delete()

            rhm_log(string.format("RHM [RHMSettings]: RHM: [Load] Loaded values - Motor: %s, Loss: %s, SpeedLimit: %s",
                tostring(settingsObject.difficultyMotor),
                tostring(settingsObject.difficultyLoss),
                tostring(settingsObject.enableSpeedLimit)))
            return
        end
    end

    -- EN: File missing or unreadable — use defaults.
    -- UA: Файл відсутній або нечитабельний — використовуємо значення за замовчуванням.
    rhm_log("RHM [RHMSettings]: RHM: [Load] Using default values")
    for _, key in ipairs(self.SERVER_SETTINGS) do
        settingsObject[key] = self.defaultConfig[key]
    end
end

-- EN: Loads client-side settings (HUD prefs) from the client XML file.
--     Falls back to defaults if the file is missing.
-- UA: Завантажує клієнтські налаштування (преференції HUD) з клієнтського XML-файлу.
--     Використовує значення за замовчуванням, якщо файл відсутній.
function RHMSettingsManager:loadClientSettings(settingsObject)
    local xmlPath = self:getClientXmlFilePath()
    if xmlPath and fileExists(xmlPath) then
        local xml = XMLFile.load("RHM_ClientConfig", xmlPath)
        if xml then
            for _, key in ipairs(self.CLIENT_SETTINGS) do
                local xmlKey = self.XMLTAG.."."..key
                if key == "unitSystem" or key == "alarmMode" then
                    settingsObject[key] = xml:getInt(xmlKey, self.defaultConfig[key] or 1)
                elseif key == "hudPosX" or key == "hudPosY" then
                    -- EN: HUD position stored as float (nil if not set = auto positioning).
                    -- UA: Позиція HUD зберігається як float (nil якщо не встановлено = автоматичне позиціонування).
                    settingsObject[key] = xml:getFloat(xmlKey)
                elseif key == "soundVolume" then
                    settingsObject[key] = math.min(1.0, math.max(0.0, xml:getFloat(xmlKey, self.defaultConfig[key] or 1.0)))
                else
                    settingsObject[key] = xml:getBool(xmlKey, self.defaultConfig[key])
                end
            end

            -- EN: Load seen tutorial flags to prevent repeating hints
            -- UA: Завантажуємо прапорці переглянутих підказок щоб не повторювати їх
            if RHM_NotificationManager then
                local seenStr = xml:getString(self.XMLTAG..".seenTutorials", "")
                if seenStr and seenStr ~= "" then
                    RHM_NotificationManager.seenTutorials = RHM_NotificationManager.seenTutorials or {}
                    for tutKey in seenStr:gmatch("[^;]+") do
                        RHM_NotificationManager.seenTutorials[tutKey] = true
                    end
                    if RHM_NotificationManager.INSTANCE then
                        RHM_NotificationManager.INSTANCE.seenTutorials = RHM_NotificationManager.seenTutorials
                    end
                end
            end

            xml:delete()
            return
        end
    end

    -- EN: Fallback to defaults for all client settings.
    -- UA: Використовуємо значення за замовчуванням для всіх клієнтських налаштувань.
    for _, key in ipairs(self.CLIENT_SETTINGS) do
        settingsObject[key] = self.defaultConfig[key]
    end
end

-- EN: Main load method — loads both server and client settings.
--     Everyone reads server settings; each client also reads their own client settings.
-- UA: Головний метод завантаження — завантажує серверні та клієнтські налаштування.
--     Всі читають серверні налаштування; кожен клієнт також читає власні клієнтські налаштування.
function RHMSettingsManager:loadSettings(settingsObject)
    self:loadServerSettings(settingsObject)

    if g_currentMission:getIsClient() then
        self:loadClientSettings(settingsObject)
    end
end

-- EN: Saves server-side settings to settings.xml. Only the server should call this.
--     Verifies the file actually exists after writing (safeguard).
-- UA: Зберігає серверні налаштування у settings.xml. Тільки сервер повинен це викликати.
--     EN: Verifies that the file actually exists after writing (safety measure).
--     UA: Перевіряє, що файл справді існує після запису (запобіжний захід).
function RHMSettingsManager:saveServerSettings(settingsObject)
    local xmlPath = self:getServerXmlFilePath()
    if not xmlPath then
        rhm_log("RHM [RHMSettings]: RHM: [Save] ERROR - Cannot get server XML path (savegame directory not available)")
        return
    end

    rhm_log(string.format("RHM [RHMSettings]: RHM: [Save] Saving server settings to: %s", xmlPath))
    rhm_log(string.format("RHM [RHMSettings]: RHM: [Save] Values - Motor: %s, Loss: %s, SpeedLimit: %s, CropLoss: %s",
        tostring(settingsObject.difficultyMotor),
        tostring(settingsObject.difficultyLoss),
        tostring(settingsObject.enableSpeedLimit),
        tostring(settingsObject.enableCropLoss)))

    local xml = XMLFile.create("RHM_ServerConfig", xmlPath, self.XMLTAG)
    if xml then
        for _, key in ipairs(self.SERVER_SETTINGS) do
            local xmlKey = self.XMLTAG.."."..key
            if key == "difficultyMotor" or key == "difficultyLoss" or key == "aiHelperTuning" then
                xml:setInt(xmlKey, settingsObject[key])
            else
                xml:setBool(xmlKey, settingsObject[key])
            end
        end
        xml:save()
        xml:delete()

        -- EN: Verify the file was actually saved to disk.
        -- UA: Перевіряємо що файл справді збережений на диску.
        if fileExists(xmlPath) then
            rhm_log(string.format("RHM [RHMSettings]: RHM: [Save] [OK] File verified to exist: %s", xmlPath))
        else
            rhm_log(string.format("RHM [RHMSettings]: RHM: [Save] [WARN] File does NOT exist after save: %s", xmlPath))
        end

        rhm_log("RHM [RHMSettings]: RHM: [Save] Server settings saved successfully")
    else
        rhm_log("RHM [RHMSettings]: RHM: [Save] ERROR - Failed to create XML file")
    end
end

-- EN: Saves client-side settings (HUD preferences) to client.xml for the current player.
-- UA: Зберігає клієнтські налаштування (переваги HUD) у client.xml для поточного гравця.
function RHMSettingsManager:saveClientSettings(settingsObject)
    local xmlPath = self:getClientXmlFilePath()
    if not xmlPath then return end

    local xml = XMLFile.create("RHM_ClientConfig", xmlPath, self.XMLTAG)
    if xml then
        for _, key in ipairs(self.CLIENT_SETTINGS) do
            local xmlKey = self.XMLTAG.."."..key
            if key == "unitSystem" or key == "alarmMode" then
                xml:setInt(xmlKey, settingsObject[key] or 1)
            elseif key == "hudPosX" or key == "hudPosY" then
                -- EN: Only save position if it has been explicitly set (not nil = auto).
                -- UA: Зберігаємо позицію тільки якщо вона була явно встановлена (не nil = авто).
                if settingsObject[key] ~= nil then
                    xml:setFloat(xmlKey, settingsObject[key])
                end
            elseif key == "soundVolume" then
                xml:setFloat(xmlKey, math.min(1.0, math.max(0.0, settingsObject[key] or 1.0)))
            else
                xml:setBool(xmlKey, settingsObject[key] or false)
            end
        end

        -- EN: Save seen tutorial flags
        -- UA: Зберігаємо прапорці переглянутих підказок
        if RHM_NotificationManager and RHM_NotificationManager.seenTutorials then
            local seenList = {}
            for tutKey, seen in pairs(RHM_NotificationManager.seenTutorials) do
                if seen then
                    table.insert(seenList, tutKey)
                end
            end
            xml:setString(self.XMLTAG..".seenTutorials", table.concat(seenList, ";"))
        end

        xml:save()
        xml:delete()
    end
end

-- EN: Main save method — saves server settings if on server, client settings if on client.
-- UA: Головний метод збереження — зберігає серверні налаштування якщо на сервері, клієнтські якщо на клієнті.
function RHMSettingsManager:saveSettings(settingsObject)
    if g_currentMission:getIsServer() then
        self:saveServerSettings(settingsObject)
    end

    if g_currentMission:getIsClient() then
        self:saveClientSettings(settingsObject)
    end
end
