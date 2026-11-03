class_name NoiseEventData
extends Resource
## Описание слышимого события. Радиус — дистанция слышимости, loudness —
## сила привлечения Тирана (не зрение). Данные лежат в .tres.

@export var id: StringName = &""
## Дистанция, с которой событие слышно, м.
@export var radius := 4.0
## Относительная громкость 0..1: чем выше, тем сильнее привлекает слух.
@export_range(0.0, 1.0) var loudness := 0.5
## Приоритет для будущих источников/микширования.
@export var priority := 0
## Колокольчик — исключение из правила: он должен увести Тирана на Героя.
@export var is_bell := false
## Длительность «следа» звука, если слушатель приходит позже.
@export var memory_seconds := 2.5


func is_valid() -> bool:
	return id != &"" and radius > 0.0 and loudness > 0.0


func is_audible_from(listener_position: Vector3, origin: Vector3) -> bool:
	var offset := listener_position - origin
	offset.y = 0.0
	return offset.length() <= radius
