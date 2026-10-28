# Сквозной прототип Первого Кошмара

Версия: 2.0  
Дата: 2026-10-24  
Статус: **S00–S15 связаны в один маршрут; headless-проход 18 шагов зелёный; полный ручной графический проход NOT TESTED.**

## Назначение

Соединить пролог и восстановленные сегменты в один проходимый маршрут без параллельной игровой системы:

1. S00 — пролог «Nightmare Begins»: скамейка, участок, изолятор, видение, караван, руны;
2. S01 — марш в цепях и прибытие к стоянке;
3. S02–S06 — стоянка, нападение, личинка, ключ, повозка, последействие, ночь и рассвет;
4. S07–S12 — разрушенная дорога, восхождение, альков, Учёный, пещера, Герой, подход к храму;
5. S13 — алтарь, семь подношений, Тиран, тени и завершение испытания;
6. S14 — звёздная оценка, True Name, Shadow Slave, Shadow Bond, First Seal;
7. S15 — пробуждение, Flaw без имени, финальная карточка.

Каждый переход — небольшая оболочка, которая инстанцирует готовую сцену и использует её сигналы. Межсценовое состояние хранится в autoload `NightmareRunState`.

## Маршрут

```text
scenes/campaign/campaign_entry.tscn
  └─ scenes/slice/prologue.tscn
       ↓ prologue_completed
scenes/campaign/first_nightmare_pass.tscn
  └─ scenes/slice/locations/caravan_road.tscn
       ↓ camp_reached
scenes/campaign/caravan_site_arrival.tscn
  └─ scenes/locations/caravan_site/caravan_site.tscn
       ↓ dawn_departure
scenes/campaign/pilgrim_path_arrival.tscn
  └─ scenes/locations/pilgrim_path/pilgrim_path.tscn
       ↓ temple_reached
scenes/campaign/sanctuary_arrival.tscn
  └─ scenes/locations/shadow_sanctuary/shadow_sanctuary.tscn
       ↓ trial_completed / tyrant_death_confirmed
scenes/campaign/appraisal_arrival.tscn
       ↓ appraisal_completed
scenes/campaign/finale_arrival.tscn
       ↓ first_nightmare_completed
финальная карточка / R → campaign_entry
```

`scenes/campaign/caravan_ambush.tscn` и `scenes/levels/ambush_site_demo.tscn` — отдельный sandbox, не часть маршрута.

## Состояние и правила

- `NightmareRunState` хранит только флаги и сюжетные предметы, не ссылки на узлы.
- `reset()` вызывается при старте кампании и по `R`.
- `key` расходуется при освобождении; `sword` удаляется в S07; `silver_bell` остаётся Памятью после использования.
- `tyrant_death_confirmed` появляется только после сцены теней в S13.
- `first_nightmare_completed` выставляется только в S15.
- `appraisal_arrival.tscn` требует `temple_reached` + `trial_completed`; `finale_arrival.tscn` — `temple_reached` + `trial_completed` + `appraisal_completed`. Прямой запуск закрывает гейт и перенаправляет в кампанию.
- Одноразовые взаимодействия защищены флагами; повторный вход не выдаёт награды заново.

## Управление в прототипе

| Действие | Клавиша |
|---|---|
| Движение | W / A / S / D |
| Бег | Shift |
| Прыжок | Space |
| Обзор | мышь |
| Взаимодействие | E |
| Продвижение диалога | E / Space / Enter |
| Статус Заклятия | Tab |
| Освободить мышь | Escape |
| Перезапуск | R |

## Проверка

Полный GUT:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Фактический результат: **35 scripts / 255 tests / 2473 asserts, all passed**.

Ключевой тест маршрута: `tests/test_full_route.gd` — 2/2, 151 assert. Он проходит 18 шагов от чистого состояния до финальной карточки и проверяет отсутствие преждевременного завершения.

## Что не входит

- Новый боевой баланс и полноценная боевая система Тирана.
- Симуляция десятков рабов с индивидуальным AI.
- Полный лицевой риг и кинематографическая мимика.
- Удаление старых sandbox-сцен и арт-вариантов парка.
- Изменение глобальных настроек Git, LFS или удалённых репозиториев.

## Ограничения

- Полный ручной графический проход от `campaign_entry` до финальной карточки — **NOT TESTED**.
- Альков и пещера очень тёмные; тени-руки читаются как чёрные стержни; кадр стадии `TYRANT` не сохранён.
- Один прогон `test_mountain_king` дал transient-сбой, немедленный повтор прошёл; требуется отдельное воспроизведение.
- `mark_of_divinity` — флаг-атрибут, выставляется на B16; в инвентарь не входит. Страж храма B3 не реализован.

Подробная матрица: `docs/design/first_nightmare_scene_matrix.md`. Проверка: `docs/design/first_nightmare_route_verification.md`. Handoff: `docs/AI_HANDOFF_AFTER_S3_2.md`.
