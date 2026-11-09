# ⚔️ Kingdom Come: Deliverance — Bohemia 1403

> *"Jesus Christ be praised! Henry's come to see us!"*

An authentic, historically grounded medieval adventure & directional combat game inspired by Warhorse Studios' **Kingdom Come: Deliverance**, featuring:
1. **A Complete Godot 4 Game** (`godot_game/`): Playable in Godot Engine 4.x with 5-point directional swordplay, Cuman AI, lockpicking minigame, blacksmith grindstone sharpening, inventory, and procedural sound synthesis.
2. **An Illuminated Medieval Landing Page** (`index.html` + `assets/`): Featuring an in-browser live canvas duel simulator, live lockpicking simulator, procedural lute/campfire Web Audio, and historical codex of 1403 Bohemia.

---

## 🛡️ Repository Structure

```
kindom_come_delivernce/
├── index.html                   # Medieval Landing Page with live interactive canvas duel & lockpicking
├── assets/
│   ├── css/
│   │   └── style.css            # Illuminated manuscript parchment styling & gold filigree
│   └── js/
│       ├── medieval_audio.js    # Web Audio API procedural lute, campfire & sword clashes
│       ├── combat_sim.js        # Browser HTML5 Canvas 5-Point Directional Combat Simulator
│       ├── lockpick_sim.js      # Browser HTML5 Canvas Lockpicking Minigame
│       └── main.js              # Codex tabs, particles & UI interaction
└── godot_game/                  # Full Godot Engine 4.x Project
    ├── project.godot            # Godot 4.x configuration & GL Compatibility renderer
    ├── icon.svg                 # Bohemian crossed swords & Skalitz seal
    ├── export_presets.cfg       # Ready-to-use export presets (Web, Mac, Windows, Linux)
    ├── scenes/
    │   ├── main_menu.tscn       # Medieval main menu with animated embers
    │   ├── world.tscn           # Skalitz courtyard skirmish arena
    │   ├── player.tscn          # Henry of Skalitz CharacterBody2D
    │   ├── enemy.tscn           # Cuman Raider CharacterBody2D with AI
    │   ├── combat_reticle.tscn  # 5-pointed combat star rose
    │   ├── lockpick.tscn        # Authentic KCD lockpicking minigame
    │   ├── grindstone.tscn      # Blacksmith sharpening wheel minigame
    │   └── ui.tscn              # Parchment HUD, health/stamina/hunger, inventory
    └── scripts/
        ├── sound_manager.gd     # 16-bit PCM procedural sound generator
        ├── player.gd            # Directional slashes, thrusts, stamina, blocks, ripostes
        ├── enemy.gd             # Guard matching AI, telegraph windups, taunts
        ├── combat_reticle.gd    # Dynamic reticle drawing with green shield flash
        ├── lockpick.gd          # Sweet spot detection, shearline cylinder rotation
        ├── grindstone.gd        # Wheel speed treadle, blade angle, spark particles
        ├── ui.gd                # Health, stamina, hunger ("I feel quite hungry"), satchel
        ├── world.gd             # Arena manager, waves, courtyard rendering
        └── main_menu.gd         # Menu navigation & sound integration
```

---

## 🎮 How to Play the Godot 4 Game

### 1. Launch from Terminal:
```bash
godot --path /Users/danilavier/kindom_come_delivernce/godot_game
```

### 2. Open in Godot 4 Editor:
```bash
godot -e --path /Users/danilavier/kindom_come_delivernce/godot_game
```

### In-Game Controls:
| Action | Key / Input |
|---|---|
| **Move Henry** | `W`, `A`, `S`, `D` or Arrow Keys |
| **Sprint** | `Shift` (drains Stamina) |
| **Aim 5-Directional Rose** | Move Mouse relative to character |
| **Slash** | `Left Mouse Button` |
| **Thrust (Center)** | `Middle Mouse Button` or `F` |
| **Block / Parry** | `Right Mouse Button` or `Space` |
| **Master Strike (Riposte)** | Block during the Green Shield flash! |
| **Blacksmith Grindstone** | `E` |
| **Rattay Lockpicking** | `L` |
| **Drink Savior Schnapps / Eat** | `H` |
| **Open Satchel Inventory** | `I` |

---

## 🌐 The Medieval Landing Page

Open `index.html` in any modern web browser or serve it with:
```bash
npx serve /Users/danilavier/kindom_come_delivernce
```

### Features on the Web Page:
- **Playable 5-Point Directional Combat Canvas**: Test your timing and directional angles directly against a Cuman raider in your browser.
- **Playable Rattay Lockpicking Canvas**: Use your mouse to locate the golden sun sweet spot, then hold `D` to rotate the cylinder.
- **Live Procedural Web Audio**: Click *"Play Medieval Ambience"* in the top right to hear crackling tavern fires and authentic medieval lute arpeggios in D-dorian mode.
- **Historical 1403 Codex**: Interactive encyclopedia detailing the Captivity of King Wenceslas IV, Sigismund's invasion, Johannes Liechtenauer's 5 Master Cuts (*Zornhau, Krumphau, Zwerchhau, Schielhau, Scheitelhau*), and Savior Schnapps brewing instructions.

---

## 📜 Historical Background

> *"Bohemia – located in the heart of Europe, the region is rich in culture, silver, and sprawling castles. The death of its beloved Emperor, Charles IV, has plunged the kingdom into dark times. King Wenceslas has inherited the throne, but his half-brother Sigismund, King of Hungary, has imprisoned him and invaded the country with an army of Cuman mercenaries..."*

---

## ⚖️ License
MIT License. Inspired by Warhorse Studios' *Kingdom Come: Deliverance*.
Developed for **TrillionaireViier**.
