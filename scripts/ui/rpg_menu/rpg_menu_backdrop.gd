extends Control
## Фоновая композиция прототипа: графит, пепел и редкие бронзовые линии.
## Всё рисуется процедурно, внешних текстур нет.

@export var show_rune_ring := true
@export var ring_center_ratio := Vector2(0.82, 0.49)
@export var ring_radius_ratio := 0.43
@export var grain_amount := 160
@export var grain_seed := 7319


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), RpgMenuTheme.BG)
	_draw_gradient_wash()
	_draw_side_lines()

	if show_rune_ring:
		_draw_rune_ring(Vector2(size.x * ring_center_ratio.x, size.y * ring_center_ratio.y))

	_draw_horizon_rules()
	_draw_grain()


func _draw_gradient_wash() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.42), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(Rect2(0.0, size.y * 0.55, size.x, size.y * 0.45), Color(0.01, 0.012, 0.012, 0.3))

	var beam := PackedVector2Array([
		Vector2(size.x * 0.55, 0.0),
		Vector2(size.x * 0.74, 0.0),
		Vector2(size.x * 0.98, size.y),
		Vector2(size.x * 0.79, size.y),
	])
	draw_colored_polygon(beam, Color(0.45, 0.34, 0.2, 0.025))

	var top_band := Rect2(0.0, 0.0, size.x, 94.0)
	draw_rect(top_band, Color(0.01, 0.012, 0.013, 0.42))


func _draw_side_lines() -> void:
	var line_color := Color(0.55, 0.5, 0.42, 0.09)
	for ratio in [0.17, 0.325, 0.68, 0.835]:
		var x := size.x * float(ratio)
		draw_line(Vector2(x, 96.0), Vector2(x, size.y - 64.0), line_color, 1.0)
	for i in 9:
		var y := 118.0 + i * 73.0
		draw_line(Vector2(size.x * 0.04, y), Vector2(size.x * 0.075, y), Color(0.55, 0.5, 0.42, 0.1), 1.0)
		draw_line(Vector2(size.x * 0.925, y), Vector2(size.x * 0.96, y), Color(0.55, 0.5, 0.42, 0.1), 1.0)


func _draw_rune_ring(center: Vector2) -> void:
	var radius := minf(size.x, size.y) * ring_radius_ratio
	var dim := Color(0.6, 0.47, 0.3, 0.09)
	var faint := Color(0.68, 0.66, 0.6, 0.055)
	var bright := Color(0.72, 0.56, 0.36, 0.12)

	draw_arc(center, radius, 0.0, TAU, 180, dim, 1.2, true)
	draw_arc(center, radius * 0.82, 0.0, TAU, 150, faint, 1.0, true)
	draw_arc(center, radius * 0.56, 0.0, TAU, 120, faint, 1.0, true)
	draw_arc(center, radius * 0.23, 0.0, TAU, 72, dim, 1.2, true)

	for i in 32:
		var angle := TAU * float(i) / 32.0
		var inner := radius * (0.9 if i % 4 == 0 else 0.935)
		var outer := radius * (0.975 if i % 4 == 0 else 0.955)
		var color := bright if i % 4 == 0 else faint
		draw_line(
			center + Vector2(cos(angle), sin(angle)) * inner,
			center + Vector2(cos(angle), sin(angle)) * outer,
			color,
			1.0,
			true
		)

	for i in 6:
		var angle := TAU * float(i) / 6.0 - PI * 0.5
		var inner := center + Vector2(cos(angle), sin(angle)) * radius * 0.25
		var outer := center + Vector2(cos(angle), sin(angle)) * radius * 0.54
		draw_line(inner, outer, Color(0.6, 0.47, 0.3, 0.055), 1.0, true)

	var diamond := PackedVector2Array([
		center + Vector2(0.0, -radius * 1.045),
		center + Vector2(radius * 0.028, -radius),
		center + Vector2(0.0, -radius * 0.955),
		center + Vector2(-radius * 0.028, -radius),
	])
	draw_polyline(diamond, Color(0.78, 0.62, 0.41, 0.26), 1.0, true)

	draw_circle(center, 2.2, Color(0.78, 0.62, 0.41, 0.22))
	draw_circle(center, radius * 0.47, Color(0.72, 0.56, 0.36, 0.02))


func _draw_horizon_rules() -> void:
	draw_line(Vector2(0.0, 95.0), Vector2(size.x, 95.0), Color(0.55, 0.5, 0.42, 0.2), 1.0)
	draw_line(Vector2(0.0, 96.5), Vector2(size.x, 96.5), Color(0.0, 0.0, 0.0, 0.4), 1.0)
	draw_line(Vector2(size.x * 0.055, size.y - 48.0), Vector2(size.x * 0.945, size.y - 48.0), Color(0.55, 0.5, 0.42, 0.12), 1.0)


func _draw_grain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = grain_seed
	for i in grain_amount:
		var point := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
		var alpha := rng.randf_range(0.015, 0.045)
		draw_rect(Rect2(point, Vector2.ONE), Color(0.75, 0.72, 0.66, alpha))
