extends SceneTree
## A06 NPC placeholder lineup and close-up capture.
## godot --path . -s tools/anim/npc_lineup_capture.gd -- --out=<dir>

const PREFABS := [
	["jett", "res://scenes/characters/npc/jett.tscn"],
	["rock", "res://scenes/characters/npc/rock.tscn"],
	["kasper", "res://scenes/characters/npc/kasper.tscn"],
	["cassia", "res://scenes/characters/npc/cassia.tscn"],
	["nephis", "res://scenes/characters/npc/nephis.tscn"],
	["academy_guard", "res://scenes/characters/npc/academy_guard.tscn"],
]

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("npc_lineup_capture: missing --out=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	root.add_child(stage)
	_add_environment(stage)
	_add_floor(stage)
	_add_lights(stage)
	var actors: Array[Node3D] = []
	for i in PREFABS.size():
		var entry: Array = PREFABS[i]
		var npc := (load(String(entry[1])) as PackedScene).instantiate() as Node3D
		npc.position = Vector3((i - 2) * 0.95, 0, 0)
		stage.add_child(npc)
		actors.append(npc)
		await process_frame
	await process_frame
	await process_frame
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 60.0
	stage.add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 1.45, -8.0)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("npc_lineup.png"))
	print("SHOT npc_lineup")

	for i in PREFABS.size():
		var entry: Array = PREFABS[i]
		var label := String(entry[0])
		var npc := actors[i]
		var poses: Array[String] = ["idle", "talk", "point"]
		if label == "cassia":
			poses = ["listen", "head_turn", "talk"]
		elif label == "nephis":
			poses = ["guard", "walk", "idle"]
		for pose in poses:
			npc.set(&"pose", pose)
			cam.position = npc.global_position + Vector3(0.35, 1.4, -3.1)
			cam.look_at(npc.global_position + Vector3(0, 1.0, 0), Vector3.UP)
			for f in 16:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [label, pose]))
			print("SHOT ", label, " ", pose)
		npc.set(&"pose", "idle" if label != "cassia" else "listen")
		if label == "nephis":
			npc.set(&"pose", "guard")
	quit(0)


func _add_environment(stage: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.4, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.4
	var node := WorldEnvironment.new()
	node.environment = env
	stage.add_child(node)


func _add_floor(stage: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 8)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.15)
	mat.roughness = 0.82
	floor.material_override = mat
	stage.add_child(floor)


func _add_lights(stage: Node3D) -> void:
	_add_spot(stage, Vector3(-3.5, 3.6, 2.8), Vector3(0, 1.2, 0), Color(1.0, 0.92, 0.82), 12.0, 12.0, 45.0, true)
	_add_spot(stage, Vector3(3.2, 2.6, 2.4), Vector3(0, 1.2, 0), Color(0.48, 0.64, 1.0), 5.0, 9.0, 45.0, false)
	_add_spot(stage, Vector3(0.4, 3.2, -2.2), Vector3(0, 1.4, 0), Color(0.62, 0.72, 1.0), 7.0, 9.0, 40.0, false)


func _add_spot(stage: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float, range_m: float, angle: float, shadows: bool) -> void:
	var light := SpotLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = angle
	light.shadow_enabled = shadows
	stage.add_child(light)
	light.look_at(target, Vector3.UP)
