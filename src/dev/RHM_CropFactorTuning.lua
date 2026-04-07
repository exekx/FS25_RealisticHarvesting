--[[
    RHM_CropFactorTuning — DEV-ONLY in-game editor for crop load factors (writes cropFactorTuning.xml).

    REMOVAL (release / cleanup):
    1) Set RHM_CropFactorTuning.ENABLED = false below, OR delete this entire file.
    2) Remove: source(... "src/dev/RHM_CropFactorTuning.lua") and the loadFromDisk() block in loadedMission from main.lua
    3) Remove the block marked "RHM_CropFactorTuning hook" in RHM_LoadCalculator.lua calculateEngineLoad
    4) Remove cropFactorTuneGUI hooks (new/update/draw/mouseEvent/delete) and registerConsoleCommand call from RHM_RealisticHarvestManager.lua

    UA: Інструмент розробника — коефіцієнти культур, XML у modSettings для копіювання в RHM_LoadCalculator.lua
--]]

RHM_CropFactorTuning = RHM_CropFactorTuning or {}

-- EN: Master switch — set false to disable completely (near-zero runtime cost).
-- UA: Головний вимикач — false = повністю вимкнено.
-- EN: Set true while tuning; keep false for release (no runtime override, GUI/command inactive).
-- UA: true під час калібрування; false для релізу.
RHM_CropFactorTuning.ENABLED = false

RHM_CropFactorTuning.XML_ROOT = "cropFactorTuning"

-- EN: Live factor table (absolute values). Initialized from REFERENCE then XML.
-- UA: Поточні значення коефіцієнтів (абсолютні), потім XML.
RHM_CropFactorTuning.values = {}

-- EN: Ordered list: must stay in sync with defaults in RHM_LoadCalculator.lua (factorMap + BY_NAME extras).
--     exampleHp / exampleHeaderM / note — reference only (typical combine class), not used in physics.
-- UA: Приклади к.с./жатки/нотатки — лише довідник для калібрування.
RHM_CropFactorTuning.REFERENCE_CROPS = {
    { name = "WHEAT",       defaultFactor = 0.814, exampleHp = 547, exampleHeaderM = 10.7, note = "Зерно: орієнтир ~5 км/год при RHM (залежить від врожаю)" },
    { name = "BARLEY",      defaultFactor = 0.869, exampleHp = 520, exampleHeaderM = 10.5, note = "Трохи важче пшениці" },
    { name = "OAT",         defaultFactor = 0.680, exampleHp = 507, exampleHeaderM = 10.8, note = "Зерно: часто швидше пшениці в моделі" },
    { name = "RYE",         defaultFactor = 0.814, exampleHp = 540, exampleHeaderM = 10.5, note = "Як пшениця" },
    { name = "SPELT",       defaultFactor = 0.814, exampleHp = 540, exampleHeaderM = 10.5, note = "Як пшениця" },
    { name = "TRITICALE",   defaultFactor = 0.461, exampleHp = 520, exampleHeaderM = 10.5, note = "Легше" },
    { name = "MILLET",      defaultFactor = 0.976, exampleHp = 500, exampleHeaderM = 9.0,  note = "Зерно" },
    { name = "MAIZE",       defaultFactor = 0.572, exampleHp = 625, exampleHeaderM = 12.0, note = "Зернова кукурудза" },
    { name = "CORN",        defaultFactor = 0.650, exampleHp = 625, exampleHeaderM = 12.0, note = "BY_NAME зерно" },
    { name = "MAIZE_FORAGE", defaultFactor = 0.300, exampleHp = 956, exampleHeaderM = 9.0, note = "Силос: силосний комбайн" },
    { name = "MAIZE_SILAGE", defaultFactor = 0.572, exampleHp = 700, exampleHeaderM = 9.0, note = "FillType силос" },
    { name = "SOYBEAN",     defaultFactor = 1.788, exampleHp = 550, exampleHeaderM = 12.0, note = "Важче на молотарці" },
    { name = "SUNFLOWER",   defaultFactor = 2.324, exampleHp = 600, exampleHeaderM = 12.0, note = "Дуже важка для комбайна" },
    { name = "CANOLA",      defaultFactor = 1.738, exampleHp = 540, exampleHeaderM = 10.5, note = "Ріпак" },
    { name = "SORGHUM",     defaultFactor = 0.801, exampleHp = 520, exampleHeaderM = 10.5, note = "Сорго" },
    { name = "RICE",        defaultFactor = 1.303, exampleHp = 480, exampleHeaderM = 8.0,  note = "Рис" },
    { name = "RICE_LONG_GRAIN", defaultFactor = 1.303, exampleHp = 480, exampleHeaderM = 8.0, note = "Рис" },
    { name = "PEA",         defaultFactor = 1.152, exampleHp = 520, exampleHeaderM = 10.5, note = "Бобові" },
    { name = "LENTIL",      defaultFactor = 1.152, exampleHp = 520, exampleHeaderM = 10.5, note = "Бобові" },
    { name = "CHICKPEA",    defaultFactor = 1.152, exampleHp = 520, exampleHeaderM = 10.5, note = "Нут" },
    { name = "GREENBEAN",   defaultFactor = 2.240, exampleHp = 400, exampleHeaderM = 6.0,  note = "Овочі — високе навантаження" },
    { name = "POTATO",      defaultFactor = 0.600, exampleHp = 450, exampleHeaderM = 2.0,  note = "Картопля (кореневий)" },
    { name = "SUGARBEET",   defaultFactor = 0.920, exampleHp = 600, exampleHeaderM = 6.0,  note = "Буряк: орієнтир ~8 км/год клас" },
    { name = "BEETROOT",    defaultFactor = 1.050, exampleHp = 500, exampleHeaderM = 6.0,  note = "Буряк столовий" },
    { name = "CARROT",      defaultFactor = 0.323, exampleHp = 400, exampleHeaderM = 3.0,  note = "Морква" },
    { name = "PARSNIP",     defaultFactor = 0.400, exampleHp = 400, exampleHeaderM = 3.0,  note = "Пастернак" },
    { name = "ONION",       defaultFactor = 0.600, exampleHp = 420, exampleHeaderM = 4.0,  note = "Цибуля" },
    { name = "ONION_DIRTY", defaultFactor = 0.700, exampleHp = 420, exampleHeaderM = 4.0,  note = "Цибуля брудна" },
    { name = "SPINACH",     defaultFactor = 2.880, exampleHp = 350, exampleHeaderM = 6.0,  note = "Шпинат — дуже важко" },
    { name = "GRASS",       defaultFactor = 1.221, exampleHp = 700, exampleHeaderM = 9.0,  note = "factorMap" },
    { name = "DRYGRASS",    defaultFactor = 1.100, exampleHp = 650, exampleHeaderM = 9.0,  note = "Сіно" },
    { name = "ALFALFA",     defaultFactor = 1.100, exampleHp = 650, exampleHeaderM = 9.0,  note = "Люцерна" },
    { name = "CLOVER",      defaultFactor = 1.100, exampleHp = 650, exampleHeaderM = 9.0,  note = "Конюшина" },
    { name = "MEADOW",      defaultFactor = 1.221, exampleHp = 650, exampleHeaderM = 9.0,  note = "Лук" },
    { name = "GRASS_WINDROW", defaultFactor = 0.380, exampleHp = 520, exampleHeaderM = 9.0,  note = "BY_NAME валок" },
    { name = "DRYGRASS_WINDROW", defaultFactor = 0.500, exampleHp = 520, exampleHeaderM = 9.0, note = "Сіно валок" },
    { name = "COTTON",      defaultFactor = 4.782, exampleHp = 600, exampleHeaderM = 12.0, note = "Бавовна — екстремальне навантаження" },
    { name = "SUGARCANE",   defaultFactor = 0.654, exampleHp = 700, exampleHeaderM = 3.0,  note = "Цукрова тростина" },
    { name = "POPLAR",      defaultFactor = 0.156, exampleHp = 500, exampleHeaderM = 4.0,  note = "Тріска / поплар" },
    { name = "OILSEED_RADISH", defaultFactor = 0.391, exampleHp = 500, exampleHeaderM = 10.5, note = "Гірчиця / cover" },
    { name = "GRAPE",       defaultFactor = 0.391, exampleHp = 200, exampleHeaderM = 2.0,  note = "Виноград (інший тип техніки)" },
    { name = "OLIVE",       defaultFactor = 0.391, exampleHp = 200, exampleHeaderM = 2.0,  note = "Оливи" },
    { name = "MINT",        defaultFactor = 1.054, exampleHp = 400, exampleHeaderM = 6.0,  note = "М'ята" },
}

function RHM_CropFactorTuning.isEnabled()
    return RHM_CropFactorTuning.ENABLED == true
end

function RHM_CropFactorTuning.initValuesFromReference()
    RHM_CropFactorTuning.values = {}
    for _, row in ipairs(RHM_CropFactorTuning.REFERENCE_CROPS) do
        RHM_CropFactorTuning.values[row.name] = row.defaultFactor
    end
end

function RHM_CropFactorTuning.getXmlPath()
    local sm = RHMSettingsManager.new()
    local base = sm:getServerXmlFilePath()
    if not base then return nil end
    return base:gsub("settings%.xml$", "cropFactorTuning.xml")
end

function RHM_CropFactorTuning.loadFromDisk()
    if not RHM_CropFactorTuning.isEnabled() then return end
    RHM_CropFactorTuning.initValuesFromReference()
    local path = RHM_CropFactorTuning.getXmlPath()
    if not path or not fileExists(path) then
        return
    end
    local xml = XMLFile.load("RHM_CropFactorTuningLoad", path)
    if not xml then return end
    local root = RHM_CropFactorTuning.XML_ROOT
    local i = 0
    while true do
        local base = string.format("%s.crop(%d)", root, i)
        local name = xml:getString(base .. "#name")
        if name == nil or name == "" then
            break
        end
        local factor = xml:getFloat(base .. "#factor", RHM_CropFactorTuning.values[name] or 0.814)
        RHM_CropFactorTuning.values[name] = factor
        i = i + 1
        if i > 512 then break end
    end
    xml:delete()
    print(string.format("[RHM] Crop factor tuning: loaded %d entries from %s", i, path))
end

function RHM_CropFactorTuning.saveToDisk()
    if not RHM_CropFactorTuning.isEnabled() then return false end
    -- EN: Ensures modSettings/FS25_RealisticHarvesting exists (same as settings.xml).
    RHMSettingsManager.new():getServerXmlFilePath()
    local path = RHM_CropFactorTuning.getXmlPath()
    if not path then return false end
    local root = RHM_CropFactorTuning.XML_ROOT
    local xml = XMLFile.create("RHM_CropFactorTuningSave", path, root)
    if not xml then return false end
    for i, row in ipairs(RHM_CropFactorTuning.REFERENCE_CROPS) do
        local idx = i - 1
        local base = string.format("%s.crop(%d)", root, idx)
        local v = RHM_CropFactorTuning.values[row.name] or row.defaultFactor
        xml:setString(base .. "#name", row.name)
        xml:setFloat(base .. "#factor", v)
    end
    xml:save()
    xml:delete()
    print(string.format("[RHM] Crop factor tuning: saved %s — copy factors into RHM_LoadCalculator.lua factorMap / CROP_FACTORS_BY_NAME", path))
    if g_currentMission then
        g_currentMission:showBlinkingWarning("RHM: cropFactorTuning.xml saved (modSettings)", 3500)
    end
    return true
end

---@param cropName string|nil
---@return number|nil
function RHM_CropFactorTuning.getFactorOverride(cropName)
    if not RHM_CropFactorTuning.isEnabled() or not cropName then return nil end
    return RHM_CropFactorTuning.values[cropName]
end

-- ============================================================================
-- GUI (client)
-- ============================================================================

RHM_CropFactorTuningGui = {}
local CropTuneGui_mt = Class(RHM_CropFactorTuningGui)

function RHM_CropFactorTuningGui.new(modDirectory)
    local self = setmetatable({}, CropTuneGui_mt)
    self.modDirectory = modDirectory
    self.isOpen = false
    self.selectedIndex = 1
    self.refScroll = 0
    self.buttons = {}
    local tex = modDirectory .. "textures/hud_icons.dds"
    self.overlay = Overlay.new(tex, 0, 0, 1, 1)
    if GuiUtils and GuiUtils.getUVs then
        self.overlay:setUVs(GuiUtils.getUVs({388, 4, 56, 56}, {512, 64}))
    end
    return self
end

function RHM_CropFactorTuningGui:delete()
    if self.overlay then
        self.overlay:delete()
        self.overlay = nil
    end
end

function RHM_CropFactorTuningGui:toggle()
    if not RHM_CropFactorTuning.isEnabled() then return end
    self.isOpen = not self.isOpen
    if self.isOpen then
        self:syncSelectionToLiveCrop()
        g_inputBinding:setShowMouseCursor(true)
    else
        local hudOn = g_realisticHarvestManager and g_realisticHarvestManager.isCursorVisible
        g_inputBinding:setShowMouseCursor(hudOn or false)
    end
end

function RHM_CropFactorTuningGui:drawRect(x, y, w, h, color)
    if not self.overlay then return end
    local r, g, b, a = color[1], color[2], color[3], color[4]
    self.overlay:setPosition(x, y)
    self.overlay:setDimension(w, h)
    self.overlay:setColor(r, g, b, a)
    self.overlay:render()
end

function RHM_CropFactorTuningGui:getActiveCombine()
    if not g_realisticHarvestManager then return nil end
    local v = g_realisticHarvestManager:getControlledVehicle()
    if not v then return nil end
    local root = v.rootVehicle or v
    return g_realisticHarvestManager.lastActiveCombine
        or (function()
            local function find(w, seen)
                if not w or seen[w] then return nil end
                seen[w] = true
                if w.spec_rhm_Combine then return w end
                if w.rootVehicle then local r = find(w.rootVehicle, seen) if r then return r end end
                if w.attacherVehicle then local r = find(w.attacherVehicle, seen) if r then return r end end
                if w.getAttachedImplements then
                    for _, im in ipairs(w.getAttachedImplements(w) or {}) do
                        if im.object then local r = find(im.object, seen) if r then return r end end
                    end
                end
                return nil
            end
            return find(root, {})
        end)()
end

function RHM_CropFactorTuningGui:syncSelectionToLiveCrop()
    local veh = self:getActiveCombine()
    if not veh or not veh.spec_rhm_Combine then return end
    local lc = veh.spec_rhm_Combine.loadCalculator and veh.spec_rhm_Combine.loadCalculator.currentCrop
    if not lc then return end
    for i, row in ipairs(RHM_CropFactorTuning.REFERENCE_CROPS) do
        if row.name == lc then
            self.selectedIndex = i
            return
        end
    end
end

function RHM_CropFactorTuningGui:update(dt)
end

local COL_BG = {0, 0, 0, 0.82}
local COL_HDR = {0.223, 0.407, 0.004, 1.0}
local COL_BTN = {0.12, 0.12, 0.12, 0.95}
local COL_BTN_H = {0.25, 0.25, 0.22, 1.0}

function RHM_CropFactorTuningGui:draw()
    if not self.isOpen or not RHM_CropFactorTuning.isEnabled() then return end

    self.buttons = {}
    local mx, my = g_inputBinding:getMousePosition()

    local lx, ly, lw, lh = 0.02, 0.12, 0.40, 0.78
    self:drawRect(lx, ly, lw, lh, COL_BG)
    self:drawRect(lx, ly + lh - 0.035, lw, 0.035, COL_HDR)

    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(lx + 0.01, ly + lh - 0.028, 0.017, "RHM Crop factors (DEV)")
    setTextBold(false)

    local veh = self:getActiveCombine()
    local liveCrop = "—"
    local liveLoad = "—"
    local liveSpeed = "—"
    local liveHp = "—"
    if veh and veh.spec_rhm_Combine and veh.spec_rhm_Combine.loadCalculator then
        local lc = veh.spec_rhm_Combine.loadCalculator
        liveCrop = lc.currentCrop or veh.spec_rhm_Combine.combineMemory and veh.spec_rhm_Combine.combineMemory.currentCrop or "—"
        liveLoad = string.format("%.0f%%", lc:getEngineLoad() or 0)
        liveSpeed = string.format("%.1f km/h", veh:getLastSpeed() or 0)
        if veh.spec_motorized and veh.spec_motorized.motor then
            liveHp = string.format("%.0f hp", veh.spec_motorized.motor.hp or 0)
        end
    end

    local ty = ly + lh - 0.065
    setTextColor(0.9, 0.88, 0.8, 1)
    renderText(lx + 0.01, ty, 0.013, "Live: " .. tostring(liveCrop) .. "  |  Load " .. liveLoad .. "  |  " .. liveSpeed .. "  |  " .. liveHp)
    ty = ty - 0.028
    renderText(lx + 0.01, ty, 0.011, "XML: " .. tostring(RHM_CropFactorTuning.getXmlPath() or "?"))

    local ref = RHM_CropFactorTuning.REFERENCE_CROPS
    local sel = ref[self.selectedIndex]
    if not sel then self.selectedIndex = 1 sel = ref[1] end

    ty = ty - 0.04
    renderText(lx + 0.01, ty, 0.014, "Edit crop:")
    ty = ty - 0.03

    local bw, bh = 0.06, 0.035
    local function regBtn(id, x, y, w, h, label)
        local hov = mx >= x and mx <= x + w and my >= y and my <= y + h
        self.buttons[id] = { x = x, y = y, w = w, h = h }
        self:drawRect(x, y, w, h, hov and COL_BTN_H or COL_BTN)
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(x + w * 0.5, y + h * 0.25, 0.014, label)
        setTextAlignment(RenderText.ALIGN_LEFT)
        return hov
    end

    regBtn("prev", lx + 0.01, ty, bw, bh, "<")
    regBtn("next", lx + 0.01 + bw + 0.01, ty, bw, bh, ">")
    regBtn("live", lx + 0.01 + 2 * (bw + 0.01), ty, 0.10, bh, "Live crop")
    setTextColor(1, 0.85, 0.2, 1)
    renderText(lx + 0.32, ty + 0.01, 0.016, sel.name)
    ty = ty - 0.05

    setTextColor(0.65, 0.72, 0.78, 1)
    renderText(lx + 0.01, ty, 0.010, sel.note or "")
    ty = ty - 0.026
    setTextColor(0.85, 0.85, 0.85, 1)
    renderText(lx + 0.01, ty, 0.012, string.format("Factor (lower=easier): %.3f", RHM_CropFactorTuning.values[sel.name] or sel.defaultFactor))
    ty = ty - 0.042
    regBtn("fm", lx + 0.01, ty, bw, bh, "-0.02")
    regBtn("fp", lx + 0.09, ty, bw, bh, "+0.02")
    regBtn("fsm", lx + 0.17, ty, bw, bh, "-0.005")
    regBtn("fsp", lx + 0.25, ty, bw, bh, "+0.005")
    ty = ty - 0.05
    regBtn("reset", lx + 0.01, ty, 0.14, bh, "Reset row")
    regBtn("save", lx + 0.17, ty, 0.18, bh, "Save XML")
    ty = ty - 0.048
    setTextColor(0.55, 0.75, 1.0, 1)
    renderText(lx + 0.01, ty, 0.010, "Console: rhm_cropTune  |  Copy saved XML into RHM_LoadCalculator.lua when done")

    -- Reference table (right)
    local rx, ry, rw, rh = 0.44, 0.12, 0.54, 0.78
    self:drawRect(rx, ry, rw, rh, COL_BG)
    self:drawRect(rx, ry + rh - 0.030, rw, 0.030, COL_HDR)
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(rx + 0.01, ry + rh - 0.024, 0.014, "Reference (examples — tune in game, not physics)")
    setTextBold(false)

    local rowH = 0.024
    local y0 = ry + rh - 0.058
    local maxVis = math.floor((rh - 0.08) / rowH)
    self.refScroll = math.max(0, math.min(self.refScroll or 0, math.max(0, #ref - maxVis)))

    setTextColor(0.75, 0.75, 0.7, 1)
    renderText(rx + 0.01, y0 + 0.006, 0.011, "Crop   def.f   ~hp  ~m   note")
    local y = y0 - rowH
    for i = self.refScroll + 1, math.min(#ref, self.refScroll + maxVis) do
        local row = ref[i]
        local v = RHM_CropFactorTuning.values[row.name] or row.defaultFactor
        local line = string.format("%s  %.2f  %d  %.1f", row.name, v, row.exampleHp or 0, row.exampleHeaderM or 0)
        if i == self.selectedIndex then setTextColor(1, 0.9, 0.4, 1) else setTextColor(0.9, 0.87, 0.78, 1) end
        renderText(rx + 0.01, y, 0.010, line)
        y = y - rowH * 0.92
    end
    setTextColor(0.6, 0.6, 0.6, 1)
    renderText(rx + 0.01, ry + 0.02, 0.009, "Scroll: buttons")
    regBtn("scrollUp", rx + rw - 0.12, ry + rh - 0.055, 0.05, 0.028, "^")
    regBtn("scrollDn", rx + rw - 0.06, ry + rh - 0.055, 0.05, 0.028, "v")

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function RHM_CropFactorTuningGui:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isOpen or not RHM_CropFactorTuning.isEnabled() then return false end
    for id, b in pairs(self.buttons) do
        if isDown and button == Input.MOUSE_BUTTON_LEFT then
            if posX >= b.x and posX <= b.x + b.w and posY >= b.y and posY <= b.y + b.h then
                local ref = RHM_CropFactorTuning.REFERENCE_CROPS
                local sel = ref[self.selectedIndex]
                if id == "prev" then
                    self.selectedIndex = self.selectedIndex - 1
                    if self.selectedIndex < 1 then self.selectedIndex = #ref end
                elseif id == "next" then
                    self.selectedIndex = self.selectedIndex + 1
                    if self.selectedIndex > #ref then self.selectedIndex = 1 end
                elseif id == "live" then
                    self:syncSelectionToLiveCrop()
                elseif id == "fm" and sel then
                    RHM_CropFactorTuning.values[sel.name] = math.max(0.05, (RHM_CropFactorTuning.values[sel.name] or sel.defaultFactor) - 0.02)
                elseif id == "fp" and sel then
                    RHM_CropFactorTuning.values[sel.name] = math.min(8.0, (RHM_CropFactorTuning.values[sel.name] or sel.defaultFactor) + 0.02)
                elseif id == "fsm" and sel then
                    RHM_CropFactorTuning.values[sel.name] = math.max(0.05, (RHM_CropFactorTuning.values[sel.name] or sel.defaultFactor) - 0.005)
                elseif id == "fsp" and sel then
                    RHM_CropFactorTuning.values[sel.name] = math.min(8.0, (RHM_CropFactorTuning.values[sel.name] or sel.defaultFactor) + 0.005)
                elseif id == "reset" and sel then
                    RHM_CropFactorTuning.values[sel.name] = sel.defaultFactor
                elseif id == "save" then
                    RHM_CropFactorTuning.saveToDisk()
                elseif id == "scrollUp" then
                    self.refScroll = math.max(0, (self.refScroll or 0) - 3)
                elseif id == "scrollDn" then
                    self.refScroll = math.min(math.max(0, #ref - 8), (self.refScroll or 0) + 3)
                end
                return true
            end
        end
    end
    return false
end

RHM_CropFactorTuning._consoleHandler = RHM_CropFactorTuning._consoleHandler or {}

function RHM_CropFactorTuning._consoleHandler:consoleCommandCropTune()
    if not RHM_CropFactorTuning.isEnabled() then return end
    if g_realisticHarvestManager and g_realisticHarvestManager.cropFactorTuneGUI then
        g_realisticHarvestManager.cropFactorTuneGUI:toggle()
    end
end

function RHM_CropFactorTuning.registerConsoleCommand()
    if not RHM_CropFactorTuning.isEnabled() then return end
    addConsoleCommand("rhm_cropTune", "Toggle RHM crop factor tuning overlay (DEV)", "consoleCommandCropTune", RHM_CropFactorTuning._consoleHandler)
end
