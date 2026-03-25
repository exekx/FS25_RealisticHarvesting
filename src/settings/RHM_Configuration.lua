-- EN: Dynamically injects the RHM Package configuration into all combines.
-- UA: Динамічно ін'єктує конфігурацію RHM Пакетів у всі комбайни.

local modDirectory = g_currentModDirectory

-- EN: Helper to add store configurations from our custom XML
local function addNewStoreConfig(manager, superFunc, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
    local configurations, defaultConfigurationIds = superFunc(manager, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
    
    -- 1. Check if the vehicle is a combine by inspecting its XML root nodes
    local isCombine = false
    if xmlFile ~= nil then
        if xmlFile:hasProperty("vehicle.combine") or
           xmlFile:hasProperty("vehicle.forageHarvester") or
           xmlFile:hasProperty("vehicle.cottonHarvester") or
           xmlFile:hasProperty("vehicle.rootCropHaarvester") then
            isCombine = true
        end
    end

    -- 2. If it's a combine, inject our custom RHM Packages
    if isCombine then
        if configurations == nil then
            configurations = {}
        end

        -- Check if vehicle already has this configuration natively built-in by the mod author
        if configurations["rhmPackage"] == nil then
            local configurationDescs = manager:getConfigurations()
            local configurationDesc = configurationDescs["rhmPackage"]

            if configurationDesc ~= nil then
                configurations["rhmPackage"] = {}
                
                local packages = {
                    {name = "rhm_package_standard", price = 0, isDefault = true},
                    {name = "rhm_package_sensor", price = 3500, isDefault = false},
                    {name = "rhm_package_yield", price = 8500, isDefault = false},
                    {name = "rhm_package_opti", price = 15000, isDefault = false}
                }

                for i, pkg in ipairs(packages) do
                    local configItem = configurationDesc.itemClass.new("rhmPackage")
                    configItem:setIndex(i)
                    configItem.name = g_i18n:hasText(pkg.name) and g_i18n:getText(pkg.name) or pkg.name
                    configItem.price = pkg.price
                    configItem.isDefault = pkg.isDefault
                    configItem.isSelectable = true
                    configItem.saveId = tostring(i)
                    configurations["rhmPackage"][i] = configItem
                end

                if defaultConfigurationIds ~= nil then
                    defaultConfigurationIds["rhmPackage"] = ConfigurationUtil.getDefaultConfigIdFromItems(configurations["rhmPackage"])
                end
            end
        end
    end
    
    return configurations, defaultConfigurationIds
end

-- EN: Register the configuration type "rhmPackage" if not exists
if g_vehicleConfigurationManager.configurations["rhmPackage"] == nil then
    g_vehicleConfigurationManager:addConfigurationType("rhmPackage", g_i18n:getText("rhm_configuration_title"), "rhmPackage", VehicleConfigurationItem)
    ConfigurationUtil.getConfigurationsFromXML = Utils.overwrittenFunction(ConfigurationUtil.getConfigurationsFromXML, addNewStoreConfig)
end
