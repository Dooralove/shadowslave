extends SliceLocation
## B01–B07: скамейка в сквере на окраине, улица, вход в участок.

const COMMUTER_SPEED := 1.3

@onready var cup: Node3D = $Props/CoffeeCup
@onready var bin_top: Marker3D = $Markers/BinTop
@onready var miss_spot: Marker3D = $Markers/MissSpot


func _ready() -> void:
	super._ready()
	# Прохожие идут мимо, пока Санни сидит; ростом все выше него.
	for commuter in $Commuters.get_children():
		_walk_loop(commuter as Node3D)


func play_cutscene(id: StringName, fast: bool) -> void:
	match id:
		&"doze":
			await _doze(fast)
		&"stand_up":
			await _stand_up(fast)
		&"bin":
			await _bin(fast)
		_:
			super.play_cutscene(id, fast)


## Кофе не помогает: веки тяжелеют, Санни клюёт носом и приходит в себя от шлепка по щеке.
func _doze(fast: bool) -> void:
	use_shot(&"DozeShot")
	var ui := director.ui
	await ui.drowsiness.animate_to(0.95, 0.0 if fast else 2.5)
	await animate(ui.fade, ^"color:a", 0.85, 0.6, fast)
	await pause(0.6, fast)
	# Шлепок: резкая встряска кадра и ясность.
	ui.fade.color.a = 0.0
	ui.drowsiness.intensity = 0.15
	await _shake(shot(&"DozeShot"), 0.35, fast)
	director.use_player_camera()


func _stand_up(fast: bool) -> void:
	cup.visible = false
	var length := director.actor.play(&"stand_up")
	await pause(length * 0.7, fast)
	var stand := get_spawn(&"BenchStand")
	await animate(director.player, ^"global_position", stand.global_position, length * 0.3, fast)
	director.actor.play(&"idle")


## Бросает стаканчик в урну, промахивается, поднимает и кладёт.
func _bin(fast: bool) -> void:
	var player := director.player
	var mark := get_spawn(&"BinThrow")
	# Поворот кратчайшей дугой.
	var turn := player.visual.rotation.y + wrapf(mark.global_rotation.y - player.visual.rotation.y, -PI, PI)
	animate(player, ^"global_position", mark.global_position, 0.3, fast)
	await animate(player.visual, ^"rotation:y", turn, 0.3, fast)

	var throw_length := director.actor.play(&"throw")
	await pause(throw_length * 0.45, fast)
	cup.global_position = player.global_position + Vector3(0, 1.4, 0)
	cup.visible = true
	await _arc(cup, miss_spot.global_position, 0.6, fast)
	await pause(throw_length * 0.2, fast)

	# Подходит к упавшему стаканчику.
	var pick_spot := get_spawn(&"PickSpot")
	director.actor.play(&"walk")
	await animate(player, ^"global_position", pick_spot.global_position, 0.7, fast)
	player.visual.rotation.y = pick_spot.global_rotation.y
	var pick_length := director.actor.play(&"pick_up")
	await pause(pick_length * 0.5, fast)
	cup.visible = false
	await pause(pick_length * 0.3, fast)
	cup.global_position = bin_top.global_position
	cup.visible = true
	await pause(0.25, fast)
	cup.visible = false
	director.actor.play(&"idle")


func _arc(node: Node3D, to: Vector3, duration: float, fast: bool) -> void:
	var from := node.global_position
	if fast:
		node.global_position = to
		return
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		node.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 0.6, 0), 0.0, 1.0, duration)
	await tween.finished


func _shake(camera: Camera3D, duration: float, fast: bool) -> void:
	if fast or camera == null:
		return
	var origin := camera.h_offset
	var tween := create_tween()
	for i in 6:
		tween.tween_property(camera, "h_offset", origin + (0.08 if i % 2 == 0 else -0.08), duration / 6.0)
	tween.tween_property(camera, "h_offset", origin, 0.05)
	await tween.finished


## Прохожий ходит туда и обратно по своему тротуару.
func _walk_loop(commuter: Node3D) -> void:
	var start := commuter.position
	var end := start + Basis(Vector3.UP, commuter.rotation.y) * Vector3(0, 0, -16)
	var duration := 16.0 / COMMUTER_SPEED
	var tween := create_tween().set_loops()
	tween.tween_property(commuter, "position", end, duration)
	tween.tween_callback(func() -> void: commuter.rotate_y(PI))
	tween.tween_property(commuter, "position", start, duration)
	tween.tween_callback(func() -> void: commuter.rotate_y(PI))
