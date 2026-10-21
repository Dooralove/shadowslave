class_name PerfProbe
extends Node
## Отладочный замер производительности по битам среза: среднее FPS и 1% худших кадров.
## Включается вручную (enabled = true), на игровую логику не влияет.

@export var enabled := false
## Текущая корзина замера — режиссёр подставляет имя бита.
var bucket := &"none"
var _frame_times := {}


func _process(delta: float) -> void:
	if not enabled:
		return
	if not _frame_times.has(bucket):
		_frame_times[bucket] = []
	_frame_times[bucket].append(delta)


func reset() -> void:
	_frame_times.clear()


func report() -> Dictionary:
	var result := {}
	for key in _frame_times:
		var times: Array = _frame_times[key].duplicate()
		if times.is_empty():
			continue
		var total := 0.0
		for t in times:
			total += t
		times.sort()
		var worst_count := maxi(1, floori(times.size() / 100.0))
		var worst_total := 0.0
		for i in worst_count:
			worst_total += times[times.size() - 1 - i]
		result[key] = {
			"frames": times.size(),
			"avg_fps": snappedf(times.size() / total, 0.1),
			"low_1pct_fps": snappedf(worst_count / worst_total, 0.1),
			"max_frame_ms": snappedf(times[-1] * 1000.0, 0.01),
		}
	return result
