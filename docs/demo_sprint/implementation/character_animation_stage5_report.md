# Character & Animation — Stage 5 final handoff

**Domain:** A06 — Character & Animation  
**Branch:** `demo/characters`  
**Final code commit:** `6ac4aba` (`feat(a06): complete character animation implementation wave`)  
**Final handoff commit:** this report commit (hash reported to TD after commit)  
**Push:** none.  
**Worktree:** clean after the report commit.

---

## 1. Closed Task IDs

| Task | Result |
|---|---|
| **A06-01** | Jett context profile in P06 + `jett.tscn`; dark-blue uniform, idle/talk/walk/point/leave |
| **A06-02** | Rock, Cassia, Nephis profiles/prefabs; guard, medic, guide and crowd profiles; Kasper prefab ready (P09 placement pending A03) |
| **A06-05** | NPC crossfade on the existing `AnimationPlayer`; no second animation framework |
| **A06-06** | `Mannequin`/`SunnyAnimator` stability; `WalkClean`, `FootGrounder`, `GuardPose` preserved |
| **A06-07** | LOD1/2 for Sunny v3, Nightmare v2, Hero v6, Carapace, Mountain King v2 |
| **A06-08** | Nightmare v2 candidate: 93,472 tri, 52 bones, 10 clips + `WalkClean`, LOD1/2, weapon socket |
| **A06-10** | `carapace_hit.tres`, `larva_hit.tres`, `larva_death.tres`; source-rig validation green |
| **A06-11** | `sleep`, `equip`, `shroud` actions added to the POC clip map |
| **A06-12** | Carapace E01 animation verification; 10/10 tests |
| **A06-13** | A03 handoff via context profiles and `scenes/characters/npc/README.md` |
| **A06-14** | Sunny 3-hit visual combo (Horizontal → Diagonal → Chop), `combo_window=1.2` |
| **A06-15** | Weapon socket for P1 and Nightmare v2; `CombatController` toggles visibility |
| **A06-17** | Arena dodge hold: 0.4 s clip held for 0.8 s movement |

---

## 2. Partially closed

| Task | Remaining |
|---|---|
| **A06-02 Kasper/crowd** | A03 must place `kasper.tscn` and `sleeper_crowd.tscn` in P09; exact request filed |
| **A06-03 Julius** | Final M2 model blocked by generation; existing M1 `Julius` + `academy_julius_seen` must be gated/removed by A03/A04 |
| **A06-04 Nephis/Cassia final** | M1 profiles are usable; final GLB/rig/LOD requires external generation |
| **A06-09 Theo** | M3 external generation |
| **A06-10 E01 integration** | A05 must wire `authored/Hit`/`authored/Death`; E01 test not run |
| **A06-11 usage** | A03/A04 must call `CinematicActor.play(&"sleep"/&"shroud")` at capsule/B01 |
| **A06-15 hitbox** | Socket/visual done; blade hitbox/attack data remain A05 |
| **A06-16 turn/foot IK** | Not implemented; P1 follow-up |
| **A06-05 literal tree** | Crossfade used; TD to confirm SS-120 acceptance |
| **A06-07 LOD0 budget** | v3 84k, Nightmare 93k, Hero 90k; exception or decimation decision |

---

## 3. New findings from the audit

1. **P09 M1 contains Julius.** `academy_sleeper_center.gd` always spawns `Julius`/`JuliusInteract` and sets `academy_julius_seen`. This contradicts A06-03 and narrative M2.
2. **P09 Kasper and crowd are missing.** POI-P09-10/11 are unimplemented; only the podium Rock (`InductionMedic` compatibility alias) and Julius exist.
3. **`InductionMedic` name is ambiguous.** The current node is at POI-P09-09 (Rock podium), not the P09-06 medic. A03 should rename it to `Rock`; A06 can then remove the compatibility alias.
4. **P06 Jet faces away.** Player spawns at z=18.5; Jet at z=17.4 with yaw 0 faces `-Z`, away from the player. Set yaw to `PI`.
5. **Nightmare armed mode had no weapon.** Fixed with a `BoneAttachment3D` sword socket in `SunnyV3Model`.
6. **Arena combo was unreachable.** Armed cooldown 0.95 s exceeded the original 0.8 s window; `combo_window=1.2`.
7. **Arena dodge tail.** `Dodge_Backward` is 0.4 s while dodge movement is 0.8 s; the state now holds the last pose for the full movement.
8. **Respawn combo leak.** `reset_to_idle()` clears combo index/timer.
9. **Full suite is green:** **636/636**, 81 scripts, 7,336 asserts, 353.6 s. The 98 orphan nodes in one UI test are warnings, not failures.
10. **`scripts/characters/**` ownership** remains unresolved; A06 used existing helpers but did not edit them.

---

## 4. Verification

### 4.1. Import and full suite

```powershell
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

- Import: exit 0.
- Full GUT: **636/636**, 7,336 asserts, 353.6 s.
- No test was disabled to obtain this result.

### 4.2. A06 tool checks

| Tool | Result |
|---|---|
| `tools/anim/npc_validate.gd` | failed=0; 6 prefabs + crowd |
| `tools/anim/location_npc_validate.gd` | failed=0; P06/P07/P08/P09/Z08 context profiles |
| `tools/anim/sunny_combo_validate.gd` | failed=0; 3-hit chain + reset |
| `tools/anim/sunny_dodge_validate.gd` | failed=0; 0.4 s clip held to 0.8 s |
| `tools/anim/nightmare_validate.gd` | failed=0; clips, LODs, actions, weapon socket |
| `tools/anim/lod_validate.gd` | failed=0; 5 assets × 3 LODs |
| `tools/anim/enemy_clip_validate.gd` | failed=0; 3 enemy libraries |

### 4.3. Captures

- `%TEMP%\opencode\a06_location_npc_shots2` — P06 Jet/guard, P09 Rock/Julius, Z08 Nephis/Cassia.
- `%TEMP%\opencode\a06_char_capture_stage4b` — Nightmare armed idle with sword.
- `%TEMP%\opencode\a06_combo_shots` — 3 combo poses.
- `%TEMP%\opencode\a06_lod_shots` — LOD0/1/2.

---

## 5. Commit contents

`6ac4aba` contains **57 files**, 3,002 insertions, 37 deletions.

New:

- `assets/animations/enemies/**` — 3 libraries + README.
- `scenes/characters/npc/**` — 6 NPC prefabs + crowd + README.
- `tools/anim/**` — LOD build, validators, captures, clip builders.
- `docs/demo_sprint/implementation/a06_cross_agent_requests.md`
- `docs/demo_sprint/implementation/character_animation_stage3_report.md`
- `docs/demo_sprint/implementation/character_animation_stage4_report.md`

Modified:

- `scripts/slice/mannequin.gd` — context profiles, tints, accessories, crossfade, scale.
- `scripts/player/sunny_animator.gd` — combo, dodge hold, reset.
- `scenes/characters/sunny.tscn` — combo clips/window, dodge hold.
- `assets/characters/generated/sunny_real_v3/sunny_v3_model.gd` — weapon socket.
- `assets/characters/generated/**` — LOD/weapon integration.
- `assets/characters/enemies/carapace_generated/**` — LOD.
- `assets/characters/sunny_realistic_poc/sunny_poc_clips.tres` — M1 actions.
- `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` — claim status.

No A03/A05/A08/A09/A10 game files were edited. `resources/slice/sunny_kaykit_clips.tres` was reverted and is not in the commit.

---

## 6. Required follow-up

See `docs/demo_sprint/implementation/a06_cross_agent_requests.md` for exact code/positions.

- **A03:** P09 Rock rename, Kasper, crowd, Julius gating, P06 Jet yaw, optional P07 Nephis silhouette.
- **A03/A04:** capsule `sleep`, B01 `shroud` action calls.
- **A05:** carapace hit integration; optional larva clips; combo/dodge contract; blade hitbox.
- **A10:** GUT coverage for context profiles/combo/dodge/LOD/enemy libraries.
- **A00:** M1 Julius contract, LOD0 exception, commit/merge, final cast generation, literal NPC tree decision.

---

## 7. Known limitations

- Final Jett/Nephis/Cassia/Julius/Theo models require external generation/credits.
- A06-16 turn-in-place/foot IK is not implemented.
- LOD0 budgets for v3/Nightmare/Hero exceed 50k.
- `scripts/characters/**` ownership is still unresolved in FILE_OWNERSHIP.
- E01 enemy hit integration is not tested until A05 wires the libraries.
