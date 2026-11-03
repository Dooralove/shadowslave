extends SceneTree
## Read-only material audit for the generated armour GLBs.

const PATHS := [
	"res://assets/characters/equipment/armor/scout_leather.glb",
	"res://assets/characters/equipment/armor/mercenary_medium.glb",
	"res://assets/characters/equipment/armor/heavy_plate.glb",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in PATHS:
		var packed := load(path) as PackedScene
		if packed == null:
			print("MISSING ", path)
			continue
		var instance := packed.instantiate()
		root.add_child(instance)
		await process_frame
		print("== ", path)
		for node in instance.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var material := mesh.get_active_material(0)
			print("  mesh ", mesh.name, " surfaces ", mesh.mesh.get_surface_count() if mesh.mesh else -1,
				" material ", material.get_class() if material else "null")
			if material is BaseMaterial3D:
				var base := material as BaseMaterial3D
				print("    albedo_texture ", base.albedo_texture)
				print("    normal_enabled ", base.normal_enabled, " normal_texture ", base.normal_texture)
				print("    metallic ", base.metallic, " roughness ", base.roughness)
				print("    metallic_texture ", base.metallic_texture)
				print("    roughness_texture ", base.roughness_texture)
				print("    cull_mode ", base.cull_mode, " transparency ", base.transparency,
					" shading_mode ", base.shading_mode)
				print("    texture_filter ", base.texture_filter)
		instance.queue_free()
		await process_frame
	quit(0)
