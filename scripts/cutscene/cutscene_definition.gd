class_name CutsceneDefinition
extends Resource
## Манифест кат-сцены. Это контракт, а не сценарий: сценарий лежит в
## cutscene_script и выполняется CutsceneDirector.

enum SkipPolicy {
	NEVER,
	AFTER_FIRST_VIEW,
	ALWAYS,
	DEBUG_ONLY,
}

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var chapter: StringName = &""

## Скрипт, который наследует CutsceneScript и реализует run(ctx).
## Не называем поле "script": у Resource уже есть встроенное свойство script.
@export var cutscene_script: Script
## Необязательная самостоятельная сцена-stage.
@export var stage_scene: PackedScene

@export var skip_policy := SkipPolicy.AFTER_FIRST_VIEW
@export var key_scene := false
@export var max_duration := 60.0
@export var min_skip_time := 0.5

@export var required_flags: Array[StringName] = []
@export var blocked_by_flags: Array[StringName] = []

@export var completion_flags: Array[StringName] = []
@export var completion_clear_flags: Array[StringName] = []
## Минимальное итоговое количество, не прибавка.
@export var completion_items: Dictionary = {}
@export var completion_remove_items: Dictionary = {}
@export var completion_checkpoint: StringName = &""
@export var completion_checkpoint_position := Vector3.ZERO
@export var completion_checkpoint_has_position := false

@export var skip_summary: Array[String] = []
@export var cosmetic_flags: Array[StringName] = []

@export var hide_hud := true
@export var letterbox := true
@export var once := true
## Пусто -> &"cutscene/<id>/done".
@export var once_flag: StringName = &""

@export var moves_player := false
@export var skip_end_player_marker: StringName = &""
## actor_id -> marker_id.
@export var skip_end_markers: Dictionary = {}
@export var skip_end_hidden: Array[StringName] = []
@export var realign_camera_on_finish := true
@export var tags: Array[StringName] = []


func get_once_flag() -> StringName:
	if once_flag != &"":
		return once_flag
	if id == &"":
		return &""
	return StringName("cutscene/%s/done" % String(id))


func has_required_flags(state: Node) -> bool:
	if required_flags.is_empty():
		return true
	if state == null or not state.has_method(&"require"):
		return false
	return bool(state.call(&"require", required_flags))


func has_blocking_flags(state: Node) -> bool:
	if blocked_by_flags.is_empty() or state == null:
		return false
	for flag in blocked_by_flags:
		if state.has_method(&"has_flag") and bool(state.call(&"has_flag", flag)):
			return true
	return false
