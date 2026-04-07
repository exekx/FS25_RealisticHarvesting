# Realistic Harvesting — Farming Simulator 25

[![Version](https://img.shields.io/badge/version-1.4.2.0-green?style=for-the-badge&logo=github)](https://github.com/exekx/FS25_RealisticHarvesting)
[![FS25](https://img.shields.io/badge/FS25-Compatible-blue?style=for-the-badge&logo=farming-simulator)](https://www.farming-simulator.com/)
[![Multiplayer](https://img.shields.io/badge/Multiplayer-Supported-brightgreen?style=for-the-badge&logo=users)](https://github.com/exekx/FS25_RealisticHarvesting)
[![License](https://img.shields.io/badge/License-All_Rights_Reserved-red?style=for-the-badge&logo=copyright)](LICENSE)
[![Roadmap](https://img.shields.io/badge/Roadmap-blue?style=for-the-badge&logo=map)](ROADMAP.md)
[![Discord](https://img.shields.io/discord/1479017497209471036?color=7289da&label=Discord&logo=discord&style=for-the-badge)](https://discord.gg/Dc2CvZJqU4)

> **Your combine now behaves like a real machine. Push it too hard — and you'll pay the price.**

---

## 📥 Download

**[kingmod.net by exekx](https://www.kingmods.net/en/fs25/mods/73932/realistic-harvesting)**

> Please do not re-upload or redistribute without permission.

---

## What Does This Mod Do?

In vanilla FS25, you can drive at full speed through any crop density with no consequences. **Realistic Harvesting** changes that.

Your combine now has a real engine load that responds to:
- **Crop density** and type (30+ crops with unique difficulty coefficients)
- **Header width** and engine horsepower
- **Terrain slope**
- **Calibration settings** (fan, rotor, sieves, feeder — unique per crop)
- **Pickup Header / Swathing** (detected automatically, 0.75x load multiplier)
- **Machine type** (grain combines, forage harvesters, root harvesters, cotton pickers)

Drive too fast → engine overloads → you lose grain. Simple.

![Gameplay Action](docs/images/gameplay.png)

---

## Quick Start — Your First 5 Minutes

**You don't need to do anything special to start.** The mod works automatically.

1. Enter your combine and start harvesting normally.
2. A **HUD panel** appears on screen with live data.
3. Watch the **Engine Load** bar — keep it below 100%.
4. If Load goes over 95%, **crop losses begin**. Slow down.
5. The mod will automatically suggest a safe speed.

That's it for the basics. Everything else is optional depth.

---

## The HUD — Reading Your Data

The HUD appears automatically when you enter a combine. Right-click to enable cursor and drag it anywhere on screen.

![HUD Metric](docs/images/hud_metric.png)
![HUD Imperial](docs/images/hud_imperial.png)
![HUD Bushels](docs/images/hud_bushels.png)

| Indicator | What It Means |
|:---|:---|
| **Engine Load %** | How hard your combine is working. Stay below 95%. |
| **T/h or L/h** | Tons (or liters) per hour — your harvesting productivity. |
| **Yield** | Live t/ha or bu/ac. Fluctuates naturally with field density. |
| **Speed / Rec.** | Your speed vs. the recommended safe speed. |
| **Loss** | LOW / MED / HIGH — how much grain you're losing right now. |

**Color code:** Green = good, Yellow = caution, Red = losing grain.

Each metric can be individually shown or hidden. Switch between Metric (t/ha, km/h), Imperial (bu/ac, mph), and Bushel display units in ESC → Settings → Realistic Harvesting. HUD position is saved per-player.

---

## Crop Loss — How It Works

Losses happen from two independent sources:

### 1. Overloading (Speed)
- Engine Load > 95% → losses begin
- The faster you push past the limit, the more grain you lose
- Slow down, use a narrower header, or choose a more powerful combine

![High Crop Loss - Combine](docs/images/crop_loss_high_combine.png)
*High losses — combine going too fast*

![Low Crop Loss - Combine](docs/images/crop_loss_low_combine.png)
*Optimal speed — minimal losses*

### 2. Poor Calibration (Settings)
If your combine's settings are incorrect for the current crop, you'll incur a calibration penalty on top of speed losses.

Each machine type now has **unique controls** — different parameters appear depending on whether you're driving a grain combine, forage harvester, root harvester, or cotton picker.

> **Preview Loss** in the Calibration Menu shows the estimated penalty from your current settings — even when you're not harvesting!

### Calibration Physics — Two Distinct Mechanics

**1. Efficiency (Speed) — Rotor & Feeder House**
These components pull crop into the machine and thresh it. Poor configuration makes the engine struggle, cruise control forces slower driving. Perfect settings grant up to a **+5.0% Speed Bonus**.

**2. Crop Loss (Wasted Grain) — Fan & Sieves**
These components separate grain from chaff. If the fan is too strong or sieves are badly adjusted, clean grain gets blown out the back. Perfect settings ensure **0% Added Crop Loss**.

> **Overload Shield:** Perfect Efficiency settings also grant a protective shield that absorbs minor crop density spikes — preventing accidental crop losses when you're driving near the limit.

---

## Difficulty Settings

Open: **ESC → Settings → Realistic Harvesting**

![Settings Menu](docs/images/settings_menu.png)

### Engine Power
| Mode | Capacity | Description |
|:---|:---:|:---|
| Arcade | 200% | Very forgiving — almost impossible to overload |
| Normal | 120% | Slight boost — default for casual play |
| Realistic | 100% | Real machine specs — requires skill |

### Crop Loss Severity
| Mode | Penalty | Description |
|:---|:---:|:---|
| Arcade | 50% | Half the standard penalty |
| Normal | 100% | Standard |
| Realistic | 200% | Very strict — even minor overload = heavy losses |

### Additional Toggles
| Setting | Description |
|:---|:---|
| **Speed Limiter** (ON/OFF) | Automatically reduces speed when engine load is too high |
| **Crop Loss System** (ON/OFF) | Enables or disables grain loss simulation entirely |
| **Independent Launch** | Allows starting thresher without lowering the header first |

**Multiplayer:** Server settings (difficulty, speed limit, crop loss) are shared for all players and can only be changed by the admin. Client settings (HUD, units, position) are personal per-player. All settings persist across save games.

---

## RHM Electronics — Upgrade Packages

When buying or modifying a combine, you can choose an **RHM Electronics** tier in the shop configuration menu:

| Tier | Name | Price | Features |
|:---|:---|:---:|:---|
| 1 | **Standard** | Free | Basic engine load and speed limiting |
| 2 | **Sensor Kit** | $3,500 | Unlocks live Yield (t/ha) and Productivity (t/h) readouts on HUD |
| 3 | **Yield & Loss Monitor** | $8,500 | Full real-time Crop Loss indicator + color-coded warnings |
| 4 | **Opti-Harvest AI** | $15,000 | Autonomous calibration system — auto-detects crop and sets optimal parameters for 0% loss |

> Tier 4 is the ultimate upgrade: plug-and-play zero-loss harvesting. Let the AI handle calibration while you focus on driving.

---

## Combine Calibration (Advanced)

Press **Right Shift + K** while in a combine to open the Calibration Menu.

![GUI Accurate Settings](docs/images/gui_accurate.png)
*Well-calibrated — low loss, high efficiency*

![GUI Inaccurate Settings](docs/images/gui_inaccurate.png)
*Poorly calibrated — high loss penalty*

### AUTO vs MANUAL

| | AUTO | MANUAL |
|:---|:---|:---|
| How it works | Sets near-optimal values automatically | You adjust everything yourself |
| Accuracy | Good starting point, intentionally imperfect | Can be perfect — if you know what you're doing |
| Loss penalty | Small (AUTO isn't perfect) | Zero or better — if tuned correctly |

> AUTO is convenient. MANUAL rewards the skilled operator with up to **+2.5% efficiency bonus**.

---

## Supported Machine Types

### 🌾 Grain Combines — 5 Parameters
*(Fan Speed · Rotor Speed · Upper Sieve · Lower Sieve · Concave Clearance)*

Organized into sections:
- **SEPARATION** (Rotor, Concave) — affects throughput efficiency  
- **CLEANING** (Fan, Upper Sieve, Lower Sieve) — affects grain loss
- **PERFORMANCE** (Concave Clearance) — affects overall speed

| Crop | Fan Speed (RPM) | Rotor Speed (RPM) | Upper Sieve (mm) | Lower Sieve (mm) | Concave Clearance (mm) |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Wheat / Barley** | 940–1070 | 870–970 | 15–18 | 10–13 | 4–8 |
| **Oat** | 940–1070 | 820–930 | 18–21 | 12–15 | 5–9 |
| **Corn (Maize)** | 1070–1180 | 470–560 | 21–24 | 15–18 | 25–35 |
| **Soybean / Pea / Legumes** | 910–1040 | 640–750 | 15–18 | 10–13 | 15–21 |
| **Canola (Rapeseed)** | 880–980 | 600–700 | 14–16 | 9–11 | 18–22 |
| **Sunflower** | 870–990 | 440–530 | 19–23 | 14–17 | 25–35 |
| **Rice** | 960–1080 | 910–1020 | 19–23 | 16–19 | 4–8 |
| **Sorghum** | 940–1070 | 720–830 | 15–18 | 11–14 | 4–8 |
| **Lentil** | 960–1080 | 520–610 | 18–21 | 12–15 | 15–21 |
| **Chickpea** | 1080–1230 | 520–610 | 21–24 | 14–16 | 15–21 |

---

### 🌿 Forage Harvesters — 3 Parameters
*(Blower Speed · Chopping Drum · Feed Rolls)*

| Crop | Blower Speed (RPM) | Chopping Drum (RPM) | Feed Rolls (RPM) |
|:---|:---:|:---:|:---:|
| **Grass / Dry Grass** | 1150–1290 | 1110–1150 | 380–460 |
| **Corn Silage (CHAFF)** | 1220–1360 | 1140–1180 | 440–520 |

---

### 🥔 Root & Vegetable Harvesters — 3 Parameters
*(Fan Speed · Cleaning Rollers · Elevator Web)*

| Crop | Fan Speed (optimal) | Cleaning Rollers (optimal) | Elevator Web (optimal) | Notes |
|:---|:---:|:---:|:---:|:---|
| **Potato** | **610 RPM** | **200 RPM** | **310 RPM** | Gentle roller to prevent bruises |
| **Sugarbeet** | **640 RPM** | **240 RPM** | **300 RPM** | Harder than potato, faster cleaning |
| **Beetroot** | **630 RPM** | **220 RPM** | **300 RPM** | Between potato and sugarbeet |
| **Onion** | **850 RPM** ⬆️ | **210 RPM** | **270 RPM** | Strong airflow to separate skins/leaves |
| **Carrot / Parsnip** | **580 RPM** | **190 RPM** | **330 RPM** ⬆️ | Very gentle, fast feeder to lift weight |
| **Spinach** | **520 RPM** ⬇️ | **160 RPM** ⬇️ | **280 RPM** | Minimal air — leaves fly and tear easily |
| **Green Bean** | **670 RPM** | **200 RPM** | **290 RPM** | Moderate; pods crack easily |

**Tolerance zone:** ±5–8% from the optimal value shown above.

---

### 🪡 Cotton Pickers — 3 Parameters
*(Fan Speed · Picker Speed · Feeder Speed)*

| Parameter | Optimal | Zero Loss Zone |
|:---|:---:|:---:|
| **Fan Speed (RPM)** | 3250 | 3100–3400 |
| **Picker Speed (RPM)** | 210 | 200–220 |
| **Feeder House (RPM)** | 190 | 170–210 |

---

## Engine Load Physics

Engine load is calculated based on **engine horsepower** and **crop difficulty**:

| Machine Type | Base Coefficient | Example |
|:---|:---:|:---|
| Grain Combines | 0.035 kg/s per HP | 500 HP → 17.5 kg/s base throughput |
| Forage Harvesters | 0.051 kg/s per HP | 950 HP → ~400 t/hr corn silage |
| Root/Vegetable Harvesters | 0.060–0.080 kg/s per HP | Higher capacity for heavy root crops |
| Cotton Pickers | 0.015 kg/s per HP | Lower capacity — cotton is light |

Each crop has a unique **difficulty coefficient** (e.g., Wheat = 0.814, Cotton = 4.782, Spinach = 2.880) that modifies how much load the crop puts on the engine. Heavier/denser crops fill the machine faster.

**NEXAT modular harvesters** are fully supported — the mod searches the vehicle hierarchy to find the correct engine power.

---

## Frequently Asked Questions

**Q: My combine is slowing down by itself. Is that normal?**
Yes. The mod automatically limits speed when engine load is too high. This prevents grain loss. You can override it by pressing accelerator harder, but losses will increase.

**Q: I just installed the mod and my settings are all at 50%. Is that bad?**
That's normal — the mod starts at 50% by default until it detects which crop you're harvesting. Once you start harvesting, AUTO mode automatically adjusts settings to near-optimal values for that crop. It's not always perfect though, so there may still be small losses. For zero loss, tune manually using the reference table above.

**Q: Does AUTO mode fully optimize for me?**
No. AUTO is intentionally imperfect. A skilled manual operator can outperform AUTO.

**Q: I lost a lot of grain. How do I prevent it?**
Two main causes: (1) driving too fast — watch the Load bar, (2) wrong calibration — open RShift+K and check your settings for the current crop.

**Q: Does this work in Multiplayer?**
Yes. Speed limiting syncs across all players. Each player has their own HUD settings. Server-side settings (difficulty, crop loss) are managed by the admin.

**Q: What are RHM Packages?**
These are electronic upgrade tiers you select when buying/modifying a combine. They unlock additional HUD metrics and features, from basic monitoring to full AI-assisted zero-loss harvesting.

**Q: How do I open the Calibration Menu?**
Press **Right Shift + K** while seated in a combine.

---

## Installation

1. Download from [kingmod.net](https://www.kingmods.net/en/fs25/mods/73932/realistic-harvesting)
2. Place `FS25_RealisticHarvesting.zip` into your `mods` folder
   - Usually: `Documents/My Games/FarmingSimulator2025/mods/`
3. Activate in the in-game Modhub

---

## Credits & Support

**Created by:** exekx

- **Bugs:** [GitHub Issues](https://github.com/exekx/FS25_RealisticHarvesting/issues)
- **Download:** [kingmod.net](https://www.kingmods.net/en/fs25/mods/73932/realistic-harvesting)


<div align="center">

**Made with ❤️ for the FS25 Community**

</div>
