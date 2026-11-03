class_name BeatData
extends Resource
## Описание одного события кампании «Первый Кошмар» по списку событий v2
## (docs/design/first_nightmare_beat_sheet_v2.md).

enum BeatType {
	GAMEPLAY,
	CUTSCENE,
	INTERACTIVE_CUTSCENE,
	TRANSITION,
}

@export var id: StringName = &""
@export var part: StringName = &""
@export var part_title: String = ""
@export var canonical_block: int = 1
@export var title: String = ""
@export var beat_type: BeatType = BeatType.GAMEPLAY
@export var format_label: String = "И"
## Единственная строка цели игрока (пустая для чистых катсцен и склеек).
@export var objective: String = ""
## Две-три ступени уточнения цели при бездействии. Пусто — уточнений нет.
@export var idle_objectives: Array[String] = []
## Id маяка GuideBeacon, который ведёт к текущей цели. Пусто — маяк не нужен.
@export var guide_beacon_id: StringName = &""
## Идентификатор стартового чекпоинта перед опасностью (пустой, если опасности нет).
@export var checkpoint_id: StringName = &""
## Все чекпоинты внутри события (для протяжённых отрезков вроде N10, N15, N21).
@export var checkpoint_ids: Array[StringName] = []
## Мировые координаты чекпоинтов события по их идентификаторам.
@export var checkpoint_positions: Dictionary[StringName, Vector3] = {}
@export var entry_conditions: Array[StringName] = []
@export var exit_conditions: Array[StringName] = []
## Флаги, которые выставляются постановкой события (например, flasks_poisoned в N13).
@export var staging_flags: Array[StringName] = []
@export var estimated_seconds: float = 60.0
@export var estimated_time_text: String = "~1 мин"
@export_file("*.tscn") var scene_path: String = ""
@export var can_die: bool = false


func is_valid() -> bool:
	return id != &"" and not title.strip_edges().is_empty() and not scene_path.is_empty() and estimated_seconds > 0.0


func get_type_name() -> String:
	match beat_type:
		BeatType.GAMEPLAY:
			return "игра"
		BeatType.CUTSCENE:
			return "катсцена"
		BeatType.INTERACTIVE_CUTSCENE:
			return "интерактивная катсцена"
		BeatType.TRANSITION:
			return "склейка"
	return "игра"


func has_checkpoint(target_id: StringName = &"") -> bool:
	if target_id == &"":
		return checkpoint_id != &"" or not checkpoint_ids.is_empty()
	return checkpoint_id == target_id or checkpoint_ids.has(target_id) or checkpoint_positions.has(target_id)


func get_checkpoint_position(target_id: StringName = &"") -> Vector3:
	var key := target_id if target_id != &"" else checkpoint_id
	if checkpoint_positions.has(key):
		return checkpoint_positions[key]
	if checkpoint_id != &"" and checkpoint_positions.has(checkpoint_id):
		return checkpoint_positions[checkpoint_id]
	return Vector3.ZERO
