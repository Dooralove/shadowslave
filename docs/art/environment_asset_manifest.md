# Environment asset manifest — A07 Stage 3

**Date:** 2026-11-03
**Scope:** post-nightmare P05–B02 overlay kit + labyrinth Z10/camp/MultiMesh pass.

## 1. Reused project assets (no new external license)

| Source | Used for | License / record |
|---|---|---|
| `assets/environments/nightmare/coral/*.glb` | B02 coral arch/clusters; labyrinth kit | Project-owned; see `docs/ASSET_LICENSES.md` |
| `assets/environments/nightmare/caravan/*.glb` | P05 supplies/chain/shackles; P06/P07/P09 dressing; Z10 camp | Project-owned; see `docs/ASSET_LICENSES.md` |
| `assets/environments/nightmare/remains/*.glb` | P05 evidence/bones | Project-owned |
| `assets/environments/nightmare/temple/*.glb` | P07 gate columns/reliefs; P08 gallery columns/reliefs | Project-owned |
| `assets/environments/nightmare/mountain/*.glb` | P06/P07/P08 snow drifts; B02 boulder | Project-owned |
| `assets/environments/nightmare/flora/*.glb` | P06 dead trees | Project-owned |
| `assets/environments/nightmare/materials/*` | PBR maps / source material recipes | Project-owned; Poly Haven CC0 where recorded |
| `assets/environments/nightmare/statue/statue_knight_colossus_lod.tscn` | B01 hero statue (A03 already instances it) | CC BY 4.0, Stone Knight; see `docs/ASSET_LICENSES.md` |
| `assets/environments/nightmare/materials/textures/p3_*.png` | decals | Project-owned |

No new external downloads or generated assets were added in this pass.

## 2. A07-owned art materials

`resources/locations/post_nightmare/materials/art_*.tres`:

- Police: `art_police_concrete`, `art_police_concrete_dark`, `art_police_tile`, `art_police_asphalt`, `art_police_paint`, `art_police_metal`, `art_police_fabric`, `art_police_mirror`.
- Academy: `art_academy_asphalt`, `art_academy_concrete`, `art_academy_wall`, `art_academy_white`, `art_academy_red`, `art_academy_metal`, `art_academy_snow`, `art_academy_glass`.
- Sleeper: `art_sleeper_tile`, `art_sleeper_wall`, `art_sleeper_dark`, `art_sleeper_metal`, `art_sleeper_fabric`, `art_sleeper_ring`.
- Black Sea: `art_b01_stone`, `art_b01_pale`, `art_b01_bronze`, `art_b01_shroud`, `art_b01_star_glow`.
- Tide descent: `art_b02_coral_live`, `art_b02_coral_pale`, `art_b02_wet_stone`, `art_b02_glow`, `art_b02_glow_dim`.
- Wood variants: `art_wood_dark`, `art_wood_light`.

All are `StandardMaterial3D` or `ORMMaterial3D` with **world triplanar** UVs for the greybox primitives. The switch avoids the `COLOR` dependency of the original `nm_*` shaders, which renders black on primitive boxes with no vertex-color layer.

## 3. Overlay scenes / profiles

- `scenes/environment/common/environment_art_overlay.gd`
- `scenes/environment/common/environment_art_profile.gd`
- `scenes/environment/common/environment_material_swap.gd`
- `scenes/environment/common/environment_art_preview.gd`
- `assets/environments/post_nightmare/environments/art_*.tres`
- `assets/environments/post_nightmare/profiles/art_*.tres`
- `scenes/environment/post_nightmare/*_art.tscn` (7 art scenes)
- `scenes/environment/post_nightmare/preview/*_preview.tscn` (7 dev previews)
- `assets/environments/post_nightmare/props/clean_*.tscn` (mesh-only copies of source props; no collision)

## 4. Verification and budgets

- Overlay validation: **7/7 scenes applied, 0 collision nodes under `ArtOverlay`**.
- Labyrinth 1920×1080, `Shots/Entrance`, 180 frames:
  - draw calls: **1361** (budget <1500; baseline 1593)
  - primitives: **4.32M** (target 2.5–3.5M; TD exception still needed)
  - average FPS: **75.1**
  - VRAM: **1236 MB**
  - shore dressing: **208 instances / 3 MultiMesh nodes**
- GUT: `test_post_nightmare_locations` 15/15 (513 asserts); `test_labyrinth_first_fragment` 13/13 (332 asserts).

## 5. Remaining / not produced

- Actual shipping-scene integration is A03-owned; see `docs/art/environment_art_integration_a03.md`.
- Z15 +25 summit / Z18 final geometry remain A03 dependencies; no A07 collision changes.
- SQ visual props (A07-11) are not placed in-game because A02/A03 POI hooks are not present in this worktree.
- `DemoEndZone` is not present in the current A03 labyrinth scene, so “camp does not block DemoEndZone” is **NOT TESTED**.

## 6. Stealth cover pilot (2026-11-03)

Pilot batch for the pilgrim path `StealthSection/Covers`: three Hyper3D-generated dark rock
covers replace the three visible `CSGBox3D` placeholders while the original CSG nodes remain as
invisible collision proxies (`visible=false`, `use_collision=true`). The art layer stays visual-only;
the route and collision footprint are unchanged.

| Asset | Replaces | Local size (m) | Tris | Material |
|---|---|---|---:|---|
| `assets/environments/nightmare/path/stealth_cover_a.glb` | `CoverWest` | 1.20 × 1.40 × 2.20 | 3 198 | `nm_rock_cover.tres` |
| `assets/environments/nightmare/path/stealth_cover_b.glb` | `CoverEast` | 1.20 × 1.40 × 2.20 | 3 199 | `nm_rock_cover.tres` |
| `assets/environments/nightmare/path/stealth_cover_c.glb` | `CoverEdge` | 1.00 × 1.20 × 1.60 | 2 599 | `nm_rock_cover.tres` |

Source: `assets/environments/nightmare/source/build_stealth_covers.py` and `stealth_covers.blend`;
raw Hyper3D GLBs are gitignored under `incoming_models/P2_environment/stealth_covers/`.
Verification: `test_pilgrim_path` 10/10, `test_full_route` 3/3, collision probe 0 failures.
Full registry and remaining batches: `docs/art/placeholder_registry.md`.
