local modDirectory = g_currentModDirectory
local modName = g_currentModName

source(modDirectory .. "src/settings/SettingsManager.lua")
source(modDirectory .. "src/settings/Settings.lua")
source(modDirectory .. "src/settings/SettingsGUI.lua")  -- Console commands for settings
source(modDirectory .. "src/network/SettingsSyncEvent.lua")  -- Network event for settings sync
source(modDirectory .. "src/network/SettingsSync.lua")  -- Settings sync helper
source(modDirectory .. "src/utils/RHMInputUtil.lua")  -- Input control utility (camera blocking)
source(modDirectory .. "src/utils/UIHelper.lua")
source(modDirectory .. "src/utils/UnitConverter.lua")  -- Unit conversion utility
source(modDirectory .. "src/settings/SettingsUI.lua")
source(modDirectory .. "src/hud/HUDRenderer.lua")
source(modDirectory .. "src/hud/DraggableHUD.lua")
source(modDirectory .. "src/gui/CombineSettingsGUI.lua")  -- Combine settings console UI
source(modDirectory .. "src/gui/CombineCalibrationGUI.lua")  -- Visual calibration GUI
source(modDirectory .. "src/data/CombineSettingsDatabase.lua")  -- Combine settings database
source(modDirectory .. "src/settings/ProfileManager.lua")  -- Global user profiles
source(modDirectory .. "src/settings/CombineMemory.lua")  -- Combine settings memory
source(modDirectory .. "src/network/CombineSettingsEvent.lua")  -- Network event for combine settings
source(modDirectory .. "src/logic/LoadCalculator.lua")  -- Розрахунок навантаження
source(modDirectory .. "src/rhm_Combine.lua")  -- Specialization для комбайна
source(modDirectory .. "src/rhm_Cutter.lua")  -- Налаштування для жаток (КРИТИЧНО для роздільного запуску!)
source(modDirectory .. "src/RealisticHarvestManager.lua")

local rhm

local function isEnabled()
    return rhm ~= nil
end

-- Викликається після завантаження місії
local function loadedMission(mission, node)
    if not isEnabled() then
        return
    end
    
    if mission.cancelLoading then
        return
    end
    
    -- Init units safely
    if UnitConverter and UnitConverter.initBushelCoefficients then
        UnitConverter.initBushelCoefficients()
    end
    
    rhm:onMissionLoaded()
end

local function load(mission)
    if rhm == nil then
        rhm = RealisticHarvestManager.new(mission, modDirectory, modName)
        getfenv(0)["g_realisticHarvestManager"] = rhm
        
        -- Initialize ProfileManager
        rhm.profileManager = ProfileManager.new()
        rhm.profileManager:loadProfiles()
    end
end

-- Викликається при видаленні
local function unload()
    if rhm ~= nil then
        rhm:delete()
        rhm = nil
        getfenv(0)["g_realisticHarvestManager"] = nil
    end
end

-- Реєстрація specialization для комбайнів
local function validateTypes(manager)
    if manager.typeName == "vehicle" then
        -- Додаємо specialization
        g_specializationManager:addSpecialization("rhm_Combine", "rhm_Combine", modDirectory .. "src/rhm_Combine.lua", nil)
        
        -- Додаємо specialization до всіх комбайнів
        for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
            if SpecializationUtil.hasSpecialization(Combine, typeEntry.specializations) then
                g_vehicleTypeManager:addSpecialization(typeName, modName .. ".rhm_Combine")
            end
        end
    end
end

-- Реєстрація хуків
Mission00.load = Utils.prependedFunction(Mission00.load, load)
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)

-- Додаємо update для оновлення HUD кожен кадр
FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(mission, dt)
    if rhm then
        rhm:update(dt)
    end
end)

-- Додаємо draw для МАЛЮВАННЯ HUD кожен кадр
-- ВАЖЛИВО: renderOverlay() працює ТІЛЬКИ в draw callbacks!
FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, function(mission)
    if rhm then
        rhm:draw()
    end
end)

-- Додаємо mouse event для drag & drop HUD
FSBaseMission.mouseEvent = Utils.prependedFunction(FSBaseMission.mouseEvent, function(mission, posX, posY, isDown, isUp, button)
    if rhm then
        local wasUsed = rhm:mouseEvent(posX, posY, isDown, isUp, button)
        if wasUsed then
            -- Prevent game from handling this mouse event
            return true
        end
    end
end)

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateTypes)

