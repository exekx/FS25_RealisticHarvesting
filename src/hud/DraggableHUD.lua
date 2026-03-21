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

-- EN: Minimum drag time delay before a click becomes a drag (milliseconds).
-- UA: Мінімальна затримка часу перед тим як клік стане перетягуванням (мілісекунди).
DraggableHUD.DRAG_DELAY_MS = 15

-- EN: Minimum pixel distance moved before treating as a drag (prevents accidental moves on click).
-- UA: Мінімальна відстань переміщення в пікселях щоб вважати це перетягуванням (запобігає випадковому переміщенню при кліку).
DraggableHUD.DRAG_LIMIT = 2

-- EN: Creates a new HUD instance. Resources are loaded separately via :load().
-- UA: Створює новий екземпляр HUD. Ресурси завантажуються окремо через :load().
function DraggableHUD.new(modDirectory, settings)
    local self = setmetatable({}, DraggableHUD)

    self.modDirectory = modDirectory
    self.settings = settings
    self.vehicle = nil

    -- EN: Live data cache updated each frame from the combine spec.
    -- UA: Кеш живих даних що оновлюється щокадру зі специфікації комбайна.
    self.data = {
        load = 0,
        yield = 0,
        speed = 0,
        moisture = 0,
        cropLoss = 0,
        tonPerHour = 0,
        litersPerHour = 0,
        recommendedSpeed = 0
    }

    -- EN: Normalized screen-space dimensions (0-1). Scaled in load() based on UI scale.
    -- UA: Нормалізовані розміри в просторі екрану (0-1). Масштабуються в load() за масштабом UI.
    self.width = 0.11
    self.height = 0.18
    self.headerHeight = 0.028
    self.uiScale = 1.0

    -- EN: Drag state — tracking whether the user is currently dragging the HUD.
    -- UA: Стан перетягування — відстежуємо чи зараз користувач перетягує HUD.
    self.dragging = false
    self.dragStartX = nil
    self.dragOffsetX = nil
    self.dragStartY = nil
    self.dragOffsetY = nil
    self.lastDragTimeStamp = nil

    self.backgroundOverlay = nil
    self.headerOverlay = nil
    self.icons = {}

    return self
end

-- EN: Loads HUD textures, icons, and calculates initial position based on UI scale.
--     Must be called after the mission is loaded (textures require the game to be initialized).
-- UA: Завантажує текстури HUD, іконки та розраховує початкову позицію за масштабом UI.
--     Має викликатись після завантаження місії (текстури потребують ініціалізацію гри).
function DraggableHUD:load()
    self.uiScale = 1.0
    if g_gameSettings then
        self.uiScale = g_gameSettings:getValue("uiScale") or 1.0
    end

    -- EN: Scale all dimensions to match the game's UI scale setting.
    -- UA: Масштабуємо всі розміри відповідно до налаштування масштабу UI гри.
    self.width = 0.09 * self.uiScale
    self.height = 0.155 * self.uiScale
    self.headerHeight = 0.030 * self.uiScale

    self.x, self.y = self:getPosition()

    -- EN: Create the colored header strip (green) above the main panel.
    -- UA: Створюємо кольорову смугу заголовку (зелену) над основною панеллю.
    local headerTexture = self.modDirectory .. "textures/hud_background.dds"
    self.headerOverlay = Overlay.new(headerTexture, self.x, self.y + self.height, self.width, self.headerHeight)
    self.headerOverlay:setColor(0.22323, 0.40724, 0.00368, 1)

    -- EN: Create the semi-transparent dark background panel.
    -- UA: Створюємо напівпрозору темну фонову панель.
    self.backgroundOverlay = Overlay.new(headerTexture, self.x, self.y, self.width, self.height)
    self.backgroundOverlay:setColor(0, 0, 0, 0.5)

    self:loadIcons(self.uiScale)

    if RHM_Debug and RHM_Debug.isEnabled("UI") then
        print("RHM: DraggableHUD loaded successfully")
    end
end

-- EN: Loads icon overlay objects for each HUD row (load, yield, speed, loss, productivity).
--     Icons are sized proportionally to the UI scale and aspect ratio.
-- UA: Завантажує оверлеї іконок для кожного рядка HUD (навантаження, врожайність, швидкість, втрати, продуктивність).
--     Іконки масштабуються пропорційно до масштабу UI та співвідношення сторін.
function DraggableHUD:loadIcons(uiScale)
    local iconHeight = 0.024 * self.uiScale
    local iconWidth = iconHeight / g_screenAspectRatio

    local iconsPath = self.modDirectory .. "textures/"

    local iconNames = {
        load         = "icon_load",
        yield        = "icon_yield",
        moisture     = "icon_moisture",
        speed        = "icon_speed",
        loss         = "icon_loss",
        productivity = "icon_productivity"
    }

    for name, filename in pairs(iconNames) do
        local iconPath = iconsPath .. filename .. ".dds"
        local icon = Overlay.new(iconPath, 0, 0, iconWidth, iconHeight)
        icon:setColor(1, 1, 1, 0.95)
        self.icons[name] = icon
    end

    -- EN: Default all row visibility settings to true if not yet set in saved settings.
    -- UA: Встановлюємо видимість всіх рядків за замовчуванням на true якщо ще не задано.
    if self.settings.showLoad == nil then self.settings.showLoad = true end
    if self.settings.showYield == nil then self.settings.showYield = true end
    if self.settings.showMoisture == nil then self.settings.showMoisture = true end
    if self.settings.showSpeed == nil then self.settings.showSpeed = true end
    if self.settings.showCropLoss == nil then self.settings.showCropLoss = true end
    if self.settings.showProductivity == nil then self.settings.showProductivity = true end
end

-- EN: Returns the HUD position — from saved settings if available and on-screen, or auto-positioned
--     left of the speed meter, with a fallback to (0.7, 0.05).
-- UA: Повертає позицію HUD — із збережених налаштувань якщо є і в межах екрану, або авто-позиціонується
--     зліва від спідометра, з запасним варіантом (0.7, 0.05).
function DraggableHUD:getPosition()
    local x = self.settings.hudPosX
    local y = self.settings.hudPosY

    if x and y then
        -- EN: Allow small margin for floating point drift, reset if well off-screen.
        -- UA: Допускаємо невелику похибку, скидаємо якщо далеко за межами екрану.
        if x >= -0.1 and x <= 1.1 and y >= -0.1 and y <= 1.1 then
            x = math.max(0, math.min(1 - (self.width or 0), x))
            y = math.max(0, math.min(1 - ((self.height or 0) + (self.headerHeight or 0)), y))
            return x, y
        end
    end

    -- EN: Auto-position: left of the game's speed meter.
    -- UA: Авто-позиціонування: зліва від спідометра гри.
    if g_currentMission and g_currentMission.hud and g_currentMission.hud.speedMeter then
        local speedMeter = g_currentMission.hud.speedMeter
        -- EN: In FS25, overlays might not have public x/y, try getPosition().
        -- UA: У FS25 оверлеї можуть не мати публічних x/y, пробуємо getPosition().
        local smX, smY
        if speedMeter.speedBg and speedMeter.speedBg.getPosition then
            smX, smY = speedMeter.speedBg:getPosition()
        elseif speedMeter.speedBg and speedMeter.speedBg.x then
            smX, smY = speedMeter.speedBg.x, speedMeter.speedBg.y
        end

        if smX and smX > 0.01 then
            local offsetX = -0.14 * (self.uiScale or 1.0)
            local offsetY = 0.02 * (self.uiScale or 1.0)
            local resX = smX + offsetX
            local resY = smY + offsetY
            
            if RHM_Debug and RHM_Debug.isEnabled("UI") then
                print(string.format("RHM: Auto-positioned HUD at (%.3f, %.3f) near speed meter at (%.3f, %.3f)", resX, resY, smX, smY))
            end
            return resX, resY
        end
    end

    if RHM_Debug and RHM_Debug.isEnabled("UI") then
        print("RHM: HUD using fallback position (0.7, 0.05)")
    end
    return 0.7, 0.05 -- EN: Last-resort fallback position / UA: Останній засіб
end

-- EN: Sets the HUD top-left position (normalized screen coords).
-- UA: Встановлює верхню ліву позицію HUD (нормалізовані координати екрану).
function DraggableHUD:setPosition(x, y)
    self.x = x
    self.y = y
end

-- EN: Sets the active combine vehicle. Clears live data when nil is passed.
-- UA: Встановлює активний комбайн. Очищає живі дані коли передано nil.
function DraggableHUD:setVehicle(vehicle)
    self.vehicle = vehicle
    if vehicle then
        self:update(vehicle)
    else
        -- EN: Reset all displayed metrics when no vehicle is active.
        -- UA: Скидаємо всі відображувані метрики коли немає активного транспортного засобу.
        self.data.load = 0
        self.data.yield = 0
        self.data.speed = 0
        self.data.cropLoss = 0
        self.data.tonPerHour = 0
        self.data.litersPerHour = 0
        self.data.recommendedSpeed = 0
    end
end

-- EN: Updates live data from the vehicle's rhm_Combine spec and handles drag movement.
--     Called every frame. Drag movement is processed here for smooth real-time updating.
-- UA: Оновлює живі дані зі специфікації rhm_Combine транспортного засобу та обробляє перетягування.
--     Викликається щоразу за кадр. Рух перетягування обробляється тут для плавного оновлення.
function DraggableHUD:update(dt)
    local vehicle = self.vehicle
    if not vehicle then return end

    local spec = vehicle.spec_rhm_Combine
    if not spec or not spec.data then return end

    -- EN: Pull latest values from the combine's live data table.
    -- UA: Беремо останні значення з таблиці живих даних комбайна.
    self.data.load             = spec.data.load or 0
    self.data.yield            = spec.data.yield or 0
    self.data.moisture         = spec.data.moisture or 0
    self.data.cropLoss         = spec.data.cropLoss or 0
    self.data.tonPerHour       = spec.data.tonPerHour or 0
    self.data.litersPerHour    = spec.data.litersPerHour or 0
    self.data.recommendedSpeed = spec.data.recommendedSpeed or 0
    self.data.speed            = vehicle:getLastSpeed() or 0

    -- EN: Move HUD to follow mouse during drag (processed every frame for smoothness).
    -- UA: Переміщуємо HUD слідуючи за мишею під час перетягування (обробляється щокадру для плавності).
    if self.dragging then
        if g_inputBinding and g_inputBinding.getMousePosition then
            local posX, posY = g_inputBinding:getMousePosition()
            if posX and posY then
                self:moveTo(posX - self.dragOffsetX, posY - self.dragOffsetY)
            end
        end
    end
end

-- EN: Renders the complete HUD including header, settings button, and metric rows.
--     Skipped when on server, when HUD is hidden, or when no vehicle is active.
-- UA: Відображає повний HUD включаючи заголовок, кнопку налаштувань та рядки метрик.
--     Пропускається на сервері, коли HUD прихований, або коли немає активного транспортного засобу.
function DraggableHUD:draw()
    if not g_currentMission:getIsClient() then return end
    if not self.settings.showHUD then return end
    
    -- EN: Diagnostic: Ensure coordinates are valid.
    -- UA: Діагностика: Переконуємось, що координати дійсні.
    if self.x == nil or self.y == nil then
        self.x, self.y = self:getPosition()
        if self.debug then print(string.format("RHM: HUD position was nil, reset to %.2f, %.2f", self.x, self.y)) end
    end

    if not self.vehicle then 
        return 
    end

    self:updateSize()

    -- EN: Sync overlay positions and dimensions to match current layout.
    -- UA: Синхронізуємо позиції та розміри оверлеїв з поточним розмічуванням.
    if self.backgroundOverlay then
        self.backgroundOverlay:setPosition(self.x, self.y)
        self.backgroundOverlay:setDimension(self.width, self.height)
        self.backgroundOverlay:render()
    end
    
    if self.headerOverlay then
        self.headerOverlay:setPosition(self.x, self.y + self.height)
        self.headerOverlay:render()
    end

    -- EN: Draw "Realistic Harvesting" title text centered in the header.
    -- UA: Малюємо назву "Realistic Harvesting" по центру заголовку.
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(0.83, 0.54, 0.04, 1.0)
    local titleTextSize = 0.012 * self.uiScale
    local headerTextX = self.x + self.width / 2
    local titleTextY = self.y + self.height + self.headerHeight * 0.65
    renderText(headerTextX, titleTextY, titleTextSize, "Realistic Harvesting")

    -- EN: Draw "Settings" sub-label below the title with hover color change.
    -- UA: Малюємо підпис "Settings" під назвою зі зміною кольору при наведенні.
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_CENTER)

    local settingsButtonArea = {
        x = self.x,
        y = self.y + self.height,
        w = self.width,
        h = (self.headerHeight or 0) * 0.4
    }
    local mx, my = g_inputBinding:getMousePosition()
    local isHovered = mx >= settingsButtonArea.x and mx <= settingsButtonArea.x + settingsButtonArea.w and
                      my >= settingsButtonArea.y and my <= settingsButtonArea.y + settingsButtonArea.h

    if isHovered then
        setTextColor(0.6, 1.0, 1.0, 1)  -- EN: Cyan on hover / UA: Блакитний при наведенні
    else
        setTextColor(0.8, 0.8, 1.0, 1)  -- EN: Light blue default / UA: Блакитний за замовчуванням
    end

    local settingsTextSize = 0.009
    local settingsTextY = self.y + self.height + (self.headerHeight or 0) * 0.20
    renderText(headerTextX, settingsTextY, settingsTextSize, "Settings")
    setTextBold(false)

    -- EN: Store button area for mouse event hit-testing.
    -- UA: Зберігаємо область кнопки для перевірки попадань мишею.
    self.menuButtonArea = settingsButtonArea

    self:drawContent()
    setTextBold(false)
end

-- EN: Draws the metric data rows (load, yield, productivity, crop loss, speed).
--     Each row consists of an icon and a formatted text value with color coding.
--     Uses UnitConverter for metric/imperial/bushel formatting.
-- UA: Малює рядки метрик (навантаження, врожайність, продуктивність, втрати, швидкість).
--     Кожен рядок містить іконку та відформатоване текстове значення з кодуванням кольором.
--     Використовує UnitConverter для форматування метрик/американських/бушелів.
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
    setTextColor(1, 1, 1, 0.95)

    local unitSystem = self.settings.unitSystem or 1
    local fruitType = nil
    if self.vehicle and self.vehicle.spec_combine then
        fruitType = self.vehicle.spec_combine.lastValidInputFruitType
    end

    -- EN: Row 1 — Engine Load (%).
    -- UA: Рядок 1 — Навантаження двигуна (%).
    if self.settings.showLoad then
        local loadColor = self:getLoadColor(self.data.load)
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "load",
            string.format("%.0f%%", self.data.load), self.data.load, loadColor[1], loadColor[2], loadColor[3])
        textY = textY - lineHeight
    end

    -- EN: Row 2 — Yield (t/ha, bu/ac, etc.).
    -- UA: Рядок 2 — Врожайність (т/га, бу/акр тощо).
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

    -- EN: Row 3 — Grain Moisture (%).
    -- UA: Рядок 3 — Вологість зерна (%).
    if self.settings.showMoisture and g_currentMission.MoistureSystem then
        local m = self.data.moisture or 0
        local moistureStr = string.format("%.1f%%", m)
        local r, g, b = 1, 1, 1
        
        -- If moisture is 0 but we are supposed to have data, it might be N/A
        if m <= 0 then
            moistureStr = "N/A"
        else
            -- Color coding for moisture
            if m > 20 or m < 10 then      r, g, b = 1, 0.4, 0.4  -- EN: Red (Bad) / UA: Червоний (Погано)
            elseif m > 15 or m < 13 then  r, g, b = 1, 1, 0.4    -- EN: Yellow (Caution) / UA: Жовтий (Увага)
            else                          r, g, b = 0.4, 1, 0.4  end -- EN: Green (Optimal) / UA: Зелений (Оптимально)
        end
        
        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "moisture", moistureStr, m, r, g, b)
        textY = textY - lineHeight
    end

    -- EN: Row 4 — Productivity (t/h or bu/h).
    -- UA: Рядок 4 — Продуктивність (т/год або бу/год).
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

    -- EN: Row 5 — Crop Loss. Skipped entirely for forage harvesters (no grain losses on choppers).
    -- UA: Рядок 5 — Втрати зерна. Пропускається для силосних комбайнів (немає втрат).
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

        local r, g, b = 1, 1, 1
        if lossVal > 3.0 then           r, g, b = 0.9, 0.1, 0.1  -- EN: Red (high loss) / UA: Червоний (великі втрати)
        elseif lossVal > 1.0 then       r, g, b = 0.9, 0.8, 0.1  -- EN: Yellow (moderate) / UA: Жовтий (помірні)
        elseif lossVal < -0.1 then      r, g, b = 0.2, 1.0, 0.2  -- EN: Bright green (bonus) / UA: Яскраво-зелений (бонус)
        else                            r, g, b = 0.2, 0.8, 0.2  end  -- EN: Green (optimal) / UA: Зелений (оптимум)

        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "loss", lossStr, lossVal, r, g, b)
        textY = textY - lineHeight
    end

    -- EN: Row 6 — Speed (current / recommended). Red/yellow when over recommended limit.
    -- UA: Рядок 6 — Швидкість (поточна / рекомендована). Червоний/жовтий при перевищенні ліміту.
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

        local r, g, b = 1, 1, 1
        if recSpeed > 0 then
            if currentSpeed > (recSpeed + 2) then r, g, b = 1, 0.4, 0.4    -- EN: Over speed / UA: Перевищення
            elseif currentSpeed > recSpeed then   r, g, b = 1, 1, 0.4  end -- EN: Near limit / UA: Близько до ліміту
        end

        self:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, "speed", speedStr, 0, r, g, b)
    end
end

-- EN: Recalculates HUD height based on how many rows are enabled.
--     Adjusts the Y position so the header line stays fixed while the body shrinks/grows.
-- UA: Перераховує висоту HUD залежно від кількості увімкнених рядків.
--     Регулює позицію Y щоб лінія заголовку залишалась фіксованою поки тіло зменшується/збільшується.
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
    if self.settings.showMoisture and g_currentMission.MoistureSystem then rowCount = rowCount + 1 end
    if self.settings.showProductivity then rowCount = rowCount + 1 end
    -- EN: Crop Loss row is not shown for forage harvesters — exclude from height.
    -- UA: Рядок втрат не відображається для силосних — не рахуємо в висоту.
    if self.settings.showCropLoss and machineType ~= "forage" then rowCount = rowCount + 1 end
    if self.settings.showSpeed then rowCount = rowCount + 1 end

    local lineHeight  = 0.028 * self.uiScale
    local padding     = 0.01 * self.uiScale
    local targetHeight = math.max(0.01 * self.uiScale, (rowCount * lineHeight) + padding)

    if math.abs(self.height - targetHeight) > 0.0001 then
        local heightDiff = self.height - targetHeight
        self.y = self.y + heightDiff
        self.height = targetHeight
        self.settings.hudPosY = self.y
    end
end

-- EN: Draws a single HUD row: an icon on the left and a formatted text value.
--     Optional RGB color overrides the default white text color.
-- UA: Малює один рядок HUD: іконка зліва та відформатоване текстове значення.
--     Необов'язковий RGB колір замінює стандартний білий колір тексту.
function DraggableHUD:drawRow(iconX, textX, textY, iconWidth, iconHeight, textSize, iconName, text, value, r, g, b)
    local icon = self.icons[iconName]
    if icon then
        local iconY = textY + textSize / 2 - iconHeight / 2
        icon:setPosition(iconX, iconY)
        icon:setColor(1, 1, 1, 0.95)
        icon:render()
    end

    if r and g and b then
        setTextColor(r, g, b, 0.95)
    else
        setTextColor(1, 1, 1, 0.95)
    end
    renderText(textX, textY, textSize, text)
end

-- EN: Maps engine load value to a display color: white (low), yellow (moderate), red (high).
-- UA: Відображає значення навантаження двигуна на колір: білий (низьке), жовтий (помірне), червоний (високе).
function DraggableHUD:getLoadColor(load)
    if load < 50 then
        return {1, 1, 1}    -- EN: White / UA: Білий
    elseif load < 80 then
        return {1, 1, 0.4}  -- EN: Yellow / UA: Жовтий
    else
        return {1, 0.4, 0.4} -- EN: Red / UA: Червоний
    end
end

-- EN: Returns true if the given position is within the draggable header area.
-- UA: Повертає true якщо задана позиція знаходиться в межах перетягуваної області заголовку.
function DraggableHUD:isMouseOverHeader(posX, posY)
    return posX >= self.x and posX <= (self.x + self.width) and
           posY >= (self.y + self.height) and posY <= (self.y + self.height + self.headerHeight)
end

-- EN: Handles mouse button events. Routes Settings button clicks and manages drag start/stop.
--     The Settings button click opens the calibration GUI via the manager.
--     Drag saves position on mouse-up for persistence.
-- UA: Обробляє події кнопок миші. Маршрутизує кліки кнопки Settings та керує початком/кінцем перетягування.
--     Клік кнопки Settings відкриває GUI калібрування через менеджер.
--     Перетягування зберігає позицію при відпусканні миші для збереження.
function DraggableHUD:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.settings.showHUD then return false end
    if button ~= Input.MOUSE_BUTTON_LEFT then return false end

    -- EN: Check click on "Settings" button in header to open the calibration GUI.
    -- UA: Перевіряємо клік на кнопку "Settings" у заголовку для відкриття GUI калібрування.
    if self.menuButtonArea and isDown then
        if posX >= self.menuButtonArea.x and posX <= (self.menuButtonArea.x + self.menuButtonArea.w) and
           posY >= self.menuButtonArea.y and posY <= (self.menuButtonArea.y + self.menuButtonArea.h) then
            if g_realisticHarvestManager then
                g_realisticHarvestManager:toggleMenu(self.vehicle)
                return true
            end
        end
    end

    -- EN: Start drag on mouse-down over the header area.
    -- UA: Починаємо перетягування при натисканні миші над областю заголовку.
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
        -- EN: Stop drag on mouse-up and save the position once to avoid per-frame saves.
        -- UA: Зупиняємо перетягування при відпусканні миші і зберігаємо позицію один раз щоб уникнути збереження щокадру.
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

-- EN: Moves the HUD to the given position, clamped to keep it fully visible on-screen.
--     Saves the position to settings in memory only (save to disk happens on drag stop).
-- UA: Переміщує HUD до заданої позиції, обмежуючи щоб він залишався повністю видимим на екрані.
--     Зберігає позицію в налаштуваннях тільки в пам'яті (збереження на диск відбувається при зупинці перетягування).
function DraggableHUD:moveTo(x, y)
    x = math.max(0, math.min(1 - self.width, x))
    y = math.max(0, math.min(1 - (self.height + self.headerHeight), y))

    self:setPosition(x, y)

    self.settings.hudPosX = x
    self.settings.hudPosY = y
end

-- EN: Releases all GPU resources (overlay objects and icon overlays).
-- UA: Звільняє всі ресурси GPU (об'єкти оверлеїв та іконок).
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
