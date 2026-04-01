# Realistic Harvesting - Changelog

## Language: EN

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

---

## Language: DE

Changelog 1.5.0.0:
- NEU: "Moisture System"-Mod-Integration! Dynamische Motorlaststrafen und erhöhte Ernteverluste bei der Ernte unter feuchten Bedingungen hinzugefügt.
- NEU: Echtzeit-Feuchtigkeitsanzeige in Prozent in das verschiebbare HUD integriert.
- NEU: Neue Einstellung zum Ein-/Ausschalten der Feuchtigkeitssystem-Integration hinzugefügt.
- VERBESSERT: "Ziel-Motorlast"-Autopilot: 2% Totzone implementiert, um Mikroschwingungen zu vermeiden und ein viel sanfteres Tempomat-Erlebnis bei unterschiedlichen Erntedichten zu bieten.
- VERBESSERT: Kalibrierungs-GUI: "Ziel-Motorlast" verfügt nun über einen dynamischen farbcodierten Fortschrittsbalken (Grün/Gelb/Rot) für besseres visuelles Feedback anstelle von einfachem Text.
- BEHOBEN: Feuchtigkeits-HUD-Anzeige fror auf ihrem letzten Wert ein, anstatt auf 0% zurückgesetzt zu werden, wenn der Mähdrescher die Ernte stoppt oder rückwärts fährt.
- BEHOBEN: "Ziel-Motorlast" wurde im Kalibrierungsmenü fälschlicherweise als "auto" angezeigt.
- NEU: Konsolenbefehl `rhm_inspect` zur Diagnose von Erntedaten in Echtzeit hinzugefügt.
- VERBESSERT: Komplette Überarbeitung der Fruchtkoeffizienten durch ein namensbasiertes Suchsystem für höhere Präzision.
- VERBESSERT: Klare Trennung zwischen Körnermais- und Silomais-Koeffizienten für realistische Erntegeschwindigkeiten.
- VERBESSERT: Ausgewogene Koeffizienten für Gras- und Heuernte (Direktschnitt und Pickup).
- VERBESSERT: Pickup-Lastmultiplikator für Getreideschwaden verfeinert (von 0,25 auf 0,45) für realistischen Motorwiderstand.
- NEU: Universelles „Forage Safety Net“ für realistische Lasten bei untypischen oder gemoddeten Früchten für Feldhäcksler.
- BEHOBEN: Problem gelöst, bei dem Feldhäcksler-Schneidwerke aufgrund der Groß-/Kleinschreibung in Kategorienamen nicht korrekt erkannt wurden.

Changelog 1.4.3.0:
- NEU: Kaufsystem! Funktion zum Kauf erweiterter Kalibriereinstellungen für Mähdrescher hinzugefügt, was eine neue Ebene des Karrierefortschritts bietet.
- NEU: Interaktives Mähdrescher-Kalibrierungsmenü (GUI) komplett überarbeitet mit neuer Fruchtauswahl, verbesserten Interaktionen und zusätzlichen Informations-Tabs.
- NEU: Verbessertes verschiebbares HUD zur Anzeige der Leistung des Mähdreschers, einschließlich grafischer Anzeigen für Ertrag und Motorlast.
- NEU: 7 detaillierte Seiten zum In-Game-Hilfemenü hinzugefügt, die alle Mod-Mechaniken abdecken, mit einzigartigen Symbolen und Lokalisierung für 11 Sprachen.
- NEU: Übersetzungsseite "Ernteverlust" hinzugefügt und Mod-Beschreibungen in allen unterstützten Sprachen verfeinert.
- VERBESSERT: Kernlogik der Geschwindigkeitsabhängigkeit von der Motorlast überarbeitet: Minimale Ernteverluste beginnen nun regulär bei 80% Last statt bei 100%.
- VERBESSERT: Der Lastfaktor für Feldhäcksler ist nun vollständig dynamisch und basiert auf der Erntedichte und Schneidwerksbreite.
- VERBESSERT: Der Einstellungs-Injektionsmechanismus verwendet nun sichere Klassen-Hooks (`InGameMenuSettingsFrame.onFrameOpen`) für maximale Kompatibilität mit DLCs (Vredo Pack, Precision Farming usw.).
- VERBESSERT: Globales Refactoring: Alle internen Klassen und Dateien wurden mit dem Präfix `RHM_` versehen, um Kollisionen mit anderen Mods zu vermeiden.
- VERBESSERT: Die Debugging-Architektur der Mod wurde komplett neu aufgebaut. Alle Debug-Ausgaben sind nun strikt hinter dem `-devWarnings`-Flag des Spiels verborgen, wodurch die `log.txt` des Spielers standardmäßig perfekt sauber bleibt.
- BEHOBEN: Ein kritischer UI-Konflikt wurde gelöst, bei dem DLC-Einstellungen aus dem Spielmenü verschwanden.
- BEHOBEN: Die Groß-/Kleinschreibung von Dateinamen in `main.lua` (`RHM_Combine`, `RHM_Renderer`) wurde korrigiert, wodurch das Einfrieren des Ladebildschirms bei 55% behoben wurde.
- BEHOBEN: Ein Fehler wurde behoben, durch den Änderungen im Einstellungsmenü aufgrund einer ungültigen Callback-Signatur nicht korrekt gespeichert oder synchronisiert wurden.
- BEHOBEN: Der massive Konsolen-Spam (60 Protokolle pro Sekunde) durch "Crop Loss Applied" während der Ernte im Entwicklermodus wurde beseitigt.
- BEHOBEN: XML-Syntaxfehler (`<paragraph>`-Tags) in `modDesc.xml` wurden korrigiert, um sicherzustellen, dass der Text im Hilfemenü perfekt ohne Engine-Warnungen dargestellt wird.
- VERBESSERT: Das UI-Layout wurde auf das standardmäßige `gameSettingsLayout` umgestellt, um eine konsistente Menüpositionierung zu gewährleisten.
- VERBESSERT: Die redundante Schaltfläche "Zurücksetzen" (X) wurde aus der Fußzeile entfernt.
- NEU: 7 detaillierte Seiten zum In-Game-Hilfemenü mit einzigartigen Symbolen und Lokalisierung für 11 Sprachen hinzugefügt.
- VERBESSERT: Der Einstellungs-Injektionsmechanismus wurde auf Klassen-Hooks umgestellt, um die Kompatibilität mit DLCs zu verbessern.
- BEHOBEN: Ein Fehler wurde behoben, durch den Änderungen im Einstellungsmenü aufgrund einer ungültigen Callback-Signatur nicht korrekt gespeichert wurden.
- VERBESSERT: Das UI-Layout wurde auf das standardmäßige `gameSettingsLayout` umgestellt, um eine konsistente Positionierung zu gewährleisten.
- VERBESSERT: Die redundante Schaltfläche "Zurücksetzen" (X) wurde aus der Fußzeile entfernt.
- VERBESSERT: Die Master-Debug-Protokollierung wurde standardmäßig deaktiviert, um die Spielekonsole sauber zu halten.

Changelog 1.4.2.0:
- BEHOBEN: Die maximale Ernte-Geschwindigkeit wird nun streng durch die Basis-Fähigkeiten des Schneidwerks im Spiel begrenzt, wodurch unrealistische Geschwindigkeiten bei Wurzelerntern verhindert werden.
- BEHOBEN: Netzwerk-Desynchronisationsprobleme auf dedizierten Servern behoben, bei denen Client-Einstellungen die Server-Standards überschreiben konnten.
- BEHOBEN: Einen Absturz durch Endlosrekursion im Zusammenhang mit dem Speichern von Mähdrescher-Einstellungen auf Multiplayer-Servern behoben.
- BEHOBEN: Ein Speicherleck in den Puffern für Motorlast- und Produktivitätsberechnungen behoben.
- BEHOBEN: Verhindert, dass Nicht-Admin-Benutzer gelegentlich vorübergehenden Zugriff auf die Server-Einstellungen erhalten.
- VERBESSERT: Durchsatzfaktoren für Zwiebeln und Karotten zur genaueren Berechnung der Motorlast neu kalibriert.
- VERBESSERT: Unnötige Debug-Ausgaben aus den Server-Synchronisationsprotokollen entfernt, um die Konsole sauber zu halten.
- BEHOBEN: Fehler, bei dem Servereinstellungen für Nicht-Admins nach dem erneuten Öffnen des Menüs entsperrt wurden.
- BEHOBEN: Lokalisierungsproblem ('window_grass') für Gras im HUD-Menü behoben.
- VERBESSERT: Übermäßige Debug-Logs bei der Motorlastberechnung entfernt.
- VERBESSERT: Zentralisierte Debug-Log-Konfiguration (RHM_Debug.lua).
- HINZUGEFÜGT: Spanische Lokalisierung für alle Mod-Funktionen und Menüs.
- NEU: Einstellung zum Deaktivieren der "High Load" HUD-Warnungen hinzugefügt.
- VERBESSERT: Interne Bereinigung der Warnlogik.
- BEHOBEN: Komplette Überarbeitung der Ertragsberechnungsmathematik zur perfekten Synchronisation mit dem Precision Farming HUD und individuellen Kartenmaßstäben.
- BEHOBEN: Feldhäcksler (Silage) zeigten aufgrund von Engine-Volumen-Bugs einen 10x niedrigeren Ertrag an.
- BEHOBEN: Mathematische Desynchronisationen beim asynchronen Befüllen des Bunkers.
- NEU: Die Physik der Mähdreschereinstellungen wurde in 2 unabhängige Kategorien unterteilt: Effizienz (beeinflusst Geschwindigkeit) und Ernteverlust.
- NEU: Einstellungsmenü-HUD überarbeitet, um immer Geschwindigkeit und Verlust gleichzeitig anzuzeigen.
- NEU: "Überlastungsschild"-Mechanik hinzugefügt - ideale Einstellungen schützen nun vor plötzlichen Erntedichtespitzen.
- BEHOBEN: Kritischer Fehler, bei dem perfekte Mähdreschereinstellungen die Geschwindigkeit auf Vanilla-Limits reduzieren konnten.
- BEHOBEN: Mähdrescher beschleunigte nicht richtig, wenn die Einstellungen während der Ernte verbessert wurden.
- BEHOBEN: Problem mit doppelter Registrierung von Savegame-XML-Pfaden behoben, das Serverlog-Fehler und das Zurücksetzen von Einstellungen verursachte.
- VERBESSERT: Durchsatz von Feldhäckslern an reale Daten angepasst (Koeffizient von 0,150 auf 0,051 korrigiert).
- NEU: Universelle Erkennung von Pickup-/Schwad-Vorsätzen mit reduziertem Motorlast-Multiplikator (0,75x) hinzugefügt.
- NEU: Automatische Fallback-Zuordnung für '_WINDROW'- und 'CUT_'-FillTypes zu ihren Basiskulturen hinzugefügt.
- VERBESSERT: Präzise Kalibrierung von Fruchtfaktoren und Dichten basierend auf realen Ertragszielen (bu/hr).
- NEU: Jede Frucht verwendet nun individuelle technische Voreinstellungen aus realen Handbüchern (20+ Früchte optimiert).
- VERBESSERT: Feldhäcksler-Logik mit universellem 0,75x Multiplikator vereinfacht.
- VERBESSERT: Pickup-Multiplikator auf 0,35x für ausgewogene Schwadernte angepasst.
- BEHOBEN: Mähdrescher beschleunigen bei leerem Vorsatz (ohne Frucht) nicht більше über das ванільний Limit hinaus.
- BEHOBEN: Sprung des Tempolimits beim Absenken des Vorsatzes entfernt.
- VERBESSERT: Robustes Erkennungssystem für Feldhäcksler und Vorsätze.
- VERBESSERT: Geschwindigkeitslimit streng auf Vanilla-Grenzwerte begrenzt (1,5x Bonus entfernt).
- VERBESSERT: Rekalibrierte Fruchtfaktoren für Hafer (+25 %), Mais (-50 %), Sojabohnen (-20 %) und Baumwolle (2x).
- VERBESSERT: Deutliche Lastreduzierung bei Wurzelfrüchten (Kartoffel, Karotte, Pastinake, Zwiebel).
- BEHOBEN: Geschwindigkeitslimit-"Reset-Schleife" bei 9,9 km/h während der Ernte behoben.
- BEHOBEN: Ausnahme für das Aufnehmen von Wurzelfrüchten erweitert, um eine realistische Last für Zwiebeln und Karotten zu gewährleisten.
- HINZUGEFÜGT: Unterstützung für die Fülltypen ONION_DIRTY und MEADOW.

Changelog 1.4.1.0:
- BEHOBEN: Spielabsturz ("attempt to call missing method 'getIsControlled'") bei Nutzung von Ausrüstung aus DLC-Packs hinzugefügt.
- BEHOBEN: Zweiter Mähdrescher in Courseplay steckte bei 10 km/h fest.
- BEHOBEN: AUTO-Modus-Einstellungen wurden auf dedizierten Servern auf 50 zurückgesetzt.
- BEHOBEN: Das Mähdrescher-Einstellungsmenü öffnete und schloss sich sofort bei Verwendung des NEXAT-Modularsystems.
- BEHOBEN: Möglicher Spielabsturz aufgrund einer fehlenden 'getAIFieldWorkerIsTurning'-Methode.

Changelog 1.4.0.0:
- NEU: Kompatibilität mit "HUD Hider"-Mods hinzugefügt (HUD passt sich der Spielsichtbarkeit an).
- BEHOBEN: Fehler bei der Produktivitätsberechnung (T/h), der plötzliche Sprünge verursachte.
- BEHOBEN: GUI schloss sich unerwartet während des Spiels.
- NEU: Interaktives Mähdrescher-Einstellungs- & Kalibrierungsmenü (RShift + K).
- NEU: Manueller Steuerungsmodus - Anpassung von Gebläse, Rotor, Sieben und Einzug.
- NEU: Falsche Einstellungen verursachen zusätzlichen Ernteverlust (im GUI angezeigt).
- NEU: Profilsystem - Speichern/Laden eigener Einstellungen für jede Fruchtart.
- NEU: Neue Früchte starten mit neutralen (50%) Einstellungen und erfordern Kalibrierung.
- NEU: Ernteverlust-Anzeige zeigt jetzt +/- Zeichen (- für Verluste, + für Boni, 0 für optimal).
- NEU: Manuelle Einstellbuttons (+/-) im Kalibrierungs-GUI immer sichtbar für einfachere Abstimmung.
- BEHOBEN: Kameradrehung wird korrekt blockiert, wenn der Cursor aktiv ist.
- BEHOBEN: HUD setzte sich auf Positionen außerhalb des Bildschirms zurück. Auto-Fix und Reset-Befehl hinzugefügt.
- VERBESSERT: Eingabeblockierung nutzt nun die korrekte camera.isRotatable-Methode.
- VERBESSERT: GUI-Hinweistext neu positioniert, um Überlappung mit Buttons zu verhindern.
- NEU: AUTO-Modus hat jetzt leichte Ungenauigkeit (1-10 Einheiten Abweichung) – manuelles Tuning kann AUTO übertreffen!
- NEU: Gleiche Verlustberechnung für AUTO und MANUAL – kein Null-Verlust-Bypass mehr im AUTO.
- BEHOBEN: Mähdrescher-Einstellungen werden jetzt korrekt im Savegame (vehicles.xml) gespeichert und geladen.
- BEHOBEN: profileCount-Cache wird nach dem Laden des Savegames korrekt wiederhergestellt.
- BEHOBEN: Auto-Erkennung der Fruchtart jetzt nur serverseitig – verhindert Desynchronisation in Multiplayer.
- VERBESSERT: Alle Mod-Einstellungen (Server + Client) werden jetzt im modSettings/-Ordner gespeichert.
- VERBESSERT: Dedizierter Server vollständig unterstützt – jedes Fahrzeug behält sein eigenes Kalibrierungsprofil.

Changelog 1.3.2.0:
- NEU: Physisches Ernteverlustsystem! Verluste reduzieren jetzt das tatsächlich geerntete Getreide.
- NEU: Ernteverluste beginnen bei 95% Motorlast (zuvor 100%).
- NEU: Progressive Verlustformel - höhere Überlastung = exponentiell mehr Verlust.
- VERBESSERT: Verluststrafen wirken sich nun direkt auf den Ernteertrag aus.

Changelog 1.3.1.0:
- NEU: Einstellungsmenü in "Simulation" und "Anzeige" unterteilt.
- NEU: Verschiebbares HUD! Rechtsklick für Cursor, dann HUD ziehen.
- NEU: Unabhängige Schneidwerkssteuerung (optionale Einstellung).
- NEU: HUD-Metriken werden beim Anheben/Stoppen des Schneidwerks sofort zurückgesetzt.
- VERBESSERT: Anpassbarer HUD-Inhalt (einzelne Elemente umschalten).

Changelog 1.3.0.0:
- NEU: Ertragsmonitor! Sehen Sie den Ertrag in Echtzeit in t/ha oder bu/ac (umschaltbar in den Einstellungen) (#10)
- NEU: Komplett überarbeitete Lastberechnungslogik basierend auf Massendurchsatz (t/h) statt Fläche.
- NEU: Experimentelle Unterstützung für das NEXAT-System hinzugefügt.
- VERBESSERT: HUD-Text ist jetzt fett für bessere Lesbarkeit.
- VERBESSERT: Problem behoben, bei dem das HUD beim Wechseln der Fahrzeugkomponenten verschwand.

Changelog 1.2.1.0:
- Produktivitätsberechnung korrigiert (zeigte falsche Werte an - war 1000x zu niedrig)
- Verbesserte Genauigkeit der Masse-zu-Volumen-Konvertierung mit tatsächlicher Erntedichte

Changelog 1.2.0.0:
- Unterstützung für Baumwollernter hinzugefügt
- Teilweise Unterstützung für Feldhäcksler hinzugefügt
- Multiplayer-Synchronisierungsprobleme behoben
- Einstellungsmenü-Konflikt mit anderen Mods
- Einheitensystem-Anzeige verbessert (Imperial/Metrisch)

Changelog 1.1.0.0:
- Neue Funktion: Schaltfläche "Einstellungen zurücksetzen" zur Fußzeile des Einstellungsmenüs hinzugefügt (Taste: X)
- UI-Verbesserungen: Seitenbeschreibungen für alle Einstellungen im Menü hinzugefügt (Tooltips)
- Lokalisation: Vollständige Übersetzungsunterstützung für 10 Sprachen (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Fehlerbehebungen: Verbesserte Stabilität des Einstellungsmenüs

---

## Language: FR

Changelog 1.5.0.0:
- NOUVEAU : Intégration du mod "Moisture System" ! Ajout de pénalités de charge du moteur dynamiques et de pertes de récolte accrues lors de la récolte dans des conditions humides.
- NOUVEAU : Affichage du pourcentage d'humidité en temps réel intégré au HUD déplaçable.
- NOUVEAU : Ajout d'un nouveau paramètre pour activer/désactiver l'intégration du système d'humidité.
- AMÉLIORÉ : Pilote automatique "Charge Cible du Moteur" : Implémentation d'une zone morte de 2 % pour éviter les micro-oscillations et offrir une expérience de régulateur de vitesse beaucoup plus fluide.
- AMÉLIORÉ : Interface de calibrage : "Charge Cible du Moteur" dispose désormais d'une barre de progression dynamique à code couleur (Vert/Jaune/Rouge) pour un meilleur retour visuel au lieu du texte.
- CORRIGÉ : L'indicateur HUD d'humidité restait bloqué à sa dernière valeur au lieu de se réinitialiser à 0 % lorsque la moissonneuse s'arrête ou recule.
- CORRIGÉ : "Charge Cible du Moteur" s'affichait incorrectement comme "auto" dans le menu de calibrage.
- NOUVEAU : Ajout de la commande console de diagnostic `rhm_inspect` pour visualiser les performances en temps réel.
- AMÉLIORÉ : Refonte complète des coefficients de culture utilisant un système de recherche par nom pour une plus grande précision.
- AMÉLIORÉ : Séparation distincte des coefficients pour le Maïs Grain et le Maïs Ensilage pour des vitesses de récolte réalistes.
- AMÉLIORÉ : Coefficients équilibrés pour la récolte de l'herbe et du foin (coupe directe et ramassage).
- AMÉLIORÉ : Multiplicateur de charge du ramasseur affiné (de 0,25 à 0,45) pour les andains de céréales afin de fournir une résistance moteur réaliste.
- NOUVEAU : "Filet de sécurité forage" universel pour garantir des charges réalistes pour les cultures non standard ou modifiées.
- CORRIGÉ : Résolution d'un problème où les barres de coupe d'ensileuse n'étaient pas détectées correctement à cause de la casse des noms de catégories.

Changelog 1.4.3.0:
- NOUVEAU : Système d'Achat ! Ajout de la fonctionnalité permettant d'acheter des paramètres de calibrage avancés pour moissonneuse, ajoutant un nouveau niveau de progression en carrière.
- NOUVEAU : Interface graphique (GUI) de calibrage de moissonneuse entièrement repensée avec une nouvelle sélection de cultures, des améliorations d'interaction et des onglets d'informations supplémentaires.
- NOUVEAU : HUD déplaçable amélioré affichant les performances de la moissonneuse, avec compteurs graphiques pour le rendement et la charge du moteur.
- NOUVEAU : Ajout de 7 pages détaillées au Menu d'Aide du jeu couvrant toutes les mécaniques du mod, avec des icônes uniques et une localisation en 11 langues.
- NOUVEAU : Page de traduction "Perte de Récolte" ajoutée et descriptions du mod affinées dans toutes les langues supportées.
- AMÉLIORÉ : Logique principale de la dépendance de la vitesse à la charge du moteur révisée : les pertes minimales commencent désormais légitimement à 80 % de charge au lieu de 100 %.
- AMÉLIORÉ : Le facteur de charge pour les ensileuses est désormais entièrement dynamique en fonction de la densité de la culture et de la largeur de la coupe.
- AMÉLIORÉ : Refonte du mécanisme d'injection des paramètres utilisant des crochets de moteur sécurisés au niveau des classes (`InGameMenuSettingsFrame.onFrameOpen`) pour une compatibilité maximale avec les DLC (Vredo Pack, Precision Farming, etc.).
- AMÉLIORÉ : Refactorisation globale de l'espace de noms : toutes les classes et fichiers internes ont été renommés avec le préfixe `RHM_` pour éviter les collisions avec d'autres mods.
- AMÉLIORÉ : Architecture de débogage du mod entièrement reconstruite. Toutes les sorties de débogage sont désormais strictement contrôlées par l'indicateur `-devWarnings` du jeu, gardant le `log.txt` de l'utilisateur parfaitement propre par défaut.
- CORRIGÉ : Résolution d'un conflit d'interface utilisateur critique où les paramètres DLC disparaissaient du menu du jeu lorsque le mod était actif.
- CORRIGÉ : Correction de la casse des noms de fichiers dans `main.lua` (`RHM_Combine`, `RHM_Renderer`), résolvant le tristement célèbre blocage de l'écran de chargement à 55 %.
- CORRIGÉ : Résolution d'un bug où les modifications dans le menu des paramètres n'étaient pas correctement enregistrées ou synchronisées avec le serveur à cause d'une signature de rappel non valide.
- CORRIGÉ : Élimination du spam massif de la console (60 journaux par seconde) causé par "Crop Loss Applied" pendant la récolte en mode développeur.
- CORRIGÉ : Correction des erreurs de syntaxe XML (balises `<paragraph>`) dans `modDesc.xml` pour s'assurer que le texte du menu d'aide s'affiche parfaitement sans avertissements du moteur.
- AMÉLIORÉ : Optimisation de la mise en page de l'interface utilisateur pour utiliser le `gameSettingsLayout` standard.
- AMÉLIORÉ : Suppression du bouton "Réinitialiser" (X) redondant dans le pied de page, car il causait une instabilité de la mise en page avec d'autres mods.

Changelog 1.4.2.0:
- CORRIGÉ : La vitesse de récolte maximale est désormais strictement limitée par les capacités de la barre de coupe du jeu de base, empêchant les arracheuses de racines de dépasser des vitesses réalistes.
- CORRIGÉ : Résolution des problèmes de désynchronisation réseau sur les serveurs dédiés où les paramètres des clients pouvaient écraser les paramètres par défaut du serveur.
- CORRIGÉ : Résolution d'un plantage par récursion infinie lié à la sauvegarde des paramètres des moissonneuses sur les serveurs multijoueurs.
- CORRIGÉ : Correction d'une fuite de mémoire dans les buffers de calcul de charge moteur et de productivité.
- CORRIGÉ : Empêché les utilisateurs non-administrateurs d'obtenir occasionnellement un accès temporaire aux paramètres du serveur.
- AMÉLIORÉ : Facteurs de rendement pour les oignons et les carottes recalibrés pour des calculs de charge moteur plus précis.
- AMÉLIORÉ : Suppression des sorties de débogage inutiles dans les journaux de synchronisation du serveur pour garder la console propre.
- CORRIGÉ: Bogue où les paramètres du serveur devenaient déverrouillés pour les joueurs non-administrateurs après avoir rouvert le menu.
- CORRIGÉ: Problème de localisation ('window_grass') pour l'herbe dans le menu HUD.
- AMÉLIORÉ: Suppression des logs de débogage excessifs.
- AMÉLIORÉ: Configuration centralisée des logs de débogage (RHM_Debug.lua).
- AJOUTÉ: Localisation espagnole pour toutes les fonctionnalités et menus du mod.
- NOUVEAU: Paramètre ajouté pour désactiver les avertissements HUD "High Load".
- AMÉLIORÉ: Nettoyage interne de la logique d'avertissement.
- CORRIGÉ: Refonte complète du calcul du rendement pour synchroniser parfaitement avec le HUD Precision Farming.
- CORRIGÉ: Les ensileuses (Silage) affichaient un rendement 10x inférieur à cause de bugs de volume moteur.
- CORRIGÉ: Désynchronisations mathématiques lors du remplissage asynchrone du bunker.
- NOUVEAU: Physique des réglages de la moissonneuse séparée en deux catégories indépendantes : Efficacité (vitesse) et Perte de récolte.
- NOUVEAU: HUD du menu des réglages repensé pour afficher simultanément l'impact de la vitesse et des pertes.
- NOUVEAU: Ajout d'une mécanique de "Bouclier de surcharge".
- CORRIGÉ: Bug critique où des réglages parfaits réduisaient involontairement la vitesse.
- CORRIGÉ: Accélération corrigée lorsque les réglages sont améliorés en cours de récolte.
- CORRIGÉ: Résolution de la double inscription des chemins XML de sauvegarde causant des erreurs dans les logs du serveur et la réinitialisation des paramètres.
- AMÉLIORÉ: Débit de l'ensileuse calibré sur des données réelles (coefficient ajusté de 0,150 à 0,051).
- NOUVEAU: Ajout de la détection universelle des ramasseurs/swath avec un multiplicateur de charge moteur réduit (0,75x).
- NOUVEAU: Ajout du mappage de secours automatique pour les types de remplissage '_WINDROW' et 'CUT_' vers leurs cultures de base.
- AMÉLIORÉ: Étalonnage précis des facteurs de culture et des densités basé sur des objectifs de rendement réels (bu/hr).
- NOUVEAU : Chaque culture utilise désormais des préréglages techniques individuels issus de manuels réels (20+ cultures affinées).
- AMÉLIORÉ : Logique de l'ensileuse simplifiée avec un multiplicateur universel de 0,75x.
- AMÉLIORÉ : Multiplicateur de ramassage affiné à 0,35x pour une récolte équilibrée des andains.
- CORRIGÉ : Les moissonneuses ne dépassent plus les vitesses de travail vanilla lorsque la coupe est vide (pas de récolte).
- CORRIGÉ : Suppression du saut de la limite de vitesse lors de l'abaissement de la coupe.
- AMÉLIORÉ : Système de détection robuste pour les ensileuses et les barres de coupe.
- AMÉLIORÉ : Limite de vitesse strictement plafonnée aux limites du jeu vanilla (suppression du bonus 1,5x).
- AMÉLIORÉ : Recalibrage des facteurs de culture pour l'avoine (+25 %), le maïs (-50 %), le soja (-20 %) et le coton (2x).
- AMÉLIORÉ : Réduction significative de la charge pour les cultures racines (pomme de terre, carotte, panais, oignon).
- CORRIGÉ : Correction de la boucle de réinitialisation de la limite de vitesse à 9,9 km/h pendant la récolte continue.
- CORRIGÉ : Élargissement de l'exception de ramassage des cultures racines pour garantir une charge réaliste pour l'oignon et la carotte.
- AJOUTÉ : Prise en charge des types de remplissage ONION_DIRTY et MEADOW.

Changelog 1.4.1.0:
- CORRIGÉ: Crash du jeu ("attempt to call missing method 'getIsControlled'") lors de l'utilisation d'équipements DLC (ex: Highland DLC NH 8040 avec les outils Holaras). Vérification nil sécurisée ajoutée.

Changelog 1.4.1.0:
- CORRIGÉ : Plantage du jeu ("attempt to call missing method 'getIsControlled'") lors de l'utilisation d'équipements de DLC.
- CORRIGÉ : La deuxième moissonneuse avec Courseplay restait bloquée à 10 km/h.
- CORRIGÉ : Le mode AUTO se réinitialisait à 50 sur les serveurs dédiés.
- CORRIGÉ : Le menu des paramètres de la moissonneuse se fermait immédiatement avec le système modulaire NEXAT.
- CORRIGÉ : Plantage du jeu lié à l'absence de la méthode 'getAIFieldWorkerIsTurning'.

Changelog 1.4.0.0:
- NOUVEAU: Compatibilité ajoutée avec les mods "HUD Hider" (le HUD s'aligne sur la visibilité du jeu).
- CORRIGÉ: Bug de calcul de la productivité (T/h) causant des sauts soudains.
- CORRIGÉ: Fermeture inattendue de l'interface graphique pendant le jeu.
- NOUVEAU: Menu interactif de réglages et de calibrage de la moissonneuse (RShift + K).
- NOUVEAU: Mode de contrôle manuel - Ajustez le ventilateur, le rotor, les tamis et le convoyeur.
- NOUVEAU: Des réglages incorrects entraînent des pertes de récolte supplémentaires.
- NOUVEAU: Système de profils - Sauvegardez/Chargez des réglages personnalisés pour chaque culture.
- NOUVEAU: Les nouvelles cultures commencent avec des réglages neutres (50%), nécessitant un calibrage.
- NOUVEAU: L'affichage des pertes montre maintenant des signes +/- (- pour pertes, + pour bonus, 0 pour optimal).
- NOUVEAU: Boutons de réglage manuel (+/-) toujours visibles dans l'interface de calibrage.
- CORRIGÉ: Rotation de la caméra correctement bloquée lorsque le curseur est actif.
- CORRIGÉ: Réinitialisation du HUD hors écran. Ajout d'une correction automatique.
- AMÉLIORÉ: Blocage des entrées utilise maintenant la méthode correcte camera.isRotatable.
- AMÉLIORÉ: Texte d'aide repositionné pour éviter le chevauchement avec les boutons.
- NOUVEAU: Le mode AUTO a maintenant une légère imperfection (1-10 unités) – le réglage manuel peut surpasser l'AUTO!
- NOUVEAU: Même calcul de pertes pour AUTO et MANUEL – plus de bypass zéro-perte en AUTO.
- CORRIGÉ: Les réglages de la moissonneuse sont maintenant correctement sauvegardés dans le savegame.
- CORRIGÉ: Cache profileCount correctement restauré après le chargement de la sauvegarde.
- CORRIGÉ: Détection automatique de culture maintenant côté serveur uniquement – évite la désynchronisation en multijoueur.
- AMÉLIORÉ: Tous les paramètres du mod (serveur + client) stockés dans le dossier modSettings/.
- AMÉLIORÉ: Serveur dédié entièrement supporté – chaque véhicule conserve son propre profil de calibrage.

Changelog 1.3.2.0:
- NOUVEAU: Système de perte de récolte physique! Les pertes réduisent maintenant le grain réellement collecté.
- NOUVEAU: Les pertes de récolte commencent à 95% de charge moteur (au lieu de 100%).
- NOUVEAU: Formule de perte progressive - surcharge plus élevée = perte exponentiellement plus grande.
- AMÉLIORÉ: Les pénalités par pertes affectent maintenant directement le rendement.

Changelog 1.3.1.0:
- NOUVEAU: Le menu des paramètres est réorganisé en sections "Simulation" et "Affichage".
- NOUVEAU: HUD déplaçable ! Clic droit pour le curseur, puis faites glisser le HUD.
- NOUVEAU: Contrôle indépendant de la barre de coupe (paramètre optionnel).
- NOUVEAU: Les mesures du HUD se réinitialisent instantanément lorsque la coupe est levée/arrêtée.
- AMÉLIORÉ: Contenu du HUD personnalisable (basculer les éléments individuels).

Changelog 1.3.0.0:
- NOUVEAU: Moniteur de rendement! Voir le rendement en temps réel en t/ha ou bu/ac (activable dans les paramètres) (#10)
- NOUVEAU: Logique de calcul de charge entièrement réécrite basée sur le débit massique (t/h) au lieu de la surface.
- NOUVEAU: Ajout du support expérimental pour le système NEXAT.
- AMÉLIORÉ: Le texte du HUD est maintenant en gras pour une meilleure visibilité.
- AMÉLIORÉ: Correction du problème où le HUD disparaissait lors du changement de composants du véhicule.

Changelog 1.2.1.0:
- Correction du calcul de productivité affichant des valeurs incorrectes (était 1000x trop bas)
- Amélioration de la précision de la conversion masse-volumen avec la densité réelle des cultures

Changelog 1.2.0.0:
- Ajout du support pour les moissonneuses à coton
- Ajout du support partiel pour les ensileuses
- Correction des problèmes de synchronisation multijoueur
- Correction du conflit du menu des paramètres avec d'autres mods
- Amélioration de l'affichage du système d'unités (Impérial/Métrique)

Changelog 1.1.0.0:
- Nouvelle fonctionnalité: Bouton "Réinitialiser les paramètres" dans le pied de page du menu (touche: X)
- Améliorations de l'interface: Descriptions latérales pour tous les paramètres (infobulles)
- Localisation: Support de traduction complet pour 10 langues (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Corrections de bugs: Amélioration de la stabilité du menu des paramètres

---

## Language: PL

Changelog 1.5.0.0:
- NOWOŚĆ: Integracja z modyfikacją "Moisture System"! Dodano dynamiczne kary do obciążenia silnika oraz zwiększone straty plonów podczas zbiorów w wilgotnych warunkach.
- NOWOŚĆ: Odczyt procentowy wilgotności w czasie rzeczywistym zintegrowany z przenośnym HUD-em.
- NOWOŚĆ: Dodano nowe ustawienie do włączania/wyłączania integracji systemu wilgotności.
- ULEPSZONO: Autopilot "Docelowe Obciążenie Silnika": Wprowadzono 2% martwą strefę, aby zapobiec mikroskokom prędkości i zapewnić płynniejsze działanie tempomatu przy zmiennej gęstości plonów.
- ULEPSZONO: GUI Kalibracji: "Docelowe Obciążenie Silnika" zawiera teraz dynamiczny, kolorowy pasek postępu (Zielony/Żółty/Czerwony) zamiast zwykłego tekstu, co zapewnia lepszą informację zwrotną.
- NAPRAWIONO: Wskaźnik wilgotności HUD zamrażał się na ostatniej wartości zamiast resetować się do 0%, gdy kombajn przerywał zbiór lub cofał.
- NAPRAWIONO: "Docelowe Obciążenie Silnika" błędnie wyświetlało się jako "auto" w menu kalibracji.
- NOWOŚĆ: Dodano komendę konsoli `rhm_inspect` do diagnostyki danych wydajności kombajnu w czasie rzeczywistym.
- ULEPSZONO: Całkowita przebudowa współczynników upraw przy użyciu systemu wyszukiwania po nazwie dla większej precyzji.
- ULEPSZONO: Wyraźny podział współczynników dla Kukurydzy na Ziarno i Kukurydzy na Kiszonkę dla realistycznych prędkości zbioru.
- ULEPSZONO: Zbalansowane współczynniki dla zbioru trawy i siana (cięcie bezpośrednie i podbieracz).
- ULEPSZONO: Dopracowano mnożnik obciążenia podbieracza (z 0,25 na 0,45) dla pokosów zboża, aby zapewnić realistyczny opór silnika.
- NOWOŚĆ: Uniwersalny „Forage Safety Net” zapewniający realistyczne obciążenia dla niestandardowych lub modowanych upraw przetwarzanych przez sieczkarnie.
- NAPRAWIONO: Rozwiązano problem, w którym hedery sieczkarni nie były wykrywane poprawnie z powodu wielkości liter w nazwach kategorii.

Changelog 1.4.3.0:
- NOWOŚĆ: System Zakupów! Dodano funkcjonalność zakupu zaawansowanych ustawień kalibracji kombajnu, wprowadzając nowy poziom progresji kariery.
- NOWOŚĆ: Całkowicie zaprojektowane od nowa interaktywne menu GUI kalibracji kombajnu z nowym wyborem upraw, poprawkami interakcji i dodatkowymi zakładkami informacyjnymi.
- NOWOŚĆ: Ulepszony przenośny HUD wyświetlający wydajność kombajnu, w tym graficzne wskaźniki plonu i obciążenia silnika.
- NOWOŚĆ: Dodano 7 szczegółowych stron do menu Pomocy w grze obejmujących wszystkie mechaniki modyfikacji, z unikalnymi niestandardowymi ikonami i lokalizacją dla 11 języków.
- NOWOŚĆ: Dodano stronę tłumaczenia "Straty Plonów" oraz poprawiono opisy modyfikacji we wszystkich wspieranych językach.
- ULEPSZONO: Zrewidowana podstawowa logika zależności prędkości od obciążenia silnika: minimalne straty upraw zaczynają się teraz od 80% obciążenia zamiast 100%.
- ULEPSZONO: Współczynnik obciążenia dla sieczkarni polowych jest teraz w pełni dynamiczny na podstawie gęstości uprawy i szerokości hedera.
- ULEPSZONO: Przebudowano mechanizm wstrzykiwania ustawień, aby używał bezpiecznych hooków na poziomie klas silnika (`InGameMenuSettingsFrame.onFrameOpen`) dla maksymalnej kompatybilności z dodatkami DLC (Vredo Pack, Precision Farming itp.).
- ULEPSZONO: Globalny Refaktoring Przestrzeni Nazw: Wszystkie wewnętrzne klasy i pliki zostały przemianowane za pomocą prefiksu `RHM_`, aby zapobiec kolizjom z innymi modyfikacjami.
- ULEPSZONO: Całkowicie przebudowano architekturę debugowania modyfikacji. Wszystkie wyjścia debugowania są teraz ściśle zablokowane za flagą gry `-devWarnings`, dzięki czemu plik `log.txt` użytkownika pozostaje domyślnie idealnie czysty.
- NAPRAWIONO: Rozwiązano krytyczny konflikt interfejsu, w którym ustawienia DLC znikały z menu gry, gdy modyfikacja była aktywna.
- NAPRAWIONO: Poprawiono wielkość liter nazw plików w `main.lua` (`RHM_Combine`, `RHM_Renderer`), rozwiązując problem z zawieszaniem się ekranu ładowania na 55%.
- NAPRAWIONO: Rozwiązano problem, z błędem w wyniku którego zmiany w menu ustawień nie były poprawnie zapisywane lub synchronizowane do serwera z powodu nieprawidłowej sygnatury callbacku.
- NAPRAWIONO: Wyeliminowano masowy spam w konsoli (60 dzienników na sekundę) spowodowany przez "Crop Loss Applied" podczas zbiorów w trybie deweloperskim.
- NAPRAWIONO: Poprawiono błędy składni XML (tagi `<paragraph>`) w `modDesc.xml`, aby upewnić się, że tekst z menu Pomocy jest poprawnie renderowany bez ostrzeżeń silnika.
- ULEPSZONO: Zoptymalizowano układ interfejsu, aby używał standardowego `gameSettingsLayout` w celu ciągłego i poprawnego pozycjonowania menu.
- ULEPSZONO: Usunięto zbędny przycisk "Zresetuj" (X) ze stopki, ponieważ powodował niestabilność układu wraz z innymi modami.

Changelog 1.4.2.0:
- NAPRAWIONO: Maksymalna prędkość zbioru jest teraz ściśle ograniczona możliwościami hedera z podstawowej gry, zapobiegając przekraczaniu realistycznych prędkości przez kombajny do buraków/ziemniaków.
- NAPRAWIONO: Rozwiązano problemy z desynchronizacją sieci na serwerach dedykowanych, gdzie ustawienia klienta mogły nadpisać domyślne ustawienia serwera.
- NAPRAWIONO: Rozwiązano problem z nieskończoną rekurencją powodującą awarię gry związaną z zapisywaniem ustawień kombajnu na serwerach wieloosobowych.
- NAPRAWIONO: Poprawiono wyciek pamięci w buforach obliczeń obciążenia silnika i wydajności.
- NAPRAWIONO: Zapobieżono przypadkowemu tymczasowemu dostępowi użytkowników bez uprawnień administratora do ustawień serwera.
- ULEPSZONO: Współczynniki przepustowości dla cebuli i marchwi zostały ponownie skalibrowane w celu dokładniejszego obliczania obciążenia silnika.
- ULEPSZONO: Usunięto niepotrzebne komunikaty debugowania z logów synchronizacji serwera, aby utrzymać konsolę w czystości.
- NAPRAWIONO: Błąd polegający na odblokowaniu ustawień serwera dla graczy niebędących administratorami po ponownym otwarciu menu.
- NAPRAWIONO: Problem z lokalizacją ('window_grass') dla trawy w menu HUD.
- ULEPSZONO: Usunięto nadmierne logi debugowania.
- ULEPSZONO: Scentralizowana konfiguracja logów debugowania (RHM_Debug.lua).
- DODANO: Hiszpańska lokalizacja dla wszystkich funkcji i menu moda.
- NOWOŚĆ: Dodano opcję wyłączania ostrzeżeń HUD "High Load".
- ULEPSZONO: Wewnętrzne oczyszczenie logiki ostrzeżeń.
- NAPRAWIONO: Całkowita przebudowa matematyki obliczania plonów dla synchronizacji z HUD Precision Farming.
- NAPRAWIONO: Sieczkarnie (Silage) wyświetlały 10x niższy plon z powodu błędów silnika.
- NAPRAWIONO: Desynchronizacje matematyczne przy asynchronicznym napełnianiu zbiornika.
- NOWOŚĆ: Fizyka ustawień kombajnu podzielona na dwie niezależne kategorie: Wydajność (wpływa na prędkość) i Straty plonów.
- NOWOŚĆ: Przebudowano HUD menu ustawień, aby zawsze jednocześnie wyświetlać wpływ na prędkość i straty.
- NOWOŚĆ: Dodano mechanikę "Tarczy Przeciążeniowej".
- NAPRAWIONO: Krytyczny błąd, w którym idealne ustawienia mogły niezamierzenie zmniejszyć prędkość.
- NAPRAWIONO: Kombajn nie przyspieszał prawidłowo po poprawieniu ustawień w trakcie zbiorів.
- NAPRAWIONO: Rozwiązano problem podwójnej rejestracji ścieżek XML zapisu gry, powodujący błędy w logach serwera i resetowanie ustawień.
- ULEPSZONO: Wydajność sieczkarni samojezdnych skalibrowana zgodnie z rzeczywistymi danymi (współczynnik skorygowany z 0,150 do 0,051).
- NOWOŚĆ: Dodano uniwersalne wykrywanie podbieraczy/pokosów z niższym mnożnikiem obciążenia silnika (0,75x).
- NOWOŚĆ: Dodano automatyczne mapowanie rezerwowe dla typów wypełnienia '_WINDROW' i 'CUT_' do ich upraw podstawowych.
- ULEPSZONO: Precyzyjna kalibracja współczynników i gęstości upraw oparta na rzeczywistych celach plonowania (bu/hr).
- NOWOŚĆ: Każda uprawa używa teraz indywidualnych ustawień technicznych z prawdziwych instrukcji (ponad 20 upraw).
- ULEPSZONO: Uproszczono logikę sieczkarni z uniwersalnym mnożnikiem 0,75x.
- ULEPSZONO: Mnożnik podbieracza dostosowany do 0,35x dla zrównoważonego zbioru pokosów.
- NAPRAWIONO: Kombajny nie przyspieszają już powyżej prędkości roboczych vanilla, gdy heder jest pusty (brak plonu).
- NAPRAWIONO: Usunięto skok limitu prędkości podczas opuszczania hedera.
- ULEPSZONO: Solidny system wykrywania sieczkarni i hederów.
- ULEPSZONO: Limit prędkości ściśle ograniczony do limitów gry vanilla (usunięto bonus 1,5x).
- ULEPSZONO: Skalibrowano czynniki upraw dla owsa (+25%), kukurydzy (-50%), soi (-20%) i bawełny (2x).
- ULEPSZONO: Znaczna redukcja obciążenia dla roślin okopowych (ziemniaki, marchew, pasternak, cebula).
- NAPRAWIONO: Błąd resetowania limitu prędkości przy 9,9 km/h podczas ciągłego zbioru.
- NAPRAWIONO: Rozszerzono wyjątek podbierania roślin okopowych, aby zapewnić realistyczne obciążenie dla cebuli i marchwi.
- ULEPSZONO: Usunięto niepotrzebne komunikaty debugowania z logów synchronizacji serwera, aby utrzymać konsolę w czystości.
- DODANO: Obsługę typów ONION_DIRTY i MEADOW.

Changelog 1.4.1.0:
- NAPRAWIONO: Crash gry ("attempt to call missing method 'getIsControlled'") podczas używania pojazdów z DLC (np. Highland DLC NH 8040 z narzędziami Holaras). Dodano bezpieczne sprawdzenie nil.

Changelog 1.4.1.0:
- NAPRAWIONO: Awaria gry ("attempt to call missing method 'getIsControlled'") podczas używania sprzętu z DLC.
- NAPRAWIONO: Drugi kombajn w Courseplay blokował się na 10 km/h.
- NAPRAWIONO: Resetowanie ustawień trybu AUTO do 50 na serwerach dedykowanych.
- NAPRAWIONO: Menu ustawień otwierało się i zamykało natychmiast w systemie modułowym NEXAT.
- NAPRAWIONO: Potencjalna awaria gry z brakująca funkcją 'getAIFieldWorkerIsTurning'.

Changelog 1.4.0.0:
- NOWOŚĆ: Dodano kompatybilność z modami "HUD Hider".
- NAPRAWIONO: Błąd obliczania produktywności (T/h), powodujący nagłe skoki.
- NAPRAWIONO: Nieoczekiwane zamykanie GUI podczas rozgrywki.
- NOWOŚĆ: Interaktywne menu ustawień i kalibracji kombajnu (RShift + K).
- NOWOŚĆ: Tryb sterowania ręcznego - Regulacja wentylatora, rotora, sit i podajnika.
- NOWOŚĆ: Nieprawidłowe ustawienia powodują dodatkowe straty plonów.
- NOWOŚĆ: System profili - Zapisuj/Wczytuj własne ustawienia dla każdej uprawy.
- NOWOŚĆ: Nowe uprawy zaczynają z neutralnymi (50%) ustawieniami, wymagającymi kalibracji.
- NOWOŚĆ: Wyświetlanie strat pokazuje teraz znaki +/- (- dla strat, + dla bonusów, 0 dla optimum).
- NOWOŚĆ: Przyciski ręcznej regulacji (+/-) zawsze widoczne w GUI kalibracji.
- NAPRAWIONO: Obrót kamery poprawnie zablokowany, gdy kursor jest aktywny.
- NAPRAWIONO: Resetowanie HUD do pozycji poza ekranem. Dodano automatyczną naprawę.
- ULEPSZONO: Blokowanie wejścia używa teraz poprawnej metody camera.isRotatable.
- ULEPSZONO: Tekst podpowiedzi GUI przesunięty, aby zapobiec nakładaniu się na przyciski.
- NOWOŚĆ: Tryb AUTO teraz ma lekką niedoskonałość (1-10 jednostek odchylenia) – ręczne strojenie może przewyższyć AUTO!
- NOWOŚĆ: Taka sama matematyka strat dla AUTO i MANUAL – brak bypassu zerowych strat w AUTO.
- NAPRAWIONO: Ustawienia kombajnu teraz poprawnie zapisywane i wczytywane z sejwu (vehicles.xml).
- NAPRAWIONO: Cache profileCount poprawnie przywracany po wczytaniu sejwu.
- NAPRAWIONO: Automatyczne wykrywanie uprawy teraz tylko po stronie serwera – zapobiega desynchro w multi.
- ULEPSZONO: Wszystkie ustawienia moda (serwer + klient) przechowywane w folderze modSettings/.
- ULEPSZONO: Dedykowany serwer w pełni obsługiwany – każdy pojazd zachowuje własny profil kalibracji.

Changelog 1.3.2.0:
- NOWOŚĆ: Fizyczny system strat plonów! Straty teraz zmniejszają rzeczywiście zebraną ilość ziarna.
- NOWOŚĆ: Straty plonów zaczynają się przy 95% obciążenia silnika (poprzednio 100%).
- NOWOŚĆ: Progresywna formuła strat - większe przeciążenie = wykładniczo większe straty.
- ULEPSZONO: Kary za straty wpływają teraz bezpośrednio na plon.

Changelog 1.3.1.0:
- NOWOŚĆ: Menu ustawień zreorganizowane w sekcje "Symulacja" i "Wyświetlanie".
- NOWOŚĆ: Przenośny HUD! Prawy przycisk dla kursora, a następnie przeciągnij HUD.
- NOWOŚĆ: Niezależne sterowanie hederem (opcjonalne ustawienie).
- NOWOŚĆ: Metryki HUD resetują się natychmiast po podniesieniu/zatrzymaniu hedera.
- ULEPSZONO: Konfigurowalna zawartość HUD (przełączanie poszczególnych elementów).

Changelog 1.3.0.0:
- NOWOŚĆ: Monitor plonów! Zobacz plon w czasie rzeczywistym w t/ha lub bu/ac (umschaltbar in den Einstellungen) (#10)
- NOWOŚĆ: Całkowicie przepisana logika obliczania obciążenia oparta na przepustowości masy (t/h) zamiast powierzchni.
- NOWOŚĆ: Dodano eksperymentalne wsparcie dla systemu NEXAT.
- ULEPSZONO: Tekst HUD jest teraz pogrubiony dla lepszej widoczności.
- ULEPSZONO: Naprawiono problem znikania HUD podczas przełączania elementów pojazdu.

Changelog 1.2.1.0:
- Naprawiono obliczanie produktywności wyświetlające nieprawidłowe wartości (było 1000x za niskie)
- Poprawiono dokładność konwersji masy na objętość przy użyciu rzeczywistej gęstości plonów

Changelog 1.2.0.0:
- Dodano wsparcie dla kombajnów bawełnianych
- Dodano częściowe wsparcie dla sieczkarni
- Naprawiono problemy z synchronizacją w trybie wieloosobowym
- Naprawiono konflikt menu ustawień z innymi modami
- Poprawiono wyświetlanie systemu jednostek (Imperialny/Metryczny)

Changelog 1.1.0.0:
- Nowa funkcja: Przycisk "Resetuj ustawienia" w stopce menu (klawisz: X)
- Ulepszenia interfejsu: Opisy boczne dla wszystkich ustawień (podpowiedzi)
- Lokalizacja: Pełne wsparcie tłumaczeń dla 10 języków (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Poprawki błędów: Poprawiona stabilność menu ustawień

---

## Language: ES

Changelog 1.5.0.0:
- NUEVO: ¡Integración del Mod "Moisture System"! Se agregaron penalizaciones dinámicos de carga del motor y mayores pérdidas de cosecha al cosechar en condiciones húmedas.
- NUEVO: Lectura del porcentaje de humedad en tiempo real integrada en el HUD desplazable.
- NUEVO: Se agregó una nueva configuración para activar/desactivar la integración del sistema de humedad.
- MEJORADO: Piloto automático de "Carga de Motor Objetivo": Se implementó una zona muerta del 2% para evitar micro-oscilaciones y ofrecer una experiencia de control de crucero mucho más suave a través de densidades de cultivo variables.
- MEJORADO: GUI de calibración: "Carga de Motor Objetivo" ahora cuenta con una barra de progreso dinámica codificada por colores (Verde/Amarillo/Rojo) para una mejor respuesta visual en lugar de texto simple.
- CORREGIDO: El indicador HUD de humedad se congelaba en su último valor en lugar de restablecerse a 0% cuando la cosechadora detiene la cosecha o retrocede.
- CORREGIDO: "Carga de Motor Objetivo" se mostraba incorrectamente como "auto" en el menú de calibración.
- NUEVO: Se agregó el comando de consola de diagnóstico `rhm_inspect` para ver datos de rendimiento en tiempo real.
- MEJORADO: Revisión completa de los coeficientes de cultivo utilizando un sistema de búsqueda basado en nombres para mayor precisión.
- MEJORADO: Separación clara entre los coeficientes de Maíz Grano y Maíz Silo para velocidades de cosecha realistas.
- MEJORADO: Coeficientes equilibrados para la cosecha de Hierba y Heno (corte directo y recolector).
- MEJORADO: Se ajustó el multiplicador de carga del recolector (de 0.25 a 0.45) para hileras de grano para proporcionar una resistencia del motor realista.
- NUEVO: "Red de seguridad de forraje" universal para garantizar cargas realistas para cultivos no estándar o modificados.
- CORREGIDO: Se resolvió un problema por el cual los cabezales de picadoras de forraje no se detectaban correctamente debido a la distinción entre mayúsculas y minúsculas en los nombres de las categorías.

Changelog 1.4.3.0:
- NUEVO: ¡Sistema de Compras! Se agregó la funcionalidad para comprar ajustes de calibración avanzados de la cosechadora, añadiendo una nueva capa de progresión en el modo carrera.
- NUEVO: Se rediseñó completamente la interfaz gráfica (GUI) de calibración de la cosechadora con nueva selección de cultivos, mejoras de interacción y pestañas de información adicionales.
- NUEVO: HUD desplazable mejorado que muestra el rendimiento de la cosechadora, incluidos medidores gráficos para el rendimiento y la carga del motor.
- NUEVO: Se agregaron 7 páginas detalladas al Menú de Ayuda del juego que cubren todas las mecánicas del mod, con iconos únicos e idiomas en 11 lenguajes.
- NUEVO: Se añadió la página de traducción "Pérdida de Cosecha" y se refinaron las descripciones del mod en todos los idiomas compatibles.
- MEJORADO: Se revisó la lógica principal de dependencia de la velocidad en la carga del motor: las pérdidas mínimas de cosecha ahora comienzan legítimamente en un 80% de carga en lugar de 100%.
- MEJORADO: El factor de carga para las picadoras de forraje ahora es completamente dinámico basado en la densidad del cultivo y el ancho de corte.
- MEJORADO: Se refactorizó el mecanismo de inyección de ajustes para usar ganchos a nivel de clase seguros (`InGameMenuSettingsFrame.onFrameOpen`) para una máxima compatibilidad con los DLC (Vredo Pack, Precision Farming, etc.).
- MEJORADO: Refactorización global del espacio de nombres: Todas las clases y archivos internos fueron renombrados con el prefijo `RHM_` para evitar colisiones con otros mods de terceros.
- MEJORADO: Se reconstruyó completamente la arquitectura de depuración del mod. Todos los registros de depuración ahora están estrictamente bloqueados detrás de la bandera `-devWarnings` del juego, manteniendo el `log.txt` del usuario perfectamente limpio por defecto.
- CORREGIDO: Se resolvió un conflicto crítico de la interfaz de usuario donde los ajustes de DLC desaparecían del menú del juego cuando Realistic Harvesting estaba activo.
- CORREGIDO: Se corrigió la capitalización de nombres de archivo en `main.lua` (`RHM_Combine`, `RHM_Renderer`), resolviendo el infame bloqueo de pantalla de carga al 55%.
- CORREGIDO: Se resolvió un error por el cual los cambios en el menú de ajustes no se guardaban o sincronizaban correctamente con el servidor debido a una firma de devolución de llamada inválida.
- CORREGIDO: Se eliminó el spam masivo de consola (60 registros por segundo) causado por "Crop Loss Applied" durante la cosecha en el modo de desarrollador.
- CORREGIDO: Se corrigieron los errores de sintaxis XML (etiquetas `<paragraph>`) en `modDesc.xml` para garantizar que el texto del Menú de Ayuda se renderice perfectamente sin advertencias del motor.
- MEJORADO: Se optimizó el diseño de la interfaz de usuario para usar el `gameSettingsLayout` estándar para un posicionamiento consistente del menú.
- MEJORADO: Se eliminó el botón de "Restablecer" (X) redundante en el pie de página, ya que causaba inestabilidad en el diseño con otros mods.
- MEJORADO: Se desactivó el registro de depuración principal de forma predeterminada.

Changelog 1.4.2.0:
- CORREGIDO: La velocidad máxima de cosecha ahora está estrictamente limitada por la capacidad del cabezal del juego base, impidiendo que las cosechadoras de raíces excedan velocidades realistas.
- CORREGIDO: Se abordaron los problemas de desincronización de red en servidores dedicados donde la configuración del cliente podía sobrescribir los valores predeterminados del servidor.
- CORREGIDO: Se resolvió un bloqueo de recursividad infinita relacionado con el guardado de la configuración de las cosechadoras en servidores multijugador.
- CORREGIDO: Se corrigió una fuga de memoria en los búferes de cálculo de carga del motor y productividad.
- CORREGIDO: Se impidió que los usuarios sin privilegios de administrador obtuvieran acceso temporal ocasional a la configuración del servidor.
- MEJORADO: Los factores de rendimiento para cebollas y zanahorias se recalibraron para cálculos de carga del motor más precisos.
- MEJORADO: Se eliminó la salida de depuración innecesaria de los registros de sincronización del servidor para mantener la consola limpia.
- CORREGIDO: Error donde la configuración del servidor se desbloqueaba para jugadores no administradores tras reabrir el menú.
- CORREGIDO: Problema de localización ('window_grass') para hierba en el menú HUD.
- MEJORADO: Eliminación de registros de depuración excesivos.
- MEJORADO: Configuración centralizada de registros de depuración (RHM_Debug.lua).
- AÑADIDO: Localización española para todas las características y menús del mod.
- NUEVO: Ajuste añadido para desactivar los avisos HUD "High Load".
- MEJORADO: Limpieza interna de la lógica de avisos.
- CORREGIDO: Revisión completa del cálculo del rendimiento para sincronizar perfecto con HUD Precision Farming.
- CORREGIDO: Las cosechadoras de forraje mostraban rendimiento 10x inferior por bugs de volumen.
- CORREGIDO: Desincronizaciones matemáticas al llenar el búnker de forma asíncrona.
- NUEVO: La física de los ajustes de la cosechadora se divide en dos categorías: Eficiencia (velocidad) y Pérdida de Cosecha.
- NUEVO: El menú HUD rediseñado para mostrar siempre simultáneamente el impacto en velocidad y pérdida.
- NUEVO: Añadida la mecánica 'Escudo de Sobrecarga'.
- CORREGIDO: Error crítico en el que unos ajustes perfectos podían reducir involuntariamente la velocidad.
- CORREGIDO: La cosechadora no aceleraba correctamente al mejorar los ajustes en marcha.
- CORREGIDO: Se resolvió el registro duplicado de las rutas XML de guardado que causaba errores en el registro del servidor y el reinicio de los ajustes.
- MEJORADO: Rendimiento de la picadora de forraje calibrado con datos reales (coeficiente ajustado de 0,150 a 0,051).
- NUEVO: Añadida detección universal de cabezales recogedores/hileradores con un multiplicador de carga de motor más bajo (0,75x).
- NUEVO: Mapeo de respaldo automático añadido para los fillTypes '_WINDROW' y 'CUT_' a sus cultivos base.
- MEJORADO: Calibración de precisión de los factores de cultivo y densidades basada en objetivos de rendimiento reales (bu/hr).
- NUEVO: Cada cultivo ahora utiliza preajustes técnicos individuales de manuales reales (más de 20 cultivos ajustados).
- MEJORADO: Lógica de picadora de forraje simplificada con un multiplicador universal de 0,75x.
- MEJORADO: Multiplicador de pick-up refinado a 0,35x para una cosecha equilibrada de hileras.
- CORREGIDO: Las cosechadoras ya no aceleran más allá de las velocidades de trabajo originales cuando el cabezal está vacío (sin cultivo).
- CORREGIDO: Se eliminó el salto del límite de velocidad al bajar el cabezal.
- MEJORADO: Sistema de detección robusto para picadoras de forraje y cabezales.
- MEJORADO: Límite de velocidad estrictamente limitado a los límites del juego original (se eliminó el bono de 1,5x).
- MEJORADO: Factores de cultivo recalibrados para avena (+25%), maíz (-50%), soja (-20%) y algodón (2x).
- MEJORADO: Reducción significativa de carga para cultivos de raíces (patata, zanahoria, chirivía, cebolla).
- CORREGIDO: Error de reinicio del límite de velocidad a 9,9 km/h durante la cosecha continua.
- CORREGIDO: Se amplió la excepción de recogida de cultivos de raíces para garantizar una carga realista para cebolla y zanahoria.
- AÑADIDO: Soporte para los tipos ONION_DIRTY y MEADOW.

Changelog 1.4.1.0:
- CORREGIDO: Crash del juego ("attempt to call missing method 'getIsControlled'") al usar equipos de DLC (p.ej. Highland DLC NH 8040 con herramientas Holaras). Añadida verificación nil segura.

Changelog 1.4.1.0:
- CORREGIDO: Cierre del juego ("attempt to call missing method 'getIsControlled'") al utilizar equipos de DLC.
- CORREGIDO: La segunda cosechadora en Courseplay se atascaba a 10 km/h.
- CORREGIDO: Los ajustes del modo AUTO se restablecían al 50 en servidores dedicados.
- CORREGIDO: El menú de ajustes de cosechadoras se abría y cerraba en el sistema modular NEXAT.
- CORREGIDO: Posible fallo de juego al usar vehículos personalizados sin 'getAIFieldWorkerIsTurning'.

Changelog 1.4.0.0:
- NUEVO: Añadida compatibilidad con mods "HUD Hider".
- CORREGIDO: Error de cálculo de productividad (T/h) que causaba saltos repentinos.
- CORREGIDO: Cierre inesperado de la interfaz durante el juego.
- NUEVO: Menú interactivo de configuración y calibración de cosechadora (RShift + K).
- NUEVO: Modo de control manual: ajuste el ventilador, el rotor, los tamices y el alimentador.
- NUEVO: La configuración incorrecta causa pérdidas de cosecha adicionales.
- NUEVO: Sistema de perfiles: guarde/cargue configuraciones personalizadas para cada cultivo.
- NUEVO: Los nuevos cultivos comienzan con una configuración neutral (50%).
- NUEVO: La pantalla de pérdida ahora muestra signos +/- (- para pérdidas, + para bonificaciones, 0 para óptimo).
- NUEVO: Botones de ajuste manual (+/-) siempre visibles en la GUI de calibración.
- CORREGIDO: La rotación de la cámara se bloquea correctamente cuando el cursor está activo.
- CORREGIDO: El HUD se restablecía a posiciones fuera de la pantalla. Se agregó corrección automática.
- MEJORADO: El bloqueo de entrada ahora utiliza el método camera.isRotatable correcto.
- MEJORADO: Texto de sugerencia de GUI reposicionado para evitar superposiciones.
- NUEVO: El modo AUTO ahora tiene leve imperfección (1-10 unidades) – ¡el ajuste manual puede superar al AUTO!
- NUEVO: Misma matemática de pérdidas para AUTO y MANUAL – sin más bypass de cero pérdidas en AUTO.
- CORREGIDO: La configuración de la cosechadora ahora se guarda/carga correctamente desde el savegame.
- CORREGIDO: Cache profileCount correctamente restaurado tras cargar savegame.
- CORREGIDO: Detección automática de cultivo ahora solo en servidor – evita desincronización en multijugador.
- MEJORADO: Todas las configuraciones del mod (servidor + cliente) almacenadas en la carpeta modSettings/.
- MEJORADO: Servidor dedicado totalmente soportado – cada vehículo conserva su propio perfil de calibración.

Changelog 1.3.2.0:
- NUEVO: ¡Sistema de pérdida de cosecha física! Las pérdidas ahora reducen el grano realmente recolectado.
- NUEVO: Las pérdidas de cosecha comienzan al 95% de carga del motor (antes 100%).
- NUEVO: Fórmula de pérdida progresiva - mayor sobrecarga = pérdida exponencialmente mayor.
- MEJORADO: Las penalizaciones por pérdidas ahora afectan directamente el rendimiento.

Changelog 1.3.1.0:
- NUEVO: Menú de configuración reorganizado en secciones "Simulación" y "Visualización".
- NUEVO: ¡HUD movible! Clic derecho para cursor, luego arrastre el HUD.
- NUEVO: Control independiente del cabezal (configuración opcional).
- NUEVO: Las métricas del HUD se restablecen instantáneamente al levantar/detener el corte.
- MEJORADO: Contenido del HUD personalizable (alternar elementos individuales).

Changelog 1.3.0.0:
- NUEVO: ¡Monitor de rendimiento! Vea el rendimiento en tiempo real en t/ha o bu/ac (conmutable en la configuración) (#10)
- NUEVO: Lógica de cálculo de carga completamente reescrita basada en el flujo másico (t/h) en lugar del área.
- NUEVO: Añadido soporte experimental para el sistema NEXAT.
- MEJORADO: El texto del HUD ahora está en negrita para una mejor visibilidad.
- MEJORADO: Solucionado el problema donde el HUD desaparecía al cambiar componentes del vehículo.

Changelog 1.2.1.0:
- Corregido cálculo de productividad mostrando valores incorrectos (era 1000x demasiado bajo)
- Mejorada precisión de conversión masa-volumen usando densidad real de cultivos

Changelog 1.2.0.0:
- Añadido soporte para cosechadoras de algodón
- Añadido soporte parcial para picadoras
- Corregidos problemas de sincronización multijugador
- Corregido conflicto del menú de configuración con otros mods
- Mejorada visualización del sistema de unidades (Imperial/Métrico)

Changelog 1.1.0.0:
- Nueva característica: Botón "Restablecer configuración" en pie de menú (tecla: X)
- Mejoras de interfaz: Descripciones laterales para todas las configuraciones (tooltips)
- Localización: Soporte de traducción completo para 10 idiomas (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Correcciones de errores: Mejorada estabilidad del menú de configuración

---

## Language: IT

Changelog 1.5.0.0:
- NOVITÀ: Integrazione della mod "Moisture System"! Aggiunte penalità dinamiche al carico del motore e maggiori perdite di raccolto in condizioni di umidità.
- NOVITÀ: Lettura della percentuale di umidità in tempo reale integrata nell'HUD trascinabile.
- NOVITÀ: Aggiunta una nuova impostazione per attivare/disattivare l'integrazione del sistema di umidità.
- MIGLIORATO: Pilota automatico "Carico Motore Target": Implementata una zona morta del 2% per prevenire micro-oscillazioni e offrire un'esperienza di controllo della velocità molto più fluida a seconda della densità del raccolto.
- MIGLIORATO: GUI di calibrazione: "Carico Motore Target" ora presenta una barra di avanzamento dinamica a colori (Verde/Giallo/Rosso) per un miglior feedback visivo rispetto al testo normale.
- CORRETTO: L'indicatore HUD dell'umidità si bloccava sull'ultimo valore invece di azzerarsi allo 0% quando la mietitrebbia interrompe il raccolto o va in retromarcia.
- CORRETTO: "Carico Motore Target" mostrava erroneamente "auto" nel menu di calibrazione.
- NOVITÀ: Aggiunto il comando console di diagnostica `rhm_inspect` per visualizzare i dati sulle prestazioni in tempo reale.
- MIGLIORATO: Revisione completa dei coefficienti delle colture utilizzando un sistema di ricerca basato sul nome per una maggiore precisione.
- MIGLIORATO: Separazione netta tra i coefficienti del Mais da Granella e del Mais da Insilato per velocità di raccolta realistiche.
- MIGLIORATO: Coefficienti bilanciati per la raccolta di Erba e Fieno (taglio diretto e pick-up).
- MIGLIORATO: Affinato il moltiplicatore di carico del pick-up (da 0,25 a 0,45) per le andane di cereali per fornire una resistenza del motore realistica.
- NOVITÀ: "Forage Safety Net" universale per garantire carichi realistici per colture non standard o modificate lavorate dalle trincia-insilatrici.
- CORRETTO: Risolto un problema per cui le testate delle trincia-insilatrici non venivano rilevate correttamente a causa della distinzione tra maiuscole e minuscole nei nomi delle categorie.

Changelog 1.4.3.0:
- NOVITÀ: Sistema di Acquisto! Aggiunta la funzionalità per acquistare impostazioni di calibrazione avanzate della mietitrebbia, introducendo un nuovo livello di progressione della carriera.
- NOVITÀ: Interfaccia grafica (GUI) di calibrazione della mietitrebbia completamente riprogettata con nuova selezione delle colture, miglioramenti dell'interazione e schede informative aggiuntive.
- NOVITÀ: HUD trascinabile migliorato che mostra le prestazioni della mietitrebbia, inclusi indicatori grafici per resa e carico del motore.
- NOVITÀ: Aggiunte 7 pagine dettagliate al Menu di Aiuto del gioco che coprono tutte le meccaniche della mod, con icone uniche e localizzazione in 11 lingue.
- NOVITÀ: Aggiunta la pagina di traduzione "Perdita di Raccolto" e migliorate le descrizioni della mod in tutte le lingue supportate.
- MIGLIORATO: Rivista la logica principale di dipendenza della velocità dal carico del motore: le perdite minime di raccolto ora iniziano legittimamente all'80% di carico invece che al 100%.
- MIGLIORATO: Il fattore di carico per le trinciacaricatrici ora è completamente dinamico in base alla densità della coltura e alla larghezza di taglio.
- MIGLIORATO: Rifattorizzato il meccanismo di iniezione delle impostazioni utilizzando hook del motore a livello di classe sicuri (`InGameMenuSettingsFrame.onFrameOpen`) per la massima compatibilità con i DLC (Vredo Pack, Precision Farming, ecc.).
- MIGLIORATO: Refactoring globale dello spazio dei nomi: Tutte le classi e i file interni sono stati rinominati con il prefisso `RHM_` per prevenire collisioni con altre mod di terze parti.
- MIGLIORATO: Ricostruita completamente l'architettura di debug della mod. Tutti gli output di debug sono ora rigorosamente nascosti dietro il flag `-devWarnings` del gioco, mantenendo il file `log.txt` dell'utente perfettamente pulito per impostazione predefinita.
- RISOLTO: Risolto un conflitto critico dell'interfaccia utente in cui le impostazioni DLC scomparivano dal menu di gioco quando Realistic Harvesting era attivo.
- RISOLTO: Corrette le lettere maiuscole e minuscole dei nomi dei file in `main.lua` (`RHM_Combine`, `RHM_Renderer`), risolvendo il famigerato blocco della schermata di caricamento al 55%.
- RISOLTO: Risolto un bug per cui le modifiche nel menu delle impostazioni non venivano salvate o sincronizzate correttamente con il server a causa di un callback errato.
- RISOLTO: Eliminato il massiccio spam in console (60 log al secondo) causato da "Crop Loss Applied" durante la raccolta in modalità sviluppatore.
- RISOLTO: Corretti gli errori di sintassi XML (tag `<paragraph>`) in `modDesc.xml` per garantire che il testo del Menu di Aiuto venga renderizzato perfettamente senza avvisi dal motore grafico.
- MIGLIORATO: Ottimizzato il layout dell'interfaccia utente per utilizzare lo standard `gameSettingsLayout` permettendo un posizionamento coerente del menu.
- MIGLIORATO: Rimosso il pulsante "Ripristina" (X) ridondante dal piè di pagina, in quanto causava instabilità del layout con altre mod.
- MIGLIORATO: Rimosso il pulsante "Reset" (X) ridondante dal piè di pagina.
- MIGLIORATO: Disabilitata la registrazione di debug principale per impostazione predefinita.

Changelog 1.4.2.0:
- CORRETTO: La velocità massima di raccolta è ora strettamente limitata dalle capacità della barra di taglio del gioco base, impedendo alle raccoglitrici di radici di superare velocità realistiche.
- CORRETTO: Risolti i problemi di desincronizzazione di rete sui server dedicati in cui le impostazioni del client potevano sovrascrivere le impostazioni predefinite del server.
- CORRETTO: Risolto un crash di ricorsione infinita relativo al salvataggio delle impostazioni della mietitrebbia sui server multiplayer.
- CORRETTO: Corretta una perdita di memoria nei buffer di calcolo del carico motore e della produttività.
- CORRETTO: Impedito agli utenti non amministratori di ottenere occasionalmente l'accesso temporaneo alle Impostazioni del Server.
- MIGLIORATO: I fattori di produttività per Cipolle e Carote sono stati ricalibrati per un calcolo più accurato del carico del motore.
- MIGLIORATO: Rimosso l'output di debug non necessario dai log di sincronizzazione del server per mantenere pulita la console.
- RISOLTO: Bug per cui le impostazioni del server si sbloccavano per i giocatori non amministratori dopo aver riaperto il menu.
- RISOLTO: Problema di localizzazione ('window_grass') per l'erba nel menu HUD.
- MIGLIORATO: Rimozione dei log di debug eccessivi.
- MIGLIORATO: Configurazione centralizzata dei log di debug (RHM_Debug.lua).
- AGGIUNTO: Localizzazione spagnola per tutte le funzioni e i menu del mod.
- NUOVO: Impostazione aggiunta per disabilitare gli avvisi HUD "High Load".
- MIGLIORATO: Pulizia interna della logica degli avvisi.
- RISOLTO: Revisione completa del calcolo del rendimento per sincronizzare con HUD Precision Farming.
- RISOLTO: Le trincia-insilatrici mostravano rendimento 10x inferiore per bug del volume motore.
- RISOLTO: Desincronizzazioni matematiche nel riempimento asincrono del bunker.
- NUOVO: Fisica delle impostazioni divisa in due categorie: Efficienza (velocità) e Perdita di Raccolto.
- NUOVO: Il menu HUD ridisegnato per mostrare sempre simultaneamente l'impatto su velocità e perdita.
- NUOVO: Aggiunta la meccanica 'Scudo Sovraccarico'.
- RISOLTO: Bug critico in cui impostazioni perfette potevano ridurre involontariamente la velocità.
- RISOLTO: La mietitrebbia non accelerava correttamente migliorando le impostazioni durante la raccolta.
- RISOLTO: Risolta la doppia registrazione dei percorsi XML di salvataggio che causava errori nei log del server e il ripristino delle impostazioni.
- MIGLIORATO: Produttività della trincia semovente calibrata sui dati reali (coefficiente regolato da 0,150 a 0,051).
- NOVITÀ: Aggiunto il rilevamento universale delle testate raccoglitrici/andanatrici con un moltiplicatore di carico del motore ridotto (0,75x).
- NUOVO: Aggiunta mappatura di fallback automatica per i fillTypes '_WINDROW' e 'CUT_' alle loro colture di base.
- MIGLIORATO: Calibrazione di precisione dei fattori di coltura e delle densità basata su obiettivi di resa reali (bu/hr).
- NUOVO: Ogni coltura ora utilizza impostazioni tecniche individuali tratte da manuali reali (oltre 20 colture ottimizzate).
- MIGLIORATO: Logica della trincia-insilatrice semplificata con un moltiplicatore universale di 0,75x.
- MIGLIORATO: Moltiplicatore di raccolta affinato a 0,35x per una raccolta equilibrata delle andane.
- RISOLTO: Le mietitrebbie non accelerano più oltre le velocità di lavoro vanilla quando la testata è vuota (niente raccolto).
- RISOLTO: Rimosso il salto del limite di velocità quando si abbassa la testata.
- MIGLIORATO: Sistema di rilevamento robusto per trincia e testate.
- MIGLIORATO: Limite di velocità strettamente limitato ai limiti del gioco vanilla (rimosso il bonus 1,5x).
- MIGLIORATO: Fattori di coltura ricalibrati per avena (+25%), mais (-50%), soia (-20%) e cotone (2x).
- MIGLIORATO: Significativa riduzione del carico per le colture a radice (patate, carote, pastinaca, cipolla).
- RISOLTO: Bug del reset del limite di velocità a 9,9 km/h durante la raccolta continua.
- RISOLTO: Ampliata l'eccezione per la raccolta delle colture a radice per garantire un carico realistico per cipolle e carote.
- AGGIUNTO: Supporto per i tipi ONION_DIRTY e MEADOW.

Changelog 1.4.1.0:
- RISOLTO: Crash del gioco ("attempt to call missing method 'getIsControlled'") quando si usano veicoli DLC (es. Highland DLC NH 8040 con attrezzi Holaras). Aggiunto controllo nil sicuro.

Changelog 1.4.1.0:
- RISOLTO: Crash del gioco ("attempt to call missing method 'getIsControlled'") durante l'utilizzo di strumenti DLC.
- RISOLTO: La seconda mietitrebbia Courseplay si bloccava a 10 km/h.
- RISOLTO: Le impostazioni del modo AUTO si azzeravano sui server dedicati.
- RISOLTO: Problemi nel menu delle impostazioni della mietitrebbia sul sistema modulare NEXAT.
- RISOLTO: Possibile crash del gioco a causa della mancanza del metodo 'getAIFieldWorkerIsTurning'.

Changelog 1.4.0.0:
- NUOVO: Aggiunta compatibilità con mod "HUD Hider".
- RISOLTO: Bug nel calcolo della produttività (T/h) che causava salti improvvisi.
- RISOLTO: Chiusura inaspettata della GUI durante il gioco.
- NUOVO: Menu interattivo impostazioni e calibrazione mietitrebbia (RShift + K).
- NUOVO: Modalità controllo manuale - Regola ventola, rotore, setacci e alimentatore.
- NUOVO: Impostazioni errate causano perdite di raccolto aggiuntive.
- NUOVO: Sistema profili - Salva/Carica impostazioni personalizzate per ogni coltura.
- NUOVO: Le nuove colture iniziano con impostazioni neutre (50%), richiedendo la calibrazione.
- NUOVO: Il display delle perdite ora mostra segni +/- (- per perdite, + per bonus, 0 per ottimale).
- NUOVO: Pulsanti di regolazione manuale (+/-) sempre visibili nella GUI di calibrazione.
- RISOLTO: Rotazione telecamera bloccata correttamente quando il cursore è attivo.
- RISOLTO: HUD resettato su posizioni fuori schermo. Aggiunto fix automatico.
- MIGLIORATO: Il blocco input ora usa il metodo corretto camera.isRotatable.
- MIGLIORATO: Testo suggerimento GUI riposizionato per evitare sovrapposizioni.
- NUOVO: Il modo AUTO ora ha una lieve imperfezione (1-10 unità) – la calibrazione manuale può superare l'AUTO!
- NUOVO: Stessa matematica delle perdite per AUTO e MANUALE – nessun bypass zero-perdita in AUTO.
- RISOLTO: Le impostazioni della mietitrebbia vengono ora salvate/caricate correttamente dal savegame.
- RISOLTO: Cache profileCount correttamente ripristinata dopo il caricamento del savegame.
- RISOLTO: Rilevamento automatico coltura ora solo lato server – evita desincronizzazione in multiplayer.
- MIGLIORATO: Tutte le impostazioni del mod (server + client) archiviate nella cartella modSettings/.
- MIGLIORATO: Server dedicato completamente supportato – ogni veicolo mantiene il proprio profilo di calibrazione.

Changelog 1.3.2.0:
- NUOVO: Sistema di perdita di raccolto fisica! Le perdite riducono ora il grano effettivamente raccolto.
- NUOVO: Le perdite di raccolto iniziano al 95% di carico motore (prima 100%).
- NUOVO: Formula di perdita progressiva - sovraccarico più alto = perdita esponenzialmente maggiore.
- MIGLIORATO: Le penalità per perdite influenzano ora direttamente il rendimento.

Changelog 1.3.1.0:
- NUOVO: Menu impostazioni riorganizzato in sezioni "Simulazione" e "Visualizzazione".
- NUOVO: HUD spostabile! Tasto destro per cursore, poi trascina HUD.
- NUOVO: Controllo indipendente testata (impostazione opzionale).
- NUOVO: Le metriche HUD si resettano istantaneamente quando la testata viene alzata/fermata.
- MIGLIORATO: Contenuto HUD personalizzabile (attiva singoli elementi).

Changelog 1.3.0.0:
- NUOVO: Monitor di resa! Vedi la resa in tempo reale in t/ha o bu/ac (attivabile nelle impostazioni) (#10)
- NUOVO: Logica di calcolo del carico completamente riscritta basata sulla portata di massa (t/h) invece che sull'area.
- NUOVO: Aggiunto supporto sperimentale per il sistema NEXAT.
- MIGLIORATO: Il testo dell'HUD è ora in grassetto per una migliore visibilità.
- MIGLIORATO: Risolto il problema per cui l'HUD scompariva quando si cambiavano i componenti del veicolo.

Changelog 1.2.1.0:
- Corretto calcolo produttività che mostrava valori errati (era 1000x troppo basso)
- Migliorata accuratezza conversione massa-volume usando densità reale colture

Changelog 1.2.0.0:
- Aggiunto supporto per raccoglitrici cotone
- Aggiunto supporto parziale per trincia
- Corretti problemi sincronizzazione multiplayer
- Corretto conflitto menu impostazioni con altri mod
- Migliorata visualizzazione sistema unità (Imperiale/Metrico)

Changelog 1.1.0.0:
- Nuova funzionalità: Pulsante "Ripristina impostazioni" nel piè di pagina menu (tasto: X)
- Miglioramenti interfaccia: Descrizioni laterali per tutti le impostazioni (tooltip)
- Localizzazione: Supporto traduzione completo per 10 lingue (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Correzioni bug: Migliorata stabilità menu impostazioni

---

## Language: CZ

Changelog 1.5.0.0:
- NOVINKA: Integrace modifikace "Moisture System"! Přidány dynamické pokuty pro zatížení motoru a zvýšené ztráty plodin při sklizni ve vlhkých podmínkách.
- NOVINKA: Zobrazení procenta vlhkosti v reálném čase integrováno do přetahovatelného uživatelského rozhraní HUD.
- NOVINKA: Přidáno nové nastavení pro zapnutí/vypnutí integrace systému vlhkosti.
- VYLEPŠENO: Autopilot "Cílové zatížení motoru": Zavedena 2% mrtvá zóna, aby se zabránilo mikrooscilacím a zajistil se mnohem plynulejší zážitek z tempomatu při různorodé hustotě plodin.
- VYLEPŠENO: Kalibrační GUI: "Cílové zatížení motoru" má nyní dynamický barevný indikátor průběhu (zelená/žlutá/červená) namísto prostého textu pro lepší vizuální zpětnou vazbu.
- OPRAVENO: Indikátor vlhkosti v HUD zamrzal na své poslední hodnotě, místo aby se po zastavení sklizně nebo couvání kombajnu resetoval na 0 %.
- OPRAVENO: "Cílové zatížení motoru" se v nabídce kalibrace nesprávně zobrazovalo jako "auto".
- NOVINKA: Přidán diagnostický příkaz konzole `rhm_inspect` pro zobrazení údajů o výkonu sklízeče v reálném čase.
- VYLEPŠENO: Kompletní přepracování koeficientů plodin pomocí systému vyhledávání podle názvu pro vyšší přesnost.
- VYLEPŠENO: Jasné oddělení koeficientů pro kukuřici na zrno a kukuřici na siláž pro realistické rychlosti sklizně.
- VYLEPŠENO: Vyvážené koeficienty pro sklizeň trávy a sena (přímé sečení i sběr z řádků).
- VYLEPŠENO: Vylepšen multiplikátor zatížení sběrače (z 0,25 na 0,45) pro řádky obilí pro zajištění realistického odporu motoru.
- NOVINKA: Univerzální „Forage Safety Net“ pro zajištění realistického zatížení u nestandardních nebo modifikovaných plodin zpracovávaných řezačkami.
- OPRAVENO: Vyřešen problém, kdy adaptéry pro řezačky nebyly správně detekovány kvůli velikosti písmen v názvech kategorií.

Changelog 1.4.3.0:
- NOVINKA: Nákupní Systém! Přidána funkce pro nákup pokročilých nastavení kalibrace kombajnu, což přidává novou vrstvu postupu kariéry.
- NOVINKA: Zcela přepracované interaktivní grafické uživatelské rozhraní (GUI) kalibrace kombajnu s novým výběrem plodin, vylepšeními interakce a dalšími informačními kartami.
- NOVINKA: Vylepšený přetahovatelný HUD zobrazující výkon kombajnu, včetně grafických měřičů výnosu a zatížení motoru.
- NOVINKA: Do herní nabídky nápovědy bylo přidáno 7 podrobných stránek pokrývajících všechny mechaniky modifikací s jedinečnými vlastními ikonami a lokalizací pro 11 jazyků.
- NOVINKA: Přidána překladová stránka "Ztráta Plodiny" a vylepšeny popisy modifikací ve všech podporovaných jazycích.
- VYLEPŠENO: Zrevidována hlavní logika závislosti rychlosti na zatížení motoru: minimální ztráty plodin nyní začínají až při 80% zatížení místo 100%.
- VYLEPŠENO: Faktor zatížení pro sklízecí řezačky je nyní plně dynamický na základě hustoty plodin a šířky žacího ústrojí.
- VYLEPŠENO: Přepracován mechanismus vkládání nastavení pro použití bezpečných háků motoru na úrovni třídy (`InGameMenuSettingsFrame.onFrameOpen`) pro maximální kompatibilitu s DLC (Vredo Pack, Precision Farming, atd.).
- VYLEPŠENO: Globální refaktorování jmenného prostoru: Všechny interní třídy a soubory byly přejmenovány se skriptovou předponou `RHM_`, aby se zabránilo kolizím s mody třetích stran.
- VYLEPŠENO: Zcela přestavěna architektura ladění modu. Všechny výstupy ladění jsou nyní přísně uzamčeny za flagem `-devWarnings` hry, a tak udržují uživatelův `log.txt` ve výchozím nastavení naprosto čistý.
- OPRAVENO: Vyřešen kritický konflikt uživatelského rozhraní, při kterém nastavení DLC mizela z herní nabídky, když byl aktivní mod Realistic Harvesting.
- OPRAVENO: Opravena velikost písmen názvů souborů v `main.lua` (`RHM_Combine`, `RHM_Renderer`), čímž se vyřešilo nechvalné zamrzání načítací obrazovky na 55%.
- OPRAVENO: Vyřešena chyba, kvůli které se změny v nabídce nastavení neukládaly nebo nesynchronizovaly správně se serverem kvůli neplatnému podpisu zpátečního volání.
- OPRAVENO: Odstraněn masivní spam konzole (60 protokolů za sekundu) způsobený protokolem "Crop Loss Applied" během sklizně ve vývojářském režimu.
- OPRAVENO: Opraveny chyby syntaxe XML (značky `<paragraph>`) v `modDesc.xml`, aby bylo zajištěno dokonalé formátování textu nabídky nápovědy bez varování motoru.
- VYLEPŠENO: Rozvržení uživatelského rozhraní bylo optimalizováno, aby používalo standardní `gameSettingsLayout` pro konzistentní umístění v nabídce.
- VYLEPŠENO: Odstraněno nadbytečné tlačítko „Obnovit“ (X) v zápatí, protože způsobovalo nestabilitu rozvržení s ostatními mody.

Changelog 1.4.2.0:
- OPRAVENO: Maximální rychlost sklizně je nyní přísně omezena možnostmi žací lišty v základní hře, což zabraňuje překročení realistických rychlostí u sklízečů kořenových plodin.
- OPRAVENO: Vyřešeny problémy s desynchronizací sítě na dedikovaných serverech, kde nastavení klienta mohlo přepsat výchozí nastavení serveru.
- OPRAVENO: Vyřešen pád nekonečné rekurze související s ukládáním nastavení sklízecích mlátiček na serverech pro více hráčů.
- OPRAVENO: Opraven únik paměti ve vyrovnávacích pamětech výpočtu zatížení motoru a produktivity.
- OPRAVENO: Zabráněno uživatelům bez oprávnění správce občas získat dočasný přístup k nastavení serveru.
- VYLEPŠENO: Faktory propustnosti pro cibuli a mrkev byly překalibrovány pro přesnější výpočty zatížení motoru.
- VYLEPŠENO: Odstraněn nepotřebný výstup ladění z protokolů synchronizace serveru, aby se konzole udržela čistá.
- OPRAVENO: Chyba, kdy se nastavení serveru odemklo pro hráče bez administrátorských práv po opětovném otevření menu.
- OPRAVENO: Problém s lokalizací ('window_grass') pro trávu v menu HUD.
- VYLEPŠENO: Odstraněny nadměrné ladicí protokoly.
- VYLEPŠENO: Centralizovaná konfigurace ladicích protokolů (RHM_Debug.lua).
- PŘIDÁNO: Španělská lokalizace pro všechny funkce a menu modu.
- NOVINKA: Přidána možnost zakázat varování HUD "High Load".
- VYLEPŠENO: Interní vyčištění logiky varování.
- OPRAVENO: Kompletní přepracování matematiky výpočtu výnosu pro synchronizaci s HUD Precision Farming.
- OPRAVENO: Sklízecí řezačky zobrazovaly 10x nižší výnos kvůli chybám objemu motoru.
- OPRAVENO: Matematické desynchronizace při asynchronním plnění zásobníku.
- NOVINKA: Fyzika nastavení kombajnu rozdělena na dvě kategorie: Účinnost (rychlost) a Ztráta úrody.
- NOVINKA: HUD menu přepracováno tak, aby vždy současně zobrazovalo dopad na rychlost i ztrátu.
- NOVINKA: Přidána mechanika "Štít proti přetížení".
- OPRAVENO: Kritická chyba, kdy perfektní nastavení mohlo neúmyslně snížit rychlost.
- OPRAVENO: Kombajn nezrychloval správně při zlepšení nastavení během sklizně.
- OPRAVENO: Vyřešena duplicitní registrace cest XML pro ukládání hry, která způsobovala chyby v logu serveru a resetování nastavení.
- VYLEPŠENO: Průchodnost řezačky zkalibrována podle skutečných dat (koeficient upraven z 0,150 na 0,051).
- NOVINKA: Přidána univerzální detekce sběracích adaptérů/řádkovačů se sníženým multiplikátorem zatížení motoru (0,75x).
- NOVINKA: Přidáno automatické mapování záložních řetězců fillTypes '_WINDROW' a 'CUT_' na jejich základní plodiny.
- VYLEPŠENO: Přesná kalibrace faktorů plodin a hustot na základě reálných výnosových cílů (bu/hr).
- NOVINKA: Každá plodina nyní používá individuální technické předvolby z reálných manuálů (více než 20 plodin).
- VYLEPŠENO: Zjednodušená logika řezačky s univerzálním multiplikátorem 0,75x.
- VYLEPŠENO: Multiplikátor sběrače upraven na 0,35x pro vyváženou sklizeň řádků.
- OPRAVENO: Kombajny již nezrychlují nad pracovní rychlosti základní hry, když je adaptér prázdný (bez plodiny).
- OPRAVENO: Odstraněn skok rychlostního limitu při spouštění adaptéru.
- VYLEPŠENO: Robustní systém detekce pro řezačky a adaptéry.
- VYLEPŠENO: Rychlostní limit přísně omezen na limity základní hry (odstraněn bonus 1,5x).
- VYLEPŠENO: Překalibrované faktory plodin pro oves (+25 %), kukuřici (-50 %), sóju (-20 %) a bavlnu (2x).
- VYLEPŠENO: Výrazné snížení zatížení u okopanin (brambory, mrkev, pastinák, cibule).
- OPRAVENO: Chyba resetování rychlostního limitu při 9,9 km/h během plynulé sklizně.
- OPRAVENO: Rozšířena výjimka pro sběr okopanin pro zajištění realistického zatížení cibule a mrkve.
- PŘIDÁNO: Podpora pro typy ONION_DIRTY a MEADOW.

Changelog 1.4.1.0:
- OPRAVENO: Pád hry ("attempt to call missing method 'getIsControlled'") při použití DLC vybavení (např. Highland DLC NH 8040 s nástroji Holaras). Přidána bezpečná kontrola nil.

Changelog 1.4.1.0:
- OPRAVENO: Pád hry při použití nástrojů z DLC ("attempt to call missing method 'getIsControlled'").
- OPRAVENO: Druhý kombajn Courseplay se zasekával o rychlosti 10 km/h.
- OPRAVENO: Nastavení režimu AUTO se na vyhrazených serverech resetovalo na 50.
- OPRAVENO: Nabídka nastavení kombajnu se neočekávaně zavírala na modulárním systému NEXAT.
- OPRAVENO: Možný pád hry na vlastních vozidlech s chybějící metodou 'getAIFieldWorkerIsTurning'.

Changelog 1.4.0.0:
- NOVINKA: Přidána kompatibilita s mody "HUD Hider".
- OPRAVENO: Chyba výpočtu produktivity (T/h) způsobující náhlé skoky.
- OPRAVENO: Neočekávané zavření GUI během hry.
- NOVINKA: Interaktivní menu nastavení a kalibrace kombajnu (RShift + K).
- NOVINKA: Manuální režim ovládání - Nastavení ventilátoru, rotoru, sít a podavače.
- NOVINKA: Nesprávné nastavení způsobuje dodatečné ztráty úrody.
- NOVINKA: Systém profilů - Uložení/Načtení vlastního nastavení pro každou plodinu.
- NOVINKA: Nové plodiny začínají s neutrálním (50%) nastavením, vyžadují kalibraci.
- NOVINKA: Zobrazení ztrát nyní ukazuje znaménka +/- (- pro ztráty, + pro bonusy, 0 pro optimální).
- NOVINKA: Tlačítka manuálního nastavení (+/-) jsou v kalibraci vždy viditelná.
- OPRAVENO: Otáčení kamery je správně blokováno, když je kurzor aktivní.
- OPRAVENO: HUD se resetoval na pozice mimo obrazovku. Přidána automatická oprava.
- VYLEPŠENO: Blokování vstupu nyní používá správnou metodu camera.isRotatable.
- VYLEPŠENO: Text nápovědy GUI přemístěn, aby se nepřekrýval s tlačítky.
- NOVINKA: Režim AUTO má nyní mírnou nedokonalost (1-10 jednotek) – ruční ladění může překonat AUTO!
- NOVINKA: Stejná matematika ztrát pro AUTO i MANUÁLNÍ – žádný bypass nulové ztráty v AUTO.
- OPRAVENO: Nastavení kombajnu jsou nyní správně ukládána/načítána ze savegame (vehicles.xml).
- OPRAVENO: Cache profileCount správně obnovena po načtení savegame.
- OPRAVENO: Automatická detekce plodiny nyní pouze na serveru – zabraňuje desynchronizaci v multiplayeru.
- VYLEPŠENO: Všechna nastavení modu (server + klient) uložena ve složce modSettings/.
- VYLEPŠENO: Dedikovaný server plně podporován – každé vozidlo si zachovává vlastní kalibrační profil.

Changelog 1.3.2.0:
- NOVINKA: Fyzický systém ztráty úrody! Ztráty nyní snižují skutečně sklizené zrní.
- NOVINKA: Ztráty úrody začínají při 95% zatížení motoru (dříve 100%).
- NOVINKA: Progresivní vzorec ztrát - vyšší přetížení = exponenciálně větší ztráty.
- VYLEPŠENÍ: Pokuty za ztráty nyní přímo ovlivňují výnos sklizně.

Changelog 1.3.1.0:
- NOVINKA: Nabídka nastavení reorganizována do sekcí "Simulace" a "Zobrazení".
- NOVINKA: Přesouvatelný HUD! Pravé tlačítko pro kurzor, poté přetáhněte HUD.
- NOVINKA: Nezávislé ovládání lišty (volitelné nastavení).
- NOVINKA: Metriky HUD se okamžitě resetují při zvednutí/zastavení lišty.
- VYLEPŠENÍ: Přizpůsobitelný obsah HUD (přepínání jednotlivých prvků).

Changelog 1.3.0.0:
- NOVINKA: Monitor výnosu! Sledujte výnos v reálném čase v t/ha nebo bu/ac (přepínatelné v nastavení) (#10)
- NOVINKA: Zcela přepsaná logika výpočtu zatížení založená na hmotnostním průtoku (t/h) namísto plochy.
- NOVINKA: Přidána experimentální podpora pro systém NEXAT.
- VYLEPŠENÍ: Text HUD je nyní tučný pro lepší viditelnost.
- VYLEPŠENÍ: Opraven problém, kdy HUD mizel při přepínání komponent vozidla.

Changelog 1.2.1.0:
- Opravený výpočet produktivity zobrazující nesprávné hodnoty (byl 1000x příliš nízký)
- Vylepšená přesnost převodu hmotnosti na objem pomocí skutečné hustoty plodin

Changelog 1.2.0.0:
- Přidána podpora pro sklízecí stroje na bavlnu
- Přidána částečná podpora pro sklízecí řezačky
- Opraveny problémy se synchronizací v multiplayeru
- Opraven konflikt nabídky nastavení s jinými mody
- Vylepšené zobrazení systému jednotek (Imperiální/Metrický)

Changelog 1.1.0.0:
- Nová funkce: Tlačítko "Obnovit nastavení" v zápatí nabídky (klávesa: X)
- Vylepšení rozhraní: Boční popisy pro všechna nastavení (nápovědy)
- Lokalizace: Plná podpora překladu pro 10 jazyků (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Opravy chyb: Vylepšená stabilita nabídky nastavení

---

## Language: BR

Changelog 1.5.0.0:
- NOVO: Integração do Mod "Moisture System"! Adicionadas penalidades dinâmicas de carga do motor e aumento nas perdas de colheita ao colher em condições úmidas.
- NOVO: Leitura em tempo real da porcentagem de umidade integrada ao HUD arrastável.
- NOVO: Adicionada uma nova configuração para ativar/desativar a integração do sistema de umidade.
- MELHORADO: Piloto automático "Carga de Motor Alvo": Implementado uma zona morta de 2% para evitar micro-oscilações e entregar uma experiência de controle de cruzeiro muito mais suave em diversas densidades de cultura.
- MELHORADO: GUI da calibração: "Carga de Motor Alvo" agora possui uma barra de progresso colorida dinâmica (Verde/Amarelo/Vermelho) para melhor feedback visual em vez de apenas texto simples.
- CORRIGIDO: O indicador HUD de umidade congelava no seu último valor em vez de redefinir para 0% quando a colheitadeira parava de colher ou dava ré.
- CORRIGIDO: "Carga de Motor Alvo" sendo exibida incorretamente como "auto" no menu de calibração.
- NOVO: Adicionado comando de console de diagnóstico `rhm_inspect` para visualizar dados de desempenho em tempo real.
- MELHORADO: Revisão completa dos coeficientes de cultura usando um sistema de busca baseado em nome para maior precisão.
- MELHORADO: Separação clara entre os coeficientes de Milho Grão e Milho Silagem para velocidades de colheita realistas.
- MELHORADO: Coeficientes equilibrados para a colheita de Grama e Feno (corte direto e recolhedor).
- MELHORADO: Refinado o multiplicador de carga do recolhedor (de 0,25 para 0,45) para leiras de grãos para fornecer uma resistência do motor realista.
- NOVO: "Rede de Segurança de Forragem" universal para garantir cargas realistas para culturas não padronizadas ou modificadas processadas por forrageiras.
- CORRIGIDO: Resolvido um problema onde os cabeçais de forrageiras não eram detectados corretamente devido à distinção entre maiúsculas e minúsculas nos nomes das categorias.

Changelog 1.4.3.0:
- NOVO: Sistema de Compras! Adicionada funcionalidade para comprar configurações avançadas de calibração da colheitadeira, adicionando uma nova camada de progressão de carreira.
- NOVO: Interface gráfica (GUI) interativa de calibração da colheitadeira completamente redesenhada com nova seleção de culturas, melhorias de interação e abas adicionais de informação.
- NOVO: HUD arrastável aprimorado exibindo o desempenho da colheitadeira, incluindo medidores gráficos de produtividade e carga do motor.
- NOVO: Adicionadas 7 páginas detalhadas ao Menu de Ajuda do jogo cobrindo todas as mecânicas do mod, com ícones personalizados únicos e localização para 11 idiomas.
- NOVO: Adicionada a página de tradução "Perda de Colheita" e descrições refinadas do mod em todos os idiomas suportados.
- MELHORADO: Revisada a lógica principal de dependência da velocidade na carga do motor: as perdas mínimas de colheita agora começam legitimamente em 80% da carga, em vez de 100%.
- MELHORADO: O fator de carga para as forrageiras agora é totalmente dinâmico com base na densidade da cultura e largura de corte.
- MELHORADO: Refatorado o mecanismo de injeção de configurações para usar ganchos (hooks) seguros da engine no nível das classes (`InGameMenuSettingsFrame.onFrameOpen`) para máxima compatibilidade com DLCs (Vredo Pack, Precision Farming, etc.).
- MELHORADO: Refatoração global do Namespace: Todas as classes e arquivos internos foram renomeados usando o prefixo `RHM_` para evitar conflitos com outros mods de terceiros.
- MELHORADO: A arquitetura de depuração do mod foi totalmente reconstruída. Toda saída de depuração agora é estritamente ocultada por trás da configuração `-devWarnings` no jogo, mantendo o arquivo `log.txt` do usuário limpo por padrão.
- CORRIGIDO: Resolvido um conflito crítico na interface de usuário (UI) onde as configurações de DLC desapareciam do menu de jogo quando o mod Realistic Harvesting estava ativo.
- CORRIGIDO: Corrigido o uso de letras maiúsculas/minúsculas de nomes de arquivos no `main.lua` (`RHM_Combine`, `RHM_Renderer`), resolvendo o famoso problema de congelamento da tela de carregamento em 55%.
- CORRIGIDO: Resolvido um bug onde alterações feitas no menu de configurações não eram salvas ou sincronizadas com o servidor corretamente devido a uma assinatura de retorno de chamada inválida.
- CORRIGIDO: Removido o spam massivo de mensagens do console (60 registros por segundo) causados pelo logs "Crop Loss Applied" no modo desenvolvedor durante a colheita.
- CORRIGIDO: Erros de sintaxe XML corrigidos (tags `<paragraph>`) no arquivo `modDesc.xml` garantindo que o texto do Menu de Ajuda seja renderizado corretamente sem avisos da engine.
- MELHORADO: Otimização do layout da interface (UI) utilizando o sistema de design padronizado do jogo `gameSettingsLayout` para um posicionamento ordenado junto aos menus existentes.
- MELHORADO: O botão redundante "Redefinir" (X) no rodapé da página foi removido porque interferia gerando instabilidade visual no layout perante a outros mods.

Changelog 1.4.2.0:
- CORRIGIDO: A velocidade máxima de colheita agora é estritamente limitada pelas capacidades da plataforma de corte do jogo base, impedindo que colheitadeiras de raízes excedam velocidades realistas.
- CORRIGIDO: Abordados os problemas de dessincronização de rede em servidores dedicados onde as configurações do cliente podiam substituir os padrões do servidor.
- CORRIGIDO: Resolvido um travamento de recursividade infinita relacionado ao salvamento das configurações das colheitadeiras em servidores multijogador.
- CORRIGIDO: Corrigido um vazamento de memória nos buffers de cálculo de carga do motor e produtividade.
- CORRIGIDO: Impediu que usuários não administradores ganhassem ocasionalmente acesso temporário às Configurações do Servidor.
- MELHORADO: Fatores de rendimento para cebolas e cenouras recalibrados para cálculos mais precisos da carga do motor.
- MELHORADO: Removida a saída de depuração desnecessária dos logs de sincronização do servidor para manter a console limpa.
- CORRIGIDO: Bug onde as configurações do servidor eram desbloqueadas para jogadores não administradores ao reabrir o menu.
- CORRIGIDO: Problema de localização ('window_grass') para grama no menu HUD.
- MELHORADO: Removidos logs de depuração excessivos.
- MELHORADO: Configuração centralizada de logs de depuração (RHM_Debug.lua).
- ADICIONADO: Localização espanhola para todas as funcionalidades e menus do mod.
- NOVO: Configuração adicionada para desativar avisos HUD "High Load".
- MELHORADO: Limpeza interna da lógica de avisos.
- CORRIGIDO: Revisão completa do cálculo de rendimento para sincronizar com HUD Precision Farming.
- CORRIGIDO: Colheitadeiras forrageiras mostravam rendimento 10x inferior por bugs de volume.
- CORRIGIDO: Desincronizações matemáticas no enchimento assíncrono do bunker.
- NOVO: Física de configurações da colheitadeira separada em duas categorias: Eficiência (velocidade) e Perda de Colheita.
- NOVO: Menu HUD redesenhado para sempre exibir simultaneamente o impacto na velocidade e perda.
- NOVO: Adicionada a mecânica de 'Escudo de Sobrecarga'.
- CORRIGIDO: Bug crítico onde configurações perfeitas poderiam reduzir involuntariamente a velocidade.
- CORRIGIDO: Colheitadeira não acelerava corretamente ao melhorar as configurações em andamento.
- CORRIGIDO: Resolvido o registro duplicado de caminhos XML de savegame que causaba erros no log do servidor e reset das configurações.
- MELHORADO: Rendimento da colhedora de forragem calibrado para dados reais (coeficiente ajustado de 0,150 para 0,051).
- NOVO: Adicionada detecção universal de plataformas de recolhimento/leira com multiplicador de carga do motor reduzido (0,75x).
- NOVO: Adicionado mapeamento de fallback automático para fillTypes '_WINDROW' e 'CUT_' para suas culturas base.
- MELHORADO: Calibração de precisão de fatores de cultura e densidades baseada em metas de produtividade reais (bu/hr).
- NOVO: Cada cultura agora usa predefinições técnicas individuais de manuais reais (mais de 20 culturas ajustadas).
- MELHORADO: Lógica da forrageira simplificada com um multiplicador universal de 0,75x.
- MELHORADO: Multiplicador de recolhimento refinado para 0,35x para colheita equilibrada de leiras.
- CORRIGIDO: Colheitadeiras não aceleram mais além das velocidades de trabalho originais quando a plataforma está vazia (sem cultura).
- CORRIGIDO: Removido o salto do limite de velocidade ao baixar a plataforma.
- MELHORADO: Sistema de detecção robusto para forrageiras e plataformas.
- MELHORADO: Limite de velocidade estritamente limitado aos limites do jogo original (removido o bônus de 1,5x).
- MELHORADO: Fatores de cultivo recalibrados para aveia (+25%), milho (-50%), soja (-20%) e algodão (2x).
- MELHORADO: Redução significativa de carga para culturas de raízes (batata, cenoura, pastinaca, cebola).
- CORRIGIDO: Bug de reset do limite de velocidade a 9,9 km/h durante em colheita contínua.
- CORRIGIDO: Ampliada a exceção de recolha de culturas de raízes para garantir uma carga realista para cebola e cenoura.
- ADICIONADO: Suporte para os tipos ONION_DIRTY e MEADOW.

Changelog 1.4.1.0:
- CORRIGIDO: Crash do jogo ("attempt to call missing method 'getIsControlled'") ao usar equipamentos DLC (ex: Highland DLC NH 8040 com ferramentas Holaras). Adicionada verificação nil segura.

Changelog 1.4.1.0:
- CORRIGIDO: Falha do jogo ao usar pacotes de DLC ("attempt to call missing method 'getIsControlled'").
- CORRIGIDO: A segunda colheitadeira Courseplay ficava presa a 10 km/h.
- CORRIGIDO: O modo AUTO reinicializava em 50 nos servidores dedicados.
- CORRIGIDO: Falha no menu de configurações com o sistema modular NEXAT.
- CORRIGIDO: Possível crash de jogo sem o método 'getAIFieldWorkerIsTurning'.

Changelog 1.4.0.0:
- NOVO: Adicionada compatibilidade com mods "HUD Hider".
- CORRIGIDO: Bug no cálculo de produtividade (T/h) causando saltos repentinos.
- CORRIGIDO: Fechamento inesperado da GUI durante o jogo.
- NOVO: Menu Interativo de Configurações e Calibração da Colheitadeira (RShift + K).
- NOVO: Modo de Controle Manual - Ajuste Ventilador, Rotor, Peneiras e Alimentador.
- NOVO: Configurações incorretas causam perda adicional de colheita.
- NOVO: Sistema de Perfil - Salvar/Carregar configurações personalizadas para cada cultura.
- NOVO: Novas colheitas começam com configurações neutras (50%), exigindo calibração.
- NOVO: Exibição de Perda de Colheita mostra sinais +/- (- para perdas, + para bônus, 0 para ideal).
- NOVO: Botões de ajuste manual (+/-) sempre visíveis na GUI de Calibração.
- CORRIGIDO: Rotação da câmera bloqueada corretamente quando o cursor está ativo.
- CORRIGIDO: HUD redefinindo para posições fora da tela. Adicionado correção automática.
- MELHORADO: Bloqueio de entrada agora usa o método correto camera.isRotatable.
- MELHORADO: Texto de dica da GUI reposicionado para evitar sobreposição.
- NOVO: O modo AUTO agora tem leve imperfeição (1-10 unidades) – a calibração manual pode superar o AUTO!
- NOVO: Mesma matemática de perdas para AUTO e MANUAL – sem mais bypass de zero perdas em AUTO.
- CORRIGIDO: Configurações da colheitadeira agora salvas/carregadas corretamente do savegame.
- CORRIGIDO: Cache profileCount corretamente restaurado após carregar savegame.
- CORRIGIDO: Detecção automática de cultura agora apenas no servidor – evita dessincronização no multiplayer.
- MELHORADO: Todas as configurações do mod (servidor + cliente) armazenadas na pasta modSettings/.
- MELHORADO: Servidor dedicado totalmente suportado – cada veículo mantém seu próprio perfil de calibração.

Changelog 1.3.2.0:
- NOVO: Sistema de perda de colheita física! As perdas agora reduzem o grão realmente coletado.
- NOVO: As perdas de colheita começam em 95% de carga do motor (antes 100%).
- NOVO: Fórmula de perda progressiva - sobrecarga maior = perda exponencialmente maior.
- MELHORADO: As penalidades por perdas afetam agora diretamente o rendimento.

Changelog 1.3.1.0:
- NOVO: Menu de configurações reorganizado em seções "Simulação" e "Visualização".
- NOVO: HUD móvel! Clique direito para cursor, depois arraste o HUD.
- NOVO: Controle independente da plataforma (configuração opcional).
- NOVO: Métricas do HUD resetam instantaneamente ao levantar/parar o corte.
- MELHORADO: Conteúdo do HUD personalizável (alternar elementos individuais).

Changelog 1.3.0.0:
- NOVO: Monitor de rendimento! Veja o rendimento em tempo real em t/ha ou bu/ac (alternável nas configurações) (#10)
- NOVO: Lógica de cálculo de carga completamente reescrita baseada no fluxo de massa (t/h) em vez de área.
- NOVO: Adicionado suporte experimental para o sistema NEXAT.
- MELHORADO: O texto do HUD agora está em negrito para melhor visibilidade.
- MELHORADO: Corrigido problema onde o HUD desaparecia ao trocar componentes do veículo.

Changelog 1.2.1.0:
- Corrigido cálculo de produtividade exibindo valores incorretos (estava 1000x muito baixo)
- Melhorada precisão da conversão massa-volume usando densidade real das culturas

Changelog 1.2.0.0:
- Adicionado suporte para colheitadeiras de algodão
- Adicionado suporte parcial para forrageiras
- Corrigidos problemas de sincronização multijogador
- Corrigido conflito do menu de configurações com outros mods
- Melhorada exibição do sistema de unidades (Imperial/Métrico)

Changelog 1.1.0.0:
- Novo recurso: Botão "Restaurar configurações" no rodapé do menu (tecla: X)
- Melhorias de interface: Descrições laterais para todas as configurações (dicas)
- Localização: Suporte completo de tradução para 10 idiomas (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Correções de bugs: Melhorada estabilidade do menu de configurações

---

## Language: UK

Зміни 1.5.0.0:
- НОВЕ: Інтеграція моду "Moisture System"! Додано динамічні штрафи до навантаження на двигун та підвищені втрати врожаю при збиранні у вологих умовах.
- НОВЕ: Відсоток вологості в реальному часі інтегровано у перетягуваний HUD.
- НОВЕ: Додано нове налаштування для ввімкнення/вимкнення інтеграції системи вологості.
- ПОКРАЩЕНО: Автопілот "Цільового навантаження на двигун": Додано "мертву зону" у 2%, щоб уникнути мікроколивань та зробити роботу круїз-контролю набагато плавнішою на полях з різною щільністю.
- ПОКРАЩЕНО: GUI калібрування: Параметр "Цільове навантаження на двигун" тепер має динамічну кольорову смугу прогресу (Зелений/Жовтий/Червоний) для кращої візуалізації замість звичайного тексту.
- ВИПРАВЛЕНО: Індикатор HUD вологості зависав на останньому значенні замість того, щоб скидатися до 0%, коли комбайн зупиняв збір врожаю або здавав назад.
- ВИПРАВЛЕНО: Рядок "Цільове навантаження на двигун" некоректно відображав текст "auto" в меню калібрування.
- НОВЕ: Додано консольну команду діагностики `rhm_inspect` для перегляду даних продуктивності та навантаження в реальному часі.
- ПОКРАЩЕНО: Повна переробка коефіцієнтів культур з використанням системи пошуку за назвою для вищої точності.
- ПОКРАЩЕНО: Чіткий поділ коефіцієнтів для кукурудзи на зерно та на силос для забезпечення реалістичної швидкості збирання.
- ПОКРАЩЕНО: Збалансовано коефіцієнти для трави та сіна як для прямого косіння, так і для підбирання з валків.
- ПОКРАЩЕНО: Оновлено множник навантаження підбирача (з 0.25 до 0.45) для зернових валків для створення реалістичного опору двигуна.
- НОВЕ: Універсальний "Захист для силосних комбайнів" (Forage Safety Net) для забезпечення реалістичного навантаження при роботі з нетиповими або модифікованими культурами.
- ВИПРАВЛЕНО: Вирішено проблему, коли жатки для силосозбиральних комбайнів розпізнавалися некоректно через регістр назв категорій.

Зміни 1.4.3.0:
- НОВЕ: Система купівлі! Додано можливість купувати розширені налаштування калібрування комбайна, що додає новий рівень розвитку кар'єри.
- НОВЕ: Повністю перероблено інтерактивний графічний інтерфейс калібрування (GUI) з новим вибором культури, покращенням взаємодії та додатковими інформаційними вкладками.
- НОВЕ: Покращений HUD, який можна перетягувати, з графічними індикаторами врожайності та навантаження на двигун.
- НОВЕ: Додано 7 розширених сторінок у внутрішньоігрове меню допомоги з описом усіх механік, унікальними іконками та перекладом на 11 мов.
- НОВЕ: Додана нова сторінка перекладу "Втрати врожаю" (Crop Loss) та вдосконалено описи мода.
- ПОКРАЩЕНО: Переглянуто основну логіку залежності швидкості від навантаження: мінімальні втрати врожаю тепер починаються з 80% навантаження замість 100%.
- ПОКРАЩЕНО: Фактор навантаження для кормозбиральних комбайнів тепер повністю динамічний і залежить від щільності культури та ширини жатки.
- ПОКРАЩЕНО: Перероблено механізм ін'єкції налаштувань. Використовуються безпечні хуки на рівні класів (`InGameMenuSettingsFrame.onFrameOpen`) для повної сумісності з DLC (Vredo, Precision Farming).
- ПОКРАЩЕНО: Глобальний рефакторинг: усі файли та внутрішні класи перейменовано з префіксом `RHM_`, щоб запобігти конфліктам простору імен з іншими модами.
- ПОКРАЩЕНО: Повністю перебудовано архітектуру логування. Всі відлагоджувальні логи тепер суворо закриті за прапорцем `-devWarnings`, завдяки чому файл `log.txt` у звичайних гравців залишається ідеально чистим.
- ВИПРАВЛЕНО: Вирішено критичний конфлікт інтерфейсу (UI), через який налаштування DLC зникали з меню гри.
- ВИПРАВЛЕНО: Виправлено регістр імен файлів у `main.lua` (`RHM_Combine.lua`, `RHM_Renderer.lua`), що усунуло зависання екрану завантаження на 55%.
- ВИПРАВЛЕНО: Помилку, через яку зміни в меню налаштувань не зберігалися коректно і не синхронізувалися із сервером через недійсний підпис колбеку (callback).
- ВИПРАВЛЕНО: Усунуто масовий спам у консолі (60 повідомлень на секунду), спричинений логом "Crop Loss Applied" під час збирання врожаю в режимі розробника.
- ВИПРАВЛЕНО: Виправлено синтаксичні помилки XML (`<paragraph>`) у `modDesc.xml`, щоб текст у меню допомоги відображався коректно і без попереджень рушія гри.
- ПОКРАЩЕНО: Оптимізовано макет інтерфейсу для використання стандартного `gameSettingsLayout`.
- ПОКРАЩЕНО: Видалено зайву кнопку "Скинути" (X) з підвалу меню.

Зміни 1.4.2.0:
- ВИПРАВЛЕНО: Проблема локалізації ('window_grass') для трави в меню HUD.
- ПОКРАЩЕНО: Видалено зайві логи дебагу з розрахунків навантаження двигуна.
- ПОКРАЩЕНО: Централізовано налаштування логів дебагу (RHM_Debug.lua).
- ДОДАНО: Іспанська локалізація для всіх функцій та меню моду.
- НОВЕ: Додано параметр для вимкнення попереджень HUD "High Load".
- ПОКРАЩЕНО: Внутрішнє прибирання логіки попереджень.
- ВИПРАВЛЕНО: Повне переписування математики підрахунку врожаю для синхронізації з HUD Precision Farming.
- ВИПРАВЛЕНО: Кормозбиральні комбайни (Silage) показували врожайність в 10 разів нижче через баги об'єму.
- ВИПРАВЛЕНО: Математичні десинхронізації при асинхронному наповненні бункера.
- НОВЕ: Фізика налаштувань комбайна розділена на дві незалежні категорії: Ефективність (впливає на швидкість) та Втрати (впливає на втрачене зерно).
- НОВЕ: HUD меню налаштувань перероблено для одночасного відображення впливу на швидкість та втрати.
- НОВЕ: Додано механіку "Щит від перевантажень" - ідеальні налаштування захищають від стрибків щільності врожаю.
- ВИПРАВЛЕНО: Критичний баг, через який ідеальні налаштування знижували швидкість до ігрових лімітів.
- ВИПРАВЛЕНО: Комбайн не прискорювався при покращенні налаштувань під час збирання.
- ВИПРАВЛЕНО: Вирішено проблему дублювання реєстрації XML-шляхів збереження, що викликала помилки в логах сервера та скидання налаштувань.
- ПОКРАЩЕНО: Пропускна здатність кормозбиральних комбайнів відкалібрована до реальних даних (коефіцієнт змінено з 0.150 на 0.051).
- НОВЕ: Додано універсальне визначення Pickup/Swath жаток зі зниженим множником навантаження на двигун (0.75x).
- НОВЕ: Додано автоматичне зіставлення (резервне визначення) валків ('_WINDROW') та зрізаних трав ('CUT_') з їхніми базовими культурами.
- ПОКРАЩЕНО: Точне калібрування факторів та щільності культур на основі реальних цільових показників врожайності (бушелі/рік).
- НОВЕ: Кожна культура тепер використовує індивідуальні технічні пресети з реальних посібників (20+ культур налаштовано).
- ПОКРАЩЕНО: Спрощено логіку кормозбиральних комбайнів з універсальним множником 0.75x.
- ПОКРАЩЕНО: Множник підбирача встановлено на 0.35x для збалансованого збору валків.
- ВИПРАВЛЕНО: Комбайн більше не розганяється вище робочої швидкості гри, коли жатка опущена, але нічого не збирає.
- ВИПРАВЛЕНО: Видалено стрибок ліміту швидкості при опусканні жатки.
- ПОКРАЩЕНО: Надійна система детекції для кормозбиральних комбайнів та жаток.
- ПОКРАЩЕНО: Ліміт швидкості суворо обмежений ванільними лімітами гри (видалено бонус 1.5x).
- ПОКРАЩЕНО: Перекалібровано фактори культур для вівса (+25%), кукурудзи (-50%), сої (-20%) та бавовни (2x).
- ПОКРАЩЕНО: Суттєве зниження навантаження на коренеплоди (картопля, морква, пастернак, цибуля).
- ВИПРАВЛЕНО: Баг скидання швидкості до 5 км/год при досягненні 9.9 км/год під час роботи.
- ВИПРАВЛЕНО: Розширено логіку винятку для підбирання коренеплодів (цибуля, морква) для реалістичного навантаження.
- ДОДАНО: Підтримку типів ONION_DIRTY та MEADOW.

Зміни 1.4.1.0:
- ВИПРАВЛЕНО: Вилітання гри ("attempt to call missing method 'getIsControlled'") при використанні техніки з DLC (наприклад, Highland DLC NH 8040 з інструментами Holaras). Додано безпечну перевірку nil.

Зміни 1.4.0.0:
- НОВЕ: Додано сумісність з модами "HUD Hider" (HUD зникає разом з інтерфейсом гри).
- ВИПРАВЛЕНО: Помилка розрахунку продуктивності (T/h), що викликала раптові стрибки.
- ВИПРАВЛЕНО: Несподіване закриття інтерфейсу під час гри.
- НОВЕ: Інтерактивне меню налаштувань та калібрування комбайна (RShift + K).
- НОВЕ: Ручний режим керування - Налаштування вентилятора, ротора, решіт та подачі.
- НОВЕ: Неправильні налаштування спричиняють додаткові втрати врожаю.
- НОВЕ: Система профілів - Збереження/Завантаження власних налаштувань для кожної культури.
- НОВЕ: Нові культури починаються з нейтральних (50%) налаштувань, потребують калібрування.
- НОВЕ: Індикатор втрат тепер показує знаки +/- (- для втрат, + для бонусів, 0 для оптимуму).
- НОВЕ: Кнопки ручного налаштування (+/-) завжди видимі в меню калібрування.
- ВИПРАВЛЕНО: Обертання камери правильно блокується, коли курсор активний.
- ВИПРАВЛЕНО: HUD скидався на позиції поза екраном. Додано автовиправлення та команду скидання.
- ПОКРАЩЕНО: Блокування введення тепер використовує правильний метод camera.isRotatable.
- ПОКРАЩЕНО: Текст підказок переміщено, щоб не перекривав кнопки.
- НОВЕ: Режим AUTO тепер має незначну недосконалість (1-10 одиниць) – ручне налаштування може перевершити AUTO!
- НОВЕ: Однакова математика втрат для AUTO і MANUAL – більше нема обходу нульових втрат в AUTO.
- ВИПРАВЛЕНО: Налаштування комбайну тепер коректно зберігаються/завантажуються з savegame (vehicles.xml).
- ВИПРАВЛЕНО: Кеш profileCount коректно відновлюється після завантаження збереження.
- ВИПРАВЛЕНО: Авто-детекція культури тепер лише на сервері – запобігає десинхронізації в мультиплеєрі.
- ПОКРАЩЕНО: Всі налаштування моду (сервер + клієнт) зберігаються в папці modSettings/.
- ПОКРАЩЕНО: Виділені сервери повністю підтримуються – кожен транспортний засіб зберігає власний профіль калібрування.

Зміни 1.3.2.0:
- НОВЕ: Фізична система втрат врожаю! Втрати тепер зменшують реальну кількість зерна в бункері.
- НОВЕ: Втрати врожаю починаються при 95% навантаженні двигуна (раніше 100%).
- НОВЕ: Прогресивна формула втрат - більше перевантаження = експоненційно більше втрат.
- ПОКРАЩЕНО: Штрафи за втрати тепер безпосередньо впливають на врожайність.

Зміни 1.3.1.0:
- НОВЕ: Меню налаштувань розділено на секції "Симуляція" та "Відображення".
- НОВЕ: Переміщення HUD! Натисніть ПКМ для курсора, потім перетягніть HUD.
- НОВЕ: Роздільне керування жаткою та молотаркою (опція в налаштуваннях).
- НОВЕ: Показники HUD скидаються миттєво при піднятті/зупинці жатки.
- ПОКРАЩЕНО: Можливість налаштування вмісту HUD (індивідуальні елементи).

Зміни 1.3.0.0:
- НОВЕ: Монітор врожайності! Дивіться врожайність в реальному часі в т/га або бу/акр (перемикається в налаштуваннях) (#10)
- НОВЕ: Повністю переписана логіка розрахунку навантаження на основі пропускної здатності маси (т/год) замість площі.
- НОВЕ: Додана експериментальна підтримка системи NEXAT.
- ПОКРАЩЕНО: Текст HUD тепер жирний для кращої видимості.
- ПОКРАЩЕНО: Виправлено проблему, коли HUD зникав при перемиканні компонентів транспортного засобу.

Зміни 1.2.1.0:
- Виправлено розрахунок продуктивності, що показував неправильні значення (було в 1000 разів занижено)
- Покращено точність перетворення маси в об'єм з використанням реальної щільності культур

Зміни 1.2.0.0:
- Додано підтримку бавовняних комбайнів
- Додано часткову підтримку кормозбиральних комбайнів
- Виправлено проблеми синхронізації в мультиплеєрі
- Виправлено конфлікт меню налаштувань з іншими модами
- Покращено відображення системи одиниць (Імперська/Метрична)

Зміни 1.1.0.0:
- Нова функція: Кнопка "Скинути налаштування" в нижній частині меню (клавіша: X)
- Покращення інтерфейсу: Бічні описи для всіх налаштувань (підказки)
- Локалізація: Повна підтримка перекладу для 10 мов (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Виправлення помилок: Покращено стабільність меню налаштувань

---

## Language: RU

Изменения 1.5.0.0:
- НОВОЕ: Интеграция мода "Moisture System"! Добавлены динамические штрафы к нагрузке на двигатель и повышенные потери урожая при уборке во влажных условиях.
- НОВОЕ: Процент влажности в реальном времени теперь интегрирован в перемещаемый HUD.
- НОВОЕ: Добавлена новая настройка для включения/выключения интеграции системы влажности.
- УЛУЧШЕНО: Автопилот "Целевой нагрузки на двигатель": Введена "мертвая зона" в 2%, чтобы избежать микроколебаний и сделать работу круиз-контроля гораздо более плавной при различной плотности урожая.
- УЛУЧШЕНО: GUI калибровки: Параметр "Целевая нагрузка на двигатель" теперь имеет динамическую цветовую полосу прогресса (Зеленый/Желтый/Красный) для лучшей визуализации вместо обычного текста.
- ИСПРАВЛЕНО: Индикатор HUD влажности зависал на последнем значении, вместо того чтобы сбрасываться на 0%, когда комбайн останавливал уборку или сдавал назад.
- ИСПРАВЛЕНО: Строка "Целевая нагрузка на двигатель" некорректно отображала текст "auto" в меню калибровки.
- НОВОЕ: Добавлена консольная команда диагностики `rhm_inspect` для просмотра данных производительности и нагрузки в реальном времени.
- УЛУЧШЕНО: Полная переработка коэффициентов культур с использованием системы поиска по названию для более высокой точности.
- УЛУЧШЕНО: Четкое разделение коэффициентов для кукурузы на зерно и на силос для обеспечения реалистичной скорости уборки.
- УЛУЧШЕНО: Сбалансированы коэффициенты для травы и сена как для прямого кошения, так и для подбора из валков.
- УЛУЧШЕНО: Обновлен множитель нагрузки подборщика (с 0.25 до 0.45) для зерновых валков для создания реалистичного сопротивления двигателя.
- НОВОЕ: Универсальная "Защита для силосных комбайнов" (Forage Safety Net) для обеспечения реалистичной нагрузки при работе с нетипичными или модифицированными культурами.
- ИСПРАВЛЕНО: Решена проблема, когда жатки для силосоуборочных комбайнов распознавались некорректно из-за регистра имен категорий.

Изменения 1.4.3.0:
- НОВОЕ: Система покупок! Добавлен функционал покупки расширенных настроек калибровки комбайна, что вносит новый слой прогрессии в режиме карьеры.
- НОВОЕ: Полностью переработан интерактивный графический интерфейс (GUI) калибровки комбайна: новый выбор культур, улучшения взаимодействия и дополнительные вкладки с информацией.
- НОВОЕ: Улучшенный перемещаемый HUD, отображающий производительность комбайна, включая графические индикаторы урожайности и нагрузки на двигатель.
- НОВОЕ: Во внутриигровое меню помощи добавлено 7 подробных страниц, описывающих все механики мода, с уникальными иконками и локализацией на 11 языков.
- НОВОЕ: Добавлена страница перевода «Потери урожая» (Crop Loss), а также улучшены описания мода для всех поддерживаемых языков.
- УЛУЧШЕНО: Пересмотрена базовая логика зависимости скорости от нагрузки на двигатель: минимальные потери урожая теперь закономерно начинаются с 80% нагрузки вместо 100%.
- УЛУЧШЕНО: Коэффициент нагрузки для кормоуборочных комбайнов теперь полностью динамический и зависит от плотности культуры и ширины жатки.
- УЛУЧШЕНО: Переработан механизм инъекции настроек. Теперь используются безопасные хуки на уровне движка (`InGameMenuSettingsFrame.onFrameOpen`) для максимальной совместимости с DLC (Vredo Pack, Precision Farming и т. д.).
- УЛУЧШЕНО: Глобальный рефакторинг пространства имен: все внутренние классы и файлы переименованы с префиксом `RHM_`, чтобы предотвратить конфликты с другими сторонними модами.
- УЛУЧШЕНО: Полностью переписана архитектура логирования (вместо ранней RHM_Debug). Все отладочные сообщения теперь строго скрыты за флагом запуска `-devWarnings`, благодаря чему `log.txt` пользователя по умолчанию остается абсолютно чистым.
- ИСПРАВЛЕНО: Решен критический конфликт пользовательского интерфейса, из-за которого настройки DLC исчезали из меню игры, когда был активен мод Realistic Harvesting.
- ИСПРАВЛЕНО: Исправлен регистр в названиях файлов в `main.lua` (`RHM_Combine`, `RHM_Renderer`), что устранило печально известное зависание экрана загрузки на 55%.
- ИСПРАВЛЕНО: Разрешена проблема, из-за которой изменения в меню настроек не сохранялись и не синхронизировались с сервером должным образом из-за неверной сигнатуры обратного вызова.
- ИСПРАВЛЕНО: Устранен массовый спам в консоль (по 60 логов в секунду) об «Учете потерь урожая» во время уборки в режиме разработчика.
- ИСПРАВЛЕНО: Исправлены синтаксические ошибки XML (теги `<paragraph>`) в `modDesc.xml`, чтобы текст меню помощи отображался идеально и без предупреждений движка.
- УЛУЧШЕНО: Оптимизирован макет интерфейса, используется стандартный `gameSettingsLayout` для единообразного позиционирования меню.
- УЛУЧШЕНО: Из подвала удалена лишняя кнопка «Сброс» (X), так как она вызывала нестабильность верстки с другими модами.

Изменения 1.4.2.0:
- ИСПРАВЛЕНО: Проблема локализации ('window_grass') для травы в меню HUD.
- УЛУЧШЕНО: Удалены чрезмерные логи отладки из расчетов нагрузки двигателя.
- УЛУЧШЕНО: Централизована настройка логов отладки (RHM_Debug.lua).
- ДОБАВЛЕНО: Испанская локализация для всех функций и меню мода.
- НОВОЕ: Добавлена настройка для отключения предупреждений HUD "High Load".
- УЛУЧШЕНО: Внутренняя очистка логики предупреждений.
- ИСПРАВЛЕНО: Полная переработка математики расчёта урожая для синхронизации с HUD Precision Farming.
- ИСПРАВЛЕНО: Кормоуборочные комбайны показывали урожайность в 10 раз ниже из-за ошибок объёма двигателя.
- ИСПРАВЛЕНО: Математические десинхронизации при асинхронном заполнении бункера.
- НОВОЕ: Физика настроек комбайна разделена на 2 независимые категории: Эффективность (скорость) и Потери урожая.
- НОВОЕ: HUD меню настроек переработано для одновременного показа скорости и потерь.
- НОВОЕ: Добавлена механика "Щит от перегрузок".
- ИСПРАВЛЕНО: Критический баг, из-за которого идеальные настройки снижали скорость.
- ИСПРАВЛЕНО: Комбайн не разгонялся при улучшении настроек на ходу.
- ИСПРАВЛЕНО: Решена проблема дублирования регистрации XML-путей сохранения, вызывавшая ошибки в логах сервера и сброс настроек.
- УЛУЧШЕНО: Пропускная способность кормоуборочных комбайнов откалибрована согласно реальным данным (коэффициент изменен с 0.150 на 0.051).
- НОВОЕ: Добавлено универсальное определение Pickup/Swath жаток с пониженным множителем нагрузки на двигатель (0.75x).
- НОВОЕ: Добавлено автоматическое сопоставление (резервное определение) валков ('_WINDROW') и срезанных трав ('CUT_') с их базовыми культурами.
- УЛУЧШЕНО: Точная калибровка факторов и плотности культур на основе реальных целевых показателей урожайности (бушели/час).
- НОВОЕ: Каждая культура теперь использует индивидуальные технические пресеты из реальных руководств (20+ культур настроены).
- УЛУЧШЕНО: Упрощена логика кормоуборочных комбайнов с универсальным множителем 0.75x.
- УЛУЧШЕНО: Множитель подборщика установлен на 0.35x для сбалансированной уборки валков.
- ИСПРАВЛЕНО: Комбайн больше не разгоняется выше рабочей скорости игры, когда жатка опущена, но ничего не убирает.
- ИСПРАВЛЕНО: Удален скачок лимита скорости при опускании жатки.
- УЛУЧШЕНО: Надежная система детекции для кормоуборочных комбайнов и жаток.
- УЛУЧШЕНО: Лимит скорости строго ограничен ванильными лимитами игры (удален бонус 1.5x).
- УЛУЧШЕНО: Перекалиброваны факторы культур для овса (+25%), кукурузы (-50%), сои (-20%) и хлопка (2x).
- УЛУЧШЕНО: Существенное снижение нагрузки на корнеплоды (картофель, морковь, пастернак, лук).
- ИСПРАВЛЕНО: Баг сброса скорости до 5 км/ч при достижении 9.9 км/ч во время работы.
- ИСПРАВЛЕНО: Расширена логика исключения для подбора корнеплодов (лук, морковь) для реалистичной нагрузки.
- ДОБАВЛЕНО: Поддержка типов ONION_DIRTY и MEADOW.

Изменения 1.4.1.0:
- ИСПРАВЛЕНО: Вылет игры ("attempt to call missing method 'getIsControlled'") при использовании техники из DLC (например, Highland DLC NH 8040 с инструментами Holaras). Добавлена безопасная проверка nil.

Изменения 1.4.0.0:
- НОВОЕ: Добавлена совместимость с модами "HUD Hider".
- ИСПРАВЛЕНО: Ошибка расчета производительности (T/h), вызывающая скачки.
- ИСПРАВЛЕНО: Неожиданное закрытие интерфейса во время игры.
- НОВОЕ: Интерактивное меню настроек и калибровки комбайна (RShift + K).
- НОВОЕ: Ручной режим управления - Настройка вентилятора, ротора, решет и подачи.
- НОВОЕ: Неправильные настройки вызывают дополнительные потери урожая.
- НОВОЕ: Система профилей - Сохранение/Загрузка пользовательских настроек для каждой культуры.
- НОВОЕ: Новые культуры начинаются с нейтральных (50%) настроек, требуют калибровки.
- НОВОЕ: Индикатор потерь теперь показывает знаки +/- (- для потерь, + для бонусов, 0 для оптимума).
- НОВОЕ: Кнопки ручной настройки (+/-) всегда видимы в меню калибровки.
- ИСПРАВЛЕНО: Вращение камеры правильно блокируется, когда курсор активен.
- ИСПРАВЛЕНО: HUD сбрасывался на позиции за пределами экрана. Добавлено автоисправление.
- УЛУЧШЕНО: Блокировка ввода теперь использует правильный метод camera.isRotatable.
- УЛУЧШЕНО: Текст подсказок в меню перемещен, чтобы не перекрывал кнопки.
- НОВОЕ: Режим AUTO теперь имеет незначительное несовершенство (1-10 единиц) – ручная настройка может превзойти AUTO!
- НОВОЕ: Одинаковая математика потерь для AUTO и MANUAL – больше нет обхода нулевых потерь в AUTO.
- ИСПРАВЛЕНО: Настройки комбайна теперь корректно сохраняются/загружаются из savegame (vehicles.xml).
- ИСПРАВЛЕНО: Кеш profileCount корректно восстанавливается после загрузки сохранения.
- ИСПРАВЛЕНО: Авто-определение культуры теперь только на сервере – предотвращает десинхронизацию в мультиплеере.
- УЛУЧШЕНО: Все настройки мода (сервер + клиент) хранятся в папке modSettings/.
- УЛУЧШЕНО: Выделенные серверы полностью поддерживаются – каждое ТС сохраняет собственный профиль калибровки.

Изменения 1.3.2.0:
- НОВОЕ: Физическая система потерь урожая! Потери теперь уменьшают реально собранное зерно.
- НОВОЕ: Потери урожая начинаются при 95% нагрузке двигателя (ранее 100%).
- НОВОЕ: Прогрессивная формула потерь - большая перегрузка = экспоненциально больше потерь.
- УЛУЧШЕНО: Штрафы за потери теперь напрямую влияют на урожайность.

Изменения 1.3.1.0:
- НОВОЕ: Меню настроек разделено на секции "Симуляция" и "Отображение".
- НОВОЕ: Перетаскиваемый HUD! ПКМ для курсора, затем перетащите HUD.
- НОВОЕ: Раздельное управление жаткой и молотилкой (опция в настройках).
- НОВОЕ: Показатели HUD сбрасываются мгновенно при поднятии/остановке жатки.
- УЛУЧШЕНО: Возможность настройки содержимого HUD (индивидуальные элементы).

Изменения 1.3.0.0:
- НОВОЕ: Монитор урожайности! Смотрите урожайность в реальном времени в т/га или бу/акр (переключается в настройках) (#10)
- НОВОЕ: Полностью переписана логика расчета нагрузки на основе пропускной способности массы (т/ч) вместо площади.
- НОВОЕ: Добавлена экспериментальная поддержка системы NEXAT.
- УЛУЧШЕНО: Текст HUD теперь жирный для лучшей видимости.
- УЛУЧШЕНО: Исправлена проблема, когда HUD исчезал при переключении компонентов транспортного средства.

Изменения 1.2.1.0:
- Исправлен расчет производительности, показывающий неправильные значения (было в 1000 раз занижено)
- Улучшена точность преобразования массы в объем с использованием реальной плотности культур

Изменения 1.2.0.0:
- Добавлена поддержка хлопкоуборочных комбайнов
- Добавлена частичная поддержка кормоуборочных комбайнов
- Исправлены проблемы синхронизации в мультиплеере
- Исправлен конфликт меню настроек с другими модами
- Улучшено отображение системы единиц (Имперская/Метрическая)

Изменения 1.1.0.0:
- Новая функция: Кнопка "Сбросить настройки" в нижней части меню (клавіша: X)
- Улучшения интерфейса: Боковые описания для всех настроек (подсказки)
- Локализация: Полная поддержка перевода для 10 языков (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Исправления ошибок: Улучшена стабильность меню налаштувань

---

## Language: HU


Változások 1.5.0.0:
- ÚJ: "Moisture System" Mod Integráció! Hozzáadva a dinamikus motorterhelési büntetések és a megnövekedett termésveszteségek nedves körülmények közötti betakarításkor.
- ÚJ: Valós idejű nedvességszázalék kijelző integrálva a mozgatható HUD-ba.
- ÚJ: Új beállítás hozzáadva a Nedvességrendszer integrációjának be- és kikapcsolására.
- FEJLESZTVE: "Cél Motorterhelés" Autópilóta: 2%-os holttér bevezetése a mikrooszcillációk megelőzése és a sokkal simább sebességtartó élmény biztosítása érdekében a különböző terménysűrűségek esetén.
- FEJLESZTVE: Kalibrációs GUI: A "Cél Motorterhelés" mostantól dinamikus színkódolt folyamatjelző sávval (Zöld/Sárga/Piros) rendelkezik a jobb vizuális visszajelzés érdekében az egyszerű szöveg helyett.
- JAVÍTVA: A nedvesség HUD indikátor az utolsó értékén fagyott be ahelyett, hogy 0%-ra állt volna vissza, amikor a kombájn leállítja a betakarítást vagy tolat.
- JAVÍTVA: A "Cél Motorterhelés" helytelenül "auto"-ként jelent meg a kalibrációs menüben.
- ÚJ: Diagnosztikai konzolparancs hozzáadva (`rhm_inspect`) a betakarítógép teljesítményadatainak valós idejű megtekintéséhez.
- FEJLESZTVE: A terménytényezők teljes felülvizsgálata név alapú keresőrendszerrel a nagyobb pontosság érdekében.
- FEJLESZTVE: Éles elkülönítés a Szemes Kukorica és a Silókukorica együtthatói között a reális betakarítási sebesség érdekében.
- FEJLESZTVE: Kiegyensúlyozott fű- és szénabetakarítási együtthatók (közvetlen vágás és rendfelszedés).
- FEJLESZTVE: Finomított rendfelszedő terhelési szorzó (0,25-ről 0,45-re) gabonarendeknél a reálisabb motorellenállás érdekében.
- ÚJ: Univerzális „Forage Safety Net” a reális terhelés biztosítására a silózók által feldolgozott nem szabványos vagy módosított terményeknél.
- JAVÍTVA: Megoldódott egy hiba, amely miatt a silózó vágószerkezetek nem lettek megfelelően felismerve a kategórianevek kis- és nagybetűérzékenysége miatt.

Változások 1.4.3.0:
- ÚJ: Vásárlási Rendszer! Hozzáadva egy funkció a fejlett kombájn kalibrációs beállítások megvásárlásához, ami a karrierépítés új szintjét jelenti.
- ÚJ: Teljesen újratervezett, interaktív Kombájn Kalibrációs GUI új terményválasztással, interakciós fejlesztésekkel és további információs lapokkal.
- ÚJ: Továbbfejlesztett húzható HUD a kombájn teljesítményének megjelenítéséhez, beleértve a hozam és a motorterhelés grafikus mérőit.
- ÚJ: 7 részletes oldallal bővült a játékon belüli súgó menü, amely minden mod mechanikát lefed egyedi ikonokkal és 11 nyelvű lokalizációval.
- ÚJ: "Terményveszteség" (Crop Loss) fordítási oldal hozzáadva, valamint a mod leírások finomítása az összes támogatott nyelven.
- FEJLESZTVE: A sebesség motorterheléstől való függésének alaplogikája felülvizsgálva: a minimális terményveszteségek mostantól 100% helyett jogosan 80%-os terhelésnél kezdődnek.
- FEJLESZTVE: A silózókkoválasztó terhelési tényezője mostantól teljesen dinamikus a termény sűrűsége és a vágószerkezet szélessége alapján.
- FEJLESZTVE: A beállítások befecskendezési mechanizmusa át lett alakítva biztonságos motor osztályszintű hook-ok (`InGameMenuSettingsFrame.onFrameOpen`) használatára a maximális DLC-kompatibilitás (Vredo Pack, Precision Farming stb.) érdekében.
- FEJLESZTVE: Globális Névtér Refaktorálás: Minden belső fájl és osztály átnevezve `RHM_` előtaggal, hogy elkerüljük az ütközéseket más harmadik féltől származó modokkal.
- FEJLESZTVE: Teljesen újraépítve a mod hibakeresési (debug) architektúrája. Minden debug kimenet mostantól szigorúan a játék `-devWarnings` jelzője mögé van rejtve, így a felhasználó `log.txt`-je alapértelmezés szerint tökéletesen tiszta marad.
- JAVÍTVA: Megoldódott egy kritikus UI konfliktus, amely miatt a DLC beállítások eltűntek a játékmenüből, amikor a Realistic Harvesting aktív volt.
- JAVÍTVA: A fájlnevek nagybetű-használata (`RHM_Combine`, `RHM_Renderer`) javítva lett a `main.lua`-ban, megoldva a hírhedt 55%-os betöltőképernyő-fagyást.
- JAVÍTVA: Megoldódott egy hiba, amely miatt a beállításmenüben végrehajtott módosítások nem mentődtek el vagy szinkronizálódtak megfelelően a szerverrel egy érvénytelen visszahívási aláírás (callback signature) miatt.
- JAVÍTVA: Megszüntetve a fejlesztői módban betakarítás közben a "Crop Loss Applied" által okozott masszív konzolos spam (másodpercenként 60 naplóbejegyzés).
- JAVÍTVA: XML szintaktikai hibák (`<paragraph>` címkék) javítása a `modDesc.xml`-ben annak biztosítására, hogy a Súgó menü szövege tökéletesen jelenjen meg motorfigyelmeztetések nélkül.
- FEJLESZTVE: A felhasználói felület (UI) elrendezése optimalizálva lett a standard `gameSettingsLayout` használatára a menü következetes elhelyezése érdekében.
- FEJLESZTVE: Az eltávolított redundáns "Visszaállítás" (Reset/X) gomb a láblécből, mivel a többi moddal együtt elrendezési instabilitást okozott.

Változások 1.4.2.0:
- JAVÍTVA: A fű ('window_grass') lokalizációs hibája a HUD menüben.
- JAVÍTVA: Eltávolítottuk a felesleges hibakeresési (debug) naplófájlokat a motorterhelési számításokból.
- JAVÍTVA: Központosított hibakeresési napló (RHM_Debug.lua).
- HOZZÁADVA: Spanyol lokalizáció az összes mod-funkcióhoz és menühöz.
- ÚJ: Lehetőség a "High Load" HUD-figyelmeztetések letiltására.
- JAVÍTVA: A hozamszámítás teljes felülvizsgálata a Precision Farming HUD szinkronizálásához.
- JAVÍTVA: Szilázskészítők 10x alacsonyabb hozamot mutattak motortérfogat-hibák miatt.
- JAVÍTVA: Matematikai deszinkronizáció az aszinkron bunkerfelöltésnél.
- ÚJ: A beállítások fizikája két kategóriába lett sorolva: Hatékonyság (sebesség) és Termésveszteség.
- ÚJ: A beállítások HUD átalakítása, hogy mindig egyszerre mutassa a sebességet és a veszteséget.
- ÚJ: "Túlterhelésvédő" mechanika hozzáadva.
- JAVÍTVA: Kritikus hiba, ami miatt a tökéletes beállítások csökkenthették a sebességet.
- JAVÍTVA: Gyorsulás javítva, ha betakarítás közben javítják a beállításokat.
- JAVÍTVA: Megoldódott a mentési XML-útvonalak kettős regisztrációja, amely szervernaplózási hibákat és a beállítások visszaállítását okozta.
- JAVÍTVA: Az önjáró szecskázó áteresztőképessége a valós adatokhoz igazítva (együttható 0,150-ről 0,051-re módosítva).
- ÚJ: Univerzális rendfelszedő/rendrakó adapter érzékelés hozzáadva alacsonyabb motorterhelési szorzóval (0,75x).
- ÚJ: Automatikus visszaesési (fallback) leképezés hozzáadva a '_WINDROW' és 'CUT_' fillType-ok alapnövényeikhez történő hozzárendeléséhez.
- JAVÍTVA: A terménytényezők és sűrűségek precíziós kalibrálása a valós hozamcélok alapján (bu/hr).
- ÚJ: Minden növény mostantól egyedi technikai előbeállításokat használ valós kézikönyvekből (20+ növény finomhangolva).
- JAVÍTVA: A szecskázó logika egyszerűsítve lett egy univerzális 0,75x-ös szorzóval.
- JAVÍTVA: A rendfelszedő szorzója 0,35x-re lett finomítva a kiegyensúlyozott rendbetakarítás érdekében.
- JAVÍTVA: A kombájnok már nem gyorsulnak az alap játék munkasebessége fölé, ha az adapter üres (nincs termény).
- JAVÍTVA: Eltávolítva a sebességkorlát ugrása az adapter leengedésekor.
- JAVÍTVA: Robusztus felismerő rendszer a szecskázókhoz és adapterekhez.
- JAVÍTVA: A sebességkorlát szigorúan az alap játék limitjeihez kötve (1,5x bónusz eltávolítva).
- JAVÍTVA: Újrakalibrált növényi tényezők zab (+25%), kukorica (-50%), szója (-20%) és gyapot (2x) esetén.
- JAVÍTVA: Jelentős terheléscsökkentés a gyökérnövényeknél (burgonya, sárgarépa, pasztinák, hagyma).
- JAVÍTVA: Sebességkorlátozás "visszaállítási hurok" hiba javítva 9,9 km/h-nál folyamatos betakarítás közben.
- JAVÍTVA: Kiterjesztett kivétel a gyökérnövények felszedéséhez a hagyma és sárgarépa reális terhelésének biztosítása érdekében.
- HOZZÁADVA: ONION_DIRTY és MEADOW fillType-ok támogatása.

Változások 1.4.1.0:
- JAVÍTVA: Játék összeomlás ("attempt to call missing method 'getIsControlled'") DLC járművek használatakor (pl. Highland DLC NH 8040 Holaras eszközökkel). Biztonságos nil ellenőrzés hozzáadva.

Változások 1.4.0.0:
- ÚJ: Kompatibilitás a "HUD Hider" modokkal.
- JAVÍTVA: A termelékenység (T/h) számítási hibája, amely hirtelen ugrásokat okozott.
- JAVÍTVA: A GUI váratlan bezáródása játék közben.
- ÚJ: Interaktív kombájn beállítási és kalibrációs menü (RShift + K).
- ÚJ: Kézi vezérlési mód - Ventilátor, rotor, rosták és adagoló beállítása.
- ÚJ: A helytelen beállítások további termésveszteséget okoznak.
- ÚJ: Profilrendszer - Egyéni beállítások mentése/betöltése minden terményhez.
- ÚJ: Az új növények semleges (50%) beállításokkal indulnak, kalibrálást igényelnek.
- ÚJ: A veszteségkijelző mostantól +/- jeleket mutat (- a veszteségeknél, + a bónuszoknál, 0 az optimálisnál).
- ÚJ: A kézi beállító gombok (+/-) mindig láthatók a kalibrációs GUI-ban.
- JAVÍTVA: A kamera forgatása megfelelően blokkolva van, amikor a kurzor aktív.
- JAVÍTVA: A HUD képernyőn kívüli pozíciókra állt vissza. Automatikus javítás hozzáadva.
- JAVÍTVA: A bemenet blokkolása most már a megfelelő camera.isRotatable módszert használja.
- JAVÍTVA: A GUI tippszöveg áthelyezve, hogy ne takarja ki a gombokat.
- ÚJ: Az AUTO mód most enyhe tökéletlenséggel rendelkezik (1-10 egység eltérés) – a kézi beállítás felülmúlhatja az AUTO-t!
- ÚJ: Azonos veszteségszámítás AUTO és MANUÁLIS módhoz – nincs több nulla-veszteség bypass AUTO-ban.
- JAVÍTVA: A kombájn beállítások mostantól helyesen kerülnek mentésre/betöltésre a savegame-ből (vehicles.xml).
- JAVÍTVA: A profileCount gyorsítótár helyesen áll vissza a savegame betöltése után.
- JAVÍTVA: Az automatikus terményfelismerés mostantól csak szerver oldalon – megakadályozza a desynchronizációt multiplayerben.
- JAVÍTVA: Minden mod beállítás (szerver + kliens) a modSettings/ mappában tárolva.
- JAVÍTVA: Dedikált szerver teljesen támogatott – minden jármű megőrzi saját kalibrációs profilját.

Változások 1.3.2.0:
- ÚJ: Fizikai termésveszteség rendszer! A veszteségek most csökkentik a ténylegesen összegyűjtött gabonát.
- ÚJ: A termésveszteségek 95%-os motorterhelésnél kezdődnek (korábban 100%).
- ÚJ: Progresszív veszteségképlet - nagyobb túlterhelés = exponenciálisan nagyobb veszteség.
- JAVÍTVA: A veszteségbüntetések most közvetlenül befolyásolják a termésátlagot.

Változások 1.3.1.0:
- ÚJ: A beállítási menü "Szimuláció" és "Megjelenítés" szekciókra lett osztva.
- ÚJ: Mozgatható HUD! Jobb klikk a kurzorhoz, majd húzza a HUD-ot.
- ÚJ: Független vágóasztal-vezérlés (opcionális beállítás).
- ÚJ: A HUD mutatói azonnal visszaállnak a vágóasztal emelésekor/megállításakor.
- JAVÍTVA: Testreszabható HUD tartalom (egyes elemek kapcsolása).

Változások 1.3.0.0:
- ÚJ: Hozammonitor! Valós idejű hozam megtekintése t/ha vagy bu/ac mértékegységben (kapcsolható a beállításokban) (#10)
- ÚJ: Teljesen átírt terhelésszámítási logika, amely terület helyett tömegáram (t/h) alapú.
- ÚJ: Kísérleti támogatás a NEXAT rendszerhez.
- JAVÍTVA: A HUD szövege most félkövér a jobb láthatóság érdekében.
- JAVÍTVA: Javítva a hiba, amely miatt a HUD eltűnt a jármű alkatrészeinek váltásakor.

Változások 1.2.1.0:
- Javítva a teljesítményszámítás, amely hibás értékeket mutatott (1000× túl alacsony volt)
- Pontosabb tömeg–térfogat átváltás a valós terménysűrűség használatával

Változások 1.2.0.0:
- Gyapotbetakarítók támogatásának hozzáadása
- Részleges támogatás a silózó betakarítókhoz
- Többjátékos szinkronizációs problémák javítása
- Beállítási menü ütközésének javítása más modokkal
- Egységrendszer megjelenítésének javítása (Imperiális/Metrikus)

Változások 1.1.0.0:
- Új funkció: „Beállítások visszaállítása” gomb hozzáadása a beállítási menü aljához (billentyű: X)
- Felhasználói felület fejlesztések: Oldalsó leírások minden beállításhoz (tooltippek)
- Lokalizáció: Teljes fordítási támogatás 10 nyelven (EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU)
- Hibajavítások: A beállítási menü stabilitásának javítása

---

