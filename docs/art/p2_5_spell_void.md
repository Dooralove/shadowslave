# P2.5 — Spell Void: переход из реального мира в Первый Кошмар

**Дата:** 2026-11-02  
**Область:** L04 / B13 (`spell_void`) — мост между P2 (реальный мир) и P3 (Первый Кошмар).  
**Статус:** визуальный переход реализован и встроен в `SliceDirector`; геймплей, маршруты и коллизии не менялись.

![P2.5 Spell Void contact sheet](previews/p2_5_spell_void/p2_5_contact_sheet.png)

## 1. Что было пропущено

`scenes/slice/locations/spell_void.tscn` был пустой чёрной сценой: в B13 (`B13_DARKNESS`) игрок видел только чёрный экран, системное сообщение Spell и сразу попадал в B14 (`mountain_vision`). Визуального перехода «Санни проваливается из реального мира в Кошмар» не было.

P2.5 закрывает именно этот разрыв, не вторгаясь в P3:

- **B13** — тёмная пустота, рунный круг, силуэт Санни, частицы, камера;
- затем — сообщение Spell;
- затем — существующая B14 (`mountain_vision_art`) и дальнейший маршрут P3.

## 2. Реализация

**Сцена:** `scenes/slice/locations/spell_void.tscn`  
**Скрипт:** `scripts/slice/locations/spell_void.gd`  
**VFX:** `scenes/environment/p25_void_motes.tscn`

- чёрная пустота с AgX, volumetric fog, glow, SSAO/SSIL/SSR;
- чёрный пол с отражениями и центральный рунный круг: три кольца, спицы, 8 рунных меток;
- силуэт Санни (`sunny_p1_model`) с idle-анимацией; в B13 основной visual игрока скрыт;
- три слоя частиц: холодные мотыльки, тёмные «щупальца» и голубые искры;
- холодный key/rim, пульсирующий свет рун;
- камера: медленный наезд с `SpellShot` к центру, затем пульсация кольца.

**Интеграция:** `scripts/slice/slice_director.gd`, B13:

1. fade to black;
2. загрузка `spell_void`;
3. fade-in пустоты;
4. `play_cutscene("spell")`;
5. существующее сообщение Spell;
6. переход в B14 `mountain_vision`.

## 3. Файлы

**Новые:**

- `scenes/slice/locations/spell_void.tscn` (расширен; раньше был пустой)
- `scripts/slice/locations/spell_void.gd`
- `scenes/environment/p25_void_motes.tscn`
- `tools/audit/p2_5_capture.gd`

**Изменены:**

- `scripts/slice/slice_director.gd` — только B13: fade-in void и вызов cutscene;
- `tools/audit/p3_validate.gd` — добавлены P2.5-сцены в проверку.

## 4. Проверки

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `p3_validate.gd` (включая P2.5) | 20/20 сцен, failed=0 |
| `test_slice_locations` | 8/8, 48 assert, exit 0 |
| `test_campaign_flow` | 10/10, 83 assert, exit 0 |
| `test_spell_void_transition` | 3/3, 15 assert, exit 0 |
| Полный GUT | 71 скриптов, 557 теста, 557 pass, 6761 assert, exit 0 |
| Рендеры | `p2_5_capture.gd`, 1280×720; контактный лист в `docs/art/previews/p2_5_spell_void/` |

**NOT TESTED:** ручной playthrough перехода, 1080p/60 FPS, субъективная оценка длительности/темпа на реальном мониторе. Это не заявляется как пройденное.

## 5. Допущение

В репозитории не было отдельного документа с названием P2.5; реализован **L04/B13 Spell Void**, единственный незакрытый визуальный мост между P2 и P3. Если под P2.5 подразумевался другой набор, это нужно уточнить отдельно; P3-арт и маршрут не затрагивались.
