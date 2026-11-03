# NPC placeholders — A06 handoff

Эти prefab-ы — **M1 placeholders**, не финальные модели. A06 владеет prefab-ами;
A03 ставит их в `scenes/locations/**` в точках POI. A06 не правит локации.

| Prefab | Модель | POI / сцена | Поза по умолчанию | Пометка |
|---|---|---|---|---|
| `jett.tscn` | `mass_female` + тёмно-синяя форма | P06 `academy_approach` | idle | placeholder |
| `rock.tscn` | `mass_male`, крупный | P09 `academy_sleeper_center` | idle | placeholder |
| `kasper.tscn` | `mass_male`, тёмная форма с золотым акцентом | P09 | idle | placeholder |
| `cassia.tscn` | `mass_female`, белая форма, blindfold | Z08 / P09 | listen | placeholder |
| `nephis.tscn` | `mass_female`, серебряные волосы, плащ и копьё | Z08 / Z10 | guard | placeholder |
| `academy_guard.tscn` | `police_guard`, перекраска | P07 | check | placeholder |
| `sleeper_crowd.tscn` | 6 `mass_*` Mannequin | P09 | idle/talk | placeholder |

## Как использовать

1. Инстанс prefab в локации, позиция по `poi_manifest.md`.
2. Для смены позы: `$Jett.pose = "point"` (доступны `idle`, `talk`, `walk`,
   `point`, `gesture`, `cross_arms`, `listen`, `head_turn`, `lean`, `check`,
   `walk_away`, `leave`, `wave`, `argue`, `guard`, `sit`, `dead`).
3. Для диалога/квеста используйте существующий `QuestNpc`/`Interactor`;
   prefab — только визуальный слой.
4. Не добавляйте коллизию на prefab: проходы P06/P09/Z08/Z10 не должны
   блокироваться. Если нужна коллизия, её ставит A03 отдельным узлом.

## Ограничения

- Материалы перекрашиваются на инстансе; исходные GLB не меняются.
- Копьё/плащ/повязка — простые placeholder-меши, не скинированы.
- Финал Jett/Rock/Kasper/Cassia/Nephis — M2/M3, не M1.
