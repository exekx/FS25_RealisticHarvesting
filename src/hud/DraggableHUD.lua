---@class DraggableHUD
---Draggable HUD for Realistic Harvesting mod
---Based on Courseplay's CpHudMoveableElement approach
DraggableHUD = {}
DraggableHUD.__index = DraggableHUD

DraggableHUD.DRAG_DELAY_MS = 15
DraggableHUD.DRAG_LIMIT = 2

---Constructor
---@param modDirectory string
---@param settings table
---@return DraggableHUD
function DraggableHUD.new(modDirectory, settings)
    local self = setmetatable({}, DraggableHUD)
    
    self.modDirectory = modDirectory
    self.settings = settings
    self.vehicle = nil
    
    -- HUD data
    self.data = {
        load = 0,
        yield = 0,
        speed = 0,
        cropLoss = 0,
        tonPerHour = 0,
        litersPerHour = 0,
        recommendedSpeed = 0
    }
    
    -- Position and size (normalized)
    -- Initial values (will be scaled in load)
    self.width = 0.11
    self.height = 0.18
    self.headerHeight = 0.028
    self.uiScale = 1.0
    
    -- Drag state (matching Courseplay's approach)
    self.dragging = false
    self.dragStartX = nil
    self.dragOffsetX = nil
    self.dragStartY = nil
    self.dragOffsetY = nil
    self.lastDragTimeStamp = nil
    
    -- Overlays
    self.backgroundOverlay = nil
    self.headerOverlay = nil
    
    -- Icons
    self.icons = {}
    
    return self
end

---Load resources
function DraggableHUD:load()
    self.uiScale = 1.0
    if g_gameSettings then
        self.uiScale = g_gameSettings:getValue("uiScale") or 1.0
    end
    
    -- Resize based on UI scale (More compact box, but room for larger text)
    self.width = 0.09 * self.uiScale -- Reduced from 0.11, slightly larger than 0.085
    self.height = 0.155 * self.uiScale -- Reduced from 0.18
    self.headerHeight = 0.024 * self.uiScale
    
    -- Get saved position or default
    self.x, self.y = self:getPosition()
    
    -- Create header overlay (green like Courseplay)
    local headerTexture = self.modDirectory .. "textures/hud_background.dds"
    self.headerOverlay = Overlay.new(headerTexture, self.x, self.y + self.height, self.width, self.headerHeight)
    self.headerOverlay:setColor(0.22323, 0.40724, 0.00368, 1)
    
    -- Create background overlay
    self.backgroundOverlay = Overlay.new(headerTexture, self.x, self.y, self.width, self.height)
    self.backgroundOverlay:setColor(0, 0, 0, 0.5)
    
    -- Load icons
    self:loadIcons(uiScale)
    
    print("RHM: DraggableHUD loaded successfully")
end

---Load icon overlays
---@param uiScale number
function DraggableHUD:loadIcons(uiScale)
    -- Calculate square icon size based on aspect ratio
    -- Larger icons as requested
    local iconHeight = 0.024 * self.uiScale 
    local iconWidth = iconHeight / g_screenAspectRatio
    
    local iconsPath = self.modDirectory .. "textures/"
    
    local iconNames = {
        load = "icon_load",
        yield = "icon_yield",
        speed = "icon_speed",
        loss = "icon_loss",
        productivity = "icon_productivity"
    }
    
    for name, filename in pairs(iconNames) do
        local iconPath = iconsPath .. filename .. ".dds"
        local icon = Overlay.new(iconPath, 0, 0, iconWidth, iconHeight)
        icon:setColor(1, 1, 1, 0.95)
        self.icons[name] = icon
    end
    
    -- Ensure default settings are active if nil
    if self.settings.showLoad == nil then self.settings.showLoad = true end
    if self.settings.showYield == nil then self.settings.showYield = true end
    if self.settings.showSpeed == nil then self.settings.showSpeed = true end
    if self.settings.showCropLoss == nil then self.settings.showCropLoss = true end
    if self.settings.showProductivity == nil then self.settings.showProductivity = true end
end

---Get HUD position (saved or default)
---@return number posX
---@return number posY
function DraggableHUD:getPosition()
    -- Use saved position if available
    local x = self.settings.hudPosX
    local y = self.settings.hudPosY
    
    if x and y then
        -- Validate coordinates (must be on screen)
        -- Allow small margin for error, but reset if completely off-screen
        if x >= -0.1 and x <= 1.1 and y >= -0.1 and y <= 1.1 then
            
            -- Clamp to strict safe bounds [0, 1] for rendering
            x = math.max(0, math.min(1 - (self.width or 0), x))
            y = math.max(0, math.min(1 - (self.height or 0), y))
            
            return x, y
        else
            print(string.format("RHM: Saved HUD position (%.2f, %.2f) is off-screen. Resetting to default.", x, y))
            -- Proceed to default...
        end
    end
    
    -- Default position: left of speed meter
    if g_currentMission and g_currentMission.hud and g_currentMission.hud.speedMeter then
        local speedMeter = g_currentMission.hud.speedMeter
        local offsetX = speedMeter:scalePixelToScreenWidth(-145)
        local offsetY = speedMeter:scalePixelToScreenHeight(15)
        return speedMeter.speedBg.x + offsetX, speedMeter.speedBg.y + offsetY
    end
    
    -- Fallback
    return 0.7, 0.05
end

---Set HUD position
---@param x number
---@param y number
function DraggableHUD:setPosition(x, y)
    self.x = x
    self.y = y
end

---Set vehicle for HUD
---@param vehicle table|nil
function DraggableHUD:setVehicle(vehicle)
    self.vehicle = vehicle
    if vehicle then
        self:update(vehicle)
    else
        -- Reset data when no vehicle
        self.data.load = 0
        self.data.yield = 0
        self.data.speed = 0
        self.data.cropLoss = 0
        self.data.tonPerHour = 0
        self.data.litersPerHour = 0
        self.data.recommendedSpeed = 0
    end
end

---Update HUD data
---@param dt number optional delta time
function DraggableHUD:update(dt)
    -- Use stored vehicle
    local vehicle = self.vehicle
    if not vehicle then return end
    
    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.data then return end
    
    -- Update data from combine spec
    self.data.load = spec.data.load or 0
    self.data.yield = spec.data.yield or 0
    self.data.cropLoss = spec.data.cropLoss or 0
    self.data.tonPerHour = spec.data.tonPerHour or 0
    self.data.litersPerHour = spec.data.litersPerHour or 0
    self.data.recommendedSpeed = spec.data.recommendedSpeed or 0
    self.data.speed = vehicle:getLastSpeed() or 0
    
    -- Handle dragging directly in update for smoothness
    if self.dragging then
        if g_inputBinding and g_inputBinding.getMousePosition then
            local posX, posY = g_inputBinding:getMousePosition()
            if posX and posY then
                self:moveTo(posX - self.dragOffsetX, posY - self.dragOffsetY)
            end
        end
    end
end

---Draw HUD
function DraggableHUD:draw()
    -- Don't render on server
    if not g_currentMission:getIsClient() then
        return
    end
    
    -- Don't render if HUD is disabled
    if not self.settings.showHUD then
        return
    end
    
    -- Don't render if no vehicle
    if not self.vehicle then
        return
    end
    
    -- Update dynamic height first (so HUD resizes correctly)
    self:updateSize()
    
    -- Update overlay positions (after size update)
    self.backgroundOverlay:setPosition(self.x, self.y)
    self.headerOverlay:setPosition(self.x, self.y + self.height)
    
    -- Update background size
    self.backgroundOverlay:setDimension(self.width, self.height)
    
    -- Draw overlays
    self.backgroundOverlay:render()
    self.headerOverlay:render()
    
    -- Draw header text (Line 1: Title)
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(1, 1, 1, 1)
    local titleTextSize = 0.013
    local headerTextX = self.x + self.width / 2
    local titleTextY = self.y + self.height + self.headerHeight * 0.65
    renderText(headerTextX, titleTextY, titleTextSize, "Realistic Harvesting")
    
    -- Draw header text (Line 2: Settings button - centered, smaller)
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_CENTER)
    
    -- Check if mouse is hovering over settings button area
    local settingsButtonArea = {
        x = self.x, 
        y = self.y + self.height, 
        w = self.width, 
        h = self.headerHeight * 0.4
    }
    local mx, my = g_inputBinding:getMousePosition()
    local isHovered = mx >= settingsButtonArea.x and mx <= settingsButtonArea.x + settingsButtonArea.w and
                      my >= settingsButtonArea.y and my <= settingsButtonArea.y + settingsButtonArea.h
    
    -- Change color on hover
    if isHovered then
        setTextColor(0.6, 1.0, 1.0, 1)  -- Bright cyan on hover
    else
        setTextColor(0.8, 0.8, 1.0, 1)  -- Light blue default
    end
    
    local settingsTextSize = 0.009
    local settingsTextY = self.y + self.height + self.headerHeight * 0.20
    renderText(headerTextX, settingsTextY, settingsTextSize, "Settings")
    setTextBold(false)
    
    -- Store button area for mouse event (full width of header for easier clicking)
    self.menuButtonArea = settingsButtonArea
    
    -- Draw HUD content
    self:drawContent()
    setTextBold(false) -- Reset bold state
end

---Draw HUD content (data rows)
function DraggableHUD:drawContent()
    -- Dynamic sizing based on UI scale (Larger text/icons in compact box)
    local textSize = 0.015 * self.uiScale -- Increased for readability
    local lineHeight = 0.028 * self.uiScale -- Matched to icon size (was 0.025)
    local iconHeight = 0.024 * self.uiScale -- Matched to loadIcons (was 0.022)
    local iconWidth = iconHeight / g_screenAspectRatio
    local padding = 0.005 * self.uiScale
    
    local iconX = self.x + padding
    local textX = iconX + iconWidth + padding
    
    -- Start from top (WITH MORE PADDING FROM HEADER)
    local textY = self.y + self.height - self.headerHeight - (0.005 * self.uiScale)
    
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true) -- User requested bold text
    setTextColor(1, 1, 1, 0.95)
    
    -- Unit system and fruit type for conversion
    local unitSystem = self.settings.unitSystem or 1
    local fruitType = nil
    if self.vehicle and self.vehicle.spec_combine then
        fruitType = self.vehicle.spec_combine.lastValidInputFruitType
    end
    
    -- Row 1: Load (Top Priority)
    if self.settings.showLoad then
        local loadColor = self:getLoadColor(self.data.load)
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "load", 
            string.format("%.0f%%", self.data.load), self.data.load, loadColor[1], loadColor[2], loadColor[3])
        textY = textY - lineHeight
    end
    
    -- Row 2: Yield (t/ha or bu/ac)
    if self.settings.showYield then
        local yieldVal = self.data.yield or 0
        local yieldStr = "---"
        
        -- Always format if we have UnitConverter, creating "0.0 unit"
        if UnitConverter then
            local val, suffix = UnitConverter.convertYield(yieldVal, unitSystem, fruitType)
            yieldStr = string.format("%.1f %s", val, suffix)
        elseif yieldVal > 0 then
            yieldStr = string.format("%.1f t/ha", yieldVal)
        else
            yieldStr = "0.0 t/ha"
        end
        
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "yield", yieldStr, 0)
        textY = textY - lineHeight
    end
    
    -- Row 3: Productivity (t/h or bu/h)
    if self.settings.showProductivity then
        local prodVal = self.data.tonPerHour or 0
        local prodStr = "---"
        
        if UnitConverter then
            local val, suffix = UnitConverter.convertProductivity(prodVal, unitSystem, fruitType, self.data.litersPerHour)
            prodStr = string.format("%.1f %s", val, suffix)
        elseif prodVal > 0 then
            prodStr = string.format("%.1f t/h", prodVal)
        else
            prodStr = "0.0 t/h"
        end
        
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "productivity", prodStr, 0)
        textY = textY - lineHeight
    end
    
    -- Row 4: Crop Loss (loss)
    if self.settings.showCropLoss then
        local lossVal = self.data.cropLoss or 0
        
        -- Format with +/- sign
        local lossStr
        if lossVal > 0.1 then
            -- Loss (red/yellow) - show as negative
            lossStr = string.format("-%.1f%%", lossVal)
        elseif lossVal < -0.1 then
            -- Bonus (green) - show as positive
            lossStr = string.format("+%.1f%%", math.abs(lossVal))
        else
            -- Neutral (0)
            lossStr = "0%"
        end
        
        -- Color coding for loss
        local r, g, b = 1, 1, 1
        if lossVal > 3.0 then r, g, b = 0.9, 0.1, 0.1 -- Red (high loss)
        elseif lossVal > 1.0 then r, g, b = 0.9, 0.8, 0.1 -- Yellow (medium loss)
        elseif lossVal < -0.1 then r, g, b = 0.2, 1.0, 0.2 -- Bright green (bonus)
        else r, g, b = 0.2, 0.8, 0.2 end -- Green (optimal)
        
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "loss", lossStr, lossVal, r, g, b)
        textY = textY - lineHeight
    end

    -- Row 5: Speed (Current / Recommended)
    if self.settings.showSpeed then
        local currentSpeed = self.data.speed -- km/h
        local recSpeed = self.data.recommendedSpeed or 0
        local speedStr
        
        if UnitConverter then
            local cur, suf = UnitConverter.convertSpeed(currentSpeed, unitSystem)
            local rec, _ = UnitConverter.convertSpeed(recSpeed, unitSystem)
            
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
        
        -- Color coding for speed
        local r, g, b = 1, 1, 1
        if recSpeed > 0 then
            if currentSpeed > (recSpeed + 2) then r, g, b = 1, 0.4, 0.4 -- Red
            elseif currentSpeed > recSpeed then r, g, b = 1, 1, 0.4 -- Yellow
            end
        end
        
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "speed", speedStr, 0, r, g, b)
    end
end

---Update HUD size based on active rows
function DraggableHUD:updateSize()
    local rowCount = 0
    if self.settings.showLoad then rowCount = rowCount + 1 end
    if self.settings.showYield then rowCount = rowCount + 1 end
    if self.settings.showProductivity then rowCount = rowCount + 1 end
    if self.settings.showCropLoss then rowCount = rowCount + 1 end
    if self.settings.showSpeed then rowCount = rowCount + 1 end
    
    -- Calculate target height
    local lineHeight = 0.028 * self.uiScale
    local padding = 0.01 * self.uiScale -- Top + Bottom padding
    local targetHeight = (rowCount * lineHeight) + padding
    
    -- Minimum height (at least some padding if empty)
    targetHeight = math.max(0.01 * self.uiScale, targetHeight)
    
    -- If height changed, adjust position to keep header fixed
    if math.abs(self.height - targetHeight) > 0.0001 then
        local heightDiff = self.height - targetHeight
        self.y = self.y + heightDiff
        self.height = targetHeight
        
        -- Update settings (position changed)
        self.settings.hudPosY = self.y
    end
end

---Draw a single row with icon and text
---@param iconX number
---@param textX number
---@param textY number
---@param iconWidth number
---@param iconHeight number
---@param textSize number
---@param iconName string
---@param text string
---@param value number (for original logic, kept for compatibility)
---@param r number|nil Red color component
---@param g number|nil Green color component
---@param b number|nil Blue color component
---@param text string
---@param value number (for original logic, kept for compatibility)
---@param r number|nil Red color component
---@param g number|nil Green color component
---@param b number|nil Blue color component
function DraggableHUD:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, iconName, text, value, r, g, b)
    -- Draw icon
    local icon = self.icons[iconName]
    if icon then
        local iconY = textY + textSize / 2 - iconHeight / 2
        icon:setPosition(iconX, iconY)
        -- Update size not needed per frame usually, but if dynamic resizing? No, loadIcons handles overlay size.
        -- Just position is enough.
        
        -- Override color if provided? No, icons stay white usually.
        -- But let's keep icons white/transparent
        icon:setColor(1, 1, 1, 0.95)
        icon:render()
    end
    
    -- Draw text
    if r and g and b then
        setTextColor(r, g, b, 0.95)
    else
        setTextColor(1, 1, 1, 0.95)
    end
    renderText(textX, textY, textSize, text)
end

---Get color for load value
---@param load number Load percentage (0-100)
---@return table {r, g, b}
function DraggableHUD:getLoadColor(load)
    if load < 50 then
        return {1, 1, 1} -- White
    elseif load < 80 then
        return {1, 1, 0.4} -- Yellow
    else
        return {1, 0.4, 0.4} -- Red
    end
end

---Check if mouse is over header
---@param posX number
---@param posY number
---@return boolean
function DraggableHUD:isMouseOverHeader(posX, posY)
    return posX >= self.x and posX <= (self.x + self.width) and
           posY >= (self.y + self.height) and posY <= (self.y + self.height + self.headerHeight)
end

---Handle mouse event (Courseplay approach)
---@param posX number
---@param posY number
---@param isDown boolean
---@param isUp boolean
---@param button number
---@return boolean handled
function DraggableHUD:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.settings.showHUD then
        return false
    end
    
    -- Only handle left mouse button
    if button ~= Input.MOUSE_BUTTON_LEFT then
        return false
    end
    
    -- Check Menu Button Click
    if self.menuButtonArea and isDown then
        if posX >= self.menuButtonArea.x and posX <= (self.menuButtonArea.x + self.menuButtonArea.w) and
           posY >= self.menuButtonArea.y and posY <= (self.menuButtonArea.y + self.menuButtonArea.h) then
            
            if g_realisticHarvestManager then
                g_realisticHarvestManager:toggleMenu(self.vehicle)
                return true
            end
        end
    end
    
    -- Handle start and end of dragging
    if isDown and self:isMouseOverHeader(posX, posY) then
        if not self.dragging then
            self.dragStartX = posX
            self.dragOffsetX = posX - self.x
            self.dragStartY = posY
            self.dragOffsetY = posY - self.y
            self.dragging = true
            self.lastDragTimeStamp = g_time
            print("RHM: Drag started")
            return true
        end
    elseif isUp then
        if self.dragging then
            self.dragging = false
            print(string.format("RHM: Drag stopped at (%.3f, %.3f)", self.x, self.y))
            
            -- Save settings on drag end (once)
            if self.settings and self.settings.save then
                self.settings:save()
            end
            
            return true
        end
    end
    
    -- Move logic is in update()
    return false
end

---Move HUD to new position
---@param x number
---@param y number
function DraggableHUD:moveTo(x, y)
    -- Constrain to screen bounds
    x = math.max(0, math.min(1 - self.width, x))
    y = math.max(0, math.min(1 - (self.height + self.headerHeight), y))
    
    self:setPosition(x, y)
    
    -- Save to settings object (memory only)
    self.settings.hudPosX = x
    self.settings.hudPosY = y
    
    -- Removed settings:save() from here to prevent Async Task exhaustion (called every frame)
    -- Save is now triggered on Drag Stop
end

---Unload resources
function DraggableHUD:delete()
    if self.backgroundOverlay then
        self.backgroundOverlay:delete()
    end
    
    if self.headerOverlay then
        self.headerOverlay:delete()
    end
    
    for _, icon in pairs(self.icons) do
        if icon then
            icon:delete()
        end
    end
    
    print("RHM: DraggableHUD unloaded")
end

return DraggableHUD
