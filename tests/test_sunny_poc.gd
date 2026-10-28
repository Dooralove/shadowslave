extends GutTest
## Прототип S2: реалистичная модель Санни (MPFB 2 + Quaternius UAL) подключается сценой-вариантом
## без изменения кода. Проверяются импорт, скелет, клипы, рост и проходимость пролога.

const MODEL := "res://assets/characters/sunny_realistic_poc/sunny_poc_model.tscn"
const SUNNY_POC := "res://assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn"
const PROLOGUE_POC := "res://assets/characters/sunny_realistic_poc/prologue_poc.tscn"


func _model() -> Node3D:
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	return model


func test_skeleton_is_retargeted_to_humanoid_profile() -> void:
	var skeleton := _model().find_child("GeneralSkeleton", true, false) as Skeleton3D
	assert_not_null(skeleton, "кости переименованы, скелет уникальный (%GeneralSkeleton)")
	var profile := SkeletonProfileHumanoid.new()
	for i in profile.bone_size:
		var bone := profile.get_bone_name(i)
		if bone in [&"LeftEye", &"RightEye", &"Jaw"]:
			continue
		assert_ne(skeleton.find_bone(bone), -1, "кость профиля %s" % bone)


func test_animation_library_has_full_tracks() -> void:
	var player := _model().get_node("AnimationPlayer") as AnimationPlayer
	for clip in [&"Idle", &"Walk", &"Sprint", &"Jump_Start", &"Jump", &"Jump_Land", &"Sitting_Idle", &"Sitting_Exit"]:
		assert_true(player.has_animation(clip), "клип %s" % clip)
		if player.has_animation(clip):
			# Импорт с удалением дорожек в Godot 4.7 оставлял 11 из 53 — проверка от регрессии.
			assert_gt(player.get_animation(clip).get_track_count(), 40, "%s: дорожки всех костей" % clip)
	assert_eq(player.get_animation(&"Walk").loop_mode, Animation.LOOP_LINEAR)


func test_every_clip_defines_full_pose_without_foreign_bone_lengths() -> void:
	var player := _model().get_node("AnimationPlayer") as AnimationPlayer
	for clip in player.get_animation_list():
		var animation := player.get_animation(clip)
		var rotations := 0
		for i in animation.get_track_count():
			var bone := StringName(animation.track_get_path(i).get_concatenated_subnames())
			match animation.track_get_type(i):
				Animation.TYPE_ROTATION_3D:
					rotations += 1
				Animation.TYPE_POSITION_3D:
					# Положение других костей несёт длины костей манекена UAL и ломает пропорции Санни.
					assert_has([&"Root", &"Hips"], bone, "%s: положение только у Root/Hips, не у %s" % [clip, bone])
		# Без неизменных дорожек кость сохраняла позу прошлого клипа (таз оставался «сидя»).
		assert_gte(rotations, 50, "%s: вращение всех костей" % clip)


func test_relaxed_idle_is_separate_clip_and_loops() -> void:
	var player := _model().get_node("AnimationPlayer") as AnimationPlayer
	assert_true(player.has_animation(&"sunny/Idle_Relaxed"), "спокойный Idle в отдельной библиотеке")
	assert_eq(player.get_animation(&"sunny/Idle_Relaxed").loop_mode, Animation.LOOP_LINEAR)
	assert_true(player.has_animation(&"Idle"), "исходный UAL Idle не удалён")


func test_standing_after_sitting_restores_hips() -> void:
	var model := _model()
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	var skeleton := model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	var hips := skeleton.find_bone(&"Hips")
	player.play(&"Sitting_Idle")
	player.advance(0.1)
	var sitting := skeleton.get_bone_global_pose(hips).origin.y
	player.play(&"sunny/Idle_Relaxed")
	player.advance(0.1)
	var standing := skeleton.get_bone_global_pose(hips).origin.y
	assert_lt(sitting, 0.6, "сидя таз низко")
	assert_gt(standing, 0.8, "после сидения Idle поднимает таз")


func test_posture_offset_present() -> void:
	var modifier := _model().find_child("PostureOffset", true, false) as SkeletonModifier3D
	assert_not_null(modifier, "поправка осанки после ретаргетинга")
	if modifier:
		assert_true(modifier.active)


func test_height_matches_canon() -> void:
	var model := _model()
	var top := -INF
	var bottom := INF
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var aabb := (mesh as MeshInstance3D).get_aabb()
		top = maxf(top, aabb.end.y)
		bottom = minf(bottom, aabb.position.y)
	assert_between(top - bottom, 1.63, 1.72, "рост с волосами и обувью ~1,65–1,70 м (канон 165–168 см)")


func test_opaque_body_and_clothes() -> void:
	var skeleton := _model().find_child("GeneralSkeleton", true, false)
	for mesh in skeleton.get_children():
		if not mesh is MeshInstance3D:
			continue
		var material := (mesh as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
		var name := String(mesh.name)
		if "hair" in name or "eyebrow" in name or "eyelashes" in name:
			continue
		assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "%s непрозрачен" % name)


func test_variant_uses_poc_model_and_keeps_rules() -> void:
	var sunny := (load(SUNNY_POC) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	assert_false((sunny.get_node("Visual/Model") as Node3D).visible, "KayKit скрыт, но не удалён (откат)")
	var animator := sunny.get_node("Animator") as SunnyAnimator
	var actor := sunny.get_node("CinematicActor") as CinematicActor
	assert_eq(animator.animation_player, sunny.get_node("Visual/ModelPoc/AnimationPlayer"))
	for clip in [animator.idle_clip, animator.walk_clip, animator.run_clip, animator.jump_clip, animator.fall_clip,
			animator.land_clip, animator.attack_clip, animator.hit_clip, animator.death_clip]:
		assert_true(animator.animation_player.has_animation(clip), "клип аниматора %s" % clip)
	for action in actor.clip_map.clips:
		assert_true(actor.has_action(action), "действие постановки %s" % action)
	assert_false(sunny.combat_enabled)
	assert_false(sunny.allow_sprint)


func test_poc_prologue_plays_through() -> void:
	var director := (load(PROLOGUE_POC) as PackedScene).instantiate() as SliceDirector
	director.autostart = false
	director.fast_mode = true
	add_child_autofree(director)
	director.start()
	for i in 200:
		if director.beat == SliceDirector.Beat.FINISHED:
			break
		if director.runner.running:
			director.runner.advance()
		elif director.ui.rune_status.showing:
			director.ui.rune_status.close()
		elif director.awaiting != &"":
			director.notify(director.awaiting)
		await wait_process_frames(1)
	assert_eq(director.beat, SliceDirector.Beat.FINISHED, "пролог с новой моделью проходится до конца")
