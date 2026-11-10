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

## Текущая проверка (2026-11-10)

- **Ветки A–G смержены** в `demo/stage5`; конфликты были только в
  `caravan_site.gd` и `pilgrim_path.gd` — сведены вручную (геометрия D/F +
  позы G). После merge пересобран кэш классов (`BeatShotStage`).
- **Full GUT:** 766/766, 8358 asserts, exit 0.
- **Туры:** `qa_campaign_tour` pass=9 fail=0; `qa_prologue_tour` — 6 кадров;
  `qa_stage5_portal_chain` 23/0, `scenario_chain` 5/0, `menu_m1` 5/0,
  `ui_tour` 8/0.
- **Парк/участок:** парк теперь с домами, дорогой, деревьями и миникартой;
  лобби участка — со стойкой, терминалом, светом и допросной.
- **Миникарта:** определяется по активной локации (парк в участке больше не
  показывается); `campaign_entry` убран из карты парка.
- **Цели пролога:** цель бита публикуется как цель сцены и меняется на B07
  («Сдаться дежурному»), а не висит «допить кофе».
- **NOT TESTED:** ручной проход M1/tech/Academy, 1080p/60, draw calls,
  прослушивание. Экспорт после merge ещё не пересобран.

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
4. **Экспорт пересобран 2026-11-09**, boot-тест exit 0; но в pck остаётся
   `MCPRuntime` и dev-инструменты, а ручной запуск клиента не проверялся.
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
3. **Уступ Горного короля — геометрия сходится.** `TyrantLedge` в
   `caravan_site_art.tscn` масштабирован `(2.4, 1.6, 2.4)` и стоит в
   `(0.8, 5.1, -4.5)`; верх `rock_outcrop_a` = `0.642 * 1.6 + 5.1 = 6.127`.
   Ступни Тирана на `6.15` — зазор 2.3 см, уступ под ним. Осталась только
   визуальная проверка кадра (не геометрия).
4. **Смерть ветерана не проигрывается (блокер).** У модели есть клип
   `HumanDeath` (1.8 с), но после `pose = "dying"/"dead"` у
   `AnimationPlayer` остаётся пустой `current_animation`; ветеран стоит с
   копьём, а не лежит. `MannequinPoseModifier` умеет только `kneel/read/point`.
   Нужен либо рабочий death-клип для UAL-скелета, либо процедурная укладка
   тела (поворот модели + скрытие копья) и проверка кадром.
5. **Жесты NPC.** Позы `kneel`/`dead` включаются только в `show_aftermath`;
   в диалогах NPC в основном статичны. Нет системы жестов для ключевых beat.
6. **Парк.** Земля — тёмный box-fill без тротуара/дороги; фасады добавлены, но
   передний план всё ещё пустоват. Нужен слой дороги/бордюра.
7. **Полицейский участок.** Лобби собрано (стойка, терминал, турели, плиты,
   свет), но комната содержания и допросная могут оставаться пустыми.
8. **Миникарта.** Карты для `containment_room` и `mountain_vision` добавлены,
   но визуально не проверены. `spell_void` карту скрывает — это ожидаемо.
9. **Камера повозки.** Вынесена из кузова, но кадр при столкновении/падении
   вручную не проверен.
10. **Освещение.** Яркость cave/ledge приглушена, но сцена всё ещё плоская:
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
