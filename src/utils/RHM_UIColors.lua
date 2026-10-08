-- ============================================================================
-- RHM_UIColors.lua
-- Realistic Harvesting Mod - Unified UI Color Palette Database
-- ============================================================================
-- Technical architecture:
--   Centralized, deterministic color repository matching native GIANTS Engine 10
--   FS25 design system ($preset_fs25_colorMainHighlight, $preset_fs25_colorOrangeDark, etc.).
--   Guarantees vivid, high-contrast, authentic in-game colors across full-screen
--   telematics and analytical dashboards, eliminating muted / washed-out tones.
-- ============================================================================

RHM_UIColors = {}

-- ----------------------------------------------------------------------------
-- 1. BASE COLOR PALETTE (FS25 Vibrant Native Equivalents)
-- ----------------------------------------------------------------------------
-- Vibrant Lime Highlight (matching $preset_fs25_colorMainHighlight / native UI neon)
RHM_UIColors.GREEN = { 0.61, 0.85, 0.15, 1.0 }

-- Bright Vibrant Yellow (Grade B, intermediate warning, active in-progress status)
RHM_UIColors.YELLOW = { 0.95, 0.85, 0.12, 1.0 }

-- Intense Warm Orange (Grade C, elevated loss warning, heavy wear)
RHM_UIColors.ORANGE = { 0.98, 0.52, 0.10, 1.0 }

-- Vivid Alert Red (Grade D/F, critical losses, financial debit, engine overload)
RHM_UIColors.RED = { 0.96, 0.22, 0.20, 1.0 }

-- Crisp Pure White (Primary text, zero-loss baseline, neutral idle metrics)
RHM_UIColors.WHITE = { 1.00, 1.00, 1.00, 1.0 }

-- Muted Gray (Secondary labels, inactive / off states, disabled metrics)
RHM_UIColors.GRAY = { 0.65, 0.68, 0.72, 1.0 }

-- Vivid Cyan (Informational indicators, telemetry accents)
RHM_UIColors.CYAN = { 0.20, 0.75, 0.95, 1.0 }

-- Semantic Aliases
RHM_UIColors.PROFIT   = RHM_UIColors.GREEN
RHM_UIColors.LOSS     = RHM_UIColors.RED
RHM_UIColors.WARN     = RHM_UIColors.ORANGE
RHM_UIColors.NEUTRAL  = RHM_UIColors.WHITE
RHM_UIColors.DIM      = RHM_UIColors.GRAY
RHM_UIColors.ALERT    = RHM_UIColors.RED

-- Grade Aliases
RHM_UIColors.RANK_S = RHM_UIColors.GREEN
RHM_UIColors.RANK_A = RHM_UIColors.GREEN
RHM_UIColors.RANK_B = RHM_UIColors.YELLOW
RHM_UIColors.RANK_C = RHM_UIColors.ORANGE
RHM_UIColors.RANK_D = RHM_UIColors.RED
RHM_UIColors.RANK_F = RHM_UIColors.RED

-- ----------------------------------------------------------------------------
-- 2. HELPER UTILITIES
-- ----------------------------------------------------------------------------

---Apply color to a GuiElement text
function RHM_UIColors.applyTextColor(element, color)
    if element and element.setTextColor and color then
        element:setTextColor(color[1], color[2], color[3], color[4] or 1.0)
    end
end

---Apply color to a GuiElement image / overlay
function RHM_UIColors.applyImageColor(element, color)
    if element and element.setImageColor and color then
        element:setImageColor(nil, color[1], color[2], color[3], color[4] or 1.0)
    end
end

---Get semantic color for crop loss percentage
function RHM_UIColors.getLossColor(lossPct)
    if not lossPct or lossPct <= 0 then
        return RHM_UIColors.WHITE
    elseif lossPct < 1.50 then
        return RHM_UIColors.GREEN
    elseif lossPct < 3.00 then
        return RHM_UIColors.ORANGE
    else
        return RHM_UIColors.RED
    end
end

---Get semantic color for financial net margin or balance
function RHM_UIColors.getMoneyColor(rawMoney)
    if not rawMoney or rawMoney == 0 then
        return RHM_UIColors.WHITE
    elseif rawMoney > 0 then
        return RHM_UIColors.GREEN
    else
        return RHM_UIColors.RED
    end
end

---Get semantic color for efficiency letter grade
function RHM_UIColors.getRankColor(rank)
    local clean = tostring(rank or "A"):gsub("%[", ""):gsub("%]", ""):upper()
    if clean == "S" or clean == "A" then
        return RHM_UIColors.GREEN
    elseif clean == "B" then
        return RHM_UIColors.YELLOW
    elseif clean == "C" then
        return RHM_UIColors.ORANGE
    else
        return RHM_UIColors.RED
    end
end

---Get semantic color for mechanical wear / damage ratio
function RHM_UIColors.getWearColor(damageRatio)
    local dmg = damageRatio or 0
    if dmg <= 0 then
        return RHM_UIColors.WHITE
    elseif dmg < 0.25 then
        return RHM_UIColors.GREEN
    elseif dmg < 0.50 then
        return RHM_UIColors.ORANGE
    else
        return RHM_UIColors.RED
    end
end

---Get semantic color for engine power load ratio
function RHM_UIColors.getLoadColor(loadRatio)
    local l = loadRatio or 0
    if l <= 0 or l < 0.35 then
        return RHM_UIColors.WHITE
    elseif l <= 0.80 then
        return RHM_UIColors.GREEN
    elseif l <= 0.95 then
        return RHM_UIColors.ORANGE
    else
        return RHM_UIColors.RED
    end
end

---Get semantic color for field or operation status code
function RHM_UIColors.getStatusColor(statusCode)
    if not statusCode or statusCode == "" or statusCode == "--" then
        return RHM_UIColors.GRAY
    end
    local code = tostring(statusCode):upper()
    if code == "HARVESTING" or code == "COMPLETED" or code == "DONE" then
        return RHM_UIColors.GREEN
    elseif code == "IN_PROGRESS" or code == "TRANSIT" or code == "IDLE" or code == "OCCUPIED" then
        return RHM_UIColors.YELLOW
    elseif code == "SOLD" or code == "PARKED" or code == "DECOMMISSIONED" then
        return RHM_UIColors.GRAY
    elseif code == "CONTRACT" then
        return RHM_UIColors.CYAN
    else
        return RHM_UIColors.WHITE
    end
end
