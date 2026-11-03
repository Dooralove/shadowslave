# Character & Animation — Stage 3 implementation report

**Domain:** A06 — Character & Animation  
**Branch:** `demo/characters`  
**Base:** `ee97325`  
**Worktree:** `C:\Users\user\Desktop\shadowslave-demo-06`  
**Status:** first production wave complete; targeted verification green; A00/A03/A05 integration pending.  
**Commits:** none created. Chat 06 instruction says “не коммить”; Stage 3 rule 10 says commit. The conflict is left for A00; all changes are in the worktree.

---

## 1. Completed

| Task | Result | Evidence |
|---|---|---|
| **A06-01** Jett placeholder | `scenes/characters/npc/jett.tscn`; `mass_female`, dark-blue uniform, 5 poses (idle/talk/walk/point/leave) | `npc_validate` 6 pose changes incl. `leave`; `npc_lineup.png` |
| **A06-02** Rock/Kasper/Cassia/Nephis | 4 prefabs; Cassia blindfold/white uniform; Nephis silver hair/cloak/spear; Rock large; Kasper gold accent | `npc_validate` 4/4; close-up captures |
| Academy guard / crowd | `academy_guard.tscn` (police_guard repaint, check), `sleeper_crowd.tscn` (6 Mannequins) | `npc_validate` guard + crowd children=6; `npc_lineup.png` |
| **A06-05** NPC transitions | `Mannequin` now uses `AnimationPlayer.play(clip, 0.18–0.2)` crossfade; no second animation tree/framework | 5 pose changes per prefab; no pose snap in captures |
| **A06-06** Stability | `Mannequin`/`SunnyAnimator`/`FootGrounder`/`GuardPose` remain; no parse errors; `WalkClean` preserved | `test_labyrinth_first_fragment` 13/13; all targeted GUT |
| **A06-07** LOD1/2 | v3, Nightmare v2, Hero v6, Carapace, Mountain King v2 | `lod_validate` failed=0; 3 LODs per asset; screenshots |
| **A06-08** Sunny Nightmare candidate | `sunny_nightmare_v2`: 93,472 tri LOD0, 52 bones, 10 clips, LOD1/2; wired into `sunny_waking_nightmare.tscn` | `nightmare_validate` failed=0; clips=11 with `WalkClean` |
| **A06-10** Enemy hit/death assets | `carapace_hit.tres`, `larva_hit.tres`, `larva_death.tres` | `enemy_clip_validate` failed=0; A05 integration pending |
| Sunny M1 actions | `sunny_poc_clips.tres`: added `sleep`, `equip`, `shroud` | `test_sunny_poc` 10/10; `nightmare_validate` actions present |

### 1.1. LOD measurements

| Asset | LOD0 | LOD1 | LOD2 | Bones | Clips |
|---|---:|---:|---:|---:|---:|
| Sunny v3 | 84,175 | 37,877 | 13,467 | 52 | 10 (+WalkClean) |
| Sunny Nightmare v2 | 93,472 | 42,062 | 14,954 | 52 | 10 (+WalkClean) |
| Hero v6 | 90,000 | 40,499 | 14,400 | 52 | 7 |
| Carapace | 120,000 | 42,000 | 14,400 | 38 | 5 |
| Mountain King v2 | 120,000 | 42,000 | 14,400 | 60 | 6 |

LOD0 budgets for v3/Nightmare/Hero still exceed the 50k hero target. LOD1/2 are within the intended fallback range; TD must approve the LOD0 exception or schedule decimation of LOD0.

---

## 2. Verification

### 2.1. Import

```powershell
godot --headless --path . --import
```

Result: exit 0; new GLBs/tscn imported.

### 2.2. Targeted GUT — 118/118

| Test | Result |
|---|---|
| `test_labyrinth_first_fragment` | 13/13 |
| `test_caravan_site` | 7/7 |
| `test_pilgrim_path` | 10/10 |
| `test_sunny_animation` | 16/16 |
| `test_sunny_poc` | 10/10 |
| `test_carapace_enemy` | 10/10 |
| `test_mountain_king` | 11/11 |
| `test_sunny_waking` | 10/10 |
| `test_enemy_animation` | 7/7 |
| `test_post_nightmare_locations` | 15/15 |
| `test_sunny_combat` | 6/6 |
| `test_full_route` | 3/3 |

Full GUT suite in this worktree: **NOT TESTED**. The earlier baseline full run was unstable; targeted suite is the evidence for this wave.

### 2.3. A06 tool checks

```powershell
godot --headless --path . -s tools/anim/npc_validate.gd
godot --headless --path . -s tools/anim/lod_validate.gd
godot --headless --path . -s tools/anim/enemy_clip_validate.gd
godot --headless --path . -s tools/anim/nightmare_validate.gd
```

| Check | Result |
|---|---|
| NPC prefabs + crowd | failed=0; 6 prefabs, crowd=6 |
| LOD cases | failed=0; 5 assets, 3 visible LODs |
| Enemy libraries | failed=0; 3 clips on source rigs |
| Nightmare variant | failed=0; 11 clips, LODs, actions |

### 2.4. Visual captures (not committed)

- `%TEMP%\opencode\a06_npc_shots4\npc_lineup.png` — Jett, Rock, Kasper, Cassia, Nephis, guard.
- `%TEMP%\opencode\a06_lod_shots\*.png` — v3/Nightmare/Hero/Carapace/Mountain King at LOD0/1/2.
- Real Forward+ capture is clean; the headless dummy renderer emits a `material is null` warning on teardown, not present in real rendering.

---

## 3. Not done / blocked

| Task | Status | Blocker |
|---|---|---|
| **A06-03** Julius final | Not started | M2; final model/rig requires external generation; M1 intentionally has no Julius |
| **A06-04** Nephis/Cassia final | Placeholder only | External generation/credits; M1 placeholders are accepted |
| **A06-09** Theo final | Not started | M3; external generation |
| **A06-10** E01 integration | Assets ready | A05 must add `authored/Hit` / `authored/Death` to enemy animators; A06 does not edit A05 files |
| **A06-05 literal AnimationTree** | Crossfade implemented | No second tree added; TD to decide if a literal NPC `AnimationTree` is required |
| **A06-07 LOD0 budget** | LOD1/2 done | v3/Nightmare/Hero LOD0 >50k; exception or decimation decision |
| **A06-08 final art sign-off** | Candidate integrated | TD/A10 visual acceptance; v2 is the current candidate, not declared final by A06 alone |

---

## 4. Integration handoff

### A03 — locations

- Prefabs and exact usage are in `scenes/characters/npc/README.md`.
- A06 did not edit `scenes/locations/**`.
- Suggested placements: Jett P06, guard P07, Rock/Kasper P09, Cassia Z08/P09, Nephis Z08/Z10, crowd P09.
- No collision on prefabs; A03 owns blocking/props.

### A05 — combat

- `assets/animations/enemies/README.md` documents the additive libraries.
- A05 should add the library to the existing `AnimationPlayer` and play `authored/Hit`/`authored/Death`.
- Carapace `Death` already exists; `Hit` is new. Larva `Hit`/`Death` are new.
- Weapon socket remains in `SunnyP1Model`; hitbox ownership remains A05.

### A10 — QA

- Targeted suite above is green.
- Please add GUT coverage for the NPC prefabs, LOD switching and enemy clip libraries if A06 tool scripts are not accepted as permanent tests.
- Full-suite baseline should be re-established after A00 merges this branch.

---

## 5. Decisions / conflicts for TD

1. **Commit policy:** top instruction says no commits; Stage 3 rule 10 says commit. No commits created.
2. **`scripts/characters/**` ownership:** still not in FILE_OWNERSHIP. A06 used existing `FootGrounder`, `GuardPoseModifier`, `CharacterLodVisibility` without editing them.
3. **Literal NPC AnimationTree:** A06 chose crossfade on the existing `AnimationPlayer` to avoid a second system. Confirm or request a follow-up.
4. **LOD0 exception:** v3 84k, Nightmare 93k, Hero 90k. Approve exception or schedule LOD0 decimation.
5. **Final cast:** Hyper3D web UI/credits are still required for Jett/Nephis/Cassia/Julius/Theo finals. M1 is not blocked by this.
6. **A06-08:** Nightmare v2 is a candidate with 10 clips + LOD; visual sign-off belongs to TD/A10.
7. **A06-10:** assets are validated on the source rigs; E01 integration is **NOT TESTED** until A05 wires them.

---

## 6. Changed files (summary)

A06-owned:

- `scripts/slice/mannequin.gd`
- `scenes/characters/npc/**`
- `assets/characters/generated/sunny_real_v3/**`
- `assets/characters/generated/sunny_nightmare_v2/**`
- `assets/characters/generated/hero_auro_v6/**`
- `assets/characters/generated/mountain_king_v2/**`
- `assets/characters/enemies/carapace_generated/**`
- `assets/characters/sunny_realistic_poc/sunny_poc_clips.tres`
- `assets/animations/enemies/**`
- `tools/anim/**`

Shared/protocol:

- `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` (claim status only)

No A03/A05/A08/A09/A10 game files were edited.
