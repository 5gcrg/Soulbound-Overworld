# Soulbound — Evaluator Walkthrough & User Guide

**Project Title**: Soulbound — E-Learning-Based 2D Turn-Based Roguelite RPG  
**Course / Level**: BSCS 4 — 2D Game Development  
**Authors**: Radzgie V. Custodio; Jeferson G. Galaraga  
**Engine**: Godot 4.7.2 Stable (official build `ed1daf0bf`), GL Compatibility Renderer  
**Target Delivery**: Windows Portable ZIP & Itch.io Web Build (Single-Threaded Compatibility)

---

## 1. Executive Overview

*Soulbound* is an educational 2D role-playing game featuring Ren, a spirit warrior journeying through overlapping physical and spiritual dimensions. The game integrates 8-direction top-down exploration, side-view turn-based tactical combat, six categories of Kurei magic, repeatable procedural modular roguelite dungeons, and senior high school competency-based learning activities.

---

## 2. Controls & Hotkey Reference

| Input Key | Action / Function |
|---|---|
| `W` / `A` / `S` / `D` or Arrows | 8-direction character movement in overworld |
| `Q` | **Dimension Shift**: Toggles between Physical and Spirit dimensions |
| `C` | **Character Sheet**: Opens level, stats, and attribute allocation panel |
| `I` | **Inventory Sheet**: Opens Town Bank (secured), Satchel (at-risk), and Gear slots |
| `O` | **Settings & Options**: Volume sliders, accessibility options, and Web profile backup |
| `Space` / `Enter` | Interact with prompts, select menu buttons, confirm choices |
| `Esc` | Close open UI sheets or step back from active dialogs |

---

## 3. Step-by-Step Evaluator Walkthrough (Chapters I–III)

### Chapter I: Dawnreach Village
1. **Starting Point**: Ren awakens in Dawnreach Village near the central village well.
2. **Guidance NPC**: Approach **Elder Kael** at `(300, 180)`. Step into the interaction zone to begin the introductory dialogue.
3. **Educational Activity (Decision-Making)**:
   - Elder Kael presents scenario `q_dec_01`: *"Your satchel holds 3 rare relics. Ren has 15% HP... What choice minimizes total risk?"*
   - Selecting the sub-optimal answer triggers an instructional explanation and immutably records `first_attempt_correct = false`.
   - Selecting the correct answer completes the activity. Chapter I unblocks Chapter II via the **completion-gated** progression rule.
4. **Transition**: Walk east to the portal labeled `To Whispering Grove ->` at `(870, 270)`.

### Chapter II: Whispering Grove & Dimension Shift Puzzle
1. **Corrupted Forest**: Ren enters Whispering Grove and meets **Scout Lyra** at `(280, 180)`.
2. **Environmental Puzzle**:
   - The path east is obstructed by **Physical Brambles** (`Obstacles/PhysicalBrambleWall`), blocking physical movement.
   - Press **`Q` (Dimension Shift)** to transition into the **Spirit Dimension**.
   - Notice the physical brambles dissolve and the ethereal Spirit Bridge illuminates.
   - Ren passes freely through the obstacle while in the Spirit plane.
3. **Educational Activity (Resource Management)**:
   - Complete scenario `q_res_01` concerning action pip allocation and lethal damage mitigation.
   - Chapter II unblocks Chapter III upon completion.
4. **Transition**: Walk east to the portal labeled `To Forgotten Shrine ->` at `(870, 270)`.

### Chapter III: Forgotten Shrine & Academic Completion
1. **Sanctum of Awakening**: Ren reaches the ancient Forgotten Shrine sanctum.
2. **Educational Activity (Critical Thinking)**:
   - Approach the **Altar of Awakening** at `(480, 240)` to evaluate scenario `q_crit_02` (analyzing conflicting observational scout reports).
   - Completing the question satisfies the final learning requirement of the 3-chapter Academic MVP.
3. **Academic Completion Portal**:
   - Step into the glowing portal labeled **Academic MVP Sanctum** at `(780, 270)`.
   - The full-screen **Academic Completion Modal** appears, detailing Ren's level, attributes, secured bank items, and competency scores.
   - Click **[Export Educator CSV]** to write an RFC-4180 compliant report to `user://reports/soulbound_academic_mvp_report.csv`.
   - Click **[Continue Free Exploration]** to freely navigate between all unlocked regions and dungeons.

---

## 4. Roguelite Modular Dungeon Expeditions

1. **Gateway**: In `test_region_alpha`, walk east to the **Expedition Gateway** at `(650, 180)`.
2. **Chamber Navigation**:
   - The interactive modal displays procedural room breadcrumbs (`Start -> Normal -> Elite -> Extraction`).
   - Click **[Advance]** to traverse chambers. Each normal chamber awards at-risk loot (`ancient_relic_fragment`) into Ren's expedition satchel.
3. **Extraction Guarantee & Defeat Invariant**:
   - Reaching the final chamber activates the **[Extract]** button.
   - Clicking **[Extract]** secures all satchel loot into the permanent **Town Bank** and safely returns Ren to overworld coordinates `(600, 220)`.
   - Clicking **[Retreat]** or suffering defeat wipes the satchel completely, while secured town bank items and character XP remain 100% intact.

---

## 5. Turn-Based Tactical Combat System

1. **Trigger**: Walk into the **Combat test** marker at `(600, 360)` in Alpha.
2. **Side-View Turn Economy**:
   - **Attack** (1 Pip): Deals physical damage to the adversary.
   - **Defend** (1 Pip): Grants Guard status, halving incoming enemy strike damage.
   - **Kurei Magic**: Opens elemental spell submenu:
     - *Lumina Lance* (1 Pip, 1 SP): Pierces armor with holy energy.
     - *Flame Burst* (2 Pips, 2 SP): Deals decisive fire damage.
   - **Item (Salve)** (1 Pip): Restores 1 HP to Ren during crucial moments.
3. **Initiative & Telegraphing**:
   - Enemy telegraphs intent above their head (`Strike [Deals 2 Damage]` or `Recover [Exposed]`).
   - Defend on Strike turns, and unleash offensive skills during Recover turns.

---

## 6. Accessibility & Web Profile Backup

1. Press **`O`** to open the **Audio & Accessibility Settings Sheet**.
2. **Audio Sliders**: Adjust Master, Music, and SFX volumes with live linear-to-dB bus mapping.
3. **Accessibility**:
   - Toggle **Reduced Motion** to suppress camera shakes.
   - Toggle **High Contrast Mode** to enhance text legibility.
   - Adjust **Text Scale** between 80% and 150%.
4. **Web Profile Backup (`AGENTS.md` Invariant)**:
   - Click **[Export Backup String]** to copy an encrypted/versioned JSON profile string.
   - Click **[Import Backup String]** to load a saved profile string in browser/web environments without filesystem access.
