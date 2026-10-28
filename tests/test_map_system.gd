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
			var point := location.marker_point(marker)
			assert_between(point.x, 0.0, 1.0, "x маркера в границах карты")
			assert_between(point.y, 0.0, 1.0, "y маркера в границах карты")
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


func test_physical_escape_closes_map() -> void:
	var map_system := get_node_or_null("/root/MapSystem")
	assert_not_null(map_system, "автозагрузка MapSystem должна существовать")
	assert_true(map_system.open_map(), "карта открывается")

	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	map_system._unhandled_input(event)
	assert_false(map_system.is_open(), "физический Escape закрывает карту")
	assert_false(get_tree().paused, "пауза снята")


func test_screen_opens_region_of_current_location_and_switches_to_world() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	screen.open_for_location(atlas.get_location(&"caravan_site"))
	assert_true(screen.visible, "экран открыт")
	assert_false(screen.showing_world, "сначала показана карта региона")
	assert_eq(screen.displayed_region.id, &"region_first_nightmare", "регион стоянки — Первый Кошмар")
	assert_eq(screen.title_label.text, "ПЕРВЫЙ КОШМАР", "заголовок региона")

	screen.world_button.emit_signal("pressed")
	assert_true(screen.showing_world, "кнопка открывает карту мира")
	assert_eq(screen.title_label.text, atlas.world_map.title, "заголовок карты мира")

	screen.world_button.emit_signal("pressed")
	assert_false(screen.showing_world, "кнопка возвращает к региону игрока")
	assert_eq(screen.displayed_region.id, &"region_first_nightmare", "вернулись к своему региону")


func test_location_outside_regions_opens_world_map() -> void:
	var screen := _spawn_screen()
	screen.open_for_location(_atlas().get_location(&"forgotten_shore"))
	assert_true(screen.showing_world, "локация вне регионов открывает общую карту")
	assert_true(screen.world_button.disabled, "карты региона для неё нет")


func test_world_regions_split_into_playable_and_in_development() -> void:
	var atlas := _atlas()
	var route := atlas.get_region(&"region_first_nightmare")
	assert_not_null(route, "регион Первого Кошмара есть")
	assert_true(route != null and route.is_playable(), "Первый Кошмар доступен")
	assert_true(route != null and route.outside_realm, "Кошмар — вне Царства снов")
	var shore := atlas.get_region(&"region_forgotten_shore")
	assert_not_null(shore, "Забытый берег есть на карте мира")
	assert_true(shore != null and not shore.is_playable(), "регион Царства в разработке недоступен")
	assert_true(shore != null and not shore.outside_realm, "Забытый берег — часть Царства")
	var realm_regions := 0
	for region in atlas.regions:
		if region != null and not region.outside_realm:
			realm_regions += 1
			assert_false(region.is_playable(), "%s пока в разработке" % region.id)
	assert_gte(realm_regions, 6, "в Царстве снов несколько регионов")


func test_world_region_click_opens_region() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	screen.open_for_location(atlas.get_location(&"caravan_road"))
	screen.show_world()
	assert_true(screen.map_canvas.click_region(&"region_city"), "доступный регион нажимается")
	assert_false(screen.showing_world, "открыта карта региона")
	assert_eq(screen.displayed_region.id, &"region_city", "открыт выбранный регион")


func test_locked_region_does_not_open() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	screen.open_for_location(atlas.get_location(&"caravan_road"))
	screen.show_world()
	assert_false(screen.map_canvas.click_region(&"region_godgrave"), "регион в разработке не нажимается")
	assert_true(screen.showing_world, "остались на общей карте")
	assert_false(screen.show_region(atlas.get_region(&"region_godgrave")), "карту региона не открыть")


func test_region_map_composes_all_location_geometry() -> void:
	var atlas := _atlas()
	var region := atlas.get_region(&"region_first_nightmare")
	var map := atlas.compose_region_map(region)
	assert_not_null(map, "карта региона собирается")
	if map == null:
		return
	var expected_markers := 0
	var expected_features := region.region_map.features.size()
	for location_id in region.location_ids:
		var location := atlas.get_location(location_id)
		assert_not_null(location, "локация %s есть в атласе" % location_id)
		assert_not_null(region.region_map.placement_for(location_id), "у %s есть размещение" % location_id)
		expected_markers += location.markers.size()
		expected_features += location.features.size()
	assert_eq(map.markers.size(), expected_markers, "все места локаций перенесены")
	assert_eq(map.features.size(), expected_features, "вся геометрия локаций перенесена")
	for marker in map.markers:
		var point := map.marker_point(marker)
		assert_between(point.x, 0.0, 1.0, "%s внутри подложки по X" % marker.id)
		assert_between(point.y, 0.0, 1.0, "%s внутри подложки по Y" % marker.id)
	var site := atlas.get_location(&"caravan_site")
	assert_not_null(site.marker_by_id(&"fire"), "у карты локации id маркеров прежние: она осталась для мини-карты")


func test_player_on_region_map_follows_location_placement() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	screen.set_player(Vector2(0.6, 2.0), Vector2(0.0, -1.0), true)
	screen.open_for_location(atlas.get_location(&"caravan_site"))
	var canvas := screen.map_canvas
	assert_true(canvas._has_player, "игрок показан на карте своего региона")
	var expected := atlas.to_region_point(screen.displayed_region, &"caravan_site", Vector2(0.6, 2.0))
	assert_almost_eq(canvas._player_world.x, expected.x, 0.001, "X игрока по размещению стоянки")
	assert_almost_eq(canvas._player_world.y, expected.y, 0.001, "Y игрока по размещению стоянки")
	assert_lt(canvas._player_forward.y, 0.0, "на стоянке север остаётся вверху")

	# Перевал повёрнут на 45°: взгляд на север сцены уходит на северо-восток карты.
	screen.open_for_location(atlas.get_location(&"caravan_road"))
	assert_gt(canvas._player_forward.x, 0.0, "поворот размещения учитывается: восток")
	assert_lt(canvas._player_forward.y, 0.0, "поворот размещения учитывается: север")


func test_player_hidden_on_other_region_and_world() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	screen.set_player(Vector2.ZERO, Vector2(0.0, -1.0), true)
	screen.open_for_location(atlas.get_location(&"caravan_site"))
	assert_true(screen.show_region(atlas.get_region(&"region_city")), "город открывается")
	assert_false(screen.map_canvas._has_player, "в чужом регионе игрока нет")
	screen.show_world()
	assert_false(screen.map_canvas._has_player, "на общей карте стрелки игрока нет")


func test_marker_click_updates_shared_legend() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	screen.open_for_location(atlas.get_location(&"caravan_site"))
	var marker := screen.displayed_map.marker_by_id(&"caravan_site/fire")
	assert_not_null(marker, "костёр стоянки есть на карте региона")
	if marker == null:
		return
	screen.map_canvas.marker_selected.emit(marker)
	assert_eq(screen.detail_title.text, marker.label, "описание места обновилось")
	assert_string_contains(screen.detail_meta.text, "СТОЯНКА", "указана локация места")


func test_zoom_reveals_all_places() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	screen.open_for_location(atlas.get_location(&"caravan_site"))
	var canvas := screen.map_canvas
	canvas.size = Vector2(900, 560)
	canvas._layout_buttons()
	var wagon := canvas.get_marker_button(&"caravan_site/wagon")
	assert_not_null(wagon, "кнопка повозки создана")
	if wagon == null:
		return
	assert_false(wagon.visible, "при общем виде мелкие места скрыты")
	var camp := canvas._local_point(screen.displayed_map.world_to_normalized(Vector2(650, 400)))
	canvas.zoom_by(3.0, camp)
	assert_gt(canvas.get_zoom(), MapCanvas.DETAIL_ZOOM, "карта приближена")
	assert_true(wagon.visible, "вблизи видны все места")
	canvas.reset_view()
	assert_almost_eq(canvas.get_zoom(), 1.0, 0.001, "вид сбрасывается")


func test_fallback_opens_world_without_region_access() -> void:
	var atlas := _atlas()
	var screen := _spawn_screen()
	var fallback := MapDefinition.create_fallback("Тестовая пещера")
	screen.open_for_location(fallback)
	assert_true(screen.showing_world, "для сцены вне атласа показана общая карта")
	assert_eq(screen.title_label.text, atlas.world_map.title, "открыта общая карта")
	assert_true(screen.world_button.disabled, "карты региона нет")


func test_route_maps_use_world_geometry_inside_bounds() -> void:
	var atlas := _atlas()
	for id in [&"caravan_road", &"caravan_site", &"pilgrim_path", &"shadow_sanctuary"]:
		var location := atlas.get_location(id)
		assert_not_null(location, "карта %s есть в атласе" % id)
		if location == null:
			continue
		assert_true(location.has_world_bounds(), "у %s заданы мировые границы" % id)
		assert_gt(location.features.size(), 0, "у %s есть геометрия" % id)
		for marker in location.markers:
			if marker == null or not marker.use_world_position:
				continue
			var point := location.marker_point(marker)
			assert_between(point.x, 0.0, 1.0, "%s: x маркера %s в границах" % [id, marker.id])
			assert_between(point.y, 0.0, 1.0, "%s: y маркера %s в границах" % [id, marker.id])


func test_world_position_round_trips_through_bounds() -> void:
	var location := MapDefinition.new()
	location.world_bounds = Rect2(-10, -20, 20, 40)
	var normalized := location.world_to_normalized(Vector2(0, 0))
	assert_almost_eq(normalized.x, 0.5, 0.0001, "x центра по середине")
	assert_almost_eq(normalized.y, 0.5, 0.0001, "z центра по середине")
	var world := location.normalized_to_world(normalized)
	assert_almost_eq(world.x, 0.0, 0.0001, "обратный перевод по X")
	assert_almost_eq(world.y, 0.0, 0.0001, "обратный перевод по Z")


func test_placement_maps_scene_points_without_mirroring() -> void:
	var placement := MapPlacement.new()
	placement.center = Vector2(100, 100)
	placement.pixels_per_meter = 2.0
	var north := placement.to_region(Vector2(0, -10), Vector2.ZERO)
	assert_almost_eq(north.y, 80.0, 0.001, "север сцены (-Z) — вверх подложки")
	var east := placement.to_region(Vector2(10, 0), Vector2.ZERO)
	assert_almost_eq(east.x, 120.0, 0.001, "восток сцены (+X) — вправо подложки")


func test_map_system_reports_player_and_minimap_snapshot() -> void:
	var map_system := get_node("/root/MapSystem")
	var root := Node3D.new()
	add_child_autofree(root)
	var player := Node3D.new()
	player.add_to_group(&"player")
	root.add_child(player)
	player.position = Vector3(3.0, 0.0, -7.0)

	var state: Dictionary = map_system.player_state(root)
	assert_true(state.found, "игрок найден в корне сцены")
	assert_almost_eq(state.position.x, 3.0, 0.001, "X игрока в координатах сцены")
	assert_almost_eq(state.position.y, -7.0, 0.001, "Z игрока в координатах сцены")

	var snapshot: Dictionary = map_system.minimap_snapshot()
	for key in ["location", "has_player", "player", "forward"]:
		assert_true(snapshot.has(key), "снимок мини-карты содержит %s" % key)
	assert_not_null(snapshot.location, "у мини-карты есть карта локации (или заглушка)")