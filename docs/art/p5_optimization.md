# P5 — оптимизация и QA: парк, LOD, culling, batching, текстуры

**Дата:** 2026-11-02  
**Область:** P5 — производительность и QA на целевых 1080p/60, VRAM < 4 GB и draw calls < 1500 с culling.  
**Статус:** реализовано; геймплей, маршруты, коллизии и авторские P2–P4 композиции не менялись.

![P5 park optimized](previews/p5_optimization/p5_park_optimized.png)

## 1. Замеры

Замер: `tools/audit/p5_benchmark.gd`, реальный Forward+ рендер, **1920×1080**, камера `(0, 1.65, 4)` → `(0, 1.8, -18)`, 120 кадров после 90 кадров прогрева. Парк: `scenes/slice/locations/park/park_street_art.tscn`. GPU — RTX 3060 Laptop 6 GB.

| Метрика | До P5 | После P5 | Цель |
|---|---:|---:|---:|
| Draw calls, среднее | **1 104,8** | **251,8** | < 1 500 |
| Draw calls, 4 ракурса | — | **211?388** | < 1 500 |
| Primitives, среднее | 1 879 508 | **1 566 064** | < 3,5 млн |
| Objects, среднее | 1 472,8 | **327,8** | — |
| VRAM | 1 068,6 MB | **1 068,6 MB** | < 4 096 MB |
| FPS, uncapped | 164,9 | **165,0** | ≥ 60 |
| Frame time | ~6,1 ms | **~6,1 ms** | ≤ 16,7 ms |

Четыре ракурса (bench/west/east/station) дали 251,0 / 284,7 / 388,0 / 211,0 draw calls и 0,65?1,93 млн primitives. VRAM во всех прогонах 1 068,6 MB.

Actual prologue with player + UI (`p5_campaign_probe.tscn`, 1920x1080): **709.0 draw calls**, 1.86M primitives, 1078.1 MB VRAM, 164.9 FPS uncapped.

![P5 metrics](previews/p5_optimization/p5_metrics.png)

## 2. Что сделано

### glTF-Transform: facades and props

Пять исходных GLB были **скопированы** в `assets/environments/park/p2/p5/` и обработаны `gltf-transform join`; оригиналы не удалены и не изменены. `p2_park_set.tscn` теперь ссылается на joined-копии.

| Ассет | До, байт | После, байт |
|---|---:|---:|
| `facade_p2_stone.glb` | 121 940 | 101 024 |
| `facade_p2_balcony.glb` | 206 104 | 172 760 |
| `facade_p2_glass.glb` | 91 720 | 58 328 |
| `station_entrance_p2.glb` | 73 340 | 65 912 |
| `bus_shelter_p2.glb` | 44 388 | 38 928 |

Основной выигрыш — не размер файла, а **склейка множества мелких MeshInstance3D** фасадов в совместимые primitives: P2 facades были главным источником draw calls.

### MultiMesh

`scripts/world/park_batch.gd` (`ParkBatch`) на старте собирает повторяющиеся статические меши в `MultiMeshInstance3D`:

- `DistantCity` — 12 башен → 2 batch-группы по материалам;
- `Art/Upgrade` — лампы и болларды → отдельные batch-группы.

Оригинальные узлы остаются в дереве, но скрываются (`visible = false`), поэтому авторские пути, отладка и проверки сцены не ломаются.

`P5Batch` uses `is_visible_in_tree`; hidden legacy Tree0-Tree4/Facade0-Facade7 nodes are skipped. This was found during the audit: the first version batched hidden facade meshes and produced dark overlays.

### Occlusion culling

- `project.godot`: `rendering/occlusion_culling/use_occlusion_culling=true`.
- В `p2_park_set.tscn` добавлен `OccluderInstance3D` (`Occlusion/StationBack`) с `BoxOccluder3D` за фасадом станции.
- Occlusion снизил primitives с ~1,88 до ~1,57 млн на основном ракурсе; draw calls остались в пределах цели на всех проверенных ракурсах.

### LOD

- `scenes/environment/park/island_tree.tscn` + `scripts/world/tree_lod.gd`: три авторских LOD (LOD0/LOD1/LOD2), переключение по дистанции; тест проверяет наличие всех трёх.
- `project.godot`: `rendering/mesh_lod/lod_change/threshold_pixels=1.5` для импортированных мешей.
- Деревья не размножены на десятки уникальных героев: в P2 семь экземпляров `island_tree`, из них пять ближних и два дальних; `Tree0–Tree4` старого `park_art` скрыты, P2-набор — актуальный.

### Текстуры / VRAM

- `project.godot`: `rendering/textures/vram_compression/import_s3tc_bptc=true`.
- Парковые texture imports уже используют `vram_texture = true`, `s3tc_bptc` и mipmaps; тест фиксирует это для `clean_asphalt_diff_1k.jpg.import`.
- VRAM на замере — **1 068,6 MB**, с запасом ниже 4 GB; 2K-текстуры не удалялись и не пережимались вслепую.


## 3. Audit findings and fixes

- **Hidden-ancestor batching bug.** The first `P5Batch` pass checked only `MeshInstance3D.visible`. Legacy `Art/Upgrade/Tree0-Tree4` and `Facade0-Facade7` roots are hidden, but their imported child meshes are individually visible, so the batcher rendered hidden facade geometry as dark overlays. Fixed with `is_visible_in_tree()`; the final capture is clean and the regression test has an upper bound.
- **Oversized culling AABB.** The first batcher used one huge hand-written AABB for every group, which defeats culling. It now computes a tight local AABB from the transformed mesh bounds; draw calls on the bench view dropped from ~278 to **251,8** after the fix.
- **Benchmark memory sampling.** The benchmark printed VRAM after freeing the scene, understating the rendered footprint. It now samples video/texture memory before cleanup and frees the scene before exiting.
- **Repeated UI theme construction.** P4's UI paths called `RpgMenuTheme.build()` independently for subtitles, objective, rune status, combat HUD and labels. `RpgMenuTheme` now caches one immutable shared theme, avoiding repeated font/theme allocation; RPG-menu, combat-HUD, P4 and P5 tests still pass.
- **Actual campaign view.** The static park view is not the same as gameplay: the real prologue camera with player + UI measured **709,0** draw calls, 1,86M primitives and 1 078,1 MB VRAM. It remains below the 1 500-draw-call target.

## 4. Проверки

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `gltf-transform validate` (5 joined GLBs) | exit 0 |
| `test_p5_optimization` | 5/5, 23 assert |
| `test_park_art` | 6/6, 72 assert |
| `test_p4_presentation` | 9/9, 65 assert |
| `test_slice_locations` | 8/8, 48 assert |
| Полный GUT | 73 скрипта, 572 теста, 572 pass, 6848 assert, exit 0 |
| P5 benchmark | 1920×1080, 4 ракурса; draw calls 211?388; VRAM 1068,6 MB |
| P5 campaign probe | 1920x1080, player + UI: 709.0 draw calls; 1.86M primitives; 1078.1 MB VRAM |

**NOT TESTED:** ручной playthrough на 1080p/60 с vsync, субъективная оценка LOD-попов на ходу, длительный thermal/VRAM soak и профилирование на другом GPU. Замеры FPS — uncapped, не заявление о стабильных 60 FPS в любом месте сцены.

## 5. Файлы

- `scripts/world/park_batch.gd`
- `scripts/ui/rpg_menu/rpg_menu_theme.gd` (shared theme cache)
- `assets/environments/park/p2/p5/*.glb` (5 joined copies)
- `scenes/slice/locations/park/p2_park_set.tscn`
- `project.godot` (`[rendering]`: S3TC/BPTC, occlusion, mesh LOD threshold)
- `tests/test_p5_optimization.gd`
- `tools/audit/p5_benchmark.gd`
- `tools/audit/p5_campaign_probe.gd`, `tools/audit/p5_campaign_probe.tscn`
- `docs/art/previews/p5_optimization/`

Коммиты не создавались.
