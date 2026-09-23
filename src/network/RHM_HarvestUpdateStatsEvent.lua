-- ============================================================================
-- RHM_HarvestUpdateStatsEvent.lua
-- Realistic Harvesting Mod - Lightweight Periodic Field Trip Delta Event
-- ============================================================================
-- Technical architecture:
--   Broadcasts live currentTrip metrics from Server to Clients for a specific farm.
--   Runs Server -> Client at ~1Hz interval when active.
-- ============================================================================

RHM_HarvestUpdateStatsEvent = {}
local HarvestUpdateStatsEvent_mt = Class(RHM_HarvestUpdateStatsEvent, Event)

InitEventClass(RHM_HarvestUpdateStatsEvent, "RHM_HarvestUpdateStatsEvent")

function RHM_HarvestUpdateStatsEvent.emptyNew()
    return Event.new(HarvestUpdateStatsEvent_mt)
end

function RHM_HarvestUpdateStatsEvent.new(farmId, trip)
    local self = RHM_HarvestUpdateStatsEvent.emptyNew()
    self.farmId = farmId or 1
    self.trip = trip
    return self
end

function RHM_HarvestUpdateStatsEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.farmId)
    local trip = self.trip or {}

    streamWriteInt32(streamId, trip.fieldId or 0)
    streamWriteString(streamId, trip.cropName or "UNKNOWN")
    streamWriteInt32(streamId, trip.fillTypeIndex or FillType.UNKNOWN)
    streamWriteFloat32(streamId, trip.harvestedLiters or 0)
    streamWriteFloat32(streamId, trip.harvestedMassKg or 0)
    streamWriteFloat32(streamId, trip.harvestedAreaHa or 0)
    streamWriteFloat32(streamId, trip.lostLiters or 0)
    streamWriteFloat32(streamId, trip.lossMoney or 0)
    streamWriteFloat32(streamId, trip.sessionDuration or 0)
    streamWriteString(streamId, trip.efficiencyRank or "A")

    local reasons = trip.reasons or {}
    streamWriteFloat32(streamId, reasons.speed or 0)
    streamWriteFloat32(streamId, reasons.moisture or 0)
    streamWriteFloat32(streamId, reasons.wear or 0)
    streamWriteFloat32(streamId, reasons.slope or 0)
end

function RHM_HarvestUpdateStatsEvent:readStream(streamId, connection)
    self.farmId = streamReadUInt8(streamId)

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if tracker then
        local farm = tracker:getFarmData(self.farmId)
        local trip = farm.currentTrip

        trip.fieldId = streamReadInt32(streamId)
        trip.cropName = streamReadString(streamId)
        trip.fillTypeIndex = streamReadInt32(streamId)
        trip.harvestedLiters = streamReadFloat32(streamId)
        trip.harvestedMassKg = streamReadFloat32(streamId)
        trip.harvestedAreaHa = streamReadFloat32(streamId)
        trip.lostLiters = streamReadFloat32(streamId)
        trip.lossMoney = streamReadFloat32(streamId)
        trip.sessionDuration = streamReadFloat32(streamId)
        trip.efficiencyRank = streamReadString(streamId)

        trip.reasons = trip.reasons or {}
        trip.reasons.speed = streamReadFloat32(streamId)
        trip.reasons.moisture = streamReadFloat32(streamId)
        trip.reasons.wear = streamReadFloat32(streamId)
        trip.reasons.slope = streamReadFloat32(streamId)
    end

    self:run(connection)
end

function RHM_HarvestUpdateStatsEvent:run(connection)
    -- Notify GUI if open on this client
    if g_realisticHarvestManager and g_realisticHarvestManager.harvestHistoryGUI and g_realisticHarvestManager.harvestHistoryGUI.isOpen then
        g_realisticHarvestManager.harvestHistoryGUI:refreshCurrentPage()
    end
end
