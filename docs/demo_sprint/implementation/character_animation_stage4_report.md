# Character & Animation — Stage 4 report

**Domain:** A06 — Character & Animation  
**Branch:** `demo/characters`  
**HEAD:** `ee97325`  
**Worktree:** `C:\Users\user\Desktop\shadowslave-demo-06`  
**Status:** second production wave complete; targeted verification green; integration requests filed for A03/A05/A10/A00.  
**Commits:** Stage 4 had no commits (Chat 06 said “не коммить”; Stage 3 rule 10 said commit). Stage 5 final commit is recorded in `character_animation_stage5_report.md`. No push.

---

## 1. Fully closed

| Task | Result | Evidence |
|---|---|---|
| **A06-01** Jett | Existing P06 `Jet` node now receives the dark-blue Jett profile; prefab `jett.tscn` remains for A03 replacement | `location_npc_validate`: `p06 Jet uniform=(0.16,0.22,0.38)`; `p06_Jet.png` |
| **A06-02** Rock/Cassia/Nephis | Existing P09 podium `InductionMedic` now receives Rock profile; Z08 `NPC_Nephis` gets silver hair/cloak/spear; `NPC_Cassia` gets blindfold; prefabs remain for exact placement | `location_npc_validate` all green; Z08 capture |
| Guard profiles | P06 `CheckpointGuard`, P07 `GateGuard`, P05 `InterrogationOfficer` get dark-blue/gold guard profile | `location_npc_validate` green |
| **A06-05** NPC transitions | `AnimationPlayer.play(clip, 0.18–0.2)` crossfade; no second tree/framework | `npc_validate` 6 poses per prefab; captures |
| **A06-06** Stability | `Mannequin`/`SunnyAnimator`/`FootGrounder`/`GuardPose` stable; `WalkClean` preserved | `test_labyrinth_first_fragment` 13/13; all targeted GUT |
| **A06-07** LOD1/2 | v3, Nightmare v2, Hero v6, Carapace, Mountain King v2 | `lod_validate` failed=0; `lod_capture` 3 LOD shots per asset |
| **A06-08** Nightmare candidate | v2: 93,472 tri, 52 bones, 10 clips + `WalkClean`, LOD1/2, **weapon socket** | `nightmare_validate` failed=0; `nightmare_armed_idle.png` shows sword |
| **A06-10** enemy assets | `carapace_hit.tres`, `larva_hit.tres`, `larva_death.tres` | `enemy_clip_validate` failed=0 |
| **A06-14** Sunny combo | 3-hit visual chain in `sunny.tscn`: Horizontal → Diagonal → Chop; `combo_window=1.2` covers 0.95 armed cooldown | `sunny_combo_validate` failed=0; 3 combo captures |
| **A06-17** Dodge hold | Arena `Dodge_Backward` 0.4 s clip held for 0.8 s movement; `dodge_hold_time=0.8` | `sunny_dodge_validate` failed=0 |
| **A06-15** weapon socket | P1 and v2 Nightmare expose `get_weapon_socket()`; `CombatController` finds it and toggles visibility | `nightmare_validate` armed/unarmed checks |

### LOD measurements

| Asset | LOD0 | LOD1 | LOD2 | Bones | Clips |
|---|---:|---:|---:|---:|---:|
| Sunny v3 | 84,175 | 37,877 | 13,467 | 52 | 10 (+WalkClean) |
| Sunny Nightmare v2 | 93,472 | 42,062 | 14,954 | 52 | 10 (+WalkClean) |
| Hero v6 | 90,000 | 40,499 | 14,400 | 52 | 7 |
| Carapace | 120,000 | 42,000 | 14,400 | 38 | 5 |
| Mountain King v2 | 120,000 | 42,000 | 14,400 | 60 | 6 |

---

## 2. Partially closed / blocked

| Task | Status | Blocker / next step |
|---|---|---|
| **A06-02 Kasper** | Missing in P09 | A03 must add `Kasper` at POI-P09-10 or instance `kasper.tscn`; request filed |
| **A06-02 crowd** | Missing in P09 | A03 must instance `sleeper_crowd.tscn` at POI-P09-11; request filed |
| **A06-03 Julius** | Final model not started; **existing Julius in M1** | M2 generation blocked; A03/A04 must gate/remove M1 `Julius` and `academy_julius_seen` |
| **A06-04 Nephis/Cassia final** | M1 placeholders/profiles only | External generation/credits; final GLB + rig + LOD pending |
| **A06-09 Theo** | Not started | M3 external generation |
| **A06-10 E01 integration** | Assets ready | A05 must wire `authored/Hit`/`authored/Death`; E01 test NOT TESTED |
| **A06-11 Sunny actions** | `sleep`/`equip`/`shroud` mapped in POC clip map | A03/A04 must call `CinematicActor.play()` at capsule/Shroud points |
| **A06-15 hitbox** | Socket/visual done | A05 owns blade hitbox/attack data |
| **A06-16 turn/foot IK** | Not started | Needs dedicated turn clips/foot IK; P1 follow-up |
| **A06-05 literal tree** | Crossfade instead | TD decision whether a literal NPC `AnimationTree` is required |
| **A06-07 LOD0 budget** | LOD1/2 done | v3/Nightmare/Hero LOD0 >50k; exception or decimation decision |

---

## 3. New findings

1. **P09 M1 contains Julius.** `academy_sleeper_center.gd` always builds `Julius`/`JuliusInteract` and sets `academy_julius_seen`; this contradicts A06-03 and narrative M2. Request filed for A03/A04/A00.
2. **P09 Kasper/crowd are absent.** POI-P09-10/11 are marked MISSING; only `InductionMedic` (podium) and `Julius` exist. Rock is covered by the temporary `InductionMedic` context alias.
3. **`InductionMedic` naming is ambiguous.** Current podium node is at POI-P09-09 (Rock), but its name says medic. A03 should rename it to `Rock`; the A06 alias can then be removed. A separate P09-06 medic should not reuse the name until then.
4. **Nightmare v2 armed mode had no weapon.** Added a `BoneAttachment3D`/sword socket to `SunnyV3Model`; `sunny_nightmare_v2.tscn` enables it. Armed mode now shows the sword.
5. **Arena combo needed a larger window.** Armed attack cooldown is 0.95 s; `combo_window=0.8` made the combo unreachable. Scene now uses `combo_window=1.2`.
6. **Arena dodge tail.** `Dodge_Backward` is 0.4 s while dodge movement is 0.8 s. `dodge_hold_time` now sets the full state duration; the last pose is held for the remaining 0.4 s.
7. **Respawn combo leak.** `reset_to_idle()` now clears combo index/timer.
8. **`scripts/characters/**` ownership** remains unresolved in FILE_OWNERSHIP; A06 used existing helpers without editing them.
9. **Full GUT suite:** Stage 5 full run is green — **636/636**, 81 scripts, 7,336 asserts, 353.6 s. The 98 orphan nodes in one UI test are warnings, not failures.

---

## 4. Verification

### 4.1. Targeted GUT

Stage 3 baseline: **118/118**. Stage 4 affected tests re-run after context profiles/combo/dodge:

| Test | Result |
|---|---|
| `test_sunny_animation` | 16/16 |
| `test_sunny_combat` | 6/6 |
| `test_combat_controller` | 9/9 |
| `test_sunny_waking` | 10/10 |
| `test_sunny_poc` | 10/10 |
| `test_post_nightmare_locations` | 15/15 |
| `test_caravan_site` | 7/7 |
| `test_pilgrim_path` | 10/10 |
| `test_labyrinth_first_fragment` | 13/13 |
| `test_full_route` | 3/3 |
| `test_carapace_enemy` | 10/10 |
| `test_mountain_king` | 11/11 |
| `test_enemy_animation` | 7/7 |

Full suite: **636/636** (81 scripts, 7,336 asserts, 353.6 s) — Stage 5 full run. The 98 orphan nodes in one UI test are warnings, not failures.

### 4.2. A06 tools

| Check | Result |
|---|---|
| `tools/anim/location_npc_validate.gd` | failed=0; P06 Jet/guard, P07 guard, P09 medic/Julius, P08 guide, Z08 Nephis/Cassia |
| `tools/anim/sunny_combo_validate.gd` | failed=0; 3 clips + reset |
| `tools/anim/sunny_dodge_validate.gd` | failed=0; 0.4 clip held to 0.8 |
| `tools/anim/nightmare_validate.gd` | failed=0; 11 clips, LODs, actions, weapon socket |
| `tools/anim/lod_validate.gd` | failed=0; 5 assets × 3 LODs |
| `tools/anim/enemy_clip_validate.gd` | failed=0; 3 libraries |
| `tools/anim/npc_validate.gd` | failed=0; 6 prefabs + crowd |

### 4.3. Captures

- `%TEMP%\opencode\a06_location_npc_shots2` — P06 Jet/guard, P09 Rock/Julius, Z08 Nephis/Cassia.
- `%TEMP%\opencode\a06_char_capture_stage4b` — Nightmare armed idle with sword.
- `%TEMP%\opencode\a06_combo_shots` — 3 combo poses.
- `%TEMP%\opencode\a06_lod_shots` — LOD0/1/2.

---

## 5. Integration requests

See `docs/demo_sprint/implementation/a06_cross_agent_requests.md` for exact changes:

- **A03:** P09 Rock rename, Kasper, crowd, Julius gating; P07 Nephis silhouette.
- **A03/A04:** capsule `sleep`, B01 `shroud` action calls.
- **A05:** carapace authored hit integration; optional larva clips; combo/dodge contract.
- **A10:** GUT coverage for context profiles, combo, dodge, LOD, enemy libraries.
- **A00:** M1 Julius contract, LOD0 exception, commit policy, final cast credits, literal NPC tree decision.

---

## 6. Remaining work (priority)

1. **A03:** add Kasper/crowd and gate Julius; then M1 P09 is contract-clean.
2. **A05:** wire carapace hit and validate E01; decide larva authored clips.
3. **A03/A04:** use `sleep`/`equip`/`shroud` actions in M1.
4. **A06:** turn-in-place/foot IK (P1), final Nephis/Cassia/Jett/Julius/Theo (external generation).
5. **A00:** resolve commit policy, `scripts/characters/**`, LOD0 exception, Hyper3D credits.
6. **A10:** full GUT baseline after merge; add GUT coverage for A06 tools.

---

## 7. Changed files (summary)

A06-owned:

- `scripts/slice/mannequin.gd` — context profiles, tints, accessories, crossfade, scale.
- `scripts/player/sunny_animator.gd` — combo, dodge hold, reset.
- `scenes/characters/sunny.tscn` — combo clips/window, dodge hold.
- `scenes/characters/npc/**` — prefabs, crowd, README.
- `assets/characters/generated/sunny_real_v3/sunny_v3_model.gd` — weapon socket.
- `assets/characters/generated/sunny_real_v3/**`, `sunny_nightmare_v2/**`, `hero_auro_v6/**`, `mountain_king_v2/**`, `enemies/carapace_generated/**` — LODs/weapon.
- `assets/characters/sunny_realistic_poc/sunny_poc_clips.tres` — sleep/equip/shroud.
- `assets/animations/enemies/**` — hit/death libraries + README.
- `tools/anim/**` — build/validate/capture tools.

Docs/protocol:

- `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` — claim status.
- `docs/demo_sprint/implementation/a06_cross_agent_requests.md` — requests.
- `docs/demo_sprint/implementation/character_animation_stage4_report.md` — this report.

No A03/A05/A08/A09/A10 game files were edited.
