extends GutTest
## Интеграция существующего прототипа RPG-меню в игровой процесс:
## открытие по C, пауза, курсор, закрытие и переключение с картой.


func before_each() -> void:
	_force_close_interfaces()


func after_each() -> void:
	_force_close_interfaces()
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _force_close_interfaces() -> void:
	var menu_system := get_node_or_null("/root/PlayerMenuSystem")
	if menu_system != null and menu_system.is_open():
		menu_system.close_menu()
	var map_system := get_node_or_null("/root/MapSystem")
	if map_system != null and map_system.is_open():
		map_system.close_map()


func _menu_system() -> Node:
	return get_node_or_null("/root/PlayerMenuSystem")


func _map_system() -> Node:
	return get_node_or_null("/root/MapSystem")


func test_player_menu_autoload_exists() -> void:
	assert_not_null(_menu_system(), "автозагрузка PlayerMenuSystem должна существовать")


func test_open_and_close_restore_pause_and_mouse() -> void:
	var menu_system := _menu_system()
	assert_not_null(menu_system)
	var was_paused := get_tree().paused
	var was_mouse := Input.mouse_mode

	assert_true(menu_system.open_menu(&"character"), "меню персонажа открывается")
	assert_true(menu_system.is_open(), "система считает меню открытым")
	assert_not_null(menu_system.screen, "экран меню создан")
	assert_true(menu_system.screen.visible, "экран меню виден")
	assert_true(menu_system.screen.menu_page.visible, "показана рабочая страница, а не стартовая")
	assert_true(menu_system.screen.nav_character.button_pressed, "открыт раздел персонажа")
	assert_true(get_tree().paused, "игра поставлена на паузу")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "курсор освобождён")

	menu_system.close_menu()
	assert_false(menu_system.is_open(), "система считает меню закрытым")
	assert_false(menu_system.screen.visible, "экран меню скрыт")
	assert_eq(get_tree().paused, was_paused, "пауза восстановлена")
	assert_eq(Input.mouse_mode, was_mouse, "режим мыши восстановлен")


func test_escape_path_in_prototype_closes_game_menu() -> void:
	var menu_system := _menu_system()
	assert_not_null(menu_system)
	assert_true(menu_system.open_menu(&"character"), "меню открывается")

	# Этот же путь используют Escape и кнопка «Закрыть» внутри прототипа.
	menu_system.screen.close_menu()
	assert_false(menu_system.is_open(), "закрытие из прототипа возвращает в игру")
	assert_false(menu_system.screen.visible, "экран меню скрыт")
	assert_false(get_tree().paused, "игра снова не на паузе")


func test_map_switch_closes_character_menu() -> void:
	var menu_system := _menu_system()
	var map_system := _map_system()
	assert_not_null(menu_system)
	assert_not_null(map_system)

	assert_true(menu_system.open_menu(&"character"), "меню открывается")
	assert_true(map_system.open_map(), "карта открывается поверх игры")
	assert_false(menu_system.is_open(), "меню закрыто при переходе к карте")
	assert_true(map_system.is_open(), "карта остаётся активной")
	assert_true(get_tree().paused, "игра на паузе под картой")

	map_system.close_map()
	assert_false(get_tree().paused, "после карты игра возвращается")


func test_character_switch_closes_map() -> void:
	var menu_system := _menu_system()
	var map_system := _map_system()
	assert_not_null(menu_system)
	assert_not_null(map_system)

	assert_true(map_system.open_map(), "карта открывается")
	assert_true(menu_system.open_menu(&"character"), "меню персонажа открывается с карты")
	assert_false(map_system.is_open(), "карта закрыта при переходе к персонажу")
	assert_true(menu_system.is_open(), "меню остаётся активным")
	assert_true(get_tree().paused, "игра на паузе под меню")

	menu_system.close_menu()
	assert_false(get_tree().paused, "после меню игра возвращается")


func test_menu_is_not_duplicated_on_reopen() -> void:
	var menu_system := _menu_system()
	assert_not_null(menu_system)

	assert_true(menu_system.open_menu(&"character"), "первое открытие")
	var first_screen_id: int = menu_system.screen.get_instance_id()
	assert_false(menu_system.open_menu(&"inventory"), "повторный вызов не открывает второе меню")
	assert_eq(menu_system.screen.get_instance_id(), first_screen_id, "экран тот же")
	assert_true(menu_system.screen.nav_inventory.button_pressed, "раздел переключился")

	menu_system.close_menu()
	assert_true(menu_system.open_menu(&"character"), "повторное открытие после закрытия")
	assert_eq(menu_system.screen.get_instance_id(), first_screen_id, "второй экран не создан")
	assert_eq(menu_system.screen.get_parent().get_child_count(), 1, "в слое ровно один экран")
	menu_system.close_menu()


func test_input_action_toggles_character_menu() -> void:
	var menu_system := _menu_system()
	assert_not_null(menu_system)

	var event := InputEventAction.new()
	event.action = &"open_character"
	event.pressed = true

	menu_system._unhandled_input(event)
	assert_true(menu_system.is_open(), "C открывает меню персонажа")

	menu_system._unhandled_input(event)
	assert_false(menu_system.is_open(), "повторный C закрывает меню")
	assert_false(get_tree().paused, "игра снова не на паузе")
