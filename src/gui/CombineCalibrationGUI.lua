
CombineCalibrationGUI = {}
local CombineCalibrationGUI_mt = Class(CombineCalibrationGUI)

function CombineCalibrationGUI.new(modDirectory)
    local self = setmetatable({}, CombineCalibrationGUI_mt)
    self.modDirectory = modDirectory
    self.isOpen = false
    self.isCursorActive = false
    self.debug = true -- Enable logging
    
    -- UI Configuration
    self.ui = {
        x = 0.68, y = 0.45, -- Position (Right side)
        w = 0.30, h = 0.45, -- Size
        margin = 0.01,
        headerHeight = 0.04,
        lineHeight = 0.035,
        fontSize = 0.014,
        titleSize = 0.020,
        buttonW = 0.025,
        buttonH = 0.025,
        
        colors = {
            bg = {0.05, 0.05, 0.05, 0.9},
            header = {0.1, 0.1, 0.1, 0.95},
            text = {1, 1, 1, 1},
            textDim = {0.7, 0.7, 0.7, 1},
            accent = {0.2, 0.6, 1.0, 1}, -- Blue
            warning = {1.0, 0.6, 0.2, 1}, -- Orange
            error = {0.9, 0.2, 0.2, 1},   -- Red
            success = {0.2, 0.8, 0.2, 1}, -- Green
            button = {0.2, 0.2, 0.2, 1},
            buttonHover = {0.3, 0.3, 0.3, 1},
            buttonActive = {0.4, 0.4, 0.4, 1}
        }
    }
    
    -- State
    self.activeVehicle = nil
    self.hoveredElement = nil
    
    -- Buttons registry for click handling
    self.buttons = {} 
    
    -- Create persistent overlay for rendering
    -- Use texture from mod or fallback to nil (Overlay handles missing file gracefully usually, or we ensure path)
    -- Using DraggableHUD's texture which is known to work
    local bgTexture = self.modDirectory .. "textures/hud_background.dds"
    self.overlay = Overlay.new(bgTexture, 0, 0, 1, 1)
    
    return self
end

function CombineCalibrationGUI:delete()
    if self.overlay then
        self.overlay:delete()
        self.overlay = nil
    end
end

---Toggle the GUI visibility
---Toggle the GUI visibility
---Toggle the GUI visibility
function CombineCalibrationGUI:toggle(vehicle)
    if self.isOpen then
        self:close()
    else
        self:open(vehicle)
    end
end

function CombineCalibrationGUI:open(vehicle)
    if self.isOpen then return end
    
    self.isOpen = true
    
    -- Manage cursor
    g_inputBinding:setShowMouseCursor(true)
    self.isCursorActive = true
    
    -- Use passed vehicle or fallback
    self.activeVehicle = vehicle or (g_currentMission and g_currentMission.controlledVehicle)
end

function CombineCalibrationGUI:close()
    if not self.isOpen then return end
    
    self.isOpen = false
    self.isCursorActive = false
    
    -- Restore cursor
    local rhmCursor = g_realisticHarvestManager and g_realisticHarvestManager.isCursorVisible
    g_inputBinding:setShowMouseCursor(rhmCursor or false)
end

function CombineCalibrationGUI:cycleCrop(direction)
    local allCrops = CombineSettingsDatabase:getAllCropNames()
    -- Find current index
    local current = self.activeVehicle.spec_rhm_Combine.combineMemory.currentCrop
    local index = 1
    
    -- If current is nil, start at 1
    if current then
        for i, name in ipairs(allCrops) do
            if name == current then 
                index = i 
                break 
            end
        end
    end
    
    -- Update index
    index = index + direction
    if index > #allCrops then index = 1 end
    if index < 1 then index = #allCrops end
    
    -- Switch
    local newCrop = allCrops[index]
    self.activeVehicle.spec_rhm_Combine.combineMemory:switchCrop(newCrop)
end

---Main update loop
function CombineCalibrationGUI:update(dt)
    if not self.isOpen then return end
    
    -- Check if vehicle exists
    if not self.activeVehicle then
         self:close()
         return
    end
    
    -- Check if vehicle has our spec
    if not self.activeVehicle.spec_rhm_Combine then
        -- Inactive but open
    end
    
    -- Check if player is still entered in THIS vehicle
    local isEntered = false
    if self.activeVehicle.getIsEntered then
        isEntered = self.activeVehicle:getIsEntered()
    elseif g_currentMission.controlledVehicle == self.activeVehicle then
        isEntered = true
    end

    if not isEntered then
        self:close()
    end
end

---Draw the GUI
function CombineCalibrationGUI:draw()
    if not self.isOpen then return end
    if not (g_currentMission and g_currentMission.hud) then return end
    
    -- Reset button registry for this frame
    self.buttons = {}
    
    local ui = self.ui
    local x, y = ui.x, ui.y
    local w, h = ui.w, ui.h
    
    -- 1. Background
    self:drawRect(x, y, w, h, ui.colors.bg)
    
    -- 2. Header
    self:drawRect(x, y + h - ui.headerHeight, w, ui.headerHeight, ui.colors.header)
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(ui.colors.text))
    renderText(x + w/2, y + h - ui.headerHeight + 0.01, ui.titleSize, "COMBINE SETTINGS")
    
    -- Content Start Y
    local cy = y + h - ui.headerHeight - ui.margin - ui.lineHeight
    
    if not self.activeVehicle then
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(x + w/2, cy, ui.fontSize, "No Combine Selected")
        return
    end
    
    local spec = self.activeVehicle.spec_rhm_Combine
    
    if not spec or not spec.combineMemory then
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(x + w/2, cy, ui.fontSize, "Combine not initialized")
        return
    end
    
    local memory = spec.combineMemory
    
    -- 3. Crop Info
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(x + ui.margin, cy + 0.005, ui.fontSize, "Crop:")
    
    local cropName = memory.currentCrop or "NONE"
    local cropX = x + ui.margin + 0.05 -- Offset for label
    
    -- Previous Button [<]
    self:drawButton(cropX, cy, 0.025, 0.035, "<", function()
        self:cycleCrop(-1)
    end)
    
    -- Crop Name
    setTextAlignment(RenderText.ALIGN_CENTER)
    renderText(cropX + 0.025 + 0.07, cy + 0.005, ui.fontSize, cropName)
    
    -- Next Button [>]
    self:drawButton(cropX + 0.025 + 0.14, cy, 0.025, 0.035, ">", function()
        self:cycleCrop(1)
    end)
    
    cy = cy - ui.lineHeight * 1.2
    
    -- Mode Buttons (User Request: Split Auto and Preset)
    setTextAlignment(RenderText.ALIGN_LEFT)
    -- renderText(x + ui.margin, cy + 0.005, ui.fontSize, "Presets:") -- Label optional, maybe just buttons
    
    local btnWidth = (w - ui.margin * 2.5 - 0.01) / 2 -- Slightly narrower
    
    -- [ AUTO ] Button (Default optimal)
    self:drawButton(x + ui.margin, cy, btnWidth, 0.035, "AUTO", function()
        memory:autoConfigureForCrop(memory.currentCrop, true) -- Force optimal (now suboptimal/safe)
    end, {0.9, 0.7, 0.1, 1}) -- Yellowish
    
    -- [ LOAD ] Button (User Preset)
    self:drawButton(x + w - ui.margin - btnWidth, cy, btnWidth, 0.035, "LOAD PRESET", function()
        memory:loadUserPreset()
    end, {0.1, 0.5, 0.9, 1}) -- Blueish
    
    cy = cy - ui.lineHeight * 1.5
    
    -- 4. Parameters
    local params = {"fan", "rotor", "upperSieve", "lowerSieve", "feeder"}
    local labels = {fan="Fan Speed", rotor="Rotor Speed", upperSieve="Upper Sieve", lowerSieve="Lower Sieve", feeder="Feeder House"}
    
    for _, param in ipairs(params) do
        self:drawParameterRow(x + ui.margin, cy, w - ui.margin*2, param, labels[param], memory, ui)
        cy = cy - ui.lineHeight
    end
    
    cy = cy - ui.lineHeight * 0.5
    
    cy = cy - ui.lineHeight * 0.5
    
    -- Yield Calibration REMOVED (User Request)
    -- 5. Loss Status
    local load = (spec.loadCalculator and spec.loadCalculator.engineLoad or 0) * 100
    local loss = spec.loadCalculator and spec.loadCalculator.cropLoss or 0
    
    local lossColor = ui.colors.text
    if loss > 0.1 then lossColor = ui.colors.warning end
    if loss > 2.0 then lossColor = ui.colors.error end
    
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.textDim))
    renderText(x + ui.margin, cy + 0.005, ui.fontSize, string.format("Engine Load: %.0f%%", load))
    
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(unpack(lossColor))
    renderText(x + w - ui.margin, cy + 0.005, ui.fontSize, string.format("Loss: %.1f%%", loss))
    
    cy = cy - ui.lineHeight * 1.5
    
    -- 6. Profile Management
    self:drawButton(x + ui.margin, cy, 0.12, 0.035, "SAVE PROFILE", function()
        -- Save logic (needs specific implementation, maybe input dialog? For now simple save)
        memory:saveProfile(memory.currentCrop)
    end)
    
    self:drawButton(x + w - ui.margin - 0.12, cy, 0.12, 0.035, "RESET DEFAULT", function()
         memory:autoConfigureForCrop(memory.currentCrop)
    end, ui.colors.warning)
    
    cy = cy - ui.lineHeight
    
    -- Tooltip/Hint
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(ui.colors.textDim))
    renderText(x + w/2, cy + 0.005, ui.fontSize * 0.9, "RShift+K to Close")
    
    -- Restore defaults
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

---Helper to draw parameter row with [-] [+] buttons
function CombineCalibrationGUI:drawParameterRow(x, y, w, param, label, memory, ui)
    local val = memory.currentSettings[param] or 0
    local optimal = 0
    local isOptimal = false
    
    -- Check optimal from DB if available
    if CombineSettingsDatabase and memory.currentCrop then
        local settings = CombineSettingsDatabase:getSettingsForCrop(memory.currentCrop)
        if settings and settings[param] then
            optimal = settings[param].optimal
            if math.abs(val - optimal) <= (settings[param].tolerance or 5) then
                isOptimal = true
            end
        end
    end
    
    -- Label
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.text))
    renderText(x, y + 0.005, ui.fontSize, label)
    
    -- Value
    local valColor = isOptimal and ui.colors.success or ui.colors.text
    if memory.autoSwitchEnabled then valColor = ui.colors.textDim end -- Dim in auto mode
    
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(valColor))
    renderText(x + w * 0.5, y + 0.005, ui.fontSize, string.format("%d%%", val))
    
    -- Buttons [-] [+] (Always visible, auto-switch to MANUAL on click)
    -- Minus
    self:drawButton(x + w - ui.buttonW*2 - 0.005, y, ui.buttonW, ui.buttonH, "-", function()
        memory:updateSetting(param, val - 1) -- This auto-switches to MANUAL
    end)
    
    -- Plus
    self:drawButton(x + w - ui.buttonW, y, ui.buttonW, ui.buttonH, "+", function()
        memory:updateSetting(param, val + 1) -- This auto-switches to MANUAL
    end)
end

---Helper to draw a button
function CombineCalibrationGUI:drawButton(x, y, w, h, text, callback, colorOverride)
    -- Check hover
    local isHovered = self:checkHover(x, y, w, h)
    local color = colorOverride or self.ui.colors.button
    if isHovered then color = self.ui.colors.buttonHover end
    
    self:drawRect(x, y, w, h, color)
    
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(1, 1, 1, 1)
    renderText(x + w/2, y + h/2 - self.ui.fontSize/2.5, self.ui.fontSize, text)
    
    -- Register click area
    table.insert(self.buttons, {x=x, y=y, w=w, h=h, callback=callback})
end

function CombineCalibrationGUI:drawRect(x, y, w, h, color)
    if not self.overlay then return end
    local r, g, b, a = unpack(color)
    self.overlay:setPosition(x, y)
    self.overlay:setDimension(w, h)
    self.overlay:setColor(r, g, b, a)
    self.overlay:render()
end

function CombineCalibrationGUI:checkHover(x, y, w, h)
    local mx, my = g_inputBinding:getMousePosition()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

---Handle mouse events
function CombineCalibrationGUI:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isOpen then return end
    
    if isDown and button == Input.MOUSE_BUTTON_LEFT then
        for _, btn in ipairs(self.buttons) do
            if posX >= btn.x and posX <= btn.x + btn.w and posY >= btn.y and posY <= btn.y + btn.h then
                if btn.callback then
                    btn.callback()
                    -- Add sound effect?
                end
                return true -- Consumed
            end
        end
    end
    
    -- Detect click inside window to prevent camera movement/interaction with game world
    if posX >= self.ui.x and posX <= self.ui.x + self.ui.w and
       posY >= self.ui.y and posY <= self.ui.y + self.ui.h then
       return true -- Consume event inside window
    end
end
