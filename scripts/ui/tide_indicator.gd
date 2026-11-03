class_name TideIndicator
extends PanelContainer
## Индикатор прилива для Лабиринта. Появляется только там, где есть
## TideController, и не создаёт второй HUD в остальных сценах.

@onready var state_label: Label = %State
@onready var detail_label: Label = %Detail
@onready var level_bar: ProgressBar = %LevelBar

var _controller: Node
var _scan_timer := 0.0
var _refresh_timer := 0.0


func _ready() -> void:
	if theme == null:
		theme = RpgMenuTheme.build()
	visible = false
	_scan_timer = 0.0


func _process(delta: float) -> void:
	_scan_timer -= delta
	if _controller == null or not is_instance_valid(_controller):
		if _scan_timer <= 0.0:
			_scan_timer = 0.5
			_controller = get_tree().get_first_node_in_group(&"tide_controller")
		if _controller == null:
			visible = false
			return
	visible = true
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.12
		_refresh()


func set_controller(controller: Node) -> void:
	_controller = controller
	_refresh()


func _refresh() -> void:
	if _controller == null or not is_instance_valid(_controller):
		visible = false
		return
	var level := float(_controller.call(&"get_level")) if _controller.has_method(&"get_level") else 0.5
	var high := bool(_controller.call(&"is_high_water")) if _controller.has_method(&"is_high_water") else false
	var rising := bool(_controller.call(&"is_rising")) if _controller.has_method(&"is_rising") else true
	level_bar.value = clampf(level, 0.0, 1.0) * 100.0
	var color := Color(0.58, 0.74, 0.86)
	if high:
		color = Color(0.78, 0.34, 0.26)
	elif level > 0.68:
		color = Color(0.82, 0.62, 0.34)
	var base_fill := level_bar.get_theme_stylebox("fill")
	if base_fill != null:
		var fill := base_fill.duplicate() as StyleBoxFlat
		if fill != null:
			fill.bg_color = color
			level_bar.add_theme_stylebox_override("fill", fill)

	state_label.text = "ПРИЛИВ" if high else ("ПРИЛИВ РАСТЁТ" if rising else "ОТЛИВ")
	state_label.add_theme_color_override("font_color", color if not high else RpgMenuTheme.RUST)
	var detail := ""
	var seconds := 0.0
	if high:
		seconds = float(_controller.call(&"seconds_until_low")) if _controller.has_method(&"seconds_until_low") else 0.0
		detail = "НИЗКИЕ ПРОХОДЫ ЗАКРЫТЫ · ДО ОТЛИВА %s" % _clock(seconds)
	else:
		seconds = float(_controller.call(&"seconds_until_high")) if _controller.has_method(&"seconds_until_high") else 0.0
		if rising and seconds <= 20.0:
			detail = "ПРИЛИВ ЧЕРЕЗ %d с · ИЩИТЕ ВЫСОКИЙ ПУТЬ" % ceili(seconds)
		else:
			detail = "ДО ПРИЛИВА %s" % _clock(seconds)
	detail_label.text = detail
	detail_label.add_theme_color_override(
		"font_color",
		RpgMenuTheme.RUST if high or (rising and seconds <= 20.0) else RpgMenuTheme.MUTED
	)


func _clock(seconds: float) -> String:
	var total := maxi(roundi(seconds), 0)
	return "%02d:%02d" % [floori(float(total) / 60.0), total % 60]
