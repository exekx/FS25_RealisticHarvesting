---
-- CombineSettingsManager
-- Manages saving and loading of RHM-specific combine settings to a separate XML file
-- to avoid "Path not registered" schema errors in vehicles.xml.
---

CombineSettingsManager = {}
local CombineSettingsManager_mt = Class(CombineSettingsManager)

function CombineSettingsManager.new()
    local self = setmetatable({}, CombineSettingsManager_mt)
    self.settingsData = {} -- Map of vehicle name/ID to its settings
    return self
end

function CombineSettingsManager:getVehicleKey(vehicle)
    -- We use a combination of XML filename and a unique identifier if possible.
    -- Since we want this to persist across saves, the best key is usually the 
    -- vehicle's position in the XML or a unique hash if FS25 provides one.
    -- For now, we'll try to use the vehicle's uniqueId which should be stable within a save session.
    -- However, uniqueId can change between loads. 
    -- A better way is to use the vehicle's "key" passed during saveToXMLFile, 
    -- which looks like "vehicles.vehicle(49)".
    return vehicle.configFileName .. "_" .. (vehicle.propertyState or 0) .. "_" .. (vehicle.ownerFarmId or 0)
end

function CombineSettingsManager:loadData()
    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if not savegameDir then return end
    
    local xmlFilename = savegameDir .. "/realisticHarvesting_vehicles.xml"
    if not fileExists(xmlFilename) then return end
    
    local xmlFile = XMLFile.load("RHM_Vehicles", xmlFilename, "realisticHarvesting")
    if not xmlFile then return end
    
    local i = 0
    while true do
        local key = string.format("realisticHarvesting.vehicle(%d)", i)
        if not xmlFile:hasProperty(key) then break end
        
        local configFileName = xmlFile:getString(key .. "#configFileName")
        if configFileName then
            local data = {
                mode = xmlFile:getString(key .. "#mode"),
                autoSwitch = xmlFile:getBool(key .. "#autoSwitch"),
                currentCrop = xmlFile:getString(key .. "#currentCrop"),
                fan = xmlFile:getInt(key .. "#fan"),
                upperSieve = xmlFile:getInt(key .. "#upperSieve"),
                lowerSieve = xmlFile:getInt(key .. "#lowerSieve"),
                rotor = xmlFile:getInt(key .. "#rotor"),
                feeder = xmlFile:getInt(key .. "#feeder")
            }
            -- Store by configFileName as a fallback, but we really need a better key for multiple same vehicles.
            -- FS25 doesn't have a stable unique ID across saves in the same way FS22 did easily.
            -- For this mod, we will apply these to the vehicle during its own load process.
            self.settingsData[configFileName] = data
        end
        i = i + 1
    end
    
    xmlFile:delete()
end

-- Since we can't easily map vehicles back to their XML entries without injecting IDs,
-- we will use a different approach: let the vehicles save their data to a table 
-- during the normal save process, and then we write that table to a file at the end.
function CombineSettingsManager:saveData()
    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if not savegameDir then return end
    
    local xmlFilename = savegameDir .. "/realisticHarvesting_vehicles.xml"
    local xmlFile = XMLFile.create("RHM_Vehicles", xmlFilename, "realisticHarvesting")
    
    local i = 0
    for configName, data in pairs(self.settingsData) do
        local key = string.format("realisticHarvesting.vehicle(%d)", i)
        xmlFile:setString(key .. "#configFileName", configName)
        if data.mode then xmlFile:setString(key .. "#mode", data.mode) end
        if data.autoSwitch ~= nil then xmlFile:setBool(key .. "#autoSwitch", data.autoSwitch) end
        if data.currentCrop then xmlFile:setString(key .. "#currentCrop", data.currentCrop) end
        if data.fan then xmlFile:setInt(key .. "#fan", data.fan) end
        if data.upperSieve then xmlFile:setInt(key .. "#upperSieve", data.upperSieve) end
        if data.lowerSieve then xmlFile:setInt(key .. "#lowerSieve", data.lowerSieve) end
        if data.rotor then xmlFile:setInt(key .. "#rotor", data.rotor) end
        if data.feeder then xmlFile:setInt(key .. "#feeder", data.feeder) end
        i = i + 1
    end
    
    xmlFile:save()
    xmlFile:delete()
end
