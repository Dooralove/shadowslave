@tool
class_name Mannequin
extends Node3D
## Временный NPC: типовая анимированная модель (MakeHuman + анимации Quaternius UAL) по архетипу.
## Заменяется моделью конкретного персонажа без изменения сценария: постановки двигают этот узел,
## а не модель внутри.

const MODELS := {
	&"townsman": preload("res://assets/characters/p1/models/mass_male.glb"),
	&"townswoman": preload("res://assets/characters/p1/models/mass_female.glb"),
	&"police": preload("res://assets/characters/p1/models/mass_police.glb"),
	&"slave": preload("res://assets/characters/p1/models/mass_slave.glb"),
	&"broad_slave": preload("res://assets/characters/generated/broad_slave_v3/broad_slave_v3.tscn"),
	&"knight": preload("res://assets/characters/p1/models/mass_soldier.glb"),
	&"police_desk": preload("res://assets/characters/p1/models/police_desk.glb"),
	&"police_guard": preload("res://assets/characters/p1/models/police_guard.glb"),
	&"hero": preload("res://assets/characters/generated/hero_auro_v6/hero_auro_v6.tscn"),
	&"auro": preload("res://assets/characters/generated/hero_auro_v6/hero_auro_v6.tscn"),
	&"scholar": preload("res://assets/characters/generated/scholar_v3/scholar_v3.tscn"),
	&"shifty": preload("res://assets/characters/generated/shifty_v4/shifty_v4.tscn"),
	&"veteran": preload("res://assets/characters/generated/veteran_v5/veteran_v5.tscn"),
	&"mass_male": preload("res://assets/characters/p1/models/mass_male.glb"),
	&"mass_female": preload("res://assets/characters/p1/models/mass_female.glb"),
	&"mass_slave": preload("res://assets/characters/p1/models/mass_slave.glb"),
	&"mass_soldier": preload("res://assets/characters/p1/models/mass_soldier.glb"),
	&"mass_police": preload("res://assets/characters/p1/models/mass_police.glb"),
}
const ANIMATIONS := preload("res://assets/characters/sunny_realistic_poc/animations/ual_standard.glb")
## Стойка «Idle» из UAL — полуприсед с широко расставленными ногами; спокойная стойка снята для Санни.
const RELAXED_IDLE := preload("res://assets/characters/sunny_realistic_poc/animations/sunny_idle_relaxed.glb")
const PostureOffset := preload("res://assets/characters/sunny_realistic_poc/posture_offset_modifier.gd")
const POSE_MODIFIER := preload("res://scripts/slice/mannequin_pose_modifier.gd")
## Поза -> клип UAL. «dead», «dying» и «fall» замирают на последнем кадре / играют падение.
const POSE_CLIPS := {
	&"idle": &"Idle_Relaxed",
	&"talk": &"Idle_Talking",
	&"walk": &"Walk",
	&"run": &"Sprint",
	&"guard": &"Sword_Idle",
	&"torch": &"Idle_Torch",
	&"kneel": &"Fixing_Kneeling",
	&"sit": &"Sitting_Idle",
	&"ride": &"Sitting_Idle",
	&"interact": &"Interact",
	&"pickup": &"PickUp_Table",
	&"point": &"Interact",
	&"gesture": &"Idle_Talking",
	&"cross_arms": &"Idle_Talking",
	&"listen": &"Idle_Talking",
	&"head_turn": &"Idle_Talking",
	&"lean": &"Idle_Talking",
	&"check": &"Interact",
	&"walk_away": &"Walk",
	&"leave": &"Walk",
	&"wave": &"Idle_Talking",
	&"argue": &"Idle_Talking",
	&"read": &"Sitting_Idle",
	&"dead": &"Death01",
	&"dying": &"Death01",
	&"fall": &"Death01",
}
## Корень всадника стоит на высоте седла (как у прежних заглушек ~0,85–0,9 м над землёй);
## модель опускается так, чтобы таз в сидячей позе лёг на седло лошади-заглушки.
const RIDE_OFFSET := Vector3(0, -0.22, 0.1)
## Колено ставит таз ниже; модель опускается, чтобы колено/стопа касались пола.
const KNEEL_OFFSET := Vector3(0, -0.52, 0)
## HumanSit — поза на сиденье; небольшой сдвиг вниз убирает «парение» над полом.
const SIT_OFFSET := Vector3(0, -0.38, 0)


## Generated Humanoid assets carry their own Mixamo-style AnimationPlayer. Map the
## gameplay pose to a native clip instead of injecting UAL tracks onto a different rig.
const NATIVE_CLIPS := {
	&"idle": &"HumanStandingIdle",
	&"talk": &"HumanStandingIdle",
	&"walk": &"WalkClean",
	&"run": &"HumanSprintLoop",
	&"guard": &"HumanStandingIdle",
	&"torch": &"HumanStandingIdle",
	&"kneel": &"HumanStandingIdle",
	&"sit": &"HumanSit",
	&"ride": &"HumanSit",
	&"interact": &"HumanStandingIdle",
	&"pickup": &"HumanSit",
	&"point": &"HumanStandingIdle",
	&"gesture": &"HumanStandingIdle",
	&"cross_arms": &"HumanStandingIdle",
	&"listen": &"HumanStandingIdle",
	&"head_turn": &"HumanStandingIdle",
	&"lean": &"HumanStandingIdle",
	&"check": &"HumanStandingIdle",
	&"walk_away": &"WalkClean",
	&"leave": &"WalkClean",
	&"wave": &"HumanStandingIdle",
	&"argue": &"HumanStandingIdle",
	&"read": &"HumanSit",
	&"dead": &"HumanDeath",
	&"dying": &"HumanDeath",
	&"fall": &"HumanDeath",
}
const NATIVE_LOOPS := [&"HumanStandingIdle", &"HumanRelaxedWalkLoopF", &"HumanSprintLoop", &"HumanSit"]
const WALK_SOURCE := &"HumanRelaxedWalkLoopF"
const WALK_CLEAN := &"WalkClean"
const WALK_START := 0.8
const WALK_END := 1.8

@export_enum("townsman", "townswoman", "police", "slave", "broad_slave", "knight", "police_desk", "police_guard", "hero", "auro", "scholar", "shifty", "veteran", "mass_male", "mass_female", "mass_slave", "mass_soldier", "mass_police") var archetype := "townsman":
	set(value):
		archetype = value
		if is_inside_tree():
			_build()
@export_enum("idle", "talk", "walk", "run", "guard", "torch", "kneel", "sit", "ride", "dead", "dying", "fall", "interact", "pickup", "point", "gesture", "cross_arms", "listen", "head_turn", "lean", "check", "walk_away", "leave", "wave", "argue", "read") var pose := "idle":
	set(value):
		pose = value
		if is_inside_tree():
			_play_pose()
## Множитель роста относительно ~1,75 м.
@export var height_scale := 1.0
## Ширина фигуры. Действует вполовину: модель не должна расплываться, как прежняя капсула.
@export var width_scale := 1.0
## Дистанции LOD в метрах; действуют, если в GLB есть _LOD1/_LOD2.
@export var lod1_distance := 10.0
@export var lod2_distance := 22.0
## Цвета placeholder-персонажа. Материалы копируются на инстанс и не меняют общий GLB.
@export_group("Placeholder")
@export var placeholder := true
## Если цвета не заданы явно, применить профиль по имени узла/родителя
## (Jet, CheckpointGuard, Nephis, Cassia и т.д.). Это позволяет существующим
## постановкам A03 получать новые силуэты без правки их сцен.
@export var use_context_profile := true
@export var uniform_color := Color(1, 1, 1, 1)
@export var hair_color := Color(1, 1, 1, 1)
@export var skin_color := Color(1, 1, 1, 1)
@export var accent_color := Color(1, 1, 1, 1)
@export_enum("none", "spear", "cloak", "blindfold", "spear_cloak", "badge") var accessory := "none":
	set(value):
		accessory = value
		if is_inside_tree() and _model != null:
			_rebuild_accessories()

## Общая для всех заглушек копия библиотеки UAL с зацикленными клипами поз: исходную библиотеку
## делит с ними Санни, её не трогаем.
static var _library: AnimationLibrary

var _model: Node3D
var _player: AnimationPlayer
var _pose_modifier: SkeletonModifier3D
var _pose_props: Node3D


static func _looped_library() -> AnimationLibrary:
	if _library == null:
		_library = AnimationLibrary.new()
		for clip: StringName in POSE_CLIPS.values():
			if _library.has_animation(clip):
				continue
			var source := RELAXED_IDLE if RELAXED_IDLE.has_animation(clip) else ANIMATIONS
			var animation := (source.get_animation(clip) as Animation).duplicate() as Animation
			if clip != POSE_CLIPS[&"dead"]:
				animation.loop_mode = Animation.LOOP_LINEAR
			_library.add_animation(clip, animation)
	return _library


## Native generated humanoids walk with a 4.1 s downhill root-motion take.
## Trim it to one clean cycle and flatten the Hips drift so the NPC walks in place.
static func _prepare_native_locomotion(player: AnimationPlayer) -> void:
	for clip in NATIVE_LOOPS:
		var native := player.get_animation(clip)
		if native != null:
			native.loop_mode = Animation.LOOP_LINEAR
	if player.has_animation(WALK_CLEAN):
		return
	var source := player.get_animation(WALK_SOURCE)
	if source == null:
		return
	var clean := source.duplicate() as Animation
	_trim_animation(clean, WALK_START, WALK_END)
	_flatten_hips(clean, WALK_END - WALK_START)
	clean.loop_mode = Animation.LOOP_LINEAR
	var library := player.get_animation_library(&"")
	if library == null:
		library = AnimationLibrary.new()
		player.add_animation_library(&"", library)
	library.add_animation(WALK_CLEAN, clean)


static func _trim_animation(anim: Animation, start: float, end: float) -> void:
	var span := end - start
	for i in range(anim.get_track_count() - 1, -1, -1):
		for k in range(anim.track_get_key_count(i) - 1, -1, -1):
			var t := anim.track_get_key_time(i, k)
			if t < start - 0.0001 or t > end + 0.0001:
				anim.track_remove_key(i, k)
		for k in anim.track_get_key_count(i):
			anim.track_set_key_time(i, k, anim.track_get_key_time(i, k) - start)
	anim.length = span


static func _flatten_hips(anim: Animation, span: float) -> void:
	var hips_track := -1
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			var bone := StringName(anim.track_get_path(i).get_concatenated_subnames())
			if bone == &"Hips":
				hips_track = i
				break
	if hips_track < 0:
		return
	var n := anim.track_get_key_count(hips_track)
	if n < 2:
		return
	var first: Vector3 = anim.track_get_key_value(hips_track, 0)
	var last: Vector3 = anim.track_get_key_value(hips_track, n - 1)
	var dy := last.y - first.y
	var dz := last.z - first.z
	for k in n:
		var t := anim.track_get_key_time(hips_track, k) / maxf(span, 0.001)
		var v: Vector3 = anim.track_get_key_value(hips_track, k)
		v.y -= dy * t
		v.z -= dz * t
		anim.track_set_key_value(hips_track, k, v)


func _ready() -> void:
	_build()


func _build() -> void:
	if _model:
		_model.free()
	_pose_modifier = null
	_pose_props = null
	_model = (MODELS[StringName(archetype)] as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	# Модели glTF смотрят в +Z, а сценарии считают лицом -Z (как «Facing» у прежней заглушки).
	_model.rotation.y = PI
	# Рост и ширина — на модели, а не на корне: корень остаётся в распоряжении постановок.
	var width := 1.0 + (width_scale - 1.0) * 0.5
	_model.scale = Vector3(width, height_scale, width)
	add_child(_model, false, Node.INTERNAL_MODE_FRONT)
	var lod := _model.find_child("LodVisibility", true, false) as CharacterLodVisibility
	if lod == null:
		lod = _model.find_child("CharacterLodVisibility", true, false) as CharacterLodVisibility
	if lod == null:
		lod = CharacterLodVisibility.new()
		lod.name = "CharacterLodVisibility"
		_model.add_child(lod)
	lod.lod1_distance = lod1_distance
	lod.lod2_distance = lod2_distance
	# Generated humanoids (image-to-3D + CLI rig) already contain their own
	# Mixamo-style AnimationPlayer. Do not inject the 53-bone UAL library into
	# them; use the native clips instead.
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		_prepare_native_locomotion(_player)
	else:
		# P1/generated-old path: humanoid-named skeleton + injected UAL library.
		# Godot calls the skeleton Skeleton3D; rename it for UAL track paths.
		var skeleton := _model.find_child("GeneralSkeleton", true, false) as Skeleton3D
		if skeleton == null:
			skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
			if skeleton != null:
				skeleton.name = "GeneralSkeleton"
		if skeleton != null:
			skeleton.owner = _model
			skeleton.unique_name_in_owner = true
			# Та же поправка осанки, что у Санни: после ретаргетинга UAL на MakeHuman спина и шея завалены вперёд.
			skeleton.add_child(PostureOffset.new())
		_player = AnimationPlayer.new()
		_player.name = "AnimationPlayer"
		_model.add_child(_player)
		_player.root_node = _player.get_path_to(_model)
		_player.add_animation_library(&"", _looped_library())
	var pose_skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if pose_skeleton == null:
		pose_skeleton = _model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if pose_skeleton != null:
		_pose_modifier = POSE_MODIFIER.new()
		_pose_modifier.name = "PoseOverlay"
		pose_skeleton.add_child(_pose_modifier)
	_apply_context_profile()
	_apply_model_scale()
	_apply_tint()
	_rebuild_accessories()
	_apply_placeholder()
	_play_pose()


func _apply_placeholder() -> void:
	if placeholder:
		add_to_group(&"placeholder_character")
		set_meta(&"placeholder", true)
	else:
		remove_from_group(&"placeholder_character")
		set_meta(&"placeholder", false)


## Existing A03 scenes spawn generic Mannequins with names such as Jet,
## CheckpointGuard, Nephis or Cassia. Apply the A06 placeholder profile by
## context so those scenes gain the new silhouettes without editing A03 files.
func _apply_context_profile() -> void:
	if not placeholder or not use_context_profile:
		return
	if accessory != "none":
		return
	if not _colors_are_default():
		return
	match _detect_context_profile():
		&"jett":
			uniform_color = Color(0.16, 0.22, 0.38, 1)
			hair_color = Color(0.09, 0.07, 0.06, 1)
			skin_color = Color(1, 0.86, 0.78, 1)
			accent_color = Color(0.08, 0.08, 0.1, 1)
			accessory = "badge"
			# P06 spawns the player north of Jet while the scene yaw is 0.
			# Face north for the M1 dialogue; A03 can set yaw=PI and remove this.
			if is_zero_approx(rotation.y):
				_model.rotation.y = 0.0
		&"guard":
			uniform_color = Color(0.1, 0.14, 0.28, 1)
			hair_color = Color(0.08, 0.06, 0.05, 1)
			skin_color = Color(1, 0.86, 0.78, 1)
			accent_color = Color(0.7, 0.58, 0.2, 1)
			if pose == "idle":
				pose = "check"
		&"rock":
			uniform_color = Color(0.26, 0.22, 0.16, 1)
			hair_color = Color(0.12, 0.09, 0.06, 1)
			skin_color = Color(0.9, 0.75, 0.62, 1)
			accent_color = Color(0.12, 0.1, 0.08, 1)
			if is_equal_approx(height_scale, 1.0):
				height_scale = 1.12
			if is_equal_approx(width_scale, 1.0):
				width_scale = 1.18
		&"kasper":
			uniform_color = Color(0.15, 0.16, 0.2, 1)
			hair_color = Color(0.35, 0.26, 0.14, 1)
			skin_color = Color(1, 0.87, 0.76, 1)
			accent_color = Color(0.72, 0.55, 0.18, 1)
			if is_equal_approx(height_scale, 1.0):
				height_scale = 1.02
			if is_equal_approx(width_scale, 1.0):
				width_scale = 0.98
		&"cassia":
			uniform_color = Color(0.92, 0.92, 0.9, 1)
			hair_color = Color(0.85, 0.85, 0.88, 1)
			skin_color = Color(1, 0.9, 0.85, 1)
			accent_color = Color(0.82, 0.82, 0.8, 1)
			accessory = "blindfold"
			if pose == "idle":
				pose = "listen"
		&"nephis":
			uniform_color = Color(0.94, 0.94, 0.92, 1)
			hair_color = Color(0.9, 0.9, 0.92, 1)
			skin_color = Color(1, 0.9, 0.85, 1)
			accent_color = Color(0.75, 0.78, 0.85, 1)
			accessory = "spear_cloak"
			if pose == "idle":
				pose = "guard"
		&"julius":
			uniform_color = Color(0.28, 0.1, 0.12, 1)
			hair_color = Color(0.4, 0.32, 0.18, 1)
			skin_color = Color(1, 0.86, 0.78, 1)
			accent_color = Color(0.72, 0.56, 0.2, 1)
		&"medic":
			uniform_color = Color(0.86, 0.9, 0.9, 1)
			hair_color = Color(0.18, 0.12, 0.08, 1)
			skin_color = Color(1, 0.86, 0.78, 1)
			accent_color = Color(0.25, 0.55, 0.6, 1)
		&"guide":
			uniform_color = Color(0.18, 0.3, 0.38, 1)
			hair_color = Color(0.1, 0.08, 0.06, 1)
			skin_color = Color(1, 0.86, 0.78, 1)
			accent_color = Color(0.55, 0.65, 0.7, 1)
		&"sleeper":
			uniform_color = Color(0.36, 0.37, 0.38, 1)
			hair_color = Color(0.14, 0.11, 0.08, 1)
			skin_color = Color(0.98, 0.84, 0.74, 1)
			accent_color = Color(0.18, 0.17, 0.16, 1)


func _apply_model_scale() -> void:
	if _model == null:
		return
	var width := 1.0 + (width_scale - 1.0) * 0.5
	_model.scale = Vector3(width, height_scale, width)


func _colors_are_default() -> bool:
	return (
		uniform_color.is_equal_approx(Color(1, 1, 1, 1))
		and hair_color.is_equal_approx(Color(1, 1, 1, 1))
		and skin_color.is_equal_approx(Color(1, 1, 1, 1))
		and accent_color.is_equal_approx(Color(1, 1, 1, 1))
	)


func _detect_context_profile() -> StringName:
	var tokens := String(name).to_lower()
	var parent := get_parent()
	if parent != null:
		tokens += " " + String(parent.name).to_lower()
		var npc_id: Variant = parent.get(&"npc_id")
		if npc_id != null:
			tokens += " " + String(npc_id).to_lower()
	if tokens.contains("nephis"):
		return &"nephis"
	if tokens.contains("cassia"):
		return &"cassia"
	if tokens.contains("julius"):
		return &"julius"
	if tokens.contains("kasper"):
		return &"kasper"
	if tokens.contains("rock"):
		return &"rock"
	if tokens.contains("inductionmedic"):
		return &"rock"
	if tokens.contains("medic"):
		return &"medic"
	if tokens.contains("guide"):
		return &"guide"
	if tokens.contains("sleeper"):
		return &"sleeper"
	if tokens.contains("guard") or tokens.contains("officer"):
		return &"guard"
	if tokens.contains("jett") or tokens.contains("jet"):
		return &"jett"
	return &""


## Placeholder recoloring: duplicate the imported material per surface so one
## NPC does not recolor every other instance of the same GLB.
func _apply_tint() -> void:
	if _model == null:
		return
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var kind := _mesh_kind(String(mesh.name))
		var tint := _tint_for_kind(kind)
		if tint.is_equal_approx(Color(1, 1, 1, 1)):
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material == null:
				continue
			var copy := material.duplicate() as BaseMaterial3D
			copy.albedo_color = tint
			# Skin keeps its texture; cloth/hair/shoes use a flat placeholder color.
			if kind != &"skin":
				copy.albedo_texture = null
			mesh.set_surface_override_material(surface, copy)


func _mesh_kind(mesh_name: String) -> StringName:
	var n := mesh_name.to_lower()
	if n.contains("hair") or n.contains("bob") or n.contains("short0") or n.contains("short_") or n.contains("messy") or n.contains("eyebrow") or n.contains("eyelash"):
		return &"hair"
	if n.contains("shoe") or n.contains("boot") or n.contains("sneaker") or n.contains("badge") or n.contains("belt") or n.contains("radio"):
		return &"shoes"
	if n.contains("body") or n.contains("head") or n.contains("hand") or n.contains("arm") or n.contains("leg") or n.contains("foot"):
		return &"skin"
	return &"clothes"


func _tint_for_kind(kind: StringName) -> Color:
	match kind:
		&"hair":
			return hair_color
		&"shoes":
			return accent_color
		&"skin":
			return skin_color
		_:
			return uniform_color


func _rebuild_accessories() -> void:
	if _model == null:
		return
	var old := _model.get_node_or_null("PlaceholderAccessories")
	if old != null:
		old.free()
	if accessory == "none":
		return
	var root := Node3D.new()
	root.name = "PlaceholderAccessories"
	_model.add_child(root)
	if accessory == "spear" or accessory == "spear_cloak":
		_add_spear(root)
	if accessory == "cloak" or accessory == "spear_cloak":
		_add_cloak(root)
	if accessory == "blindfold":
		_add_blindfold(root)
	if accessory == "badge":
		_add_badge(root)


func _add_spear(root: Node3D) -> void:
	var spear := Node3D.new()
	spear.name = "Spear"
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.height = 2.0
	shaft_mesh.top_radius = 0.025
	shaft_mesh.bottom_radius = 0.03
	shaft_mesh.radial_segments = 6
	shaft.mesh = shaft_mesh
	shaft.material_override = _flat_material(Color(0.2, 0.13, 0.08), 0.85)
	shaft.add_to_group(&"lod_ignore")
	shaft.position = Vector3(0, 1.0, 0)
	spear.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.height = 0.3
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.07
	tip_mesh.radial_segments = 8
	tip.mesh = tip_mesh
	tip.material_override = _flat_material(Color(0.7, 0.72, 0.76), 0.25, 0.8)
	tip.add_to_group(&"lod_ignore")
	tip.position = Vector3(0, 2.15, 0)
	spear.add_child(tip)
	spear.position = Vector3(0.32, 0, 0.02)
	spear.rotation.z = -0.08
	root.add_child(spear)


func _add_cloak(root: Node3D) -> void:
	var cloak := MeshInstance3D.new()
	cloak.name = "Cloak"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 7
	var rows := 5
	for r in rows + 1:
		var v := float(r) / float(rows)
		var y := lerpf(1.45, 1.0, v)
		var half := lerpf(0.16, 0.2, v)
		for c in cols + 1:
			var u := float(c) / float(cols)
			var theta := lerpf(-PI * 0.5, PI * 0.5, u)
			var x := sin(theta) * half
			var z := -0.12 - cos(theta) * 0.06 + sin(u * PI * 4.0) * 0.012
			st.set_normal(Vector3(sin(theta), 0, -cos(theta)).normalized())
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(x, y, z))
	for r in rows:
		for c in cols:
			var i := r * (cols + 1) + c
			var right := i + 1
			var below := i + cols + 1
			var below_right := below + 1
			st.add_index(i)
			st.add_index(below)
			st.add_index(right)
			st.add_index(right)
			st.add_index(below)
			st.add_index(below_right)
	cloak.mesh = st.commit()
	cloak.material_override = _flat_material(Color(0.9, 0.9, 0.88), 0.9, 0.0, true)
	cloak.add_to_group(&"lod_ignore")
	root.add_child(cloak)


func _add_blindfold(root: Node3D) -> void:
	var band := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.032, 0.018)
	band.mesh = box
	band.material_override = _flat_material(Color(0.82, 0.82, 0.8), 0.85)
	band.add_to_group(&"lod_ignore")
	# Follow the head bone so listen/head-turn poses do not leave the band behind.
	var attachment := _bone_attachment(&"Head", "BlindfoldAttachment")
	var parent: Node3D = attachment if attachment != null else root
	band.position = Vector3(0, 0.06, 0.1) if attachment != null else Vector3(0, 1.58, 0.11)
	parent.add_child(band)


func _add_badge(root: Node3D) -> void:
	var badge := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.055, 0.07, 0.012)
	badge.mesh = box
	badge.material_override = _flat_material(Color(0.78, 0.62, 0.22), 0.35, 0.7)
	badge.add_to_group(&"lod_ignore")
	badge.position = Vector3(0.09, 1.35, 0.12)
	root.add_child(badge)


func _bone_attachment(bone_name: StringName, node_name: String) -> BoneAttachment3D:
	if _model == null:
		return null
	var skeleton := _model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone(bone_name) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	return attachment


func _flat_material(color: Color, roughness: float, metallic := 0.0, double_sided := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if double_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _play_pose() -> void:
	if _player == null:
		return
	var key := StringName(pose)
	var model_offset := Vector3.ZERO
	if key == &"ride":
		model_offset = RIDE_OFFSET
	elif key == &"kneel":
		model_offset = KNEEL_OFFSET
	elif key == &"sit" or key == &"read":
		model_offset = SIT_OFFSET
	_model.position = model_offset
	_set_pose_overlay(key)
	_update_pose_props(key)
	# Native generated-humanoid path.
	var native_clip: StringName = NATIVE_CLIPS.get(key, NATIVE_CLIPS[&"idle"])
	if native_clip == WALK_CLEAN and not _player.has_animation(native_clip):
		native_clip = WALK_SOURCE
	if _player.has_animation(native_clip):
		var native_animation := _player.get_animation(native_clip)
		if key == &"fall":
			_player.play(native_clip, 0.08)
			_player.speed_scale = 1.0
			return
		if key == &"dead" or key == &"dying":
			_player.play(native_clip, 0.08)
			_player.seek(native_animation.length * (0.99 if key == &"dead" else 0.88), true)
			_player.speed_scale = 1.0
			return
		var native_rng := RandomNumberGenerator.new()
		native_rng.seed = hash(get_path()) if is_inside_tree() else 0
		_player.play(native_clip, 0.18)
		if key in [&"idle", &"talk", &"torch", &"sit", &"ride", &"point", &"gesture", &"cross_arms", &"listen", &"head_turn", &"lean", &"check", &"wave", &"argue", &"read"]:
			_player.seek(native_rng.randf() * native_animation.length, true)
		_player.speed_scale = native_rng.randf_range(0.9, 1.1)
		return
	var clip: StringName = POSE_CLIPS.get(key, POSE_CLIPS[&"idle"])
	var animation := _player.get_animation(clip)
	if animation == null:
		return
	if key == &"fall":
		_player.play(clip, 0.1)
		_player.speed_scale = 1.0
		return
	if key == &"dead" or key == &"dying":
		_player.play(clip)
		_player.seek(animation.length * (0.99 if key == &"dead" else 0.88), true)
		return
	# Толпа не должна дышать в такт: случайная фаза и чуть разный темп.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_path()) if is_inside_tree() else 0
	_player.play(clip, 0.2)
	_player.seek(rng.randf() * animation.length, true)
	_player.speed_scale = rng.randf_range(0.9, 1.1)


func _set_pose_overlay(key: StringName) -> void:
	if _pose_modifier == null:
		return
	var overlay := key if key in [&"kneel", &"read", &"point"] else &""
	_pose_modifier.set(&"pose", overlay)


func _update_pose_props(key: StringName) -> void:
	if _model == null:
		return
	if _pose_props == null or not is_instance_valid(_pose_props):
		_pose_props = Node3D.new()
		_pose_props.name = "PoseProps"
		_model.add_child(_pose_props)
	var book := _pose_props.get_node_or_null("Book")
	if key == &"read":
		if book == null:
			_add_book(_pose_props)
	elif book != null:
		book.free()


func _add_book(root: Node3D) -> void:
	var book := MeshInstance3D.new()
	book.name = "Book"
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.035, 0.22)
	book.mesh = box
	book.material_override = _flat_material(Color(0.2, 0.12, 0.07), 0.85)
	book.add_to_group(&"lod_ignore")
	book.position = Vector3(0.0, 0.78, 0.22)
	book.rotation.x = deg_to_rad(18.0)
	root.add_child(book)


## Поворачивает корень к мировой точке; модель внутри уже развёрнута на PI.
func face_position(target: Vector3) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	rotation.y = atan2(-direction.x, -direction.z)


func face_node(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	face_position(target.global_position)


func face_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		face_position(player.global_position)


func is_facing_position(target: Vector3, tolerance_deg := 25.0) -> bool:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	var desired := atan2(-direction.x, -direction.z)
	return absf(wrapf(desired - rotation.y, -PI, PI)) <= deg_to_rad(tolerance_deg)


## Модель с анимацией; для постановок, которым нужен AnimationPlayer (например, CinematicActor).
func get_animation_player() -> AnimationPlayer:
	return _player
