extends SceneTree
## Read-only steady-state performance audit for the equipment/loot demo.

const DEMO := "res://scenes/dev/equipment_loot_demo.tscn"
const SETS := [
	["scout", "res://resources/equipment/armor/scout_leather.tres"],
	["mercenary", "res://resources/equipment/armor/mercenary_medium.tres"],
	["heavy", "res://resources/equipment/armor/heavy_plate.tres"],
]
const WARMUP_FRAMES := 90
const MEASURE_FRAMES := 180


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1600, 900)
	var scene := (load(DEMO) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var equipment := scene.get_node("Equipment")
	equipment.call("unequip", EquipmentItemData.Slot.BODY)
	await _warmup()
	await _measure("no_armor")
	for set_info in SETS:
		equipment.call("equip", load(set_info[1]))
		await _warmup()
		await _measure(set_info[0])
	quit(0)


func _warmup() -> void:
	for i in WARMUP_FRAMES:
		await process_frame


func _measure(tag: String) -> void:
	var start := Time.get_ticks_usec()
	for i in MEASURE_FRAMES:
		await process_frame
	var elapsed := maxf((Time.get_ticks_usec() - start) / 1_000_000.0, 0.0001)
	var fps := MEASURE_FRAMES / elapsed
	print(tag,
		" avg_fps=", snappedf(fps, 0.1),
		" draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		" objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		" vram_mb=", snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1))
