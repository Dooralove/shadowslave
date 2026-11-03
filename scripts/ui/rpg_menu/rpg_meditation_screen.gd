class_name RpgMeditationScreen
extends Control
## Экран медитации: сводка текущего события и безопасный возврат к чекпоинту.
##
## Это не отдельная система сохранений. Кнопка возврата использует уже
## существующий FallRecovery игрока, поэтому ведёт себя как возврат после
## падения: сбрасывает бой и ставит Санни в последнюю точку.

signal feedback_requested(text: String, tone: StringName)
signal return_requested

const RULES_PATH := "res://resources/campaign/journal/rules_of_nightmare.tres"

const ITEM_TITLES := {
	&"key": "Ключ",
	&"silver_bell": "Серебряный колокол",
	&"cloak": "Плащ",
	&"boots": "Сапоги",
	&"flasks": "Фляги",
	&"sword": "Клинок",
	&"puppeteer_shroud": "Саван Кукловода",
	&"shadow_blessing": "Благословение тени",
	&"provisions": "Провизия",
	&"water_skin": "Мех с водой",
	&"field_medkit": "Полевая аптечка",
	&"rope": "Верёвка",
	&"oil_flask": "Масло сколопендры",
	&"torch": "Факел из кости",
	&"carapace_plate": "Пластина панциря",
	&"carapace_claw": "Клешня карапакса",
	&"carapace_joint": "Сочленение карапакса",
	&"centurion_scythe_fragment": "Обломок косы центуриона",
	&"demon_fat": "Жир демона",
	&"blood_fiend_fang": "Клык кровавого демона",
	&"bone_spear": "Костяное копьё",
	&"ancient_coral_plate": "Древняя коралловая пластина",
	&"reef_warden_helm": "Шлем Кораллового Стража",
	&"reef_warden_plate": "Нагрудник Кораллового Стража",
	&"reef_warden_greaves": "Поножи Кораллового Стража",
	&"iron_sword_worn": "Изношенный железный меч",
	&"iron_sword_used": "Подержанный железный меч",
	&"iron_sword_fine": "Целый железный меч",
	&"leather_cuirass_worn": "Потёртая кожаная куртка",
	&"leather_cuirass_used": "Кожаная куртка",
	&"bandit_cloak": "Плащ разбойника",
}

var _beat_title: Label
var _beat_objective: Label
var _checkpoint_label: Label
var _items_label: Label
var _session_meta: Label
var _rules_body: Label
var _return_button: Button
var _return_hint: Label


func _ready() -> void:
	theme = RpgMenuTheme.build()
	_build_ui()
	refresh()


func refresh() -> void:
	var guide := get_node_or_null("/root/CampaignGuide")
	var run_state := get_node_or_null("/root/NightmareRunState")

	var beat_id := &""
	var beat_title := ""
	var objective := ""
	if guide != null:
		if guide.has_method(&"get_current_beat_id"):
			beat_id = StringName(guide.call(&"get_current_beat_id"))
		if guide.has_method(&"get_current_beat_title"):
			beat_title = String(guide.call(&"get_current_beat_title"))
		if guide.has_method(&"get_display_objective"):
			objective = String(guide.call(&"get_display_objective"))
	if run_state != null and beat_id == &"" and run_state.has_method(&"get_current_beat"):
		beat_id = StringName(run_state.call(&"get_current_beat"))

	_beat_title.text = beat_title if not beat_title.is_empty() else (
		"СОБЫТИЕ %s" % String(beat_id) if beat_id != &"" else "СОБЫТИЕ НЕ НАЧАЛОСЬ"
	)
	_beat_objective.text = objective if not objective.strip_edges().is_empty() else "Активной цели нет."
	_session_meta.text = "СОБЫТИЕ · %s" % (String(beat_id) if beat_id != &"" else "—")

	var checkpoint := &""
	if run_state != null and run_state.has_method(&"get_checkpoint_id"):
		checkpoint = StringName(run_state.call(&"get_checkpoint_id"))
	if run_state != null and run_state.has_method(&"get_item_count"):
		_checkpoint_label.text = "ТОЧКА ВОЗВРАТА · %s" % (
			String(checkpoint) if checkpoint != &"" else "ещё не назначена"
		)
	else:
		_checkpoint_label.text = "ТОЧКА ВОЗВРАТА · нет данных"
	_items_label.text = _items_text(run_state)

	var rules := load(RULES_PATH) as Resource
	if rules != null:
		_rules_body.text = String(rules.get(&"text"))
	else:
		_rules_body.text = "Правила Кошмара не загружены."

	var available := _recovery_available()
	_return_button.disabled = not available
	_return_hint.text = (
		"Вернуться в последнюю точку и закрыть меню."
		if available
		else "Возврат недоступен: Санни или точка возврата не найдены."
	)


func is_return_available() -> bool:
	return _recovery_available()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)

	var kicker := Label.new()
	kicker.text = "МЕДИТАЦИЯ · БЕЗОПАСНАЯ ПАУЗА"
	kicker.theme_type_variation = &"OverlineLabel"
	titles.add_child(kicker)

	var title := Label.new()
	title.text = "ТИХАЯ МИНУТА"
	title.theme_type_variation = &"ScreenTitleSmall"
	titles.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Сверьте путь, прочитайте правило и вернитесь в Кошмар."
	subtitle.theme_type_variation = &"MutedLabel"
	titles.add_child(subtitle)

	_session_meta = Label.new()
	_session_meta.theme_type_variation = &"BronzeLabel"
	_session_meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_session_meta)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.27, 0.25, 0.21, 0.65)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(470, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 9)
	body.add_child(left)

	var beat_panel := PanelContainer.new()
	beat_panel.theme_type_variation = &"SubPanel"
	left.add_child(beat_panel)

	var beat_box := VBoxContainer.new()
	beat_box.add_theme_constant_override("separation", 4)
	beat_panel.add_child(beat_box)

	var beat_caption := Label.new()
	beat_caption.text = "ТЕКУЩЕЕ СОБЫТИЕ"
	beat_caption.theme_type_variation = &"SectionLabel"
	beat_box.add_child(beat_caption)

	_beat_title = Label.new()
	_beat_title.theme_type_variation = &"DisplayValue"
	_beat_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	beat_box.add_child(_beat_title)

	_beat_objective = Label.new()
	_beat_objective.theme_type_variation = &"BodyLargeLabel"
	_beat_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	beat_box.add_child(_beat_objective)

	_checkpoint_label = Label.new()
	_checkpoint_label.theme_type_variation = &"TinyMutedLabel"
	beat_box.add_child(_checkpoint_label)

	var items_panel := PanelContainer.new()
	items_panel.theme_type_variation = &"SubPanel"
	left.add_child(items_panel)

	var items_box := VBoxContainer.new()
	items_box.add_theme_constant_override("separation", 4)
	items_panel.add_child(items_box)

	var items_caption := Label.new()
	items_caption.text = "ПРИ СЕБЕ"
	items_caption.theme_type_variation = &"SectionLabel"
	items_box.add_child(items_caption)

	_items_label = Label.new()
	_items_label.theme_type_variation = &"MutedLabel"
	_items_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items_box.add_child(_items_label)

	var right := PanelContainer.new()
	right.theme_type_variation = &"ParchmentPanel"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var parchment := MarginContainer.new()
	parchment.add_theme_constant_override("margin_left", 30)
	parchment.add_theme_constant_override("margin_right", 30)
	parchment.add_theme_constant_override("margin_top", 24)
	parchment.add_theme_constant_override("margin_bottom", 22)
	right.add_child(parchment)

	var rules_box := VBoxContainer.new()
	rules_box.add_theme_constant_override("separation", 7)
	parchment.add_child(rules_box)

	var rules_caption := Label.new()
	rules_caption.text = "ПРАВИЛА КОШМАРА"
	rules_caption.theme_type_variation = &"ParchmentOverline"
	rules_box.add_child(rules_caption)

	var rules_title := Label.new()
	rules_title.text = "Прежде чем идти дальше"
	rules_title.theme_type_variation = &"ParchmentTitle"
	rules_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_box.add_child(rules_title)

	var rules_rule := ColorRect.new()
	rules_rule.custom_minimum_size = Vector2(0, 1)
	rules_rule.color = Color(0.35, 0.29, 0.19, 0.5)
	rules_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules_box.add_child(rules_rule)

	_rules_body = Label.new()
	_rules_body.theme_type_variation = &"ParchmentBody"
	_rules_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_box.add_child(_rules_body)

	_return_button = Button.new()
	_return_button.text = "ВЕРНУТЬСЯ К ТОЧКЕ"
	_return_button.theme_type_variation = &"ParchmentButton"
	_return_button.custom_minimum_size = Vector2(0, 46)
	_return_button.pressed.connect(_on_return_pressed)
	rules_box.add_child(_return_button)

	_return_hint = Label.new()
	_return_hint.theme_type_variation = &"ParchmentHint"
	_return_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_box.add_child(_return_hint)

	var footer := Label.new()
	footer.text = "ВОЗВРАТ ИСПОЛЬЗУЕТ СУЩЕСТВУЮЩУЮ ТОЧКУ ПАДЕНИЯ/СМЕРТИ · ESC — ЗАКРЫТЬ"
	footer.theme_type_variation = &"TinyMutedLabel"
	column.add_child(footer)


func _items_text(run_state: Node) -> String:
	if run_state == null or not run_state.has_method(&"get_item_count"):
		return "Данные инвентаря недоступны."
	var lines: Array[String] = []
	var ids: Variant = run_state.get(&"ITEM_IDS")
	if ids is Array:
		for id in ids:
			var count := int(run_state.call(&"get_item_count", id))
			if count > 0:
				var title := String(ITEM_TITLES.get(StringName(id), String(id)))
				lines.append("%s × %d" % [title, count])
	if lines.is_empty():
		return "Пока пусто. Сюжетные предметы появятся здесь по мере прохождения."
	return "\n".join(lines)


func _recovery_available() -> bool:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return false
	var recovery := player.get_node_or_null(^"FallRecovery")
	if recovery == null:
		return false
	if recovery.has_method(&"has_checkpoint") and not bool(recovery.call(&"has_checkpoint")):
		return false
	return recovery.has_method(&"recover")


func _on_return_pressed() -> void:
	if not _recovery_available():
		feedback_requested.emit("Возврат недоступен: точка ещё не назначена.", &"warning")
		return
	return_requested.emit()
