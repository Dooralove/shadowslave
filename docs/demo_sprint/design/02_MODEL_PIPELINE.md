# Model Pipeline — от GLB до игрового персонажа

Дата: 2026-11-02  
Назначение: один конвейер для всех моделей сюжета, чтобы «все модели» не превратились в 50 несвязанных GLB.  
Основа: `docs/art/character_asset_audit_2026-11-02.md`, `docs/art/generation_queue_2026-11-02.md`, `docs/art/asset_production_standards.md`.

## 1. Текущее состояние

| Категория | Есть | Качество | Вердикт |
|---|---|---|---|
| Sunny | `sunny_real`, `sunny_nightmare`, POC `sunny_waking_poc` | POC/MPFB, 46–48k tri, без tangents | fallback, не финал |
| Караван | Hero, Shifty, Scholar, Veteran, BroadSlave, mass_* | 47–65k tri, double-sided, без tangents | fallback, v2 отклонён |
| Полиция | police_desk, police_guard, mass_police | 14–50k tri | fallback |
| Mountain King | p1/p2/p3 | 50–75k tri, без UV/текстур | p3 fallback |
| Larva | `larva_corpse_lod.glb` | 49.5k tri, 3 LOD, PBR | лучший монстр, можно оставить |
| Carapace | `carapace_scavenger.glb` | 9.7k tri, без UV/текстур | fallback, нужен v2 |
| Statue | `statue_knight_colossus.glb` + LOD1/2 | 49k tri LOD0, PBR | hero-ассет, принять |
| Coral kit | 60 GLB | PBR/трипланар | принять, нужна интеграция |
| Soul Sea kit | 63 GLB | статичные тени | принять, нужна интеграция |
| Horse | `horse.glb` | 690 tri, low-poly | placeholder |
| Nephis/Cassia/Echo | маркеры | нет моделей | не начинать без сцены |

## 2. Конвейер (обязательный)

```text
1. Brief / canon check
2. Generate or source (GLB)
3. Inspect: tris, UV, tangents, materials, islands, non-manifold
4. Retopo / clean (Blender)
5. UV + tangents + PBR maps
6. Rig (humanoid 53-bone or custom) + weights
7. Animation clips (idle/walk/run/attack/telegraph/death/interact)
8. LOD0/1/2 + shadow mesh
9. Export GLB, glTF-Transform validate/optimize
10. Godot import, scene placement, material check
11. License registration
12. In-game screenshot / test
```

Ни один шаг нельзя пропускать. Модель без rig/weights — не персонаж, а статуя.

### 2.1. Технические требования

| Параметр | Требование |
|---|---|
| Формат | GLB, +Y up, meters |
| Поза | A-pose для гуманоидов, neutral для монстров |
| Полигоны | LOD0 ≤ 50k tri для героя, ≤ 30k для NPC, ≤ 15k для массовки |
| UV | UV0 обязателен; UV1 — по необходимости |
| Tangents | обязательны для normal maps |
| Материалы | PBR, opaque closed meshes — single-sided |
| Текстуры | 1K–2K, VRAM-компрессия, без embedded 4K |
| Rig | 53-bone humanoid (`SkeletonProfileHumanoid`) или custom |
| Клипы | idle, walk, run, attack, telegraph, hit, death, interact |
| LOD | 3 уровня, visibility ranges |
| Коллизия | capsule/box, не по мешу |
| Лицензия | `docs/ASSET_LICENSES.md` |

### 2.2. Приёмка

Модель принята, только если:

- открывается в Godot без ошибок;
- стоит в сцене в правильном масштабе;
- анимации не ломают скелет;
- нет «парящих» деталей и разорванных islands;
- LOD не мигает;
- материалы не розовые/чёрные;
- есть лицензия;
- есть скриншот/тест.

## 3. Очередь моделей

### P0 — текущий milestone (пост-Кошмар)

| Модель | Роль | Статус | Действие |
|---|---|---|---|
| Sunny (nightmare/real) | главный герой | POC | принять POC на milestone; финал — позже |
| Police desk/guard | участок | есть | оставить |
| Jet | машина/академия | нет | сгенерировать/собрать |
| Julius | академия | нет | сгенерировать |
| Academy crowd | массовка | mass_* | перекрасить/уменьшить |
| Carapace Scavenger | Лабиринт | fallback | v2 UV/текстуры |
| Statue | Чёрное море | есть | принять |
| Coral kit | Лабиринт | есть | интегрировать |

### P1 — Лабиринт

| Модель | Роль | Статус |
|---|---|---|
| Carapace Centurion | элита | нет |
| Centipede | враг | нет |
| Worm Knot | враг | нет |
| Blood Flower | враг | нет |
| Echo | NPC/эхо | нет дизайна |
| Nephis | спутник | маркер |
| Cassia | спутник | маркер |
| Theo | NPC | нет |
| Hero corpse / skeleton | декор | нет |

### P2 — поздний сюжет

Kai, Effie, Gunlaug, Black Knight, Great Devil, Sleepers, Blood Fiend, Starlight Legion, лодка, каменная рука.

## 4. Источники моделей

| Источник | Плюсы | Минусы | Решение |
|---|---|---|---|
| Hyper3D web UI | быстрый концепт | API недоступен, rig/weights грязные | использовать для концептов, не для финала |
| Hyper3D CLI | OAuth, генерация/rig | требует подписки, качество нестабильно | только после проверки |
| MPFB/MakeHuman | CC0, чистый humanoid | стиль, одежда | база для каравана/массовки |
| Sketchfab | готовые модели | лицензии, стиль | только CC0/CC BY, проверять |
| Blender вручную | контроль | время | hero-модели, статуя, декор |
| Poly Haven | окружение | не персонажи | пропсы |

**Правило:** не генерировать массовку, пока не решён главный каст. Не принимать модель без retopo/weights.

## 5. Анимации

- Humanoid: UAL/retarget или собственные клипы.
- Monsters: 5 клипов (idle/walk/telegraph/attack/death).
- `SunnyAnimator`/`EnemyAnimator`/`CarapaceAnimator` — существующие контракты.
- `AttackData.contact_time` — для попадания.
- Foot sliding — проверять в движении, не по скриншоту.
- Death/respawn — `reset_to_idle()`/`FallRecovery`.

## 6. Оптимизация

- `gltf-transform join` для статичных мешей.
- LOD0/1/2, shadow mesh off для дальних.
- Текстуры 1K/2K, VRAM-компрессия.
- MultiMesh для массовки/декора.
- Occlusion culling, mesh LOD threshold.
- Профилировать в реальной сцене, не в preview.

## 7. Лицензии

Каждый внешний ассет:

1. источник;
2. автор;
3. лицензия;
4. ссылка;
5. дата;
6. где используется.

Без записи в `docs/ASSET_LICENSES.md` модель не попадает в игру.

## 8. Статус

- Пайплайн — предложение TD; требует утверждения пользователя.
- Ни одна новая модель не сгенерирована в этом спринте.
- Все текущие модели — fallback, **NOT TESTED** как финальные.
