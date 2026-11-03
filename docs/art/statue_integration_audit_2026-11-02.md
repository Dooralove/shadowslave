# Аудит и пост-аудит интеграции колосса — 2026-11-02

**Статус:** техническая интеграция и часть P0/P1 исправлений выполнены.
Hero-приёмка **не пройдена**: нет ручного прохода, проверки спуска,
`tide_descent`/лабиринта, визуального LOD-теста и профилирования VRAM/CPU.

**Объект:** `statue_knight_colossus.glb`, `statue_knight_colossus_lod.tscn`,
`black_sea_platform`, `main_menu` credits, окружение и документация.

---

## 1. Что исправлено после аудита

### P0 — CC BY 4.0

Добавлен экран **«Кредиты и лицензии»** в главное меню:
`CreditsButton` + `CreditsDialog` в `scripts/ui/main_menu/main_menu.gd`.

В кредитах есть:

- `Stone Knight — mzee92, CC BY 4.0, via Sketchfab`;
- ссылка на Sketchfab и Creative Commons;
- пометка, что `statue_knight_colossus.glb`, LOD1 и LOD2 — производные;
- `low_tide_rocks` — Poly Haven, Rob Tuytel, CC0 1.0.

Проверка `tools/audit/main_menu_credits_check.gd` — **PASS**:

```text
CREDITS_BUTTON=true
CREDITS_DIALOG=true
HAS_MZEE92=true
HAS_CC_BY=true
HAS_SOURCE=true
```

### P1 — площадка

**Было:** видимая верхняя поверхность `NeckCollar` доходила примерно до
радиуса 8,2 м, collision — до 6,0 м, boundary — до 6,35 м. Игрок упирался
в невидимую стену, а площадка визуально казалась шире канонических 12 м.

**Исправлено в ассете и сцене:**

- центральная плита `build_platform` расширена до радиуса **6,0 м**;
- у `NeckCollar` убрана верхняя крышка (`cap=False`);
- `NeckCollarRim` опущен на `y≈−0,42`; внешний коллар читается как нижняя
  сломанная полка;
- boundary сдвинут на радиус **6,15 м**;
- final GLB и LOD1/LOD2 пересобраны.

Raycast-проба `tools/audit/neck_collision_probe.gd`:

```text
PROBE (0.0, 5.0, 0.0)  hit=true  NeckPlatformCollision at y=0
PROBE (5.5, 5.0, 3.0)  hit=true  NeckBoundary1 at y=2.9
PROBE (6.2, 5.0, 3.0)  hit=false
PROBE (7.0, 5.0, 3.0)  hit=false
PROBE (8.0, 5.0, 3.0)  hit=false
```

Пол за радиусом 6 м отсутствует — это ожидаемо: там нижний сломанный
коллар, а не проходимая плита. **Ручной проход по периметру и восточному
спуску всё равно NOT TESTED.**

### P1 — Start-кадр

`Start` перекадрирован: камера `(0, 12, −90)`, цель `(0, −30, −10)`.
Новый `black_sea_integrated_start.png` показывает нагрудник, семь звёзд,
руки и шею колосса. Позиция игрока в `Spawns/Start` не менялась.

### P1 — меч

Координаты старого primitive-меча `x≈−30` больше не используются:

- `SwordGlow` — `(0, −34, −40)`;
- `SwordLabel` — `(0, −48, −32)`;
- `SwordTarget` — `(0, −36, −30)`;
- `Sword`-камера — `(0, −25, −80)`.

`Sword`-кадр теперь строится от центра меча/кистей.

### P1/P2 — source, LOD и generated-файлы

- `stone_knight_source.glb` перенесён в
  `assets/environments/nightmare/source/`, где лежит `.gdignore`;
  Godot больше не импортирует исходник и не дублирует его текстуры.
- source-текстуры-сироты удалены из `statue/`.
- сгенерированные extracted-текстуры финала добавлены в `.gitignore`.
- у LOD1/LOD2 отключены `meshes/generate_lods` и
  `create_shadow_meshes`; для LOD-переходов добавлены margins 24 м.
- **Исправлена ошибка первой версии аудита:** `gltf-transform
  renderVertexCount` — это индексный поток, а не число уникальных вершин.
  LOD1 действительно снижает нагрузку.

---

## 2. Фактическое состояние ассета

| Параметр | Значение |
|---|---|
| Финальный GLB | `assets/environments/nightmare/statue/statue_knight_colossus.glb` |
| Размер | 43 239 212 байт (≈43,2 МБ) |
| Треугольники | **49 406** |
| Index / upload vertices | **148 218 / 52 321** |
| Материалы / primitive | **14** |
| Изображения | 27 images, 33 texture slots |
| Разрешения | 24 × 1024², 3 × 2048² (`low_tide_rocks`) |
| AABB | X −44.76…47.77, Y −200.0…0.62, Z −43.63…28.58 |
| Origin | центр верхней площадки-шеи, `(0, 0, 0)` |
| Высота | ≈200,6 м |
| Центральная плита | радиус 6,0 м; внешний коллар ниже |
| glTF validation | 0 errors, 0 warnings |
| Семь звёзд | 7 медальонов, визуально читаются |
| Меч | остриём вниз, руки сведены |

### LOD

| LOD | Треугольники | Index vertices | Upload vertices | Дистанция | Текстуры |
|---|---:|---:|---:|---:|---:|
| LOD0 | 49 406 | 148 218 | 52 321 | 0–420 м | 27 |
| LOD1 | 17 292 | 51 876 | 29 181 | 420–1200 м | 0 |
| LOD2 | 4 940 | 14 820 | 7 436 | 1200–4000 м | 0 |

LOD1/LOD2 — производные Stone Knight, CC BY 4.0, без текстур.
`gltf-transform validate` для обоих — **0 errors, 0 warnings**.

---

## 3. Проверки

Выполнено:

```text
godot --headless --path . --import
    PASS, exit 0

godot --headless --path . --script tools/audit/statue_integration_check.gd
    PASS

godot --headless --path . --script tools/audit/main_menu_credits_check.gd
    PASS

godot --headless --path . --script tools/audit/neck_collision_probe.gd
    PASS (выявил отсутствие пола за радиусом 6 м — ожидаемая нижняя полка)

godot --path . -s tools/audit/location_capture.gd -- ...
    PASS, сцена отрендерена

gltf-transform validate final / LOD1 / LOD2
    0 errors, 0 warnings
```

Фактический вывод интеграционной проверки:

```text
STATUE=true COLLISION=true
STATUE_CHILDREN=3
  LOD=LOD0 tris=49406   begin=0.0    end=420.0
  LOD=LOD1 tris=17292   begin=420.0  end=1200.0
  LOD=LOD2 tris=4940    begin=1200.0 end=4000.0
COLLISION_SHAPE=CylinderShape3D
OLD_PRIMITIVE_CHEST=false
PLATFORM_RAY_HIT=true NeckPlatformCollision:<StaticBody3D#...>
```

Новые превью: `docs/art/previews/forgotten_shore/black_sea_integrated_*.png`.

---

## 4. Что ещё открыто

### P1 — спуск, риф, `tide_descent` и лабиринт

- `_build_descent()` теперь использует `concrete_dark` вместо синего
  `statue` и нейтральный `DescentGlow`, но остаётся primitive-формой.
- `_build_sea_and_reef()` — красные primitive-цилиндры дальнего рифа.
- `tide_descent.gd` и `labyrinth_first_fragment.gd::_build_statue()` всё ещё
  строят primitive-статую.

Нужно: заменить спуск/риф на каменный/коралловый kit и поставить
`StatueKnightLOD` в `tide_descent`/лабиринт там, где колосс должен быть
виден. Проверить портал `ToCoral` и проходимость спуска.

### P1 — texture memory / VRAM

LOD0 держит 27 текстур (24 × 1024² + 3 × 2048²). Оценка `gltf-transform` —
около **201 МБ GPU** без учёта фактического сжатия Godot. Source-дублирование
убрано, но LOD0 загружается всегда. Нужно:

- измерить VRAM в реальном рендере;
- проверить/включить VRAM-сжатие;
- при необходимости уменьшить 1024² карты или собрать атлас;
- сравнить качество на площадке и в обзорном кадре.

### P2 — LOD-визуал

Margins и отключение auto-LOD сделаны, но визуальный тест на 380/450/1150/
1250 м **NOT TESTED**. Нужно проверить LOD1/LOD2 вблизи порогов, цвет
бестекстурного камня и отсутствие резкого pop.

### P2 — dead code, debris, generated files

- В `black_sea_platform.gd` остаются неиспользуемые primitive-функции
  (`_build_neck`, `_build_broken_collar`, `_build_shoulders_and_arms`,
  `_build_chest`, `_build_lower_body`, `_build_sword`, `_add_sword_hand`,
  `_add_star`, `_star_mesh`) и `STATUE_STAR_MATERIAL`.
- `FallenHelm`/`Debris` не имеют collision; игрок проходит сквозь них.
- В `git status` по `statue/` остаются untracked `LICENSE`, LOD1/LOD2,
  LOD-сцена и их `.import`; их нужно добавить в Git. Generated-текстуры
  теперь в `.gitignore`.
- Source GLB в `source/` не импортируется, но должен быть добавлен в Git
  LFS как provenance.

### Проверки, которые не выполнены

- Ручной проход Санни по площадке — **NOT TESTED**.
- Спуск/портал `tide_descent` — **NOT TESTED**.
- LOD1/LOD2 визуально на порогах — **NOT TESTED**.
- VRAM, draw calls, frame time — **NOT TESTED**.
- Полный GUT — **NOT TESTED**.
- `tide_descent`/лабиринт — **NOT TESTED**.

---

## 5. Следующий порядок работ

1. Ручной проход по площадке, периметру и восточному спуску.
2. Визуальный LOD-тест и проверка texture memory.
3. Замена primitive-спуска/рифа и интеграция LOD-сцены в `tide_descent`/
   лабиринт.
4. Удаление мёртвого primitive-кода и debris collision.
5. Полный GUT и релизная проверка Credits.

## 6. Ограничения

- Я не запускал игру вручную, не ходил по площадке и не проверял
  ощущения от LOD/спуска.
- Я не измерял FPS, frame time, реальный VRAM и draw calls.
- 201 МБ — оценка `gltf-transform`, не замер Godot.
- В рабочем дереве есть несвязанные изменения (soul sea и др.); аудит
  ограничен статуей, `black_sea_platform`, меню кредитов и документацией.
- `PASS` в этом документе относится только к фактически выполненным
  headless/рендер-проверкам, а не к ручной приёмке.
