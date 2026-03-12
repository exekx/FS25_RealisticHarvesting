-- EN: Interactive visual calibration GUI for combine harvester settings.
--     Renders as an always-on overlay panel with sliders ([-]/[+] buttons and mouse wheel)
--     for each active parameter (fan, rotor, sieves, feeder) based on machine type.
--     Shows real-time color-coded loss and speed penalty preview from CombineSettingsDatabase.
--     Supports NEXAT modular systems by searching the vehicle hierarchy for spec_rhm_Combine.
--     Blocks camera rotation and zoom while open; restores them on close.
-- UA: Інтерактивний візуальний GUI калібрування для налаштувань зернозбирального комбайна.
--     Відображається як постійна накладка з повзунками (кнопки [-]/[+] та колесо миші)
--     для кожного активного параметра (вентилятор, ротор, решета, подача) залежно від типу машини.
--     Показує попередній перегляд штрафів за втрати та швидкість у режимі реального часу з CombineSettingsDatabase.
--     Підтримує модульні системи NEXAT, шукаючи spec_rhm_Combine в ієрархії транспорту.
--     Блокує обертання та масштабування камери при відкритті; відновлює при закритті.
CombineCalibrationGUI = {}
local CombineCalibrationGUI_mt = Class(CombineCalibrationGUI)

-- EN: Creates a new GUI instance. Initializes UI layout constants, color palette,
--     button registry, scroll debouncing, and the persistent overlay object.
-- UA: Створює новий екземпляр GUI. Ініціалізує константи розмітки UI, кольорову палітру,
--     реєстр кнопок, захист від дребезгу прокрутки та постійний об'єкт оверлею.
function CombineCalibrationGUI.new(modDirectory)
    local self = setmetatable({}, CombineCalibrationGUI_mt)
    self.modDirectory = modDirectory
    self.isOpen = false
    self.isCursorActive = false
    self.debug = true -- EN: Enable diagnostic logging / UA: Увімкнути діагностичне логування
    
    -- EN: UI layout configuration: position, size, margins, typography, and color palette.
    -- UA: Конфігурація розмітки UI: позиція, розмір, відступи, типографіка та кольорова палітра.
    self.ui = {
        x = 0.68, y = 0.45, -- EN: Position (right side of screen) / UA: Позиція (права сторона екрану)
        w = 0.30, h = 0.45, -- EN: Width and height (normalized screen units) / UA: Ширина та висота (нормалізовані одиниці)
        margin = 0.01,
        headerHeight = 0.04,
        lineHeight = 0.035,
        fontSize = 0.014,
        titleSize = 0.020,
        buttonW = 0.025,
        buttonH = 0.025,
        
        -- EN: Color palette for all GUI elements.
        -- UA: Кольорова палітра для всіх елементів GUI.
        colors = {
            bg = {0.05, 0.05, 0.05, 0.9},
            header = {0.1, 0.1, 0.1, 0.95},
            text = {1, 1, 1, 1},
            textDim = {0.7, 0.7, 0.7, 1},
            accent = {0.2, 0.6, 1.0, 1},          -- EN: Blue highlight / UA: Синій акцент
            warning = {1.0, 0.6, 0.2, 1},          -- EN: Orange warning / UA: Помаранчеве попередження
            error = {0.9, 0.2, 0.2, 1},             -- EN: Red error / UA: Червона помилка
            success = {0.2, 0.8, 0.2, 1},           -- EN: Green optimal / UA: Зелений оптимум
            button = {0.2, 0.2, 0.2, 1},
            buttonHover = {0.3, 0.4, 0.5, 1},      -- EN: Blue-tinted hover / UA: Синюватий колір при наведенні
            buttonActive = {0.4, 0.4, 0.4, 1},
            paramRowHover = {0.15, 0.15, 0.15, 0.8} -- EN: Subtle row highlight / UA: М'яке підсвічування рядка
        }
    }
    
    -- EN: Interaction state: active vehicle, hover tracking, mouse position.
    -- UA: Стан взаємодії: активний транспорт, відстеження наведення, позиція миші.
    self.activeVehicle = nil
    self.hoveredElement = nil
    self.mouseX = 0
    self.mouseY = 0
    self.hoveredParameter = nil  -- EN: Which parameter row the mouse is over / UA: Над яким рядком параметра знаходиться миша
    
    -- EN: Saved camera state — restored exactly on close, not globally reset.
    -- UA: Збережений стан камери — відновлюється точно при закритті, а не скидається глобально.
    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}
    
    -- EN: Scroll debouncing prevents scroll events from firing more than once per scrollDelayMs.
    -- UA: Захист від дребезгу прокрутки запобігає спрацюванню більше ніж раз за scrollDelayMs.
    self.lastScrollTimeStamp = 0
    self.scrollDelayMs = 100
    
    -- EN: Button registry rebuilt every frame in draw(). Used for click hit-testing.
    -- UA: Реєстр кнопок перебудовується кожен кадр у draw(). Використовується для перевірки кліків.
    self.buttons = {} 
    
    -- EN: Persistent overlay object — reused every frame for drawing all colored rectangles.
    -- UA: Постійний об'єкт оверлею — перевикористовується кожен кадр для малювання всіх кольорових прямокутників.
    local bgTexture = self.modDirectory .. "textures/hud_background.dds"
    self.overlay = Overlay.new(bgTexture, 0, 0, 1, 1)
    
    return self
end

-- EN: Releases the overlay GPU resource.
-- UA: Звільняє ресурс GPU оверлею.
function CombineCalibrationGUI:delete()
    if self.overlay then
        self.overlay:delete()
        self.overlay = nil
    end
end

-- EN: Toggles the GUI open if closed (for the given vehicle) or closes if open.
-- UA: Перемикає GUI відкрити/закрити — відкриває для заданого транспортного засобу або закриває.
function CombineCalibrationGUI:toggle(vehicle)
    if self.isOpen then
        self:close()
    else
        self:open(vehicle)
    end
end

-- EN: Opens the calibration GUI for a vehicle.
--     For modular systems (NEXAT), searches the entire vehicle hierarchy for spec_rhm_Combine
--     because the player may be sitting in a cab that doesn't have the spec itself.
--     Blocks camera rotation and zoom to prevent accidental camera movement while adjusting sliders.
-- UA: Відкриває GUI калібрування для транспортного засобу.
--     Для модульних систем (NEXAT), шукає в усій ієрархії транспорту spec_rhm_Combine,
--     оскільки гравець може сидіти у кабіні без самої специфікації.
--     Блокує обертання та масштابування камери для запобігання випадкового руху під час регулювання.
function CombineCalibrationGUI:open(vehicle)
    if self.isOpen then return end
    
    -- EN: NEXAT FIX: find the vehicle with spec_rhm_Combine in the full hierarchy.
    -- UA: NEXAT FIX: шукаємо транспортний засіб з spec_rhm_Combine у повній ієрархії.
    local combineVehicle = vehicle
    if vehicle and not vehicle.spec_rhm_Combine then
        -- EN: Recursive hierarchy search — visits parent, attacher, and all implements.
        -- UA: Рекурсивний пошук в ієрархії — відвідує батька, причеп та всі реалізації.
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
    
    -- EN: Enable mouse cursor so the player can interact with the GUI.
    -- UA: Вмикаємо курсор миші щоб гравець міг взаємодіяти з GUI.
    g_inputBinding:setShowMouseCursor(true)
    self.isCursorActive = true
    
    -- EN: Block camera rotation AND zoom on the vehicle the player is ACTUALLY sitting in.
    --     (For NEXAT, this is the cab vehicle, not the combine module.)
    -- UA: Блокуємо обертання і масштаб камери на транспортному засобі в якому сидить гравець.
    --     (Для NEXAT — це кабіна, а не модуль комбайна.)
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
            camera.allowZoom = false  -- EN: Block scroll-wheel zoom / UA: Блокуємо масштабування колесом
        end
    end
    
    -- EN: Store both the combine vehicle (from hierarchy) and the vehicle the player controls.
    -- UA: Зберігаємо як комбайн (з ієрархії), так і транспорт яким керує гравець.
    self.activeVehicle = combineVehicle
    self.controllerVehicle = cv or vehicle or combineVehicle
end

-- EN: Closes the calibration GUI. Restores camera rotation and zoom to their pre-open state.
--     If HUD cursor mode is still active (from RealisticHarvestManager:toggleCursor),
--     the cursor is kept visible but camera rotation is re-blocked from the HUD drag state.
-- UA: Закриває GUI калібрування. Відновлює обертання та масштаб камери до стану до відкриття.
--     Якщо режим курсора HUD ще активний (з RealisticHarvestManager:toggleCursor),
--     курсор залишається видимим але обертання камери знову блокується для стану перетягування HUD.
function CombineCalibrationGUI:close()
    if not self.isOpen then return end
    
    self.isOpen = false
    self.isCursorActive = false
    
    -- EN: Use the controller vehicle (cab) for camera restoration, not the combine module.
    -- UA: Використовуємо транспорт з кабіною для відновлення камери, а не модуль комбайна.
    local vehicle = self.controllerVehicle
    
    -- EN: Check if HUD cursor mode is still active (from RHM Manager toggleCursor).
    -- UA: Перевіряємо чи активний режим курсора HUD (з toggleCursor менеджера RHM).
    local hudCursorActive = g_realisticHarvestManager and g_realisticHarvestManager.isCursorVisible
    g_inputBinding:setShowMouseCursor(hudCursorActive or false)
    
    -- EN: Restore camera rotation and zoom from saved state.
    -- UA: Відновлюємо обертання та масштаб камери зі збереженого стану.
    if vehicle and vehicle.spec_enterable then
        for _, camera in pairs(vehicle.spec_enterable.cameras) do
            local savedRotatable = self.savedCameraRotatableInfo[camera]
            local savedZoom = self.savedCameraZoomInfo[camera]
            camera.isRotatable = savedRotatable ~= nil and savedRotatable or true
            camera.allowTranslation = savedZoom ~= nil and savedZoom or true
            camera.allowZoom = savedZoom ~= nil and savedZoom or true
        end
        self.savedCameraRotatableInfo = {}
        self.savedCameraZoomInfo = {}
    end
    
    -- EN: If HUD cursor was active, re-block camera rotation (camera state managed by Manager, not GUI).
    -- UA: Якщо курсор HUD був активний, знову блокуємо обертання камери (стан управляється Менеджером, не GUI).
    if hudCursorActive and vehicle and vehicle.spec_enterable then
        RHMInputUtil.setCameraRotation(vehicle, false, g_realisticHarvestManager.savedCameraRotatableInfo)
    end
end

-- EN: Cycles to the previous (-1) or next (+1) crop in the machine-type-filtered crop list.
--     Calls CombineMemory:switchCrop which handles settings handover and network sync.
-- UA: Перемикає на попередню (-1) або наступну (+1) культуру у відфільтрованому за типом машини списку.
--     Викликає CombineMemory:switchCrop який обробляє передачу налаштувань та мережеву синхронізацію.
function CombineCalibrationGUI:cycleCrop(direction)
    local spec = self.activeVehicle.spec_rhm_Combine
    local machineType = spec.machineType or "grain"
    -- EN: Only show crops relevant to this machine type in the cycle.
    -- UA: У циклі показуємо лише культури відповідного типу машини.
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

-- EN: Handles mouse events. Intercepts scroll wheel events to prevent camera zoom while GUI is open.
--     Left-click is handled separately in the full mouseEvent method below.
-- UA: Обробляє події миші. Перехоплює події колеса прокрутки щоб запобігти масштабуванню камери поки GUI відкритий.
--     Лівий клік обробляється окремо у повному методі mouseEvent нижче.
function CombineCalibrationGUI:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    if not self.isOpen then return false end
    
    -- EN: Consume scroll wheel events entirely to block camera zoom (GIANTS engine: button 4=up, 5=down).
    -- UA: Повністю з'їдаємо події колеса прокрутки для блокування масштабування камери (button 4=вгору, 5=вниз).
    if button == Input.MOUSE_BUTTON_WHEEL_UP or button == Input.MOUSE_BUTTON_WHEEL_DOWN then
        return true
    end
    
    return false
end

-- EN: Called every frame while open. Auto-closes if the player exits the vehicle.
--     Handles both standard vehicles and NEXAT modular systems (root vehicle matching).
-- UA: Викликається кожен кадр поки відкритий. Автоматично закриває якщо гравець виходить з транспорту.
--     Обробляє як стандартні транспортні засоби, так і модульні системи NEXAT (перевірка кореневого транспорту).
function CombineCalibrationGUI:update(dt)
    if not self.isOpen then return end
    
    -- EN: Close if the active vehicle was unloaded or removed from the mission.
    -- UA: Закриваємо якщо активний транспортний засіб вивантажено або видалено з місії.
    if not self.activeVehicle then
         self:close()
         return
    end
    
    -- EN: Determine if the player is still in their vehicle.
    --     For NEXAT: controllerVehicle = cab, activeVehicle = combine module.
    --     Match by direct equality or by shared rootVehicle to support modular trains.
    -- UA: Визначаємо чи гравець все ще знаходиться у своєму транспортному засобі.
    --     Для NEXAT: controllerVehicle = кабіна, activeVehicle = модуль комбайна.
    --     Порівнюємо напряму або за спільним rootVehicle для підтримки модульних потягів.
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
                -- EN: Match by shared root vehicle (NEXAT cab vs combine module).
                -- UA: Порівнюємо за спільним кореневим транспортом (кабіна NEXAT vs модуль комбайна).
                local rootA = cv.rootVehicle or cv
                local rootB = vehicleToCheck.rootVehicle or vehicleToCheck
                if rootA == rootB then
                    isEntered = true
                end
            end
        end
        
        -- EN: Fallback for AI-controlled or directly entered vehicles.
        -- UA: Резервна перевірка для транспорту під управлінням AI або прямого входу.
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

-- EN: Main draw function. Renders the calibration panel with header, crop selector,
--     mode buttons (AUTO/LOAD PRESET), parameter rows, loss/speed preview, and profile buttons.
--     Also processes mouse wheel scroll over parameter rows at the end of the frame.
-- UA: Головна функція малювання. Відображає панель калібрування із заголовком, вибором культури,
--     кнопками режиму (AUTO/LOAD PRESET), рядками параметрів, попереднім переглядом втрат/швидкості та кнопками профілю.
--     Також обробляє прокрутку колесом миші над рядками параметрів в кінці кадру.
function CombineCalibrationGUI:draw()
    if not self.isOpen then return end
    if not (g_currentMission and g_currentMission.hud) then 
        if self.debug then print("RHM: [GUI] draw() abort: no g_currentMission.hud") end
        return 
    end
    
    -- EN: Clear button registry at start of each frame — rebuilt during draw.
    -- UA: Очищаємо реєстр кнопок на початку кожного кадру — перебудовується під час малювання.
    self.buttons = {}
    self.hoveredParameter = nil
    
    local ui = self.ui
    local x, y = ui.x, ui.y
    local w, h = ui.w, ui.h
    
    -- EN: Draw background panel and header strip.
    -- UA: Малюємо фонову панель і смугу заголовку.
    self:drawRect(x, y, w, h, ui.colors.bg)
    self:drawRect(x, y + h - ui.headerHeight, w, ui.headerHeight, ui.colors.header)
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(ui.colors.text))
    renderText(x + w/2, y + h - ui.headerHeight + 0.01, ui.titleSize, g_i18n:getText("rhm_gui_title"))
    
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
    
    -- EN: Crop selector row with prev/next buttons and localized crop name.
    -- UA: Рядок вибору культури з кнопками попередньої/наступної та локалізованою назвою культури.
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(x + ui.margin, cy + 0.005, ui.fontSize, g_i18n:getText("rhm_gui_crop"))
    
    local cropX = x + ui.margin + 0.05
    
    self:drawButton(cropX, cy, 0.025, 0.035, "<", function()
        self:cycleCrop(-1)
    end)
    
    -- EN: Localize the crop name via FillType manager, with l10n key fallback.
    -- UA: Локалізуємо назву культури через FillType менеджер, з резервним l10n ключем.
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
            end
        end
        return displayName
    end
    
    setTextAlignment(RenderText.ALIGN_CENTER)
    renderText(cropX + 0.025 + 0.07, cy + 0.005, ui.fontSize, getLocalizedCropName(memory.currentCrop))
    
    self:drawButton(cropX + 0.025 + 0.14, cy, 0.025, 0.035, ">", function()
        self:cycleCrop(1)
    end)
    
    cy = cy - ui.lineHeight * 1.2
    
    -- EN: Mode buttons: AUTO applies optimal settings (server-side randomized); LOAD PRESET loads the user's saved profile.
    -- UA: Кнопки режиму: AUTO застосовує оптимальні налаштування (з серверною рандомізацією); LOAD PRESET завантажує збережений профіль.
    local btnWidth = (w - ui.margin * 2.5 - 0.01) / 2
    
    self:drawButton(x + ui.margin, cy, btnWidth, 0.035, g_i18n:getText("rhm_gui_btn_auto"), function()
        memory:requestAutoSettings()
    end, {0.9, 0.7, 0.1, 1})
    
    self:drawButton(x + w - ui.margin - btnWidth, cy, btnWidth, 0.035, g_i18n:getText("rhm_gui_btn_load_preset"), function()
        memory:loadUserPreset()
    end, {0.1, 0.5, 0.9, 1})
    
    cy = cy - ui.lineHeight * 1.5
    
    -- EN: Parameter rows — dynamically built from machine type active param list.
    -- UA: Рядки параметрів — динамічно будуються зі списку активних параметрів типу машини.
    local machineType = spec.machineType or "grain"
    local activeParams = CombineSettingsDatabase:getParamsForMachineType(machineType)
    
    for _, param in ipairs(activeParams) do
        local labelKey = CombineSettingsDatabase:getParamLabel(machineType, param)
        local label = g_i18n:hasText(labelKey) and g_i18n:getText(labelKey) or param
        self:drawParameterRow(x + ui.margin, cy, w - ui.margin*2, param, label, memory, ui, machineType)
        cy = cy - ui.lineHeight
    end
    
    cy = cy - ui.lineHeight * 0.5
    
    -- EN: Settings efficiency/loss preview: reads checkSettingsForCrop from CombineMemory.
    --     effPenalty < 0 means a speed bonus; lossPenalty <= 0 means no crop loss.
    -- UA: Попередній перегляд ефективності/втрат: читає checkSettingsForCrop з CombineMemory.
    --     effPenalty < 0 означає бонус швидкості; lossPenalty <= 0 означає відсутність втрат.
    local load = (spec.loadCalculator and spec.loadCalculator.engineLoad or 0) * 100
    
    local effPenalty = 0
    local lossPenalty = 0
    if memory.currentCrop then
        effPenalty, lossPenalty, _ = memory:checkSettingsForCrop(memory.currentCrop)
    end
    
    -- EN: Format speed and loss text. Negative effPenalty = speed bonus (+X%).
    -- UA: Форматуємо текст швидкості та втрат. Від'ємний effPenalty = бонус швидкості (+X%).
    local speedStr = ""
    local lossStr = ""
    
    if effPenalty < 0 then
        local speedBonus = math.abs(effPenalty) * 5.0
        speedStr = string.format("Speed: +%.1f%%", speedBonus)
    else
        speedStr = string.format("Speed: -%.1f%%", effPenalty)
    end
    
    -- EN: Loss values below 0 are mathematical bonuses in core logic, displayed as 0.0% to the player.
    -- UA: Значення втрат нижче 0 є математичними бонусами в ядрі логіки, відображаються гравцеві як 0.0%.
    if lossPenalty <= 0 then
        lossStr = "Loss: 0.0%"
    else
        lossStr = string.format("Loss: +%.1f%%", lossPenalty)
    end
    
    local textStr = speedStr .. "  |  " .. lossStr
    
    -- EN: Color the penalty line: red if any penalty > 0.5%, green if speed bonus and no loss.
    -- UA: Кольоруємо рядок штрафу: червоний якщо будь-який штраф > 0.5%, зелений якщо бонус швидкості і немає втрат.
    local textColor = ui.colors.text
    if lossPenalty > 0.5 or effPenalty > 0.5 then
        textColor = ui.colors.error or {0.9, 0.2, 0.2, 1.0}
    elseif effPenalty < -0.1 and lossPenalty <= 0.5 then
        textColor = ui.colors.success or {0.2, 0.8, 0.2, 1.0}
    end
    
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.textDim))
    renderText(x + ui.margin, cy + 0.005, ui.fontSize, string.format(g_i18n:getText("rhm_gui_engine_load"), load))
    
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(unpack(textColor))
    renderText(x + w - ui.margin, cy + 0.005, ui.fontSize, textStr)

    cy = cy - ui.lineHeight * 1.5
    
    -- EN: Profile management buttons: save current settings, or reset to defaults.
    -- UA: Кнопки управління профілем: зберегти поточні налаштування або скинути до типових.
    self:drawButton(x + ui.margin, cy, 0.12, 0.035, g_i18n:getText("rhm_gui_btn_save"), function()
        memory:saveCurrentProfile(memory.currentCrop)
    end)
    
    self:drawButton(x + w - ui.margin - 0.12, cy, 0.12, 0.035, g_i18n:getText("rhm_gui_btn_reset"), function()
        memory:requestResetSettings()
    end, ui.colors.warning)
    
    cy = cy - ui.lineHeight
    
    -- EN: Close hint text at the bottom (e.g. "Press K to close").
    -- UA: Підказка закриття внизу (напр. "Натисніть K для закриття").
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(ui.colors.textDim))
    renderText(x + w/2, cy + 0.005, ui.fontSize * 0.9, g_i18n:getText("rhm_gui_close_hint"))
    
    -- EN: Process scroll wheel adjustments (debounced). Only fires when mouse is inside GUI.
    --     Shift held = 5x step multiplier for faster adjustment.
    -- UA: Обробляємо прокрутку колесом (з захистом від дребезгу). Спрацьовує лише коли миша в середині GUI.
    --     Shift = 5x множник кроку для швидшого регулювання.
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
    
    -- EN: Reset text rendering state.
    -- UA: Скидаємо стан відображення тексту.
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

-- EN: Draws a single parameter row: label on left, formatted value in center,
--     [-] and [+] buttons on right. Color-codes value green when within tolerance of optimal.
--     Highlights the value box in cyan when hovered, and sets hoveredParameter for wheel scroll.
--     Uses UnitConverter.formatSetting to display physical units (RPM, mm) instead of %.
--     Smart step logic: calculates physical steps (10 RPM / 0.5 mm) then converts back to %.
-- UA: Малює один рядок параметра: мітка ліворуч, відформатоване значення по центру,
--     кнопки [-] та [+] праворуч. Кодує значення зеленим коли в межах допуску від оптимуму.
--     Підсвічує область значення блакитним при наведенні, встановлює hoveredParameter для прокрутки.
--     Використовує UnitConverter.formatSetting для відображення фізичних одиниць (об/хв, мм) замість %.
--     Розумна логіка кроку: розраховує фізичні кроки (10 об/хв / 0.5 мм) і конвертує назад у %.
function CombineCalibrationGUI:drawParameterRow(x, y, w, param, label, memory, ui, machineType)
    local val = memory.currentSettings[param] or 0
    local optimal = 0
    local isOptimal = false
    
    local isHovered = self:checkHover(x, y - 0.003, w, ui.lineHeight)
    
    -- EN: Check if current value is within tolerance of optimal from DB.
    -- UA: Перевіряємо чи поточне значення знаходиться в межах допуску від оптимуму з БД.
    if CombineSettingsDatabase and memory.currentCrop then
        local settings = CombineSettingsDatabase:getSettingsForCrop(memory.currentCrop)
        if settings and settings[param] then
            optimal = settings[param].optimal
            local tolerance = settings[param].tolerance or 5
            -- EN: Value is highlighted as optimal when within tolerance range.
            -- UA: Значення підсвічується як оптимальне коли в межах діапазону допуску.
            if math.abs(val - optimal) <= tolerance then
                isOptimal = true
            end
        end
    end
    
    -- EN: Format value using physical units (RPM, mm) via UnitConverter.
    -- UA: Форматуємо значення у фізичних одиницях (об/хв, мм) через UnitConverter.
    local displayStr = ""
    if UnitConverter and UnitConverter.formatSetting then
        displayStr = UnitConverter.formatSetting(param, val, machineType)
    else
        displayStr = string.format("%d%%", val)
    end
    
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.text))
    renderText(x, y + 0.005, ui.fontSize, label)
    
    -- EN: Value box occupies 25-75% of row width for hover detection.
    -- UA: Область значення займає 25-75% ширини рядка для виявлення наведення.
    local valBoxX = x + w * 0.25
    local valBoxW = w * 0.5
    local valBoxY = y - 0.003
    local valBoxH = ui.lineHeight
    
    local isValueHovered = self:checkHover(valBoxX, valBoxY, valBoxW, valBoxH)
    if isValueHovered then
        self.hoveredParameter = param
    end
    
    local valColor = isOptimal and ui.colors.success or ui.colors.text
    if memory.autoSwitchEnabled then valColor = ui.colors.textDim end -- EN: Dim when AUTO mode active / UA: Приглушений при активному AUTO режимі
    
    -- EN: Cyan highlight when mouse is over the value box.
    -- UA: Блакитне підсвічування коли миша над областю значення.
    if isValueHovered then
        valColor = {0.6, 1.0, 1.0, 1}
    end
    
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(valColor))
    renderText(x + w * 0.5, y + 0.005, ui.fontSize, displayStr)
    
    -- EN: Smart step logic for [-]/[+] buttons.
    --     Calculates physical increment (10 RPM or 0.5 mm), snaps to grid first,
    --     then converts back to %. Falls back to 1% steps if UnitConverter unavailable.
    -- UA: Розумна логіка кроку для кнопок [-]/[+].
    --     Розраховує фізичний крок (10 об/хв або 0.5 мм), спочатку прив'язується до сітки,
    --     потім конвертує назад у %. Відступає до кроків 1% якщо UnitConverter недоступний.
    local function performSmartStep(direction)
        if UnitConverter and UnitConverter.percentToPhysical then
            local physVal = UnitConverter.percentToPhysical(param, val, machineType)
            local range = UnitConverter.getPhysicalRange(param, machineType)
            
            if range then
                local stepValue = 1
                if range.unit == "RPM" then
                    stepValue = 10
                elseif range.unit == "mm" then
                    stepValue = 0.5 -- EN: 0.5mm for fine sieve adjustment / UA: 0.5мм для точного регулювання решет
                end
                
                local targetPhysVal = physVal
                
                -- EN: Snap to nearest grid point first to eliminate floating-point drift.
                -- UA: Спочатку прив'язуємось до найближчої точки сітки для усунення дрейфу з плаваючою точкою.
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
                    -- EN: Fractional step (0.5mm): same snap logic but for sub-1 increments.
                    -- UA: Дробовий крок (0.5мм): та ж логіка прив'язки але для часток одиниці.
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
                
                -- EN: If the physical change doesn't move even 1%, force a 1% change to prevent being stuck.
                -- UA: Якщо фізична зміна не рухає навіть 1%, примусово змінюємо на 1% щоб уникнути застрягання.
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

    -- EN: [-] and [+] buttons positioned at the right edge of the row.
    -- UA: Кнопки [-] та [+] розміщені біля правого краю рядка.
    self:drawButton(x + w - ui.buttonW*2 - 0.005, y, ui.buttonW, ui.buttonH, "-", function()
        performSmartStep(-1)
    end)
    
    self:drawButton(x + w - ui.buttonW, y, ui.buttonW, ui.buttonH, "+", function()
        performSmartStep(1)
    end)
end

-- EN: Draws a colored button rectangle and its label. Text turns cyan on hover.
--     Registers the button in self.buttons for click hit-testing in mouseEvent.
-- UA: Малює кольоровий прямокутник кнопки та її мітку. Текст стає блакитним при наведенні.
--     Реєструє кнопку в self.buttons для перевірки кліків у mouseEvent.
function CombineCalibrationGUI:drawButton(x, y, w, h, text, callback, colorOverride)
    local isHovered = self:checkHover(x, y, w, h)
    
    local bgColor = colorOverride or self.ui.colors.button
    self:drawRect(x, y, w, h, bgColor)
    
    setTextAlignment(RenderText.ALIGN_CENTER)
    if isHovered then
        setTextColor(0.6, 1.0, 1.0, 1)  -- EN: Bright cyan on hover / UA: Яскраво-блакитний при наведенні
    else
        setTextColor(1, 1, 1, 1)
    end
    renderText(x + w/2, y + h/2 - self.ui.fontSize/2.5, self.ui.fontSize, text)
    
    table.insert(self.buttons, {x=x, y=y, w=w, h=h, callback=callback})
end

-- EN: Draws a solid-color rectangle using the persistent overlay object. Cheaper than creating new overlays.
-- UA: Малює суцільний кольоровий прямокутник використовуючи постійний об'єкт оверлею. Дешевше за створення нових оверлеїв.
function CombineCalibrationGUI:drawRect(x, y, w, h, color)
    if not self.overlay then return end
    local r, g, b, a = unpack(color)
    self.overlay:setPosition(x, y)
    self.overlay:setDimension(w, h)
    self.overlay:setColor(r, g, b, a)
    self.overlay:render()
end

-- EN: Returns true if the current mouse position (from last mouseEvent or getMousePosition fallback)
--     is inside the given rectangle. Used for hover detection on all interactive elements.
-- UA: Повертає true якщо поточна позиція миші (із останнього mouseEvent або запасного getMousePosition)
--     знаходиться всередині заданого прямокутника. Використовується для виявлення наведення на всі інтерактивні елементи.
function CombineCalibrationGUI:checkHover(x, y, w, h)
    local mx, my = self.mouseX, self.mouseY
    if not mx or not my then
        mx, my = g_inputBinding:getMousePosition()
    end
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- EN: Full mouse event handler. Tracks mouse position, consumes all wheel events inside the GUI,
--     dispatches scroll wheel to smart parameter adjustment (with Shift=5x multiplier),
--     and dispatches left-clicks to the registered button callbacks.
--     Returns true to consume the event and prevent it from reaching FS25 camera/other systems.
-- UA: Повний обробник подій миші. Відстежує позицію миші, поглинає всі події колеса в середині GUI,
--     направляє прокрутку до розумного регулювання параметрів (Shift=5x множник),
--     та направляє ліві кліки до зареєстрованих колбеків кнопок.
--     Повертає true щоб поглинути подію і запобігти її потраплянню до камери/інших систем FS25.
function CombineCalibrationGUI:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isOpen then return end
    
    -- EN: Track mouse position every frame for hover effects.
    -- UA: Відстежуємо позицію миші кожен кадр для ефектів наведення.
    self.mouseX = posX
    self.mouseY = posY
    
    local insideGUI = posX >= self.ui.x and posX <= self.ui.x + self.ui.w and
                      posY >= self.ui.y and posY <= self.ui.y + self.ui.h
    
    -- EN: Scroll wheel inside GUI: adjust the hovered parameter with smart physical steps.
    --     Shift held applies a 5x multiplier for fast adjustment.
    -- UA: Прокрутка колесом всередині GUI: регулює наведений параметр з розумними фізичними кроками.
    --     Shift застосовує 5x множник для швидкого регулювання.
    local isWheel = button == Input.MOUSE_BUTTON_WHEEL_UP or button == Input.MOUSE_BUTTON_WHEEL_DOWN
    if isWheel and insideGUI then
        if isDown then
            local wheelUp = button == Input.MOUSE_BUTTON_WHEEL_UP
            local delta = wheelUp and 1 or -1
            
            -- EN: Shift modifier: 5x faster adjustment.
            -- UA: Модифікатор Shift: регулювання у 5 разів швидше.
            if Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift) then
                delta = delta * 5
            end
            
            local param = self:getParameterAtMouse(posX, posY)
            if param then
                local spec = self.activeVehicle.spec_rhm_Combine
                if spec and spec.combineMemory then
                    local currentVal = spec.combineMemory.currentSettings[param]
                    local machineType = spec.machineType or "grain"
                    
                    -- EN: Smart step: use physical unit increments (10 RPM, 0.5 mm) same as button logic.
                    -- UA: Розумний крок: використовуємо фізичні кроки (10 об/хв, 0.5 мм) як у логіці кнопок.
                    if UnitConverter and UnitConverter.percentToPhysical then
                        local physVal = UnitConverter.percentToPhysical(param, currentVal, machineType)
                        local range = UnitConverter.getPhysicalRange(param, machineType)
                        
                        if range then
                            local stepValue = range.unit == "RPM" and 10 or 0.5
                            local targetPhysVal = physVal
                            
                            -- EN: Grid snapping for scroll wheel same as buttons.
                            -- UA: Прив'язка до сітки для колеса прокрутки так само як у кнопок.
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
                            
                            -- EN: Force a 1% move if stuck at precision boundary.
                            -- UA: Примусово рухаємо на 1% якщо застрягли на межі точності.
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
        return true  -- EN: Always consume wheel events inside GUI / UA: Завжди поглинаємо події колеса всередині GUI
    end
    
    -- EN: Dispatch left-click to button callbacks.
    -- UA: Направляємо лівий клік до колбеків кнопок.
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
    
    -- EN: Consume all events inside GUI to prevent click-through.
    -- UA: Поглинаємо всі події всередині GUI щоб запобігти прокиданню кліків.
    if insideGUI then
       return true
    end
end

-- EN: Wheel scroll handler used by the debounced polling in draw().
--     Applies adjustment to hoveredParameter if one is set. Shift=5x multiplier.
-- UA: Обробник прокрутки колесом використовуваний дебаунсним опитуванням у draw().
--     Застосовує регулювання до hoveredParameter якщо він встановлений. Shift=5x множник.
function CombineCalibrationGUI:handleWheelScroll(direction, posX, posY)
    local delta = direction
    -- EN: Shift modifier for 5x faster adjustment.
    -- UA: Модифікатор Shift для 5x швидшого регулювання.
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

-- EN: Returns the name of the parameter the mouse is currently hovering over.
--     hoveredParameter is set each frame during drawParameterRow() calls.
-- UA: Повертає назву параметра над яким зараз знаходиться миша.
--     hoveredParameter встановлюється кожен кадр під час викликів drawParameterRow().
function CombineCalibrationGUI:getParameterAtMouse(x, y)
    if self.hoveredParameter then
        return self.hoveredParameter
    end
    return nil
end
