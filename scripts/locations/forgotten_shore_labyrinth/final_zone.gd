class_name FinalZone
extends Area3D
## Tech-demo final at Z18. The zone is deliberately separate from DemoEndZone:
## it must only fire in `demo_mode_full`, so the M1 route can end at Z10 even
## while the full labyrinth route remains walkable.

@export var required_flag: StringName = &"demo_mode_full"
@export var completion_flag: StringName = &"post_nightmare_completed"
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
	if required_flag != &"" and not NightmareRunState.has_flag(required_flag):
		return
	if one_shot and NightmareRunState.has_flag(completion_flag):
		return
	_fired = true
	NightmareRunState.set_flag(completion_flag)
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
