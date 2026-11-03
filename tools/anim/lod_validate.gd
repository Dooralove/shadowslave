extends SceneTree
## Headless verification that LOD copies are imported and hidden at LOD0.
## godot --headless --path . -s tools/anim/lod_validate.gd

const CASES := [
	["sunny_v3", "res://assets/characters/generated/sunny_real_v3/sunny_real_v3.tscn", "Model"],
	["sunny_nightmare_v2", "res://assets/characters/generated/sunny_nightmare_v2/sunny_nightmare_v2.tscn", "Model"],
	["hero_v6", "res://assets/characters/generated/hero_auro_v6/hero_auro_v6.tscn", "Model"],
	["carapace", "res://scenes/enemies/carapace_enemy.tscn", "Visual/Model"],
	["mountain_king", "res://scenes/characters/mountain_king.tscn", "Visual/Model"],
]

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for entry in CASES:
		var label: String = entry[0]
		var path: String = entry[1]
		var lod_parent_path: String = entry[2]
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("%s: cannot load %s" % [label, path])
			continue
		var node := packed.instantiate() as Node3D
		root.add_child(node)
		await process_frame
		await process_frame
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		var lod1 := 0
		var lod2 := 0
		var lod0 := 0
		var icosphere := 0
		for m in meshes:
			var mesh := m as MeshInstance3D
			var n := String(mesh.name).to_lower()
			if n.contains("_lod2") or n.contains("lod2_"):
				lod2 += 1
				if mesh.visible:
					_fail("%s: LOD2 visible at start (%s)" % [label, mesh.name])
			elif n.contains("_lod1") or n.contains("lod1_"):
				lod1 += 1
				if mesh.visible:
					_fail("%s: LOD1 visible at start (%s)" % [label, mesh.name])
			else:
				lod0 += 1
			if n.contains("icosphere"):
				icosphere += 1
		if lod1 < 1 or lod2 < 1:
			_fail("%s: missing LOD meshes (lod0=%d lod1=%d lod2=%d)" % [label, lod0, lod1, lod2])
		if icosphere > 0:
			_fail("%s: Icosphere helper still present" % label)
		var lod_node := node.get_node_or_null(NodePath(lod_parent_path + "/LodVisibility"))
		if lod_node == null:
			_fail("%s: CharacterLodVisibility missing under %s" % [label, lod_parent_path])
		var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clips := player.get_animation_list().size() if player != null else 0
		print("LOD ", label, " lod0=", lod0, " lod1=", lod1, " lod2=", lod2, " clips=", clips)
		node.queue_free()
		await process_frame
	await _check_mannequin_hero()
	print("LOD_VALIDATE failed=%d" % _failed)
	quit(1 if _failed > 0 else 0)


func _check_mannequin_hero() -> void:
	var mannequin := (load("res://scenes/slice/props/mannequin.tscn") as PackedScene).instantiate() as Mannequin
	mannequin.archetype = "hero"
	root.add_child(mannequin)
	await process_frame
	await process_frame
	var lod_nodes: Array[CharacterLodVisibility] = []
	for child in mannequin.find_children("*", "Node", true, false):
		if child is CharacterLodVisibility:
			lod_nodes.append(child)
	if lod_nodes.size() != 1:
		_fail("hero mannequin: expected 1 LOD component, got %d" % lod_nodes.size())
	else:
		print("LOD hero_mannequin components=1 lod1=", lod_nodes[0].lod1_distance, " lod2=", lod_nodes[0].lod2_distance)
	mannequin.queue_free()
	await process_frame


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
