extends SceneTree
## Точечная проверка проходимости: под каждым ключевым спуском/карнизом должен
## быть пол. Печатает, куда попадает луч и на какой высоте.

const SCENES := {
	"pilgrim": "res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn",
	"camp": "res://scenes/locations/caravan_site/caravan_site_art.tscn",
}

const PROBES := {
	"pilgrim": [
		["road_start", Vector3(0, 10, 12)],
		["road_gap", Vector3(0, 10, -2)],
		["landing", Vector3(0, 10, -14)],
		["trail", Vector3(1, 10, -24)],
		["alcove", Vector3(1, 10, -31)],
		["ledge_start", Vector3(1, 12, -37)],
		["ledge_mid", Vector3(1, 12, -41.5)],
		["ledge_end", Vector3(1, 12, -46)],
		["cave_mouth", Vector3(1, 12, -48)],
		["cave_mid", Vector3(1, 12, -51)],
		["cave_deep", Vector3(1, 12, -54)],
		["hero_ledge", Vector3(1, 12, -60)],
	],
	"camp": [
		["fire", Vector3(0.6, 10, 0.5)],
		["wagon", Vector3(2, 10, 2)],
		["veteran", Vector3(4.4, 10, -2.2)],
		["south_exit", Vector3(0, 10, 6)],
	],
}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for key in SCENES:
		var packed := load(SCENES[key]) as PackedScene
		var scene := packed.instantiate() as Node3D
		root.add_child(scene)
		await physics_frame
		await physics_frame
		var space := scene.get_world_3d().direct_space_state
		print("--- ", key, " ", SCENES[key])
		for probe in PROBES[key]:
			var name: String = probe[0]
			var origin: Vector3 = probe[1]
			var query := PhysicsRayQueryParameters3D.create(
				origin, origin + Vector3(0, -30, 0), 1 | 32 | 2 | 4
			)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				print("  %-12s NO FLOOR at %s" % [name, origin])
			else:
				var collider := hit["collider"] as Node
				print(
					"  %-12s y=%.2f  %s"
					% [name, hit["position"].y, collider.get_path() if collider != null else "?"]
				)
		scene.queue_free()
		await process_frame
	quit()
