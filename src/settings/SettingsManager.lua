---@class SettingsManager
SettingsManager = {}
local SettingsManager_mt = Class(SettingsManager)

SettingsManager.MOD_NAME = g_currentModName
SettingsManager.XMLTAG = "realisticHarvestManager"

-- Server-side settings (global, admin only)
SettingsManager.SERVER_SETTINGS = {
    "difficultyMotor",
    "difficultyLoss",
    "enableSpeedLimit",
    "enableCropLoss"
}

-- Client-side settings (personal, per-player)
SettingsManager.CLIENT_SETTINGS = {
    "showHUD",
    "showYield",
    "showLoad",          -- NEW: Show Engine Load
    "showProductivity",  -- NEW: Show Productivity (t/h)
    "showCropLoss",      -- NEW: Show Crop Loss
    "showSpeed",         -- NEW: Show Speed
    "showLoadWarnings",  -- NEW: Toggle load warnings
    "hudOffsetX",
    "hudOffsetY",
    "hudPosX",      -- NEW: Saved HUD X position
    "hudPosY",      -- NEW: Saved HUD Y position
    "unitSystem"
}

SettingsManager.defaultConfig = {
    difficultyMotor = 3,  -- Normal
    difficultyLoss = 3,   -- Normal
    showHUD = true,
    showYield = true,     -- Show yield monitor by default
    enableSpeedLimit = true,
    enableCropLoss = false,
    hudOffsetX = 0,    -- Horizontal offset
    hudOffsetY = 350,  -- Vertical offset
    unitSystem = 1     -- Metric
}

function SettingsManager.new()
    return setmetatable({}, SettingsManager_mt)
end

-- Get path for server settings (NOW IN modSettings FOR GLOBAL ACCESS)
function SettingsManager:getServerXmlFilePath()
    local userPath = getUserProfileAppPath()
    if not userPath then
        print("RHM: ERROR - Cannot get user profile path")
        return nil
    end
    
    -- Create modSettings/FS25_RealisticHarvesting directory structure
    local modSettingsPath = userPath .. "modSettings"
    local rhmPath = modSettingsPath .. "/FS25_RealisticHarvesting"
    
    -- Create directories if they don't exist
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

-- Get path for client settings (also in modSettings directory, alongside server settings)
function SettingsManager:getClientXmlFilePath()
    local serverPath = self:getServerXmlFilePath()
    if not serverPath then return nil end
    -- Replace 'settings.xml' with 'client.xml' in the same folder
    return serverPath:gsub("settings.xml$", "client.xml")
end

-- Legacy method for backward compatibility
function SettingsManager:getSavegameXmlFilePath()
    return self:getServerXmlFilePath()
end

-- Load server settings (everyone reads)
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
            
            -- MIGRATION: Convert old 'difficulty' to split fields if needed
            if settingsObject.difficultyMotor == nil and settingsObject.difficultyLoss == nil then
                -- Try to load legacy 'difficulty' field
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
    
    -- Fallback to defaults
    print("RHM: [Load] Using default values")
    for _, key in ipairs(self.SERVER_SETTINGS) do
        settingsObject[key] = self.defaultConfig[key]
    end

end

-- Load client settings (each client reads their own)
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
                    -- Load as float (can be nil if not set)
                    settingsObject[key] = xml:getFloat(xmlKey)
                else
                    settingsObject[key] = xml:getBool(xmlKey, self.defaultConfig[key])
                end
            end
            xml:delete()
            return
        end
    end
    
    -- Fallback to defaults
    for _, key in ipairs(self.CLIENT_SETTINGS) do
        settingsObject[key] = self.defaultConfig[key]
    end
end

-- Main load method (loads both server and client settings)
function SettingsManager:loadSettings(settingsObject)
    -- Everyone loads server settings
    self:loadServerSettings(settingsObject)
    
    -- Each client loads their own client settings
    if g_currentMission:getIsClient() then
        self:loadClientSettings(settingsObject)
    end
end

-- Save server settings (only server)
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
        
        -- Verify file was actually saved
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

-- Save client settings (each client)
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
                -- Save as float (only if not nil)
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

-- Main save method (saves server and/or client settings based on context)
function SettingsManager:saveSettings(settingsObject)
    -- Server saves server settings
    if g_currentMission:getIsServer() then
        self:saveServerSettings(settingsObject)
    end
    
    -- Each client saves their own client settings
    if g_currentMission:getIsClient() then
        self:saveClientSettings(settingsObject)
    end
end