-- EN: Entry point for the Realistic Harvesting mod (FS25).
--     Loads all subsystem scripts in dependency order, registers the rhm_Combine
--     specialization for all combine-type vehicles, and hooks into the game's
--     mission lifecycle (load, update, draw, mouse, delete).
-- UA: Точка входу мода Realistic Harvesting (FS25).
--     Завантажує всі підсистемні скрипти у порядку залежностей, реєструє спеціалізацію
--     rhm_Combine для всіх транспортних засобів типу комбайн, і підключається до
--     життєвого циклу місії гри (завантаження, оновлення, малювання, миша, видалення).

local modDirectory = g_currentModDirectory
local modName = g_currentModName

-- EN: Custom logging function that respects FS25 development warnings setting.
-- UA: Кастомна функція логування, яка поважає налаштування development warnings FS25.
function rhm_log(...)
    -- EN: Only print if -devWarnings is passed to the game or the game is explicitly a development build.
    -- UA: Логуємо тільки якщо грі передано -devWarnings або гра у режимі розробника.
    if g_showDevelopmentWarnings or g_isDevelopmentVersion then
        print(...)
    end
end

-- EN: Load all subsystem scripts in dependency order.
-- UA: Завантажуємо всі підсистемні скрипти у порядку залежностей.
source(modDirectory .. "src/utils/RHM_Debug.lua")
source(modDirectory .. "src/utils/RHM_DiagnosticTool.lua")
source(modDirectory .. "src/settings/RHM_Configuration.lua")
source(modDirectory .. "src/settings/RHM_SettingsManager.lua")
source(modDirectory .. "src/settings/RHM_Settings.lua")
source(modDirectory .. "src/settings/RHM_SettingsGUI.lua")
source(modDirectory .. "src/network/RHM_SettingsSyncEvent.lua")
source(modDirectory .. "src/network/RHM_SettingsSync.lua")
source(modDirectory .. "src/utils/RHM_InputUtil.lua")
source(modDirectory .. "src/utils/RHM_UnitConverter.lua")
source(modDirectory .. "src/utils/RHM_UIColors.lua")
source(modDirectory .. "src/integration/RHM_MoistureAdapter.lua")
source(modDirectory .. "src/settings/RHM_SettingsUI.lua")
source(modDirectory .. "src/hud/RHM_NotificationManager.lua")
source(modDirectory .. "src/hud/RHM_DraggableHUD.lua")
source(modDirectory .. "src/gui/RHM_CombineCalibrationGUI.lua")
source(modDirectory .. "src/data/RHM_CombineSettingsDatabase.lua")
source(modDirectory .. "src/settings/RHM_ProfileManager.lua")
source(modDirectory .. "src/settings/RHM_CombineMemory.lua")
source(modDirectory .. "src/network/RHM_CombineSettingsEvent.lua")
source(modDirectory .. "src/logic/RHM_HarvestTracker.lua")
source(modDirectory .. "src/network/RHM_HarvestSyncInitialEvent.lua")
source(modDirectory .. "src/network/RHM_HarvestUpdateStatsEvent.lua")
source(modDirectory .. "src/network/RHM_HarvestResetTripEvent.lua")
source(modDirectory .. "src/network/RHM_HarvestFarmSettingsEvent.lua")
source(modDirectory .. "src/gui/frames/RHM_HarvestHistoryTrip.lua")
source(modDirectory .. "src/gui/frames/RHM_HarvestHistoryFields.lua")
source(modDirectory .. "src/gui/frames/RHM_HarvestHistoryAnalytics.lua")
source(modDirectory .. "src/gui/frames/RHM_HarvestHistoryFleet.lua")
source(modDirectory .. "src/gui/RHM_HarvestHistoryGUI.lua")
source(modDirectory .. "src/integration/RHM_ModCompatibility.lua")
source(modDirectory .. "src/integration/RHM_Api.lua")
if RHM_Api then
    getfenv(0)["RHM_API"] = RHM_Api
    getfenv(0)["RHM_Api"] = RHM_Api
end
if RHM_ModCompatibility and RHM_ModCompatibility.init then
    RHM_ModCompatibility.init()
end
source(modDirectory .. "src/logic/RHM_LoadCalculator.lua")
source(modDirectory .. "src/rhm_Combine.lua")
-- EN: CRITICAL: rhm_Cutter must be loaded AFTER rhm_Combine for independent header launch to work.
-- UA: КРИТИЧНО: rhm_Cutter має бути завантажений ПІСЛЯ rhm_Combine, щоб роздільний запуск жатки працював.
source(modDirectory .. "src/rhm_Cutter.lua")
source(modDirectory .. "src/RHM_RealisticHarvestManager.lua")

if RHM_ModCompatibility and RHM_ModCompatibility.registerIntegrityBaseline then
    RHM_ModCompatibility.registerIntegrityBaseline({
        { name = "RHM_LoadCalculator.getCropSpecificEnergy", tbl = RHM_LoadCalculator, key = "getCropSpecificEnergy", fn = RHM_LoadCalculator and RHM_LoadCalculator.getCropSpecificEnergy },
        { name = "RHM_LoadCalculator.calculateEngineLoad",   tbl = RHM_LoadCalculator, key = "calculateEngineLoad",   fn = RHM_LoadCalculator and RHM_LoadCalculator.calculateEngineLoad },
        { name = "RHM_LoadCalculator.calculateSpeedLimit",   tbl = RHM_LoadCalculator, key = "calculateSpeedLimit",   fn = RHM_LoadCalculator and RHM_LoadCalculator.calculateSpeedLimit },
        { name = "RHM_LoadCalculator.update",                tbl = RHM_LoadCalculator, key = "update",                fn = RHM_LoadCalculator and RHM_LoadCalculator.update },
        { name = "RHMSettings.getPowerBoost",                tbl = RHMSettings,        key = "getPowerBoost",         fn = RHMSettings and RHMSettings.getPowerBoost },
        { name = "RHMDraggableHUD.buildActiveCells",         tbl = RHMDraggableHUD,    key = "buildActiveCells",      fn = RHMDraggableHUD and RHMDraggableHUD.buildActiveCells },
    })
end

-- EN: Global reference to the main mod manager instance (nil = disabled/not loaded).
-- UA: Глобальне посилання на головний екземпляр менеджера мода (nil = вимкнено/не завантажено).
local rhm

-- EN: Returns true if the mod manager has been successfully initialized.
-- UA: Повертає true, якщо менеджер мода успішно ініціалізований.
local function isEnabled()
    return rhm ~= nil
end

-- EN: Helper to construct normalized savegame file paths with guaranteed directory separator
-- UA: Допоміжна функція для побудови нормалізованих шляхів збереження з гарантованим розділювачем директорій
local function getSavegameFilePath(saveDir, filename)
    if not saveDir or saveDir == "" then return nil end
    local cleanDir = tostring(saveDir):gsub("\\", "/")
    if not cleanDir:match("/$") then
        cleanDir = cleanDir .. "/"
    end
    return cleanDir .. filename
end

-- EN: Helper to reliably locate the active savegame folder across all game modes & dedicated servers
-- UA: Допоміжна функція для надійного визначення директорії збереження в усіх режимах гри та на виділеному сервері
local function resolveSavegameDirectory(context)
    -- Priority 1: missionInfo.savegameDirectory (authentic permanent savegame folder e.g. "savegame6")
    local saveDir = (context and context.missionInfo and context.missionInfo.savegameDirectory)
        or (g_currentMission and g_currentMission.missionInfo and g_currentMission.missionInfo.savegameDirectory)
    -- Priority 2: direct savegameDirectory property (fallback)
    if not saveDir or saveDir == "" or saveDir == "tempsavegame" then
        local direct = (context and context.savegameDirectory)
            or (g_currentMission and g_currentMission.savegameDirectory)
        if direct and direct ~= "" and direct ~= "tempsavegame" then
            saveDir = direct
        end
    end
    -- Priority 3: Fallback to any provided savegameDirectory
    if not saveDir or saveDir == "" then
        saveDir = (context and context.savegameDirectory)
            or (g_currentMission and g_currentMission.savegameDirectory)
    end
    return saveDir
end

-- EN: Called after the mission finishes loading.
--     Initializes unit converter bushel coefficients (requires FruitType to be available),
--     then triggers the manager's post-load routine (HUD setup, etc.).
-- UA: Викликається після завершення завантаження місії.
--     Ініціалізує коефіцієнти бушелів для конвертора одиниць (потрібен FruitType),
--     а потім запускає процедуру після завантаження менеджера (налаштування HUD тощо).
local function loadedMission(mission, node)
    if not isEnabled() then
        return
    end

    if mission.cancelLoading then
        return
    end
    
    -- EN: Initialize bushel coefficients safely (FruitType is only available after mission load).
    -- UA: Безпечно ініціалізуємо коефіцієнти бушелів (FruitType доступний тільки після завантаження місії).
    if RHM_UnitConverter and RHM_UnitConverter.initBushelCoefficients then
        RHM_UnitConverter.initBushelCoefficients()
    end

    if RHM_DiagnosticTool and RHM_DiagnosticTool.init then
        RHM_DiagnosticTool:init()
    end

    if RHM_MoistureAdapter and RHM_MoistureAdapter.initialize then
        RHM_MoistureAdapter.initialize()
    end

    -- EN: Register and localize all map fruit and fill types immediately on mission load
    -- UA: Реєструємо та локалізуємо всі типи культур та врожаїв карти одразу при завантаженні місії
    if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.initMapCrops then
        RHM_CombineSettingsDatabase:initMapCrops()
    end

    -- EN: Register unified RHM texture atlas (Help tabs, HUD telemetry, and Shift+J UI icons)
    -- UA: Реєструємо єдиний атлас іконок RHM (вкладки довідки, HUD телеметрія та іконки Shift+J)
    g_overlayManager:addTextureConfigFile(modDirectory .. "textures/rhm_atlas.xml", "rhmUi")

    rhm:onMissionLoaded()

    -- EN: Load persistent harvest trip and fleet statistics on the server
    -- UA: Завантажуємо збережені дані одометра та парку техніки на сервері
    local isServer = (mission and mission.getIsServer and mission:getIsServer()) or (g_server ~= nil)
    local saveDir = resolveSavegameDirectory(mission)
    if isServer and saveDir then
        local xmlPath = getSavegameFilePath(saveDir, "realisticHarvestingData.xml")
        local tracker = (rhm and rhm.harvestTracker) or (g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker)
        if xmlPath and fileExists(xmlPath) and tracker then
            local xmlFile = loadXMLFile("RHM_Data", xmlPath)
            if xmlFile ~= 0 then
                tracker:loadFromXMLFile(xmlFile, "realisticHarvesting")
                delete(xmlFile)
                rhm_log(string.format("RHM: [LOAD] Successfully restored harvest tracker data from %s", xmlPath))
            end
        else
            rhm_log(string.format("RHM: [LOAD] No existing realisticHarvestingData.xml found at %s (fresh start or first run)", tostring(xmlPath)))
        end
    end

    if RHM_ModCompatibility and RHM_ModCompatibility.init then
        RHM_ModCompatibility.init()
    end
end

-- EN: Called when the mission starts loading.
--     Creates the main manager instance and initializes the RHM_ProfileManager.
-- UA: Викликається при початку завантаження місії.
--     Створює головний екземпляр менеджера та ініціалізує RHM_ProfileManager.
local function loadMission(mission)
    if rhm == nil then
        rhm = RHM_RealisticHarvestManager.new(mission, modDirectory, modName)
        -- EN: Expose manager globally so other scripts can access it via g_realisticHarvestManager.
        -- UA: Робимо менеджер глобально доступним, щоб інші скрипти могли звертатись через g_realisticHarvestManager.
        getfenv(0)["g_realisticHarvestManager"] = rhm

        rhm.profileManager = RHM_ProfileManager.new()
        rhm.profileManager:loadProfiles()
    end
end

-- EN: Called when the mission is deleted (game exit, map change).
--     Destroys the manager and removes the global reference.
-- UA: Викликається при видаленні місії (вихід з гри, зміна карти).
--     Знищує менеджер та видаляє глобальне посилання.
local function unload()
    if rhm ~= nil then
        rhm:delete()
        rhm = nil
        getfenv(0)["g_realisticHarvestManager"] = nil
        getfenv(0)["RHM_API"] = nil
        getfenv(0)["RHM_Api"] = nil
    end
end

-- EN: Called once during type validation by the TypeManager.
--     Registers the rhm_Combine specialization and adds it to all vehicle types
--     that already have the base Combine specialization.
-- UA: Викликається один раз TypeManager при валідації типів.
--     Реєструє спеціалізацію rhm_Combine і додає її до всіх типів транспортних засобів,
--     які вже мають базову спеціалізацію Combine.
local function validateTypes(manager)
    if manager.typeName == "vehicle" then
        -- EN: Add the specialization to genuine harvesters (grain, forage, root, specialty)
        --     while strictly excluding non-combines (balers, cutting balers, mobile pelletizers, bale shredders).
        -- UA: Додаємо спеціалізацію лише до справжніх комбайнів (зернових, силосних, коренеплодів, спецтехніки),
        --     суворо виключаючи не-комбайни (тюкопреси, гранулятори, подрібнювачі тюків).
        for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
            local hasCombine = SpecializationUtil.hasSpecialization(Combine, typeEntry.specializations)
            local hasForage = (ForageHarvester ~= nil and SpecializationUtil.hasSpecialization(ForageHarvester, typeEntry.specializations))
            local hasCotton = (CottonHarvester ~= nil and SpecializationUtil.hasSpecialization(CottonHarvester, typeEntry.specializations))
                or (typeName and typeName:lower():find("cotton") ~= nil)
                or (typeEntry.specializationsByName and (typeEntry.specializationsByName["cottonharvester"] ~= nil or typeEntry.specializationsByName["cottonHarvester"] ~= nil))

            if hasCombine or hasForage or hasCotton then
                local isExcludedNonCombine = false

                if not hasCotton then
                    -- 1. Check if vehicle has Baler specialization (e.g. cutting balers like BioBaler WB-55, round/square balers)
                    if Baler ~= nil and SpecializationUtil.hasSpecialization(Baler, typeEntry.specializations) then
                        isExcludedNonCombine = true
                    end

                    -- 2. Check typeName string for known non-combine processing equipment
                    if not isExcludedNonCombine and typeName then
                        local tLower = typeName:lower()
                        if tLower:find("baler") or tLower:find("pellet") or tLower:find("premos") or tLower:find("baleshredder") or tLower:find("biobaler") then
                            isExcludedNonCombine = true
                        end
                    end

                    -- 3. Check specializationsByName / specializationNames
                    if not isExcludedNonCombine and typeEntry.specializationsByName then
                        for sName, _ in pairs(typeEntry.specializationsByName) do
                            local sLower = tostring(sName):lower()
                            if sLower:find("baler") or sLower:find("pelletizer") or sLower:find("baleshredder") then
                                isExcludedNonCombine = true
                                break
                            end
                        end
                    end

                    if not isExcludedNonCombine and typeEntry.specializationNames then
                        for _, sName in ipairs(typeEntry.specializationNames) do
                            local sLower = tostring(sName):lower()
                            if sLower:find("baler") or sLower:find("pelletizer") or sLower:find("baleshredder") then
                                isExcludedNonCombine = true
                                break
                            end
                        end
                    end
                end

                if not isExcludedNonCombine then
                    g_vehicleTypeManager:addSpecialization(typeName, modName .. ".rhm_Combine")
                end
            end

            -- EN: Register rhm_Cutter specialization on all genuine cutters
            -- UA: Реєструємо спеціалізацію rhm_Cutter на всіх жатках
            local hasCutter = (Cutter ~= nil and SpecializationUtil.hasSpecialization(Cutter, typeEntry.specializations))
            local hasTurnOn = (TurnOnVehicle ~= nil and SpecializationUtil.hasSpecialization(TurnOnVehicle, typeEntry.specializations))
            if hasCutter and hasTurnOn then
                g_vehicleTypeManager:addSpecialization(typeName, modName .. ".rhm_Cutter")
            end
        end
    end
end

-- EN: Hook into the mission lifecycle using FS25's Utils.appendedFunction/prependedFunction pattern.
-- UA: Підключаємось до життєвого циклу місії через Utils.appendedFunction/prependedFunction від FS25.
Mission00.load = Utils.prependedFunction(Mission00.load, loadMission)
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)

-- EN: Helper to persist realisticHarvestingData.xml on server or career save using native GIANTS Engine XML API
-- UA: Допоміжна функція для запису realisticHarvestingData.xml через нативний GIANTS XML API (без блокованих пісочницею copyFile/deleteFile)
local lastSavedDir = nil
local lastSavedTime = 0

local function saveRealisticHarvestingData(savegameDirectory)
    if not savegameDirectory or savegameDirectory == "" then return end
    local tracker = (rhm and rhm.harvestTracker) or (g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker)
    if not tracker then return end

    local now = (g_currentMission and g_currentMission.time) or g_time or 0
    -- EN: Prevent duplicate saves within the same save cycle (e.g. FSCareerMissionInfo and FSBaseMission hooks firing together)
    -- UA: Запобігаємо подвійному запису протягом одного сейв-циклу
    if lastSavedDir == savegameDirectory and math.abs(now - lastSavedTime) < 5000 then
        return
    end

    local xmlPath = getSavegameFilePath(savegameDirectory, "realisticHarvestingData.xml")
    if not xmlPath then return end

    local xmlFile = createXMLFile("RHM_Data", xmlPath, "realisticHarvesting")
    if xmlFile ~= 0 then
        tracker:saveToXMLFile(xmlFile, "realisticHarvesting")
        saveXMLFile(xmlFile)
        delete(xmlFile)
        lastSavedDir = savegameDirectory
        lastSavedTime = now
        rhm_log(string.format("RHM: [SAVE] Successfully saved realisticHarvestingData.xml to %s", xmlPath))
    else
        Logging.devWarning(string.format("RHM: [SAVE] Failed to create XML file at %s", xmlPath))
    end
end

-- EN: Hook interactive menu saving (Single Player / Client Host)
-- UA: Підключаємось до збереження через меню (Одиночна гра / Клієнт-хост)
local function onSaveSavegame(self)
    local isServer = (self and self.getIsServer and self:getIsServer())
        or (g_currentMission and g_currentMission.getIsServer and g_currentMission:getIsServer())
        or (g_server ~= nil)
    local saveDir = resolveSavegameDirectory(self)
    if isServer and saveDir then
        saveRealisticHarvestingData(saveDir)
    end
end
if FSBaseMission and FSBaseMission.saveSavegame then
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, onSaveSavegame)
end
if Mission00 and Mission00.saveSavegame and Mission00.saveSavegame ~= FSBaseMission.saveSavegame then
    Mission00.saveSavegame = Utils.appendedFunction(Mission00.saveSavegame, onSaveSavegame)
end

-- EN: Hook dedicated server autosave & career XML serialization (Dedicated Server)
-- UA: Підключаємось до збереження виділеного сервера (Dedicated Server)
local function onCareerMissionInfoSaveToXMLFile(missionInfo, customSavegameDirectory)
    local saveDir = (customSavegameDirectory and customSavegameDirectory ~= "" and customSavegameDirectory)
        or resolveSavegameDirectory(missionInfo)
    if saveDir then
        saveRealisticHarvestingData(saveDir)
    end
end
if FSCareerMissionInfo and FSCareerMissionInfo.saveToXMLFile then
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, onCareerMissionInfoSaveToXMLFile)
end
if FSMissionInfo and FSMissionInfo.saveToXMLFile and FSMissionInfo.saveToXMLFile ~= FSCareerMissionInfo.saveToXMLFile then
    FSMissionInfo.saveToXMLFile = Utils.appendedFunction(FSMissionInfo.saveToXMLFile, onCareerMissionInfoSaveToXMLFile)
end

-- EN: Hook initial client state transmission in multiplayer to sync farm data & settings to joining player
-- UA: Передаємо повний стан ферм та налаштування гравцю, який приєднується до сесії мультиплеєра
local function onSendInitialClientState(mission, connection, user, isReconnect)
    local manager = rhm or g_realisticHarvestManager
    local tracker = manager and manager.harvestTracker
    if mission and connection and tracker and (g_server ~= nil or (mission.missionDynamicInfo and mission.missionDynamicInfo.isMultiplayer)) then
        -- Sync active global physics & farm settings
        if manager.settings and RHM_SettingsSyncEvent then
            connection:sendEvent(RHM_SettingsSyncEvent.new(manager.settings))
        end
        -- Sync all farm statistics, combine trips, and season history
        if tracker.farms then
            for farmId, farmData in pairs(tracker.farms) do
                if farmData and RHM_HarvestSyncInitialEvent then
                    connection:sendEvent(RHM_HarvestSyncInitialEvent.new(farmId, farmData))
                end
            end
        end
    end
end
FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState, onSendInitialClientState)

-- EN: Update hook — runs every game frame to update HUD data and calibration GUI state.
--     Guarded against re-entrant calls when Mission00 calls superClass().update.
-- UA: Хук оновлення — виконується кожен кадр для оновлення даних HUD та стану GUI калібрування.
--     Захищений від повторного виклику коли Mission00 викликає superClass().update.
local isUpdating = false
local function onMissionUpdate(mission, dt)
    if isUpdating then
        return
    end
    isUpdating = true

    if rhm then
        rhm:update(dt)
    end

    if RHM_DiagnosticTool and RHM_DiagnosticTool.update then
        RHM_DiagnosticTool:update(dt)
    end

    isUpdating = false
end
if Mission00 ~= nil then
    Mission00.update = Utils.appendedFunction(Mission00.update, onMissionUpdate)
elseif FSBaseMission ~= nil then
    FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, onMissionUpdate)
end

-- EN: Draw hook — runs every game frame to render HUD overlays.
--     IMPORTANT: renderOverlay() only works within draw callbacks, not update!
-- UA: Хук малювання — виконується кожен кадр для рендерингу HUD оверлеїв.
--     ВАЖЛИВО: renderOverlay() працює ТІЛЬКИ в draw callbacks, не в update!
local isDrawing = false
local function onMissionDraw(mission)
    if isDrawing then
        return
    end
    isDrawing = true

    if rhm then
        rhm:draw()
    end

    isDrawing = false
end
if Mission00 ~= nil then
    Mission00.draw = Utils.appendedFunction(Mission00.draw, onMissionDraw)
elseif FSBaseMission ~= nil then
    FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, onMissionDraw)
end

-- EN: Mouse event hook — captures mouse input for calibration GUI and HUD dragging.
--     Hooks Mission00 (or FSBaseMission fallback) to avoid recursive double delta handling.
-- UA: Хук події миші — перехоплює введення миші для GUI калібрування та перетягування HUD.
--     Підключається до Mission00 (або FSBaseMission фолбек), уникаючи подвійної обробки дельт миші.
local function onMissionMouseEvent(mission, superFunc, posX, posY, isDown, isUp, button)
    if rhm then
        local wasUsed = rhm:mouseEvent(posX, posY, isDown, isUp, button)
        if wasUsed then
            return true
        end
    end
    if superFunc ~= nil then
        return superFunc(mission, posX, posY, isDown, isUp, button)
    end
end
if Mission00 ~= nil then
    Mission00.mouseEvent = Utils.overwrittenFunction(Mission00.mouseEvent, onMissionMouseEvent)
elseif FSBaseMission ~= nil then
    FSBaseMission.mouseEvent = Utils.overwrittenFunction(FSBaseMission.mouseEvent, onMissionMouseEvent)
end

-- EN: Key event hook — captures keyboard input (e.g. ESC to close calibration GUI).
-- UA: Хук клавіатури — перехоплює клавіші (наприклад ESC для закриття GUI калібрування).
local function onMissionKeyEvent(mission, superFunc, unicode, sym, modifier, isDown)
    if rhm and rhm.keyEvent then
        local wasUsed = rhm:keyEvent(unicode, sym, modifier, isDown)
        if wasUsed then
            return true
        end
    end
    if superFunc ~= nil then
        return superFunc(mission, unicode, sym, modifier, isDown)
    end
end
if Mission00 ~= nil then
    Mission00.keyEvent = Utils.overwrittenFunction(Mission00.keyEvent, onMissionKeyEvent)
elseif FSBaseMission ~= nil then
    FSBaseMission.keyEvent = Utils.overwrittenFunction(FSBaseMission.keyEvent, onMissionKeyEvent)
end

-- EN: Register the specialization before vehicle types are validated.
-- UA: Реєструємо спеціалізацію до валідації типів транспортних засобів.
TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateTypes)


