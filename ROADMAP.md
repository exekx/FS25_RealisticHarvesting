# � Development Roadmap

> **Help shape the future of Realistic Harvesting!**
> Submit your ideas and feedback on [GitHub Issues](https://github.com/exekx/FS25_RealisticHarvesting/issues).

---

## 📜 Version History (Changelog)

### v1.4.2.0 (Current)
**New Features:**
*   **Machine-Specific Settings:** Each machine type now has its own set of parameters in the Calibration GUI:
    *   🌾 **Grain Combines** — Fan Speed, Rotor Speed, Upper Sieve, Lower Sieve, Feeder House
    *   🌿 **Forage Harvesters** — Fan Speed, Drum Speed, Feeder House
    *   🥔 **Root/Vegetable Harvesters** — Fan Speed, Roller Speed, Feeder House
    *   🪡 **Cotton Pickers** — Fan Speed, Picker Speed, Feeder House
*   **Manual Crop Selection:** Players can now switch crops in the Calibration GUI without actively harvesting, instantly applying optimal settings.
*   **Preview Loss:** The GUI now shows a real-time **Preview Loss %** calculated from how far current settings deviate from the crop's optimal template — visible even when the machine is idle.
*   **Per-Crop Optimal Settings:** Each root/vegetable crop now has unique optimal values instead of a shared generic template:
    *   🥔 Potato: Fan 35%, Roller 40%, Feeder 70%
    *   🧅 Onion: Fan **75%** (strong air for leaf separation), Roller 45%
    *   🥕 Carrot/Parsnip: Fan **30%**, Roller **35%**, Feeder 75%
    *   🥬 Spinach: Fan **20%**, Roller **25%** (minimal to avoid damage)
    *   🫘 Green Bean: Fan 45%, Roller 38%, Feeder 62%

**Fixed:**
*   **Auto Crop Detection Broken for Forage/Root/Veg:** The local `fillTypeMapping` in `addCutterArea` only contained 10 grain crops. Replaced with a single call to `CombineSettingsDatabase:getCropNameFromFillType()` — now detects all machine types including CHAFF, ONION, POTATO, SPINACH, GREENBEAN.
*   **`autoConfigureForCrop` Hardcoded Grain Params:** Settings auto-config was applying `fan/upperSieve/lowerSieve/rotor/feeder` even on forage/root harvesters (which only have 3 params). Now dynamically iterates active params based on machine type.
*   **All Root/Veg Crops Showing Same Settings:** All 8 root/veg crops shared a single `root_harvest` template. Each now has its own template with distinct realistic values.

**Improved:**
*   **Crop Factors Rebalanced** — `SPINACH`: 0.3→**3.0**, `GREENBEAN`: 0.8→**2.5** for realistic engine load on vegetable harvesters.
*   **Localization:** All GUI text strings (title, buttons, labels, hints) now use `g_i18n` with full translations across all 10 languages.
*   **CHAFF, GRASS, SILAGE, COTTON** added to `fillTypeMapping` for complete auto-detection coverage.

### v1.4.1.0
**Fixed:**
*   **DLC Compatibility:** Fixed game crash `attempt to call missing method 'getIsControlled'` when using Highland DLC equipment (NH 8040 + Holaras tools). Added a safe nil guard before calling the method.
*   **Courseplay — Second Combine Stuck at 10 km/h:** Removed incorrect `movingDirection` check from `getSpeedLimit()`. Courseplay speed workaround now only activates when the cutter is actually harvesting.
*   **AUTO Mode on Dedicated Servers:** AUTO mode now stores a pending state when crop is not yet detected. Settings are applied automatically on the first harvest instead of resetting to 50.
*   **NEXAT — Calibration Menu Not Opening:** `CombineCalibrationGUI:open()` now searches for the combine vehicle (with `spec_rhm_Combine`) in the full vehicle hierarchy before opening, correctly handling modular NEXAT setups.

### v1.4.0.0
**New Features:**
*   **Combine Calibration:** Full manual control over Fan Speed, Rotor Speed, Sieve Openings, and Feeder House.
*   **Settings Penalty:** Incorrect calibration now causes crop loss (displayed in HUD).
*   **Profile System:** Save and load custom settings profiles for different crops/conditions.
*   **GUI:** Interactive graphical menu (RShift+K) to manage settings and profiles.
*   **AUTO Imperfection:** AUTO mode now applies a slight random deviation (1-10 units) — skilled manual tuning can outperform it!
*   **Unified Loss Math:** Same penalty formula for AUTO and MANUAL modes — no more zero-loss bypass.
*   **Savegame Fix:** Combine calibration now correctly saves and restores from `vehicles.xml`.
*   **Dedicated Server Ready:** Auto-crop detection is server-side only; each vehicle keeps its own calibration profile.
*   **Settings Consolidation:** All mod settings (server + client) now stored in `modSettings/` folder.

### v1.3.2.0
**New Features:**
*   **Physical Crop Loss System:** Crop losses now physically reduce the amount of grain collected in the bunker!
*   **95% Load Threshold:** Losses start at 95% engine load (previously 100%) for earlier feedback.
*   **Progressive Loss Formula:** Higher overload results in exponentially more loss for realistic penalties.
*   **Difficulty Impact:** Arcade/Normal/Realistic settings now directly control crop loss severity.

### v1.3.1.0
**New Features:**
*   **Independent Header Control:** Threshing and cutter can now be started independently (option in settings: "Enable Independent Header Control").
*   **New Draggable HUD:** Completely redesigned HUD with Courseplay-style interaction (Right Click to toggle cursor, Left Click drag to move).
*   **HUD Customization:** Toggle individual HUD elements (Yield, Load, Speed, Loss, Productivity) and choose between Metric/Imperial/Bushels units.
*   **HUD Reset Logic:** All metrics (yield, productivity, recommended speed) now reset instantly when the cutter is lifted or disabled.
*   **Settings Reorganization:** Settings menu split into "Simulation" and "HUD & Visuals" sections for better clarity.

### v1.3.0.0
**Fixed:**
*   **Settings Persistence:** Resolved critical bug where Difficulty (Motor/Loss) settings were not saving between sessions.
*   **Settings Storage:** Migrated settings to `modSettings/` directory for global persistence across all savegames.
*   **Yield Monitor:** Fixed incorrect yield values; now accurate within ±5% with realistic noise fluctuation.
*   **Throughput Indicator:** Fixed `T/h` indicator to correctly display real-time harvesting rate.
*   **HUD Position:** Adjusted HUD placement higher on screen for better visibility.
*   **Nexat Compatibility:** Fixed HUD visibility issues with the modular Nexat system.
*   **Cutter Detection:** Improved logic to only limit speed when header is actually working (not just attached/lifted).

**Changed:**
*   **Mass-Based Calculation:** Switched engine load logic from theoretical area to **actual harvested mass** for consistent realism.
*   **Conservative Start:** Implemented 7 km/h initial speed limit to prevent immediate overload on start.
*   **Crop Factors:** Rebalanced resistance values for all crop types based on real-world data.
*   **Performance:** Optimized core load calculation scripts for smoother gameplay.

### v1.2.1.0
*   **Fixed:** Productivity calculation displaying values 1000x too low.
*   **Improved:** Mass-to-volume conversion accuracy using actual game density values.

### v1.2.0.0
*   **New Feature:** Added support for Cotton Harvesters.
*   **New Feature:** Added partial support for Forage Harvesters.
*   **Fixed:** Multiplayer synchronization issues.
*   **Fixed:** Settings menu conflicts with other mods.
*   **Improved:** Unit System display toggles (Imperial/Metric).

### v1.1.0.0
*   **New Feature:** "Reset Settings" button in menu footer (Key: X).
*   **UX:** Added side descriptions (tooltips) for all settings.
*   **Localization:** Full translation support for 10 languages (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU).
*   **Fixed:** Improved settings menu stability.

### v1.0.0.0
*   Initial Release.

---

## 🚀 Future Plans

Based on community feedback and suggestions, here is the plan for future updates.

### Phase 1: Core Mechanics & Refinement (Next)
*   **Smoother Load Control:** Improve the "feel" of the governor to maintain ~90-95% load more consistently without "hunting" or hesitation.
*   **Pickup Header Improved Support:** Better handling for windrow harvesting (grass/straw) with accurate load calculations.

### Phase 2: Advanced Realism Features
*   **Realistic Weather Integration:**
    *   *Upcoming Support:* Direct integration with the **Realistic Weather** mod.
    *   *Features:* Moisture, air humidity, and rain will affect crop resistance, threshing difficulty, and clogging risks.
*   **"Combine Jamming" (Verstopfung):** Simulated combine blockage when severely overloaded.

### Phase 3: The "Operator" Update (Long Term)
*   **Store Customization - Automation:**
    *   *Idea:* Buyable "Auto-Combine" module in the shop. Casual players can buy automation to handle settings, while enthusiasts can save money by setting it manually.

---

*Notes: This roadmap is subject to change based on technical feasibility and user feedback.*
