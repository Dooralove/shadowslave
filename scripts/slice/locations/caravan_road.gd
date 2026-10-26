extends SliceLocation
## B15–B16: горная дорога; Санни идёт в цепи рабов вверх по склону, вдоль колонны ездят всадники.

## Темп цепи вдоль дороги, м/с.
@export var march_speed := 1.1
## Как далеко всадник отъезжает вдоль колонны, прежде чем развернуться, м.
@export var rider_patrol := 18.0

@onready var road: Node3D = $Road
@onready var chain: Node3D = $Road/Chain

var marching := false
var auto_barks := false
var _march_follower: Node3D = null


func _ready() -> void:
	super._ready()
	for rider in $Road/Chain/Riders.get_children():
		_patrol(rider as Node3D)


func march_velocity() -> Vector3:
	return road.global_basis * Vector3(0, 0, -march_speed)


func start_march() -> void:
	marching = true


func stop_march() -> void:
	marching = false


func set_march_follower(player: Node3D) -> void:
	_march_follower = player


func _physics_process(_delta: float) -> void:
	# Цепь держится вровень с Санни вдоль дороги: физика тела на склоне чуть отстаёт от расчётного темпа,
	# и без привязки звенья разошлись бы с персонажем.
	if marching and director:
		chain.position.z = road.to_local(director.player.global_position).z


## Всадник ездит вдоль колонны вперёд и назад (относительно цепи).
func _patrol(rider: Node3D) -> void:
	var start := rider.position
	var end := start + Vector3(0, 0, -rider_patrol)
	var tween := create_tween().set_loops()
	tween.tween_property(rider, "position", end, rider_patrol / 1.5)
	tween.tween_callback(func() -> void: rider.rotate_y(PI))
	tween.tween_property(rider, "position", start, rider_patrol / 1.5)
	tween.tween_callback(func() -> void: rider.rotate_y(PI))
