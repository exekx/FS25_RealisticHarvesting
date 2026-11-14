-- EN: Tactile in-cab field terminal for combine harvester calibration (CEBIS / CommandCenter / AFS Pro style).
--     Features:
--       - High-tech rugged tablet chassis with corner allen fasteners and smoked semi-transparent glass.
--       - Dynamic manufacturer styling (Claas CEBIS, John Deere CommandCenter, Case IH AFS Pro, New Holland IntelliView, FendtONE).
--       - 4 Progressive Tiers (Tier 1 Retro Amber, Tier 2 Slate Cyan, Tier 3 Full Telemetry, Tier 4 Opti-Harvest AI Flagship).
--       - Live telemetry dials row (Engine Load %, Speed Efficiency %, Predicted Loss %) with clean automotive gauge dials.
--       - 2 Primary views: [CALIBRATION] (interactive sliders & dials) and [PROFILES] (custom named presets).
--       - Recessed slider tracks with glowing sweet-spot zones, brushed metallic thumbs, physical readout boxes, and status pills.
--       - Fixed-height chassis with permanent 4-button quick action footer: [FACTORY RESET], [LOAD PRESET], [SAVE PROFILE], [AI AUTO-CALIBRATION].
--       - Magnetic docking system matching RHM Draggable HUD: docks below top-right clock bar with glowing green slot placeholder.
-- UA: Тактильний польовий термінал у кабіні для калібрування комбайна (у стилі CEBIS / CommandCenter / AFS Pro).
--     Особливості:
--       - Захищений планшетний корпус із кутовими кріпленнями та димчастим напівпрозорим склом.
--       - Динамічна стилізація під бренди (Claas CEBIS, John Deere CommandCenter, Case IH AFS Pro, New Holland IntelliView, FendtONE).
--       - 4 прогресивних рівня (Тір 1 Ретро-бурштин, Тір 2 Цифровий сталевий, Тір 3 Телеметрія, Тір 4 Флагман Opti-Harvest AI).
--       - Рядок живої телеметрії з симетричними круглими шкалами та цифровими показниками без зайвого шуму.
--       - 2 основні режими: [НАЛАШТУВАННЯ] (інтерактивні повзунки та датчики) і [ПРОФІЛІ] (збережені набори налаштувань).
--       - Поглиблені треки слайдерів зі sweet-spot зонами, металевими бігунками, цифровими блоками та статус-пігулками.
--       - Стабільна фіксована висота корпусу з постійним 4-кнопковим футером швидких дій.
--       - Магнітне прилипання до верхнього правого кута під годинником із пульсуючим силуетом слота.

RHMCombineCalibrationGUI = {}
local CombineCalibrationGUI_mt = Class(RHMCombineCalibrationGUI)

local PARAM_SECTION_MAP = {
    -- GRAIN
    rotor            = "SEPARATION",
    feeder           = "SEPARATION",
    concave          = "SEPARATION",
    upperSieve       = "CLEANING",
    lowerSieve       = "CLEANING",
    fan              = "CLEANING",
    -- FORAGE
    chopLength       = "SEPARATION",
    kernelProcessor  = "SEPARATION",
    blower           = "CLEANING",
    -- ROOT
    shakingIntensity = "SEPARATION",
}

local PARAM_SUBTITLE_KEYS = {
    rotor            = "rhm_ui_sub_rotor_rpm",
    feeder           = "rhm_ui_sub_threshing_clearance",
    concave          = "rhm_ui_sub_threshing_clearance",
    upperSieve       = "rhm_ui_sub_chaffer_opening",
    lowerSieve       = "rhm_ui_sub_shoe_opening",
    fan              = "rhm_ui_sub_fan_airflow",
    chopLength       = "rhm_ui_sub_chop_length",
    kernelProcessor  = "rhm_ui_sub_kernel_processor",
    blower           = "rhm_ui_sub_forage_blower",
    shakingIntensity = "rhm_ui_sub_shaking_intensity",
    targetEngineLoad = "rhm_ui_sub_governor_cruise",
}

local PARAM_SUBTITLES = {
    rotor            = "Rotor RPM Setpoint",
    feeder           = "Feeder House Velocity",
    concave          = "Threshing Clearance mm",
    upperSieve       = "Chaffer Sieve Opening mm",
    lowerSieve       = "Shoe Sieve Opening mm",
    fan              = "Cleaning Airflow RPM",
    chopLength       = "Theoretical Cut Length mm",
    kernelProcessor  = "Cracker Roll Clearance mm",
    blower           = "Accelerator Discharge RPM",
    shakingIntensity = "Web Agitation Frequency %",
    targetEngineLoad = "Governor Cruise Setpoint %",
}

local function getParamSubtitle(machineType, param)
    local key = nil
    local defaultText = nil

    if machineType == "forage" then
        if param == "rotor" then
            key = "rhm_ui_sub_forage_drum"
            defaultText = "Chopping Drum RPM"
        elseif param == "feeder" then
            key = "rhm_ui_sub_forage_feeder"
            defaultText = "Feed Rolls Velocity"
        elseif param == "fan" or param == "blower" then
            key = "rhm_ui_sub_forage_blower"
            defaultText = "Accelerator Discharge RPM"
        end
    elseif machineType == "root" then
        if param == "rotor" then
            key = "rhm_ui_sub_root_roller"
            defaultText = "Cleaning Roller RPM"
        elseif param == "feeder" then
            key = "rhm_ui_sub_root_feeder"
            defaultText = "Intake Web Speed"
        elseif param == "fan" then
            key = "rhm_ui_sub_root_blower"
            defaultText = "Cleaning Blower Velocity"
        end
    end

    if not key then
        key = PARAM_SUBTITLE_KEYS[param]
    end

    if key and g_i18n and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end
    if g_i18n and g_i18n:hasText("rhm_ui_sub_mechanical_calib") then
        return defaultText or PARAM_SUBTITLES[param] or g_i18n:getText("rhm_ui_sub_mechanical_calib")
    end
    return defaultText or PARAM_SUBTITLES[param] or "Mechanical Calibration"
end

local function getParamSection(machineType, param)
    if machineType == "forage" then
        if param == "fan" or param == "blower" then
            return "CLEANING"
        end
        return "SEPARATION"
    elseif machineType == "root" then
        if param == "fan" or param == "rotor" then
            return "CLEANING"
        end
        return "SEPARATION"
    elseif machineType == "grape" or machineType == "olive" then
        if param == "fan" then
            return "CLEANING"
        end
        return "SEPARATION"
    end
    return PARAM_SECTION_MAP[param] or "SEPARATION"
end

local THRESHING_TYPE_LABELS = {
    grain     = { key = "typeDesc_combine",        default = "GRAIN COMBINE" },
    forage    = { key = "rhm_threshing_forage",    default = "FORAGE CHOPPER" },
    root      = { key = "rhm_threshing_root",      default = "ROOT HARVESTER" },
    specialty = { key = "rhm_threshing_specialty", default = "SPECIALTY" },
}

local TABS = {
    { id = 1, key = "CALIBRATION", labelKey = "rhm_ui_page_settings", default = "CALIBRATION" },
    { id = 2, key = "PROFILES",    labelKey = "rhm_ui_page_profiles", default = "PROFILES" },
}

local BRAND_CONFIGS = {
    CLAAS          = { brandTitle = "CLAAS",           terminalName = "CEBIS TOUCH" },
    JOHNDEERE      = { brandTitle = "JOHN DEERE",      terminalName = "COMMANDCENTER 4600" },
    CASEIH         = { brandTitle = "CASE IH",         terminalName = "AFS PRO 1200" },
    NEWHOLLAND     = { brandTitle = "NEW HOLLAND",     terminalName = "INTELLIVIEW IV" },
    FENDT          = { brandTitle = "FENDT",           terminalName = "FENDTONE TERMINAL" },
    MASSEYFERGUSON = { brandTitle = "MASSEY FERGUSON", terminalName = "DATATRONIC 5" },
    DEUTZFAHR      = { brandTitle = "DEUTZ-FAHR",      terminalName = "IMONITOR 3" },
    ROSTSELMASH    = { brandTitle = "ROSTSELMASH",     terminalName = "ADVISER III" },
    ROPA           = { brandTitle = "ROPA",            terminalName = "TOP-TOUCH TERMINAL" },
    GRIMME         = { brandTitle = "GRIMME",          terminalName = "CCI 1200 TERMINAL" },
    HOLMER         = { brandTitle = "HOLMER",          terminalName = "EASYTOUCH TERMINAL" },
    DEFAULT        = { brandTitle = "COMBINE",         terminalName = "FIELD OPERATOR TERMINAL" }
}

local function getCombineBrandConfig(v)
    if not v then return BRAND_CONFIGS.DEFAULT end
    local brandIndex = v.brand or (v.getBrand and v:getBrand())
    local brandName = nil
    if brandIndex and g_brandManager and g_brandManager.getBrandByIndex then
        local b = g_brandManager:getBrandByIndex(brandIndex)
        brandName = b and (b.name or b.title)
    end
    if not brandName and v.getFullName then
        brandName = v:getFullName()
    elseif not brandName and v.getName then
        brandName = v:getName()
    end
    local upper = string.upper(brandName or "")
    if string.find(upper, "CLAAS") then return BRAND_CONFIGS.CLAAS end
    if string.find(upper, "DEERE") then return BRAND_CONFIGS.JOHNDEERE end
    if string.find(upper, "CASE") then return BRAND_CONFIGS.CASEIH end
    if string.find(upper, "NEW HOLLAND") or string.find(upper, "NEWHOLLAND") then return BRAND_CONFIGS.NEWHOLLAND end
    if string.find(upper, "FENDT") then return BRAND_CONFIGS.FENDT end
    if string.find(upper, "MASSEY") or string.find(upper, "FERGUSON") then return BRAND_CONFIGS.MASSEYFERGUSON end
    if string.find(upper, "DEUTZ") then return BRAND_CONFIGS.DEUTZFAHR end
    if string.find(upper, "ROSTSEL") then return BRAND_CONFIGS.ROSTSELMASH end
    if string.find(upper, "ROPA") then return BRAND_CONFIGS.ROPA end
    if string.find(upper, "GRIMME") then return BRAND_CONFIGS.GRIMME end
    if string.find(upper, "HOLMER") then return BRAND_CONFIGS.HOLMER end
    return BRAND_CONFIGS.DEFAULT
end

-- EN: Centralized Design System & Layout Configuration (colors, opacities, dimensions, and paddings).
-- UA: Централізована система дизайну та конфігурації макета (кольори, прозорість, розміри та відступи).
local UI_CONFIG = {
    -- 1. Color Palette & Opacities (Figma 5-Color System: #020202, #222222, #86B500, #D9D9D9, #FFFFFF)
    colors = {
        -- Base Chassis & Screen Panels
        chassisBg        = { 0.0160, 0.0160, 0.0160, 1.00 }, -- Exact sRGB #222222 (100% Solid Opaque Chassis, blocks 3D world)
        screenBg         = { 0.0097, 0.0097, 0.0097, 1.00 }, -- Exact sRGB #191919 (100% Solid Opaque Screen Display)
        screenBorder     = nil,                               -- Clean contour without unwanted outer glow

        -- Highlight Accent (#86B500 Lime Green)
        accent           = { 0.525, 0.710, 0.000, 1.00 },    -- Vibrant sRGB #86B500 Primary highlight lime green
        accentDarkText   = { 0.050, 0.070, 0.050, 1.00 },    -- Contrast dark text on lime/light surfaces (#0D120D)

        -- Horizontal Navigation Tabs (SETTINGS vs PROFILES)
        tabActiveBg      = { 0.525, 0.710, 0.000, 1.00 },    -- Vibrant #86B500 Solid Lime for Active Tab
        tabActiveBrd     = { 0.525, 0.710, 0.000, 1.00 },    -- #86B500 Border
        tabActiveText    = { 0.050, 0.070, 0.050, 1.00 },    -- Bold Dark Text for Active Tab (#0D120D)
        tabInactiveBg    = { 0.0001, 0.0001, 0.0001, 0.30 }, -- Linear rgba(2, 2, 2, 0.30)
        tabInactiveBrd   = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border
        tabInactiveText  = { 0.851, 0.851, 0.851, 1.00 },    -- #D9D9D9 Light Grey Inactive Text

        -- Telemetry Cards (3x Live Gauges: Engine Load %, Speed Efficiency %, Predicted Loss %)
        cardBg           = { 0.0001, 0.0001, 0.0001, 0.30 }, -- Linear rgba(2, 2, 2, 0.30)
        cardBorder       = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border
        cardTitleText    = { 0.650, 0.680, 0.720, 1.00 },    -- Muted Grey Card Title

        -- Parameter Rows & Sliders
        trackGroove      = { 0.0001, 0.0001, 0.0001, 0.30 }, -- Recessed Groove: Linear rgba(2, 2, 2, 0.30)
        trackBorder      = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border
        trackFill        = { 0.525, 0.710, 0.000, 1.00 },    -- #86B500 Solid Lime Fill
        thumbBg          = { 0.851, 0.851, 0.851, 1.00 },    -- #D9D9D9 Metallic Thumb Handle
        thumbBorder      = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border
        thumbGrip        = { 0.050, 0.070, 0.050, 0.85 },    -- Dark Ticks on Thumb
        btnStepBg        = { 0.0001, 0.0001, 0.0001, 0.30 }, -- Micro-Step [-] / [+] Button
        btnStepBorder    = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border
        btnStepText      = { 0.851, 0.851, 0.851, 1.00 },    -- #D9D9D9 Step Symbols

        -- Status Pills (79 x 21 px: OPTIMAL, LOW, HIGH)
        statusOptimalBg  = { 0.008, 0.016, 0.008, 0.85 },    -- Dark Greenish Card
        statusOptimalBrd = { 0.525, 0.710, 0.000, 1.00 },    -- #86B500 Lime Border
        statusOptimalTxt = { 0.525, 0.710, 0.000, 1.00 },    -- #86B500 Lime Text
        statusWarningBg  = { 0.025, 0.016, 0.005, 0.85 },    -- Dark Amber Card
        statusWarningBrd = { 0.900, 0.640, 0.100, 1.00 },    -- #E6A219 Amber Border
        statusWarningTxt = { 0.900, 0.640, 0.100, 1.00 },    -- #E6A219 Amber Text
        statusAlertBg    = { 0.030, 0.008, 0.008, 0.85 },    -- Dark Red Card
        statusAlertBrd   = { 0.850, 0.220, 0.220, 1.00 },    -- #D93838 Red Border
        statusAlertTxt   = { 0.850, 0.220, 0.220, 1.00 },    -- #D93838 Red Text

        -- Physical Readout Value Boxes (110 x 21 px)
        pillValueBg      = { 0.851, 0.851, 0.851, 1.00 },    -- #D9D9D9 Solid Light Grey
        pillValueBorder  = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border
        pillValueText    = { 0.050, 0.070, 0.050, 1.00 },    -- Bold Dark Text (#0D120D)

        -- Top Header Elements
        cropSelectorBg   = { 0.0001, 0.0001, 0.0001, 0.30 }, -- Linear rgba(2, 2, 2, 0.30)
        cropSelectorBrd  = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border
        cropSelectorText = { 1.000, 1.000, 1.000, 1.00 },    -- Crisp Pure White Text (#FFFFFF)
        tierBadgeBg      = { 0.008, 0.016, 0.008, 0.85 },    -- Dark Forest Green
        tierBadgeBrd     = { 0.525, 0.710, 0.000, 1.00 },    -- #86B500 Lime Border
        tierBadgeText    = { 0.525, 0.710, 0.000, 1.00 },    -- #86B500 Lime Text
        infoPillBg       = { 0.0001, 0.0001, 0.0001, 0.30 }, -- Linear rgba(2, 2, 2, 0.30)
        infoPillBorder   = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border
        btnCloseBg       = { 0.600, 0.150, 0.150, 0.95 },    -- Crimson Red (#992626)
        btnCloseBorder   = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border

        -- Footer Action Buttons
        btnActionBg      = { 0.0001, 0.0001, 0.0001, 0.30 }, -- Linear rgba(2, 2, 2, 0.30)
        btnActionBorder  = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 2px Solid Border
        btnActionText    = { 0.851, 0.851, 0.851, 1.00 },    -- #D9D9D9
        btnResetBg       = { 0.180, 0.060, 0.060, 0.92 },    -- Dark Crimson #2E0F0F
        btnResetBorder   = { 0.400, 0.130, 0.130, 0.80 },    -- Muted Red #662222
        btnResetText     = { 0.890, 0.690, 0.690, 1.00 },    -- Soft Red #E3B0B0
        btnDeleteBg      = { 0.180, 0.060, 0.060, 0.92 },
        btnDeleteBorder  = { 0.400, 0.130, 0.130, 0.80 },
        btnDeleteText    = { 0.890, 0.690, 0.690, 1.00 },

        -- Section Dividers & General
        categoryNotch    = { 0.525, 0.710, 0.000, 1.00 },    -- #86B500 Lime Vertical Notch
        categoryNotchBrd = { 0.133, 0.133, 0.133, 1.00 },    -- #222222 Notch Contour
        dividerLine      = { 1.000, 1.000, 1.000, 0.15 },    -- Soft White Divider Line
        textWhite        = { 1.000, 1.000, 1.000, 1.00 },    -- Pure White (#FFFFFF)
        textDim          = { 0.650, 0.680, 0.720, 1.00 },    -- Secondary Dim Grey
    },

    -- 2. Dimensions & Spacings (Figma 802 x 573 Reference Scale)
    layout = {
        artboardW        = 802,
        artboardH        = 573,
        chassisRadius    = 10,
        screenRadius     = 10,
        bezelPad         = 10,

        -- Header (H = 21, Top = 20)
        headerY          = 20,
        headerH          = 21,
        cropPrevX        = 191,
        cropPrevW        = 25,
        cropMidX         = 217,
        cropMidW         = 117,
        cropNextX        = 336,
        cropNextW        = 25,
        moistureX        = 368,
        moistureW        = 90,
        engineHpX        = 464,
        engineHpW        = 84,
        cutterWidthX     = 552,
        cutterWidthW     = 75,
        tierBadgeX       = 633,
        tierBadgeW       = 106,
        closeBtnX        = 746,
        closeBtnW        = 37,

        -- Tabs (Y = 54, H = 28, W = 171)
        tabY             = 54,
        tabH             = 28,
        tabW             = 171,
        tabGap           = 10,

        -- Telemetry Cards (Y = 84, H = 52, W = 251)
        cardY            = 84,
        cardH            = 52,
        card1X           = 19,
        card2X           = 275,
        card3X           = 531,
        cardW            = 251,

        -- Category Sections & Dividers
        notchW           = 8,
        notchH           = 16,
        notchRadius      = 4,
        dividerX         = 25,
        dividerW         = 753,
        dividerH         = 2,
        sec1NotchY       = 138,
        sec1LineY        = 154,
        sec2NotchY       = 237,
        sec2LineY        = 253,
        sec3NotchY       = 378,
        sec3LineY        = 394,
        categoryGap      = 31,

        -- Parameter Rows
        rowPitch         = 41,

        -- Row Controls
        btnMinusX        = 224,
        btnStepW         = 33,
        btnStepH         = 21,
        trackX           = 260,
        trackH           = 10,
        trackStdW        = 278,
        trackWideW       = 361,
        thumbW           = 15,
        thumbH           = 20,
        btnPlusStdX      = 541,
        btnPlusWideX     = 624,
        statusPillX      = 582,
        statusPillW      = 79,
        statusPillH      = 21,
        valueBoxX        = 668,
        valueBoxW        = 110,
        valueBoxH        = 21,

        -- Footer (Y = 517, H = 34)
        footerY          = 517,
        footerH          = 34,
        footerBtn1X      = 19,
        footerBtn1W      = 184,
        footerBtn2X      = 209,
        footerBtn2W      = 184,
        footerBtn3X      = 399,
        footerBtn3W      = 184,
        footerBtn4X      = 594,
        footerBtn4W      = 188,
        footerLoadX      = 403,
        footerLoadW      = 380,
    }
}

function UI_CONFIG.applyNativePalette()
    local function parseNativeColor(val, fallback)
        if type(val) == "table" then
            if val[1] ~= nil and type(val[1]) == "number" then
                return { val[1], val[2] or val[1], val[3] or val[1], val[4] or 1.0 }
            elseif val.r ~= nil then
                return { val.r, val.g, val.b, val.a or 1.0 }
            end
        elseif type(val) == "string" then
            local p = {}
            for n in string.gmatch(val, "%S+") do
                local num = tonumber(n)
                if num then
                    table.insert(p, num)
                end
            end
            if #p == 3 then
                return { p[1], p[2], p[3], 1.0 }
            elseif #p >= 4 then
                return { p[1], p[2], p[3], p[4] }
            end
        end
        return fallback
    end

    local rawGreen   = (HUD and HUD.COLOR and HUD.COLOR.ACTIVE)
    local rawRed     = (WarningDisplay and (WarningDisplay.ALERT_RED or (WarningDisplay.COLOR and WarningDisplay.COLOR.ALERT_RED)))
    local rawYellow  = (HUD and HUD.COLOR and HUD.COLOR.AVAILABLE)
    local rawOrange  = (SpeedMeterDisplay and (SpeedMeterDisplay.CRITICAL_RED or (SpeedMeterDisplay.COLOR and SpeedMeterDisplay.COLOR.CRITICAL_RED)))
    local rawWhite   = (HUD and HUD.COLOR and HUD.COLOR.DEFAULT)
    local rawLightBg = (g_gui and g_gui.presets and (g_gui.presets["fs25_colorGrey"] or g_gui.presets["colorGrey"]))
    local rawDarkBg  = (HUD and HUD.COLOR and HUD.COLOR.FRAME_BACKGROUND)
    local rawBlue    = (SpeedMeterDisplay and (SpeedMeterDisplay.DEF_BLUE or (SpeedMeterDisplay.COLOR and SpeedMeterDisplay.COLOR.DEF_BLUE)))
    local rawGray    = (g_gui and g_gui.presets and (g_gui.presets["colorDescription"] or g_gui.presets["fs25_colorDescription"])) or (HUD and HUD.COLOR and HUD.COLOR.INACTIVE)

    local green   = parseNativeColor(rawGreen,   {0.24, 0.46, 0.00, 1.00})
    local red     = parseNativeColor(rawRed,     {0.7796, 0.0578, 0.0612, 1.00})
    local yellow  = parseNativeColor(rawYellow,  {1.00, 0.43, 0.00, 1.00})
    local orange  = parseNativeColor(rawOrange,  {1.00, 0.12, 0.00, 1.00})
    local white   = parseNativeColor(rawWhite,   {1.00, 1.00, 1.00, 1.00})
    local lightBg = parseNativeColor(rawLightBg, {0.0160, 0.0160, 0.0160, 1.00})
    local darkBg  = parseNativeColor(rawDarkBg,  {0.0097, 0.0097, 0.0097, 1.00})
    local blue    = parseNativeColor(rawBlue,    {0.01, 0.43, 0.64, 1.00})
    local gray    = parseNativeColor(rawGray,    {0.40, 0.49, 0.51, 1.00})

    local c = UI_CONFIG.colors
    c.chassisBg        = { 0.0160, 0.0160, 0.0160, 1.00 }
    c.screenBg         = { 0.0097, 0.0097, 0.0097, 1.00 }
    c.accent           = green
    c.tabActiveBg      = green
    c.tabActiveBrd     = green
    c.tabActiveText    = { 0.05, 0.07, 0.05, 1.00 }
    c.tabInactiveBg    = { darkBg[1], darkBg[2], darkBg[3], 0.30 }
    c.tabInactiveBrd   = lightBg
    c.tabInactiveText  = white

    c.cardBg           = { darkBg[1], darkBg[2], darkBg[3], 0.30 }
    c.cardBorder       = lightBg
    c.cardTitleText    = gray

    c.trackGroove      = { darkBg[1], darkBg[2], darkBg[3], 0.30 }
    c.trackBorder      = lightBg
    c.trackFill        = green
    c.thumbBg          = white
    c.thumbBorder      = lightBg
    c.thumbGrip        = gray

    c.btnStepBg        = { darkBg[1], darkBg[2], darkBg[3], 0.30 }
    c.btnStepBorder    = lightBg
    c.btnStepText      = white

    c.statusOptimalBg  = { green[1] * 0.15, green[2] * 0.15, green[3] * 0.15, 0.85 }
    c.statusOptimalBrd = green
    c.statusOptimalTxt = green

    c.statusWarningBg  = { yellow[1] * 0.15, yellow[2] * 0.15, yellow[3] * 0.15, 0.85 }
    c.statusWarningBrd = yellow
    c.statusWarningTxt = yellow

    c.statusAlertBg    = { red[1] * 0.15, red[2] * 0.15, red[3] * 0.15, 0.85 }
    c.statusAlertBrd   = red
    c.statusAlertTxt   = red

    c.pillValueBg      = white
    c.pillValueBorder  = lightBg
    c.pillValueText    = { 0.05, 0.07, 0.05, 1.00 }

    c.cropSelectorBg   = { darkBg[1], darkBg[2], darkBg[3], 0.30 }
    c.cropSelectorBrd  = lightBg
    c.cropSelectorText = white

    c.tierBadgeBg      = { green[1] * 0.15, green[2] * 0.15, green[3] * 0.15, 0.85 }
    c.tierBadgeBrd     = green
    c.tierBadgeText    = green

    c.infoPillBg       = { darkBg[1], darkBg[2], darkBg[3], 0.30 }
    c.infoPillBorder   = lightBg
    c.infoPillBlue     = blue

    c.btnCloseBg       = red
    c.btnCloseBorder   = lightBg

    c.btnActionBg      = { darkBg[1], darkBg[2], darkBg[3], 0.30 }
    c.btnActionBorder  = lightBg
    c.btnActionText    = white

    c.btnResetBg       = { red[1] * 0.25, red[2] * 0.08, red[3] * 0.08, 0.90 }
    c.btnResetBorder   = { red[1] * 0.50, red[2] * 0.15, red[3] * 0.15, 0.80 }
    c.btnResetText     = white

    c.btnDeleteBg      = { red[1] * 0.25, red[2] * 0.08, red[3] * 0.08, 0.90 }
    c.btnDeleteBorder  = { red[1] * 0.50, red[2] * 0.15, red[3] * 0.15, 0.80 }
    c.btnDeleteText    = white

    c.categoryNotch    = green
    c.categoryNotchBrd = lightBg
    c.dividerLine      = { white[1], white[2], white[3], 0.15 }
    c.textWhite        = white
    c.textDim          = gray

    -- Direct Native Color Bindings
    c.activeGreen      = green
    c.alertRed         = red
    c.availableYellow  = yellow
    c.criticalOrange   = orange
    c.defaultWhite     = white
    c.presetGrey       = lightBg
    c.frameDark        = darkBg
    c.defBlue          = blue
    c.inactiveGray     = gray

    if FIGMA_PALETTE then
        FIGMA_PALETTE.CHASSIS   = c.chassisBg
        FIGMA_PALETTE.GLASS     = c.screenBg
        FIGMA_PALETTE.ACCENT    = c.accent
        FIGMA_PALETTE.LIGHT     = c.thumbBg
        FIGMA_PALETTE.WHITE     = c.textWhite
        FIGMA_PALETTE.BORDER    = c.cardBorder
        FIGMA_PALETTE.TEXT_DIM  = c.textDim
        FIGMA_PALETTE.DARK_TEXT = c.accentDarkText
    end
end

local function resolveColorRGBA(color, defAlpha)
    if not color then return 1.0, 1.0, 1.0, defAlpha or 1.0 end
    if type(color) == "table" then
        return color[1] or 0.0, color[2] or 0.0, color[3] or 0.0, color[4] or defAlpha or 1.0
    elseif type(color) == "string" then
        if color:sub(1, 1) == "#" and (#color == 7 or #color == 9) then
            local r = tonumber(color:sub(2, 3), 16) or 255
            local g = tonumber(color:sub(4, 5), 16) or 255
            local b = tonumber(color:sub(6, 7), 16) or 255
            local a = (#color == 9) and (tonumber(color:sub(8, 9), 16) or 255) / 255 or (defAlpha or 1.0)
            return r / 255, g / 255, b / 255, a
        end
        local p = {}
        for n in string.gmatch(color, "%S+") do
            table.insert(p, tonumber(n) or 0.0)
        end
        if #p >= 3 then
            return p[1] or 0.0, p[2] or 0.0, p[3] or 0.0, p[4] or defAlpha or 1.0
        end
    end
    return 1.0, 1.0, 1.0, defAlpha or 1.0
end

local function safeSetTextColor(color, defAlpha)
    local r, g, b, a = resolveColorRGBA(color, defAlpha or 1.0)
    setTextColor(r, g, b, a)
end

local FIGMA_PALETTE = {
    CHASSIS   = UI_CONFIG.colors.chassisBg,
    GLASS     = UI_CONFIG.colors.screenBg,
    ACCENT    = UI_CONFIG.colors.accent,
    LIGHT     = UI_CONFIG.colors.thumbBg,
    WHITE     = UI_CONFIG.colors.textWhite,
    BORDER    = UI_CONFIG.colors.cardBorder,
    TEXT_DIM  = UI_CONFIG.colors.textDim,
    DARK_TEXT = UI_CONFIG.colors.accentDarkText,
}

local TIER_THEMES = {
    [1] = {
        name         = "tier1_mechanical",
        bg           = UI_CONFIG.colors.screenBg,
        chassis      = UI_CONFIG.colors.chassisBg,
        outerBorder  = nil,
        accent       = UI_CONFIG.colors.accent,
        accentGlow   = {0.525, 0.710, 0.000, 0.35},
        text         = UI_CONFIG.colors.textWhite,
        textDim      = UI_CONFIG.colors.textDim,
        cardBg       = UI_CONFIG.colors.cardBg,
        cardBorder   = UI_CONFIG.colors.cardBorder,
        trackGroove  = UI_CONFIG.colors.trackGroove,
        trackFill    = UI_CONFIG.colors.trackFill,
        trackThumb   = UI_CONFIG.colors.thumbBg,
        hasSweetSpot = false,
        hasLiveCards = false,
        hasAiAuto    = false,
        badgeKey     = "rhm_ui_tier1_manual",
        defaultBadge = "TIER 1 - MECHANICAL",
    },
    [2] = {
        name         = "tier2_sensors",
        bg           = UI_CONFIG.colors.screenBg,
        chassis      = UI_CONFIG.colors.chassisBg,
        outerBorder  = nil,
        accent       = UI_CONFIG.colors.accent,
        accentGlow   = {0.525, 0.710, 0.000, 0.35},
        text         = UI_CONFIG.colors.textWhite,
        textDim      = UI_CONFIG.colors.textDim,
        cardBg       = UI_CONFIG.colors.cardBg,
        cardBorder   = UI_CONFIG.colors.cardBorder,
        trackGroove  = UI_CONFIG.colors.trackGroove,
        trackFill    = UI_CONFIG.colors.trackFill,
        trackThumb   = UI_CONFIG.colors.thumbBg,
        hasSweetSpot = true,
        hasLiveCards = false,
        hasAiAuto    = false,
        badgeKey     = "rhm_ui_tier2_sensors",
        defaultBadge = "TIER 2 - SENSORS",
    },
    [3] = {
        name         = "tier3_telemetry",
        bg           = UI_CONFIG.colors.screenBg,
        chassis      = UI_CONFIG.colors.chassisBg,
        outerBorder  = nil,
        accent       = UI_CONFIG.colors.accent,
        accentGlow   = {0.525, 0.710, 0.000, 0.35},
        text         = UI_CONFIG.colors.textWhite,
        textDim      = UI_CONFIG.colors.textDim,
        cardBg       = UI_CONFIG.colors.cardBg,
        cardBorder   = UI_CONFIG.colors.cardBorder,
        trackGroove  = UI_CONFIG.colors.trackGroove,
        trackFill    = UI_CONFIG.colors.trackFill,
        trackThumb   = UI_CONFIG.colors.thumbBg,
        hasSweetSpot = true,
        hasLiveCards = true,
        hasAiAuto    = false,
        badgeKey     = "rhm_ui_tier3_monitor",
        defaultBadge = "TIER 3 - TELEMETRY",
    },
    [4] = {
        name         = "tier4_ai_opti",
        bg           = UI_CONFIG.colors.screenBg,
        chassis      = UI_CONFIG.colors.chassisBg,
        outerBorder  = nil,
        accent       = UI_CONFIG.colors.accent,
        accentGlow   = {0.525, 0.710, 0.000, 0.35},
        text         = UI_CONFIG.colors.textWhite,
        textDim      = UI_CONFIG.colors.textDim,
        cardBg       = UI_CONFIG.colors.cardBg,
        cardBorder   = UI_CONFIG.colors.cardBorder,
        trackGroove  = UI_CONFIG.colors.trackGroove,
        trackFill    = UI_CONFIG.colors.trackFill,
        trackThumb   = UI_CONFIG.colors.thumbBg,
        hasSweetSpot = true,
        hasLiveCards = true,
        hasAiAuto    = true,
        badgeKey     = "rhm_ui_tier4_opti",
        defaultBadge = "TIER 4 - AI OPTI",
    }
}

local function getEffectiveTheme(packageLevel, vehicle)
    local level = math.min(4, math.max(1, packageLevel or 1))
    local baseTheme = TIER_THEMES[level] or TIER_THEMES[3]
    local brandCfg = getCombineBrandConfig(vehicle)

    local theme = {}
    for k, v in pairs(baseTheme) do theme[k] = v end

    theme.brandCfg = brandCfg
    theme.terminalName = brandCfg.terminalName or "FIELD OPERATOR TERMINAL"

    if not theme.badgeLabel or theme._lastLang ~= (g_i18n and g_i18n.currentLanguage) then
        theme.badgeLabel = (g_i18n and g_i18n:hasText(theme.badgeKey)) and g_i18n:getText(theme.badgeKey) or theme.defaultBadge
        theme._lastLang = g_i18n and g_i18n.currentLanguage
    end

    return theme
end

local function getVehicleRoot(v)
    if not v then return nil end
    return (v.getRootVehicle and v:getRootVehicle()) or v.rootVehicle or v
end

local function renderPanelSlice(overlay, sx, sy, sw, sh, uvs)
    if sw <= 0 or sh <= 0 or not uvs then return end
    overlay:setPosition(sx, sy)
    overlay:setDimension(sw, sh)
    overlay:setUVs(uvs)
    overlay:render()
end

function RHMCombineCalibrationGUI.new(modDirectory)
    local self = setmetatable({}, CombineCalibrationGUI_mt)
    self.modDirectory = modDirectory
    self.isOpen = false
    self.isCursorActive = false

    -- Active category tab (1 = ALL, 2 = THRESHING, 3 = CLEANING, 4 = POWER, 5 = PROFILES)
    self.activeTab = 1

    -- In-cab rugged tactile field terminal layout (Fixed 0.424 width x 0.525 height)
    self.ui = {
        x = 0.56, y = 0.35,
        w = 0.424, h = 0.525,
        margin       = 0.008,
        headerHeight = 0.040,
        tabHeight    = 0.024,
        statsHeight  = 0.046,
        lineHeight   = 0.038,
        sectionGap   = 0.016,
        fontSize     = 0.0125,
        titleSize    = 0.0145,
        sectionSize  = 0.0115,
        statusSize   = 0.0095,
        buttonW      = 0.017,
        buttonH      = 0.017,
        bezelSide    = 0.0055,
        bezelBottom  = 0.0065,
        bezelTop     = 0.0065,
    }

    self.activeVehicle = nil
    self.hoveredElement = nil
    self.mouseX = 0
    self.mouseY = 0
    self.hoveredParameter = nil
    self.draggingSlider = nil
    self.draggingSliderRatio = nil

    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}

    self.lastScrollTimeStamp = 0
    self.scrollDelayMs = 100

    self.buttons = {}
    self.sliders = {}

    -- Dragging & Magnetic Snapping System
    self.isDraggingTablet = false
    self.dragOffsetTabletX = 0
    self.dragOffsetTabletY = 0
    self.hasCustomPosition = false
    self.isNearDock = false

    -- Live Rolling Telemetry History (8 samples for authentic curves)
    self.telemetryHistory = {
        load           = {0.15, 0.25, 0.40, 0.60, 0.72, 0.80, 0.84, 0.88},
        eff            = {0.92, 0.94, 0.95, 0.96, 0.97, 0.98, 0.98, 0.99},
        loss           = {0.05, 0.04, 0.03, 0.02, 0.02, 0.01, 0.01, 0.00},
        lastSampleTime = 0,
    }

    -- Pixel overlay for pure solid rendering (identical to native engine graph_pixel.dds)
    self.overlay = Overlay.new("dataS/menu/base/graph_pixel.dds", 0, 0, 1, 1)
    self.overlay:setUVs({0, 0, 0, 1, 1, 0, 1, 1})

    local panelTexturePath = Utils.getFilename("textures/rhm_atlas.dds", self.modDirectory)
    self.roundedOverlay = Overlay.new(panelTexturePath, 0, 0, 1, 1)

    local pxUVs = {
        topLeft     = {  0, 384,  5,  5 },
        top         = {  5, 384, 54,  5 },
        topRight    = { 59, 384,  5,  5 },
        left        = {  0, 389,  5, 54 },
        center      = {  5, 389, 54, 54 },
        right       = { 59, 389,  5, 54 },
        bottomLeft  = {  0, 443,  5,  5 },
        bottom      = {  5, 443, 54,  5 },
        bottomRight = { 59, 443,  5,  5 }
    }
    self.roundedUVs = {}
    for key, coords in pairs(pxUVs) do
        self.roundedUVs[key] = GuiUtils.getUVs(coords, {1024, 1024})
    end

    -- Icon Atlas Overlays (from rhm_atlas.dds)
    self.iconOverlay = Overlay.new(panelTexturePath, 0, 0, 1, 1)
    local iconDefs = {
        load      = {0,   256, 64, 64},
        speed     = {320, 256, 64, 64},
        loss      = {256, 256, 64, 64},
        moisture  = {192, 256, 64, 64},
        yield     = {64,  256, 64, 64},
        reset     = {576, 320, 64, 64},
        combine   = {704, 320, 64, 64},
    }
    self.iconUVs = {}
    for name, coords in pairs(iconDefs) do
        self.iconUVs[name] = GuiUtils.getUVs(coords, {1024, 1024})
    end

    -- Dedicated Calibration Tablet & Telemetry UI Atlas Slices (from textures/rhm_atlas.dds, 1024x1024)
    self.atlasOverlay = Overlay.new(panelTexturePath, 0, 0, 1, 1)

    -- Full-resolution Rugged Tablet Chassis Frame (Exact 802x573 Figma Asset)
    local frameTexturePath = Utils.getFilename("textures/tablet_frame.dds", self.modDirectory)
    self.frameOverlay = Overlay.new(frameTexturePath, 0, 0, 1, 1)

    -- EN: White sprites and high-contrast indicators for dynamic tinting via overlay:setColor.
    -- UA: Білі спрайти та висококонтрастні індикатори для динамічного тонування через overlay:setColor.
    local uiSlices = {
        dial_disc               = {   2, 450, 124, 124 },
        dial_segment            = { 136, 452,  48, 120 },
        card_telemetry          = { 192, 448, 251,  52 },
        tab_active              = { 456, 448, 171,  28 },
        tab_inactive            = { 636, 448, 171,  28 },
        btn_close               = { 816, 448,  37,  21 },
        tier_badge              = { 864, 448, 106,  21 },
        tab_active_hover        = { 456, 488, 171,  28 },
        tab_inactive_hover      = { 636, 488, 171,  28 },
        btn_close_hover         = { 816, 488,  37,  21 },
        btn_footer_reset        = {   4, 580, 184,  34 },
        btn_footer_action       = { 196, 580, 184,  34 },
        btn_footer_ai           = { 388, 580, 188,  34 },
        pill_crop               = { 584, 580, 117,  21 },
        pill_moisture           = { 708, 580,  90,  21 },
        pill_hp                 = { 808, 580,  84,  21 },
        pill_width              = { 900, 580,  75,  21 },
        slider_track_std        = {   4, 624, 278,  10 },
        slider_track_wide       = { 292, 624, 361,  10 },
        slider_thumb            = { 664, 624,  15,  20 },
        slider_tick             = { 688, 624,   4,  16 },
        btn_step                = { 700, 624,  33,  21 },
        glyph_minus             = { 744, 624,   9,   3 },
        glyph_plus              = { 760, 624,   9,   9 },
        btn_arrow_left          = { 776, 624,  25,  21 },
        btn_arrow_right         = { 808, 624,  25,  21 },
        glyph_arrow_left        = { 840, 624,   9,   9 },
        glyph_arrow_right       = { 856, 624,   9,   9 },
        category_notch          = { 872, 624,   8,  16 },
        glyph_close             = { 888, 624,   8,   8 },
        slider_fill_cap         = { 904, 624,   4,   8 },
        slider_fill_body        = { 916, 624,   8,   8 },
        category_line           = {   4, 656, 753,   2 },
        pill_status_optimal     = {   4, 668,  79,  21 },
        pill_status_warning     = {  92, 668,  79,  21 },
        pill_status_alert       = { 180, 668,  79,  21 },
        pill_value              = { 268, 668, 110,  21 },
        profile_badge_sel       = { 388, 668,  89,  21 },
        profile_badge_unsel     = { 488, 668,  89,  21 },
        btn_step_hover          = { 588, 668,  33,  21 },
        btn_arrow_left_hover    = { 632, 668,  25,  21 },
        btn_arrow_right_hover   = { 668, 668,  25,  21 },
        slider_thumb_hover      = { 704, 668,  15,  20 },
        btn_footer_reset_hover  = {   4, 700, 184,  34 },
        btn_footer_action_hover = { 196, 700, 184,  34 },
        btn_footer_ai_hover     = { 388, 700, 188,  34 },
        btn_footer_load         = { 584, 700, 380,  34 },
        btn_footer_load_hover   = {   4, 744, 380,  34 },
        slider_track_std_hover  = { 396, 744, 278,  10 },
        slider_track_wide_hover = { 396, 764, 361,  10 },
        profile_table_header    = {   4, 784, 763,  21 },
        profile_row_sel         = {   4, 812, 764,  46 },
        profile_row_unsel       = {   4, 864, 764,  46 },
        profile_row_hover       = {   4, 916, 764,  46 },
        profile_row_sel_hover   = {   4, 968, 764,  46 },
    }
    self.uiUVs = {}
    for name, coords in pairs(uiSlices) do
        self.uiUVs[name] = GuiUtils.getUVs(coords, {1024, 1024})
    end

    self.showColorSwatches = false
    UI_CONFIG.applyNativePalette()

    return self
end

function RHMCombineCalibrationGUI:delete()
    if self.overlay then
        self.overlay:delete()
        self.overlay = nil
    end
    if self.roundedOverlay then
        self.roundedOverlay:delete()
        self.roundedOverlay = nil
    end
    if self.iconOverlay then
        self.iconOverlay:delete()
        self.iconOverlay = nil
    end
    if self.atlasOverlay then
        self.atlasOverlay:delete()
        self.atlasOverlay = nil
    end
    if self.frameOverlay then
        self.frameOverlay:delete()
        self.frameOverlay = nil
    end
    self.roundedUVs = nil
    self.iconUVs = nil
    self.uiUVs = nil
end

---EN: Converts Figma absolute pixel coordinates (802x573 artboard) to pixel-snapped normalized screen coordinates.
---UA: Переводить пікселі Figma (802x573) у прив'язані до сітки нормалізовані координати екрана.
function RHMCombineCalibrationGUI:figmaToScreen(fX, fY, fW, fH)
    local ui = self.ui
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local baseX = math.floor(ui.x * screenW + 0.5) / screenW
    local baseTopY = math.floor((ui.y + ui.h) * screenH + 0.5) / screenH
    local rawX = baseX + (fX / 802.0) * ui.w
    local rawW = (fW / 802.0) * ui.w
    local rawH = (fH / 573.0) * ui.h
    local rawY = baseTopY - ((fY + fH) / 573.0) * ui.h
    local x = math.floor(rawX * screenW + 0.5) / screenW
    local y = math.floor(rawY * screenH + 0.5) / screenH
    local w = math.max(1 / screenW, math.floor(rawW * screenW + 0.5) / screenW)
    local h = math.max(1 / screenH, math.floor(rawH * screenH + 0.5) / screenH)
    return x, y, w, h
end

---EN: Renders a dedicated UI texture overlay from rhm_atlas.dds with pixel-snapped bounds and optional color tint.
---UA: Малює текстурний оверлей інтерфейсу з rhm_atlas.dds із прив'язкою до пікселів та можливим тонуванням кольором.
function RHMCombineCalibrationGUI:drawUITexture(keyOrOverlay, x, y, w, h, color)
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local px = math.floor(x * screenW + 0.5) / screenW
    local py = math.floor(y * screenH + 0.5) / screenH
    local pw = math.max(1 / screenW, math.floor(w * screenW + 0.5) / screenW)
    local ph = math.max(1 / screenH, math.floor(h * screenH + 0.5) / screenH)

    local uvs = nil
    if type(keyOrOverlay) == "string" then
        uvs = self.uiUVs and self.uiUVs[keyOrOverlay]
    elseif type(keyOrOverlay) == "table" and keyOrOverlay.render then
        keyOrOverlay:setPosition(px, py)
        keyOrOverlay:setDimension(pw, ph)
        if color then
            local r, g, b, a = resolveColorRGBA(color, 1.0)
            keyOrOverlay:setColor(r, g, b, a)
        else
            keyOrOverlay:setColor(1, 1, 1, 1)
        end
        keyOrOverlay:render()
        return
    end

    if uvs and self.atlasOverlay then
        self.atlasOverlay:setPosition(px, py)
        self.atlasOverlay:setDimension(pw, ph)
        self.atlasOverlay:setUVs(uvs)
        self.atlasOverlay:setRotation(0, 0, 0)
        if color then
            local r, g, b, a = resolveColorRGBA(color, 1.0)
            self.atlasOverlay:setColor(r, g, b, a)
        else
            self.atlasOverlay:setColor(1, 1, 1, 1)
        end
        self.atlasOverlay:render()
    end
end

---EN: Returns the canonical dock slot coordinates beneath the top-right clock bar, snapped to physical screen pixels.
---UA: Повертає координати слота прикріплення під годинником, прив'язані до пікселів.
function RHMCombineCalibrationGUI:getDockedPosition()
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local rawX = 1.0 - self.ui.w - 0.016
    local rawY = math.max(0.04, 0.880 - self.ui.h)
    local dockX = math.floor(rawX * screenW + 0.5) / screenW
    local dockY = math.floor(rawY * screenH + 0.5) / screenH
    return dockX, dockY, self.ui.w, self.ui.h
end

function RHMCombineCalibrationGUI:toggle(vehicle)
    if self.isOpen then
        local currentRoot = getVehicleRoot(self.activeVehicle)
        local newRoot = getVehicleRoot(vehicle)
        self:close()
        if currentRoot ~= nil and newRoot ~= nil and currentRoot ~= newRoot then
            self:open(vehicle)
        end
    else
        self:open(vehicle)
    end
end

function RHMCombineCalibrationGUI:open(vehicle)
    if self.isOpen then return end

    local cv = nil
    if g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
        cv = g_realisticHarvestManager:getControlledVehicle()
    end
    if not cv then
        if g_localPlayer and g_localPlayer.getCurrentVehicle then
            cv = g_localPlayer:getCurrentVehicle()
        elseif g_currentMission then
            if g_currentMission.getControlledVehicle then
                cv = g_currentMission:getControlledVehicle()
            elseif g_currentMission.controlledVehicle then
                cv = g_currentMission.controlledVehicle
            end
        end
    end

    local callerVehicle = vehicle or cv
    if cv then
        local cvRoot = getVehicleRoot(cv)
        local callerRoot = getVehicleRoot(callerVehicle)
        if not callerRoot or callerRoot ~= cvRoot then
            callerVehicle = cv
        end
    end

    local combineVehicle = callerVehicle
    if combineVehicle and not (combineVehicle.spec_rhm_Combine and combineVehicle.spec_rhm_Combine.isRhmCombine == true) then
        local found = RHM_Api and RHM_Api.findCombine and RHM_Api.findCombine(combineVehicle)
        if found and found.spec_rhm_Combine and found.spec_rhm_Combine.isRhmCombine == true then
            combineVehicle = found
        else
            rhm_log("RHM [UI]: [GUI] No combine with spec_rhm_Combine found in vehicle hierarchy")
            return
        end
    end

    if not combineVehicle or not (combineVehicle.spec_rhm_Combine and combineVehicle.spec_rhm_Combine.isRhmCombine == true) then
        return
    end

    self.isOpen = true

    if RHM_ModCompatibility and RHM_ModCompatibility.onCalibrationGUIOpened then
        RHM_ModCompatibility.onCalibrationGUIOpened()
    end

    g_inputBinding:setShowMouseCursor(true)
    self.isCursorActive = true

    local camTarget = (cv and cv.spec_enterable and cv)
                   or (callerVehicle and callerVehicle.spec_enterable and callerVehicle)
                   or (combineVehicle and combineVehicle.spec_enterable and combineVehicle)

    if camTarget and camTarget.spec_enterable then
        RHMInputUtil.setCameraRotation(camTarget, false, self.savedCameraRotatableInfo)
        RHMInputUtil.setCameraZoom(camTarget, false, self.savedCameraZoomInfo)
    end

    self.activeVehicle = combineVehicle
    self.controllerVehicle = cv or callerVehicle or combineVehicle

    -- Validate active crop on the combine
    if combineVehicle and combineVehicle.spec_rhm_Combine and combineVehicle.spec_rhm_Combine.combineMemory then
        local mem = combineVehicle.spec_rhm_Combine.combineMemory
        local mType = combineVehicle.spec_rhm_Combine.machineType or "grain"
        local mapCrops = RHM_CombineSettingsDatabase:getCropNamesForMachineType(mType, combineVehicle)

        local isValidCrop = false
        local canonicalCurrent = RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(mem.currentCrop)
        if mem.currentCrop and mapCrops then
            for _, c in ipairs(mapCrops) do
                if c == mem.currentCrop or (canonicalCurrent and c == canonicalCurrent) then
                    mem.currentCrop = c
                    isValidCrop = true
                    break
                end
            end
            if not isValidCrop and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.cropAliases then
                local alias = RHM_CombineSettingsDatabase.cropAliases[mem.currentCrop]
                if alias then
                    local canonicalAlias = RHM_CombineSettingsDatabase:getCanonicalCropName(alias)
                    for _, c in ipairs(mapCrops) do
                        if c == alias or (canonicalAlias and c == canonicalAlias) then
                            mem.currentCrop = c
                            isValidCrop = true
                            break
                        end
                    end
                end
            end
        end

        if not isValidCrop and mapCrops and #mapCrops > 0 then
            local defaultCrop = mapCrops[1]
            local preferred = (mType == "grain" and "WHEAT")
                           or (mType == "root" and "POTATO")
                           or (mType == "forage" and "MAIZE_FORAGE")
                           or (mType == "cotton" and "COTTON")
                           or (mType == "grape" and "GRAPE")
                           or (mType == "olive" and "OLIVE")
            if preferred then
                for _, c in ipairs(mapCrops) do
                    if c == preferred then
                        defaultCrop = preferred
                        break
                    end
                end
            end
            mem.currentCrop = defaultCrop
            if combineVehicle.spec_rhm_Combine.loadCalculator then
                combineVehicle.spec_rhm_Combine.loadCalculator.currentCrop = defaultCrop
            end
        end
    end
end

function RHMCombineCalibrationGUI:close()
    if not self.isOpen then return end
    self.isOpen = false
    self.isCursorActive = false
    self.draggingSlider = nil
    self.draggingSliderRatio = nil
    self.isDraggingTablet = false
    self.isNearDock = false

    if RHM_ModCompatibility and RHM_ModCompatibility.onCalibrationGUIClosed then
        RHM_ModCompatibility.onCalibrationGUIClosed()
    end

    local vehicle = self.controllerVehicle or (g_realisticHarvestManager and g_realisticHarvestManager:getControlledVehicle()) or self.activeVehicle
    local restoreTarget = (vehicle and vehicle.spec_enterable and vehicle)
                       or (self.activeVehicle and self.activeVehicle.spec_enterable and self.activeVehicle)

    local otherSystemOwnsCursor = false
    if CpHud and CpHud.isHudActive then
        otherSystemOwnsCursor = true
    end
    if AutoDrive and AutoDrive.isEditorModeEnabled and AutoDrive:isEditorModeEnabled() then
        otherSystemOwnsCursor = true
    end
    if VehicleMouseCursor and VehicleMouseCursor._cursorOwned then
        otherSystemOwnsCursor = true
    end

    if not otherSystemOwnsCursor then
        g_inputBinding:setShowMouseCursor(false)
    end

    if restoreTarget and restoreTarget.spec_enterable then
        RHMInputUtil.setCameraRotation(restoreTarget, true, self.savedCameraRotatableInfo)
        RHMInputUtil.setCameraZoom(restoreTarget, true, self.savedCameraZoomInfo)
    end

    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}
    self.activeVehicle = nil
    self.controllerVehicle = nil
    self.hoveredElement = nil
    self.hoveredParameter = nil
end

function RHMCombineCalibrationGUI:cycleCrop(direction)
    local spec = self.activeVehicle and self.activeVehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then return end

    local machineType = spec.machineType or "grain"
    local crops = RHM_CombineSettingsDatabase:getCropNamesForMachineType(machineType, self.activeVehicle)
    if not crops or #crops == 0 then return end

    local current = spec.combineMemory.currentCrop
    local canonicalCurrent = RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName
        and RHM_CombineSettingsDatabase:getCanonicalCropName(current)
    local index = 1

    if current then
        for i, name in ipairs(crops) do
            if name == current or (canonicalCurrent and name == canonicalCurrent) then
                index = i
                break
            end
        end
        if index == 1 and crops[1] ~= current and (not canonicalCurrent or crops[1] ~= canonicalCurrent)
            and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.cropAliases then
            local alias = RHM_CombineSettingsDatabase.cropAliases[current]
            if alias then
                local canonicalAlias = RHM_CombineSettingsDatabase:getCanonicalCropName(alias)
                for i, name in ipairs(crops) do
                    if name == alias or (canonicalAlias and name == canonicalAlias) then
                        index = i
                        break
                    end
                end
            end
        end
        index = index + direction
    else
        index = (direction > 0) and 1 or #crops
    end

    if index > #crops then index = 1 end
    if index < 1 then index = #crops end

    local newCrop = crops[index]
    spec.combineMemory:switchCrop(newCrop)
end

function RHMCombineCalibrationGUI:update(dt)
    if not self.isOpen then return end

    -- Keep mouse cursor explicitly visible while calibration GUI is open
    if g_inputBinding and g_inputBinding.setShowMouseCursor then
        g_inputBinding:setShowMouseCursor(true)
    end

    -- Keep camera rotation and translation blocked while GUI is open
    local vehicle = self.controllerVehicle or (g_realisticHarvestManager and g_realisticHarvestManager:getControlledVehicle()) or self.activeVehicle
    local camTarget = (vehicle and vehicle.spec_enterable and vehicle)
                   or (self.activeVehicle and self.activeVehicle.spec_enterable and self.activeVehicle)
    if camTarget and camTarget.spec_enterable and camTarget.spec_enterable.cameras then
        for _, camera in pairs(camTarget.spec_enterable.cameras) do
            camera.isRotatable = false
            camera.allowTranslation = false
        end
    end

    -- Suppress IC active controller while calibration GUI is open
    if g_currentMission and g_currentMission.interactiveControl then
        if g_currentMission.interactiveControl.activeController ~= nil then
            if type(g_currentMission.interactiveControl.setActiveInteractiveController) == "function" then
                g_currentMission.interactiveControl:setActiveInteractiveController(nil)
            end
        end
    end

    -- Keep VMC cursor overlay suppressed while calibration GUI is open
    if VehicleMouseCursor ~= nil and VehicleMouseCursor._cursorGui ~= nil then
        if VehicleMouseCursor._cursorGui.isOpen then
            VehicleMouseCursor._cursorGui.isOpen = false
        end
        VehicleMouseCursor._cursorOwned = false
    end

    if not self.activeVehicle or self.activeVehicle.isDeleted then
        self:close()
        return
    end

    local cv = nil
    if g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
        cv = g_realisticHarvestManager:getControlledVehicle()
    end
    if not cv then
        if g_localPlayer and g_localPlayer.getCurrentVehicle then
            cv = g_localPlayer:getCurrentVehicle()
        elseif g_currentMission then
            if g_currentMission.getControlledVehicle then
                cv = g_currentMission:getControlledVehicle()
            elseif g_currentMission.controlledVehicle then
                cv = g_currentMission.controlledVehicle
            end
        end
    end

    -- Strict validation: player must remain inside the active combine's vehicle hierarchy
    local isEntered = false
    if cv and self.activeVehicle then
        local cvRoot = getVehicleRoot(cv)
        local activeRoot = getVehicleRoot(self.activeVehicle)
        if cvRoot == activeRoot then
            isEntered = true
        else
            local combineInCv = RHM_Api and RHM_Api.findCombine and RHM_Api.findCombine(cv)
            if combineInCv and combineInCv == self.activeVehicle then
                isEntered = true
            end
        end
    end

    if not isEntered then
        self:close()
        return
    end

    if self.draggingSlider and Input and Input.isMouseButtonPressed and not Input.isMouseButtonPressed(Input.MOUSE_BUTTON_LEFT) then
        self.draggingSlider = nil
        self.draggingSliderRatio = nil
    end

    if self.isDraggingTablet and Input and Input.isMouseButtonPressed and not Input.isMouseButtonPressed(Input.MOUSE_BUTTON_LEFT) then
        self.isDraggingTablet = false
        if self.hasMovedTablet then
            if self.isNearDock then
                local dockX, dockY = self:getDockedPosition()
                self.ui.x = dockX
                self.ui.y = dockY
                self.hasCustomPosition = false
            else
                self.hasCustomPosition = true
            end
        end
        self.isNearDock = false
    end

    -- Sample authentic rolling telemetry for live curve graphs every 400ms
    local now = g_time or 0
    if now - (self.telemetryHistory.lastSampleTime or 0) >= 400 then
        self.telemetryHistory.lastSampleTime = now
        local spec = self.activeVehicle.spec_rhm_Combine
        local currentLoad = 0
        if spec then
            currentLoad = (spec.data and spec.data.load)
                or (spec.loadCalculator and spec.loadCalculator.getEngineLoad and spec.loadCalculator:getEngineLoad())
                or ((spec.loadCalculator and spec.loadCalculator.engineLoad or 0) * 100)
        end
        local lRatio = math.max(0.05, math.min(1.0, currentLoad / 100.0))
        table.remove(self.telemetryHistory.load, 1)
        table.insert(self.telemetryHistory.load, lRatio)

        local effVal = 0.98
        local lossVal = 0.005
        local mem = spec and spec.combineMemory
        if mem and mem.currentCrop then
            local harvestCtx = self:getHarvestContext(spec.machineType)
            local effP, lossP = mem:checkSettingsForCrop(mem.currentCrop, harvestCtx)
            effVal = math.max(0.10, math.min(1.0, (100.0 - (effP or 0)) / 100.0))
            lossVal = math.max(0.02, math.min(1.0, ((lossP or 0) + 0.1) / 3.0))
        end
        table.remove(self.telemetryHistory.eff, 1)
        table.insert(self.telemetryHistory.eff, effVal)

        table.remove(self.telemetryHistory.loss, 1)
        table.insert(self.telemetryHistory.loss, lossVal)
    end
end

---EN: Draws magnetic green glowing docking silhouette showing target attachment edge.
---UA: Малює зелену пульсуючу рамку магнітного слота в області прикріплення меню.
function RHMCombineCalibrationGUI:drawDockSnapPlaceholder(dockX, dockY, dockW, dockH)
    if not self.roundedOverlay or not self.roundedUVs then return end

    local padX = 0.003
    local padY = 0.003
    local slotX = dockX - padX
    local slotY = dockY - padY
    local slotW = dockW + (padX * 2)
    local slotH = (dockH or self.ui.h) + (padY * 2)

    local greenBase = {0.61, 0.85, 0.15, 1.0}
    local pulse = 0.85 + 0.15 * math.sin((g_time or 0) * 0.008)
    local r = greenBase[1] * pulse
    local g = greenBase[2] * pulse
    local b = greenBase[3] * pulse

    -- Outer rounded outline in magnetic glowing green
    self:drawPanelBackground(slotX, slotY, slotW, slotH, {r, g, b, 0.85}, 8)

    -- Inner cutout for glowing border effect
    local thickness = 0.0015
    local inX = slotX + thickness
    local inY = slotY + thickness
    local inW = slotW - (thickness * 2)
    local inH = slotH - (thickness * 2)
    self:drawPanelBackground(inX, inY, inW, inH, {0.04, 0.08, 0.02, 0.50}, 7)
end

---EN: Draws an industrial corner allen fastener/bolt.
---UA: Малює шестигранний металевий болт кріплення на кутах корпусу.
function RHMCombineCalibrationGUI:drawAllenBolt(cx, cy, radius, theme)
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local aspect = screenW / screenH
    local rx = radius / aspect
    local ry = radius

    -- Dark circular recess
    self:drawRect(cx - rx, cy - ry, rx * 2, ry * 2, {0.015, 0.018, 0.022, 0.95})
    self:drawBorder(cx - rx, cy - ry, rx * 2, ry * 2, {0.35, 0.40, 0.46, 0.70}, 1)

    -- Hex / cross metallic core
    local irx = rx * 0.45
    local iry = ry * 0.45
    self:drawRect(cx - irx, cy - iry, irx * 2, iry * 2, {0.08, 0.10, 0.12, 0.95})
    self:drawRect(cx - irx * 0.6, cy - 0.0004, irx * 1.2, 0.0008, {0.45, 0.50, 0.55, 0.80})
end

---EN: Draws an atlas icon by slice ID.
---UA: Малює іконку з атласу за ідентифікатором.
function RHMCombineCalibrationGUI:drawAtlasIcon(name, x, y, size, color)
    local uvs = self.iconUVs and self.iconUVs[name]
    if not uvs or not self.iconOverlay then return end
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local aspect = screenW / screenH
    local w = size / aspect
    local h = size
    local r, g, b, a = resolveColorRGBA(color, 1.0)
    self.iconOverlay:setPosition(x, y)
    self.iconOverlay:setDimension(w, h)
    self.iconOverlay:setUVs(uvs)
    self.iconOverlay:setColor(r, g, b, a or 1.0)
    self.iconOverlay:render()
end

---EN: Probes GIANTS Engine 10 native GUI color presets and HUD color tables.
---UA: Досліджує системні пресети кольорів GUI та HUD базової гри GIANTS Engine 10.
function RHMCombineCalibrationGUI:inspectNativeColors()
    if self.cachedNativeColors then return self.cachedNativeColors end

    local colors = {}
    local seen = {}

    local function parseColor(val)
        if type(val) == "table" then
            if val[1] ~= nil and type(val[1]) == "number" then
                return { val[1], val[2] or val[1], val[3] or val[1], val[4] or 1.0 }
            elseif val.r ~= nil then
                return { val.r, val.g, val.b, val.a or 1.0 }
            end
        elseif type(val) == "string" then
            if string.find(val, "px") or string.find(val, "pt") then return nil end
            local p = {}
            for n in string.gmatch(val, "%S+") do
                local num = tonumber(n)
                if not num or num < 0 or num > 1.05 then
                    return nil
                end
                table.insert(p, num)
            end
            if #p == 3 then
                return { p[1], p[2], p[3], 1.0 }
            elseif #p == 4 then
                return { p[1], p[2], p[3], p[4] }
            end
        end
        return nil
    end

    local function addColor(name, raw, source)
        if not name or seen[name] then return end
        local c = parseColor(raw)
        if c then
            seen[name] = true
            table.insert(colors, { name = name, color = c, source = source })
        end
    end

    -- 1. Official FS25 Engine HUD warning, danger & alert colors
    addColor("WarningDisplay.ALERT_RED", { 0.7796, 0.0578, 0.0612, 1.00 }, "WarningDisplay.lua")
    addColor("SpeedMeter.CRITICAL_RED", { 1.0000, 0.1233, 0.0000, 1.00 }, "SpeedMeterDisplay.lua")
    addColor("SpeedMeter.WARNING_ORANGE", { 1.0000, 0.4287, 0.0006, 1.00 }, "SpeedMeterDisplay.lua")
    addColor("SpeedMeter.DEF_BLUE", { 0.0097, 0.4287, 0.6445, 1.00 }, "SpeedMeterDisplay.lua")

    -- 2. Probe HUD.COLOR (Standard GIANTS Engine HUD table)
    if HUD and HUD.COLOR and type(HUD.COLOR) == "table" then
        for name, raw in pairs(HUD.COLOR) do
            addColor("HUD." .. tostring(name), raw, "HUD.COLOR")
        end
    end

    -- 3. Probe g_gui.presets (The master table of all $preset_ definitions in FS25!)
    if g_gui and g_gui.presets and type(g_gui.presets) == "table" then
        for name, raw in pairs(g_gui.presets) do
            local sName = tostring(name)
            local lower = string.lower(sName)
            if string.find(lower, "color") or string.find(lower, "red") or string.find(lower, "green")
               or string.find(lower, "orange") or string.find(lower, "yellow") or string.find(lower, "blue")
               or string.find(lower, "white") or string.find(lower, "black") or string.find(lower, "grey")
               or string.find(lower, "gray") or string.find(lower, "dark") or string.find(lower, "light")
               or string.find(lower, "highlight") or string.find(lower, "disabled") then
                addColor("preset_" .. sName, raw, "g_gui.presets")
            end
        end
    end

    -- 4. Probe known FS25 GUI profiles
    local knownProfiles = {
        "button", "baseReference", "header", "rhmListItem", "rhmRowCellCenter", "rhmCardSurface"
    }
    if g_gui and g_gui.getProfile then
        for _, pName in ipairs(knownProfiles) do
            local p = g_gui:getProfile(pName)
            if p and type(p) == "table" then
                if p.imageColor then addColor(pName .. ".imageColor", p.imageColor, "profile") end
                if p.textColor then addColor(pName .. ".textColor", p.textColor, "profile") end
                if p.color then addColor(pName .. ".color", p.color, "profile") end
                if p.textSelectedColor then addColor(pName .. ".textSelectedColor", p.textSelectedColor, "profile") end
                if p.imageSelectedColor then addColor(pName .. ".imageSelectedColor", p.imageSelectedColor, "profile") end
            end
        end
    end

    -- Log all to log.txt for complete transparent analysis
    if not self._nativeColorsLogged then
        self._nativeColorsLogged = true
        rhm_log(string.format("RHM [NativeColors]: Probed %d native game colors from engine:", #colors))
        for _, item in ipairs(colors) do
            local r, g, b, a = item.color[1], item.color[2], item.color[3], item.color[4]
            local hexR = math.floor(math.max(0, math.min(1, r)) * 255 + 0.5)
            local hexG = math.floor(math.max(0, math.min(1, g)) * 255 + 0.5)
            local hexB = math.floor(math.max(0, math.min(1, b)) * 255 + 0.5)
            rhm_log(string.format("  - %-32s = RGBA(%.4f, %.4f, %.4f, %.4f)  #%02X%02X%02X  [%s]",
                item.name, r, g, b, a, hexR, hexG, hexB, item.source or "engine"))
        end
    end

    self.cachedNativeColors = colors
    return colors
end

---EN: Renders live test squares on screen with colors probed directly from the base game.
---UA: Малює на екрані тестові кольорові квадрати з кольорами, взятими напряму з базової гри.
function RHMCombineCalibrationGUI:drawNativeColorSwatches()
    if not self.showColorSwatches then return end

    local colors = self:inspectNativeColors()
    if not colors or #colors == 0 then return end

    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local aspect = screenW / screenH

    -- 2-Column layout to display up to 26 colors simultaneously
    local numItems = #colors
    local itemsPerCol = math.min(13, math.ceil(numItems / 2))
    local colW = 0.170
    local panelW = (numItems > 13) and (colW * 2 + 0.024) or (colW + 0.016)
    local itemH = 0.023
    local headerH = 0.038
    local panelH = headerH + (itemsPerCol * itemH) + 0.012
    local panelX = 0.016
    local panelY = math.max(0.04, 0.880 - panelH)

    -- Semi-transparent dark container panel
    self:drawRect(panelX, panelY, panelW, panelH, {0.012, 0.012, 0.012, 0.94})
    self:drawBorder(panelX, panelY, panelW, panelH, {0.30, 0.30, 0.30, 1.0}, 1)

    -- Header title
    local fScale = self.ui.h / 573.0
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.accent)
    local titleSize = 10.5 * fScale
    renderText(panelX + 0.008, panelY + panelH - 0.020, titleSize, "FS25 NATIVE ENGINE COLORS")

    -- Close [X] button for the swatch panel
    local closeX = panelX + panelW - 0.022
    local closeY = panelY + panelH - 0.024
    local closeW = 0.016
    local closeH = 0.016
    self:drawRect(closeX, closeY, closeW, closeH, {0.35, 0.10, 0.10, 0.85})
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(1, 1, 1, 1)
    renderText(closeX + closeW * 0.5, closeY + (closeH - 9.0 * fScale * 0.72) * 0.5, 9.0 * fScale, "X")
    table.insert(self.buttons, {
        x = closeX, y = closeY, w = closeW, h = closeH,
        callback = function() self.showColorSwatches = false end
    })

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    safeSetTextColor(UI_CONFIG.colors.textDim)
    local subSize = 8.0 * fScale
    renderText(panelX + 0.008, panelY + panelH - 0.032, subSize, string.format("Live engine probe: %d colors discovered (Red, Orange, Lime, Blue, Grayscale)", numItems))

    -- Horizontal line under title
    self:drawRect(panelX + 0.008, panelY + panelH - 0.036, panelW - 0.016, 1 / screenH, {0.35, 0.35, 0.35, 0.60})

    -- Render swatch items across 1 or 2 columns
    for idx, item in ipairs(colors) do
        if idx <= itemsPerCol * 2 then
            local col = (idx <= itemsPerCol) and 1 or 2
            local row = (col == 1) and (idx - 1) or (idx - itemsPerCol - 1)

            local c = item.color
            local sqSize = itemH * 0.72
            local sqW = sqSize / aspect
            local colStartX = (col == 1) and (panelX + 0.008) or (panelX + colW + 0.016)
            local itemY = panelY + panelH - 0.040 - (row + 1) * itemH
            local sqX = colStartX
            local sqY = itemY + (itemH - sqSize) * 0.5

            -- Filled color square
            self:drawRect(sqX, sqY, sqW, sqSize, c)
            -- Outline around square so dark/black swatches don't disappear
            self:drawBorder(sqX, sqY, sqW, sqSize, {0.55, 0.55, 0.55, 0.85}, 1)

            -- Text label next to square
            local labelX = sqX + sqW + 0.005
            local hexR = math.floor(math.max(0, math.min(1, c[1])) * 255 + 0.5)
            local hexG = math.floor(math.max(0, math.min(1, c[2])) * 255 + 0.5)
            local hexB = math.floor(math.max(0, math.min(1, c[3])) * 255 + 0.5)
            local hexStr = string.format("#%02X%02X%02X", hexR, hexG, hexB)

            -- Shorten display name for compact view
            local shortName = item.name
            if string.len(shortName) > 22 then
                shortName = string.sub(shortName, 1, 20) .. ".."
            end

            setTextBold(true)
            setTextColor(1.0, 1.0, 1.0, 0.95)
            renderText(labelX, sqY + sqSize * 0.48, 8.0 * fScale, shortName)

            setTextBold(false)
            setTextColor(0.70, 0.74, 0.78, 0.85)
            renderText(labelX, sqY, 7.0 * fScale, string.format("%s (%.2f, %.2f, %.2f)", hexStr, c[1], c[2], c[3]))
        end
    end

    self:_resetTextState()
end

function RHMCombineCalibrationGUI:draw()
    if not self.isOpen then return end
    if not (g_currentMission and g_currentMission.hud) then return end

    self.buttons = {}
    self.sliders = {}
    self.hoveredParameter = nil

    UI_CONFIG.applyNativePalette()

    local ui = self.ui
    local spec = self.activeVehicle and self.activeVehicle.spec_rhm_Combine
    local memory = spec and spec.combineMemory
    if not memory and self.activeVehicle and rhm_Combine and rhm_Combine.getOrInitCombineMemory then
        memory = rhm_Combine.getOrInitCombineMemory(self.activeVehicle)
    end

    local machineType = spec and (spec.machineType or (memory and memory.machineType)) or "grain"
    local activeParams = RHM_CombineSettingsDatabase:getParamsForMachineType(machineType)
    local packageLevel = (spec and spec.packageLevel) or 1
    local theme = getEffectiveTheme(packageLevel, self.activeVehicle)
    local harvestContext = self:getHarvestContext(machineType)
    local cachedCropSettings = (RHM_CombineSettingsDatabase and memory and memory.currentCrop)
        and RHM_CombineSettingsDatabase:getSettingsForCrop(memory.currentCrop, harvestContext)
        or nil

    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local aspect = screenW / screenH

    -- Exact Figma Artboard Dimensions (802 x 573 px)
    ui.h = 573.0 / 1080.0
    ui.w = (802.0 / 1080.0) / aspect

    -- Docked canonical position calculation
    local dockX, dockY, dockW, dockH = self:getDockedPosition()
    if not self.hasCustomPosition and not self.isDraggingTablet then
        ui.x = dockX
        ui.y = dockY
    end

    -- If currently dragging near docking zone: show magnetic green slot placeholder!
    if self.isDraggingTablet and self.isNearDock then
        self:drawDockSnapPlaceholder(dockX, dockY, dockW, ui.h)
    end

    -- 1. Outer Rugged Tablet Chassis & Screen (802x573 Figma Asset: #222222 Chassis + #191919 Screen)
    local chX, chY, chW, chH = self:figmaToScreen(0, 0, UI_CONFIG.layout.artboardW, UI_CONFIG.layout.artboardH)
    if self.frameOverlay then
        self.frameOverlay:setPosition(chX, chY)
        self.frameOverlay:setDimension(chW, chH)
        self.frameOverlay:setUVs({0, 0, 0, 1, 1, 0, 1, 1})
        self.frameOverlay:setColor(1, 1, 1, 1)
        self.frameOverlay:render()
    else
        self:drawRoundedBox(chX, chY, chW, chH, UI_CONFIG.colors.chassisBg, nil, UI_CONFIG.layout.chassisRadius)
        local bPad = UI_CONFIG.layout.bezelPad
        local scX, scY, scW, scH = self:figmaToScreen(bPad, bPad, UI_CONFIG.layout.artboardW - bPad * 2, UI_CONFIG.layout.artboardH - bPad * 2)
        self:drawRoundedBox(scX, scY, scW, scH, UI_CONFIG.colors.screenBg, UI_CONFIG.colors.screenBorder, UI_CONFIG.layout.screenRadius)
    end

    -- 3. Top Header Bar (Model, Terminal name, Environmental Pills, Tier Badge, Close button)
    self:drawHeader(spec, memory, theme, packageLevel)

    -- 4. Horizontal Navigation Tabs Bar (SETTINGS vs PROFILES at top = 54)
    self:drawHorizontalTabs(theme)

    -- 5. Main Content depending on Active Tab
    if self.activeTab == 1 then
        -- Telemetry Cards (Tier 3+ Live Telemetry Gauge Cards: Engine Load %, Efficiency %, Predicted Loss %)
        if theme.hasLiveCards then
            self:drawTelemetryCards(spec, memory, harvestContext, machineType, theme)
        end

        -- [ CALIBRATION ] TAB: Full settings overview
        self:drawAllTab(spec, memory, activeParams, machineType, packageLevel, cachedCropSettings, theme)

        -- Action Footer for Tab 1: [RESET], [PROFILES], [SAVE PROFILE], [AI AUTO-CALIB]
        self:drawActionFooter(memory, theme, packageLevel)
    else
        -- [ PROFILES ] TAB: Preset save/load management
        self:drawProfilesTab(memory, theme, packageLevel)
    end

    -- Scroll Wheel Handling
    if self.lastScrollTimeStamp + self.scrollDelayMs < g_time then
        local mx, my = self.mouseX, self.mouseY
        if (not mx or not my or (mx == 0 and my == 0)) and g_lastMousePosX and g_lastMousePosY then
            mx, my = g_lastMousePosX, g_lastMousePosY
        end
        if mx and my and mx >= ui.x and mx <= ui.x + ui.w and my >= ui.y and my <= ui.y + ui.h then
            if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
                self.lastScrollTimeStamp = g_time
                self:handleWheelScroll(1, mx, my)
            elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
                self.lastScrollTimeStamp = g_time
                self:handleWheelScroll(-1, mx, my)
            end
        end
    end

    -- 6. Live Native Game Colors Swatch Panel (interactive engine probe)
    if self.showColorSwatches then
        self:drawNativeColorSwatches()
    end

    self:_resetTextState()
end

---EN: Robust detection of attached cutter working width across FS25 engine hierarchies.
---UA: Надійне визначення робочої ширини під'єднаної жатки у FS25.
function RHMCombineCalibrationGUI:getCutterWorkingWidth(v)
    if not v then return 0 end
    local w = 0

    -- 1. Try public API first
    if RHM_Api and RHM_Api.getWorkingWidth then
        local rawW = RHM_Api.getWorkingWidth(v)
        if rawW and tonumber(rawW) and tonumber(rawW) > 0 then
            w = math.max(w, tonumber(rawW))
        end
    end

    -- 2. Try loadCalculator lastHeaderWidth
    local spec = v.spec_rhm_Combine
    if w == 0 and spec and spec.loadCalculator and spec.loadCalculator.lastHeaderWidth and spec.loadCalculator.lastHeaderWidth > 0 then
        w = math.max(w, spec.loadCalculator.lastHeaderWidth)
    end

    -- 3. Check attached cutters and implements hierarchy recursively
    local candidates = {}
    local visited = {}
    local function collectImplements(veh)
        if not veh or visited[veh] then return end
        visited[veh] = true
        table.insert(candidates, veh)
        if veh.getAttachedImplements then
            for _, impl in pairs(veh:getAttachedImplements()) do
                if impl.object then
                    collectImplements(impl.object)
                end
            end
        end
    end

    if rhm_Combine and rhm_Combine.getAllAttachedCutters then
        local cutters = rhm_Combine.getAllAttachedCutters(v)
        for c, _ in pairs(cutters) do
            collectImplements(c)
        end
    end
    collectImplements(v)

    for _, obj in ipairs(candidates) do
        -- Direct getWorkingWidth
        if obj.getWorkingWidth then
            local raw = obj:getWorkingWidth()
            if raw and tonumber(raw) and tonumber(raw) > 0 then w = math.max(w, tonumber(raw)) end
        end
        if obj.spec_cutter and obj.spec_cutter.workingWidth and obj.spec_cutter.workingWidth > 0 then
            w = math.max(w, obj.spec_cutter.workingWidth)
        end
        if obj.spec_cutter and obj.spec_cutter.cutterWorkWidth and obj.spec_cutter.cutterWorkWidth > 0 then
            w = math.max(w, obj.spec_cutter.cutterWorkWidth)
        end
        -- AI markers (distance between left and right marker nodes)
        if obj.getAIMarkers then
            local mLeft, mRight = obj:getAIMarkers()
            if mLeft and mRight and MathUtil and getWorldTranslation then
                local x1, _, z1 = getWorldTranslation(mLeft)
                local x2, _, z2 = getWorldTranslation(mRight)
                local markerDist = MathUtil.vector2Length(x2 - x1, z2 - z1)
                if markerDist and markerDist > 0 then
                    w = math.max(w, markerDist)
                end
            end
        end
        -- Work Areas
        if obj.spec_workArea and obj.spec_workArea.workAreas and MathUtil and getWorldTranslation then
            for _, wa in pairs(obj.spec_workArea.workAreas) do
                if wa.start and wa.width then
                    local sx, _, sz = getWorldTranslation(wa.start)
                    local wx, _, wz = getWorldTranslation(wa.width)
                    local areaWidth = MathUtil.vector2Length(wx - sx, wz - sz)
                    if areaWidth and areaWidth > 0 then w = math.max(w, areaWidth) end
                end
            end
        end
        -- StoreManager item specs
        if obj.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
            local item = g_storeManager:getItemByXMLFilename(obj.configFileName)
            if item and item.specs and item.specs.workingWidth then
                local num = tonumber(string.match(tostring(item.specs.workingWidth), "%d+%.?%d*"))
                if num and num > 0 then w = math.max(w, num) end
            end
        end
        -- StoreData xml File
        if obj.xmlFile and obj.xmlFile.getValue then
            local rawXML = obj.xmlFile:getValue("vehicle.storeData.specs.workingWidth")
            if rawXML then
                local num = tonumber(string.match(tostring(rawXML), "%d+%.?%d*"))
                if num and num > 0 then w = math.max(w, num) end
            end
        end
    end

    return w
end

---EN: Draws the top header bar with model title, brand terminal name, environmental pills, tier badge, and exit [X].
---UA: Малює верхній заголовок із назвою моделі, маркуванням терміналу, пігулками характеристик, рівнем та [X].
function RHMCombineCalibrationGUI:drawHeader(spec, memory, theme, packageLevel)
    local ui = self.ui
    local fScale = ui.h / UI_CONFIG.layout.artboardH

    -- Close Button [X] at (746, 20, 37, 21)
    local xBtnX, xBtnY, xBtnW, xBtnH = self:figmaToScreen(
        UI_CONFIG.layout.closeBtnX, UI_CONFIG.layout.headerY, UI_CONFIG.layout.closeBtnW, UI_CONFIG.layout.headerH
    )
    local isCloseHovered = self:checkHover(xBtnX, xBtnY, xBtnW, xBtnH)
    local closeTex = (isCloseHovered and self.uiUVs and self.uiUVs["btn_close_hover"]) and "btn_close_hover" or "btn_close"
    if self.uiUVs and self.uiUVs[closeTex] then
        self:drawUITexture(closeTex, xBtnX, xBtnY, xBtnW, xBtnH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(xBtnX, xBtnY, xBtnW, xBtnH, UI_CONFIG.colors.btnCloseBg, UI_CONFIG.colors.btnCloseBorder, 5)
    end
    if self.uiUVs and self.uiUVs["glyph_close"] then
        local gX, gY, gW, gH = self:figmaToScreen(
            UI_CONFIG.layout.closeBtnX + (UI_CONFIG.layout.closeBtnW - 8) * 0.5,
            UI_CONFIG.layout.headerY + (UI_CONFIG.layout.headerH - 8) * 0.5, 8, 8
        )
        self:drawUITexture("glyph_close", gX, gY, gW, gH, UI_CONFIG.colors.textWhite)
    else
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        safeSetTextColor(UI_CONFIG.colors.textWhite)
        local xFontSize = 11.5 * fScale
        renderText(xBtnX + xBtnW * 0.5, xBtnY + (xBtnH - xFontSize * 0.72) * 0.5, xFontSize, "X")
    end

    table.insert(self.buttons, {
        x = xBtnX, y = xBtnY, w = xBtnW, h = xBtnH,
        callback = function() self:close() end
    })

    -- Tier Badge at (633, 20, 106, 21)
    local bX, bY, bW, bH = self:figmaToScreen(UI_CONFIG.layout.tierBadgeX, UI_CONFIG.layout.headerY, UI_CONFIG.layout.tierBadgeW, UI_CONFIG.layout.headerH)
    if self.uiUVs and self.uiUVs["tier_badge"] then
        self:drawUITexture("tier_badge", bX, bY, bW, bH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(bX, bY, bW, bH, UI_CONFIG.colors.tierBadgeBg, UI_CONFIG.colors.tierBadgeBrd, 5)
    end
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.tierBadgeText)
    local bFontSize = 9.5 * fScale
    renderText(bX + bW * 0.5, bY + (bH - bFontSize * 0.72) * 0.5, bFontSize, theme.badgeLabel or "TIER")

    -- Width Pill at (552, 20, 75, 21)
    local v = self.activeVehicle
    local cutterWidth = self:getCutterWorkingWidth(v)
    local widthStr = (cutterWidth > 0) and string.format("%.1fm", cutterWidth) or "--"
    local wX, wY, wW, wH = self:figmaToScreen(UI_CONFIG.layout.cutterWidthX, UI_CONFIG.layout.headerY, UI_CONFIG.layout.cutterWidthW, UI_CONFIG.layout.headerH)
    if self.uiUVs and self.uiUVs["pill_width"] then
        self:drawUITexture("pill_width", wX, wY, wW, wH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(wX, wY, wW, wH, UI_CONFIG.colors.infoPillBg, UI_CONFIG.colors.infoPillBorder, 5)
    end
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.textWhite)
    renderText(wX + wW * 0.5, wY + (wH - 9.5 * fScale * 0.72) * 0.5, 9.5 * fScale, widthStr)

    -- Engine HP Pill at (464, 20, 84, 21)
    local engineHp = nil
    if spec and spec.data and spec.data.effectiveHp and spec.data.effectiveHp > 0 then
        engineHp = spec.data.effectiveHp
    elseif spec and spec.loadCalculator and spec.loadCalculator.getEnginePowerHp then
        engineHp = spec.loadCalculator:getEnginePowerHp(v)
    elseif v and v._rhm_engineHp and v._rhm_engineHp > 0 then
        engineHp = v._rhm_engineHp
    end
    if not engineHp and v then
        local motorObj = v
        if not (v.spec_motorized and v.spec_motorized.motor) then
            local root = v.rootVehicle or (v.getRootVehicle and v:getRootVehicle())
            if root and root.spec_motorized and root.spec_motorized.motor then motorObj = root end
        end
        if motorObj and motorObj.spec_motorized and motorObj.spec_motorized.motor then
            local motor = motorObj.spec_motorized.motor
            if motor.maxMotorPower and tonumber(motor.maxMotorPower) > 0 then
                engineHp = tonumber(motor.maxMotorPower) * 1.35962
            elseif motor.peakMotorPower and tonumber(motor.peakMotorPower) > 0 then
                engineHp = tonumber(motor.peakMotorPower) * 1.35962
            elseif motor.getHp then
                engineHp = motor:getHp()
            end
        end
    end
    local hpStr = engineHp and string.format("%.0f HP", engineHp) or "--"
    local hpX, hpY, hpW, hpH = self:figmaToScreen(UI_CONFIG.layout.engineHpX, UI_CONFIG.layout.headerY, UI_CONFIG.layout.engineHpW, UI_CONFIG.layout.headerH)
    if self.uiUVs and self.uiUVs["pill_hp"] then
        self:drawUITexture("pill_hp", hpX, hpY, hpW, hpH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(hpX, hpY, hpW, hpH, UI_CONFIG.colors.infoPillBg, UI_CONFIG.colors.infoPillBorder, 5)
    end
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.textWhite)
    renderText(hpX + hpW * 0.5, hpY + (hpH - 9.5 * fScale * 0.72) * 0.5, 9.5 * fScale, hpStr)

    -- Moisture Pill at (368, 20, 90, 21)
    local liveMoisture = (spec and spec.data and spec.data.moisture) or 0
    if liveMoisture <= 0 and RHM_MoistureAdapter and RHM_MoistureAdapter.getStandingCropMoisture then
        local fillType = spec and (spec.lastFillType or (memory and memory.currentCrop))
        liveMoisture = RHM_MoistureAdapter.getStandingCropMoisture(self.activeVehicle, fillType) or 0
    end
    local moistureStr = (liveMoisture > 0) and string.format("%.1f%% H2O", liveMoisture) or "14.0% H2O"
    local mX, mY, mW, mH = self:figmaToScreen(UI_CONFIG.layout.moistureX, UI_CONFIG.layout.headerY, UI_CONFIG.layout.moistureW, UI_CONFIG.layout.headerH)
    local mCol = (liveMoisture > 14.5) and UI_CONFIG.colors.availableYellow or (UI_CONFIG.colors.defBlue or UI_CONFIG.colors.accent)
    if self.uiUVs and self.uiUVs["pill_moisture"] then
        self:drawUITexture("pill_moisture", mX, mY, mW, mH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(mX, mY, mW, mH, UI_CONFIG.colors.infoPillBg, UI_CONFIG.colors.infoPillBorder, 5)
    end
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    safeSetTextColor(mCol)
    renderText(mX + mW * 0.5, mY + (mH - 9.5 * fScale * 0.72) * 0.5, 9.5 * fScale, moistureStr)

    -- Crop Selector: [<] at (191, 20, 25, 21), Center at (217, 20, 117, 21), [>] at (336, 20, 25, 21)
    local cPrevX, cPrevY, cPrevW, cPrevH = self:figmaToScreen(
        UI_CONFIG.layout.cropPrevX, UI_CONFIG.layout.headerY, UI_CONFIG.layout.cropPrevW, UI_CONFIG.layout.headerH
    )
    local isPrevHovered = self:checkHover(cPrevX, cPrevY, cPrevW, cPrevH)
    local prevTex = (isPrevHovered and self.uiUVs and self.uiUVs["btn_arrow_left_hover"]) and "btn_arrow_left_hover" or "btn_arrow_left"
    local prevGlyphCol = isPrevHovered and UI_CONFIG.colors.textWhite or UI_CONFIG.colors.btnStepText
    if self.uiUVs and self.uiUVs[prevTex] then
        self:drawUITexture(prevTex, cPrevX, cPrevY, cPrevW, cPrevH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(cPrevX, cPrevY, cPrevW, cPrevH, UI_CONFIG.colors.btnStepBg, UI_CONFIG.colors.btnStepBorder, 5)
    end
    if self.uiUVs and self.uiUVs["glyph_arrow_left"] then
        local gX, gY, gW, gH = self:figmaToScreen(UI_CONFIG.layout.cropPrevX + 8, UI_CONFIG.layout.headerY + 6, 9, 9)
        self:drawUITexture("glyph_arrow_left", gX, gY, gW, gH, prevGlyphCol)
    else
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        safeSetTextColor(prevGlyphCol)
        renderText(cPrevX + cPrevW * 0.5, cPrevY + (cPrevH - 11.5 * fScale * 0.72) * 0.5, 11.5 * fScale, "<")
    end
    table.insert(self.buttons, {
        x = cPrevX, y = cPrevY, w = cPrevW, h = cPrevH,
        callback = function() self:cycleCrop(-1) end
    })

    local cropName = (memory and memory.currentCrop) or "WHEAT"
    if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
        cropName = RHM_CombineSettingsDatabase:getCropDisplayName(cropName)
    end
    local cropUpper = string.upper(cropName)

    local cMidX, cMidY, cMidW, cMidH = self:figmaToScreen(
        UI_CONFIG.layout.cropMidX, UI_CONFIG.layout.headerY, UI_CONFIG.layout.cropMidW, UI_CONFIG.layout.headerH
    )
    if self.uiUVs and self.uiUVs["pill_crop"] then
        self:drawUITexture("pill_crop", cMidX, cMidY, cMidW, cMidH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(cMidX, cMidY, cMidW, cMidH, UI_CONFIG.colors.cropSelectorBg, UI_CONFIG.colors.cropSelectorBrd, 5)
    end
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.cropSelectorText)
    renderText(cMidX + cMidW * 0.5, cMidY + (cMidH - 9.5 * fScale * 0.72) * 0.5, 9.5 * fScale, cropUpper)

    local cNextX, cNextY, cNextW, cNextH = self:figmaToScreen(
        UI_CONFIG.layout.cropNextX, UI_CONFIG.layout.headerY, UI_CONFIG.layout.cropNextW, UI_CONFIG.layout.headerH
    )
    local isNextHovered = self:checkHover(cNextX, cNextY, cNextW, cNextH)
    local nextTex = (isNextHovered and self.uiUVs and self.uiUVs["btn_arrow_right_hover"]) and "btn_arrow_right_hover" or "btn_arrow_right"
    local nextGlyphCol = isNextHovered and UI_CONFIG.colors.textWhite or UI_CONFIG.colors.btnStepText
    if self.uiUVs and self.uiUVs[nextTex] then
        self:drawUITexture(nextTex, cNextX, cNextY, cNextW, cNextH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(cNextX, cNextY, cNextW, cNextH, UI_CONFIG.colors.btnStepBg, UI_CONFIG.colors.btnStepBorder, 5)
    end
    if self.uiUVs and self.uiUVs["glyph_arrow_right"] then
        local gX, gY, gW, gH = self:figmaToScreen(UI_CONFIG.layout.cropNextX + 8, UI_CONFIG.layout.headerY + 6, 9, 9)
        self:drawUITexture("glyph_arrow_right", gX, gY, gW, gH, nextGlyphCol)
    else
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        safeSetTextColor(nextGlyphCol)
        renderText(cNextX + cNextW * 0.5, cNextY + (cNextH - 11.5 * fScale * 0.72) * 0.5, 11.5 * fScale, ">")
    end
    table.insert(self.buttons, {
        x = cNextX, y = cNextY, w = cNextW, h = cNextH,
        callback = function() self:cycleCrop(1) end
    })

    -- Combine Model Title & Authentic Brand Terminal Name on Left
    local fullVehicleName = (v and v.getFullName and v:getFullName()) or (v and v:getName()) or "COMBINE"
    local fullUpper = string.upper(fullVehicleName)
    local titleX, titleY, _, titleH = self:figmaToScreen(20, UI_CONFIG.layout.headerY, 170, 21)

    local titleSize = 14.0 * fScale
    if getTextWidth then
        local tw = getTextWidth(titleSize, fullUpper)
        local maxTitleW = cPrevX - titleX - (6.0 / 802.0) * ui.w
        if tw and tw > maxTitleW and tw > 0 and maxTitleW > 0.02 then
            titleSize = math.max(9.0 * fScale, titleSize * (maxTitleW / tw))
        end
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.textWhite)
    renderText(titleX, titleY + titleH * 0.20, titleSize, fullUpper)

    -- Terminal Subtitle Name (e.g. CEBIS TOUCH, COMMANDCENTER 4600)
    local subX, subY, _, _ = self:figmaToScreen(20, 42, 170, 12)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.accent)
    renderText(subX, subY + (2.0 / 573.0) * ui.h, 10.0 * fScale, string.upper(theme.terminalName or "OPERATOR TERMINAL"))
end

---EN: Draws the sleek horizontal category tabs bar right below the header.
---UA: Малює горизонтальну смугу вкладок під заголовком планшета.
function RHMCombineCalibrationGUI:drawHorizontalTabs(theme)
    local ui = self.ui
    local fScale = ui.h / UI_CONFIG.layout.artboardH

    local tabDefs = {
        { id = 1, fX = 20, fY = UI_CONFIG.layout.tabY, fW = UI_CONFIG.layout.tabW, fH = UI_CONFIG.layout.tabH,
          labelKey = "rhm_ui_page_settings", default = "SETTINGS" },
        { id = 2, fX = 20 + UI_CONFIG.layout.tabW + UI_CONFIG.layout.tabGap, fY = UI_CONFIG.layout.tabY,
          fW = UI_CONFIG.layout.tabW, fH = UI_CONFIG.layout.tabH, labelKey = "rhm_ui_page_profiles", default = "PROFILES" },
    }

    for _, tab in ipairs(tabDefs) do
        local tX, tY, tW, tH = self:figmaToScreen(tab.fX, tab.fY, tab.fW, tab.fH)
        local isActive = (self.activeTab == tab.id)
        local isHovered = self:checkHover(tX, tY, tW, tH)

        local textColor
        if isActive then
            local activeTex = (isHovered and self.uiUVs and self.uiUVs["tab_active_hover"]) and "tab_active_hover" or "tab_active"
            if self.uiUVs and self.uiUVs[activeTex] then
                self:drawUITexture(activeTex, tX, tY, tW, tH, {1.0, 1.0, 1.0, 1.0})
            else
                self:drawRoundedBox(tX, tY, tW, tH, UI_CONFIG.colors.tabActiveBg, UI_CONFIG.colors.tabActiveBg, 5)
            end
            textColor = UI_CONFIG.colors.tabActiveText
        else
            local inactTex = (isHovered and self.uiUVs and self.uiUVs["tab_inactive_hover"]) and "tab_inactive_hover" or "tab_inactive"
            if self.uiUVs and self.uiUVs[inactTex] then
                self:drawUITexture(inactTex, tX, tY, tW, tH, {1.0, 1.0, 1.0, 1.0})
            else
                local tabBg = isHovered and {0.02, 0.02, 0.02, 0.50} or UI_CONFIG.colors.tabInactiveBg
                local tabBorder = isHovered and {1.0, 1.0, 1.0, 0.35} or UI_CONFIG.colors.tabInactiveBrd
                self:drawRoundedBox(tX, tY, tW, tH, tabBg, tabBorder, 5)
            end
            textColor = isHovered and UI_CONFIG.colors.textWhite or UI_CONFIG.colors.tabInactiveText
        end

        local label = (g_i18n and g_i18n:hasText(tab.labelKey)) and g_i18n:getText(tab.labelKey) or tab.default
        local upperLabel = string.upper(label)
        local tabFontSize = 11.5 * fScale

        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        safeSetTextColor(textColor)
        renderText(tX + tW * 0.5, tY + (tH - tabFontSize * 0.72) * 0.5, tabFontSize, upperLabel)

        table.insert(self.buttons, {
            x = tX, y = tY, w = tW, h = tH,
            callback = function()
                self.activeTab = tab.id
            end
        })
    end

    -- Subtle horizontal line extending to the right edge from tab 2 to screen right (372 to 782)
    local lX, lY, lW, lH = self:figmaToScreen(372, 80, 410, UI_CONFIG.layout.dividerH)
    if self.uiUVs and self.uiUVs["category_line"] then
        self:drawUITexture("category_line", lX, lY, lW, lH)
    else
        self:drawRect(lX, lY, lW, lH, UI_CONFIG.colors.dividerLine)
    end
end

---EN: Draws a high-definition 100-segment circular progress ring with dark circular disc backing.
---UA: Малює високоточне 100-сегментне кругове кільце прогресу з темним круглим диском-підкладкою.
function RHMCombineCalibrationGUI:drawProgressRing(centerX, centerY, width, height, ratio, arcColor, trackColor, discColor)
    if not self.atlasOverlay then return end

    -- 1. Dark circular disc backing
    if discColor and self.uiUVs and self.uiUVs["dial_disc"] then
        self.atlasOverlay:setDimension(width, height)
        self.atlasOverlay:setPosition(centerX - width * 0.5, centerY - height * 0.5)
        self.atlasOverlay:setUVs(self.uiUVs["dial_disc"])
        self.atlasOverlay:setColor(discColor[1], discColor[2], discColor[3], discColor[4] or 0.85)
        self.atlasOverlay:render()
    end

    -- 2. 100-Segment radial circular arc with increased line width
    local SEGMENT_WIDTH = 48 / 1024
    local SEGMENT_HEIGHT = 140 / 1024   -- Increased line thickness
    local RADIUS = 107 / 256
    local SEGMENTS = 100

    local segmentWidth = width * SEGMENT_WIDTH
    local segmentHeight = height * SEGMENT_HEIGHT
    local radiusX = width * RADIUS
    local radiusY = height * RADIUS
    local lit = math.floor(math.max(0, math.min(1, ratio or 0)) * SEGMENTS + 1e-6)

    self.atlasOverlay:setDimension(segmentWidth, segmentHeight)
    if self.uiUVs and self.uiUVs["dial_segment"] then
        self.atlasOverlay:setUVs(self.uiUVs["dial_segment"])
    end

    local aR, aG, aB, aA = arcColor[1], arcColor[2], arcColor[3], arcColor[4] or 1.0
    local tR, tG, tB, tA = trackColor[1], trackColor[2], trackColor[3], trackColor[4] or 0.35

    for index = 0, SEGMENTS - 1 do
        local angle = (index + 0.5) * 2 * math.pi / SEGMENTS
        if index < lit then
            self.atlasOverlay:setColor(aR, aG, aB, aA)
        else
            self.atlasOverlay:setColor(tR, tG, tB, tA)
        end
        self.atlasOverlay:setPosition(
            centerX + math.sin(angle) * radiusX - segmentWidth * 0.5,
            centerY + math.cos(angle) * radiusY - segmentHeight * 0.5
        )
        self.atlasOverlay:setRotation(-angle, segmentWidth * 0.5, segmentHeight * 0.5)
        self.atlasOverlay:render()
    end
    self.atlasOverlay:setRotation(0, 0, 0)
end

---EN: Draws the 3 live telemetry gauge cards with symmetrical horseshoe dials & real rolling history curves.
---UA: Малює 3 циферблатні картки живої телеметрії з симетричними шкалами та реальною кривою показників.
function RHMCombineCalibrationGUI:drawTelemetryCards(spec, memory, harvestContext, machineType, theme)
    local ui = self.ui
    local fScale = ui.h / 573.0

    local load = (spec.data and spec.data.load)
        or (spec.loadCalculator and spec.loadCalculator.getEngineLoad and spec.loadCalculator:getEngineLoad())
        or ((spec.loadCalculator and spec.loadCalculator.engineLoad or 0) * 100)

    local effPenalty = 0
    local lossPenalty = 0
    if memory and memory.currentCrop then
        effPenalty, lossPenalty, _ = memory:checkSettingsForCrop(memory.currentCrop, harvestContext)
    end
    local isArcadeMotor = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.difficultyMotor == 1)
    local isArcadeLoss = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.difficultyLoss == 1)
    if isArcadeMotor then
        effPenalty = 0
    end
    if isArcadeLoss then
        lossPenalty = 0
    end
    local efficiencyVal = math.max(0, 100.0 - math.max(0, effPenalty))

    local isForage = (machineType == "forage")
    local isCropLossEnabled = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableCropLoss)

    local cards = {
        {
            fX         = UI_CONFIG.layout.card1X,
            fY         = UI_CONFIG.layout.cardY,
            fW         = UI_CONFIG.layout.cardW,
            fH         = UI_CONFIG.layout.cardH,
            title      = (g_i18n and g_i18n:hasText("rhm_ui_card_engine_load")) and g_i18n:getText("rhm_ui_card_engine_load") or "ENGINE LOAD",
            valStr     = string.format("%.0f%%", load),
            ratio      = math.max(0, math.min(1, load / 100)),
            color      = (load > 95) and UI_CONFIG.colors.alertRed or ((load > 80) and UI_CONFIG.colors.availableYellow or UI_CONFIG.colors.activeGreen),
            icon       = "load",
        },
        {
            fX         = UI_CONFIG.layout.card2X,
            fY         = UI_CONFIG.layout.cardY,
            fW         = UI_CONFIG.layout.cardW,
            fH         = UI_CONFIG.layout.cardH,
            title      = (g_i18n and g_i18n:hasText("rhm_ui_card_speed_efficiency")) and g_i18n:getText("rhm_ui_card_speed_efficiency")
                or ((g_i18n and g_i18n:hasText("rhm_ui_card_efficiency")) and g_i18n:getText("rhm_ui_card_efficiency") or "SPEED EFFICIENCY"),
            valStr     = string.format("%.1f%%", efficiencyVal),
            ratio      = math.max(0, math.min(1, efficiencyVal / 100)),
            color      = (effPenalty <= 0.5) and UI_CONFIG.colors.activeGreen
                or ((effPenalty <= 5.0) and UI_CONFIG.colors.availableYellow
                or ((effPenalty <= 15.0) and UI_CONFIG.colors.criticalOrange or UI_CONFIG.colors.alertRed)),
            icon       = "speed",
        },
        {
            fX         = UI_CONFIG.layout.card3X,
            fY         = UI_CONFIG.layout.cardY,
            fW         = UI_CONFIG.layout.cardW,
            fH         = UI_CONFIG.layout.cardH,
            title      = (g_i18n and g_i18n:hasText("rhm_ui_card_predicted_loss")) and g_i18n:getText("rhm_ui_card_predicted_loss") or "PREDICTED LOSS",
            valStr     = (isForage or (not isCropLossEnabled)) and ((not isCropLossEnabled) and "OFF" or "N/A") or "",
            ratio      = 0.15,
            color      = UI_CONFIG.colors.activeGreen,
            icon       = "loss",
        }
    }

    if not (isForage or (not isCropLossEnabled)) then
        local settingsLoss = math.max(0, lossPenalty)
        local wearLoss = 0
        if spec.loadCalculator and self.activeVehicle then
            wearLoss = spec.loadCalculator:calculateWearLoss(self.activeVehicle) or 0
        end
        local isWearEnabled = (g_realisticHarvestManager and g_realisticHarvestManager.settings and g_realisticHarvestManager.settings.enableWearLoss ~= false)
        if not isWearEnabled or isArcadeLoss then
            wearLoss = 0
        end
        local displayLoss = settingsLoss + wearLoss
        cards[3].valStr = string.format("%.1f%%", displayLoss)
        cards[3].ratio = math.max(0, math.min(1, displayLoss / 3.0))
        cards[3].color = (displayLoss <= 0.05) and UI_CONFIG.colors.activeGreen
            or ((displayLoss <= 1.0) and UI_CONFIG.colors.availableYellow
            or ((displayLoss <= 2.5) and UI_CONFIG.colors.criticalOrange or UI_CONFIG.colors.alertRed))
    end

    local aspect = (g_screenWidth or 1920) / (g_screenHeight or 1080)

    for _, c in ipairs(cards) do
        local cX, cY, cW, cH = self:figmaToScreen(c.fX, c.fY, c.fW, c.fH)
        if self.uiUVs and self.uiUVs["card_telemetry"] then
            self:drawUITexture("card_telemetry", cX, cY, cW, cH, {1.0, 1.0, 1.0, 1.0})
        else
            self:drawRoundedBox(cX, cY, cW, cH, UI_CONFIG.colors.cardBg, UI_CONFIG.colors.cardBorder, 5, 2)
        end

        -- Perfectly centered circular gauge dial hub on left of card
        local ringH = cH * 0.76
        local ringW = ringH / aspect
        local dialCenterX = cX + ringW * 0.5 + (8.0 / 802.0) * ui.w
        local dialCenterY = cY + cH * 0.50

        -- Authentic FS25 100-segment progress ring with dark circular disc backing
        local trackCol = {UI_CONFIG.colors.textDim[1], UI_CONFIG.colors.textDim[2], UI_CONFIG.colors.textDim[3], 0.35}
        local discCol = {UI_CONFIG.colors.frameDark[1], UI_CONFIG.colors.frameDark[2], UI_CONFIG.colors.frameDark[3], 0.88}
        self:drawProgressRing(dialCenterX, dialCenterY, ringW, ringH, c.ratio, c.color, trackCol, discCol)

        -- Center Icon inside the ring (crisp and glowing)
        local iconSize = ringH * 0.40
        self:drawAtlasIcon(c.icon, dialCenterX - (iconSize / aspect) * 0.5, dialCenterY - iconSize * 0.5, iconSize, c.color)

        -- Right side of card: Metric Title and Large Bold Readout
        local textStartX = dialCenterX + ringW * 0.5 + (8.0 / 802.0) * ui.w
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(true)
        safeSetTextColor(UI_CONFIG.colors.cardTitleText)
        renderText(textStartX, cY + cH * 0.58, 10.5 * fScale, c.title)

        setTextBold(true)
        safeSetTextColor(c.color)
        renderText(textStartX, cY + cH * 0.18, 16.0 * fScale, c.valStr)
    end

    setTextBold(false)
end

---EN: Draws category header with green vertical notch and divider line.
---UA: Малює заголовок категорії із зеленим вертикальним пазом та розділювальною лінією.
function RHMCombineCalibrationGUI:drawCategoryHeader(fY, defaultTitle, i18nKey)
    local ui = self.ui
    local fScale = ui.h / UI_CONFIG.layout.artboardH

    local nX, nY, nW, nH = self:figmaToScreen(20, fY, UI_CONFIG.layout.notchW, UI_CONFIG.layout.notchH)
    if self.uiUVs and self.uiUVs["category_notch"] then
        self:drawUITexture("category_notch", nX, nY, nW, nH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(nX, nY, nW, nH, UI_CONFIG.colors.categoryNotch, UI_CONFIG.colors.categoryNotchBrd, UI_CONFIG.layout.notchRadius)
    end

    local lX, lY, lW, lH = self:figmaToScreen(UI_CONFIG.layout.dividerX, fY + 16, UI_CONFIG.layout.dividerW, UI_CONFIG.layout.dividerH)
    if self.uiUVs and self.uiUVs["category_line"] then
        self:drawUITexture("category_line", lX, lY, lW, lH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRect(lX, lY, lW, lH, UI_CONFIG.colors.dividerLine)
    end

    local title = (g_i18n and i18nKey and g_i18n:hasText(i18nKey)) and g_i18n:getText(i18nKey) or defaultTitle
    local tX, tY, _, _ = self:figmaToScreen(34, fY, 300, 14)
    local fontSize = 11.0 * fScale
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.textWhite)
    renderText(tX, tY + (nH - fontSize * 0.72) * 0.5, fontSize, string.upper(title))
end

---EN: Draws the [ALL] tab containing all subsystems compactly stacked.
---UA: Малює вкладку [ВСЕ], де всі підсистеми скомпоновані разом.
function RHMCombineCalibrationGUI:drawAllTab(spec, memory, activeParams, machineType, packageLevel, cachedCropSettings, theme)
    local sepParams = {}
    local clnParams = {}
    for _, p in ipairs(activeParams) do
        local sec = getParamSection(machineType, p)
        if sec == "SEPARATION" then
            table.insert(sepParams, p)
        else
            table.insert(clnParams, p)
        end
    end

    local curFigmaY = UI_CONFIG.layout.sec1NotchY

    -- 1. SEPARATION Category Header & Rows
    if #sepParams > 0 then
        self:drawCategoryHeader(curFigmaY, "SEPARATION", "rhm_ui_section_separation")
        local rowY = curFigmaY + 27

        for _, p in ipairs(sepParams) do
            local pKey = RHM_CombineSettingsDatabase:getParamLabel(machineType, p)
            local label = (g_i18n and g_i18n:hasText(pKey)) and g_i18n:getText(pKey) or p
            self:drawParameterRowFigma(rowY, p, label, memory, machineType, packageLevel, cachedCropSettings, theme, false)
            rowY = rowY + UI_CONFIG.layout.rowPitch
        end
        curFigmaY = rowY - UI_CONFIG.layout.rowPitch + (UI_CONFIG.layout.categoryGap or 31)
    end

    -- 2. CLEANING Category Header & Rows
    if #clnParams > 0 then
        self:drawCategoryHeader(curFigmaY, "CLEANING", "rhm_ui_section_cleaning")
        local rowY = curFigmaY + 28

        for _, p in ipairs(clnParams) do
            local pKey = RHM_CombineSettingsDatabase:getParamLabel(machineType, p)
            local label = (g_i18n and g_i18n:hasText(pKey)) and g_i18n:getText(pKey) or p
            self:drawParameterRowFigma(rowY, p, label, memory, machineType, packageLevel, cachedCropSettings, theme, false)
            rowY = rowY + UI_CONFIG.layout.rowPitch
        end
        curFigmaY = rowY - UI_CONFIG.layout.rowPitch + (UI_CONFIG.layout.categoryGap or 31)
    end

    -- 3. PERFORMANCE Category Header & Target Load Row
    self:drawCategoryHeader(curFigmaY, "PERFORMANCE", "rhm_ui_section_performance")
    local loadRowY = curFigmaY + 27

    local loadLabel = (g_i18n and g_i18n:hasText("rhm_target_load")) and g_i18n:getText("rhm_target_load") or "Target Engine Load"
    self:drawParameterRowFigma(loadRowY, "targetEngineLoad", loadLabel, memory, machineType, packageLevel, cachedCropSettings, theme, true)
end

---EN: Saves the current crop configuration profile directly under the active crop name.
---UA: Зберігає поточний профіль налаштувань культури під назвою активної культури.
function RHMCombineCalibrationGUI:openSaveProfileDialog(memory)
    if not memory then return end
    local cropName = memory.currentCrop or "WHEAT"
    local defaultTitle = cropName
    if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
        defaultTitle = RHM_CombineSettingsDatabase:getCropDisplayName(cropName)
    end

    local clean = tostring(defaultTitle or cropName)
    if memory.saveCurrentProfileNamed then
        memory:saveCurrentProfileNamed(clean, cropName)
    elseif memory.saveCurrentProfile then
        memory:saveCurrentProfile(cropName)
    end
    local msg = string.format(g_i18n:getText("rhm_msg_profile_saved") or "Profile saved: %s", clean)
    if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
        RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
    end
end

---EN: Draws the 4-button quick action footer: [RESET], [LOAD], [SAVE], [AI AUTO].
---UA: Малює 4 кнопки швидких дій у футері: [СКИДАННЯ], [ЗАВАНТАЖИТИ], [ЗБЕРЕГТИ], [AI АВТО].
function RHMCombineCalibrationGUI:drawActionFooter(memory, theme, packageLevel)
    local ui = self.ui
    local fScale = ui.h / UI_CONFIG.layout.artboardH

    -- 1. FACTORY RESET at (20, 518, 184, 34)
    local rX, rY, rW, rH = self:figmaToScreen(UI_CONFIG.layout.footerBtn1X, UI_CONFIG.layout.footerY, UI_CONFIG.layout.footerBtn1W, UI_CONFIG.layout.footerH)
    local resetBtnText = g_i18n:hasText("rhm_ui_btn_reset_defaults") and string.upper(g_i18n:getText("rhm_ui_btn_reset_defaults")) or "RESET TO FACTORY DEFAULTS"
    self:drawButton(rX, rY, rW, rH, resetBtnText, function()
        if memory and memory.requestResetSettings then memory:requestResetSettings() end
    end, UI_CONFIG.colors.btnResetBg, UI_CONFIG.colors.btnResetBorder, true, 12.0 * fScale, UI_CONFIG.colors.btnResetText, 5, "btn_footer_reset")

    -- 2. PROFILES at (210, 518, 184, 34)
    local pX, pY, pW, pH = self:figmaToScreen(UI_CONFIG.layout.footerBtn2X, UI_CONFIG.layout.footerY, UI_CONFIG.layout.footerBtn2W, UI_CONFIG.layout.footerH)
    local btnLoadText = g_i18n:hasText("rhm_ui_page_profiles") and string.upper(g_i18n:getText("rhm_ui_page_profiles")) or "PROFILES"
    self:drawButton(pX, pY, pW, pH, btnLoadText, function()
        self.activeTab = 2
    end, UI_CONFIG.colors.btnActionBg, UI_CONFIG.colors.btnActionBorder, true, 12.0 * fScale, UI_CONFIG.colors.btnActionText, 5, "btn_footer_action")

    -- 3. SAVE PROFILE at (400, 518, 184, 34)
    local sX, sY, sW, sH = self:figmaToScreen(UI_CONFIG.layout.footerBtn3X, UI_CONFIG.layout.footerY, UI_CONFIG.layout.footerBtn3W, UI_CONFIG.layout.footerH)
    local btnSaveText = g_i18n:hasText("rhm_ui_btn_save_profile") and string.upper(g_i18n:getText("rhm_ui_btn_save_profile")) or "SAVE PROFILE"
    self:drawButton(sX, sY, sW, sH, btnSaveText, function()
        if packageLevel >= 2 then
            self:openSaveProfileDialog(memory)
        else
            local msg = g_i18n:getText("rhm_msg_req_tier2") or "Requires Sensors Package (Tier 2)"
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
            end
        end
    end, UI_CONFIG.colors.btnActionBg, UI_CONFIG.colors.btnActionBorder, true, 12.0 * fScale, UI_CONFIG.colors.btnActionText, 5, "btn_footer_action")

    -- 4. AI AUTO-CALIBRATION at (590, 518, 188, 34)
    local aX, aY, aW, aH = self:figmaToScreen(UI_CONFIG.layout.footerBtn4X, UI_CONFIG.layout.footerY, UI_CONFIG.layout.footerBtn4W, UI_CONFIG.layout.footerH)
    if packageLevel >= 4 then
        local btnAutoText = g_i18n:hasText("rhm_ui_btn_ai_auto") and string.upper(g_i18n:getText("rhm_ui_btn_ai_auto")) or "AI AUTO-CALIB"
        self:drawButton(aX, aY, aW, aH, btnAutoText, function()
            if memory and memory.requestAutoSettings then memory:requestAutoSettings() end
        end, UI_CONFIG.colors.tabActiveBg, UI_CONFIG.colors.tabActiveBrd, true, 12.0 * fScale, UI_CONFIG.colors.tabActiveText, 5, "btn_footer_ai")
    else
        local btnLockedText = g_i18n:hasText("rhm_ui_btn_auto_locked") and string.upper(g_i18n:getText("rhm_ui_btn_auto_locked")) or "AI LOCKED"
        self:drawButton(aX, aY, aW, aH, btnLockedText, function()
            local msg = g_i18n:hasText("rhm_msg_req_tier4") and g_i18n:getText("rhm_msg_req_tier4") or "Requires Opti-Harvest AI (Tier 4)"
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
            end
        end, UI_CONFIG.colors.btnActionBg, UI_CONFIG.colors.btnActionBorder, true, 11.0 * fScale, UI_CONFIG.colors.textDim, 5, "btn_footer_action")
    end
end

---EN: Draws the [PROFILES] tab matching the exact Figma artboard layout.
---UA: Малює вкладку [ПРОФІЛІ] відповідно до піксель-перфект макета Figma.
function RHMCombineCalibrationGUI:drawProfilesTab(memory, theme, packageLevel)
    local pm = g_realisticHarvestManager and g_realisticHarvestManager.profileManager
    local profiles = (pm and pm.getNamedProfiles and pm:getNamedProfiles()) or {}
    local fScale = self.ui.h / 573.0

    -- 1. Section Header & Green Notch at (19, 84)
    local nX, nY, nW, nH = self:figmaToScreen(19, 84, UI_CONFIG.layout.notchW, UI_CONFIG.layout.notchH)
    if self.uiUVs and self.uiUVs["category_notch"] then
        self:drawUITexture("category_notch", nX, nY, nW, nH)
    else
        self:drawRoundedBox(nX, nY, nW, nH, UI_CONFIG.colors.categoryNotch, UI_CONFIG.colors.categoryNotchBrd, UI_CONFIG.layout.notchRadius)
    end

    local pTitle = g_i18n:hasText("rhm_ui_page_profiles") and string.upper(g_i18n:getText("rhm_ui_page_profiles")) or "PROFILES"
    local pSubTitle = (g_i18n and g_i18n:hasText("rhm_ui_profiles_subtitle")) and g_i18n:getText("rhm_ui_profiles_subtitle") or "SAVED CROP CONFIGURATIONS"
    local fullTitle = pTitle .. " - " .. pSubTitle
    local tX, tY, _, tH = self:figmaToScreen(33, 84, 700, 16)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.textWhite)
    local secTitleSize = 11.0 * fScale
    renderText(tX, tY + (tH - secTitleSize * 0.72) * 0.5, secTitleSize, fullTitle)

    -- Divider Line at (25, 100, 753, 2)
    local lX, lY, lW, lH = self:figmaToScreen(25, 100, 753, UI_CONFIG.layout.dividerH)
    if self.uiUVs and self.uiUVs["category_line"] then
        self:drawUITexture("category_line", lX, lY, lW, lH)
    else
        self:drawRect(lX, lY, lW, lH, UI_CONFIG.colors.dividerLine)
    end

    -- 2. Rounded Table Column Header Bar at (19, 109, 763, 21) (Vector-14.png)
    local thX, thY, thW, thH = self:figmaToScreen(19, 109, 763, 21)
    if self.uiUVs and self.uiUVs["profile_table_header"] then
        self:drawUITexture("profile_table_header", thX, thY, thW, thH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(thX, thY, thW, thH, UI_CONFIG.colors.cardBg, UI_CONFIG.colors.cardBorder, 4)
    end

    local thCol1 = (g_i18n and g_i18n:hasText("rhm_ui_profiles_col_name")) and g_i18n:getText("rhm_ui_profiles_col_name") or "PROFILE NAME"
    local thCol2 = (g_i18n and g_i18n:hasText("rhm_ui_profiles_col_breakdown"))
        and g_i18n:getText("rhm_ui_profiles_col_breakdown") or "BREAKDOWN (ROTOR / CONCAVE / FAN / SIEVES / LOAD)"
    local thCol3 = (g_i18n and g_i18n:hasText("rhm_ui_profiles_col_crop")) and g_i18n:getText("rhm_ui_profiles_col_crop") or "CROP"

    local col1X, _, _, _ = self:figmaToScreen(32, 109, 150, 21)
    local col2X, _, _, _ = self:figmaToScreen(200, 109, 450, 21)
    local col3CenterX, _, _, _ = self:figmaToScreen(681 + 44.5, 109, 1, 21)

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.textDim)
    local thFontSize = 9.0 * fScale
    local thTextY = thY + (thH - thFontSize * 0.72) * 0.5
    renderText(col1X, thTextY, thFontSize, thCol1)
    renderText(col2X, thTextY, thFontSize, thCol2)

    setTextAlignment(RenderText.ALIGN_CENTER)
    renderText(col3CenterX, thTextY, thFontSize, thCol3)
    setTextAlignment(RenderText.ALIGN_LEFT)

    -- 3. Profiles List Container
    local maxVisible = 7
    if not self.selectedProfileIndex or self.selectedProfileIndex > #profiles or self.selectedProfileIndex < 1 then
        self.selectedProfileIndex = 1
    end
    self.profileScrollOffset = self.profileScrollOffset or 0
    if self.profileScrollOffset > #profiles - maxVisible then
        self.profileScrollOffset = math.max(0, #profiles - maxVisible)
    end

    if #profiles == 0 then
        local eX, eY, eW, eH = self:figmaToScreen(20, 200, 762, 100)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        safeSetTextColor(UI_CONFIG.colors.textWhite)
        local noProfTxt = g_i18n:hasText("rhm_msg_profile_not_found") and g_i18n:getText("rhm_msg_profile_not_found") or "No saved profiles found"
        renderText(eX + eW * 0.5, eY + eH * 0.6, 13.0 * fScale, noProfTxt)

        setTextBold(false)
        safeSetTextColor(UI_CONFIG.colors.textDim)
        local noProfSub = (g_i18n and g_i18n:hasText("rhm_ui_profiles_empty_sub")) and g_i18n:getText("rhm_ui_profiles_empty_sub")
            or "Configure settings in the SETTINGS tab and click [SAVE PROFILE] to save custom presets."
        renderText(eX + eW * 0.5, eY + eH * 0.35, 10.0 * fScale, noProfSub)
    else
        local startIdx = self.profileScrollOffset + 1
        local endIdx = math.min(#profiles, startIdx + maxVisible - 1)

        for i = startIdx, endIdx do
            local prof = profiles[i]
            local rowTop = 136 + (i - startIdx) * 51
            local isSelected = (self.selectedProfileIndex == i)
            local rX, rY, rW, rH = self:figmaToScreen(19, rowTop - 1, 764, 46)
            local isHovered = self:checkHover(rX, rY, rW, rH)

            local rowTexKey
            local titleColor
            local summaryColor

            if isSelected then
                rowTexKey = (isHovered and self.uiUVs and self.uiUVs["profile_row_sel_hover"]) and "profile_row_sel_hover" or "profile_row_sel"
                titleColor = {0.05, 0.07, 0.05, 1.0}
                summaryColor = {0.14, 0.22, 0.03, 1.0}
            else
                rowTexKey = (isHovered and self.uiUVs and self.uiUVs["profile_row_hover"]) and "profile_row_hover" or "profile_row_unsel"
                titleColor = UI_CONFIG.colors.textWhite
                summaryColor = isHovered and UI_CONFIG.colors.tabInactiveText or UI_CONFIG.colors.textDim
            end

            if self.uiUVs and self.uiUVs[rowTexKey] then
                self:drawUITexture(rowTexKey, rX, rY, rW, rH, {1.0, 1.0, 1.0, 1.0})
            else
                local rowBg = isSelected and UI_CONFIG.colors.tabActiveBg or UI_CONFIG.colors.cardBg
                local rowBorder = isSelected and UI_CONFIG.colors.tabActiveBrd or UI_CONFIG.colors.cardBorder
                self:drawRoundedBox(rX, rY, rW, rH, rowBg, rowBorder, 4)
            end

            table.insert(self.buttons, {
                x = rX, y = rY, w = rW, h = rH,
                callback = function()
                    self.selectedProfileIndex = i
                end
            })

            local textLeftX, _, _, _ = self:figmaToScreen(32, rowTop, 400, 44)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextBold(true)
            safeSetTextColor(titleColor)
            local pNameSize = 13.0 * fScale
            renderText(textLeftX, rY + rH * 0.56, pNameSize, tostring(prof.name or prof.cropName))

            local s = prof.settings or {}
            local summaryFmt = (g_i18n and g_i18n:hasText("rhm_ui_profile_summary_fmt")) and g_i18n:getText("rhm_ui_profile_summary_fmt")
                or "Rotor: %d%% | Concave: %d%% | Fan: %d%% | Sieves: %d / %d%% | Load: %d%%"
            local summaryStr = string.format(summaryFmt,
                s.rotor or 50, s.feeder or 50, s.fan or 50, s.upperSieve or 50, s.lowerSieve or 50, s.targetEngineLoad or 80)
            setTextBold(isSelected)
            safeSetTextColor(summaryColor)
            local pSubSize = 9.5 * fScale
            renderText(textLeftX, rY + rH * 0.18, pSubSize, summaryStr)

            local cropDisplayName = tostring(prof.cropName or "UNKNOWN")
            if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
                cropDisplayName = RHM_CombineSettingsDatabase:getCropDisplayName(prof.cropName)
            end
            local badgeX, badgeY, badgeW, badgeH = self:figmaToScreen(681, rowTop + 11, 89, 21)
            local badgeTexKey = isSelected and "profile_badge_sel" or "profile_badge_unsel"
            local badgeTextColor = isSelected and UI_CONFIG.colors.tabActiveBg or UI_CONFIG.colors.tabInactiveText

            if self.uiUVs and self.uiUVs[badgeTexKey] then
                self:drawUITexture(badgeTexKey, badgeX, badgeY, badgeW, badgeH, {1.0, 1.0, 1.0, 1.0})
            else
                local badgeBg = isSelected and {0.05, 0.07, 0.05, 0.90} or {0.02, 0.02, 0.02, 0.85}
                local badgeBorder = isSelected and {0.05, 0.07, 0.05, 1.0} or UI_CONFIG.colors.cardBorder
                self:drawRoundedBox(badgeX, badgeY, badgeW, badgeH, badgeBg, badgeBorder, 4)
            end
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextBold(true)
            safeSetTextColor(badgeTextColor)
            local bFontSize = 9.0 * fScale
            renderText(badgeX + badgeW * 0.5, badgeY + (badgeH - bFontSize * 0.72) * 0.5, bFontSize, string.upper(cropDisplayName))
        end

        if #profiles > maxVisible then
            local pUpX, pUpY, pUpW, pUpH = self:figmaToScreen(718, 109, 28, 21)
            self:drawButton(pUpX, pUpY, pUpW, pUpH, "^", function()
                if self.profileScrollOffset > 0 then
                    self.profileScrollOffset = self.profileScrollOffset - 1
                end
            end, UI_CONFIG.colors.cardBg, UI_CONFIG.colors.cardBorder, true, 10.0 * fScale, UI_CONFIG.colors.textWhite, 4, "btn_arrow_left")

            local pDownX, pDownY, pDownW, pDownH = self:figmaToScreen(750, 109, 28, 21)
            self:drawButton(pDownX, pDownY, pDownW, pDownH, "v", function()
                if self.profileScrollOffset < #profiles - maxVisible then
                    self.profileScrollOffset = self.profileScrollOffset + 1
                end
            end, UI_CONFIG.colors.cardBg, UI_CONFIG.colors.cardBorder, true, 10.0 * fScale, UI_CONFIG.colors.textWhite, 4, "btn_arrow_right")
        end
    end

    -- 4. Footer Action Buttons at (19, 517)
    local flX, flY, flW, flH = self:figmaToScreen(24, 507, 753, UI_CONFIG.layout.dividerH)
    if self.uiUVs and self.uiUVs["category_line"] then
        self:drawUITexture("category_line", flX, flY, flW, flH)
    else
        self:drawRect(flX, flY, flW, flH, UI_CONFIG.colors.dividerLine)
    end

    local bX, bY, bW, bH = self:figmaToScreen(
        UI_CONFIG.layout.footerBtn1X, UI_CONFIG.layout.footerY, UI_CONFIG.layout.footerBtn1W, UI_CONFIG.layout.footerH
    )
    local btnBackText = (g_i18n and g_i18n:hasText("button_back") and string.upper(g_i18n:getText("button_back"))) or "BACK"
    self:drawButton(bX, bY, bW, bH, btnBackText, function()
        self.activeTab = 1
    end, UI_CONFIG.colors.btnActionBg, UI_CONFIG.colors.btnActionBorder, true, 12.0 * fScale, UI_CONFIG.colors.btnActionText, 5, "btn_footer_action")

    local dX, dY, dW, dH = self:figmaToScreen(
        UI_CONFIG.layout.footerBtn2X, UI_CONFIG.layout.footerY, UI_CONFIG.layout.footerBtn2W, UI_CONFIG.layout.footerH
    )
    local btnDelText = (g_i18n and g_i18n:hasText("rhm_ui_profile_delete") and string.upper(g_i18n:getText("rhm_ui_profile_delete"))) or "DELETE"
    self:drawButton(dX, dY, dW, dH, btnDelText, function()
        if pm and self.selectedProfileIndex and profiles[self.selectedProfileIndex] then
            local toDelete = profiles[self.selectedProfileIndex]
            pm:deleteNamedProfile(toDelete.id or self.selectedProfileIndex)
            if self.selectedProfileIndex > 1 then
                self.selectedProfileIndex = self.selectedProfileIndex - 1
            end
            local delPrefix = (g_i18n and g_i18n:hasText("rhm_ui_profile_delete") and g_i18n:getText("rhm_ui_profile_delete")) or "DELETE"
            local msg = delPrefix .. ": " .. tostring(toDelete.name or "")
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 3000)
            end
        end
    end, UI_CONFIG.colors.btnDeleteBg, UI_CONFIG.colors.btnDeleteBorder, true, 12.0 * fScale, UI_CONFIG.colors.btnDeleteText, 5, "btn_footer_reset")

    local loadX, loadY, loadW, loadH = self:figmaToScreen(
        UI_CONFIG.layout.footerLoadX, UI_CONFIG.layout.footerY, UI_CONFIG.layout.footerLoadW, UI_CONFIG.layout.footerH
    )
    local btnApplyText = (g_i18n and g_i18n:hasText("rhm_ui_btn_load_preset") and string.upper(g_i18n:getText("rhm_ui_btn_load_preset")))
        or ((g_i18n and g_i18n:hasText("rhm_ui_btn_load_combine") and string.upper(g_i18n:getText("rhm_ui_btn_load_combine"))) or "LOAD PRESET")
    self:drawButton(loadX, loadY, loadW, loadH, btnApplyText, function()
        if (packageLevel or 1) < 2 then
            local msg = (g_i18n and g_i18n:hasText("rhm_msg_req_tier2") and g_i18n:getText("rhm_msg_req_tier2"))
                     or (g_i18n and g_i18n:hasText("rhm_msg_req_tier3") and g_i18n:getText("rhm_msg_req_tier3"))
                     or "Profiles require Sensors Package (Tier 2)"
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
            elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                g_currentMission.hud:showInGameMessage("Realistic Harvesting", msg, -1)
            end
            return
        end
        if pm and self.selectedProfileIndex and profiles[self.selectedProfileIndex] then
            local sel = profiles[self.selectedProfileIndex]
            if memory and memory.applySettingsProfile then
                memory:applySettingsProfile(sel.settings, sel.cropName)
            elseif memory and memory.loadUserPreset then
                memory:switchCrop(sel.cropName)
                memory:loadUserPreset()
            end
            local msg = string.format(g_i18n:getText("rhm_msg_profile_loaded") or "Loaded: %s", tostring(sel.name or sel.cropName))
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("Realistic Harvesting", msg, 4000)
            end
            self.activeTab = 1
        end
    end, UI_CONFIG.colors.tabActiveBg, UI_CONFIG.colors.tabActiveBrd, true, 12.0 * fScale, UI_CONFIG.colors.tabActiveText, 5, "btn_footer_load")
end

---EN: Draws an interactive parameter slider row with sweet-spot optimal band, micro-buttons, and physical readout matching Figma specs.
---UA: Малює рядок параметра зі слайдером, кнопками [-]/[+], статусом та фізичними одиницями за координатами Figma.
function RHMCombineCalibrationGUI:drawParameterRowFigma(rowTop, param, label, memory, machineType, packageLevel, cachedCropSettings, theme, isWideTrack)
    local val = memory.currentSettings[param] or 0
    local optimal = 0
    local tolerance = 5
    local isOptimal = false
    local hasOptimal = false
    local fScale = self.ui.h / 573.0

    local rowHitX, rowHitY, rowHitW, rowHitH = self:figmaToScreen(20, rowTop - 4, 762, 30)
    if self:checkHover(rowHitX, rowHitY, rowHitW, rowHitH) then
        self.hoveredParameter = param
    end

    if cachedCropSettings and cachedCropSettings[param] ~= nil then
        local pSetting = cachedCropSettings[param]
        if type(pSetting) == "table" then
            optimal = tonumber(pSetting.optimal) or 0
            tolerance = tonumber(pSetting.tolerance) or 5
        else
            optimal = tonumber(pSetting) or 0
            tolerance = 5
        end
        hasOptimal = true
        local diff = math.abs(val - optimal)
        isOptimal = (diff <= tolerance)
    end

    local displayStr = ""
    if param == "targetEngineLoad" then
        displayStr = string.format("%d%%", val)
    elseif RHM_UnitConverter and RHM_UnitConverter.formatSetting then
        displayStr = RHM_UnitConverter.formatSetting(param, val, machineType)
    elseif RHM_UnitConverter and RHM_UnitConverter.percentToPhysical and RHM_UnitConverter.getPhysicalRange then
        local phys = RHM_UnitConverter.percentToPhysical(param, val, machineType)
        local range = RHM_UnitConverter.getPhysicalRange(param, machineType)
        if range and range.unit == "RPM" then
            displayStr = string.format("%.0f %s", phys, range.unit)
        elseif range then
            displayStr = string.format("%.1f %s", phys, range.unit)
        else
            displayStr = string.format("%d%%", val)
        end
    else
        displayStr = string.format("%d%%", val)
    end

    -- 1. Parameter Label & Subtitle on Left
    local lX, lY, lW, lH = self:figmaToScreen(20, rowTop, 200, 24)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.textWhite)
    local titleSize = 13.5 * fScale
    renderText(lX, lY + lH * 0.55, titleSize, label)

    local subtitle = getParamSubtitle(machineType, param)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.textDim)
    local subSize = 10.0 * fScale
    renderText(lX, lY + lH * 0.12, subSize, subtitle)

    -- 2. Micro-Step Minus [-] Button at (224, rowTop, 33, 21)
    local mX, mY, mW, mH = self:figmaToScreen(
        UI_CONFIG.layout.btnMinusX, rowTop, UI_CONFIG.layout.btnStepW, UI_CONFIG.layout.btnStepH
    )
    local isMinusHovered = self:checkHover(mX, mY, mW, mH)
    local minusTex = (isMinusHovered and self.uiUVs and self.uiUVs["btn_step_hover"]) and "btn_step_hover" or "btn_step"
    local minusGlyphCol = isMinusHovered and UI_CONFIG.colors.textWhite or UI_CONFIG.colors.btnStepText
    if self.uiUVs and self.uiUVs[minusTex] then
        self:drawUITexture(minusTex, mX, mY, mW, mH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(mX, mY, mW, mH, UI_CONFIG.colors.btnStepBg, UI_CONFIG.colors.btnStepBorder, 5)
    end
    if self.uiUVs and self.uiUVs["glyph_minus"] then
        local gX, gY, gW, gH = self:figmaToScreen(UI_CONFIG.layout.btnMinusX + 12, rowTop + 9, 9, 3)
        self:drawUITexture("glyph_minus", gX, gY, gW, gH, minusGlyphCol)
    else
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        safeSetTextColor(minusGlyphCol)
        renderText(mX + mW * 0.5, mY + (mH - 13.0 * fScale * 0.72) * 0.5, 13.0 * fScale, "-")
    end
    table.insert(self.buttons, {
        x = mX, y = mY, w = mW, h = mH,
        callback = function()
            local isFast = Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift)
            self:stepParameter(param, -1, isFast)
        end
    })

    -- 3. Slider Track, Rounded Lime Fill & Metallic Thumb
    local trackFWidth = isWideTrack and UI_CONFIG.layout.trackWideW or UI_CONFIG.layout.trackStdW
    local tX, tY, tW, tH = self:figmaToScreen(UI_CONFIG.layout.trackX, rowTop + 5, trackFWidth, UI_CONFIG.layout.trackH)

    local isDraggingThis = (self.draggingSlider ~= nil and self.draggingSlider.param == param)
    local fillRatio
    if isDraggingThis and self.draggingSliderRatio ~= nil then
        fillRatio = self.draggingSliderRatio
    else
        fillRatio = (param == "targetEngineLoad") and ((val - 70) / 30.0) or (val / 100.0)
    end
    fillRatio = math.max(0.0, math.min(1.0, fillRatio))
    local thFLeft = UI_CONFIG.layout.trackX + (fillRatio * trackFWidth) - (UI_CONFIG.layout.thumbW * 0.5)
    local thX, thY, thW, thH = self:figmaToScreen(thFLeft, rowTop, UI_CONFIG.layout.thumbW, UI_CONFIG.layout.thumbH)

    local isSliderActive = isDraggingThis
        or self:checkHover(tX, tY - 0.005, tW, tH + 0.010)
        or self:checkHover(thX, thY, thW, thH)

    local trackTex = isWideTrack and "slider_track_wide" or "slider_track_std"
    if isSliderActive then
        local trackHoverKey = trackTex .. "_hover"
        if self.uiUVs and self.uiUVs[trackHoverKey] then
            trackTex = trackHoverKey
        end
    end

    if self.uiUVs and self.uiUVs[trackTex] then
        self:drawUITexture(trackTex, tX, tY, tW, tH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(tX, tY, tW, tH, UI_CONFIG.colors.trackGroove, UI_CONFIG.colors.trackBorder, 4)
    end

    -- Active Value Fill in Lime (#86B500) with authentic rounded left cap (Vector-40.png)
    local fillFPx = fillRatio * (trackFWidth - 2)
    if fillFPx >= 1.0 then
        if self.uiUVs and self.uiUVs["slider_fill_cap"] and self.uiUVs["slider_fill_body"] then
            local capFW = math.min(4.0, fillFPx)
            local capX, capY, capW, capH = self:figmaToScreen(UI_CONFIG.layout.trackX + 1, rowTop + 6, capFW, 8)
            self:drawUITexture("slider_fill_cap", capX, capY, capW, capH, {1.0, 1.0, 1.0, 1.0})
            if fillFPx > 4.0 then
                local bodyX, bodyY, bodyW, bodyH = self:figmaToScreen(UI_CONFIG.layout.trackX + 5, rowTop + 6, fillFPx - 4.0, 8)
                self:drawUITexture("slider_fill_body", bodyX, bodyY, bodyW, bodyH, {1.0, 1.0, 1.0, 1.0})
            end
        else
            local currentFillW = fillRatio * tW
            local inPadY = (1.0 / 573.0) * self.ui.h
            self:drawRect(tX + 0.001, tY + inPadY, math.max(0.0001, currentFillW - 0.002), tH - inPadY * 2, UI_CONFIG.colors.trackFill)
        end
    end

    -- Sweet Spot Ticks (Sensor / Opti Package)
    if theme.hasSweetSpot and hasOptimal and optimal then
        local optRatio = (param == "targetEngineLoad") and ((optimal - 70) / 30.0) or (optimal / 100.0)
        local tolRatio = (param == "targetEngineLoad") and (tolerance / 30.0) or (tolerance / 100.0)
        local optMinRatio = math.max(0.0, math.min(1.0, optRatio - tolRatio))
        local optMaxRatio = math.max(0.0, math.min(1.0, optRatio + tolRatio))

        local tkMinX, tkY, tkW, tkH = self:figmaToScreen(UI_CONFIG.layout.trackX + optMinRatio * trackFWidth - 2, rowTop + 2, 4, 16)
        local tkMaxX, _, _, _ = self:figmaToScreen(UI_CONFIG.layout.trackX + optMaxRatio * trackFWidth - 2, rowTop + 2, 4, 16)

        if self.uiUVs and self.uiUVs["slider_tick"] then
            self:drawUITexture("slider_tick", tkMinX, tkY, tkW, tkH)
            if math.abs(optMaxRatio - optMinRatio) > 0.005 then
                self:drawUITexture("slider_tick", tkMaxX, tkY, tkW, tkH)
            end
        else
            local function drawProceduralTick(r)
                local cX = UI_CONFIG.layout.trackX + r * trackFWidth
                local oX, oY, oW, oH = self:figmaToScreen(cX - 2, rowTop + 2, 4, 16)
                local iX, iY, iW, iH = self:figmaToScreen(cX - 1, rowTop + 3, 2, 14)
                self:drawRect(oX, oY, oW, oH, UI_CONFIG.colors.chassisBg)
                self:drawRect(iX, iY, iW, iH, UI_CONFIG.colors.accent)
            end
            drawProceduralTick(optMinRatio)
            if math.abs(optMaxRatio - optMinRatio) > 0.005 then
                drawProceduralTick(optMaxRatio)
            end
        end
    end

    -- Tactile Metallic Thumb Handle (15x20 px centered on track, highlighted on hover/drag)
    local thumbTex = (isSliderActive and self.uiUVs and self.uiUVs["slider_thumb_hover"]) and "slider_thumb_hover" or "slider_thumb"
    if self.uiUVs and self.uiUVs[thumbTex] then
        self:drawUITexture(thumbTex, thX, thY, thW, thH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(thX, thY, thW, thH, UI_CONFIG.colors.thumbBg, UI_CONFIG.colors.thumbBorder, 4)
    end

    if isDraggingThis then
        self.draggingSlider.trackX = tX
        self.draggingSlider.trackW = tW
    end
    table.insert(self.sliders, {
        x = tX - thW * 0.5,
        y = thY - 0.004,
        w = tW + thW,
        h = thH + 0.008,
        trackX = tX,
        trackW = tW,
        param = param
    })

    -- 4. Micro-Step Plus [+] Button
    local plusFLeft = isWideTrack and UI_CONFIG.layout.btnPlusWideX or UI_CONFIG.layout.btnPlusStdX
    local pX, pY, pW, pH = self:figmaToScreen(plusFLeft, rowTop, UI_CONFIG.layout.btnStepW, UI_CONFIG.layout.btnStepH)
    local isPlusHovered = self:checkHover(pX, pY, pW, pH)
    local plusTex = (isPlusHovered and self.uiUVs and self.uiUVs["btn_step_hover"]) and "btn_step_hover" or "btn_step"
    local plusGlyphCol = isPlusHovered and UI_CONFIG.colors.textWhite or UI_CONFIG.colors.btnStepText
    if self.uiUVs and self.uiUVs[plusTex] then
        self:drawUITexture(plusTex, pX, pY, pW, pH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(pX, pY, pW, pH, UI_CONFIG.colors.btnStepBg, UI_CONFIG.colors.btnStepBorder, 5)
    end
    if self.uiUVs and self.uiUVs["glyph_plus"] then
        local gX, gY, gW, gH = self:figmaToScreen(plusFLeft + 12, rowTop + 6, 9, 9)
        self:drawUITexture("glyph_plus", gX, gY, gW, gH, plusGlyphCol)
    else
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        safeSetTextColor(plusGlyphCol)
        renderText(pX + pW * 0.5, pY + (pH - 13.0 * fScale * 0.72) * 0.5, 13.0 * fScale, "+")
    end
    table.insert(self.buttons, {
        x = pX, y = pY, w = pW, h = pH,
        callback = function()
            local isFast = Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift)
            self:stepParameter(param, 1, isFast)
        end
    })

    -- 5. Status Pill (Standard Rows 1-5 only)
    if not isWideTrack then
        local sX, sY, sW, sH = self:figmaToScreen(UI_CONFIG.layout.statusPillX, rowTop, UI_CONFIG.layout.statusPillW, UI_CONFIG.layout.statusPillH)
        local statusText = ""
        local statusTexKey = "pill_status_optimal"
        local statusTextColor = UI_CONFIG.colors.textDim

        if theme.hasSweetSpot and hasOptimal then
            if isOptimal then
                statusText = (g_i18n and g_i18n:hasText("rhm_ui_status_optimal")) and g_i18n:getText("rhm_ui_status_optimal") or "OPTIMAL"
                statusTexKey = "pill_status_optimal"
                statusTextColor = UI_CONFIG.colors.statusOptimalTxt
            elseif val < optimal then
                statusText = (g_i18n and g_i18n:hasText("rhm_ui_status_low")) and g_i18n:getText("rhm_ui_status_low") or "LOW"
                local isSevere = (optimal - val) > 20
                statusTexKey = isSevere and "pill_status_alert" or "pill_status_warning"
                statusTextColor = isSevere and UI_CONFIG.colors.statusAlertTxt or UI_CONFIG.colors.statusWarningTxt
            else
                statusText = (g_i18n and g_i18n:hasText("rhm_ui_status_high")) and g_i18n:getText("rhm_ui_status_high") or "HIGH"
                local isSevere = (val - optimal) > 20
                statusTexKey = isSevere and "pill_status_alert" or "pill_status_warning"
                statusTextColor = isSevere and UI_CONFIG.colors.statusAlertTxt or UI_CONFIG.colors.statusWarningTxt
            end
        else
            statusText = "--"
        end

        if self.uiUVs and self.uiUVs[statusTexKey] then
            self:drawUITexture(statusTexKey, sX, sY, sW, sH, {1.0, 1.0, 1.0, 1.0})
        else
            self:drawRoundedBox(sX, sY, sW, sH, UI_CONFIG.colors.cardBg, UI_CONFIG.colors.cardBorder, 5)
        end

        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        safeSetTextColor(statusTextColor)
        local sFontSize = 10.5 * fScale
        renderText(sX + sW * 0.5, sY + (sH - sFontSize * 0.72) * 0.5, sFontSize, statusText)
    end

    -- 6. Physical Value Box at (668, rowTop, 110, 21)
    local vX, vY, vW, vH = self:figmaToScreen(UI_CONFIG.layout.valueBoxX, rowTop, UI_CONFIG.layout.valueBoxW, UI_CONFIG.layout.valueBoxH)
    if self.uiUVs and self.uiUVs["pill_value"] then
        self:drawUITexture("pill_value", vX, vY, vW, vH, {1.0, 1.0, 1.0, 1.0})
    else
        self:drawRoundedBox(vX, vY, vW, vH, UI_CONFIG.colors.pillValueBg, UI_CONFIG.colors.pillValueBorder, 5)
    end

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    safeSetTextColor(UI_CONFIG.colors.pillValueText)
    local vFontSize = 11.5 * fScale
    renderText(vX + vW * 0.5, vY + (vH - vFontSize * 0.72) * 0.5, vFontSize, displayStr)
end

---EN: Backward compatibility alias for parameter row drawing.
function RHMCombineCalibrationGUI:drawParameterRow(x, y, w, param, label, memory, ui, machineType, packageLevel, cachedCropSettings, theme)
    self:drawParameterRowFigma(165, param, label, memory, machineType, packageLevel, cachedCropSettings, theme, param == "targetEngineLoad")
end



function RHMCombineCalibrationGUI:drawPanelBackground(x, y, w, h, color, cornerSizePx)
    if not self.roundedOverlay or not self.roundedUVs then
        self:drawRect(x, y, w, h, color)
        return
    end

    local r, g, b, a = resolveColorRGBA(color, 0.85)

    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local snappedX = math.floor(x * screenW + 0.5) / screenW
    local snappedY = math.floor(y * screenH + 0.5) / screenH
    local snappedW = math.max(math.floor(w * screenW + 0.5) / screenW, 1 / screenW)
    local snappedH = math.max(math.floor(h * screenH + 0.5) / screenH, 1 / screenH)

    local cornerPx = cornerSizePx or 5
    local cornerW = math.min(math.floor((cornerPx / screenW) * screenW + 0.5) / screenW, snappedW * 0.5)
    local cornerH = math.min(math.floor((cornerPx / screenH) * screenH + 0.5) / screenH, snappedH * 0.5)

    local leftX = snappedX
    local centerX = snappedX + cornerW
    local rightX = snappedX + snappedW - cornerW
    local bottomY = snappedY
    local centerY = snappedY + cornerH
    local topY = snappedY + snappedH - cornerH
    local centerW = math.max(rightX - centerX, 0)
    local centerH = math.max(topY - centerY, 0)

    local overlay = self.roundedOverlay
    overlay:setColor(r, g, b, a)

    local uvs = self.roundedUVs
    renderPanelSlice(overlay, leftX, bottomY, cornerW, cornerH, uvs.bottomLeft)
    renderPanelSlice(overlay, centerX, bottomY, centerW, cornerH, uvs.bottom)
    renderPanelSlice(overlay, rightX, bottomY, cornerW, cornerH, uvs.bottomRight)

    renderPanelSlice(overlay, leftX, centerY, cornerW, centerH, uvs.left)
    renderPanelSlice(overlay, centerX, centerY, centerW, centerH, uvs.center)
    renderPanelSlice(overlay, rightX, centerY, cornerW, centerH, uvs.right)

    renderPanelSlice(overlay, leftX, topY, cornerW, cornerH, uvs.topLeft)
    renderPanelSlice(overlay, centerX, topY, centerW, cornerH, uvs.top)
    renderPanelSlice(overlay, rightX, topY, cornerW, cornerH, uvs.topRight)
end

function RHMCombineCalibrationGUI:drawRoundedBox(x, y, w, h, fillCol, borderCol, cornerPx, borderThicknessPx)
    cornerPx = cornerPx or 4
    if fillCol then
        self:drawPanelBackground(x, y, w, h, fillCol, cornerPx)
    end
    if borderCol then
        self:drawBorder(x, y, w, h, borderCol, borderThicknessPx or 1)
    end
end

function RHMCombineCalibrationGUI:drawRect(x, y, w, h, color)
    if not self.overlay or not color then return end
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local px = math.floor(x * screenW + 0.5) / screenW
    local py = math.floor(y * screenH + 0.5) / screenH
    local pw = math.max(math.floor(w * screenW + 0.5) / screenW, 1 / screenW)
    local ph = math.max(math.floor(h * screenH + 0.5) / screenH, 1 / screenH)

    local r, g, b, a = resolveColorRGBA(color, 1.0)
    self.overlay:setPosition(px, py)
    self.overlay:setDimension(pw, ph)
    self.overlay:setUVs({0, 0, 0, 1, 1, 0, 1, 1})
    self.overlay:setColor(r, g, b, a or 1.0)
    self.overlay:render()
end

function RHMCombineCalibrationGUI:drawBorder(x, y, w, h, color, thicknessPx)
    if not self.overlay or not color then return end
    local r, g, b, a = resolveColorRGBA(color, 1.0)
    if (a or 1.0) <= 0.001 then return end

    thicknessPx = thicknessPx or 1
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local px = math.floor(x * screenW + 0.5) / screenW
    local py = math.floor(y * screenH + 0.5) / screenH
    local pw = math.max(math.floor(w * screenW + 0.5) / screenW, 1 / screenW)
    local ph = math.max(math.floor(h * screenH + 0.5) / screenH, 1 / screenH)
    local tW = thicknessPx / screenW
    local tH = thicknessPx / screenH

    self.overlay:setUVs({0, 0, 0, 1, 1, 0, 1, 1})
    self.overlay:setColor(r, g, b, a or 1.0)

    -- Bottom
    self.overlay:setPosition(px, py)
    self.overlay:setDimension(pw, tH)
    self.overlay:render()

    -- Top
    self.overlay:setPosition(px, py + ph - tH)
    self.overlay:setDimension(pw, tH)
    self.overlay:render()

    -- Left
    self.overlay:setPosition(px, py + tH)
    self.overlay:setDimension(tW, ph - 2 * tH)
    self.overlay:render()

    -- Right
    self.overlay:setPosition(px + pw - tW, py + tH)
    self.overlay:setDimension(tW, ph - 2 * tH)
    self.overlay:render()
end

function RHMCombineCalibrationGUI:drawButton(x, y, w, h, text, callback, colorOverride, borderOverride, textBold, fontSize, textColorOverride, cornerPx, textureKey)
    local isHovered = self:checkHover(x, y, w, h)
    local bgColor = colorOverride or {0.065, 0.075, 0.085, 0.95}
    local borderColor = borderOverride or {1.0, 1.0, 1.0, 0.12}

    if isHovered then
        bgColor = {
            math.min(1.0, bgColor[1] * 1.35),
            math.min(1.0, bgColor[2] * 1.35),
            math.min(1.0, bgColor[3] * 1.35),
            math.min(1.0, (bgColor[4] or 0.95) * 1.05)
        }
        borderColor = {1.0, 1.0, 1.0, 0.45}
    end

    if textureKey and self.uiUVs and self.uiUVs[textureKey] then
        local hoverKey = textureKey .. "_hover"
        if isHovered and self.uiUVs[hoverKey] then
            self:drawUITexture(hoverKey, x, y, w, h, {1.0, 1.0, 1.0, 1.0})
        elseif isHovered then
            self:drawUITexture(textureKey, x, y, w, h, {1.15, 1.15, 1.15, 1.0})
        else
            self:drawUITexture(textureKey, x, y, w, h, {1.0, 1.0, 1.0, 1.0})
        end
    else
        self:drawRoundedBox(x, y, w, h, bgColor, borderColor, cornerPx or 4)
    end

    if text and text ~= "" then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(textBold ~= false)

        local fgColor = textColorOverride
        if isHovered and fgColor then
            local lum = (fgColor[1] * 0.299) + (fgColor[2] * 0.587) + (fgColor[3] * 0.114)
            if lum > 0.35 then
                fgColor = UI_CONFIG.colors.textWhite
            end
        elseif not fgColor then
            local lum = (bgColor[1] * 0.299) + (bgColor[2] * 0.587) + (bgColor[3] * 0.114)
            if lum > 0.40 then
                fgColor = isHovered and {0.0, 0.0, 0.0, 1.0} or {0.05, 0.07, 0.05, 1.0}
            else
                fgColor = isHovered and {1.0, 1.0, 1.0, 1.0} or {0.92, 0.94, 0.96, 1.0}
            end
        end
        safeSetTextColor(fgColor)

        local btnFontSize = fontSize or self.ui.fontSize
        if getTextWidth and text and text ~= "X" and text ~= "+" and text ~= "-" and text ~= "<" and text ~= ">" then
            local tw = getTextWidth(btnFontSize, text)
            if tw and tw > (w - 0.006) and tw > 0 and w > 0.01 then
                btnFontSize = btnFontSize * ((w - 0.006) / tw)
            end
        end
        renderText(x + w * 0.5, y + (h - btnFontSize * 0.72) * 0.5, btnFontSize, text)
        setTextBold(false)
    end

    table.insert(self.buttons, {x=x, y=y, w=w, h=h, callback=callback})
end

function RHMCombineCalibrationGUI:_resetTextState()
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function RHMCombineCalibrationGUI:checkHover(x, y, w, h)
    local mx, my = self.mouseX, self.mouseY
    if (not mx or not my or (mx == 0 and my == 0)) and g_lastMousePosX and g_lastMousePosY then
        mx, my = g_lastMousePosX, g_lastMousePosY
    end
    if not mx or not my then return false end
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function RHMCombineCalibrationGUI:stepParameter(param, direction, isFast)
    local spec = self.activeVehicle and self.activeVehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory or not param then return end

    local memory = spec.combineMemory
    local val = memory.currentSettings[param] or 0
    local machineType = spec.machineType or "grain"

    if param == "targetEngineLoad" then
        local step = isFast and 10 or 5
        local snapped = math.floor((val / step) + 0.5) * step
        local newLoad
        if math.abs(val - snapped) > 0.01 then
            if direction > 0 then
                newLoad = math.ceil(val / step) * step
            else
                newLoad = math.floor(val / step) * step
            end
        else
            newLoad = snapped + (direction * step)
        end
        newLoad = math.max(70, math.min(100, newLoad))
        memory:updateSetting(param, newLoad)
        return
    end

    if RHM_UnitConverter and RHM_UnitConverter.percentToPhysical and RHM_UnitConverter.getPhysicalRange then
        local physVal = RHM_UnitConverter.percentToPhysical(param, val, machineType)
        local range = RHM_UnitConverter.getPhysicalRange(param, machineType)
        if range then
            local stepValue = (range.step or ((range.unit == "RPM") and 10 or 1.0)) * (isFast and 5 or 1)
            local targetPhysVal = physVal

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

            local targetPercent = RHM_UnitConverter.physicalToPercent(param, targetPhysVal, machineType)
            if math.abs(targetPercent - val) < 0.5 then
                targetPercent = val + (direction * (isFast and 5 or 1))
            end
            memory:updateSetting(param, math.max(0, math.min(100, math.floor(targetPercent + 0.5))))
            return
        end
    end

    memory:updateSetting(param, math.max(0, math.min(100, val + (direction * (isFast and 5 or 1)))))
end

function RHMCombineCalibrationGUI:updateSliderFromMouse(slider, posX)
    if not slider or not posX then return end
    local param = slider.param
    local spec = self.activeVehicle and self.activeVehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then return end

    local trackX = slider.trackX or slider.x
    local trackW = slider.trackW or slider.w
    if not trackX or not trackW or trackW <= 0 then return end

    local ratio = math.max(0.0, math.min(1.0, (posX - trackX) / trackW))
    self.draggingSliderRatio = ratio

    if param == "targetEngineLoad" then
        local percent = math.max(70, math.min(100, math.floor(70 + (ratio * 30.0) + 0.5)))
        if spec.combineMemory.currentSettings[param] ~= percent then
            spec.combineMemory:updateSetting(param, percent)
        end
        return
    end

    local percent = math.max(0, math.min(100, math.floor(ratio * 100.0 + 0.5)))
    if spec.combineMemory.currentSettings[param] ~= percent then
        spec.combineMemory:updateSetting(param, percent)
    end
end

function RHMCombineCalibrationGUI:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isOpen then return end

    self.mouseX = posX
    self.mouseY = posY

    local isLMB = (button == 1) or (Input and button == Input.MOUSE_BUTTON_LEFT)
    local insideGUI = posX >= self.ui.x and posX <= self.ui.x + self.ui.w and
                      posY >= self.ui.y and posY <= self.ui.y + self.ui.h

    -- Slider Dragging
    if self.draggingSlider then
        if isUp then
            self.draggingSlider = nil
            self.draggingSliderRatio = nil
            return true
        else
            self:updateSliderFromMouse(self.draggingSlider, posX)
            return true
        end
    end

    -- Window Dragging & Magnetic Snapping Detection (identical smooth delta model to RHMDraggableHUD)
    if self.isDraggingTablet and not isUp then
        local dx = posX - (self.dragStartX or posX)
        local dy = posY - (self.dragStartY or posY)
        if math.abs(dx) > 0.002 or math.abs(dy) > 0.002 then
            self.hasMovedTablet = true
        end

        if self.hasMovedTablet then
            local rawX = (self.dragInitialTabletX or self.ui.x) + dx
            local rawY = (self.dragInitialTabletY or self.ui.y) + dy
            local screenMargin = 0.003
            rawX = math.max(screenMargin, math.min(1.0 - self.ui.w - screenMargin, rawX))
            rawY = math.max(screenMargin, math.min(1.0 - self.ui.h - screenMargin, rawY))

            local dockX, dockY = self:getDockedPosition()
            local snapRadiusX = 0.045
            local snapRadiusY = 0.045
            if math.abs(rawX - dockX) <= snapRadiusX and math.abs(rawY - dockY) <= snapRadiusY then
                self.isNearDock = true
            else
                self.isNearDock = false
            end

            self.ui.x = rawX
            self.ui.y = rawY
            self.hasCustomPosition = true
        end
        return true
    end

    if self.isDraggingTablet and isUp then
        self.isDraggingTablet = false
        if self.hasMovedTablet then
            if self.isNearDock then
                local dockX, dockY = self:getDockedPosition()
                self.ui.x = dockX
                self.ui.y = dockY
                self.hasCustomPosition = false
            else
                self.hasCustomPosition = true
            end
        end
        self.isNearDock = false
        return true
    end

    local isWheel = button == Input.MOUSE_BUTTON_WHEEL_UP or button == Input.MOUSE_BUTTON_WHEEL_DOWN
    if isWheel and insideGUI then
        if isDown then
            local wheelUp = button == Input.MOUSE_BUTTON_WHEEL_UP
            local delta = wheelUp and 1 or -1
            local isFast = Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift)
            if self.hoveredParameter then
                self:stepParameter(self.hoveredParameter, delta, isFast)
            end
        end
        return true
    end

    if isDown and isLMB then
        -- Check slider clicks
        if self.sliders then
            for _, slider in ipairs(self.sliders) do
                if posX >= slider.x and posX <= (slider.x + slider.w) and
                   posY >= slider.y and posY <= (slider.y + slider.h) then
                    self.draggingSlider = slider
                    self:updateSliderFromMouse(slider, posX)
                    return true
                end
            end
        end

        -- Check button clicks
        for _, btn in ipairs(self.buttons) do
            if posX >= btn.x and posX <= btn.x + btn.w and posY >= btn.y and posY <= btn.y + btn.h then
                if btn.callback then
                    btn.callback()
                end
                return true
            end
        end

        -- Dragging tablet by clicking anywhere on the tablet surface outside interactive controls
        if insideGUI then
            self.isDraggingTablet = true
            self.dragStartX = posX
            self.dragStartY = posY
            self.dragInitialTabletX = self.ui.x
            self.dragInitialTabletY = self.ui.y
            self.hasMovedTablet = false
            self.isNearDock = false
            return true
        end
    end

    if insideGUI then
        return true
    end

    -- Allow dragging and clicking small HUD even while calibration tablet is open
    if g_realisticHarvestManager and g_realisticHarvestManager.hud then
        local hud = g_realisticHarvestManager.hud
        if hud.isDragging or (hud.isMouseOver and hud:isMouseOver(posX, posY)) then
            return false
        end
    end

    if isDown or isUp then
        return true
    end
end

function RHMCombineCalibrationGUI:handleWheelScroll(direction, posX, posY)
    if not self.hoveredParameter then return end
    local isFast = Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift)
    self:stepParameter(self.hoveredParameter, direction, isFast)
end

function RHMCombineCalibrationGUI:getHarvestContext(machineType)
    local dayTimeHours, isRaining = 12.0, false
    if RHM_MoistureAdapter and RHM_MoistureAdapter.getEnvironmentContext then
        dayTimeHours, isRaining = RHM_MoistureAdapter.getEnvironmentContext()
    end

    if self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
        local rhmSpec = self.activeVehicle.spec_rhm_Combine
        local m = (rhmSpec.data and rhmSpec.data.moisture) or 0
        if m <= 0 and RHM_MoistureAdapter and RHM_MoistureAdapter.getStandingCropMoisture then
            local fillType = rhmSpec.lastFillType or (rhmSpec.combineMemory and rhmSpec.combineMemory.currentCrop)
            m = RHM_MoistureAdapter.getStandingCropMoisture(self.activeVehicle, fillType) or 0
        end

        return {
            machineType = machineType or rhmSpec.machineType or "grain",
            moisture = m,
            weedRatio = (rhmSpec.data and rhmSpec.data.weedRatio) or (rhmSpec.loadCalculator and rhmSpec.loadCalculator.currentWeedRatio) or 0,
            yield = (rhmSpec.data and rhmSpec.data.yield) or 0,
            isPickup = (rhmSpec.data and rhmSpec.data.isPickup) or false,
            fillType = rhmSpec.lastFillType or (rhmSpec.trip and rhmSpec.trip.fillTypeIndex),
            fruitType = rhmSpec.lastFruitType,
            dayTime = dayTimeHours,
            isRaining = isRaining,
        }
    end
    return {
        machineType = machineType or "grain",
        dayTime = dayTimeHours,
        isRaining = isRaining,
    }
end

rhm_log("RHM [UI]: [OK] RHMCombineCalibrationGUI (Tactile Field Terminal) loaded")

return RHMCombineCalibrationGUI
