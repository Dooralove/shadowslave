class_name TimingChallenge
extends CanvasLayer
## Один бросок петли: маркер идёт по полосе, E в зелёном окне — успех.
## После одного прохода испытание закрывается; промах обрабатывает сцена.

signal resolved(success: bool)

@export var cycle_time := 1.15
@export_range(0.0, 1.0) var window_start := 0.42
@export_range(0.0, 1.0) var window_end := 0.58

var _active := false
var _elapsed := 0.0
var _resolved := false
var _start_frame := 0
var _root: Control
var _bar: ColorRect
var _marker: ColorRect
var _hint: Label


func _ready() -> void:
	layer = 22
	_build_ui()
	visible = false


func start() -> void:
	_active = true
	_resolved = false
	_elapsed = 0.0
	_start_frame = Engine.get_process_frames()
	visible = true
	_update_marker()


func reset() -> void:
	_active = false
	_resolved = false
	_elapsed = 0.0
	visible = false


func is_active() -> bool:
	return _active


func get_elapsed() -> float:
	return _elapsed


func advance(delta: float) -> void:
	if not _active or _resolved:
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= cycle_time:
		_finish(false)
		return
	_update_marker()


func press() -> void:
	if not _active or _resolved:
		return
	var ratio := clampf(_elapsed / maxf(cycle_time, 0.001), 0.0, 1.0)
	_finish(ratio >= window_start and ratio <= window_end)


## Детерминированный ввод для тестов и будущих геймпадов: сразу поставить
## маркер в нужную точку полосы и нажать.
func press_at_ratio(ratio: float) -> void:
	if not _active or _resolved:
		return
	_elapsed = clampf(ratio, 0.0, 1.0) * maxf(cycle_time, 0.001)
	_update_marker()
	press()


func _process(delta: float) -> void:
	advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _resolved or Engine.get_process_frames() <= _start_frame:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"advance_dialogue"):
		get_viewport().set_input_as_handled()
		press()


func _finish(success: bool) -> void:
	if _resolved:
		return
	_resolved = true
	_active = false
	visible = false
	resolved.emit(success)


func _update_marker() -> void:
	if _marker == null:
		return
	var ratio := clampf(_elapsed / maxf(cycle_time, 0.001), 0.0, 1.0)
	_marker.position.x = ratio * _bar.size.x - 2.0


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_hint = Label.new()
	_hint.text = "Бросок петли — E"
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -160.0
	_hint.offset_top = -138.0
	_hint.offset_right = 160.0
	_hint.offset_bottom = -112.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96, 1.0))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.add_theme_font_size_override("font_size", 18)
	_root.add_child(_hint)

	_bar = ColorRect.new()
	_bar.color = Color(0.08, 0.09, 0.12, 0.88)
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -180.0
	_bar.offset_top = -106.0
	_bar.offset_right = 180.0
	_bar.offset_bottom = -88.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar)

	var success := ColorRect.new()
	success.color = Color(0.45, 0.72, 0.5, 0.85)
	success.position = Vector2(window_start * 360.0, 0.0)
	success.size = Vector2((window_end - window_start) * 360.0, 18.0)
	success.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(success)

	_marker = ColorRect.new()
	_marker.color = Color(0.92, 0.82, 0.54, 1.0)
	_marker.size = Vector2(4.0, 24.0)
	_marker.position = Vector2(0.0, -3.0)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_marker)
