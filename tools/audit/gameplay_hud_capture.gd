extends SceneTree
## Captures the reference-layout gameplay HUD over a coral labyrinth frame.
## Run without --headless:
##   godot --path . -s tools/audit/gameplay_hud_capture.gd -- --out=<folder>

var _out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		push_error("gameplay_hud_capture: нужен --out=<папка>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1600, 900)

	_add_backdrop()

	var world := Node3D.new()
	world.name = "CaptureWorld"
	world.set_meta(&"map_id", &"labyrinth_first_fragment")
	root.add_child(world)
	var player := Node3D.new()
	player.name = "Sunny"
	player.position = Vector3(0.0, 1.6, 0.0)
	player.add_to_group(&"player")
	world.add_child(player)

	var run_state := root.get_node_or_null(^"NightmareRunState")
	if run_state != null:
		run_state.call(&"reset")
		run_state.call(&"set_item", &"provisions", 5)
		run_state.call(&"set_item", &"water_skin", 2)
		run_state.call(&"set_item", &"torch", 1)

	var player_health := HealthComponent.new()
	player_health.name = "CapturePlayerHealth"
	player_health.max_health = 100.0
	root.add_child(player_health)
	var enemy_health := HealthComponent.new()
	enemy_health.name = "CaptureEnemyHealth"
	enemy_health.max_health = 300.0
	root.add_child(enemy_health)
	var stamina := StaminaComponent.new()
	stamina.name = "CaptureStamina"
	stamina.max_stamina = 100.0
	root.add_child(stamina)
	await process_frame
	player_health.take_damage(36.0)
	enemy_health.take_damage(80.0)
	stamina.spend(28.0)

	var hud := (load("res://scenes/quests/gameplay_hud.tscn") as PackedScene).instantiate() as GameplayHud
	root.add_child(hud)
	await process_frame
	await process_frame

	var combat := hud.get_node_or_null(^"CombatHud") as CombatHud
	if combat != null:
		combat.bind(player_health, enemy_health, stamina)
		combat.set_visible_for_combat(true)
		combat.enemy_label.text = "Карапасный центурион"
		if combat.vitals_bar != null:
			combat.vitals_bar.set_hp(64.0, 100.0)
			combat.vitals_bar.set_stamina(72.0, 100.0)

	if hud.objective_line != null:
		hud.objective_line.show_objective("Дойти до первой развилки", 0, true)
	if hud.prompt != null:
		hud.prompt.text = "E — Идти"
		hud.prompt.visible = true
	if hud.minimap != null:
		hud.minimap.call(&"_refresh")

	for index in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join("hud_reference_full.png"))
	print("WROTE ", _out_dir.path_join("hud_reference_full.png"))

	var subtitles := hud.get_node_or_null(^"Subtitles") as SubtitleUI
	if subtitles != null:
		subtitles.show_line(
			"Санни",
			"Мы больше не в цепях. Но это не значит, что мы свободны.",
			false,
			0,
			1
		)
		for index in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out_dir.path_join("hud_reference_subtitles.png"))
		print("WROTE ", _out_dir.path_join("hud_reference_subtitles.png"))

	quit(0)


func _add_backdrop() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var path := ProjectSettings.globalize_path(
		"res://docs/art/previews/post_nightmare/coral_labyrinth_audit/player_view.png"
	)
	var image := Image.new()
	if FileAccess.file_exists(path) and image.load(path) == OK:
		background.texture = ImageTexture.create_from_image(image)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(background)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.02, 0.025, 0.38)
	root.add_child(dim)
