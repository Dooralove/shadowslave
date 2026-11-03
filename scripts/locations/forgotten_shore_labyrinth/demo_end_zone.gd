class_name DemoEndZone
extends Area3D
## M1 final at the Z10 campfire.
##
## The zone is not a second level manager: it only checks flags, closes the
## Labyrinth objective, and hands control to the existing finale scene.
## `nightmare_run_state.flag_changed` is used as well as body_entered, because
## CampNight and DemoEndZone overlap and the entry order is not fixed.

@export var required_flags: Array[StringName] = [
	&"shore_first_day_complete",
	&"camp_night_seen",
]
@export var disabled_by_flag: StringName = &"demo_mode_full"
@export_file("*.tscn") var destination_scene := "res://scenes/campaign/post_nightmare_finale.tscn"
@export var one_shot := true

var _fired := false
var _inside := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	NightmareRunState.flag_changed.connect(_on_flag_changed)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	_inside = true
	_try_fire()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_inside = false


func _on_flag_changed(_name: StringName, _value: bool) -> void:
	if _inside:
		_try_fire()


func _try_fire() -> void:
	if _fired or not _inside:
		return
	if one_shot and NightmareRunState.has_flag(&"post_nightmare_demo_completed"):
		return
	if disabled_by_flag != &"" and NightmareRunState.has_flag(disabled_by_flag):
		return
	if not NightmareRunState.require(required_flags):
		return
	_fired = true
	NightmareRunState.set_flag(&"demo_mode_m1")
	NightmareRunState.set_flag(&"post_nightmare_demo_completed")
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide != null and guide.has_method(&"clear_external_objective"):
		guide.call(&"clear_external_objective", &"post_nightmare")
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"deactivate_scope"):
		quests.call(&"deactivate_scope")
	# Scene changes are not allowed inside a physics callback.
	call_deferred(&"_enter_finale")


func _enter_finale() -> void:
	get_tree().change_scene_to_file(destination_scene)
