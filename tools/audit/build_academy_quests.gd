extends SceneTree
## Generates the Academy quest catalog and academy loot pools.
## Run:
##   godot --headless --path . -s tools/audit/build_academy_quests.gd
##
## This is a content build tool, not gameplay code. It writes .tres resources
## into resources/quests/academy/ and resources/loot/academy/.

const QUEST_DIR := "res://resources/quests/academy"
const LOOT_DIR := "res://resources/loot/academy"
const CATALOG_PATH := "res://resources/quests/academy/quest_catalog_academy.tres"


func _initialize() -> void:
	_build()
	quit(0)


func _build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QUEST_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOOT_DIR))
	_build_loot_pools()
	var quests: Array = []
	for data in _quest_data():
		var quest := _make_quest(data)
		var path := "%s/%s.tres" % [QUEST_DIR, String(quest.id)]
		var error := ResourceSaver.save(quest, path)
		if error != OK:
			push_error("Academy quests: cannot save %s (%d)" % [path, error])
			continue
		quests.append(quest)
	var catalog := QuestCatalog.new()
	catalog.scope = &"academy"
	catalog.quests = quests
	var error := ResourceSaver.save(catalog, CATALOG_PATH)
	print("ACADEMY_QUESTS built=", quests.size(), " catalog_error=", error, " path=", CATALOG_PATH)


func _make_quest(data: Dictionary) -> QuestDefinition:
	var quest := QuestDefinition.new()
	quest.id = StringName(data.id)
	quest.scope = &"academy"
	quest.code = String(data.get("code", ""))
	quest.title = String(data.title)
	quest.category = QuestDefinition.Category.MAIN if bool(data.get("main", false)) else QuestDefinition.Category.SIDE
	quest.summary = String(data.get("summary", ""))
	quest.description = String(data.get("description", ""))
	var prereq: Array[StringName] = []
	for flag in data.get("prereq", []):
		prereq.append(StringName(flag))
	quest.prerequisites = prereq
	quest.auto_start = bool(data.get("auto", false))
	quest.show_available = bool(data.get("show", false))
	var objectives: Array = []
	for row in data.get("objectives", []):
		var objective := QuestObjective.new()
		objective.id = StringName(row[0])
		objective.kind = _kind(String(row[1]))
		objective.target_id = StringName(row[2])
		objective.text = String(row[3])
		objective.required_count = int(row[4]) if row.size() > 4 else 1
		objective.optional = bool(row[5]) if row.size() > 5 else false
		objectives.append(objective)
	quest.objectives = objectives
	var rewards: Array = []
	for reward_data in data.get("rewards", []):
		var reward := QuestReward.new()
		reward.item_id = StringName(reward_data.get("item", ""))
		reward.item_count = int(reward_data.get("count", 1))
		reward.currency_id = StringName(reward_data.get("currency", ""))
		reward.currency_amount = int(reward_data.get("amount", 0))
		reward.flag = StringName(reward_data.get("flag", ""))
		reward.heal_amount = float(reward_data.get("heal", 0.0))
		reward.text = String(reward_data.get("text", ""))
		rewards.append(reward)
	quest.rewards = rewards
	quest.completion_flag = StringName(data.get("completion", "ac_%s_complete" % String(data.id)))
	return quest


func _kind(name: String) -> QuestObjective.Kind:
	match name:
		"KILL": return QuestObjective.Kind.KILL
		"COLLECT": return QuestObjective.Kind.COLLECT
		"INTERACT": return QuestObjective.Kind.INTERACT
		"REACH": return QuestObjective.Kind.REACH
		"TALK": return QuestObjective.Kind.TALK
		"CURRENCY": return QuestObjective.Kind.CURRENCY
		_: return QuestObjective.Kind.FLAG


func _build_loot_pools() -> void:
	var provisions := load("res://resources/loot/items/provisions.tres") as LootItemData
	var medkit := load("res://resources/loot/items/field_medkit.tres") as LootItemData
	var rope := load("res://resources/loot/items/rope.tres") as LootItemData
	var torch := load("res://resources/loot/items/torch.tres") as LootItemData
	var water := load("res://resources/loot/items/water_skin.tres") as LootItemData
	var oil := load("res://resources/loot/items/oil_flask.tres") as LootItemData
	var locker := _pool(&"academy_locker", "Шкафчик Академии", provisions, [
		_entry(medkit, 1, 1, 2.0), _entry(rope, 1, 1, 1.4), _entry(torch, 1, 2, 1.2), _entry(oil, 1, 1, 0.7),
	])
	var supply := _pool(&"academy_supply", "Поставка Академии", rope, [
		_entry(provisions, 1, 2, 2.2), _entry(torch, 1, 2, 1.4), _entry(water, 1, 1, 1.2), _entry(oil, 1, 1, 0.8),
	])
	var medical := _pool(&"academy_medical", "Медицинский шкаф", medkit, [
		_entry(water, 1, 1, 1.4), _entry(provisions, 1, 1, 0.8),
	])
	for pair in [[locker, "academy_locker_pool"], [supply, "academy_supply_pool"], [medical, "academy_medical_pool"]]:
		var pool: LootPool = pair[0]
		var path := "%s/%s.tres" % [LOOT_DIR, pair[1]]
		var error := ResourceSaver.save(pool, path)
		print("ACADEMY_LOOT ", path, " error=", error)


func _pool(id: StringName, display: String, guaranteed_item: LootItemData, entries: Array) -> LootPool:
	var pool := LootPool.new()
	pool.id = id
	pool.display_name = display
	pool.description = "Академический контейнер: бытовые припасы, инструменты, медикаменты."
	pool.source_kind = "container"
	pool.canon_status = &"GD"
	pool.guaranteed = [_entry(guaranteed_item, 1, 1, 1.0)]
	pool.entries = []
	for entry in entries:
		pool.entries.append(entry)
	pool.bonus_rolls = 1
	pool.empty_chance = 0.0
	pool.respawns = false
	pool.tags = PackedStringArray(["academy", "container"])
	return pool


func _entry(item: LootItemData, min_count: int, max_count: int, weight: float) -> LootPoolEntry:
	var entry := LootPoolEntry.new()
	entry.item = item
	entry.min_count = min_count
	entry.max_count = max_count
	entry.weight = weight
	return entry


func _quest_data() -> Array:
	return [
		# ------------------------------------------------------------------
		# MAIN 01-04
		# ------------------------------------------------------------------
		{
			"id": "ac_mq_01_red_gate", "code": "AC-MQ-01", "title": "Красные ворота",
			"main": true, "auto": true,
			"summary": "Пройти проверку на КПП и войти в Академию.",
			"description": "Санни приходит к Академии Пробуждённых. Охрана проверяет имя и статус; за воротами начинается кампус.",
			"objectives": [
				["talk_guard", "TALK", "gate_guard", "Пройти проверку на КПП"],
				["enter_campus", "FLAG", "academy_reached_campus", "Войти в кампус"],
			],
			"rewards": [
				{"currency": "credits", "amount": 10, "text": "10 кредитов"},
				{"flag": "academy_pass", "text": "Пропуск на территорию"},
			],
			"completion": "ac_mq_01_complete",
		},
		{
			"id": "ac_mq_02_city_within", "code": "AC-MQ-02", "title": "Город в городе",
			"main": true, "auto": true, "prereq": ["ac_mq_01_complete"],
			"summary": "Найти Sleeper Center и зарегистрироваться.",
			"description": "Кампус оказывается городом в городе. Терминал выдаёт направление, стойка регистрации — комнату и форму.",
			"objectives": [
				["terminal", "INTERACT", "campus_terminal", "Получить направление у терминала"],
				["reach_sleeper", "FLAG", "academy_reached_sleeper_entry", "Дойти до Sleeper Center"],
				["register", "TALK", "sleeper_receptionist", "Зарегистрироваться"],
			],
			"rewards": [
				{"flag": "room_key", "text": "Ключ от комнаты 07"},
				{"currency": "credits", "amount": 15, "text": "15 кредитов"},
			],
			"completion": "ac_mq_02_complete",
		},
		{
			"id": "ac_mq_03_induction", "code": "AC-MQ-03", "title": "Индукция",
			"main": true, "auto": true, "prereq": ["ac_mq_02_complete"],
			"summary": "Пройти индукцию и не выдать себя.",
			"description": "Рок объясняет правила Царства Снов. Каспер спрашивает, кто уже убивал. Кассия сидит в углу.",
			"objectives": [
				["listen_rock", "TALK", "rock_induction", "Выслушать Рока"],
				["answer_kasper", "TALK", "kasper_induction", "Ответить Касперу"],
				["see_cassia", "FLAG", "cassia_seen", "Заметить Кассию"],
			],
			"rewards": [
				{"flag": "academy_schedule", "text": "Расписание занятий"},
				{"currency": "credits", "amount": 20, "text": "20 кредитов"},
			],
			"completion": "ac_mq_03_complete",
		},
		{
			"id": "ac_mq_04_first_night", "code": "AC-MQ-04", "title": "Первая ночь",
			"main": true, "auto": true, "prereq": ["ac_mq_03_complete"],
			"summary": "Найти комнату 07 и лечь спать.",
			"description": "В дортуаре двенадцать капсул. В комнате 07 — койка, стол, зеркало и экран-окно. Ночью тень поднимает руку.",
			"objectives": [
				["enter_dorm", "FLAG", "academy_reached_dormitory", "Войти в дортуар"],
				["sleep", "INTERACT", "room_bed", "Лечь спать"],
			],
			"rewards": [
				{"flag": "rest_unlocked", "text": "Отдых в комнате 07"},
				{"currency": "credits", "amount": 5, "text": "5 кредитов"},
			],
			"completion": "ac_mq_04_complete",
		},
		# ------------------------------------------------------------------
		# MAIN 05-08
		# ------------------------------------------------------------------
		{
			"id": "ac_mq_05_schedule", "code": "AC-MQ-05", "title": "Расписание и интервью",
			"main": true, "auto": true, "prereq": ["ac_mq_04_complete"],
			"summary": "Выбрать курс и пройти интервью.",
			"description": "На доске — Wilderness Survival, боевая подготовка и мёртвые языки. Администратор задаёт вопросы об Аспекте.",
			"objectives": [
				["read_schedule", "INTERACT", "schedule_board", "Прочитать расписание"],
				["interview", "TALK", "administrator", "Пройти интервью"],
			],
			"rewards": [
				{"flag": "library_pass", "text": "Допуск в библиотеку"},
				{"currency": "credits", "amount": 25, "text": "25 кредитов"},
			],
			"completion": "ac_mq_05_complete",
		},
		{
			"id": "ac_mq_06_true_name", "code": "AC-MQ-06", "title": "Имя на табло",
			"main": true, "auto": true, "prereq": ["ac_mq_05_complete"],
			"summary": "Понять, кто такая Нефис.",
			"description": "На табло появляется True Name Нефис — Changing Star. Каспер кланяется. Кассия сидит одна.",
			"objectives": [
				["read_board", "INTERACT", "ranking_board", "Прочитать табло"],
				["talk_kasper", "TALK", "kasper_dining", "Поговорить с Каспером"],
			],
			"rewards": [
				{"flag": "nephis_true_name_seen", "text": "True Name Нефис"},
				{"currency": "credits", "amount": 10, "text": "10 кредитов"},
			],
			"completion": "ac_mq_06_complete",
		},
		{
			"id": "ac_mq_07_wilderness", "code": "AC-MQ-07", "title": "Уроки выживания",
			"main": true, "auto": true, "prereq": ["ac_mq_05_complete"],
			"summary": "Освоить огонь, воду и звёздную навигацию.",
			"description": "Джулиус ведёт почти пустой класс. Он учит читать звёзды, разводить огонь и находить воду.",
			"objectives": [
				["talk_julius", "TALK", "julius", "Поговорить с Джулиусом"],
				["stars", "INTERACT", "star_map", "Изучить карту звёзд"],
				["fire", "INTERACT", "fire_pit", "Развести огонь"],
			],
			"rewards": [
				{"flag": "star_navigation", "text": "Звёздная навигация"},
				{"flag": "firemaking", "text": "Разведение огня"},
				{"flag": "water_finding", "text": "Поиск воды"},
			],
			"completion": "ac_mq_07_complete",
		},
		{
			"id": "ac_mq_08_measure", "code": "AC-MQ-08", "title": "Мера силы",
			"main": true, "auto": true, "prereq": ["ac_mq_05_complete"],
			"summary": "Пройти тест удара в додзё.",
			"description": "Нефис бьёт на 16, Каспер — на 21, Санни — на 10–11. Рок говорит, что сила — не всё.",
			"objectives": [
				["strike", "INTERACT", "strike_meter", "Ударить по датчику"],
				["talk_rock", "TALK", "rock_dojo", "Выслушать Рока"],
			],
			"rewards": [
				{"flag": "dojo_token", "text": "Доступ в додзё после отбоя"},
				{"flag": "parry_basics", "text": "Основы парирования"},
				{"currency": "credits", "amount": 20, "text": "20 кредитов"},
			],
			"completion": "ac_mq_08_complete",
		},
		# ------------------------------------------------------------------
		# MAIN 09-12
		# ------------------------------------------------------------------
		{
			"id": "ac_mq_09_shadow", "code": "AC-MQ-09", "title": "Тень в коридорах",
			"main": true, "auto": true, "prereq": ["ac_mq_04_complete"],
			"summary": "Освоить тень-разведчика в сервисных коридорах.",
			"description": "Ночью тень тянется к вентиляции. Три точки разведки ведут к старой табличке с именами.",
			"objectives": [
				["scout_1", "INTERACT", "shadow_point_1", "Осмотреть коридор"],
				["scout_2", "INTERACT", "shadow_point_2", "Осмотреть фильтры"],
				["scout_3", "INTERACT", "shadow_point_3", "Осмотреть архив"],
			],
			"rewards": [
				{"flag": "shadow_scout", "text": "Тень-разведчик"},
				{"flag": "maintenance_key", "text": "Ключ от сервисных тоннелей"},
				{"currency": "credits", "amount": 15, "text": "15 кредитов"},
			],
			"completion": "ac_mq_09_complete",
		},
		{
			"id": "ac_mq_10_sparring", "code": "AC-MQ-10", "title": "Спарринг",
			"main": true, "auto": true, "prereq": ["ac_mq_08_complete"],
			"summary": "Посмотреть бой Каспера и Нефис.",
			"description": "Нефис почти побеждает без Аспекта. В раздевалке Каспер рассказывает о клане Immortal Flame.",
			"objectives": [
				["watch", "FLAG", "academy_reached_dojo", "Посмотреть спарринг"],
				["locker", "TALK", "kasper_locker", "Поговорить с Каспером в раздевалке"],
			],
			"rewards": [
				{"flag": "immortal_flame_known", "text": "История клана Immortal Flame"},
				{"currency": "credits", "amount": 25, "text": "25 кредитов"},
			],
			"completion": "ac_mq_10_complete",
		},
		{
			"id": "ac_mq_11_storm", "code": "AC-MQ-11", "title": "Ночь шторма",
			"main": true, "auto": true, "prereq": ["ac_mq_09_complete", "ac_mq_10_complete"],
			"summary": "Открыть заблокированный блок и вывести кадетов.",
			"description": "Шторм валит антенну. Дверь в нижний блок заблокирована; Мира и Рен остались внутри.",
			"objectives": [
				["alarm", "FLAG", "academy_reached_alarm", "Понять, что произошло"],
				["release", "INTERACT", "manual_release", "Открыть дверь вручную"],
				["rescue", "FLAG", "cadet_rescued", "Вывести кадетов"],
			],
			"rewards": [
				{"item": "field_medkit", "count": 1, "text": "Полевая аптечка"},
				{"currency": "credits", "amount": 30, "text": "30 кредитов"},
			],
			"completion": "ac_mq_11_complete",
		},
		{
			"id": "ac_mq_12_last_day", "code": "AC-MQ-12", "title": "Семнадцать",
			"main": true, "auto": true, "prereq": ["ac_mq_11_complete"],
			"summary": "Прожить последний день и лечь в капсулу.",
			"description": "Кофе, день рождения, прощание с Джулиусом, галерея Hollow и капсула.",
			"objectives": [
				["coffee", "INTERACT", "coffee_machine", "Взять кофе"],
				["cassia", "TALK", "cassia_birthday", "Поговорить с Кассией"],
				["farewell", "TALK", "julius_farewell", "Попрощаться с Джулиусом"],
				["hollow", "FLAG", "academy_reached_hollow", "Пройти галерею Hollow"],
				["capsule", "INTERACT", "sleeper_capsule", "Лечь в капсулу"],
			],
			"rewards": [
				{"flag": "birthday_17", "text": "Семнадцать лет"},
				{"flag": "hollow_seen", "text": "Галерея Hollow"},
				{"flag": "capsule_entered", "text": "Капсула сна"},
			],
			"completion": "academy_complete",
		},
		# ------------------------------------------------------------------
		# SIDE 01-04
		# ------------------------------------------------------------------
		{
			"id": "ac_sq_01_lucky_charm", "code": "AC-SQ-01", "title": "Талисман",
			"summary": "Найти талисман Миры в вентиляции прачечной.",
			"description": "Мира потеряла латунный талисман — единственную вещь от брата. Он упал в вентиляцию.",
			"objectives": [["vent", "INTERACT", "laundry_vent", "Обыскать вентиляцию"]],
			"rewards": [
				{"item": "provisions", "count": 2, "text": "Провизия ×2"},
				{"flag": "ac_rep_outcast_1", "text": "Доверие «обречённых»"},
			],
			"completion": "ac_sq_01_complete",
		},
		{
			"id": "ac_sq_02_borrowed_uniform", "code": "AC-SQ-02", "title": "Чужая форма",
			"summary": "Найти форму Рена в шкафчиках додзё.",
			"description": "Группа Legacy «одолжила» форму Рена для посвящения. Он слишком напуган, чтобы сообщить.",
			"objectives": [["locker", "INTERACT", "dojo_locker", "Обыскать шкафчики додзё"]],
			"rewards": [
				{"currency": "credits", "amount": 10, "text": "10 кредитов"},
				{"flag": "ac_rep_outcast_1", "text": "Доверие «обречённых»"},
			],
			"completion": "ac_sq_02_complete",
		},
		{
			"id": "ac_sq_03_star_chart", "code": "AC-SQ-03", "title": "Карта, которой нет",
			"summary": "Найти карту звёзд в закрытом архиве.",
			"description": "Джулиус потерял карту, которую рисовал для Санни. Она попала в закрытый архив.",
			"objectives": [["archive", "INTERACT", "restricted_archive", "Найти карту в архиве"]],
			"rewards": [
				{"flag": "star_navigation", "text": "Звёздная навигация"},
				{"flag": "ac_rep_faculty_1", "text": "Доверие преподавателей"},
			],
			"completion": "ac_sq_03_complete",
		},
		{
			"id": "ac_sq_04_dead_word", "code": "AC-SQ-04", "title": "Слово из мёртвого языка",
			"summary": "Перевести надпись на старой плите.",
			"description": "На плите в библиотеке вырезано слово на мёртвом языке. Джулиус просит помочь с переводом.",
			"objectives": [["plaque", "INTERACT", "library_plaque", "Изучить плиту"]],
			"rewards": [
				{"flag": "dead_languages", "text": "Мёртвые языки"},
				{"flag": "library_restricted", "text": "Доступ в закрытый архив"},
			],
			"completion": "ac_sq_04_complete",
		},
		# ------------------------------------------------------------------
		# SIDE 05-08
		# ------------------------------------------------------------------
		{
			"id": "ac_sq_05_dojo_ghost", "code": "AC-SQ-05", "title": "Призрак в додзё",
			"summary": "Проверить ночной шум в додзё.",
			"description": "После отбоя в додзё слышны удары. Это Рен тренируется тайком, чтобы не попасть в «обречённые».",
			"objectives": [["ghost", "INTERACT", "dojo_night_point", "Проверить шум"]],
			"rewards": [
				{"flag": "parry_basics", "text": "Основы парирования"},
				{"flag": "dojo_token", "text": "Доступ в додзё после отбоя"},
			],
			"completion": "ac_sq_05_complete",
		},
		{
			"id": "ac_sq_06_second_from_last", "code": "AC-SQ-06", "title": "Второй с конца",
			"summary": "Пройти три тренировочных боя.",
			"description": "Рок предлагает неофициальную лестницу. Победа не делает Санни героем, но меняет место в списке.",
			"objectives": [["duel", "INTERACT", "ladder_point", "Пройти тренировочную лестницу"]],
			"rewards": [
				{"flag": "academy_rank", "text": "Место в рейтинге"},
				{"currency": "credits", "amount": 20, "text": "20 кредитов"},
			],
			"completion": "ac_sq_06_complete",
		},
		{
			"id": "ac_sq_07_kasper_bet", "code": "AC-SQ-07", "title": "Пари Каспера",
			"summary": "Принять или отклонить пари Каспера.",
			"description": "Каспер предлагает пари: Санни не продержится три удара против кадета из его группы.",
			"objectives": [["bet", "INTERACT", "kasper_bet_point", "Ответить на пари"]],
			"rewards": [
				{"currency": "credits", "amount": 30, "text": "30 кредитов"},
				{"flag": "kasper_favor", "text": "Услуга Каспера"},
			],
			"completion": "ac_sq_07_complete",
		},
		{
			"id": "ac_sq_08_tea_for_cassia", "code": "AC-SQ-08", "title": "Чай для слепой",
			"summary": "Найти травяной чай для Кассии.",
			"description": "Автомат сломан. Санни идёт на кухню, находит чай и заваривает. Маленький жест, который Кассия запомнит.",
			"objectives": [["tea", "INTERACT", "kitchen_tea", "Найти чай на кухне"]],
			"rewards": [
				{"flag": "ac_rep_cassia_1", "text": "Доверие Кассии"},
				{"item": "water_skin", "count": 1, "text": "Фляга"},
			],
			"completion": "ac_sq_08_complete",
		},
		# ------------------------------------------------------------------
		# SIDE 09-12
		# ------------------------------------------------------------------
		{
			"id": "ac_sq_09_missing_cadet", "code": "AC-SQ-09", "title": "Пропавший кадет",
			"summary": "Найти Рена в старом фильтрационном блоке.",
			"description": "Мира говорит, что Рен пропал после отбоя. Тень ведёт Санни в сервисные тоннели.",
			"objectives": [["find", "FLAG", "academy_reached_filtration", "Обыскать старый фильтрационный блок"]],
			"rewards": [
				{"item": "field_medkit", "count": 1, "text": "Полевая аптечка"},
				{"flag": "ac_rep_outcast_2", "text": "Доверие «обречённых»"},
			],
			"completion": "ac_sq_09_complete",
		},
		{
			"id": "ac_sq_10_maintenance_key", "code": "AC-SQ-10", "title": "Ключ от подвалов",
			"summary": "Найти ключ сержанта Хольта в корзине с бельём.",
			"description": "Хольт потерял ключ от сервисных тоннелей и не хочет сообщать начальству.",
			"objectives": [["bin", "INTERACT", "laundry_bin", "Обыскать корзину с бельём"]],
			"rewards": [
				{"flag": "maintenance_key", "text": "Ключ от сервисных тоннелей"},
				{"currency": "credits", "amount": 15, "text": "15 кредитов"},
			],
			"completion": "ac_sq_10_complete",
		},
		{
			"id": "ac_sq_11_hollow_letter", "code": "AC-SQ-11", "title": "Письмо из галереи",
			"summary": "Найти письмо в галерее Hollow.",
			"description": "В руке одного из Hollow зажат конверт, адресованный матери. Кассия чувствует, что это важно.",
			"objectives": [["letter", "INTERACT", "hollow_letter", "Найти письмо"]],
			"rewards": [
				{"flag": "ac_rep_cassia_2", "text": "Доверие Кассии"},
				{"flag": "hollow_letter_resolved", "text": "Письмо из галереи"},
			],
			"completion": "ac_sq_11_complete",
		},
		{
			"id": "ac_sq_12_wall_walk", "code": "AC-SQ-12", "title": "Прогулка по стене",
			"summary": "Дойти до восточной турели по стене.",
			"description": "Стражник спорит, что Санни не дойдёт до восточной турели до удара колокола. Это не насмешка, а скука.",
			"objectives": [["turret", "FLAG", "academy_reached_east_turret", "Дойти до восточной турели"]],
			"rewards": [
				{"currency": "credits", "amount": 10, "text": "10 кредитов"},
				{"flag": "old_academy_map", "text": "Старая карта Академии"},
			],
			"completion": "ac_sq_12_complete",
		},
	]
