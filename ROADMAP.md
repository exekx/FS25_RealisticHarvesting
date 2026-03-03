# � Development Roadmap

> **Help shape the future of Realistic Harvesting!**
> Submit your ideas and feedback on [GitHub Issues](https://github.com/exekx/FS25_RealisticHarvesting/issues).

---

## 📜 Version History (Changelog)

### v1.4.0.0 (Current)
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
