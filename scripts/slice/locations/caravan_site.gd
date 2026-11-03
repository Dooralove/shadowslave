class_name CaravanSite
extends SliceLocation
## S02–S06: стоянка каравана, нападение, личинка, повозка, последствия,
## ветеран, Silver Bell, ночь и рассвет.
##
## Локация отвечает за геометрию, предметы и одноразовые взаимодействия.
## Постановкой, UI, звуком и переходами управляет оболочка caravan_site_arrival.
## Так сценарий не зависит от конкретных мешей, а состояние хранится в
## NightmareRunState и переживает перезагрузку.

signal sequence_requested(sequence: DialogueSequence)
signal hint_requested(text: String)
signal camp_explored
signal meal_taken
signal second_larva_finished
signal tyrant_attention_caught
signal attack_requested
signal larva_grabbed
signal key_collected
signal wagon_push_requested
signal veteran_found
signal veteran_execution_requested
signal night_requested
signal dawn_requested
signal phase_changed(phase: StringName)

const FLAG_RATIONS := &"camp_rations_taken"
const FLAG_BLOODBANE := &"camp_bloodbane_seen"
const FLAG_FLASKS_POISONED := &"flasks_poisoned"
const FLAG_SUNNY_FLASK_CLEAN := &"sunny_flask_clean"
const FLAG_WAGON := &"camp_wagon_examined"
const FLAG_CAMP_EXPLORED := &"camp_explored"
const FLAG_CAMP_COMPLETED := &"camp_completed"
const FLAG_ATTACK := &"attack_started"
const FLAG_WEDGES := &"wagon_wedges_removed"
const FLAG_LOOP := &"wagon_loop_ready"
const FLAG_WAGON_FALL := &"wagon_fall_seen"
const FLAG_TYRANT_FALL := &"tyrant_fall_seen"
const FLAG_COUNCIL := &"survivors_council_done"
const FLAG_TASKS := &"tasks_assigned"
const FLAG_VETERAN_FOUND := &"veteran_found"
const FLAG_VETERAN_DEAD := &"veteran_dead"
const FLAG_VETERAN_SWORD := &"veteran_sword_taken"
const FLAG_SILVER_BELL := &"silver_bell_obtained"
const FLAG_NIGHT := &"night_started"
const FLAG_NIGHT_PASSED := &"night_passed"
const FLAG_DAWN := &"dawn_departure"

const PHASE_CAMP := &"CAMP"
const PHASE_ATTACK := &"ATTACK"
const PHASE_LARVA := &"LARVA"
const PHASE_WAGON := &"WAGON"
const PHASE_AFTERMATH := &"AFTERMATH"
const PHASE_NIGHT := &"NIGHT"
const PHASE_DAWN := &"DAWN"
const PHASE_COMPLETE := &"COMPLETE"

const FLASK_FLAGS := [&"flask_a_collected", &"flask_b_collected", &"flask_c_collected"]

const CAMP_RATIONS := preload("res://resources/dialogue/caravan/camp_rations.tres")
const CAMP_WAGON := preload("res://resources/dialogue/caravan/camp_wagon.tres")
const SECOND_LARVA_SCENE := preload("res://scenes/enemies/larva_enemy.tscn")

@export var ration_sequence: DialogueSequence
@export var wagon_sequence: DialogueSequence


@onready var fire_light: OmniLight3D = $Props/Fire/FireLight
@onready var flame_a: Node3D = $Props/Fire/FlameA
@onready var flame_b: Node3D = $Props/Fire/FlameB
@onready var chain: Node3D = $Props/Chain
@onready var key: Node3D = $Props/Key
@onready var rations_prop: Node3D = $Props/Rations
@onready var broad_slave: Node3D = $NPCs/BroadSlave
@onready var broad_corpse: Node3D = $NPCs/BroadCorpse
@onready var larva: Node3D = $Props/Larva
@onready var four_larvae: Node3D = $Props/FourLarvae
@onready var tyrant: MountainKing = $Tyrant
@onready var rocks: Node3D = $Props/Rocks
@onready var rockfall: RockfallHazard = $Props/Rocks/RockfallHazard
@onready var chain_anchor: Node3D = $Spawns/ChainAnchor
@onready var wagon: Node3D = $Props/Wagon
@onready var wedge_l: Node3D = $Props/Wagon/WedgeL
@onready var wedge_r: Node3D = $Props/Wagon/WedgeR
@onready var chain_loop: Node3D = $Props/ChainLoop
@onready var shifty: Node3D = $NPCs/ShiftySlave
@onready var scholar: Node3D = $NPCs/Scholar
@onready var hero: Node3D = $NPCs/Hero
@onready var veteran: Node3D = $NPCs/Veteran
@onready var white_horse: Node3D = $NPCs/Hero/WhiteHorse
@onready var dark_horse: Node3D = $NPCs/Veteran/DarkHorse
@onready var veteran_sword: Node3D = $Props/VeteranSword
@onready var fire: Node3D = $Props/Fire
@onready var flask_props: Array[Node3D] = [
	$Props/Flasks/FlaskA,
	$Props/Flasks/FlaskB,
	$Props/Flasks/FlaskC,
]
@onready var dawn_light: DirectionalLight3D = $Environment/DawnLight

var phase: StringName = PHASE_CAMP
var _time := 0.0
var _rock_targets: Dictionary = {}
var _tyrant_home := Vector3.ZERO
var _tyrant_attention_active := false
@export var tyrant_attention_radius := 0.9
var second_larva: TestEnemy
var _second_larva_finishing := false
var _night_edges: Array[TriggerZone] = []


func _ready() -> void:
	super._ready()
	interacted.connect(_on_interacted)
	var triggers := get_node_or_null("Triggers")
	if triggers != null:
		for node in triggers.get_children():
			if node is TriggerZone:
				var zone := node as TriggerZone
				_night_edges.append(zone)
				zone.triggered.connect(_on_night_edge_triggered)
	if ration_sequence == null:
		ration_sequence = CAMP_RATIONS
	if wagon_sequence == null:
		wagon_sequence = CAMP_WAGON
	_prepare_props()
	set_process(true)


func _prepare_props() -> void:
	key.visible = false
	larva.visible = false
	hide_four_larvae()
	broad_corpse.visible = false
	chain_loop.visible = false
	veteran_sword.visible = false
	for flask in flask_props:
		flask.visible = false
	if is_instance_valid(dawn_light):
		dawn_light.light_energy = 0.0
		dawn_light.visible = false
	rations_prop.visible = not NightmareRunState.has_flag(FLAG_RATIONS)
	if is_instance_valid(tyrant):
		# Горный Король уже существует как боевой прототип. В лагере он только
		# кинематографическая модель: AI, урон, коллизии и гравитация отключены,
		# иначе без слоя коллизий он проваливается сквозь мир до появления.
		_tyrant_home = tyrant.position
		tyrant.set_ai_enabled(false)
		tyrant.set_physics_process(false)
		tyrant.velocity = Vector3.ZERO
		tyrant.collision_layer = 0
		tyrant.collision_mask = 0
		tyrant.visible = false
	for rock in rocks.get_children():
		if rock is RockfallHazard:
			continue
		_rock_targets[rock] = (rock as Node3D).position
		(rock as Node3D).position += Vector3(0.0, 9.0, 0.0)
		(rock as Node3D).visible = false


func begin_camp() -> void:
	_set_phase(PHASE_CAMP)
	_apply_phase_audio()
	for id in [&"camp_rations"]:
		var interactable := get_interactable(id)
		if interactable:
			interactable.enabled = not _is_camp_interaction_seen(id)
	# N07 v2: костёр и ягоды — постановка, а не чек-лист осмотров.
	set_interactable_enabled(&"camp_bloodbane", false)
	set_interactable_enabled(&"camp_wagon", false)
	set_interactable_enabled(&"camp_attack", false)
	set_interactable_enabled(&"chain_larva", false)
	set_interactable_enabled(&"hero_key", false)
	set_interactable_enabled(&"wagon_wedges", false)
	set_interactable_enabled(&"wagon_loop", false)
	set_interactable_enabled(&"wagon_push", false)
	for id in [&"flask_a", &"flask_b", &"flask_c", &"veteran", &"veteran_sword", &"dawn_exit"]:
		set_interactable_enabled(id, false)
	_arm_night_edges(false)
	_refresh_camp_progress(false)


func _is_camp_interaction_seen(id: StringName) -> bool:
	match id:
		&"camp_rations":
			return NightmareRunState.has_flag(FLAG_RATIONS)
		&"camp_bloodbane":
			return NightmareRunState.has_flag(FLAG_BLOODBANE)
		&"camp_wagon":
			return NightmareRunState.has_flag(FLAG_WAGON)
	return false


func all_camp_interactions_seen() -> bool:
	return (
		NightmareRunState.has_flag(FLAG_RATIONS)
		and NightmareRunState.has_flag(FLAG_BLOODBANE)
		and NightmareRunState.has_flag(FLAG_WAGON)
	)


func _on_interacted(id: StringName) -> void:
	match id:
		&"camp_rations":
			_take_rations()
		&"camp_wagon":
			_examine_wagon()
		&"camp_attack":
			_begin_attack()
		&"chain_larva":
			_grab_larva()
		&"hero_key":
			_collect_key()
		&"wagon_wedges":
			_remove_wedges()
		&"wagon_loop":
			_prepare_loop()
		&"wagon_push":
			_push_wagon()
		&"flask_a":
			_collect_flask(0)
		&"flask_b":
			_collect_flask(1)
		&"flask_c":
			_collect_flask(2)
		&"veteran":
			_discover_veteran()
		&"veteran_sword":
			_take_veteran_sword()
		&"dawn_exit":
			_request_dawn()


func _take_rations() -> void:
	if NightmareRunState.has_flag(FLAG_RATIONS):
		return
	NightmareRunState.set_flag(FLAG_RATIONS)
	set_interactable_enabled(&"camp_rations", false)
	rations_prop.visible = false
	if ration_sequence:
		sequence_requested.emit(ration_sequence)
	hint_requested.emit("Хлеб жёсткий, вода отдаёт железом. Лучше, чем ничего.")
	_refresh_camp_progress()
	meal_taken.emit()


func _examine_wagon() -> void:
	if NightmareRunState.has_flag(FLAG_WAGON):
		return
	NightmareRunState.set_flag(FLAG_WAGON)
	set_interactable_enabled(&"camp_wagon", false)
	if wagon_sequence:
		sequence_requested.emit(wagon_sequence)
	hint_requested.emit("Повозка стоит боком. Задние колёса — у самого обрыва, под ними клинья.")
	_refresh_camp_progress()


## Постановка N07 (список v2, D02): узнавание ягод Bloodbane и повозки с клиньями
## через взгляд Санни и вспышку кадра из видения, без ручного чек-листа осмотра.
func stage_camp_vision_recognition() -> void:
	NightmareRunState.set_flag(FLAG_BLOODBANE)
	NightmareRunState.set_flag(FLAG_WAGON)
	set_interactable_enabled(&"camp_bloodbane", false)
	set_interactable_enabled(&"camp_wagon", false)
	_refresh_camp_progress(false)



func _refresh_camp_progress(announce := true) -> void:
	if not all_camp_interactions_seen():
		return
	if not NightmareRunState.has_flag(FLAG_CAMP_EXPLORED):
		NightmareRunState.set_flag(FLAG_CAMP_EXPLORED)
		set_interactable_enabled(&"camp_attack", true)
		if announce:
			hint_requested.emit("Все якоря лагеря осмотрены. Вернитесь к костру и присядьте.")
		camp_explored.emit()
	else:
		set_interactable_enabled(&"camp_attack", true)


func _begin_attack() -> void:
	if NightmareRunState.has_flag(FLAG_ATTACK):
		return
	NightmareRunState.set_flag(FLAG_ATTACK)
	NightmareRunState.set_flag(FLAG_CAMP_COMPLETED)
	set_interactable_enabled(&"camp_attack", false)
	for id in [&"camp_rations", &"camp_bloodbane", &"camp_wagon", &"chain_larva", &"hero_key", &"wagon_wedges", &"wagon_loop", &"wagon_push"]:
		set_interactable_enabled(id, false)
	_arm_night_edges(false)
	_set_phase(PHASE_ATTACK)
	attack_requested.emit()


func _grab_larva() -> void:
	if phase != PHASE_LARVA:
		return
	set_interactable_enabled(&"chain_larva", false)
	larva_grabbed.emit()


func _collect_key() -> void:
	if phase != PHASE_LARVA:
		return
	set_interactable_enabled(&"hero_key", false)
	key.visible = false
	NightmareRunState.set_item(&"key", 1)
	key_collected.emit()


func _set_phase(next_phase: StringName) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)
	_apply_phase_audio()


func _apply_phase_audio() -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	if director.has_method(&"set_reverb_profile"):
		director.call(&"set_reverb_profile", &"outdoor")
	match phase:
		PHASE_CAMP:
			_audio_music(&"camp", 2.0)
			_audio_ambience(&"camp", 2.0)
			_audio_intensity(0.35)
		PHASE_ATTACK:
			_audio_music(&"caravan", 2.0)
			_audio_ambience(&"camp", 2.0)
			_audio_intensity(0.85)
		PHASE_LARVA:
			_audio_intensity(1.0)
		PHASE_WAGON:
			_audio_intensity(0.8)
		PHASE_AFTERMATH:
			_audio_music(&"camp", 2.0)
			_audio_ambience(&"camp", 2.0)
			_audio_intensity(0.3)
		PHASE_NIGHT:
			_audio_stop_music(2.0)
			_audio_ambience(&"camp", 2.0)
			_audio_intensity(0.0)
		PHASE_DAWN:
			_audio_music(&"camp", 2.0)
			_audio_ambience(&"camp", 2.0)
			_audio_intensity(0.45)
		PHASE_COMPLETE:
			_audio_stop_music(2.0)
			_audio_stop_ambience(2.0)
	if director.has_method(&"play_sfx"):
		match phase:
			PHASE_ATTACK:
				var roar_position: Vector3 = tyrant.global_position if is_instance_valid(tyrant) else global_position
				director.call(&"play_sfx", &"combat_tyrant_roar", roar_position, -4.0)
			PHASE_LARVA:
				var screech_position: Vector3 = larva.global_position if is_instance_valid(larva) else global_position
				director.call(&"play_sfx", &"combat_larva_screech", screech_position)
			PHASE_DAWN:
				if director.has_method(&"play_ui"):
					director.call(&"play_ui", &"ui_quest_update")


func _audio_music(cue_id: StringName, fade: float) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"play_music"):
		director.call(&"play_music", cue_id, fade)


func _audio_ambience(zone_id: StringName, fade: float) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"play_ambience"):
		director.call(&"play_ambience", zone_id, fade)


func _audio_intensity(value: float) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"set_music_intensity"):
		director.call(&"set_music_intensity", value)


func _audio_stop_music(fade: float) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"stop_music"):
		director.call(&"stop_music", fade)


func _audio_stop_ambience(fade: float) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"stop_ambience"):
		director.call(&"stop_ambience", fade)


func begin_larva_phase() -> void:
	_set_phase(PHASE_LARVA)
	set_interactable_enabled(&"chain_larva", true)
	hint_requested.emit("Цепь ослабла. Набросьте её на шею твари — E.")


## Вторая личинка N09/D04: настоящий враг на боевой основе, а не декор.
func spawn_second_larva(target: Node3D) -> TestEnemy:
	if is_instance_valid(second_larva):
		return second_larva
	hide_four_larvae()
	var enemy := (SECOND_LARVA_SCENE as PackedScene).instantiate() as TestEnemy
	enemy.name = "SecondLarva"
	enemy.target = target
	add_child(enemy)
	enemy.global_position = Vector3(2.2, 0.05, -1.1)
	enemy.health.damaged.connect(_on_second_larva_damaged)
	enemy.health.died.connect(_on_second_larva_died)
	second_larva = enemy
	_second_larva_finishing = false
	return enemy


func _on_second_larva_damaged(_amount: float) -> void:
	if second_larva == null or _second_larva_finishing:
		return
	if second_larva.health.current_health <= second_larva.health.max_health * 0.35:
		_finish_second_larva()


func _on_second_larva_died() -> void:
	_finish_second_larva()


func _finish_second_larva() -> void:
	if second_larva == null or _second_larva_finishing:
		return
	_second_larva_finishing = true
	second_larva.attack.disable()
	second_larva.set_physics_process(false)
	if not second_larva.health.is_dead():
		second_larva.health.take_damage(second_larva.health.max_health)
	second_larva.visible = false
	# Отдельный флаг: оценка не должна считать эту личинку лишним деянием.
	NightmareRunState.set_flag(&"second_larva_killed")
	second_larva_finished.emit()


func finish_episode() -> void:
	_set_phase(PHASE_COMPLETE)
	set_interactable_enabled(&"chain_larva", false)
	set_interactable_enabled(&"hero_key", false)
	set_interactable_enabled(&"wagon_wedges", false)
	set_interactable_enabled(&"wagon_loop", false)
	set_interactable_enabled(&"wagon_push", false)


func begin_wagon_phase() -> void:
	_set_phase(PHASE_WAGON)
	# N10/D05: Тиран стоит у повозки и реагирует на слишком близкое движение.
	stage_tyrant_for_wagon()
	set_tyrant_attention(true)
	# Эпизод нападения закончен: четыре личинки не должны оставаться в кадре
	# во время обсуждения плана с повозкой и во всех последующих фазах.
	hide_four_larvae()
	chain_loop.visible = false
	set_interactable_enabled(&"wagon_wedges", not NightmareRunState.has_flag(FLAG_WEDGES))
	set_interactable_enabled(&"wagon_loop", NightmareRunState.has_flag(FLAG_WEDGES) and not NightmareRunState.has_flag(FLAG_LOOP))
	set_interactable_enabled(&"wagon_push", NightmareRunState.has_flag(FLAG_LOOP) and not NightmareRunState.has_flag(FLAG_WAGON_FALL))
	if not NightmareRunState.has_flag(FLAG_WEDGES):
		hint_requested.emit("Повозка у обрыва. Выбейте клинья из-под задних колёс — E.")
	elif not NightmareRunState.has_flag(FLAG_LOOP):
		hint_requested.emit("Клинья убраны. Свейте петлю из разорванного конца цепи — E.")
	else:
		hint_requested.emit("Петля готова. Один бросок — E.")


func _remove_wedges() -> void:
	if phase != PHASE_WAGON or NightmareRunState.has_flag(FLAG_WEDGES):
		return
	NightmareRunState.set_flag(FLAG_WEDGES)
	set_interactable_enabled(&"wagon_wedges", false)
	wedge_l.visible = false
	wedge_r.visible = false
	set_interactable_enabled(&"wagon_loop", true)
	hint_requested.emit("Клинья выбиты. Задние колёса теперь держит только цепь.")


func _prepare_loop() -> void:
	if phase != PHASE_WAGON or NightmareRunState.has_flag(FLAG_LOOP):
		return
	NightmareRunState.set_flag(FLAG_LOOP)
	set_interactable_enabled(&"wagon_loop", false)
	chain_loop.visible = true
	set_interactable_enabled(&"wagon_push", true)
	hint_requested.emit("Скользящая петля готова. Один бросок — E.")


func _push_wagon() -> void:
	if phase != PHASE_WAGON:
		return
	if not NightmareRunState.has_flag(FLAG_WEDGES) or not NightmareRunState.has_flag(FLAG_LOOP):
		return
	for id in [&"wagon_wedges", &"wagon_loop", &"wagon_push"]:
		set_interactable_enabled(id, false)
	wagon_push_requested.emit()


## После промаха петля остаётся готовой: игрок возвращается на CP-N10b и бросает снова.
func reset_wagon_throw() -> void:
	if phase != PHASE_WAGON:
		return
	set_interactable_enabled(&"wagon_push", NightmareRunState.has_flag(FLAG_LOOP) and not NightmareRunState.has_flag(FLAG_WAGON_FALL))
	set_interactable_enabled(&"wagon_wedges", false)
	set_interactable_enabled(&"wagon_loop", false)


## Выставляет Тирана у обрыва для постановки с повозкой. В отличие от первого
## появления, здесь он уже не «выглядывает» из-за стены, а стоит на площадке.
func stage_tyrant_for_wagon() -> void:
	if not is_instance_valid(tyrant):
		return
	tyrant.position = Vector3(-4.5, 0.0, -3.4)
	tyrant.rotation = Vector3(0.0, -1.35, 0.0)
	tyrant.scale = Vector3.ONE
	tyrant.visible = true


func set_tyrant_attention(active: bool) -> void:
	_tyrant_attention_active = active


func is_tyrant_attention_active() -> bool:
	return _tyrant_attention_active


func animate_wagon_fall(fast := false) -> void:
	if fast:
		wagon.visible = false
		tyrant.visible = false
		chain_loop.visible = false
		_mark_wagon_fall_seen()
		return
	var start := wagon.position
	var target := start + Vector3(-3.8, -11.0, -0.5)
	var tyrant_start := tyrant.position
	var tyrant_target := tyrant_start + Vector3(-3.1, -12.0, -0.4)
	var loop_start := chain_loop.global_position
	var loop_target := tyrant_start + Vector3(0.0, 2.2, 0.0)
	chain_loop.visible = true
	var loop_tween := create_tween()
	loop_tween.tween_property(chain_loop, "global_position", loop_target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(wagon, "position", target, 1.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(wagon, "rotation", wagon.rotation + Vector3(0.2, 0.45, -0.9), 1.25)
	tween.tween_property(tyrant, "position", tyrant_target, 1.35).set_delay(0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(tyrant, "rotation", tyrant.rotation + Vector3(0.0, 0.8, 0.5), 1.35).set_delay(0.22)
	await tween.finished
	chain_loop.global_position = loop_start
	wagon.visible = false
	tyrant.visible = false
	chain_loop.visible = false
	_mark_wagon_fall_seen()


func _mark_wagon_fall_seen() -> void:
	NightmareRunState.set_flag(FLAG_WAGON_FALL)
	NightmareRunState.set_flag(FLAG_TYRANT_FALL)
	# Смерть Тирана не подтверждается: это отдельное событие храма, а не следствие
	# падения повозки. Флаг нужен будущим сценам, чтобы не воскрешать монстра.
	NightmareRunState.set_flag(&"tyrant_alive_suspected")


func show_aftermath() -> void:
	_set_phase(PHASE_AFTERMATH)
	set_tyrant_attention(false)
	wagon.visible = false
	tyrant.visible = false
	chain_loop.visible = false
	hide_four_larvae()
	broad_corpse.visible = false
	larva.visible = false
	white_horse.visible = false
	dark_horse.visible = false
	# Без лошадей Герой и Ветеран стоят, а не сидят в воздухе.
	(hero as Mannequin).pose = "idle"
	(veteran as Mannequin).pose = "idle"
	for node in [$NPCs/SoldierA, $NPCs/SoldierB, $NPCs/SlaveA, $NPCs/SlaveB, $NPCs/SlaveC]:
		(node as Node3D).visible = false
	hero.position = Vector3(1.2, 0.0, 1.5)
	hero.rotation.y = 0.2
	shifty.position = Vector3(1.5, 0.0, 0.0)
	scholar.position = Vector3(-0.6, 0.0, 1.4)
	veteran.position = Vector3(4.4, 0.0, -3.0)
	veteran.rotation.y = -0.7
	veteran_sword.visible = false
	set_interactable_enabled(&"wagon_wedges", false)
	set_interactable_enabled(&"wagon_loop", false)
	set_interactable_enabled(&"wagon_push", false)
	NightmareRunState.set_flag(&"aftermath_started")
	NightmareRunState.set_flag(&"survivors_four")
	hint_requested.emit("Нападение закончилось. У костра остались только четверо живых.")


## После совета у огня: задачи распределены, можно собирать фляги и найти
## раненого ветерана на тёмном краю площадки.
func begin_aftermath_search() -> void:
	if phase != PHASE_AFTERMATH:
		return
	NightmareRunState.set_flag(FLAG_COUNCIL)
	NightmareRunState.set_flag(FLAG_TASKS)
	_refresh_aftermath()
	if not NightmareRunState.has_flag(FLAG_VETERAN_DEAD):
		hint_requested.emit("Соберите три фляги у тел солдат. На тёмном краю кто-то стонет.")


func _refresh_aftermath() -> void:
	if phase != PHASE_AFTERMATH:
		return
	for i in FLASK_FLAGS.size():
		var id := StringName("flask_%s" % ["a", "b", "c"][i])
		var collected := NightmareRunState.has_flag(FLASK_FLAGS[i])
		flask_props[i].visible = not collected
		set_interactable_enabled(id, not collected)
	var found := NightmareRunState.has_flag(FLAG_VETERAN_FOUND)
	var dead := NightmareRunState.has_flag(FLAG_VETERAN_DEAD)
	var sword_taken := NightmareRunState.has_flag(FLAG_VETERAN_SWORD)
	set_interactable_enabled(&"veteran", not found and not dead)
	set_interactable_enabled(&"veteran_sword", found and not sword_taken and not dead)
	veteran_sword.visible = found and not sword_taken and not dead
	# Ночь начинается не кнопкой у костра, а когда игрок подходит к краю.
	_arm_night_edges(NightmareRunState.has_flag(FLAG_TASKS) and phase == PHASE_AFTERMATH)
	set_interactable_enabled(&"dawn_exit", false)


func collected_flasks() -> int:
	var count := 0
	for flag in FLASK_FLAGS:
		if NightmareRunState.has_flag(flag):
			count += 1
	return count


## Постановка N13 (список v2, D06): ночной монтаж Bloodbane выставляет
## последствия за кадром. Точки E и старой подсказки здесь больше нет.
func stage_bloodbane_montage() -> void:
	NightmareRunState.set_flag(FLAG_BLOODBANE)
	NightmareRunState.set_flag(FLAG_FLASKS_POISONED)
	NightmareRunState.set_flag(FLAG_SUNNY_FLASK_CLEAN)


func can_start_night() -> bool:
	return (
		phase == PHASE_AFTERMATH
		and NightmareRunState.has_flag(FLAG_ATTACK)
		and collected_flasks() >= 3
		and NightmareRunState.has_flag(FLAG_VETERAN_DEAD)
	)


func night_block_reason() -> String:
	if not NightmareRunState.has_flag(FLAG_ATTACK):
		return "Сначала нужно пережить нападение."
	if collected_flasks() < 3:
		return "Сначала соберите три фляги у мёртвых солдат."
	if not NightmareRunState.has_flag(FLAG_VETERAN_DEAD):
		return "Сначала разберитесь с раненым ветераном."
	return ""


func _collect_flask(index: int) -> void:
	if phase != PHASE_AFTERMATH or index < 0 or index >= FLASK_FLAGS.size():
		return
	var flag: StringName = FLASK_FLAGS[index]
	if NightmareRunState.has_flag(flag):
		return
	NightmareRunState.set_flag(flag)
	NightmareRunState.add_item(&"flasks", 1)
	flask_props[index].visible = false
	set_interactable_enabled(StringName("flask_%s" % ["a", "b", "c"][index]), false)
	if not NightmareRunState.has_flag(FLAG_VETERAN_FOUND) and not NightmareRunState.has_flag(FLAG_VETERAN_DEAD):
		set_interactable_enabled(&"veteran", true)
	var count := collected_flasks()
	if count < 3:
		hint_requested.emit("Фляга с водой. Ещё %d." % (3 - count))
	elif not NightmareRunState.has_flag(FLAG_VETERAN_DEAD):
		hint_requested.emit("Три фляги собраны. На тёмном краю всё ещё слышен стон.")
		_set_campaign_objective("Подойти к раненому ветерану на тёмном краю.")
	else:
		hint_requested.emit("Припасы собраны. Пора к краю.")
		_set_campaign_objective("Вернуться к повозке и продолжить путь.")
	_refresh_aftermath()


func _set_campaign_objective(text: String) -> void:
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide != null and guide.has_method(&"set_external_objective"):
		guide.call(&"set_external_objective", text, &"campaign")


func _discover_veteran() -> void:
	if phase != PHASE_AFTERMATH:
		return
	if NightmareRunState.has_flag(FLAG_VETERAN_DEAD) or NightmareRunState.has_flag(FLAG_VETERAN_FOUND):
		return
	NightmareRunState.set_flag(FLAG_VETERAN_FOUND)
	set_interactable_enabled(&"veteran", false)
	NightmareRunState.set_flag(FLAG_VETERAN_SWORD, false)
	veteran_sword.visible = true
	set_interactable_enabled(&"veteran_sword", true)
	veteran_found.emit()
	hint_requested.emit("Ветеран тянется к сломанному мечу. Поднимите меч первым — E.")


func _take_veteran_sword() -> void:
	if phase != PHASE_AFTERMATH:
		return
	if not NightmareRunState.has_flag(FLAG_VETERAN_FOUND) or NightmareRunState.has_flag(FLAG_VETERAN_SWORD):
		return
	if NightmareRunState.has_flag(FLAG_VETERAN_DEAD):
		return
	NightmareRunState.set_flag(FLAG_VETERAN_SWORD)
	NightmareRunState.set_item(&"sword", 1)
	set_interactable_enabled(&"veteran_sword", false)
	veteran_execution_requested.emit()
	hint_requested.emit("Сломанный меч в руке. Ветеран ждёт.")


## Казнь не имеет ветки пощады: это односторонний сюжетный шаг.
func execute_veteran() -> void:
	if NightmareRunState.has_flag(FLAG_VETERAN_DEAD):
		return
	if not NightmareRunState.has_flag(FLAG_VETERAN_FOUND):
		return
	NightmareRunState.set_flag(FLAG_VETERAN_DEAD)
	NightmareRunState.set_flag(FLAG_VETERAN_SWORD)
	NightmareRunState.set_flag(FLAG_SILVER_BELL)
	NightmareRunState.set_flag(&"has_cloak")
	NightmareRunState.set_flag(&"has_boots")
	NightmareRunState.add_item(&"silver_bell", 1)
	NightmareRunState.add_item(&"cloak", 1)
	NightmareRunState.add_item(&"boots", 1)
	veteran.visible = false
	veteran_sword.visible = false
	set_interactable_enabled(&"veteran_sword", false)
	_refresh_aftermath()
	hint_requested.emit("Колокольчик звенит в ладони. Накидка и сапоги ещё хранят тепло.")


func request_night() -> void:
	_request_night()


func _on_night_edge_triggered(id: StringName) -> void:
	if id == &"night_edge":
		_request_night()


func _arm_night_edges(value: bool) -> void:
	for zone in _night_edges:
		zone.enabled = value


func _request_night() -> void:
	if phase != PHASE_AFTERMATH:
		return
	# Причина отказа показывается до события; край снова активен, чтобы игрок
	# мог вернуться после сбора фляг или разговора с ветераном.
	var reason := night_block_reason()
	if not reason.is_empty():
		hint_requested.emit(reason)
		_arm_night_edges(true)
		return
	# N13: монтаж Bloodbane — постановка события, а не E-точка.
	stage_bloodbane_montage()
	NightmareRunState.set_flag(FLAG_NIGHT)
	_set_phase(PHASE_NIGHT)
	_arm_night_edges(false)
	for id in [&"flask_a", &"flask_b", &"flask_c", &"veteran", &"veteran_sword", &"dawn_exit"]:
		set_interactable_enabled(id, false)
	night_requested.emit()



func place_party_at_fire() -> void:
	hero.position = Vector3(1.2, 0.0, 1.5)
	hero.rotation.y = 0.0
	shifty.position = Vector3(1.5, 0.0, -0.1)
	shifty.rotation.y = 0.6
	scholar.position = Vector3(-0.6, 0.0, 1.4)
	scholar.rotation.y = -0.4
	if NightmareRunState.has_flag(FLAG_VETERAN_DEAD):
		veteran.visible = false


func begin_dawn() -> void:
	NightmareRunState.set_flag(FLAG_NIGHT_PASSED)
	_set_phase(PHASE_DAWN)
	if is_instance_valid(dawn_light):
		dawn_light.visible = true
		dawn_light.light_energy = 0.9
		dawn_light.light_color = Color(1.0, 0.78, 0.62, 1.0)
	set_interactable_enabled(&"dawn_exit", true)
	hint_requested.emit("Серый рассвет. Пора подниматься.")


func _request_dawn() -> void:
	if phase != PHASE_DAWN:
		return
	NightmareRunState.set_flag(FLAG_DAWN)
	NightmareRunState.set_flag(&"camp_aftermath_completed")
	_set_phase(PHASE_COMPLETE)
	set_interactable_enabled(&"dawn_exit", false)
	dawn_requested.emit()


func drop_rocks(fast := false) -> void:
	reset_rocks()
	for rock in _rock_targets:
		(rock as Node3D).visible = true
	if fast:
		for rock in _rock_targets:
			(rock as Node3D).position = _rock_targets[rock]
		return
	var tween := create_tween().set_parallel(true)
	var index := 0
	for rock in _rock_targets:
		var target: Vector3 = _rock_targets[rock]
		tween.tween_property(rock, "position", target, 0.75).set_delay(index * 0.06)
		tween.tween_property(rock, "rotation", (rock as Node3D).rotation + Vector3(0.4, 0.8, 0.25), 0.75)
		index += 1
	await tween.finished


func reset_rocks() -> void:
	for rock in _rock_targets:
		var node := rock as Node3D
		node.position = _rock_targets[rock] + Vector3(0.0, 9.0, 0.0)
		node.visible = false
	rockfall.reset()


func begin_rockfall_warning() -> void:
	rockfall.start_warning()


func resolve_rockfall() -> bool:
	return rockfall.resolve_impact()


func get_rockfall_warning_time() -> float:
	return rockfall.warning_time


func show_tyrant() -> void:
	if not is_instance_valid(tyrant):
		return
	tyrant.position = _tyrant_home
	tyrant.visible = true
	tyrant.scale = Vector3(0.35, 0.35, 0.35)


func grow_tyrant(duration := 0.6, fast := false) -> void:
	if not is_instance_valid(tyrant):
		return
	if fast or duration <= 0.0:
		tyrant.scale = Vector3.ONE
		return
	var tween := create_tween()
	tween.tween_property(tyrant, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished


func hide_tyrant() -> void:
	if is_instance_valid(tyrant):
		tyrant.visible = false


func show_broad_death() -> void:
	broad_slave.visible = false
	broad_corpse.visible = true
	NightmareRunState.set_flag(&"broad_slave_dead", true)


func show_larva() -> void:
	broad_corpse.visible = false
	larva.visible = true
	larva.scale = Vector3(0.2, 0.2, 0.2)
	var tween := create_tween()
	tween.tween_property(larva, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func kill_larva() -> void:
	larva.visible = false
	NightmareRunState.set_flag(&"larva_killed", true)
	NightmareRunState.set_flag(&"broad_slave_metamorphosed", true)


func show_four_larvae() -> void:
	# Личинки принадлежат только эпизоду нападения. Запоздалый вызов после
	# перехода к повозке не должен возвращать их в уже завершённую сцену.
	if phase != PHASE_LARVA:
		return
	four_larvae.visible = true
	for child in four_larvae.get_children():
		(child as Node3D).visible = true


## Полностью скрывает группу из четырёх личинок. Используется при завершении
## эпизода нападения и при восстановлении сцены, чтобы ни одна личинка не
## осталась видимой в WAGON, AFTERMATH и NIGHT.
func hide_four_larvae() -> void:
	four_larvae.visible = false
	for index in four_larvae.get_child_count():
		hide_one_larva(index)


## Скрывает одну личинку. Текущая постановка не выделяет смерть одной из
## четырёх личинок в отдельное событие, поэтому частичное скрытие вызывается
## только как часть hide_four_larvae().
func hide_one_larva(index: int) -> void:
	if index < 0 or index >= four_larvae.get_child_count():
		return
	(four_larvae.get_child(index) as Node3D).visible = false


func show_key() -> void:
	key.visible = true
	set_interactable_enabled(&"hero_key", true)
	hint_requested.emit("Ключ упал рядом. Подберите его — E.")


func release_chains() -> void:
	chain.visible = false
	NightmareRunState.set_flag(&"chains_released", true)
	NightmareRunState.remove_item(&"key", 1)
	NightmareRunState.set_flag(&"chain_restrained", false)


func get_fire_position() -> Vector3:
	return $Props/Fire.global_position


func get_chain_anchor_position() -> Vector3:
	return chain_anchor.global_position


func _process(delta: float) -> void:
	_time += delta
	if _tyrant_attention_active and is_instance_valid(tyrant) and tyrant.visible:
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		if player != null and player.global_position.distance_to(tyrant.global_position) <= tyrant_attention_radius:
			_tyrant_attention_active = false
			tyrant_attention_caught.emit()
	if fire_light:
		fire_light.light_energy = 1.55 + sin(_time * 10.0) * 0.12 + sin(_time * 23.0) * 0.05
	if flame_a and flame_b:
		flame_a.scale.y = 0.9 + sin(_time * 9.0) * 0.08
		flame_b.scale.y = 0.75 + sin(_time * 12.0 + 1.3) * 0.06
