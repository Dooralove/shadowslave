extends SceneTree
## Проверка и снимки колосса безголового рыцаря в Godot.
## Запуск (нужен рендер, без --headless):
##   godot --path . -s tools/audit/statue_colossus_preview.gd -- --out=C:/Users/user/AppData/Local/Temp/opencode/statue_shots
##
## Скрипт только читает GLB; сцены/ресурсы не меняет.

const GLB := "res://assets/environments/nightmare/statue/statue_knight_colossus.glb"
const MAT_DIR := "res://assets/environments/nightmare/materials/"
const MATERIALS := {
	"nm_statue_dark": "nm_statue_dark.tres",
	"nm_statue_pale": "nm_statue_pale.tres",
	"nm_statue_bronze": "nm_statue_bronze.tres",
	"nm_statue_crack": "nm_statue_crack.tres",
	"nm_statue_star": "nm_statue_star.tres",
}

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1280, 720)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.085, 0.095, 0.115)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.60, 0.66)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_intensity = 1.3
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.12, 0.16)
	env.fog_density = 0.00035
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -34, 0)
	sun.light_color = Color(0.96, 0.93, 0.86)
	sun.light_energy = 5.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	root.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 145, 0)
	rim.light_color = Color(0.48, 0.62, 0.92)
	rim.light_energy = 2.2
	rim.shadow_enabled = false
	root.add_child(rim)

	var packed := load(GLB) as PackedScene
	if packed == null:
		push_error("statue preview: cannot load " + GLB)
		quit(2)
		return
	var statue := packed.instantiate() as Node3D
	root.add_child(statue)
	_bind_materials(statue)
	_print_stats(statue)

	# Человеческий масштаб на площадке-шее.
	var scale_ref := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	scale_ref.mesh = capsule
	var ref_mat := StandardMaterial3D.new()
	ref_mat.albedo_color = Color(0.82, 0.74, 0.62)
	ref_mat.roughness = 0.75
	scale_ref.material_override = ref_mat
	scale_ref.position = Vector3(2.1, 0.875, 0.0)
	root.add_child(scale_ref)

	# Чёрное море.
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	water.mesh = plane
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.004, 0.008, 0.014)
	wmat.metallic = 0.25
	wmat.roughness = 0.08
	water.material_override = wmat
	water.position = Vector3(0, -72, 0)
	root.add_child(water)
	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(700, 700)
	floor_mesh.mesh = floor_plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.14, 0.135, 0.13)
	fmat.roughness = 0.82
	floor_mesh.material_override = fmat
	floor_mesh.position = Vector3(0, -202.7, 0)
	root.add_child(floor_mesh)

	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 4000.0
	root.add_child(cam)
	cam.make_current()

	# Полный вид: спереди-сбоку, ноги на постаменте.
	water.visible = false
	floor_mesh.visible = true
	cam.position = Vector3(100, -35, -330)
	cam.look_at(Vector3(0, -100, 0), Vector3.UP)
	await _save("statue_godot_full.png")

	# Чёрное море: только верхняя часть над водой.
	water.visible = true
	floor_mesh.visible = false
	cam.position = Vector3(0, -18, -175)
	cam.look_at(Vector3(0, -30, 0), Vector3.UP)
	await _save("statue_godot_black_sea.png")

	# Площадка-шея и человеческий масштаб.
	water.visible = false
	floor_mesh.visible = true
	cam.position = Vector3(8.0, 4.0, -11.5)
	cam.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	await _save("statue_godot_neck.png")

	# Грудь и семь звёзд.
	cam.position = Vector3(18.0, -22.0, -48.0)
	cam.look_at(Vector3(0, -32, 0), Vector3.UP)
	await _save("statue_godot_chest.png")

	print("statue_colossus_preview: saved ", _out)
	quit(0)


func _bind_materials(root_node: Node) -> void:
	var cache := {}
	for key in MATERIALS.keys():
		cache[key] = load(MAT_DIR + MATERIALS[key])
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				for i in mi.mesh.get_surface_count():
					var mat := mi.mesh.surface_get_material(i)
					var key := mat.resource_name if mat != null else ""
					if cache.has(key):
						mi.set_surface_override_material(i, cache[key])
					else:
						push_warning("statue preview: unbind surface %d material '%s'" % [i, key])
		for c in n.get_children():
			stack.append(c)


func _print_stats(root_node: Node) -> void:
	var stack: Array[Node] = [root_node]
	var tris := 0
	var surfaces := 0
	var aabb := AABB()
	var first := true
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				for i in mi.mesh.get_surface_count():
					surfaces += 1
					var arr := mi.mesh.surface_get_arrays(i)
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
					if idx.size() > 0:
						tris += idx.size() / 3
				var box := mi.get_aabb()
				if first:
					aabb = box
					first = false
				else:
					aabb = aabb.merge(box)
		for c in n.get_children():
			stack.append(c)
	print("statue preview stats: surfaces=", surfaces, " tris=", tris, " aabb=", aabb)


func _save(file_name: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(file_name))
