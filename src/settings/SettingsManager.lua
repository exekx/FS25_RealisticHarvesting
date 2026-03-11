-- EN: Handles persistence of mod settings using two separate XML files:
--     - Server settings (settings.xml): difficulty, speed limit, crop loss — shared for all players (admin-only change)
--     - Client settings (client.xml): HUD visibility, position, unit system — per-player preferences
--     Both files are stored in the FS25 modSettings/FS25_RealisticHarvesting folder for global access across saves.
-- UA: Відповідає за збереження налаштувань мода за допомогою двох окремих XML-файлів:
--     - Серверні налаштування (settings.xml): складність, ліміт швидкості, втрати врожаю — спільні для всіх гравців (зміна тільки адміном)
--     - Клієнтські налаштування (client.xml): видимість HUD, позиція, система одиниць — персональні переваги гравця
--     Обидва файли зберігаються в папці modSettings/FS25_RealisticHarvesting для доступу незалежно від карти.
SettingsManager = {}
local SettingsManager_mt = Class(SettingsManager)

SettingsManager.MOD_NAME = g_currentModName
-- EN: XML root element tag used in both settings files.
-- UA: Назва кореневого тегу XML, що використовується у файлах налаштувань.
SettingsManager.XMLTAG = "realisticHarvestManager"

-- EN: List of server-side setting keys (shared globally, admin-only write).
-- UA: Список ключів серверних налаштувань (глобальні, тільки адмін може змінювати).
SettingsManager.SERVER_SETTINGS = {
    "difficultyMotor",
    "difficultyLoss",
    "enableSpeedLimit",
    "enableCropLoss",
    "enableIndependentLaunch"
}

-- EN: List of client-side setting keys (personal, per-player, HUD-related).
-- UA: Список ключів клієнтських налаштувань (персональні, для кожного гравця, пов'язані з HUD).
SettingsManager.CLIENT_SETTINGS = {
    "showHUD",
    "showYield",
    "showLoad",
    "showProductivity",
    "showCropLoss",
    "showSpeed",
    "showLoadWarnings",
    "hudOffsetX",
    "hudOffsetY",
    "hudPosX",
    "hudPosY",
    "unitSystem",
    "showSpeedometer"
}

-- EN: Default configuration values used as fallback when no saved file exists.
-- UA: Значення конфігурації за замовчуванням, що використовуються якщо збережений файл відсутній.
SettingsManager.defaultConfig = {
    difficultyMotor = 2,
    difficultyLoss = 2,
    showHUD = true,
    showYield = true,
    showSpeedometer = true,
    enableSpeedLimit = true,
    enableCropLoss = false,
    enableIndependentLaunch = true,
    hudOffsetX = 0,
    hudOffsetY = 350,
    unitSystem = 1
}

-- EN: Creates a new SettingsManager instance.
-- UA: Створює новий екземпляр SettingsManager.
function SettingsManager.new()
    return setmetatable({}, SettingsManager_mt)
end

-- EN: Returns the absolute path to the server settings XML file.
--     Creates required directories (modSettings and mod subfolder) if they don't exist.
-- UA: Повертає абсолютний шлях до XML-файлу серверних налаштувань.
--     Створює необхідні директорії (modSettings та підпапку мода), якщо вони не існують.
function SettingsManager:getServerXmlFilePath()
    local userPath = getUserProfileAppPath()
    if not userPath then
        print("RHM: ERROR - Cannot get user profile path")
        return nil
    end

    local modSettingsPath = userPath .. "modSettings"
    local rhmPath = modSettingsPath .. "/FS25_RealisticHarvesting"

    if not fileExists(modSettingsPath) then
        createFolder(modSettingsPath)
        print(string.format("RHM: Created modSettings directory: %s", modSettingsPath))
    end

    if not fileExists(rhmPath) then
        createFolder(rhmPath)
        print(string.format("RHM: Created mod settings directory: %s", rhmPath))
    end

    return rhmPath .. "/settings.xml"
end

-- EN: Returns the absolute path to the client settings XML file (same folder as server file).
--     The client file is "client.xml" alongside "settings.xml".
-- UA: Повертає абсолютний шлях до XML-файлу клієнтських налаштувань (та сама папка, що й серверний файл).
--     Клієнтський файл — "client.xml" поруч з "settings.xml".
function SettingsManager:getClientXmlFilePath()
    local serverPath = self:getServerXmlFilePath()
    if not serverPath then return nil end
    return serverPath:gsub("settings.xml$", "client.xml")
end

-- EN: Legacy method kept for backward compatibility. Returns the server XML path.
-- UA: Застарілий метод для зворотньої сумісності. Повертає шлях до серверного XML.
function SettingsManager:getSavegameXmlFilePath()
    return self:getServerXmlFilePath()
end

-- EN: Loads server-side settings from the XML file into the settings object.
--     Falls back to defaults if the file doesn't exist or cannot be parsed.
--     Handles migration from legacy single "difficulty" field to split fields.
-- UA: Завантажує серверні налаштування з XML-файлу в об'єкт налаштувань.
--     Використовує значення за замовчуванням, якщо файл відсутній або не може бути прочитаний.
--     Обробляє міграцію з застарілого поля "difficulty" до роздільних полів.
function SettingsManager:loadServerSettings(settingsObject)
    local xmlPath = self:getServerXmlFilePath()

    print(string.format("RHM: [Load] Attempting to load server settings from: %s", tostring(xmlPath)))
    print(string.format("RHM: [Load] File exists: %s", tostring(xmlPath and fileExists(xmlPath))))

    if xmlPath and fileExists(xmlPath) then
        local xml = XMLFile.load("RHM_ServerConfig", xmlPath)
        if xml then
            for _, key in ipairs(self.SERVER_SETTINGS) do
                local xmlKey = self.XMLTAG.."."..key
                if key == "difficultyMotor" or key == "difficultyLoss" or key == "hudOffsetX" or key == "hudOffsetY" or key == "unitSystem" then
                    settingsObject[key] = xml:getInt(xmlKey, self.defaultConfig[key])
                else
                    settingsObject[key] = xml:getBool(xmlKey, self.defaultConfig[key])
                end
            end
            xml:delete()

            print(string.format("RHM: [Load] Loaded values - Motor: %s, Loss: %s, SpeedLimit: %s",
                tostring(settingsObject.difficultyMotor),
                tostring(settingsObject.difficultyLoss),
                tostring(settingsObject.enableSpeedLimit)))

            -- EN: MIGRATION: If split difficulty fields are missing, try reading the legacy "difficulty" key.
            -- UA: МІГРАЦІЯ: Якщо роздільні поля відсутні, спробуємо зчитати застарілий ключ "difficulty".
            if settingsObject.difficultyMotor == nil and settingsObject.difficultyLoss == nil then
                local legacyXml = XMLFile.load("RHM_ServerConfig_Legacy", xmlPath)
                if legacyXml then
                    local legacyDifficulty = legacyXml:getInt(self.XMLTAG..".difficulty", 2)
                    settingsObject.difficultyMotor = legacyDifficulty
                    settingsObject.difficultyLoss = legacyDifficulty
                    print(string.format("RHM: Migrated legacy difficulty (%d) to split fields", legacyDifficulty))
                    legacyXml:delete()
                end
            end

            return
        end
    end

    -- EN: File missing or unreadable — use defaults.
    -- UA: Файл відсутній або нечитабельний — використовуємо значення за замовчуванням.
    print("RHM: [Load] Using default values")
    for _, key in ipairs(self.SERVER_SETTINGS) do
        settingsObject[key] = self.defaultConfig[key]
    end
end

-- EN: Loads client-side settings (HUD prefs) from the client XML file.
--     Falls back to defaults if the file is missing.
-- UA: Завантажує клієнтські налаштування (преференції HUD) з клієнтського XML-файлу.
--     Використовує значення за замовчуванням, якщо файл відсутній.
function SettingsManager:loadClientSettings(settingsObject)
    local xmlPath = self:getClientXmlFilePath()
    if xmlPath and fileExists(xmlPath) then
        local xml = XMLFile.load("RHM_ClientConfig", xmlPath)
        if xml then
            for _, key in ipairs(self.CLIENT_SETTINGS) do
                local xmlKey = self.XMLTAG.."."..key
                if key == "hudOffsetX" or key == "hudOffsetY" or key == "unitSystem" then
                    settingsObject[key] = xml:getInt(xmlKey, self.defaultConfig[key] or 0)
                elseif key == "hudPosX" or key == "hudPosY" then
                    -- EN: HUD position stored as float (nil if not set = auto positioning).
                    -- UA: Позиція HUD зберігається як float (nil якщо не встановлено = автоматичне позиціонування).
                    settingsObject[key] = xml:getFloat(xmlKey)
                else
                    settingsObject[key] = xml:getBool(xmlKey, self.defaultConfig[key])
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
function SettingsManager:loadSettings(settingsObject)
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
function SettingsManager:saveServerSettings(settingsObject)
    local xmlPath = self:getServerXmlFilePath()
    if not xmlPath then
        print("RHM: [Save] ERROR - Cannot get server XML path (savegame directory not available)")
        return
    end

    print(string.format("RHM: [Save] Saving server settings to: %s", xmlPath))
    print(string.format("RHM: [Save] Values - Motor: %s, Loss: %s, SpeedLimit: %s, CropLoss: %s",
        tostring(settingsObject.difficultyMotor),
        tostring(settingsObject.difficultyLoss),
        tostring(settingsObject.enableSpeedLimit),
        tostring(settingsObject.enableCropLoss)))

    local xml = XMLFile.create("RHM_ServerConfig", xmlPath, self.XMLTAG)
    if xml then
        for _, key in ipairs(self.SERVER_SETTINGS) do
            local xmlKey = self.XMLTAG.."."..key
            if key == "difficultyMotor" or key == "difficultyLoss" then
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
            print(string.format("RHM: [Save] ✓ File verified to exist: %s", xmlPath))
        else
            print(string.format("RHM: [Save] ✗ WARNING - File does NOT exist after save: %s", xmlPath))
        end

        print("RHM: [Save] Server settings saved successfully")
    else
        print("RHM: [Save] ERROR - Failed to create XML file")
    end
end

-- EN: Saves client-side settings (HUD preferences) to client.xml for the current player.
-- UA: Зберігає клієнтські налаштування (переваги HUD) у client.xml для поточного гравця.
function SettingsManager:saveClientSettings(settingsObject)
    local xmlPath = self:getClientXmlFilePath()
    if not xmlPath then return end

    local xml = XMLFile.create("RHM_ClientConfig", xmlPath, self.XMLTAG)
    if xml then
        for _, key in ipairs(self.CLIENT_SETTINGS) do
            local xmlKey = self.XMLTAG.."."..key
            if key == "hudOffsetX" or key == "hudOffsetY" or key == "unitSystem" then
                xml:setInt(xmlKey, settingsObject[key])
            elseif key == "hudPosX" or key == "hudPosY" then
                -- EN: Only save position if it has been explicitly set (not nil = auto).
                -- UA: Зберігаємо позицію тільки якщо вона була явно встановлена (не nil = авто).
                if settingsObject[key] ~= nil then
                    xml:setFloat(xmlKey, settingsObject[key])
                end
            else
                xml:setBool(xmlKey, settingsObject[key])
            end
        end
        xml:save()
        xml:delete()
    end
end

-- EN: Main save method — saves server settings if on server, client settings if on client.
-- UA: Головний метод збереження — зберігає серверні налаштування якщо на сервері, клієнтські якщо на клієнті.
function SettingsManager:saveSettings(settingsObject)
    if g_currentMission:getIsServer() then
        self:saveServerSettings(settingsObject)
    end

    if g_currentMission:getIsClient() then
        self:saveClientSettings(settingsObject)
    end
end