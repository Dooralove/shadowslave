extends SceneTree
## Read-only geometry/collision probe for the containment room art overlay.
##
## Prints world AABBs for the corridor CSG proxies and the art modules, then
## checks that the CSG proxies still block rays from inside the corridor.
##
## Run:
##   godot --headless --path . -s tools/audit/containment_probe.gd

const SCENE := "res://scenes/slice/locations/containment_room_art.tscn"

const PROXIES := {
	"CorridorFloor": "Geometry/CorridorFloor",
	"CorridorWallL": "Geometry/CorridorWallL",
	"CorridorWallR": "Geometry/CorridorWallR",
	"CorridorEnd": "Geometry/CorridorEnd",
	"CorridorCeiling": "Geometry/CorridorCeiling",
}


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

	print("== PROXIES ==")
	for key in PROXIES:
		var node := scene.get_node_or_null(PROXIES[key]) as CSGBox3D
		if node == null:
			print("%s MISSING" % key)
			continue
		var aabb := _world_aabb(node)
		print("%s pos=%s aabb=%s collision=%s visible=%s" % [
			key, _v(node.global_position), _a(aabb), node.use_collision, node.is_visible_in_tree()
		])

	print("== CORRIDOR ART ==")
	var corridor := scene.get_node_or_null(^"Art/Corridor")
	if corridor == null:
		print("Corridor MISSING")
	else:
		for child in corridor.get_children():
			if child is Node3D:
				var mi := child as Node3D
				var line := "%s pos=%s" % [child.name, _v(mi.global_position)]
				var mesh := mi as MeshInstance3D
				if mesh != null and mesh.mesh != null:
					line += " aabb=%s" % _a(_world_aabb(mesh))
				print(line)

	print("== RAY BLOCKING ==")
	var world: World3D = (scene as Node3D).get_world_3d()
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var failures := 0
	var checks := [
		["left wall", Vector3(0, 1.2, -5.5), Vector3(-4, 1.2, -5.5), "CorridorWallL"],
		["right wall", Vector3(0, 1.2, -5.5), Vector3(4, 1.2, -5.5), "CorridorWallR"],
		["end wall", Vector3(0, 1.2, -5.5), Vector3(0, 1.2, -12), "CorridorEnd"],
		["floor", Vector3(0, 1.0, -5.5), Vector3(0, -2, -5.5), "CorridorFloor"],
	]
	for check in checks:
		var q := PhysicsRayQueryParameters3D.create(check[1], check[2])
		var hit: Dictionary = space.intersect_ray(q)
		var collider_name := ""
		if not hit.is_empty():
			var collider := hit.get("collider") as Node
			if collider != null:
				collider_name = String(collider.name)
		var ok: bool = collider_name == String(check[3])
		if not ok:
			failures += 1
		print("%s -> expected=%s hit=%s ok=%s" % [check[0], check[3], collider_name if collider_name != "" else "none", ok])

	print("== FLOOR COVERAGE ==")
	for point in [Vector3(0, 1.2, 2.6), Vector3(1.2, 1.2, 1.0), Vector3(-1.2, 1.2, 0.0), Vector3(0, 1.2, -1.3)]:
		var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			point, point + Vector3(0, -3, 0)))
		var floor_name := "none"
		if not floor_hit.is_empty():
			var collider := floor_hit.get("collider") as Node
			if collider != null:
				floor_name = String(collider.name)
		print("floor at %s -> %s" % [_v(point), floor_name])
	var holes: Array[String] = []
	var z := -1.0
	while z >= -7.4:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(0, 1.0, z), Vector3(0, -2.0, z)))
		if hit.is_empty():
			holes.append("%.2f" % z)
		z -= 0.1
	print("floor gaps at x=0: %s" % (", ".join(holes) if not holes.is_empty() else "none"))

	print("RESULT failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _world_aabb(node: Node3D) -> AABB:
	var local := AABB()
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		local = mesh.mesh.get_aabb()
	elif node is CSGBox3D:
		var box := node as CSGBox3D
		local = AABB(-box.size * 0.5, box.size)
	else:
		return AABB()
	var xf := node.global_transform
	var out := AABB(xf * local.position, Vector3.ZERO)
	for i in 8:
		var corner := local.position + Vector3(
			local.size.x if (i & 1) else 0.0,
			local.size.y if (i & 2) else 0.0,
			local.size.z if (i & 4) else 0.0
		)
		var p: Vector3 = xf * corner
		out = out.expand(p)
	return out


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _a(a: AABB) -> String:
	return "pos%s size(%.2f, %.2f, %.2f)" % [_v(a.position), a.size.x, a.size.y, a.size.z]
