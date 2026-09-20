-- EN: Non-blocking HUD notification and onboarding tutorial manager for Realistic Harvesting.
--     Renders sleek in-game notifications with dark translucent rounded background and neon accents.
--     Features cascading tutorial hints with cooldowns and persistent seen-flags across saves.
-- UA: Неблокуючий менеджер сповіщень та навчальних підказок для Realistic Harvesting.
--     Відображає стильні напівпрозорі сповіщення із закругленими кутами та неоновим акцентом.
--     Підтримує каскадні підказки з кулдауном і збереженням прапорців перегляду між сесіями.

RHM_NotificationManager = {}
RHM_NotificationManager.INSTANCE = nil

local NotificationManager_mt = Class(RHM_NotificationManager)

-- EN: Visual constants unified with RHM Draggable HUD and Calibration Terminal
-- UA: Візуальні константи, уніфіковані з RHM Draggable HUD та терміналом калібрування
local COLOR_BG = {0.0, 0.0, 0.0, 0.72}               -- Pure deep black glass (72% opacity, matching game HUD)
local COLOR_ACCENT = {0.529, 0.706, 0.0, 1.0}        -- Authentic game HUD green accent
local COLOR_DIVIDER = {1.00, 1.00, 1.00, 0.10}       -- Subtle metallic divider
local COLOR_TITLE = {0.529, 0.706, 0.0, 1.0}         -- Authentic game HUD green title
local COLOR_TEXT = {0.94, 0.95, 0.97, 0.96}          -- High-readability clean white
local COLOR_OK = {0.94, 0.95, 0.97, 1.00}            -- Action prompt text
local COLOR_BUTTON_BG = {0.0, 0.0, 0.0, 0.40}        -- Action button badge
local COLOR_BUTTON_BORDER = {1.00, 1.00, 1.00, 0.12} -- Action button border

function RHM_NotificationManager.new(modDirectory, settings)
    local self = setmetatable({}, NotificationManager_mt)

    self.modDirectory = modDirectory or g_currentModDirectory
    self.settings = settings
    self.activeNotification = nil
    self.cooldownTimer = 2000 -- 2s initial silence after loading game
    self.cooldownDurationMs = 45000 -- 45s between tutorial hints to prevent spam
    self.seenTutorials = RHM_NotificationManager.seenTutorials or {}
    RHM_NotificationManager.seenTutorials = self.seenTutorials

    self.cumulativeTier1HarvestTime = 0
    self.harvestActiveRunTime = 0

    self.roundedOverlay = nil
    self.roundedUVs = nil
    self.rectOverlay = nil
    self.notificationCloseGlyph = nil
    self.notificationCloseGlyphWidth = nil
    self.notificationCloseGlyphHeight = nil
    self.notificationCloseGlyphInputMode = nil

    self.mouseButtonDownLast = false
    self.gamepadButtonDownLast = false

    return self
end

function RHM_NotificationManager:load()
    if not self.roundedOverlay then
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
    end

    if not self.rectOverlay then
        local atlasPath = Utils.getFilename("textures/hud_icons.dds", self.modDirectory)
        local bgUVs = GuiUtils.getUVs({388, 4, 56, 56}, {512, 64})
        self.rectOverlay = Overlay.new(atlasPath, 0, 0, 1, 1)
        if bgUVs then
            self.rectOverlay:setUVs(bgUVs)
        end
    end

    addConsoleCommand("rhm_hint", "Show a tutorial hint manually [welcome|overload|loss|moisture|headland|upgrade]", "consoleCommandShowHint", self)
    addConsoleCommand("rhm_reset_hints", "Reset seen tutorial hints so they appear again", "consoleCommandResetHints", self)
end

function RHM_NotificationManager:delete()
    removeConsoleCommand("rhm_hint")
    removeConsoleCommand("rhm_reset_hints")

    if self.roundedOverlay then
        self.roundedOverlay:delete()
        self.roundedOverlay = nil
    end
    self.roundedUVs = nil
    if self.rectOverlay then
        self.rectOverlay:delete()
        self.rectOverlay = nil
    end
    if self.notificationCloseGlyph then
        self.notificationCloseGlyph:delete()
        self.notificationCloseGlyph = nil
        self.notificationCloseGlyphWidth = nil
        self.notificationCloseGlyphHeight = nil
        self.notificationCloseGlyphInputMode = nil
    end

    self.activeNotification = nil
end

function RHM_NotificationManager:scalePixelToScreenWidth(pixel)
    local screenW = g_screenWidth or 1920
    return (pixel or 0) / screenW
end

function RHM_NotificationManager:scalePixelToScreenHeight(pixel)
    local screenH = g_screenHeight or 1080
    return (pixel or 0) / screenH
end

function RHM_NotificationManager:snapScreenRect(x, y, width, height)
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local snappedX = math.floor(x * screenW + 0.5) / screenW
    local snappedY = math.floor(y * screenH + 0.5) / screenH
    local snappedWidth = math.max(math.floor(width * screenW + 0.5) / screenW, 1 / screenW)
    local snappedHeight = math.max(math.floor(height * screenH + 0.5) / screenH, 1 / screenH)
    return snappedX, snappedY, snappedWidth, snappedHeight
end

function RHM_NotificationManager:consoleCommandShowHint(name)
    name = tostring(name or "welcome"):upper():gsub("%s+", "")
    if name == "" or name == "WELCOME" or name == "1" then
        local title = "REALISTIC HARVESTING"
        local msg = g_i18n:hasText("rhm_tut_welcome_msg") and g_i18n:getText("rhm_tut_welcome_msg") or "Harvesting speed is now dynamically controlled by crop density, engine power, and moisture. Press Shift+K to open the combine calibration terminal."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: WELCOME"
    elseif name == "OVERLOAD" or name == "2" then
        local title = g_i18n:hasText("rhm_tut_overload_title") and g_i18n:getText("rhm_tut_overload_title") or "ENGINE OVERLOAD"
        local msg = g_i18n:hasText("rhm_tut_overload_msg") and g_i18n:getText("rhm_tut_overload_msg") or "The combine is operating at peak capacity! The hydrostatic drive automatically slows down to protect the drum. Raise the cutter or reduce width to relieve pressure."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: OVERLOAD"
    elseif name == "LOSS" or name == "3" then
        local title = g_i18n:hasText("rhm_tut_loss_title") and g_i18n:getText("rhm_tut_loss_title") or "CROP LOSS"
        local msg = g_i18n:hasText("rhm_tut_loss_msg") and g_i18n:getText("rhm_tut_loss_msg") or "Excessive crop loss detected! Rotor speed, fan airflow, or sieve openings are misaligned for this crop. Press Shift+K to load an optimal factory preset."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: LOSS"
    elseif name == "MOISTURE" or name == "4" then
        local title = g_i18n:hasText("rhm_tut_moisture_title") and g_i18n:getText("rhm_tut_moisture_title") or "HIGH MOISTURE"
        local msg = g_i18n:hasText("rhm_tut_moisture_msg") and g_i18n:getText("rhm_tut_moisture_msg") or "Damp straw and grain require significantly more horsepower to thresh, reducing your harvesting speed and increasing loss risk. Harvest during dry conditions for optimal efficiency."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: MOISTURE"
    elseif name == "HEADLAND" or name == "5" then
        local title = g_i18n:hasText("rhm_tut_headland_title") and g_i18n:getText("rhm_tut_headland_title") or "WORKING SPEED MEMORY"
        local msg = g_i18n:hasText("rhm_tut_headland_msg") and g_i18n:getText("rhm_tut_headland_msg") or "The combine automatically remembers your cruising harvest speed across field turns. When lowering the header for the next row, it will smoothly accelerate back to this speed."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: HEADLAND"
    elseif name == "UPGRADE" or name == "UPGRADE_TIERS" or name == "6" then
        local title = g_i18n:hasText("rhm_tut_upgrade_title") and g_i18n:getText("rhm_tut_upgrade_title") or "UPGRADE PACKAGES"
        local msg = g_i18n:hasText("rhm_tut_upgrade_msg") and g_i18n:getText("rhm_tut_upgrade_msg") or "Harvester upgrade packages are available at the vehicle shop: Tier 2 (Sensors & Profiles), Tier 3 (Telemetry & Loss Monitor), and Tier 4 (Opti-Harvest AI autopilot)."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: UPGRADE"
    else
        return "Unknown hint name. Available: welcome, overload, loss, moisture, headland, upgrade (or 1..6)"
    end
end

function RHM_NotificationManager:consoleCommandResetHints()
    self.seenTutorials = {}
    RHM_NotificationManager.seenTutorials = self.seenTutorials
    self.cooldownTimer = 0
    if self.settings and self.settings.save then
        self.settings:save()
    end
    rhm_log("RHM [NotificationManager]: Reset all seen tutorials via console command")
    return "All tutorial hints have been reset and will trigger naturally again."
end

---EN: Word-wrapper with fallback character estimation
function RHM_NotificationManager:wrapText(text, maxWidth, textSize)
    local maxW = math.max(maxWidth or 0.2, 0.1)
    local words = {}
    for word in tostring(text or ""):gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local currentLine = ""

    local hasGetTextWidth = (getTextWidth ~= nil)
    for _, word in ipairs(words) do
        local candidate = (currentLine == "") and word or (currentLine .. " " .. word)
        local widthOk = true
        if hasGetTextWidth then
            local tw = getTextWidth(textSize, candidate)
            if tw and tw > 0 then
                widthOk = (tw <= maxW)
            else
                widthOk = (#candidate * textSize * 0.45 <= maxW)
            end
        else
            widthOk = (#candidate * textSize * 0.45 <= maxW)
        end

        if currentLine == "" or widthOk then
            currentLine = candidate
        else
            table.insert(lines, currentLine)
            currentLine = word
        end
    end

    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end

    return lines
end

---EN: Displays a notification modal
---UA: Відображає модальне вікно сповіщення
function RHM_NotificationManager:showNotification(title, text, durationMs, isTutorial, tutorialKey)
    local rawTitle = tostring(title or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    local rawText = tostring(text or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    if rawText == "" then
        self:dismissNotification()
        return
    end

    local formattedTitle = nil
    if rawTitle ~= "" then
        if rawTitle:upper() == "RHM" or rawTitle == "" then
            rawTitle = "REALISTIC HARVESTING"
        elseif rawTitle:upper() == "RHM [AI]" then
            rawTitle = "REALISTIC HARVESTING [AI]"
        end

        if utf8ToUpper ~= nil then
            formattedTitle = utf8ToUpper(rawTitle)
        else
            formattedTitle = string.upper(rawTitle)
        end
    end

    local parsedDuration = tonumber(durationMs) or 0
    local isPersistent = parsedDuration <= 0
    local displayDuration = isPersistent and 60000 or math.max(parsedDuration, 4000)

    -- Pre-calculate layout & wrapped lines ONCE to avoid garbage collection in draw loop
    local panelWidth = math.max(0.24, self:scalePixelToScreenWidth(460))
    local padding = self:scalePixelToScreenWidth(18)
    local fullTextWidth = panelWidth - (padding * 2)

    local titleTextSize = self:scalePixelToScreenHeight(17)
    local titleLineHeight = self:scalePixelToScreenHeight(21)
    local textSize = self:scalePixelToScreenHeight(13.5)
    local lineHeight = self:scalePixelToScreenHeight(18.5)

    local padTop = self:scalePixelToScreenHeight(12)
    local gapAfterTitle = self:scalePixelToScreenHeight(7)
    local titleDividerHeight = math.max(self:scalePixelToScreenHeight(1.5), 1 / (g_screenHeight or 1080))
    local gapAfterTopDivider = self:scalePixelToScreenHeight(9)
    local gapBeforeBottomDivider = self:scalePixelToScreenHeight(9)
    local gapBeforeFooter = self:scalePixelToScreenHeight(7)
    local closeGlyphHeight = self:scalePixelToScreenHeight(16)
    local padBottom = self:scalePixelToScreenHeight(9)

    local titleLines = {}
    if formattedTitle ~= nil and formattedTitle ~= "" then
        titleLines = self:wrapText(formattedTitle, fullTextWidth, titleTextSize)
    end
    local hasTitle = #titleLines > 0

    local lines = self:wrapText(rawText, fullTextWidth, textSize)

    local dynamicHeight = 0
    if hasTitle then
        dynamicHeight = padTop + (#titleLines * titleLineHeight) + gapAfterTitle + titleDividerHeight + gapAfterTopDivider + (#lines * lineHeight) + gapBeforeBottomDivider + titleDividerHeight + gapBeforeFooter + closeGlyphHeight + padBottom
    else
        dynamicHeight = padTop + (#lines * lineHeight) + gapBeforeFooter + closeGlyphHeight + padBottom
    end

    local baseAnchorY = 0.14 -- Sitting comfortably in lower screen region
    local panelX = (1.0 - panelWidth) * 0.5
    local panelY = baseAnchorY

    self.activeNotification = {
        title = formattedTitle,
        text = rawText,
        titleLines = titleLines,
        lines = lines,
        hasTitle = hasTitle,
        panelX = panelX,
        panelY = panelY,
        panelWidth = panelWidth,
        dynamicHeight = dynamicHeight,
        padding = padding,
        titleTextSize = titleTextSize,
        titleLineHeight = titleLineHeight,
        textSize = textSize,
        lineHeight = lineHeight,
        padTop = padTop,
        gapAfterTitle = gapAfterTitle,
        titleDividerHeight = titleDividerHeight,
        gapAfterTopDivider = gapAfterTopDivider,
        gapBeforeBottomDivider = gapBeforeBottomDivider,
        gapBeforeFooter = gapBeforeFooter,
        closeGlyphHeight = closeGlyphHeight,
        padBottom = padBottom,
        durationMs = displayDuration,
        isPersistent = isPersistent,
        timer = 0,
        isTutorial = isTutorial or false,
        tutorialKey = tutorialKey
    }

    if tutorialKey then
        self.seenTutorials[tutorialKey] = true
        if RHM_NotificationManager.seenTutorials then
            RHM_NotificationManager.seenTutorials[tutorialKey] = true
        end
        self.cooldownTimer = self.cooldownDurationMs
        if self.settings and self.settings.save then
            self.settings:save()
        end
    end

    rhm_log(string.format("RHM [NotificationManager]: Displaying '%s' (tutorialKey=%s, duration=%dms)", tostring(formattedTitle), tostring(tutorialKey), displayDuration))
end

function RHM_NotificationManager:dismissNotification()
    self.activeNotification = nil
end

function RHM_NotificationManager:closeActiveNotification()
    self:dismissNotification()
end

---EN: Draws authentic FS25 9-slice rounded translucent panel
---UA: Малює автентичну 9-секційну заокруглену напівпрозору панель FS25
function RHM_NotificationManager:drawPanelBackground(x, y, w, h, color)
    if not self.roundedOverlay or not self.roundedUVs then return end

    local c = color or COLOR_BG
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

---EN: Draws a solid rectangle using atlas white pixel
---UA: Малює суцільний прямокутник за допомогою білого пікселя з атласу
function RHM_NotificationManager:drawRect(x, y, w, h, r, g, b, a)
    if not self.rectOverlay then return end
    self.rectOverlay:setPosition(x, y)
    self.rectOverlay:setDimension(w, h)
    self.rectOverlay:setColor(r, g, b, a or 1.0)
    self.rectOverlay:render()
end

---EN: Draws a bordered rectangle (e.g. for button pills)
---UA: Малює прямокутник з рамкою (наприклад, для кнопок-підказок)
function RHM_NotificationManager:drawBorderedRect(x, y, w, h, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA, borderWidth)
    local bw = borderWidth or (1 / (g_screenWidth or 1920))
    local bh = borderWidth or (1 / (g_screenHeight or 1080))
    self:drawRect(x, y, w, h, bgR, bgG, bgB, bgA)
    self:drawRect(x, y + h - bh, w, bh, borderR, borderG, borderB, borderA)
    self:drawRect(x, y, w, bh, borderR, borderG, borderB, borderA)
    self:drawRect(x, y + bh, bw, h - bh * 2, borderR, borderG, borderB, borderA)
    self:drawRect(x + w - bw, y + bh, bw, h - bh * 2, borderR, borderG, borderB, borderA)
end

---EN: Gets or caches the close glyph element (avoids recreating every frame)
function RHM_NotificationManager:getNotificationCloseGlyph(glyphWidth, glyphHeight)
    if g_inputDisplayManager == nil or InputGlyphElement == nil or InputAction == nil then
        return nil
    end

    local closeAction = InputAction.RHM_CLOSE_NOTIFICATION or InputAction.MENU_ACCEPT or InputAction.ACTIVATE_OBJECT

    if self.notificationCloseGlyph == nil then
        self.notificationCloseGlyph = InputGlyphElement.new(g_inputDisplayManager, glyphWidth, glyphHeight)
        self.notificationCloseGlyph:setKeyboardGlyphColor(COLOR_ACCENT, {0.0, 0.0, 0.0, 0.72})
        self.notificationCloseGlyph:setButtonGlyphColor(COLOR_ACCENT)
        self.notificationCloseGlyphWidth = glyphWidth
        self.notificationCloseGlyphHeight = glyphHeight
    elseif self.notificationCloseGlyphWidth ~= glyphWidth or self.notificationCloseGlyphHeight ~= glyphHeight then
        self.notificationCloseGlyph:delete()
        self.notificationCloseGlyph = InputGlyphElement.new(g_inputDisplayManager, glyphWidth, glyphHeight)
        self.notificationCloseGlyph:setKeyboardGlyphColor(COLOR_ACCENT, {0.0, 0.0, 0.0, 0.72})
        self.notificationCloseGlyph:setButtonGlyphColor(COLOR_ACCENT)
        self.notificationCloseGlyphWidth = glyphWidth
        self.notificationCloseGlyphHeight = glyphHeight
        self.notificationCloseGlyphInputMode = nil
    end

    local inputMode = g_inputBinding ~= nil and g_inputBinding:getInputHelpMode() or nil
    if self.notificationCloseGlyphInputMode ~= inputMode then
        self.notificationCloseGlyph:setAction(closeAction, nil, nil, true)
        self.notificationCloseGlyphInputMode = inputMode
    end

    return self.notificationCloseGlyph
end

function RHM_NotificationManager:getNotificationGamepadState()
    if getNumOfGamepads == nil or getInputButton == nil then
        return false
    end

    local numGamepads = getNumOfGamepads()
    for gamepadId = 0, numGamepads - 1 do
        if getInputButton(1, gamepadId) > 0 then
            return true
        end
    end
    return false
end

function RHM_NotificationManager:updateInput()
    if not self.activeNotification then return end

    local isGamepadDown = self:getNotificationGamepadState()

    if isGamepadDown and not self.gamepadButtonDownLast then
        self:dismissNotification()
        self.gamepadButtonDownLast = true
        return
    end

    self.gamepadButtonDownLast = isGamepadDown
end

---EN: Helper to detect if a combine cutter is currently active (lowered and spinning)
function RHM_NotificationManager.getIsCutterActive(combineVehicle)
    if not combineVehicle then return false end

    local spec_combine = combineVehicle.spec_combine
    if spec_combine and spec_combine.attachedCutters then
        for cutter, _ in pairs(spec_combine.attachedCutters) do
            if cutter.spec_cutter then
                local spec_cutter = cutter.spec_cutter
                if cutter:getIsTurnedOn() and (spec_cutter.allowCuttingWhileRaised or cutter:getIsLowered(true)) then
                    return true
                end
            end
        end
    end

    if combineVehicle.spec_cutter then
        local spec_cutter = combineVehicle.spec_cutter
        if combineVehicle:getIsTurnedOn() and (spec_cutter.allowCuttingWhileRaised or combineVehicle:getIsLowered(true)) then
            return true
        end
    end

    return false
end

---EN: Main update tick for managing timer and cascading onboarding tutorials
function RHM_NotificationManager:update(dt, combineVehicle)
    -- Poll gamepad dismiss
    self:updateInput()

    -- 1. Advance active notification timer
    if self.activeNotification then
        self.activeNotification.timer = self.activeNotification.timer + dt
        if not self.activeNotification.isPersistent and self.activeNotification.timer >= self.activeNotification.durationMs then
            self:dismissNotification()
        end
        return
    end

    -- 2. Respect settings toggle
    if self.settings and self.settings.getEnableTutorials and not self.settings:getEnableTutorials() then
        return
    end

    -- 3. Decrement cooldown between tutorial hints
    if self.cooldownTimer > 0 then
        self.cooldownTimer = self.cooldownTimer - dt
        return
    end

    -- 4. Only evaluate triggers if player is controlling an active combine
    if not combineVehicle then return end
    local spec = combineVehicle.spec_rhm_Combine
    if not spec or not spec.data then
        return
    end

    local isCutterActive = RHM_NotificationManager.getIsCutterActive(combineVehicle)
    local speed = (combineVehicle.getLastSpeed and combineVehicle:getLastSpeed()) or 0
    local isHarvesting = isCutterActive and speed > 0.5
    local load = (spec.data and spec.data.load) or 0
    local cropLoss = (spec.data and spec.data.cropLoss) or 0
    local moisture = (spec.data and spec.data.moisture) or 0

    if isHarvesting then
        self.harvestActiveRunTime = self.harvestActiveRunTime + dt
        if spec.packageLevel == 1 then
            self.cumulativeTier1HarvestTime = self.cumulativeTier1HarvestTime + dt
        end
    else
        self.harvestActiveRunTime = math.max(0, self.harvestActiveRunTime - dt * 0.5)
    end

    -- =========================================================================
    -- CASCADING TUTORIAL TRIGGERS (Priority order, max 1 trigger per check)
    -- =========================================================================

    -- TRIGGER 1: First Harvest / Welcome (triggers upon boarding combine)
    if not self.seenTutorials["WELCOME"] then
        local title = "REALISTIC HARVESTING"
        local msg = g_i18n:hasText("rhm_tut_welcome_msg") and g_i18n:getText("rhm_tut_welcome_msg") or "Harvesting speed is now dynamically controlled by crop density, engine power, and moisture. Press Shift+K to open the combine calibration terminal."
        self:showNotification(title, msg, 0, true, "WELCOME")
        return
    end

    local isArcadeMotor = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.difficultyMotor == 1)
    local isArcadeLoss = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.difficultyLoss == 1)

    -- TRIGGER 2: Engine Overload (> 98%)
    if not isArcadeMotor and not self.seenTutorials["OVERLOAD"] and isHarvesting and load >= 98 then
        local title = g_i18n:hasText("rhm_tut_overload_title") and g_i18n:getText("rhm_tut_overload_title") or "ENGINE OVERLOAD"
        local msg = g_i18n:hasText("rhm_tut_overload_msg") and g_i18n:getText("rhm_tut_overload_msg") or "The combine is operating at peak capacity! The hydrostatic drive automatically slows down to protect the drum. In extreme overloads, the threshing unit may clog."
        self:showNotification(title, msg, 0, true, "OVERLOAD")
        return
    end

    -- TRIGGER 3: Excessive Crop Loss (> 1.5%)
    if not isArcadeLoss and not self.seenTutorials["LOSS"] and isHarvesting and cropLoss > 1.5 then
        local title = g_i18n:hasText("rhm_tut_loss_title") and g_i18n:getText("rhm_tut_loss_title") or "CROP LOSS"
        local msg = g_i18n:hasText("rhm_tut_loss_msg") and g_i18n:getText("rhm_tut_loss_msg") or "Excessive crop loss detected! Rotor speed, fan airflow, or sieve openings are misaligned for this crop. Press Shift+K to load an optimal factory preset."
        self:showNotification(title, msg, 0, true, "LOSS")
        return
    end

    -- TRIGGER 4: High Moisture (> 15% or Rain)
    local isRaining = g_currentMission and g_currentMission.environment and g_currentMission.environment.weather and g_currentMission.environment.weather:getIsRaining()
    if not self.seenTutorials["MOISTURE"] and isHarvesting and (moisture > 15.0 or isRaining) then
        local title = g_i18n:hasText("rhm_tut_moisture_title") and g_i18n:getText("rhm_tut_moisture_title") or "HIGH MOISTURE"
        local msg = g_i18n:hasText("rhm_tut_moisture_msg") and g_i18n:getText("rhm_tut_moisture_msg") or "Damp straw and grain require significantly more horsepower to thresh, reducing your harvesting speed and increasing loss risk. Harvest during dry conditions for optimal efficiency."
        self:showNotification(title, msg, 0, true, "MOISTURE")
        return
    end

    -- TRIGGER 5: Headland Turn Speed Memory (cutter raised after >= 8s harvest)
    if not self.seenTutorials["HEADLAND"] and not isCutterActive and self.harvestActiveRunTime >= 8000 then
        local title = g_i18n:hasText("rhm_tut_headland_title") and g_i18n:getText("rhm_tut_headland_title") or "WORKING SPEED MEMORY"
        local msg = g_i18n:hasText("rhm_tut_headland_msg") and g_i18n:getText("rhm_tut_headland_msg") or "The combine automatically remembers your cruising harvest speed across field turns. When lowering the header for the next row, it will smoothly accelerate back to this speed."
        self:showNotification(title, msg, 0, true, "HEADLAND")
        return
    end

    -- TRIGGER 6: Upgrade Tiers (2 cumulative minutes on Tier 1 combine)
    if not self.seenTutorials["UPGRADE_TIERS"] and spec.packageLevel == 1 and self.cumulativeTier1HarvestTime >= 120000 then
        local title = g_i18n:hasText("rhm_tut_upgrade_title") and g_i18n:getText("rhm_tut_upgrade_title") or "UPGRADE PACKAGES"
        local msg = g_i18n:hasText("rhm_tut_upgrade_msg") and g_i18n:getText("rhm_tut_upgrade_msg") or "Harvester upgrade packages are available at the vehicle shop: Tier 2 (Sensors & Profiles), Tier 3 (Telemetry & Loss Monitor), and Tier 4 (Opti-Harvest AI autopilot)."
        self:showNotification(title, msg, 0, true, "UPGRADE_TIERS")
        return
    end
end

---EN: Draws the notification panel on screen
---UA: Малює панель сповіщень на екрані
function RHM_NotificationManager:draw()
    local notification = self.activeNotification
    if not notification or notification.text == nil then return end

    if not self.roundedOverlay or not self.rectOverlay then
        self:load()
    end

    local panelX = notification.panelX
    local panelY = notification.panelY
    local panelWidth = notification.panelWidth
    local dynamicHeight = notification.dynamicHeight
    local padding = notification.padding
    local titleLines = notification.titleLines
    local hasTitle = notification.hasTitle
    local lines = notification.lines

    local titleTextSize = notification.titleTextSize
    local titleLineHeight = notification.titleLineHeight
    local textSize = notification.textSize
    local lineHeight = notification.lineHeight

    local padTop = notification.padTop or self:scalePixelToScreenHeight(12)
    local gapAfterTitle = notification.gapAfterTitle or self:scalePixelToScreenHeight(7)
    local titleDividerHeight = notification.titleDividerHeight or math.max(self:scalePixelToScreenHeight(1.5), 1 / (g_screenHeight or 1080))
    local gapAfterTopDivider = notification.gapAfterTopDivider or self:scalePixelToScreenHeight(9)
    local gapBeforeBottomDivider = notification.gapBeforeBottomDivider or self:scalePixelToScreenHeight(9)
    local gapBeforeFooter = notification.gapBeforeFooter or self:scalePixelToScreenHeight(7)
    local closeGlyphHeight = notification.closeGlyphHeight or self:scalePixelToScreenHeight(16)
    local closeGlyphWidth = self:scalePixelToScreenWidth(16)

    -- 1. Draw authentic 3-part rounded dark glass background (matching HUD capsule)
    self:drawPanelBackground(panelX, panelY, panelWidth, dynamicHeight, COLOR_BG)

    local centerX = panelX + panelWidth * 0.5
    local currentY = panelY + dynamicHeight - padTop

    -- 2. Render Title in crisp emerald green with accent line
    if hasTitle then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        setTextBold(true)
        setTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3], COLOR_TITLE[4])

        for _, line in ipairs(titleLines) do
            renderText(centerX, currentY, titleTextSize, line)
            currentY = currentY - titleLineHeight
        end

        currentY = currentY - gapAfterTitle
        local dividerWidth = panelWidth - padding * 2
        local dividerY = currentY - titleDividerHeight * 0.5
        -- Emerald accent divider line under title
        self:drawRect(panelX + padding, dividerY, dividerWidth, titleDividerHeight, COLOR_ACCENT[1], COLOR_ACCENT[2], COLOR_ACCENT[3], COLOR_ACCENT[4])

        currentY = currentY - gapAfterTopDivider
    end

    -- 3. Render Centered Body Text in pure crisp white
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(false)
    setTextColor(COLOR_TEXT[1], COLOR_TEXT[2], COLOR_TEXT[3], COLOR_TEXT[4])

    for _, line in ipairs(lines) do
        renderText(centerX, currentY, textSize, line)
        currentY = currentY - lineHeight
    end

    -- 4. Render Bottom Divider and Footer Prompt
    if hasTitle then
        currentY = currentY - gapBeforeBottomDivider
        local dividerWidth = panelWidth - padding * 2
        local bottomDividerY = currentY - titleDividerHeight * 0.5
        -- Subtle metallic divider line above footer
        self:drawRect(panelX + padding, bottomDividerY, dividerWidth, titleDividerHeight, COLOR_DIVIDER[1], COLOR_DIVIDER[2], COLOR_DIVIDER[3], COLOR_DIVIDER[4])

        currentY = currentY - gapBeforeFooter

        -- 5. Footer: Input Glyph + "OK"
        local glyph = self:getNotificationCloseGlyph(closeGlyphWidth, closeGlyphHeight)
        local okText = "OK"
        local okTextSize = textSize
        local textSpacing = self:scalePixelToScreenWidth(6)
        local okTextWidth = getTextWidth ~= nil and getTextWidth(okTextSize, okText) or (#okText * okTextSize * 0.5)

        local footerY = currentY - closeGlyphHeight

        if glyph ~= nil then
            local glyphWidth = glyph:getGlyphWidth()
            local totalFooterW = glyphWidth + textSpacing + okTextWidth
            local glyphX = centerX - totalFooterW * 0.5
            glyph:setPosition(glyphX, footerY)
            glyph:draw()

            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextBold(true)
            setTextColor(COLOR_OK[1], COLOR_OK[2], COLOR_OK[3], COLOR_OK[4])
            renderText(glyphX + glyphWidth + textSpacing, footerY + closeGlyphHeight * 0.5, okTextSize, okText)
        else
            -- Fallback button badge: [ Enter ] OK
            local mWidth = self:scalePixelToScreenWidth(16)
            local mHeight = closeGlyphHeight
            local totalFooterW = mWidth + textSpacing + okTextWidth
            local mX = centerX - totalFooterW * 0.5
            local mY = footerY

            self:drawBorderedRect(mX, mY, mWidth, mHeight, COLOR_BUTTON_BG[1], COLOR_BUTTON_BG[2], COLOR_BUTTON_BG[3], COLOR_BUTTON_BG[4], COLOR_BUTTON_BORDER[1], COLOR_BUTTON_BORDER[2], COLOR_BUTTON_BORDER[3], COLOR_BUTTON_BORDER[4])
            self:drawRect(mX + self:scalePixelToScreenWidth(2), mY + mHeight * 0.5, (mWidth - self:scalePixelToScreenWidth(4)) * 0.5, (mHeight * 0.5) - self:scalePixelToScreenHeight(2), COLOR_ACCENT[1], COLOR_ACCENT[2], COLOR_ACCENT[3], 0.90)

            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextBold(true)
            setTextColor(COLOR_OK[1], COLOR_OK[2], COLOR_OK[3], COLOR_OK[4])
            renderText(mX + mWidth + textSpacing, mY + mHeight * 0.5, okTextSize, okText)
        end
    end

    -- Reset engine render states
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BOTTOM)
end

function RHM_NotificationManager:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.activeNotification then return false end

    -- Close on any left or right mouse click down
    if isDown and (button == Input.MOUSE_BUTTON_LEFT or button == Input.MOUSE_BUTTON_RIGHT) then
        self:dismissNotification()
        return true
    end

    return false
end

function RHM_NotificationManager:keyEvent(unicode, sym, modifier, isDown)
    if not self.activeNotification then return false end

    if isDown and (sym == Input.KEY_return or sym == Input.KEY_space or sym == Input.KEY_escape) then
        self:dismissNotification()
        return true
    end

    return false
end
