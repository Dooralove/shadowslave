class_name QuestInspectable
extends Interactable
## Аддитивная точка осмотра для квестовых улик, зеркала и Плаща.
##
## Наследует существующий Interactable, поэтому использует тот же Interactor,
## prompt и audio-канал. Не заменяет Inspectable (подсветка/чутьё): оба
## компонента могут жить на одном объекте.

signal inspected(id: StringName)

@export var required_flags: Array[StringName] = []
@export var completion_flag: StringName
@export var quest_event: StringName = &"interacted"
@export var quest_subject: StringName
@export var start_quest_id: StringName
@export_multiline var inspect_text := ""
@export var one_shot := true

var _completed := false


func _ready() -> void:
	super._ready()
	add_to_group(&"quest_inspectable")
	if completion_flag != &"" and NightmareRunState.has_flag(completion_flag):
		_completed = true
		enabled = false
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state != null and not run_state.flag_changed.is_connected(_on_flag_changed):
		run_state.flag_changed.connect(_on_flag_changed)


func can_interact_from(point: Vector3) -> bool:
	if not super.can_interact_from(point):
		return false
	if _completed and one_shot:
		return false
	return NightmareRunState.require(required_flags)


func interact() -> void:
	if not enabled or _completed and one_shot:
		return
	if not NightmareRunState.require(required_flags):
		return
	if start_quest_id != &"":
		QuestSystem.start_quest(start_quest_id)
	super.interact()
	if completion_flag != &"":
		NightmareRunState.set_flag(completion_flag)
	if quest_subject != &"":
		QuestSystem.notify_event(quest_event, quest_subject, 1)
	inspected.emit(interaction_id)
	if not inspect_text.strip_edges().is_empty():
		QuestSystem.show_message(inspect_text, &"info")
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
