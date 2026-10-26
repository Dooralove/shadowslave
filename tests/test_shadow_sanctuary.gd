extends GutTest
## Блок-аут «Святилище Тени»: размеры, события контроллера и сообщения Заклятия.

const SCENE := "res://scenes/locations/shadow_sanctuary/shadow_sanctuary.tscn"
const OVERLAY_SCENE := "res://scenes/ui/spell_overlay/spell_overlay.tscn"


func _make_sanctuary() -> SanctuaryController:
	var sanctuary := (load(SCENE) as PackedScene).instantiate() as SanctuaryController
	add_child_autofree(sanctuary)
	await wait_physics_frames(1)
	return sanctuary


func test_scene_has_required_hierarchy() -> void:
	var sanctuary := await _make_sanctuary()
	assert_not_null(sanctuary.get_node_or_null("Environment/WorldEnvironment"))
	assert_not_null(sanctuary.get_node_or_null("Geometry/Blockout"))
	assert_not_null(sanctuary.get_node_or_null("Spawns/SanctuaryEntrance"))
	assert_not_null(sanctuary.get_node_or_null("Triggers/Trigger_CreviceHideout"))


func test_floor_walls_and_roof_dimensions() -> void:
	var sanctuary := await _make_sanctuary()
	var blockout := sanctuary.get_node("Geometry/Blockout")
	var floor_mesh := blockout.get_node("HallFloor") as CSGBox3D
	var wall := blockout.get_node("MegalithWalls/WallWest") as CSGBox3D
	var roof := blockout.get_node("MegalithWalls/Roof") as CSGBox3D

	assert_eq(floor_mesh.size, Vector3(20.0, 0.5, 15.0))
	assert_almost_eq(wall.size.y, 6.0, 0.0001)
	assert_almost_eq(wall.size.x, 0.8, 0.0001)
	assert_almost_eq(roof.position.y - roof.size.y / 2.0, 6.0, 0.0001, "потолок на высоте 6 м")


func test_six_pillars_and_roof_breach_is_subtraction() -> void:
	var sanctuary := await _make_sanctuary()
	var blockout := sanctuary.get_node("Geometry/Blockout")
	var pillars := blockout.get_node("Pillars")
	var pillar_count := 0
	for child in pillars.get_children():
		if child.name.begins_with("Pillar"):
			pillar_count += 1
	assert_eq(pillar_count, 6)

	var breach := blockout.get_node("MegalithWalls/CeilingBreach_Main") as CSGBox3D
	assert_eq(breach.operation, CSGShape3D.OPERATION_SUBTRACTION)
	assert_eq(breach.size, Vector3(7.5, 2.0, 5.5))


func test_dais_and_altar_dimensions() -> void:
	var sanctuary := await _make_sanctuary()
	var blockout := sanctuary.get_node("Geometry/Blockout")
	var lower := blockout.get_node("AltarDais/StepLower") as CSGBox3D
	var upper := blockout.get_node("AltarDais/StepUpper") as CSGBox3D
	var altar := blockout.get_node("AltarStone/Monolith") as CSGBox3D

	assert_eq(lower.size, Vector3(4.0, 0.3, 3.0))
	assert_eq(upper.size, Vector3(3.2, 0.3, 2.4))
	assert_almost_eq(upper.position.y + upper.size.y / 2.0, 0.6, 0.0001, "высота помоста 0,6 м")
	assert_eq(altar.size, Vector3(1.5, 1.0, 1.0))


func test_crevice_gap_between_wall_and_fallen_column() -> void:
	var sanctuary := await _make_sanctuary()
	var blockout := sanctuary.get_node("Geometry/Blockout")
	var wall := blockout.get_node("MegalithWalls/WallWest") as CSGBox3D
	var column := blockout.get_node("SunnyCrevice/FallenColumn") as CSGCylinder3D
	var wall_inner := wall.position.x + wall.size.x / 2.0
	var column_west := column.position.x - column.radius
	assert_almost_eq(column_west - wall_inner, 0.6, 0.0001)


func test_three_signals_are_one_shot() -> void:
	var sanctuary := await _make_sanctuary()
	var counts := {"crevice": 0, "blood": 0, "trial": 0}
	sanctuary.player_entered_crevice.connect(func() -> void: counts["crevice"] += 1)
	sanctuary.blood_offered_to_altar.connect(func() -> void: counts["blood"] += 1)
	sanctuary.trial_completed.connect(func() -> void: counts["trial"] += 1)

	sanctuary.enter_crevice()
	sanctuary.offer_blood()
	sanctuary.complete_trial()
	sanctuary.enter_crevice()
	sanctuary.offer_blood()
	sanctuary.complete_trial()

	assert_eq(counts["crevice"], 1)
	assert_eq(counts["blood"], 1)
	assert_eq(counts["trial"], 1)


func test_spell_messages_keep_divine_and_glorious_separate() -> void:
	var sanctuary := await _make_sanctuary()
	var messages: Array = []
	sanctuary.spell_message.connect(
		func(text: String, evaluation: int) -> void:
			messages.append([text, evaluation])
	)

	sanctuary.announce_evaluation(SanctuaryController.Evaluation.DIVINE)
	sanctuary.announce_evaluation(SanctuaryController.Evaluation.GLORIOUS)
	sanctuary.announce_spell_message("Проверка.", SanctuaryController.Evaluation.NONE)

	assert_eq(messages.size(), 3)
	assert_eq(messages[0], ["Ранг Аспекта: Божественный.", SanctuaryController.Evaluation.DIVINE])
	assert_eq(messages[1], ["Итоговая оценка: Славная.", SanctuaryController.Evaluation.GLORIOUS])
	assert_eq(messages[2], ["Проверка.", SanctuaryController.Evaluation.NONE])


func test_spell_message_signal_can_drive_overlay() -> void:
	var sanctuary := await _make_sanctuary()
	var overlay := (load(OVERLAY_SCENE) as PackedScene).instantiate() as SpellOverlay
	add_child_autofree(overlay)
	sanctuary.spell_message.connect(
		func(text: String, _evaluation: int) -> void:
			overlay.show_text(text, 2.0)
	)

	sanctuary.announce_evaluation(SanctuaryController.Evaluation.GLORIOUS)
	assert_true(overlay.visible, "сигнал контроллера показывает панель")
	assert_eq(overlay.body_label.text, "Итоговая оценка: Славная.")
	assert_eq(overlay.header_label.text, SpellMessage.DEFAULT_HEADER)


func test_player_triggers_are_wired_but_evaluation_zone_is_not_armed() -> void:
	var sanctuary := await _make_sanctuary()
	assert_gt(sanctuary.crevice_trigger.body_entered.get_connections().size(), 0)
	assert_gt(sanctuary.altar_trigger.body_entered.get_connections().size(), 0)
	assert_false(sanctuary.evaluation_trigger.monitoring, "зона оценки включается сценарием")


func test_crevice_trigger_fires_at_accessible_mouth() -> void:
	var sanctuary := await _make_sanctuary()
	watch_signals(sanctuary)
	_add_test_body(Vector3(-8.5, 0.05, 3.8))
	await wait_physics_frames(3)
	assert_signal_emitted(sanctuary, "player_entered_crevice")


func test_altar_approach_arms_offering_once() -> void:
	var sanctuary := await _make_sanctuary()
	watch_signals(sanctuary)
	_add_test_body(Vector3(0.0, 0.05, -3.1))
	await wait_physics_frames(3)
	assert_signal_emitted(sanctuary, "altar_ready")
	assert_signal_not_emitted(sanctuary, "blood_offered_to_altar", "подход не запускает финал")
	assert_false(sanctuary.altar_trigger.monitoring, "зона подхода выключается после входа")
	sanctuary.arm_altar()
	assert_signal_emit_count(sanctuary, "altar_ready", 1, "повторный вход не дублирует событие")


func _add_test_body(position: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group(&"player")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = position
	return body
