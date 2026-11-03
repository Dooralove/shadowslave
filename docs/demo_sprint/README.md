# Demo Sprint — ShadowSlave

Дата открытия: 2026-11-02  
Владелец процесса: Chat 00 — Technical Director / Executive Producer / Integration Lead  
Статус: **Stage 3 — design package DP-1.0 зафиксирован; массовая реализация не начата.**  
Итог: `MASTER_PLAN.md`, `FILE_OWNERSHIP.md`, `implementation/AGENT_TASKS.md`, `implementation/INTEGRATION_CONTRACTS.md`; ранее — `MASTER_AUDIT.md`, `BACKLOG.md`, `DEMO_FLOW.md`, `DECISIONS.md`.

## 1. Цель спринта

Собрать **одно** демонстрационное прохождение, а не одиннадцать несовместимых наборов изменений.

Ограничения:

- рабочий спринт — примерно **3 часа**;
- приоритет — **полноценное демонстрационное прохождение**;
- изменения принимаются только через общий дизайн-план, контракты и распределение файлов;
- чужие незакоммиченные изменения не удаляются и не перезаписываются.

## 2. Целевая программа

**Решение пользователя: реализовать весь сюжет, все локации и все модели.**

Это производственная программа на несколько спринтов. Текущий 3-часовой milestone — **первый играбельный вертикальный срез пост-Кошмарной цепочки**:

```text
main_menu
  → «После Кошмара»
  → police_precinct
  → academy_approach → academy_gate → academy_campus → academy_sleeper_center
  → black_sea_platform → tide_descent → labyrinth_first_fragment
  → финальная точка / возврат в меню
```

Полный контракт, этапы M0–M7 и границы — `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md`.

Коротко:

- **Текущий milestone:** вход из меню, цели, взаимодействия, переходы, читаемость, звук, финальная точка, зелёный целевой набор тестов.
- **Следующие этапы:** академия, 18 зон Лабиринта, Acts C–D (утёсы, Кость-Хребет, Пепельная пустошь, Древо Души), западный город, релизная полировка.
- **Все модели:** только через конвейер retopo → UV/tangents → rig/weights → LOD → PBR → Godot; текущие GLB — fallback, не «финал».
- **Не обещаем:** весь сюжет за 3 часа. Обещаем один играбельный конец и работающий конвейер для остального.

### 2.0. Статус M2 (2026-11-02 23:55; исторический)

- M2-контент добавлен: участок, подъезд, ворота, кампус, Sleeper Center, Чёрное море, спуск.
- NPC/диалоги/интерактивы Stage 2: Джет, охрана, медик, зеркало, капсула, звёзды, меч, спуск. **Джулиус перенесён в M2** решением Stage 3; текущий placeholder в Sleeper Center вне M1.
- Аудио: музыка/эмбиент по сценам через `AudioDirector`.
- Импорт — exit 0. GUT: стабильный срез 632/632; после N18/N07/N25 — 633/634 с транзиентным parse error. Чистого полного прогона после Stage 3 нет.
- Модели — `Mannequin`-плейсхолдеры; Hyper3D-конвейер — следующий шаг.
- Ручной проход — **NOT TESTED**.

### 2.1. Статус M1 (2026-11-02 21:20)

- Вход из меню и кнопка на финале N26 — **есть**.
- Цепочка `police_precinct → … → labyrinth_first_fragment → post_nightmare_finale` — **связана**.
- HUD целей и подсказок — **добавлен** через `GameplayHud` в `GreyboxLocation`.
- Финальная карточка демо — **есть**.
- Полный GUT — **632/632** на стабильном срезе; после N18/N07/N25 — **633/634** с одним транзиентным parse error. Это не чистый PASS; M1 gate требует 0 fail.
- Сцены получили NPC, диалоги, HUD и аудио; модели — плейсхолдеры.
- Полный ручной проход — **NOT TESTED**.

## 3. Структура

```text
docs/demo_sprint/
  BASELINE.md                  исходное состояние, проверки, ограничения
  MASTER_AUDIT.md              единый аудит всех систем
  BACKLOG.md                   все задачи с ID, приоритетами и критериями
  MASTER_PLAN.md               DP-1.0: объём, порядок, приёмка, консистентность
  FILE_OWNERSHIP.md            единственный актуальный file-level ownership
  DEMO_FLOW.md                 законченный сценарий M1 + tech demo
  DECISIONS.md                 решения спринта и открытые вопросы
  EXPECTED_REPORTS.md          перечень и формат десяти отчётов
  OWNERSHIP.md                 исторический ownership draft; заменён FILE_OWNERSHIP
  README.md                    этот файл
  audits/                      отчёты десяти направлений + глобальный аудит TD
  design/                      единый дизайн-план и контракты систем
  implementation/              AGENT_TASKS, INTEGRATION_CONTRACTS, active claims
  qa/                          чек-листы, прогоны, release gate
```

## 4. Порядок работы

1. **Аудит.** Каждый чат пишет отчёт в `docs/demo_sprint/audits/` по формату `EXPECTED_REPORTS.md`. Игровые файлы на этом этапе не переписываются.
2. **Консолидация.** TD сводит отчёты, фиксирует решения, обновляет `design/00_DEMO_SCOPE_AND_CONTRACT.md`, назначает P0/P1 и владельцев файлов.
3. **Реализация.** Только после консолидации. Каждый чат работает в своих путях из `FILE_OWNERSHIP.md`; общие файлы — только через TD.
4. **Интеграция.** TD собирает изменения, запускает импорт, GUT и живой прогон.
5. **QA / release gate.** `qa/` фиксирует фактические результаты. Незапущенное помечается **NOT TESTED**.

## 5. Статус отчётов

| # | Направление | Ожидаемый файл | Статус |
|---:|---|---|---|
| 00 | Technical Director | `audits/00_TECHNICAL_DIRECTOR_GLOBAL_AUDIT.md` | **получен** |
| 01 | Narrative & Story | `audits/01_narrative_story.md` | **получен** (`narrative.md`) |
| 02 | Side Quest Design | `audits/02_side_quest_design.md` | **получен** как `quests.md` |
| 03 | World & Level Design | `audits/03_world_level_design.md` | **получен** (`level_design.md`) |
| 04 | Gameplay & Quest Systems | `audits/04_gameplay_quest_systems.md` | **получен** (`gameplay_systems.md`) |
| 05 | Combat & Enemy AI | `audits/05_combat_enemy_ai.md` | **получен** (`combat_ai.md`) |
| 06 | Character & Animation | `audits/06_character_animation.md` | **получен** как `characters_animation.md` |
| 07 | Environment Art | `audits/07_environment_art.md` | **получен** (`environment_art.md`) |
| 08 | UI/UX | `audits/08_ui_ux.md` | **получен** как `ui_ux.md` |
| 09 | Audio & VFX | `audits/09_audio_vfx.md` | **получен** (`audio_vfx.md`) |
| 10 | QA & Release | `audits/10_qa_release.md` | **получен** (`qa_baseline.md`) |

Все 11 отчётов сведены в `MASTER_AUDIT.md`; задачи — в `BACKLOG.md`; сценарий — в `DEMO_FLOW.md`; решения — в `DECISIONS.md`.

Отчёт считается принятым, когда:

- лежит в `docs/demo_sprint/audits/`;
- содержит сводку, факты, расхождения «документ ↔ код», P0/P1/P2, риски интеграции и `NOT TESTED`;
- не меняет игровые файлы вне своей зоны;
- указывает, какие файлы автор готов взять в реализацию.

## 6. Жёсткие правила

- Не коммитить, не push, не переключать ветку и не чистить рабочее дерево без отдельного задания.
- Не удалять и не перезаписывать чужие незакоммиченные изменения.
- Не менять общую архитектуру, `project.godot`, autoload-контракты и общие ресурсы без TD.
- Не добавлять новые MCP-серверы, внешние ассеты и генерации без решения пользователя.
- Не выдавать headless-тесты за ручной проход. Всё непроверенное — **NOT TESTED**.
- Один файл — один владелец. Совместные файлы ведутся через `implementation/ACTIVE_CLAIMS.md`.

## 7. Ссылки

- `docs/demo_sprint/BASELINE.md`
- `docs/demo_sprint/EXPECTED_REPORTS.md`
- `docs/demo_sprint/OWNERSHIP.md`
- `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md`
- `docs/DECISIONS.md`
- `AGENTS.md`
