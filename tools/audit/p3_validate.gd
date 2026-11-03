extends SceneTree
## Загружает P3-сцены и проверяет, что они инстанцируются без ошибок.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths := [
		"res://scenes/environment/p3_snow_gust.tscn",
		"res://scenes/environment/p3_breath_puff.tscn",
		"res://scenes/environment/p3_camp_smoke.tscn",
		"res://scenes/environment/p3_dust_motes.tscn",
		"res://scenes/environment/p3_road_dressing.tscn",
		"res://scenes/environment/p3_site_dressing.tscn",
		"res://scenes/environment/p3_trail_dressing.tscn",
		"res://scenes/environment/p3_vision_dressing.tscn",
		"res://scenes/environment/p3_sanctuary_dressing.tscn",
		"res://scenes/environment/p25_void_motes.tscn",
		"res://scenes/slice/locations/spell_void.tscn",
		"res://scenes/slice/locations/caravan_road_art.tscn",
		"res://scenes/locations/caravan_site/caravan_site_art.tscn",
		"res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn",
		"res://scenes/slice/locations/mountain_vision_art.tscn",
		"res://scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn",
		"res://scenes/campaign/first_nightmare_pass.tscn",
		"res://scenes/campaign/caravan_site_arrival.tscn",
		"res://scenes/campaign/pilgrim_path_arrival.tscn",
		"res://scenes/campaign/sanctuary_arrival.tscn",
	]
	var failed := 0
	for path in paths:
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("P3 validation: cannot load %s" % path)
			failed += 1
			continue
		var node := packed.instantiate()
		if node == null:
			push_error("P3 validation: cannot instantiate %s" % path)
			failed += 1
			continue
		root.add_child(node)
		await process_frame
		await process_frame
		print("P3 validation OK: ", path, " -> ", node.name)
		node.queue_free()
		await process_frame
	print("P3 validation DONE failed=", failed)
	quit(1 if failed > 0 else 0)
