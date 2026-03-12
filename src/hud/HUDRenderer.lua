-- EN: Low-level HUD rendering utility. Provides helper functions for drawing
--     text with specific colors, alignment, and font settings, and for measuring
--     text width. Used internally by DraggableHUD and other HUD components.
-- UA: Низькорівнева утиліта відтворення HUD. Надає допоміжні функції для малювання
--     тексту з певними кольорами, вирівнюванням і налаштуваннями шрифту,
--     а також для вимірювання ширини тексту. Використовується DraggableHUD та іншими HUD-компонентами.
HUDRenderer = {}

-- EN: Predefined color constants used throughout HUD rendering.
-- UA: Заздалегідь визначені константи кольорів для рендерингу HUD.
HUDRenderer.COLORS = {
    BACKGROUND = {0, 0, 0, 0.7},      -- EN: Dark semi-transparent background / UA: Темний напівпрозорий фон
    BORDER     = {1, 1, 1, 0.3},      -- EN: Light semi-transparent border / UA: Світла напівпрозора рамка
    TEXT_WHITE  = {1, 1, 1, 1},       -- EN: White text / UA: Білий текст
    TEXT_GREEN  = {0.2, 1, 0.2, 1},   -- EN: Green text (good/optimal status) / UA: Зелений текст (хороший/оптимальний стан)
    TEXT_YELLOW = {1, 1, 0.2, 1},     -- EN: Yellow text (warning) / UA: Жовтий текст (попередження)
    TEXT_RED    = {1, 0.2, 0.2, 1}    -- EN: Red text (critical/overload) / UA: Червоний текст (критичний/перевантаження)
}

-- EN: Size constants for layout calculations (all values in normalized screen coordinates).
-- UA: Константи розмірів для розрахунку розмітки (всі значення в нормалізованих координатах екрану).
HUDRenderer.SIZES = {
    PADDING      = 0.005,  -- EN: Internal padding around content / UA: Внутрішні відступи навколо контенту
    BORDER_WIDTH = 0.002,  -- EN: Border thickness / UA: Товщина рамки
    LINE_HEIGHT  = 0.015   -- EN: Text line height / UA: Висота рядка тексту
}

-- EN: Renders text at the given screen position with the specified color, size, and alignment.
--     Resets text state (color, alignment, bold) to defaults after rendering.
-- UA: Відображає текст у заданій позиції екрану з вказаним кольором, розміром і вирівнюванням.
--     Скидає стан тексту (колір, вирівнювання, жирний) до значень за замовчуванням після відображення.
function HUDRenderer.drawText(text, x, y, size, color, align)
    align = align or "left"

    -- EN: Skip empty text to avoid unnecessary render calls.
    -- UA: Пропускаємо порожній текст, щоб уникнути зайвих викликів рендерингу.
    if not text or text == "" then
        return
    end

    setTextColor(color[1], color[2], color[3], color[4])
    setTextBold(true)
    setTextAlignment(RenderText["ALIGN_" .. string.upper(align)])

    renderText(x, y, size, text)

    -- EN: Reset text rendering state to engine defaults after every draw call.
    -- UA: Скидаємо стан рендерингу тексту до значень рушія після кожного виклику малювання.
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

-- EN: Calculates and returns the rendered width of a text string at the given font size.
--     Temporarily sets bold mode to match the rendering style used in drawText.
-- UA: Розраховує та повертає ширину відображуваного рядка тексту при заданому розмірі шрифту.
--     Тимчасово вмикає жирний шрифт, щоб відповідати стилю відображення в drawText.
function HUDRenderer.getTextWidth(text, size)
    setTextBold(true)
    local width = getTextWidth(size, text)
    setTextBold(false)
    return width
end
