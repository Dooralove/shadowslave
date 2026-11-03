---
name: Texture Toolchain
description: Use when authoring or processing PBR textures with Krita, Materialize, and glTF-Transform — coral/mud/bone maps, decals, tiling, channel packing, and Godot import checks.
---

# Texture Toolchain

## When to use

- Turning a diffuse/photo into normal/AO/roughness/height maps.
- Painting coral tips, blue blood, mud, barnacle decals, or fixing seams.
- Preparing 2K/1K texture sets for Godot `.tres` materials.
- Inspecting/optimizing GLB texture payloads before import.

For Blender coral geometry, use `graphics-production` instead.

## Tools

| Tool | Path / command | Role |
|---|---|---|
| Krita 5.3.4.1 | `%PROGRAMFILES%\Krita (x64)\bin\krita.exe` | 2D paint, decals, masks, cleanup |
| Materialize 1.78 | `%USERPROFILE%\Tools\Materialize\Materialize.exe` | diffuse/height → PBR maps |
| glTF-Transform 4.5.1 | `gltf-transform` | inspect/optimize/resize GLB textures |
| Python 3.13 + Pillow/OpenCV/numpy | `python` | tiling, channel packing, batch ops |
| Blender 5.1.1 Cycles | `%PROGRAMFILES%\Blender Foundation\Blender 5.1\blender.exe` | bake high-poly detail to low-poly |

## Pipeline

1. **Source and license.**
   - Prefer CC0 Poly Haven staged sets (`docs/art/asset_staging_manifest.md`).
   - If using non-CC0, record author/license/URL in `docs/ASSET_LICENSES.md` before importing.
   - Do not put the source photo/asset into `assets/` without a recorded license.
2. **Materialize.**
   - Load diffuse or height.
   - Generate height → normal, AO, roughness, metallic, edge.
   - Keep normal strength moderate (0.5–1.0); over-strong normals look like plastic.
   - Export PNG/TGA 2K for walls/floors, 1K for props.
3. **Krita.**
   - Work in sRGB for albedo; keep masks/roughness linear.
   - Use wrap-around tiling for seamless textures.
   - Paint coral tip gradient, wet edges, blue blood, mud tracks, barnacle clusters.
   - Export clean PNGs; keep source `.kra` in LFS if committed (`.kra` is LFS).
4. **Channel packing.**
   - Godot ORM convention: R=AO, G=roughness, B=metallic.
   - Use Python/Pillow to pack; do not rely on visual inspection alone.
5. **Godot import.**
   - Albedo: sRGB; normal: `hint_normal` / RGTC; ORM: linear, no sRGB.
   - 2K for large surfaces, 1K for props; enable VRAM compression for desktop.
   - Create/update `.tres` via the existing `make_godot_materials.py` pattern, not ad-hoc duplicates.
6. **Validate.**
   - `godot --headless --path . --import` → exit 0.
   - Render a close-up in Godot; check tiling, roughness response, normal seams.
   - Record result; `NOT TESTED` if not run.

## Commands

```powershell
# Materialize GUI
& "$env:USERPROFILE\Tools\Materialize\Materialize.exe"

# Krita
& "$env:PROGRAMFILES\Krita (x64)\bin\krita.exe"

# GLB texture inspection/optimization
gltf-transform inspect path\to\asset.glb
gltf-transform resize --width 2048 --height 2048 input.glb output.glb
gltf-transform optimize input.glb output.glb --compress false

# Project import
godot --headless --path . --import
```

## Guardrails

- No AI-generated final PBR maps without cleanup, tiling, and normal/AO validation.
- No 4K/8K textures on background assets; budget VRAM (<3 GB total).
- No absolute paths or secrets in tracked materials/docs.
- Do not overwrite existing `.tres`/textures without approval; prefer new names and a migration note.
- Every external texture set gets a row in `docs/ASSET_LICENSES.md`.
- Do not claim a material is finished from the Materialize preview alone; check it in Godot.
