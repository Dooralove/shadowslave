class_name SurfaceDetector
extends Node
## Emits footsteps for the player based on a short downward raycast.
## Surface names are discovered from collider metadata or node names, because
## the greybox does not use PhysicMaterial surface types yet.

@export var ray_length := 1.6
@export_flags_3d_physics var collision_mask: int = 1
@export var walk_interval := 0.46
@export var run_interval := 0.32
@export var run_speed_threshold := 5.0
@export var default_surface: StringName = &"stone"

var _body: CharacterBody3D
var _timer := 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody3D


func _physics_process(delta: float) -> void:
	if _body == null or not _body.is_on_floor():
		_timer = 0.0
		return
	if _body.has_method(&"is_dead") and bool(_body.call(&"is_dead")):
		return
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	if speed < 0.35:
		_timer = 0.0
		return
	var interval := run_interval if speed >= run_speed_threshold else walk_interval
	_timer += delta
	if _timer < interval:
		return
	_timer = 0.0
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"play_sfx"):
		director.call(&"play_sfx", StringName("footstep_" + String(detect_surface())), Vector3.INF, -4.0)


func detect_surface() -> StringName:
	if _body == null:
		return default_surface
	var space := _body.get_world_3d().direct_space_state
	var origin := _body.global_position + Vector3.UP * 0.45
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * ray_length, collision_mask)
	query.exclude = [_body.get_rid()]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return default_surface
	var collider := result.get("collider") as Node
	return _surface_from_node(collider)


func _surface_from_node(node: Node) -> StringName:
	var current := node
	for depth in 4:
		if current == null:
			break
		var meta: Variant = current.get_meta(&"surface", &"")
		if meta != null and String(meta) != "":
			return StringName(String(meta))
		var surface := _surface_from_name(String(current.name))
		if surface != &"":
			return surface
		current = current.get_parent()
	return default_surface


func _surface_from_name(raw_name: String) -> StringName:
	var name := raw_name.to_lower()
	if name.contains("snow") or name.contains("drift") or name.contains("powder"):
		if name.contains("soft") or name.contains("drift") or name.contains("powder"):
			return &"snow_soft"
		return &"snow_packed"
	if name == "ice" or name.begins_with("ice") or name.contains("ice_") or name.contains("_ice") or name.contains("icicle") or name.contains("frozen") or name.contains("glacier"):
		return &"ice"
	if name.contains("bone") or name.contains("rib") or name.contains("skull"):
		return &"bone"
	if name.contains("mud") or name.contains("dirt") or name.contains("swamp"):
		return &"mud"
	if name.contains("wood") or name.contains("plank") or name.contains("wagon"):
		return &"wood"
	if name.contains("metal") or name.contains("iron") or name.contains("steel") or name.contains("grate"):
		return &"metal"
	if name.contains("water") or name.contains("puddle") or name.contains("pool"):
		return &"mud"
	if name.contains("coral"):
		return &"coral"
	if name.contains("marble") or name.contains("stone") or name.contains("rock") or name.contains("cliff"):
		return &"stone"
	if name.contains("concrete") or name.contains("tile") or name.contains("asphalt") or name.contains("gravel") or name.contains("road"):
		return &"stone"
	return &""
