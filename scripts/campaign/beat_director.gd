class_name BeatDirector
extends Node
## Режиссёр слоя событий (beat system) для кампании «Первый Кошмар» v2
## (docs/design/first_nightmare_beat_sheet_v2.md).
##
## Хранит 26 событий P01–N26, переключает текущее событие, эмитит сигналы
## beat_started / beat_completed / objective_changed, пишет и читает чекпоинты
## в NightmareRunState и синхронизирует их с FallRecovery.

signal beat_started(beat: BeatData)
signal beat_completed(beat: BeatData)
signal objective_changed(objective: String)
signal checkpoint_activated(checkpoint_id: StringName, position: Vector3)
signal campaign_completed

const BEATS_DIR := "res://resources/campaign/beats/"
const BEAT_IDS: Array[StringName] = [
	&"P01", &"P02", &"P03", &"P04",
	&"N05", &"N06", &"N07", &"N08", &"N09", &"N10",
	&"N11", &"N12", &"N13",
	&"N14", &"N15", &"N16", &"N17", &"N18", &"N19",
	&"N20", &"N21", &"N22", &"N23",
	&"N24", &"N25", &"N26",
]

@export var beats: Array[BeatData] = []
@export var fall_recovery: FallRecovery

var current_beat: BeatData = null
var current_index: int = -1
var current_objective: String = ""
var _beat_map: Dictionary = {}


func _ready() -> void:
	_ensure_beats_loaded()
	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_method(&"bind_director"):
		guide.call(&"bind_director", self)


func _ensure_beats_loaded() -> void:
	if beats.is_empty():
		beats = load_default_beats()
	_beat_map.clear()
	for beat in beats:
		if beat != null and beat.id != &"":
			_beat_map[beat.id] = beat


static func load_default_beats() -> Array[BeatData]:
	var loaded: Array[BeatData] = []
	for id in BEAT_IDS:
		var path := "%s%s.tres" % [BEATS_DIR, String(id).to_lower()]
		var resource := load(path) as BeatData
		if resource != null:
			loaded.append(resource)
		else:
			push_error("BeatDirector: не удалось загрузить ресурс события %s" % path)
	return loaded


func bind_player(player: Node) -> void:
	if player == null:
		return
	if player is FallRecovery:
		fall_recovery = player as FallRecovery
	else:
		fall_recovery = player.get_node_or_null("FallRecovery") as FallRecovery
	if fall_recovery != null and NightmareRunState.has_checkpoint():
		var cid := NightmareRunState.get_checkpoint_id()
		var pos := resolve_checkpoint_position(cid)
		fall_recovery.set_checkpoint(pos, cid)


func get_beat(beat_id: StringName) -> BeatData:
	_ensure_beats_loaded()
	return _beat_map.get(StringName(beat_id), null) as BeatData


func get_beat_index(beat_id: StringName) -> int:
	_ensure_beats_loaded()
	var target := StringName(beat_id)
	for index in beats.size():
		if beats[index] != null and beats[index].id == target:
			return index
	return -1


func get_current_beat() -> BeatData:
	return current_beat


func get_current_beat_id() -> StringName:
	return current_beat.id if current_beat != null else &""


func can_enter_beat(beat: BeatData) -> bool:
	if beat == null:
		return false
	if beat.entry_conditions.is_empty():
		return true
	return NightmareRunState.require(beat.entry_conditions)


func start_campaign(from_beat_id: StringName = &"P01", ignore_entry_conditions := false) -> BeatData:
	_ensure_beats_loaded()
	start_beat(from_beat_id, ignore_entry_conditions)
	return current_beat


func start_beat(beat_id: StringName, ignore_entry_conditions := false) -> bool:
	_ensure_beats_loaded()
	var index := get_beat_index(beat_id)
	if index < 0:
		push_error("BeatDirector: неизвестное событие %s" % beat_id)
		return false
	var target := beats[index]
	if not ignore_entry_conditions and not can_enter_beat(target):
		return false

	current_index = index
	current_beat = target
	NightmareRunState.set_current_beat(target.id)

	if target.checkpoint_id != &"":
		activate_checkpoint(target.checkpoint_id)

	beat_started.emit(target)
	_set_objective(target.objective)
	return true


func complete_current_beat(auto_advance := true) -> BeatData:
	if current_beat == null:
		return null
	var finished := current_beat
	apply_staging_flags(finished)
	for flag in finished.exit_conditions:
		NightmareRunState.set_flag(flag)
	beat_completed.emit(finished)

	if not auto_advance:
		return finished

	var next_index := current_index + 1
	if next_index < beats.size():
		start_beat(beats[next_index].id, false)
		return current_beat

	campaign_completed.emit()
	return null


func complete_beat(beat_id: StringName, auto_advance := false) -> bool:
	_ensure_beats_loaded()
	if current_beat == null or current_beat.id != beat_id:
		if not start_beat(beat_id, true):
			return false
	complete_current_beat(auto_advance)
	return true


func advance_to_next_beat(ignore_entry_conditions := false) -> BeatData:
	_ensure_beats_loaded()
	var next_index := current_index + 1
	if next_index < 0 or next_index >= beats.size():
		return null
	if start_beat(beats[next_index].id, ignore_entry_conditions):
		return current_beat
	return null


## Переключает событие из живой сцены, эмитя beat_completed для предыдущего
## события и запуская новое вместе с его чекпоинтом и целью, не перезаписывая
## промежуточные флаги постановки раньше времени.
func transition_to_beat(beat_id: StringName) -> bool:
	_ensure_beats_loaded()
	if current_beat != null and current_beat.id != beat_id:
		beat_completed.emit(current_beat)
	return start_beat(beat_id, true)




## Применяет флаги постановки события (например, flasks_poisoned в N13 или camp_bloodbane_seen в N07).
func apply_staging_flags(beat: BeatData) -> void:
	if beat == null:
		return
	for flag in beat.staging_flags:
		NightmareRunState.set_flag(flag)


func stage_beat(beat_id: StringName) -> bool:
	var beat := get_beat(beat_id)
	if beat == null:
		return false
	apply_staging_flags(beat)
	return true


func _set_objective(next_objective: String) -> void:
	current_objective = next_objective
	objective_changed.emit(current_objective)


## Возвращает все чекпоинты по всем BeatData строго в порядке событий.
func get_all_checkpoints() -> Array[StringName]:
	_ensure_beats_loaded()
	var result: Array[StringName] = []
	for beat in beats:
		if beat == null:
			continue
		for cid in beat.checkpoint_ids:
			if not result.has(cid):
				result.append(cid)
	return result


func find_beat_for_checkpoint(checkpoint_id: StringName) -> BeatData:
	_ensure_beats_loaded()
	var key := StringName(checkpoint_id)
	for beat in beats:
		if beat != null and beat.has_checkpoint(key):
			return beat
	return null


func resolve_checkpoint_position(checkpoint_id: StringName) -> Vector3:
	if NightmareRunState.get_checkpoint_id() == checkpoint_id and NightmareRunState.has_checkpoint_position():
		return NightmareRunState.get_checkpoint_position()
	var owner_beat := find_beat_for_checkpoint(checkpoint_id)
	if owner_beat != null:
		return owner_beat.get_checkpoint_position(checkpoint_id)
	return Vector3.ZERO


func activate_checkpoint(
	checkpoint_id: StringName,
	custom_position := Vector3.ZERO,
	use_custom_position := false
) -> Vector3:
	var cid := StringName(checkpoint_id)
	if cid == &"":
		return Vector3.ZERO
	var pos := custom_position
	if not use_custom_position:
		var owner_beat := find_beat_for_checkpoint(cid)
		if owner_beat != null:
			pos = owner_beat.get_checkpoint_position(cid)
	NightmareRunState.set_checkpoint(cid, pos, true)
	if fall_recovery != null:
		fall_recovery.set_checkpoint(pos, cid)
	if not OS.has_feature("headless"):
		var save_system := get_node_or_null(^"/root/SaveSystem")
		if save_system != null and save_system.has_method(&"save_game"):
			save_system.call(&"save_game", "checkpoint")
	checkpoint_activated.emit(cid, pos)
	return pos


func get_active_checkpoint_id() -> StringName:
	if fall_recovery != null and fall_recovery.get_checkpoint_id() != &"":
		return fall_recovery.get_checkpoint_id()
	return NightmareRunState.get_checkpoint_id()


func get_active_checkpoint_position() -> Vector3:
	if fall_recovery != null and fall_recovery.has_checkpoint():
		return fall_recovery.recovery_point()
	return NightmareRunState.get_checkpoint_position()


## Возвращает игрока на активный чекпоинт из состояния кампании без экрана загрузки.
func recover_to_checkpoint() -> Vector3:
	var cid := NightmareRunState.get_checkpoint_id()
	var pos := resolve_checkpoint_position(cid)
	if fall_recovery != null:
		if cid != &"":
			fall_recovery.set_checkpoint(pos, cid)
		fall_recovery.recover()
		return fall_recovery.recovery_point()
	return pos
