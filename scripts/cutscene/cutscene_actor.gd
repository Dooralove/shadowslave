class_name CutsceneActor
extends CinematicActor
## Постановочный актёр: движение, поворот, видимость и снапшот для skip.

@export var actor_id: StringName
@export var body: Node3D
@export var visual: Node3D
@export var movement_root: Node3D
@export var look_root: Node3D
@export var animation_tree: AnimationTree
@export var freeze_body := true
@export var tracked := true
var fast_mode := false

var _motion_tween: Tween
var _body_was_physics := true
var _tree_was_active := false


func _ready() -> void:
	super._ready()
	add_to_group(&"cutscene_actor")
	if body == null:
		body = get_parent() as Node3D
	if visual == null and body != null:
		visual = body.get_node_or_null(^"Visual") as Node3D
	if movement_root == null:
		movement_root = body
	if look_root == null:
		look_root = visual


func begin() -> void:
	if active:
		return
	super.begin()
	if freeze_body and body != null:
		_body_was_physics = body.is_physics_processing()
		body.set_physics_process(false)
	if animation_tree != null:
		_tree_was_active = animation_tree.active
		animation_tree.active = false


func end() -> void:
	super.end()
	if freeze_body and body != null:
		body.set_physics_process(_body_was_physics)
	if animation_tree != null:
		animation_tree.active = _tree_was_active


func finish(keep_pose := true) -> void:
	if not keep_pose:
		stop()
	cancel_motion()
	end()
	active = false


func stop() -> void:
	if animation_player != null:
		animation_player.stop()


func play_action(action: StringName, blend := 0.2, speed := 1.0) -> float:
	if animation_player == null:
		push_error("CutsceneActor '%s': animation_player is null" % actor_id)
		return 0.0
	var clip := action
	if clip_map != null:
		var mapped := clip_map.clip_for(action)
		if mapped != &"":
			clip = mapped
	if not animation_player.has_animation(clip):
		push_error("CutsceneActor '%s': clip '%s' not found" % [actor_id, clip])
		return 0.0
	animation_player.speed_scale = speed
	animation_player.play(clip, blend)
	animation_player.seek(0.0, true)
	return animation_player.get_animation(clip).length


func move_to(marker: Node3D, duration: float, ease_mode := Tween.EASE_IN_OUT) -> void:
	var root := _movement_node()
	if root == null or marker == null:
		push_error("CutsceneActor '%s': cannot move (root/marker is null)" % actor_id)
		return
	cancel_motion()
	var target := marker.global_position
	if fast_mode or duration <= 0.0:
		root.global_position = target
		return
	_motion_tween = create_tween()
	_motion_tween.tween_property(root, "global_position", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(ease_mode)
	await _motion_tween.finished
	_motion_tween = null


func walk_to(marker: Node3D, speed := 1.4) -> void:
	var root := _movement_node()
	if root == null or marker == null:
		push_error("CutsceneActor '%s': cannot walk (root/marker is null)" % actor_id)
		return
	var distance := root.global_position.distance_to(marker.global_position)
	var duration := distance / maxf(speed, 0.1)
	play(&"walk")
	await move_to(marker, duration)
	stop()


func face(target: Node3D, duration := 0.3) -> void:
	if visual == null or target == null:
		return
	var direction := target.global_position - visual.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	var from_yaw := visual.rotation.y
	var to_yaw := from_yaw + wrapf(target_yaw - from_yaw, -PI, PI)
	if fast_mode or duration <= 0.0:
		visual.rotation.y = to_yaw
		return
	cancel_motion()
	_motion_tween = create_tween()
	_motion_tween.tween_property(visual, "rotation:y", to_yaw, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _motion_tween.finished
	_motion_tween = null


func look_at(target: Node3D, duration := 0.3) -> void:
	await face(target, duration)


func show() -> void:
	if visual != null:
		visual.visible = true


func hide() -> void:
	if visual != null:
		visual.visible = false


func cancel_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null


func snapshot() -> Dictionary:
	var data := {
		"active": active,
		"body_transform": body.global_transform if body != null else Transform3D.IDENTITY,
		"visual_transform": visual.global_transform if visual != null else Transform3D.IDENTITY,
		"visible": visual.visible if visual != null else true,
		"body_physics": body.is_physics_processing() if body != null else true,
		"tree_active": animation_tree.active if animation_tree != null else false,
		"cinematic": bool(animator.get(&"cinematic")) if animator != null else false,
		"animation": &"",
		"animation_position": 0.0,
		"animation_speed": 1.0,
		"animation_playing": false,
	}
	if animation_player != null:
		data["animation"] = animation_player.current_animation
		data["animation_speed"] = animation_player.speed_scale
		data["animation_playing"] = animation_player.is_playing()
		if animation_player.current_animation != &"":
			data["animation_position"] = animation_player.current_animation_position
	return data


func restore(data: Dictionary) -> void:
	cancel_motion()
	if active:
		end()
	if body != null and data.has("body_transform"):
		body.global_transform = data["body_transform"] as Transform3D
		body.set_physics_process(bool(data.get("body_physics", true)))
	if visual != null:
		if data.has("visual_transform"):
			visual.global_transform = data["visual_transform"] as Transform3D
		visual.visible = bool(data.get("visible", true))
	if animation_tree != null:
		animation_tree.active = bool(data.get("tree_active", false))
	if animator != null:
		animator.set(&"cinematic", bool(data.get("cinematic", false)))
	if animation_player != null:
		var clip: StringName = data.get("animation", &"")
		if clip != &"" and animation_player.has_animation(clip):
			animation_player.play(clip, 0.0)
			animation_player.seek(float(data.get("animation_position", 0.0)), true)
			animation_player.speed_scale = float(data.get("animation_speed", 1.0))
			if not bool(data.get("animation_playing", false)):
				animation_player.pause()
	active = false


func _movement_node() -> Node3D:
	if movement_root != null:
		return movement_root
	return body
