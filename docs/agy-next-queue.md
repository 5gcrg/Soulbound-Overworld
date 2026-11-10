# Next Work Queue — Approved OD-010/OD-011 Narrative and Dungeon Batch

Executor: `opencode-go/mimo-v2.6-flash`. Codex CLI review deferred.

## Approved specifications

### OD-010 narrative/quests

- Branch locally and reconverge at approved chapter beats.
- Academic MVP remains linear across Chapters I–III.
- Full-release structure may support one local choice cluster per chapter, reconverging at the next chapter gate.
- Reputation/faction systems remain deferred from the academic MVP.
- Do not invent Ren's origin, villain identity, permanent lore reveal, ending trigger, faction roster, or dialogue content.

### OD-011 dungeons

- Academic MVP retains the seeded 4-room DAG and guaranteed extraction.
- Full-release proposal: 3 floors, 6 generated room slots per floor, one entry, at least one valid route, and one extraction endpoint.
- Seeds producing disconnected graphs or unreachable extraction are invalid.
- Optional risk rooms may increase reward value only through existing approved reward paths; no drop probabilities may be invented.
- Dungeon mastery grants knowledge/access markers, not uncapped combat power.

## Requirements

- GDD-036..048, GDD-061..066.
- FR-WLD-001, FR-QST-001, FR-DNG-001/003.
- TC-WLD-001, TC-DNG-001/004, TC-SAV-001.

## Acceptance

- Academic MVP chapter path remains linear and unchanged.
- Branch state is local, persists safely, and reconverges at approved gates without revealing unapproved lore.
- Quest/profile/backup isolation and reload tests pass.
- Full-release dungeon generation is seeded, connected, validates extraction reachability, and rejects invalid graphs.
- Three-floor/six-slot structure is represented without adding unapproved content or reward probabilities.
- Mastery markers persist as knowledge/access only.
- Canonical headless suite, export/manifest, OD-013, and restoration gates pass with disposable user data.
- Update docs/report and commit `[REVIEW_PENDING_CODEX]`; do not mark reviewed.

## Boundaries

- No new dialogue, named villain, faction lore, ending reveal, educational content, images, audio, browser work, or additional OD resolution.
- Preserve OD-009, OD-002/003/004, and OD-005/006/007/008 behavior.
