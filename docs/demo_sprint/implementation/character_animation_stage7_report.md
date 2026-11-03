# Character & Animation — Stage 7 maximum quality pass

**Domain:** A06 — Character & Animation  
**Branch:** `demo/characters`  
**Starting point:** `7a9931e` (Stage 6 audit)  
**Stage 7 status:** player-visible polish applied; full GUT green.  
**Push:** none.

---

## 1. What a player would notice

| Visible issue | Impact | Action |
|---|---|---|
| P06 Jett faced away from the player spawn | Dialogue scene starts with the NPC’s back | A06 context profile now faces Jet north when the scene yaw is 0; A03 can set yaw `PI` and remove the compatibility |
| Jett read as a generic blue body-suit | Weak character identity in P06 | Added a gold badge accessory and kept the dark-blue uniform |
| Nephis’ cloak was a large flat white board | Cheap silhouette in Z08/Z10 | Replaced with a curved short shoulder cape with fold variation |
| Cassia’s blindfold stayed fixed when the head moved | Accessory floated during `listen`/`head_turn` | Blindfold now follows the `Head` bone via `BoneAttachment3D` |
| v3/Nightmare guard looked like idle | Blocking had no readable pose | `SunnyV3Model` supplies a guard modifier; Mixamo arm offsets tested |
| Hero could get two LOD components through `Mannequin` | Potential LOD fighting/popping | `Mannequin` reuses the scene’s `LodVisibility` |
| Sword/accessories could be hidden by LOD switching | Weapon/cloak disappearing at distance | `lod_ignore` group added to the LOD collector and accessory meshes |

---

## 2. Visual verification

- P06 Jet: front view shows dark-blue uniform and badge; player spawn is north of Jet.
- Z08 Nephis: short white shoulder cape, spear, silver hair.
- Z08 Cassia: blindfold follows the head; white uniform.
- P09 Rock: dark podium speaker profile; Julius remains red (M2 content, see below).
- v3/Nightmare guard: arms raised in a readable guard pose.
- Nightmare armed idle: sword visible in the right hand.
- LOD0/1/2 captures: model remains visible; Hero has one LOD component.

Capture folders:

- `%TEMP%\opencode\a06_location_npc_stage7h`
- `%TEMP%\opencode\a06_char_capture_stage6e`
- `%TEMP%\opencode\a06_lod_stage6`
- `%TEMP%\opencode\a06_combo_shots`

---

## 3. Remaining player-visible issues

### Owned by A03/A04

1. **P09 still contains Julius in M1** and sets `academy_julius_seen`; this is an M2 character.
2. **P09 Kasper and the induction crowd are missing**; only the Rock podium alias and Julius exist.
3. **`InductionMedic` is the Rock podium node**; A03 should rename it to `Rock`.
4. **P06 Jet yaw** is now compensated by A06; A03 should set yaw `PI` and remove the compatibility.
5. **P06 city-edge character screen** was visible from the north capture; check whether this is an intentional terminal/billboard or an A08/A03 debug overlay.

### Owned by A05

6. **Carapace/Larva hit/death libraries are not wired**; E01 hit feedback still uses procedural flinch.
7. **Blade hitbox** is still a sphere in front of the character, not the sword.

### A03/A04 actions

8. **`sleep`/`equip`/`shroud` actions** are mapped but not called at the capsule/B01.

### Remaining A06

9. **Turn-in-place / foot IK** — not implemented; the controller still snaps yaw.
10. **v3/Nightmare sword combo/parry/riposte** — v3 only has `HumanSpBoxing`; combo is arena-only.
11. **Directional hit reactions** — one `HumanSpHeadHit`; no chest/heavy/left/right.
12. **Special ability animation** — `Spell_Simple_Shoot`/`HumanSpBoxing` placeholder; VFX is A09.
13. **NPC wave/argue** — UAL talk/interact only.
14. **Nightmare armed attack** — sword is visible, but the clip is still `HumanSpBoxing` (punch).
15. **Facial/finger/ragdoll** — P2/P3, not implemented.

### Acceptance gaps

16. **Manual playthrough** — **NOT TESTED**.
17. **1080p/60 FPS** — **NOT TESTED**; LOD0 v3/Nightmare/Hero is still heavy.
18. **Foot slide in real gameplay** — **NOT TESTED**; loop seam itself is clean (0.72 cm / 0.40 cm).
19. **LOD0 budget** — v3 84k, Nightmare 93k, Hero 90k; TD exception or decimation needed.
20. **`scripts/characters/**` ownership** — still unresolved; A06 touched only the shared LOD helper for the `lod_ignore` group.

---

## 4. Verification

### Full GUT

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

- **636/636 passed**
- 81 scripts
- 7,336 asserts
- 274.8 s
- 98 orphan nodes in one UI test — warnings, not failures.

### A06 checks

| Check | Result |
|---|---|
| `sunny_guard_validate.gd` | failed=0; v3 + Nightmare guard |
| `walk_seam_measure.gd` | 0.72 cm / 0.40 cm at 0.8–1.8 s |
| `lod_validate.gd` | failed=0; Hero mannequin has one LOD component |
| `nightmare_validate.gd` | failed=0; clips/LOD/actions/weapon |
| `location_npc_validate.gd` | failed=0; P06/P07/P08/P09/Z08 profiles |
| `sunny_combo_validate.gd` | failed=0; combo chain/reset |
| `sunny_dodge_validate.gd` | failed=0; 0.4 s clip held to 0.8 s |
| `enemy_clip_validate.gd` | failed=0; 3 enemy libraries |
| `npc_validate.gd` | failed=0; 6 prefabs + crowd |

---

## 5. Changed in Stage 7

- `scripts/slice/mannequin.gd` — Jett facing/badge, curved shoulder cape, head-bone blindfold, LOD-safe accessories.
- `scenes/characters/npc/jett.tscn` — badge accessory.
- `tools/anim/location_npc_capture.gd` — front-facing P06 Jet capture.

No A03/A05/A08/A09/A10 game files were edited.

---

## 6. Handoff

Exact requests: `docs/demo_sprint/implementation/a06_cross_agent_requests.md`.

- **A03:** P09 Julius gating, Kasper/crowd, `InductionMedic` rename, P06 yaw cleanup, city-screen check.
- **A05:** enemy hit/death integration, blade hitbox.
- **A03/A04:** capsule `sleep`, B01 `shroud`.
- **A10:** GUT coverage for NPC profiles, guard, combo, dodge, LOD, enemy libraries.
- **A00:** LOD0 exception, `scripts/characters/**` ownership, final cast generation, merge.
