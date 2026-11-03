class_name AcademyGameplayDirector
extends Node3D
## Spawns the playable Academy content on top of the standalone art scene:
## NPCs, quest interactables, reach triggers, loot containers and portals.
## Content is data-driven so the art scene stays untouched.

const MANNEQUIN_SCENE := preload("res://scenes/slice/props/mannequin.tscn")
const CASSIA_SCENE := preload("res://scenes/characters/npc/cassia.tscn")
const KASPER_SCENE := preload("res://scenes/characters/npc/kasper.tscn")
const NEPHIS_SCENE := preload("res://scenes/characters/npc/nephis.tscn")
const ROCK_SCENE := preload("res://scenes/characters/npc/rock.tscn")
const GUARD_SCENE := preload("res://scenes/characters/npc/academy_guard.tscn")
const LOCKER_POOL := preload("res://resources/loot/academy/academy_locker_pool.tres")
const SUPPLY_POOL := preload("res://resources/loot/academy/academy_supply_pool.tres")
const MEDICAL_POOL := preload("res://resources/loot/academy/academy_medical_pool.tres")

@export_enum("grounds", "sleeper") var scene_kind := "grounds"

var _built := false
var _hidden_npcs: Array[Dictionary] = []
var _gate_left: Node3D
var _gate_right: Node3D
var _gate_blocker: StaticBody3D
var _gate_open := false


func _ready() -> void:
	call_deferred(&"setup")


func setup() -> void:
	if _built:
		return
	_built = true
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null:
		quests.call(&"activate_scope", &"academy")
		if not quests.quest_completed.is_connected(_on_quest_completed):
			quests.quest_completed.connect(_on_quest_completed)
		if not quests.quest_started.is_connected(_on_quest_started):
			quests.quest_started.connect(_on_quest_started)
		quests.call(&"refresh_auto_start")
	_build_content()
	_update_objective()


func _build_content() -> void:
	if scene_kind == "grounds":
		for data in _grounds_npcs():
			_spawn_npc(data)
		for data in _grounds_interactables():
			_spawn_interactable(data)
		for data in _grounds_triggers():
			_spawn_trigger(data)
		for data in _grounds_loot():
			_spawn_loot(data)
		_build_gate()
		_spawn_visual("Nephis", NEPHIS_SCENE, Vector3(10, 0.2, 8), 0.0)
		_spawn_portal(
			"ToSleeper",
			Vector3(0, 1.5, -48.4),
			Vector3(10, 4, 2.4),
			"res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn",
			&"FromGrounds"
		)
	else:
		for data in _sleeper_npcs():
			_spawn_npc(data)
		for data in _sleeper_interactables():
			_spawn_interactable(data)
		for data in _sleeper_triggers():
			_spawn_trigger(data)
		for data in _sleeper_loot():
			_spawn_loot(data)
		_spawn_portal(
			"ToGrounds",
			Vector3(0, 1.5, 13.2),
			Vector3(8, 4, 2.0),
			"res://scenes/locations/academy_playable/academy_grounds_playable.tscn",
			&"FromSleeper"
		)


# ---------------------------------------------------------------------------
# Red gate: closed until the checkpoint guard lets Sunny through.
# ---------------------------------------------------------------------------

func _build_gate() -> void:
	var art := get_parent().get_node_or_null(^"Art") if get_parent() != null else null
	if art != null:
		var leaves: Array[Node] = []
		for node in art.find_children("*", "MeshInstance3D", true, false):
			if String(node.name).begins_with("GateLeaf"):
				leaves.append(node)
		_gate_left = _make_gate_pivot("GatePivotLeft", Vector3(-9.8, 0.0, 69.0), leaves, true)
		_gate_right = _make_gate_pivot("GatePivotRight", Vector3(9.8, 0.0, 69.0), leaves, false)
	var blocker := StaticBody3D.new()
	blocker.name = "GateBlocker"
	blocker.position = Vector3(0, 6.0, 70.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 12.0, 0.8)
	shape.shape = box
	blocker.add_child(shape)
	add_child(blocker)
	_gate_blocker = blocker
	var state := get_node_or_null(^"/root/NightmareRunState")
	if NightmareRunState.has_flag(&"academy_gate_passed"):
		_open_gate(true)
	elif state != null and not state.flag_changed.is_connected(_on_gate_flag_changed):
		state.flag_changed.connect(_on_gate_flag_changed)


func _make_gate_pivot(pivot_name: String, position: Vector3, leaves: Array[Node], left_side: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = position
	add_child(pivot)
	for node in leaves:
		var mesh := node as Node3D
		if mesh == null:
			continue
		var is_left := mesh.global_position.x < 0.0
		if is_left == left_side:
			mesh.reparent(pivot, true)
	return pivot


func _on_gate_flag_changed(flag_name: StringName, value: bool) -> void:
	if value and flag_name == &"academy_gate_passed":
		_open_gate(false)


func _open_gate(instant: bool) -> void:
	if _gate_open:
		return
	_gate_open = true
	if _gate_blocker != null:
		_gate_blocker.queue_free()
		_gate_blocker = null
	var left_target := deg_to_rad(80.0)
	var right_target := deg_to_rad(-80.0)
	if instant:
		if _gate_left != null:
			_gate_left.rotation.y = left_target
		if _gate_right != null:
			_gate_right.rotation.y = right_target
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _gate_left != null:
		tween.tween_property(_gate_left, "rotation:y", left_target, 1.1)
	if _gate_right != null:
		tween.tween_property(_gate_right, "rotation:y", right_target, 1.1)


# ---------------------------------------------------------------------------
# NPCs
# ---------------------------------------------------------------------------

func _grounds_npcs() -> Array:
	return [
		{
			"id": "gate_guard", "name": "Охрана ворот", "pos": Vector3(5.5, 0.2, 95), "rot": 0.0,
			"scene": GUARD_SCENE, "quest": "ac_mq_01_red_gate", "flag": "academy_gate_passed",
			"lines": [
				["guard", "Стоять. Имя и статус."],
				["sunny", "Санни. Sleeper."],
				["guard", "Кто-то за тебя отвечает?"],
				["sunny", "Нет."],
				["guard", "Проходи. Sleeper Center — прямо, потом налево."],
			],
		},
		{
			"id": "rock_induction", "name": "Рок", "pos": Vector3(0, 0.2, 25), "rot": 0.0,
			"archetype": "mass_male", "pose": "idle", "quest": "ac_mq_03_induction", "flag": "induction_seen",
			"lines": [
				["rock", "Слушайте внимательно. Кошмар — это испытание. Царство Снов — не сюжет."],
				["rock", "Врата — выход. Цитадели — укрытия. Монстры умеют носить человеческие лица."],
				["rock", "Ответственность за ваше выживание — только ваша."],
			],
		},
		{
			"id": "kasper_induction", "name": "Каспер", "pos": Vector3(5, 0.2, 26), "rot": 0.0,
			"scene": KASPER_SCENE, "quest": "ac_mq_03_induction",
			"lines": [
				["kasper", "Каспер. Legacy. Аспект Ascended. Оценка — excellent."],
				["kasper", "Кто из вас уже убивал?"],
				["sunny", "Я. Тирана. Плевком."],
				["kasper", "Оставьте его. Он потерял разум в Кошмаре, а не хвастается."],
			],
		},
		{
			"id": "cassia_induction", "name": "Кассия", "pos": Vector3(-5, 0.2, 27), "rot": 0.0,
			"scene": CASSIA_SCENE, "flag": "cassia_seen",
			"lines": [
				["narration", "В углу сидит слепая девушка. Она поворачивает голову, но не говорит."],
				["sunny", "Ты слышишь меня?"],
				["cassia", "Слышу. Ты стоишь слишком далеко, чтобы я могла тебя разглядеть."],
			],
		},
		{
			"id": "administrator", "name": "Администратор", "pos": Vector3(-30, 0.2, -31), "rot": 90.0,
			"archetype": "mass_female", "pose": "idle", "quest": "ac_mq_05_schedule", "flag": "interview_done",
			"lines": [
				["administrator", "Аспект. Памяти. Кратко."],
				["sunny", "Вспомогательный. Я не воин."],
				["administrator", "Слабый. Записываю. Допуск в библиотеку выдан."],
				["administrator", "Не разочаруй Академию, Sleeper."],
			],
		},
		{
			"id": "julius", "name": "Джулиус", "pos": Vector3(-34, 0.2, -35), "rot": 90.0,
			"archetype": "mass_male", "pose": "idle", "quest": "ac_mq_07_wilderness", "flag": "julius_met",
			"lines": [
				["julius", "Ты пришёл. Остальные не пришли. Садись."],
				["julius", "В Царстве Снов карта врёт, а звёзды — нет. Запомни это."],
				["julius", "Огонь, вода, звёзды. Три вещи, которые возвращают тебя домой."],
			],
		},
		{
			"id": "julius_farewell", "name": "Джулиус", "pos": Vector3(-34, 0.2, -33), "rot": 90.0,
			"archetype": "mass_male", "pose": "idle", "required": ["ac_mq_11_complete"],
			"lines": [
				["julius", "Сегодня солнцестояние. Семнадцать, да?"],
				["sunny", "Видимо, да."],
				["julius", "Возвращайся. Я оставлю тебе должность ассистента."],
			],
		},
		{
			"id": "rock_dojo", "name": "Рок", "pos": Vector3(35, 0.2, 10), "rot": -90.0,
			"archetype": "mass_male", "pose": "idle", "quest": "ac_mq_08_measure",
			"lines": [
				["rock", "Бей по датчику. Не думай. Просто бей."],
				["rock", "Сила — не всё. Выживание — это выбор."],
			],
		},
		{
			"id": "kasper_dining", "name": "Каспер", "pos": Vector3(-34, 0.2, 12), "rot": 90.0,
			"scene": KASPER_SCENE, "required": ["ac_mq_05_complete"], "quest": "ac_mq_06_true_name",
			"flag": "nephis_true_name_seen",
			"lines": [
				["kasper", "Ты видел табло? Changing Star. Клан Immortal Flame."],
				["kasper", "Она последняя. И она это знает."],
				["sunny", "А ты? Ты тоже знаешь, кто я?"],
				["kasper", "Пока нет. Но узнаю."],
			],
		},
		{
			"id": "kasper_locker", "name": "Каспер", "pos": Vector3(34, 0.2, 13), "rot": 0.0,
			"scene": KASPER_SCENE, "required": ["ac_mq_08_complete"],
			"lines": [
				["kasper", "Она почти победила. Без Аспекта."],
				["kasper", "Нефис — из клана Immortal Flame. Родители мертвы. Она последняя."],
				["sunny", "Зачем ты мне это рассказываешь?"],
				["kasper", "Чтобы ты не сделал глупость."],
			],
		},
		{
			"id": "cadet_mira", "name": "Мира", "pos": Vector3(9, 0.2, 30), "rot": 180.0,
			"archetype": "mass_female", "pose": "idle", "quest": "ac_sq_01_lucky_charm",
			"lines": [
				["cadet_mira", "Ты не видел латунный талисман? Он упал в прачечной."],
				["sunny", "Твой?"],
				["cadet_mira", "Брата. Он не вернулся из Царства Снов."],
			],
		},
		{
			"id": "cadet_mira_lost", "name": "Мира", "pos": Vector3(8, 0.2, 28), "rot": 180.0,
			"archetype": "mass_female", "pose": "idle", "required": ["ac_mq_10_complete"],
			"quest": "ac_sq_09_missing_cadet",
			"lines": [
				["cadet_mira", "Рен пропал после отбоя. Его нет в дортуаре."],
				["sunny", "Куда он мог уйти?"],
				["cadet_mira", "В сервисные тоннели. Он говорил, что там есть выход."],
			],
		},
		{
			"id": "cadet_ren", "name": "Рен", "pos": Vector3(32, 0.2, 12), "rot": -90.0,
			"archetype": "mass_male", "pose": "idle", "quest": "ac_sq_02_borrowed_uniform",
			"lines": [
				["cadet_ren", "У меня забрали форму. Сказали, что вернут после посвящения."],
				["sunny", "Кто?"],
				["cadet_ren", "Люди Каспера. Не говори им, что я пожаловался."],
			],
		},
		{
			"id": "cadet_ren_night", "name": "Рен", "pos": Vector3(38, 0.2, 7), "rot": 180.0,
			"archetype": "mass_male", "pose": "guard", "required": ["ac_mq_08_complete"],
			"quest": "ac_sq_05_dojo_ghost",
			"lines": [
				["cadet_ren", "Не говори никому. Я тренируюсь ночью, чтобы не попасть в «обречённые»."],
				["sunny", "Я не скажу."],
				["cadet_ren", "Спасибо. Правда."],
			],
		},
		{
			"id": "sergeant_holt", "name": "Сержант Хольт", "pos": Vector3(-25, 0.2, 20), "rot": 90.0,
			"archetype": "mass_male", "pose": "idle", "quest": "ac_sq_10_maintenance_key",
			"lines": [
				["sergeant_holt", "Ключ от тоннелей потерял. Не докладывать начальству — себе дороже."],
				["sunny", "Где потерял?"],
				["sergeant_holt", "В прачечной. Наверное."],
			],
		},
		{
			"id": "wall_guard", "name": "Стражник", "pos": Vector3(-22, 0.2, 80), "rot": 0.0,
			"scene": GUARD_SCENE, "quest": "ac_sq_12_wall_walk",
			"lines": [
				["wall_guard", "Спорим, не дойдёшь до восточной турели до колокола?"],
				["sunny", "Спорим."],
				["wall_guard", "Тогда иди. И не упади."],
			],
		},
		{
			"id": "kasper_bet", "name": "Каспер", "pos": Vector3(34, 0.2, 6), "rot": -90.0,
			"scene": KASPER_SCENE, "required": ["ac_mq_08_complete"], "quest": "ac_sq_07_kasper_bet",
			"lines": [
				["kasper", "Пари. Три удара против кадета из моей группы."],
				["sunny", "Что на кону?"],
				["kasper", "Тридцать кредитов. Или услуга."],
			],
		},
		{
			"id": "rock_ladder", "name": "Рок", "pos": Vector3(34, 0.2, 8), "rot": -90.0,
			"archetype": "mass_male", "pose": "idle", "required": ["ac_mq_08_complete"],
			"quest": "ac_sq_06_second_from_last",
			"lines": [
				["rock", "Хочешь подняться в списке? Три боя. Без смерти."],
				["sunny", "Я согласен."],
				["rock", "Тогда начнём."],
			],
		},
	]


func _sleeper_npcs() -> Array:
	return [
		{
			"id": "sleeper_receptionist", "name": "Регистратор", "pos": Vector3(-2.2, 0.2, 8.8), "rot": 180.0,
			"archetype": "mass_female", "pose": "idle", "quest": "ac_mq_02_city_within", "flag": "dorm_assigned",
			"lines": [
				["sleeper_receptionist", "Имя, статус, номер койки."],
				["sunny", "Санни. Sleeper."],
				["sleeper_receptionist", "Комната 07. Форма в шкафчике. Расписание на доске."],
			],
		},
		{
			"id": "cassia_tea", "name": "Кассия", "pos": Vector3(-20, 0.2, 3), "rot": 0.0,
			"scene": CASSIA_SCENE, "required": ["ac_mq_05_complete"], "quest": "ac_sq_08_tea_for_cassia",
			"lines": [
				["cassia", "Здесь есть травяной чай? Автомат вечно сломан."],
				["sunny", "Посмотрю на кухне."],
				["cassia", "Спасибо. Я подожду."],
			],
		},
		{
			"id": "cassia_birthday", "name": "Кассия", "pos": Vector3(-20, 0.2, 1), "rot": 0.0,
			"scene": CASSIA_SCENE, "required": ["ac_mq_11_complete"],
			"lines": [
				["cassia", "Happy Birthday."],
				["sunny", "Что?"],
				["cassia", "Сегодня твой день рождения. Тебе семнадцать."],
				["sunny", "Я... перестал считать."],
			],
		},
		{
			"id": "cassia_letter", "name": "Кассия", "pos": Vector3(11, 0.2, -20), "rot": 180.0,
			"scene": CASSIA_SCENE, "required": ["ac_mq_11_complete"],
			"lines": [
				["cassia", "Там, в галерее... письмо. Кто-то держал его до конца."],
				["sunny", "Я посмотрю."],
			],
		},
		{
			"id": "cadet_ren_lost", "name": "Рен", "pos": Vector3(1, 0.2, -17), "rot": 180.0,
			"archetype": "mass_male", "pose": "sit", "required": ["ac_mq_10_complete"],
			"lines": [
				["cadet_ren", "Я хотел уйти. Нашёл тоннель, но дверь заклинило."],
				["sunny", "Идём. Я выведу тебя."],
				["cadet_ren", "Ты не скажешь Року?"],
				["sunny", "Не скажу."],
			],
		},
	]


# ---------------------------------------------------------------------------
# Interactables
# ---------------------------------------------------------------------------

func _grounds_interactables() -> Array:
	return [
		{"id": "campus_terminal", "prompt": "Терминал: найти Sleeper Center", "pos": Vector3(0, 0, 40),
			"visual": "terminal", "label": "ТЕРМИНАЛ", "rot": 0.0, "color": Color(0.25, 0.62, 0.86), "flags": ["campus_direction_known"]},
		{"id": "schedule_board", "prompt": "Прочитать расписание", "pos": Vector3(-37.3, 1.5, -30),
			"visual": "board", "label": "РАСПИСАНИЕ", "rot": 90.0, "size": Vector3(2.4, 1.2, 0.2), "color": Color(0.30, 0.62, 0.82), "flags": ["wilderness_survival_selected", "academy_schedule"]},
		{"id": "ranking_board", "prompt": "Прочитать табло", "pos": Vector3(-37.3, 1.5, 10),
			"visual": "board", "label": "ТАБЛО", "rot": 90.0, "size": Vector3(2.4, 1.2, 0.2), "color": Color(0.30, 0.62, 0.82), "flags": ["nephis_true_name_seen"]},
		{"id": "star_map", "prompt": "Изучить карту звёзд", "pos": Vector3(-37.3, 1.5, -33),
			"visual": "board", "label": "КАРТА ЗВЁЗД", "rot": 90.0, "size": Vector3(2.0, 1.2, 0.1), "color": Color(0.25, 0.55, 0.78), "flags": ["star_navigation"]},
		{"id": "fire_pit", "prompt": "Развести огонь", "pos": Vector3(-34, 0, -33),
			"visual": "fire", "rot": 0.0, "color": Color(0.95, 0.42, 0.12), "flags": ["firemaking"]},
		{"id": "strike_meter", "prompt": "Ударить по датчику", "pos": Vector3(36.2, 0, 10),
			"visual": "sensor", "label": "ДАТЧИК", "rot": -90.0, "color": Color(0.78, 0.18, 0.15), "flags": ["strike_rating"]},
		{"id": "dojo_locker", "prompt": "Обыскать шкафчики", "pos": Vector3(36.2, 0, 13),
			"visual": "locker", "rot": -90.0, "color": Color(0.34, 0.40, 0.46), "flags": ["ac_sq_02_uniform_found"]},
		{"id": "restricted_archive", "prompt": "Открыть архив", "pos": Vector3(-37.2, 0, -36),
			"visual": "locker", "rot": 90.0, "color": Color(0.36, 0.32, 0.24), "start": "ac_sq_03_star_chart", "flags": ["star_chart_found"]},
		{"id": "library_plaque", "prompt": "Изучить плиту", "pos": Vector3(-37.3, 1.3, -39),
			"visual": "board", "label": "ПЛИТА", "rot": 90.0, "size": Vector3(1.2, 1.0, 0.1), "color": Color(0.60, 0.52, 0.40), "start": "ac_sq_04_dead_word", "flags": ["dead_languages"]},
		{"id": "dojo_night_point", "prompt": "Проверить шум", "pos": Vector3(36.0, 0, 6),
			"visual": "marker", "label": "ШУМ", "rot": 0.0, "color": Color(0.40, 0.62, 0.90), "start": "ac_sq_05_dojo_ghost", "flags": ["ac_sq_05_resolved"]},
		{"id": "ladder_point", "prompt": "Начать тренировочную лестницу", "pos": Vector3(36.0, 0, 8),
			"visual": "marker", "label": "ЛЕСТНИЦА", "rot": 0.0, "color": Color(0.90, 0.62, 0.28), "start": "ac_sq_06_second_from_last", "flags": ["academy_rank"]},
		{"id": "kasper_bet_point", "prompt": "Ответить на пари", "pos": Vector3(36.0, 0, 4),
			"visual": "marker", "label": "ПАРИ", "rot": 0.0, "color": Color(0.86, 0.40, 0.28), "start": "ac_sq_07_kasper_bet", "flags": ["kasper_favor"]},
	]


func _sleeper_interactables() -> Array:
	return [
		{"id": "room_bed", "prompt": "Лечь спать", "pos": Vector3(-35, 1.05, -8.2),
			"visual": "item", "label": "СОН", "color": Color(0.35, 0.58, 0.88), "flags": ["ac_first_night", "rest_unlocked"]},
		{"id": "shadow_point_1", "prompt": "Осмотреть коридор", "pos": Vector3(0, 0, -10),
			"visual": "marker", "label": "КОРИДОР", "color": Color(0.24, 0.46, 0.72), "flags": []},
		{"id": "shadow_point_2", "prompt": "Осмотреть фильтры", "pos": Vector3(0.8, 0, -16),
			"visual": "marker", "label": "ФИЛЬТРЫ", "color": Color(0.24, 0.46, 0.72), "flags": []},
		{"id": "shadow_point_3", "prompt": "Осмотреть архив", "pos": Vector3(8, 0, -20),
			"visual": "marker", "label": "АРХИВ", "color": Color(0.24, 0.46, 0.72), "flags": ["shadow_scout"]},
		{"id": "manual_release", "prompt": "Открыть дверь вручную", "pos": Vector3(1.85, 1.3, -16),
			"visual": "panel", "label": "СБРОС", "rot": -90.0, "size": Vector3(0.55, 0.9, 0.12), "color": Color(0.78, 0.18, 0.12), "flags": ["cadet_rescued", "storm_night_survived"]},
		{"id": "coffee_machine", "prompt": "Взять кофе", "pos": Vector3(-22, 0, -5.4),
			"visual": "terminal", "label": "КОФЕ", "rot": 0.0, "color": Color(0.72, 0.46, 0.22), "flags": ["coffee_taken"]},
		{"id": "sleeper_capsule", "prompt": "Лечь в капсулу", "pos": Vector3(0, 1.05, -24.0),
			"visual": "item", "label": "КАПСУЛА", "color": Color(0.34, 0.56, 0.92), "flags": ["capsule_entered"]},
		{"id": "laundry_vent", "prompt": "Обыскать вентиляцию", "pos": Vector3(-25, 1.3, 11.8),
			"visual": "panel", "label": "ВЕНТИЛЯЦИЯ", "rot": 180.0, "size": Vector3(0.8, 0.6, 0.12), "color": Color(0.46, 0.52, 0.58), "flags": ["ac_sq_01_charm_found"]},
		{"id": "laundry_bin", "prompt": "Обыскать корзину с бельём", "pos": Vector3(-24, 0, 7.0),
			"visual": "crate", "color": Color(0.62, 0.52, 0.40), "flags": ["ac_sq_10_key_found"]},
		{"id": "kitchen_tea", "prompt": "Найти травяной чай", "pos": Vector3(-20, 0, -5.4),
			"visual": "terminal", "label": "ЧАЙ", "rot": 0.0, "color": Color(0.74, 0.60, 0.32), "start": "ac_sq_08_tea_for_cassia", "flags": ["tea_found"]},
		{"id": "hollow_letter", "prompt": "Взять письмо", "pos": Vector3(9, 1.2, -20),
			"visual": "item", "label": "ПИСЬМО", "color": Color(0.92, 0.84, 0.60), "start": "ac_sq_11_hollow_letter", "flags": ["ac_sq_11_resolved"]},
	]


# ---------------------------------------------------------------------------
# Reach triggers
# ---------------------------------------------------------------------------

func _grounds_triggers() -> Array:
	return [
		{"id": "academy_campus_entry", "pos": Vector3(0, 2, 58), "size": Vector3(30, 4, 3), "flag": "academy_reached_campus"},
		{"id": "sleeper_center_entry", "pos": Vector3(0, 2, -48), "size": Vector3(10, 4, 3), "flag": "academy_reached_sleeper_entry"},
		{"id": "dojo_ring", "pos": Vector3(32, 2, 10), "size": Vector3(12, 4, 10), "flag": "academy_reached_dojo"},
		{"id": "east_turret", "pos": Vector3(22, 2, 72), "size": Vector3(8, 4, 8), "flag": "academy_reached_east_turret"},
	]


func _sleeper_triggers() -> Array:
	return [
		{"id": "dormitory", "pos": Vector3(0, 2, 7), "size": Vector3(26, 4, 4), "flag": "academy_reached_dormitory"},
		{"id": "sleeper_center_alarm", "pos": Vector3(0, 2, 0), "size": Vector3(26, 4, 14), "flag": "academy_reached_alarm"},
		{"id": "hollow_gallery", "pos": Vector3(8, 2, -20), "size": Vector3(12, 4, 8), "flag": "academy_reached_hollow"},
		{"id": "old_filtration", "pos": Vector3(0, 2, -16), "size": Vector3(4, 4, 6), "flag": "academy_reached_filtration"},
	]


# ---------------------------------------------------------------------------
# Loot
# ---------------------------------------------------------------------------

func _grounds_loot() -> Array:
	return [
		{"id": "academy_gate_locker", "pos": Vector3(-3.5, 0.35, 96), "pool": LOCKER_POOL, "prompt": "Обыскать шкафчик"},
		{"id": "academy_supply_crate", "pos": Vector3(-10, 0.35, 40), "pool": SUPPLY_POOL, "prompt": "Открыть ящик"},
		{"id": "academy_dojo_crate", "pos": Vector3(35.8, 0.35, 8), "pool": SUPPLY_POOL, "prompt": "Открыть ящик"},
		{"id": "academy_academic_cabinet", "pos": Vector3(-36.6, 0.35, -30), "pool": SUPPLY_POOL, "prompt": "Открыть шкаф"},
		{"id": "academy_medical_cabinet", "pos": Vector3(39.4, 0.35, -35), "pool": MEDICAL_POOL, "prompt": "Открыть медицинский шкаф"},
	]


func _sleeper_loot() -> Array:
	return [
		{"id": "academy_dorm_locker", "pos": Vector3(-8, 0.35, 5.0), "pool": LOCKER_POOL, "prompt": "Обыскать шкафчик"},
		{"id": "academy_common_locker", "pos": Vector3(-23, 0.35, 4), "pool": LOCKER_POOL, "prompt": "Обыскать шкафчик"},
		{"id": "academy_shower_locker", "pos": Vector3(16.6, 0.35, 5.4), "pool": LOCKER_POOL, "prompt": "Обыскать шкафчик"},
		{"id": "academy_observation_cabinet", "pos": Vector3(5, 0.35, -12), "pool": SUPPLY_POOL, "prompt": "Открыть шкаф"},
		{"id": "academy_medical_cabinet_i", "pos": Vector3(1.5, 0.35, -14), "pool": MEDICAL_POOL, "prompt": "Открыть медицинский шкаф"},
		{"id": "academy_dream_supply", "pos": Vector3(4.5, 0.35, -20), "pool": MEDICAL_POOL, "prompt": "Открыть ящик"},
	]


# ---------------------------------------------------------------------------
# Spawn helpers
# ---------------------------------------------------------------------------

func _spawn_npc(data: Dictionary) -> void:
	var npc := QuestNpc.new()
	npc.name = String(data.get("name_id", data.get("id", "NPC")))
	npc.npc_id = StringName(data.get("id", ""))
	npc.display_name = String(data.get("name", ""))
	npc.prompt = "Поговорить"
	npc.interaction_radius = float(data.get("radius", 2.4))
	npc.dialogue = _seq(data.get("lines", []))
	npc.start_quest_id = StringName(data.get("quest", ""))
	npc.completion_flag = StringName(data.get("flag", ""))
	npc.one_shot = bool(data.get("one_shot", true))
	var required: Array[StringName] = []
	for flag in data.get("required", []):
		required.append(StringName(flag))
	npc.required_flags = required
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.interaction_id = npc.npc_id
	interactable.prompt = npc.prompt
	interactable.radius = npc.interaction_radius
	interactable.interact_cue = &"ui_confirm"
	interactable.interact_volume_db = -8.0
	interactable.enabled = true
	npc.add_child(interactable)
	_add_npc_visual(npc, data)
	npc.talked.connect(_on_npc_talked)
	add_child(npc)
	npc.position = data.get("pos", Vector3.ZERO)
	npc.rotation_degrees.y = float(data.get("rot", 0.0))
	var available := NightmareRunState.require(required)
	npc.visible = available
	if not available:
		_hidden_npcs.append({"npc": npc, "required": required})
		var state := get_node_or_null(^"/root/NightmareRunState")
		if state != null and not state.flag_changed.is_connected(_on_any_flag_changed):
			state.flag_changed.connect(_on_any_flag_changed)


func _on_any_flag_changed(_flag: StringName, _value: bool) -> void:
	var still_hidden: Array[Dictionary] = []
	for entry in _hidden_npcs:
		var npc := entry.get("npc") as QuestNpc
		var required: Array[StringName] = entry.get("required", [])
		if not is_instance_valid(npc):
			continue
		if NightmareRunState.require(required):
			npc.visible = true
		else:
			still_hidden.append(entry)
	_hidden_npcs = still_hidden


func _add_npc_visual(npc: QuestNpc, data: Dictionary) -> void:
	var visual: Node3D
	if data.has("scene"):
		visual = (data["scene"] as PackedScene).instantiate() as Node3D
	else:
		var mannequin := MANNEQUIN_SCENE.instantiate() as Mannequin
		mannequin.archetype = String(data.get("archetype", "mass_male"))
		mannequin.pose = String(data.get("pose", "idle"))
		visual = mannequin
	if visual == null:
		return
	visual.name = "Model"
	npc.add_child(visual)


func _spawn_visual(node_name: String, packed: PackedScene, position: Vector3, rotation_y: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	var visual := packed.instantiate() as Node3D
	if visual != null:
		root.add_child(visual)
	add_child(root)
	root.position = position
	root.rotation_degrees.y = rotation_y


func _spawn_interactable(data: Dictionary) -> void:
	var obj := Interactable.new()
	obj.name = String(data.get("id", "Interactable"))
	obj.interaction_id = StringName(data.get("id", ""))
	obj.prompt = String(data.get("prompt", "Взаимодействовать"))
	obj.radius = float(data.get("radius", 2.2))
	obj.interact_cue = &"ui_confirm"
	obj.interact_volume_db = -8.0
	obj.enabled = true
	obj.position = data.get("pos", Vector3.ZERO)
	obj.rotation_degrees.y = float(data.get("rot", 0.0))
	_build_interactable_visual(obj, data)
	obj.interacted.connect(_on_interactable.bind(data))
	add_child(obj)


## Builds a readable prop instead of a bare colored box. The interaction
## volume is still the Interactable node; visuals are swappable children.
func _build_interactable_visual(obj: Node3D, data: Dictionary) -> void:
	match String(data.get("visual", "terminal")):
		"board":
			_build_board(obj, data)
		"locker":
			_build_locker(obj, data)
		"crate":
			_build_crate(obj, data)
		"fire":
			_build_fire(obj, data)
		"sensor":
			_build_sensor(obj, data)
		"marker":
			_build_marker(obj, data)
		"panel":
			_build_panel(obj, data)
		"item":
			_build_item(obj, data)
		_:
			_build_terminal(obj, data)


func _build_board(obj: Node3D, data: Dictionary) -> void:
	var size: Vector3 = data.get("size", Vector3(2.2, 1.2, 0.14))
	size.z = maxf(size.z, 0.12)
	var accent: Color = data.get("color", Color(0.30, 0.62, 0.82))
	_visual_mesh(obj, _box_mesh(size), _metal(Color(0.07, 0.08, 0.10), 0.65, 0.34))
	var screen_size := Vector3(size.x * 0.90, size.y * 0.80, 0.02)
	_visual_mesh(obj, _box_mesh(screen_size), _glow(Color(0.01, 0.03, 0.06), accent, 1.25), Vector3(0, 0, size.z * 0.5 + 0.012))
	for side in [-1.0, 1.0]:
		_visual_mesh(obj, _box_mesh(Vector3(0.035, size.y * 0.68, 0.025)), _glow(accent * 0.6, accent, 2.2), Vector3(side * size.x * 0.455, 0, size.z * 0.5 + 0.024))
	_label3d(obj, String(data.get("label", "")), Vector3(0, 0, size.z * 0.5 + 0.032), 44, 0.0036, false)


func _build_terminal(obj: Node3D, data: Dictionary) -> void:
	var accent: Color = data.get("color", Color(0.25, 0.62, 0.86))
	var metal := _metal(Color(0.10, 0.11, 0.13), 0.60, 0.35)
	_visual_mesh(obj, _box_mesh(Vector3(0.82, 0.06, 0.62)), metal, Vector3(0, 0.03, 0))
	_visual_mesh(obj, _box_mesh(Vector3(0.22, 0.92, 0.20)), metal, Vector3(0, 0.50, 0))
	_visual_mesh(obj, _box_mesh(Vector3(0.68, 0.44, 0.10)), metal, Vector3(0, 1.08, 0.02), Vector3(-12, 0, 0))
	_visual_mesh(obj, _box_mesh(Vector3(0.56, 0.32, 0.02)), _glow(Color(0.01, 0.03, 0.05), accent, 1.6), Vector3(0, 1.09, 0.08), Vector3(-12, 0, 0))
	for side in [-1.0, 1.0]:
		_visual_mesh(obj, _box_mesh(Vector3(0.035, 0.18, 0.03)), _glow(accent * 0.6, accent, 1.8), Vector3(side * 0.30, 1.09, 0.08), Vector3(-12, 0, 0))
	_label3d(obj, String(data.get("label", "")), Vector3(0, 1.55, 0), 38, 0.0032, true)


func _build_locker(obj: Node3D, data: Dictionary) -> void:
	var accent: Color = data.get("color", Color(0.34, 0.40, 0.46))
	var height := 1.90
	_visual_mesh(obj, _box_mesh(Vector3(0.90, height, 0.55)), _metal(Color(0.14, 0.16, 0.19), 0.70, 0.38), Vector3(0, height * 0.5, 0))
	_visual_mesh(obj, _box_mesh(Vector3(0.78, height * 0.88, 0.03)), _metal(Color(0.22, 0.24, 0.28), 0.60, 0.46), Vector3(0, height * 0.5, 0.29))
	_visual_mesh(obj, _box_mesh(Vector3(0.30, 0.04, 0.03)), _glow(accent * 0.5, accent, 1.4), Vector3(0, height * 0.78, 0.31))
	for i in 3:
		_visual_mesh(obj, _box_mesh(Vector3(0.34, 0.02, 0.02)), _metal(Color(0.03, 0.03, 0.04), 0.2, 0.8), Vector3(0, height * 0.64 - i * 0.055, 0.31))
	_label3d(obj, String(data.get("label", "")), Vector3(0, height + 0.18, 0), 34, 0.0030, true)


func _build_crate(obj: Node3D, data: Dictionary) -> void:
	var accent: Color = data.get("color", Color(0.80, 0.62, 0.32))
	_visual_mesh(obj, _box_mesh(Vector3(0.90, 0.62, 0.66)), _metal(Color(0.24, 0.21, 0.16), 0.20, 0.64), Vector3(0, 0.31, 0))
	for side in [-1.0, 1.0]:
		_visual_mesh(obj, _box_mesh(Vector3(0.06, 0.66, 0.70)), _metal(Color(0.12, 0.12, 0.13), 0.65, 0.40), Vector3(side * 0.34, 0.32, 0))
	_visual_mesh(obj, _box_mesh(Vector3(0.52, 0.02, 0.38)), _glow(accent * 0.4, accent, 0.7), Vector3(0, 0.64, 0))


func _build_fire(obj: Node3D, data: Dictionary) -> void:
	var accent: Color = data.get("color", Color(0.95, 0.42, 0.12))
	var stone := _metal(Color(0.17, 0.16, 0.15), 0.05, 0.92)
	for i in 10:
		var angle := TAU * float(i) / 10.0
		_visual_mesh(obj, _box_mesh(Vector3(0.26, 0.20, 0.22)), stone, Vector3(cos(angle) * 0.72, 0.10, sin(angle) * 0.72), Vector3(0, rad_to_deg(angle), 0))
	_visual_mesh(obj, _cylinder_mesh(0.38, 0.10, 16), _glow(Color(0.35, 0.08, 0.01), accent, 2.6), Vector3(0, 0.12, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.14)
	light.light_energy = 1.1
	light.omni_range = 4.5
	light.position = Vector3(0, 0.7, 0)
	obj.add_child(light)


func _build_sensor(obj: Node3D, data: Dictionary) -> void:
	var accent: Color = data.get("color", Color(0.78, 0.18, 0.15))
	var metal := _metal(Color(0.10, 0.11, 0.13), 0.60, 0.35)
	_visual_mesh(obj, _box_mesh(Vector3(0.72, 0.06, 0.56)), metal, Vector3(0, 0.03, 0))
	_visual_mesh(obj, _box_mesh(Vector3(0.24, 1.45, 0.24)), metal, Vector3(0, 0.75, 0))
	_visual_mesh(obj, _box_mesh(Vector3(0.66, 0.62, 0.28)), _glow(accent * 0.35, accent, 1.3), Vector3(0, 1.18, 0.06))
	_visual_mesh(obj, _box_mesh(Vector3(0.46, 0.06, 0.02)), _glow(accent * 0.6, accent, 2.0), Vector3(0, 1.36, 0.21))
	_label3d(obj, String(data.get("label", "")), Vector3(0, 1.78, 0), 38, 0.0032, true)


func _build_marker(obj: Node3D, data: Dictionary) -> void:
	var accent: Color = data.get("color", Color(0.24, 0.46, 0.72))
	_visual_mesh(obj, _cylinder_mesh(0.38, 0.06, 18), _metal(Color(0.08, 0.09, 0.11), 0.55, 0.42), Vector3(0, 0.03, 0))
	_visual_mesh(obj, _cylinder_mesh(0.018, 1.00, 6), _glow(accent * 0.5, accent, 1.2), Vector3(0, 0.55, 0))
	_visual_mesh(obj, _box_mesh(Vector3(0.18, 0.18, 0.18)), _glow(accent * 0.6, accent, 2.2), Vector3(0, 1.15, 0), Vector3(45, 0, 45))
	_label3d(obj, String(data.get("label", "")), Vector3(0, 1.58, 0), 36, 0.0030, true)


func _build_panel(obj: Node3D, data: Dictionary) -> void:
	var size: Vector3 = data.get("size", Vector3(0.55, 0.90, 0.12))
	var accent: Color = data.get("color", Color(0.78, 0.18, 0.12))
	_visual_mesh(obj, _box_mesh(size), _metal(Color(0.08, 0.09, 0.11), 0.65, 0.36))
	_visual_mesh(obj, _box_mesh(Vector3(size.x * 0.72, size.y * 0.62, 0.02)), _glow(Color(0.02, 0.02, 0.03), accent, 1.4), Vector3(0, 0, size.z * 0.5 + 0.011))
	_visual_mesh(obj, _box_mesh(Vector3(size.x * 0.30, 0.04, 0.02)), _glow(accent * 0.6, accent, 2.0), Vector3(0, -size.y * 0.33, size.z * 0.5 + 0.024))
	_label3d(obj, String(data.get("label", "")), Vector3(0, size.y * 0.62, size.z * 0.5 + 0.03), 32, 0.0028, true)


func _build_item(obj: Node3D, data: Dictionary) -> void:
	var accent: Color = data.get("color", Color(0.85, 0.78, 0.55))
	_visual_mesh(obj, _box_mesh(Vector3(0.34, 0.22, 0.05)), _glow(Color(0.10, 0.09, 0.05), accent, 1.6))
	_visual_mesh(obj, _box_mesh(Vector3(0.42, 0.02, 0.08)), _glow(accent * 0.4, accent, 1.2), Vector3(0, -0.13, 0))
	_label3d(obj, String(data.get("label", "")), Vector3(0, 0.38, 0), 34, 0.0030, true)


func _visual_mesh(parent: Node3D, mesh: Mesh, material: Material, offset := Vector3.ZERO, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	instance.rotation_degrees = rotation
	parent.add_child(instance)
	return instance


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder_mesh(radius: float, height: float, segments := 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


func _metal(color: Color, metallic := 0.60, roughness := 0.36) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _glow(color: Color, emission: Color, energy := 2.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.roughness = 0.30
	return material


func _label3d(parent: Node3D, text: String, offset: Vector3, font_size: int, pixel_size: float, billboard := true) -> void:
	if text.strip_edges().is_empty():
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.outline_size = 5
	label.modulate = Color(0.88, 0.95, 1.0, 1.0)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.position = offset
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	parent.add_child(label)


func _spawn_trigger(data: Dictionary) -> void:
	var zone := QuestTriggerZone.new()
	zone.name = String("Trigger_%s" % String(data.get("id", "zone")))
	zone.trigger_id = StringName(data.get("id", ""))
	zone.enabled = true
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.set_flag = StringName(data.get("flag", ""))
	zone.quest_event = StringName(data.get("event", "reached"))
	zone.quest_subject = StringName(data.get("subject", data.get("id", "")))
	var required: Array[StringName] = []
	for flag in data.get("required", []):
		required.append(StringName(flag))
	zone.required_flags = required
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data.get("size", Vector3(4, 3, 4))
	shape.shape = box
	zone.add_child(shape)
	add_child(zone)
	zone.position = data.get("pos", Vector3.ZERO)


func _spawn_loot(data: Dictionary) -> void:
	var cache := LootCache.new()
	cache.name = String("Loot_%s" % String(data.get("id", "cache")))
	cache.container_id = StringName(data.get("id", ""))
	cache.interaction_id = StringName(data.get("id", ""))
	cache.prompt = String(data.get("prompt", "Открыть"))
	cache.radius = float(data.get("radius", 2.2))
	cache.loot_pool = data.get("pool", LOCKER_POOL) as LootPool
	cache.opened_flag = StringName("loot_%s_opened" % String(data.get("id", "")))
	cache.enabled = true
	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.7, 0.6)
	mesh.mesh = box
	mesh.material_override = _flat(Color(0.24, 0.26, 0.28))
	visual_root.add_child(mesh)
	var lid := MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(0.94, 0.08, 0.64)
	lid.mesh = lid_box
	lid.material_override = _flat(Color(0.36, 0.38, 0.42))
	lid.position = Vector3(0, 0.38, 0)
	visual_root.add_child(lid)
	cache.add_child(visual_root)
	cache.visual_root = visual_root
	cache.lid = lid
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.72, 0.4)
	glow.light_energy = 0.7
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.9, 0)
	cache.add_child(glow)
	cache.glow = glow
	add_child(cache)
	cache.position = data.get("pos", Vector3.ZERO)


func _spawn_portal(portal_name: String, position: Vector3, size: Vector3, destination: String, spawn: StringName) -> void:
	var portal := LevelPortal.new()
	portal.name = portal_name
	portal.destination_scene = destination
	portal.destination_spawn = spawn
	portal.fade_out_duration = 0.28
	portal.fade_in_duration = 0.32
	portal.trigger_on_body = true
	portal.body_trigger_ignore_frames = 24
	portal.lock_player = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	portal.add_child(shape)
	add_child(portal)
	portal.position = position


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	return material


func _seq(lines: Array) -> DialogueSequence:
	var sequence := DialogueSequence.new()
	for row in lines:
		if row.size() < 2:
			continue
		var line := DialogueLine.new()
		line.speaker = StringName(row[0])
		line.text = String(row[1])
		line.duration = 0.0
		sequence.lines.append(line)
	return sequence


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_npc_talked(npc_id: StringName) -> void:
	match npc_id:
		&"gate_guard": NightmareRunState.set_flag(&"academy_gate_passed")
		&"sleeper_receptionist": NightmareRunState.set_flag(&"dorm_assigned")
		&"rock_induction": NightmareRunState.set_flag(&"induction_seen")
		&"cassia_induction": NightmareRunState.set_flag(&"cassia_seen")
		&"administrator": NightmareRunState.set_flag(&"interview_done")
		&"kasper_dining": NightmareRunState.set_flag(&"nephis_true_name_seen")
		&"julius": NightmareRunState.set_flag(&"julius_met")
		&"kasper_locker": NightmareRunState.set_flag(&"immortal_flame_known")
		&"cassia_birthday": NightmareRunState.set_flag(&"birthday_17")
		&"julius_farewell": NightmareRunState.set_flag(&"julius_farewell")
		&"cassia_tea":
			NightmareRunState.set_flag(&"cassia_tea_shared")
			var tea_npc := get_node_or_null(^"cassia_tea") as Node3D
			if tea_npc != null:
				tea_npc.visible = false
		&"cassia_letter": NightmareRunState.set_flag(&"hollow_letter_resolved")


func _on_interactable(interaction_id: StringName, data: Dictionary) -> void:
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests == null:
		return
	var start := StringName(data.get("start", ""))
	if start != &"":
		quests.call(&"start_quest", start)
	for flag in data.get("flags", []):
		NightmareRunState.set_flag(StringName(flag))
	quests.call(&"notify_event", &"interacted", interaction_id, 1)
	var text := String(data.get("message", ""))
	if not text.is_empty():
		quests.call(&"show_message", text, &"info")


func _on_quest_started(_quest: QuestDefinition) -> void:
	_update_objective.call_deferred()


func _on_quest_completed(quest: QuestDefinition) -> void:
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null:
		quests.call(&"refresh_auto_start")
	_update_objective.call_deferred()
	if quest.id == &"ac_mq_12_last_day" or quest.id == &"academy_complete":
		var guide := get_node_or_null(^"/root/CampaignGuide")
		if guide != null and guide.has_method(&"set_external_objective"):
			guide.call(&"set_external_objective", "Академия пройдена. Капсула ждёт.", &"academy")


func _update_objective() -> void:
	var quests := get_node_or_null(^"/root/QuestSystem")
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide == null:
		return
	var text := "Осмотреть Академию."
	if quests != null:
		var tracked := String(quests.call(&"get_tracked_objective_text"))
		if not tracked.strip_edges().is_empty():
			text = tracked
	if guide.has_method(&"set_external_objective"):
		guide.call(&"set_external_objective", text, &"academy")

