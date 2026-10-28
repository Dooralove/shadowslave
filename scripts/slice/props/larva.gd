extends Node3D
## Временная личинка Горного Короля: примитивы, без AI и без коллизии.
## Анимация — только дрожь и повороты; сценарий управляет масштабом и видимостью.

@export var writhe_speed := 7.0
@export var writhe_amount := 0.08

var _time := 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	rotation.z = sin(_time * writhe_speed) * writhe_amount
	rotation.x = sin(_time * writhe_speed * 0.7 + 0.8) * writhe_amount * 0.6
