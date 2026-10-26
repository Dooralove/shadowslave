extends Node2D
## Звёздное поле для сцены оценки. Рисунок детерминированный: тесты и
## скриншоты не зависят от случайного зерна.

@export var star_count := 240
@export var thread_count := 14
@export var seed_value := 24051991


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in star_count:
		var point := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var radius := rng.randf_range(0.4, 1.5)
		var alpha := rng.randf_range(0.25, 0.9)
		draw_circle(point, radius, Color(0.78, 0.86, 1.0, alpha))
	for i in thread_count:
		var start := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var end := start + Vector2(rng.randf_range(-180.0, 180.0), rng.randf_range(-120.0, 120.0))
		draw_line(start, end, Color(0.56, 0.72, 0.95, rng.randf_range(0.07, 0.2)), 1.0)
