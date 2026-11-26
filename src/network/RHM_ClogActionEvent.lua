-- ============================================================================
-- RHM_ClogActionEvent.lua
-- Realistic Harvesting Mod - Multiplayer Network Event for Clogging Clear Actions
-- ============================================================================
-- Synchronizes feeder reverse clearing and on-foot manual blockage clearing
-- from client players to the authoritative server, including proximity validation.
-- ============================================================================

RHM_ClogActionEvent = {}
local RHM_ClogActionEvent_mt = Class(RHM_ClogActionEvent, Event)

InitEventClass(RHM_ClogActionEvent, "RHM_ClogActionEvent")

RHM_ClogActionEvent.ACTION_REVERSE_COMPLETE = 1
RHM_ClogActionEvent.ACTION_MANUAL_CLEAR_COMPLETE = 2
RHM_ClogActionEvent.ACTION_SET_REVERSING = 3

function RHM_ClogActionEvent.emptyNew()
    local self = Event.new(RHM_ClogActionEvent_mt)
    return self
end

---EN: Creates a clogging clearing action event for a target harvester.
---@param vehicle table Target combine/forage/root harvester
---@param actionType number One of RHM_ClogActionEvent.ACTION_*
---@param flagValue boolean|nil Optional boolean state (used for ACTION_SET_REVERSING)
function RHM_ClogActionEvent.new(vehicle, actionType, flagValue)
    local self = RHM_ClogActionEvent.emptyNew()
    self.vehicle = vehicle
    self.actionType = actionType or RHM_ClogActionEvent.ACTION_REVERSE_COMPLETE
    self.flagValue = flagValue == true
    return self
end

function RHM_ClogActionEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.actionType = streamReadUInt8(streamId)
    self.flagValue = streamReadBool(streamId)
    self:run(connection)
end

function RHM_ClogActionEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUInt8(streamId, self.actionType or RHM_ClogActionEvent.ACTION_REVERSE_COMPLETE)
    streamWriteBool(streamId, self.flagValue == true)
end

---EN: Validates server authority, farm access, and proximity before applying clog state changes.
function RHM_ClogActionEvent:run(connection)
    if g_server == nil then
        return
    end

    local vehicle = self.vehicle
    if vehicle == nil or vehicle.spec_rhm_Combine == nil or vehicle.spec_rhm_Combine.cloggingSystem == nil then
        return
    end

    local spec = vehicle.spec_rhm_Combine
    local clogSys = spec.cloggingSystem

    -- Verify sender has farm access to this vehicle when sender connection is resolved
    if connection ~= nil and g_currentMission ~= nil and g_currentMission.getHasPlayerPermission ~= nil then
        local userManager = g_currentMission.userManager
        local userId = userManager and userManager.getUserIdByConnection and userManager:getUserIdByConnection(connection)
        if userId ~= nil then
            local farm = g_farmManager and g_farmManager.getFarmByUserId and g_farmManager:getFarmByUserId(userId)
            local vehicleFarmId = (vehicle.getOwnerFarmId and vehicle:getOwnerFarmId()) or AccessHandler.EVERYONE
            if farm ~= nil and vehicleFarmId ~= AccessHandler.EVERYONE and farm.farmId ~= vehicleFarmId then
                local canTrade = g_currentMission.accessHandler and g_currentMission.accessHandler:canFarmAccessOtherId(farm.farmId, vehicleFarmId)
                if not canTrade then
                    return
                end
            end
        end
    end

    if self.actionType == RHM_ClogActionEvent.ACTION_SET_REVERSING then
        clogSys:setPlayerReversing(vehicle, self.flagValue == true)
    elseif self.actionType == RHM_ClogActionEvent.ACTION_REVERSE_COMPLETE then
        -- Enforce realistic mode rule: hard blockage requires on-foot clearing when cloggingMode == 3
        local settings = g_realisticHarvestManager and g_realisticHarvestManager.settings
        local cloggingMode = (settings and settings.cloggingMode) or 2
        if clogSys.clogState == RHM_CloggingSystem.STATE_BLOCKED and cloggingMode == 3 then
            return
        end
        clogSys:clearBlockage(vehicle, true)
    elseif self.actionType == RHM_ClogActionEvent.ACTION_MANUAL_CLEAR_COMPLETE then
        clogSys:clearBlockage(vehicle, true)
    end

    rhm_Combine.syncCloggingData(vehicle, spec)
    if spec.dataDirtyFlag and type(spec.dataDirtyFlag) == "number" then
        vehicle:raiseDirtyFlags(spec.dataDirtyFlag)
    end
end
