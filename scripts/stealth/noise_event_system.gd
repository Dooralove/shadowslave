class_name NoiseEventSystem
extends Node
## Шина звуковых событий стелса. Сама ничего не решает: выдаёт событие,
## а слушатели (Тиран) проверяют радиус и реагируют.

signal noise_emitted(event: NoiseEventData, origin: Vector3, source: Node3D)

@export var events: Array[NoiseEventData] = []

var _by_id: Dictionary = {}


func _ready() -> void:
	for event in events:
		register_event(event)


func register_event(event: NoiseEventData) -> bool:
	if event == null or not event.is_valid():
		return false
	_by_id[event.id] = event
	return true


func get_event(event_id: StringName) -> NoiseEventData:
	return _by_id.get(StringName(event_id), null) as NoiseEventData


func emit_event(event_id: StringName, origin: Vector3, source: Node3D = null) -> bool:
	var event := get_event(event_id)
	if event == null:
		return false
	noise_emitted.emit(event, origin, source)
	return true


func emit_data(event: NoiseEventData, origin: Vector3, source: Node3D = null) -> bool:
	if event == null:
		return false
	noise_emitted.emit(event, origin, source)
	return true


func is_audible_at(event: NoiseEventData, listener_position: Vector3, origin: Vector3) -> bool:
	return event != null and event.is_audible_from(listener_position, origin)
