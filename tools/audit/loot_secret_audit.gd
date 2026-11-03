extends SceneTree
## Read-only audit of placed loot caches in the labyrinth fragment.
##
## Checks that every LootCache under Gameplay/Interactables/Secrets sits on a
## world collision surface (layer 1) and does not overlap a wall at torso height.
## Usage:
##   godot --headless --path . -s tools/audit/loot_secret_audit.gd

const SCENE_PATH := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
const TOLERANCE := 0.35


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("loot_secret_audit: cannot load scene")
		quit(2)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	for _i in 6:
		await process_frame

	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var secrets := scene.get_node_or_null(^"Gameplay/Interactables/Secrets")
	if secrets == null:
		push_error("loot_secret_audit: Secrets node missing")
		quit(2)
		return

	var failures := 0
	var count := 0
	for child in secrets.get_children():
		if not (child is LootCache):
			continue
		count += 1
		var cache := child as LootCache
		var origin := cache.global_position
		var own_body := cache.get_node_or_null(^"StaticBody3D") as StaticBody3D
		var ray := PhysicsRayQueryParameters3D.create(
			origin + Vector3.UP * 3.0,
			origin - Vector3.UP * 6.0,
			1
		)
		if own_body != null:
			ray.exclude = [own_body.get_rid()]
		var hit: Dictionary = space.intersect_ray(ray)
		var ground_y := origin.y
		var delta := 999.0
		if not hit.is_empty():
			ground_y = float(hit.get("position", Vector3.ZERO).y)
			delta = absf(origin.y - ground_y)

		var shape := SphereShape3D.new()
		shape.radius = 0.35
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis.IDENTITY, origin + Vector3.UP * 0.55)
		params.collision_mask = 1
		if own_body != null:
			params.exclude = [own_body.get_rid()]
		var overlaps: Array[Dictionary] = space.intersect_shape(params, 8)

		var ok: bool = delta <= TOLERANCE and overlaps.is_empty()
		if not ok:
			failures += 1
		print(
			"SECRET %s pos=%s ground_y=%.2f delta=%.2f overlaps=%d %s" % [
				cache.name,
				str(origin),
				ground_y,
				delta,
				overlaps.size(),
				"OK" if ok else "CHECK",
			]
		)
	print("LOOT_SECRET_AUDIT count=%d failures=%d" % [count, failures])
	quit(0 if failures == 0 else 1)
