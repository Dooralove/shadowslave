class_name ThoughtBubble
extends Label3D
## Мировая реплика Санни: короткая строка над головой, а не HUD-подсказка.
## Следует за игроком и мягко гаснет, поэтому не загораживает кадр.

@export var follow_offset := Vector3(0.0, 2.15, 0.0)
@export var fade_seconds := 0.35

var target: Node3D
var _tween: Tween
var _showing := false


func _ready() -> void:
	visible = false
	modulate = Color(modulate.r, modulate.g, modulate.b, 0.0)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = false
	fixed_size = false


func _process(_delta: float) -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position + follow_offset


func show_text(text: String, seconds: float, fade: float = -1.0) -> void:
	if text.strip_edges().is_empty():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var clean := text.strip_edges()
	self.text = clean
	var fade_time := fade if fade >= 0.0 else fade_seconds
	_showing = true
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_time)
	_tween.tween_interval(maxf(seconds, 0.1))
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	_tween.tween_callback(_finish)


func hide_text(instant := false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_showing = false
	if instant:
		modulate.a = 0.0
		visible = false
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	_tween.tween_callback(_finish)


func is_showing() -> bool:
	return _showing


func _finish() -> void:
	_showing = false
	visible = false
