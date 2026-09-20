-- EN: High-end touchscreen field terminal for combine harvester calibration (CEBIS / CommandCenter style).
--     Features dynamic Tier progression:
--       - Tier 1 (Standard): Pure manual controls, no optimal markers, AUTO locked with informative prompt.
--       - Tier 2 (Sensor Kit): Displays glowing green sweet-spot bands on sliders with live deviation indicators.
--       - Tier 3 (Monitor): Unlocks live digital telemetry cards (Load, Speed Efficiency, Loss) and custom profile Save/Load.
--       - Tier 4 (Opti-Harvest AI): Cybernetic styling accents and active one-touch [AI AUTO-CALIBRATION].
--     Interactive horizontal track-bar sliders with recessed grooves, tick marks, direct dragging, and micro-step buttons [-]/[+].
--     Deep obsidian carbon glass aesthetic with zero blue cast, matching authentic in-cab agricultural displays.
-- UA: Висококласний сенсорний польовий термінал для калібрування комбайна (у стилі CEBIS / CommandCenter).
--     Має динамічну прогресію за рівнями (Tiers):
--       - Рівень 1 (Базовий): Чисте ручне керування, без оптимальних маркерів, AUTO заблоковано з підказкою.
--       - Рівень 2 (Сенсорний набір): Сяючі зелені смуги sweet-spot на слайдерах з точними показниками відхилення.
--       - Рівень 3 (Монітор): Картки цифрової телеметрії (Навантаження, ККД швидкості, Втрати) та Збереження/Завантаження профілів.
--       - Рівень 4 (Opti-Harvest AI): Кібернетичні акценти та активна кнопка [AI АВТО-КАЛІБРУВАННЯ] в один дотик.
--     Інтерактивні трек-слайдери з поглибленими пазами, мітками шкали, прямим перетягуванням та мікро-кнопками [-]/[+].
--     Глибоке карбонове скло без сторонніх синіх відтінків, що відповідає справжнім терміналам у кабіні.

RHMCombineCalibrationGUI = {}
local CombineCalibrationGUI_mt = Class(RHMCombineCalibrationGUI)

local PARAM_SECTION_MAP = {
    -- GRAIN
    rotor            = "SEPARATION",
    concave          = "SEPARATION",
    upperSieve       = "CLEANING",
    lowerSieve       = "CLEANING",
    fan              = "CLEANING",
    -- FORAGE
    chopLength       = "SEPARATION",
    kernelProcessor  = "SEPARATION",
    blower           = "DISCHARGE",
    -- ROOT
    shakingIntensity = "SEPARATION",
    feeder           = "SEPARATION",
}

local SECTIONS_ORDERED = {
    { key = "SEPARATION", label = "rhm_ui_section_separation" },
    { key = "CLEANING",   label = "rhm_ui_section_cleaning"   },
    { key = "DISCHARGE",  label = "rhm_ui_section_discharge"  },
}

function RHMCombineCalibrationGUI.new(modDirectory)
    local self = setmetatable({}, CombineCalibrationGUI_mt)
    self.modDirectory = modDirectory
    self.isOpen = false
    self.isCursorActive = false

    -- In-cab tablet layout (Tactile Field Terminal)
    self.ui = {
        x = 0.60, y = 0.35,
        w = 0.392, h = 0.55,
        margin       = 0.009,
        headerHeight = 0.038,
        statsHeight  = 0.032,
        lineHeight   = 0.036,
        sectionGap   = 0.020,
        fontSize     = 0.0125,
        titleSize    = 0.0145,
        sectionSize  = 0.0115,
        statusSize   = 0.0095,
        buttonW      = 0.017,
        buttonH      = 0.017,
        bezelSide    = 0.0025,
        bezelBottom  = 0.0038,
        bezelTop     = 0.0038,

        -- Authentic frosted glass palette (unified with RHM Draggable HUD, game HUD, and Notifications)
        colors = {
            outerBorder    = {1.00, 1.00, 1.00, 0.10}, -- 1px subtle glass edge
            bg             = {0.012, 0.015, 0.020, 0.68}, -- Smoked semi-transparent glass base
            header         = {0.0, 0.0, 0.0, 0.0}, -- Seamless with body glass
            headerAccent   = {0.529, 0.706, 0.0, 1.0}, -- Authentic game HUD green accent line
            sectionBg      = {0.0, 0.0, 0.0, 0.0}, -- Transparent, seamless with body glass
            sectionNotch   = {0.529, 0.706, 0.0, 1.0}, -- Authentic game HUD green notch
            statsCardBg    = {0.005, 0.008, 0.012, 0.45}, -- Recessed frosted telemetry card background
            statsCardBorder= {1.00, 1.00, 1.00, 0.12},
            separator      = {1.00, 1.00, 1.00, 0.10},
            paramRowHover  = {1.00, 1.00, 1.00, 0.025},

            -- Tactile Slider Colors
            trackGroove    = {0.0, 0.0, 0.0, 0.50}, -- Deep recessed groove
            trackBorder    = {1.00, 1.00, 1.00, 0.10},
            trackTick      = {1.00, 1.00, 1.00, 0.12},
            trackOptimal   = {0.529, 0.706, 0.0, 0.45}, -- Game HUD green sweet spot band
            trackOptimalBorder = {0.529, 0.706, 0.0, 0.70},
            trackCenterNotch   = {0.529, 0.706, 0.0, 0.95},
            trackThumb     = {0.94, 0.95, 0.97, 1.00}, -- Brushed metallic silver
            trackThumbHover= {1.00, 1.00, 1.00, 1.00},
            trackFill      = {0.529, 0.706, 0.0, 0.88}, -- Game HUD green fill
            trackFillWarn  = {0.95, 0.72, 0.18, 0.88}, -- Warm amber fill
            trackFillErr   = {0.90, 0.24, 0.24, 0.88}, -- Alert ruby red fill

            text           = {0.94, 0.95, 0.97, 1.00},
            textDim        = {0.70, 0.73, 0.78, 1.00},
            success        = {0.529, 0.706, 0.0, 1.00}, -- Authentic game HUD green
            warning        = {0.95, 0.72, 0.18, 1.00}, -- Warm amber
            error          = {0.90, 0.24, 0.24, 1.00}, -- Alert red

            button         = {0.04, 0.04, 0.05, 0.65}, -- Dark graphite monochrome
            buttonBorder   = {1.00, 1.00, 1.00, 0.12},
            buttonHover    = {0.12, 0.14, 0.16, 0.85},
            buttonHoverBorder = {0.529, 0.706, 0.0, 0.70}, -- Game green outline hover
            buttonAuto     = {0.20, 0.28, 0.04, 0.85}, -- Deep olive green pill
            buttonAutoBorder={0.529, 0.706, 0.0, 0.88},
            buttonAutoHover= {0.30, 0.42, 0.06, 0.95},
            buttonReset    = {0.04, 0.04, 0.05, 0.65}, -- Restrained dark graphite
            buttonResetBorder={0.85, 0.28, 0.28, 0.45}, -- Subtle terracotta red border
            buttonResetHover={0.35, 0.10, 0.10, 0.75}, -- Warm amber-red on hover
        }
    }

    self.activeVehicle = nil
    self.hoveredElement = nil
    self.mouseX = 0
    self.mouseY = 0
    self.hoveredParameter = nil
    self.draggingSlider = nil

    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}

    self.lastScrollTimeStamp = 0
    self.scrollDelayMs = 100

    self.buttons = {}
    self.sliders = {}

    self.isDraggingTablet = false
    self.dragOffsetTabletX = 0
    self.dragOffsetTabletY = 0
    self.hasCustomPosition = false

    local bgTexture = self.modDirectory .. "textures/hud_icons.dds"
    self.overlay = Overlay.new(bgTexture, 0, 0, 1, 1)
    if GuiUtils and GuiUtils.getUVs then
        self.overlay:setUVs(GuiUtils.getUVs({388, 4, 56, 56}, {512, 64}))
    else
        self.overlay:setUVs({0.758, 0.062, 0.758, 0.937, 0.867, 0.062, 0.867, 0.937})
    end

    local panelTexturePath = Utils.getFilename("textures/panelRounded.dds", self.modDirectory)
    self.roundedOverlay = Overlay.new(panelTexturePath, 0, 0, 1, 1)

    local pxUVs = {
        topLeft     = {  0,  0,  5,  5 },
        top         = {  5,  0, 54,  5 },
        topRight    = { 59,  0,  5,  5 },
        left        = {  0,  5,  5, 54 },
        center      = {  5,  5, 54, 54 },
        right       = { 59,  5,  5, 54 },
        bottomLeft  = {  0, 59,  5,  5 },
        bottom      = {  5, 59, 54,  5 },
        bottomRight = { 59, 59,  5,  5 }
    }
    self.roundedUVs = {}
    for key, coords in pairs(pxUVs) do
        self.roundedUVs[key] = GuiUtils.getUVs(coords, {64, 64})
    end

    return self
end

function RHMCombineCalibrationGUI:delete()
    if self.overlay then
        self.overlay:delete()
        self.overlay = nil
    end
    if self.roundedOverlay then
        self.roundedOverlay:delete()
        self.roundedOverlay = nil
    end
    self.roundedUVs = nil
end

function RHMCombineCalibrationGUI:toggle(vehicle)
    if self.isOpen then
        self:close()
    else
        self:open(vehicle)
    end
end

function RHMCombineCalibrationGUI:open(vehicle)
    if self.isOpen then return end

    local combineVehicle = vehicle
    if vehicle and not vehicle.spec_rhm_Combine then
        local function findCombine(v, visited)
            if not v or visited[v] then return nil end
            visited[v] = true
            if v.spec_rhm_Combine then return v end
            if v.rootVehicle then
                local r = findCombine(v.rootVehicle, visited)
                if r then return r end
            end
            if v.attacherVehicle then
                local r = findCombine(v.attacherVehicle, visited)
                if r then return r end
            end
            if v.getAttachedImplements then
                for _, impl in ipairs(v:getAttachedImplements() or {}) do
                    if impl.object then
                        local r = findCombine(impl.object, visited)
                        if r then return r end
                    end
                end
            end
            return nil
        end
        local found = findCombine(vehicle.rootVehicle or vehicle, {})
        if found then
            combineVehicle = found
            rhm_log(string.format("RHM [UI]: RHM: [GUI] NEXAT: found combine vehicle in hierarchy: %s", tostring(combineVehicle)))
        else
            rhm_log("RHM [UI]: RHM: [GUI] No combine with spec_rhm_Combine found in vehicle hierarchy — GUI will not open")
            return
        end
    end

    self.isOpen = true

    -- Notify compatibility layer (IC, Headtracking) to suspend conflicting overlays and exclusive action events
    if RHM_ModCompatibility and RHM_ModCompatibility.onCalibrationGUIOpened then
        RHM_ModCompatibility.onCalibrationGUIOpened()
    end

    g_inputBinding:setShowMouseCursor(true)
    self.isCursorActive = true

    local cv = nil
    if g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
        cv = g_realisticHarvestManager:getControlledVehicle()
    end
    if not cv then
        if g_localPlayer and g_localPlayer.getCurrentVehicle then
            cv = g_localPlayer:getCurrentVehicle()
        elseif g_currentMission then
            if g_currentMission.getControlledVehicle then
                cv = g_currentMission:getControlledVehicle()
            elseif g_currentMission.controlledVehicle then
                cv = g_currentMission.controlledVehicle
            end
        end
    end

    local camTarget = (cv and cv.spec_enterable and cv)
                   or (vehicle and vehicle.spec_enterable and vehicle)
                   or (combineVehicle and combineVehicle.spec_enterable and combineVehicle)

    if camTarget and camTarget.spec_enterable then
        RHMInputUtil.setCameraRotation(camTarget, false, self.savedCameraRotatableInfo)
        RHMInputUtil.setCameraZoom(camTarget, false, self.savedCameraZoomInfo)
    end

    self.activeVehicle = combineVehicle
    self.controllerVehicle = cv or vehicle or combineVehicle

    -- Validate active crop on the combine
    if combineVehicle and combineVehicle.spec_rhm_Combine and combineVehicle.spec_rhm_Combine.combineMemory then
        local mem = combineVehicle.spec_rhm_Combine.combineMemory
        local mType = combineVehicle.spec_rhm_Combine.machineType or "grain"
        local mapCrops = RHM_CombineSettingsDatabase:getCropNamesForMachineType(mType, combineVehicle)

        local isValidCrop = false
        local canonicalCurrent = RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(mem.currentCrop)
        if mem.currentCrop and mapCrops then
            for _, c in ipairs(mapCrops) do
                if c == mem.currentCrop or (canonicalCurrent and c == canonicalCurrent) then
                    mem.currentCrop = c
                    isValidCrop = true
                    break
                end
            end
            if not isValidCrop and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.cropAliases then
                local alias = RHM_CombineSettingsDatabase.cropAliases[mem.currentCrop]
                if alias then
                    local canonicalAlias = RHM_CombineSettingsDatabase:getCanonicalCropName(alias)
                    for _, c in ipairs(mapCrops) do
                        if c == alias or (canonicalAlias and c == canonicalAlias) then
                            mem.currentCrop = c
                            isValidCrop = true
                            break
                        end
                    end
                end
            end
        end

        if not isValidCrop and mapCrops and #mapCrops > 0 then
            local defaultCrop = mapCrops[1]
            local preferred = (mType == "grain" and "WHEAT")
                           or (mType == "root" and "POTATO")
                           or (mType == "forage" and "MAIZE_FORAGE")
                           or (mType == "cotton" and "COTTON")
                           or (mType == "grape" and "GRAPE")
                           or (mType == "olive" and "OLIVE")
            if preferred then
                for _, c in ipairs(mapCrops) do
                    if c == preferred then
                        defaultCrop = preferred
                        break
                    end
                end
            end
            mem.currentCrop = defaultCrop
            if combineVehicle.spec_rhm_Combine.loadCalculator then
                combineVehicle.spec_rhm_Combine.loadCalculator.currentCrop = defaultCrop
            end
        end
    end
end

function RHMCombineCalibrationGUI:close()
    if not self.isOpen then return end

    self.isOpen = false
    self.isCursorActive = false
    self.draggingSlider = nil

    -- Notify compatibility layer that calibration GUI has closed
    if RHM_ModCompatibility and RHM_ModCompatibility.onCalibrationGUIClosed then
        RHM_ModCompatibility.onCalibrationGUIClosed()
    end

    local vehicle = self.controllerVehicle or (g_realisticHarvestManager and g_realisticHarvestManager:getControlledVehicle()) or self.activeVehicle
    local camTarget = (vehicle and vehicle.spec_enterable and vehicle)
                   or (self.activeVehicle and self.activeVehicle.spec_enterable and self.activeVehicle)

    local otherSystemOwnsCursor = false
    if CpHud and CpHud.isHudActive then
        otherSystemOwnsCursor = true
    end
    if AutoDrive and AutoDrive.isEditorModeEnabled and AutoDrive:isEditorModeEnabled() then
        otherSystemOwnsCursor = true
    end
    if VehicleMouseCursor and VehicleMouseCursor._cursorOwned then
        otherSystemOwnsCursor = true
    end

    if not otherSystemOwnsCursor then
        g_inputBinding:setShowMouseCursor(false)
    end

    if camTarget and camTarget.spec_enterable then
        RHMInputUtil.setCameraRotation(camTarget, true, self.savedCameraRotatableInfo)
        RHMInputUtil.setCameraZoom(camTarget, true, self.savedCameraZoomInfo)
    end
    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}
end

function RHMCombineCalibrationGUI:cycleCrop(direction)
    local spec = self.activeVehicle.spec_rhm_Combine
    local machineType = spec.machineType or "grain"
    local crops = RHM_CombineSettingsDatabase:getCropNamesForMachineType(machineType, self.activeVehicle)
    if #crops == 0 then return end

    local current = spec.combineMemory.currentCrop
    local canonicalCurrent = RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(current)
    local index = 1

    if current then
        for i, name in ipairs(crops) do
            if name == current or (canonicalCurrent and name == canonicalCurrent) then
                index = i
                break
            end
        end
        if index == 1 and crops[1] ~= current and (not canonicalCurrent or crops[1] ~= canonicalCurrent) and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.cropAliases then
            local alias = RHM_CombineSettingsDatabase.cropAliases[current]
            if alias then
                local canonicalAlias = RHM_CombineSettingsDatabase:getCanonicalCropName(alias)
                for i, name in ipairs(crops) do
                    if name == alias or (canonicalAlias and name == canonicalAlias) then
                        index = i
                        break
                    end
                end
            end
        end
        index = index + direction
    else
        index = (direction > 0) and 1 or #crops
    end

    if index > #crops then index = 1 end
    if index < 1 then index = #crops end

    local newCrop = crops[index]
    spec.combineMemory:switchCrop(newCrop)
end

function RHMCombineCalibrationGUI:update(dt)
    if not self.isOpen then return end

    -- Keep mouse cursor explicitly visible while calibration GUI is open
    if g_inputBinding and g_inputBinding.setShowMouseCursor then
        g_inputBinding:setShowMouseCursor(true)
    end

    -- Keep camera rotation and translation blocked while GUI is open
    local vehicle = self.controllerVehicle or (g_realisticHarvestManager and g_realisticHarvestManager:getControlledVehicle()) or self.activeVehicle
    local camTarget = (vehicle and vehicle.spec_enterable and vehicle)
                   or (self.activeVehicle and self.activeVehicle.spec_enterable and self.activeVehicle)
    if camTarget and camTarget.spec_enterable and camTarget.spec_enterable.cameras then
        for _, camera in pairs(camTarget.spec_enterable.cameras) do
            camera.isRotatable = false
            camera.allowTranslation = false
        end
    end

    -- Suppress IC active controller while calibration GUI is open
    if g_currentMission and g_currentMission.interactiveControl then
        if g_currentMission.interactiveControl.activeController ~= nil then
            if type(g_currentMission.interactiveControl.setActiveInteractiveController) == "function" then
                g_currentMission.interactiveControl:setActiveInteractiveController(nil)
            end
        end
    end

    -- Keep VMC cursor overlay suppressed while calibration GUI is open
    if VehicleMouseCursor ~= nil and VehicleMouseCursor._cursorGui ~= nil then
        if VehicleMouseCursor._cursorGui.isOpen then
            VehicleMouseCursor._cursorGui.isOpen = false
        end
        VehicleMouseCursor._cursorOwned = false
    end

    if not self.activeVehicle then
        self:close()
        return
    end

    local vehicleToCheck = self.controllerVehicle or self.activeVehicle
    local isEntered = false

    if vehicleToCheck then
        local cv = nil
        if g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
            cv = g_realisticHarvestManager:getControlledVehicle()
        end
        if not cv then
            if g_localPlayer and g_localPlayer.getCurrentVehicle then
                cv = g_localPlayer:getCurrentVehicle()
            elseif g_currentMission then
                if g_currentMission.getControlledVehicle then
                    cv = g_currentMission:getControlledVehicle()
                elseif g_currentMission.controlledVehicle then
                    cv = g_currentMission.controlledVehicle
                end
            end
        end

        if cv then
            if cv == vehicleToCheck then
                isEntered = true
            else
                local rootA = cv.rootVehicle or cv
                local rootB = vehicleToCheck.rootVehicle or vehicleToCheck
                if rootA == rootB then
                    isEntered = true
                end
            end
        end

        if not isEntered and vehicleToCheck.getIsEntered then
            isEntered = vehicleToCheck:getIsEntered()
        end
        if not isEntered and vehicleToCheck.spec_enterable and vehicleToCheck.spec_enterable.isEntered then
            isEntered = true
        end
        if not isEntered and vehicleToCheck.getIsAIActive and vehicleToCheck:getIsAIActive() then
            if vehicleToCheck.isEntered or (vehicleToCheck.rootVehicle and vehicleToCheck.rootVehicle.isEntered) then
                isEntered = true
            end
        end
    end

    if not isEntered then
        self:close()
    end
end

function RHMCombineCalibrationGUI:draw()
    if not self.isOpen then return end
    if not (g_currentMission and g_currentMission.hud) then return end

    self.buttons = {}
    self.sliders = {}
    self.hoveredParameter = nil

    local ui = self.ui
    local spec = self.activeVehicle and self.activeVehicle.spec_rhm_Combine

    if spec and spec.combineMemory then
        local machineType = spec.machineType or "grain"
        local activeParams = RHM_CombineSettingsDatabase:getParamsForMachineType(machineType)
        local numParams = #activeParams + 1 -- +1 for targetEngineLoad

        local sectionsShown = 0
        for _, section in ipairs(SECTIONS_ORDERED) do
            for _, p in ipairs(activeParams) do
                if PARAM_SECTION_MAP[p] == section.key then
                    sectionsShown = sectionsShown + 1
                    break
                end
            end
        end
        sectionsShown = sectionsShown + 1 -- +1 for PERFORMANCE section

        local packageLevel = spec.packageLevel or 1
        local actualStatsHeight = (packageLevel >= 3) and (ui.statsHeight + ui.margin * 0.4) or 0

        local screenW = g_screenWidth or 1920
        local screenH = g_screenHeight or 1080
        local pixelW = 1.0 / screenW
        local pixelH = 1.0 / screenH

        local bezelSide = math.max(4 * pixelW, 0.0025)
        local bezelBottom = math.max(4 * pixelH, 0.0038)
        local bezelTop = math.max(4 * pixelH, 0.0038)
        ui.bezelSide = bezelSide
        ui.bezelBottom = bezelBottom
        ui.bezelTop = bezelTop

        local dynamicH = ui.headerHeight
                       + actualStatsHeight
                       + ui.lineHeight + 0.004 -- crop row
                       + (sectionsShown * ui.sectionGap)
                       + (numParams * ui.lineHeight)
                       + (ui.lineHeight * 2.1) -- action buttons
                       + ui.margin * 3.0

        ui.h = dynamicH + bezelBottom + bezelTop
        if not self.hasCustomPosition then
            -- EN: Cleanly offset below the base game top-right clock/money bar (bar bottom ≈ 0.920).
            --     Leaves ~40px breathing margin from the top HUD and ~70px above the speedometer.
            -- UA: Чистий відступ нижче верхньої смуги годинника/грошей базової гри (низ смуги ≈ 0.920).
            --     Залишає ~40px відступу від верхнього HUD та ~70px над спідометром.
            local topY = 0.880
            ui.y = topY - ui.h
            ui.x = 1.0 - ui.w - 0.016
        end
    else
        local screenW = g_screenWidth or 1920
        local screenH = g_screenHeight or 1080
        local pixelW = 1.0 / screenW
        local pixelH = 1.0 / screenH
        local bezelSide = math.max(4 * pixelW, 0.0025)
        local bezelBottom = math.max(4 * pixelH, 0.0038)
        local bezelTop = math.max(4 * pixelH, 0.0038)
        ui.bezelSide = bezelSide
        ui.bezelBottom = bezelBottom
        ui.bezelTop = bezelTop

        ui.h = 0.50 + bezelBottom + bezelTop
        if not self.hasCustomPosition then
            ui.y = 0.38
            ui.x = 1.0 - ui.w - 0.016
        end
    end

    local tabletX, tabletY = ui.x, ui.y
    local tabletW, tabletH = ui.w, ui.h

    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local pixelW = 1.0 / screenW
    local pixelH = 1.0 / screenH

    -- Inner Display Bounds (The glass screen inside the sleek bezel)
    local x = tabletX + (ui.bezelSide or 0.0025)
    local y = tabletY + (ui.bezelBottom or 0.0038)
    local w = tabletW - ((ui.bezelSide or 0.0025) * 2)
    local h = tabletH - (ui.bezelBottom or 0.0038) - (ui.bezelTop or 0.0038)

    -- ── 1. Outer Tablet Chassis (Sleek Minimalist Bezel - Clean, No Camera/LED) ──
    local caseBg = {0.045, 0.048, 0.054, 0.98} -- Premium dark matte chassis
    self:drawPanelBackground(tabletX, tabletY, tabletW, tabletH, caseBg)
    self:drawBorder(tabletX, tabletY, tabletW, tabletH, {0.16, 0.18, 0.22, 0.60}, 1)

    -- ── 2. Inner Recessed Touchscreen Display Glass (Smoked Acrylic & Edge Refraction) ──
    self:drawPanelBackground(x, y, w, h, ui.colors.bg)

    -- Glass Refraction Edge Highlights & Sub-surface Chamfer
    self:drawRect(x + pixelW, y + h - pixelH, w - 2 * pixelW, pixelH, {1.0, 1.0, 1.0, 0.22}) -- Top specular rim
    self:drawRect(x, y + pixelH, pixelW, h - 2 * pixelH, {1.0, 1.0, 1.0, 0.12})              -- Left ambient rim
    self:drawRect(x + w - pixelW, y, pixelW, h, {0.0, 0.0, 0.0, 0.50})                       -- Right inner bezel shadow
    self:drawRect(x, y, w, pixelH, {0.0, 0.0, 0.0, 0.65})                                    -- Bottom inner bezel shadow
    self:drawBorder(x + 1.5 * pixelW, y + 1.5 * pixelH, w - 3 * pixelW, h - 3 * pixelH, {1.0, 1.0, 1.0, 0.04}, 1) -- Sub-surface glass thickness

    -- ── Terminal Status Header (Inside Display) ──────────────────────────────
    local headerY = y + h - ui.headerHeight
    self:drawRect(x, headerY, w, ui.headerHeight, ui.colors.header)
    self:drawRect(x, headerY, w, 1.5 * pixelH, ui.colors.headerAccent)

    -- Tier Badge
    local packageLevel = (spec and spec.packageLevel) or 1
    local tierConfigs = {
        [1] = { label = g_i18n:hasText("rhm_ui_tier1_manual") and g_i18n:getText("rhm_ui_tier1_manual") or "TIER 1 - MANUAL",  bg = {0.08, 0.09, 0.10, 0.85}, border = {1.0, 1.0, 1.0, 0.12}, text = {0.70, 0.72, 0.76, 1.0} },
        [2] = { label = g_i18n:hasText("rhm_ui_tier2_sensors") and g_i18n:getText("rhm_ui_tier2_sensors") or "TIER 2 - SENSORS", bg = {0.12, 0.10, 0.04, 0.85}, border = {0.95, 0.72, 0.18, 0.60}, text = {0.95, 0.72, 0.18, 1.0} },
        [3] = { label = g_i18n:hasText("rhm_ui_tier3_monitor") and g_i18n:getText("rhm_ui_tier3_monitor") or "TIER 3 - MONITOR", bg = {0.08, 0.12, 0.04, 0.85}, border = {0.529, 0.706, 0.0, 0.60}, text = {0.529, 0.706, 0.0, 1.0} },
        [4] = { label = g_i18n:hasText("rhm_ui_tier4_opti") and g_i18n:getText("rhm_ui_tier4_opti") or "TIER 4 - AI OPTI", bg = {0.05, 0.06, 0.07, 0.90}, border = {0.529, 0.706, 0.0, 0.80}, text = {1.0, 1.0, 1.0, 1.0} }
    }
    local tier = tierConfigs[math.min(4, math.max(1, packageLevel))] or tierConfigs[1]

    local badgeW = 0.058
    local badgeH = 0.018
    local badgeX = x + ui.margin
    local badgeY = headerY + (ui.headerHeight - badgeH) * 0.5
    self:drawRect(badgeX, badgeY, badgeW, badgeH, tier.bg)
    self:drawBorder(badgeX, badgeY, badgeW, badgeH, tier.border or tier.text, 1)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(unpack(tier.text))
    renderText(badgeX + badgeW * 0.5, badgeY + badgeH * 0.25, ui.fontSize * 0.68, tier.label)

    local isArcade = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.difficultyMotor == 1)
    local nextHeaderBadgeX = badgeX + badgeW
    if isArcade then
        local arcadeW = 0.046
        local arcadeX = badgeX + badgeW + 0.004
        self:drawRect(arcadeX, badgeY, arcadeW, badgeH, {0.05, 0.12, 0.04, 0.85})
        self:drawBorder(arcadeX, badgeY, arcadeW, badgeH, {0.529, 0.706, 0.0, 0.80}, 1)
        local arcadeLabel = g_i18n:hasText("rhm_ui_arcade_badge") and g_i18n:getText("rhm_ui_arcade_badge") or "ARCADE"
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(0.529, 0.706, 0.0, 1.0)
        renderText(arcadeX + arcadeW * 0.5, badgeY + badgeH * 0.25, ui.fontSize * 0.68, arcadeLabel)
        nextHeaderBadgeX = arcadeX + arcadeW
    end

    -- Close Button [X] (Top Right)
    local closeBtnW = 0.018
    local closeBtnH = 0.018
    local closeBtnX = x + w - ui.margin - closeBtnW
    local closeBtnY = headerY + (ui.headerHeight - closeBtnH) * 0.5
    self:drawButton(closeBtnX, closeBtnY, closeBtnW, closeBtnH, "X", function()
        self:close()
    end)

    -- Cutter Working Width Telemetry
    local v = self.activeVehicle
    local cutterWidth = 0

    local function resolveCutterWidth(obj)
        if not obj then return 0 end
        local w = 0
        if obj.getWorkingWidth then
            local raw = obj:getWorkingWidth()
            if raw and tonumber(raw) and tonumber(raw) > 0 then
                w = tonumber(raw)
            end
        end
        if w == 0 and obj.spec_cutter and obj.spec_cutter.workingWidth then
            local raw = obj.spec_cutter.workingWidth
            if raw and tonumber(raw) and tonumber(raw) > 0 then
                w = tonumber(raw)
            end
        end
        if w == 0 and obj.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
            local item = g_storeManager:getItemByXMLFilename(obj.configFileName)
            if item and item.specs and item.specs.workingWidth then
                local rawW = tostring(item.specs.workingWidth)
                local parsed = tonumber(string.match(rawW, "%d+%.?%d*"))
                if parsed and parsed > 0 then
                    w = parsed
                end
            end
        end
        if w == 0 and obj.xmlFile and obj.xmlFile.getValue then
            local rawW = obj.xmlFile:getValue("vehicle.storeData.specs.workingWidth")
            if rawW then
                local parsed = tonumber(string.match(tostring(rawW), "%d+%.?%d*"))
                if parsed and parsed > 0 then
                    w = parsed
                end
            end
        end
        if w == 0 and obj.spec_workArea and obj.spec_workArea.workAreas then
            for _, wa in pairs(obj.spec_workArea.workAreas) do
                if wa.start and wa.width then
                    local sx, _, sz = getWorldTranslation(wa.start)
                    local wx, _, wz = getWorldTranslation(wa.width)
                    local areaWidth = MathUtil.vector2Length(wx - sx, wz - sz)
                    if areaWidth > w then w = areaWidth end
                end
            end
        end
        return w
    end

    if spec and spec.loadCalculator and spec.loadCalculator.lastHeaderWidth and spec.loadCalculator.lastHeaderWidth > 0 then
        cutterWidth = spec.loadCalculator.lastHeaderWidth
    end

    if cutterWidth == 0 and v and v.spec_combine and v.spec_combine.attachedCutters then
        for cutter, _ in pairs(v.spec_combine.attachedCutters) do
            local cw = resolveCutterWidth(cutter)
            if cw > cutterWidth then cutterWidth = cw end
        end
    end

    if cutterWidth == 0 and v and v.getAttachedImplements then
        for _, imp in pairs(v:getAttachedImplements()) do
            local obj = imp.object
            if obj then
                local cw = resolveCutterWidth(obj)
                if cw > cutterWidth then cutterWidth = cw end
                if obj.getAttachedImplements then
                    for _, subImp in pairs(obj:getAttachedImplements()) do
                        local subObj = subImp.object
                        if subObj then
                            local subCw = resolveCutterWidth(subObj)
                            if subCw > cutterWidth then cutterWidth = subCw end
                        end
                    end
                end
            end
        end
    end

    if cutterWidth == 0 and v and (v.spec_cutter ~= nil or v.spec_forageCutter ~= nil) then
        cutterWidth = resolveCutterWidth(v)
    end

    local widthStr = (cutterWidth and cutterWidth > 0) and string.format("%.1f m", cutterWidth) or "—"

    -- Engine Horsepower Telemetry
    local engineHp = nil
    if v and v._rhm_engineHp and v._rhm_engineHp > 0 then
        engineHp = v._rhm_engineHp
    elseif spec and spec.loadCalculator and spec.loadCalculator.getEnginePowerHp then
        engineHp = spec.loadCalculator:getEnginePowerHp(v)
    end
    if not engineHp and v then
        local motorObj = v
        if not (v.spec_motorized and v.spec_motorized.motor) then
            local root = v.rootVehicle or (v.getRootVehicle and v:getRootVehicle())
            if root and root.spec_motorized and root.spec_motorized.motor then
                motorObj = root
            else
                local attacher = v.attacherVehicle or (v.getAttacherVehicle and v:getAttacherVehicle())
                if attacher and attacher.spec_motorized and attacher.spec_motorized.motor then
                    motorObj = attacher
                end
            end
        end
        if motorObj and motorObj.spec_motorized and motorObj.spec_motorized.motor then
            local motor = motorObj.spec_motorized.motor
            if motor.maxMotorPower and tonumber(motor.maxMotorPower) and tonumber(motor.maxMotorPower) > 0 then
                engineHp = tonumber(motor.maxMotorPower) * 1.35962
            elseif motor.peakMotorPower and tonumber(motor.peakMotorPower) and tonumber(motor.peakMotorPower) > 0 then
                engineHp = tonumber(motor.peakMotorPower) * 1.35962
            elseif motor.getHp then
                engineHp = motor:getHp()
            end
        end
    end
    local hpStr = engineHp and string.format("%.0f HP", engineHp) or "—"

    -- Telemetry Badges (Cutter Width & Horsepower)
    local infoCapsuleH = 0.018
    local infoCapsuleY = headerY + (ui.headerHeight - infoCapsuleH) * 0.5

    -- 1. Cutter Width Capsule
    local cwBoxW = 0.046
    local cwBoxX = closeBtnX - 0.005 - cwBoxW
    self:drawRect(cwBoxX, infoCapsuleY, cwBoxW, infoCapsuleH, {0.02, 0.025, 0.03, 0.85})
    self:drawBorder(cwBoxX, infoCapsuleY, cwBoxW, infoCapsuleH, {0.529, 0.706, 0.0, 0.50}, 1)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(0.529, 0.706, 0.0, 1.0)
    renderText(cwBoxX + cwBoxW * 0.5, infoCapsuleY + 0.004, ui.fontSize * 0.82, widthStr)

    -- 2. Engine HP Capsule
    local hpBoxW = 0.048
    local hpBoxX = cwBoxX - 0.004 - hpBoxW
    self:drawRect(hpBoxX, infoCapsuleY, hpBoxW, infoCapsuleH, {0.02, 0.025, 0.03, 0.85})
    self:drawBorder(hpBoxX, infoCapsuleY, hpBoxW, infoCapsuleH, {0.95, 0.72, 0.18, 0.50}, 1)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(0.95, 0.72, 0.18, 1.0)
    renderText(hpBoxX + hpBoxW * 0.5, infoCapsuleY + 0.004, ui.fontSize * 0.82, hpStr)

    -- Full Machine Name: Brand + Model (Positioned between Tier badge and HP capsule)
    local fullVehicleName = nil
    if v and v.getFullName then
        fullVehicleName = v:getFullName()
    end
    if not fullVehicleName or fullVehicleName == "" then
        local brandName = ""
        local brandIndex = (v and v.getBrand and v:getBrand()) or (v and v.brand)
        if brandIndex and g_brandManager and g_brandManager.getBrandByIndex then
            local b = g_brandManager:getBrandByIndex(brandIndex)
            if b and b.title then brandName = b.title end
        elseif v and v.getBrandName then
            brandName = v:getBrandName() or ""
        end
        local rawModel = v and v:getName() or "COMBINE"
        if brandName ~= "" and not rawModel:upper():find(brandName:upper(), 1, true) then
            fullVehicleName = brandName .. " " .. rawModel
        else
            fullVehicleName = rawModel
        end
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(unpack(ui.colors.text))
    local titleX = (nextHeaderBadgeX or (badgeX + badgeW)) + 0.007
    local maxTitleW = hpBoxX - titleX - 0.006
    local titleSize = ui.titleSize
    local fullUpper = string.upper(fullVehicleName)
    local textW = getTextWidth(titleSize, fullUpper)
    if textW and textW > maxTitleW and textW > 0 then
        titleSize = math.max(ui.fontSize * 0.85, titleSize * (maxTitleW / textW))
    end
    renderText(titleX, headerY + ui.headerHeight * 0.32, titleSize, fullUpper)

    local cy = headerY - ui.margin * 0.5

    local memory = spec and spec.combineMemory
    if not memory and self.activeVehicle and rhm_Combine and rhm_Combine.getOrInitCombineMemory then
        memory = rhm_Combine.getOrInitCombineMemory(self.activeVehicle)
    end

    if not self.activeVehicle or not spec or not memory then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(unpack(ui.colors.textDim))
        local notInitText = g_i18n:hasText("rhm_ui_combine_not_init") and g_i18n:getText("rhm_ui_combine_not_init") or "Combine not initialized"
        renderText(x + w * 0.5, cy - ui.lineHeight, ui.fontSize, notInitText)
        self:_resetTextState()
        return
    end

    local machineType = spec.machineType or (memory and memory.machineType) or "grain"

    -- ── Tier 3+ Live Telemetry Cards ────────────────────────────────────────
    if packageLevel >= 3 then
        cy = cy - ui.statsHeight
        local cardGap = 0.004
        local innerW = w - ui.margin * 2
        local cardW = (innerW - cardGap * 2) / 3
        local cardH = ui.statsHeight
        local startX = x + ui.margin

        local load = (spec.loadCalculator and spec.loadCalculator.engineLoad or 0) * 100
        local effPenalty = 0
        local lossPenalty = 0
        if memory.currentCrop then
            local context = self:getHarvestContext(machineType)
            effPenalty, lossPenalty, _ = memory:checkSettingsForCrop(memory.currentCrop, context)
        end
        local isArcadeMotor = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.difficultyMotor == 1)
        local isArcadeLoss = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.difficultyLoss == 1)
        if isArcadeMotor then
            effPenalty = 0
        end
        if isArcadeLoss then
            lossPenalty = 0
        end
        local isForage = (machineType == "forage")

        -- Card 1: Engine Load
        local cx1 = startX
        self:drawRect(cx1, cy, cardW, cardH, ui.colors.statsCardBg)
        self:drawBorder(cx1, cy, cardW, cardH, ui.colors.statsCardBorder, 1)
        local loadColor = (load > 95) and ui.colors.error or ((load > 80) and ui.colors.warning or ui.colors.success)
        local cardLoadText = g_i18n:hasText("rhm_ui_card_engine_load") and g_i18n:getText("rhm_ui_card_engine_load") or "ENGINE LOAD"
        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(unpack(ui.colors.textDim))
        renderText(cx1 + cardW * 0.5, cy + cardH * 0.56, ui.statusSize * 0.85, cardLoadText)
        setTextColor(unpack(loadColor))
        renderText(cx1 + cardW * 0.5, cy + cardH * 0.14, ui.fontSize, string.format("%.0f%%", load))

        -- Card 2: Speed Efficiency
        local cx2 = cx1 + cardW + cardGap
        self:drawRect(cx2, cy, cardW, cardH, ui.colors.statsCardBg)
        self:drawBorder(cx2, cy, cardW, cardH, ui.colors.statsCardBorder, 1)
        local speedVal = math.max(0, effPenalty)
        local speedColor = (speedVal <= 0.05) and ui.colors.success or ((speedVal <= 2.0) and ui.colors.warning or ui.colors.error)
        local speedPrefix = (speedVal <= 0.05) and "" or "-"
        local cardEffText = g_i18n:hasText("rhm_ui_card_efficiency") and g_i18n:getText("rhm_ui_card_efficiency") or "EFFICIENCY"
        setTextColor(unpack(ui.colors.textDim))
        renderText(cx2 + cardW * 0.5, cy + cardH * 0.56, ui.statusSize * 0.85, cardEffText)
        setTextColor(unpack(speedColor))
        renderText(cx2 + cardW * 0.5, cy + cardH * 0.14, ui.fontSize, string.format("%s%.1f%%", speedPrefix, speedVal))

        -- Card 3: Predicted Loss
        local cx3 = cx2 + cardW + cardGap
        self:drawRect(cx3, cy, cardW, cardH, ui.colors.statsCardBg)
        self:drawBorder(cx3, cy, cardW, cardH, ui.colors.statsCardBorder, 1)
        local cardLossText = g_i18n:hasText("rhm_ui_card_predicted_loss") and g_i18n:getText("rhm_ui_card_predicted_loss") or "PREDICTED LOSS"
        setTextColor(unpack(ui.colors.textDim))
        renderText(cx3 + cardW * 0.5, cy + cardH * 0.56, ui.statusSize * 0.85, cardLossText)
        if isForage then
            setTextColor(unpack(ui.colors.textDim))
            renderText(cx3 + cardW * 0.5, cy + cardH * 0.14, ui.fontSize, "N/A")
        else
            local settingsLoss = math.max(0, lossPenalty)
            local wearLoss = (spec.loadCalculator and spec.loadCalculator.totalWearLoss) or 0
            local isWearEnabled = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableWearLoss ~= false)
            if not isWearEnabled or isArcadeLoss then
                wearLoss = 0
            end
            local displayLoss = settingsLoss + wearLoss
            local lossColor = (displayLoss <= 0.05) and ui.colors.success or ((displayLoss <= 2.0) and ui.colors.warning or ui.colors.error)
            setTextColor(unpack(lossColor))
            if wearLoss > 0.05 then
                renderText(cx3 + cardW * 0.5, cy + cardH * 0.22, ui.fontSize * 0.90, string.format("%.1f%%", displayLoss))
                local wearLabel = g_i18n:hasText("rhm_ui_wear_loss") and g_i18n:getText("rhm_ui_wear_loss") or "Wear"
                setTextColor(unpack(ui.colors.warning))
                renderText(cx3 + cardW * 0.5, cy + cardH * 0.06, ui.statusSize * 0.85, string.format("+%.1f%% %s", wearLoss, wearLabel))
            else
                renderText(cx3 + cardW * 0.5, cy + cardH * 0.14, ui.fontSize, string.format("%.1f%%", displayLoss))
            end
        end

        setTextBold(false)
        cy = cy - ui.margin * 0.4
    end

    -- ── Crop Selector & Auto Calibration Row ────────────────────────────────
    cy = cy - ui.lineHeight - 0.002

    local function getLocalizedCropName(rawName)
        if not rawName then return "NONE" end
        if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
            return RHM_CombineSettingsDatabase:getCropDisplayName(rawName)
        end
        return rawName
    end

    -- [<] CROP NAME [>]
    local cropNavX = x + ui.margin
    local arrowW = 0.020
    self:drawButton(cropNavX, cy + 0.004, arrowW, ui.buttonH + 0.004, "<", function()
        self:cycleCrop(-1)
    end)

    local cropName = getLocalizedCropName(memory.currentCrop)
    local cropBoxW = 0.135
    local cropBoxX = cropNavX + arrowW + 0.004
    self:drawRect(cropBoxX, cy + 0.004, cropBoxW, ui.buttonH + 0.004, {0.0, 0.0, 0.0, 0.50})
    self:drawBorder(cropBoxX, cy + 0.004, cropBoxW, ui.buttonH + 0.004, {1.0, 1.0, 1.0, 0.12}, 1)
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(ui.colors.text))
    renderText(cropBoxX + cropBoxW * 0.5, cy + 0.009, ui.fontSize, cropName)
    setTextBold(false)

    self:drawButton(cropBoxX + cropBoxW + 0.004, cy + 0.004, arrowW, ui.buttonH + 0.004, ">", function()
        self:cycleCrop(1)
    end)

    -- AUTO Calibration Button
    local autoBtnW = 0.115
    local autoBtnX = x + w - ui.margin - autoBtnW
    local autoBtnH = ui.buttonH + 0.004

    if packageLevel >= 4 then
        local btnAutoText = g_i18n:hasText("rhm_ui_btn_ai_auto") and g_i18n:getText("rhm_ui_btn_ai_auto") or "AI AUTO-CALIB"
        self:drawButton(autoBtnX, cy + 0.004, autoBtnW, autoBtnH, btnAutoText, function()
            memory:requestAutoSettings()
        end, ui.colors.buttonAuto, ui.colors.buttonAutoBorder)
    else
        self:drawRect(autoBtnX, cy + 0.004, autoBtnW, autoBtnH, {0.05, 0.055, 0.065, 0.85})
        self:drawBorder(autoBtnX, cy + 0.004, autoBtnW, autoBtnH, {1.0, 1.0, 1.0, 0.10}, 1)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(0.40, 0.42, 0.46, 1.0)
        local btnLockedText = g_i18n:hasText("rhm_ui_btn_auto_locked") and g_i18n:getText("rhm_ui_btn_auto_locked") or "AUTO (LOCKED)"
        renderText(autoBtnX + autoBtnW * 0.5, cy + 0.009, ui.fontSize * 0.78, btnLockedText)
        setTextBold(false)

        table.insert(self.buttons, {
            x = autoBtnX, y = cy + 0.004, w = autoBtnW, h = autoBtnH,
            callback = function()
                local msg = g_i18n:hasText("rhm_msg_req_tier4") and g_i18n:getText("rhm_msg_req_tier4") or "Requires Opti-Harvest AI (Tier 4)"
                if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                    RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
                elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                    g_currentMission.hud:showInGameMessage("Realistic Harvesting", msg, -1)
                end
            end
        })
    end

    self:drawRect(x + ui.margin, cy - 0.004, w - ui.margin * 2, pixelH, ui.colors.separator)
    cy = cy - ui.margin * 0.3

    -- ── Parameter Sections ──────────────────────────────────────────────────
    local activeParams = RHM_CombineSettingsDatabase:getParamsForMachineType(machineType)
    local drawnParams = {}

    for _, section in ipairs(SECTIONS_ORDERED) do
        local hasAny = false
        for _, p in ipairs(activeParams) do
            if PARAM_SECTION_MAP[p] == section.key then
                hasAny = true
                break
            end
        end

        if hasAny then
            cy = cy - ui.sectionGap
            local secW = w - ui.margin * 2
            local secH = ui.sectionGap - 0.004
            self:drawRect(x + ui.margin, cy + 0.002, secW, secH, ui.colors.sectionBg)
            self:drawRect(x + ui.margin, cy + 0.002, 0.0025, secH, ui.colors.sectionNotch)

            setTextBold(true)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextColor(unpack(ui.colors.text))
            local sLabel = g_i18n:hasText(section.label) and g_i18n:getText(section.label) or section.key
            renderText(x + ui.margin + 0.006, cy + 0.006, ui.sectionSize, sLabel)

            for _, p in ipairs(activeParams) do
                if PARAM_SECTION_MAP[p] == section.key and not drawnParams[p] then
                    cy = cy - ui.lineHeight
                    local labelKey = RHM_CombineSettingsDatabase:getParamLabel(machineType, p)
                    local label = g_i18n:hasText(labelKey) and g_i18n:getText(labelKey) or p
                    self:drawParameterRow(x + ui.margin, cy, secW, p, label, memory, ui, machineType, packageLevel)
                    drawnParams[p] = true
                end
            end
        end
    end

    -- PERFORMANCE Section
    cy = cy - ui.sectionGap
    local secW = w - ui.margin * 2
    local secH = ui.sectionGap - 0.004
    self:drawRect(x + ui.margin, cy + 0.002, secW, secH, ui.colors.sectionBg)
    self:drawRect(x + ui.margin, cy + 0.002, 0.0025, secH, ui.colors.sectionNotch)
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.text))
    local perfLabel = g_i18n:hasText("rhm_ui_section_performance") and g_i18n:getText("rhm_ui_section_performance") or "PERFORMANCE"
    renderText(x + ui.margin + 0.006, cy + 0.006, ui.sectionSize, perfLabel)

    for _, p in ipairs(activeParams) do
        if not drawnParams[p] then
            cy = cy - ui.lineHeight
            local labelKey = RHM_CombineSettingsDatabase:getParamLabel(machineType, p)
            local label = g_i18n:hasText(labelKey) and g_i18n:getText(labelKey) or p
            self:drawParameterRow(x + ui.margin, cy, secW, p, label, memory, ui, machineType, packageLevel)
            drawnParams[p] = true
        end
    end

    cy = cy - ui.lineHeight
    local loadLabel = g_i18n:hasText("rhm_target_load") and g_i18n:getText("rhm_target_load") or "Target Engine Load"
    self:drawParameterRow(x + ui.margin, cy, secW, "targetEngineLoad", loadLabel, memory, ui, machineType, packageLevel)

    cy = cy - ui.margin * 0.8
    self:drawRect(x + ui.margin, cy, w - ui.margin * 2, pixelH, ui.colors.separator)
    cy = cy - ui.margin * 0.6

    -- ── Action Buttons ──────────────────────────────────────────────────────
    cy = cy - ui.lineHeight * 1.0
    local actionBtnW = (w - ui.margin * 2.5) / 2

    if packageLevel >= 2 then
        local btnLoadText = g_i18n:hasText("rhm_ui_btn_load_preset") and g_i18n:getText("rhm_ui_btn_load_preset") or "LOAD PRESET"
        self:drawButton(x + ui.margin, cy, actionBtnW, 0.026, btnLoadText, function()
            local success = memory:loadUserPreset()
            local msg = ""
            if success then
                local cropTitle = memory.currentCrop
                if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
                    cropTitle = RHM_CombineSettingsDatabase:getCropDisplayName(memory.currentCrop)
                end
                local formatStr = g_i18n:hasText("rhm_msg_profile_loaded") and g_i18n:getText("rhm_msg_profile_loaded") or "Loaded Profile: %s"
                msg = string.format(formatStr, tostring(cropTitle))
            else
                msg = g_i18n:hasText("rhm_msg_profile_not_found") and g_i18n:getText("rhm_msg_profile_not_found") or "No saved profile found for this crop"
            end
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
            elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                g_currentMission.hud:showInGameMessage("Realistic Harvesting", msg, -1)
            end
        end)

        local btnSaveText = g_i18n:hasText("rhm_ui_btn_save_profile") and g_i18n:getText("rhm_ui_btn_save_profile") or "SAVE PROFILE"
        self:drawButton(x + w - ui.margin - actionBtnW, cy, actionBtnW, 0.026, btnSaveText, function()
            local success = memory:saveCurrentProfile(memory.currentCrop)
            if success then
                local cropTitle = memory.currentCrop
                if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
                    cropTitle = RHM_CombineSettingsDatabase:getCropDisplayName(memory.currentCrop)
                end
                local formatStr = g_i18n:hasText("rhm_msg_profile_saved") and g_i18n:getText("rhm_msg_profile_saved") or "Saved Profile: %s"
                local msg = string.format(formatStr, tostring(cropTitle))
                if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                    RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
                elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                    g_currentMission.hud:showInGameMessage("Realistic Harvesting", msg, -1)
                end
            end
        end)
    else
        local btnLoadLockText = g_i18n:hasText("rhm_ui_btn_load_locked") and g_i18n:getText("rhm_ui_btn_load_locked") or "LOAD (LOCKED)"
        self:drawButton(x + ui.margin, cy, actionBtnW, 0.026, btnLoadLockText, function()
            local msg = (g_i18n:hasText("rhm_msg_req_tier2") and g_i18n:getText("rhm_msg_req_tier2"))
                     or (g_i18n:hasText("rhm_msg_req_tier3") and g_i18n:getText("rhm_msg_req_tier3"))
                     or "Profiles require Sensors Package (Tier 2)"
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
            elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                g_currentMission.hud:showInGameMessage("Realistic Harvesting", msg, -1)
            end
        end, {0.04, 0.04, 0.05, 0.45}, {1.0, 1.0, 1.0, 0.06})

        local btnSaveLockText = g_i18n:hasText("rhm_ui_btn_save_locked") and g_i18n:getText("rhm_ui_btn_save_locked") or "SAVE (LOCKED)"
        self:drawButton(x + w - ui.margin - actionBtnW, cy, actionBtnW, 0.026, btnSaveLockText, function()
            local msg = (g_i18n:hasText("rhm_msg_req_tier2") and g_i18n:getText("rhm_msg_req_tier2"))
                     or (g_i18n:hasText("rhm_msg_req_tier3") and g_i18n:getText("rhm_msg_req_tier3"))
                     or "Profiles require Sensors Package (Tier 2)"
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
            elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                g_currentMission.hud:showInGameMessage("Realistic Harvesting", msg, -1)
            end
        end, {0.04, 0.04, 0.05, 0.45}, {1.0, 1.0, 1.0, 0.06})
    end

    cy = cy - ui.lineHeight * 1.0
    local resetBtnW = w - ui.margin * 2
    local resetBtnText = g_i18n:hasText("rhm_ui_btn_reset_defaults") and g_i18n:getText("rhm_ui_btn_reset_defaults") or "RESET TO FACTORY DEFAULTS"
    self:drawButton(x + ui.margin, cy, resetBtnW, 0.026, resetBtnText, function()
        memory:requestResetSettings()
    end, ui.colors.buttonReset, ui.colors.buttonResetBorder)

    -- ── Scroll Wheel Handling ───────────────────────────────────────────────
    if self.lastScrollTimeStamp + self.scrollDelayMs < g_time then
        local mx, my = g_inputBinding:getMousePosition()
        if mx and my and mx >= ui.x and mx <= ui.x + ui.w and my >= ui.y and my <= ui.y + ui.h then
            if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
                self.lastScrollTimeStamp = g_time
                self:handleWheelScroll(1, mx, my)
            elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
                self.lastScrollTimeStamp = g_time
                self:handleWheelScroll(-1, mx, my)
            end
        end
    end

    self:_resetTextState()
end

---EN: Draws an interactive parameter row with direct track slider and [-][+] micro-buttons.
---UA: Малює інтерактивний рядок параметра з прямим трек-слайдером та мікро-кнопками [-][+].
function RHMCombineCalibrationGUI:drawParameterRow(x, y, w, param, label, memory, ui, machineType, packageLevel)
    local val = memory.currentSettings[param] or 0
    local optimal = 0
    local tolerance = 5
    local isOptimal = false
    local hasOptimal = false

    local isRowHovered = self:checkHover(x, y - 0.003, w, ui.lineHeight)
    if isRowHovered then
        self:drawRect(x, y - 0.003, w, ui.lineHeight, ui.colors.paramRowHover)
        self.hoveredParameter = param
    end

    -- Query optimal value from DB
    if RHM_CombineSettingsDatabase and memory.currentCrop then
        local context = self:getHarvestContext(machineType)
        local settings = RHM_CombineSettingsDatabase:getSettingsForCrop(memory.currentCrop, context)
        if settings and settings[param] then
            optimal = settings[param].optimal
            tolerance = settings[param].tolerance or 5
            isOptimal = math.abs(val - optimal) <= tolerance
            hasOptimal = true
        end
    end

    -- Format physical value
    local displayStr = ""
    if RHM_UnitConverter and RHM_UnitConverter.formatSetting then
        displayStr = RHM_UnitConverter.formatSetting(param, val, machineType)
    else
        displayStr = string.format("%d%%", val)
    end

    -- Proportions (Grid Column System with dedicated Telemetry Capsule)
    local labelW       = 0.100
    local valBoxW      = 0.046
    local pillW        = 0.054
    local pillH        = 0.016
    local sliderW      = 0.108
    local microBtnW    = 0.015
    local microBtnH    = 0.016

    local valBoxX      = x + labelW
    local pillX        = valBoxX + valBoxW + 0.005
    local sliderStartX = pillX + pillW + 0.007
    local btnStartX    = sliderStartX + sliderW + 0.006

    -- Determine colors & status text based on Tier progression
    local valColor = ui.colors.text
    local statusText = ""
    local statusColor = {1.0, 1.0, 1.0, 1.0} -- Pure crisp white text (Option 1A)
    local pillBg = {0.0, 0.0, 0.0, 0.55} -- Dark translucent glass
    local pillBorder = {1.0, 1.0, 1.0, 0.12}
    local fillColor = ui.colors.trackFill

    if packageLevel >= 2 and hasOptimal and param ~= "targetEngineLoad" then
        pillBg = {0.0, 0.0, 0.0, 0.55}
        if isOptimal then
            valColor = ui.colors.success
            statusText = g_i18n:hasText("rhm_ui_status_optimal") and g_i18n:getText("rhm_ui_status_optimal") or "OPTIMAL"
            statusColor = {1.0, 1.0, 1.0, 1.0}
            pillBorder = {0.529, 0.706, 0.0, 0.80} -- Authentic game HUD green border
            fillColor = ui.colors.trackFill
        else
            local deviation = math.abs(val - optimal) - tolerance
            if deviation > 20 then
                valColor = ui.colors.error
                statusColor = {1.0, 1.0, 1.0, 1.0}
                pillBorder = {0.90, 0.24, 0.24, 0.80} -- Restrained alert red border
                fillColor = ui.colors.trackFillErr
            else
                valColor = ui.colors.warning
                statusColor = {1.0, 1.0, 1.0, 1.0}
                pillBorder = {0.95, 0.72, 0.18, 0.80} -- Warm amber border
                fillColor = ui.colors.trackFillWarn
            end
            local lowText = g_i18n:hasText("rhm_ui_status_low") and g_i18n:getText("rhm_ui_status_low") or "LOW"
            local highText = g_i18n:hasText("rhm_ui_status_high") and g_i18n:getText("rhm_ui_status_high") or "HIGH"
            statusText = (val < optimal) and lowText or highText
        end
    else
        valColor = ui.colors.text
        statusText = ""
        fillColor = {0.45, 0.48, 0.52, 0.85}
        hasOptimal = false
    end

    -- ── Label ──────────────────────────────────────────────────────────────
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.text))
    renderText(x + 0.002, y + 0.012, ui.fontSize, label)

    -- ── Physical Value in Recessed Dark Box ────────────────────────────────
    local valBoxH = 0.018
    local valBoxY = y + (ui.lineHeight - valBoxH) * 0.5
    self:drawRect(valBoxX, valBoxY, valBoxW, valBoxH, {0.018, 0.020, 0.024, 0.90})
    self:drawBorder(valBoxX, valBoxY, valBoxW, valBoxH, {1.0, 1.0, 1.0, 0.10}, 1)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(valColor))
    renderText(valBoxX + valBoxW * 0.5, valBoxY + 0.004, ui.fontSize * 0.92, displayStr)

    -- ── Status Pill Capsule (Option 1A) ────────────────────────────────────
    if statusText ~= "" and packageLevel >= 2 then
        local pillY = y + (ui.lineHeight - pillH) * 0.5
        self:drawRect(pillX, pillY, pillW, pillH, pillBg)
        self:drawBorder(pillX, pillY, pillW, pillH, pillBorder, 1)

        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(unpack(statusColor))
        renderText(pillX + pillW * 0.5, pillY + 0.0035, ui.statusSize * 0.88, statusText)
    end

    -- ── Advanced Recessed Track Slider ─────────────────────────────────────
    local trackH = 0.0075
    local trackY = y + (ui.lineHeight - trackH) * 0.5

    -- Outer Groove Border & Slot
    self:drawRect(sliderStartX, trackY, sliderW, trackH, ui.colors.trackGroove)
    self:drawBorder(sliderStartX, trackY, sliderW, trackH, ui.colors.trackBorder, 1)

    -- Gauge Tick Notches (0%, 25%, 50%, 75%, 100%)
    for step = 0, 4 do
        local tickX = sliderStartX + (step / 4) * sliderW
        self:drawRect(tickX, trackY - 0.002, 0.0006, trackH + 0.004, ui.colors.trackTick)
    end

    -- Glowing Green Optimal Sweet-Spot Band (Tier 2+)
    if packageLevel >= 2 and hasOptimal then
        local optMin = math.max(0, optimal - tolerance)
        local optMax = math.min(100, optimal + tolerance)
        local bandStartX = sliderStartX + (optMin / 100) * sliderW
        local bandW = ((optMax - optMin) / 100) * sliderW
        self:drawRect(bandStartX, trackY, bandW, trackH, ui.colors.trackOptimal)
        self:drawBorder(bandStartX, trackY, bandW, trackH, ui.colors.trackOptimalBorder, 1)

        -- Bright center sweet-spot pin
        local centerPinX = sliderStartX + (optimal / 100) * sliderW
        self:drawRect(centerPinX, trackY - 0.001, 0.0008, trackH + 0.002, ui.colors.trackCenterNotch)
    end

    -- Active Value Fill
    local currentFillW = math.max(0, math.min(sliderW, (val / 100) * sliderW))
    self:drawRect(sliderStartX, trackY, currentFillW, trackH, fillColor)

    -- Tactile Metallic Thumb Handle
    local thumbW = 0.0055
    local thumbH = 0.0170
    local thumbX = sliderStartX + currentFillW - thumbW * 0.5
    local thumbY = trackY + (trackH - thumbH) * 0.5

    -- Thumb drop shadow & border
    self:drawRect(thumbX, thumbY, thumbW, thumbH, (isRowHovered or self.draggingSlider) and ui.colors.trackThumbHover or ui.colors.trackThumb)
    self:drawBorder(thumbX, thumbY, thumbW, thumbH, {0.02, 0.02, 0.02, 0.95}, 1)

    -- Thumb center indicator groove
    self:drawRect(thumbX + thumbW * 0.5 - 0.0004, thumbY + 0.002, 0.0008, thumbH - 0.004, isOptimal and {0.18, 0.80, 0.45, 1.0} or {0.30, 0.35, 0.40, 1.0})

    -- Register Slider Hitbox for direct dragging
    table.insert(self.sliders, {
        x = sliderStartX,
        y = trackY - 0.006,
        w = sliderW,
        h = trackH + 0.012,
        param = param
    })

    -- Smart Step Function
    local function performSmartStep(direction)
        if param == "targetEngineLoad" then
            local newLoad = math.max(50, math.min(100, val + (direction * 5)))
            memory:updateSetting(param, newLoad)
            return
        end

        if RHM_UnitConverter and RHM_UnitConverter.percentToPhysical then
            local physVal = RHM_UnitConverter.percentToPhysical(param, val, machineType)
            local range = RHM_UnitConverter.getPhysicalRange(param, machineType)

            if range then
                local stepValue = (range.unit == "RPM") and 10 or 0.5
                local targetPhysVal = physVal

                local snapped = math.floor((physVal / stepValue) + 0.5) * stepValue
                if math.abs(physVal - snapped) > 0.01 then
                    if direction > 0 then
                        targetPhysVal = math.ceil(physVal / stepValue) * stepValue
                    else
                        targetPhysVal = math.floor(physVal / stepValue) * stepValue
                    end
                else
                    targetPhysVal = snapped + (stepValue * direction)
                end

                local targetPercent = RHM_UnitConverter.physicalToPercent(param, targetPhysVal, machineType)
                if math.abs(targetPercent - val) < 0.5 then
                    targetPercent = val + direction
                end
                memory:updateSetting(param, math.floor(targetPercent + 0.5))
            else
                memory:updateSetting(param, val + direction)
            end
        else
            memory:updateSetting(param, val + direction)
        end
    end

    -- Micro Fine-Tuning Buttons [-] and [+]
    local btnY = y + (ui.lineHeight - microBtnH) * 0.5
    self:drawButton(btnStartX, btnY, microBtnW, microBtnH, "-", function()
        performSmartStep(-1)
    end)

    self:drawButton(btnStartX + microBtnW + 0.003, btnY, microBtnW, microBtnH, "+", function()
        performSmartStep(1)
    end)
end

function RHMCombineCalibrationGUI:drawButton(x, y, w, h, text, callback, colorOverride, borderOverride)
    local isHovered = self:checkHover(x, y, w, h)
    local bgColor
    local borderColor = borderOverride or self.ui.colors.buttonBorder

    if text == "X" then
        if isHovered then
            bgColor = {0.35, 0.08, 0.08, 0.85}
            borderColor = {0.95, 0.35, 0.35, 0.85}
        else
            bgColor = {0.05, 0.05, 0.06, 0.65}
            borderColor = {1.0, 1.0, 1.0, 0.12}
        end
    elseif colorOverride then
        if isHovered and colorOverride == self.ui.colors.buttonReset and self.ui.colors.buttonResetHover then
            bgColor = self.ui.colors.buttonResetHover
            borderColor = {0.95, 0.35, 0.35, 0.75}
        elseif isHovered then
            bgColor = {
                math.min(1.0, colorOverride[1] * 1.4),
                math.min(1.0, colorOverride[2] * 1.4),
                math.min(1.0, colorOverride[3] * 1.4),
                math.min(1.0, (colorOverride[4] or 0.8) * 1.15)
            }
            if borderOverride then
                borderColor = {
                    math.min(1.0, borderOverride[1] * 1.4),
                    math.min(1.0, borderOverride[2] * 1.4),
                    math.min(1.0, borderOverride[3] * 1.4),
                    math.min(1.0, (borderOverride[4] or 0.8) * 1.2)
                }
            end
        else
            bgColor = colorOverride
        end
    elseif isHovered then
        bgColor = self.ui.colors.buttonHover
        borderColor = self.ui.colors.buttonHoverBorder or {0.529, 0.706, 0.0, 0.70}
    else
        bgColor = self.ui.colors.button
    end

    self:drawRect(x, y, w, h, bgColor)
    self:drawBorder(x, y, w, h, borderColor, 1)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)

    if isHovered then
        if text == "+" then
            setTextColor(0.529, 0.706, 0.0, 1.0)
        elseif text == "-" then
            setTextColor(0.95, 0.35, 0.35, 1.0)
        elseif text == "X" then
            setTextColor(1.0, 1.0, 1.0, 1.0)
        else
            setTextColor(1.0, 1.0, 1.0, 1.0)
        end
    else
        if text == "+" or text == "-" then
            setTextColor(0.70, 0.74, 0.80, 1.0)
        elseif text == "X" then
            setTextColor(0.85, 0.88, 0.92, 1.0)
        else
            setTextColor(unpack(self.ui.colors.textDim))
        end
    end

    local btnFontSize = (text == "X") and (self.ui.fontSize * 1.15) or self.ui.fontSize
    local offsetY = (text == "X") and (btnFontSize * 0.35) or (self.ui.fontSize * 0.38)
    renderText(x + w * 0.5, y + h * 0.5 - offsetY, btnFontSize, text)
    setTextBold(false)

    table.insert(self.buttons, {x=x, y=y, w=w, h=h, callback=callback})
end

function RHMCombineCalibrationGUI:drawPanelBackground(x, y, w, h, color)
    if not self.roundedOverlay or not self.roundedUVs then return end

    local c = color or self.ui.colors.bg
    local r = c[1] or 0.0
    local g = c[2] or 0.0
    local b = c[3] or 0.0
    local a = c[4] or 0.86

    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local snappedX = math.floor(x * screenW + 0.5) / screenW
    local snappedY = math.floor(y * screenH + 0.5) / screenH
    local snappedW = math.max(math.floor(w * screenW + 0.5) / screenW, 1 / screenW)
    local snappedH = math.max(math.floor(h * screenH + 0.5) / screenH, 1 / screenH)

    local cornerW = math.min(math.floor((6 / screenW) * screenW + 0.5) / screenW, snappedW * 0.5)
    local cornerH = math.min(math.floor((6 / screenH) * screenH + 0.5) / screenH, snappedH * 0.5)

    local leftX = snappedX
    local centerX = snappedX + cornerW
    local rightX = snappedX + snappedW - cornerW
    local bottomY = snappedY
    local centerY = snappedY + cornerH
    local topY = snappedY + snappedH - cornerH
    local centerW = math.max(rightX - centerX, 0)
    local centerH = math.max(topY - centerY, 0)

    local overlay = self.roundedOverlay
    overlay:setColor(r, g, b, a)

    local function renderSlice(sx, sy, sw, sh, uvs)
        if sw <= 0 or sh <= 0 or not uvs then return end
        overlay:setPosition(sx, sy)
        overlay:setDimension(sw, sh)
        overlay:setUVs(uvs)
        overlay:render()
    end

    local uvs = self.roundedUVs
    renderSlice(leftX, bottomY, cornerW, cornerH, uvs.bottomLeft)
    renderSlice(centerX, bottomY, centerW, cornerH, uvs.bottom)
    renderSlice(rightX, bottomY, cornerW, cornerH, uvs.bottomRight)

    renderSlice(leftX, centerY, cornerW, centerH, uvs.left)
    renderSlice(centerX, centerY, centerW, centerH, uvs.center)
    renderSlice(rightX, centerY, cornerW, centerH, uvs.right)

    renderSlice(leftX, topY, cornerW, cornerH, uvs.topLeft)
    renderSlice(centerX, topY, centerW, cornerH, uvs.top)
    renderSlice(rightX, topY, cornerW, cornerH, uvs.topRight)
end

function RHMCombineCalibrationGUI:drawRect(x, y, w, h, color)
    if not self.overlay or not color then return end
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local px = math.floor(x * screenW + 0.5) / screenW
    local py = math.floor(y * screenH + 0.5) / screenH
    local pw = math.max(math.floor(w * screenW + 0.5) / screenW, 1 / screenW)
    local ph = math.max(math.floor(h * screenH + 0.5) / screenH, 1 / screenH)

    local r, g, b, a = unpack(color)
    self.overlay:setPosition(px, py)
    self.overlay:setDimension(pw, ph)
    self.overlay:setColor(r, g, b, a or 1.0)
    self.overlay:render()
end

function RHMCombineCalibrationGUI:drawBorder(x, y, w, h, color, thicknessPx)
    if not self.overlay or not color then return end
    thicknessPx = thicknessPx or 1
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local px = math.floor(x * screenW + 0.5) / screenW
    local py = math.floor(y * screenH + 0.5) / screenH
    local pw = math.max(math.floor(w * screenW + 0.5) / screenW, 1 / screenW)
    local ph = math.max(math.floor(h * screenH + 0.5) / screenH, 1 / screenH)
    local tW = thicknessPx / screenW
    local tH = thicknessPx / screenH

    local r, g, b, a = unpack(color)
    self.overlay:setColor(r, g, b, a or 1.0)

    -- Bottom
    self.overlay:setPosition(px, py)
    self.overlay:setDimension(pw, tH)
    self.overlay:render()

    -- Top
    self.overlay:setPosition(px, py + ph - tH)
    self.overlay:setDimension(pw, tH)
    self.overlay:render()

    -- Left
    self.overlay:setPosition(px, py)
    self.overlay:setDimension(tW, ph)
    self.overlay:render()

    -- Right
    self.overlay:setPosition(px + pw - tW, py)
    self.overlay:setDimension(tW, ph)
    self.overlay:render()
end

function RHMCombineCalibrationGUI:_resetTextState()
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function RHMCombineCalibrationGUI:checkHover(x, y, w, h)
    local mx, my = self.mouseX, self.mouseY
    if not mx or not my then
        mx, my = g_inputBinding:getMousePosition()
    end
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function RHMCombineCalibrationGUI:updateSliderFromMouse(slider, posX)
    local param = slider.param
    local spec = self.activeVehicle and self.activeVehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then return end

    local ratio = math.max(0, math.min(1, (posX - slider.x) / slider.w))
    local percent = math.floor(ratio * 100 + 0.5)

    if param == "targetEngineLoad" then
        percent = math.floor(percent / 5 + 0.5) * 5
        percent = math.max(50, math.min(100, percent))
        spec.combineMemory:updateSetting(param, percent)
        return
    end

    local machineType = spec.machineType or "grain"
    if RHM_UnitConverter and RHM_UnitConverter.percentToPhysical and RHM_UnitConverter.getPhysicalRange then
        local physVal = RHM_UnitConverter.percentToPhysical(param, percent, machineType)
        local range = RHM_UnitConverter.getPhysicalRange(param, machineType)
        if range then
            local step = (range.unit == "RPM") and 10 or 0.5
            local snappedPhys = math.floor((physVal / step) + 0.5) * step
            local snappedPercent = RHM_UnitConverter.physicalToPercent(param, snappedPhys, machineType)
            spec.combineMemory:updateSetting(param, math.floor(snappedPercent + 0.5))
            return
        end
    end

    spec.combineMemory:updateSetting(param, percent)
end

function RHMCombineCalibrationGUI:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isOpen then return end

    self.mouseX = posX
    self.mouseY = posY

    local insideGUI = posX >= self.ui.x and posX <= self.ui.x + self.ui.w and
                      posY >= self.ui.y and posY <= self.ui.y + self.ui.h

    -- Handle slider dragging
    if self.draggingSlider then
        if isUp and button == Input.MOUSE_BUTTON_LEFT then
            self.draggingSlider = nil
            return true
        else
            self:updateSliderFromMouse(self.draggingSlider, posX)
            return true
        end
    end

    -- Handle tablet window dragging by header bar
    if self.isDraggingTablet then
        if isUp and button == Input.MOUSE_BUTTON_LEFT then
            self.isDraggingTablet = false
            return true
        else
            self.ui.x = math.max(0.005, math.min(1.0 - self.ui.w - 0.005, posX - self.dragOffsetTabletX))
            self.ui.y = math.max(0.005, math.min(0.98 - self.ui.h, posY - self.dragOffsetTabletY))
            self.hasCustomPosition = true
            return true
        end
    end

    local isWheel = button == Input.MOUSE_BUTTON_WHEEL_UP or button == Input.MOUSE_BUTTON_WHEEL_DOWN
    if isWheel and insideGUI then
        if isDown then
            local wheelUp = button == Input.MOUSE_BUTTON_WHEEL_UP
            local delta = wheelUp and 1 or -1
            if Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift) then
                delta = delta * 5
            end

            local param = self.hoveredParameter
            if param and self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
                local spec = self.activeVehicle.spec_rhm_Combine
                if spec.combineMemory then
                    local currentVal = spec.combineMemory.currentSettings[param] or 50
                    if param == "targetEngineLoad" then
                        local newLoad = math.max(50, math.min(100, currentVal + (delta * 5)))
                        spec.combineMemory:updateSetting(param, newLoad)
                    else
                        spec.combineMemory:updateSetting(param, math.max(0, math.min(100, currentVal + delta)))
                    end
                end
            end
        end
        return true
    end

    if isDown and button == Input.MOUSE_BUTTON_LEFT then
        -- Check slider clicks
        if self.sliders then
            for _, slider in ipairs(self.sliders) do
                if posX >= slider.x and posX <= (slider.x + slider.w) and
                   posY >= slider.y and posY <= (slider.y + slider.h) then
                    self.draggingSlider = slider
                    self:updateSliderFromMouse(slider, posX)
                    return true
                end
            end
        end

        -- Check button clicks (including close [X] button)
        for _, btn in ipairs(self.buttons) do
            if posX >= btn.x and posX <= btn.x + btn.w and posY >= btn.y and posY <= btn.y + btn.h then
                if btn.callback then
                    btn.callback()
                end
                return true
            end
        end

        -- Check dragging tablet by outer bezel frame or header bar (outside buttons)
        local isBezelOrHeader = false
        if posX >= self.ui.x and posX <= (self.ui.x + self.ui.w) and
           posY >= self.ui.y and posY <= (self.ui.y + self.ui.h) then
            local headerY = self.ui.y + self.ui.h - self.ui.headerHeight - (self.ui.bezelTop or 0.0038)
            if posY >= headerY then
                isBezelOrHeader = true
            elseif posX <= self.ui.x + (self.ui.bezelSide or 0.0025) or
                   posX >= self.ui.x + self.ui.w - (self.ui.bezelSide or 0.0025) or
                   posY <= self.ui.y + (self.ui.bezelBottom or 0.0038) then
                isBezelOrHeader = true
            end
        end

        if isBezelOrHeader then
            self.isDraggingTablet = true
            self.dragOffsetTabletX = posX - self.ui.x
            self.dragOffsetTabletY = posY - self.ui.y
            return true
        end
    end

    if insideGUI then
        return true
    end

    -- While modal calibration GUI is open, consume all mouse button presses/releases
    -- so clicks outside the tablet never trigger vehicle tools, IC actions, or camera jumps.
    if isDown or isUp then
        return true
    end
end

function RHMCombineCalibrationGUI:handleWheelScroll(direction, posX, posY)
    local delta = direction
    if Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift) then
        delta = delta * 5
    end

    if self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
        local spec = self.activeVehicle.spec_rhm_Combine
        if spec.combineMemory and self.hoveredParameter then
            local currentVal = spec.combineMemory.currentSettings[self.hoveredParameter] or 50
            if self.hoveredParameter == "targetEngineLoad" then
                local newLoad = math.max(50, math.min(100, currentVal + (delta * 5)))
                spec.combineMemory:updateSetting(self.hoveredParameter, newLoad)
            else
                spec.combineMemory:updateSetting(self.hoveredParameter, math.max(0, math.min(100, currentVal + delta)))
            end
        end
    end
end

function RHMCombineCalibrationGUI:getHarvestContext(machineType)
    if self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
        local rhmSpec = self.activeVehicle.spec_rhm_Combine
        return {
            machineType = machineType or rhmSpec.machineType or "grain",
            moisture = (rhmSpec.data and rhmSpec.data.moisture) or 0,
            yield = (rhmSpec.data and rhmSpec.data.yield) or 0,
            isPickup = (rhmSpec.loadCalculator and rhmSpec.loadCalculator.isPickup) or false,
            fillType = rhmSpec.lastFillType,
            fruitType = rhmSpec.lastFruitType,
        }
    end
    return { machineType = machineType or "grain" }
end

rhm_log("RHM [UI]: [OK] RHMCombineCalibrationGUI (Obsidian CEBIS In-Cab Terminal) loaded")

return RHMCombineCalibrationGUI
