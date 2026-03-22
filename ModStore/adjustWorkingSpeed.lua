--[[
    Author: PeterAH (Modding-Welt)
    Mod name: Adjust Working Speed
    Version: 0.9.0.0 Beta (FS25)
    Date: March 2025
    Contact: https://www.modding-welt.com
    Discord: @peter_ah
]]

adjustWorkingSpeed = {}

function adjustWorkingSpeed.prerequisitesPresent(specializations)
    return true
end

function adjustWorkingSpeed.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", adjustWorkingSpeed)
end

function adjustWorkingSpeed:onPostLoad(savegame)
    local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)

    if storeItem ~= nil and storeItem.configurations ~= nil then
        if storeItem.configurations["adjustWorkingSpeed"] ~= nil then

            local standardSpeedLimit
            if storeItem.awsStandardSpeedLimit == nil then
                standardSpeedLimit = 0
            elseif storeItem.awsStandardSpeedLimit == "" then
                standardSpeedLimit = 0
            else
                standardSpeedLimit = Utils.getNoNil(tonumber(storeItem.awsStandardSpeedLimit), 0)
            end
        
            if self.speedLimit ~= nil then
                if self.speedLimit > 0.5 then
                    if standardSpeedLimit > 0.5 then
                        local configId = Utils.getNoNil(self.configurations["adjustWorkingSpeed"], 0)
                        if configId > 0.5 then
                            self.speedLimit = math.max(standardSpeedLimit + configId - 11, 1)
                        end
                    end
                end
            end
            
        end
    end

end
