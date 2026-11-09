# Soulbound — Academic Defense Presentation & Demonstration Guide

This guide provides the presentation script and testing procedures for the **Soulbound: Educational 2D Turn-Based Roguelite RPG** academic defense.

---

## 1. System Specifications & Engineering Invariants

| Attribute | Specification |
|---|---|
| **Engine Version** | Godot 4.7.2 Stable (Official build `ed1daf0bf`) |
| **Rendering Backend** | Compatibility (`gl_compatibility`) for Windows & Web portability |
| **Web Runtime** | Single-threaded WebAssembly + WebGL 2.0 (Variant `web_nothreads_release.zip`) |
| **Package Sizes** | Web distribution: **10.5 MB** (< 50 MB threshold) \| Windows portable: **86.4 MB** |
| **Headless Verification** | **21 automated test suites** passing with 0 errors |
| **Save Architecture** | Atomic multi-revision envelope persistence (`user://profiles/profile_XX`) |
| **Educational Engine** | Completion-gated progression, immutable first-attempt tracking, RFC-4180 CSV exports |

---

## 2. Five-Minute Live Defense Demonstration Script

### Step 1: Launch & Title Screen
1. Run `Soulbound.exe` (or serve `builds/web/index.html` via local HTTP server).
2. The **Title Screen** will display:
   - Click **"Continue Journey (profile_01)"** or **"[🎓 Academic Defense Quick-Start]"**.
   - Note: The Quick-Start button instantly populates Chapter 3 access, sets Ren to Level 10, equips iron gear, and activates the Sanctum for instant demonstration.

### Step 2: Overworld Exploration & Dimensional Phase Shift (GDD-001/002)
1. Use **WASD** or **Arrow Keys** to move Ren across the overworld.
2. Approach the physical obstacle (bramble wall / fissure in Whispering Grove / Ashen Peaks).
3. Press **Q** (or click **Shift Dimension** in Evaluator Tools):
   - Notice the visual shift into the **Spirit Dimension**.
   - Physical colliders dissolve, allowing Ren to walk freely through the phase barrier.
   - An ethereal procedural sweep audio cue confirms the shift.

### Step 3: Turn-Based Combat & Kurei Resonance Arts (GDD-016/018/022)
1. Walk into the encounter marker (or press **F1** $\rightarrow$ **Trigger Combat**):
   - Notice the enemy's opening intent indicator (e.g. **Strike**).
   - Press **Defend**: mitigates incoming damage and generates defense feedback.
   - Click **Kurei Arts** $\rightarrow$ select **Flame Burst**: deals 2 damage and inflicts **Burn** status via the `StatusEngine`.
   - Click **Use Item**: validates inventory ownership, consumes a `spirit_salve` from the bank, and restores 1 Ren pip (enforcing maximum health caps).

### Step 4: Modular Procedural Dungeon & Suspend/Resume Invariant (GDD-031..035)
1. Step into the **Expedition Gateway** in the overworld (or press **F1** $\rightarrow$ **Start Dungeon**):
   - Traverse through modular chambers (Loot, Combat, Rest).
   - Click **Suspend Expedition**:
     - *Key Invariant*: Suspending **does not count as extraction** and does not duplicate rewards or wipe the satchel.
     - Ren returns to the overworld with the dungeon state serialized.
   - Step back into the gateway: the expedition seamlessly resumes at the exact chamber step!
   - Reach the extraction point: satchel rewards transfer to the permanent town bank exactly once.

### Step 5: Educational Assessment & RFC-4180 CSV Export (GDD-067..072)
1. Approach a Chapter Spirit Guide (or press **F1** $\rightarrow$ **Chapter Question**):
   - Answer the competency question (e.g. Critical Thinking or Decision Making).
   - *Key Invariant*: Demonstrates **completion-gated progression** (advancement is unlocked by finishing the activity, while first-attempt correctness is recorded immutably for educator assessment).
2. Step into the **Academic MVP Sanctum** portal:
   - The **Academic Completion Modal** appears displaying total attempts, first-attempt accuracy, and regional clearance.
   - Click **Export Educator Analytics (CSV)**:
     - On Windows: exports to `user://reports/educational_assessment_report.csv`.
     - On Web: triggers browser download via `JavaScriptBridge.download_buffer()`.

### Step 6: Settings & Evaluator Defense Tools
1. Press **Escape** or **O** to open the **Settings Sheet**:
   - Volume sliders update `AudioServer` buses in real time.
   - High-contrast mode and text scaling assist accessibility.
   - Web save backup allows one-click export/import of profile JSON.
2. Press **F1** or **\`** to open the **Evaluator Defense Bar**:
   - Warp instantly to Chapter 1 (Dawnreach), Chapter 2 (Whispering Grove), Chapter 3 (Forgotten Shrine), or Chapter 4 (Ashen Peaks).
   - Click **Title Screen** to return to the main menu at any time.

---

## 3. Automated Release Build Command

To generate fresh release packages for the presentation:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build/export_release.ps1
```
This produces:
- `dist/Soulbound-Web.zip` (for web deployment)
- `dist/Soulbound-Windows-Portable.zip` (for standalone Windows presentation)
