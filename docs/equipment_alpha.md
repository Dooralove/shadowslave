# Equipment Alpha — модульная экипировка

**Дата:** 2026-11-03  
**Статус:** alpha / A/B prototype, pass 2.
**Ветка:** `feature/equipment-alpha-2`.

## 1. Что реализовано

- `EquipmentComponent` — цельный skinned-сет на общем `Skeleton3D`, `BoneAttachment3D` для оружия/аксессуаров.
- `CharacterRigProfile` — 52-костный generated v3 и 53-костный P1/UAL.
- `EquipmentItemData` / `ArmorSetData` / `WeaponData` — типизированные `Resource`-описания.
- `EquipmentLoadout` — тело, оружие, до двух аксессуаров; сериализуется только в ID.
- `EquipmentCatalog` — каталоги для v3/nightmare и P1.
- `EquipmentABTest` — два сета на одном риге.
- Броня:
  - `caravan_alpha` / `coral_alpha` — nightmare v2;
  - `caravan_alpha_p1` / `coral_alpha_p1` — P1/UAL;
  - `caravan_alpha_v3` / `coral_alpha_v3` — generated v3 split.
- Оружие/аксессуар: существующие `short_sword.glb` и `water_flask.glb` с вариантами под rig-профили.
- LOD: у каждого сета LOD0/LOD1/LOD2, переключение по дистанции внутри `EquipmentComponent`.
- Материалы: Poly Haven `brown_leather` и `rust_coarse_01` (уже зарегистрированы, CC0).
- `CombatController.set_unarmed()` синхронизирован с `EquipmentComponent.set_weapon_drawn()`.
- `NightmareRunState` хранит `equipment` snapshot (body/weapon/accessories ID); `SaveSystem` сохраняет его вместе с остальным состоянием.
- UI-мост `RpgDemoSession` → `EquipmentComponent`; `RpgDemoItem.equipment_id` связывает демо-предмет с реальным сетом.
- `SunnyV3Model` добавляет alpha-клип `Sword_Attack` из UAL-ретаргета; `CombatController` использует его для armed-атаки.
- Dev-сцены:
  - `scenes/dev/equipment_lab.tscn` — nightmare v2;
  - `scenes/dev/equipment_lab_p1.tscn` — P1/UAL;
  - `scenes/dev/equipment_lab_v3.tscn` — generated v3 split;
  - `scenes/dev/sunny_equipment_preview.tscn` — playable nightmare preview.
- `tools/audit/equipment_capture.gd` — read-only A/B capture.

## 2. Как устроено

### Nightmare v2

Surface `model` — только открытая кожа головы/шеи; руки, ноги и торс входят в tunic/trousers/shoes. Поэтому alpha-сет дублирует эти поверхности, слегка раздувает их по нормалям, перекрашивает и добавляет пластины. Пока сет надет, surface 1–3 скрываются; при снятии восстанавливаются.

### P1 / UAL

P1 уже имеет отдельные меши одежды. Сет дублирует sweater/pants/shoes, добавляет пластины и скрывает исходные узлы по именам. `CharacterLodVisibility` отключается на время ношения, чтобы не перезаписывать `visible`.

### Real v3 split

`build_real_v3_split.py` классифицирует disconnected islands по средней текстуре и bounds:

- skin/hair islands → `sunny_real_v3_base.glb`;
- clothing islands → `caravan_alpha_v3` / `coral_alpha_v3`.

Это **alpha split**, не production body: базовая модель содержит открытую кожу/голову, а броня обязательна для покрытия торса и конечностей. Сцена `equipment_lab_v3.tscn` показывает эту связку.

## 3. Управление в лабораториях

- `1` / `2` — A/B-сет;
- `3` — надеть/снять броню;
- `4` — показать/скрыть оружие;
- `5` — аксессуар (nightmare) / следующая поза (P1);
- `6` — следующая поза (nightmare/v3);
- `R` — сброс.

## 4. Проверки

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| GUT `test_equipment_alpha` | **17/17, 79 asserts, exit 0** |
| Полный GUT после слияния с generated armor/loot | **723/723, 7882 asserts, exit 0** |
| Lab nightmare / P1 / v3 headless | exit 0 |
| Playable preview headless | exit 0 |
| A/B capture | `equipment_capture.gd`, кадры в `%TEMP%/equipment_*` |
| Ручной playthrough | **NOT TESTED** |
| 1080p/60 FPS | **NOT TESTED** |

## 5. Ограничения alpha

- Сет — blockout: грубая форма, упрощённые пластины, без cloth/финальной ретопологии.
- Текстуры — существующие 1K Poly Haven leather/rust; UV брони унаследованы от одежды, поэтому рисунок местами растянут.
- Real v3 base — полный силуэт с нейтральным underlayer; без брони это alpha-болванка, а не финальное тело, но голова/конечности больше не «висят» отдельно.
- `Sword_Attack` — UAL→v3 retarget только верхней части тела; это alpha-клип, не production animation. Требует ручной полировки.
- P1 armor использует `hide_parts`; при добавлении новых LOD-мешей P1 список нужно обновлять.
- Нет ручного playthrough, замеров 1080p/60 и полного визуального A/B с тестерами.

## 6. Следующие шаги

1. Полировка `Sword_Attack`: плечо, кисть, контакт и возврат в стойку.
2. Ручной playthrough nightmare/P1/v3 и проверка клиппинга в 9 позах.
3. Заменить alpha-split real v3 на полноценный base-body asset.
4. Замерить draw calls/tri и провести A/B с 8–12 тестерами.
5. Проверить сохранение/загрузку через `SaveSystem` в живой сцене.

## 7. См. также

- `docs/equipment_armor_loot.md` — статы брони, `CharacterStats`, три сгенерированных сета и физический лут.
