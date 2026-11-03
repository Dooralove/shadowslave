extends SceneTree
## Offscreen capture for the layered vitals HUD.
## Run without --headless:
##   godot --path . -s tools/audit/vitals_hud_capture.gd -- --out=<folder>

var _out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		push_error("vitals_hud_capture: нужен --out=<папка>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1600, 900)

	var background := TextureRect.new()
	background.name = "Backdrop"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var preview_path := ProjectSettings.globalize_path("res://docs/art/previews/post_nightmare/coral_labyrinth_audit/player_view.png")
	var preview := Image.new()
	var preview_error := preview.load(preview_path) if FileAccess.file_exists(preview_path) else ERR_FILE_NOT_FOUND
	if preview_error == OK:
		background.texture = ImageTexture.create_from_image(preview)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([
			Color(0.025, 0.035, 0.045),
			Color(0.065, 0.075, 0.085),
			Color(0.035, 0.025, 0.028),
		])
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 1600
		texture.height = 900
		texture.fill_from = Vector2(0.1, 0.0)
		texture.fill_to = Vector2(0.9, 1.0)
		background.texture = texture
	root.add_child(background)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.02, 0.025, 0.42)
	root.add_child(dim)

	var health := HealthComponent.new()
	health.name = "CaptureHealth"
	health.max_health = 100.0
	root.add_child(health)
	var stamina := StaminaComponent.new()
	stamina.name = "CaptureStamina"
	stamina.max_stamina = 100.0
	root.add_child(stamina)
	await process_frame
	await process_frame

	var hud := (load("res://scenes/ui/combat_hud.tscn") as PackedScene).instantiate() as CombatHud
	hud.first_reveal_seconds = 10.0
	root.add_child(hud)
	hud.bind(health, null, stamina)
	await process_frame
	await _save("vitals_full.png")

	health.take_damage(36.0)
	stamina.spend(42.0)
	hud.vitals_bar.health.catch_up_speed = 40.0
	hud.vitals_bar.stamina.catch_up_speed = 40.0
	await _save("vitals_wounded.png")

	health.take_damage(42.0)
	await _save("vitals_critical.png")

	print("vitals_hud_capture: done out=", _out_dir)
	quit(0)


func _save(file_name: String) -> void:
	for i in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_out_dir.path_join(file_name))
	print("WROTE ", _out_dir.path_join(file_name))
