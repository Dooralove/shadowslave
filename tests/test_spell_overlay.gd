extends GutTest
## Слой сообщений Кошмарного Заклятия: структура, анимации, очередь и жизненный цикл.

const SCENE := "res://scenes/ui/spell_overlay/spell_overlay.tscn"
const CATALOG := "res://resources/spell/spell_messages.tres"


func _make_overlay() -> SpellOverlay:
	var overlay := (load(SCENE) as PackedScene).instantiate() as SpellOverlay
	add_child_autofree(overlay)
	return overlay


func _panel_message(text: String, duration: float, header := SpellMessage.DEFAULT_HEADER) -> SpellMessage:
	var message := SpellMessage.new()
	message.header = header
	message.text = text
	message.duration = duration
	message.presentation = SpellMessage.Presentation.PANEL
	return message


func _cinematic_message(text: String, duration: float) -> SpellMessage:
	var message := _panel_message(text, duration)
	message.presentation = SpellMessage.Presentation.CINEMATIC
	return message


func test_scene_starts_clean() -> void:
	var overlay := _make_overlay()
	assert_false(overlay.visible)
	assert_eq(overlay.dim.color.a, 0.0, "фон не затемнён до показа")
	assert_eq(overlay.rune_text.visible_ratio, 0.0)
	assert_true(overlay.rune_text.bbcode_enabled)
	assert_eq(overlay.rune_text.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(overlay.rune_text.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
	assert_not_null(overlay.message_panel, "в сцене есть панель")
	assert_false(overlay.message_panel.visible)
	assert_eq(overlay.header_label.text, "")
	assert_eq(overlay.body_label.text, "")
	assert_false(overlay.is_showing())
	assert_eq(overlay.queued_count(), 0)


func test_show_runes_reveals_text_and_dims_background() -> void:
	var overlay := _make_overlay()
	var animation := overlay.animation_player.get_animation(&"show_runes")
	assert_not_null(animation)
	assert_almost_eq(animation.length, 2.0, 0.001)

	var reveal := _track_by_path(animation, NodePath("Center/RuneText:visible_ratio"))
	assert_ne(reveal, -1, "есть дорожка visible_ratio")
	assert_eq(animation.track_get_key_value(reveal, 0), 0.0)
	assert_eq(animation.track_get_key_value(reveal, 1), 1.0)

	var dim := _track_by_path(animation, NodePath("Dim:color"))
	assert_ne(dim, -1, "есть дорожка затемнения")
	assert_almost_eq((animation.track_get_key_value(dim, 0) as Color).a, 0.0, 0.001)
	assert_gt((animation.track_get_key_value(dim, 1) as Color).a, 0.0, "фон затемняется")


func test_hide_runes_dissolves_text() -> void:
	var overlay := _make_overlay()
	var animation := overlay.animation_player.get_animation(&"hide_runes")
	assert_not_null(animation)

	var dissolve := _track_by_path(animation, NodePath("Center/RuneText:modulate"))
	assert_ne(dissolve, -1, "есть дорожка modulate")
	assert_eq(animation.track_get_key_value(dissolve, 0), Color.WHITE)
	assert_eq(animation.track_get_key_value(dissolve, 1), Color(1.0, 1.0, 1.0, 0.0))


func test_catalog_contains_canonical_messages() -> void:
	var catalog := load(CATALOG) as SpellMessageCatalog
	assert_not_null(catalog)
	assert_eq(catalog.messages.size(), 6, "тестовый набор из шести сообщений")

	var expected := {
		&"greeting": "Претендент! Добро пожаловать в Кошмарное Заклятие. Приготовься к своему Первому испытанию...",
		&"trial_over": "Претендент! Твоё испытание завершено.",
		&"mountain_king_defeated": "Вы одолели Пробуждённого тирана: Горного Короля.",
		&"shadow_blessing": "Вы получили благословение Бога Тени.",
		&"final_appraisal": "Итоговая оценка: Славная.",
		&"true_name": "Тебе даровано Истинное Имя: Lost from Light.",
	}
	for message_id in expected:
		var message := catalog.get_message(message_id)
		assert_not_null(message, "есть сообщение %s" % message_id)
		assert_eq(message.text, expected[message_id])
		assert_false(message.text.contains("["), "квадратные скобки документа не попали в текст")
		assert_false(message.text.contains("]"), "квадратные скобки документа не попали в текст")

	assert_eq(catalog.get_message(&"greeting").presentation, SpellMessage.Presentation.CINEMATIC)
	assert_eq(catalog.get_message(&"final_appraisal").presentation, SpellMessage.Presentation.CINEMATIC)
	assert_eq(catalog.get_message(&"mountain_king_defeated").presentation, SpellMessage.Presentation.PANEL)


func test_panel_lifecycle_shows_header_and_text_then_cleans_up() -> void:
	var overlay := _make_overlay()
	watch_signals(overlay)
	overlay.show_message(_panel_message("Текст панели", 0.5, "ПРОВЕРКА"))

	assert_true(overlay.visible)
	assert_true(overlay.message_panel.visible)
	assert_eq(overlay.header_label.text, "ПРОВЕРКА")
	assert_eq(overlay.body_label.text, "Текст панели")
	assert_false(overlay.rune_text.visible, "панель не смешивается с полноэкранным текстом")
	assert_eq(overlay.dim.color.a, 0.0, "панель не затемняет весь кадр")
	assert_true(overlay.is_showing())

	await wait_seconds(1.0)
	assert_signal_emit_count(overlay, "message_finished", 1)
	assert_signal_emit_count(overlay, "queue_finished", 1)
	assert_false(overlay.visible)
	assert_false(overlay.message_panel.visible)
	assert_eq(overlay.header_label.text, "")
	assert_eq(overlay.body_label.text, "")
	assert_false(overlay.is_showing())


func test_empty_header_falls_back_to_default() -> void:
	var overlay := _make_overlay()
	overlay.show_message(_panel_message("Текст", 0.5, ""))
	assert_eq(overlay.header_label.text, SpellMessage.DEFAULT_HEADER)
	overlay.clear_messages()


func test_messages_are_shown_one_after_another() -> void:
	var overlay := _make_overlay()
	watch_signals(overlay)
	overlay.show_message(_panel_message("Первое", 0.15))
	overlay.show_message(_panel_message("Второе", 0.15))

	assert_eq(overlay.body_label.text, "Первое", "второе сообщение ждёт своей очереди")
	assert_eq(overlay.queued_count(), 1)

	await wait_seconds(0.6)
	assert_eq(overlay.body_label.text, "Второе", "после первого показано второе")
	assert_signal_emit_count(overlay, "message_finished", 1)

	await wait_seconds(0.6)
	assert_signal_emit_count(overlay, "message_finished", 2)
	assert_signal_emit_count(overlay, "queue_finished", 1)
	assert_false(overlay.visible)


func test_clear_prevents_old_presentation_from_hiding_new_one() -> void:
	var overlay := _make_overlay()
	watch_signals(overlay)
	overlay.show_message(_panel_message("Старое", 0.5))
	await wait_seconds(0.3)
	overlay.clear_messages()
	assert_false(overlay.visible, "очистка убирает текущий показ")

	overlay.show_message(_panel_message("Новое", 0.5))
	assert_true(overlay.visible)
	assert_eq(overlay.body_label.text, "Новое")

	# Старое сообщение закончилось бы примерно на 0,8 с; новое ещё должно быть на экране.
	await wait_seconds(0.6)
	assert_true(overlay.visible, "запоздавший показ не скрыл новое сообщение")
	assert_eq(overlay.body_label.text, "Новое")

	await wait_seconds(0.4)
	assert_false(overlay.visible)
	assert_signal_emit_count(overlay, "message_finished", 1, "завершилось только новое сообщение")


func test_invalid_calls_do_not_start_presentation() -> void:
	var overlay := _make_overlay()
	watch_signals(overlay)
	overlay.show_message(null)
	overlay.show_message(SpellMessage.new())
	overlay.show_message(_panel_message("Текст", -1.0))

	await wait_process_frames(2)
	assert_false(overlay.visible)
	assert_false(overlay.is_showing())
	assert_eq(overlay.queued_count(), 0)
	assert_signal_emit_count(overlay, "message_finished", 0)
	assert_signal_emit_count(overlay, "queue_finished", 0)


func test_overlay_without_nodes_does_not_crash() -> void:
	var overlay := SpellOverlay.new()
	add_child_autofree(overlay)
	watch_signals(overlay)
	overlay.show_message(_panel_message("Текст", 0.1))

	await wait_process_frames(2)
	assert_false(overlay.visible)
	assert_false(overlay.is_showing())
	assert_signal_emit_count(overlay, "message_finished", 0)
	assert_signal_emit_count(overlay, "queue_finished", 1, "очередь завершается даже без узлов")


func test_cinematic_lifecycle_reveals_and_dissolves() -> void:
	var overlay := _make_overlay()
	watch_signals(overlay)
	overlay.show_message(_cinematic_message("В темноте", 2.1))

	assert_true(overlay.visible)
	assert_eq(overlay.animation_player.current_animation, &"show_runes")
	assert_true(overlay.rune_text.visible)
	assert_eq(overlay.rune_text.text, "В темноте")
	assert_false(overlay.message_panel.visible)

	# 2,0 c проявления + 0,1 c удержания + 1,2 c растворения; запас на кадры.
	await wait_seconds(3.5)
	assert_signal_emit_count(overlay, "message_finished", 1)
	assert_false(overlay.visible)
	assert_eq(overlay.rune_text.visible_ratio, 0.0)
	assert_eq(overlay.dim.color.a, 0.0)


func _track_by_path(animation: Animation, path: NodePath) -> int:
	for index in animation.get_track_count():
		if animation.track_get_path(index) == path:
			return index
	return -1
