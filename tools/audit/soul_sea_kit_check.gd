extends SceneTree
## Read-only проверка кита Моря Души: все GLB загружаются, меши и материалы на месте.

const KIT := "res://assets/environments/soul_sea/kit/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := DirAccess.open(KIT)
	if dir == null:
		push_error("soul_sea_kit_check: нет каталога " + KIT)
		quit(1)
		return
	var names: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".glb"):
			names.append(f)
	names.sort()
	var bad := 0
	var external := 0
	for f in names:
		var path := KIT + f
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("soul_sea_kit_check: не загрузился " + path)
			bad += 1
			continue
		var inst := packed.instantiate()
		root.add_child(inst)
		await process_frame
		var meshes := inst.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			push_error("soul_sea_kit_check: нет мешей " + path)
			bad += 1
		for m in meshes:
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				push_error("soul_sea_kit_check: пустой mesh " + path)
				bad += 1
				continue
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s)
				if mat == null:
					push_error("soul_sea_kit_check: нет материала %s surface %d" % [path, s])
					bad += 1
				elif not mat.resource_path.is_empty():
					external += 1
		inst.queue_free()
		await process_frame
	print("soul_sea_kit_check: checked=", names.size(), " bad=", bad, " external_materials=", external)
	quit(1 if bad > 0 else 0)
