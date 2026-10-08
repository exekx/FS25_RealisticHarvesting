-- EN: Minimalist on-screen telemetry HUD for Realistic Harvesting.
--     Uses the authentic rounded capsule slices (rhm_atlas.dds) with 3-part border rendering.
--     Correctly tinted with dark obsidian glass color (0.028, 0.030, 0.036, 0.88).
--     Docks dynamically beneath the auxiliary combine telemetry bar or F1 ControlsHelp menu.
--     Dynamically tracks the F1 help menu toggle via g_gameSettings showHelpMenu.
--     Supports interactive click-to-cycle metrics (t/h <-> ha/h, Loss <-> Speed, Moisture <-> Yield).
-- UA: Мінімалістичний телеметричний HUD для Realistic Harvesting.
--     Використовує текстуру капсули (rhm_atlas.dds) з 3-компонентними заокругленими кутами.
--     Тонований у глибокий колір темного скла (0.028, 0.030, 0.036, 0.88).
--     Приліпає динамічно під смугу додаткової телеметрії комбайна або меню довідки F1 (ControlsHelp).
--     Динамічно відстежує відкриття/закриття F1 через g_gameSettings showHelpMenu.
--     Підтримує інтерактивне перемикання показників кліком (т/ч <-> га/ч, Втрати <-> Швидкість, Волога <-> Урожайність).

local HUD_BG_COLOR = {0.0, 0.0, 0.0, 0.72}
local DOCK_INNER_BG = {0.04, 0.08, 0.02, 0.60}
local SNAP_OUTER_COLOR = {0.0, 0.0, 0.0, 0.88}

local function renderPanelSlice(overlay, sx, sy, sw, sh, uvs)
    if sw <= 0 or sh <= 0 or not uvs then return end
    overlay:setPosition(sx, sy)
    overlay:setDimension(sw, sh)
    overlay:setUVs(uvs)
    overlay:render()
end

RHMDraggableHUD = {}
RHMDraggableHUD.__index = RHMDraggableHUD

function RHMDraggableHUD.new(modDirectory, settings)
    local self = setmetatable({}, RHMDraggableHUD)

    self.modDirectory = modDirectory
    self.settings = settings
    self.vehicle = nil

    self.data = {
        load = 0,
        yield = 0,
        speed = 0,
        cropLoss = 0,
        tonPerHour = 0,
        litersPerHour = 0,
        recommendedSpeed = 0,
        moisture = 0,
        hectaresPerHour = 0
    }

    self.displayData = {
        load = 0,
        yield = 0,
        speed = 0,
        cropLoss = 0,
        tonPerHour = 0,
        litersPerHour = 0,
        recommendedSpeed = 0,
        moisture = 0,
        hectaresPerHour = 0
    }

    self.displayTimer = 0
    self.cachedCells = nil

    self.displayModes = {
        cell1 = "load",
        cell2 = "loss",
        cell3 = "moisture",
        cell4 = "yield",
        cell4_weed = "weed",
        cell5 = "flowRate",
        cell6 = "yield",
        cell7 = "area",
        cell8 = "mass"
    }

    self.uiScale = 1.0
    self.width = 0.176
    local hudStyle = (settings and settings.hudStyle) or 2
    self.height = (hudStyle == 2 and 0.082 or 0.042)

    self.rectOverlay = nil
    self.bgTopOverlay = nil
    self.bgMidOverlay = nil
    self.bgBotOverlay = nil
    self.icons = {}

    self.isDragging = false
    self.hasMoved = false
    self.isNearDock = false

    return self
end

function RHMDraggableHUD:load()
    self.uiScale = 1.0
    if g_gameSettings then
        self.uiScale = g_gameSettings:getValue("uiScale") or 1.0
    end

    local hudStyle = (self.settings and self.settings.hudStyle) or 2
    self.height = (hudStyle == 2 and 0.082 or 0.042) * self.uiScale
    self.width  = 0.176 * self.uiScale

    -- 1. Load authentic FS25 rounded panel texture from unified atlas
    if not self.roundedOverlay then
        local panelTexturePath = self.modDirectory .. "textures/rhm_atlas.dds"
        self.roundedOverlay = Overlay.new(panelTexturePath, 0, 0, 1, 1)

        -- 9-slice UVs from rhm_atlas.dds (panel_rounded slot at X: 0, Y: 384, Size: 64x64)
        local pxUVs = {
            topLeft     = {  0, 384,  5,  5 },
            top         = {  5, 384, 54,  5 },
            topRight    = { 59, 384,  5,  5 },
            left        = {  0, 389,  5, 54 },
            center      = {  5, 389, 54, 54 },
            right       = { 59, 389,  5, 54 },
            bottomLeft  = {  0, 443,  5,  5 },
            bottom      = {  5, 443, 54,  5 },
            bottomRight = { 59, 443,  5,  5 }
        }
        self.roundedUVs = {}
        for key, coords in pairs(pxUVs) do
            self.roundedUVs[key] = GuiUtils.getUVs(coords, {1024, 1024})
        end
    end

    -- 2. Solid 1x1 overlay for dividers and underline indicators (solid_white at X: 512, Y: 256)
    self.iconAtlasPath = self.modDirectory .. "textures/rhm_atlas.dds"
    self.bgUVs = GuiUtils.getUVs({516, 260, 56, 56}, {1024, 1024})
    self.rectOverlay = Overlay.new(self.iconAtlasPath, 0, 0, 1, 1)
    if self.bgUVs then
        self.rectOverlay:setUVs(self.bgUVs)
    end

    local dockX, dockY, dockW = self:getDockedPosition()
    if self.settings and self.settings.hudPosX ~= nil and self.settings.hudPosY ~= nil then
        self.x = self.settings.hudPosX
        self.y = self.settings.hudPosY
        self.width = dockW
        self.isSnapped = false
    else
        self.x = dockX
        self.y = dockY
        self.width = dockW
        self.isSnapped = true
    end

    self:loadIcons(self.uiScale)

    rhm_log("RHM [UI]: RHMDraggableHUD (PF style) loaded successfully")
end

function RHMDraggableHUD:updateLayout()
    local hudStyle = (self.settings and self.settings.hudStyle) or 2
    self.height = (hudStyle == 2 and 0.082 or 0.042) * (self.uiScale or 1.0)
    self.cachedCells = nil
    if self.isSnapped then
        local dockX, dockY, dockW = self:getDockedPosition()
        self.x = dockX
        self.y = dockY
        self.width = dockW
    end
end

function RHMDraggableHUD:loadIcons(uiScale)
    local hudStyle = (self.settings and self.settings.hudStyle) or 2
    self.height = (hudStyle == 2 and 0.082 or 0.042) * self.uiScale
    self.width  = 0.176 * self.uiScale

    local iconHeight = 0.024 * self.uiScale
    local iconWidth  = iconHeight / g_screenAspectRatio

    local atlasPath = self.iconAtlasPath or (self.modDirectory .. "textures/rhm_atlas.dds")
    local atlasSize = {1024, 1024}
    local iconPx = 64

    local iconDefs = {
        load         = {0,     256, iconPx, iconPx},
        yield        = {64,    256, iconPx, iconPx},
        productivity = {128,   256, iconPx, iconPx},
        moisture     = {192,   256, iconPx, iconPx},
        loss         = {256,   256, iconPx, iconPx},
        speed        = {320,   256, iconPx, iconPx},
        weed         = {384,   256, iconPx, iconPx},
        area_rate    = {448,   256, iconPx, iconPx},
        field        = {64,    320, iconPx, iconPx},
        trip         = {0,     320, iconPx, iconPx},
        history      = {256,   320, iconPx, iconPx}
    }

    for name, uvRect in pairs(iconDefs) do
        local icon = Overlay.new(atlasPath, 0, 0, iconWidth, iconHeight)
        icon:setUVs(GuiUtils.getUVs(uvRect, atlasSize))
        icon:setColor(1, 1, 1, 0.95)
        self.icons[name] = icon
    end

    if self.settings.showLoad == nil then self.settings.showLoad = true end
    if self.settings.showYield == nil then self.settings.showYield = true end
    if self.settings.showSpeed == nil then self.settings.showSpeed = true end
    if self.settings.showCropLoss == nil then self.settings.showCropLoss = true end
    if self.settings.showProductivity == nil then self.settings.showProductivity = true end
    if self.settings.showMoisture == nil then self.settings.showMoisture = true end
    if self.settings.showWeeds == nil then self.settings.showWeeds = true end
    self.settings.hudDocked = true
end

-- Frame tracking for dynamic HUD docking
local rhm_currentDrawFrame = 0
local rhm_hooksInitialized = false
local rhm_activeInputHelpDisplay = nil
local rhm_extraPrintCountThisFrame = 0
local rhm_lastExtraPrintCount = 0

local function rhm_initHudHooks()
    if rhm_hooksInitialized then return end
    rhm_hooksInitialized = true

    -- Prepend to Mission00.draw / FSBaseMission.draw to increment frame counter and intercept extra print texts
    local function rhm_onPreDraw(mission)
        rhm_currentDrawFrame = rhm_currentDrawFrame + 1
        if mission and not mission.rhm_extraPrintHooked and mission.addExtraPrintText then
            mission.rhm_extraPrintHooked = true
            local origAddExtra = mission.addExtraPrintText
            mission.addExtraPrintText = function(mSelf, text, ...)
                rhm_extraPrintCountThisFrame = rhm_extraPrintCountThisFrame + 1
                return origAddExtra(mSelf, text, ...)
            end
        end
        rhm_lastExtraPrintCount = rhm_extraPrintCountThisFrame
        rhm_extraPrintCountThisFrame = 0
    end
    if Mission00 and Mission00.draw then
        Mission00.draw = Utils.prependedFunction(Mission00.draw, rhm_onPreDraw)
    end
    if FSBaseMission and FSBaseMission.draw then
        FSBaseMission.draw = Utils.prependedFunction(FSBaseMission.draw, rhm_onPreDraw)
    end

    -- Hook auxiliary combine telemetry HUD extension for dynamic docking
    if ExtendedCombineHUDExtension and ExtendedCombineHUDExtension.draw then
        ExtendedCombineHUDExtension.draw = Utils.overwrittenFunction(ExtendedCombineHUDExtension.draw, function(self, superFunc, inputHelpDisplay, posX, posY)
            local ret = superFunc(self, inputHelpDisplay, posX, posY)
            self.rhm_lastBottomY = (self.backgroundBottom and self.backgroundBottom.y) or ret
            self.rhm_lastBottomX = (self.backgroundBottom and self.backgroundBottom.x) or posX
            self.rhm_lastWidth = self.displayWidth
            self.rhm_lastDrawFrame = rhm_currentDrawFrame
            return ret
        end)
    end

    -- Hook InputHelpDisplay main draw to capture active instance, count pending extra texts, and track baseline bottom Y
    if InputHelpDisplay and InputHelpDisplay.draw then
        InputHelpDisplay.draw = Utils.overwrittenFunction(InputHelpDisplay.draw, function(self, superFunc, offsetX, offsetY)
            rhm_activeInputHelpDisplay = self
            self.rhm_frameHelpMinY = nil

            -- EN: Count pending extra help texts before draw() processes and empties the table.
            -- UA: Рахуємо очікувані додаткові тексти до того, як draw() їх відрендерить та очистить таблицю.
            local pendingExtra = 0
            if self.extraHelpTexts then
                for _ in pairs(self.extraHelpTexts) do
                    pendingExtra = pendingExtra + 1
                end
            end
            self.rhm_lastExtraHelpCount = pendingExtra

            local ret = superFunc(self, offsetX, offsetY)

            self.rhm_lastDrawFrame = rhm_currentDrawFrame
            self.rhm_baseHelpBottomY = self.rhm_frameHelpMinY

            return ret
        end)
    end

    -- Hook InputHelpDisplay vehicle schema
    if InputHelpDisplay and InputHelpDisplay.drawVehicleSchema then
        InputHelpDisplay.drawVehicleSchema = Utils.overwrittenFunction(InputHelpDisplay.drawVehicleSchema, function(self, superFunc, posX, posY, isOnlySchema)
            local retPosY, retCtrlPosY = superFunc(self, posX, posY, isOnlySchema)
            self.rhm_lastSchemaBottomY = retPosY
            self.rhm_lastSchemaFrame = rhm_currentDrawFrame
            return retPosY, retCtrlPosY
        end)
    end

    -- Hook InputHelpDisplay help elements
    if InputHelpDisplay and InputHelpDisplay.drawInputHelpElement then
        InputHelpDisplay.drawInputHelpElement = Utils.overwrittenFunction(InputHelpDisplay.drawInputHelpElement, function(self, superFunc, posX, posY, helpElement, ignoreComboButtons)
            local retY = superFunc(self, posX, posY, helpElement, ignoreComboButtons)
            local currentBottom = retY or (posY - (self.lineBg and self.lineBg.height or 0.024))
            if currentBottom and currentBottom > 0.01 and currentBottom < 0.99 then
                if not self.rhm_frameHelpMinY or currentBottom < self.rhm_frameHelpMinY then
                    self.rhm_frameHelpMinY = currentBottom
                end
            end
            self.rhm_lastHelpBottomY = currentBottom
            self.rhm_lastHelpFrame = rhm_currentDrawFrame
            return retY
        end)
    end

    -- Hook InputHelpDisplay extra text (control groups, warnings, mod extras)
    if InputHelpDisplay and InputHelpDisplay.drawExtraText then
        InputHelpDisplay.drawExtraText = Utils.overwrittenFunction(InputHelpDisplay.drawExtraText, function(self, superFunc, posX, posY, text)
            local retY = superFunc(self, posX, posY, text)
            local currentBottom = retY or (posY - (self.lineBg and self.lineBg.height or 0.024))
            if currentBottom and currentBottom > 0.01 and currentBottom < 0.99 then
                if not self.rhm_frameHelpMinY or currentBottom < self.rhm_frameHelpMinY then
                    self.rhm_frameHelpMinY = currentBottom
                end
            end
            self.rhm_lastHelpBottomY = currentBottom
            self.rhm_lastHelpFrame = rhm_currentDrawFrame
            return retY
        end)
    end
end

-- Attempt immediate hook
rhm_initHudHooks()

local function getPfHudExtension(vehicle)
    if not vehicle then return nil end
    if vehicle.spec_extendedCombine and vehicle.spec_extendedCombine.hudExtension then
        return vehicle.spec_extendedCombine.hudExtension
    end
    for k, v in pairs(vehicle) do
        if type(k) == "string" and k:find("extendedCombine") and type(v) == "table" and v.hudExtension then
            return v.hudExtension
        end
    end
    return nil
end

local function rhm_getExtraHelpLinesCount(vehicle, ch)
    local count = 0

    -- 1. Check live queued extraHelpTexts counted at start of InputHelpDisplay.draw
    if ch and ch.rhm_lastExtraHelpCount and ch.rhm_lastExtraHelpCount > 0 then
        count = math.max(count, ch.rhm_lastExtraHelpCount)
    end

    -- 2. Check live extra texts captured this frame via g_currentMission:addExtraPrintText hook
    if rhm_extraPrintCountThisFrame and rhm_extraPrintCountThisFrame > 0 then
        count = math.max(count, rhm_extraPrintCountThisFrame)
    elseif rhm_lastExtraPrintCount and rhm_lastExtraPrintCount > 0 then
        count = math.max(count, rhm_lastExtraPrintCount)
    end

    -- 3. Check live extraPrintTexts table on mission if engine exposes it
    if g_currentMission and g_currentMission.extraPrintTexts and #g_currentMission.extraPrintTexts > 0 then
        count = math.max(count, #g_currentMission.extraPrintTexts)
    end

    -- 4. Check active vehicle and attached implements for active control groups
    local v = vehicle or (g_currentMission and g_currentMission.controlledVehicle)
    if v ~= nil then
        local checkedVehicles = {}
        local function checkVeh(veh)
            if not veh or checkedVehicles[veh] then return end
            checkedVehicles[veh] = true

            if veh.spec_cylindered then
                local sc = veh.spec_cylindered
                local numNames = (sc.controlGroupNames and #sc.controlGroupNames) or 0
                local numGroups = (sc.controlGroups and #sc.controlGroups) or 0
                local hasMultiple = (numNames > 1) or (numGroups > 1)
                local isGroupActive = (sc.currentControlGroupIndex ~= nil and sc.currentControlGroupIndex ~= 0)
                if hasMultiple and isGroupActive then
                    count = math.max(count, 1)
                end
            end

            if veh.getAttachedImplements then
                local implements = veh:getAttachedImplements()
                if implements then
                    for _, impl in ipairs(implements) do
                        if impl.object then
                            checkVeh(impl.object)
                        end
                    end
                end
            end
        end

        checkVeh(v)
        if v.rootVehicle and v.rootVehicle ~= v then
            checkVeh(v.rootVehicle)
        end
    end

    return count
end

local function rhm_getInputHelpDisplay()
    if rhm_activeInputHelpDisplay ~= nil then
        return rhm_activeInputHelpDisplay
    end
    if g_currentMission and g_currentMission.hud then
        local hud = g_currentMission.hud
        return hud.inputHelpDisplay or hud.inputHelp or hud.controlsHelp or hud.helpDisplay
    end
    return nil
end

---EN: Computes the docked position directly beneath the auxiliary combine telemetry bar or F1 ControlsHelp menu.
---UA: Обчислює позицію стикування під смугою додаткової телеметрії комбайна або меню довідки F1 (ControlsHelp).
function RHMDraggableHUD:getDockedPosition()
    rhm_initHudHooks()

    -- Lazy hook Mission00.draw once mission is created
    if not RHMDraggableHUD.mission00Hooked and Mission00 and Mission00.draw then
        RHMDraggableHUD.mission00Hooked = true
        Mission00.draw = Utils.prependedFunction(Mission00.draw, function(mission)
            rhm_currentDrawFrame = rhm_currentDrawFrame + 1
            if mission and not mission.rhm_extraPrintHooked and mission.addExtraPrintText then
                mission.rhm_extraPrintHooked = true
                local origAddExtra = mission.addExtraPrintText
                mission.addExtraPrintText = function(mSelf, text, ...)
                    rhm_extraPrintCountThisFrame = rhm_extraPrintCountThisFrame + 1
                    return origAddExtra(mSelf, text, ...)
                end
            end
            rhm_lastExtraPrintCount = rhm_extraPrintCountThisFrame
            rhm_extraPrintCountThisFrame = 0
        end)
    end

    local uiScale = self.uiScale or 1.0
    local defaultX = 0.016 * uiScale
    local defaultW = 0.176 * uiScale

    local ch = rhm_getInputHelpDisplay()
    local spacing = (ch and ch.lineOffsetY) or (0.0030 * uiScale)

    local chX = (ch and ch.lineBg and ch.lineBg.x) or (ch and ch.getX and ch:getX()) or (ch and ch.x) or defaultX
    local chW = (ch and ch.lineBg and ch.lineBg.width) or (ch and ch.getWidth and ch:getWidth()) or (ch and ch.width) or defaultW

    -- Lazy hook auxiliary combine telemetry HUD extension if loaded dynamically
    if not RHMDraggableHUD.pfHooked and ExtendedCombineHUDExtension and ExtendedCombineHUDExtension.draw then
        RHMDraggableHUD.pfHooked = true
        ExtendedCombineHUDExtension.draw = Utils.overwrittenFunction(ExtendedCombineHUDExtension.draw, function(extSelf, superFunc, inputHelpDisplay, posX, posY)
            local ret = superFunc(extSelf, inputHelpDisplay, posX, posY)
            extSelf.rhm_lastBottomY = (extSelf.backgroundBottom and extSelf.backgroundBottom.y) or ret
            extSelf.rhm_lastBottomX = (extSelf.backgroundBottom and extSelf.backgroundBottom.x) or posX
            extSelf.rhm_lastWidth = extSelf.displayWidth
            extSelf.rhm_lastDrawFrame = rhm_currentDrawFrame
            return ret
        end)
    end

    local currentVeh = self.vehicle or (g_currentMission and g_currentMission.controlledVehicle)

    local isF1Open = false
    if g_gameSettings and g_gameSettings.getValue then
        isF1Open = (g_gameSettings:getValue("showHelpMenu") == true)
    end
    if ch and ch.getVisible then
        isF1Open = isF1Open and ch:getVisible()
    end

    -- 1. Check auxiliary combine HUD extension on the active combine
    local pfExt = getPfHudExtension(currentVeh)
    if pfExt then
        local pfX = nil
        local pfY = nil
        local pfW = nil

        -- Method A: Hook recorded draw in the current frame (real-time dynamic ground truth)
        if pfExt.rhm_lastDrawFrame == rhm_currentDrawFrame and pfExt.rhm_lastBottomY then
            pfX = pfExt.rhm_lastBottomX or defaultX
            pfY = pfExt.rhm_lastBottomY
            pfW = pfExt.rhm_lastWidth or defaultW
        -- Method B: Fallback check of backgroundBottom overlay position (if hook missed or initial render)
        elseif pfExt.backgroundBottom and pfExt.backgroundBottom.y and pfExt.backgroundBottom.y > 0.05 and pfExt.backgroundBottom.y < 0.95 then
            pfX = pfExt.backgroundBottom.x or defaultX
            pfY = pfExt.backgroundBottom.y
            pfW = pfExt.displayWidth or defaultW
        end

        if pfY then
            -- EN: Extra print texts (control groups, warnings) are only drawn by the engine when F1 is OPEN!
            -- UA: Додаткові тексти (контрольні групи) малюються движком тільки тоді, коли меню F1 ВІДКРИТЕ!
            if isF1Open then
                local extraLines = rhm_getExtraHelpLinesCount(currentVeh, ch)
                if extraLines > 0 then
                    local itemH = (ch and ch.lineBg and ch.lineBg.height) or (ch and ch.entryHeight) or (ch and ch.lineHeight) or (0.0260 * uiScale)
                    local rowSpacing = (ch and ch.lineOffsetY) or spacing or (0.0030 * uiScale)
                    pfY = pfY - (extraLines * (itemH + rowSpacing))
                end
            end

            local dockY = pfY - spacing - self.height

            -- Overflow Guard: if F1 + PF + extras is extremely tall, dock to the right
            local minSafeY = 0.015 * uiScale
            if dockY < minSafeY then
                if pfY < (minSafeY + self.height + spacing) then
                    local sideX = (pfX or chX) + (pfW or chW) + (0.008 * uiScale)
                    local sideY = math.min(0.85 * uiScale, ((ch and ch.getY and ch:getY()) or (ch and ch.y) or 0.85) - self.height)
                    return sideX, sideY, (pfW or chW)
                else
                    dockY = minSafeY
                end
            end

            return pfX or chX, dockY, pfW or chW
        end
    end

    -- 2. Auxiliary combine telemetry extension is not active: Check F1 Help Menu elements

    if isF1Open and ch then
        -- F1 Help Menu is OPEN:
        local helpBottomY = nil

        -- Priority 1: Base bottom of regular help entries (from drawInputHelpElement / drawVehicleSchema)
        if ch.rhm_baseHelpBottomY and ch.rhm_baseHelpBottomY > 0.02 and ch.rhm_baseHelpBottomY < 0.98 then
            helpBottomY = ch.rhm_baseHelpBottomY
        elseif ch.rhm_lastHelpBottomY and ch.rhm_lastHelpBottomY > 0.02 and ch.rhm_lastHelpBottomY < 0.98 then
            helpBottomY = ch.rhm_lastHelpBottomY
        end

        -- Priority 2: Fallback calculation based on item count
        if not helpBottomY then
            local numItems = 0
            if ch.helpList and ch.helpList.items then
                numItems = #ch.helpList.items
            elseif ch.helpList and ch.helpList.entries then
                numItems = #ch.helpList.entries
            elseif ch.entries then
                numItems = #ch.entries
            else
                numItems = 13
            end
            local itemH = 0.0260 * uiScale
            local listTopY = 0.816 * uiScale
            helpBottomY = math.max(0.12, listTopY - (numItems * itemH))
        end

        -- EN: Account for extra print texts below the F1 menu (e.g. control groups like Pipe/Door/Ladder, mode alerts)
        -- UA: Враховуємо додаткові тексти під меню F1 (контрольні групи на зразок труби/дверей/драбини, сповіщення)
        local currentVeh = self.vehicle or (g_currentMission and g_currentMission.controlledVehicle)
        local extraLines = rhm_getExtraHelpLinesCount(currentVeh, ch)
        if extraLines > 0 then
            local itemH = (ch.lineBg and ch.lineBg.height) or (ch.entryHeight) or (ch.lineHeight) or (0.0260 * uiScale)
            local rowSpacing = (ch.lineOffsetY) or spacing or (0.0030 * uiScale)
            helpBottomY = helpBottomY - (extraLines * (itemH + rowSpacing))
        end

        local dockY = helpBottomY - spacing - self.height

        -- Overflow Guard: if F1 is extremely tall and would push HUD off screen bottom,
        -- position HUD to the right side of F1 instead of clipping off screen
        local minSafeY = 0.015 * uiScale
        if dockY < minSafeY then
            if helpBottomY < (minSafeY + self.height + spacing) then
                local sideX = chX + chW + (0.008 * uiScale)
                local sideY = math.min(0.85 * uiScale, ((ch.getY and ch:getY()) or ch.y or 0.85) - self.height)
                return sideX, sideY, chW
            else
                dockY = minSafeY
            end
        end

        return chX, dockY, chW
    else
        -- F1 Help Menu is CLOSED:
        -- Hook recorded bottom of vehicle schema drawn this frame:
        if ch and ch.rhm_lastSchemaFrame == rhm_currentDrawFrame and ch.rhm_lastSchemaBottomY then
            local dockY = ch.rhm_lastSchemaBottomY - spacing - self.height
            return chX, dockY, chW
        end

        -- Fallback if hook hasn't run yet
        local schemaBottomY = 0.878
        if ch then
            local chY = (ch.getY and ch:getY()) or ch.y
            if chY and chY > 0.70 and chY < 0.98 then
                schemaBottomY = chY
            end
        end
        local dockY = schemaBottomY - self.height - spacing
        return chX, dockY, chW
    end
end

function RHMDraggableHUD:getPosition()
    if self.settings and self.settings.hudPosX ~= nil and self.settings.hudPosY ~= nil then
        return self.settings.hudPosX, self.settings.hudPosY
    end
    return self:getDockedPosition()
end

function RHMDraggableHUD:setPosition(x, y)
    self.x = x
    self.y = y
    if self.settings then
        self.settings.hudPosX = x
        self.settings.hudPosY = y
    end
end

function RHMDraggableHUD:setVehicle(vehicle)
    local vehicleChanged = (self.vehicle ~= vehicle)
    if vehicleChanged then
        self.cachedCells = nil
        self.displayTimer = 0
    end
    self.vehicle = vehicle
    if vehicle then
        local spec = vehicle.spec_rhm_Combine
        local vData = spec and spec.data
        if vehicleChanged then
            -- Immediately snap raw and smoothed data to prevent previous vehicle's values leaking
            self.data = self.data or {}
            self.displayData = self.displayData or {}
            self.data.load             = (vData and vData.load) or 0
            self.data.yield            = (vData and vData.yield) or 0
            self.data.cropLoss         = (vData and vData.cropLoss) or 0
            self.data.tonPerHour       = (vData and vData.tonPerHour) or 0
            self.data.litersPerHour    = (vData and vData.litersPerHour) or 0
            self.data.recommendedSpeed = (vData and vData.recommendedSpeed) or 0
            self.data.targetSpeed      = (vData and (vData.targetSpeed or vData.recommendedSpeed)) or 0
            self.data.moisture         = (vData and vData.moisture) or 0
            self.data.hectaresPerHour  = (vData and vData.hectaresPerHour) or 0
            self.data.speed            = (vehicle.getLastSpeed and vehicle:getLastSpeed()) or 0
            self.data.weedRatio        = (vData and vData.weedRatio) or 0

            for k, v in pairs(self.data) do
                self.displayData[k] = v
            end
        else
            self:update(0)
        end
    else
        for k, _ in pairs(self.data) do
            self.data[k] = 0
        end
        if self.displayData then
            for k, _ in pairs(self.displayData) do
                self.displayData[k] = 0
            end
        end
        self.cachedCells = nil
    end
end

function RHMDraggableHUD:update(dt)
    local vehicle = self.vehicle
    if not vehicle then return end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.data then return end

    -- Raw synced data from combine
    self.data.load             = spec.data.load or 0
    self.data.yield            = spec.data.yield or 0
    self.data.cropLoss         = spec.data.cropLoss or 0
    self.data.tonPerHour       = spec.data.tonPerHour or 0
    self.data.litersPerHour    = spec.data.litersPerHour or 0
    self.data.recommendedSpeed = spec.data.recommendedSpeed or 0
    self.data.targetSpeed      = spec.data.targetSpeed or spec.data.recommendedSpeed or 0
    self.data.moisture         = spec.data.moisture or 0
    self.data.hectaresPerHour  = spec.data.hectaresPerHour or 0
    self.data.speed            = (vehicle.getLastSpeed and vehicle:getLastSpeed()) or 0
    self.data.weedRatio        = spec.data.weedRatio or 0

    if not self.displayData then
        self.displayData = {}
        for k, v in pairs(self.data) do
            self.displayData[k] = v
        end
    end

    -- Visual display smoothing (simulates CEBIS / CommandCenter LCD filter)
    local dtSec = math.min(0.2, math.max(0.001, (dt or 16) / 1000.0))
    local isStationary = (self.data.speed < 0.4)
    if isStationary then
        self.data.tonPerHour = 0
        self.data.litersPerHour = 0
        self.data.hectaresPerHour = 0
    end

    local function smoothField(curr, target, tauHarvest, tauStop)
        curr = curr or 0
        target = target or 0
        if isStationary and target <= 0.01 then
            local tau = tauStop or 0.15
            local b = 1.0 - math.exp(-dtSec / tau)
            local res = curr + (0 - curr) * b
            return (res < 0.02) and 0 or res
        end
        local tau = tauHarvest or 0.60
        local b = 1.0 - math.exp(-dtSec / tau)
        return curr + (target - curr) * b
    end

    self.displayData.load            = smoothField(self.displayData.load, self.data.load, 0.45, 0.20)
    self.displayData.cropLoss        = smoothField(self.displayData.cropLoss, self.data.cropLoss, 0.60, 0.15)
    self.displayData.tonPerHour      = smoothField(self.displayData.tonPerHour, self.data.tonPerHour, 0.70, 0.15)
    self.displayData.litersPerHour   = smoothField(self.displayData.litersPerHour, self.data.litersPerHour, 0.70, 0.15)
    self.displayData.hectaresPerHour = smoothField(self.displayData.hectaresPerHour, self.data.hectaresPerHour, 0.70, 0.15)
    self.displayData.yield           = smoothField(self.displayData.yield, self.data.yield, 0.70, 0.25)
    self.displayData.weedRatio       = smoothField(self.displayData.weedRatio, self.data.weedRatio, 0.60, 0.20)
    
    -- EN: Moisture should not decay to 0 simply because combine stopped at headland or paused.
    -- UA: Вологість не повинна зникати до 0 тільки через те, що комбайн зупинився або очікує.
    if (self.data.moisture or 0) > 0 then
        local tauM = 0.80
        local bM = 1.0 - math.exp(-dtSec / tauM)
        self.displayData.moisture = (self.displayData.moisture or self.data.moisture) + (self.data.moisture - (self.displayData.moisture or self.data.moisture)) * bM
    end
    self.displayData.speed           = self.data.speed
    self.displayData.recommendedSpeed= self.data.recommendedSpeed
    self.displayData.targetSpeed     = self.data.targetSpeed

    -- Digital refresh cadence: refresh cell strings at 4 Hz (every 250ms)
    self.displayTimer = (self.displayTimer or 0) + (dt or 16)
    if self.displayTimer >= 250 or not self.cachedCells then
        self.displayTimer = 0
        self.cachedCells = self:buildActiveCells()
    end
end

function RHMDraggableHUD:drawPanelBackground(x, y, w, h, color)
    if not self.roundedOverlay or not self.roundedUVs then return end

    local c = color or HUD_BG_COLOR
    local r = c[1] or 0.0
    local g = c[2] or 0.0
    local b = c[3] or 0.0
    local a = c[4] or 0.72

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

    local uvs = self.roundedUVs
    renderPanelSlice(overlay, leftX, bottomY, cornerW, cornerH, uvs.bottomLeft)
    renderPanelSlice(overlay, centerX, bottomY, centerW, cornerH, uvs.bottom)
    renderPanelSlice(overlay, rightX, bottomY, cornerW, cornerH, uvs.bottomRight)

    renderPanelSlice(overlay, leftX, centerY, cornerW, centerH, uvs.left)
    renderPanelSlice(overlay, centerX, centerY, centerW, centerH, uvs.center)
    renderPanelSlice(overlay, rightX, centerY, cornerW, centerH, uvs.right)

    renderPanelSlice(overlay, leftX, topY, cornerW, cornerH, uvs.topLeft)
    renderPanelSlice(overlay, centerX, topY, centerW, cornerH, uvs.top)
    renderPanelSlice(overlay, rightX, topY, cornerW, cornerH, uvs.topRight)
end

function RHMDraggableHUD:drawRect(x, y, w, h, r, g, b, a)
    if not self.rectOverlay then return end
    self.rectOverlay:setPosition(x, y)
    self.rectOverlay:setDimension(w, h)
    self.rectOverlay:setColor(r, g, b, a or 1.0)
    self.rectOverlay:render()
end

function RHMDraggableHUD:drawBorder(x, y, w, h, r, g, b, a, thickness)
    local t = thickness or (0.0010 * (self.uiScale or 1.0))
    self:drawRect(x, y, w, t, r, g, b, a)
    self:drawRect(x, y + h - t, w, t, r, g, b, a)
    self:drawRect(x, y + t, t, h - 2 * t, r, g, b, a)
    self:drawRect(x + w - t, y + t, t, h - 2 * t, r, g, b, a)
end

function RHMDraggableHUD:drawDockSnapPlaceholder(dockX, dockY, dockW, dockH)
    if not self.roundedOverlay or not self.roundedUVs then return end

    local uiScale = self.uiScale or 1.0
    local padX = 0.0035 * uiScale
    local padY = 0.0025 * uiScale
    local slotX = dockX - padX
    local slotY = dockY - padY
    local slotW = dockW + (padX * 2)
    local slotH = (dockH or self.height) + (padY * 2)

    local greenBase = (RHM_UIColors and RHM_UIColors.GREEN) or {0.61, 0.85, 0.15, 1.0}
    local pulse = 0.85 + 0.15 * math.sin((g_time or 0) * 0.008)
    local r = greenBase[1] * pulse
    local g = greenBase[2] * pulse
    local b = greenBase[3] * pulse

    -- 1. Outer rounded rectangle in magnetic green
    SNAP_OUTER_COLOR[1] = r
    SNAP_OUTER_COLOR[2] = g
    SNAP_OUTER_COLOR[3] = b
    self:drawPanelBackground(slotX, slotY, slotW, slotH, SNAP_OUTER_COLOR)

    -- 2. Inner rounded cutout (creates a crisp rounded outline with soft glowing fill)
    local thickness = 0.0012 * uiScale
    local inX = slotX + thickness
    local inY = slotY + thickness
    local inW = slotW - (thickness * 2)
    local inH = slotH - (thickness * 2)
    self:drawPanelBackground(inX, inY, inW, inH, DOCK_INNER_BG)
end

function RHMDraggableHUD:draw()
    if not g_currentMission:getIsClient() then return end
    if not self.settings.showHUD then return end
    if not self.vehicle then return end

    if not self.roundedOverlay then
        self:load()
    end
    if not self.roundedOverlay then return end

    -- Update docked coordinates dynamically each frame to track F1 toggle & PF movement
    local hudStyle = (self.settings and self.settings.hudStyle) or 2
    local expectedHeight = (hudStyle == 2 and 0.082 or 0.042) * self.uiScale
    if math.abs(self.height - expectedHeight) > 0.001 then
        self:updateLayout()
    end

    local dockX, dockY, dockW = self:getDockedPosition()
    self.width = dockW

    if not self.isDragging then
        if self.settings and self.settings.hudPosX ~= nil and self.settings.hudPosY ~= nil then
            self.x = self.settings.hudPosX
            self.y = self.settings.hudPosY
            self.isSnapped = false
        else
            self.x = dockX
            self.y = dockY
            self.isSnapped = true
        end
    end

    -- 1. If currently dragging AND in auto-snap zone: illuminate the target dock slot with rounded outline
    if self.isDragging and self.hasMoved and self.isNearDock then
        self:drawDockSnapPlaceholder(dockX, dockY, dockW, self.height)
    end

    local x = self.x
    local y = self.y
    local w = self.width
    local h = self.height

    -- 2. Authentic FS25 Translucent Rounded Background for HUD
    self:drawPanelBackground(x, y, w, h, HUD_BG_COLOR)

    -- ── Render Stacked Cells ──────────────────────────────────────────────
    local cells = self.cachedCells or self:buildActiveCells()
    local numCells = #cells
    if numCells == 0 then return end

    if hudStyle == 1 then
        -- Compact 1-row rendering (cells 1 to 4)
        local cellW = w / math.max(1, numCells)
        local borderW = 0.0006
        local iconH = 0.022 * self.uiScale
        local iconW = iconH / g_screenAspectRatio
        local numTextSize  = 0.0145 * self.uiScale
        local unitTextSize = 0.0078 * self.uiScale

        local currentX = x
        for i, cell in ipairs(cells) do
            local cellEndX = currentX + cellW
            if i < numCells then
                self:drawRect(cellEndX - borderW, y + 0.007 * self.uiScale, borderW, h - 0.014 * self.uiScale, 1.0, 1.0, 1.0, 0.12)
            end
            self:renderCell(cell, currentX, y, cellW, h, iconW, iconH, numTextSize, unitTextSize, cellEndX)
            currentX = cellEndX
        end
    else
        -- Expanded 2-row rendering (Row 1: cells 1..4, Row 2: cells 5..8)
        local rowH = h * 0.5
        local cols = 4
        local cellW = w / cols
        local borderW = 0.0006
        local iconH = 0.020 * self.uiScale
        local iconW = iconH / g_screenAspectRatio
        local numTextSize  = 0.0135 * self.uiScale
        local unitTextSize = 0.0075 * self.uiScale

        -- Horizontal divider between Row 1 and Row 2
        local midY = y + rowH
        self:drawRect(x + 0.006 * self.uiScale, midY - borderW * 0.5, w - 0.012 * self.uiScale, borderW, 1.0, 1.0, 1.0, 0.12)

        -- Row 1: Machine & Field Conditions (cells 1 to 4)
        local row1Y = midY
        local curX = x
        for c = 1, cols do
            local cell = cells[c]
            local cellEndX = curX + cellW
            if c < cols then
                self:drawRect(cellEndX - borderW, row1Y + 0.004 * self.uiScale, borderW, rowH - 0.008 * self.uiScale, 1.0, 1.0, 1.0, 0.12)
            end
            if cell then
                self:renderCell(cell, curX, row1Y, cellW, rowH, iconW, iconH, numTextSize, unitTextSize, cellEndX)
            end
            curX = cellEndX
        end

        -- Row 2: Yield & Production Monitor (cells 5 to 8)
        local row2Y = y
        curX = x
        for c = 1, cols do
            local cell = cells[4 + c]
            local cellEndX = curX + cellW
            if c < cols then
                self:drawRect(cellEndX - borderW, row2Y + 0.004 * self.uiScale, borderW, rowH - 0.008 * self.uiScale, 1.0, 1.0, 1.0, 0.12)
            end
            if cell then
                self:renderCell(cell, curX, row2Y, cellW, rowH, iconW, iconH, numTextSize, unitTextSize, cellEndX)
            end
            curX = cellEndX
        end
    end

    local spec = self.vehicle and self.vehicle.spec_rhm_Combine
    if spec and spec.resetHoldProgress and spec.resetHoldProgress > 0 then
        local barH = 0.005 * self.uiScale
        local barY = y - barH - (0.001 * self.uiScale)
        local barW = w
        self:drawRect(x, barY, barW, barH, 0.1, 0.1, 0.1, 0.85)
        self:drawRect(x, barY, barW * spec.resetHoldProgress, barH, 0.55, 0.72, 0.0, 0.95)
    end

    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function RHMDraggableHUD:renderCell(cell, cellX, cellY, cellW, cellH, iconW, iconH, numTextSize, unitTextSize, cellEndX)
    -- Icon (vertically centered on the left of cell)
    local icon = self.icons[cell.iconName]
    local iconX = cellX + 0.0022 * self.uiScale
    local iconY = cellY + (cellH - iconH) * 0.50
    if icon then
        icon:setPosition(iconX, iconY)
        icon:setDimension(iconW, iconH)
        icon:setColor(1.0, 1.0, 1.0, 0.95)
        icon:render()
    end

    -- Two-line stacked typography: number on top, unit on bottom (or centered if no unit)
    local textX = iconX + iconW + 0.0020 * self.uiScale
    local hasUnit = (cell.unitStr and cell.unitStr ~= "")
    local currentNumSize = (cell.numStr and #cell.numStr >= 5) and (numTextSize * 0.93) or numTextSize
    local topY = hasUnit and (cellY + cellH * 0.49) or (cellY + (cellH - currentNumSize) * 0.50 + 0.0010 * self.uiScale)
    local botY = cellY + cellH * 0.17

    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    if cell.color then
        setTextColor(cell.color[1], cell.color[2], cell.color[3], cell.color[4] or 0.98)
    else
        setTextColor(0.98, 0.98, 0.98, 0.98)
    end
    renderText(textX, topY, currentNumSize, cell.numStr)

    if hasUnit then
        if cell.rankColor and cell.unitStr and cell.unitStr:sub(1, 1) == "[" then
            local closeIdx = cell.unitStr:find("%]")
            if closeIdx then
                local rankPart = cell.unitStr:sub(1, closeIdx)
                local restPart = cell.unitStr:sub(closeIdx + 1)
                restPart = restPart:match("^%s*(.-)$") or restPart
                local rankTextSize = unitTextSize
                setTextBold(true)
                setTextColor(cell.rankColor[1], cell.rankColor[2], cell.rankColor[3], 1.0)
                renderText(textX, botY, rankTextSize, rankPart)
                local grayCol = (RHM_UIColors and RHM_UIColors.GRAY) or {0.65, 0.68, 0.72, 1.0}
                local rkW = (getTextWidth and getTextWidth(rankTextSize, rankPart)) or (0.0070 * self.uiScale)
                setTextBold(false)
                setTextColor(grayCol[1], grayCol[2], grayCol[3], 0.90)
                renderText(textX + rkW + (0.0012 * self.uiScale), botY, rankTextSize, restPart)
            else
                local grayCol = (RHM_UIColors and RHM_UIColors.GRAY) or {0.65, 0.68, 0.72, 1.0}
                setTextBold(false)
                setTextColor(grayCol[1], grayCol[2], grayCol[3], 0.90)
                renderText(textX, botY, unitTextSize, cell.unitStr)
            end
        else
            local grayCol = (RHM_UIColors and RHM_UIColors.GRAY) or {0.65, 0.68, 0.72, 1.0}
            setTextBold(false)
            setTextColor(grayCol[1], grayCol[2], grayCol[3], 0.90)
            renderText(textX, botY, unitTextSize, cell.unitStr)
        end
    end

    -- Dynamic Colored Underline Indicator (exact PF style: centered under text, strictly contained in cell)
    if cell.indicatorColor then
        local numW = (getTextWidth and getTextWidth(currentNumSize, cell.numStr)) or (0.018 * self.uiScale)
        local indX = textX
        local maxIndW = math.max(0.008 * self.uiScale, cellEndX - indX - 0.0020 * self.uiScale)
        local indW = math.min(math.max(0.014 * self.uiScale, numW), maxIndW)
        local indH = 0.0020 * self.uiScale
        local indY = cellY + 0.0030 * self.uiScale
        local c = cell.indicatorColor
        self:drawRect(indX, indY, indW, indH, c[1], c[2], c[3], c[4] or 0.95)
    end
end

function RHMDraggableHUD:buildActiveCells()
    local cells = {}
    local hudStyle = (self.settings and self.settings.hudStyle) or 2
    local unitSystem = (RHM_UnitConverter and RHM_UnitConverter.getActiveSystem and RHM_UnitConverter.getActiveSystem()) or (self.settings and self.settings.unitSystem) or 1
    local fruitType = nil
    if self.vehicle and self.vehicle.spec_combine then
        fruitType = self.vehicle.spec_combine.lastValidInputFruitType
    end

    local machineType = nil
    local packageLevel = 1
    if self.vehicle and self.vehicle.spec_rhm_Combine then
        machineType = self.vehicle.spec_rhm_Combine.machineType
        packageLevel = self.vehicle.spec_rhm_Combine.packageLevel or 1
    end

    local farmId = (self.vehicle and self.vehicle.getOwnerFarmId and self.vehicle:getOwnerFarmId()) or 1
    local trip = (self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.trip)
    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if not trip and tracker and self.vehicle then
        local farm = tracker:getFarmData(farmId)
        if farm and farm.combineTrips then
            local machineKey = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(self.vehicle)) or self.vehicle.configFileName or (self.vehicle.getFullName and self.vehicle:getFullName()) or "Harvester"
            trip = farm.combineTrips[machineKey]
        end
        trip = trip or (farm and farm.currentTrip)
    end

    local function rhm_getLocalizedUnit(unitKey)
        if not unitKey or unitKey == "" then return "" end
        local lang = g_languageShort or (g_i18n and g_i18n.languageShort) or "en"
        if lang == "uk" then
            if unitKey == "t/ha" then return "т/га"
            elseif unitKey == "t/h" then return "т/год"
            elseif unitKey == "ha/h" then return "га/год"
            elseif unitKey == "km/h" then return "км/год"
            elseif unitKey == "kg/s" then return "кг/с"
            elseif unitKey == "lbs/s" then return "фунт/с"
            elseif unitKey == "bu/min" then return "буш/хв"
            elseif unitKey == "bu/h" then return "буш/год"
            elseif unitKey == "bu/ac" then return "буш/акр"
            elseif unitKey == "ac/h" then return "акр/год"
            elseif unitKey == "t" then return "т"
            elseif unitKey == "ha" then return "га"
            elseif unitKey == "ac" then return "акр"
            elseif unitKey == "bu" then return "буш"
            elseif unitKey == "kL" then return "кЛ"
            elseif unitKey == "L" then return "л"
            elseif unitKey == "h" then return "год"
            elseif unitKey == "min" then return "хв"
            elseif unitKey == "HP" then return "к.с."
            end
        elseif lang == "ru" then
            if unitKey == "t/ha" then return "т/га"
            elseif unitKey == "t/h" then return "т/ч"
            elseif unitKey == "ha/h" then return "га/ч"
            elseif unitKey == "km/h" then return "км/ч"
            elseif unitKey == "kg/s" then return "кг/с"
            elseif unitKey == "lbs/s" then return "фунт/с"
            elseif unitKey == "bu/min" then return "буш/мин"
            elseif unitKey == "bu/h" then return "буш/ч"
            elseif unitKey == "bu/ac" then return "буш/акр"
            elseif unitKey == "ac/h" then return "акр/ч"
            elseif unitKey == "t" then return "т"
            elseif unitKey == "ha" then return "га"
            elseif unitKey == "ac" then return "акр"
            elseif unitKey == "bu" then return "буш"
            elseif unitKey == "kL" then return "кЛ"
            elseif unitKey == "L" then return "л"
            elseif unitKey == "h" then return "ч"
            elseif unitKey == "min" then return "мин"
            elseif unitKey == "HP" then return "л.с."
            end
        end
        if unitKey == "t/h" and g_i18n and g_i18n:hasText("rhm_unit_t_per_hour") then
            return g_i18n:getText("rhm_unit_t_per_hour")
        elseif unitKey == "ha/h" and g_i18n and g_i18n:hasText("rhm_unit_ha_per_hour") then
            return g_i18n:getText("rhm_unit_ha_per_hour")
        end
        return unitKey
    end

    local tripRank = nil
    local tripRankColor = nil
    local tripLossSubStr = nil
    local tripHarvestSubStr = nil
    local tripAreaSubStr = nil
    local tripAreaHa = (trip and trip.harvestedAreaHa) or 0
    local tripLiters = (trip and trip.harvestedLiters) or 0
    local tripMassKg = (trip and trip.harvestedMassKg) or (tripLiters * 0.75)
    local tripTons = tripMassKg * 0.001
    local tripDuration = (trip and trip.sessionDuration) or 0

    if trip and tripLiters > 0 then
        local rk = trip.efficiencyRank or "A"
        tripRank = rk
        tripRankColor = (RHM_UIColors and RHM_UIColors.getRankColor and RHM_UIColors.getRankColor(rk)) or {0.61, 0.85, 0.15, 1.0}

        local totalBio = tripLiters + (trip.lostLiters or 0)
        local tripLossPct = (totalBio > 0) and (((trip.lostLiters or 0) / totalBio) * 100.0) or 0
        tripLossSubStr = string.format("[%s] %.1f%%", rk, tripLossPct)

        if RHM_UnitConverter and RHM_UnitConverter.convertMass then
            local val, suffix = RHM_UnitConverter.convertMass(tripTons, unitSystem, fruitType, tripLiters)
            local locSuffix = rhm_getLocalizedUnit(suffix)
            if suffix == "bu" then
                tripHarvestSubStr = string.format("%.0f %s", val, locSuffix)
            else
                tripHarvestSubStr = string.format("%.1f %s", val, locSuffix)
            end
        else
            tripHarvestSubStr = string.format("%.1f %s", tripTons, rhm_getLocalizedUnit("t"))
        end

        if tripAreaHa > 0.005 then
            if RHM_UnitConverter and RHM_UnitConverter.convertArea then
                local val, suffix = RHM_UnitConverter.convertArea(tripAreaHa, unitSystem)
                local locSuffix = rhm_getLocalizedUnit(suffix)
                tripAreaSubStr = string.format("%.1f %s", val, locSuffix)
            else
                tripAreaSubStr = string.format("%.1f %s", tripAreaHa, rhm_getLocalizedUnit("ha"))
            end
        end
    end

    local grayCol = (RHM_UIColors and RHM_UIColors.GRAY) or {0.65, 0.68, 0.72, 1.0}
    local d = self.displayData or self.data

    -- ── 1. Cell 1: Engine Load (% <-> HP) ───────────────────────────
    if self.settings.showLoad == false then
        table.insert(cells, {
            iconName = "load",
            numStr = "--",
            unitStr = "OFF",
            color = grayCol
        })
    else
        local loadVal = d.load or 0
        local loadColor, indColor = self:getLoadColors(loadVal)
        local mode1 = self.displayModes.cell1 or "load"
        if mode1 == "loadHp" then
            local calc = self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.loadCalculator
            local effHp = (calc and calc.lastEffectiveHp) or (calc and calc:getEnginePowerHp(self.vehicle)) or 0
            if effHp > 10 then
                local curHp = (loadVal / 100.0) * effHp
                local locHp = rhm_getLocalizedUnit("HP")
                table.insert(cells, {
                    iconName = "load",
                    numStr = string.format("%.0f", curHp),
                    unitStr = string.format("/ %.0f %s", effHp, locHp),
                    color = loadColor,
                    indicatorColor = indColor
                })
            else
                table.insert(cells, {
                    iconName = "load",
                    numStr = string.format("%.0f%%", loadVal),
                    unitStr = "",
                    color = loadColor,
                    indicatorColor = indColor
                })
            end
        else
            table.insert(cells, {
                iconName = "load",
                numStr = string.format("%.0f%%", loadVal),
                unitStr = "",
                color = loadColor,
                indicatorColor = indColor
            })
        end
    end

    -- ── 2. Cell 2: Speed OR Crop Loss ──────────────────────────────
    local isCropLossEnabled = (self.settings and self.settings.enableCropLoss ~= false)
    local hasLossSensor = (packageLevel >= 2) and (machineType ~= "forage" and machineType ~= "cotton")
    local canShowLoss = hasLossSensor and isCropLossEnabled and (self.settings and self.settings.showCropLoss ~= false)

    local mode2 = self.displayModes.cell2 or "loss"
    if mode2 == "loss" and not canShowLoss then
        mode2 = "speed"
    elseif mode2 ~= "loss" and mode2 ~= "speed" then
        mode2 = canShowLoss and "loss" or "speed"
    end

    if mode2 == "loss" then
        local lossVal = d.cropLoss or 0
        local lossStr = (lossVal > 0.05) and string.format("%.1f%%", lossVal) or "0.0%"
        local lossColor, indColor = self:getLossColors(lossVal)
        local lossUnit = tripLossSubStr or ""
        table.insert(cells, {
            iconName = "loss",
            numStr = lossStr,
            unitStr = lossUnit,
            rankColor = tripRankColor,
            color = lossColor,
            indicatorColor = indColor
        })
    else
        local curSpeed = d.speed or 0
        local targetSpeed = (d.recommendedSpeed and d.recommendedSpeed > 0) and d.recommendedSpeed or (d.targetSpeed or 0)
        local dispSpeed = curSpeed
        local speedUnit = "km/h"
        if RHM_UnitConverter then
            dispSpeed, speedUnit = RHM_UnitConverter.convertSpeed(curSpeed, unitSystem)
        end
        local locSpeedUnit = rhm_getLocalizedUnit(speedUnit)
        local unitText = locSpeedUnit
        if targetSpeed and targetSpeed > 0.5 then
            local dispTarget = targetSpeed
            if RHM_UnitConverter then
                dispTarget = RHM_UnitConverter.convertSpeed(targetSpeed, unitSystem)
            end
            unitText = string.format("/ %.1f %s", dispTarget, locSpeedUnit)
        end
        table.insert(cells, {
            iconName = "speed",
            numStr = string.format("%.1f", dispSpeed),
            unitStr = unitText,
            color = {0.98, 0.98, 0.98, 1.0}
        })
    end

    -- ── 3. Cell 3: Moisture (Compact: Moisture <-> Weed; Expanded: Moisture)
    local isWeedLoadEnabled = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableWeedLoad ~= false)
    local areWeedsInGame = (g_currentMission and g_currentMission.missionInfo and g_currentMission.missionInfo.weedsEnabled ~= false)
    local canShowWeeds = isWeedLoadEnabled and areWeedsInGame and (self.settings and self.settings.showWeeds ~= false)
    local canShowMoisture = (self.settings and self.settings.showMoisture ~= false)

    if hudStyle == 1 then
        -- Compact Mode: Cell 3 toggles between moisture and weed
        local mode3 = self.displayModes.cell3 or "moisture"
        if mode3 == "weed" and not canShowWeeds then
            mode3 = "moisture"
        elseif mode3 == "moisture" and not canShowMoisture then
            mode3 = canShowWeeds and "weed" or "moisture"
        end

        if mode3 == "weed" then
            local wVal = (d.weedRatio or 0) * 100
            local valStr = (wVal <= 0.05) and "0.0%" or string.format("%.1f%%", wVal)
            local whiteCol = (RHM_UIColors and RHM_UIColors.WHITE) or {1.0, 1.0, 1.0, 1.0}
            local greenCol = (RHM_UIColors and RHM_UIColors.GREEN) or {0.61, 0.85, 0.15, 1.0}
            local yellowCol = (RHM_UIColors and RHM_UIColors.YELLOW) or {0.95, 0.85, 0.12, 1.0}
            local redCol = (RHM_UIColors and RHM_UIColors.RED) or {0.96, 0.22, 0.20, 1.0}

            local textColor = whiteCol
            local indColor = greenCol
            if wVal > 20 then
                textColor = redCol
                indColor = redCol
            elseif wVal > 5 then
                textColor = whiteCol
                indColor = yellowCol
            end
            table.insert(cells, {
                iconName = "weed",
                numStr = valStr,
                unitStr = "",
                color = textColor,
                indicatorColor = indColor
            })
        else
            local mVal = d.moisture or 0
            local valStr = (mVal <= 0.1) and "--" or string.format("%.1f%%", mVal)
            local mColor = {0.98, 0.98, 0.98, 1.0}
            local indColor = nil
            if mVal > 0.1 then
                if mVal > 20 then
                    mColor = {0.95, 0.28, 0.28, 1.0}
                    indColor = {0.95, 0.28, 0.28, 1.0}
                elseif mVal > 14 then
                    mColor = {0.98, 0.75, 0.20, 1.0}
                    indColor = {0.95, 0.80, 0.20, 0.95}
                else
                    mColor = {0.45, 0.80, 0.98, 1.0}
                    indColor = {0.35, 0.75, 0.98, 0.95}
                end
            end
            table.insert(cells, {
                iconName = "moisture",
                numStr = valStr,
                unitStr = "",
                color = mColor,
                indicatorColor = indColor
            })
        end

    else
        -- Expanded Mode: Cell 3 is Dedicated Moisture
        if not canShowMoisture then
            table.insert(cells, {
                iconName = "moisture",
                numStr = "--",
                unitStr = "OFF",
                color = grayCol
            })
        else
            local mVal = d.moisture or 0
            local valStr = (mVal <= 0.1) and "--" or string.format("%.1f%%", mVal)
            local mColor = {0.98, 0.98, 0.98, 1.0}
            local indColor = nil
            local statusStr = ""
            if mVal > 0.1 then
                if mVal > 20 then
                    mColor = {0.95, 0.28, 0.28, 1.0}
                    indColor = {0.95, 0.28, 0.28, 1.0}
                    statusStr = "WET"
                elseif mVal > 14 then
                    mColor = {0.98, 0.75, 0.20, 1.0}
                    indColor = {0.95, 0.80, 0.20, 0.95}
                    statusStr = "DAMP"
                else
                    mColor = {0.45, 0.80, 0.98, 1.0}
                    indColor = {0.35, 0.75, 0.98, 0.95}
                    statusStr = "OPT"
                end
            end
            local unitLabel = (self.displayModes.cell3 == "moistureStatus" and mVal > 0.1) and statusStr or ""
            table.insert(cells, {
                iconName = "moisture",
                numStr = valStr,
                unitStr = unitLabel,
                color = mColor,
                indicatorColor = indColor
            })
        end
    end

    -- ── 4. Cell 4: Compact Mode: Production; Expanded Mode: Weeds ───
    if hudStyle == 1 then
        -- Compact Mode: Cycle Yield <-> Throughput <-> Work Rate
        local mode4 = self.displayModes.cell4 or "yield"
        if mode4 == "hectaresPerHour" then
            local haVal = d.hectaresPerHour or 0
            local dispArea = haVal
            local areaUnit = "ha/h"
            if RHM_UnitConverter and RHM_UnitConverter.convertArea then
                local areaVal, areaSuffix = RHM_UnitConverter.convertArea(haVal, unitSystem)
                dispArea = areaVal
                areaUnit = areaSuffix .. "/h"
            end
            local isStationary = (d.speed or 0) < 0.5
            local valStr = (isStationary or dispArea <= 0.05) and "0.0" or string.format("%.1f", dispArea)
            local locAreaUnit = rhm_getLocalizedUnit(areaUnit)
            local unitLabel = locAreaUnit
            if tripAreaSubStr then
                unitLabel = string.format("%s | %s", locAreaUnit, tripAreaSubStr)
            end
            table.insert(cells, {
                iconName = "area_rate",
                numStr = valStr,
                unitStr = unitLabel,
                color = {0.98, 0.98, 0.98, 1.0}
            })
        elseif mode4 == "tonPerHour" then
            local prodVal = d.tonPerHour or 0
            local isStationary = (d.speed or 0) < 0.5
            local valStr, suffixStr
            if RHM_UnitConverter and RHM_UnitConverter.convertProductivity then
                local val, suffix = RHM_UnitConverter.convertProductivity(prodVal, unitSystem, fruitType, d.litersPerHour)
                valStr = (isStationary or prodVal <= 0.05) and "0.0" or string.format("%.1f", val)
                suffixStr = suffix or "t/h"
            else
                valStr = (isStationary or prodVal <= 0.05) and "0.0" or string.format("%.1f", prodVal)
                suffixStr = "t/h"
            end
            local locProdUnit = rhm_getLocalizedUnit(suffixStr)
            local unitLabel = locProdUnit
            if tripHarvestSubStr then
                unitLabel = string.format("%s | %s", locProdUnit, tripHarvestSubStr)
            end
            table.insert(cells, {
                iconName = "productivity",
                numStr = valStr,
                unitStr = unitLabel,
                color = {0.98, 0.98, 0.98, 1.0}
            })
        else
            local yieldVal = d.yield or 0
            local valStr, suffixStr
            if RHM_UnitConverter and RHM_UnitConverter.convertYield then
                local val, suffix = RHM_UnitConverter.convertYield(yieldVal, unitSystem, fruitType)
                valStr = string.format("%.1f", val)
                suffixStr = suffix or "t/ha"
            else
                valStr = string.format("%.1f", yieldVal)
                suffixStr = "t/ha"
            end
            local locYieldUnit = rhm_getLocalizedUnit(suffixStr)
            local unitLabel = locYieldUnit
            if tripHarvestSubStr then
                unitLabel = string.format("%s | %s", locYieldUnit, tripHarvestSubStr)
            end
            table.insert(cells, {
                iconName = "yield",
                numStr = valStr,
                unitStr = unitLabel,
                color = {0.98, 0.98, 0.98, 1.0}
            })
        end

    else
        -- Expanded Mode: Cell 4 is Dedicated Weeds
        if not canShowWeeds then
            table.insert(cells, {
                iconName = "weed",
                numStr = "--",
                unitStr = "OFF",
                color = grayCol
            })
        else
            local wVal = (d.weedRatio or 0) * 100
            local whiteCol = (RHM_UIColors and RHM_UIColors.WHITE) or {1.0, 1.0, 1.0, 1.0}
            local greenCol = (RHM_UIColors and RHM_UIColors.GREEN) or {0.61, 0.85, 0.15, 1.0}
            local yellowCol = (RHM_UIColors and RHM_UIColors.YELLOW) or {0.95, 0.85, 0.12, 1.0}
            local redCol = (RHM_UIColors and RHM_UIColors.RED) or {0.96, 0.22, 0.20, 1.0}

            local textColor = whiteCol
            local indColor = greenCol
            if wVal > 20 then
                textColor = redCol
                indColor = redCol
            elseif wVal > 5 then
                textColor = whiteCol
                indColor = yellowCol
            end

            local valStr = (wVal <= 0.05) and "0.0%" or string.format("%.1f%%", wVal)
            local unitLabel = ""
            if self.displayModes.cell4_weed == "weedDrag" then
                local dragPct = math.min(25.0, (d.weedRatio or 0) * 25.0)
                valStr = string.format("+%.1f%%", dragPct)
                unitLabel = "DRAG"
            end

            table.insert(cells, {
                iconName = "weed",
                numStr = valStr,
                unitStr = unitLabel,
                color = textColor,
                indicatorColor = indColor
            })
        end
    end

    -- ── If Compact Mode, we're done with 4 cells! ────────────────────
    if hudStyle == 1 then
        return cells
    end

    -- ══════════════════════════════════════════════════════════════════
    -- ── EXPANDED MODE: ROW 2 (CELLS 5 to 8) ──────────────────────────
    -- ══════════════════════════════════════════════════════════════════

    -- ── 5. Cell 5: Flow Rate / Caudal (kg/s <-> t/h) ────────────────
    if self.settings.showProductivity == false then
        table.insert(cells, {
            iconName = "productivity",
            numStr = "--",
            unitStr = "OFF",
            color = grayCol
        })
    else
        local tph = d.tonPerHour or 0
        local isStationary = (d.speed or 0) < 0.5
        local mode5 = self.displayModes.cell5 or "flowRate"

        if mode5 == "tonPerHour" then
            local val, suffix = RHM_UnitConverter.convertProductivity(tph, unitSystem, fruitType, d.litersPerHour)
            local valStr = (isStationary or tph <= 0.05) and "0.0" or string.format("%.1f", val)
            local unitLabel = rhm_getLocalizedUnit(suffix or "t/h")
            table.insert(cells, {
                iconName = "productivity",
                numStr = valStr,
                unitStr = unitLabel,
                color = {0.98, 0.98, 0.98, 1.0}
            })
        else
            local val, suffix = RHM_UnitConverter.convertFlowRate(tph, unitSystem, fruitType, d.litersPerHour)
            local valStr = (isStationary or tph <= 0.05) and "0.0" or string.format("%.1f", val)
            local unitLabel = rhm_getLocalizedUnit(suffix or "kg/s")
            table.insert(cells, {
                iconName = "productivity",
                numStr = valStr,
                unitStr = unitLabel,
                color = {0.98, 0.98, 0.98, 1.0}
            })
        end
    end

    -- ── 6. Cell 6: Yield (Instantaneous <-> Session Average) ────────
    if self.settings.showYield == false then
        table.insert(cells, {
            iconName = "yield",
            numStr = "--",
            unitStr = "OFF",
            color = grayCol
        })
    else
        local mode6 = self.displayModes.cell6 or "yield"
        if mode6 == "avgYield" then
            local sessionAvgYieldTha = (tripAreaHa > 0.005 and tripMassKg > 0) and ((tripMassKg * 0.001) / tripAreaHa) or 0
            if sessionAvgYieldTha > 0.05 then
                local val, suffix = RHM_UnitConverter.convertYield(sessionAvgYieldTha, unitSystem, fruitType)
                local valStr = string.format("%.1f", val)
                local unitLabel = string.format("[AVG] %s", rhm_getLocalizedUnit(suffix or "t/ha"))
                table.insert(cells, {
                    iconName = "yield",
                    numStr = valStr,
                    unitStr = unitLabel,
                    rankColor = tripRankColor,
                    color = {0.98, 0.98, 0.98, 1.0}
                })
            else
                local _, suffix = RHM_UnitConverter.convertYield(1.0, unitSystem, fruitType)
                table.insert(cells, {
                    iconName = "yield",
                    numStr = "--",
                    unitStr = string.format("[AVG] %s", rhm_getLocalizedUnit(suffix or "t/ha")),
                    color = grayCol
                })
            end
        else
            local yieldVal = d.yield or 0
            local val, suffix = RHM_UnitConverter.convertYield(yieldVal, unitSystem, fruitType)
            local valStr = string.format("%.1f", val)
            local unitLabel = rhm_getLocalizedUnit(suffix or "t/ha")
            table.insert(cells, {
                iconName = "yield",
                numStr = valStr,
                unitStr = unitLabel,
                color = {0.98, 0.98, 0.98, 1.0}
            })
        end
    end

    -- ── 7. Cell 7: Area & Work Rate (Session Area + % <-> ha/h) ──────
    local mode7 = self.displayModes.cell7 or "area"
    if mode7 == "workRate" then
        local haVal = d.hectaresPerHour or 0
        local dispArea, areaSuffix = RHM_UnitConverter.convertArea(haVal, unitSystem)
        local isStationary = (d.speed or 0) < 0.5
        local valStr = (isStationary or haVal <= 0.05) and "0.0" or string.format("%.1f", dispArea)
        local unitLabel = rhm_getLocalizedUnit((areaSuffix or "ha") .. "/h")
        table.insert(cells, {
            iconName = "area_rate",
            numStr = valStr,
            unitStr = unitLabel,
            color = {0.98, 0.98, 0.98, 1.0}
        })
    else
        local val, suffix = RHM_UnitConverter.convertArea(tripAreaHa, unitSystem)
        local locSuffix = rhm_getLocalizedUnit(suffix or "ha")
        local valStr = (tripAreaHa > 0.005) and string.format("%.1f", val) or "0.0"
        local unitLabel = locSuffix

        local fid = (trip and (trip.masterFieldId or trip.fieldId)) or 0
        if fid > 0 and RHM_HarvestTracker and RHM_HarvestTracker.getFieldNominalAreaHa then
            local nomHa = RHM_HarvestTracker.getFieldNominalAreaHa(fid, nil, nil, farmId)
            if nomHa and nomHa > 0.05 and tripAreaHa > 0.005 then
                local pct = math.min(100.0, (tripAreaHa / nomHa) * 100.0)
                unitLabel = string.format("%s (%.0f%%)", locSuffix, pct)
            end
        end

        table.insert(cells, {
            iconName = "field",
            numStr = valStr,
            unitStr = unitLabel,
            color = {0.98, 0.98, 0.98, 1.0}
        })
    end

    -- ── 8. Cell 8: Clean Harvested Mass (t <-> Volume kL <-> Time) ──
    local mode8 = self.displayModes.cell8 or "mass"
    if mode8 == "volume" then
        local valStr = ""
        local unitLabel = ""
        if tripLiters >= 1000 then
            valStr = string.format("%.1f", tripLiters / 1000)
            unitLabel = rhm_getLocalizedUnit("kL")
        else
            valStr = string.format("%.0f", tripLiters)
            unitLabel = rhm_getLocalizedUnit("L")
        end
        table.insert(cells, {
            iconName = "trip",
            numStr = valStr,
            unitStr = unitLabel,
            color = {0.98, 0.98, 0.98, 1.0}
        })
    elseif mode8 == "time" then
        local valStr = ""
        local unitLabel = ""
        if tripDuration >= 3600 then
            local hrs = math.floor(tripDuration / 3600)
            local mins = math.floor((tripDuration % 3600) / 60)
            valStr = string.format("%d:%02d", hrs, mins)
            unitLabel = rhm_getLocalizedUnit("h")
        else
            local mins = math.floor(tripDuration / 60)
            local secs = math.floor(tripDuration % 60)
            valStr = string.format("%02d:%02d", mins, secs)
            unitLabel = rhm_getLocalizedUnit("min")
        end
        table.insert(cells, {
            iconName = "history",
            numStr = valStr,
            unitStr = unitLabel,
            color = {0.98, 0.98, 0.98, 1.0}
        })
    else
        local val, suffix = RHM_UnitConverter.convertMass(tripTons, unitSystem, fruitType, tripLiters)
        local locSuffix = rhm_getLocalizedUnit(suffix or "t")
        local valStr = (tripTons > 0.01) and ((suffix == "bu") and string.format("%.0f", val) or string.format("%.1f", val)) or "0.0"
        table.insert(cells, {
            iconName = "trip",
            numStr = valStr,
            unitStr = locSuffix,
            color = {0.98, 0.98, 0.98, 1.0}
        })
    end

    return cells
end

function RHMDraggableHUD:getLoadColors(load)
    local redCol = (RHM_UIColors and RHM_UIColors.RED) or {0.96, 0.22, 0.20, 1.0}
    local orangeCol = (RHM_UIColors and RHM_UIColors.ORANGE) or {0.98, 0.52, 0.10, 1.0}
    local yellowCol = (RHM_UIColors and RHM_UIColors.YELLOW) or {0.95, 0.85, 0.12, 1.0}
    local greenCol = (RHM_UIColors and RHM_UIColors.GREEN) or {0.61, 0.85, 0.15, 1.0}
    local whiteCol = (RHM_UIColors and RHM_UIColors.WHITE) or {1.0, 1.0, 1.0, 1.0}

    if load >= 105 then
        local pulse = 0.70 + 0.30 * math.sin((g_time or 0) * 0.012)
        local c = {redCol[1] * pulse, redCol[2] * pulse, redCol[3] * pulse, 1.0}
        return c, c
    elseif load >= 95 then
        return whiteCol, orangeCol
    elseif load >= 80 then
        return whiteCol, yellowCol
    else
        return whiteCol, greenCol
    end
end

function RHMDraggableHUD:getLossColors(loss)
    local redCol = (RHM_UIColors and RHM_UIColors.RED) or {0.96, 0.22, 0.20, 1.0}
    local orangeCol = (RHM_UIColors and RHM_UIColors.ORANGE) or {0.98, 0.52, 0.10, 1.0}
    local greenCol = (RHM_UIColors and RHM_UIColors.GREEN) or {0.61, 0.85, 0.15, 1.0}
    local whiteCol = (RHM_UIColors and RHM_UIColors.WHITE) or {1.0, 1.0, 1.0, 1.0}

    if loss > 3.0 then
        local pulse = 0.70 + 0.30 * math.sin((g_time or 0) * 0.012)
        local c = {redCol[1] * pulse, redCol[2] * pulse, redCol[3] * pulse, 1.0}
        return c, c
    elseif loss > 1.5 then
        return whiteCol, orangeCol
    else
        return whiteCol, greenCol
    end
end

function RHMDraggableHUD:isMouseOver(posX, posY)
    if not posX or not posY or not self.x or not self.y then return false end
    return posX >= self.x and posX <= (self.x + self.width) and
           posY >= self.y and posY <= (self.y + self.height)
end

function RHMDraggableHUD:handleCellClickCompact(clickedCol)
    local handled = false
    if clickedCol == 1 then
        local cur = self.displayModes.cell1 or "load"
        self.displayModes.cell1 = (cur == "load") and "loadHp" or "load"
        handled = true
    elseif clickedCol == 2 then
        local pkgLevel = (self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.packageLevel) or 1
        local mType = self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.machineType
        local isCropLossEnabled = (self.settings and self.settings.enableCropLoss ~= false)
        local canShowLoss = (pkgLevel >= 2) and (mType ~= "forage" and mType ~= "cotton") and isCropLossEnabled and (self.settings and self.settings.showCropLoss ~= false)

        local curMode = self.displayModes.cell2 or "loss"
        if curMode == "loss" then
            self.displayModes.cell2 = "speed"
        else
            self.displayModes.cell2 = canShowLoss and "loss" or "speed"
        end
        handled = true
    elseif clickedCol == 3 then
        local isWeedLoadEnabled = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableWeedLoad ~= false)
        local areWeedsInGame = (g_currentMission and g_currentMission.missionInfo and g_currentMission.missionInfo.weedsEnabled ~= false)
        local canShowWeeds = isWeedLoadEnabled and areWeedsInGame and (self.settings and self.settings.showWeeds ~= false)
        local canShowMoisture = (self.settings and self.settings.showMoisture ~= false)

        local curMode = self.displayModes.cell3 or "moisture"
        if curMode == "moisture" then
            self.displayModes.cell3 = canShowWeeds and "weed" or "moisture"
        else
            self.displayModes.cell3 = canShowMoisture and "moisture" or "weed"
        end
        handled = true
    elseif clickedCol == 4 then
        local curMode = self.displayModes.cell4 or "yield"
        if curMode == "yield" then
            self.displayModes.cell4 = "tonPerHour"
        elseif curMode == "tonPerHour" then
            self.displayModes.cell4 = "hectaresPerHour"
        else
            self.displayModes.cell4 = "yield"
        end
        handled = true
    end

    if handled then
        self.cachedCells = nil
        self.displayTimer = 9999
        return true
    end
    return false
end

function RHMDraggableHUD:handleCellClickExpanded(cellIndex)
    local handled = false
    if cellIndex == 1 then
        local cur = self.displayModes.cell1 or "load"
        self.displayModes.cell1 = (cur == "load") and "loadHp" or "load"
        handled = true
    elseif cellIndex == 2 then
        local pkgLevel = (self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.packageLevel) or 1
        local mType = self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.machineType
        local isCropLossEnabled = (self.settings and self.settings.enableCropLoss ~= false)
        local canShowLoss = (pkgLevel >= 2) and (mType ~= "forage" and mType ~= "cotton") and isCropLossEnabled and (self.settings and self.settings.showCropLoss ~= false)

        local curMode = self.displayModes.cell2 or "loss"
        if curMode == "loss" then
            self.displayModes.cell2 = "speed"
        else
            self.displayModes.cell2 = canShowLoss and "loss" or "speed"
        end
        handled = true
    elseif cellIndex == 3 then
        local cur = self.displayModes.cell3 or "moisture"
        self.displayModes.cell3 = (cur == "moisture") and "moistureStatus" or "moisture"
        handled = true
    elseif cellIndex == 4 then
        local cur = self.displayModes.cell4_weed or "weed"
        self.displayModes.cell4_weed = (cur == "weed") and "weedDrag" or "weed"
        handled = true
    elseif cellIndex == 5 then
        local cur = self.displayModes.cell5 or "flowRate"
        self.displayModes.cell5 = (cur == "flowRate") and "tonPerHour" or "flowRate"
        handled = true
    elseif cellIndex == 6 then
        local cur = self.displayModes.cell6 or "yield"
        self.displayModes.cell6 = (cur == "yield") and "avgYield" or "yield"
        handled = true
    elseif cellIndex == 7 then
        local cur = self.displayModes.cell7 or "area"
        self.displayModes.cell7 = (cur == "area") and "workRate" or "area"
        handled = true
    elseif cellIndex == 8 then
        local cur = self.displayModes.cell8 or "mass"
        if cur == "mass" then
            self.displayModes.cell8 = "volume"
        elseif cur == "volume" then
            self.displayModes.cell8 = "time"
        else
            self.displayModes.cell8 = "mass"
        end
        handled = true
    end

    if handled then
        self.cachedCells = nil
        self.displayTimer = 9999
        return true
    end
    return false
end

function RHMDraggableHUD:handleClickAt(posX, posY)
    local hudStyle = (self.settings and self.settings.hudStyle) or 2
    local w = self.width
    local h = self.height
    local cellW = w / 4
    local col = math.floor((posX - self.x) / cellW) + 1
    col = math.max(1, math.min(4, col))

    local handled = false
    if hudStyle == 1 then
        handled = self:handleCellClickCompact(col)
    else
        local isRow1 = (posY >= (self.y + h * 0.5))
        local cellIndex = isRow1 and col or (4 + col)
        handled = self:handleCellClickExpanded(cellIndex)
    end

    return handled
end

function RHMDraggableHUD:handleCellClick(clickedCol)
    local hudStyle = (self.settings and self.settings.hudStyle) or 2
    if hudStyle == 1 then
        return self:handleCellClickCompact(clickedCol)
    else
        return self:handleCellClickExpanded(clickedCol)
    end
end

function RHMDraggableHUD:mouseEvent(posX, posY, isDown, isUp, button)
    -- 1. Mouse Button Down (LMB): initiate drag or potential click
    local isLMB = (button == 1) or (Input and button == Input.MOUSE_BUTTON_LEFT)
    if isDown and isLMB then
        if self:isMouseOver(posX, posY) then
            self.isDragging = true
            self.dragStartX = posX
            self.dragStartY = posY
            self.dragInitialHudX = self.x
            self.dragInitialHudY = self.y
            self.hasMoved = false
            self.isNearDock = false
            self.clickPosX = posX
            self.clickPosY = posY
            return true
        end
    end

    -- 2. Ongoing Drag / Mouse Move
    if self.isDragging and not isUp then
        local dx = posX - self.dragStartX
        local dy = posY - self.dragStartY
        if math.abs(dx) > 0.003 or math.abs(dy) > 0.003 then
            self.hasMoved = true
        end

        if self.hasMoved then
            local rawX = self.dragInitialHudX + dx
            local rawY = self.dragInitialHudY + dy
            local screenMargin = 0.003
            rawX = math.max(screenMargin, math.min(1.0 - self.width - screenMargin, rawX))
            rawY = math.max(screenMargin, math.min(1.0 - self.height - screenMargin, rawY))

            local dockX, dockY, dockW = self:getDockedPosition()
            local uiScale = self.uiScale or 1.0
            local snapRadiusX = 0.048 * uiScale
            local snapRadiusY = ((self.settings and self.settings.hudStyle == 2) and 0.060 or 0.038) * uiScale

            if math.abs(rawX - dockX) <= snapRadiusX and math.abs(rawY - dockY) <= snapRadiusY then
                self.isNearDock = true
            else
                self.isNearDock = false
            end

            self.x = rawX
            self.y = rawY
        end
        return true
    end

    -- 3. Mouse Button Up (Release)
    if self.isDragging and isUp then
        self.isDragging = false
        if not self.hasMoved then
            -- Stationary click without drag: cycle cell metric with row & column detection
            self:handleClickAt(self.clickPosX or posX, self.clickPosY or posY)
        else
            -- Drag release: commit new position or snap back to automatic dock
            if self.isNearDock then
                self.isSnapped = true
                local dockX, dockY = self:getDockedPosition()
                self.x = dockX
                self.y = dockY
                if self.settings then
                    self.settings.hudPosX = nil
                    self.settings.hudPosY = nil
                end
            else
                self.isSnapped = false
                if self.settings then
                    self.settings.hudPosX = self.x
                    self.settings.hudPosY = self.y
                end
            end
            if g_realisticHarvestManager and g_realisticHarvestManager.settingsManager and self.settings then
                g_realisticHarvestManager.settingsManager:saveClientSettings(self.settings)
            end
        end
        self.hasMoved = false
        self.isNearDock = false
        return true
    end

    return false
end

function RHMDraggableHUD:delete()
    if self.rectOverlay then
        self.rectOverlay:delete()
        self.rectOverlay = nil
    end

    if self.bgTopOverlay then
        self.bgTopOverlay:delete()
        self.bgTopOverlay = nil
    end
    if self.bgMidOverlay then
        self.bgMidOverlay:delete()
        self.bgMidOverlay = nil
    end
    if self.bgBotOverlay then
        self.bgBotOverlay:delete()
        self.bgBotOverlay = nil
    end

    for _, icon in pairs(self.icons) do
        if icon then icon:delete() end
    end
    self.icons = {}

    rhm_log("RHM [UI]: RHMDraggableHUD unloaded")
end

return RHMDraggableHUD
