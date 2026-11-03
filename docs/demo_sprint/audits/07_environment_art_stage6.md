# 07 Environment Art — Stage 6 deep audit

**Date:** 2026-11-03
**Branch:** `demo/environment`
**Base:** `ee97325`
**Scope:** A07 Environment Art; comparison of Master Audit, design package, AGENT_TASKS, original Stage 1 files, Stage 3–5 commit `4a7a2f0`, and current runtime.

## 1. Master Audit comparison

| Master Audit gap | Stage 6 result |
|---|---|
| Z15/Z18 “scaffold, not hero” | **Partial.** Added Z15 edge ledges/overhang and Z18 ledge/sea-stack silhouettes. +25 summit and final platform remain A03 geometry; hero rebuild not possible without A03 changes. |
| Z02/Z13 “placeholder, not hero” | **Partial.** Z02 carcass has rib cage, oversized skull, bone debris and azure decals; Z13 skeleton already used the Stage 1 spine/rib kit. No new GLB/LOD assets were authorized. |
| Decals missing | **Closed for available textures.** 6 named types across Z02/Z03/Z08/Z10/Z13/Z14: azure blood, footprints, chain scrape, wet trail, wet drag, claw mark. |
| Draw calls 1593 > 1500 | **Closed.** 1361 draw calls at 1920×1080 `Shots/Entrance`, 180 frames. |
| Algae/rocks/shells no MultiMesh | **Closed.** 208 shore instances in 3 MultiMesh nodes; no physics. |
| P05–B02 greybox | **A07-side closed.** Full overlay kit, 7 art scenes, 7 preview wrappers, 35 PBR materials. Shipping scenes are A03-owned and still do not instance the overlay. |
| Z10 end zone / camp | **A07-side closed.** Camp props moved outside A03 `DemoEndZone` r=4; clearance test 0 offenders. Actual trigger/finale flow after merge NOT TESTED. |

## 2. Stage 6 fixes

- P05: mirror panel/frame on the visible wall, reflection probe, yard moon fill, mirror readability.
- P06: checkpoint interior warm light + three emissive guide strips so the checkpoint opening is readable at night.
- P07: red gate trim in front of the tower faces; relief panels; gate flood/star lights.
- P08: stone gallery columns/reliefs; muted academic screen material; evening wash.
- P09: pale metal capsule bodies + pale-blue emissive lids; 12 capsules read as capsules rather than black boxes.
- B01: two tattered shroud panels with fold normals, echo stars, bronze/stone materials.
- B02: coral arch/clusters, wet stone, warm coral glow replacing cyan, stair path lights + guide strips.
- Z02/Z13/Z15/Z18: larger carcass skull, decals, ledge/sea-stack silhouettes.
- Z10: meat rack, rope coil, crate, sack, firewood, water flask, barrel; pillar reduced and moved to the edge; campfire remains the only camp prop inside the A03 end-zone sphere.
- Labyrinth: MultiMesh seabed/horizon/far cliffs/Z14 and 208-instance shore dressing; no collision added.

## 3. Runtime / dependency audit

- **Parsing/import:** `godot --headless --path . --import` — no parse/import errors.
- **Scenes:** all 7 preview wrappers instantiate; direct-parent `ArtOverlay` test applies on all 7.
- **Signals:** overlay only connects to `GreyboxLocation.layout_built`; no new gameplay signals.
- **Save/load:** art layer owns no persistent state and writes no save data. Reload applies the profile again; no stale runtime state.
- **Interactions:** art scenes add no `Interactable`, collision, spawn, portal or trigger. P05 mirror remains the A03 interactable.
- **Transitions:** no route/portal changes. A03 integration remains the only way the art reaches shipping scenes.
- **Edge cases:** overlay applies immediately if `Generated` already exists; otherwise waits for `layout_built`; direct-parent and preview `host_path` paths both tested.
- **A03 dependency:** `demo-03` now contains `DemoEndZone`/`CampNight`, but still has no `ArtOverlay` node in post-nightmare scenes. Exact patch in `docs/art/environment_art_integration_a03.md`.

## 4. Verification

| Check | Result |
|---|---|
| Overlay validation, 7 previews | **7/7 applied, art_collision=0, failures=0** |
| Direct-parent overlay P05–B02 | **7/7 applied, failures=0** |
| Z10 end-zone clearance (A03 coords) | **0 offenders; only campfire inside** |
| Labyrinth shore dressing | **208 instances / 3 MultiMesh / no physics** |
| `test_post_nightmare_locations.gd` | **15/15, 513 asserts** |
| `test_labyrinth_first_fragment.gd` | **13/13, 332 asserts** |
| Labyrinth smoke | no parse/runtime errors |
| Perf 1920×1080, 180 frames | **1361 draw calls / 4.32M tris / 75.1 avg FPS / 1236 MB VRAM** |

## 5. Remaining problems

1. **A03 integration not merged into shipping scenes.** Art is visible in A07 previews/direct test only; actual game flow NOT TESTED.
2. **Tris 4.32M > 3.5M target.** Draw calls/FPS pass; TD exception or further LOD/decimation needed.
3. **Z15 +25 / Z18 final geometry.** A03 dependency; no A03 files edited.
4. **A07-11 SQ props.** A02/A03 POI hooks absent; not placed.
5. **Visual limitations.** P06 checkpoint-inner camera remains dark even with guide strips; B02 `Shots/Stairs` camera is inside dark geometry; P05 overview is a dark night exterior. Other angles are readable.
6. **Hero quality.** Z02/Z13 use the existing project kit, not new bespoke LOD/GLB; no new asset generation was authorized.

## 6. Handoff

- Final Stage 6 commit: see TD handoff message / `git log -1`.
- No A03/A00/A02/A04/A05/A06/A08/A09/A10 files were modified.
- No push performed.
