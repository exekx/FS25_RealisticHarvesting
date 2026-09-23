# Realistic Harvesting - Changelog

Changelog 1.6.1.0:
- ADDED: Fullscreen Harvest Records & Field Job Counter menu (Right Shift + J).
- ADDED: Live field-level yield, harvested area, clean crop volume, and financial loss metrics.
- ADDED: Loss root-cause diagnostic breakdown (Speed, Moisture/Dew, Wear, Slope) and Operator Scorecard.
- ADDED: Multi-combine fleet overview monitoring driver state, throughput, yield, and mechanical wear.
- ADDED: Multi-season historical harvest log archiving all completed fields and crop types.
- ADDED: Native diurnal crop moisture and ambient dew simulation with harmonic day/night cycles.
- ADDED: In-cockpit HUD mini-badge with live trip yield, loss %, and efficiency rank.
- ADDED: Quick in-cab field counter reset action by holding Right Shift + R.
- ADDED: Multi-stage power model for forage harvesters (feed rolls, chopping drum, accelerator).
- ADDED: Swath pickup header support with intake surge damping and windrow volume load.
- ADDED: Dedicated public integration API methods for fleet stats and field trip counters.
- IMPROVED: Authentic agricultural terminology overhaul ("Field Counter" / "Feldzähler") across all 27 languages.
- IMPROVED: Recalibrated crop specific energy and throughput curves based on DLG & ASABE standards.
- IMPROVED: Straw chopper power consumption model (extra 15-20% engine load when chopping vs swathing).
- IMPROVED: Architectural hardening, purging defensive pcalls and enforcing unambiguous API contracts.
- IMPROVED: Full dedicated server multiplayer network synchronization and farm-isolated XML savegame storage.
- FIXED: Fatal crash at 100% map loading caused by unsupported GUI XML color profile attributes.
- FIXED: Game freeze when opening menu and recursive event loop on trip reset.
- FIXED: Full 27-language localization parity (347 keys) and eliminated double-encoded mojibake in Asian/European languages.
- FIXED: Multi-combine cab focus and odometer isolation when harvesting different crops simultaneously.
- FIXED: Missing method 'getCurrentPage' error and vehicle discovery for hired AI helpers.
- FIXED: Stripped non-standard unicode emojis to guarantee clean rendering in GIANTS bitmap fonts.

Changelog 1.6.0.0:
- ADDED: Free-floating draggable mini HUD with magnetic dock snapping (LMB).
- ADDED: Grape and olive harvesters support with viticulture calibration controls.
- ADDED: Mechanical equipment wear losses for blunt cutterbar knives and threshing components.
- ADDED: Dedicated public integration API (RHM_Api) for external mod compatibility.
- ADDED: Audio preview test beep on overload buzzer volume slider adjustments.
- IMPROVED: Complete Arcade Mode overhaul (0% engine load, no speed limits, zero crop losses).
- IMPROVED: Smart overload buzzer pattern (3 beeps with interval pause) and 0%-100% volume slider.
- IMPROVED: Calibration tablet styling with ultra-slim bezels and glass edge refraction lighting.
- IMPROVED: Forage harvester rotary corn header power recalibration (20 HP/m) for realistic speed.
- IMPROVED: Mod archive size reduced from 2.5 MB to 1.0 MB.
- FIXED: HUD docking clearance beneath F1 menu with control groups and InputHelpPager.
- FIXED: Precision Farming gap elimination when F1 menu is hidden.
- FIXED: Imperial unit conversions for speed (mph) and productivity (ac/h) on mini HUD.
- FIXED: NEXAT modular carrier true horsepower resolution (1100 HP) and phantom load removal.
- FIXED: Silage maize crop bouncing between grain corn and chopped corn silage.
- FIXED: Network dirty flag crashes on complex machinery with >32 specializations.
- FIXED: Encoding artifacts and double-encoded strings across translation files.
- REMOVED: Center-screen blinking text overload warning and its settings toggle.
- REMOVED: Internal "RHM" acronym replaced with official title "Realistic Harvesting".

Changelog 1.5.4.1:
- FIXED: Full NEXAT Modular Carrier & NEXCO Harvester Support!
  * Corrected horsepower resolution for encrypted DLC machinery (resolves true 1100 HP).
  * Fixed phantom trailed harvester PTO load duplication on modular combines.
  * Restored responsive harvesting speed and realistic Arcade mode engine load reduction.
  * Fixed `Object.lua:187: invalid argument #2 to 'bor'` crash when network dirty flags are exhausted.
  * Fixed `rhm_Combine.lua:813: attempt to index nil with 'currentCrop'` and guaranteed combine settings initialization.
- IMPROVED: Public Integration API (`RHM_Api.lua`)!
  * Added `RHM_Api.getEnginePowerHp(vehicle)` returning rated engine horsepower with modular carrier traversal.

Changelog 1.5.4.0:
- FIXED: Resolved Mouse Drag & Camera Freezes under Left Mouse Button (LMB)!
  * Removed duplicate mission hooks that were simultaneously registered on both Mission00 and FSBaseMission.
  * Eliminates recursive mouse delta re-dispatching during tool adjustment and camera rotation.
- FIXED: Automatic Tutorial Onboarding Hints Triggering!
  * Fixed an issue where cascading hints failed to pop up automatically due to querying uninitialized variables.
  * Implemented robust combine cutter detection across attached and integrated cutters, real speed evaluation, and engine load monitoring.
- OPTIMIZED: Notification Overlay Performance & Memory Footprint!
  * Precalculated 9-slice panel UV vectors and single-pass text wrapping, reducing heap table allocations to zero in draw loops.
  * Cached input glyph element dimensions, eliminating frame-by-frame destruction and recreation of input glyphs.
  * Decoupled notification rendering from active combine presence, ensuring alerts always display reliably.

Changelog 1.5.3.0:
- NEW: In-Game Help Pages & Interactive Guide Overhaul!
  * Fully restructured all 9 In-game Help tutorial pages in the ESC menu (Overview, Engine Load, Crop Losses, Cutterbar & Header, Threshing Settings, Crop Profiles, Electronics Tiers, Moisture & Weather, Mod Compatibility).
  * Rewritten in clean, native GIANTS handbook style with structured bullet points, eliminating technical jargon, formulas, and visual clutter.
  * Complete, high-quality localization across 15 languages (EN, UK, DE, FR, PL, ES, IT, CZ, BR, PT, HU, RO, NL, TR, RU).
- NEW: Interactive On-Screen Notification Dialogs!
  * Added non-intrusive contextual notification banners for key harvesting events (first-time combine setup, overload warning, optimal tuning).
  * Styled with a sleek, dark rounded panel and integrated input glyphs; dismissible via Left Mouse Click (LMB) or configurable hotkey.
- NEW: Player Settings Protection from AI Helpers & Courseplay!
  * Added dedicated `aiHelperTuning` setting (Keep Player Settings / Always AI Tune / Disabled).
  * When set to 'Keep Player Settings', hired AI workers and Courseplay will never overwrite player-calibrated combine settings.
  * Calibration GUI (`Right Shift + K`) can now be opened while an AI worker or Courseplay is actively driving to inspect or tweak settings on the fly.
  * Automatically loads and respects player-saved crop profiles for hired workers.
- NEW: Smooth Hydrostatic Cruise Control & Crop Speed Memory!
  * Replaced abrupt speed steps with continuous exponential hydrostatic smoothing (`tau` filtering) for realistic acceleration and braking under load.
  * Hermite S-curve transit ramp eases feederhouse entry, preventing sudden stops when entering thick crop stands.
  * Per-crop harvesting speed memory (`cropHarvestingSpeeds`) remembers the optimal pace for each crop across headland turns.
  * Fixed speed limit oscillation and erratic jerking when reversing.
- NEW: In-Cabin Overload & High-Loss Audio Alarm!
  * Added electronic in-cabin warning buzzer triggering during critical engine overload (98%+) or excessive grain loss (> 4.0%).
  * Seamless audio propagation between 1st person cabin view and 3rd person exterior camera with intelligent volume balancing (+25% exterior boost).
  * Dedicated audio settings in ESC menu to toggle alarms and adjust master volume (50%–150%).
- IMPROVED: Hopper Ground Truth Crop Detection & Advanced Machine Classification!
  * Hopper fill level (> 50 L) now acts as authoritative ground truth for active crop selection, eliminating header boundary overlap errors and false resets.
  * Robust multi-map crop classification distinguishes grain legumes (`BEANS`, `FABABEAN`) from specialty root crops (`GREENBEAN`).
  * Non-grain crops (grapes, olives, weeds) are strictly excluded from standard combine harvesters.
  * Physical ASABE calibration models automatically generated for custom map grain legumes.
- IMPROVED: HUD Telemetry & Precision Farming Docking!
  * Dynamic mechanical stress row coloring (white -> yellow -> orange -> pulsing red critical alert).
  * Zero-gap magnetic docking underneath the Precision Farming yield display box, adapting to F1 Help menu visibility.
  * Added live target speed readout in the HUD telemetry capsule.
  * Added `Right Shift + H` quick toggle hotkey to show/hide the RHM HUD.
- FIXED: Interactive Control & HeadTracking Input Conflict Resolution!
  * Integrated dedicated compatibility mediator (`RHM_ModCompatibility`) for `FS25_interactiveControl` and `FS25_headTrackICextension`.
  * Suspends in-cab click point detection and fullscreen overlay capture while the RHM calibration GUI is active, preventing frozen mouse clicks.
  * Eliminated camera rotation and cursor lock issues with Courseplay and AutoDrive.
- FIXED: Savegame XML Schema Validation & Multi-Vehicle Persistence!
  * Fully registered `#isCalibrated` and `#calibratedCrops` within the GIANTS `savegame_vehicles` schema, eliminating `Path not registered` console errors in `vehicles.xml`.
  * Safe loading wrappers (`hasProperty` and `pcall`) prevent savegame corruption or crashes when updating existing careers.
- OPTIMIZED: Performance & Garbage Collector Overhead!
  * Replaced dynamic sliding-window tables in hot loops with fixed O(1) ring buffers, completely eliminating GC allocation spikes and micro-stutters during harvesting.
  * Enhanced dedicated server network stream synchronization for seamless multiplayer joining.

Changelog 1.5.2.0:
- NEW: Dynamic Map Crop Extraction & Localization! The combine calibration menu (`Right Shift + K`) now exclusively displays crops present on the active map, sorted alphabetically and localized in the player's language (`ft.title`). Hardcoded static crop lists have been completely removed.
- NEW: Instant Dynamic Physical Templates for Custom Map Crops! Any custom or modded crops introduced by a map are automatically classified by machine type (`grain`, `root`, `forage`, `cotton`) and assigned accurate physical separation and cleaning templates on the fly.
- NEW: Multi-Tier AI Worker & Courseplay Auto-Tuning! When an AI worker or Courseplay operates the combine, settings are automatically calibrated according to the installed RHM Electronics Tier:
  * Tier 1 (Standard): ±18% setting variance (simulates an inexperienced hired operator; higher loss and lower throughput).
  * Tier 2 (Sensor Kit): ±10% setting variance.
  * Tier 3 (Yield & Loss Monitor): ±4% setting variance.
  * Tier 4 (Opti-Harvest AI): 0% variance (flawless factory settings) plus live continuous dynamic micro-trimming during the cut.
  * Human drivers retain 100% manual control without any silent background changes.
- FIXED: Savegame Persistence for Active Combine Settings! Fixed an issue with GIANTS XMLFile reading where active slider values, chosen crop, and target engine load would reset on savegame reload. All settings are now permanently preserved across career saves.
- IMPROVED: Contract & Leasing Progression! Rented machinery on contracts correctly spawns in the baseline configuration (Tier 1), reinforcing economic motivation to invest in your own high-tier farm fleet.

Changelog 1.5.1.0:
- NEW: Physical Power-Balance Load Engine! Completely eradicated arbitrary static crop coefficients. Harvester engine load and speed regulation are now calculated through a true physical power-balance equation: P_total = P_base + P_header(v) + P_process.
  * P_base: Mechanical driveline, straw chopper & threshing idle resistance (~10% of engine power).
  * P_header(v): Dynamically queries PTO requirements directly from the attached header's spec_powerConsumer or store XML, scaling with ground speed. Over-sized headers naturally drag underpowered combines down to realistic field speeds.
  * P_process: Crop processing power derived from specific processing energy (HP per t/h) based on physical crop traits (standing whole-crop forage chopping, direct grass, grain with straw, oilseeds, pulses, corn cobs, roots, and cotton).
- NEW: 100% Dynamic Physics-Based Crop Settings! Replaced static hardcoded templates with an ASABE & FS25-compliant physical calculation engine. All crops (vanilla and modded) dynamically calculate optimal fan, rotor, sieves, and feeder values based on bulk density and seed geometry.
- NEW: Live Environmental Adjustments! Combine calibration pins dynamically shift based on real-time field moisture and yield conditions.
- NEW: Electronics Tier Rebalance & Factory Variance! All newly purchased combines now arrive with realistic factory mechanical tolerances (~50% ± 8% per parameter) instead of flat identical numbers.
- NEW: Strict MANUAL Mode for Tiers 1, 2, and 3: Combines operate purely manually; auto-switch and optimal presets are completely blocked. Players must manually tune sliders or save custom profiles.
- NEW: Interactive Opti-Harvest AI (Tier 4) Auto-Calibration: Harvesters no longer silently auto-tune settings behind the scenes. Operators harvest a few meters into a field to gather telemetry, then press AUTO in the Shift+K menu to run AI calibration tailored to live field moisture and yield, activating continuous dynamic auto-trimming.
- FIXED: Multiplayer & Dedicated Server crop selection in Shift+K menu: added bidirectional network event synchronization (`CROP`), preventing selected crops from reverting to "NONE" / "no crop".
- FIXED: Resolved camera rotation and zoom locking issues when opening/closing menus or activating HUD cursor (RMB).
- FIXED: Cleanly reset global text rendering states after drawing draggable HUD to prevent leaking state to the base game HUD.
- FIXED: FS25 compatibility issues with deprecated `g_currentMission.controlledVehicle` API
- FIXED: Added multiple fallback methods for vehicle detection in FS25
- FIXED: Added nil safety checks for critical game managers (g_fruitTypeManager, g_fillTypeManager, g_storeManager)
- FIXED: Enhanced error handling in network synchronization and event processing
- IMPROVED: Better string validation before pattern matching operations
- IMPROVED: Optimized vehicle hierarchy search with cache validation
- IMPROVED: Enhanced memory initialization with proper error handling
- FIXED: Added safety checks for combine spec components during load calculation
- FIXED: Grain tank loss deduction now dynamically resolves the active harvesting fillUnitIndex instead of hardcoded 1, ensuring losses properly deduct grain on vehicles where fuel or DEF occupies fillUnit 1
- FIXED: Hand-held tool package and passive harvesters (without spec_turnOnVehicle) are no longer blocked from harvesting root crops by the thresher-on check

Changelog 1.5.0.0:
- NEW: "Moisture System" Mod Integration! Added dynamic engine load penalties and increased crop losses when harvesting in damp conditions.
- NEW: Real-time moisture percentage readout integrated into the draggable HUD.
- NEW: Added a new setting to toggle Moisture System integration on/off.
- IMPROVED: "Target Engine Load" Auto-Pilot: Implemented a 2% deadzone to prevent micro-oscillations and deliver a much smoother cruise-control experience across varying crop densities.
- IMPROVED: Calibration GUI: "Target Engine Load" now features a dynamic color-coded progress bar (Green/Yellow/Red) for better visual feedback instead of plain text.
- FIXED: Moisture HUD indicator freezing at its last value instead of resetting to 0% when the combine stops harvesting or reverses.
- FIXED: "Target Engine Load" incorrectly showing as "auto" in the calibration menu.
- NEW: Added diagnostic console command `rhm_inspect` to view real-time harvester performance data in the console and log.txt.
- IMPROVED: Complete overhaul of crop coefficients using a name-based lookup system for higher precision.
- IMPROVED: Distinct separation between Grain Corn and Silage Corn coefficients for realistic harvesting speeds.
- IMPROVED: Balanced Grass and Hay harvesting coefficients for both direct cut and pickup methods.
- IMPROVED: Refined Pickup load multiplier (from 0.25 to 0.45) for grain windrows to provide more realistic engine resistance.
- NEW: Universal "Forage Safety Net" to ensure realistic loads for non-standard or modded crops processed by forage harvesters.
- FIXED: Resolved an issue where forage harvester cutters were not detected correctly due to case-sensitivity in category names.

Changelog 1.4.3.0:
- NEW: Purchasing System! Added functionality to purchase advanced combine calibration settings, adding a new layer of career progression.
- NEW: Completely redesigned the interactive Combine Calibration GUI with new culture selection, interaction improvements, and additional information tabs.
- NEW: Improved draggable HUD displaying harvester performance, including graphical meters for yield and engine load.
- NEW: Added 7 detailed pages to the in-game Help Menu covering all mod mechanics, with unique custom icons and localization for 11 languages.
- NEW: "Crop Loss" translation page added and refined mod descriptions across all supported languages.
- IMPROVED: Revised the core logic of speed dependence on engine load: minimum crop losses now legitimately start at 80% load instead of 100%.
- IMPROVED: Forage harvester load factor is now fully dynamic based on crop density and cutter width.
- IMPROVED: Refactored settings injection mechanism to use safe class-level engine hooks (`InGameMenuSettingsFrame.onFrameOpen`) for maximum compatibility with DLCs (Vredo Pack, Precision Farming, etc.).
- IMPROVED: Global Namespace Refactoring: All internal classes and files were renamed with the `RHM_` prefix to prevent collisions with other third-party mods.
- IMPROVED: Completely rebuilt the mod's debugging architecture. All debug outputs are now strictly gated behind the game's `-devWarnings` flag, keeping the user's `log.txt` perfectly clean by default.
- FIXED: Resolved a critical UI conflict where DLC settings disappeared from the game menu when Realistic Harvesting was active.
- FIXED: Corrected filename capitalization in `main.lua` (`RHM_Combine`, `RHM_Renderer`), resolving the infamous 55% loading screen freeze.
- FIXED: Resolved a bug where changes in the settings menu were not saved correctly or synced to the server due to an invalid callback signature.
- FIXED: Eliminated massive console spam (60 logs per second) caused by "Crop Loss Applied" during harvesting in developer mode.
- FIXED: Corrected XML syntax errors (`<paragraph>` tags) in `modDesc.xml` to ensure the Help Menu text renders perfectly without engine warnings.
- IMPROVED: Optimized the UI layout to use the standard `gameSettingsLayout` for consistent menu positioning.
- IMPROVED: Removed the redundant "Reset" button (X) from the footer as it was causing layout instability with other mods.

Changelog 1.4.2.0:
- FIXED: Maximum harvesting speed is strictly limited by the base game's header capabilities, preventing root crop harvesters from exceeding realistic speeds.
- FIXED: Addressed network desynchronization issues on dedicated servers where client settings could override server defaults.
- FIXED: Resolved an infinite recursion crash related to saving combine settings on multiplayer servers.
- FIXED: Corrected a memory leak in the engine load and productivity calculation buffers.
- FIXED: Prevented non-admin users from occasionally gaining temporary access to Server Settings.
- IMPROVED: Onion and Carrot throughput factors re-calibrated for more accurate engine load calculations.
- IMPROVED: Removed unnecessary debug output from server synchronization logs to keep console clean.
- FIXED: Server-side settings becoming unlocked for non-admin clients upon reopening the menu.
- FIXED: Menu 'window_grass' localization issue for Grass harvesting.
- IMPROVED: Removed spammy debug logs from engine load calculations.
- IMPROVED: Centralized debug log configuration (RHM_Debug.lua).
- ADDED: Spanish localization for all mod features and menus.
- NEW: Added setting to disable "High Load" HUD warnings.
- IMPROVED: Internal logic cleanup for warning system.
- FIXED: Complete overhaul of Yield Calculation math to perfectly synchronize with Precision Farming HUD and custom map scales.
- FIXED: Forage harvesters (Silage) showing 10x lower yield due to engine volume bugs.
- FIXED: Mathematical desyncs when grain enters the bunker asynchronously from the header cut.
- NEW: Combine settings physics separated into two independent categories: Efficiency (affects processing speed) and Crop Loss (affects wasted grain).
- NEW: Settings Menu HUD redesigned to always display both Speed and Loss impacts simultaneously.
- NEW: Added 'Overload Shield' mechanics - ideal settings now protect against sudden crop density spikes.
- FIXED: Critical bug where perfect combine settings could inadvertently reduce speed to vanilla limits.
- FIXED: Combine failing to accelerate properly when settings were improved mid-harvest.
- FIXED: Resolved duplicate registration of savegame XML paths causing server log errors and settings reset.
- IMPROVED: Forage Harvester throughput calibrated to real-world data (coefficient adjusted from 0.150 to 0.051).
- NEW: Added universal Pickup/Swath header detection with lower engine load multiplier (0.75x).
- NEW: Added automatic fallback mapping for '_WINDROW' and 'CUT_' fillTypes to their base crops.
- IMPROVED: Precision calibration of crop factors and densities based on real-world yield targets (bu/hr).
- NEW: Every crop now uses individual technical presets derived from real-world manuals (20+ crops fine-tuned).
- IMPROVED: Forage harvester logic simplified with a universal 0.75x multiplier.
- IMPROVED: Pickup multiplier refined to 0.35x for balanced windrow harvesting.
- FIXED: Combines no longer accelerate past vanilla working speeds when header is idle (no crop).
- FIXED: Removed initial speed limit jump when lowering the header.
- IMPROVED: Robust detection system for forage harvesters and headers.
- IMPROVED: Speed limit strictly capped at vanilla game limits (removed artificial 1.5x bonus).
- IMPROVED: Recalibrated crop factors for Oat (+25%), Maize (-50%), Soybean (-20%), and Cotton (2x).
- IMPROVED: Significant load reduction for root crops (Potato, Carrot, Parsnip, Onion).
- FIXED: Speed limit "reset loop" at 9.9 km/h during continuous harvesting.
- FIXED: Broadened root crop pickup exception to ensure realistic load for Onion and Carrot.
- ADDED: Support for ONION_DIRTY and MEADOW fill types.

Changelog 1.4.1.0:
- FIXED: Game crash ("attempt to call missing method 'getIsControlled'") when using equipment from DLC packs (e.g. Highland DLC NH 8040 with Holaras tools). Added safe nil check for the method.
- FIXED: Courseplay second combine getting stuck at 10 km/h. Removed incorrect movingDirection check from getSpeedLimit() and added guard so Courseplay speed limit only applies when cutter is actually working.
- FIXED: AUTO mode settings resetting to 50 on dedicated servers. AUTO mode now registers as pending if crop not yet detected and applies automatically on first harvest.
- FIXED: Combine Settings menu (RShift+K) not opening and closing immediately when using NEXAT modular system.
- FIXED: Potential game crash with missing 'getAIFieldWorkerIsTurning' method on custom vehicles.

Changelog 1.4.0.0:
- NEW: Added compatibility with "HUD Hider" mods (HUD aligns with game visibility).
- FIXED: Productivity (T/h) calculation bug causing sudden jumps.
- FIXED: GUI closing unexpectedly during gameplay.
- NEW: Interactive Combine Settings & Calibration Menu (RShift + K).
- NEW: Manual Control Mode - Adjust Fan, Rotor, Sieves, and Feeder.
- NEW: Incorrect settings cause additional Crop Loss (displayed in GUI).
- NEW: Profile System - Save/Load custom settings for each crop.
- NEW: New crops start with neutral (50%) settings, requiring calibration.
- NEW: Crop Loss display now shows +/- signs (- for losses, + for bonuses, 0 for optimal).
- NEW: Manual adjustment buttons (+/-) always visible in Calibration GUI for easier tuning.
- FIXED: Camera rotation properly blocked when cursor is active (HUD drag/GUI interaction).
- FIXED: HUD resetting to off-screen positions. Added auto-fix and reset command.
- IMPROVED: Input blocking now uses proper camera.isRotatable method.
- IMPROVED: GUI hint text repositioned to prevent overlap with buttons.
- NEW: AUTO mode now applies slight random imperfection (1-10 units) - skilled manual tuning can outperform AUTO!
- NEW: Same loss math for AUTO and MANUAL modes - no more zero-loss bypass in AUTO.
- FIXED: Combine settings now correctly saved and loaded from savegame (vehicles.xml).
- FIXED: profileCount cache correctly restored after loading savegame.
- FIXED: Auto crop detection now server-side only - prevents random value desync in multiplayer.
- IMPROVED: All mod settings (server + client) now stored in modSettings/ folder.
- IMPROVED: Dedicated server fully supported - each vehicle retains its own calibration profile.

Changelog 1.3.2.0:
- NEW: Physical Crop Loss System! Losses now reduce actual grain collected in bunker.
- NEW: Crop losses start at 95% engine load (was 100%).
- NEW: Progressive loss formula - higher overload = exponentially more loss.
- IMPROVED: Loss penalties now directly affect harvest yield for realistic gameplay.

Changelog 1.3.1.0:
- NEW: Settings menu reorganized into "Simulation" and "HUD & Visuals" sections.
- NEW: Draggable HUD! Right-click to toggle cursor, then drag HUD to move it.
- NEW: Independent Header Control (optional setting).
- NEW: HUD metrics now reset instantly when cutter is lifted/stopped.
- IMPROVED: Customizable HUD content (toggle individual elements).

Changelog 1.3.0.0:
- NEW: Yield Monitor! See real-time yield in t/ha or bu/ac (toggleable in settings) (#10)
- NEW: Completely rewritten load calculation logic based on Mass Throughput (t/h) instead of area.
- NEW: Added experimental support for NEXAT system (HUD & Physics).
- IMPROVED: HUD text is now bold for better visibility.
- IMPROVED: Fixed issue where HUD would disappear when switching vehicle components.

Changelog 1.2.1.0:
- Fixed productivity calculation displaying incorrect values (was 1000x too low)
- Improved accuracy of mass-to-volume conversion using actual crop density

Changelog 1.2.0.0:
- Added support for Cotton Harvesters
- Added partial support for Forage Harvesters
- Fixed Multiplayer Synchronization issues
- Fixed settings menu conflict with other mods
- Improved Unit System display (Imperial/Metric)

Changelog 1.1.0.0:
- New Feature: Added "Reset Settings" button to settings menu footer (key: X)
- UI Improvements: Added side descriptions for all settings in menu (tooltips)
- Localization: Full translation support for 10 languages (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Bug Fixes: Improved settings menu stability
