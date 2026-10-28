# ShadowSlave

3D-игра на Godot 4.7.2 (GDScript). Стадия: S1 — проходимый graybox-срез пролога «Nightmare Begins» (от скамейки до экрана рун) поверх боевого прототипа Milestone 4: Санни и тестовый противник с временными моделями (KayKit, CC0), атака с фазами, боевое испытание.

Отладка: зону удара можно показать флагом `show_hit_zone` у узла `MeleeAttack` (Санни: `Visual/MeleeAttack`, противник: то же) — на физику и урон не влияет.

## Управление

| Действие | Клавиша | Input Map action |
|---|---|---|
| Ходьба | W / A / S / D | `move_forward`, `move_left`, `move_back`, `move_right` |
| Бег | Shift (удерживать) | `sprint` |
| Прыжок | Space | `jump` |
| Обзор камерой | мышь | — |
| Освободить мышь | Escape | `release_mouse` |
| Захватить мышь снова | ЛКМ в окне игры | `capture_mouse` |
| Удар ближнего боя | ЛКМ (при захваченной мыши) | `attack` |
| Перезапустить боевое испытание | R | `restart` |
| Взаимодействовать (срез) | E | `interact` |
| Следующая реплика (срез) | E / Space / Enter | `advance_dialogue` |
| Статус Заклинания (срез) | Tab | `open_status` |

В срезе нет боя, бега и прыжка; в диалогах и постановках можно только оглядываться.

## Версии инструментов

| Инструмент | Версия |
|---|---|
| Godot Engine | 4.7.2 stable, Standard (Windows x86_64) |
| Node.js | v24.x (LTS-линейка), для godot-mcp-server |
| Git | 2.45.x |
| Git LFS | 3.5.x |
| GUT | 9.7.1 (`addons/gut/`) |
| Godot MCP plugin | `addons/godot_mcp/`, v0.6.1 (официальный репозиторий tomyud1/godot-mcp) |

## Запуск

Путь к Godot CLI: `C:\Users\user\Tools\Godot\4.7.2\godot.cmd` (добавлен в пользовательский PATH).

Открыть редактор:

```bash
godot --editor --path "C:\Users\user\Desktop\shadowslave"
```

Запустить основную сцену:

```bash
godot --path "C:\Users\user\Desktop\shadowslave"
```

Запустить только тестовую локацию:

```bash
godot --path "C:\Users\user\Desktop\shadowslave" res://scenes/levels/test_level.tscn
```

Запустить боевое испытание:

```bash
godot --path "C:\Users\user\Desktop\shadowslave" res://scenes/levels/combat_arena.tscn
```

Запустить вертикальный срез (пролог, B01–B16):

```bash
godot --path "C:\Users\user\Desktop\shadowslave" res://scenes/slice/prologue.tscn
```

Headless-импорт и проверка без окна:

```bash
godot --headless --editor --path "C:\Users\user\Desktop\shadowslave" --quit
```

Тесты GUT (headless):

```bash
godot --headless --path "C:\Users\user\Desktop\shadowslave" -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Полная проверка окружения: `scripts/verify_env.ps1`.

## Структура

```
project.godot        конфигурация проекта
scenes/              сцены: main/main.tscn (точка входа), characters/{sunny,sunny_waking,test_enemy}.tscn,
                     levels/{test_level,combat_arena}.tscn, slice/ (срез: prologue.tscn, locations/, props/),
                     ui/ (prologue_ui.tscn)
scripts/             GDScript: player/ (передвижение, камера, аниматор), combat/ (здоровье, хёртбокс, атака,
                     противник), slice/ (режиссёр среза, локации, CinematicActor), interaction/, dialogue/,
                     spell/ (лист статуса), world/ (сцены-обвязки), ui/ (HUD и слои среза), debug/ (PerfProbe), quests
resources/           типизированные Resource (.tres): characters/sunny_attack.tres,
                     enemies/test_enemy_attack.tres, dialogue/prologue/ (реплики среза),
                     spell/sunny_status.tres, slice/ (карты клипов), items, quests
assets/              исходные ассеты (через Git LFS для бинарных форматов):
                     characters/sunny_placeholder/ — временная модель Санни (KayKit, CC0)
                     characters/enemy_placeholder/ — временная модель противника (KayKit, CC0)
tests/               тесты GUT
docs/                документация проекта: README.md (навигация), DECISIONS.md, ASSET_LICENSES.md, разделы art/, story/, design/, production/
addons/              сторонние плагины: godot_mcp, gut
```

## Отложено

- Dialogic 2 — подключим после подтверждения работы проекта, управления персонажем и базовой сцены.
- Финальная модель Санни, комбо, блок, оружие, канонические противники, квесты — следующие этапы.
