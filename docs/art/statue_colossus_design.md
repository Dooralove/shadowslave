# Колосс безголового рыцаря — дизайн и as-built

**Статус:** hero-ассет v2 на базе скульптуры Stone Knight. Встроен в
`black_sea_platform`, имеет collision площадки, три LOD-уровня и Credits
с CC BY-атрибуцией. После аудита исправлены ширина площадки, Start-кадр и
смещения меча. Игровой проход вручную ещё не выполнен; это не релизная
приёмка.

**Дата:** 2026-11-02  
**Связанные документы:** `docs/design/forgotten_shore_labyrinth_research.md`,
`docs/research/post_first_nightmare_dream_realm/03_locations_and_world.md`,
`docs/art/labyrinth_model_map.md`, `docs/ASSET_LICENSES.md`.

## 1. Канон

- Гигантский безголовый рыцарь, около **200 м**.
- Голова отсутствует; её срез — круглая каменная площадка **около 12 м** в диаметре.
- Площадка плоская, с бороздами и неровным краем.
- На нагруднике **семь звёзд**: центральная и шесть вокруг.
- Меч опущен остриём вниз; кисти рук сведены на рукояти.
- Вокруг Чёрное море: чёрная вода без луны и звёзд.
- Площадка — укрытие Санни от прилива; тело и меч — визуальный масштаб.

## 2. Источник и лицензия

Базовая скульптура — **Stone Knight** с Sketchfab:

- Автор: **mzee92**
- URL: https://sketchfab.com/3d-models/stone-knight-c3e3712fd5164e44abdab658981cb395
- Лицензия: **CC BY 4.0** (https://creativecommons.org/licenses/by/4.0/)
- Локальная копия: `assets/environments/nightmare/source/stone_knight_source.glb`
- Атрибуция: `assets/environments/nightmare/statue/LICENSE_STONE_KNIGHT.txt`

Кредит «Stone Knight by mzee92, CC BY 4.0, via Sketchfab» добавлен в
главное меню (`CreditsButton` / `CreditsDialog`); до релиза проверить его
в финальной сборке.

Модель скачана через Sketchfab API после явного разрешения пользователя.
Процедурный v1 (`build_statue_colossus.py`) оставлен как fallback/история;
финальный ассет собирается `build_stone_knight_colossus.py`.

## 3. As-built

| Параметр | Значение |
|---|---|
| Итоговый файл | `assets/environments/nightmare/statue/statue_knight_colossus.glb` |
| Исходник | `assets/environments/nightmare/source/statue_colossus.blend` |
| Сборщик | `assets/environments/nightmare/source/build_stone_knight_colossus.py` |
| Исходная скульптура | `assets/.../source/stone_knight_source.glb` (26,9 МБ) |
| Размер итогового GLB | ≈43,2 МБ (встроенные текстуры) |
| Треугольники (Godot) | 49 406 |
| Поверхности / материалы | 14 |
| AABB (Godot, Y-up) | X −44.76…47.77, Y −200.0…0.62, Z −43.63…28.58 |
| Оригин | центр верхней площадки-шеи, `(0, 0, 0)` |
| Ось тела | вниз по −Y (Godot) / −Z (Blender) |
| Фронт | в Godot смотрит в −Z; в Blender — в +Y |
| Диаметр площадки | 12 м (центральный диск); внешний венец ниже и шире, не проходим |
| Высота | ≈200,6 м |

Оригин в площадке позволяет ставить ассет двумя способами:

1. **Чёрное море / `black_sea_platform`:** поставить в `(0, 0, 0)`, тело уйдёт под воду.
2. **Лабиринт:** поставить площадку на нужную высоту, тело уйдёт вниз к земле.

## 4. Интеграция в `black_sea_platform`

- Визуал: `StatueKnightLOD` (`statue_knight_colossus_lod.tscn`) инстанцируется в
  `Generated/Structure/StatueKnightColossus`, позиция `(0, 0, 0)`.
- Старые primitive-функции `_build_chest`, `_build_shoulders…`, `_build_sword`
  больше не вызываются; оставлены как fallback/история.
- Коллизия площадки: отдельный `NeckPlatformCollision` — `CylinderShape3D`
  радиус 6 м, высота 2,4 м, верх ровно `y=0`. Тело/меч — без коллизии.
- Центральная плита: радиус **6,0 м**; верхняя крышка `NeckCollar` убрана,
  внешний коллар опущен и читается как сломанная нижняя полка.
- Граница площадки: 12 невидимых сегментов на радиусе **6,15 м**; восточный
  сектор открыт под существующий спуск/портал `ToCoral`.
- LOD-узлы: `LOD0` 0–420 м (49 406 tris, textured), `LOD1` 420–1200 м
  (17 292 tris, простой камень), `LOD2` 1200–4000 м (4 940 tris).
- Проверка: `tools/audit/statue_integration_check.gd` — сцена загружается,
  статуя и 3 LOD найдены, raycast попадает в `NeckPlatformCollision`.
- Скриншоты интеграции: `docs/art/previews/forgotten_shore/black_sea_integrated_*.png`.
- Полный аудит интеграции и список улучшений: `docs/art/statue_integration_audit_2026-11-02.md`.

## 5. Что добавлено к исходной скульптуре

- Ориентация и масштаб приведены к 200 м; origin перенесён на срез шеи.
- Площадка-шея 12 м: плоский каменный диск с радиальными канавками,
  светлой кромкой, сломанным внешним венцом и мелкими обломками.
- Массивная каменная пробка/кольцо шеи, чтобы площадка не читалась парящей крышкой.
- **Семь звёзд:** тёмные каменные шайбы, бронзовые кольца, светлые звёздные
  вставки; констелляция разведена вокруг рукояти меча.
- Все объекты склеены в один меш с 14 слотами материалов (меньше draw calls).

## 6. Материалы

- Исходная скульптура сохраняет свои PBR-текстуры (камень, мох, трещины).
- Новые детали площадки/звезды используют `stone_textured`, `stone_light`,
  `nm_statue_star`, `nm_statue_crack`, `nm_statue_bronze`.
- Каменная основа `low_tide_rocks` — CC0 Poly Haven, Rob Tuytel.
- Исходные texture maps входят в CC BY-модель; атрибуция обязательна.

## 7. Превью

Blender (Eevee):

- `docs/art/previews/forgotten_shore/statue_full.jpg`
- `statue_neck.jpg`
- `statue_chest.jpg`
- `statue_sword_hand.jpg`
- `statue_black_sea.jpg`
- `statue_tide.jpg`

Godot 4.7.2 (`tools/audit/statue_colossus_preview.gd`):

- `statue_godot_full.png`
- `statue_godot_black_sea.png`
- `statue_godot_neck.png`
- `statue_godot_chest.png`

Интеграция в `black_sea_platform`:

- `black_sea_integrated_overview.png`
- `black_sea_integrated_start.png`
- `black_sea_integrated_player.png`
- `black_sea_integrated_chest.png`
- `black_sea_integrated_sword.png`
- `black_sea_integrated_descent.png`

## 8. Проверки

| Проверка | Результат |
|---|---|
| Blender background build + GLB export | **PASS**, 14 primitives |
| Godot 4.7.2 headless import | **PASS**, exit 0 |
| Godot preview / material binding | **PASS**, 14 surfaces, 49 406 tris |
| AABB / масштаб / origin | **PASS**, ≈200.6 м, origin на площадке |
| Интеграция в `black_sea_platform` | **PASS**: LOD scene, 3 уровня, collision |
| Collision площадки | **PASS**: raycast hit `NeckPlatformCollision` |
| LOD ranges | **PASS**: 0–420 / 420–1200 / 1200–4000 м; 49 406 / 17 292 / 4 940 tris |
| Визуальный захват сцены | **PASS**: `black_sea_integrated_*.png` |
| Credits / CC BY | **PASS**: `main_menu_credits_check.gd` |
| Полный ручной проход Санни | **NOT TESTED** |
| `tide_descent` / лабиринт | **NOT TESTED** |

## 9. Ограничения и следующий quality-pass

- Скульптура исходника — палевый известняк с мхом, не тёмный базальт; для
  Чёрного моря нужен отдельный material-tint/weathering-проход.
- Площадка пока геометрически простая: диск + каннелюры + обломки; нужен
  более богатый carved-rim, трещины и морские обрастания.
- Семь звёзд — накладные медальоны; при финальном пассе лучше сделать
  углублённые инкрустации в нагрудник.
- Collision есть только у площадки; тело/меч непроходимы, но без физики.
- LOD1/LOD2 визуально не проверены вблизи/на порогах; LOD1/2 — простой камень
  без текстур.
- LOD0 держит 27 текстур; фактический VRAM/сжатие не измерены.
- Спуск/портал и дальний reef остаются primitive/graybox; спуск переведён на
  нейтральный `concrete_dark`, но его форма ещё не hero-качества.
- Нужен ручной проход в Godot и проверка масштаба с игроком на площадке.
