# 🌾 Realistic Harvesting - Farming Simulator 25

[![Version](https://img.shields.io/badge/version-1.4.0.0-green.svg)](https://github.com/exekx/FS25_RealisticHarvesting)
[![FS25](https://img.shields.io/badge/FS25-Compatible-blue.svg)](https://www.farming-simulator.com/)
[![Multiplayer](https://img.shields.io/badge/Multiplayer-Supported-brightgreen.svg)](https://github.com/exekx/FS25_RealisticHarvesting)
[![License](https://img.shields.io/badge/License-All%20Rights%20Reserved-red.svg)](LICENSE)
[![Roadmap](https://img.shields.io/badge/📍-Roadmap-blue.svg)](ROADMAP.md)

> **Transform your harvesting experience with realistic combine physics and authentic crop management!**

---

## 📥 Download

**Original download link:** [kingmod.net by exekx](https://www.kingmods.net/en/fs25/mods/73932/realistic-harvesting)

> ⚠️ **Please do not re-upload or modify this link - support the original creator!**

---

## 🎯 What Does This Mod Do?

**Realistic Harvesting** simulates real-world combine harvester physics in Farming Simulator 25. Instead of harvesting at full speed regardless of crop density, your combine now responds to the volume of material entering the header. Heavy crops, wide headers, and steep hills will naturally limit your speed, just like in real life.

### Key Features

*   **⚡ Smart Speed Limiting**: Automatically adjusts your harvesting speed based on engine load.
*   **📊 Advanced Yield Monitor**: Real-time display of:
    *   **Productivity**: Tons per Hour (T/h)
    *   **Engine Load**: Live percentage with color-coded feedback
    *   **Yield Data**: Accurate yield tracking with realistic fluctuation
*   **🌾 Physical Crop Loss**: Overloading now reduces actual grain collected in bunker!
    *   Losses start at 95% engine load
    *   Progressive penalty - higher overload = exponentially more loss
    *   Difficulty settings control severity (Arcade/Normal/Realistic)
*   **🚜 Vehicle Support**:
    *   **Standard Combines**: Fully supported
    *   **Forage Harvesters**: Partial support
    *   **Cotton Harvesters**: Supported
    *   **Nexat System**: Specialized support for Nexat carrier and headers
*   **🌱 Crop-Specific Physics**: Different resistance values for various crop types (e.g., Wheat vs. Corn vs. Rice).
*   **🔧 Combine Calibration**: Manual control over Fan, Rotor, Sieves, and Feeder. Optimize settings for each crop to minimize losses!
*   **⚙️ Independent Control**: Option to start threshing and cutter separately (ideal for immersion and roleplay).
*   **⚙️ Global Settings**: Configurations are saved globally in `modSettings/`, persistent across all savegames.

---

## 🎮 Game Modes (Difficulty Settings)

You can customize the experience with **two independent difficulty settings** found in `ESC` -> `Settings` -> `Realistic Harvesting`. Mix and match to find your perfect balance!

### 🚜 Engine Power (Motor Difficulty)
Determines how much "power boost" your combine gets beyond its real-world specs.

| Mode | Boost | Capacity vs Real Life |
| :--- | :--- | :--- |
| **Arcade** | +100% | **200%** (Double capacity) |
| **Normal** | +20% | **120%** (Slightly boosted) |
| **Realistic** | +0% | **100%** (Real specs) |

### 🌾 Crop Loss (Loss Difficulty)
Determines how strictly the crop loss penalties are applied when overloading.

| Mode | Effect |
| :--- | :--- |
| **Arcade** | **50%** of standard loss penalties. |
| **Normal** | **Standard** loss penalties. |
| **Realistic** | **200%** loss penalties (Strict). |

---

## 📸 Screenshots

> **Gameplay Action**
>
> ![Gameplay Action](docs/images/gameplay.png)

> **HUD Explanation (Metric)**
>
> ![HUD Metric](docs/images/hud_metric.png)
>
> **HUD Explanation (Imperial)**
>
> ![HUD Imperial](docs/images/hud_imperial.png)
>
> **HUD Explanation (Bushels)**
>
> ![HUD Bushels](docs/images/hud_bushels.png)

> **Settings Menu**
>
> ![Settings Menu](docs/images/settings_menu.png)

> **Crop Loss Comparison - High Loss Scenario**
>
> ![High Crop Loss - Combine](docs/images/crop_loss_high_combine.png)
>
> *Combine showing high crop loss due to exceeding speed limits*
>
> ![High Crop Loss - Truck](docs/images/crop_loss_high_truck.png)
>
> *Reduced grain amount in truck after high losses*

> **Crop Loss Comparison - Optimal Harvesting**
>
> ![Low Crop Loss - Combine](docs/images/crop_loss_low_combine.png)
>
> *Combine within optimal speed range, minimal losses*
>
> ![Low Crop Loss - Truck](docs/images/crop_loss_low_truck.png)
>
> *Maximum grain collected when following recommended speed*

---

## 📟 The HUD

A modern, non-intrusive HUD appears when you enter a harvester.

### **Features:**
*   **Moveable**: Right-Click to enable cursor, then Left-Click drag the HUD anywhere on screen.
*   **Customizable**: Toggle individual elements (Yield, Load, Speed, Loss, T/h) in settings.
*   **Real-Time Data**:
    *   **Load Bar**: Visual representation of current engine strain.
    *   **T/h Display**: Monitor your harvesting throughput efficiency.
    *   **Yield**: Live yield data (t/ha or bu/ac).
    *   **Speed**: Current vs Recommended speed to prevent clogging.
    *   **Loss**: Visual indicator of crop loss (Low/Med/High).

    *   **Loss**: Visual indicator of crop loss (Low/Med/High).

---

## 🔧 Combine Calibration Guide

New in v1.4.0.0 is the interactive **Combine Calibration System**.

### How to Access
Press **Right Shift + K** while in a combine to open the Calibration Menu.

### Manual vs Auto
*   **Manual Mode (Default)**: You must adjust the Fan, Rotor, Upper Sieve, Lower Sieve, and Feeder House speed manually.
    *   New crops start at **50% efficiency** (neutral settings). This is safe but not optimal!
    *   You need to tweak values to match the crop type. Incorrect settings will increase **Crop Loss**.
*   **Auto Mode**: Automatically applies the perfect settings for the current crop.
    *   Enable by clicking the "AUTO" button in the menu.

### Crop Loss Penalties
*   The HUD now displays **Engine Load** and **Loss**.
*   **Loss** is affected by:
    1.  **Overloading**: Driving too fast (Engine Load > 95%).
    2.  **Bad Settings**: Incorrect calibration (deviation from optimal values).
*   High losses (RED) mean you are losing real grain! Slow down or improve your settings.

### Examples

> **Accurate Settings (Optimal)**
>
> ![GUI Accurate Settings](docs/images/gui_accurate.png)
>
> *Low loss, high efficiency.*

> **Inaccurate Settings (High Loss)**
>
> ![GUI Inaccurate Settings](docs/images/gui_inaccurate.png)
>
> *High loss due to poor calibration.*

---

## ️ Installation

1.  Download the latest version from [kingmod.net](https://www.kingmods.net/en/fs25/mods/73932/realistic-harvesting).
2.  Place the `FS25_RealisticHarvesting.zip` file into your `mods` folder.
    *   Usually: `Documents/My Games/FarmingSimulator2025/mods/`
3.  Activate the mod in the in-game Modhub menu.

---

## 🌐 Multiplayer

**Fully Multiplayer Compatible!**
*   Each player has their own local settings and HUD preferences.
*   Speed limiting is synchronized for smooth cooperative play.

---

## 🤝 Credits & Support

**Created by:** exekx

*   **Report Bugs:** [GitHub Issues](https://github.com/exekx/FS25_RealisticHarvesting/issues)
*   **Support:** [kingmod.net](https://www.kingmods.net/en/fs25/mods/73932/realistic-harvesting)

---

<div align="center">

**Made with ❤️ for the FS25 Community**

</div>
