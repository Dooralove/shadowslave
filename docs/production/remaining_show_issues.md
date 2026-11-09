# Remaining show issues — 2026-11-03

Подробный список того, что ещё не закрыто после ремонта S00–S15 и хвоста M1/tech/Academy.
Документ дополняет `docs/production/show_repair_plan.md`; решения — в `docs/DECISIONS.md`.

## Что считается концом показа

Промо-сборка заканчивается на `labyrinth_first_fragment.tscn` → карточке
«КОНЕЦ ДЕМОНСТРАЦИОННОГО ФРАГМЕНТА» (`scenes/campaign/post_nightmare_finale.tscn`).
Полная цепочка: `campaign_entry` (пролог B01–B16) → Первый Кошмар S01–S15 →
`police_precinct` (M1, P05) → `academy_approach` → `academy_gate` →
`academy_campus` → `academy_sleeper_center` → `black_sea_platform` →
`tide_descent` → `labyrinth_first_fragment` → финальная карточка.

## Текущая проверка (2026-11-09)

- **Remote:** `origin/demo/stage5` — чистая ветка показа; актуальный HEAD смотри в `git log --oneline -1 origin/demo/stage5`.
- **Full GUT:** 750 тестов, 749 прошли; единственное падение — тайминг-флейк
  `test_level_transition` (шторка не успевала за 0.16 с под нагрузкой). Тест
  переписан на ожидание завершения твина; отдельный прогон
  `test_level_transition` — 22/22, 83 assert. Полный прогон после этой правки
  не повторялся.
- **Точечные прогоны:** `test_map_system` 22/22, `test_pilgrim_path` 10/10,
  `test_caravan_site` 8/8, `test_audio_system` 19/19,
  `test_campaign_flow` 11/11, `test_finale_v2` 4/4.
- **Campaign tour:** `pass=9 fail=0`, тур гоняет арт-сцены
  (`caravan_site_art`, `pilgrim_path_art`).
- **Хвост M1/Academy/tech (автоцепочка):** `qa_stage5_scenario_chain` 5/0,
  `qa_stage5_portal_chain` 23/0 (P05 → P06 → P07 → P08 → P09 → B01 → B02 →
  Labyrinth), `qa_stage5_menu_m1` 5/0, `qa_stage5_ui_tour` 8/0.
- **Кэш классов:** после экспорта Godot снова потерял `HudMinimap`,
  `HudQuickItems`, `HudControlHints`; из-за этого HUD не грузился в QA.
  Пересобран `python tools/audit/rebuild_class_cache.py` (284 класса).
  Сборочный скрипт `tools/build/export_windows.ps1` теперь делает это
  обязательным шагом перед экспортом.
- **Экспорт:** пересобран из `demo/stage5` с чистым кэшем; `build/ShadowSlave.exe`
  109 268 480 B, `build/ShadowSlave.pck` 909 947 252 B; headless-запуск
  экспорта — exit 0. Из pck исключены `tests/`, `docs/`, `tools/audit/`,
  `addons/gut/`, `experiments/`.
- **NOT TESTED:** ручной проход M1 P05→Z10, tech Z11→Z18, Академии;
  1080p/60 FPS; draw calls; прослушивание.

## Блокеры показа (P0)

1. **Ручной проход M1 P05→Z10 не выполнен.** Автотесты покрывают сцены и переходы,
   но живой проход (диалоги, катсцены, инвентарь, сохранения) не проверялся.
   Проверять: `police_precinct` → `academy_approach` → `academy_gate` →
   `academy_campus` → `academy_sleeper_center` → `black_sea_platform` →
   `tide_descent` → `labyrinth_first_fragment`.
2. **Tech demo Z11–Z18 вручную не пройден.** Продолжение из карточки M1
   (`demo_mode_full`) не проверялось вживую.
3. **Академия вручную не пройдена.** 24 квеста, 23 NPC и 11 тайников проверены
   только probe/walkthrough-скриптами.
4. **Экспорт не пересобран после последних правок.** Старый
   `build/ShadowSlave.exe`/`.pck` от 19:16 устарел. Пересобрать и boot-тест.
5. **1080p/60 FPS, draw calls и прослушивание не измерены.** Нет подтверждённых
   замеров после добавления света и арт-оверлеев.

## Визуальные проблемы

1. **Пещера — это арт-ущелье, а не интерьер.** Самодельный CSG-тоннель убран по
   требованию пользователя. Сейчас `Art/Trail/Cave` (`cave_crevice_wide.glb`)
   стоит справа от тропы и читается как скальная масса. Бит «войти в пещеру и
   выжить» визуально происходит на открытом карнизе. Нужен либо отдельный
   cave-ассет с проходом, либо переработка бита (укрытие/расщелина).
2. **Плавающий декор в pilgrim_path.** `TrDress*`, `ice_flow`, `snow_drift` и
   `boulder_shard` стоят на высоте старой снежной дороги; после замены пола на
   арт-меш часть из них висит/утопает. Проверять
   `tools/audit/floating_objects.gd` и глазами на карнизе/у пещеры.
3. **Уступ Горного короля не подтверждён.** `TyrantLedge` в
   `caravan_site_art.tscn` стоит в `(0.8, 5.1, -4.5)`, Тиран — в
   `(0.8, 6.15, -4.5)`. Нужно проверить, что верх камня совпадает со ступнями
   Тирана и он не парит и не утопает.
4. **Жесты NPC.** Позы `kneel`/`dead` включаются только в `show_aftermath`;
   в диалогах NPC в основном статичны. Нет системы жестов для ключевых beat.
5. **Парк.** Земля — тёмный box-fill без тротуара/дороги; фасады добавлены, но
   передний план всё ещё пустоват. Нужен слой дороги/бордюра.
6. **Полицейский участок.** Лобби собрано (стойка, терминал, турели, плиты,
   свет), но комната содержания и допросная могут оставаться пустыми.
7. **Миникарта.** Карты для `containment_room` и `mountain_vision` добавлены,
   но визуально не проверены. `spell_void` карту скрывает — это ожидаемо.
8. **Камера повозки.** Вынесена из кузова, но кадр при столкновении/падении
   вручную не проверен.
9. **Освещение.** Яркость cave/ledge приглушена, но сцена всё ещё плоская:
   нет контраста факелов/луны, часть скал освещена ровно.

## Геймплейные проблемы

1. **Пещера/стелс вживую не пройдены.** Триггер входа теперь всегда активен и
   даёт подсказку, если Учёный не ушёл; но сам проход (вход → рана → выход →
   BlindTyrant → камень → колокол → захват Героя) не игрался.
2. **Прыжок и удары вне боя** включены, но не проверены в живом сценарии.
3. **Цели.** Добавлены цели по фазам подъёма, в святилище и очистка цели лагеря
   при выходе. Нужно проверить, что цели M1 (`post_nightmare` source) не
   конфликтуют с `campaign`.
4. **Сохранение/загрузка** после новых флагов (`scholar_abandoned`,
   `cave_entered`, `wounded`, `stealth_completed`) не перепроверялась.
5. **NPC-стейджинг.** Ветеран/Герой переставлены, но Шифти и Учёный в разных
   фазах могут стоять не по beat sheet.

## Технический долг

1. **`MCPRuntime` autoload** всё ещё в `project.godot`; перед релизной сборкой
   убрать или исключить.
2. **Кэш классов Godot** может потерять HUD-классы после ручных правок и
   экспорта. Обязательный шаг — `python tools/audit/rebuild_class_cache.py`;
   он уже встроен в `tools/build/export_windows.ps1`.
3. **`build/ShadowSlave.pck` ~910 МБ** и не в Git; экспорт пересобирать локально
   скриптом `tools/build/export_windows.ps1`.
4. **QA-тур кампании** теперь использует арт-сцены (`*_art.tscn`); prologue tour
   идёт через `campaign_entry`. При добавлении новых локаций обновлять
   `tools/audit/qa_campaign_tour.gd`.
5. **Аудит-скрипты** в `tools/audit/` (`scene_shot.gd`, `route_probe.gd`,
   `ui_probe.gd`, `asset_aabb.gd`) — вспомогательные, в релиз не входят.

## Команды проверки

```powershell
# полный GUT
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# тур кампании
godot --path . res://tools/audit/qa_campaign_tour.tscn -- --out=$env:TEMP\opencode\tour

# тур пролога
godot --path . res://tools/audit/qa_prologue_tour.tscn -- --out=$env:TEMP\opencode\prologue

# проходимость маршрута
godot --headless --path . -s tools/audit/route_probe.gd

# кадр локации
godot --path . -s tools/audit/scene_shot.gd -- --scene=res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn --out=C:\tmp\shot.png --pos=1,5.8,-42.5 --look=1,4.8,-55 --fov=72

# хвост M1 → Academy → tech demo → Labyrinth
godot --path . res://tools/audit/qa_stage5_portal_chain.tscn -- --out=$env:TEMP\opencode\stage5
godot --path . res://tools/audit/qa_stage5_scenario_chain.tscn -- --out=$env:TEMP\opencode\stage5
godot --path . res://tools/audit/qa_stage5_menu_m1.tscn -- --out=$env:TEMP\opencode\stage5

# экспорт (сам пересобирает кэш классов и делает boot-тест)
powershell -ExecutionPolicy Bypass -File tools/build/export_windows.ps1
```
