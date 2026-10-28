# Каноническая матрица сцен Первого Кошмара

Статус: **актуально после C4–C9**  
Дата: 2026-10-24  
Основа: `docs/story/first_nightmare_canonical_timeline.md` (блоки 01–20), `docs/design/first_nightmare_restoration_spec.md`, `tests/test_full_route.gd`.  
Назначение: одна таблица, по которой можно проверить, какая сцена отвечает за каждый канонический блок, какие флаги она выставляет и чем это подтверждено. Это не замена художественному канону и не разрешение менять сцены.

## 1. Актуальный маршрут

```text
scenes/campaign/campaign_entry.tscn
  └─ scenes/slice/prologue.tscn                         S00, блоки 01–04
       ↓ prologue_completed
scenes/campaign/first_nightmare_pass.tscn                S01, блок 05
  └─ scenes/slice/locations/caravan_road.tscn
       ↓ CampArrival / camp_reached
scenes/campaign/caravan_site_arrival.tscn                S02–S06, блоки 06–12
  └─ scenes/locations/caravan_site/caravan_site.tscn
       ↓ dawn_departure
scenes/campaign/pilgrim_path_arrival.tscn                S07–S12, блоки 13–17
  └─ scenes/locations/pilgrim_path/pilgrim_path.tscn
       ↓ temple_reached
scenes/campaign/sanctuary_arrival.tscn                   S13, блок 18
  └─ scenes/locations/shadow_sanctuary/shadow_sanctuary.tscn
       ↓ trial_completed / tyrant_death_confirmed
scenes/campaign/appraisal_arrival.tscn                   S14, блок 19
       ↓ appraisal_completed
scenes/campaign/finale_arrival.tscn                      S15, блок 20
       ↓ first_nightmare_completed
финальная карточка / R → campaign_entry
```

`scenes/campaign/caravan_ambush.tscn` и `scenes/levels/ambush_site_demo.tscn` — **не** часть канонического маршрута. Это сохранённый sandbox для проверки укрытия и побега. Его нельзя удалять или считать канонической засадой.

## 2. Матрица блоков 01–20

| Блок | Каноническое событие | Сцена / обёртка | Фаза или точка | Ключевые флаги и предметы | Подтверждение | Статус |
|---:|---|---|---|---|---|---|
| 01 | Скамейка, кофе, улица | `scenes/slice/prologue.tscn` | B01 | — | пролог входит в кампанию; графический spot-check в этом проходе — **NOT TESTED** | Готово по коду |
| 02 | Участок, Code Black | `scenes/slice/prologue.tscn` | B02 | — | пролог; графический spot-check в этом проходе — **NOT TESTED** | Готово по коду |
| 03 | Изолятор, брифинг, засыпание | `scenes/slice/prologue.tscn` | B03 | — | пролог; графический spot-check в этом проходе — **NOT TESTED** | Готово по коду |
| 04 | Переход, видение, пробуждение, руны | `scenes/slice/prologue.tscn`, `scenes/slice/locations/mountain_vision.tscn`, `scenes/slice/locations/spell_void.tscn` | B15–B16 | `prologue_completed` | шаг 1–2 `test_full_route` проверяет только завершение пролога; B15–B16 графически — **NOT TESTED** | Готово по коду |
| 05 | Марш в цепях, знакомства каравана | `scenes/campaign/first_nightmare_pass.tscn` + `caravan_road.tscn` | марш, `CampArrival` | `march_intro_seen`, `camp_reached`, `chain_restrained` | шаг 3 `test_full_route`; `test_caravan_march`; графический spot-check — **NOT TESTED** в этом проходе | Готово по коду |
| 06 | Стоянка, еда, Bloodbane, осмотр | `scenes/campaign/caravan_site_arrival.tscn` + `caravan_site.tscn` | `CAMP` | `camp_rations_taken`, `camp_bloodbane_seen`, `camp_wagon_examined`, `camp_explored` | шаги 4–5 `test_full_route`; `test_caravan_site`; графический spot-check | Готово |
| 07 | Камнепад, первый удар Тирана, смерть широкоплечего | `caravan_site.tscn` | `ATTACK` | `attack_started`, `camp_completed`, `broad_slave_dead` | шаг 6 `test_full_route`; `test_caravan_site`; графический spot-check | Готово |
| 08 | Личинка, ключ, освобождение от цепи | `caravan_site.tscn` | `LARVA` | `larva_grabbed`, `larva_killed`, `chains_released`, `chain_restrained = false`; `key` расходуется | шаг 7 `test_full_route`; `test_caravan_site`; графический spot-check | Готово |
| 09 | План с повозкой, клинья, петля, падение Тирана | `caravan_site.tscn` | `WAGON` | `wagon_wedges_removed`, `wagon_loop_ready`, `wagon_fall_seen`, `tyrant_fall_seen`, `tyrant_alive_suspected`; **нет** `tyrant_death_confirmed` | шаг 8 `test_full_route`; `test_caravan_site`; графический spot-check | Готово |
| 10 | Выжившие, совет, задачи, фляги | `caravan_site.tscn` | `AFTERMATH` | `aftermath_started`, `survivors_four`, `survivors_council_done`, `tasks_assigned`, `camp_aftermath_completed` | шаг 9 `test_full_route`; `test_caravan_site`; графический spot-check — **NOT TESTED** в этом проходе | Готово по коду |
| 11 | Ветеран, Silver Bell, накидка, сапоги | `caravan_site.tscn` | `AFTERMATH` | `veteran_dead`, `veteran_sword_taken`, `silver_bell_obtained`, `has_cloak`, `has_boots`; предметы `silver_bell`, `cloak`, `boots` | шаг 9 `test_full_route`; `test_caravan_site`; графический spot-check — **NOT TESTED** в этом проходе | Готово по коду |
| 12 | Ночь у огня и рассвет | `caravan_site.tscn` | `NIGHT` → `DAWN` → `COMPLETE` | `night_started`, `night_passed`, `dawn_departure` | шаг 10 `test_full_route`; `test_caravan_site`; графический spot-check — **NOT TESTED** в этом проходе | Готово по коду |
| 13 | Разрушенная дорога, старая тропа, брошенный меч | `scenes/campaign/pilgrim_path_arrival.tscn` + `pilgrim_path.tscn` | `BROKEN_ROAD` / `ASCENT` | `road_gap_seen`, `sword_discarded`; `sword` удаляется | шаг 11 `test_full_route`; `test_pilgrim_path`; графический spot-check | Готово |
| 14 | Альков, слепота, смерть Шифти | `pilgrim_path.tscn` | `ALCOVE` | `alcove_reached`, `tyrant_sighting`, `shifty_dead`, `dawn_ascent`; тело Шифти остаётся | шаг 12 `test_full_route`; `test_pilgrim_path`; графический spot-check | Готово |
| 15 | Приманка, разоблачение Учёного | `pilgrim_path.tscn` | `SCHOLAR` | `scholar_confronted`, `scholar_abandoned`; Учёный исчезает | шаг 13 `test_full_route`; `test_pilgrim_path` | Готово |
| 16 | Пещера, признание, яд, ранение, побег | `pilgrim_path.tscn` | `CAVE` | `cave_entered`, `scholar_confession_seen`, `wound_taken`, `cave_escaped` | шаг 14 `test_full_route`; `test_pilgrim_path`; графический spot-check | Готово |
| 17 | Silver Bell, смерть Героя, подход к храму | `pilgrim_path.tscn` | `HERO_DEATH` → `TEMPLE_APPROACH` | `hero_confrontation_seen`, `silver_bell_used`, `hero_taken`, `hero_dead`, `temple_reached`; `silver_bell` остаётся Памятью | шаг 15 `test_full_route`; `test_pilgrim_path`; графический spot-check | Готово |
| 18 | Храм, алтарь, семь подношений, тени, смерть Тирана | `scenes/campaign/sanctuary_arrival.tscn` + `shadow_sanctuary.tscn` + `altar_ritual.gd` | `ALTAR` → `TYRANT` → `DEATH` | `trial_completed`, `tyrant_death_confirmed`, item `shadow_blessing`; **нет** `first_nightmare_completed` | шаг 16 `test_full_route`; `test_altar_offering`; графический spot-check | Готово |
| 19 | Звёздная оценка, True Name, Shadow Slave, Shadow Bond, First Seal | `scenes/campaign/appraisal_arrival.tscn` | `APPRAISAL` | `appraisal_started`, `appraisal_completed`, `final_appraisal_glorious`, `true_name_lost_from_light`, `aspect_shadow_slave`, `shadow_bond_known`, `first_seal_broken`, item `puppeteer_shroud`; **нет** финального флага | шаг 17 `test_full_route`; `test_appraisal_and_finale`; графический spot-check | Готово |
| 20 | Пробуждение, Flaw без имени, финальная карточка | `scenes/campaign/finale_arrival.tscn` | `AWAKENING` → `CARD` | `awakening_completed`, `first_nightmare_finished`, `first_nightmare_completed` | шаг 18 `test_full_route`; `test_appraisal_and_finale`; графический spot-check; `R` проверен | Готово |

## 3. Сквозные инварианты

1. **Один Санни.** Кампания использует `assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn`. POC не означает, что модель официально утверждена.
2. **Одноразовые взаимодействия.** Повторный вход в сцену не должен повторно выдавать награды: точки опираются на флаги, а не только на видимость.
3. **Постоянные отсутствия.** Широкоплечий, ветеран, Шифти, Учёный и Герой не возвращаются после своих канонических смертей/уходов.
4. **Цепь.** До ключа `chain_restrained = true`; после `chains_released` — false. Повторный вход не возвращает ограничение.
5. **Тиран.** `tyrant_death_confirmed` выставляется только после сцены теней в S13. Падение повозки даёт `tyrant_alive_suspected`, но не смерть.
6. **Финальный флаг.** `first_nightmare_completed` выставляется только в `finale.gd`. S13 завершает испытание, S14 выдаёт оценку, S15 завершает Кошмар.
7. **Гейты.** `appraisal.gd` требует `temple_reached` + `trial_completed`; `finale.gd` требует `temple_reached` + `trial_completed` + `appraisal_completed`. Прямой запуск этих сцен перенаправляет в кампанию; `redirect_without_gate = false` используется только тестами.
8. **Имя флага храма.** В коде канонический флаг — `temple_reached`. Старое написание `temple_entered` в документах считается устаревшим синонимом и не должно использоваться в новых проверках.

## 4. Что остаётся вне матрицы

- Полный ручной графический проход от `campaign_entry` до финальной карточки — **NOT TESTED**.
- Визуальная полировка: тёмные альков/пещера, тени-руки читаются как чёрные стержни, кадр стадии `TYRANT` не сохранён.
- `shadow_blessing` и `puppeteer_shroud` выдаются в S13/S14. `mark_of_divinity` — флаг-атрибут, выставляется на B16 и отображается в статусе; в `ITEM_IDS` и инвентарь не входит. Страж храма относится к B3 и ещё не реализован.
