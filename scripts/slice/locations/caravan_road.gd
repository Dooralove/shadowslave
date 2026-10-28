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
	_set_chain_pose("walk")


func stop_march() -> void:
	marching = false
	_set_chain_pose("idle")


func _set_chain_pose(pose: String) -> void:
	for node in chain.get_children():
		if node is Mannequin:
			(node as Mannequin).pose = pose


func set_march_follower(player: Node3D) -> void:
	_march_follower = player


func _physics_process(_delta: float) -> void:
	# Цепь держится вровень с Санни вдоль дороги: физика тела на склоне чуть отстаёт от расчётного темпа,
	# и без привязки звенья разошлись бы с персонажем. В прологе Санни — у режиссёра,
	# в марше S01 его передаёт set_march_follower().
	var follower: Node3D = _march_follower if _march_follower else (director.player if director else null)
	if marching and follower:
		chain.position.z = road.to_local(follower.global_position).z


## Всадник ездит вдоль колонны вперёд и назад (относительно цепи).
func _patrol(rider: Node3D) -> void:
	var start := rider.position
	var end := start + Vector3(0, 0, -rider_patrol)
	var tween := create_tween().set_loops()
	tween.tween_property(rider, "position", end, rider_patrol / 1.5)
	tween.tween_callback(func() -> void: rider.rotate_y(PI))
	tween.tween_property(rider, "position", start, rider_patrol / 1.5)
	tween.tween_callback(func() -> void: rider.rotate_y(PI))
