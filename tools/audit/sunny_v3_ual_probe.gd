extends SceneTree
## Probe: apply the project UAL library to the cleaned Sunny v3 rig.

const GLB := "res://assets/characters/generated/sunny_real_v3/sunny_real_v3_clean.glb"
const UAL := "res://assets/characters/sunny_realistic_poc/animations/ual_standard.glb"
const IDLE := "res://assets/characters/sunny_realistic_poc/animations/sunny_idle_relaxed.glb"

const BONE_MAP := {
	"Hips": "Hips", "Spine": "Spine", "Spine1": "Chest", "Spine2": "UpperChest",
	"Neck": "Neck", "Head": "Head",
	"LeftShoulder": "LeftShoulder", "LeftArm": "LeftUpperArm", "LeftForeArm": "LeftLowerArm", "LeftHand": "LeftHand",
	"LeftHandThumb1": "LeftThumbMetacarpal", "LeftHandThumb2": "LeftThumbProximal", "LeftHandThumb3": "LeftThumbDistal",
	"LeftHandIndex1": "LeftIndexProximal", "LeftHandIndex2": "LeftIndexIntermediate", "LeftHandIndex3": "LeftIndexDistal",
	"LeftHandMiddle1": "LeftMiddleProximal", "LeftHandMiddle2": "LeftMiddleIntermediate", "LeftHandMiddle3": "LeftMiddleDistal",
	"LeftHandRing1": "LeftRingProximal", "LeftHandRing2": "LeftRingIntermediate", "LeftHandRing3": "LeftRingDistal",
	"LeftHandPinky1": "LeftLittleProximal", "LeftHandPinky2": "LeftLittleIntermediate", "LeftHandPinky3": "LeftLittleDistal",
	"RightShoulder": "RightShoulder", "RightArm": "RightUpperArm", "RightForeArm": "RightLowerArm", "RightHand": "RightHand",
	"RightHandThumb1": "RightThumbMetacarpal", "RightHandThumb2": "RightThumbProximal", "RightHandThumb3": "RightThumbDistal",
	"RightHandIndex1": "RightIndexProximal", "RightHandIndex2": "RightIndexIntermediate", "RightHandIndex3": "RightIndexDistal",
	"RightHandMiddle1": "RightMiddleProximal", "RightHandMiddle2": "RightMiddleIntermediate", "RightHandMiddle3": "RightMiddleDistal",
	"RightHandRing1": "RightRingProximal", "RightHandRing2": "RightRingIntermediate", "RightHandRing3": "RightRingDistal",
	"RightHandPinky1": "RightLittleProximal", "RightHandPinky2": "RightLittleIntermediate", "RightHandPinky3": "RightLittleDistal",
	"LeftUpLeg": "LeftUpperLeg", "LeftLeg": "LeftLowerLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToes",
	"RightUpLeg": "RightUpperLeg", "RightLeg": "RightLowerLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToes",
}

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(900, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	_add_environment(stage)
	_add_floor(stage)
	_add_lights(stage)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(GLB, state) != OK:
		quit(3)
		return
	var model := doc.generate_scene(state) as Node3D
	model.position.y = 0.95
	stage.add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	skeleton.name = "GeneralSkeleton"
	skeleton.unique_name_in_owner = true
	skeleton.owner = model
	for bone_name in BONE_MAP:
		var idx := skeleton.find_bone(bone_name)
		if idx >= 0:
			skeleton.set_bone_name(idx, BONE_MAP[bone_name])
	var old_player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if old_player:
		old_player.name = "NativeAnimationPlayer"
	var player := AnimationPlayer.new()
	player.name = "UalPlayer"
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"ual", load(UAL))
	player.add_animation_library(&"sunny", load(IDLE))
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.05
	cam.far = 50.0
	stage.add_child(cam)
	cam.current = true
	cam.position = Vector3(1.6, 1.55, -5.4)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	for entry in [[&"sunny/Idle_Relaxed", 0.5, "idle"], [&"ual/Walk", 0.5, "walk"], [&"ual/Sprint", 0.3, "sprint"], [&"ual/Sword_Attack", 0.55, "attack"], [&"ual/Hit_Chest", 0.16, "hit"]]:
		var clip: StringName = entry[0]
		var at: float = entry[1]
		var label: String = entry[2]
		if not player.has_animation(clip):
			print("MISSING ", clip)
			continue
		player.play(clip)
		player.seek(at, true)
		player.pause()
		for i in 4:
			await process_frame
		var hips := skeleton.find_bone("Hips")
		var lf := skeleton.find_bone("LeftFoot")
		print("POSE ", label, " hips=", skeleton.get_bone_global_pose(hips).origin, " lf=", skeleton.get_bone_global_pose(lf).origin)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("v3ual_%s.png" % label))
		print("SHOT ", label)
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
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.3
	var node := WorldEnvironment.new()
	node.environment = env
	stage.add_child(node)


func _add_floor(stage: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.15)
	mat.roughness = 0.82
	floor.material_override = mat
	stage.add_child(floor)


func _add_lights(stage: Node3D) -> void:
	_add_spot(stage, Vector3(-2.7, 3.5, 3.0), Vector3(0, 1.2, 0), Color(1.0, 0.92, 0.82), 10.0, 10.0, 45.0, true)
	_add_spot(stage, Vector3(2.8, 2.2, 2.7), Vector3(0, 1.2, 0), Color(0.48, 0.64, 1.0), 4.0, 8.0, 45.0, false)
	_add_spot(stage, Vector3(0.4, 3.1, -2.0), Vector3(0, 1.4, 0), Color(0.62, 0.72, 1.0), 6.0, 8.0, 40.0, false)


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
