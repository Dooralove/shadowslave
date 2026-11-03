# Armor stats, generated sets and loot — 2026-11-03

**Status:** alpha / vertical slice.  
**Scope:** `EquipmentComponent`, `ArmorItem`/`ArmorStats`, `CharacterStats`, physical loot and `LootContainer`.  
**Demo:** `scenes/dev/equipment_loot_demo.tscn`.  
**Capture:** `tools/audit/armor_sets_capture.gd`.

## 1. What is implemented

### 1.1 Armor data

- `ArmorItem` (`scripts/equipment/armor_item.gd`) extends `ArmorSetData`. It keeps the
  existing shared-skeleton visual path and adds:
  - `stats: ArmorStats`;
  - rarity, set id, required strength, description/lore and rarity colour.
- `ArmorStats` (`scripts/equipment/armor_stats.gd`) stores:
  - armor value, weight, impact bonus, stagger resistance;
  - typed damage resistances (`physical`, `slash`, `pierce`, `blunt`, `fire`, `cold`, `shadow`);
  - movement/stamina multipliers;
  - explicit passive buffs, passive debuffs and neutral modifiers.
- `StatModifier` (`scripts/stats/stat_modifier.gd`) supports ADD, PERCENT and MULTIPLY.
  Negative ADD/PERCENT or MULTIPLY < 1 is a debuff.

### 1.2 Applying stats to the character

`CharacterStats` (`scripts/stats/character_stats.gd`) is the single aggregator. It
receives the current `EquipmentLoadout` from `EquipmentComponent` after every rebuild
and computes:

- armor -> `damage_reduction = armor / (armor + 100)`;
- weight -> encumbrance ratio and speed penalty after the threshold;
- impact -> `MeleeAttack.damage_bonus`;
- stagger resistance -> `CombatController` guard-break duration;
- move/stamina multipliers -> `CombatController.get_move_speed_multiplier()` and the
  exposed stamina value;
- max-health modifiers -> `HealthComponent.set_max_health_preserving_ratio()`;
- resistances -> `HealthComponent.damage_resistances`.

The application is reversible: unequipping the body calls `rebuild()`, `CharacterStats`
recomputes from base values, and the player returns to the unarmoured numbers. This is
covered by `test_demo_equip_applies_and_removes_stats_on_player`.

`EquipmentComponent.persist_to_run_state` stores only item IDs in
`NightmareRunState` and restores them through `apply_ids()`; visuals are always
rebuilt from the catalog. The demo enables this path. It is covered by
`test_equipment_ids_persist_in_run_state`.

`InventoryComponent.persist_to_run_state` stores stacks in
`NightmareRunState.inventory` (separate from campaign `items`), so the demo
inventory survives a snapshot/restore round-trip. It is covered by
`test_demo_inventory_persists_stacks`.

Damage types are passed from `AttackStats.damage_type` through
`MeleeAttack.apply_hit()` -> `Hurtbox.receive_hit()` -> `HealthComponent.take_damage()`.
Existing attacks now declare `slash`, `pierce` or `blunt`; the default remains
`physical`, so old resources keep working.

### 1.3 Weapon stow / draw

`WeaponData` has a grip socket and a sheath socket. `EquipmentComponent` moves the same
weapon visual between `hand_r` and `hips`/`back` instead of creating a second copy.
`set_weapon_drawn(false)` puts it on the belt and keeps it visible; if the sheath socket
does not exist, the weapon hides instead of failing the whole equip.

### 1.4 Loot

- `LootEntry` / `LootTable` (`scripts/loot/`): chance, weight, min/max quantity,
  guaranteed entries, optional flag conditions and a drop cap.
- `LootDropComponent`: listens to `HealthComponent.died`, rolls the table, and spawns
  physical `WorldLootItem` nodes with a small outward/upward impulse.
- `WorldLootItem`: `RigidBody3D` with a glowing gem, rarity colour, label, `Interactable`
  child and optional auto-pickup `Area3D`. Picking it up writes to `InventoryComponent`;
  if no inventory exists, it falls back to `NightmareRunState.add_item(id, count)`.
- `InventoryComponent`: ID-based stacks, capacity, add/remove, `to_ids()`/`from_ids()`.
- `LootContainer`: extends `Interactable`; opens by the `interact` action, rolls the
  table once, grants all items, supports a one-shot mode, and falls back to
  `NightmareRunState` when there is no demo inventory.

The campaign's generic loot layer (`LootPool`, `LootPoolEntry`, `LootItemData`,
`LootPoolRoller`, `LootCache`, `LootDropper`) is intentionally kept. It serves currency,
materials, consumables and Memories through `NightmareRunState`; the equipment layer
above serves `EquipmentItemData`, physical pickups and the equipment demo. The two
layers are separate, not competing implementations.

### 1.5 LOD, materials and head weights

- Each generated set is one GLB with `model_LOD0`, `model_LOD1` and
  `model_LOD2`. `EquipmentComponent` drives `visibility_range_begin/end`:
  LOD0 0–8 m, LOD1 8–18 m, LOD2 18 m+ (0.5 m margins). No second skeleton
  and no extra animation player.
- The metallic-roughness map splits the outfit into cloth (double-sided) and
  plate (single-sided) materials. Heavy has no cloth slot; Scout and Mercenary
  keep both.
- Scout's hood region is overridden to 100% `Head` weight; without it the hood
  lagged behind the face on head turns. Helmets already follow `Head`.
- Pose captures are in `docs/art/previews/equipment/pose_*`. Head turn and
  death/dodge read correctly; the boxing attack (`HumanSpBoxing`) still clips
  large pauldrons/cloak — this is an animation-content limitation, not a
  missing weight override.

## 2. Generated armour sets

| ID | Name | Armor | Weight | Impact | Resistances | Passive |
|---|---|---:|---:|---:|---|---|
| `scout_leather` | Доспех разведчика | 18 | 6.5 kg | +1.0 | physical 5%, slash 8%, pierce 2%, cold 5% | +4% speed, +8% stamina regen, -5 max health |
| `mercenary_medium` | Доспех наёмника | 32 | 13.0 kg | +2.0 | physical 10%, slash 12%, pierce 8%, fire 3% | +5 max health, +5% stagger; x0.97 speed, x0.97 stamina |
| `heavy_plate` | Тяжёлые латы | 55 | 24.0 kg | +3.5 | physical 18%, slash 22%, pierce 15%, fire 8%, cold 10% | +15 max health, +5% stagger; x0.86 speed, x0.85 stamina |

Runtime files:

- `assets/characters/equipment/armor/scout_leather.glb` — LOD0 59,457 / LOD1 26,754 /
  LOD2 10,702 tri; 52 bones; 1K PBR; cloth + plate materials.
- `assets/characters/equipment/armor/mercenary_medium.glb` — LOD0 58,458 / LOD1 26,306 /
  LOD2 10,522 tri; 52 bones; 1K PBR; cloth + plate materials. Local height
  1.760 m; `mercenary_medium.tres` uses `visual_scale.y = 1.0793` to match the
  1.900 m base.
- `assets/characters/equipment/armor/heavy_plate.glb` — LOD0 60,000 / LOD1 27,000 /
  LOD2 10,799 tri; 52 bones; 1K PBR; plate only.

Data:

- `resources/equipment/armor/scout_leather.tres`, `mercenary_medium.tres`,
  `heavy_plate.tres`;
- `resources/equipment/stats/*_stats.tres`;
- `resources/equipment/catalog_alpha.tres` (all three added);
- `resources/equipment/loadouts/demo_loadout.tres`;
- `resources/loot/demo_loot.tres`.

Coverage rules:

- scout keeps the base head surface (`hide_surfaces = [1,2,3]`) so the face is visible
  inside the hood;
- mercenary and heavy hide the base head as well (`[0,1,2,3]`) because their helmets
  are closed.

## 3. Asset pipeline

1. **Hyper3D CLI text-to-3D.** Prompts describe a complete outfit on an invisible
   mannequin, A-pose, no weapons. Generation IDs:
   - scout `d3a04960-d300-40f7-9632-4902df14d0ec`;
   - mercenary `fedeb263-cf19-4eca-b225-ebd980bd06a6`;
   - heavy `18d9b4bb-ca0d-45ec-a04d-51dabd958102`.
2. **Hyper3D rigging.** `--bone-template human --skinning-method core`:
   - scout `cdddc84f-2ab0-4310-9941-0280c4cd24b6`;
   - mercenary `38d6f2cc-71a6-4b48-bf00-1692db2a49a2`;
   - heavy `49ebaa26-44a9-4b27-af8e-6f3ac740ec9b`.
3. **Head cleanup.** `assets/characters/equipment/source/prepare_generated_armor.py`
   removes the blank mannequin head island (the generated outfit otherwise shows a
   featureless face inside the hood/helmet). The island is selected by its head-like
   bounding box, not by vertex index.
4. **Re-bind to the base skeleton.** `rebind_generated_armor.py` imports the
   `sunny_nightmare_v2` body and the generated armour, transfers the body's vertex
   weights to the armour with a Blender Data Transfer modifier, limits influences to
   four, normalises them, binds the armour to the *base* armature and exports a new GLB.
   This is required because the Hyper3D human template has different bone rest lengths;
   a plain `Skin` remap compresses the armour.
5. **Cloth/plate split.** `split_armor_materials.py` samples the metallic channel
   and assigns metal faces a single-sided plate material; cloth stays double-sided.
6. **Head weights.** `fix_armor_head_weights.py` assigns the Scout hood region to
   `Head` 100%. A rigid-plate experiment (`rigidify_armor_plates.py`) was evaluated
   and rejected: it separated plates in the boxing guard instead of fixing them.
7. **LOD build.** `build_armor_lods.py` duplicates the split mesh, decimates LOD1/2
   and exports all three skinned meshes into one GLB.
8. **Texture budget.** `gltf-transform resize --width 1024 --height 1024` on each set.
9. **Import.** `godot --headless --path . --import` exits 0.

Raw generations and rigs remain in `incoming_models/P2_equipment/` (gitignored).

## 4. Demo

`scenes/dev/equipment_loot_demo.tscn` contains a playable Sunny, the three sets, a
training dummy with `LootDropComponent`, a `LootContainer` chest, an inventory and a
stats panel.

Controls:

- `1` / `2` / `3` — equip scout / mercenary / heavy;
- `4` — draw or stow the sword;
- `5` — kill the dummy (physical loot spawns);
- `6` — open the chest;
- `7` — spawn a test heavy-armour drop at the player;
- `8` — clear inventory;
- `R` — reset dummy, chest, inventory and equipment.

The demo uses `rng_seed = 7` so the captures deterministically show the scout armour and the water flask.

Capture:

```powershell
godot --path . -s tools/audit/armor_sets_capture.gd -- --out="$env:TEMP/opencode/armor_sets"
```

The capture produces `armor_scout.png`, `armor_mercenary.png`, `armor_heavy.png`,
`weapon_stowed.png`, `stats_heavy.png`, `loot_drop.png` and `container_open.png`.

LOD and pose checks:

```powershell
godot --path . -s tools/audit/armor_lod_capture.gd -- --out="$env:TEMP/opencode/armor_lod"
godot --path . -s tools/audit/armor_pose_capture.gd -- --out="$env:TEMP/opencode/armor_poses"
```

### Captures

![Scout leather](art/previews/equipment/armor_scout.png)

![Mercenary medium](art/previews/equipment/armor_mercenary.png)

![Heavy plate](art/previews/equipment/armor_heavy.png)

![Weapon stowed on the hip](art/previews/equipment/weapon_stowed.png)

![Heavy armour stats](art/previews/equipment/stats_heavy.png)

![Physical loot drop](art/previews/equipment/loot_drop.png)

![Container grant](art/previews/equipment/container_open.png)

![LOD 2 m](art/previews/equipment/lod_02m.png)

![LOD 10 m](art/previews/equipment/lod_10m.png)

![LOD 20 m](art/previews/equipment/lod_20m.png)

![Scout head turn](art/previews/equipment/pose_scout_head_turn.png)

![Scout attack clipping](art/previews/equipment/pose_scout_attack.png)

![Heavy attack clipping](art/previews/equipment/pose_heavy_attack.png)

## 5. Verification

| Check | Result |
|---|---|
| Headless import | exit 0 |
| `test_armor_stats_loot.gd` | 20/20, 88 asserts, all passed |
| `test_equipment_alpha.gd` | 11/11, 46 asserts, all passed |
| `test_combat_arena.gd` | 6/6, 19 asserts, all passed |
| `test_carapace_enemy.gd` | 10/10, 45 asserts, all passed |
| Full GUT | 717/717, 7,849 asserts, exit 0 |
| LOD capture | 2 / 10 / 20 m, LOD0→LOD1→LOD2 visible |
| Pose capture | attack / dodge / death / head turn, 1600×900 |
| Equipment ID persistence | covered by `test_equipment_ids_persist_in_run_state` |
| Demo inventory persistence | covered by `test_demo_inventory_persists_stacks` |
| Manual playthrough | **NOT TESTED** |
| 1080p / 60 FPS with three sets | **NOT TESTED** |

## 6. Limitations

- The sets are generated alpha assets: 1K textures, LOD0/1/2, no collision, no
  cloth/rigid-plate simulation. They are not final art.
- The boxing attack (`HumanSpBoxing`) clips large pauldrons and the cloak into the
  head. A sword-swing clip or separated pauldron meshes is required; automatic
  rigidification was tested and rejected because plates separated.
- Scout's hood is tight around the base head; the head-turn capture is acceptable,
  but extreme head/arm poses still touch the hood opening.
- The head-island removal is heuristic. A future asset should be generated without a
  mannequin head, or authored as separate helmet/hood pieces.
- Equipment IDs and demo inventory stacks are persisted in `NightmareRunState`;
  there is still no inventory UI bridge or full campaign save round-trip for stacks.
- The campaign's `LootCache`/`LootDropper` layer remains the canonical run-state loot
  path; this document does not replace it.
- The three sets use the `generated_v3` 52-bone profile only. P1/UAL and real-v3 armor
  variants are not built.

## 7. Audit

- `docs/equipment_armor_loot_audit.md` — findings, evidence and residual risks.
  Fixed during audit: stale HUD HP on max-health change, non-atomic inventory load,
  `apply_ids()` bypassing rig validation, armour LOD toggling, LOD1/2, cloth/plate
  materials, Scout hood weights, equipment ID persistence and demo inventory stacks.
  Open: boxing-attack pauldron/cloak clipping, manual playthrough and 1080p/60 FPS.
