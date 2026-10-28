extends Control
## Сдержанный рунический знак: концентрические окружности, насечки и ромб.

@export var color := Color(0.7, 0.55, 0.35, 0.24)
@export var faint_color := Color(0.7, 0.67, 0.6, 0.1)
@export var accent_color := Color(0.83, 0.68, 0.46, 0.42)
@export var animate := true
@export var rotation_speed := 0.018
@export var tick_count := 24

var _angle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if not animate or not is_visible_in_tree():
		return
	_angle = fmod(_angle + delta * rotation_speed, TAU)
	queue_redraw()


func _draw() -> void:
	var extent := minf(size.x, size.y)
	if extent < 12.0:
		return

	var center := size * 0.5
	var radius := extent * 0.44
	draw_arc(center, radius, _angle, _angle + TAU, 144, color, 1.1, true)
	draw_arc(center, radius * 0.83, -_angle * 0.6, -_angle * 0.6 + TAU, 120, faint_color, 1.0, true)
	draw_arc(center, radius * 0.56, _angle * 1.4, _angle * 1.4 + TAU, 96, faint_color, 1.0, true)
	draw_arc(center, radius * 0.2, 0.0, TAU, 48, color, 1.0, true)

	for i in tick_count:
		var angle := _angle + TAU * float(i) / float(tick_count)
		var long_tick := i % 3 == 0
		var inner := radius * (0.88 if long_tick else 0.925)
		var outer := radius * (0.97 if long_tick else 0.95)
		var tick_color := accent_color if long_tick else faint_color
		draw_line(_polar(center, inner, angle), _polar(center, outer, angle), tick_color, 1.0, true)

	for i in 4:
		var angle := _angle * 0.5 + TAU * float(i) / 4.0
		var inner := _polar(center, radius * 0.22, angle)
		var outer := _polar(center, radius * 0.54, angle)
		draw_line(inner, outer, faint_color, 1.0, true)
		draw_circle(outer, 1.7, color)

	var top := _polar(center, radius * 1.02, -PI * 0.5)
	var diamond := PackedVector2Array([
		top + Vector2(0.0, -7.0),
		top + Vector2(6.0, 0.0),
		top + Vector2(0.0, 7.0),
		top + Vector2(-6.0, 0.0),
	])
	draw_polyline(diamond, accent_color, 1.2, true)
	draw_circle(center, 2.0, accent_color)


func _polar(center: Vector2, radius: float, angle: float) -> Vector2:
	return center + Vector2(cos(angle), sin(angle)) * radius
