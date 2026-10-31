# Генераторы арт-вариантов сцен Первого Кошмара

Скрипты пишут текстовые `.tscn`-наследники базовых CSG-сцен: переопределения узлов сценария и расстановку моделей.
Запуск из любой папки (Python 3, без Godot и Blender):

    python assets/environments/nightmare/source/scene_gen/gen_vision.py   # scenes/slice/locations/mountain_vision_art.tscn
    python assets/environments/nightmare/source/scene_gen/gen_road.py     # scenes/slice/locations/caravan_road_art.tscn
    python assets/environments/nightmare/source/scene_gen/gen_site.py     # scenes/locations/caravan_site/caravan_site_art.tscn
    python assets/environments/nightmare/source/scene_gen/gen_path.py     # scenes/locations/pilgrim_path/pilgrim_path_art.tscn
    python assets/environments/nightmare/source/scene_gen/gen_sanct.py    # scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn

`tscn.py` — запись `.tscn` (Transform3D построчно, как пишет Godot), окружение ночи; `strip.py` — раскладка дороги
вдоль пути из прямых и дуг (полотно с наклоном по уклону пути, стены, кромки, высокие массивы). Сцена
перезаписывается целиком: правки вручную в `*_art.tscn` нужно переносить в генератор. Решения и проверка —
`docs/art/level_audit.md`.
