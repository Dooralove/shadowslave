class_name FlickerLight
extends OmniLight3D
## Живой огонь: энергия света дрожит по шуму (костёр, угли). Без случайных скачков —
## плавный шум, чтобы тени не «прыгали».

@export var base_energy := 2.4
@export var amount := 0.3
@export var speed := 7.0

var _t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta * speed
	light_energy = base_energy * (1.0 + amount * _noise.get_noise_1d(_t))
