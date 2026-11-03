class_name QuestLever
extends Interactable
## SQ-04 tide lock lever. State is LOW/HIGH; the director evaluates the
## required [LOW, HIGH, LOW] combination after every pull.

@export var lever_id: StringName = &"a"
@export var director_path: NodePath
@export var required_flags: Array[StringName] = []
## A/C start HIGH and must be lowered; B starts LOW and must be raised.
@export var initial_high := true

var _high := false


func _ready() -> void:
	super()
	_high = initial_high
	_apply_flag()
	_refresh_enabled()
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state != null and not run_state.flag_changed.is_connected(_on_flag_changed):
		run_state.flag_changed.connect(_on_flag_changed)


func _on_flag_changed(_name: StringName, _value: bool) -> void:
	_refresh_enabled()


func _refresh_enabled() -> void:
	var available := true
	for flag in required_flags:
		if not NightmareRunState.has_flag(flag):
			available = false
			break
	enabled = available


func _apply_flag() -> void:
	var flag := StringName("sq_fs_04_lever_%s_high" % lever_id)
	if _high:
		NightmareRunState.set_flag(flag)
	else:
		NightmareRunState.clear_flag(flag)


func interact() -> void:
	if not enabled:
		return
	for flag in required_flags:
		if not NightmareRunState.has_flag(flag):
			return
	_high = not _high
	_apply_flag()
	super.interact()
	var director := get_node_or_null(director_path)
	if director != null and director.has_method(&"evaluate_sq04_levers"):
		director.call(&"evaluate_sq04_levers")
