class_name CutsceneScript
extends Node
## Базовый класс сценария кат-сцены. Наследник реализует run(ctx).
## Скрипт создаётся директором на один запуск и удаляется при завершении/пропуске.

func run(_ctx: CutsceneContext) -> void:
	push_error("CutsceneScript.run() not implemented in %s" % get_path())
