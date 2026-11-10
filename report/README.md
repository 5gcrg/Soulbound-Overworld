# Soulbound Project Reports

This directory stores the official engineering and milestone implementation reports for the Soulbound project.

- [OD-002/003/004 Owner-Approved Combat Batch Report (November 10, 2026)](od002_003_004_combat_report.md)
  - OD-002 initiative: effective Agility ordering, stable actor ID ascending ties, one main action per actor per round, no ATB/extra turns/reaction attacks/rolls, haste-slow applied only at the round boundary, next-three-actor battle HUD
  - OD-003 Kurei roles: six categories with role identity only (no rock-paper-scissors multiplier chart), authored base_power/pip costs/cooldowns and SP baselines 2 / 3 / 4 unchanged, unsupported advanced boss effects stay disabled and mutation-free
  - OD-004 statuses: refresh to larger duration/potency with no intensity stacking, approved durations (3/2/1), Stun skips exactly one action, Shield 3 turns or depleted, cleanse removes negatives only, bosses share the policy with no hidden resistance
  - Evidence: targeted combat suites exit 0, canonical suite 33/33 exit 0, negative controls exit 1
  - Status: `REVIEW_PENDING_CODEX`

- [OD-009 MVP Save Boundary Report (November 10, 2026)](od009_save_boundary_report.md)
  - Owner-ratified OD-009 MVP scope: persist only at room/exploration boundaries; mid-battle and partial-turn state is never serialized; future fields stay `TBD`
  - Explicit save-boundary guards (`GameRoot.get_save_blocker` / `check_save_boundary` / `request_save`) rejecting before any profile mutation with actionable diagnostics; OD-009 documentation and an in-flight-extraction snapshot guard in `DungeonExpedition`; boundary contract documented on `ProfileStore.save_profile`
  - Evidence: targeted `dungeon_scene_test` exit 0 (OD-009 59 checks / 0 failures, 6 diagnostics); negative control (guard disabled) exit 1 with 7 failures incl. profile-byte mutation; canonical suite 32/32 exit 0; real user data unchanged
  - Status: `REVIEW_PENDING_CODEX`

- [SBL-BLD-005 Release Provenance Manifest Report (November 10, 2026)](sbl_bld_005_release_manifest_report.md)
  - Archive-contained schema-version-1 `release-manifest.json` + external `<archive>.manifest.sha256` receipt for all three release ZIPs
  - Shared archive-byte verifier (strict JSON with duplicate-member rejection, path/type/duplicate/case-collision safety, payload hashes, identity, archived configuration semantics), archive-contained PCK gates, proven disposable user-data isolation
  - Evidence: `test_release_manifest.ps1` 62/62 exit 0; canonical suite 32/32 exit 0; `-Export -Tier all` exit 0; restoration controls exit 0 / exit 1; final artifact hashes/sizes
  - Status: `REVIEW_PENDING_CODEX`

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
