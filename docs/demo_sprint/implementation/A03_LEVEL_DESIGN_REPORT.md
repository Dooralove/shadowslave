# A03 — Level Design / World Production Report

**Stage:** 4 — close-out  
**Date:** 2026-11-03  
**Worktree:** `C:\Users\user\Desktop\shadowslave-demo-03`  
**Branch:** `demo/level-design`  
**Integration:** local A03 commit; A00 collects/integrates it. No push.

## 1. Closed tasks

| Task | Result |
|---|---|
| A03-01 P05 | `Player` and `Spawns/Start` in the cell `(5.0,0.2,−18.2)`; `JettAtBed` / `JettInteract`; `MirrorInteract` and `InterrogationMirror`; portal requires `p05_jett_talked` + `p05_mirror_seen`; adds `flaw_revealed`, `flaw_clear_conscience`, `shadow_sight_unlocked`. |
| A03-02 P06 | `Jet` `(−4.8,0,18.0)`; `JetTrigger` `(−4.2,1.2,17.5)` → `jett_advice_heard`; checkpoint → `p06_checkpoint_passed`; portal → `p06_completed`. |
| A03-03 P07 | `GateGuard`; `NephisSilhouette` `(6,0,−5)`; `NephisGateTrigger` → `nephis_seen_at_gate`; checkpoint → `academy_gate_passed`; portal → `p07_completed`. |
| A03-04 P08 | `CampusTerminal` `(−2.5,1.2,4)` → `dorm_assigned`; `CampusGuide` hidden and disabled; portal → `p08_completed`. |
| A03-05 P09 | `InductionMedic`, `Rock`, `Kasper`, `Cassia`; induction, `kasper_met`, `cassia_seen`; capsule → `capsule_entered` + `academy_month_passed`; portal → `p09_completed`; Julius absent. |
| A03-06 B01 | `StarsInteract` / `SwordInteract` → `statue_seen`; `ShroudInteract` → `shroud_summoned`; portal requires both; `b01_arrived`. |
| A03-07 B02 | Visual steps retained; continuous ramp collision; verified in both directions. |
| A03-08 G1–G5 + Z10 | Z03–Z11 geometry fixed; `CampNight` and `DemoEndZone`; M1 final is disabled when `demo_mode_full`; `DemoEndZone` also listens to `flag_changed` to avoid an entry-order soft-lock. |
| A03-09 POI | `poi_manifest.md` and `world_layout.md` synchronised with implemented coordinates, node names and flags. |
| A03-10 P1 | Z11–Z18: G2, Z13/Z16 gaps, Z15 landing/ramp, Z18 `FinalZone`; `Portals/ToWest` disabled. |
| A03-11 P1 | `route_walk` 51/51; `route_reachability` 69/69; no lethal jumps; no ghost floor on the main route (see residual art cells below). |

## 2. Checks

| Check | Result |
|---|---|
| `godot --headless --path . --import` | exit 0; `FinalZone` and `DemoEndZone` parsed |
| `test_labyrinth_first_fragment.gd` | 12/13, 331/332 asserts; only outdated `Portals/ToWest.enabled` expectation fails |
| `test_labyrinth_quest_content.gd` | 4/4, 41 asserts |
| `test_save_system.gd` | 2/2, 14 asserts |
| `test_post_nightmare_locations.gd` | 14/15, 511/513 asserts; only old `Julius`/`JuliusInteract` expectations fail |
| `test_level_transition.gd` | 22/22, 83 asserts; exit 0 |
| `labyrinth_route_walk.gd` | 51/51 |
| `route_reachability.gd` | 69 PASS / 0 FAIL |
| `boundary_audit.gd --step=1.5 --jump=1` | 3483 lethal edges; 0 lethal jumps; 2 residual ghost cells (Z10 arch art); 115 floating |

## 3. Remaining blockers / dependencies

1. **A04-10:** `scripts/campaign/post_nightmare_finale.gd` still sets `post_nightmare_completed` for every finale. M1 must set only `post_nightmare_demo_completed`; tech demo sets `post_nightmare_completed`. Without an `demo_mode_m1` branch, M1 pollutes the tech-demo flag.
2. **A08 / A00-08:** there is no entry that sets `demo_mode_full`; `FinalZone` exists at Z18 but intentionally stays dormant without that flag.
3. **A10:** `test_labyrinth_first_fragment.gd` still expects `Portals/ToWest.enabled == true`; DP-1.0 requires it disabled and uses `FinalZone`.
4. **A10:** `test_post_nightmare_locations.gd` still expects `Julius`/`JuliusInteract`; MASTER_PLAN makes Julius M2-only.
5. **A07:** two residual ghost-floor cells under `ArtFinal/Zones/Z10_CoralHill`; they do not block the route or tests, but strict zero-ghost requires art collision follow-up.

## 4. Audit-tool notes

- `tools/audit/labyrinth_route_walk.gd` now excludes runtime enemies from the geometric walk and follows the Z10 west switchback through a waypoint. This is an A10-owned file; review is requested.
- `tools/audit/route_reachability.gd` uses the same runtime-enemy isolation.
- No temporary debug tools remain in the worktree.

## 5. Stage 6 — deep completeness audit

### Fixed in this pass

- P05 `MirrorInteract` is now disabled until `p05_jett_talked`; `JettInteract` disables after the conversation, the mirror disables after `p05_mirror_seen`, and re-entry restores the correct state from flags.
- P06/P07/P08/P09/B01/B02 interactions now guard against repeat dialogue and restore their enabled state from persisted flags on scene reload: Jet trigger, gate portal, campus terminal, Rock/capsule/portal, Shroud/descent/portal, tide warning.
- `CampNight` no longer depends on the `body_entered` order relative to `shore_first_day_complete`; it sets `camp_night_seen` on entry, while `DemoEndZone` still gates the final on both `shore_first_day_complete` and `camp_night_seen`.
- Added campus direction labels (`СТОЛОВАЯ`, `ДОДЗЁ`, `ВЫЖИВАНИЕ · SLEEPER CENTER`) and an induction label in the Sleeper Center.

### Remaining content/integration work

1. **A01-01:** `precinct_wake.tres` is only narration/Sunny; the Jett awakening dialogue (`p05_jett_awakening.tres`) is still absent. The scene and flags are ready; A01 must supply the Jett conversation.
2. **A01-05:** `academy_julius.tres` is currently reused as the Rock induction sequence, which is narratively wrong. A01 must provide `p09_induction.tres` (Rock/Kasper/Cassia) and the month time-skip card. `academy_month_passed` is currently set on capsule interaction as a fallback.
3. **A01-06:** B01 uses existing stars/sword/shroud sequences; no separate `b01_statue.tres` / shroud visual layer.
4. **A04-10:** `post_nightmare_finale.gd` still always sets `post_nightmare_completed`; M1 must set only `post_nightmare_demo_completed`. This remains the main M1/tech-demo state blocker.
5. **A08 / A00-08:** no `demo_mode_full` entry and no final-card routing; `FinalZone` is present but dormant.
6. **A07:** two residual ghost-floor cells under `ArtFinal/Zones/Z10_CoralHill`; no route impact, but not strict zero-ghost.
7. **A06/A09:** mannequin animations and scene audio/VFX remain outside A03 ownership; no new assets were added in this pass.

## 6. Stage 7 — player-facing presentation pass

Checked the actual M1 scene cameras and found these player-visible issues:

- The P05 spawn stood inside the east bunk mattress. The east beds are now shifted toward the cell wall, leaving the canonical spawn clear.
- The P06 arrival camera looked past the car and Jett. The arrival spawn now faces the car/Jett, and Jett stands in front of the car instead of clipping through its body; her facing is corrected.
- Added objective updates through the existing `CampaignGuide` API: after Jett → mirror, after mirror → yard, after P06 Jet → checkpoint, after gate → campus, after campus terminal → Sleeper Center, after induction → capsule, after Shroud → descent.
- Added readable campus wing signs and the induction label.

Remaining visual/content risks:

- The player model appears in a low/rest pose in capture, not a polished standing idle. This is A06-owned animation/model work and is the most visible character-quality issue in M1.
- P07 plaza, P08 gallery and P09 capsule hall still rely heavily on greybox/art-pass geometry; A07 owns the final set dressing.
- B01/B02 are dominated by large low-poly statue/shoulder forms; they read as geometry, not final art until A07 replaces them.
- Jett/Rock dialogue resources are still the A01 gaps listed above; those are the most visible narrative failures.
- 2 residual ghost-floor cells remain in Z10 art; no route blockage.
