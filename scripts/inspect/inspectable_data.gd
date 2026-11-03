class_name InspectableData
extends Resource
## Описание «чутья» для одного значимого объекта.
##
## Что подсвечивать — задаёт сам Inspectable (target_paths), а здесь лежит
## как и когда: цвет, режим, радиус, событие, флаги и короткая мысль Санни.

enum Kind { OUTLINE, TRACKS, BLOOD, WEAK_POINT }

@export var id: StringName = &""
@export var display_name := ""
@export var kind: Kind = Kind.OUTLINE
@export var highlight_color := Color(0.72, 0.86, 1.0, 1.0)
@export_range(0.0, 2.0) var highlight_strength := 0.9
@export var pulse_speed := 2.2
@export var detection_radius := 3.0
@export var auto_inspect := true
## Пусто — объект доступен в любом событии; иначе только в этом beat.
@export var beat_id: StringName = &""
@export var required_flags: Array[StringName] = []
@export var forbidden_flags: Array[StringName] = []
## После выполнения объект больше не светится.
@export var completed_flag: StringName = &""
@export var completed_item: StringName = &""
@export var thought_id: StringName = &""
@export var thought_once := true
## Если задан, на время подсветки приглушается GuideBeacon с этим id,
## чтобы чутьё и ведение игрока не дублировали друг друга.
@export var suppress_beacon_id: StringName = &""


func is_valid() -> bool:
	return id != &"" and detection_radius > 0.0
