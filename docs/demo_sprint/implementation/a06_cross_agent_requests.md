# A06 cross-agent requests — Stage 4

**Status:** open requests for A00 routing. A06 did **not** edit these files.  
**Rule:** each owner applies the change in their own branch; A06 provides assets,
contract names and acceptance criteria.

---

## 1. A03 — P09 Rock/Kasper/crowd and M1 Julius

**File:** `scripts/locations/post_nightmare/academy_sleeper_center.gd`  
**Priority:** P0 for M1.

Current state:

- `_build_post_nightmare_content()` always runs, including in M1.
- It spawns `InductionMedic` at `(0, 0, -23.4)` — this is the POI-P09-09
  podium position where the design expects **Rock**.
- It spawns `Julius` at `(-20, 0, -2)` and `JuliusInteract`; interacting sets
  `academy_julius_seen`. Julius is M2, not M1.
- Kasper and the P09-11 crowd are missing.

Requested change:

1. Rename the podium node to `Rock` (A06 context profile already handles both
   `Rock` and the temporary `InductionMedic` compatibility alias).
2. Add Kasper at `(2.5, 0, -21.5)`, yaw `PI`, using
   `res://scenes/characters/npc/kasper.tscn` (or a `Mannequin` named `Kasper`
   with archetype `mass_male`).
3. Add `res://scenes/characters/npc/sleeper_crowd.tscn` at
   `(-3.0, 0, -22.5)`, yaw `PI * 0.5` for POI-P09-11.
4. If POI-P09-06 still needs a medic at `(4.2, 0, -20.3)`, add a separate
   `InductionMedic` there; do not reuse the podium node.
5. Gate `Julius` and `JuliusInteract` behind an M2 flag (or remove them from the
   M1 build). M1 must not set `academy_julius_seen`.

Acceptance:

- P09 contains Rock, Kasper and the crowd; no Julius in the M1 route.
- `test_post_nightmare_locations` 15/15.
- A06 `tools/anim/location_npc_validate.gd` finds `Rock`/`Kasper` and no
  `Julius` in M1.

---

## 2. A03 — P07 Nephis silhouette (optional P1)

**File:** `scripts/locations/post_nightmare/academy_gate.gd`  
POI-P07-? calls for the first Nephis silhouette. Add a `Mannequin` named
`Nephis` (or instance `res://scenes/characters/npc/nephis.tscn`) at the POI
position, without collision and without dialogue. A06 context profile supplies
silver hair, cloak and spear.

Acceptance: visible silhouette at P07; no interaction; no quest flag.

### 2.1. P06 Jet facing

`academy_approach.gd` spawns `Jet` at `(-1.2, 0, 17.4)` with yaw `0.0`, while
the player spawn `Spawns/FromPrecinct` is at `(1.5, 0.2, 18.5)`. With the
Mannequin model facing `-Z`, Jet currently faces away from the player. Set her
yaw to `PI` (or rotate the marker) so she faces the player during the dialogue.

Acceptance: P06 Jet faces the player; no collision/quest change.

**A06 compatibility:** `Mannequin` temporarily faces `Jet` north when the scene yaw is `0`. Once A03 sets yaw `PI`, remove that compatibility block in `_apply_context_profile`.

---

## 3. A03/A04 — M1 capsule / Shroud actions

**Files:** `scripts/locations/post_nightmare/academy_sleeper_center.gd`,
`scenes/locations/post_nightmare/black_sea_platform.tscn` (or the owning
interactable script).

`sunny_poc_clips.tres` now maps:

- `sleep` → `HumanSit`
- `equip` → `HumanStandingIdle`
- `shroud` → `HumanStandingIdle`

Use the existing `CinematicActor.play(&"sleep")` / `play(&"shroud")` at the
capsule and Shroud points; A09 supplies the capsule/shroud VFX. Do not add a
second clip map.

Acceptance: `CinematicActor.has_action()` true for all three; no T-pose; M1
capsule and B01 Shroud play the action.

---

## 4. A05 — Carapace authored hit clip

**File:** `scripts/combat/carapace_animator.gd`  
**Asset:** `res://assets/animations/enemies/carapace_hit.tres` (validated).

Suggested change:

```gdscript
@export var hit_clip: StringName = &"Hit"

func _ready() -> void:
    var authored := load("res://assets/animations/enemies/carapace_hit.tres") as AnimationLibrary
    if authored != null:
        animation_player.add_animation_library(&"authored", authored)
    ...

func _on_damaged(_amount: float) -> void:
    # keep existing guard for TELEGRAPH/ATTACK/DEAD
    if animation_player.has_animation(&"authored/Hit"):
        animation_player.play(&"authored/Hit", 0.05)
    else:
        _start_procedural_flinch()
```

Acceptance: E01 hit outside committed attack plays the authored clip; no
interruption of the attack window; `test_carapace_enemy` remains 10/10.

A06 does not edit `CarapaceAnimator` or `scenes/enemies/**`.

---

## 5. A05 — Larva authored hit/death (optional)

**Assets:** `larva_hit.tres`, `larva_death.tres` (validated).  
`LarvaAnimator` currently uses procedural tweens and has no `AnimationPlayer`
dependency. If A05 wants authored clips, add the libraries to the larva's
`AnimationPlayer` and play `authored/Hit`/`authored/Death`; otherwise keep the
procedural version and treat the assets as optional. A06 does not edit
`LarvaAnimator` or `scenes/enemies/**`.

---

## 6. A05 — Sunny combo/dodge contract

- `SunnyAnimator.dodge_hold_time` is set to `0.8` in `sunny.tscn`, matching
  `CombatSettings.dodge_duration`. If A05 changes `dodge_duration`, update the
  animator hold or call a setter.
- `SunnyAnimator.combo_clips` is a visual 3-hit chain for the armed arena Sunny;
  `combo_window = 1.2` covers the armed attack cooldown of `0.95`. If A05 adds
  unarmed combo clips or changes cooldowns, expose them through
  `CombatController`/`SunnyAnimator` rather than hardcoding another chain.
- A06 does not edit `CombatController`, `MeleeAttack`, `AttackData` or
  `CombatSettings`.

---

## 7. A10 — tests for A06 features

Convert/cover in GUT:

- `Mannequin` context profiles: P06 Jet/CheckpointGuard, P07 GateGuard, P09
  Rock/Kasper, Z08 Nephis/Cassia.
- `SunnyAnimator` combo: first attack `attack_clip`, second/third combo clips,
  reset after `combo_window`.
- LOD switching: v3, Nightmare v2, Hero v6, Carapace, Mountain King.
- Enemy libraries: `carapace_hit`, `larva_hit`, `larva_death`.

Existing A06 tool scripts:

```powershell
godot --headless --path . -s tools/anim/location_npc_validate.gd
godot --headless --path . -s tools/anim/sunny_combo_validate.gd
godot --headless --path . -s tools/anim/lod_validate.gd
godot --headless --path . -s tools/anim/enemy_clip_validate.gd
```

---

## 8. A00 — decisions

1. **M1 Julius:** A03 currently spawns Julius and sets `academy_julius_seen` in
   P09, contradicting A06-03 acceptance and narrative M2. Decide: gate behind
   M2 or update the contract.
2. **LOD0 exception:** v3 84,175; Nightmare v2 93,472; Hero v6 90,000 vs the
   50k hero target. Approve exception or schedule LOD0 decimation.
3. **Commit policy:** Chat 06 instruction says no commits; Stage 3 rule 10 says
   commits. No commits were created; A00 should commit/merge the worktree.
4. **Final cast generation:** Jett/Nephis/Cassia/Julius/Theo finals still need
   Hyper3D web UI/credits; M1 is not blocked.
5. **A06-05 literal tree:** A06 uses `AnimationPlayer` crossfade, not a second
   `AnimationTree`; confirm this satisfies SS-120.
