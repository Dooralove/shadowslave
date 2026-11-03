extends SceneTree
## Read-only capture for the generated armour sets and the loot demo.
## godot --path . -s tools/audit/armor_sets_capture.gd -- --out=<dir>

const DEMO := "res://scenes/dev/equipment_loot_demo.tscn"
const SETS := [
	["scout", "res://resources/equipment/armor/scout_leather.tres"],
	["mercenary", "res://resources/equipment/armor/mercenary_medium.tres"],
	["heavy", "res://resources/equipment/armor/heavy_plate.tres"],
]

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1600, 900)

	var scene := (load(DEMO) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var equipment := scene.get_node("Equipment")
	var ui := scene.get_node("UI") as CanvasLayer
	var backdrop := scene.get_node("UI/Backdrop") as ColorRect
	var stats_label := scene.get_node("UI/StatsLabel") as Label
	var inventory_label := scene.get_node("UI/InventoryLabel") as Label
	var dummy_health := scene.get_node("Dummy/Health") as HealthComponent
	var chest := scene.get_node("Chest") as LootContainer
	ui.visible = false

	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0.0, 1.05, 0.05)
	camera.fov = 50.0
	camera.look_at(Vector3(0.0, 0.95, 2.0), Vector3.UP)
	camera.current = true

	for set_info in SETS:
		var armor := load(set_info[1]) as ArmorItem
		equipment.call("equip", armor)
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := _out.path_join("armor_%s.png" % set_info[0])
		root.get_texture().get_image().save_png(path)
		print("CAPTURE ", path)

	# Weapon stow: the same sword moves from the hand to the hip.
	equipment.call("set_weapon_drawn", false)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var stow_path := _out.path_join("weapon_stowed.png")
	root.get_texture().get_image().save_png(stow_path)
	print("CAPTURE ", stow_path)
	equipment.call("set_weapon_drawn", true)

	# Stats panel shot: character shifted right so the panel does not cover it.
	ui.visible = true
	backdrop.visible = true
	stats_label.visible = true
	inventory_label.visible = false
	camera.position = Vector3(-1.0, 1.05, 0.05)
	camera.look_at(Vector3(-0.5, 0.95, 2.0), Vector3.UP)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var stats_path := _out.path_join("stats_heavy.png")
	root.get_texture().get_image().save_png(stats_path)
	print("CAPTURE ", stats_path)

	# Loot demo: a wider camera that sees the character, dummy and chest.
	# The stats panel is hidden so the loot labels are readable.
	backdrop.visible = false
	stats_label.visible = false
	inventory_label.visible = true
	camera.position = Vector3(3.0, 2.0, 4.2)
	camera.look_at(Vector3(0.8, 0.8, -1.2), Vector3.UP)
	ui.visible = true
	dummy_health.take_damage(dummy_health.max_health)
	for i in 18:
		await process_frame
	await RenderingServer.frame_post_draw
	var loot_path := _out.path_join("loot_drop.png")
	root.get_texture().get_image().save_png(loot_path)
	print("CAPTURE ", loot_path)

	chest.open()
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var chest_path := _out.path_join("container_open.png")
	root.get_texture().get_image().save_png(chest_path)
	print("CAPTURE ", chest_path)
	quit(0)
