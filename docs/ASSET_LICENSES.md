# Реестр ассетов ShadowSlave

Каждый внешний ассет (модели, текстуры, анимации, звук, шрифты, плагины) регистрируется здесь до попадания в проект.

| Имя | Источник | Автор | Лицензия | URL | Дата загрузки | Ограничения использования |
|---|---|---|---|---|---|---|
| Godot Engine 4.7.2 | godotengine.org / github.com/godotengine/godot-builds | Godot Engine contributors | MIT | https://godotengine.org/download/archive/4.7.2-stable/ | 2026-10-21 | Инструмент разработки, в проект не входит |
| Godot MCP plugin (`addons/godot_mcp/`) | github.com/tomyud1/godot-mcp (commit 2c1f300) | tomyud1 | См. `addons/godot_mcp/LICENSE` | https://github.com/tomyud1/godot-mcp | 2026-10-21 | Инструмент разработки, копия LICENSE в папке плагина |
| GUT 9.7.1 (`addons/gut/`) | github.com/bitwes/Gut | Butch Wesley и участники | MIT | https://github.com/bitwes/Gut | 2026-10-21 | Тестовый фреймворк |
| Rogue_Hooded.glb — временная модель Санни со скелетом и 76 анимациями (`assets/characters/sunny_placeholder/`) | KayKit : Adventurers Character Pack 1.0, официальный GitHub автора (`Characters/gltf/Rogue_Hooded.glb`, SHA-256 `93E6E252…BB91545`) | Kay Lousberg (www.kaylousberg.com) | CC0 1.0 (текст: `assets/characters/sunny_placeholder/LICENSE_KayKit.txt`) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 | 2026-10-21 | Нет (CC0). Упоминание автора желательно, но не обязательно. Временный ассет: не финальный облик Санни |
| Rogue_Hooded_rogue_texture.png — текстура модели, извлечена Godot из .glb при импорте | то же | Kay Lousberg | CC0 1.0 | — | 2026-10-21 | Как у модели |

| Barbarian.glb — временная модель тестового противника со скелетом и 76 анимациями (`assets/characters/enemy_placeholder/`) | KayKit : Adventurers Character Pack 1.0, тот же официальный GitHub (`Characters/gltf/Barbarian.glb`, SHA-256 `CEFC311A…0669CC6`) | Kay Lousberg (www.kaylousberg.com) | CC0 1.0 (текст: `assets/characters/enemy_placeholder/LICENSE_KayKit.txt`) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 | 2026-10-21 | Нет (CC0). Временный ассет |
| Barbarian_barbarian_texture.png — текстура модели, извлечена Godot из .glb при импорте | то же | Kay Lousberg | CC0 1.0 | — | 2026-10-21 | Как у модели |

`rogue_placeholder_dark.tres` и `barbarian_placeholder_dark.tres` — собственные материалы проекта (затемнённые копии материалов моделей), не внешние ассеты.

Mixamo рассматривался как основной источник, но скачивание требует входа в аккаунт Adobe; выбран CC0-аналог с подтверждения пользователя.
