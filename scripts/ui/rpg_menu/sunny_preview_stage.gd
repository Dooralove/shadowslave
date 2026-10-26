extends Node3D
## Медленный показ существующей POC-модели Санни в SubViewport.
## Модель не копируется и не переодевается: это только презентация.

@export var auto_turn := true
@export var turn_amplitude := 0.11
@export var turn_speed := 0.24
@export var manual_turn_speed := 0.012

@onready var turntable: Node3D = $Turntable
@onready var animation_player: AnimationPlayer = $Turntable/Sunny/AnimationPlayer

var _elapsed := 0.0
var _manual_rotation := 0.0


func _ready() -> void:
	animation_player.play(&"sunny/Idle_Relaxed")


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	var sway := sin(_elapsed * turn_speed) * turn_amplitude if auto_turn else 0.0
	turntable.rotation.y = _manual_rotation + sway


## Поворот мышью. Значение в радианах, обычно delta.x * 0.01.
func rotate_by(amount: float) -> void:
	_manual_rotation = fposmod(_manual_rotation + amount, TAU)
	if not auto_turn:
		turntable.rotation.y = _manual_rotation


func reset_view() -> void:
	_manual_rotation = 0.0
	_elapsed = 0.0
