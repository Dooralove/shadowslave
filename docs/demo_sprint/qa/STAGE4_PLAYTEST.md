# STAGE 4 — Complete Demo Playtest

Date: 2026-11-03  
Snapshot: HEAD `ab8fe304f5b4c9915d1d5579851f1402d2cf8b18` + dirty working tree (30+ uncommitted files from other agents). Results below are tied to that working tree, not to a clean commit.

## 1. Gates

| Check | Result |
|---|---|
| `--import` | exit 0 |
| Full GUT | **711/711, 7811 asserts, exit 0** after Stage 4 fixes |
| `qa_script_audit` | **378 scripts, 0 failures** (tools/** excluded) |
| `route_reachability` | **18/18 zones, 51/51 POI** |
| `labyrinth_route_walk` @10 m/s | **NOT COMPLETED** — stopped at `z16_to_z17` (34/51) after 10+ min |
| `labyrinth_route_walk` @30 m/s | 47/51; failures 31/33/36/50 are speed-induced, not geometry proof |
| Actual menu → P05 → … → Labyrinth | **PASS** (real clicks, `LevelPortal.activate`) |
| Save/load F5/F9 | **PASS** (position, flags, currency, enemy respawn) |
| M1 finale Z10 | **PASS** (real transition, card + flags) |
| Tech finale Z18 | **PASS** (via tech demo entry or M1 continuation) |
| Tech demo entry | **PASS** (`TechDemoButton` + M1 `ContinueButton`; `qa_stage4_menu_tech` 7/7) |

## 2. Playthrough coverage

- **Base quests (7/7):** `first_day`, `first_blood`, `azure_blade`, `crystal_cache`, `hunt_pack`, `camp_rest`, `bridge_stand` — all completed in a single live labyrinth run.
- **Combat E01–E03:** E01 aggro/damage/player melee kill; E02 3-pack; E03 2-carapace pair; kill credits and quest completion pass.
- **SQ-01:** pass (token → 3 traces → Theo).
- **SQ-02:** pass — `echo_polyp.tscn` created; polyp killed, `destroy_polyp=1`, cloak/core taken.
- **SQ-03:** pass — choice panel active, truth choice, `sq_fs_03_resolved`, cord/cache.
- **SQ-04:** pass — markers/runtime, low tide, levers [LOW,HIGH,LOW], box, +2 shards.
- **SQ-05:** pass — Old Shell killed, alpha reward, shell cutter +2 shards.
- **Tide:** low/high cycle, 8 gates open/close pass.
- **Checkpoint death:** respawn 1.0 m from checkpoint, no softlock.
- **Re-entry:** runtime rebuilt; dead E01 not respawned; SQ-01 token not repeatable; currency/quest states preserved.
- **UI:** objective line, captions, combat HUD, tide indicator, inventory, pause menu pass; inventory is a demo set, not run inventory.
- **Finale zones:** `DemoEndZone`/`FinalZone` emit `Removing a CollisionObject node during a physics callback...` — real runtime error; scene still changes, but transition must be deferred.

## 3. Evidence

| Artifact | Path |
|---|---|
| Post-nightmare harness | `%TEMP%\opencode\fix_stage4_post2.log`, `stage4_post_fixed2_shots\` (62/62) |
| Labyrinth harness | `%TEMP%\opencode\fix_stage4_lab2.log`, `stage4_lab_fixed2_shots\` (161/161) |
| Final/save harness | `%TEMP%\opencode\fix_stage4_final3.log`, `stage4_final_fixed2_shots\` (41/41) |
| Input/combat + F5/F9 | `%TEMP%\opencode\fix_stage4_input.log`, `stage4_input_fixed_shots\` (15/15) |
| Tech menu entry | `%TEMP%\opencode\fix_stage4_menu_tech2.log`, `stage4_menu_tech_shots\` (7/7) |
| GUT after import | `%TEMP%\opencode\final_stage4_gut.log` (711/711) |
| Script audit | `%TEMP%\opencode\stage4_script_audit2.log` |
| Reachability | `%TEMP%\opencode\stage4_reach2.log` |
| Route walk | `%TEMP%\opencode\stage4_walk.log`, `stage4_walk30.log` |
| Actual MCP screenshots | `addons/godot_mcp/cache/screenshots/stage4_*.png` |

## 4. Verdict

**M1 (P05→Z10): PASS WITH LIMITATIONS.** Base quests, E01–E03, SQ-01, save/load, re-entry, checkpoint and M1 finale work.  
**Full demo (Z01–Z18 + SQ-01…05): PASS in live harness.** Tech demo is reachable via `TechDemoButton` and M1 `ContinueButton`; SQ-02/03/04/05 complete.  
**Remaining:** B01 readability (BUG-032), route walk not completed @10 m/s, no clean commit/build.  
**Release:** **NOT READY** — BUG-001/002/011/012/017 + BUG-032 remain.
