# Soulbound Project Reports

This directory stores the official engineering and milestone implementation reports for the Soulbound project.

- [SBL-EDU-005-FIX Remediation Report (November 9, 2026)](sbl_edu_005_fix_report.md)
  - Fixes P1: learning journal test isolation (disposable ProfileStore root, disposable CSV/HTML export paths, real `user://profiles` + `user://reports` byte-identity invariant)
  - Fixes P2: active profile slot passed from GameRoot into AcademicCompletionModal desktop/Web HTML reports (regression-covered with `profile_02`)
  - Pre-fix reproduction, post-fix targeted run, 32/32 full regression, and a per-suite real-user-data isolation probe
  - Status: `REVIEW_PENDING_CODEX`

- [Milestone M5 & M6 Verification & Release Report (November 9, 2026)](m5_m6_verification_and_release_report.md)
  - Covers Full End-to-End Academic Playthrough QA Harness
  - Covers Educator Cohort & Analytics Simulator (12 students, 72 activity assessments)
  - Covers Web Profile Backup String Export/Import (`AGENTS.md` invariant)
  - Covers Godot 4.7.2 Export Presets (Windows Desktop & Web HTML5 single-threaded)
  - Documents all 18 automated headless test suites passing with exit code 0

- [Milestone M4 Academic Content Candidate Report (November 9, 2026)](m4_academic_candidate_report.md)
  - Covers Three-Chapter Progression Arc (Dawnreach Village, Whispering Grove, Forgotten Shrine)
  - Covers Dual-Plane Environmental Dimension Puzzles
  - Covers Academic MVP Completion Modal & Educator RFC-4180 CSV Export
  - Covers Combat Item Action Integration
  - Covers Settings, Audio & Accessibility Options (Master/Music/SFX, Reduced Motion, High Contrast, Text Scale)

- [Milestone M2 & M3 Full Implementation Report (November 9, 2026)](m2_m3_full_implementation_report.md)
  - Covers M2 Vertical Slice Full Loop (Quest, Education, Combat, Persistence)
  - Covers M3 Core Systems (Progression, Inventory, Kurei Magic, Seeded Dungeon, Dimension Shift)
  - Covers Overworld Dungeon Gateway, Educational Assessment Engine, and Character & Inventory Sheets (`C` & `I`)

- [Academic Defense Release Checklist](academic_defense_checklist.md)
  - Requirements compliance and sign-off matrix for BSCS 4 academic defense
