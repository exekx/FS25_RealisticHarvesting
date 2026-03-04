
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
            buttonHover = {0.3, 0.4, 0.5, 1}, -- Blueish highlight on hover
            buttonActive = {0.4, 0.4, 0.4, 1},
            paramRowHover = {0.15, 0.15, 0.15, 0.8} -- Subtle row highlight
        }
    }
    
    -- State
    self.activeVehicle = nil
    self.hoveredElement = nil
    self.mouseX = 0
    self.mouseY = 0
    self.hoveredParameter = nil  -- Track which parameter row is hovered
    
    -- Storage for camera rotation and zoom state
    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}
    
    -- Wheel scroll debouncing
    self.lastScrollTimeStamp = 0
    self.scrollDelayMs = 100  -- Milliseconds between wheel events
    
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
    
    -- NEXAT FIX: Шукаємо vehicle з spec_rhm_Combine у всій ієрархії
    -- (на modular systems як NEXAT гравець може бути в секції без spec_rhm_Combine)
    local combineVehicle = vehicle
    if vehicle and not vehicle.spec_rhm_Combine then
        -- Шукаємо у rootVehicle та прикріплених
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
            print(string.format("RHM: [GUI] NEXAT: found combine vehicle in hierarchy: %s", tostring(combineVehicle)))
        else
            print("RHM: [GUI] No combine with spec_rhm_Combine found in vehicle hierarchy — GUI will not open")
            return
        end
    end
    
    self.isOpen = true
    
    -- Manage cursor
    g_inputBinding:setShowMouseCursor(true)
    self.isCursorActive = true
    
    -- Block camera rotation AND zoom
    -- We must block it on the vehicle the player is ACTUALLY sitting in
    local cv = nil
    if g_realisticHarvestManager then
        cv = g_realisticHarvestManager:getControlledVehicle()
    else
        cv = g_currentMission.controlledVehicle
    end
    
    if cv and cv.spec_enterable then
        for _, camera in pairs(cv.spec_enterable.cameras) do
            self.savedCameraRotatableInfo[camera] = camera.isRotatable
            self.savedCameraZoomInfo[camera] = camera.allowZoom
            camera.isRotatable = false
            camera.allowTranslation = false
            camera.allowZoom = false  -- Блокуємо zoom (колесо миші)
        end
    end
    
    -- Use found combine vehicle (works for NEXAT and standard combines)
    self.activeVehicle = combineVehicle
    -- NEXAT FIX: remember the vehicle the player is actually sitting in
    self.controllerVehicle = cv or vehicle or combineVehicle
end

function CombineCalibrationGUI:close()
    if not self.isOpen then return end
    
    self.isOpen = false
    self.isCursorActive = false
    
    -- NEXAT FIX: Must restore cameras on the vehicle the player actually sits in
    local vehicle = self.controllerVehicle
    
    -- Check if HUD cursor is also active (from RealisticHarvestManager:toggleCursor)
    local hudCursorActive = g_realisticHarvestManager and g_realisticHarvestManager.isCursorVisible
    
    -- Restore cursor: keep it active only if HUD cursor mode is still on
    g_inputBinding:setShowMouseCursor(hudCursorActive or false)
    
    -- FIX: Restore camera rotation and zoom ALWAYS
    if vehicle and vehicle.spec_enterable then
        for _, camera in pairs(vehicle.spec_enterable.cameras) do
            local savedRotatable = self.savedCameraRotatableInfo[camera]
            local savedZoom = self.savedCameraZoomInfo[camera]
            camera.isRotatable = savedRotatable ~= nil and savedRotatable or true
            camera.allowTranslation = savedZoom ~= nil and savedZoom or true
            camera.allowZoom = savedZoom ~= nil and savedZoom or true  -- Відновлюємо zoom
        end
        self.savedCameraRotatableInfo = {}
        self.savedCameraZoomInfo = {}
    end
    
    -- If HUD cursor is still active, re-block camera rotation (but not from CalibrationGUI's saved state)
    if hudCursorActive and vehicle and vehicle.spec_enterable then
        RHMInputUtil.setCameraRotation(vehicle, false, g_realisticHarvestManager.savedCameraRotatableInfo)
    end
end

function CombineCalibrationGUI:cycleCrop(direction)
    local spec = self.activeVehicle.spec_rhm_Combine
    local machineType = spec.machineType or "grain"
    -- Show only crops relevant to this machine type
    local crops = CombineSettingsDatabase:getCropNamesForMachineType(machineType)
    if #crops == 0 then return end
    
    local current = spec.combineMemory.currentCrop
    local index = 1
    
    if current then
        for i, name in ipairs(crops) do
            if name == current then
                index = i
                break
            end
        end
    end
    
    index = index + direction
    if index > #crops then index = 1 end
    if index < 1 then index = #crops end
    
    local newCrop = crops[index]
    spec.combineMemory:switchCrop(newCrop)
end

---Main update loop
---Перехоплює події миші — блокує scroll (zoom камери) поки GUI відкритий
---@return boolean true якщо подія з'їдена (не передається далі)
function CombineCalibrationGUI:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    if not self.isOpen then return false end
    
    -- З'їдаємо scroll wheel (button 4 = up, button 5 = down у GIANTS Engine)
    if button == Input.MOUSE_BUTTON_WHEEL_UP or button == Input.MOUSE_BUTTON_WHEEL_DOWN then
        return true  -- Подія оброблена — не передаємо далі
    end
    
    return false
end

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
    
    -- Check if player is still entered in the vehicle they were controlling (NEXAT safe)
    -- For NEXAT: controllerVehicle = cab ; activeVehicle = combine module
    local vehicleToCheck = self.controllerVehicle or self.activeVehicle
    local isEntered = false
    
    if vehicleToCheck then
        local cv = nil
        if g_realisticHarvestManager then
            cv = g_realisticHarvestManager:getControlledVehicle()
        else
            cv = g_currentMission.controlledVehicle
        end
        
        if cv then
            -- 1. Direct match
            if cv == vehicleToCheck then
                isEntered = true
            -- 2. Player is in a vehicle that belongs to the same modular system (NEXAT)
            else
                local rootA = cv.rootVehicle or cv
                local rootB = vehicleToCheck.rootVehicle or vehicleToCheck
                if rootA == rootB then
                    isEntered = true
                end
            end
        end
        
        -- Fallback check for AI or direct enter
        if not isEntered and vehicleToCheck.getIsEntered then
            isEntered = vehicleToCheck:getIsEntered()
        end
    end

    if not isEntered then
        print("RHM: [GUI] Closing due to isEntered=false."
            .. " RHM_cv=" .. tostring(g_realisticHarvestManager and g_realisticHarvestManager:getControlledVehicle())
            .. " vToCheck=" .. tostring(vehicleToCheck) 
            .. " (root=" .. tostring(vehicleToCheck and (vehicleToCheck.rootVehicle or vehicleToCheck)) .. ")")
        self:close()
    end
end

---Draw the GUI
function CombineCalibrationGUI:draw()
    if not self.isOpen then return end
    if not (g_currentMission and g_currentMission.hud) then 
        if self.debug then print("RHM: [GUI] draw() abort: no g_currentMission.hud") end
        return 
    end
    
    -- Reset button registry for this frame
    self.buttons = {}
    self.hoveredParameter = nil  -- Reset hover state
    
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
    renderText(x + w/2, y + h - ui.headerHeight + 0.01, ui.titleSize, g_i18n:getText("rhm_gui_title"))
    
    -- Content Start Y
    local cy = y + h - ui.headerHeight - ui.margin - ui.lineHeight
    
    if not self.activeVehicle then
        if self.debug then print("RHM: [GUI] draw() rendering 'No Combine Selected'") end
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(x + w/2, cy, ui.fontSize, g_i18n:getText("rhm_gui_no_combine"))
        return
    end
    
    local spec = self.activeVehicle.spec_rhm_Combine
    
    if not spec or not spec.combineMemory then
        if self.debug then print("RHM: [GUI] draw() rendering 'Combine not initialized' | spec="..tostring(spec~=nil).." memory="..tostring(spec and spec.combineMemory~=nil)) end
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(x + w/2, cy, ui.fontSize, g_i18n:getText("rhm_gui_not_init"))
        return
    end
    
    local memory = spec.combineMemory
    
    -- 3. Crop Info
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(x + ui.margin, cy + 0.005, ui.fontSize, g_i18n:getText("rhm_gui_crop"))
    
    local cropName = memory.currentCrop or "NONE"
    local cropX = x + ui.margin + 0.05 -- Offset for label
    
    -- Previous Button [<]
    self:drawButton(cropX, cy, 0.025, 0.035, "<", function()
        self:cycleCrop(-1)
    end)
    
    -- Crop Name
    setTextAlignment(RenderText.ALIGN_CENTER)
    renderText(cropX + 0.025 + 0.07, cy + 0.005, ui.fontSize, memory.currentCrop or g_i18n:getText("rhm_gui_none"))
    
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
    self:drawButton(x + ui.margin, cy, btnWidth, 0.035, g_i18n:getText("rhm_gui_btn_auto"), function()
        memory:autoConfigureForCrop(memory.currentCrop, true)
    end, {0.9, 0.7, 0.1, 1})
    
    -- [ LOAD ] Button (User Preset)
    self:drawButton(x + w - ui.margin - btnWidth, cy, btnWidth, 0.035, g_i18n:getText("rhm_gui_btn_load_preset"), function()
        memory:loadUserPreset()
    end, {0.1, 0.5, 0.9, 1})
    
    cy = cy - ui.lineHeight * 1.5
    
    -- 4. Parameters — dynamically based on machine type
    local machineType = spec.machineType or "grain"
    local activeParams = CombineSettingsDatabase:getParamsForMachineType(machineType)
    
    for _, param in ipairs(activeParams) do
        local labelKey = CombineSettingsDatabase:getParamLabel(machineType, param)
        local label = g_i18n:hasText(labelKey) and g_i18n:getText(labelKey) or param
        self:drawParameterRow(x + ui.margin, cy, w - ui.margin*2, param, label, memory, ui)
        cy = cy - ui.lineHeight
    end
    
    cy = cy - ui.lineHeight * 0.5
    
    cy = cy - ui.lineHeight * 0.5
    
    -- 5. Loss Status — settings-based preview (always shown, accurate)
    -- cropLoss in LoadCalculator is not populated → always use calcSettingsLossPreview
    local load = (spec.loadCalculator and spec.loadCalculator.engineLoad or 0) * 100
    
    local previewLoss = 0
    if memory.currentCrop then
        previewLoss = CombineSettingsDatabase:calcSettingsLossPreview(memory.currentCrop, memory.currentSettings)
    end
    
    local lossColor = ui.colors.text
    if previewLoss > 0.5 then lossColor = ui.colors.warning end
    if previewLoss > 3.0 then lossColor = ui.colors.error end
    
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.textDim))
    renderText(x + ui.margin, cy + 0.005, ui.fontSize, string.format(g_i18n:getText("rhm_gui_engine_load"), load))
    
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(unpack(lossColor))
    renderText(x + w - ui.margin, cy + 0.005, ui.fontSize, string.format(g_i18n:getText("rhm_gui_preview_loss"), previewLoss))

    
    cy = cy - ui.lineHeight * 1.5
    
    -- 6. Profile Management
    self:drawButton(x + ui.margin, cy, 0.12, 0.035, g_i18n:getText("rhm_gui_btn_save"), function()
        memory:saveCurrentProfile(memory.currentCrop)
    end)
    
    self:drawButton(x + w - ui.margin - 0.12, cy, 0.12, 0.035, g_i18n:getText("rhm_gui_btn_reset"), function()
        memory:autoConfigureForCrop(memory.currentCrop)
    end, ui.colors.warning)
    
    cy = cy - ui.lineHeight
    
    -- Tooltip/Hint
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(ui.colors.textDim))
    renderText(x + w/2, cy + 0.005, ui.fontSize * 0.9, g_i18n:getText("rhm_gui_close_hint"))
    
    -- Now hoveredParameter is set, so we can handle wheel scroll
    if self.lastScrollTimeStamp + self.scrollDelayMs < g_time then
        local mx, my = g_inputBinding:getMousePosition()
        
        -- Check if mouse is inside GUI
        if mx >= ui.x and mx <= ui.x + ui.w and my >= ui.y and my <= ui.y + ui.h then
            -- Check for wheel press
            if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
                self.lastScrollTimeStamp = g_time
                self:handleWheelScroll(1, mx, my)  -- +1 for up
            elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
                self.lastScrollTimeStamp = g_time
                self:handleWheelScroll(-1, mx, my)  -- -1 for down
            end
        end
    end
    
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
    
    -- Check if mouse is hovering over this row
    local isHovered = self:checkHover(x, y - 0.003, w, ui.lineHeight)
    
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
    
    -- Value box with hover highlight (center area only)
    local valBoxX = x + w * 0.25  -- Start at 25% of row width
    local valBoxW = w * 0.5       -- 50% of row width for value area
    local valBoxY = y - 0.003
    local valBoxH = ui.lineHeight
    
    -- Check if hovered over VALUE BOX specifically
    local isValueHovered = self:checkHover(valBoxX, valBoxY, valBoxW, valBoxH)
    if isValueHovered then
        -- Set hoveredParameter for wheel scroll
        self.hoveredParameter = param
    end
    
    local valColor = isOptimal and ui.colors.success or ui.colors.text
    if memory.autoSwitchEnabled then valColor = ui.colors.textDim end -- Dim in auto mode
    
    -- Override color if hovered - bright cyan like buttons
    if isValueHovered then
        valColor = {0.6, 1.0, 1.0, 1}
    end
    
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
    
    -- Draw button background (same color always)
    local bgColor = colorOverride or self.ui.colors.button
    self:drawRect(x, y, w, h, bgColor)
    
    -- Change TEXT color on hover (like HUD Settings button)
    setTextAlignment(RenderText.ALIGN_CENTER)
    if isHovered then
        setTextColor(0.6, 1.0, 1.0, 1)  -- Bright cyan on hover
    else
        setTextColor(1, 1, 1, 1)  -- White default
    end
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
    -- Use tracked mouse position from mouseEvent, fallback to getMousePosition
    local mx, my = self.mouseX, self.mouseY
    if not mx or not my then
        mx, my = g_inputBinding:getMousePosition()
    end
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

---Handle mouse events
function CombineCalibrationGUI:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isOpen then return end
    
    -- Always track mouse position for hover effects (every frame)
    self.mouseX = posX
    self.mouseY = posY
    
    -- Check if inside GUI window
    local insideGUI = posX >= self.ui.x and posX <= self.ui.x + self.ui.w and
                      posY >= self.ui.y and posY <= self.ui.y + self.ui.h
    
    -- PRIORITY: Consume ALL wheel events when inside GUI to prevent camera zoom
    local isWheel = button == Input.MOUSE_BUTTON_WHEEL_UP or button == Input.MOUSE_BUTTON_WHEEL_DOWN
    if isWheel and insideGUI then
        -- Handle parameter adjustment ONLY on isDown to prevent double-trigger
        if isDown then
            local wheelUp = button == Input.MOUSE_BUTTON_WHEEL_UP
            local delta = wheelUp and 1 or -1
            
            -- Check for Shift modifier (5x faster)
            if Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift) then
                delta = delta * 5
            end
            
            -- Check if mouse is over a parameter and adjust
            local param = self:getParameterAtMouse(posX, posY)
            if param then
                local spec = self.activeVehicle.spec_rhm_Combine
                if spec and spec.combineMemory then
                    local currentVal = spec.combineMemory.currentSettings[param]
                    spec.combineMemory:updateSetting(param, currentVal + delta)
                end
            end
        end
        -- ALWAYS return true for wheel events inside GUI
        return true
    end
    
    -- Handle button clicks
    if isDown and button == Input.MOUSE_BUTTON_LEFT then
        for _, btn in ipairs(self.buttons) do
            if posX >= btn.x and posX <= btn.x + btn.w and posY >= btn.y and posY <= btn.y + btn.h then
                if btn.callback then
                    btn.callback()
                end
                return true -- Consumed
            end
        end
    end
    
    -- Consume all events inside GUI window
    if insideGUI then
       return true
    end
end

---Handle wheel scroll
---@param direction number 1 for up, -1 for down
---@param posX number Mouse X position
---@param posY number Mouse Y position
function CombineCalibrationGUI:handleWheelScroll(direction, posX, posY)
    -- Check for Shift modifier (5x faster)
    local delta = direction
    if Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift) then
        delta = delta * 5
    end
    
    -- This will check if mouse is over a parameter (set during draw)
    -- We need to manually check here since hoveredParameter is set later in draw
    -- For now, we can use current mouse position to determine parameter
    
    -- Apply to active vehicle's settings
    if self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
        local spec = self.activeVehicle.spec_rhm_Combine
        if spec.combineMemory and self.hoveredParameter then
            local currentVal = spec.combineMemory.currentSettings[self.hoveredParameter]
            spec.combineMemory:updateSetting(self.hoveredParameter, currentVal + delta)
        end
    end
end

---Get parameter name at mouse position (for wheel scroll)
---@param x number
---@param y number
---@return string|nil Parameter name if mouse is over a parameter row
function CombineCalibrationGUI:getParameterAtMouse(x, y)
    -- This will be populated during draw() with clickable parameter areas
    if self.hoveredParameter then
        return self.hoveredParameter
    end
    return nil
end
