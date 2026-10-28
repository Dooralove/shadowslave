class_name RpgDemoSkillSession
extends RefCounted
## Локальное состояние DEMO-дерева: изученные узлы, выбранный узел и очки.
##
## Состояние живёт только в памяти запущенной сцены. Никаких сохранений,
## характеристик персонажа или боевых эффектов здесь нет.

signal changed

enum State {
	LOCKED,
	AVAILABLE,
	LEARNED,
}

var tree: RpgDemoSkillTree
var points := 0
var selected_id: StringName = &""
var _learned: Dictionary = {}


func initialize(data: RpgDemoSkillTree) -> void:
	tree = data
	reset()


func reset() -> void:
	_learned.clear()
	points = 0
	selected_id = &""
	if tree == null:
		changed.emit()
		return

	points = tree.starting_points
	for node in tree.nodes:
		if node != null and node.initially_learned:
			_learned[node.id] = true
	selected_id = _first_learned_id()
	if selected_id.is_empty() and not tree.nodes.is_empty():
		selected_id = tree.nodes[0].id
	changed.emit()


func get_skill(skill_id: StringName) -> RpgDemoSkill:
	if tree == null:
		return null
	for node in tree.nodes:
		if node != null and node.id == skill_id:
			return node
	return null


func get_selected() -> RpgDemoSkill:
	return get_skill(selected_id)


func select(skill_id: StringName) -> bool:
	if get_skill(skill_id) == null:
		return false
	if selected_id == skill_id:
		return true
	selected_id = skill_id
	changed.emit()
	return true


func get_state(node: RpgDemoSkill) -> State:
	if node == null:
		return State.LOCKED
	if _learned.has(node.id):
		return State.LEARNED
	for required_id in node.required_skill_ids():
		if not _learned.has(required_id):
			return State.LOCKED
	return State.AVAILABLE


func is_learned(skill_id: StringName) -> bool:
	return _learned.has(skill_id)


func can_learn(node: RpgDemoSkill) -> bool:
	return node != null and get_state(node) == State.AVAILABLE and points >= node.cost


func learn(node: RpgDemoSkill) -> bool:
	if not can_learn(node):
		return false
	_learned[node.id] = true
	points -= node.cost
	changed.emit()
	return true


func learn_by_id(skill_id: StringName) -> bool:
	return learn(get_skill(skill_id))


func learned_count() -> int:
	return _learned.size()


func total_count() -> int:
	return tree.nodes.size() if tree != null else 0


func branch_count() -> int:
	var branches: Dictionary = {}
	if tree != null:
		for node in tree.nodes:
			if node != null and node.branch != "START":
				branches[node.branch] = true
	return branches.size()


func _first_learned_id() -> StringName:
	if tree == null:
		return &""
	for node in tree.nodes:
		if node != null and _learned.has(node.id):
			return node.id
	return &""
