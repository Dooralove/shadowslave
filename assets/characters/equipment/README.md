# Equipment Alpha Assets

The folder contains project-owned blockout armour and one alpha sword-attack
clip for Sunny.

## First checkout

Textures are Git LFS objects. After cloning:

```powershell
git lfs install
git lfs pull
git lfs checkout
py tools/audit/check_equipment_lfs.py
```

The checker fails if any equipment PNG/JPEG is still an LFS pointer.

## Armour sets

- `armor/caravan_alpha.glb`, `armor/coral_alpha.glb` — nightmare v2 (52 bones).
- `armor/caravan_alpha_p1.glb`, `armor/coral_alpha_p1.glb` — P1/UAL (53 bones).
- `armor/caravan_alpha_v3.glb`, `armor/coral_alpha_v3.glb` — generated v3 split (52 bones).
- `armor/sunny_real_v3_base.glb` — exposed-skin/hair base for the v3 split.
  This is an alpha split: the armour is required to cover torso and limbs.

Each armour GLB has LOD0/LOD1/LOD2 meshes. The LOD copies are generated with
Blender Decimate and switched by `EquipmentComponent` at 10 m / 22 m.

## Build

```powershell
& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  -b --factory-startup `
  --python assets/characters/equipment/source/build_caravan_alpha.py -- --preview

& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  -b --factory-startup `
  --python assets/characters/equipment/source/build_p1_alpha.py

& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  -b --factory-startup `
  --python assets/characters/equipment/source/build_real_v3_split.py

& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  -b --factory-startup `
  --python assets/characters/equipment/source/build_v3_sword_attack.py
```

Materials reuse the registered Poly Haven CC0 sets `brown_leather` and
`rust_coarse_01`; Godot extracts the texture files next to the GLBs.

`animations/sunny_v3_sword_attack.glb` is a UAL `Sword_Attack` upper-body
retarget for the v3 skeleton. It is an alpha placeholder, not production
animation.

The original `sunny_nightmare_v2.glb` is not modified. The armour is an alpha
OVERLAY: the component hides surfaces 1-3 of the base mesh while equipped and
restores them on unequip.

This is not production art: no LODs, no final normals, no texture atlas, and
the rigid plates are blockout shapes. Use it to validate the equipment layer
and A/B silhouettes, not as a shipping set.

## Generated sets (2026-11-03)

`armor/scout_leather.glb`, `mercenary_medium.glb` and `heavy_plate.glb` are
Hyper3D text-to-3D outfits, rigged with the human/core template, then re-bound
to the `sunny_nightmare_v2` 52-bone armature.

Pipeline:

```powershell
# 1. Remove the blank mannequin head island.
& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  -b --factory-startup `
  --python assets/characters/equipment/source/prepare_generated_armor.py -- `
  --input incoming_models/P2_equipment/scout_leather_rigged.glb `
  --output "$env:TEMP/opencode/scout_leather.glb" --delete-head

# 2. Transfer the base body weights and bind to the base armature.
& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  -b --factory-startup `
  --python assets/characters/equipment/source/rebind_generated_armor.py -- `
  --base assets/characters/generated/sunny_nightmare_v2/sunny_nightmare_v2.glb `
  --armor "$env:TEMP/opencode/scout_leather.glb" `
  --output "$env:TEMP/opencode/scout_rebound.glb"

# 3. Split cloth (double-sided) and plate (single-sided) materials.
& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  -b --factory-startup `
  --python assets/characters/equipment/source/split_armor_materials.py -- `
  --input "$env:TEMP/opencode/scout_rebound.glb" `
  --output "$env:TEMP/opencode/scout_split.glb"

# 4. Scout only: make the hood follow the Head bone.
& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  -b --factory-startup `
  --python assets/characters/equipment/source/fix_armor_head_weights.py -- `
  --input "$env:TEMP/opencode/scout_split.glb" `
  --output "$env:TEMP/opencode/scout_head.glb" --radius 0.24 --z-margin 0.08

# 5. Build LOD0/1/2 into one skinned GLB.
& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  -b --factory-startup `
  --python assets/characters/equipment/source/build_armor_lods.py -- `
  --input "$env:TEMP/opencode/scout_head.glb" `
  --output assets/characters/equipment/armor/scout_leather.glb
```

The re-bind is required because the Hyper3D human template has different bone
rest lengths; a plain `Skin` remap compresses the outfit. The generated sets
have LOD0/1/2 and split cloth/plate materials; the alpha blockout sets
(`caravan_alpha`, `coral_alpha`) still have no LODs. Textures are resized to
1024 with glTF-Transform. Runtime data lives in
`resources/equipment/armor/*.tres` and `resources/equipment/stats/*_stats.tres`;
see `docs/equipment_armor_loot.md` for stats, loot and the demo.

## P1/UAL and v3 split alpha sets

- `armor/caravan_alpha_p1.glb`, `coral_alpha_p1.glb` — P1 53-bone UAL proof.
- `armor/caravan_alpha_v3.glb`, `coral_alpha_v3.glb` — generated v3 split.
- `armor/sunny_real_v3_base.glb` — full-silhouette v3 base: original skin/hair
  plus a neutral underlayer for clothing islands. The armour covers the
  underlayer; without armour it is still an alpha body, not final art.
- `animations/sunny_v3_sword_attack.glb` — UAL `Sword_Attack` upper-body retarget
  for v3, injected by `SunnyV3Model` as `Sword_Attack`.

Build scripts: `build_p1_alpha.py`, `build_real_v3_split.py`,
`build_v3_sword_attack.py`. Dev scenes: `equipment_lab_p1.tscn`,
`equipment_lab_v3.tscn`.
