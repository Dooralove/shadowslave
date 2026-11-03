class_name CutsceneTrigger
extends Area3D
## Запускает CutsceneStage при входе игрока в зону.

@export var stage: CutsceneStage
@export var one_shot := true
@export var required_flags: Array[StringName] = []
@export var blocked_by_flags: Array[StringName] = []

var _used := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _used and one_shot:
		return
	if not body.is_in_group(&"player"):
		return
	var director = get_node_or_null(^"/root/CutsceneDirector")
	if director == null or bool(director.call(&"is_playing")):
		return
	var state := get_node_or_null(^"/root/NightmareRunState")
	for flag in required_flags:
		if state == null or not bool(state.call(&"has_flag", flag)):
			return
	for flag in blocked_by_flags:
		if state != null and bool(state.call(&"has_flag", flag)):
			return
	if bool(director.call(&"start_stage", stage)):
		_used = true
		if one_shot:
			set_deferred(&"monitoring", false)
