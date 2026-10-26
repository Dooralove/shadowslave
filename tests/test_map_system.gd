extends GutTest
## Система карт: данные атласа, определение локации, единый экран и
## восстановление паузы/ввода при закрытии.

const ATLAS_PATH := "res://resources/map/map_atlas.tres"
const MAP_SCREEN_PATH := "res://scenes/ui/map/map_screen.tscn"
const TEST_LEVEL_PATH := "res://scenes/levels/test_level.tscn"
const PASS_SCENE_PATH := "res://scenes/campaign/first_nightmare_pass.tscn"


func before_each() -> void:
	_force_close_map()


func after_each() -> void:
	_force_close_map()


func _force_close_map() -> void:
	var map_system := get_node_or_null("/root/MapSystem")
	if map_system != null and map_system.is_open():
		map_system.close_map()
	# Тесты не должны оставлять дерево на паузе, иначе GUT зависнет.
	if get_tree().paused:
		get_tree().paused = false


func _atlas() -> MapAtlas:
	return load(ATLAS_PATH) as MapAtlas


func _spawn_screen() -> MapScreen:
	var screen := (load(MAP_SCREEN_PATH) as PackedScene).instantiate() as MapScreen
	add_child_autofree(screen)
	screen.setup(_atlas())
	return screen


func test_atlas_loads_with_world_and_multiple_locations() -> void:
	var atlas := _atlas()
	assert_not_null(atlas, "атлас должен загружаться")
	assert_not_null(atlas.world_map, "у атласа есть общая карта мира")
	assert_gt(atlas.locations.size(), 2, "нужны минимум две локальные карты")

	var ids := {}
	for location in atlas.locations:
		assert_not_null(location, "локация не пустая")
		if location == null:
			continue
		assert_false(location.id.is_empty(), "у локации есть id")
		assert_false(location.title.is_empty(), "у локации есть название")
		assert_true(ids.get(location.id) == null, "id локации уникален: %s" % location.id)
		ids[location.id] = true


func test_each_location_has_own_visual_data_and_markers() -> void:
	var atlas := _atlas()
	for location in atlas.locations:
		if location == null:
			continue
		assert_gt(location.markers.size(), 0, "у %s есть маркеры" % location.id)
		assert_gte(location.get_contour().size(), 3, "у %s есть контур" % location.id)
		assert_gt(location.accent_color.a, 0.0, "у %s задан акцент" % location.id)

		var marker_ids := {}
		for marker in location.markers:
			assert_not_null(marker, "маркер не пустой")
			if marker == null:
				continue
			assert_false(marker.label.is_empty(), "у маркера есть подпись")
			assert_between(marker.position.x, 0.0, 1.0, "x маркера в границах карты")
			assert_between(marker.position.y, 0.0, 1.0, "y маркера в границах карты")
			assert_true(marker_ids.get(marker.id) == null,
				"id маркера уникален внутри %s" % location.id)
			marker_ids[marker.id] = true


func test_scene_paths_are_unique_and_resolve() -> void:
	var atlas := _atlas()
	var owners := {}
	for location in atlas.locations:
		if location == null:
			continue
		for scene_path in location.scene_paths:
			assert_false(owners.has(scene_path),
				"сцена %s не принадлежит двум картам" % scene_path)
			owners[scene_path] = location.id

	assert_eq(
		atlas.find_location_for_scene_path(TEST_LEVEL_PATH).id,
		&"forgotten_shore",
		"test_level.tscn ведёт на карту Забытого берега"
	)
	assert_eq(
		atlas.find_location_for_scene_path(PASS_SCENE_PATH).id,
		&"caravan_road",
		"сцена перевала ведёт на карту караванной дороги"
	)


func test_current_location_is_found_through_nested_scene() -> void:
	var map_system := get_node_or_null("/root/MapSystem")
	assert_not_null(map_system, "автозагрузка MapSystem должна существовать")

	var wrapper := Node3D.new()
	wrapper.name = "UnmappedCampaignWrapper"
	add_child_autofree(wrapper)
	var level := (load(TEST_LEVEL_PATH) as PackedScene).instantiate()
	wrapper.add_child(level)

	var location := map_system.resolve_location_for(wrapper) as MapDefinition
	assert_not_null(location, "карта определяется по вложенной сцене")
	if location != null:
		assert_eq(location.id, &"forgotten_shore", "найдена карта вложенного уровня")


func test_unknown_scene_gets_universal_fallback() -> void:
	var map_system := get_node_or_null("/root/MapSystem")
	assert_not_null(map_system, "автозагрузка MapSystem должна существовать")

	var unknown := Node3D.new()
	unknown.name = "RuinedChapel"
	add_child_autofree(unknown)

	var fallback := map_system.resolve_location_for(unknown) as MapDefinition
	assert_not_null(fallback, "для неизвестной сцены строится заглушка")
	if fallback != null:
		assert_true(fallback.is_fallback, "карта помечена как универсальная заглушка")
		assert_true(fallback.title.contains("Ruined"), "в названии есть имя сцены")
		assert_eq(fallback.markers.size(), 0, "у заглушки нет выдуманных маркеров")

	unknown.set_meta(&"map_title", "Забытая часовня")
	var titled := map_system.resolve_location_for(unknown) as MapDefinition
	assert_eq(titled.title, "Забытая часовня", "meta map_title задаёт название заглушки")


func test_open_and_close_restore_pause_and_mouse() -> void:
	var map_system := get_node_or_null("/root/MapSystem")
	assert_not_null(map_system, "автозагрузка MapSystem должна существовать")
	var screen := map_system.screen as MapScreen
	assert_not_null(screen, "экран карты создан")

	var was_paused := get_tree().paused
	var was_mouse := Input.mouse_mode
	assert_false(was_paused, "тест начинается без паузы")

	assert_true(map_system.open_map(), "карта открывается")
	assert_true(map_system.is_open(), "система считает карту открытой")
	assert_true(screen.visible, "экран карты виден")
	assert_true(get_tree().paused, "игра поставлена на паузу")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "курсор освобождён")

	map_system.close_map()
	assert_false(map_system.is_open(), "система считает карту закрытой")
	assert_false(screen.visible, "экран карты скрыт")
	assert_eq(get_tree().paused, was_paused, "пауза восстановлена")
	assert_eq(Input.mouse_mode, was_mouse, "режим мыши восстановлен")


func test_screen_switches_between_location_and_world() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	var location := atlas.get_location(&"caravan_site")
	assert_not_null(location, "карта стоянки существует")

	screen.open_for_location(location)
	assert_true(screen.visible, "экран открыт")
	assert_false(screen.showing_world, "сначала показана локальная карта")
	assert_eq(screen.title_label.text, location.title, "заголовок локации")

	screen.world_button.emit_signal("pressed")
	assert_true(screen.showing_world, "кнопка открывает карту мира")
	assert_eq(screen.title_label.text, atlas.world_map.title, "заголовок карты мира")

	screen.world_button.emit_signal("pressed")
	assert_false(screen.showing_world, "кнопка возвращает на текущую локацию")
	assert_eq(screen.displayed_location.id, &"caravan_site", "вернулись к текущей карте")


func test_world_region_opens_local_map_and_locked_region_does_not() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	screen.open_for_location(atlas.get_location(&"forgotten_shore"))
	screen.show_world()

	var region_button := screen.map_canvas.get_location_button(&"pilgrim_path")
	assert_not_null(region_button, "регион тропы паломников есть на карте мира")
	assert_true(region_button.disabled == false, "доступный регион кликабелен")

	assert_true(screen.open_location_by_id(&"pilgrim_path"), "регион открывается")
	assert_eq(screen.displayed_location.id, &"pilgrim_path", "показана выбранная карта")
	assert_false(screen.showing_world, "после выбора показана локальная карта")

	screen.show_world()
	var locked := screen.map_canvas.get_location_button(&"drowned_city")
	assert_not_null(locked, "закрытый регион виден")
	assert_true(locked.disabled, "закрытый регион нельзя нажать")
	assert_false(screen.open_location_by_id(&"drowned_city"), "закрытая карта не открывается")
	assert_eq(screen.displayed_location.id, &"pilgrim_path", "карта не сменилась")


func test_marker_click_updates_shared_legend() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	var location := atlas.get_location(&"forgotten_shore")
	screen.open_for_location(location)

	var marker := location.marker_by_id(&"altar")
	assert_not_null(marker, "маркер алтаря существует")
	var button := screen.map_canvas.get_marker_button(&"altar")
	assert_not_null(button, "маркер есть на холсте")
	if button != null:
		button.emit_signal("pressed")
	assert_eq(screen.detail_title.text, marker.label, "описание маркера обновилось")


func test_fallback_renders_without_error_and_keeps_world_access() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	var fallback := MapDefinition.create_fallback("Тестовая пещера")

	screen.open_for_location(fallback)
	assert_eq(screen.title_label.text, "Тестовая пещера", "заголовок заглушки")
	assert_string_contains(screen.kicker_label.text, "УНИВЕРСАЛЬНАЯ", "виден режим заглушки")
	assert_false(screen.world_button.disabled, "карта мира доступна из заглушки")

	screen.world_button.emit_signal("pressed")
	assert_true(screen.showing_world, "из универсальной карты можно перейти к миру")
	assert_eq(screen.title_label.text, atlas.world_map.title, "открылась общая карта")
