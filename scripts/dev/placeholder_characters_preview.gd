extends Node3D
## Сцена осмотра типовых NPC-заглушек (инструмент проверки, не игровой путь): все архетипы в ряд,
## позы, всадник на лошади, печать габаритов.
##
## Захват кадров и выход:
##   godot --path . res://scenes/dev/placeholder_characters_preview.tscn -- --capture=<абсолютная папка>

const MANNEQUIN := preload("res://scenes/slice/props/mannequin.tscn")
const HORSE := preload("res://scenes/slice/props/horse.tscn")
const ARCHETYPES := ["townsman", "townswoman", "police", "slave", "knight"]

var _shots: Array[Camera3D] = []


func _ready() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(40, 40)
	add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.38)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)

	for i in ARCHETYPES.size():
		_figure(ARCHETYPES[i], "idle", Vector3(i * 1.0 - 2.0, 0, 0))
	for i in ["talk", "guard", "kneel", "dead"].size():
		_figure("slave", ["talk", "guard", "kneel", "dead"][i], Vector3(i * 1.2 - 1.8, 0, 3))

	# Всадник: как в сценах — корень на высоте седла, лошадь дочерним узлом у земли.
	var rider := _figure("knight", "ride", Vector3(4.5, 0.9, 0.5))
	var horse := HORSE.instantiate() as Node3D
	horse.position = Vector3(0, -0.9, 0)
	rider.add_child(horse)
	var white := HORSE.instantiate() as Node3D
	white.set("coat_color", Color(0.85, 0.83, 0.78))
	white.set("pose", "walk")
	white.position = Vector3(7, 0, 0.5)
	add_child(white)

	_shot(Vector3(1.5, 1.4, -6.0), Vector3(1.5, 0.9, 0), 50)
	_shot(Vector3(8.5, 1.6, -2.5), Vector3(5, 1.0, 0.5), 50)
	_shot(Vector3(0.0, 1.6, 6.5), Vector3(0, 0.6, 3), 50)
	_report.call_deferred()
	var capture := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			capture = a.trim_prefix("--capture=")
	if capture != "":
		_capture.call_deferred(capture)


func _figure(archetype: String, pose: String, pos: Vector3) -> Node3D:
	var m := MANNEQUIN.instantiate() as Node3D
	m.set("archetype", archetype)
	m.set("pose", pose)
	m.position = pos
	m.name = "%s_%s" % [archetype, pose]
	add_child(m)
	return m


func _report() -> void:
	for node in get_children():
		if node is Mannequin or node is HorsePlaceholder:
			var box := AABB()
			for mesh in node.find_children("*", "MeshInstance3D", true, false):
				var b := (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
				box = b if box.size == Vector3.ZERO else box.merge(b)
			print("PLACEHOLDER ", node.name, " aabb_pos=", box.position, " size=", box.size)


func _shot(from: Vector3, to: Vector3, fov: float) -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = from
	cam.look_at(to)
	cam.fov = fov
	_shots.append(cam)
	if _shots.size() == 1:
		cam.current = true


func _capture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for i in _shots.size():
		_shots[i].current = true
		for _f in 40:
			await get_tree().process_frame
		var path := folder.path_join("placeholder_characters_%d.png" % i)
		get_viewport().get_texture().get_image().save_png(path)
		print("PLACEHOLDER captured ", path)
	get_tree().quit()
