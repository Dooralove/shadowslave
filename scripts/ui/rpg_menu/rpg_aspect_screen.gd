class_name RpgAspectScreen
extends Control
## Экран «Аспект / навыки» с временным DEMO-деревом.
##
## Компоновка повторяет инвентарь: категории/сводка слева, рабочая область
## в центре и описание выбранного объекта справа. Дерево, очки и состояния
## существуют только в RpgDemoSkillSession и не подключены к игре.

signal feedback_requested(text: String, tone: StringName)
signal navigate_requested(section: StringName)

const LEGEND_STATES: Array[int] = [
	RpgDemoSkillSession.State.LEARNED,
	RpgDemoSkillSession.State.AVAILABLE,
	RpgDemoSkillSession.State.LOCKED,
]

@onready var graph: RpgSkillGraph = %SkillGraph
@onready var detail_scroll: ScrollContainer = %DetailScroll
@onready var points_value: Label = %PointsValue
@onready var spent_value: Label = %SpentValue
@onready var learned_bar: ProgressBar = %LearnedBar
@onready var learned_label: Label = %LearnedLabel
@onready var legend_rows: VBoxContainer = %LegendRows
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton
@onready var node_count_label: Label = %NodeCountLabel
@onready var node_overline: Label = %NodeOverline
@onready var node_title: Label = %NodeTitle
@onready var node_status: Label = %NodeStatus
@onready var node_meta: Label = %NodeMeta
@onready var node_description: Label = %NodeDescription
@onready var effect_value: Label = %EffectValue
@onready var requirement_rows: VBoxContainer = %RequirementRows
@onready var requirement_summary: Label = %RequirementSummary
@onready var learn_button: Button = %LearnButton
@onready var action_hint: Label = %ActionHint

var session: RpgDemoSkillSession
var _legend_counts: Dictionary = {}
var _last_node_id: StringName = &""


func _ready() -> void:
	learn_button.pressed.connect(_on_learn_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_build_legend()


func setup(tree: RpgDemoSkillTree) -> void:
	if session != null and session.changed.is_connected(_on_session_changed):
		session.changed.disconnect(_on_session_changed)

	session = RpgDemoSkillSession.new()
	session.initialize(tree)
	session.changed.connect(_on_session_changed)
	graph.setup(session)
	_refresh()


func focus_initial() -> void:
	graph.focus_selected()


func _build_legend() -> void:
	for child in legend_rows.get_children():
		legend_rows.remove_child(child)
		child.queue_free()
	_legend_counts.clear()

	for state in LEGEND_STATES:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 20)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 7)
		legend_rows.add_child(row)

		var mark := Label.new()
		mark.text = RpgSkillNode.state_mark(state)
		mark.custom_minimum_size = Vector2(18, 0)
		mark.theme_type_variation = &"TinyMutedLabel"
		mark.add_theme_color_override("font_color", RpgSkillNode.state_color(state))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)

		var title := Label.new()
		title.text = RpgSkillNode.state_title(state)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.theme_type_variation = &"MicroLabel"
		title.add_theme_color_override("font_color", RpgSkillNode.state_color(state))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)

		var count := Label.new()
		count.text = "0"
		count.theme_type_variation = &"TinyMutedLabel"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(count)
		_legend_counts[state] = count


func _refresh() -> void:
	if session == null or session.tree == null:
		return

	points_value.text = str(session.points)
	spent_value.text = "ИЗРАСХОДОВАНО: %d" % maxi(0, session.tree.starting_points - session.points)
	learned_label.text = "ИЗУЧЕНО %d ИЗ %d УЗЛОВ" % [
		session.learned_count(),
		session.total_count(),
	]
	learned_bar.max_value = maxf(1.0, float(session.total_count()))
	learned_bar.value = float(session.learned_count())
	node_count_label.text = "%d УЗЛОВ · %d ВЕТВИ" % [
		session.total_count(),
		session.branch_count(),
	]
	_refresh_legend()
	_refresh_selected()
	graph.queue_redraw()


func _refresh_legend() -> void:
	var counts := {
		RpgDemoSkillSession.State.LEARNED: 0,
		RpgDemoSkillSession.State.AVAILABLE: 0,
		RpgDemoSkillSession.State.LOCKED: 0,
	}
	for node in session.tree.nodes:
		if node != null:
			counts[session.get_state(node)] += 1
	for state in _legend_counts:
		var label := _legend_counts[state] as Label
		label.text = str(counts[state])


func _refresh_selected() -> void:
	var node := session.get_selected()
	if node == null:
		_clear_details()
		return

	var state := session.get_state(node)
	var state_text := RpgSkillNode.state_title(state)
	var state_color := RpgSkillNode.state_color(state)

	node_title.text = node.display_name
	node_status.text = "%s %s" % [RpgSkillNode.state_mark(state), state_text]
	node_status.add_theme_color_override("font_color", state_color)
	node_meta.text = "%s · %s · СТОИМОСТЬ: %d %s" % [
		node.code,
		node.branch_title,
		node.cost,
		_points_word(node.cost),
	]
	node_description.text = node.description
	effect_value.text = node.effect_note
	_rebuild_requirements(node, state)
	_refresh_action(node, state)

	if _last_node_id != node.id:
		_detail_scroll_reset()
		_last_node_id = node.id


func _clear_details() -> void:
	node_title.text = "УЗЕЛ НЕ ВЫБРАН"
	node_status.text = "— НЕТ ДАННЫХ"
	node_status.add_theme_color_override("font_color", RpgMenuTheme.DIM)
	node_meta.text = "DEMO"
	node_description.text = "Выберите узел на DEMO-дереве."
	effect_value.text = "—"
	_clear_rows(requirement_rows)
	requirement_summary.text = "—"
	learn_button.text = "НЕТ ВЫБРАННОГО УЗЛА"
	learn_button.theme_type_variation = &"UnavailableActionButton"
	learn_button.tooltip_text = "Сначала выберите узел."
	action_hint.text = "Выбор узла не меняет состояние."
	action_hint.add_theme_color_override("font_color", RpgMenuTheme.MUTED)


func _rebuild_requirements(node: RpgDemoSkill, state: RpgDemoSkillSession.State) -> void:
	_clear_rows(requirement_rows)
	var required := node.required_skill_ids()
	if required.is_empty():
		var empty := Label.new()
		empty.text = "Нет обязательных предшественников."
		empty.theme_type_variation = &"MutedLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		requirement_rows.add_child(empty)
	else:
		for required_id in required:
			var dependency := session.get_skill(required_id)
			if dependency == null:
				_add_requirement_row("Неизвестный узел: %s" % required_id, "НЕТ", RpgMenuTheme.RUST)
				continue
			var dependency_state := session.get_state(dependency)
			_add_requirement_row(
				dependency.display_name,
				RpgSkillNode.state_title(dependency_state),
				RpgSkillNode.state_color(dependency_state)
			)

	var cost_color := (
		RpgMenuTheme.BRONZE_BRIGHT
		if session.points >= node.cost
		else RpgMenuTheme.RUST
	)
	_add_requirement_row(
		"Стоимость изучения",
		"%d %s" % [node.cost, _points_word(node.cost)],
		cost_color
	)

	requirement_summary.add_theme_color_override("font_color", RpgMenuTheme.DIM)
	match state:
		RpgDemoSkillSession.State.LEARNED:
			requirement_summary.text = "Все требования выполнены. Узел уже изучен в этой DEMO-сессии."
		RpgDemoSkillSession.State.AVAILABLE:
			if session.points >= node.cost:
				requirement_summary.text = "Требования выполнены. Узел можно изучить."
			else:
				requirement_summary.text = "Требования выполнены, но не хватает %d %s." % [
					node.cost - session.points,
					_points_word(node.cost - session.points),
				]
				requirement_summary.add_theme_color_override("font_color", RpgMenuTheme.RUST)
		_:
			requirement_summary.text = "Сначала изучите предшественников, отмеченных выше."


func _refresh_action(node: RpgDemoSkill, state: RpgDemoSkillSession.State) -> void:
	var cost_text := "%d %s" % [node.cost, _points_word(node.cost)]
	var hint_color := RpgMenuTheme.MUTED
	match state:
		RpgDemoSkillSession.State.LEARNED:
			learn_button.text = "УЗЕЛ УЖЕ ИЗУЧЕН"
			learn_button.theme_type_variation = &"UnavailableActionButton"
			learn_button.tooltip_text = "Этот DEMO-узел уже изучен."
			action_hint.text = "Изучение меняет только DEMO-модель и сбрасывается при перезапуске."
		RpgDemoSkillSession.State.AVAILABLE:
			if session.points >= node.cost:
				learn_button.text = "ИЗУЧИТЬ · %s" % cost_text
				learn_button.theme_type_variation = &"PrimaryButton"
				learn_button.tooltip_text = "Списать %s и изучить узел." % cost_text
				action_hint.text = "Эффект не назначен: изменится только состояние DEMO-дерева."
			else:
				var missing := node.cost - session.points
				learn_button.text = "НЕДОСТАТОЧНО DEMO-ОЧКОВ"
				learn_button.theme_type_variation = &"UnavailableActionButton"
				learn_button.tooltip_text = "Не хватает %d %s." % [missing, _points_word(missing)]
				action_hint.text = "Не хватает %d %s. Сбросьте DEMO-дерево, чтобы вернуть очки." % [
					missing,
					_points_word(missing),
				]
				hint_color = RpgMenuTheme.RUST
		_:
			learn_button.text = "ТРЕБУЕТСЯ ПРЕДШЕСТВЕННИК"
			learn_button.theme_type_variation = &"UnavailableActionButton"
			learn_button.tooltip_text = "Сначала изучите связанные узлы."
			action_hint.text = "Сначала изучите предшественников. Выбор узла не меняет состояние."
			hint_color = RpgMenuTheme.RUST
	action_hint.add_theme_color_override("font_color", hint_color)


func _add_requirement_row(text: String, state_text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	requirement_rows.add_child(row)

	var marker := Label.new()
	marker.text = "◆"
	marker.theme_type_variation = &"TinyMutedLabel"
	marker.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_DIM)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var state := Label.new()
	state.text = state_text
	state.theme_type_variation = &"TinyMutedLabel"
	state.add_theme_color_override("font_color", color)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(state)


func _on_learn_pressed() -> void:
	if session == null:
		return
	var node := session.get_selected()
	if node == null:
		_warn("Сначала выберите узел DEMO-дерева.")
		return

	var state := session.get_state(node)
	if state == RpgDemoSkillSession.State.LEARNED:
		_warn("Узел «%s» уже изучен." % node.display_name)
		return
	if state == RpgDemoSkillSession.State.LOCKED:
		var missing_names := _missing_requirement_names(node)
		if missing_names.is_empty():
			_warn("Узел «%s» заблокирован." % node.display_name)
		else:
			_warn("Сначала изучите: %s." % ", ".join(missing_names))
		return
	if session.points < node.cost:
		var missing := node.cost - session.points
		_warn("Недостаточно DEMO-очков: нужно %d %s." % [missing, _points_word(missing)])
		return

	var node_name := node.display_name
	var spent := node.cost
	var remaining := session.points - spent
	if session.learn(node):
		feedback_requested.emit(
			"Изучен DEMO-узел: %s. Списано %d %s, осталось %d." % [
				node_name,
				spent,
				_points_word(spent),
				remaining,
			],
			&"success"
		)


func _on_reset_pressed() -> void:
	if session == null:
		return
	session.reset()
	feedback_requested.emit(
		"DEMO-дерево сброшено. Очки и состояния возвращены к исходным.",
		&"info"
	)


func _on_back_pressed() -> void:
	navigate_requested.emit(&"inventory")


func _on_session_changed() -> void:
	_refresh()


func _detail_scroll_reset() -> void:
	detail_scroll.scroll_vertical = 0


func _missing_requirement_names(node: RpgDemoSkill) -> Array[String]:
	var result: Array[String] = []
	for required_id in node.required_skill_ids():
		if session.is_learned(required_id):
			continue
		var dependency := session.get_skill(required_id)
		result.append(dependency.display_name if dependency != null else String(required_id))
	return result


func _warn(text: String) -> void:
	feedback_requested.emit(text, &"warning")


func _clear_rows(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _points_word(value: int) -> String:
	var mod_100 := value % 100
	var mod_10 := value % 10
	if mod_100 >= 11 and mod_100 <= 14:
		return "DEMO-ОЧКОВ"
	if mod_10 == 1:
		return "DEMO-ОЧКО"
	if mod_10 >= 2 and mod_10 <= 4:
		return "DEMO-ОЧКА"
	return "DEMO-ОЧКОВ"
