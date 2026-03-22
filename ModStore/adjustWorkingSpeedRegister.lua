--[[
    Author: PeterAH (Modding-Welt)
    Mod name: Adjust Working Speed
    Version: 0.9.0.0 Beta (FS25)
    Date: March 2025
    Contact: https://www.modding-welt.com
    Discord: @peter_ah
]]

local _modDirectory = g_currentModDirectory

if g_specializationManager:getSpecializationByName("adjustWorkingSpeed") == nil then
    g_specializationManager:addSpecialization('adjustWorkingSpeed', 'adjustWorkingSpeed', Utils.getFilename('adjustWorkingSpeed.lua', g_currentModDirectory), nil)
end

for vehicleTypeName, vehicleType in pairs(g_vehicleTypeManager.types) do 
    if vehicleType == nil then
    elseif SpecializationUtil.hasSpecialization(adjustWorkingSpeed, vehicleType.specializations) then
    elseif SpecializationUtil.hasSpecialization(Locomotive, vehicleType.specializations) then
    elseif vehicleTypeName == 'trainTimberTrailer' then
    elseif vehicleTypeName == 'trainTrailer' then
    elseif vehicleTypeName == 'pallet' then
    elseif vehicleTypeName == 'horse' then
    else
        g_vehicleTypeManager:addSpecialization(vehicleTypeName, 'adjustWorkingSpeed')
    end 
end

local function addNewStoreConfig(manager, superFunc, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
    local configurations, defaultConfigurationIds = superFunc(manager, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
    local speedLimit = 0

    if storeItem ~= nil then
        if xmlFile:hasProperty("vehicle.base.speedLimit#value") then
            speedLimit = xmlFile:getValue("vehicle.base.speedLimit#value")
        end
        if speedLimit > 0.5 then
            if configurations == nil then
                configurations = {}
            end
        end
    end

    local integrateConfig = false
    if storeItem == nil then
    elseif configurations == nil then
    elseif configurations["adjustWorkingSpeed"] ~= nil then
    elseif speedLimit == 0 then 
    else
        integrateConfig = true
    end
    
    if speedLimit > 0.5 and integrateConfig == true then
        local configurationFile = XMLFile.load("adjustWorkingSpeedXML", _modDirectory .. "adjustWorkingSpeedConfigurations.xml", xmlFile.schema)
        if configurationFile then
            local configurationDescs = manager:getConfigurations()
            local configurationDesc = configurationDescs["adjustWorkingSpeed"]

            if configurationDesc ~= nil then
                configurations["adjustWorkingSpeed"] = {}
                local counter = 0

                while true do
                    local configKey = string.format(configurationDesc.configurationKey .."(%d)", counter)
                    if not configurationFile:hasProperty(configKey) then
                        break
                    end
                    counter = counter + 1
                    local configItem = configurationDesc.itemClass.new("adjustWorkingSpeed")
                    configItem:setIndex(counter)
                    if configItem:loadFromXML(configurationFile, configurationDesc.configurationsKey, configKey, baseDir, customEnvironment) then
                        configurations["adjustWorkingSpeed"][counter] = configItem
                    end
                end --end while

                if #configurations["adjustWorkingSpeed"] > 0 then
                    local i = 0
                    local speed
                    local milesSpeed
                    local kph = " " .. g_i18n:getText("CONFIG_KPH")
                    local cName = {}

                    for speed = speedLimit - 10, speedLimit + 10 do
                        i = i + 1
                        if i == 11 then
                            if g_gameSettings.useMiles == false then
                                configurations["adjustWorkingSpeed"][i].name = math.max(tostring(math.floor(speed + 0.5)), 1) .. kph .. " " .. g_i18n:getText("CONFIG_STANDARD")
                            else
                                milesSpeed = math.floor(speed / 1.609344)
                                configurations["adjustWorkingSpeed"][i].name = math.max(tostring(milesSpeed), 1) .. " mph " .. g_i18n:getText("CONFIG_STANDARD")
                            end
                        else
                            if g_gameSettings.useMiles == false then
                                configurations["adjustWorkingSpeed"][i].name = math.max(tostring(math.floor(speed + 0.5)), 1) .. kph
                            else
                                milesSpeed = math.floor(speed / 0.1609344 - 5) / 10
                                configurations["adjustWorkingSpeed"][i].name = math.max(tostring(milesSpeed), 1) .. " mph "
                            end
                        end
                    end --end for

                    if speedLimit < 11 then
                        configurations["adjustWorkingSpeed"][1].isSelectable = false
                        configurations["adjustWorkingSpeed"][2].isSelectable = false
                        if speedLimit < 9 then
                            configurations["adjustWorkingSpeed"][3].isSelectable = false
                            configurations["adjustWorkingSpeed"][4].isSelectable = false
                        end
                    end
                    if defaultConfigurationIds ~= nil then  -- to avoid error with "Claas Vario 620" and "Horsch Versa 3 KR" (found in the game folders, loaded at startup but not shown in the shop ingame)
                        defaultConfigurationIds["adjustWorkingSpeed"] = ConfigurationUtil.getDefaultConfigIdFromItems(configurations["adjustWorkingSpeed"])
                    end
                    adjWS.i = adjWS.i + 1
                    adjWS.xmls[adjWS.i] = storeItem.xmlFilename
                    storeItem.awsStandardSpeedLimit = speedLimit
                else
                    configurations["adjustWorkingSpeed"] = nil
                    print("Error: No configuration property found")
                end
            end
            configurationFile:delete()
        else
            print("Error: File not found: 'adjustWorkingSpeedConfigurations.xml'")
        end
    end
    
    return configurations, defaultConfigurationIds
end

if g_vehicleConfigurationManager.configurations["adjustWorkingSpeed"] == nil then
    g_vehicleConfigurationManager:addConfigurationType("adjustWorkingSpeed", g_i18n:getText("CONFIG_TITLE"), "adjustWorkingSpeed", VehicleConfigurationItem)
    ConfigurationUtil.getConfigurationsFromXML = Utils.overwrittenFunction(ConfigurationUtil.getConfigurationsFromXML, addNewStoreConfig)
end


adjWS = {}   -- adjWS = adjustWorkingSpeed
adjWS.xmls = {}
adjWS.i = 0

function adjWS:update(dt)
    
    if adjWS.miles ~= g_gameSettings.useMiles then
        adjWS.miles = g_gameSettings.useMiles
        
        local ii = 0
        for ii = 1, adjWS.i do
            local storeItem = g_storeManager:getItemByXMLFilename(adjWS.xmls[ii])
            if storeItem ~= nil and storeItem.configurations ~= nil then
                if storeItem.configurations["adjustWorkingSpeed"] ~= nil then
                    
                    local i = 0
                    local speed
                    local milesSpeed
                    local kph = " " .. g_i18n:getText("CONFIG_KPH")
                    local speedLimit = Utils.getNoNil(tonumber(storeItem.awsStandardSpeedLimit), 0)
                    for speed = speedLimit - 10, speedLimit + 10 do
                        i = i + 1
                        if i == 11 then
                            if g_gameSettings.useMiles == false then
                                storeItem.configurations["adjustWorkingSpeed"][i].name = math.max(tostring(math.floor(speed + 0.5)), 1) .. kph .. " " .. g_i18n:getText("CONFIG_STANDARD")
                            else
                                milesSpeed = math.floor(speed / 1.609344)
                                storeItem.configurations["adjustWorkingSpeed"][i].name = math.max(tostring(milesSpeed), 1) .. " mph " .. g_i18n:getText("CONFIG_STANDARD")
                            end
                        else
                            if g_gameSettings.useMiles == false then
                                storeItem.configurations["adjustWorkingSpeed"][i].name = math.max(tostring(math.floor(speed + 0.5)), 1) .. kph
                            else
                                milesSpeed = math.floor(speed / 0.1609344 - 5) / 10
                                storeItem.configurations["adjustWorkingSpeed"][i].name = math.max(tostring(milesSpeed), 1) .. " mph"
                            end
                        end
                    end
                    
                end
            end
        end
        
    end    
end

if adjWS.active == nil then
    adjWS.active = true
    adjWS.miles = g_gameSettings.useMiles
    addModEventListener(adjWS)
end
