extends GutTest
## Интерактивное подношение алтарю: подсказка, каноническая последовательность,
## приход Тирана, его смерть от теней и одноразовость.

const SCENE := "res://scenes/locations/shadow_sanctuary/shadow_sanctuary.tscn"
const CATALOG := "res://resources/spell/altar_offering.tres"


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _make_sanctuary() -> SanctuaryController:
	var sanctuary := (load(SCENE) as PackedScene).instantiate() as SanctuaryController
	add_child_autofree(sanctuary)
	await wait_physics_frames(1)
	return sanctuary


func _fast_catalog() -> SpellMessageCatalog:
	var catalog := SpellMessageCatalog.new()
	catalog.messages = [
		_message(&"altar_sacrifice", "Ты предложил себя в жертву богам."),
		_message(&"altar_gods_dead", "Боги мертвы и не могут тебя услышать."),
		_message(&"altar_mark_of_divinity", "Твоя душа несёт знак божественности."),
		_message(&"altar_temple_slave", "Ты — храмовый раб."),
		_message(&"altar_shadow_god_stirs", "Бог Тени пробуждается в вечном сне."),
		_message(&"altar_blessing_beyond_grave", "Он посылает благословение из-за пределов смерти."),
		_message(&"altar_child_of_shadows", "Дитя Теней, прими своё благословение!"),
		_message(&"altar_tyrant_slain", "Ты убил пробуждённого тирана — Горного Короля."),
		_message(&"altar_wake_up", "Просыпайся, Санлесс! Твой кошмар окончен."),
		_message(&"altar_prepare_appraisal", "Приготовься к оценке…"),
	]
	return catalog


func _message(id: StringName, text: String) -> SpellMessage:
	var message := SpellMessage.new()
	message.id = id
	message.text = text
	message.duration = 0.0
	return message


func _configure_fast_ritual(ritual: AltarRitual) -> void:
	ritual.messages = _fast_catalog()
	ritual.spell_overlay = null
	ritual.start_delay = 0.0
	ritual.line_gap = 0.0
	ritual.finale_delay = 0.0
	ritual.fast_mode = true


func test_scene_has_player_prompt_and_altar_point() -> void:
	var sanctuary := await _make_sanctuary()
	assert_true(sanctuary.get_node("Sunny") is SunnyController, "в сцене есть играбельный Санни")
	assert_true(sanctuary.get_node("Sunny").is_in_group(&"player"), "Санни виден триггерам как игрок")
	assert_not_null(sanctuary.get_node_or_null("Sunny/Interactor"), "у Санни есть Interactor")
	assert_not_null(sanctuary.get_node_or_null("UI/Prompt") as InteractionPromptUI, "в HUD есть подсказка")
	assert_not_null(sanctuary.get_node_or_null("SpellOverlay") as SpellOverlay, "слой Заклятия подключён")
	assert_not_null(sanctuary.get_node_or_null("Tyrant") as Node3D, "в зале есть силуэт Тирана")
	assert_not_null(sanctuary.get_node_or_null("ShadowHands") as Node3D, "в зале есть руки тени")
	var altar := sanctuary.get_node_or_null("Interactables/AltarOffering") as Interactable
	assert_not_null(altar, "у алтаря есть точка взаимодействия")
	assert_true(altar.enabled, "точка доступна")
	assert_eq(altar.prompt, "Совершить подношение")


func test_catalog_uses_canonical_sequence() -> void:
	var catalog := load(CATALOG) as SpellMessageCatalog
	assert_not_null(catalog)
	var messages := catalog.get_valid_messages()
	assert_eq(messages.size(), 11)
	for message in messages:
		assert_gt(message.duration, 2.0, "строка должна успеть проявиться")
	assert_eq(messages[0].text, "Ты предложил себя в жертву богам.")
	assert_eq(messages[1].text, "Боги мертвы и не могут тебя услышать.")
	assert_eq(messages[2].text, "Твоя душа несёт знак божественности.")
	assert_eq(messages[3].text, "Ты — храмовый раб.")
	assert_eq(messages[4].text, "Бог Тени пробуждается в вечном сне.")
	assert_eq(messages[5].text, "Он посылает благословение из-за пределов смерти.")
	assert_eq(messages[6].text, "Дитя Теней, прими своё благословение!")
	assert_eq(messages[8].id, &"altar_tyrant_slain")
	assert_eq(messages[9].id, &"altar_wake_up")
	assert_eq(messages[10].id, &"altar_prepare_appraisal")
	assert_eq(messages[10].text, "Приготовься к оценке…")


func test_prompt_appears_near_altar_and_hides_when_point_closes() -> void:
	var sanctuary := await _make_sanctuary()
	var sunny := sanctuary.get_node("Sunny") as SunnyController
	var interactor := sanctuary.get_node("Sunny/Interactor") as Interactor
	var prompt := sanctuary.get_node("UI/Prompt") as InteractionPromptUI
	var altar := sanctuary.get_node("Interactables/AltarOffering") as Interactable

	sunny.global_position = Vector3(0.0, 0.05, -3.0)
	await wait_physics_frames(2)
	interactor.refresh()
	assert_eq(interactor.focused, altar, "игрок в зоне алтаря")
	assert_true(prompt.visible, "подсказка появилась")
	assert_eq(prompt.text, "E — Совершить подношение")

	altar.enabled = false
	interactor.refresh()
	assert_false(prompt.visible, "подсказка скрыта, когда точка недоступна")


func test_offering_runs_sequence_once_and_confirms_tyrant_death() -> void:
	var sanctuary := await _make_sanctuary()
	var ritual := sanctuary.get_node("AltarRitual") as AltarRitual
	var altar := sanctuary.get_node("Interactables/AltarOffering") as Interactable
	var light := sanctuary.get_node("RitualLight") as OmniLight3D
	var glow := sanctuary.get_node("RitualGlow") as MeshInstance3D
	var status := sanctuary.get_node("UI/Status") as Label
	var tyrant := sanctuary.get_node("Tyrant") as Node3D
	var hands := sanctuary.get_node("ShadowHands") as Node3D

	_configure_fast_ritual(ritual)
	ritual.lock_player = false

	var texts: Array[String] = []
	sanctuary.spell_message.connect(
		func(text: String, _evaluation: int) -> void:
			texts.append(text)
	)
	watch_signals(sanctuary)
	watch_signals(ritual)

	altar.interact()
	await wait_seconds(0.4)

	assert_eq(texts.size(), 10, "семь строк подношения и три строки после смерти Тирана")
	assert_eq(texts[0], "Ты предложил себя в жертву богам.")
	assert_eq(texts[6], "Дитя Теней, прими своё благословение!")
	assert_eq(texts[7], "Ты убил пробуждённого тирана — Горного Короля.")
	assert_eq(texts[8], "Просыпайся, Санлесс! Твой кошмар окончен.")
	assert_eq(texts[9], "Приготовься к оценке…")
	assert_signal_emitted(sanctuary, "blood_offered_to_altar")
	assert_signal_not_emitted(sanctuary, "trial_completed", "ритуал не завершает испытание за оболочку")
	assert_signal_emitted(ritual, "finished")
	assert_eq(sanctuary.nightmare_state, SanctuaryController.NightmareState.OFFERING)
	assert_false(sanctuary.is_completed(), "ритуал не завершает Первый Кошмар за оболочку")
	assert_true(NightmareRunState.has_flag(&"tyrant_death_confirmed"), "смерть Тирана подтверждается после теней")
	assert_true(NightmareRunState.has_flag(&"trial_completed"))
	assert_false(tyrant.visible, "Тиран исчезает после смерти")
	assert_false(hands.visible, "руки тени исчезают после убийства")
	assert_true(light.visible, "алтарь подсвечен после подношения")
	assert_true(glow.visible, "на алтаре виден отклик")
	assert_eq(status.text, "Испытание завершено. Оценка ещё не началась.")

	# Повторное взаимодействие и повторный запуск не дают второго финала.
	altar.interact()
	ritual.begin()
	sanctuary.offer_blood()
	await wait_seconds(0.1)

	assert_signal_emit_count(sanctuary, "blood_offered_to_altar", 1)
	assert_signal_emit_count(ritual, "finished", 1)
	assert_eq(texts.size(), 10, "повторный запуск не добавляет сообщений")


func test_player_control_is_restored_after_ritual() -> void:
	var sanctuary := await _make_sanctuary()
	var ritual := sanctuary.get_node("AltarRitual") as AltarRitual
	var altar := sanctuary.get_node("Interactables/AltarOffering") as Interactable
	var sunny := sanctuary.get_node("Sunny") as SunnyController

	_configure_fast_ritual(ritual)
	ritual.lock_player = true

	assert_true(sunny.input_enabled)
	altar.interact()
	assert_false(sunny.input_enabled, "на время ритуала управление заблокировано")
	await wait_seconds(0.4)
	assert_true(sunny.input_enabled, "после ритуала управление возвращено")


func test_altar_approach_hint_fires_once() -> void:
	var sanctuary := await _make_sanctuary()
	var trigger := sanctuary.get_node("Triggers/Trigger_AltarInteract") as Area3D
	watch_signals(sanctuary)
	assert_true(trigger.monitoring)

	_add_test_body(Vector3(0.0, 0.05, -3.1))
	await wait_physics_frames(3)

	assert_signal_emitted(sanctuary, "altar_ready")
	assert_false(trigger.monitoring, "зона подхода выключается после первого входа")
	assert_signal_emit_count(sanctuary, "altar_ready", 1)

	sanctuary.arm_altar()
	assert_signal_emit_count(sanctuary, "altar_ready", 1, "повторный вызов не дублирует событие")


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
