# AI Handoff после S3.2 / C4–C9

Дата: 2026-10-24  
Ветка: `s3-park-art` (не переключалась)  
Состояние: **C4–C8 реализованы и проверены headless-тестами; C9 — документация и Git-аудит.** Коммитов, push и очистки рабочего дерева не было.

## 1. Что сделано

- Восстановлен сквозной маршрут Первого Кошмара S00–S15:
  `campaign_entry → first_nightmare_pass → caravan_site_arrival → pilgrim_path_arrival → sanctuary_arrival → appraisal_arrival → finale_arrival`.
- S02–S06: стоянка, нападение, личинка, ключ, освобождение, повозка, падение Тирана, последействие, ветеран, Silver Bell, ночь и рассвет.
- S07–S12: разрушенная дорога, восхождение, альков, смерть Шифти, разоблачение Учёного, пещера, ранение, смерть Героя, подход к храму.
- S13: алтарь, семь подношений, Тиран, тени, `trial_completed`/`tyrant_death_confirmed`, item `shadow_blessing`.
- S14: оценка, `glorious`, True Name, Shadow Slave, Shadow Bond, First Seal, item `puppeteer_shroud`.
- S15: пробуждение, Flaw без имени, финальная карточка, `first_nightmare_completed` только здесь.
- Добавлены закрытые гейты для `appraisal_arrival.tscn` и `finale_arrival.tscn`; прямой запуск не обходит оценку.
- Добавлен `tests/test_full_route.gd`: связность сцен и 18-шаговый headless-проход после пролога (B01–B16 не проигрываются).

## 2. Ключевые архитектурные решения

1. **Один маршрут, без параллельной кампании.** Обёртки в `scenes/campaign/` инстанцируют готовые локации и слушают их сигналы.
2. **Состояние — autoload `NightmareRunState`.** Только флаги и сюжетные предметы; никаких ссылок на узлы.
3. **Две большие локации вместо телепортов.** `caravan_site.tscn` и `pilgrim_path.tscn` — state machine с фазами.
4. **Смерти постоянны.** Повторный вход не воскрешает широкоплечего, ветерана, Шифти, Учёного и Героя.
5. **S13 не завершает Кошмар.** `AltarRitual` завершает только испытание; `first_nightmare_completed` выставляется в S15.
6. **Гейты поздних сцен.** `appraisal` требует `temple_reached + trial_completed`; `finale` — `temple_reached + trial_completed + appraisal_completed`. `redirect_without_gate = false` — только тестовый режим.
7. **Флаг храма — `temple_reached`.** Старое `temple_entered` в документах считается устаревшим синонимом.
8. **Модель Санни — POC.** `sunny_waking_poc.tscn` используется во всех сюжетных сценах; официального утверждения модели нет.
9. **Sandbox не удалён.** `caravan_ambush.tscn` и `ambush_site_demo.tscn` остаются неканоническими сценами для проверки укрытия/побега.

## 3. Где что лежит

| Область | Пути |
|---|---|
| Точка входа | `scenes/campaign/campaign_entry.tscn`, `scripts/campaign/campaign_entry.gd` |
| Марш | `scenes/campaign/first_nightmare_pass.tscn`, `scripts/campaign/first_nightmare_pass.gd`, `scenes/slice/locations/caravan_road.tscn` |
| Лагерь | `scenes/campaign/caravan_site_arrival.tscn`, `scenes/locations/caravan_site/caravan_site.tscn`, `scripts/slice/locations/caravan_site.gd` |
| Тропа | `scenes/campaign/pilgrim_path_arrival.tscn`, `scenes/locations/pilgrim_path/pilgrim_path.tscn`, `scripts/slice/locations/pilgrim_path.gd` |
| Святилище | `scenes/campaign/sanctuary_arrival.tscn`, `scenes/locations/shadow_sanctuary/shadow_sanctuary.tscn`, `altar_ritual.gd` |
| Оценка | `scenes/campaign/appraisal_arrival.tscn`, `scripts/campaign/appraisal.gd`, `resources/spell/appraisal_messages.tres` |
| Финал | `scenes/campaign/finale_arrival.tscn`, `scripts/campaign/finale.gd`, `resources/spell/awakening_messages.tres` |
| Состояние | `scripts/campaign/nightmare_run_state.gd` (autoload `NightmareRunState`) |
| Тесты | `tests/test_full_route.gd`, `test_caravan_site.gd`, `test_pilgrim_path.gd`, `test_altar_offering.gd`, `test_appraisal_and_finale.gd` |
| Документация | `docs/design/first_nightmare_scene_matrix.md`, `docs/design/first_nightmare_route_verification.md`, `docs/design/first_nightmare_restoration_spec.md`, `docs/design/first_nightmare_gap_matrix.md`, `docs/design/first_nightmare_prototype_flow.md` |

## 4. Проверка

Полный GUT:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Фактический результат последнего запуска:

```text
Scripts              35
Tests               255
Passing Tests       255
Asserts            2473
All tests passed!
```

Целевые результаты:

| Тест | Результат |
|---|---|
| `test_full_route.gd` | 2/2, 151 assert |
| `test_caravan_site.gd` | 5/5, 425 asserts |
| `test_pilgrim_path.gd` | 5/5, 108 asserts |
| `test_altar_offering.gd` | 6/6, 67 asserts |
| `test_appraisal_and_finale.gd` | 5/5, 38 asserts |

Графические spot-check'и: стоянка, нападение, личинка/ключ, повозка, восхождение, альков/рассвет, пещера/Герой, святилище/алтарь, оценка, финал, `R`. Марш S01, aftermath/ночь в лагере и пролог B01–B16 в этом проходе графически — **NOT TESTED**. Полный ручной проход — **NOT TESTED**.

## 5. Backlog по приоритетам

### P1 — до следующей приёмки

1. **Полный ручной графический проход** от `campaign_entry` до финальной карточки. Это главный невыполненный критерий.
2. **Освещение алькова и пещеры.** Сейчас сцены очень тёмные; нужен световой/композиционный проход без изменения логики.
3. **Тени-руки в святилище.** Читаются как чёрные стержни; нужна форма кистей/пальцев или более выразительный силуэт.
4. **Кадр стадии `TYRANT`.** Сохранить визуальное доказательство стадии до смерти, а не только `DEATH`.

### P2 — целостность контента

5. **`mark_of_divinity` (B2, решено).** Это флаг-атрибут, выставляется на B16 и отображается в статусе; в `ITEM_IDS`/инвентарь не входит. Для B3 остаётся проверка стража храма.
6. **Flaw flag.** Текст Flaw показывается, но отдельного флага `flaw_received` нет. Решить, нужен ли он для будущих сцен.
7. **Transient-сбой `test_mountain_king`.** Один полный прогон дал failure в `test_activation_can_wait_for_target_that_appears_later`; немедленный повтор прошёл. Проверить изоляцию группы `player` между тестами.

### P3 — полировка

8. Единый художественный проход по POC-модели Санни и NPC.
9. Проверить длительности диалогов, звук, субтитры и пропуск длинных сцен на всём маршруте.
10. Проверить производительность и читаемость на разных разрешениях.
11. Проверить геймпад и переназначение клавиш.

## 6. Ограничения и предупреждения

- **Не коммитить, не push, не переключать ветку, не чистить рабочее дерево** без отдельного задания.
- В рабочем дереве есть многочисленные pre-existing изменения и untracked-файлы, не относящиеся к C4–C9. Не удалять и не перезаписывать их.
- `scenes/campaign/caravan_ambush.tscn` и `scenes/levels/ambush_site_demo.tscn` — неканонический sandbox; сохранить.
- Основная сцена проекта остаётся `res://scenes/main/main.tscn`; кампания запускается явно через `res://scenes/campaign/campaign_entry.tscn`.
- Скриншоты MCP лежат в `res://addons/godot_mcp/cache/screenshots/` и не являются durable/committed evidence.
- Не выдавать headless-тесты за полный ручной проход. Всё, что не проверялось вручную, помечено **NOT TESTED**.

## 7. Следующий разумный шаг

1. Запустить `campaign_entry.tscn` и пройти маршрут вручную, фиксируя баги по сценам.
2. Исправить P1-визуал (свет алькова/пещеры, тени-руки) и сохранить кадр `TYRANT`.
3. Разобрать P2: `flaw_received`, flaky `test_mountain_king`; B3 — страж храма и проверки святилища.
4. После ручного прохода обновить `first_nightmare_route_verification.md` и этот handoff.

## 8. Git-аудит на 2026-10-24

- Ветка: `s3-park-art`; переключений не было.
- Коммитов, push, сброса/очистки рабочего дерева не было.
- `git diff --check` — без ошибок.
- `git status --short --branch`: 116 строк, из них 16 modified tracked и 99 untracked; это не «чистое» дерево, а текущее рабочее состояние с pre-existing изменениями S1–S3.
- Tracked-изменения: `README.md`, `docs/DECISIONS.md`, `project.godot` (autoloads), `caravan_road.tscn`, `caravan_road.gd`, `dialogue_runner.gd`, `sunny_controller.gd`, `spell_message_ui.gd` и 8 `.import`-файлов POC-текстур. `.import`-файлы и большая часть кода — pre-existing изменения, не удалялись и не перезаписывались в C9.
- Новые файлы C4–C9: `docs/AI_HANDOFF_AFTER_S3_2.md`, `docs/design/first_nightmare_scene_matrix.md`, `docs/design/first_nightmare_route_verification.md`, обновлённые `first_nightmare_gap_matrix.md`/`restoration_spec.md`/`prototype_flow.md`, сцены/скрипты кампании, ресурсы диалогов и тесты. Большая часть каталогов `scenes/campaign/`, `scenes/locations/`, `scripts/campaign/`, `tests/` уже была untracked до этого этапа.
- Новых бинарных ассетов, `.env`, токенов и секретов в C4–C9 не добавлялось. Абсолютные пути в новых документах не записывались; команды используют `--path .`.
- `opencode.json` остаётся untracked pre-existing файлом; не изменялся и не анализировался как часть C4–C9.
- Полный вывод `git status --short --branch` сохранён локально в `%TEMP%\opencode\git_status_final.txt` и не коммитится.
