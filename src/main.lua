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

-- EN: Load all subsystem scripts in dependency order.
-- UA: Завантажуємо всі підсистемні скрипти у порядку залежностей.
source(modDirectory .. "src/utils/RHM_Debug.lua")
source(modDirectory .. "src/settings/SettingsManager.lua")
source(modDirectory .. "src/settings/Settings.lua")
source(modDirectory .. "src/settings/SettingsGUI.lua")
source(modDirectory .. "src/network/SettingsSyncEvent.lua")
source(modDirectory .. "src/network/SettingsSync.lua")
source(modDirectory .. "src/utils/RHMInputUtil.lua")
source(modDirectory .. "src/utils/UIHelper.lua")
source(modDirectory .. "src/utils/UnitConverter.lua")
source(modDirectory .. "src/settings/SettingsUI.lua")
source(modDirectory .. "src/hud/HUDRenderer.lua")
source(modDirectory .. "src/hud/DraggableHUD.lua")
source(modDirectory .. "src/gui/CombineSettingsGUI.lua")
source(modDirectory .. "src/gui/CombineCalibrationGUI.lua")
source(modDirectory .. "src/data/CombineSettingsDatabase.lua")
source(modDirectory .. "src/settings/ProfileManager.lua")
source(modDirectory .. "src/settings/CombineMemory.lua")
source(modDirectory .. "src/network/CombineSettingsEvent.lua")
source(modDirectory .. "src/logic/LoadCalculator.lua")
source(modDirectory .. "src/rhm_Combine.lua")
-- EN: CRITICAL: rhm_Cutter must be loaded AFTER rhm_Combine for independent header launch to work.
-- UA: КРИТИЧНО: rhm_Cutter має бути завантажений ПІСЛЯ rhm_Combine, щоб роздільний запуск жатки працював.
source(modDirectory .. "src/rhm_Cutter.lua")
source(modDirectory .. "src/RealisticHarvestManager.lua")

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
    if UnitConverter and UnitConverter.initBushelCoefficients then
        UnitConverter.initBushelCoefficients()
    end

    rhm:onMissionLoaded()
end

-- EN: Called when the mission starts loading.
--     Creates the main manager instance and initializes the ProfileManager.
-- UA: Викликається при початку завантаження місії.
--     Створює головний екземпляр менеджера та ініціалізує ProfileManager.
local function load(mission)
    if rhm == nil then
        rhm = RealisticHarvestManager.new(mission, modDirectory, modName)
        -- EN: Expose manager globally so other scripts can access it via g_realisticHarvestManager.
        -- UA: Робимо менеджер глобально доступним, щоб інші скрипти могли звертатись через g_realisticHarvestManager.
        getfenv(0)["g_realisticHarvestManager"] = rhm

        rhm.profileManager = ProfileManager.new()
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
        -- EN: Register the specialization class itself.
        -- UA: Реєструємо сам клас спеціалізації.
        g_specializationManager:addSpecialization("rhm_Combine", "rhm_Combine", modDirectory .. "src/rhm_Combine.lua", nil)

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
-- UA: Хук оновлення — виконується кожен кадр для оновлення даних HUD та стану GUI калібрування.
FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(mission, dt)
    if rhm then
        rhm:update(dt)
    end
end)

-- EN: Draw hook — runs every game frame to render HUD overlays.
--     IMPORTANT: renderOverlay() only works within draw callbacks, not update!
-- UA: Хук малювання — виконується кожен кадр для рендерингу HUD оверлеїв.
--     ВАЖЛИВО: renderOverlay() працює ТІЛЬКИ в draw callbacks, не в update!
FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, function(mission)
    if rhm then
        rhm:draw()
    end
end)

-- EN: Mouse event hook — captures mouse input for HUD drag-and-drop.
--     Returns true to consume the event and prevent the game from handling it.
-- UA: Хук події миші — перехоплює введення миші для перетягування HUD.
--     Повертає true, щоб поглинути подію і не дати грі її обробити.
FSBaseMission.mouseEvent = Utils.prependedFunction(FSBaseMission.mouseEvent, function(mission, posX, posY, isDown, isUp, button)
    if rhm then
        local wasUsed = rhm:mouseEvent(posX, posY, isDown, isUp, button)
        if wasUsed then
            -- EN: Prevent game from handling this mouse event.
            -- UA: Забороняємо грі обробляти цю подію миші.
            return true
        end
    end
end)

-- EN: Register the specialization before vehicle types are validated.
-- UA: Реєструємо спеціалізацію до валідації типів транспортних засобів.
TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateTypes)
