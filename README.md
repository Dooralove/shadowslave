# ShadowSlave

3D-игра на Godot 4.7.2 (GDScript). Стадия: инфраструктура и минимальная пустая сцена, игровая механика ещё не реализована.

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
scenes/              сцены (main, characters, levels, ui)
scripts/             GDScript (player, combat, world, quests, ui)
resources/           типизированные Resource (.tres): characters, enemies, items, quests
assets/              исходные ассеты (через Git LFS для бинарных форматов)
tests/               тесты GUT
docs/                ASSET_LICENSES.md, DECISIONS.md, журналы решений
addons/              сторонние плагины: godot_mcp, gut
```

## Отложено

- Dialogic 2 — подключим после подтверждения работы проекта, управления персонажем и базовой сцены.
- Управление Санни, боевая система, квесты — следующие этапы.
