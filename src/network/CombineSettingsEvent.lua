---@class CombineSettingsEvent
-- Event to sync combine settings from client GUI to server
CombineSettingsEvent = {}
local CombineSettingsEvent_mt = Class(CombineSettingsEvent, Event)

InitEventClass(CombineSettingsEvent, "CombineSettingsEvent")

function CombineSettingsEvent.emptyNew()
    local self = Event.new(CombineSettingsEvent_mt)
    return self
end

function CombineSettingsEvent.new(vehicle, parameter, value, isFullProfile, fullSettings)
    local self = CombineSettingsEvent.emptyNew()
    self.vehicle = vehicle
    self.parameter = parameter or ""
    self.value = value or 0
    self.isFullProfile = isFullProfile == true
    self.fullSettings = fullSettings
    return self
end

function CombineSettingsEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isFullProfile = streamReadBool(streamId)
    
    if self.isFullProfile then
        self.fullSettings = {}
        self.fullSettings.fan = streamReadUInt8(streamId)
        self.fullSettings.rotor = streamReadUInt8(streamId)
        self.fullSettings.upperSieve = streamReadUInt8(streamId)
        self.fullSettings.lowerSieve = streamReadUInt8(streamId)
        self.fullSettings.feeder = streamReadUInt8(streamId)
    else
        self.parameter = streamReadString(streamId)
        self.value = streamReadInt16(streamId)
    end
    self:run(connection)
end

function CombineSettingsEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isFullProfile)
    
    if self.isFullProfile then
        streamWriteUInt8(streamId, self.fullSettings.fan or 50)
        streamWriteUInt8(streamId, self.fullSettings.rotor or 50)
        streamWriteUInt8(streamId, self.fullSettings.upperSieve or 50)
        streamWriteUInt8(streamId, self.fullSettings.lowerSieve or 50)
        streamWriteUInt8(streamId, self.fullSettings.feeder or 50)
    else
        streamWriteString(streamId, self.parameter)
        streamWriteInt16(streamId, self.value)
    end
end

function CombineSettingsEvent:run(connection)
    if self.vehicle and self.vehicle:getIsSynchronized() and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.combineMemory then
        local mem = self.vehicle.spec_rhm_Combine.combineMemory
        
        if self.isFullProfile then
            -- Apply full profile (e.g., from loading a user preset)
            mem.currentSettings.fan = self.fullSettings.fan
            mem.currentSettings.rotor = self.fullSettings.rotor
            mem.currentSettings.upperSieve = self.fullSettings.upperSieve
            mem.currentSettings.lowerSieve = self.fullSettings.lowerSieve
            mem.currentSettings.feeder = self.fullSettings.feeder
            mem.autoSwitchEnabled = false
            mem.mode = "MANUAL"
            print("RHM: [Sync] Received full user profile settings via network")
        else
            if self.parameter == "AUTO_SET" then
                -- Client requested to set AUTO mode
                mem.autoSwitchEnabled = true
                mem.mode = "AUTO"
                if mem.currentCrop then
                    -- SERVER AUTHORITATIVE ACTION: Recalculate and sync back
                    mem:autoConfigureForCrop(mem.currentCrop, true)
                    print(string.format("RHM: [Sync] Server applied AUTO mode for %s", mem.currentCrop))
                end
            elseif self.parameter == "RESET_SET" then
                -- Client requested to RESET settings to neutral (50%)
                mem.autoSwitchEnabled = false
                mem.mode = "MANUAL"
                if mem.currentCrop then
                    mem:autoConfigureForCrop(mem.currentCrop, false)
                    print(string.format("RHM: [Sync] Server applied RESET to 50%% for %s", mem.currentCrop))
                end
            elseif self.parameter == "AUTO_MODE" then
                -- Manual toggle of the behavior flag
                mem.autoSwitchEnabled = (self.value == 1)
                mem.mode = mem.autoSwitchEnabled and "AUTO" or "MANUAL"
            else
                -- Apply single parameter update
                if mem.currentSettings[self.parameter] ~= nil then
                    mem.currentSettings[self.parameter] = math.max(0, math.min(100, self.value))
                    mem.autoSwitchEnabled = false
                    mem.mode = "MANUAL"
                    print(string.format("RHM: [Sync] Received parameter update: %s = %d", self.parameter, self.value))
                end
            end
        end
        
        -- If we are the server, broadcast the change to all other clients
        if g_server ~= nil then
            g_server:broadcastEvent(CombineSettingsEvent.new(self.vehicle, self.parameter, self.value, self.isFullProfile, self.fullSettings), nil, connection, self.vehicle)
            -- Raise dirty flag so clients see the new values in their sync stream
            self.vehicle:raiseDirtyFlags(self.vehicle.spec_rhm_Combine.dirtyFlag)
        end
    end
end
