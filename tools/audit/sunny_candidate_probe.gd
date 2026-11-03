extends SceneTree
## Read-only probe: apply the project UAL library to the generated Sunny v2 rig.
## Loads the GLB through GLTFDocument (no import step), renames the Mixamo-style
## bones to the humanoid names used by UAL tracks, then renders a few poses.
## godot --path . -s tools/audit/sunny_candidate_probe.gd -- --out=<dir>

const GLB := "res://incoming_models/P0_characters/sunny_real_v2_rigged_core10.glb"
const UAL := "res://assets/characters/sunny_realistic_poc/animations/ual_standard.glb"
const IDLE := "res://assets/characters/sunny_realistic_poc/animations/sunny_idle_relaxed.glb"

const BONE_MAP := {
	"Hips": "Hips",
	"Spine": "Spine",
	"Spine1": "Chest",
	"Spine2": "UpperChest",
	"Neck": "Neck",
	"Head": "Head",
	"LeftShoulder": "LeftShoulder",
	"LeftArm": "LeftUpperArm",
	"LeftForeArm": "LeftLowerArm",
	"LeftHand": "LeftHand",
	"LeftHandThumb1": "LeftThumbMetacarpal",
	"LeftHandThumb2": "LeftThumbProximal",
	"LeftHandThumb3": "LeftThumbDistal",
	"LeftHandIndex1": "LeftIndexProximal",
	"LeftHandIndex2": "LeftIndexIntermediate",
	"LeftHandIndex3": "LeftIndexDistal",
	"LeftHandMiddle1": "LeftMiddleProximal",
	"LeftHandMiddle2": "LeftMiddleIntermediate",
	"LeftHandMiddle3": "LeftMiddleDistal",
	"LeftHandRing1": "LeftRingProximal",
	"LeftHandRing2": "LeftRingIntermediate",
	"LeftHandRing3": "LeftRingDistal",
	"LeftHandPinky1": "LeftLittleProximal",
	"LeftHandPinky2": "LeftLittleIntermediate",
	"LeftHandPinky3": "LeftLittleDistal",
	"RightShoulder": "RightShoulder",
	"RightArm": "RightUpperArm",
	"RightForeArm": "RightLowerArm",
	"RightHand": "RightHand",
	"RightHandThumb1": "RightThumbMetacarpal",
	"RightHandThumb2": "RightThumbProximal",
	"RightHandThumb3": "RightThumbDistal",
	"RightHandIndex1": "RightIndexProximal",
	"RightHandIndex2": "RightIndexIntermediate",
	"RightHandIndex3": "RightIndexDistal",
	"RightHandMiddle1": "RightMiddleProximal",
	"RightHandMiddle2": "RightMiddleIntermediate",
	"RightHandMiddle3": "RightMiddleDistal",
	"RightHandRing1": "RightRingProximal",
	"RightHandRing2": "RightRingIntermediate",
	"RightHandRing3": "RightRingDistal",
	"RightHandPinky1": "RightLittleProximal",
	"RightHandPinky2": "RightLittleIntermediate",
	"RightHandPinky3": "RightLittleDistal",
	"LeftUpLeg": "LeftUpperLeg",
	"LeftLeg": "LeftLowerLeg",
	"LeftFoot": "LeftFoot",
	"LeftToeBase": "LeftToes",
	"RightUpLeg": "RightUpperLeg",
	"RightLeg": "RightLowerLeg",
	"RightFoot": "RightFoot",
	"RightToeBase": "RightToes",
}

var _out := ""
var _model: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("need --out=<dir>")
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
	var err := doc.append_from_file(GLB, state)
	if err != OK:
		push_error("GLTF load failed: %s" % err)
		quit(3)
		return
	_model = doc.generate_scene(state) as Node3D
	stage.add_child(_model)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		push_error("no Skeleton3D")
		quit(4)
		return
	_skeleton.name = "GeneralSkeleton"
	_skeleton.unique_name_in_owner = true
	_skeleton.owner = _model
	for bone_name in BONE_MAP:
		var idx := _skeleton.find_bone(bone_name)
		if idx >= 0:
			_skeleton.set_bone_name(idx, BONE_MAP[bone_name])
	print("BONES ", _skeleton.get_bone_count())
	for i in _skeleton.get_bone_count():
		print("  ", i, " ", _skeleton.get_bone_name(i))

	var old_player := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if old_player != null:
		old_player.name = "NativeAnimationPlayer"
	_player = AnimationPlayer.new()
	_player.name = "ProbePlayer"
	_model.add_child(_player)
	_player.root_node = _player.get_path_to(_model)
	var ual := load(UAL) as AnimationLibrary
	var idle := load(IDLE) as AnimationLibrary
	if ual:
		_player.add_animation_library(&"ual", ual)
	if idle:
		_player.add_animation_library(&"sunny", idle)
	print("ANIMS ", _player.get_animation_list())
	for clip in [&"ual/Walk_Loop", &"ual/Sword_Attack", &"ual/Hit_Chest", &"ual/Idle_Loop", &"sunny/Idle_Relaxed_Loop"]:
		if _player.has_animation(clip):
			var anim := _player.get_animation(clip)
			print("TRACKS ", clip, " n=", anim.get_track_count())
			for t in mini(4, anim.get_track_count()):
				print("  ", anim.track_get_path(t))

	_camera = Camera3D.new()
	_camera.fov = 34.0
	_camera.near = 0.05
	_camera.far = 50.0
	stage.add_child(_camera)
	_camera.current = true
	_camera.position = Vector3(1.4, 1.45, 5.6)
	_camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)

	var poses := [
		[&"sunny/Idle_Relaxed_Loop", 0.4, "idle"],
		[&"ual/Walk_Loop", 0.45, "walk"],
		[&"ual/Sprint_Loop", 0.35, "sprint"],
		[&"ual/Sword_Attack", 0.55, "sword_attack"],
		[&"ual/Hit_Chest", 0.18, "hit"],
		[&"ual/Roll", 0.55, "roll"],
	]
	for entry in poses:
		var clip: StringName = entry[0]
		var at: float = entry[1]
		var label: String = entry[2]
		if not _player.has_animation(clip):
			print("MISSING ", clip)
			continue
		_player.play(clip)
		_player.seek(at, true)
		_player.pause()
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		_dump_pose(label)
		root.get_texture().get_image().save_png(_out.path_join("sunny_v2_%s.png" % label))
		print("SHOT ", label)
	quit(0)


func _dump_pose(label: String) -> void:
	if _skeleton == null:
		return
	var hips := _skeleton.find_bone("Hips")
	var lf := _skeleton.find_bone("LeftFoot")
	var rf := _skeleton.find_bone("RightFoot")
	var head := _skeleton.find_bone("Head")
	var values := []
	for idx in [hips, lf, rf, head]:
		if idx >= 0:
			values.append(_skeleton.get_bone_global_pose(idx).origin)
	print("POSE ", label, " hips=", values[0] if values.size() > 0 else "?", " lf=", values[1] if values.size() > 1 else "?", " rf=", values[2] if values.size() > 2 else "?", " head=", values[3] if values.size() > 3 else "?")


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
	env.glow_enabled = true
	env.glow_intensity = 0.18
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
