---@class ProfileManager
-- Manages global user profiles for combine settings, saved in modSettings
ProfileManager = {}
local ProfileManager_mt = Class(ProfileManager)

ProfileManager.XMLTAG = "realisticHarvestingProfiles.profiles"

function ProfileManager.new()
    local self = setmetatable({}, ProfileManager_mt)
    self.profiles = {}
    return self
end

function ProfileManager:getXmlFilePath()
    local userPath = getUserProfileAppPath()
    if not userPath then
        print("RHM: ERROR - Cannot get user profile path for profiles")
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

function ProfileManager:loadProfiles()
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
            
            local cropName = xml:getString(key .. "#cropName")
            if cropName then
                self.profiles[cropName] = {
                    fan = xml:getInt(key .. "#fan", 50),
                    rotor = xml:getInt(key .. "#rotor", 50),
                    upperSieve = xml:getInt(key .. "#upperSieve", 50),
                    lowerSieve = xml:getInt(key .. "#lowerSieve", 50),
                    feeder = xml:getInt(key .. "#feeder", 50)
                }
            end
            i = i + 1
        end
        xml:delete()
        print(string.format("RHM: Loaded %d user crop profiles from %s", i, xmlPath))
        return true
    end
    return false
end

function ProfileManager:saveProfiles()
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
            i = i + 1
        end
        xml:save()
        xml:delete()
        print(string.format("RHM: Saved %d user crop profiles to %s", i, xmlPath))
        return true
    end
    return false
end

function ProfileManager:getProfile(cropName)
    if not cropName then return nil end
    return self.profiles[cropName]
end

function ProfileManager:saveProfile(cropName, settings)
    if not cropName or not settings then return false end
    
    self.profiles[cropName] = {
        fan = settings.fan or 50,
        rotor = settings.rotor or 50,
        upperSieve = settings.upperSieve or 50,
        lowerSieve = settings.lowerSieve or 50,
        feeder = settings.feeder or 50
    }
    
    self:saveProfiles()
    return true
end
