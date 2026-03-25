-- EN: Low-level HUD rendering utility. Provides helper functions for drawing
--     text with specific colors, alignment, and font settings, and for measuring
--     text width. Used internally by RHMDraggableHUD and other HUD components.
-- UA: Низькорівнева утиліта відтворення HUD. Надає допоміжні функції для малювання
--     тексту з певними кольорами, вирівнюванням і налаштуваннями шрифту,
--     а також для вимірювання ширини тексту. Використовується RHMDraggableHUD та іншими HUD-компонентами.
RHM_HUDRenderer = {}

-- EN: Predefined color constants — industrial dark theme with amber accents.
--     Dark olive background, warm white text, amber highlights.
-- UA: Заздалегідь визначені константи кольорів — індустріальна темна тема з бурштиновими акцентами.
--     Темно-оливковий фон, тепло-білий текст, бурштинові підсвічування.
RHM_HUDRenderer.COLORS = {
    BACKGROUND      = {0.04, 0.05, 0.03, 0.95},
    HEADER          = {0.09, 0.07, 0.03, 1.00},
    SURFACE         = {1.00, 1.00, 1.00, 0.04},
    STATS_BG        = {0.00, 0.00, 0.00, 0.28},
    BAR_BG          = {1.00, 1.00, 1.00, 0.07},
    BAR_OPTIMAL     = {1.00, 1.00, 1.00, 0.42},
    SECTION_LINE    = {1.00, 1.00, 1.00, 0.08},
    SEPARATOR       = {1.00, 1.00, 1.00, 0.10},
    ACCENT          = {0.83, 0.54, 0.04, 1.00},
    ACCENT_DIM      = {0.83, 0.54, 0.04, 0.14},
    TEXT_WHITE      = {0.91, 0.87, 0.78, 1.00},
    TEXT_DIM        = {0.38, 0.36, 0.32, 1.00},
    TEXT_GREEN      = {0.24, 0.72, 0.47, 1.00},
    TEXT_YELLOW     = {0.91, 0.78, 0.25, 1.00},
    TEXT_RED        = {0.89, 0.29, 0.29, 1.00},
    TEXT_TEAL       = {0.60, 1.00, 0.80, 1.00},
    BTN_DEFAULT     = {0.10, 0.10, 0.08, 1.00},
    BTN_HOVER       = {0.20, 0.20, 0.16, 1.00},
    BTN_PLUS_HOVER  = {0.06, 0.20, 0.10, 1.00},
    BTN_MINUS_HOVER = {0.22, 0.06, 0.06, 1.00},
    BTN_AUTO        = {0.05, 0.18, 0.09, 1.00},
    BTN_RESET       = {0.20, 0.08, 0.03, 1.00},
    BTN_SAVE        = {0.06, 0.12, 0.04, 1.00},
}

RHM_HUDRenderer.SIZES = {
    PADDING      = 0.005,
    BORDER_WIDTH = 0.001,
    LINE_HEIGHT  = 0.015
}

function RHM_HUDRenderer.drawText(text, x, y, size, color, align)
    align = align or "left"
    if not text or text == "" then return end
    setTextColor(color[1], color[2], color[3], color[4])
    setTextBold(true)
    setTextAlignment(RenderText["ALIGN_" .. string.upper(align)])
    renderText(x, y, size, text)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

function RHM_HUDRenderer.getTextWidth(text, size)
    setTextBold(true)
    local width = getTextWidth(size, text)
    setTextBold(false)
    return width
end

