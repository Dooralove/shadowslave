# Character Animation Pipeline — статус реализации (2026-11-02)

Короткий отчёт по фактически сделанному после аудита
`docs/art/character_animation_pipeline_audit.md`. Документ описывает только проверенное;
непроверенное помечено явно. Критический разбор собственной работы и план улучшений:
`docs/art/animation_pipeline_self_audit_2026-11-02.md`.

## 1. Что установлено

| Инструмент | Размер | Лицензия | Статус |
|---|---:|---|---|
| Blender Retarget extension 5.2.0 | ~220 КБ | GPL-3.0-or-later | Установлен в user extensions Blender 5.1.1; `addon_utils.check("bl_ext.user_default.retarget")` → `(True, True)` |

Другие инструменты не устанавливались. Cascadeur Indie, Rokoko Studio, Auto-Rig Pro и
платные паки требуют аккаунта/оплаты или не дают нужный экспорт в бесплатном варианте.
Лимит 5 ГБ не израсходован. Версии Godot 4.7.2, Blender 5.1.1, glTF-Transform 4.5.1,
Krita, Materialize и GUT 9.7.1 проверены в этой же сессии; они уже были установлены.

## 2. Что добавлено в проект

### Rokoko: 7 клипов и общая библиотека

`assets/characters/animation_library/rokoko/`:

| Клип | Длина | Дорожек | Назначение |
|---|---:|---:|---|
| `Walk_Forward` | 16.833 с | 53 | длинный root-motion тейк |
| `Run_Treadmill` | 15.900 с | 53 | бег на месте |
| `Run_Injured_Treadmill` | 16.000 с | 53 | бег с травмой |
| `Knife_Stab_01` | 8.475 с | 17 | ножевой удар |
| `Knife_Stab_02` | 6.267 с | 17 | второй ножевой удар |
| `Grenade_Throw_01` | 6.650 с | 17 | бросок гранаты |
| `Grenade_Throw_02` | 4.300 с | 17 | второй бросок |

- Исходные FBX: 7 файлов, 11 195 040 байт.
- Импорт: `AnimationLibrary`, `BoneMap` Newton → `SkeletonProfileHumanoid`,
  rest fixer, уникальный скелет `GeneralSkeleton`, post-import очистка дорожек
  `keep_rotation_tracks.gd`.
- Слияние: `assets/characters/animation_library/rokoko_library.tres`.
- Карта костей: `assets/characters/animation_library/rokoko/bone_map_rokoko_newton.tres`.
- Лицензия и источники: `docs/ASSET_LICENSES.md`, раздел Character Animation Pipeline.

Проверка импорта: каждая библиотека загружается, у locomotion-клипов 53 дорожки,
у weapon-клипов 17; клипы проигрываются на P1-скелете с переименованием костей.
`godot --headless --path . --import` завершился с кодом 0 (2026-11-02).

> **Важно: клипы пока не production-ready.** Визуальная проверка на P1 показала,
> что `Walk_Forward` и `Knife_Stab_02` стоят в неверной ориентации: Hips имеет
> `y≈0.006`, `z≈-0.955` вместо ожидаемого `y≈0.94`; персонаж наклонён/висит,
> стопы уходят ниже пола. Причина — ориентация исходного FBX (armature object
> `-90° X` + scale `0.01`) не переносится в pose-треки Godot. Это staging-ассеты,
> не для интеграции в игру. Нужен Blender-ретargет/бейк на P1; подробности — в
> self-audit ниже.

### Лаборатория AnimationTree

- `scenes/dev/animation_lab.tscn`
- `scripts/dev/animation_lab.gd`
- `tests/test_animation_lab.gd`

Что внутри:

- P1-модель `sunny_p1_model.tscn`;
- UAL idle/walk/sprint и `Sword_Attack` как безопасная заглушка;
- `AnimationTree` + `AnimationNodeStateMachine` + `AnimationNodeBlendSpace1D`;
- состояния `Locomotion`, `Combat`, `RokokoWalk`, `Knife02`;
- `BoneAttachment3D` `WeaponSocket` на `RightHand` с debug-мечом;
- камера, свет, пол и подсказки по клавишам.

Запуск:

```powershell
godot --path . --scene res://scenes/dev/animation_lab.tscn
```

Клавиши: `1` — Locomotion, `2` — Combat, `3` — RokokoWalk, `4` — Knife02,
`W/S` — скорость blend space, `L` — лог, `R` — сброс.

Сцена изолированная: она не подключена к `sunny.tscn`, кампании или боевым сценам.

## 3. Точечные безопасные изменения

### Per-attack contact time

- В `AttackData` добавлено `contact_time` (по умолчанию `0.0`).
- `SunnyAnimator.attack_clip_speed()` использует `AttackData.contact_time`, если оно
  больше нуля; иначе — прежний общий `attack_contact_time`.
- В `sunny_light_armed.tres` выставлено `contact_time = 0.25` — ровно прежнее
  глобальное значение, поэтому игровые тайминги не изменились.
- Это инфраструктура для будущей настройки каждой атаки без правки аниматора.

### Respawn-поза

- Добавлен `SunnyAnimator.reset_to_idle()`.
- `FallRecovery.recover()` вызывает его после смерти, а не просто меняет enum.
- Теперь после возврата проигрывается idle, а не остаётся death-клип.

## 4. Проверки

| Проверка | Результат |
|---|---|
| Blender Retarget установлен и включён | Да, `(True, True)` |
| 7 Rokoko FBX импортированы как AnimationLibrary | Да, 17/53 дорожки |
| `rokoko_library.tres` | 7 клипов, сохранена |
| `test_animation_lab.gd` | 5/5 passed, 25 asserts |
| `test_sunny_animation.gd` | 16/16 passed |
| `test_fall_recovery.gd` | 8/8 passed |
| `test_combat_controller.gd` | 8/8 passed |
| Итого targeted GUT | **37/37 passed, 175 asserts, exit 0** |
| Визуальный кадр лаборатории (Idle) | Получен; персонаж на полу, Tree работает |
| Визуальная проверка Rokoko Walk/Knife | **FAIL**: неверная ориентация, Hips/стопы вне ожидаемых координат; клипы не production-ready |
| Полный GUT (`-gdir=res://tests`), прогон 1 | **510/536 passed, 26 failing, 6436/6463 asserts, exit 1** (до фикса `AttackData`) |
| Полный GUT, прогон 2 после фикса | **NOT COMPLETED**: crash signal 11 на pre-existing campaign flow; полный baseline нестабилен |
| Runtime/MCP | **NOT TESTED** — нужен отдельный проход по pre-existing ошибкам |

Полный GUT запускался фактически. В первом прогоне 24 падения — существующие
проблемы вне задачи (`CampaignGuide`, `BeatDirector`, `InspectableData`,
autoload/parse errors). Ещё 2 — lab-тесты `weapon_socket` и `state_machine` под
нагрузкой: P1-текстуры не загрузились; изолированно `test_animation_lab` проходит
5/5. После исправления собственного parse-регресса (`AttackData`) editor scan —
exit 0, targeted GUT — 37/37. Повторный полный прогон успел пройти `test_animation_lab`
5/5, но затем упал с signal 11 в pre-existing campaign flow и не завершился.
Runtime/MCP не выдаётся за проверенный.

## 5. Что намеренно не менялось

- Игровые тайминги, хитбоксы, контроллер, коллизии и урон.
- Rokoko-клипы не признаны готовыми: их нельзя подключать к игре до исправления
  ретаргета (ориентация/масштаб/root motion). Текущая библиотека — staging.
- Лаборатория зависит от `assets/characters/p1/` и P1-текстур, которые пока
  не отслеживаются Git (`??`); перед коммитом лаборатории их нужно добавить или
  перевести лабораторию на tracked-модель.
- `MeleeAttack` остаётся единственным источником урона; урон не перенесён в
  animation events.
- Foot IK не внедрён: без отдельного прототипа он искажает позу и требует
  настройки pole/target на P1. Foot sliding 4–5× остаётся.
- Attack-clip truncation не «исправлена» растяжением клипа: это изменило бы
  ощущение боя. `contact_time` только синхронизирует контакт.
- Dodge-дистанция, guard full-body, hitbox оружия не переписаны.
- `AnimationTree` не подключён к `SunnyAnimator`; сначала нужен визуальный
  просмотр лаборатории и решение по интеграции.

## 6. Следующие шаги (после анализа)

1. Открыть `animation_lab`, проверить Rokoko walk/knife на P1 в движении.
2. Решить, переносить ли state machine в `SunnyAnimator` (отдельный PR/этап).
3. Отдельным прототипом сделать foot IK / foot lock и замерить sliding.
4. Задать `contact_time` для unarmed/heavy/armed атак по фактическим клипам.
5. Подключить реальный weapon mesh к `WeaponSocket` и перенести hitbox на оружие.
6. Разобрать pre-existing parse errors, затем прогнать полный GUT/runtime.
