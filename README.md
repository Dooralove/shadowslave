# ShadowSlave

3D-игра на Godot 4.7.2 (GDScript). Стадия: Milestone 1 — управляемый персонаж Санни (капсула) в graybox-локации.

## Управление

| Действие | Клавиша | Input Map action |
|---|---|---|
| Ходьба | W / A / S / D | `move_forward`, `move_left`, `move_back`, `move_right` |
| Бег | Shift (удерживать) | `sprint` |
| Прыжок | Space | `jump` |
| Обзор камерой | мышь | — |
| Освободить мышь | Escape | `release_mouse` |
| Захватить мышь снова | ЛКМ в окне игры | `capture_mouse` |

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
scenes/              сцены: main/main.tscn (точка входа), characters/sunny.tscn, levels/test_level.tscn, ui
scripts/             GDScript: player/sunny_controller.gd, player/third_person_camera.gd, world, combat, quests, ui
resources/           типизированные Resource (.tres): characters, enemies, items, quests
assets/              исходные ассеты (через Git LFS для бинарных форматов)
tests/               тесты GUT
docs/                ASSET_LICENSES.md, DECISIONS.md, журналы решений
addons/              сторонние плагины: godot_mcp, gut
```

## Отложено

- Dialogic 2 — подключим после подтверждения работы проекта, управления персонажем и базовой сцены.
- Модель, скелет и анимации Санни, боевая система, квесты — следующие этапы.
