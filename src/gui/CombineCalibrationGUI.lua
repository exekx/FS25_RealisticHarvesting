-- EN: Interactive visual calibration GUI for combine harvester settings.
--     Renders as an always-on overlay panel with [-]/[+] buttons and mouse wheel
--     for each active parameter (fan, rotor, sieves, feeder) based on machine type.
--     Shows real-time color-coded loss and speed penalty preview from CombineSettingsDatabase.
--     Parameters grouped by function: SEPARATION / CLEANING / PERFORMANCE.
--     Each parameter row shows: label | physical value | status hint | progress bar | [-][+] buttons.
--     Supports NEXAT modular systems by searching the vehicle hierarchy for spec_rhm_Combine.
--     Blocks camera rotation and zoom while open; restores them on close.
-- UA: Інтерактивний візуальний GUI калібрування для налаштувань зернозбирального комбайна.
--     Відображається як постійна накладка з кнопками [-]/[+] та колесом миші
--     для кожного активного параметра (вентилятор, ротор, решета, подача) залежно від типу машини.
--     Показує попередній перегляд штрафів за втрати та швидкість у режимі реального часу з CombineSettingsDatabase.
--     Параметри згруповані за функцією: SEPARATION / CLEANING / PERFORMANCE.
--     Кожен рядок параметра показує: мітка | фізичне значення | статус | прогрес-бар | кнопки [-][+].
--     Підтримує модульні системи NEXAT, шукаючи spec_rhm_Combine в ієрархії транспорту.
--     Блокує обертання та масштабування камери при відкритті; відновлює при закритті.
CombineCalibrationGUI = {}
local CombineCalibrationGUI_mt = Class(CombineCalibrationGUI)

-- EN: Parameter section grouping — defines which parameters belong to which section label.
--     Parameters not listed here that come from getParamsForMachineType fall through to a
--     catch-all "OTHER" render before the Performance/TargetEngineLoad section.
-- UA: Групування параметрів по секціях — визначає які параметри до якої секції належать.
--     Параметри яких немає у цьому списку що приходять з getParamsForMachineType потрапляють
--     у загальну секцію "OTHER" перед секцією Performance/TargetEngineLoad.
local PARAM_SECTION_MAP = {
    -- GRAIN
    rotor      = "SEPARATION",
    concave    = "SEPARATION",
    upperSieve = "CLEANING",
    lowerSieve = "CLEANING",
    fan        = "CLEANING",
    -- FORAGE (no CLEANING section — choppers don't clean grain)
    chopLength      = "SEPARATION",
    kernelProcessor = "SEPARATION",
    blower          = "DISCHARGE",
    -- ROOT
    shakingIntensity = "SEPARATION",
    feeder           = "SEPARATION",
}

-- EN: Ordered section definitions for the draw loop.
-- UA: Впорядковані визначення секцій для циклу малювання.
local SECTIONS_ORDERED = {
    { key = "SEPARATION", label = "rhm_ui_section_separation" },
    { key = "CLEANING",   label = "rhm_ui_section_cleaning"   },
    { key = "DISCHARGE",  label = "rhm_ui_section_discharge"  },
}

-- EN: Creates a new GUI instance. Initializes UI layout constants, color palette,
--     button registry, scroll debouncing, and the persistent overlay object.
-- UA: Створює новий екземпляр GUI. Ініціалізує константи розмітки UI, кольорову палітру,
--     реєстр кнопок, захист від дребезгу прокрутки та постійний об'єкт оверлею.
function CombineCalibrationGUI.new(modDirectory)
    local self = setmetatable({}, CombineCalibrationGUI_mt)
    self.modDirectory = modDirectory
    self.isOpen = false
    self.isCursorActive = false
    self.debug = true

    -- EN: UI layout — industrial dark theme with amber accents.
    -- UA: Розмітка UI — індустріальна темна тема з бурштиновими акцентами.
    self.ui = {
        x = 0.68, y = 0.45,
        w = 0.30, h = 0.45,
        margin      = 0.010,
        headerHeight = 0.038,
        statsHeight  = 0.026,  -- EN: Live stats bar height / UA: Висота смуги живої статистики
        lineHeight   = 0.038,  -- EN: Increased from 0.035 to fit progress bar / UA: Збільшено з 0.035 для прогрес-бару
        sectionGap   = 0.022,  -- EN: Height of each section header row / UA: Висота рядка заголовку секції
        fontSize    = 0.013,
        titleSize   = 0.018,
        sectionSize = 0.012,   -- EN: Section label font size / UA: Розмір шрифту мітки секції
        statusSize  = 0.011,   -- EN: Status hint font size / UA: Розмір шрифту підказки статусу
        buttonW     = 0.026,
        buttonH     = 0.022,

        -- EN: Industrial dark color palette.
        -- UA: Індустріальна темна кольорова палітра.
        colors = {
            bg            = {0.04, 0.05, 0.03, 0.96},
            header        = {0.09, 0.07, 0.03, 1.00},
            headerAccent  = {0.83, 0.54, 0.04, 1.00},  -- EN: Amber accent line / UA: Бурштинова акцентна лінія
            statsBg       = {0.00, 0.00, 0.00, 0.30},
            sectionLine   = {1.00, 1.00, 1.00, 0.08},
            separator     = {1.00, 1.00, 1.00, 0.06},
            paramRowHover = {1.00, 1.00, 1.00, 0.03},
            barBg         = {1.00, 1.00, 1.00, 0.07},
            barOptimal    = {1.00, 1.00, 1.00, 0.42},
            text          = {0.91, 0.87, 0.78, 1.00},
            textDim       = {0.70, 0.68, 0.65, 1.00},
            accent        = {0.83, 0.54, 0.04, 1.00},
            accentDim     = {0.83, 0.54, 0.04, 0.14},
            success       = {0.24, 0.72, 0.47, 1.00},
            warning       = {0.91, 0.78, 0.25, 1.00},
            error         = {0.89, 0.29, 0.29, 1.00},
            teal          = {0.60, 1.00, 0.80, 1.00},
            button        = {0.15, 0.15, 0.13, 0.95},
            buttonHover   = {0.22, 0.22, 0.20, 1.00},
            buttonAuto    = {0.05, 0.18, 0.09, 1.00},
            buttonReset   = {0.20, 0.08, 0.03, 1.00},
            buttonSave    = {0.06, 0.12, 0.04, 1.00},
        }
    }

    self.activeVehicle = nil
    self.hoveredElement = nil
    self.mouseX = 0
    self.mouseY = 0
    self.hoveredParameter = nil

    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}

    self.lastScrollTimeStamp = 0
    self.scrollDelayMs = 100

    self.buttons = {}

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

function CombineCalibrationGUI:toggle(vehicle)
    if self.isOpen then
        self:close()
    else
        self:open(vehicle)
    end
end

-- EN: Opens the calibration GUI for a vehicle.
--     For modular systems (NEXAT), searches the entire vehicle hierarchy for spec_rhm_Combine.
--     Blocks camera rotation and zoom to prevent accidental camera movement.
-- UA: Відкриває GUI калібрування для транспортного засобу.
--     Для модульних систем (NEXAT), шукає в усій ієрархії транспорту spec_rhm_Combine.
--     Блокує обертання та масштабування камери для запобігання випадкового руху.
function CombineCalibrationGUI:open(vehicle)
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
            RHM_Debug.log("UI", string.format("RHM: [GUI] NEXAT: found combine vehicle in hierarchy: %s", tostring(combineVehicle)))
        else
            RHM_Debug.log("UI", "RHM: [GUI] No combine with spec_rhm_Combine found in vehicle hierarchy — GUI will not open")
            return
        end
    end

    self.isOpen = true
    g_inputBinding:setShowMouseCursor(true)
    self.isCursorActive = true

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
            camera.allowZoom = false
        end
    end

    self.activeVehicle = combineVehicle
    self.controllerVehicle = cv or vehicle or combineVehicle
end

-- EN: Closes the calibration GUI. Restores camera rotation and zoom.
-- UA: Закриває GUI калібрування. Відновлює обертання та масштаб камери.
function CombineCalibrationGUI:close()
    if not self.isOpen then return end

    self.isOpen = false
    self.isCursorActive = false

    local vehicle = self.controllerVehicle

    local hudCursorActive = g_realisticHarvestManager and g_realisticHarvestManager.isCursorVisible
    g_inputBinding:setShowMouseCursor(hudCursorActive or false)

    for camera, savedRotatable in pairs(self.savedCameraRotatableInfo) do
        local savedZoom = self.savedCameraZoomInfo[camera]
        camera.isRotatable = savedRotatable ~= nil and savedRotatable or true
        camera.allowTranslation = savedZoom ~= nil and savedZoom or true
        camera.allowZoom = savedZoom ~= nil and savedZoom or true
    end
    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}

    if hudCursorActive and vehicle and vehicle.spec_enterable then
        RHMInputUtil.setCameraRotation(vehicle, false, g_realisticHarvestManager.savedCameraRotatableInfo)
    end
end

-- EN: Cycles to the previous (-1) or next (+1) crop in the machine-type-filtered list.
-- UA: Перемикає на попередню (-1) або наступну (+1) культуру у відфільтрованому списку.
function CombineCalibrationGUI:cycleCrop(direction)
    local spec = self.activeVehicle.spec_rhm_Combine
    local machineType = spec.machineType or "grain"
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

-- EN: Called every frame while open. Auto-closes if the player exits the vehicle.
-- UA: Викликається кожен кадр поки відкритий. Автоматично закриває якщо гравець виходить з транспорту.
function CombineCalibrationGUI:update(dt)
    if not self.isOpen then return end

    if not self.activeVehicle then
        self:close()
        return
    end

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
    end

    if not isEntered then
        RHM_Debug.log("UI", "RHM: [GUI] Closing due to isEntered=false."
            .. " RHM_cv=" .. tostring(g_realisticHarvestManager and g_realisticHarvestManager:getControlledVehicle())
            .. " vToCheck=" .. tostring(vehicleToCheck)
            .. " (root=" .. tostring(vehicleToCheck and (vehicleToCheck.rootVehicle or vehicleToCheck)) .. ")")
        self:close()
    end
end

-- EN: Main draw function. Renders the redesigned calibration panel:
--       Header (amber title + close hint)
--       Stats bar (live: engine load | speed | loss preview)
--       Crop selector (< CROPNAME >) + AUTO button
--       Grouped parameter rows (SEPARATION / CLEANING / PERFORMANCE)
--         each row: label | value | status | progress bar | [-] [+]
--       Save Profile | Reset Default buttons
--       Close hint
-- UA: Головна функція малювання. Відображає перероблену панель калібрування:
--       Заголовок (бурштиновий заголовок + підказка закриття)
--       Смуга статистики (жива: навантаження двигуна | швидкість | попередній перегляд втрат)
--       Вибір культури (< НАЗВА >) + кнопка AUTO
--       Згруповані рядки параметрів (SEPARATION / CLEANING / PERFORMANCE)
--         кожен рядок: мітка | значення | статус | прогрес-бар | [-] [+]
--       Кнопки Save Profile | Reset Default
--       Підказка закриття
function CombineCalibrationGUI:draw()
    if not self.isOpen then return end
    if not (g_currentMission and g_currentMission.hud) then
        if self.debug then RHM_Debug.log("UI", "RHM: [GUI] draw() abort: no g_currentMission.hud") end
        return
    end

    self.buttons = {}
    self.hoveredParameter = nil

    local ui = self.ui
    local spec = self.activeVehicle and self.activeVehicle.spec_rhm_Combine

    -- EN: Dynamic height: accounts for header, stats bar, crop row, section headers,
    --     param rows, action buttons, close hint.
    -- UA: Динамічна висота: враховує заголовок, смугу статистики, рядок культури,
    --     заголовки секцій, рядки параметрів, кнопки дій, підказку закриття.
    if spec and spec.combineMemory then
        local machineType = spec.machineType or "grain"
        local activeParams = CombineSettingsDatabase:getParamsForMachineType(machineType)
        local numParams = #activeParams + 1  -- +1 for targetEngineLoad

        -- EN: Count how many sections will be shown (for height calculation).
        -- UA: Рахуємо скільки секцій буде показано (для розрахунку висоти).
        local sectionsShown = 0
        for _, section in ipairs(SECTIONS_ORDERED) do
            for _, p in ipairs(activeParams) do
                if PARAM_SECTION_MAP[p] == section.key then
                    sectionsShown = sectionsShown + 1
                    break
                end
            end
        end
        sectionsShown = sectionsShown + 1  -- +1 for PERFORMANCE section

        -- EN: Only add statsHeight and its associated margin if packageLevel >= 3 (Yield Monitor).
        -- UA: Додаємо statsHeight та відступ тільки якщо packageLevel >= 3.
        local packageLevel = spec.packageLevel or 1
        local actualStatsHeight = (packageLevel >= 3) and (ui.statsHeight + ui.margin * 0.4) or 0

        local dynamicH = ui.headerHeight
                       + actualStatsHeight
                       + ui.lineHeight        -- crop row
                       + (sectionsShown * ui.sectionGap)
                       + (numParams * ui.lineHeight)
                       + (ui.lineHeight * 2.0)  -- action buttons
                       + ui.margin * 3.2      -- precise bottom padding

        local targetTop = 0.91
        ui.h = dynamicH
        ui.y = targetTop - dynamicH
    else
        ui.h = 0.50
        ui.y = 0.40
    end

    local x, y = ui.x, ui.y
    local w, h = ui.w, ui.h

    -- ── Background panel ────────────────────────────────────────────────────
    self:drawRect(x, y, w, h, ui.colors.bg)

    -- ── Header strip ────────────────────────────────────────────────────────
    local headerY = y + h - ui.headerHeight
    self:drawRect(x, headerY, w, ui.headerHeight, ui.colors.header)

    -- EN: Amber accent line at bottom of header (visual separator).
    -- UA: Бурштинова акцентна лінія знизу заголовку (візуальний розділювач).
    self:drawRect(x, headerY, w, 0.0015, ui.colors.headerAccent)

    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.accent))
    renderText(x + ui.margin, headerY + ui.headerHeight * 0.35, ui.titleSize, g_i18n:getText("rhm_gui_title"))
    setTextBold(false)

    -- EN: Close hint right-aligned in header.
    -- UA: Підказка закриття по правому краю заголовку.
    local closeHintText = g_i18n:hasText("rhm_gui_close_hint") and g_i18n:getText("rhm_gui_close_hint") or "RShift+K to Close"
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(unpack(ui.colors.textDim))
    renderText(x + w - ui.margin - 0.025, headerY + ui.headerHeight * 0.35, ui.fontSize * 0.80, closeHintText)

    -- EN: Close [X] button
    -- UA: Кнопка закриття [X]
    local closeBtnW = 0.018
    local closeBtnH = ui.headerHeight * 0.7
    local closeBtnX = x + w - ui.margin - closeBtnW + 0.005
    local closeBtnY = headerY + (ui.headerHeight - closeBtnH) * 0.5
    self:drawButton(closeBtnX, closeBtnY, closeBtnW, closeBtnH, "X", function()
        self:close()
    end, {0.6, 0.1, 0.1, 0.9})

    local cy = headerY - ui.margin * 0.5

    -- EN: Early exit if vehicle/spec not ready.
    -- UA: Ранній вихід якщо транспорт/специфікація не готові.
    if not self.activeVehicle then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(unpack(ui.colors.textDim))
        renderText(x + w / 2, cy - ui.lineHeight, ui.fontSize, g_i18n:getText("rhm_gui_no_combine"))
        self:_resetTextState()
        return
    end

    spec = self.activeVehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(unpack(ui.colors.textDim))
        renderText(x + w / 2, cy - ui.lineHeight, ui.fontSize, g_i18n:getText("rhm_gui_not_init"))
        self:_resetTextState()
        return
    end

    local memory = spec.combineMemory
    local machineType = spec.machineType or "grain"

    local packageLevel = spec.packageLevel or 1
    
    if packageLevel >= 3 then
        -- ── Stats bar (3 separate sections) ──────────────────────────────────────
        -- EN: Live stats split into 3 distinct color-coded sections: Load | Speed | Loss.
        --     Each section has its own background and individual color coding.
        -- UA: Жива статистика розділена на 3 окремі секції з кольоровим кодуванням: Навантаження | Швидкість | Втрати.
        --     Кожна секція має власний фон та індивідуальний колір.
        cy = cy - ui.statsHeight
        local sectionGap = 0.003  -- EN: Gap between sections / UA: Відступ між секціями

        local load = (spec.loadCalculator and spec.loadCalculator.engineLoad or 0) * 100
        local effPenalty = 0
        local lossPenalty = 0
    if memory.currentCrop then
        effPenalty, lossPenalty, _ = memory:checkSettingsForCrop(memory.currentCrop)
    end
    local isForage = (machineType == "forage")

    -- EN: Calculate section widths: 3 equal columns with gaps.
    -- UA: Розраховуємо ширину секцій: 3 рівні колонки з відступами.
    local totalGaps = sectionGap * 2
    local sectionW = (w - totalGaps) / 3
    local sectionH = ui.statsHeight

    -- EN: Darker background for each individual section panel.
    -- UA: Темніший фон для кожної окремої секції.
    local sectionBg = {0.08, 0.07, 0.05, 0.85}

    -- ── Section 1: ENGINE LOAD ──
    local sx1 = x
    self:drawRect(sx1, cy, sectionW, sectionH, sectionBg)

    local loadColor = load > 95 and ui.colors.error or (load > 80 and ui.colors.warning or ui.colors.success)
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    local sx1Center = sx1 + sectionW * 0.5
    setTextColor(unpack(ui.colors.textDim))
    renderText(sx1Center, cy + sectionH * 0.55, ui.statusSize * 0.85, g_i18n:hasText("rhm_ui_load") and g_i18n:getText("rhm_ui_load") or "Load")
    setTextColor(unpack(loadColor))
    renderText(sx1Center, cy + sectionH * 0.12, ui.fontSize, string.format("%.0f%%", load))

    -- ── Section 2: SPEED EFFICIENCY ──
    local sx2 = sx1 + sectionW + sectionGap
    self:drawRect(sx2, cy, sectionW, sectionH, sectionBg)

    -- EN: effPenalty < 0 = bonus (green), 0 = neutral (green), 0..2 = mild penalty (yellow), >2 = bad (red).
    -- UA: effPenalty < 0 = бонус (зелений), 0 = нейтральний (зелений), 0..2 = штраф (жовтий), >2 = поганий (червоний).
    local speedVal
    if effPenalty < 0 then
        speedVal = math.abs(effPenalty) * 5.0
    else
        speedVal = effPenalty
    end
    local speedColor
    if effPenalty < 0 then
        speedColor = ui.colors.success   -- EN: Bonus speed / UA: Бонус швидкості
    elseif effPenalty <= 0.1 then
        speedColor = ui.colors.success   -- EN: Perfect settings / UA: Ідеальні налаштування
    elseif effPenalty <= 2.0 then
        speedColor = ui.colors.warning   -- EN: Mild penalty / UA: Легкий штраф
    else
        speedColor = ui.colors.error     -- EN: Significant penalty / UA: Значний штраф
    end

    local sx2Center = sx2 + sectionW * 0.5
    setTextColor(unpack(ui.colors.textDim))
    renderText(sx2Center, cy + sectionH * 0.55, ui.statusSize * 0.85, g_i18n:hasText("rhm_ui_speed_eff") and g_i18n:getText("rhm_ui_speed_eff") or "Speed")
    setTextColor(unpack(speedColor))
    renderText(sx2Center, cy + sectionH * 0.12, ui.fontSize, string.format("%.1f%%", speedVal))

    -- ── Section 3: CROP LOSS ──
    local sx3 = sx2 + sectionW + sectionGap
    self:drawRect(sx3, cy, sectionW, sectionH, sectionBg)

    local sx3Center = sx3 + sectionW * 0.5
    setTextColor(unpack(ui.colors.textDim))
    renderText(sx3Center, cy + sectionH * 0.55, ui.statusSize * 0.85, g_i18n:hasText("rhm_ui_loss") and g_i18n:getText("rhm_ui_loss") or "Loss")

    if isForage then
        -- EN: Forage harvesters have no crop loss — show "N/A" dimmed.
        -- UA: Силосні комбайни не мають втрат — показуємо "N/A" тьмяним.
        setTextColor(unpack(ui.colors.textDim))
        renderText(sx3Center, cy + sectionH * 0.12, ui.fontSize, "N/A")
    else
        -- EN: Loss penalty can be negative internally (bonus), but physically loss can't be negative. Clamp to 0.
        -- UA: Штраф за втрати внутрішньо може бути від'ємним (бонус), але фізично втрати не можуть бути < 0.
        local displayLoss = math.max(0, lossPenalty)
        local lossColor
        if displayLoss <= 0.1 then
            lossColor = ui.colors.success    -- EN: No loss / UA: Без втрат
        elseif displayLoss <= 2.0 then
            lossColor = ui.colors.warning    -- EN: Mild loss / UA: Помірні втрати
        else
            lossColor = ui.colors.error      -- EN: Significant loss / UA: Значні втрати
        end
        setTextColor(unpack(lossColor))
        renderText(sx3Center, cy + sectionH * 0.12, ui.fontSize, string.format("%.1f%%", displayLoss))
    end

        setTextBold(false)
        cy = cy - ui.margin * 0.4
    end

    -- ── Crop selector + AUTO button ─────────────────────────────────────────
    cy = cy - ui.lineHeight

    local function getLocalizedCropName(rawName)
        if not rawName then return g_i18n:getText("rhm_gui_none") end
        local displayName = rawName
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(rawName)
        if fillTypeIndex and fillTypeIndex > 0 then
            local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
            if fillType and fillType.title then
                displayName = fillType.title
            end
        else
            local l10nKey = "fillType_" .. string.lower(rawName)
            if g_i18n:hasText(l10nKey) then
                displayName = g_i18n:getText(l10nKey)
            else
                local cleanName = rawName:gsub("_", " ")
                displayName = cleanName:sub(1,1):upper() .. cleanName:sub(2):lower()
            end
        end
        return displayName
    end

    -- EN: Crop selector: [<] CROPNAME [>] — left side of the row.
    -- UA: Вибір культури: [<] НАЗВА [>] — ліва частина рядка.
    local cropLabel = g_i18n:getText("rhm_gui_crop")
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.textDim))
    renderText(x + ui.margin, cy + 0.010, ui.fontSize * 0.9, cropLabel)

    local cropNavX = x + ui.margin + 0.030
    local arrowW = 0.020
    self:drawButton(cropNavX, cy + 0.004, arrowW, ui.buttonH, "<", function()
        self:cycleCrop(-1)
    end)

    local cropName = getLocalizedCropName(memory.currentCrop)
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(memory.currentCrop and ui.colors.text or ui.colors.textDim))
    
    local cropNavW = 0.104 -- Total width for the crop name display area (between arrows)
    local cropTextW = getTextWidth(ui.fontSize, cropName)
    local maxCropW = cropNavW - 0.010 -- Allow some padding
    local cropScale = 1.0
    if cropTextW > maxCropW then
        cropScale = maxCropW / cropTextW
    end
    renderText(cropNavX + arrowW + cropNavW / 2, cy + 0.010 + ui.fontSize * (1 - cropScale) * 0.5, ui.fontSize * cropScale, cropName)
    setTextBold(false)

    self:drawButton(cropNavX + arrowW + cropNavW, cy + 0.004, arrowW, ui.buttonH, ">", function()
        self:cycleCrop(1)
    end)

    -- EN: AUTO button — right-aligned in crop row. Sets optimal settings for current crop.
    --     Disabled if packageLevel < 4.
    -- UA: Кнопка AUTO — по правому краю. Встановлює оптимальні налаштування. 
    --     Заблоковано, якщо packageLevel < 4.
    local autoBtnW = 0.065
    local autoBtnX = x + w - ui.margin - autoBtnW
    local packageLevel = spec.packageLevel or 1
    
    if packageLevel >= 4 then
        self:drawButton(autoBtnX, cy + 0.003, autoBtnW, ui.buttonH + 0.003, g_i18n:getText("rhm_gui_btn_auto"), function()
            memory:requestAutoSettings()
        end, ui.colors.buttonAuto)
    else
        -- EN: Fully disabled visual state (no hover effect)
        -- UA: Повністю неактивний візуальний стан (без ефекту наведення)
        local btnH = ui.buttonH + 0.003
        self:drawRect(autoBtnX, cy + 0.003, autoBtnW, btnH, {0.10, 0.10, 0.09, 0.85})
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(0.45, 0.42, 0.38, 1.0)
        renderText(autoBtnX + autoBtnW / 2, cy + 0.003 + btnH / 2 - ui.fontSize / 2.5, ui.fontSize * 0.8, "AUTO (LOCKED)")
        setTextBold(false)
        
        -- Add just the click hit-box to trigger the message
        table.insert(self.buttons, {x=autoBtnX, y=cy + 0.003, w=autoBtnW, h=btnH, callback=function()
            if g_currentMission and g_currentMission.hud then
                g_currentMission.hud:showInGameMessage("RHM", g_i18n:hasText("rhm_msg_req_level_4") and g_i18n:getText("rhm_msg_req_level_4") or "Requires Opti-Harvest AI (Level 4)", -1)
            end
        end})
    end

    -- EN: Thin separator under crop row.
    -- UA: Тонкий розділювач під рядком культури.
    self:drawRect(x + ui.margin, cy - 0.004, w - ui.margin * 2, 0.001, ui.colors.separator)

    cy = cy - ui.margin * 0.3

    -- ── Parameter sections ──────────────────────────────────────────────────
    local activeParams = CombineSettingsDatabase:getParamsForMachineType(machineType)
    local drawnParams = {}

    for _, section in ipairs(SECTIONS_ORDERED) do
        -- EN: Check if any param in this section is active for the current machine type.
        -- UA: Перевіряємо чи є активний параметр цієї секції для поточного типу машини.
        local hasAny = false
        for _, p in ipairs(activeParams) do
            if PARAM_SECTION_MAP[p] == section.key then
                hasAny = true
                break
            end
        end
        
        if hasAny then
            -- EN: Center section header background bar.
            -- UA: Центрована фонова плашка для заголовку секції.
            cy = cy - ui.sectionGap
            self:drawRect(x, cy + 0.002, w, ui.sectionGap - 0.004, {0, 0, 0, 0.40}) -- Darker strip

            setTextBold(true)
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextColor(unpack(ui.colors.accent))
            local sectionName = g_i18n:hasText(section.label) and g_i18n:getText(section.label) or section.key
            renderText(x + w * 0.5, cy + 0.006, ui.sectionSize, string.upper(sectionName))

            -- EN: No horizontal rule anymore if centered, it looks cleaner.
            -- UA: Більше немає горизонтальної лінії, якщо текст по центру, так виглядає чистіше.

            -- EN: Draw each parameter in this section (in original DB order).
            -- UA: Малюємо кожен параметр цієї секції (у порядку оригінальної БД).
            for _, p in ipairs(activeParams) do
                if PARAM_SECTION_MAP[p] == section.key and not drawnParams[p] then
                    cy = cy - ui.lineHeight
                    local labelKey = CombineSettingsDatabase:getParamLabel(machineType, p)
                    local label = g_i18n:hasText(labelKey) and g_i18n:getText(labelKey) or p
                    self:drawParameterRow(x + ui.margin, cy, w - ui.margin * 2, p, label, memory, ui, machineType)
                    drawnParams[p] = true
                end
            end
        end
    end

    -- EN: PERFORMANCE section — remaining unlisted params + targetEngineLoad.
    -- UA: Секція PERFORMANCE — решта незгрупованих параметрів + targetEngineLoad.
    -- PERFORMANCE section background.
    cy = cy - ui.sectionGap
    self:drawRect(x, cy + 0.002, w, ui.sectionGap - 0.004, {0, 0, 0, 0.40}) -- Darker strip

    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(ui.colors.accent))
    local perfLabel = g_i18n:hasText("rhm_ui_section_performance") and g_i18n:getText("rhm_ui_section_performance") or "PERFORMANCE"
    renderText(x + w * 0.5, cy + 0.006, ui.sectionSize, string.upper(perfLabel))

    -- EN: Draw any active params not yet grouped (catch-all).
    -- UA: Малюємо незгруповані активні параметри (catch-all).
    for _, p in ipairs(activeParams) do
        if not drawnParams[p] then
            cy = cy - ui.lineHeight
            local labelKey = CombineSettingsDatabase:getParamLabel(machineType, p)
            local label = g_i18n:hasText(labelKey) and g_i18n:getText(labelKey) or p
            self:drawParameterRow(x + ui.margin, cy, w - ui.margin * 2, p, label, memory, ui, machineType)
            drawnParams[p] = true
        end
    end

    -- EN: Target Engine Load always last in PERFORMANCE.
    -- UA: Target Engine Load завжди останній у PERFORMANCE.
    cy = cy - ui.lineHeight
    local loadLabel = g_i18n:hasText("rhm_target_load") and g_i18n:getText("rhm_target_load") or "Target Engine Load"
    self:drawParameterRow(x + ui.margin, cy, w - ui.margin * 2, "targetEngineLoad", loadLabel, memory, ui, machineType)

    cy = cy - ui.margin * 0.8
    self:drawRect(x + ui.margin, cy, w - ui.margin * 2, 0.001, ui.colors.separator)
    cy = cy - ui.margin * 0.6

    -- ── Action buttons ──────────────────────────────────────────────────────
    -- Row 1: Load Preset | Save Profile
    cy = cy - ui.lineHeight * 1.0
    local btnWidth = (w - ui.margin * 2.5 - 0.008) / 2

    self:drawButton(x + ui.margin, cy, btnWidth, 0.026, g_i18n:getText("rhm_gui_btn_load_preset"), function()
        memory:loadUserPreset()
    end, ui.colors.button)

    self:drawButton(x + w - ui.margin - btnWidth, cy, btnWidth, 0.026, g_i18n:getText("rhm_gui_btn_save"), function()
        memory:saveCurrentProfile(memory.currentCrop)
    end, ui.colors.buttonSave)

    -- Row 2: Reset Default
    cy = cy - ui.lineHeight * 1.0
    local resetBtnW = w - ui.margin * 2
    self:drawButton(x + ui.margin, cy, resetBtnW, 0.026, g_i18n:getText("rhm_gui_btn_reset"), function()
        memory:requestResetSettings()
    end, ui.colors.buttonReset)

    -- ── Scroll wheel handling ───────────────────────────────────────────────
    if self.lastScrollTimeStamp + self.scrollDelayMs < g_time then
        local mx, my = g_inputBinding:getMousePosition()
        if mx >= ui.x and mx <= ui.x + ui.w and my >= ui.y and my <= ui.y + ui.h then
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

-- EN: Draws a single parameter row with: label | physical value | status hint | progress bar | [-] [+] buttons.
--     Progress bar shows current value position relative to full range (0-100%),
--     with a white marker at the optimal position from the database.
--     Status hint shows "optimal" / "^ low" / "v high" with color coding.
--     Smart step logic calculates physical increments (10 RPM / 0.5 mm) and converts back to %.
-- UA: Малює один рядок параметра: мітка | фізичне значення | підказка статусу | прогрес-бар | кнопки [-] [+].
--     Прогрес-бар показує позицію поточного значення відносно повного діапазону (0-100%),
--     з білим маркером в оптимальній позиції з бази даних.
--     Підказка статусу показує "optimal" / "^ low" / "v high" з кольоровим кодуванням.
--     Розумна логіка кроку розраховує фізичні кроки (10 об/хв / 0.5 мм) і конвертує назад у %.
function CombineCalibrationGUI:drawParameterRow(x, y, w, param, label, memory, ui, machineType)
    local val = memory.currentSettings[param] or 0
    local optimal = 0
    local tolerance = 5
    local isOptimal = false
    local hasOptimal = false

    -- EN: Row hover highlight.
    -- UA: Підсвічування рядка при наведенні.
    local isRowHovered = self:checkHover(x, y - 0.005, w, ui.lineHeight)
    if isRowHovered then
        self:drawRect(x, y - 0.005, w, ui.lineHeight, ui.colors.paramRowHover)
    end

    -- EN: Fetch optimal value and tolerance from database.
    -- UA: Отримуємо оптимальне значення та допуск з бази даних.
    if CombineSettingsDatabase and memory.currentCrop then
        local settings = CombineSettingsDatabase:getSettingsForCrop(memory.currentCrop)
        if settings and settings[param] then
            optimal = settings[param].optimal
            tolerance = settings[param].tolerance or 5
            isOptimal = math.abs(val - optimal) <= tolerance
            hasOptimal = true
        end
    end

    -- EN: Format value with physical units (RPM, mm) via UnitConverter.
    -- UA: Форматуємо значення у фізичних одиницях (об/хв, мм) через UnitConverter.
    local displayStr = ""
    if UnitConverter and UnitConverter.formatSetting then
        displayStr = UnitConverter.formatSetting(param, val, machineType)
    else
        displayStr = string.format("%d%%", val)
    end

    -- EN: Layout proportions within the row.
    --   [0 .. labelW] label
    --   [labelW .. valEndX] value (centered)
    --   [valEndX .. btnStartX] status hint
    --   [btnStartX .. end] [-] [+] buttons
    -- UA: Пропорції розмітки в рядку.
    local labelW    = w * 0.38
    local valW      = w * 0.24
    local valX      = x + labelW
    local valEndX   = valX + valW
    local btnAreaW  = ui.buttonW * 2 + 0.006
    local btnStartX = x + w - btnAreaW
    local statusW   = btnStartX - valEndX - 0.004

    -- EN: Determine value color and status text based on optimality.
    -- UA: Визначаємо колір значення та текст статусу на основі оптимальності.
    local valColor, statusText, statusColor

    if memory.autoSwitchEnabled then
        valColor    = ui.colors.textDim
        statusText  = "auto"
        statusColor = ui.colors.textDim
    elseif not hasOptimal then
        valColor    = ui.colors.text
        statusText  = ""
        statusColor = ui.colors.textDim
    elseif isOptimal then
        valColor    = ui.colors.success
        statusText  = "optimal"
        statusColor = {ui.colors.success[1], ui.colors.success[2], ui.colors.success[3], 0.60}
    else
        local deviation = math.abs(val - optimal) - tolerance
        if deviation > 20 then
            valColor    = ui.colors.error
            statusColor = ui.colors.error
        else
            valColor    = ui.colors.warning
            statusColor = ui.colors.warning
        end
        statusText = (val < optimal) and "^ low" or "v high"
    end

    -- EN: Package Level override: hide hints if packageLevel < 2 (Sensor Kit).
    -- UA: Перевизначення рівня: приховуємо підказки та оптимальні кольори якщо рівень < 2.
    if self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
        local packageLevel = self.activeVehicle.spec_rhm_Combine.packageLevel or 1
        if packageLevel < 2 then
            valColor = ui.colors.text
            statusText = ""
            statusColor = ui.colors.textDim
            hasOptimal = false -- Disable optimal pin marker & green bar
        end
    end

    -- EN: Teal highlight when mouse is over the value area (scroll wheel target).
    -- UA: Бірюзове підсвічування коли миша над областю значення (ціль колеса прокрутки).
    local valBoxHovered = self:checkHover(valX, y - 0.005, valW, ui.lineHeight)
    if valBoxHovered then
        self.hoveredParameter = param
        valColor = ui.colors.teal
    end

    -- EN: Also track hover for the full value+status area.
    -- UA: Також відстежуємо наведення для всієї області значення+статусу.
    if isRowHovered then
        self.hoveredParameter = param
    end

    -- ── Label ──────────────────────────────────────────────────────────────
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.textDim))
    local labelTextW = getTextWidth(ui.fontSize, label)
    local maxLabelW = labelW - 0.010
    local labelScale = 1.0
    if labelTextW > maxLabelW then
        labelScale = maxLabelW / labelTextW
    end
    renderText(x + 0.005, y + 0.014 + ui.fontSize * (1 - labelScale) * 0.5, ui.fontSize * labelScale, label)

    -- ── Value ──────────────────────────────────────────────────────────────
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(valColor))
    local valTextW = getTextWidth(ui.fontSize, displayStr)
    local maxValW = valW - 0.005
    local valScale = 1.0
    if valTextW > maxValW then
        valScale = maxValW / valTextW
    end
    renderText(valX + valW * 0.5, y + 0.014 + ui.fontSize * (1 - valScale) * 0.5, ui.fontSize * valScale, displayStr)

    -- ── Status hint ────────────────────────────────────────────────────────
    if statusText ~= "" and statusW > 0.008 then
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(unpack(statusColor))
        renderText(valEndX + 0.002, y + 0.014, ui.statusSize, statusText)
    end

    -- ── Progress bar ───────────────────────────────────────────────────────
    -- EN: Bar spans from value column start to button area. Shows current % position.
    --     White marker pin at the optimal % position.
    -- UA: Бар від початку колонки значень до кнопок. Показує позицію поточного % значення.
    --     Білий маркер на позиції оптимального % значення.
    if hasOptimal then
        local barX = valX
        local barW = btnStartX - valX - 0.004
        local barY = y + 0.005
        local barH = 0.003

        -- EN: Bar track.
        -- UA: Трек бару.
        self:drawRect(barX, barY, barW, barH, ui.colors.barBg)

        -- EN: Bar fill (current value).
        -- UA: Заповнення бару (поточне значення).
        local fillPct = math.max(0, math.min(val / 100.0, 1.0))
        local fillColor = isOptimal and ui.colors.success
                        or (val < optimal - tolerance and ui.colors.warning or ui.colors.warning)
        if math.abs(val - optimal) - tolerance > 20 then
            fillColor = ui.colors.error
        end
        self:drawRect(barX, barY, fillPct * barW, barH, fillColor)

        -- The optimal pin marker has been removed based on user feedback.
    end

    -- ── Smart step logic ───────────────────────────────────────────────────
    -- EN: Calculates physical increment (10 RPM or 0.5 mm), snaps to grid,
    --     converts back to %. Falls back to 1% steps if UnitConverter unavailable.
    -- UA: Розраховує фізичний крок (10 об/хв або 0.5 мм), прив'язується до сітки,
    --     конвертує назад у %. Відступає до кроків 1% якщо UnitConverter недоступний.
    local function performSmartStep(direction)
        if param == "targetEngineLoad" then
            memory:updateSetting(param, val + (direction * 5))
            return
        end

        if UnitConverter and UnitConverter.percentToPhysical then
            local physVal = UnitConverter.percentToPhysical(param, val, machineType)
            local range = UnitConverter.getPhysicalRange(param, machineType)

            if range then
                local stepValue = 1
                if range.unit == "RPM" then
                    stepValue = 10
                elseif range.unit == "mm" then
                    stepValue = 0.5
                end

                local targetPhysVal = physVal

                if stepValue >= 1 then
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
                else
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
                end

                local targetPercent = UnitConverter.physicalToPercent(param, targetPhysVal, machineType)

                if math.abs(targetPercent - val) < 0.5 then
                    targetPercent = val + (direction * 1)
                end

                memory:updateSetting(param, math.floor(targetPercent + 0.5))
            else
                memory:updateSetting(param, val + direction)
            end
        else
            memory:updateSetting(param, val + direction)
        end
    end

    -- ── [-] and [+] buttons ────────────────────────────────────────────────
    self:drawButton(btnStartX, y + 0.004, ui.buttonW, ui.buttonH, "-", function()
        performSmartStep(-1)
    end)

    self:drawButton(btnStartX + ui.buttonW + 0.004, y + 0.004, ui.buttonW, ui.buttonH, "+", function()
        performSmartStep(1)
    end)
end

-- EN: Draws a colored button. Text and hover color differ for [-] and [+] buttons
--     to give instant visual feedback on the direction of change.
-- UA: Малює кольорову кнопку. Колір тексту та наведення відрізняються для кнопок [-] та [+],
--     щоб дати миттєвий візуальний зворотній зв'язок про напрямок зміни.
function CombineCalibrationGUI:drawButton(x, y, w, h, text, callback, colorOverride)
    local isHovered = self:checkHover(x, y, w, h)

    local bgColor
    if colorOverride then
        bgColor = isHovered and {
            colorOverride[1] * 1.4,
            colorOverride[2] * 1.4,
            colorOverride[3] * 1.4,
            colorOverride[4]
        } or colorOverride
    elseif isHovered then
        if text == "+" then
            bgColor = self.ui.colors.buttonHover  -- green tint applied via text color
        elseif text == "-" then
            bgColor = self.ui.colors.buttonHover  -- red tint applied via text color
        else
            bgColor = self.ui.colors.buttonHover
        end
    else
        bgColor = self.ui.colors.button
    end

    self:drawRect(x, y, w, h, bgColor)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)

    if isHovered then
        if text == "+" then
            setTextColor(0.40, 1.00, 0.55, 1.0)   -- EN: Bright green / UA: Яскраво-зелений
        elseif text == "-" then
            setTextColor(1.00, 0.40, 0.40, 1.0)   -- EN: Bright red / UA: Яскраво-червоний
        else
            setTextColor(unpack(self.ui.colors.accent))  -- EN: Amber for action buttons / UA: Бурштин для кнопок дій
        end
    else
        if text == "+" then
            setTextColor(0.38, 0.36, 0.32, 1.0)
        elseif text == "-" then
            setTextColor(0.38, 0.36, 0.32, 1.0)
        elseif colorOverride then
            setTextColor(unpack(self.ui.colors.text))
        else
            setTextColor(unpack(self.ui.colors.textDim))
        end
    end

    renderText(x + w / 2, y + h / 2 - self.ui.fontSize / 2.5, self.ui.fontSize, text)
    setTextBold(false)

    table.insert(self.buttons, {x=x, y=y, w=w, h=h, callback=callback})
end

-- EN: Draws a solid-color rectangle using the persistent overlay object.
-- UA: Малює суцільний кольоровий прямокутник використовуючи постійний об'єкт оверлею.
function CombineCalibrationGUI:drawRect(x, y, w, h, color)
    if not self.overlay then return end
    local r, g, b, a = unpack(color)
    self.overlay:setPosition(x, y)
    self.overlay:setDimension(w, h)
    self.overlay:setColor(r, g, b, a)
    self.overlay:render()
end

-- EN: Resets text rendering state to engine defaults.
-- UA: Скидає стан рендерингу тексту до значень рушія.
function CombineCalibrationGUI:_resetTextState()
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

-- EN: Returns true if the current mouse position is inside the given rectangle.
-- UA: Повертає true якщо поточна позиція миші знаходиться всередині заданого прямокутника.
function CombineCalibrationGUI:checkHover(x, y, w, h)
    local mx, my = self.mouseX, self.mouseY
    if not mx or not my then
        mx, my = g_inputBinding:getMousePosition()
    end
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- EN: Full mouse event handler. Tracks position, consumes wheel events inside GUI,
--     dispatches scroll to smart parameter adjustment (Shift=5x), dispatches clicks to buttons.
-- UA: Повний обробник подій миші. Відстежує позицію, поглинає події колеса всередині GUI,
--     направляє прокрутку до розумного регулювання (Shift=5x), направляє кліки до кнопок.
function CombineCalibrationGUI:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isOpen then return end

    self.mouseX = posX
    self.mouseY = posY

    local insideGUI = posX >= self.ui.x and posX <= self.ui.x + self.ui.w and
                      posY >= self.ui.y and posY <= self.ui.y + self.ui.h

    local isWheel = button == Input.MOUSE_BUTTON_WHEEL_UP or button == Input.MOUSE_BUTTON_WHEEL_DOWN
    if isWheel and insideGUI then
        if isDown then
            local wheelUp = button == Input.MOUSE_BUTTON_WHEEL_UP
            local delta = wheelUp and 1 or -1

            if Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift) then
                delta = delta * 5
            end

            local param = self:getParameterAtMouse(posX, posY)
            if param then
                local spec = self.activeVehicle.spec_rhm_Combine
                if spec and spec.combineMemory then
                    local currentVal = spec.combineMemory.currentSettings[param]
                    local machineType = spec.machineType or "grain"

                    if param == "targetEngineLoad" then
                        spec.combineMemory:updateSetting(param, currentVal + (delta * 5))
                        return true
                    end

                    if UnitConverter and UnitConverter.percentToPhysical then
                        local physVal = UnitConverter.percentToPhysical(param, currentVal, machineType)
                        local range = UnitConverter.getPhysicalRange(param, machineType)

                        if range then
                            local stepValue = range.unit == "RPM" and 10 or 0.5
                            local targetPhysVal = physVal

                            local snapped = math.floor((physVal / stepValue) + 0.5) * stepValue
                            if math.abs(physVal - snapped) > 0.01 then
                                if delta > 0 then targetPhysVal = math.ceil(physVal / stepValue) * stepValue
                                else targetPhysVal = math.floor(physVal / stepValue) * stepValue end
                                if math.abs(delta) > 1 then
                                    local remaining = delta > 0 and (delta - 1) or (delta + 1)
                                    targetPhysVal = targetPhysVal + (stepValue * remaining)
                                end
                            else
                                targetPhysVal = snapped + (stepValue * delta)
                            end

                            local targetPercent = UnitConverter.physicalToPercent(param, targetPhysVal, machineType)

                            if math.abs(targetPercent - currentVal) < 0.5 then
                                targetPercent = currentVal + (delta > 0 and 1 or -1)
                                if math.abs(delta) > 1 then targetPercent = targetPercent + delta end
                            end

                            spec.combineMemory:updateSetting(param, math.floor(targetPercent + 0.5))
                        else
                            spec.combineMemory:updateSetting(param, currentVal + delta)
                        end
                    else
                        spec.combineMemory:updateSetting(param, currentVal + delta)
                    end
                end
            end
        end
        return true
    end

    if isDown and button == Input.MOUSE_BUTTON_LEFT then
        for _, btn in ipairs(self.buttons) do
            if posX >= btn.x and posX <= btn.x + btn.w and posY >= btn.y and posY <= btn.y + btn.h then
                if btn.callback then
                    btn.callback()
                end
                return true
            end
        end
    end

    if insideGUI then
        return true
    end
end

-- EN: Wheel scroll handler used by the debounced polling in draw().
--     Applies adjustment to hoveredParameter if one is set. Shift=5x multiplier.
-- UA: Обробник прокрутки колесом для дебаунсного опитування у draw().
--     Застосовує регулювання до hoveredParameter якщо він встановлений. Shift=5x множник.
function CombineCalibrationGUI:handleWheelScroll(direction, posX, posY)
    local delta = direction
    if Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift) then
        delta = delta * 5
    end

    if self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
        local spec = self.activeVehicle.spec_rhm_Combine
        if spec.combineMemory and self.hoveredParameter then
            local currentVal = spec.combineMemory.currentSettings[self.hoveredParameter]
            spec.combineMemory:updateSetting(self.hoveredParameter, currentVal + delta)
        end
    end
end

-- EN: Returns the name of the parameter currently hovered by the mouse.
-- UA: Повертає назву параметра над яким зараз знаходиться миша.
function CombineCalibrationGUI:getParameterAtMouse(x, y)
    if self.hoveredParameter then
        return self.hoveredParameter
    end
    return nil
end

RHM_Debug.log("UI", "[OK] CombineCalibrationGUI loaded")