class_name FallRecovery
extends Node
## Возврат Санни после смертельного падения (docs/design/first_nightmare_gameplay_research.md, §12.1).
## Пока Санни стоит на ровном месте, узел запоминает безопасную точку: пол есть не только под
## центром, но и вокруг, поэтому возврат не ставит его на самый край. Если Санни упал ниже
## безопасной точки больше чем на fall_limit, он возвращается на чекпоинт (если задан) или на
## безопасную точку, а экран коротко гаснет.
## Постановки не считаются падением: пока ввод у режиссёра, а также после телепорта скриптом
## отсчёт начинается заново с текущей позиции.

signal recovered(position: Vector3)

## Падение глубже — смерть, м.
@export var fall_limit := 10.0
## Как часто проверять безопасную точку, с.
@export var sample_interval := 0.2
## Пол должен быть под ногами в этом радиусе вокруг центра, м.
@export var safe_radius := 0.6
## Скачок позиции больше ожидаемого на эту величину считается телепортом, м.
@export var teleport_threshold := 1.5
@export var fade_duration := 0.35
## Мир и границы локаций (слои 1 и 6).
@export_flags_3d_physics var floor_mask := 1 | 32

var _body: SunnyController
var _start := Vector3.ZERO
var _safe := Vector3.ZERO
var _has_safe := false
var _checkpoint := Vector3.ZERO
var _has_checkpoint := false
var _sample_timer := 0.0
var _last_position := Vector3.ZERO
var _last_velocity := Vector3.ZERO
var _fade: ColorRect


func _ready() -> void:
	_body = get_parent() as SunnyController
	_reset_reference()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## Чекпоинт перед опасным отрезком: после падения Санни вернётся сюда, а не на последний пол.
func set_checkpoint(point: Vector3) -> void:
	_checkpoint = point
	_has_checkpoint = true


func clear_checkpoint() -> void:
	_has_checkpoint = false


func has_checkpoint() -> bool:
	return _has_checkpoint


## Куда вернётся Санни, если упадёт сейчас.
func recovery_point() -> Vector3:
	if _has_checkpoint:
		return _checkpoint
	return _safe if _has_safe else _start


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var position := _body.global_position
	var expected := _last_velocity.length() * delta
	var scripted := not (_body.controls_enabled and _body.input_enabled)
	if scripted or position.distance_to(_last_position) > expected + teleport_threshold:
		# Постановка или телепорт: прежняя безопасная точка и чекпоинт больше не про это место.
		_reset_reference()
		clear_checkpoint()
	elif _body.is_on_floor():
		_sample_timer -= delta
		if _sample_timer <= 0.0:
			_sample_timer = sample_interval
			if _is_safe_ground(position):
				_safe = position
				_has_safe = true
	elif position.y < _reference_height() - fall_limit:
		recover()
	_last_position = _body.global_position
	_last_velocity = _body.velocity


## Немедленный возврат на чекпоинт или безопасную точку.
func recover() -> void:
	var target := recovery_point()
	_body.global_position = target
	_body.velocity = Vector3.ZERO
	_last_position = target
	_last_velocity = Vector3.ZERO
	_fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, fade_duration)
	recovered.emit(target)


func _reset_reference() -> void:
	_start = _body.global_position
	_has_safe = false
	_last_position = _start
	_last_velocity = _body.velocity


func _reference_height() -> float:
	return _safe.y if _has_safe else _start.y


func _is_safe_ground(position: Vector3) -> bool:
	if _body.get_floor_normal().y < 0.8:
		return false
	var space := _body.get_world_3d().direct_space_state
	for offset in [Vector3(safe_radius, 0, 0), Vector3(-safe_radius, 0, 0), Vector3(0, 0, safe_radius), Vector3(0, 0, -safe_radius)]:
		var from: Vector3 = position + offset + Vector3.UP * 0.5
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5, floor_mask, [_body.get_rid()])
		if space.intersect_ray(query).is_empty():
			return false
	return true
