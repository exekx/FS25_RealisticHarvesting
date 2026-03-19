-- EN: Draggable on-screen HUD overlay for the Realistic Harvesting mod.
--     Displays live combine metrics: engine load, yield, productivity, crop loss, and speed.
--     Supports drag-and-drop repositioning (via mouse on the header), dynamic row sizing
--     based on user-selected visible metrics, and the "Settings" button that opens the calibration GUI.
-- UA: Перетягуваний HUD-оверлей на екрані для мода Realistic Harvesting.
--     Відображає живі показники комбайна: навантаження двигуна, врожайність, продуктивність, втрати зерна, швидкість.
--     Підтримує перетягування для репозиціонування (через мишу по заголовку), динамічне змінення розміру рядків
--     залежно від вибраних метрик і кнопку "Settings" яка відкриває GUI калібрування.
DraggableHUD = {}
DraggableHUD.__index = DraggableHUD

DraggableHUD.DRAG_DELAY_MS = 15
DraggableHUD.DRAG_LIMIT = 2

function DraggableHUD.new(modDirectory, settings)
    local self = setmetatable({}, DraggableHUD)

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
        recommendedSpeed = 0
    }

    self.width = 0.11
    self.height = 0.18
    self.headerHeight = 0.028
    self.uiScale = 1.0

    self.dragging = false
    self.dragStartX = nil
    self.dragOffsetX = nil
    self.dragStartY = nil
    self.dragOffsetY = nil
    self.lastDragTimeStamp = nil

    self.backgroundOverlay = nil
    self.headerOverlay = nil
    self.accentLineOverlay = nil
    self.icons = {}

    return self
end

function DraggableHUD:load()
    self.uiScale = 1.0
    if g_gameSettings then
        self.uiScale = g_gameSettings:getValue("uiScale") or 1.0
    end

    self.width = 0.09 * self.uiScale
    self.height = 0.155 * self.uiScale
    self.headerHeight = 0.030 * self.uiScale

    self.x, self.y = self:getPosition()

    local bgTexture = self.modDirectory .. "textures/hud_background.dds"

    -- EN: Dark amber-tinted header strip replacing the old green one.
    -- UA: Темна бурштинова смуга заголовку замість старої зеленої.
    self.headerOverlay = Overlay.new(bgTexture, self.x, self.y + self.height, self.width, self.headerHeight)
    self.headerOverlay:setColor(0.09, 0.07, 0.03, 1.0)

    -- Removed the thin amber accent line at the top of the header as requested.
    self.accentLineOverlay = nil

    -- EN: Dark olive background panel, more opaque for better readability.
    -- UA: Темно-оливкова фонова панель, більш непрозора для кращої читабельності.
    self.backgroundOverlay = Overlay.new(bgTexture, self.x, self.y, self.width, self.height)
    self.backgroundOverlay:setColor(0.04, 0.05, 0.03, 0.92)

    self:loadIcons(self.uiScale)

    if RHM_Debug and RHM_Debug.isEnabled("UI") then
        print("RHM: DraggableHUD loaded successfully")
    end
end

function DraggableHUD:loadIcons(uiScale)
    local iconHeight = 0.024 * self.uiScale
    local iconWidth = iconHeight / g_screenAspectRatio

    local iconsPath = self.modDirectory .. "textures/"

    local iconNames = {
        load         = "icon_load",
        yield        = "icon_yield",
        speed        = "icon_speed",
        loss         = "icon_loss",
        productivity = "icon_productivity"
    }

    for name, filename in pairs(iconNames) do
        local iconPath = iconsPath .. filename .. ".dds"
        local icon = Overlay.new(iconPath, 0, 0, iconWidth, iconHeight)
        icon:setColor(1, 1, 1, 0.80)
        self.icons[name] = icon
    end

    if self.settings.showLoad == nil then self.settings.showLoad = true end
    if self.settings.showYield == nil then self.settings.showYield = true end
    if self.settings.showSpeed == nil then self.settings.showSpeed = true end
    if self.settings.showCropLoss == nil then self.settings.showCropLoss = true end
    if self.settings.showProductivity == nil then self.settings.showProductivity = true end
end

function DraggableHUD:getPosition()
    local x = self.settings.hudPosX
    local y = self.settings.hudPosY

    if x and y then
        if x >= -0.1 and x <= 1.1 and y >= -0.1 and y <= 1.1 then
            x = math.max(0, math.min(1 - (self.width or 0), x))
            y = math.max(0, math.min(1 - (self.height or 0), y))
            return x, y
        else
            if RHM_Debug and RHM_Debug.isEnabled("UI") then
                print(string.format("RHM: Saved HUD position (%.2f, %.2f) is off-screen. Resetting to default.", x, y))
            end
        end
    end

    if g_currentMission and g_currentMission.hud and g_currentMission.hud.speedMeter then
        local speedMeter = g_currentMission.hud.speedMeter
        if speedMeter.speedBg and speedMeter.speedBg.x and speedMeter.speedBg.x > 0.01 then
            local offsetX = speedMeter:scalePixelToScreenWidth(-145)
            local offsetY = speedMeter:scalePixelToScreenHeight(15)
            return speedMeter.speedBg.x + offsetX, speedMeter.speedBg.y + offsetY
        end
    end

    return 0.7, 0.05
end

function DraggableHUD:setPosition(x, y)
    self.x = x
    self.y = y
end

function DraggableHUD:setVehicle(vehicle)
    self.vehicle = vehicle
    if vehicle then
        self:update(vehicle)
    else
        self.data.load = 0
        self.data.yield = 0
        self.data.speed = 0
        self.data.cropLoss = 0
        self.data.tonPerHour = 0
        self.data.litersPerHour = 0
        self.data.recommendedSpeed = 0
    end
end

function DraggableHUD:update(dt)
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
    self.data.speed            = vehicle:getLastSpeed() or 0

    if self.dragging then
        if g_inputBinding and g_inputBinding.getMousePosition then
            local posX, posY = g_inputBinding:getMousePosition()
            if posX and posY then
                self:moveTo(posX - self.dragOffsetX, posY - self.dragOffsetY)
            end
        end
    end
end

function DraggableHUD:draw()
    if not g_currentMission:getIsClient() then return end
    if not self.settings.showHUD then return end
    if not self.vehicle then return end

    self:updateSize()

    self.backgroundOverlay:setPosition(self.x, self.y)
    self.headerOverlay:setPosition(self.x, self.y + self.height)
    self.backgroundOverlay:setDimension(self.width, self.height)
    self.headerOverlay:setDimension(self.width, self.headerHeight)

    self.backgroundOverlay:render()
    self.headerOverlay:render()



    -- EN: Amber title text in header.
    -- UA: Бурштиновий заголовок.
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(0.83, 0.54, 0.04, 1.0)
    local titleTextSize = 0.012 * self.uiScale
    local headerTextX = self.x + self.width / 2
    local titleTextY = self.y + self.height + self.headerHeight * 0.65
    renderText(headerTextX, titleTextY, titleTextSize, "Realistic Harvesting")

    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_CENTER)

    local settingsTextSize = 0.009 * self.uiScale
    local btnW = 0.040 * self.uiScale
    local btnH = self.headerHeight * 0.40
    local btnX = self.x + (self.width - btnW) / 2
    local btnY = self.y + self.height + self.headerHeight * 0.06

    local settingsButtonArea = { x = btnX, y = btnY, w = btnW, h = btnH }
    local mx, my = g_inputBinding:getMousePosition()
    local isHovered = mx >= settingsButtonArea.x and mx <= settingsButtonArea.x + settingsButtonArea.w and
                      my >= settingsButtonArea.y and my <= settingsButtonArea.y + settingsButtonArea.h

    if self.backgroundOverlay then
        local btnBgTex = self.modDirectory .. "textures/hud_background.dds"
        local rect = Overlay.new(btnBgTex, btnX, btnY, btnW, btnH)
        if isHovered then
            rect:setColor(0.83, 0.54, 0.04, 0.22)
        else
            rect:setColor(0.00, 0.00, 0.00, 0.28)
        end
        rect:render()
        rect:delete()
    end

    if isHovered then
        setTextColor(0.83, 0.54, 0.04, 1.0)
    else
        setTextColor(0.38, 0.36, 0.32, 1.0)
    end

    local textYOffset = btnY + (btnH - settingsTextSize) / 2 + 0.002
    renderText(headerTextX, textYOffset, settingsTextSize, "Settings")
    setTextBold(false)

    self.menuButtonArea = settingsButtonArea

    self:drawContent()
    setTextBold(false)
end

function DraggableHUD:drawContent()
    local textSize   = 0.015 * self.uiScale
    local lineHeight = 0.028 * self.uiScale
    local iconHeight = 0.024 * self.uiScale
    local iconWidth  = iconHeight / g_screenAspectRatio
    local padding    = 0.005 * self.uiScale

    local iconX = self.x + padding
    local textX = iconX + iconWidth + padding
    local textY = self.y + self.height - self.headerHeight - (0.005 * self.uiScale)

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(0.91, 0.87, 0.78, 0.95)

    local unitSystem = self.settings.unitSystem or 1
    local fruitType = nil
    if self.vehicle and self.vehicle.spec_combine then
        fruitType = self.vehicle.spec_combine.lastValidInputFruitType
    end

    -- EN: Row 1 — Engine Load.
    -- UA: Рядок 1 — Навантаження двигуна.
    if self.settings.showLoad then
        local loadColor = self:getLoadColor(self.data.load)
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "load",
            string.format("%.0f%%", self.data.load), self.data.load, loadColor[1], loadColor[2], loadColor[3])
        textY = textY - lineHeight
    end

    -- EN: Row 2 — Yield.
    -- UA: Рядок 2 — Врожайність.
    if self.settings.showYield then
        local yieldVal = self.data.yield or 0
        local yieldStr
        if UnitConverter then
            local val, suffix = UnitConverter.convertYield(yieldVal, unitSystem, fruitType)
            yieldStr = string.format("%.1f %s", val, suffix)
        else
            yieldStr = string.format("%.1f t/ha", yieldVal)
        end
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "yield", yieldStr, 0)
        textY = textY - lineHeight
    end

    -- EN: Row 3 — Productivity.
    -- UA: Рядок 3 — Продуктивність.
    if self.settings.showProductivity then
        local prodVal = self.data.tonPerHour or 0
        local prodStr
        if UnitConverter then
            local val, suffix = UnitConverter.convertProductivity(prodVal, unitSystem, fruitType, self.data.litersPerHour)
            prodStr = string.format("%.1f %s", val, suffix)
        else
            prodStr = string.format("%.1f t/h", prodVal)
        end
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "productivity", prodStr, 0)
        textY = textY - lineHeight
    end

    -- EN: Row 4 — Crop Loss. Skipped entirely for forage harvesters (no grain losses on choppers).
    -- UA: Рядок 4 — Втрати зерна. Пропускається для силосних комбайнів (немає втрат).
    local machineType = nil
    if self.vehicle and self.vehicle.spec_rhm_Combine then
        machineType = self.vehicle.spec_rhm_Combine.machineType
    end
    if self.settings.showCropLoss and machineType ~= "forage" then
        local lossVal = self.data.cropLoss or 0
        local lossStr
        if lossVal > 0.1 then
            lossStr = string.format("-%.1f%%", lossVal)
        elseif lossVal < -0.1 then
            lossStr = string.format("+%.1f%%", math.abs(lossVal))
        else
            lossStr = "0%"
        end

        local r, g, b = 0.91, 0.87, 0.78
        if lossVal > 3.0 then       r, g, b = 0.89, 0.29, 0.29
        elseif lossVal > 1.0 then   r, g, b = 0.91, 0.78, 0.25
        elseif lossVal < -0.1 then  r, g, b = 0.24, 0.90, 0.55
        else                        r, g, b = 0.24, 0.72, 0.47
        end

        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "loss", lossStr, lossVal, r, g, b)
        textY = textY - lineHeight
    end

    -- EN: Row 5 — Speed (current / recommended).
    -- UA: Рядок 5 — Швидкість (поточна / рекомендована).
    if self.settings.showSpeed then
        local currentSpeed = self.data.speed
        local recSpeed = self.data.recommendedSpeed or 0
        local speedStr

        if UnitConverter then
            local cur, suf = UnitConverter.convertSpeed(currentSpeed, unitSystem)
            local rec, _   = UnitConverter.convertSpeed(recSpeed, unitSystem)
            if recSpeed > 0 then
                speedStr = string.format("%.1f / %.1f %s", cur, rec, suf)
            else
                speedStr = string.format("%.1f %s", cur, suf)
            end
        else
            if recSpeed > 0 then
                speedStr = string.format("%.1f / %.1f km/h", currentSpeed, recSpeed)
            else
                speedStr = string.format("%.1f km/h", currentSpeed)
            end
        end

        local r, g, b = 0.91, 0.87, 0.78
        if recSpeed > 0 then
            if currentSpeed > (recSpeed + 2) then   r, g, b = 0.89, 0.29, 0.29
            elseif currentSpeed > recSpeed then     r, g, b = 0.91, 0.78, 0.25
            end
        end

        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "speed", speedStr, 0, r, g, b)
    end
end

function DraggableHUD:updateSize()
    -- EN: Detect machine type to exclude forage-specific suppressed rows from height.
    -- UA: Визначаємо тип машини щоб прибрати зайве місце для silosних комбайнів.
    local machineType = nil
    if self.vehicle and self.vehicle.spec_rhm_Combine then
        machineType = self.vehicle.spec_rhm_Combine.machineType
    end

    local rowCount = 0
    if self.settings.showLoad then rowCount = rowCount + 1 end
    if self.settings.showYield then rowCount = rowCount + 1 end
    if self.settings.showProductivity then rowCount = rowCount + 1 end
    -- EN: Crop Loss row is not shown for forage harvesters — exclude from height.
    -- UA: Рядок втрат не відображається для силосних — не рахуємо в висоту.
    if self.settings.showCropLoss and machineType ~= "forage" then rowCount = rowCount + 1 end
    if self.settings.showSpeed then rowCount = rowCount + 1 end

    local lineHeight  = 0.028 * self.uiScale
    local padding     = 0.010 * self.uiScale
    local targetHeight = math.max(0.01 * self.uiScale, (rowCount * lineHeight) + padding)

    if math.abs(self.height - targetHeight) > 0.0001 then
        local heightDiff = self.height - targetHeight
        self.y = self.y + heightDiff
        self.height = targetHeight
        self.settings.hudPosY = self.y
    end
end

function DraggableHUD:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, iconName, text, value, r, g, b)
    local icon = self.icons[iconName]
    if icon then
        local iconY = textY + textSize / 2 - iconHeight / 2
        icon:setPosition(iconX, iconY)
        icon:setColor(0.91, 0.87, 0.78, 0.60)
        icon:render()
    end

    if r and g and b then
        setTextColor(r, g, b, 0.95)
    else
        setTextColor(0.91, 0.87, 0.78, 0.95)
    end
    renderText(textX, textY, textSize, text)

    if self.backgroundOverlay then
        local lineY = textY - 0.004
        local lineTex = self.modDirectory .. "textures/hud_background.dds"
        local line = Overlay.new(lineTex, self.x + 0.005, lineY, self.width - 0.010, 0.0007)
        line:setColor(1, 1, 1, 0.07)
        line:render()
        line:delete()
    end
end

-- EN: Engine load → color: warm white < 60%, amber-yellow 60-85%, red > 85%.
-- UA: Навантаження двигуна → колір: тепло-білий < 60%, бурштиново-жовтий 60-85%, червоний > 85%.
function DraggableHUD:getLoadColor(load)
    if load < 60 then
        return {0.91, 0.87, 0.78}
    elseif load < 85 then
        return {0.91, 0.78, 0.25}
    else
        return {0.89, 0.29, 0.29}
    end
end

function DraggableHUD:isMouseOverHeader(posX, posY)
    return posX >= self.x and posX <= (self.x + self.width) and
           posY >= (self.y + self.height) and posY <= (self.y + self.height + self.headerHeight)
end

function DraggableHUD:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.settings.showHUD then return false end
    if button ~= Input.MOUSE_BUTTON_LEFT then return false end

    if self.menuButtonArea and isDown then
        if posX >= self.menuButtonArea.x and posX <= (self.menuButtonArea.x + self.menuButtonArea.w) and
           posY >= self.menuButtonArea.y and posY <= (self.menuButtonArea.y + self.menuButtonArea.h) then
            if g_realisticHarvestManager then
                g_realisticHarvestManager:toggleMenu(self.vehicle)
                return true
            end
        end
    end

    if isDown and self:isMouseOverHeader(posX, posY) then
        if not self.dragging then
            self.dragStartX  = posX
            self.dragOffsetX = posX - self.x
            self.dragStartY  = posY
            self.dragOffsetY = posY - self.y
            self.dragging = true
            self.lastDragTimeStamp = g_time
            if RHM_Debug and RHM_Debug.isEnabled("UI") then print("RHM: Drag started") end
            return true
        end
    elseif isUp then
        if self.dragging then
            self.dragging = false
            if RHM_Debug and RHM_Debug.isEnabled("UI") then
                print(string.format("RHM: Drag stopped at (%.3f, %.3f)", self.x, self.y))
            end
            if self.settings and self.settings.save then
                self.settings:save()
            end
            return true
        end
    end

    return false
end

function DraggableHUD:moveTo(x, y)
    x = math.max(0, math.min(1 - self.width, x))
    y = math.max(0, math.min(1 - (self.height + self.headerHeight), y))
    self:setPosition(x, y)
    self.settings.hudPosX = x
    self.settings.hudPosY = y
end

function DraggableHUD:delete()
    if self.backgroundOverlay then self.backgroundOverlay:delete() end
    if self.headerOverlay then self.headerOverlay:delete() end

    for _, icon in pairs(self.icons) do
        if icon then icon:delete() end
    end

    if RHM_Debug and RHM_Debug.isEnabled("UI") then
        print("RHM: DraggableHUD unloaded")
    end
end

return DraggableHUD