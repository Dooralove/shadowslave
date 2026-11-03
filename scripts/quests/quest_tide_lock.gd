class_name QuestTideLock
extends Interactable
## Интерактивный объект, доступный только при достаточно низкой воде.
##
## Не создаёт второй TideController: использует существующий узел из группы
## tide_controller. Поддерживает новый A03 get_water_y(), а до его появления
## переводит low_y/high_y + get_level() в мировую высоту.

@export var tide_controller: Node3D
@export var max_level := -1.0
@export var quest_id: StringName
@export var start_quest_id: StringName
@export var required_flags: Array[StringName] = []
@export var completion_flag: StringName
@export var quest_event: StringName = &"interacted"
@export var quest_subject: StringName
@export var blocked_prompt := "Вода слишком высока. Соль разбухла."
@export_multiline var success_text := ""
@export var one_shot := true

var _completed := false


func _ready() -> void:
	super._ready()
	add_to_group(&"quest_tide_lock")
	if tide_controller == null:
		tide_controller = get_tree().get_first_node_in_group(&"tide_controller") as Node3D
	if completion_flag != &"" and NightmareRunState.has_flag(completion_flag):
		_completed = true
		enabled = false
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state != null and not run_state.flag_changed.is_connected(_on_flag_changed):
		run_state.flag_changed.connect(_on_flag_changed)


func is_tide_ready() -> bool:
	if tide_controller == null or not is_instance_valid(tide_controller):
		return false
	if tide_controller.has_method(&"get_water_y"):
		return float(tide_controller.call(&"get_water_y")) <= max_level
	if tide_controller.has_method(&"get_level"):
		var level := float(tide_controller.call(&"get_level"))
		var low_raw: Variant = tide_controller.get(&"low_y")
		var high_raw: Variant = tide_controller.get(&"high_y")
		if (low_raw is float or low_raw is int) and (high_raw is float or high_raw is int):
			var low := float(low_raw)
			var high := float(high_raw)
			var water_y := lerpf(low, high, clampf(level, 0.0, 1.0))
			return water_y <= max_level
		# Совместимость с нормализованным порогом 0..1.
		return max_level >= 0.0 and max_level <= 1.0 and level <= max_level
	return false


func can_interact_from(point: Vector3) -> bool:
	if not super.can_interact_from(point):
		return false
	if _completed and one_shot:
		return false
	return NightmareRunState.require(required_flags)


func interact() -> void:
	if not enabled:
		return
	if _completed and one_shot:
		return
	if not NightmareRunState.require(required_flags):
		return
	if start_quest_id != &"":
		QuestSystem.start_quest(start_quest_id)
	if not is_tide_ready():
		QuestSystem.show_message(blocked_prompt, &"warning")
		return
	super.interact()
	if completion_flag != &"":
		NightmareRunState.set_flag(completion_flag)
	if quest_subject != &"":
		QuestSystem.notify_event(quest_event, quest_subject, 1)
	if not success_text.strip_edges().is_empty():
		QuestSystem.show_message(success_text, &"info")
	if one_shot:
		_completed = true
		enabled = false


func is_completed() -> bool:
	return _completed


func _on_flag_changed(flag_name: StringName, value: bool) -> void:
	if not value or completion_flag == &"" or flag_name != completion_flag:
		return
	_completed = true
	if one_shot:
		enabled = false
