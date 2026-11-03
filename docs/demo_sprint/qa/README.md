# QA — чек-листы и release gate

Актуальный отчёт: `docs/demo_sprint/qa/FINAL_QA_REPORT.md`
Stage 3 baseline: `docs/demo_sprint/qa/BASELINE_RESULTS.md`
Bug registry: `docs/demo_sprint/qa/BUG_REGISTRY.md`
Stage 4 playtest: `docs/demo_sprint/qa/STAGE4_PLAYTEST.md`
План: `docs/demo_sprint/qa/TEST_PLAN.md`
Implementation spec: `docs/demo_sprint/implementation/qa_release_implementation.md`
Старые QA-заметки: `docs/demo_sprint/qa/QA_ISSUES.md`

## Минимальный release gate

| # | Проверка | Команда / метод | Статус |
|---:|---|---|---|
| 1 | Импорт | `godot --headless --path . --import` | **PASS** (exit 0, 0 ошибок) |
| 2 | Полный GUT | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` | **PASS** (636/636, 7333 asserts, 2026-11-03 01:35) |
| 3 | Главное меню | запуск `main_menu.tscn` | **PASS** |
| 4 | Кампания | запуск `campaign_entry.tscn` | **PASS** |
| 5 | Непрерывный проход | ручной, от меню до финальной карточки | **NOT VERIFIED** |
| 6 | `R` | сброс и возврат в начало | **PASS** (тесты) |
| 7 | Консоль | нет новых ошибок/parse errors | **PASS WITH LIMITATIONS** (warnings) |
| 8 | Пост-Кошмарные сцены | прямой запуск, без падений | **PASS WITH LIMITATIONS** (blockout) |
| 9 | Лабиринт | прямой запуск, без падений | **FAIL** (Z07/Z10 route; Z12 под вопросом) |
| 10 | Аудио | музыка/эмбиент/SFX, без дублей | **NOT VERIFIED** (тесты есть, на слух нет) |
| 11 | Экспорт | Windows preset + артефакт | **FAIL / BLOCKED** (нет `export_presets.cfg`) |

## Формат записи

```markdown
## YYYY-MM-DD HH:MM — <проверка>
- HEAD: <hash>
- Команда: ...
- Результат: ...
- Exit code: ...
- Что не проверено: ...
- Вердикт: PASS / PASS WITH LIMITATIONS / FAIL / NOT VERIFIED / BLOCKED
```

## Правила

- Не писать PASS без вывода.
- Не выдавать headless за ручной проход.
- Падения фиксировать с текстом assert.
- После каждой интеграционной правки — минимум целевой тест.
- Полный GUT — на freeze-точках, не после каждой правки.
- Доказательства привязывать к HEAD и времени; грязное дерево делает старые прогоны недействительными.
