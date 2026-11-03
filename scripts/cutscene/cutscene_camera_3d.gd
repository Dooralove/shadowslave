class_name CutsceneCamera3D
extends Camera3D
## Одна кинематографическая камера на запуск. Плавно переходит между
## статическими Shots/* и возвращается к игровой камере.

signal shot_changed(shot_id: StringName)

var stage: CutsceneStage
var scene: Node
var player_camera: Camera3D
var fast_mode := false

var _tween: Tween
var _from_xform: Transform3D
var _to_xform: Transform3D
var _from_fov := 0.0
var _to_fov := 0.0


func setup_from_camera(source: Camera3D) -> void:
	if source == null:
		return
	global_transform = source.global_transform
	fov = source.fov
	near = source.near
	far = source.far
	projection = source.projection
	size = source.size
	keep_aspect = source.keep_aspect
	cull_mask = source.cull_mask
	environment = source.environment
	attributes = source.attributes


func shot(id: StringName, blend := 0.6) -> void:
	var shot_camera := _find_shot(id)
	if shot_camera == null:
		push_error("CutsceneCamera3D: shot '%s' not found" % id)
		return
	_apply_lens_from(shot_camera)
	await _blend_to(shot_camera.global_transform, shot_camera.fov, blend)
	shot_changed.emit(id)


func hard_cut(id: StringName) -> void:
	await shot(id, 0.0)


func player(blend := 0.6) -> void:
	if player_camera == null:
		return
	_apply_lens_from(player_camera)
	await _blend_to(player_camera.global_transform, player_camera.fov, blend)
	player_camera.make_current()
	shot_changed.emit(&"__player__")


func focus_on(target: Node3D, blend := 0.4) -> void:
	if target == null:
		return
	var direction := target.global_position - global_position
	if direction.length_squared() < 0.0001:
		return
	var target_xform := global_transform.looking_at(target.global_position, Vector3.UP)
	await _blend_to(target_xform, fov, blend)


func fov_to(value: float, blend := 0.4) -> void:
	if fast_mode or blend <= 0.0:
		fov = value
		return
	cancel_tweens()
	_tween = create_tween()
	_tween.tween_property(self, "fov", value, blend).set_trans(Tween.TRANS_SINE)
	await _tween.finished
	_tween = null


func cancel_tweens() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _blend_to(target_xform: Transform3D, target_fov: float, blend: float) -> void:
	cancel_tweens()
	if fast_mode or blend <= 0.0:
		global_transform = target_xform
		fov = target_fov
		return
	_from_xform = global_transform
	_to_xform = target_xform
	_from_fov = fov
	_to_fov = target_fov
	_tween = create_tween()
	_tween.tween_method(_apply_blend, 0.0, 1.0, blend) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	_tween = null


func _apply_blend(t: float) -> void:
	var rotation_basis := _from_xform.basis.slerp(_to_xform.basis, t)
	global_transform = Transform3D(rotation_basis, _from_xform.origin.lerp(_to_xform.origin, t))
	fov = lerpf(_from_fov, _to_fov, t)


func _find_shot(id: StringName) -> Camera3D:
	if stage != null:
		var stage_shot := stage.get_shot(id)
		if stage_shot != null:
			return stage_shot
	if scene != null:
		return scene.get_node_or_null(NodePath("Shots/%s" % String(id))) as Camera3D
	return null


func _apply_lens_from(source: Camera3D) -> void:
	if source == null:
		return
	near = source.near
	far = source.far
	projection = source.projection
	size = source.size
	keep_aspect = source.keep_aspect
	cull_mask = source.cull_mask
	environment = source.environment
	attributes = source.attributes
