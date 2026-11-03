# Vitals HUD — coral reliquary sprite kit (2026-11-03)

**Purpose:** a modular, Witcher-3-inspired player health/stamina HUD for the
Forgotten Shore / ShadowSlave palette: aged bronze and bone, dark crimson coral,
black-blue abyss plate, azure memory light.

**Status:** implemented in `CombatHud`; targeted GUT and a 1600×900 capture run
pass. Manual playthrough / 1080p performance are **NOT TESTED**.

## 1. Why the source is 3D and the output is 2D

The project’s approved image CLI is **Hyper3D CLI** (`@hyper3d/cli`, Rodin
Gen-2.5). It generates GLB reliefs, not flat PNGs. The 2D sprites therefore come
from an orthographic Blender render of those reliefs:

```
Hyper3D CLI prompt -> GLB relief -> Blender orthographic front render (alpha)
-> trim/resize -> Godot TextureRect layers
```

This keeps the silhouette clean and gives the UI real PBR metal/bone/coral
lighting without perspective. The raw GLBs stay in `incoming_models/P3_ui/`
(gitignored); they are not shipped.

## 2. Hyper3D prompts

### Frame

```
Flat horizontal fantasy UI frame relief for a health bar, wide ornate
reliquary frame, aged bronze and bone, crimson coral branches growing from both
ends, small shell inlays, open empty center, perfectly symmetrical, front view,
shallow relief, no perspective, no background, orthographic 2D game UI sprite,
clean silhouette, 4:1 wide composition
```

- Generation ID: `442c7ad3-b6bf-4080-8d74-c4e2b6fcb8c3`
- Raw file: `incoming_models/P3_ui/hp_frame_raw.glb`
- Tier/mode: `Gen-2.5-Medium`, `Quad`, 8,000 target polygons.

### Medallion

```
Flat circular medallion relief for a fantasy health HUD, ornate nautilus shell
framed by branching crimson coral, aged bone ring, small barnacles, front view,
shallow relief, symmetrical, no chain, no background, orthographic 2D game UI
sprite, clean silhouette, 1:1 composition
```

- Generation ID: `8ae8e4d8-3993-4d8e-a827-6ec86dd7399a`
- Raw file: `incoming_models/P3_ui/hp_medallion_raw.glb`
- Tier/mode: `Gen-2.5-Medium`, `Quad`, 6,000 target polygons.

### Reproduction commands

```powershell
hyper3d generate --prompt "<frame prompt>" --tier Gen-2.5-Medium --mesh-mode Quad --quality 8000 --format glb --output json
hyper3d poll <generation-id> --timeout 180 --output json
hyper3d result <generation-id> --output json
# download the base_basic_pbr.glb URL to incoming_models/P3_ui/

& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" --background --factory-startup `
  --python tools/art/render_ui_props.py -- `
  --input incoming_models/P3_ui/hp_frame_raw.glb `
  --output assets/ui/vitals/source/hp_frame_wide_render.png `
  --width 2048 --height 512 --scale-x 1.65 --samples 96

& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" --background --factory-startup `
  --python tools/art/render_ui_props.py -- `
  --input incoming_models/P3_ui/hp_medallion_raw.glb `
  --output assets/ui/vitals/source/hp_medallion_render.png `
  --width 1024 --height 1024 --samples 96

python tools/art/finalize_vitals_sprites.py
python tools/art/generate_vitals_textures.py --out assets/ui/vitals
```

## 3. Sprite kit

| File | Size | Role | Source |
|---|---:|---|---|
| `assets/ui/vitals/hp_frame.png` | 1536×377 | Bronze/bone/coral frame, transparent window | Hyper3D + Blender render, recolored |
| `assets/ui/vitals/hp_medallion.png` | 512×512 | Nautilus/coral amulet, transparent center | Hyper3D + Blender render, recolored |
| `assets/ui/vitals/hp_fill.png` | 1024×128 | Grayscale organic fill, tinted per health state | `generate_vitals_textures.py` |
| `assets/ui/vitals/hp_plate.png` | 1024×256 | Dark abyss plate behind the fill | `generate_vitals_textures.py` |
| `assets/ui/vitals/hp_glow.png` | 512×512 | Radial azure/bone glow for medallion core and bar | `generate_vitals_textures.py` |
| `assets/ui/vitals/hp_shine.png` | 1024×128 | Soft moving gloss overlay | `generate_vitals_textures.py` |
| `assets/ui/vitals/hp_notch.png` | 64×128 | Bone divider studs across the bar | `generate_vitals_textures.py` |

`assets/ui/vitals/source/hp_frame_render.png` is the earlier 2.5:1 frame
render, kept as an alternate source; the scene uses the 4:1
`hp_frame_wide_render.png` version.

The fill is deliberately grayscale: `VitalsBar` tints it with the healthy /
wounded / critical palette. This keeps one texture for all three states.

## 4. Art direction

- The frame is a **reliquary**, not a modern rectangle: coral grows out of the
  ends, the shell crest sits top and bottom, the metal is bone/bronze.
- Coral is shifted from the generator’s pink to the project’s dark crimson
  (`#4a1c22`–`#8c4a4a` family) in `finalize_vitals_sprites.py`.
- The fill sits inside the window; the frame is drawn above it so the metal
  always wins the silhouette.
- The medallion’s empty nautilus center holds a small azure glow — the
  “memory light” — which pulses on damage and at critical health.
- The low-health vignette is a separate full-screen shader, not part of the bar.

## 5. Integration

| File | Role |
|---|---|
| `scenes/ui/vitals_bar.tscn` | Layered bar: glow, plate, ghost, fill, shine, notches, frame, medallion, labels |
| `scripts/ui/vitals_bar.gd` | Presentation: widths, colors, flash, medallion pulse, status text |
| `scripts/ui/vitals_display.gd` | Pure math: frame-rate independent smoothing, ghost trail, flash decay |
| `scripts/ui/combat_hud.gd` | Existing owner of `HealthComponent`/`StaminaComponent`; forwards values |
| `scenes/ui/combat_hud.tscn` | `VitalsBar` inside `PlayerPanel`; full-screen vignette child |
| `assets/ui/vitals/vitals_vignette.gdshader` | Low-health screen-edge tint |
| `tests/test_vitals_hud.gd` | Display-model and integration tests |

`CombatHud` remains the single HUD owner. No second HUD, no new autoload, and
`HealthComponent` is unchanged. The bar is 360×130 at the bottom-left; its right
edge stops at x=380, where the subtitle panel begins, so the two do not overlap.

Previews: `docs/art/previews/vitals/vitals_full.png`,
`vitals_wounded.png`, `vitals_critical.png` (1600×900, captured over the
coral-labyrinth audit frame), and `vitals_sprite_kit.png` (contact sheet).

## 6. Verification

```powershell
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_vitals_hud.gd -gexit
godot --path . -s tools/audit/vitals_hud_capture.gd -- --out=<folder>
```

Results from this pass:

- Headless import: exit 0.
- `test_vitals_hud`: 6/6 tests, exit 0.
- `test_combat_hud`: 2/2 tests, 6 asserts, exit 0.
- Full GUT: 83 scripts, 656/656 tests, 7,424 asserts; output reports
  `All tests passed`.
- Capture: `vitals_full.png`, `vitals_wounded.png` and `vitals_critical.png` at
  1600×900.
- Manual gameplay, 1080p/60 FPS and controller readability: **NOT TESTED**.

## 7. License

- `hp_frame.png`, `hp_medallion.png`: project-owned outputs generated with the
  project’s Hyper3D account. Verify the current Hyper3D terms before release.
- All other sprites and the shader: project-owned procedural content, no external
  source, no third-party license.
- Raw GLBs are gitignored and are not shipped.
