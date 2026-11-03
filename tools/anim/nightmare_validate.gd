extends SceneTree
## Validate the M1/M2 Sunny Nightmare variant (v2 model, LOD, clip map).
## godot --headless --path . -s tools/anim/nightmare_validate.gd

const SCENE := "res://assets/characters/p1/sunny_waking_nightmare.tscn"

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var node := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(node)
	await process_frame
	await process_frame
	var player := node.get_node_or_null(^"Visual/ModelPoc/Model/AnimationPlayer") as AnimationPlayer
	if player == null:
		_fail("nightmare: ModelPoc AnimationPlayer missing")
	else:
		var clips := player.get_animation_list()
		if clips.size() < 10:
			_fail("nightmare: expected >=10 clips, got %d" % clips.size())
		if not player.has_animation(&"HumanStandingIdle"):
			_fail("nightmare: HumanStandingIdle missing")
		if not player.has_animation(&"WalkClean"):
			_fail("nightmare: WalkClean missing")
		print("NIGHTMARE player clips=", clips.size())
	var lod := node.get_node_or_null(^"Visual/ModelPoc/Model/LodVisibility")
	if lod == null:
		_fail("nightmare: LodVisibility missing")
	var meshes := node.get_node(^"Visual/ModelPoc/Model").find_children("*", "MeshInstance3D", true, false)
	var lod1 := 0
	var lod2 := 0
	for m in meshes:
		var n := String((m as MeshInstance3D).name).to_lower()
		if n.contains("_lod1") or n.contains("lod1_"):
			lod1 += 1
		elif n.contains("_lod2") or n.contains("lod2_"):
			lod2 += 1
	if lod1 < 1 or lod2 < 1:
		_fail("nightmare: LOD meshes missing (lod1=%d lod2=%d)" % [lod1, lod2])
	var actor := node.get_node_or_null(^"CinematicActor") as CinematicActor
	if actor == null:
		_fail("nightmare: CinematicActor missing")
	else:
		for action in [&"sleep", &"equip", &"shroud", &"sit_idle", &"stand_up"]:
			if not actor.has_action(action):
				_fail("nightmare: action %s has no clip" % action)
	var model_poc := node.get_node_or_null(^"Visual/ModelPoc")
	var socket: BoneAttachment3D = null
	if model_poc != null and model_poc.has_method(&"get_weapon_socket"):
		socket = model_poc.call(&"get_weapon_socket") as BoneAttachment3D
	if socket == null:
		_fail("nightmare: weapon socket missing")
	elif socket.get_node_or_null(^"Weapon") == null:
		_fail("nightmare: weapon mesh missing")
	var combat := node.get_node_or_null(^"CombatController")
	if combat != null and socket != null:
		combat.call(&"set_unarmed", false)
		if not socket.visible:
			_fail("nightmare: armed mode does not show weapon socket")
		combat.call(&"set_unarmed", true)
		if socket.visible:
			_fail("nightmare: unarmed mode still shows weapon socket")
	print("NIGHTMARE_VALIDATE failed=", _failed)
	quit(1 if _failed > 0 else 0)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
