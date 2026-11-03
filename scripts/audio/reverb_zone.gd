class_name ReverbZone
extends Area3D
## Placeholder interior/exterior reverb trigger. Add a CollisionShape3D child;
## the player must be on collision mask 2 and in the `player` group.

@export var profile: StringName = &"coral_cave"


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"push_reverb_profile"):
		director.call(&"push_reverb_profile", profile)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"pop_reverb_profile"):
		director.call(&"pop_reverb_profile", profile)
