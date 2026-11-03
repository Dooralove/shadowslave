---
name: Graphics Production
description: Use for Forgotten Shore Labyrinth graphics work — Blender coral kit, PBR materials, textures, lighting, post, and optimization. Read the G1 audit and current level brief before changing any asset.
---

# Graphics Production

## Read before acting

1. `docs/art/graphics_audit_and_tooling.md` — current visual state, gaps, stage plan.
2. `docs/design/level_brief_labyrinth_first_fragment.md` — current spatial plan (B03–B05, 18 zones, full tide cycle).
3. `docs/art/asset_production_standards.md` — Blender/GLB/material/collision rules.
4. `docs/art/tooling_inventory.md` — installed software, versions, paths, licenses.
5. `docs/art/asset_staging_manifest.md` — staged CC0 textures.
6. `docs/ASSET_LICENSES.md` — licenses; register every new asset before it enters `assets/`.

If a document conflicts with memory, the document wins. Record architectural decisions in `docs/DECISIONS.md`; do not silently change contracts.

## Ground rules

- Do **not** change gameplay geometry, routes, collisions, the player controller, or shared systems unless the user explicitly asks.
- The old `coral_labyrinth` is a **sandbox**. Do not polish its shrine/star/chairs as final art; the target is `labyrinth_first_fragment`.
- Do not delete or overwrite existing scenes, materials, or assets without explicit approval.
- No destructive Git operations. No commits unless asked.
- No secrets, tokens, `.env`, or absolute user paths in tracked configuration. Use `%ENV%` placeholders in docs.
- Text formats (`.gd`, `.tscn`, `.tres`, `.json`, `.md`) stay in plain Git; binary assets go to LFS per `.gitattributes`.
- Never claim a test/import/render passed without running it and recording the result. Use `NOT TESTED` when true.

## Installed toolchain

| Tool | Path / command | Use |
|---|---|---|
| Blender 5.1.1 | `%PROGRAMFILES%\Blender Foundation\Blender 5.1\blender.exe` | DCC, Geometry Nodes, remesh, UV, Cycles |
| Krita 5.3.4.1 | `%PROGRAMFILES%\Krita (x64)\bin\krita.exe` | 2D painting, decals, texture cleanup |
| Materialize 1.78 | `%USERPROFILE%\Tools\Materialize\Materialize.exe` | normal/AO/roughness/height from images |
| glTF-Transform 4.5.1 | `gltf-transform` | inspect, optimize, simplify, dedup, resize |
| Material Maker 1.7 | `%USERPROFILE%\Tools\MaterialMaker_1.7\...\material_maker.exe` | experimental procedural materials |
| Godot 4.7.2 | `godot` / `%USERPROFILE%\Tools\Godot\4.7.2\...` | runtime/editor |

Existing reusable pipeline:

- `assets/environments/nightmare/source/nm_lib.py` — rock/asset generators, voxel remesh, decimate, masks, collisions, GLB export, previews.
- `nm_props.py` — boxes, cylinders, lathes, tubes, chains, deformations.
- `nm_materials.py` / `make_nm_textures.py` / `make_godot_materials.py` — shared materials, textures, `.tres`.
- `build_*.py` — batch builders. For coral, add `build_coral_kit.py` rather than a new DCC.

## Production workflow

1. **Zone art bible (Stage 1).** For Z01–Z18 define silhouette, density, palette, light, and 2–3 hero objects. Use `Shots/*` and `Landmarks` anchors.
2. **Blockout is not art.** Keep `Generated/Collision`; replace visuals in `Generated/Visual/Zxx` or `Art/Final`; hero meshes in `Landmarks`.
3. **Coral kit.** Build 25–40 modules with Python/bmesh + Geometry Nodes:
   - merged masses, blades, arches, tunnels, pillars, fans, brain coral, rubble;
   - LOD0/1/2; simple collision; UV-box; vertex masks; GLB export.
4. **Materials.** Start from `nm_layered_triplanar.gdshader`; create a coral variant with tip gradient, wetness, SSS and `nm_mask` AO. Use Poly Haven `coral_ground_02`, `coral_gravel`, `coral_mud_01` only as substrate; organic red coral must be authored/baked.
5. **Tide.** `water_tide` shader: depth tint, foam at the edge, normal ripples, reflections. Wet line at +4 m, low routes close at high water.
6. **Light/atmosphere.** East pale side light; centre grey + warm sunset spots; west dark blue/storm. `env_coral`, `env_labyrinth_west`, `env_storm`; volumetric fog, god rays, reflection probes, SSAO/SSIL, AgX.
7. **Set dressing.** Carcass Z02, bones Z05–Z06, camp Z10, bone bridge Z14, refuge Z15, pack/storm/cliffs Z16–Z18. Only canon; no shrine/altar/star/chairs.
8. **Optimize.** `VisibilityEnabler3D` per zone, `OccluderInstance3D` on masses, `MultiMesh` for bones/blades, LOD, glTF-Transform. Budget: 1080p 60 FPS, draw calls <1500 with culling, triangles 2.5–3.5M, VRAM <4 GB.

## Useful commands

```powershell
# Build a future coral kit
& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  --background --factory-startup `
  --python assets/environments/nightmare/source/build_coral_kit.py -- --test

# Inspect/optimize a GLB
gltf-transform inspect assets/environments/nightmare/coral/coral_mass_a.glb
gltf-transform optimize input.glb output.glb --compress false

# Project import check
godot --headless --path . --import

# Read-only scene captures/stats
godot --path . -s tools/audit/location_capture.gd -- --out="$env:TEMP/opencode/shots_coral"
godot --path . -s tools/audit/scene_stats.gd
godot --headless --path . -s tools/audit/resource_check.gd
```

## Acceptance

- Silhouette reads without textures; not a “red forest”, not a “corridor maze”.
- No flat untextured surfaces in close-up; no plastic coral.
- Tide visibly changes the space; storm reads as a different act.
- No mandatory jump/climb/swim; route/landmarks readable without a mini-map.
- `boundary_audit` = 0 deadly edges; GUT/import results reported honestly.
- `docs/art/location_asset_matrix.md`, `docs/ASSET_LICENSES.md`, `docs/DECISIONS.md` updated when relevant.
