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
- Crop density and type
- Header width
- Terrain slope
- Calibration settings

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
| **T/h** | Tons per hour — your harvesting productivity. |
| **Yield** | Live t/ha or bu/ac. Fluctuates naturally. |
| **Speed / Rec.** | Your speed vs. the recommended safe speed. |
| **Loss** | LOW / MED / HIGH — how much grain you're losing right now. |

**Color code:** Green = good, Yellow = caution, Red = losing grain.

---

## Crop Loss — How It Works

Losses happen from two sources:

### 1. Overloading (Speed)
- Engine Load > 95% → losses begin
- The faster you push past the limit, the more grain you lose
- Slow down or switch to a narrower header

![High Crop Loss - Combine](docs/images/crop_loss_high_combine.png)
*High losses — combine going too fast*

![High Crop Loss - Truck](docs/images/crop_loss_high_truck.png)
*Less grain in the trailer as a result*

![Low Crop Loss - Combine](docs/images/crop_loss_low_combine.png)
*Optimal speed — minimal losses*

![Low Crop Loss - Truck](docs/images/crop_loss_low_truck.png)
*Full trailer when harvesting correctly*

### 2. Poor Calibration (Settings)
If your combine's settings are incorrect for the current crop, you'll incur a calibration penalty on top of speed losses.

Each machine type now has **unique controls** — different parameters appear depending on whether you're driving a grain combine, forage harvester, root harvester, or cotton picker.

> **Preview Loss** in the Calibration Menu shows the estimated penalty from your current settings — even when you're not harvesting!

New saves start at **neutral settings (50%)** — safe, but not optimal.

---

## Difficulty Settings

Open: **ESC → Settings → Realistic Harvesting**

![Settings Menu](docs/images/settings_menu.png)

### Engine Power
| Mode | Capacity |
|:---|:---:|
| Arcade | 200% — very forgiving |
| Normal | 120% — slight boost |
| Realistic | 100% — real machine specs |

### Crop Loss Severity
| Mode | Penalty |
|:---|:---:|
| Arcade | 50% of standard |
| Normal | Standard |
| Realistic | 200% — very strict |

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

### How Calibration Affects Loss

The calibration system uses a **continuous curve** for each parameter:

| Position | Effect |
|:---|:---:|
| Exactly at Sweet Spot | +2.5% efficiency bonus |
| Zero Loss zone | 0% |
| Edge of tolerance | −2.5% penalty |
| Beyond tolerance | Increasing penalty |

> All 5 parameters are interconnected — you can't ignore 4 and fix 1.

---

---

## Calibration Settings Reference — Zero Loss Zones

The **Zero Loss Zone** is the range where settings contribute 0% penalty. Values outside this range start adding crop loss.

Open the Calibration GUI with **RShift+K**. Use **< >** buttons to switch crops manually — the GUI shows a **Preview Loss %** even without harvesting.

---

### 🌾 Grain Combines — 5 Parameters
*(Fan Speed · Rotor Speed · Upper Sieve · Lower Sieve · Feeder House)*

| Crop | Fan | Rotor | Upper Sieve | Lower Sieve | Feeder |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Wheat / Barley** | 58–72 | 69–81 | 54–66 | 64–76 | 40–60 |
| **Oat** | 63–77 | 74–86 | 59–71 | 69–81 | 45–65 |
| **Corn (Maize)** | 79–91 | 85–95 | 74–86 | 79–91 | 60–80 |
| **Soybean / Pea / Legumes** | 43–57 | 48–62 | 44–56 | 54–66 | 27–43 |
| **Canola (Rapeseed)** | 39–51 | 54–66 | 36–44 | 46–54 | 32–48 |
| **Sunflower** | 48–62 | 59–71 | 64–76 | 74–86 | 50–70 |
| **Rice** | 73–87 | 79–91 | 64–76 | 64–76 | 48–72 |
| **Sorghum** | 58–72 | 69–81 | 54–66 | 64–76 | 40–60 |

---

### 🌿 Forage Harvesters — 3 Parameters
*(Fan Speed · Drum Speed · Feeder House)*

| Crop | Fan | Drum | Feeder |
|:---|:---:|:---:|:---:|
| **Grass / Dry Grass** | 50–70 | 55–75 | 45–65 |
| **Corn Silage (CHAFF)** | 60–80 | 70–90 | 60–80 |

---

### 🥔 Root & Vegetable Harvesters — 3 Parameters
*(Fan Speed · Roller Speed · Feeder House)*

> Each crop has **unique optimal values** — check the Calibration Menu when switching crops!

| Crop | Fan (optimal) | Roller (optimal) | Feeder (optimal) | Notes |
|:---|:---:|:---:|:---:|:---|
| **Potato** | **35%** | **40%** | **70%** | Low air (soil doesn't blow), gentle roller (potato bruises easily) |
| **Sugarbeet** | **40%** | **55%** | **65%** | Harder than potato, faster roller ok |
| **Beetroot** | **38%** | **48%** | **68%** | Between potato and sugarbeet |
| **Onion** | **75%** ⬆️ | **45%** | **55%** | Strong airflow needed to separate skins and leaves |
| **Carrot / Parsnip** | **30%** | **35%** | **75%** ⬆️ | Very gentle — fragile root, fast feeder to lift |
| **Spinach** | **20%** ⬇️ | **25%** ⬇️ | **60%** | Minimal settings — leaves fly and tear easily |
| **Green Bean** | **45%** | **38%** | **62%** | Moderate, careful — pods crack |

**Tolerance zone:** ±5–8% from the optimal value shown above.

---

### 🪡 Cotton Pickers — 3 Parameters
*(Fan Speed · Picker Speed · Feeder House)*

| Parameter | Optimal | Zero Loss Zone |
|:---|:---:|:---:|
| **Fan Speed** | 50% | 40–60 |
| **Picker Speed** | 55% | 45–65 |
| **Feeder House** | 45% | 35–55 |

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
Yes. Speed limiting syncs across all players. Each player has their own HUD settings.

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
