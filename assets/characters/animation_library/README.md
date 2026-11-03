# Animation Library

Общие анимационные библиотеки для персонажей Shadow Slave. Только визуальный слой:
урон и здоровье остаются в `MeleeAttack` / `HealthComponent`.

## Rokoko (free packs)

`rokoko/` содержит исходные FBX из двух бесплатных паков Rokoko и карту костей.
В проект взяты 7 клипов:

| Файл | Анимация | Длина |
|---|---|---:|
| `rokoko_walk_forward.fbx` | `Walk_Forward` | 16.833 с |
| `rokoko_run_treadmill.fbx` | `Run_Treadmill` | 15.900 с |
| `rokoko_run_injured_treadmill.fbx` | `Run_Injured_Treadmill` | 16.000 с |
| `rokoko_knife_stab_01.fbx` | `Knife_Stab_01` | 8.475 с |
| `rokoko_knife_stab_02.fbx` | `Knife_Stab_02` | 6.267 с |
| `rokoko_grenade_throw_01.fbx` | `Grenade_Throw_01` | 6.650 с |
| `rokoko_grenade_throw_02.fbx` | `Grenade_Throw_02` | 4.300 с |

`rokoko_library.tres` — слияние этих клипов под именами из таблицы. Лаборатория
`scenes/dev/animation_lab.tscn` подключает его как библиотеку `rokoko`, поэтому
клипы доступны как `rokoko/Walk_Forward`, `rokoko/Knife_Stab_01` и т.д.

### Настройки импорта

FBX импортируются не как `scene`, а как `AnimationLibrary`:

- `importer="animation_library"`;
- `fbx/importer=0` — FBX2glTF; для части файлов ufbx-путь в Godot 4.7.2 падал;
- `retarget/bone_map = bone_map_rokoko_newton.tres`;
- `retarget/bone_renamer/rename_bones = true`;
- `retarget/bone_renamer/unique_node/skeleton_name = "GeneralSkeleton"`;
- rest fixer включён, `fix_silhouette` включён, `normalize_position_tracks` включён;
- `retarget/remove_tracks/except_bone_transform = false` — в Godot 4.7.2 этот
  флаг удалял вообще все дорожки у FBX; mesh/scale-дорожки вместо этого чистит
  post-import скрипт `keep_rotation_tracks.gd`;
- `retarget/remove_tracks/unmapped_bones = true`.

После импорта у locomotion-клипов 53 дорожки (Hips position + 52 rotation),
у weapon-клипов 17 дорожек (Hips position + 16 rotation). Это ожидаемо: в
weapon-исходниках анимирован только верх тела и Hips.

### Добавление нового клипа

1. Положить FBX в `rokoko/` с осмысленным именем.
2. Дать Godot создать `.import`, затем привести его к настройкам выше.
3. Проверить, что библиотека загружается и число дорожек не 0:
   `godot --headless --path . --import`.
4. Добавить клип в `rokoko_library.tres` тем же способом, каким он был собран
   (headless-скрипт или редактор), и обновить таблицу.
5. Обновить `docs/ASSET_LICENSES.md`.

### Лицензия

Источники, авторы и условия — `docs/ASSET_LICENSES.md`, раздел
«Character Animation Pipeline». Исходные паки Rokoko разрешают коммерческое
использование; сохраняйте ссылки на источники. Не добавляйте сюда Mixamo-
ассеты без проверки Adobe Terms.

## P1 / UAL

P1-модель (`assets/characters/p1/sunny_p1_model.tscn`) использует UAL Standard
и `sunny/Idle_Relaxed`. Bone map и настройки UAL лежат в
`assets/characters/sunny_realistic_poc/animations/`. Не дублируйте UAL-клипы в
Rokoko-библиотеке: для locomotion в лаборатории используется UAL, Rokoko — для
проверки длинных тейков и weapon-анимаций.

## Ограничения

- **Rokoko-клипы сейчас staging, не production-ready.** Исходный FBX имеет
  armature object `-90° X` и scale `0.01`; Godot переносит scale, но не переносит
  ориентацию в pose-треки. Визуально Walk_Forward наклонён/висит, Hips `y≈0.006`,
  `z≈-0.955`, стопы уходят ниже пола. Нужен Blender-ретargет/бейк на P1.
- `AnimationTree` пока только в `scenes/dev/animation_lab.tscn`; в игре
  `SunnyAnimator` по-прежнему управляет `AnimationPlayer` напрямую.
- Root motion не экстрагируется: длинные Rokoko walk/run-тейки нельзя просто
  подключить к `CharacterBody3D` без драйвера root motion.
- Foot IK не реализован; foot sliding остаётся известным дефектом.
