extends SceneTree
## Read-only collision probe for the three stealth covers in the pilgrim path.
## Confirms that the hidden CSG collision proxies still block the volume that
## the visual cover occupies.
##
## CSG collision is a surface, not a solid, so a point/sphere query at the
## centre can miss it. Ray queries through the volume are the reliable test.
##
## Run:
##   godot --headless --path . -s tools/audit/stealth_cover_collision_probe.gd

const SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn"
const COVERS := [
	"StealthSection/Covers/CoverWest",
	"StealthSection/Covers/CoverEast",
	"StealthSection/Covers/CoverEdge",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		push_error("cannot load " + SCENE)
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 12:
		await physics_frame

	var failures := 0
	for path in COVERS:
		var cover := scene.get_node_or_null(path) as Node3D
		if cover == null:
			printerr("MISSING ", path)
			failures += 1
			continue
		var center := cover.global_position + Vector3(0, 0.7, 0)
		var hits_cover := false
		var colliders: Array[String] = []
		for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3.DOWN]:
			var q := PhysicsRayQueryParameters3D.create(center - dir * 3.0, center + dir * 3.0)
			var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(q)
			if hit.is_empty():
				continue
			var collider := hit.get("collider") as Node
			if collider != null:
				colliders.append(String(collider.name))
				if collider == cover:
					hits_cover = true
		print("%s blocked_by_its_own_collision=%s colliders=%s" % [path, hits_cover, colliders])
		if not hits_cover:
			failures += 1
	print("RESULT failures=%d" % failures)
	quit(0 if failures == 0 else 1)
