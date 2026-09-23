-- ============================================================================
-- RHM_HarvestFarmSettingsEvent.lua
-- Realistic Harvesting Mod - Farm Harvesting Settings Sync Event
-- ============================================================================
-- Technical architecture:
--   Bi-directional:
--     Client -> Server: Sends requested farm settings change.
--     Server: Validates permissions, applies changes, persists to XML.
--     Server -> Clients: Broadcasts updated settings to all clients of this farm.
-- ============================================================================

RHM_HarvestFarmSettingsEvent = {}
local HarvestFarmSettingsEvent_mt = Class(RHM_HarvestFarmSettingsEvent, Event)

InitEventClass(RHM_HarvestFarmSettingsEvent, "RHM_HarvestFarmSettingsEvent")

function RHM_HarvestFarmSettingsEvent.emptyNew()
    return Event.new(HarvestFarmSettingsEvent_mt)
end

function RHM_HarvestFarmSettingsEvent.new(farmId, settings)
    local self = RHM_HarvestFarmSettingsEvent.emptyNew()
    self.farmId = farmId or 1
    self.settings = settings or {}
    return self
end

function RHM_HarvestFarmSettingsEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.farmId)
    streamWriteBool(streamId, self.settings.aiSpeedLimiter ~= false)
    streamWriteFloat32(streamId, self.settings.aiMaxLossPct or 2.0)
    streamWriteBool(streamId, self.settings.volunteerCrops ~= false)
    streamWriteBool(streamId, self.settings.autoResetOnFieldChange == true)
end

function RHM_HarvestFarmSettingsEvent:readStream(streamId, connection)
    self.farmId = streamReadUInt8(streamId)
    self.settings = {
        aiSpeedLimiter = streamReadBool(streamId),
        aiMaxLossPct = streamReadFloat32(streamId),
        volunteerCrops = streamReadBool(streamId),
        autoResetOnFieldChange = streamReadBool(streamId)
    }
    self:run(connection)
end

function RHM_HarvestFarmSettingsEvent:run(connection)
    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if not tracker then return end

    if g_currentMission:getIsServer() then
        local user = connection and g_currentMission.userManager:getUserByConnection(connection)
        tracker:updateFarmSettings(self.farmId, self.settings, user)
    else
        local farm = tracker:getFarmData(self.farmId)
        if farm and farm.farmSettings then
            farm.farmSettings.aiSpeedLimiter = self.settings.aiSpeedLimiter
            farm.farmSettings.aiMaxLossPct = self.settings.aiMaxLossPct
            farm.farmSettings.volunteerCrops = self.settings.volunteerCrops
            farm.farmSettings.autoResetOnFieldChange = self.settings.autoResetOnFieldChange
        end

        if g_realisticHarvestManager and g_realisticHarvestManager.harvestHistoryGUI and g_realisticHarvestManager.harvestHistoryGUI.isOpen then
            g_realisticHarvestManager.harvestHistoryGUI:refreshCurrentPage()
        end
    end
end
