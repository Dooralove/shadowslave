extends SceneTree
## Headless validation of A06 NPC placeholder prefabs.
## godot --headless --path . -s tools/anim/npc_validate.gd

const PREFABS := [
	"res://scenes/characters/npc/jett.tscn",
	"res://scenes/characters/npc/rock.tscn",
	"res://scenes/characters/npc/kasper.tscn",
	"res://scenes/characters/npc/cassia.tscn",
	"res://scenes/characters/npc/nephis.tscn",
	"res://scenes/characters/npc/academy_guard.tscn",
]
const CROWD := "res://scenes/characters/npc/sleeper_crowd.tscn"

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in PREFABS:
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("%s: cannot load" % path)
			continue
		var npc := packed.instantiate() as Node3D
		if npc == null:
			_fail("%s: not Node3D" % path)
			continue
		root.add_child(npc)
		await process_frame
		await process_frame
		var label := String(path.get_file().get_basename())
		await _check(label, npc)
		npc.queue_free()
		await process_frame
	await _check_crowd()
	print("NPC_VALIDATE failed=%d" % _failed)
	quit(1 if _failed > 0 else 0)


func _check_crowd() -> void:
	var packed := load(CROWD) as PackedScene
	if packed == null:
		_fail("sleeper_crowd: cannot load")
		return
	var crowd := packed.instantiate() as Node3D
	root.add_child(crowd)
	await process_frame
	var count := 0
	for child in crowd.get_children():
		var npc := child as Node3D
		if npc == null or not npc.has_method(&"get_animation_player"):
			continue
		count += 1
		var player := npc.call(&"get_animation_player") as AnimationPlayer
		if player == null or player.current_animation == &"":
			_fail("sleeper_crowd: child %s has no animation" % npc.name)
		if not npc.is_in_group(&"placeholder_character"):
			_fail("sleeper_crowd: child %s not marked placeholder" % npc.name)
	if count < 6:
		_fail("sleeper_crowd: expected >=6 Mannequin children, got %d" % count)
	print("NPC sleeper_crowd children=", count)
	crowd.queue_free()
	await process_frame


func _check(label: String, npc: Node3D) -> void:
	var meshes := npc.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		_fail("%s: no MeshInstance3D" % label)
		return
	var player := npc.call(&"get_animation_player") as AnimationPlayer
	if player == null:
		_fail("%s: no AnimationPlayer" % label)
		return
	if not npc.is_in_group(&"placeholder_character"):
		_fail("%s: not in placeholder_character group" % label)
	if npc.get_meta(&"placeholder", false) != true:
		_fail("%s: placeholder meta missing" % label)
	var accessory := npc.get_node_or_null(^"Model/PlaceholderAccessories")
	if label == "cassia" or label == "nephis":
		if accessory == null:
			_fail("%s: placeholder accessory missing" % label)
	else:
		if accessory != null:
			_fail("%s: unexpected placeholder accessory" % label)
	for pose in [&"idle", &"talk", &"point", &"walk", &"leave", &"guard"]:
		npc.set(&"pose", String(pose))
		await process_frame
		var current := player.current_animation
		if current == &"":
			_fail("%s: pose %s has no current animation" % [label, pose])
		else:
			print("NPC ", label, " pose=", pose, " clip=", current)
	print("NPC ", label, " meshes=", meshes.size(), " placeholder=", npc.get(&"placeholder"))


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
