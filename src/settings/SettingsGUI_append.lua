-- EN: Deprecated HUD left/right movement commands. Kept for backward compatibility but do nothing useful
--     because drag-and-drop replaced pixel-based offset commands in a previous refactor.
-- UA: Застарілі команди переміщення HUD ліворуч/праворуч. Збережені для зворотної сумісності але нічого корисного не роблять,
--     оскільки перетягування замінило команди зміщення на основі пікселів у попередньому рефакторингу.

-- EN: Moves HUD 10 pixels to the left by decrementing the saved hudOffsetX.
-- UA: Переміщує HUD на 10 пікселів ліворуч, зменшуючи збережений hudOffsetX.
function SettingsGUI:consoleCommandMoveHUDLeft()
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        local settings = g_realisticHarvestManager.settings
        settings.hudOffsetX = math.max(-200, settings.hudOffsetX - 10)
        settings:save()
        return string.format("HUD Offset X: %d (moved LEFT)", settings.hudOffsetX)
    end
    return "Error: RHM not initialized"
end

-- EN: Moves HUD 10 pixels to the right by incrementing the saved hudOffsetX.
-- UA: Переміщує HUD на 10 пікселів праворуч, збільшуючи збережений hudOffsetX.
function SettingsGUI:consoleCommandMoveHUDRight()
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        local settings = g_realisticHarvestManager.settings
        settings.hudOffsetX = math.min(200, settings.hudOffsetX + 10)
        settings:save()
        return string.format("HUD Offset X: %d (moved RIGHT)", settings.hudOffsetX)
    end
    return "Error: RHM not initialized"
end
