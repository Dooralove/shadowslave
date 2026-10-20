# Журнал решений ShadowSlave

## 2026-10-21 — Базовая среда разработки

- **Движок:** Godot 4.7.2 stable, Standard, GDScript. Установлен в `C:\Users\user\Tools\Godot\4.7.2`, путь добавлен в пользовательский PATH.
- **Расположение проекта:** `C:\Users\user\Desktop\shadowslave`. Диска D в системе нет, на диске C достаточно места, путь без пробелов.
- **MCP:** один сервер `godot` (пакет `godot-mcp-server`) с плагином `addons/godot_mcp/` из официального репозитория tomyud1/godot-mcp. Регистрация на уровне проекта.
- **Тесты:** GUT 9.7.1 в `addons/gut/`.
- **Git LFS:** только для бинарных форматов (FBX, GLB, GLTF, BLEND, WAV, OGG, PSD, KRA, XCF, TGA, EXR). Текстовые форматы остаются в обычном Git.
- **Данные баланса:** типизированные Godot Resources (`.tres`). JSON только для внешних данных.
- **Отложено:** Dialogic 2, Unreal Engine, Blender MCP, дополнительные MCP-серверы. Dialogic подключим после подтверждения работы проекта, управления персонажем и базовой сцены.
