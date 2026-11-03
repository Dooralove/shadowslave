# 07 Environment Art — Stage 3 report

**Дата:** 2026-11-03
**Ветка:** `demo/environment` (worktree `shadowslave-demo-07`)
**База:** `ee97325`
**Статус:** A07-сторона P05–B02 и Z10 реализована и проверена в preview; боевые сцены A03 не менялись.

## 1. Сделано

### A07-01 P05 police precinct
- 8 PBR-материалов (`art_police_*`), холодный key light, interior fill, yard sodium, reflection probe.
- Арт-зеркало на видимой внутренней стене (исходный A03 `MirrorGlass` оказался за стеной), рама, handprint decal.
- 6+ props: crate, barrel, chain, shackles, evidence bones, cell bones; drag decal.
- Captures: `docs/art/previews/post_nightmare/p05_overview.png`, `p05_entrance.png`, `p05_interrogation.png`.

### A07-02 P06/P07/P08 academy
- P06: snow drifts, dead trees, checkpoint crate/barrel, road debris, warm approach/checkpoint lights.
- P07: 4 temple columns, relief panels, red gate trim (lintel/posts/threshold), snow, supply crate, barrel, gate/star lights.
- P08: 14 stone gallery columns, 2 relief panels, snow, debris, evening wash; old metal `GalleryColumn` visuals hidden by prefix.
- Captures: `p06_overview.png`, `p07_overview.png`, `p07_gate_detail.png`, `p08_overview.png`.

### A07-03 P09 Sleeper Center
- PBR tile/wall/metal/fabric, 2 induction torus rings, medical supply box, shower barrel, cold dorm/induction/observation lights.
- Capture: `p09_overview.png`.

### A07-04 B01 Black Sea
- PBR stone/pale/bronze swaps, two draped shroud panels with tattered edge and fold normals, 6 echo stars, shroud rim/fill, sword glint, moon key.
- Capture: `b01_overview.png`.

### A07-05 B02 Tide descent
- Coral arch, coral clusters, weathered boulder, wet-stone swaps, warm coral glow replacement for cyan glow.
- Capture: `b02_overview.png`, `b02_bottom.png` (stairs camera is unusably dark in the A03 shot; bottom gate reads).

### A07-06 Z10 camp
- Meat rack (posts/crossbar/straps/meat/hook), rope coil, crate, sack, firewood, water flask, barrel.
- New chain-scrape decals in Z02/Z13/Z10; camp fill kept; camp spawn radius kept clear.
- Capture: `docs/art/previews/forgotten_shore/environment_art/z10_camp.png`.

### A07-08 / A07-10
- 30 PBR material variants under `resources/locations/post_nightmare/materials/art_*.tres`.
- Labyrinth MultiMesh for seabed silhouettes, horizon ridges, far cliffs/spires, Z14 vertebrae/ribs and **208** shore seaweed/shell/wet-rock instances in **3** MultiMeshes (A07-08b: 200+, <20 draws, no physics).
- Capture: `docs/art/previews/forgotten_shore/environment_art/z02_carcass.png`.
- Z15/Z18: edge ledges/overhang and Z18 sea stacks; captures `z15_refuge.png`, `z18_cliffs.png`.
- Z10 camp capture: `z10_camp.png`.
- 1920×1080 `Shots/Entrance`, 180 frames: **1361 draw calls**, **4.32M tris**, **75.1 average FPS**, **1236 MB VRAM**.
- Draw calls PASS (<1500, baseline 1593); FPS PASS in this probe; tris remain above the 2.5–3.5M target and need a TD exception.
- Decals: 6 named types (azure blood, footprints, chain scrape, wet trail, wet drag, claw mark) across Z02/Z03/Z08/Z10/Z13/Z14.

### A07-14
- `docs/art/environment_asset_manifest.md`
- `docs/art/environment_art_integration_a03.md`
- A07 tools: build, validation, capture, perf probe.

## 2. Проверки

| Проверка | Результат |
|---|---|
| Overlay validation, 7 preview wrappers | **7/7 applied, art_collision=0, failures=0** |
| Direct-parent overlay test (P05–B02) | **7/7 applied, failures=0** |
| Z10 DemoEndZone clearance (A03 coords r=4) | **0 camp-prop offenders; only campfire inside** |
| Labyrinth shore dressing | **208 instances / 3 MultiMesh nodes / no physics** |
| `tests/test_post_nightmare_locations.gd` | **15/15 passed, 513 asserts** |
| `tests/test_labyrinth_first_fragment.gd` | **13/13 passed, 332 asserts** |
| Labyrinth smoke scene | no parse/runtime error |
| P05–B02/ Z10 captures | produced and inspected |

Команды:
```text
godot --headless --path . res://tools/art/validate_environment_art.tscn
godot --headless --path . res://tools/art/validate_direct_overlay.tscn
godot --headless --path . res://tools/art/validate_z10_clearance.tscn
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_post_nightmare_locations.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_first_fragment.gd -gexit
```

## 3. Блокеры и NOT TESTED

1. **A03 integration.** P05–B02 art scenes are not in shipping scenes; A03 must instance them as child `ArtOverlay`. Actual gameplay integration is **NOT TESTED**. Exact patch is in `docs/art/environment_art_integration_a03.md`.
2. **Z10 DemoEndZone / A03 merge.** A03 `demo-03` worktree now contains `DemoEndZone` at `(-100,18.2,-5)` r=4 and `CampNight`; A07 camp-prop clearance test uses these coords and reports **0 offenders** (only campfire inside). Actual trigger/finale flow after merge is **NOT TESTED** in this worktree. A03 still had no `ArtOverlay` hook when checked.
3. **Tris budget.** 4.32M exceeds 3.5M; draw calls pass. Needs TD decision/exception or further LOD/decimation.
4. **Z15 +25 / Z18 final geometry.** A03 G1–G5/final platform still missing; A07 does not edit A03 geometry. Z15/Z18 art remains the Stage 1 pass, not a new hero rebuild.
5. **A07-11 SQ props.** Not placed because A02/A03 POI hooks are absent in this worktree.
6. **B02 stairs camera.** `Shots/Stairs` is inside/dark geometry; bottom/overview captures used. Ramp traversal is A03/A10 responsibility.
7. **Commit status.** Stage 3 changes were uncommitted; Stage 5 creates the final A07 commit (see TD handoff). No push.

## 4. Stage 5 closure

**Fully closed A07-side:** A07-01, A07-02, A07-03, A07-04, A07-05, A07-06, A07-08a, A07-08b, A07-09 (captures/lighting for the implemented set), A07-10 draw-call/MultiMesh part, A07-14.

**Partially closed:** A07-07 (Z02/Z13 existing hero pass + decals + Z15/Z18 ledges; +25/final geometry still A03), A07-10 triangle budget (TD exception needed).

**Blocked:** A07-11 SQ props — A02/A03 POI hooks are not present in this worktree; A07-12+ depends on A03 post-merge geometry.

**New audit findings:**
- A03 `demo-03` added `DemoEndZone`/`CampNight`; A07 relocated camp bedrolls/gear outside the r=4 end-zone sphere and verified **0 camp-prop offenders**.
- A03 still has no `ArtOverlay` in shipping post-nightmare scenes; integration package is ready.
- P06 checkpoint inner camera is still dark; P06 overview/checkpoint props are correct.
- B02 `Shots/Stairs` is inside dark geometry; B02 bottom/overview/top captures used.
- FPS probe is variable (73–118 average); draw calls and tris are stable. Last run: **1361 draw calls / 4.32M tris / 73.1 avg FPS / 1236 MB VRAM**. Tris >3.5M target → TD exception.
