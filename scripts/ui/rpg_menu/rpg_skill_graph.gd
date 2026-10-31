class_name RpgSkillGraph
extends Control
## Поле DEMO-дерева: рисует связи и размещает карточки узлов.
##
## Граф только отображает состояние RpgDemoSkillSession. Клик по карточке
## выбирает узел; изучение выполняется отдельной кнопкой на панели описания.

const NODE_SCENE := preload("res://scenes/ui/rpg_menu/skill_node.tscn")
const NODE_SIZE := Vector2(150.0, 70.0)

var session: RpgDemoSkillSession
var _cards: Dictionary = {}
var _branch_labels: Array[Label] = []


func _ready() -> void:
	resized.connect(_layout_cards)
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(data: RpgDemoSkillSession) -> void:
	if session != null and session.changed.is_connected(_on_session_changed):
		session.changed.disconnect(_on_session_changed)
	session = data
	if session == null:
		return
	session.changed.connect(_on_session_changed)
	_build()


func focus_selected() -> void:
	if session == null:
		return
	var card := _cards.get(session.selected_id) as RpgSkillNode
	if card != null:
		card.grab_focus()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_cards.clear()
	_branch_labels.clear()
	if session == null or session.tree == null:
		return

	for node in session.tree.nodes:
		if node == null:
			continue
		var card := NODE_SCENE.instantiate() as RpgSkillNode
		add_child(card)
		card.pressed.connect(_on_node_pressed.bind(node.id))
		card.focus_entered.connect(_on_node_focused.bind(node.id))
		_cards[node.id] = card

	_create_branch_labels()
	_layout_cards()
	_refresh_cards()


func _create_branch_labels() -> void:
	var first_by_branch: Dictionary = {}
	for node in session.tree.nodes:
		if node == null or node.branch == "START":
			continue
		if not first_by_branch.has(node.branch):
			first_by_branch[node.branch] = node

	for branch in first_by_branch:
		var node := first_by_branch[branch] as RpgDemoSkill
		var label := Label.new()
		label.text = node.branch_title
		label.theme_type_variation = &"TinyMutedLabel"
		label.add_theme_font_size_override("font_size", 9)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.custom_minimum_size = Vector2(NODE_SIZE.x, 16.0)
		label.size = Vector2(NODE_SIZE.x, 16.0)
		add_child(label)
		_branch_labels.append(label)


func _layout_cards() -> void:
	if session == null or session.tree == null:
		return
	for node in session.tree.nodes:
		if node == null:
			continue
		var card := _cards.get(node.id) as RpgSkillNode
		if card == null:
			continue
		var center := node.graph_position * size
		var card_position := center - NODE_SIZE * 0.5
		card_position.x = clampf(card_position.x, 0.0, maxf(0.0, size.x - NODE_SIZE.x))
		card_position.y = clampf(card_position.y, 0.0, maxf(0.0, size.y - NODE_SIZE.y))
		card.position = card_position
		card.size = NODE_SIZE

	var first_by_branch: Dictionary = {}
	for node in session.tree.nodes:
		if node == null or node.branch == "START":
			continue
		if not first_by_branch.has(node.branch):
			first_by_branch[node.branch] = node

	var label_index := 0
	for branch in first_by_branch:
		if label_index >= _branch_labels.size():
			break
		var node := first_by_branch[branch] as RpgDemoSkill
		var center := node.graph_position * size
		var label := _branch_labels[label_index]
		label.position = Vector2(
			clampf(center.x - NODE_SIZE.x * 0.5, 0.0, maxf(0.0, size.x - NODE_SIZE.x)),
			maxf(2.0, center.y - NODE_SIZE.y * 0.5 - 21.0)
		)
		label.size = Vector2(NODE_SIZE.x, 16.0)
		label_index += 1

	queue_redraw()


func _draw() -> void:
	_draw_grid()
	if session == null or session.tree == null:
		return
	_draw_links()
	_draw_root_marker()


func _draw_grid() -> void:
	var grid_color := Color(0.33, 0.3, 0.25, 0.055)
	var x := 48.0
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), grid_color, 1.0)
		x += 64.0
	var y := 40.0
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), grid_color, 1.0)
		y += 64.0
	for row_y in [0.19, 0.5, 0.81]:
		draw_line(
			Vector2(0.2 * size.x, row_y * size.y),
			Vector2(0.98 * size.x, row_y * size.y),
			Color(0.45, 0.39, 0.3, 0.035),
			1.0
		)


func _draw_links() -> void:
	for target in session.tree.nodes:
		if target == null:
			continue
		for required_id in target.required_skill_ids():
			var source := session.get_skill(required_id)
			if source == null:
				continue
			var from_point := _card_right_center(source)
			var to_point := _card_left_center(target)
			var state := session.get_state(target)
			var color := RpgMenuTheme.LINE_SOFT
			var width := 1.0
			if state == RpgDemoSkillSession.State.LEARNED:
				color = Color(RpgMenuTheme.BRONZE_BRIGHT, 0.82)
				width = 2.0
			elif state == RpgDemoSkillSession.State.AVAILABLE:
				color = Color(RpgMenuTheme.BRONZE, 0.72)
				width = 1.5

			var points := _curve_points(from_point, to_point)
			draw_polyline(points, Color(0.01, 0.012, 0.013, 0.8), width + 2.4, true)
			draw_polyline(points, color, width, true)
			if state != RpgDemoSkillSession.State.LOCKED:
				_draw_connection_mark(points, color)


func _draw_root_marker() -> void:
	for node in session.tree.nodes:
		if node != null and node.initially_learned:
			var center := node.graph_position * size
			draw_arc(center, 50.0, -0.55, 0.55, 18, Color(0.84, 0.67, 0.45, 0.12), 1.0)
			break


func _draw_connection_mark(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var middle := points[int(points.size() / 2)]
	var mark := PackedVector2Array([
		middle + Vector2(0.0, -2.6),
		middle + Vector2(2.6, 0.0),
		middle + Vector2(0.0, 2.6),
		middle + Vector2(-2.6, 0.0),
	])
	draw_colored_polygon(mark, color)


func _curve_points(from_point: Vector2, to_point: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var control_offset := maxf(42.0, absf(to_point.x - from_point.x) * 0.42)
	var c1 := from_point + Vector2(control_offset, 0.0)
	var c2 := to_point - Vector2(control_offset, 0.0)
	for step in 19:
		var t := float(step) / 18.0
		var inv := 1.0 - t
		var point := (
			from_point * inv * inv * inv
			+ c1 * 3.0 * inv * inv * t
			+ c2 * 3.0 * inv * t * t
			+ to_point * t * t * t
		)
		result.append(point)
	return result


func _card_right_center(node: RpgDemoSkill) -> Vector2:
	var card := _cards.get(node.id) as RpgSkillNode
	if card == null:
		return node.graph_position * size
	return card.position + Vector2(NODE_SIZE.x, NODE_SIZE.y * 0.5)


func _card_left_center(node: RpgDemoSkill) -> Vector2:
	var card := _cards.get(node.id) as RpgSkillNode
	if card == null:
		return node.graph_position * size
	return card.position + Vector2(0.0, NODE_SIZE.y * 0.5)


func _refresh_cards() -> void:
	if session == null or session.tree == null:
		return
	for node in session.tree.nodes:
		if node == null:
			continue
		var card := _cards.get(node.id) as RpgSkillNode
		if card == null:
			continue
		card.setup(node, session.get_state(node), node.id == session.selected_id)
	queue_redraw()


func _on_session_changed() -> void:
	_refresh_cards()


func _on_node_pressed(skill_id: StringName) -> void:
	if session != null:
		session.select(skill_id)


func _on_node_focused(skill_id: StringName) -> void:
	if session != null and session.selected_id != skill_id:
		session.select(skill_id)
