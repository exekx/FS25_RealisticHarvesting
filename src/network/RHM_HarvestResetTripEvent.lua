-- ============================================================================
-- RHM_HarvestResetTripEvent.lua
-- Realistic Harvesting Mod - Trip Odometer Reset Request & Broadcast Event
-- ============================================================================
-- Technical architecture:
--   Bi-directional:
--     Client -> Server: Sends request to reset active field trip odometer.
--     Server: Validates farm permissions, archives trip, resets to 0.
--     Server -> Clients: Broadcasts confirmation to reset local client display.
-- ============================================================================

RHM_HarvestResetTripEvent = {}
local HarvestResetTripEvent_mt = Class(RHM_HarvestResetTripEvent, Event)

InitEventClass(RHM_HarvestResetTripEvent, "RHM_HarvestResetTripEvent")

function RHM_HarvestResetTripEvent.emptyNew()
    return Event.new(HarvestResetTripEvent_mt)
end

function RHM_HarvestResetTripEvent.new(farmId)
    local self = RHM_HarvestResetTripEvent.emptyNew()
    self.farmId = farmId or 1
    return self
end

function RHM_HarvestResetTripEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.farmId)
end

function RHM_HarvestResetTripEvent:readStream(streamId, connection)
    self.farmId = streamReadUInt8(streamId)
    self:run(connection)
end

function RHM_HarvestResetTripEvent:run(connection)
    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if not tracker then return end

    if connection and not connection:getIsServer() then
        -- Server validates permissions and executes reset (received from remote client)
        local user = g_currentMission.userManager and g_currentMission.userManager:getUserByConnection(connection)
        tracker:resetTrip(self.farmId, user)
    else
        -- Client received broadcast confirmation from server: clear local display
        local farm = tracker:getFarmData(self.farmId)
        if farm and farm.currentTrip then
            farm.currentTrip.harvestedLiters = 0
            farm.currentTrip.harvestedMassKg = 0
            farm.currentTrip.harvestedAreaHa = 0
            farm.currentTrip.lostLiters = 0
            farm.currentTrip.lossMoney = 0
            farm.currentTrip.reasons = { speed = 0, moisture = 0, wear = 0, slope = 0 }
            farm.currentTrip.sessionDuration = 0
            farm.currentTrip.efficiencyRank = RHM_HarvestTracker.RANK_A
            farm.currentTrip.isActive = false
        end

        if g_realisticHarvestManager and g_realisticHarvestManager.harvestHistoryGUI and g_realisticHarvestManager.harvestHistoryGUI.isOpen then
            g_realisticHarvestManager.harvestHistoryGUI:refreshCurrentPage()
        end
    end
end
