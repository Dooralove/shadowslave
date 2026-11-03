extends GutTest
## Контракты standalone Academy-сегмента и его входа из главного меню.

const CATALOG := "res://resources/quests/academy/quest_catalog_academy.tres"
const GROUNDS := "res://scenes/locations/academy_playable/academy_grounds_playable.tscn"
const SLEEPER := "res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn"


func before_each() -> void:
	NightmareRunState.reset()
	QuestSystem.deactivate_scope()


func after_each() -> void:
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()


func test_catalog_has_twenty_four_academy_quests() -> void:
	var catalog := load(CATALOG) as QuestCatalog
	assert_not_null(catalog, "academy-каталог загружается")
	if catalog == null:
		return
	assert_eq(catalog.scope, &"academy", "каталог принадлежит scope academy")
	assert_eq(catalog.quests.size(), 24, "12 основных и 12 побочных заданий")


func test_main_menu_has_academy_entry() -> void:
	var packed := load("res://scenes/ui/main_menu/main_menu.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var menu := packed.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	var button := menu.find_child("AcademyButton", true, false) as Button
	assert_not_null(button, "кнопка Академии существует")
	if button != null:
		assert_string_contains(button.text, "Академия")
	menu.transition_enabled = false
	await menu.start_academy()
	assert_true(NightmareRunState.has_flag(&"academy_chapter_started"), "вход включает academy-главу")
	assert_eq(NightmareRunState.get_current_beat(), &"AC01", "academy начинается с AC01")


func test_grounds_scene_builds_playable_layer() -> void:
	var packed := load(GROUNDS) as PackedScene
	assert_not_null(packed, "Academy Grounds playable загружается")
	if packed == null:
		return
	var scene := packed.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(scene.get_node_or_null(^"Player"), "игрок создан")
	assert_not_null(scene.get_node_or_null(^"GameplayHud"), "HUD создан")
	var director := scene.get_node_or_null(^"AcademyGameplayDirector")
	assert_not_null(director, "director создан")
	if director != null:
		assert_not_null(director.get_node_or_null(^"GateBlocker"), "красные ворота перекрыты до допуска")
		assert_gt(director.get_node(^"GateBlocker").get_child_count(), 0, "у блокировщика есть коллайдер")


func test_sleeper_scene_builds_playable_layer() -> void:
	var packed := load(SLEEPER) as PackedScene
	assert_not_null(packed, "Sleeper Center playable загружается")
	if packed == null:
		return
	var scene := packed.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(scene.get_node_or_null(^"Player"), "игрок создан")
	assert_not_null(scene.get_node_or_null(^"GameplayHud"), "HUD создан")
	assert_not_null(scene.get_node_or_null(^"AcademyGameplayDirector"), "director создан")
	assert_not_null(scene.get_node_or_null(^"AcademyGameplayDirector/ToGrounds"), "портал обратно в кампус создан")


func test_academy_scope_starts_first_main_quest() -> void:
	QuestSystem.activate_scope(&"academy")
	QuestSystem.refresh_auto_start()
	assert_eq(QuestSystem.get_state(&"ac_mq_01_red_gate"), &"active", "AC-MQ-01 стартует автоматически")
