-- EN: Minimalist on-screen telemetry HUD for Realistic Harvesting.
--     Uses the authentic rounded capsule slices (ui_elements.dds) with 3-part border rendering.
--     Correctly tinted with dark obsidian glass color (0.028, 0.030, 0.036, 0.88).
--     Docks dynamically beneath the auxiliary combine telemetry bar or F1 ControlsHelp menu.
--     Dynamically tracks the F1 help menu toggle via g_gameSettings showHelpMenu.
--     Supports interactive click-to-cycle metrics (t/h <-> ha/h, Loss <-> Speed, Moisture <-> Yield).
-- UA: Мінімалістичний телеметричний HUD для Realistic Harvesting.
--     Використовує текстуру капсули (ui_elements.dds) з 3-компонентними заокругленими кутами.
--     Тонований у глибокий колір темного скла (0.028, 0.030, 0.036, 0.88).
--     Приліпає динамічно під смугу додаткової телеметрії комбайна або меню довідки F1 (ControlsHelp).
--     Динамічно відстежує відкриття/закриття F1 через g_gameSettings showHelpMenu.
--     Підтримує інтерактивне перемикання показників кліком (т/ч <-> га/ч, Втрати <-> Швидкість, Волога <-> Урожайність).

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

    self.displayModes = {
        cell1 = "load",
        cell2 = "loss",
        cell3 = "moisture",
        cell4 = "tonPerHour"
    }

    self.uiScale = 1.0
    self.width = 0.172
    self.height = 0.042

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

    self.height = 0.042 * self.uiScale
    self.width  = 0.172 * self.uiScale

    -- 1. Load authentic FS25 rounded panel texture
    if not self.roundedOverlay then
        local panelTexturePath = self.modDirectory .. "textures/panelRounded.dds"
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
    end

    -- 2. Solid 1x1 overlay for dividers and underline indicators
    self.iconAtlasPath = self.modDirectory .. "textures/hud_icons.dds"
    self.bgUVs = GuiUtils.getUVs({388, 4, 56, 56}, {512, 64})
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

function RHMDraggableHUD:loadIcons(uiScale)
    self.height = 0.042 * self.uiScale
    self.width  = 0.172 * self.uiScale

    local iconHeight = 0.024 * self.uiScale
    local iconWidth  = iconHeight / g_screenAspectRatio

    local atlasPath = self.iconAtlasPath or (self.modDirectory .. "textures/hud_icons.dds")
    local atlasSize = {512, 64}
    local iconPx = 64

    local iconDefs = {
        load         = {0,     0, iconPx, iconPx},
        yield        = {64,    0, iconPx, iconPx},
        productivity = {128,   0, iconPx, iconPx},
        moisture     = {192,   0, iconPx, iconPx},
        loss         = {256,   0, iconPx, iconPx},
        speed        = {320,   0, iconPx, iconPx}
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
    local defaultW = 0.172 * uiScale

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
    self.vehicle = vehicle
    if vehicle then
        self:update(0)
    else
        self.data.load = 0
        self.data.yield = 0
        self.data.speed = 0
        self.data.cropLoss = 0
        self.data.tonPerHour = 0
        self.data.litersPerHour = 0
        self.data.recommendedSpeed = 0
        self.data.moisture = 0
        self.data.hectaresPerHour = 0
    end
end

function RHMDraggableHUD:update(dt)
    local vehicle = self.vehicle
    if not vehicle then return end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.data then return end

    self.data.load             = spec.data.load or 0
    self.data.yield            = spec.data.yield or 0
    self.data.cropLoss         = spec.data.cropLoss or 0
    self.data.tonPerHour       = spec.data.tonPerHour or 0
    self.data.litersPerHour    = spec.data.litersPerHour or 0
    self.data.recommendedSpeed = spec.data.recommendedSpeed or 0
    self.data.targetSpeed      = spec.data.targetSpeed or spec.data.recommendedSpeed or 0
    self.data.moisture         = spec.data.moisture or 0
    self.data.hectaresPerHour  = spec.data.hectaresPerHour or 0
    self.data.speed            = vehicle:getLastSpeed() or 0
end

function RHMDraggableHUD:drawPanelBackground(x, y, w, h, color)
    if not self.roundedOverlay or not self.roundedUVs then return end

    local c = color or {0.0, 0.0, 0.0, 0.72}
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

    local pulse = 0.85 + 0.15 * math.sin((g_time or 0) * 0.008)
    local r = 0.529 * pulse
    local g = 0.706 * pulse
    local b = 0.0

    -- 1. Outer rounded rectangle in magnetic green
    self:drawPanelBackground(slotX, slotY, slotW, slotH, {r, g, b, 0.88})

    -- 2. Inner rounded cutout (creates a crisp rounded outline with soft glowing fill)
    local thickness = 0.0012 * uiScale
    local inX = slotX + thickness
    local inY = slotY + thickness
    local inW = slotW - (thickness * 2)
    local inH = slotH - (thickness * 2)
    self:drawPanelBackground(inX, inY, inW, inH, {0.04, 0.08, 0.02, 0.60})
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
    self:drawPanelBackground(x, y, w, h, {0.0, 0.0, 0.0, 0.72})

    -- ── Build 4-Column PF-Style Stacked Cells ───────────────────────────────
    local cells = self:buildActiveCells()
    local numCells = #cells
    if numCells == 0 then return end

    local cellW = w / numCells
    local borderW = 0.0006

    local iconH = 0.024 * self.uiScale
    local iconW = iconH / g_screenAspectRatio
    local numTextSize  = 0.0150 * self.uiScale
    local unitTextSize = 0.0085 * self.uiScale

    local currentX = x
    for i, cell in ipairs(cells) do
        local cellEndX = currentX + cellW

        -- Thin vertical divider between cells (exact PF style)
        if i < numCells then
            self:drawRect(cellEndX - borderW, y + 0.007 * self.uiScale, borderW, h - 0.014 * self.uiScale, 1.0, 1.0, 1.0, 0.12)
        end

        -- Icon (vertically centered on the left of cell)
        local icon = self.icons[cell.iconName]
        local iconX = currentX + 0.0035 * self.uiScale
        local iconY = y + (h - iconH) * 0.50
        if icon then
            icon:setPosition(iconX, iconY)
            icon:setDimension(iconW, iconH)
            icon:setColor(1.0, 1.0, 1.0, 0.95)
            icon:render()
        end

        -- Two-line stacked typography: number on top, unit on bottom (or centered if no unit)
        local textX = iconX + iconW + 0.0030 * self.uiScale
        local hasUnit = (cell.unitStr and cell.unitStr ~= "")
        local topY = hasUnit and (y + h * 0.44) or (y + (h - numTextSize) * 0.54)
        local botY = y + h * 0.13

        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_LEFT)
        if cell.color then
            setTextColor(cell.color[1], cell.color[2], cell.color[3], cell.color[4] or 0.98)
        else
            setTextColor(0.98, 0.98, 0.98, 0.98)
        end
        renderText(textX, topY, numTextSize, cell.numStr)

        if hasUnit then
            setTextBold(false)
            setTextColor(0.72, 0.74, 0.78, 0.90)
            renderText(textX, botY, unitTextSize, cell.unitStr)
        end

        -- Dynamic Colored Underline Indicator (exact PF style: centered under text)
        if cell.indicatorColor then
            local indW = 0.020 * self.uiScale
            local indX = textX
            local indH = 0.0020 * self.uiScale
            local indY = y + 0.0035 * self.uiScale
            local c = cell.indicatorColor
            self:drawRect(indX, indY, indW, indH, c[1], c[2], c[3], c[4] or 0.95)
        end

        currentX = cellEndX
    end

    -- ── Field Trip Telemetry Mini-Badge & Quick Reset Hold Indicator ──────────
    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if tracker and self.vehicle then
        local farmId = self.vehicle.getOwnerFarmId and self.vehicle:getOwnerFarmId() or 1
        local farm = tracker:getFarmData(farmId)
        local trip = (self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.trip)
        if not trip and farm and farm.combineTrips and self.vehicle then
            local machineKey = self.vehicle.configFileName or (self.vehicle.getFullName and self.vehicle:getFullName()) or "Harvester"
            trip = farm.combineTrips[machineKey]
        end
        trip = trip or (farm and farm.currentTrip)
        if trip and trip.harvestedLiters and trip.harvestedLiters > 0 then
            local badgeH = 0.018 * self.uiScale
            local badgeY = y - badgeH - (0.002 * self.uiScale)
            local badgeW = w
            self:drawPanelBackground(x, badgeY, badgeW, badgeH, {0.02, 0.03, 0.04, 0.85})

            local rank = trip.efficiencyRank or "A"
            local rankColor = {0.55, 0.72, 0.0, 1.0}
            if rank == "B" then rankColor = {0.80, 0.85, 0.20, 1.0}
            elseif rank == "C" then rankColor = {1.0, 0.60, 0.0, 1.0}
            elseif rank == "D" then rankColor = {0.95, 0.25, 0.20, 1.0}
            end

            local tripVolStr = string.format("TRIP: %.1f kL", trip.harvestedLiters / 1000.0)
            local totalBio = trip.harvestedLiters + trip.lostLiters
            local tripLossPct = (totalBio > 0) and ((trip.lostLiters / totalBio) * 100.0) or 0
            local tripLossStr = string.format("LOSS: %.1f%%", tripLossPct)

            setTextBold(true)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextColor(0.92, 0.92, 0.92, 0.95)
            renderText(x + 0.005 * self.uiScale, badgeY + 0.004 * self.uiScale, 0.0105 * self.uiScale, tripVolStr)

            setTextColor(0.75, 0.78, 0.82, 0.90)
            renderText(x + 0.062 * self.uiScale, badgeY + 0.004 * self.uiScale, 0.0105 * self.uiScale, tripLossStr)

            setTextColor(rankColor[1], rankColor[2], rankColor[3], 1.0)
            setTextAlignment(RenderText.ALIGN_RIGHT)
            renderText(x + badgeW - 0.006 * self.uiScale, badgeY + 0.004 * self.uiScale, 0.0115 * self.uiScale, "[" .. rank .. "]")
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

function RHMDraggableHUD:buildActiveCells()
    local cells = {}
    local unitSystem = self.settings.unitSystem or 1
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

    local hasAuxTelemetry = false
    if self.vehicle and (self.vehicle.spec_precisionFarmingStatistic ~= nil or self.vehicle.spec_extendedCombine ~= nil) then
        hasAuxTelemetry = true
    end

    local function getL10n(key, fallback)
        if g_i18n and g_i18n:hasText(key) then
            return g_i18n:getText(key)
        end
        return fallback
    end

    -- 1. Engine Load Cell
    if self.settings.showLoad then
        local loadVal = self.data.load or 0
        local loadColor, indColor = self:getLoadColors(loadVal)
        table.insert(cells, {
            iconName = "load",
            numStr = string.format("%.0f%%", loadVal),
            unitStr = "",
            color = loadColor,
            indicatorColor = indColor
        })
    end

    -- 2. Crop Loss Cell (requires Tier >= 2; falls back to Speed if Tier 1, toggled, forage, or cotton)
    local hasLossSensor = (packageLevel >= 2) and (machineType ~= "forage" and machineType ~= "cotton")
    local showLossMode = (self.displayModes.cell2 == "loss") and hasLossSensor
    if showLossMode and self.settings.showCropLoss then
        local lossVal = self.data.cropLoss or 0
        local lossStr = (lossVal > 0.05) and string.format("%.1f%%", lossVal) or "0.0%"
        local lossColor, indColor = self:getLossColors(lossVal)
        table.insert(cells, {
            iconName = "loss",
            numStr = lossStr,
            unitStr = "",
            color = lossColor,
            indicatorColor = indColor
        })
    else
        local curSpeed = self.data.speed or 0
        local targetSpeed = (self.data.recommendedSpeed and self.data.recommendedSpeed > 0) and self.data.recommendedSpeed or (self.data.targetSpeed or 0)
        -- EN: Convert speed value and unit label to the active unit system (km/h → mph for Imperial/Bushels).
        -- UA: Конвертуємо значення та підпис швидкості відповідно до активної системи одиниць.
        local dispSpeed = curSpeed
        local speedUnit = "km/h"
        if RHM_UnitConverter then
            dispSpeed, speedUnit = RHM_UnitConverter.convertSpeed(curSpeed, unitSystem)
        end
        local unitText = speedUnit
        if targetSpeed and targetSpeed > 0.5 then
            local dispTarget = targetSpeed
            if RHM_UnitConverter then
                dispTarget = RHM_UnitConverter.convertSpeed(targetSpeed, unitSystem)
            end
            unitText = string.format("/ %.1f %s", dispTarget, speedUnit)
        end
        table.insert(cells, {
            iconName = "speed",
            numStr = string.format("%.1f", dispSpeed),
            unitStr = unitText,
            color = {0.98, 0.98, 0.98, 1.0}
        })
    end

    -- 3. Moisture Cell (requires Tier >= 3; falls back to Yield if Tier < 3, toggled, or moisture absent)
    local hasMoistureSensor = (packageLevel >= 3) and (hasPF or (RHM_MoistureAdapter and RHM_MoistureAdapter.isActive))
    local showMoistMode = (self.displayModes.cell3 == "moisture") and hasMoistureSensor
    if showMoistMode and self.settings.showMoisture then
        local mVal = self.data.moisture or 0
        local valStr = (mVal <= 0.1) and "--" or string.format("%.1f%%", mVal)
        local mColor = {0.45, 0.80, 0.98, 1.0}
        if mVal > 20 then
            mColor = {0.95, 0.28, 0.28, 1.0}
        elseif mVal > 14 then
            mColor = {0.98, 0.75, 0.20, 1.0}
        end
        table.insert(cells, {
            iconName = "moisture",
            numStr = valStr,
            unitStr = "",
            color = mColor
        })
    else
        local yieldVal = self.data.yield or 0
        local valStr, suffixStr
        if RHM_UnitConverter then
            local val, suffix = RHM_UnitConverter.convertYield(yieldVal, unitSystem, fruitType)
            valStr = string.format("%.1f", val)
            suffixStr = suffix or "t/ha"
        else
            valStr = string.format("%.1f", yieldVal)
            suffixStr = "t/ha"
        end
        table.insert(cells, {
            iconName = "yield",
            numStr = valStr,
            unitStr = suffixStr,
            color = {0.98, 0.98, 0.98, 1.0}
        })
    end

    -- 4. Productivity Cell: Tons/hour (t/h) or Hectares/hour (ha/h)
    if self.settings.showProductivity then
        if self.displayModes.cell4 == "hectaresPerHour" then
            local haVal = self.data.hectaresPerHour or 0
            -- EN: Convert area from ha to ac for Imperial/Bushels unit systems.
            -- UA: Конвертуємо площу з га в акри для систем Imperial/Bushels.
            local dispArea = haVal
            local areaUnit = "ha/h"
            if RHM_UnitConverter then
                local areaVal, areaSuffix = RHM_UnitConverter.convertArea(haVal, unitSystem)
                dispArea = areaVal
                -- EN: Append "/h" to the area suffix ("ha" → "ha/h", "ac" → "ac/h").
                -- UA: Додаємо "/h" до суфіксу площі ("га" → "га/год", "акр" → "акр/год").
                areaUnit = areaSuffix .. "/h"
            end
            local valStr = (dispArea <= 0.05 and (self.data.speed or 0) < 0.5) and "0.0" or string.format("%.1f", dispArea)
            local unitLabel = areaUnit
            table.insert(cells, {
                iconName = "yield",
                numStr = valStr,
                unitStr = unitLabel,
                color = {0.98, 0.98, 0.98, 1.0}
            })
        else
            local prodVal = self.data.tonPerHour or 0
            local valStr, suffixStr
            if RHM_UnitConverter then
                local val, suffix = RHM_UnitConverter.convertProductivity(prodVal, unitSystem, fruitType, self.data.litersPerHour)
                valStr = (prodVal <= 0.05 and (self.data.speed or 0) < 0.5) and "0.0" or string.format("%.1f", val)
                suffixStr = suffix or "t/h"
            else
                valStr = string.format("%.1f", prodVal)
                suffixStr = "t/h"
            end
            local unitLabel = (suffixStr == "t/h" and g_i18n:hasText("rhm_unit_t_per_hour")) and g_i18n:getText("rhm_unit_t_per_hour") or suffixStr
            table.insert(cells, {
                iconName = "productivity",
                numStr = valStr,
                unitStr = unitLabel,
                color = {0.98, 0.98, 0.98, 1.0}
            })
        end
    end

    return cells
end

function RHMDraggableHUD:getLoadColors(load)
    if load >= 105 then
        local pulse = 0.70 + 0.30 * math.sin((g_time or 0) * 0.012)
        local c = {1.0 * pulse, 0.18 * pulse, 0.18 * pulse, 1.0}
        return c, c
    elseif load >= 95 then
        local c = {1.0, 0.50, 0.10, 0.95}
        return {0.98, 0.98, 0.98, 1.0}, c
    elseif load >= 80 then
        local c = {0.95, 0.80, 0.20, 0.95}
        return {0.98, 0.98, 0.98, 1.0}, c
    else
        return {0.98, 0.98, 0.98, 1.0}, {0.529, 0.706, 0.0, 1.0}
    end
end

function RHMDraggableHUD:getLossColors(loss)
    if loss > 3.0 then
        local pulse = 0.70 + 0.30 * math.sin((g_time or 0) * 0.012)
        local c = {1.0 * pulse, 0.18 * pulse, 0.18 * pulse, 1.0}
        return c, c
    elseif loss > 1.5 then
        local c = {0.95, 0.80, 0.20, 0.95}
        return {0.98, 0.98, 0.98, 1.0}, c
    else
        return {0.98, 0.98, 0.98, 1.0}, {0.529, 0.706, 0.0, 1.0}
    end
end

function RHMDraggableHUD:isMouseOver(posX, posY)
    if not posX or not posY or not self.x or not self.y then return false end
    return posX >= self.x and posX <= (self.x + self.width) and
           posY >= self.y and posY <= (self.y + self.height)
end

function RHMDraggableHUD:handleCellClick(clickedCol)
    if clickedCol == 4 then
        -- Toggle between tons/h and ha/h
        if self.displayModes.cell4 == "tonPerHour" then
            self.displayModes.cell4 = "hectaresPerHour"
        else
            self.displayModes.cell4 = "tonPerHour"
        end
        return true
    elseif clickedCol == 2 then
        -- Toggle between grain loss (%) and current speed (km/h) (Loss requires Tier >= 2)
        local pkgLevel = (self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.packageLevel) or 1
        local mType = self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.machineType
        local canShowLoss = (pkgLevel >= 2) and (mType ~= "forage" and mType ~= "cotton")
        if canShowLoss then
            if self.displayModes.cell2 == "loss" then
                self.displayModes.cell2 = "speed"
            else
                self.displayModes.cell2 = "loss"
            end
            return true
        end
    elseif clickedCol == 3 then
        -- Toggle between moisture (%) and yield (t/ha) (Moisture requires Tier >= 3)
        local pkgLevel = (self.vehicle and self.vehicle.spec_rhm_Combine and self.vehicle.spec_rhm_Combine.packageLevel) or 1
        local hasAuxTelemetry = false
        if self.vehicle and (self.vehicle.spec_precisionFarmingStatistic ~= nil or self.vehicle.spec_extendedCombine ~= nil) then
            hasAuxTelemetry = true
        end
        local canShowMoisture = (pkgLevel >= 3) and (hasAuxTelemetry or (RHM_MoistureAdapter and RHM_MoistureAdapter.isActive))
        if canShowMoisture then
            if self.displayModes.cell3 == "moisture" then
                self.displayModes.cell3 = "yield"
            else
                self.displayModes.cell3 = "moisture"
            end
            return true
        end
    end
    return false
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
            local cellW = self.width / 4
            self.clickCell = math.floor((posX - self.x) / cellW) + 1
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
            local snapRadiusY = 0.038 * uiScale

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
            -- Stationary click without drag: cycle cell metric (zero flicker/border)
            self:handleCellClick(self.clickCell or 1)
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
