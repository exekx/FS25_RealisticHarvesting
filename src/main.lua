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
source(modDirectory .. "src/settings/RHM_Configuration.lua")
source(modDirectory .. "src/settings/RHM_SettingsManager.lua")
source(modDirectory .. "src/settings/RHM_Settings.lua")
source(modDirectory .. "src/settings/RHM_SettingsGUI.lua")
source(modDirectory .. "src/network/RHM_SettingsSyncEvent.lua")
source(modDirectory .. "src/network/RHM_SettingsSync.lua")
source(modDirectory .. "src/utils/RHM_InputUtil.lua")
source(modDirectory .. "src/utils/RHM_UnitConverter.lua")
source(modDirectory .. "src/settings/RHM_SettingsUI.lua")
source(modDirectory .. "src/hud/RHM_NotificationManager.lua")
source(modDirectory .. "src/hud/RHM_DraggableHUD.lua")
source(modDirectory .. "src/gui/RHM_CombineCalibrationGUI.lua")
source(modDirectory .. "src/data/RHM_CombineSettingsDatabase.lua")
source(modDirectory .. "src/settings/RHM_ProfileManager.lua")
source(modDirectory .. "src/settings/RHM_CombineMemory.lua")
source(modDirectory .. "src/network/RHM_CombineSettingsEvent.lua")
source(modDirectory .. "src/integration/RHM_MoistureAdapter.lua")
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

-- EN: Global reference to the main mod manager instance (nil = disabled/not loaded).
-- UA: Глобальне посилання на головний екземпляр менеджера мода (nil = вимкнено/не завантажено).
local rhm

-- EN: Returns true if the mod manager has been successfully initialized.
-- UA: Повертає true, якщо менеджер мода успішно ініціалізований.
local function isEnabled()
    return rhm ~= nil
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

    if RHM_MoistureAdapter and RHM_MoistureAdapter.initialize then
        RHM_MoistureAdapter.initialize()
    end

    -- EN: Register and localize all map fruit and fill types immediately on mission load
    -- UA: Реєструємо та локалізуємо всі типи культур та врожаїв карти одразу при завантаженні місії
    if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.initMapCrops then
        RHM_CombineSettingsDatabase:initMapCrops()
    end

    -- EN: Register custom help menu tab icons
    -- UA: Реєструємо власні іконки для вкладок меню довідки
    local tabs = {"overview", "hud", "calibration", "special", "croploss", "difficulty", "upgrades", "moisture"}
    for _, tab in ipairs(tabs) do
        g_overlayManager:addTextureConfigFile(modDirectory .. "textures/tab_icons/" .. tab .. ".xml", "rhmHelp_" .. tab)
    end

    rhm:onMissionLoaded()

    if RHM_ModCompatibility and RHM_ModCompatibility.init then
        RHM_ModCompatibility.init()
    end
end

-- EN: Called when the mission starts loading.
--     Creates the main manager instance and initializes the RHM_ProfileManager.
-- UA: Викликається при початку завантаження місії.
--     Створює головний екземпляр менеджера та ініціалізує RHM_ProfileManager.
local function load(mission)
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
        -- EN: Add the specialization to every vehicle type that has a Combine spec.
        -- UA: Додаємо спеціалізацію до кожного типу транспорту, який має спеціалізацію Combine.
        for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
            if SpecializationUtil.hasSpecialization(Combine, typeEntry.specializations) then
                g_vehicleTypeManager:addSpecialization(typeName, modName .. ".rhm_Combine")
            end
        end
    end
end

-- EN: Hook into the mission lifecycle using FS25's Utils.appendedFunction/prependedFunction pattern.
-- UA: Підключаємось до життєвого циклу місії через Utils.appendedFunction/prependedFunction від FS25.
Mission00.load = Utils.prependedFunction(Mission00.load, load)
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)

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


