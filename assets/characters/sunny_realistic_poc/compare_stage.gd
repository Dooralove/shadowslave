extends Node3D
## Стенд сравнения KayKit и прототипа (только для S2). Время рендера кадра меряется через
## RenderingServer: оно не зависит от вертикальной синхронизации, в отличие от FPS.

const KAYKIT := preload("res://assets/characters/sunny_placeholder/Rogue_Hooded.glb")
const POC := preload("res://assets/characters/sunny_realistic_poc/sunny_poc_model.tscn")

var _gpu: Array[float] = []
var _cpu: Array[float] = []
var _crowd: Array[Node3D] = []


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	# Как в прологе (sunny_waking.tscn): ножи временной модели скрыты.
	for knife in [^"KayKit/Rig/Skeleton3D/handslot_r/Knife", ^"KayKit/Rig/Skeleton3D/handslot_l/Knife_Offhand"]:
		var node := get_node_or_null(knife) as Node3D
		if node:
			node.visible = false


func _process(_delta: float) -> void:
	var rid := get_viewport().get_viewport_rid()
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))


## Одинаковая постановка для обеих моделей: "idle", "walk", "run", "sit".
## Клипы — те же, что в прологе (KayKit: SunnyAnimator / sunny_kaykit_clips, прототип: вариант сцены).
func pose(kind: String) -> void:
	var clips := {
		"idle": [&"Unarmed_Idle", &"sunny/Idle_Relaxed"],
		"walk": [&"Walking_A", &"Walk"],
		"run": [&"Running_A", &"Sprint"],
		"sit": [&"Sit_Chair_Idle", &"Sitting_Idle"],
	}
	($KayKit/AnimationPlayer as AnimationPlayer).play(clips[kind][0])
	($Poc/AnimationPlayer as AnimationPlayer).play(clips[kind][1])
	$Benches.visible = kind == "sit"


## Проигрывает клип прототипа и останавливает его на моменте time (с), чтобы рассмотреть позу.
func poc_frame(clip: StringName, time: float) -> void:
	var player := $Poc/AnimationPlayer as AnimationPlayer
	player.play(clip)
	player.seek(time, true)
	player.pause()


## Ставит камеру Detail на расстоянии distance от точки target под углом yaw_deg (0 — спереди) и делает её текущей.
func focus(target: Vector3, distance: float, yaw_deg: float, height := 0.0) -> void:
	var camera := $Detail as Camera3D
	var yaw := deg_to_rad(yaw_deg)
	camera.position = target + Vector3(sin(yaw) * distance, height, cos(yaw) * distance)
	camera.look_at(target)
	camera.make_current()


## "kaykit", "poc" или "both" — какие модели стенда видны.
func show_only(kind: String) -> void:
	$KayKit.visible = kind != "poc"
	$Poc.visible = kind != "kaykit"


## Ставит сетку из count копий модели перед камерой Wide (замер стоимости персонажа).
func spawn_crowd(kind: String, count: int) -> void:
	for node in _crowd:
		node.queue_free()
	_crowd.clear()
	for i in count:
		var node: Node3D
		if kind == "kaykit":
			node = KAYKIT.instantiate()
			node.scale = Vector3.ONE * 0.8
			node.get_node("AnimationPlayer").play(&"Walking_A")
		else:
			node = POC.instantiate()
			node.get_node("AnimationPlayer").play(&"Walk")
		node.position = Vector3(-3.0 + (i % 8) * 0.85, 0, -1.5 - (i / 8) * 1.2)
		add_child(node)
		_crowd.append(node)


func reset_timing() -> void:
	_gpu.clear()
	_cpu.clear()


func report() -> Dictionary:
	return {"frames": _gpu.size(), "gpu_ms": _stats(_gpu), "cpu_ms": _stats(_cpu)}


func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	return {
		"avg": snappedf(total / sorted.size(), 0.001),
		"p99": snappedf(sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))], 0.001),
	}
