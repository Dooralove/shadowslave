extends Node3D
## Прототип прилива для первого greybox-фрагмента Лабиринта.
##
## Цикл намеренно ускорен для проверки: в документации целевой цикл 16 минут,
## здесь 120 секунд. Экспорт cycle_seconds позволяет выставить финальное
## значение без изменения сцены.
##
## Вода — визуальная плоскость. Затопление пока не убивает: TideController
## закрывает низкие проходы через TideGate и оставляет высокие обходы. Это
## проверка пространственной структуры, а не финальная система выживания.

signal tide_changed(high: bool)

@export var water_plane: MeshInstance3D
@export var low_y := -8.0
@export var high_y := 4.0
@export var cycle_seconds := 120.0
@export var gate_threshold := 2.0

var _time := 0.0
var _high := false
var _gates: Array[Node] = []


func _ready() -> void:
	add_to_group(&"tide_controller")
	if water_plane == null:
		water_plane = get_node_or_null(^"../WaterPlane") as MeshInstance3D
	if water_plane != null:
		water_plane.position.y = low_y
	call_deferred(&"_collect_gates")


func _collect_gates() -> void:
	_gates = get_tree().get_nodes_in_group(&"tide_gate")


func _process(delta: float) -> void:
	if water_plane == null:
		return
	_time = fmod(_time + delta, maxf(cycle_seconds, 1.0))
	var phase := _time / maxf(cycle_seconds, 1.0)
	var level := lerpf(low_y, high_y, 0.5 - 0.5 * cos(phase * TAU))
	water_plane.position.y = level
	var high := level >= gate_threshold
	if high != _high:
		_high = high
		_set_gates(high)
		tide_changed.emit(high)


func _set_gates(high: bool) -> void:
	for gate in _gates:
		if gate == null or not is_instance_valid(gate):
			continue
		if gate is StaticBody3D:
			gate.collision_layer = 1 if high else 0
		var shape := gate.get_child(0) as CollisionShape3D
		if shape != null:
			shape.disabled = not high


## Для тестов и отладки: принудительно поставить фазу 0..1.
func set_phase(value: float) -> void:
	_time = clampf(value, 0.0, 1.0) * maxf(cycle_seconds, 1.0)
	_process(0.0)


## SQ-04: довести прилив до низкой воды. Возвращает false, если уже отлив.
func advance_to_low() -> bool:
	if not _high and get_level() <= 0.05:
		return false
	set_phase(0.0)
	return true


## SQ-04/SQ-05: довести прилив до высокой воды. Возвращает false, если уже прилив.
func advance_to_high() -> bool:
	if _high:
		return false
	set_phase(0.5)
	return true


func is_high_water() -> bool:
	return _high


## Уровень воды 0..1 (0 — отлив, 1 — полный прилив). HUD читает его для полосы.
func get_level() -> float:
	if high_y <= low_y:
		return 0.0
	return clampf((water_plane.position.y - low_y) / (high_y - low_y), 0.0, 1.0)


## Фаза цикла 0..1: 0 — низкая вода, 1 — снова низкая вода.
func get_cycle_progress() -> float:
	return fmod(_time / maxf(cycle_seconds, 1.0), 1.0)


func is_rising() -> bool:
	return sin(get_cycle_progress() * TAU) > 0.0


## Секунды до ближайшего перехода «низкая вода → высокая».
func seconds_until_high() -> float:
	var level := get_level()
	if level >= high_threshold_level():
		return 0.0
	var phase := get_cycle_progress()
	var start := acos(clampf(1.0 - 2.0 * high_threshold_level(), -1.0, 1.0)) / TAU
	var end := 1.0 - start
	if phase < start:
		return (start - phase) * maxf(cycle_seconds, 1.0)
	if phase > end:
		return (1.0 - phase + start) * maxf(cycle_seconds, 1.0)
	return 0.0


## Секунды до ближайшего перехода «высокая вода → низкая».
func seconds_until_low() -> float:
	if get_level() < high_threshold_level():
		return 0.0
	var phase := get_cycle_progress()
	var start := acos(clampf(1.0 - 2.0 * high_threshold_level(), -1.0, 1.0)) / TAU
	var end := 1.0 - start
	if phase <= end:
		return (end - phase) * maxf(cycle_seconds, 1.0)
	return (1.0 - phase + end) * maxf(cycle_seconds, 1.0)


func high_threshold_level() -> float:
	if high_y <= low_y:
		return 1.0
	return clampf((gate_threshold - low_y) / (high_y - low_y), 0.0, 1.0)
