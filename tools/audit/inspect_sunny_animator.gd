extends SceneTree
## Диагностика: какой скрипт реально висит на Animator и куда смотрит
## CinematicActor.animator в sunny_waking.tscn.


func _init() -> void:
	var packed := load("res://scenes/characters/sunny_waking.tscn") as PackedScene
	if packed == null:
		print("SCENE_LOAD_FAILED")
		quit(1)
		return
	var sunny := packed.instantiate()
	var animator := sunny.get_node_or_null(^"Animator")
	var actor := sunny.get_node_or_null(^"CinematicActor")
	print("ANIMATOR_CLASS=", animator.get_class() if animator != null else "NONE")
	print("ANIMATOR_SCRIPT=", _script_path(animator))
	print("ACTOR_ANIMATOR=", actor.get(&"animator") if actor != null else "NONE")
	var target: Node = actor.get(&"animator") if actor != null else null
	print("TARGET_CLASS=", target.get_class() if target != null else "NONE")
	print("TARGET_SCRIPT=", _script_path(target))
	print("TARGET_HAS_CINEMATIC=", _has_property(target, "cinematic"))
	quit(0)


func _script_path(node: Node) -> String:
	if node == null:
		return "NONE"
	var script: Script = node.get_script()
	return script.resource_path if script != null else "NONE"


func _has_property(node: Node, property_name: String) -> bool:
	if node == null:
		return false
	for prop in node.get_property_list():
		if String(prop.get("name", "")) == property_name:
			return true
	return false
