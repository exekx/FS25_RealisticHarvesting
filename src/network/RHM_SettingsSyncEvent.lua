-- EN: Network event used to synchronize server-side settings (difficulty, toggles) between server and all clients.
--     Sent by an admin client to the server, then the server rebroadcasts to all other clients.
-- UA: Мережева подія для синхронізації серверних налаштувань (складність, перемикачі) між сервером і клієнтами.
--     Надсилається клієнтом-адміністратором на сервер, після чого сервер ретранслює всім іншим клієнтам.
RHM_SettingsSyncEvent = {}
local SettingsSyncEvent_mt = Class(RHM_SettingsSyncEvent, Event)

InitEventClass(RHM_SettingsSyncEvent, "RHM_SettingsSyncEvent")

local integerSettings = {
    difficultyMotor = 3,
    difficultyLoss = 3,
    aiHelperTuning = 3,
    autoResetTripMode = 3,
    cloggingMode = 3,
    clogSensitivity = 3,
    clogFactors = 2,
    aiCloggingMode = 3
}

local function isServerSetting(name)
    for _, key in ipairs(RHMSettingsManager.SERVER_SETTINGS) do
        if key == name then return true end
    end
    return false
end

function RHM_SettingsSyncEvent.emptyNew()
    return Event.new(SettingsSyncEvent_mt)
end

function RHM_SettingsSyncEvent.new(settings, settingName)
    local self = RHM_SettingsSyncEvent.emptyNew()
    self.settingName = settingName or ""
    for _, key in ipairs(RHMSettingsManager.SERVER_SETTINGS) do
        self[key] = settings[key]
    end
    return self
end

function RHM_SettingsSyncEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.settingName)
    for _, key in ipairs(RHMSettingsManager.SERVER_SETTINGS) do
        if self.settingName == "" or self.settingName == key then
            if integerSettings[key] then
                streamWriteUInt8(streamId, self[key])
            else
                streamWriteBool(streamId, self[key])
            end
        end
    end
end

function RHM_SettingsSyncEvent:readStream(streamId, connection)
    self.settingName = streamReadString(streamId)
    for _, key in ipairs(RHMSettingsManager.SERVER_SETTINGS) do
        if self.settingName == "" or self.settingName == key then
            if integerSettings[key] then
                self[key] = streamReadUInt8(streamId)
            else
                self[key] = streamReadBool(streamId)
            end
        end
    end
    self:run(connection)
end

function RHM_SettingsSyncEvent:run(connection)
    local manager = g_realisticHarvestManager
    local settings = manager and manager.settings
    if not settings then return end
    local name = self.settingName or ""
    if name ~= "" and not isServerSetting(name) then return end

    local isServer = g_currentMission:getIsServer()
    if isServer then
        if not connection or connection:getIsServer() then return end
        local user = g_currentMission.userManager and g_currentMission.userManager:getUserByConnection(connection)
        if not user or not user:getIsMasterUser() then return end
        for _, key in ipairs(RHMSettingsManager.SERVER_SETTINGS) do
            if (name == "" or name == key) and integerSettings[key] then
                local value = self[key]
                local maxVal = integerSettings[key]
                if type(value) ~= "number" or value < 1 or value > maxVal or value % 1 ~= 0 then return end
            end
        end
    elseif not connection or not connection:getIsServer() then
        return
    end

    for _, key in ipairs(RHMSettingsManager.SERVER_SETTINGS) do
        if name == "" or name == key then settings[key] = self[key] end
    end
    if (name == "" or name == "autoResetTripMode") and manager.harvestTracker then
        for _, farm in pairs(manager.harvestTracker.farms or {}) do
            if farm.farmSettings then
                farm.farmSettings.autoResetMode = settings.autoResetTripMode
                farm.farmSettings.autoResetOnFieldChange = settings.autoResetTripMode ~= 3
            end
        end
    end

    if isServer then
        manager.settingsManager:saveServerSettings(settings)
        -- Include the requester: only the server's accepted values are authoritative.
        g_server:broadcastEvent(RHM_SettingsSyncEvent.new(settings, name))
    end
    if RHMSettingsUI and RHMSettingsUI.refreshUI then RHMSettingsUI.refreshUI(settings) end
end
