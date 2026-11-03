class_name AnimationLab
extends Node3D
## Изолированная лаборатория анимации: P1-модель, UAL + Rokoko-библиотеки,
## AnimationTree и тестовый weapon socket. Не влияет на игровые сцены.

@export var model_path := NodePath("Model")
@export var camera_path := NodePath("Camera3D")

var model: Node3D
var player: AnimationPlayer
var tree: AnimationTree
var skeleton: Skeleton3D
var playback: AnimationNodeStateMachinePlayback
var speed := 0.0
var current := "Locomotion"

const ROKOKO_LIB := preload("res://assets/characters/animation_library/rokoko_library.tres")


func _ready() -> void:
	model = get_node(model_path) as Node3D
	if model == null:
		push_error("AnimationLab: не найдена модель " + str(model_path))
		return
	player = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null:
		push_error("AnimationLab: у модели нет AnimationPlayer")
		return
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_error("AnimationLab: у модели нет Skeleton3D")
		return
	skeleton = skeletons[0] as Skeleton3D
	add_rokoko_library()
	add_weapon_socket()
	build_tree()
	_update_camera()


func _process(delta: float) -> void:
	if tree == null:
		return
	if Input.is_key_pressed(KEY_W):
		speed = minf(speed + delta * 1.5, 1.0)
	elif Input.is_key_pressed(KEY_S):
		speed = maxf(speed - delta * 1.5, 0.0)
	if current == "Locomotion":
		tree.set("parameters/Locomotion/blend_position", speed)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			travel("Locomotion")
		KEY_2:
			travel("Combat")
		KEY_3:
			travel("RokokoWalk")
		KEY_4:
			travel("Knife02")
		KEY_L:
			print("LAB state=", current, " speed=", speed, " anim=", player.current_animation, " pos=", player.current_animation_position)
		KEY_R:
			speed = 0.0
			travel("Locomotion")


func travel(state: StringName) -> void:
	if playback == null:
		return
	playback.travel(state)
	current = String(state)
	if state == "Combat" and player != null:
		player.speed_scale = 1.0
	if state == "RokokoWalk" and player != null:
		player.speed_scale = 1.0


func add_rokoko_library() -> void:
	if player == null or ROKOKO_LIB == null:
		return
	if player.has_animation_library(&"rokoko"):
		player.remove_animation_library(&"rokoko")
	player.add_animation_library(&"rokoko", ROKOKO_LIB)


func add_weapon_socket() -> void:
	if skeleton == null:
		return
	var socket := skeleton.get_node_or_null("WeaponSocket") as BoneAttachment3D
	if socket == null:
		socket = BoneAttachment3D.new()
		socket.name = "WeaponSocket"
		# P1/MPFB использует humanoid-имена; hand_r — это имя из другого рига.
		socket.bone_name = &"RightHand"
		skeleton.add_child(socket)
	if socket.get_node_or_null("DebugWeapon") != null:
		return
	var debug := MeshInstance3D.new()
	debug.name = "DebugWeapon"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 0.42)
	debug.mesh = mesh
	debug.position = Vector3(0, 0.02, -0.16)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.52, 0.58)
	mat.metallic = 0.7
	mat.roughness = 0.35
	debug.material_override = mat
	socket.add_child(debug)


func build_tree() -> void:
	if player == null:
		return
	var sm := AnimationNodeStateMachine.new()
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 1.0
	locomotion.add_blend_point(_node(&"sunny/Idle_Relaxed"), 0.0, -1, &"Idle")
	locomotion.add_blend_point(_node(&"Walk"), 0.35, -1, &"Walk")
	locomotion.add_blend_point(_node(&"Sprint"), 1.0, -1, &"Sprint")
	sm.add_node(&"Locomotion", locomotion, Vector2(0, 0))

	var combat := _node(&"Sword_Attack")
	sm.add_node(&"Combat", combat, Vector2(360, -120))
	var walk := _node(&"rokoko/Walk_Forward")
	sm.add_node(&"RokokoWalk", walk, Vector2(360, 80))
	var knife2 := _node(&"rokoko/Knife_Stab_02")
	sm.add_node(&"Knife02", knife2, Vector2(360, 260))

	_add_transition(sm, &"Locomotion", &"Combat", 0.08)
	_add_transition(sm, &"Combat", &"Locomotion", 0.15)
	_add_transition(sm, &"Locomotion", &"RokokoWalk", 0.15)
	_add_transition(sm, &"RokokoWalk", &"Locomotion", 0.15)
	_add_transition(sm, &"Locomotion", &"Knife02", 0.08)
	_add_transition(sm, &"Knife02", &"Locomotion", 0.15)

	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = sm
	tree.active = true
	playback = tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	playback.start(&"Locomotion")
	tree.set("parameters/Locomotion/blend_position", 0.0)
	# AnimationTree не начинает playback сам, если у AnimationPlayer нет активного клипа.
	player.play(&"sunny/Idle_Relaxed")


func _node(anim: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = anim
	return n


func _add_transition(sm: AnimationNodeStateMachine, from: StringName, to: StringName, fade: float) -> void:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = fade
	t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	sm.add_transition(from, to, t)


func _update_camera() -> void:
	var cam := get_node_or_null(camera_path) as Camera3D
	if cam == null:
		return
	cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)

