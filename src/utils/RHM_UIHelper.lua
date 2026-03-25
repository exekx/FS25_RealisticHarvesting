-- EN: Factory functions for injecting custom settings elements into FS25's in-game settings menu.
--     Uses cloning of existing vanilla elements to ensure visual consistency.
--     Supports section headers, binary (checkbox) options, and multi-text (dropdown-style) options.
-- UA: Фабричні функції для впровадження власних елементів налаштувань у меню FS25.
--     EN: Uses cloning of existing vanilla elements for visual consistency.
--     UA: Використовує клонування існуючих ванільних елементів для візуальної узгодженості.
--     EN: Supports section headers, binary (checkbox) options, and multi-option parameters.
--     UA: Підтримує заголовки секцій, бінарні (чекбокс) параметри та параметри з кількома варіантами.
RHMUIHelper = {}

-- EN: Safely fetches a localized string, returning the raw key if the translation is missing.
--     Logs a warning if the key is not found to help track missing translations.
-- UA: Безпечно отримує локалізований рядок, повертаючи сирий ключ якщо переклад відсутній.
--     EN: Logs a warning if the key is not found to track missing translations.
--     UA: Логує попередження якщо ключ не знайдено, щоб відстежувати відсутні переклади.
local function getTextSafe(key)
    local text = g_i18n:getText(key)
    if text == nil or text == "" then
        Logging.warning("RHM: Missing translation for key: " .. tostring(key))
        return key
    end
    return text
end

local function assignUniqueIdsAndFocus(element, baseId)
    if not element then return end
    
    element.focusId = FocusManager:serveAutoFocusId()
    
    if element.id then
        -- EN: Completely overwrite the inherited ID to prevent substring conflicts (e.g. Vredo Pack)
        if baseId then
            element.id = baseId .. "_" .. tostring(element.focusId or math.random(1000, 9999))
        else
            element.id = "rhm_" .. tostring(element.focusId or math.random(1000, 9999))
        end
    end
    
    -- Register focus for gamepad/keyboard navigation
    if FocusManager.currentFocusData ~= nil and element.focusId ~= nil then
        if not FocusManager.currentFocusData.idToElementMapping[element.focusId] then
            pcall(function() FocusManager:loadElementFromCustomValues(element, nil, nil, false, false) end)
        end
    end

    if element.elements then
        for i, child in ipairs(element.elements) do
            assignUniqueIdsAndFocus(child, (baseId or "rhm") .. "_" .. tostring(i))
        end
    end
end

-- EN: Clones a UI element safely assigning unique IDs and Focus IDs.
-- UA: Безпечно клонує елемент UI, призначаючи унікальні ID та Focus ID.
local function safeClone(template, uniqueId)
    -- EN: Clone without parent to prevent auto-adding to layout twice
    -- UA: Клонуємо без батьківського елемента, щоб уникнути подвійного додавання
    local cloned = template:clone(nil)
    
    assignUniqueIdsAndFocus(cloned, uniqueId)

    return cloned
end

-- EN: Creates a section header element in the settings layout.
--     Clones the first "sectionHeader" element found in the layout and sets its localized text.
-- UA: Створює елемент заголовку секції в розмітці налаштувань.
--     EN: Clones the first "sectionHeader" element in the layout and sets its localized text.
--     UA: Клонує перший елемент "sectionHeader" в розмітці і встановлює його локалізований текст.
function RHMUIHelper.createSection(page, layout, textId)
    local section = nil
    -- EN: Use the template layout for searching if set (allows sourcing from a different tab)
    local searchLayout = RHMUIHelper._templateLayout or layout
    for _, el in ipairs(searchLayout.elements) do
        if el.name == "sectionHeader" then
            section = safeClone(el, textId .. "_sec")
            section:setText(getTextSafe(textId))
            layout:addElement(section)
            if page and page.controlsList then table.insert(page.controlsList, section) end
            break
        end
    end
    return section
end

-- EN: Creates a descriptive text element (subtitle) in the settings layout.
--     Clones the second child of an existing row, reduces font size and grays out color.
-- UA: Створює текстовий елемент-опис (підзаголовок) в розмітці налаштувань.
--     EN: Clones the second child element of an existing row, reduces font size and grays the color.
--     UA: Клонує другий дочірній елемент існуючого рядка, зменшує розмір шрифту і сірить колір.
function RHMUIHelper.createDescription(page, layout, textId)
    local template = nil
    -- EN: Use the template layout for searching if set (allows sourcing from a different tab)
    local searchLayout = RHMUIHelper._templateLayout or layout
    -- EN: Find a row that has a text-setting child (for cloning).
    -- UA: Знаходимо рядок з дочірнім елементом тексту (для клонування).
    for _, el in ipairs(searchLayout.elements) do
        if el.elements and #el.elements >= 2 then
            local secondChild = el.elements[2]
            if secondChild.setText then
                template = secondChild
                break
            end
        end
    end

    if not template then
        Logging.warning("RHM: Description template not found!")
        return nil
    end

    local desc = safeClone(template, textId .. "_desc")

    if desc.setText then
        desc:setText(getTextSafe(textId))
    end

    -- EN: Apply smaller font size and gray color to distinguish from regular options.
    -- UA: Застосовуємо менший розмір шрифту і сірий колір, щоб відрізнити від звичайних параметрів.
    if desc.textSize then
        desc.textSize = desc.textSize * 0.85
    end

    if desc.textColor then
        desc.textColor = {0.7, 0.7, 0.7, 1}
    end

    layout:addElement(desc)
    if page and page.controlsList then table.insert(page.controlsList, desc) end
    return desc
end

-- EN: Creates a binary (on/off checkbox) settings option in the layout.
--     Clones a vanilla checkbox element, strips its original target/IDs, sets our callback,
--     and properly initializes state and tooltip texts.
--     IMPORTANT: The onClickCallback receives arguments in reverse order: (newState, element).
-- UA: Створює бінарний (вкл/викл чекбокс) параметр у розмітці налаштувань.
--     EN: Clones a vanilla checkbox element, removes original target/IDs, sets our callback,
--     UA: Клонує ванільний елемент чекбоксу, видаляє оригінальний target/IDs, встановлює наш callback,
--     EN: and correctly initializes the state and tooltip texts.
--     UA: і правильно ініціалізує стан та тексти підказок.
--     EN: IMPORTANT: onClickCallback receives arguments in reverse order: (newState, element).
--     UA: ВАЖЛИВО: onClickCallback отримує аргументи у зворотному порядку: (newState, element).
function RHMUIHelper.createBinaryOption(page, layout, id, textId, state, callback)
    local template = nil

    -- EN: Use the template layout for searching if set (allows sourcing from a different tab)
    local searchLayout = RHMUIHelper._templateLayout or layout

    -- EN: Try known-safe vanilla checkbox IDs first to avoid conflicts with other mods.
    -- UA: Спочатку пробуємо відомі безпечні ванільні ID, щоб уникнути конфліктів з іншими модами.
    local safeIds = {"checkUseMiles", "checkRadio", "checkVolumeMaster", "checkHelpIcon"}

    for _, safeId in ipairs(safeIds) do
        for _, el in ipairs(searchLayout.elements) do
            if el.elements and #el.elements >= 2 then
                local firstChild = el.elements[1]
                if firstChild.id and firstChild.id == safeId then
                    template = el
                    break
                end
            end
        end
        if template then break end
    end

    -- EN: Fallback: find any "check*" prefixed element, avoiding known conflicts.
    -- UA: Резервний варіант: знаходимо будь-який елемент з префіксом "check*", уникаючи відомих конфліктів.
    if not template then
        for _, el in ipairs(searchLayout.elements) do
            if el.elements and #el.elements >= 2 then
                local firstChild = el.elements[1]
                if firstChild.id and (
                    string.find(firstChild.id, "^check") or
                    string.find(firstChild.id, "Check")
                ) then
                    if not string.find(firstChild.id, "Currency") then
                        template = el
                        break
                    end
                end
            end
        end
    end

    if not template then
        Logging.warning("RHM: BinaryOption template not found!")
        return nil
    end

    local row = safeClone(template, id .. "_bin")

    local opt = row.elements[1]
    local lbl = row.elements[2]

    -- EN: Clear inherited targets and tooltips from the cloned template.
    -- UA: Очищаємо успадковані targets і підказки з клонованого шаблону.
    opt.target = nil

    if opt.toolTipText then opt.toolTipText = "" end
    if lbl and lbl.toolTipText then lbl.toolTipText = "" end

    -- EN: Hook our callback. newState=1 means unchecked, newState=2 means checked.
    -- UA: Підключаємо наш callback. newState=1 = не відмічено, newState=2 = відмічено.
    opt.onClickCallback = function(newState, element)
        local isChecked = (newState == 2)
        callback(isChecked)
    end

    -- EN: Set the label to the shortened localized text.
    -- UA: Встановлюємо підпис на скорочений локалізований текст.
    if lbl and lbl.setText then
        lbl:setText(getTextSafe(textId .. "_short"))
    end

    -- EN: Override inherited option texts with On/Off labels.
    -- UA: Заміщаємо успадковані тексти варіантів підписами Вкл/Викл.
    if opt.setTexts then
        opt:setTexts({
            g_i18n:getText("ui_off") or "Off",
            g_i18n:getText("ui_on") or "On"
        })
    end

    -- EN: Add to layout FIRST before setting state (required for correct initialization).
    -- UA: Додаємо до розмітки СПОЧАТКУ перед встановленням стану (потрібно для коректної ініціалізації).
    layout:addElement(row)
    if page and page.controlsList then table.insert(page.controlsList, row) end

    -- EN: Reset to unchecked first, then set to the desired state.
    -- UA: Спочатку скидаємо до невідміченого, а потім встановлюємо бажаний стан.
    if opt.setState then
        opt:setState(1)
    end

    if state then
        if opt.setIsChecked then
            opt:setIsChecked(true)
        elseif opt.setState then
            opt:setState(2)
        end
    end

    -- EN: Apply tooltip using all available methods for maximum compatibility.
    --     FS25 doesn't expose a single reliable way to set tooltips on injected elements.
    -- UA: Застосовуємо підказку всіма доступними методами для максимальної сумісності.
    --     EN: FS25 doesn't provide a single reliable way to set tooltips on injected elements.
--     UA: FS25 не надає єдиного надійного способу встановлення підказок на впроваджених елементах.
    local tooltipText = getTextSafe(textId .. "_long")

    if opt.setToolTipText then opt:setToolTipText(tooltipText) end
    if lbl and lbl.setToolTipText then lbl:setToolTipText(tooltipText) end

    opt.toolTipText = tooltipText
    if lbl then lbl.toolTipText = tooltipText end

    if row.setToolTipText then row:setToolTipText(tooltipText) end
    row.toolTipText = tooltipText

    if opt.elements and opt.elements[1] and opt.elements[1].setText then
        opt.elements[1]:setText(tooltipText)
    end

    return opt
end

-- EN: Creates a multi-text (multi-option) settings element (similar to dropdown/slider in game menus).
--     Clones a vanilla "multi*" prefixed element, sets texts, state, callback, and tooltip.
--     The callback receives the selected option index (1-based integer).
-- UA: Створює параметр з кількома варіантами (схожий на список/повзунок у меню гри).
--     EN: Clones a vanilla element with "multi*" prefix, sets texts, state, callback, and tooltip.
--     UA: Клонує ванільний елемент з префіксом "multi*", встановлює тексти, стан, callback і підказку.
--     EN: Callback receives the selected option index (integer starting from 1).
--     UA: Callback отримує індекс вибраного варіанту (ціле число починаючи з 1).
function RHMUIHelper.createMultiOption(page, layout, id, textId, options, state, callback)
    local template = nil

    -- EN: Use the template layout for searching if set (allows sourcing from a different tab)
    local searchLayout = RHMUIHelper._templateLayout or layout

    -- EN: Find any element containing a "multi*" prefixed child element as a template.
    -- UA: Знаходимо будь-який елемент з дочірнім елементом з префіксом "multi*" як шаблон.
    for _, el in ipairs(searchLayout.elements) do
        if el.elements and #el.elements >= 2 then
            local firstChild = el.elements[1]
            if firstChild.id and string.find(firstChild.id, "^multi") then
                template = el
                break
            end
        end
    end

    if not template then
        Logging.warning("RHM: MultiOption template not found!")
        return nil
    end

    local row = safeClone(template, id .. "_multi")

    local opt = row.elements[1]
    local lbl = row.elements[2]

    -- EN: Clear inherited targets and tooltips from the cloned template.
    -- UA: Очищаємо успадковані targets і підказки з клонованого шаблону.
    opt.target = nil

    if opt.toolTipText then opt.toolTipText = "" end
    if lbl and lbl.toolTipText then lbl.toolTipText = "" end

    -- EN: Set the list of option texts and the initial selection.
    -- UA: Встановлюємо список текстів варіантів і початковий вибір.
    if opt.setTexts then
        opt:setTexts(options)
    end

    if opt.setState then
        opt:setState(state)
    end

    -- EN: Hook callback — newState is the 1-based index of the selected option.
    -- UA: Підключаємо callback — newState це 1-базований індекс вибраного варіанту.
    opt.onClickCallback = function(newState, element)
        callback(newState)
    end

    if lbl and lbl.setText then
        lbl:setText(getTextSafe(textId .. "_short"))
    end

    -- EN: Add to layout FIRST before setting tooltip (required pattern in FS25).
    -- UA: Додаємо до розмітки СПОЧАТКУ перед встановленням підказки (обов'язковий порядок у FS25).
    layout:addElement(row)
    if page and page.controlsList then table.insert(page.controlsList, row) end

    -- EN: Apply tooltip using all available methods for maximum compatibility.
    -- UA: Застосовуємо підказку всіма доступними методами для максимальної сумісності.
    local tooltipText = getTextSafe(textId .. "_long")

    if opt.setToolTipText then opt:setToolTipText(tooltipText) end
    if lbl and lbl.setToolTipText then lbl:setToolTipText(tooltipText) end

    opt.toolTipText = tooltipText
    if lbl then lbl.toolTipText = tooltipText end

    if row.setToolTipText then row:setToolTipText(tooltipText) end
    row.toolTipText = tooltipText

    if opt.elements and opt.elements[1] and opt.elements[1].setText then
        opt.elements[1]:setText(tooltipText)
    end

    rhm_log(string.format("RHM [UI]: RHM: Set tooltip for %s: %s", textId, tooltipText))

    return opt
end
