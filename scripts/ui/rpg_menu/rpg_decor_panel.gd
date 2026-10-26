extends PanelContainer
## Тонкие угловые засечки поверх панели. Не заменяет StyleBox, только дополняет.

@export var corners := true
@export var accent := false
@export var corner_length := 14.0
@export var line_color := Color(0.6, 0.48, 0.31, 0.55)


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if not corners or size.x < 20.0 or size.y < 20.0:
		return

	var inset := 1.0
	var length := minf(corner_length, minf(size.x, size.y) * 0.18)
	var points := [
		[Vector2(inset, inset + length), Vector2(inset, inset), Vector2(inset + length, inset)],
		[Vector2(size.x - inset - length, inset), Vector2(size.x - inset, inset), Vector2(size.x - inset, inset + length)],
		[Vector2(inset, size.y - inset - length), Vector2(inset, size.y - inset), Vector2(inset + length, size.y - inset)],
		[Vector2(size.x - inset - length, size.y - inset), Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset, size.y - inset - length)],
	]
	for corner in points:
		draw_polyline(PackedVector2Array(corner), line_color, 1.0, true)

	if accent:
		var center := Vector2(size.x * 0.5, 1.0)
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -3.0),
			center + Vector2(3.0, 0.0),
			center + Vector2(0.0, 3.0),
			center + Vector2(-3.0, 0.0),
		])
		draw_colored_polygon(diamond, Color(0.75, 0.59, 0.38, 0.8))
