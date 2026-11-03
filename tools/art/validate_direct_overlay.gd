extends Node
## Direct-parent contract check: instance the A03 location first, then add the
## A07 art scene as its child exactly as A03 will in the shipping scene.

const CASES := [
	["P05", "res://scenes/locations/post_nightmare/police_precinct.tscn", "res://scenes/environment/post_nightmare/police_precinct_art.tscn"],
	["P06", "res://scenes/locations/post_nightmare/academy_approach.tscn", "res://scenes/environment/post_nightmare/academy_approach_art.tscn"],
	["P07", "res://scenes/locations/post_nightmare/academy_gate.tscn", "res://scenes/environment/post_nightmare/academy_gate_art.tscn"],
	["P08", "res://scenes/locations/post_nightmare/academy_campus.tscn", "res://scenes/environment/post_nightmare/academy_campus_art.tscn"],
	["P09", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", "res://scenes/environment/post_nightmare/academy_sleeper_center_art.tscn"],
	["B01", "res://scenes/locations/post_nightmare/black_sea_platform.tscn", "res://scenes/environment/post_nightmare/black_sea_platform_art.tscn"],
	["B02", "res://scenes/locations/post_nightmare/tide_descent.tscn", "res://scenes/environment/post_nightmare/tide_descent_art.tscn"],
]


func _ready() -> void:
	var failures: Array[String] = []
	for entry in CASES:
		var loc_scene := load(String(entry[1])) as PackedScene
		var art_scene := load(String(entry[2])) as PackedScene
		if loc_scene == null or art_scene == null:
			failures.append(String(entry[0]) + " scene load failed")
			continue
		var location := loc_scene.instantiate() as Node3D
		add_child(location)
		await get_tree().process_frame
		var art := art_scene.instantiate() as Node3D
		art.name = "ArtOverlay"
		location.add_child(art)
		await get_tree().process_frame
		await get_tree().process_frame
		var applied := bool(art.get_meta(&"art_profile_applied", false))
		print("A07_DIRECT %s applied=%s" % [entry[0], str(applied)])
		if not applied:
			failures.append(String(entry[0]) + " direct overlay not applied")
		location.queue_free()
		await get_tree().process_frame
	print("A07_DIRECT_DONE failures=%d" % failures.size())
	for failure in failures:
		print("A07_DIRECT_FAIL " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)
