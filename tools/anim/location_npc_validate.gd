extends SceneTree
## Verify that existing A03 location spawners pick up A06 context profiles.
## godot --headless --path . -s tools/anim/location_npc_validate.gd

const CASES := [
	["academy_approach", "res://scenes/locations/post_nightmare/academy_approach.tscn", [
		["Jet", false, "none"],
		["CheckpointGuard", false, "none"],
	]],
	["academy_gate", "res://scenes/locations/post_nightmare/academy_gate.tscn", [
		["GateGuard", false, "none"],
	]],
	["academy_sleeper_center", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", [
		["InductionMedic", false, "none"],
		["Julius", false, "none"],
	]],
	["academy_campus", "res://scenes/locations/post_nightmare/academy_campus.tscn", [
		["CampusGuide", false, "none"],
	]],
]

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for entry in CASES:
		var label: String = entry[0]
		var path: String = entry[1]
		var checks: Array = entry[2]
		var scene := (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		for check in checks:
			var node_name: String = check[0]
			var expect_accessory: String = check[2]
			var npc := scene.find_child(node_name, true, false) as Mannequin
			if npc == null:
				_fail("%s: %s missing" % [label, node_name])
				continue
			if npc.uniform_color.is_equal_approx(Color(1, 1, 1, 1)):
				_fail("%s: %s has default uniform (context profile not applied)" % [label, node_name])
			if expect_accessory != "none" and npc.accessory != expect_accessory:
				_fail("%s: %s accessory=%s expected=%s" % [label, node_name, npc.accessory, expect_accessory])
			print("LOCATION_NPC ", label, " ", node_name, " uniform=", npc.uniform_color, " accessory=", npc.accessory)
		scene.queue_free()
		await process_frame
	await _check_labyrinth()
	print("LOCATION_NPC_VALIDATE failed=", _failed)
	quit(1 if _failed > 0 else 0)


func _check_labyrinth() -> void:
	var scene := (load("res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for node_name in ["NPC_Nephis", "NPC_Cassia"]:
		var parent := scene.find_child(node_name, true, false)
		if parent == null:
			_fail("labyrinth: %s missing" % node_name)
			continue
		var npc := parent.get_node_or_null(^"Mannequin") as Mannequin
		if npc == null:
			_fail("labyrinth: %s/Mannequin missing" % node_name)
			continue
		if npc.uniform_color.is_equal_approx(Color(1, 1, 1, 1)):
			_fail("labyrinth: %s has default uniform" % node_name)
		var expected := "blindfold" if node_name.ends_with("Cassia") else "spear_cloak"
		if npc.accessory != expected:
			_fail("labyrinth: %s accessory=%s expected=%s" % [node_name, npc.accessory, expected])
		print("LOCATION_NPC labyrinth ", node_name, " uniform=", npc.uniform_color, " accessory=", npc.accessory)
	scene.queue_free()
	await process_frame


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
