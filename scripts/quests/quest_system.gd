extends Node
## Autoload QuestSystem.
##
## Единственный владелец логики заданий. Данные заданий лежат в
## resources/quests/*.tres, изменяемый прогресс — в NightmareRunState, поэтому
## он переживает смену сцен и попадает в snapshot. Система не создаёт второй
## инвентарь, вторую валюту или второй журнал: награды пишут в существующее
## состояние, а журнал читает готовые снимки через RpgQuestScreen.

signal catalog_loaded(scope: StringName)
signal quest_started(quest: QuestDefinition)
signal quest_progressed(quest: QuestDefinition, objective: QuestObjective, progress: int, required: int)
signal quest_objective_completed(quest: QuestDefinition, objective: QuestObjective)
signal quest_completed(quest: QuestDefinition)
signal reward_granted(quest: QuestDefinition, reward: QuestReward)
signal tracked_quest_changed(quest: QuestDefinition)
signal journal_changed
## Короткие сообщения мира (подбор, отдых, закрытая дверь). HUD показывает
## их тем же тостом, что и квестовые события.
signal message_requested(text: String, tone: StringName)

const CATALOG_PATH := "res://resources/quests/quest_catalog.tres"
const ACADEMY_CATALOG_PATH := "res://resources/quests/academy/quest_catalog_academy.tres"
const DEFAULT_SCOPE := &"forgotten_shore"
const EXTERNAL_SOURCE := &"quest_system"

var catalog: QuestCatalog
var active_scope: StringName = &""
var _definitions: Dictionary = {}
var _scope_order: Array[StringName] = []
var _catalog_scopes: Dictionary = {}
var _run_state: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_catalog()
	_run_state = get_node_or_null(^"/root/NightmareRunState")
	if _run_state != null:
		_connect_run_state()


func _load_catalog() -> void:
	_definitions.clear()
	_scope_order.clear()
	_catalog_scopes.clear()
	catalog = null
	for path in [CATALOG_PATH, ACADEMY_CATALOG_PATH]:
		var loaded := load(path) as QuestCatalog
		if loaded == null:
			push_warning("QuestSystem: не удалось загрузить %s" % path)
			continue
		if catalog == null:
			catalog = loaded
		_catalog_scopes[loaded.scope] = true
		var index := loaded.build_index()
		for quest_id in index:
			if _definitions.has(quest_id):
				push_warning("QuestSystem: повторный id задания %s в %s" % [quest_id, path])
				continue
			_definitions[quest_id] = index[quest_id]
			_scope_order.append(quest_id)
	if catalog != null:
		catalog_loaded.emit(catalog.scope)
	else:
		push_error("QuestSystem: не удалось загрузить ни один каталог")


func _connect_run_state() -> void:
	if not _run_state.state_reset.is_connected(_on_state_reset):
		_run_state.state_reset.connect(_on_state_reset)
	if not _run_state.state_restored.is_connected(_on_state_restored):
		_run_state.state_restored.connect(_on_state_restored)
	if not _run_state.flag_changed.is_connected(_on_flag_changed):
		_run_state.flag_changed.connect(_on_flag_changed)
	if not _run_state.item_changed.is_connected(_on_item_changed):
		_run_state.item_changed.connect(_on_item_changed)
	if not _run_state.currency_changed.is_connected(_on_currency_changed):
		_run_state.currency_changed.connect(_on_currency_changed)


## Вход из сцены фрагмента. До активации каталог пассивен: задания
## Первого Кошмара и другие сцены не получают чужих квестов.
func activate_scope(scope: StringName = DEFAULT_SCOPE) -> void:
	var next := StringName(scope)
	if next == &"":
		next = catalog.scope if catalog != null else DEFAULT_SCOPE
	if catalog == null or not _catalog_scopes.has(next):
		push_warning("QuestSystem: неизвестный scope '%s'" % next)
		return
	if active_scope == next:
		refresh_auto_start()
		_ensure_tracked_quest()
		_push_external_objective()
		return
	active_scope = next
	refresh_auto_start()
	_ensure_tracked_quest()
	_push_external_objective()
	journal_changed.emit()


func deactivate_scope() -> void:
	if active_scope == &"":
		return
	active_scope = &""
	_clear_external_objective()
	journal_changed.emit()


func is_scope_active() -> bool:
	return active_scope != &""


func show_message(text: String, tone: StringName = &"info") -> void:
	if text.strip_edges().is_empty():
		return
	message_requested.emit(text, tone)


func get_definition(quest_id: StringName) -> QuestDefinition:
	return _definitions.get(StringName(quest_id), null) as QuestDefinition


func get_state(quest_id: StringName) -> StringName:
	return NightmareRunState.get_quest_state(quest_id)


func is_active(quest_id: StringName) -> bool:
	return get_state(quest_id) == &"active"


func is_completed(quest_id: StringName) -> bool:
	return get_state(quest_id) == &"completed"


func get_objective_progress(quest_id: StringName, objective_id: StringName) -> int:
	return NightmareRunState.get_quest_objective_progress(quest_id, objective_id)


func get_active_quests() -> Array[QuestDefinition]:
	var result: Array[QuestDefinition] = []
	for quest_id in _scope_order:
		var quest := _definitions[quest_id] as QuestDefinition
		if quest != null and quest.scope == active_scope and get_state(quest_id) == &"active":
			result.append(quest)
	return result


func get_completed_quests() -> Array[QuestDefinition]:
	var result: Array[QuestDefinition] = []
	for quest_id in _scope_order:
		var quest := _definitions[quest_id] as QuestDefinition
		if quest != null and quest.scope == active_scope and get_state(quest_id) == &"completed":
			result.append(quest)
	return result


func get_available_quests() -> Array[QuestDefinition]:
	var result: Array[QuestDefinition] = []
	for quest_id in _scope_order:
		var quest := _definitions[quest_id] as QuestDefinition
		if quest != null and quest.scope == active_scope and get_state(quest_id) == &"" and _is_available(quest):
			result.append(quest)
	return result


## Автозапуск только для активного пространства имён. Повторный вызов безопасен.
func refresh_auto_start() -> void:
	if active_scope == &"" or catalog == null:
		return
	var started := false
	for quest_id in _scope_order:
		var quest := _definitions[quest_id] as QuestDefinition
		if quest.scope != active_scope or not quest.auto_start:
			continue
		if get_state(quest_id) != &"":
			continue
		if _is_available(quest):
			if start_quest(quest_id):
				started = true
	if started:
		journal_changed.emit()


func start_quest(quest_id: StringName, force := false) -> bool:
	var quest := get_definition(quest_id)
	if quest == null or quest.scope != active_scope:
		return false
	if get_state(quest_id) != &"":
		return false
	if not force and not _is_available(quest):
		return false

	NightmareRunState.set_quest_state(quest.id, &"active")
	for item in quest.objectives:
		var objective := item as QuestObjective
		if objective != null:
			var initial := _initial_progress(objective)
			NightmareRunState.set_quest_objective_progress(
				quest.id,
				objective.id,
				initial,
				objective.required_count
			)
	quest_started.emit(quest)
	_ensure_tracked_quest()
	_push_external_objective()
	journal_changed.emit()
	_check_completion(quest)
	return true


## Явное завершение для сюжетных сцен, где условие не сводится к событию мира.
func complete_quest(quest_id: StringName, force := false) -> bool:
	var quest := get_definition(quest_id)
	if quest == null or quest.scope != active_scope:
		return false
	if get_state(quest_id) == &"completed":
		return false
	if get_state(quest_id) == &"":
		if not force or not start_quest(quest_id, true):
			return false
	for item in quest.required_objectives():
		if get_objective_progress(quest.id, item.id) < item.required_count:
			NightmareRunState.set_quest_objective_progress(
				quest.id,
				item.id,
				item.required_count,
				item.required_count
			)
	_complete_quest(quest)
	return true


## Универсальная шина событий мира. Сцены не знают id заданий: они сообщают,
## что произошло, а совпадение с целями выполняет QuestSystem.
func notify_event(event_id: StringName, subject_id: StringName = &"", amount := 1) -> void:
	if active_scope == &"" or amount <= 0:
		return
	var changed_quests: Array[QuestDefinition] = []
	for quest in get_active_quests():
		var changed := false
		for item in quest.objectives:
			var objective := item as QuestObjective
			if objective == null or not objective.matches(event_id, subject_id):
				continue
			var current := get_objective_progress(quest.id, objective.id)
			var next := mini(current + amount, objective.required_count)
			if _advance_objective(quest, objective, current, next):
				changed = true
		if changed and not changed_quests.has(quest):
			changed_quests.append(quest)
	for quest in changed_quests:
		_check_completion(quest)


func set_tracked_quest(quest_id: StringName) -> bool:
	var quest := get_definition(quest_id)
	if quest == null or quest.scope != active_scope:
		return false
	var state := get_state(quest_id)
	if state != &"active" and state != &"completed":
		return false
	NightmareRunState.set_tracked_quest(quest.id)
	tracked_quest_changed.emit(quest)
	_push_external_objective()
	journal_changed.emit()
	return true


func get_tracked_quest() -> QuestDefinition:
	var quest_id := NightmareRunState.get_tracked_quest()
	return get_definition(quest_id)


func get_tracked_objective_text() -> String:
	var quest := get_tracked_quest()
	if quest == null or quest.scope != active_scope:
		return ""
	if get_state(quest.id) == &"completed":
		return "%s · завершено" % quest.title
	for item in quest.objectives:
		var objective := item as QuestObjective
		if objective == null:
			continue
		var progress := get_objective_progress(quest.id, objective.id)
		if progress < objective.required_count:
			# Числовой прогресс рисует ProgressBar в ObjectiveLine; не дублируем
			# его в тексте, чтобы строка оставалась короткой.
			return "%s: %s" % [quest.title, objective.text]
	return quest.title


## Снимки для RpgQuestScreen. Экран не меняет состояние и не создаёт
## отдельного источника заданий.
func get_journal_entries() -> Array[QuestJournalEntry]:
	var result: Array[QuestJournalEntry] = []
	if active_scope == &"":
		return result
	var tracked := NightmareRunState.get_tracked_quest()
	for quest_id in _scope_order:
		var quest := _definitions[quest_id] as QuestDefinition
		if quest.scope != active_scope:
			continue
		var state := get_state(quest_id)
		if state == &"" and not _is_available(quest):
			continue
		if state == &"" and not quest.show_available and not quest.auto_start:
			continue
		var entry := QuestJournalEntry.new()
		entry.id = quest.id
		entry.code = quest.get_status_code()
		entry.title = quest.title
		entry.category = quest.get_category_title()
		entry.summary = quest.summary
		entry.description = quest.description
		entry.tracked = tracked == quest.id
		if state == &"completed":
			entry.status = 2
			entry.note = "Задание завершено. Награда выдана."
		elif state == &"active":
			entry.status = 0
			entry.note = "Задание отслеживается в строке цели." if entry.tracked else "Активное задание."
		else:
			entry.status = 1
			entry.note = "Задание доступно: подойдите к точке начала."
		for item in quest.objectives:
			var objective := item as QuestObjective
			if objective == null:
				continue
			var row := QuestJournalObjective.new()
			row.id = objective.id
			row.text = objective.text
			row.optional = objective.optional
			row.required = objective.required_count
			row.progress = get_objective_progress(quest.id, objective.id)
			row.completed = row.progress >= objective.required_count
			entry.objectives.append(row)
		result.append(entry)
	return result


## Ближайшая незавершённая цель — для HUD и тестов.
func get_tracked_objective() -> QuestObjective:
	var quest := get_tracked_quest()
	if quest == null:
		return null
	for item in quest.objectives:
		var objective := item as QuestObjective
		if objective != null and get_objective_progress(quest.id, objective.id) < objective.required_count:
			return objective
	return null


func _is_available(quest: QuestDefinition) -> bool:
	if quest == null:
		return false
	if not NightmareRunState.require(quest.prerequisites):
		return false
	for required_id in quest.required_quests:
		if get_state(required_id) != &"completed":
			return false
	return true


func _initial_progress(objective: QuestObjective) -> int:
	match objective.kind:
		QuestObjective.Kind.COLLECT:
			return mini(NightmareRunState.get_item_count(objective.target_id), objective.required_count)
		QuestObjective.Kind.CURRENCY:
			return mini(NightmareRunState.get_currency(objective.target_id), objective.required_count)
		QuestObjective.Kind.FLAG:
			return objective.required_count if NightmareRunState.has_flag(objective.target_id) else 0
	return 0


func _advance_objective(quest: QuestDefinition, objective: QuestObjective, current: int, next: int) -> bool:
	if next <= current:
		return false
	NightmareRunState.set_quest_objective_progress(
		quest.id, objective.id, next, objective.required_count
	)
	quest_progressed.emit(quest, objective, next, objective.required_count)
	if next >= objective.required_count:
		quest_objective_completed.emit(quest, objective)
	journal_changed.emit()
	return true


func _check_completion(quest: QuestDefinition) -> void:
	if get_state(quest.id) != &"active":
		return
	for item in quest.required_objectives():
		if get_objective_progress(quest.id, item.id) < item.required_count:
			return
	_complete_quest(quest)


func _complete_quest(quest: QuestDefinition) -> void:
	if get_state(quest.id) == &"completed":
		return
	NightmareRunState.set_quest_state(quest.id, &"completed")
	if quest.completion_flag != &"":
		NightmareRunState.set_flag(quest.completion_flag)
	if not NightmareRunState.is_quest_reward_claimed(quest.id):
		for item in quest.rewards:
			var reward := item as QuestReward
			if reward != null and not reward.is_empty():
				_grant_reward(quest, reward)
		NightmareRunState.mark_quest_reward_claimed(quest.id)
	quest_completed.emit(quest)
	_ensure_tracked_quest()
	_push_external_objective()
	journal_changed.emit()
	if not OS.has_feature("headless"):
		var save_system := get_node_or_null(^"/root/SaveSystem")
		if save_system != null and save_system.has_method(&"save_game"):
			save_system.call(&"save_game", "quest")


func _grant_reward(quest: QuestDefinition, reward: QuestReward) -> void:
	if reward.item_id != &"":
		NightmareRunState.add_item(reward.item_id, reward.item_count)
	if reward.currency_id != &"" and reward.currency_amount > 0:
		NightmareRunState.add_currency(reward.currency_id, reward.currency_amount)
	if reward.memory_id != &"":
		NightmareRunState.unlock_memory(reward.memory_id)
	if reward.flag != &"":
		NightmareRunState.set_flag(reward.flag)
	if reward.heal_amount > 0.0:
		var player := get_tree().get_first_node_in_group(&"player")
		if player != null:
			var health := player.get_node_or_null(^"Health") as HealthComponent
			if health != null:
				health.heal(reward.heal_amount)
	reward_granted.emit(quest, reward)


func _ensure_tracked_quest() -> void:
	if active_scope == &"":
		return
	var tracked := get_tracked_quest()
	if tracked != null and tracked.scope == active_scope and get_state(tracked.id) == &"active":
		return
	var chosen: QuestDefinition = null
	for quest in get_active_quests():
		if quest.category == QuestDefinition.Category.MAIN:
			chosen = quest
			break
	if chosen == null:
		var active := get_active_quests()
		if not active.is_empty():
			chosen = active[0]
	NightmareRunState.set_tracked_quest(chosen.id if chosen != null else &"")
	tracked_quest_changed.emit(chosen)


func _push_external_objective() -> void:
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide == null:
		return
	if active_scope == &"":
		_clear_external_objective()
		return
	var text := get_tracked_objective_text()
	if text.strip_edges().is_empty():
		_clear_external_objective()
	elif guide.has_method(&"set_external_objective"):
		guide.call(&"set_external_objective", text, EXTERNAL_SOURCE)


func _clear_external_objective() -> void:
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide != null and guide.has_method(&"clear_external_objective"):
		guide.call(&"clear_external_objective", EXTERNAL_SOURCE)


func _on_flag_changed(flag_name: StringName, value: bool) -> void:
	if not value:
		return
	refresh_auto_start()
	notify_event(&"flag", flag_name)


func _on_item_changed(item_id: StringName, count: int) -> void:
	if active_scope == &"":
		return
	for quest in get_active_quests():
		var changed := false
		for item in quest.objectives:
			var objective := item as QuestObjective
			if objective == null or objective.kind != QuestObjective.Kind.COLLECT:
				continue
			if objective.target_id != item_id:
				continue
			var current := get_objective_progress(quest.id, objective.id)
			var next := maxi(current, mini(count, objective.required_count))
			if _advance_objective(quest, objective, current, next):
				changed = true
		if changed:
			_check_completion(quest)


func _on_currency_changed(currency_id: StringName, amount: int) -> void:
	if active_scope == &"":
		return
	for quest in get_active_quests():
		var changed := false
		for item in quest.objectives:
			var objective := item as QuestObjective
			if objective == null or objective.kind != QuestObjective.Kind.CURRENCY:
				continue
			if objective.target_id != currency_id:
				continue
			var current := get_objective_progress(quest.id, objective.id)
			var next := maxi(current, mini(amount, objective.required_count))
			if _advance_objective(quest, objective, current, next):
				changed = true
		if changed:
			_check_completion(quest)


func _on_state_reset() -> void:
	_clear_external_objective()
	refresh_auto_start()
	_ensure_tracked_quest()
	_push_external_objective()
	journal_changed.emit()


func _on_state_restored() -> void:
	refresh_auto_start()
	_ensure_tracked_quest()
	_push_external_objective()
	journal_changed.emit()
