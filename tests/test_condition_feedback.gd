extends GutTest
## Холод и шум показываются дыханием, виньеткой и звуком, без полосок.

const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"


func test_condition_feedback_drives_vignette_and_audio() -> void:
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	await wait_process_frames(1)
	var feedback := sunny.get_node("ConditionFeedback") as ConditionFeedback
	assert_not_null(feedback)

	feedback.set_cold(1.0)
	assert_true(feedback.get_vignette().visible)
	var material := feedback.get_vignette().material as ShaderMaterial
	assert_not_null(material)
	assert_almost_eq(float(material.get_shader_parameter(&"cold")), 1.0, 0.001)
	var breath := feedback.get_breath_player().stream as AudioStreamWAV
	assert_not_null(breath)
	assert_eq(breath.loop_mode, AudioStreamWAV.LOOP_FORWARD, "дыхание зациклено")

	feedback.set_noise(0.8)
	assert_almost_eq(float(material.get_shader_parameter(&"noise")), 0.8, 0.001)
	assert_not_null(feedback.get_noise_player().stream)

	feedback.set_cold(0.0)
	feedback.set_noise(0.0)
	assert_false(feedback.get_vignette().visible, "при нулевых значениях виньетка не мешает кадру")
