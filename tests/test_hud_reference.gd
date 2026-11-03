extends GutTest
## Reference-layout HUD: element placement and the new minimap / quick items /
## control hints widgets.

const HUD_SCENE := "res://scenes/quests/gameplay_hud.tscn"


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func test_reference_layout_places_elements_like_the_reference() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as GameplayHud
	hud.tutorial_enabled = false
	add_child_autofree(hud)
	await wait_process_frames(2)
	var viewport: Vector2 = hud.get_viewport().get_visible_rect().size
	assert_not_null(hud.minimap, "minimap exists")
	assert_not_null(hud.quick_items, "quick items exist")
	assert_not_null(hud.control_hints, "control hints exist")
	if hud.minimap != null:
		var rect := hud.minimap.get_global_rect()
		assert_gt(rect.position.x, viewport.x * 0.68, "minimap is top-right")
		assert_lt(rect.position.y, viewport.y * 0.2, "minimap is at the top")
	if hud.objective_line != null:
		assert_gt(hud.objective_line.get_global_rect().position.x, viewport.x * 0.65, "quest tracker is on the right")
	if hud.quick_items != null:
		var rect := hud.quick_items.get_global_rect()
		assert_lt(rect.position.x, viewport.x * 0.25, "quick items are bottom-left")
		assert_gt(rect.position.y, viewport.y * 0.6, "quick items are at the bottom")
	if hud.control_hints != null:
		var rect := hud.control_hints.get_global_rect()
		assert_gt(rect.position.x, viewport.x * 0.68, "control hints are bottom-right")
		assert_gt(rect.position.y, viewport.y * 0.6, "control hints are at the bottom")
	var combat := hud.get_node_or_null(^"CombatHud") as CombatHud
	assert_not_null(combat, "combat vitals exist")
	if combat != null:
		var rect := combat.player_panel.get_global_rect()
		assert_lt(rect.position.x, viewport.x * 0.3, "vitals are top-left")
		assert_lt(rect.position.y, viewport.y * 0.3, "vitals are at the top")
		assert_gt(combat.enemy_panel.get_global_rect().position.x, viewport.x * 0.3, "enemy bar is top-centre")


func test_quick_items_reads_real_run_state() -> void:
	NightmareRunState.set_item(&"provisions", 5)
	NightmareRunState.set_item(&"water_skin", 2)
	NightmareRunState.set_item(&"torch", 1)
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as GameplayHud
	hud.tutorial_enabled = false
	add_child_autofree(hud)
	await wait_process_frames(2)
	var rows := hud.quick_items.get_rows_text()
	assert_eq(rows.size(), 3, "three quick-item rows")
	assert_string_contains(rows[0], "5")
	assert_string_contains(rows[0], "Хлеб")
	assert_string_contains(rows[1], "2")
	assert_string_contains(rows[1], "Вода")
	assert_string_contains(rows[2], "1")
	assert_string_contains(rows[2], "Факел")


func test_control_hints_use_live_input_map() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as GameplayHud
	hud.tutorial_enabled = false
	add_child_autofree(hud)
	await wait_process_frames(2)
	var rows := hud.control_hints.get_rows_text()
	assert_gte(rows.size(), 3, "sprint, interact and map hints")
	for row in rows:
		assert_false(row.contains("?"), "every hint resolves to a key: %s" % row)


func test_minimap_has_texture_and_caption() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as GameplayHud
	hud.tutorial_enabled = false
	add_child_autofree(hud)
	await wait_process_frames(2)
	var texture := hud.minimap.get_node("%MapTexture") as TextureRect
	assert_not_null(texture, "minimap texture node")
	if texture != null:
		assert_not_null(texture.texture, "minimap viewport texture is assigned")
	var caption := hud.minimap.get_node("%RegionLabel") as Label
	assert_not_null(caption, "minimap region caption")
	if caption != null:
		assert_false(caption.text.strip_edges().is_empty(), "caption is not empty")


func test_quest_tracker_is_right_aligned() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as GameplayHud
	hud.tutorial_enabled = false
	add_child_autofree(hud)
	await wait_process_frames(2)
	var text := hud.objective_line.get_node("Box/Text") as Label
	var caption := hud.objective_line.get_node("Box/Caption") as Label
	assert_eq(text.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	assert_eq(caption.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
