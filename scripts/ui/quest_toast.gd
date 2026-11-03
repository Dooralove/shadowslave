class_name QuestToast
extends Label
## Короткий тост квестовых событий. Не отдельный экран и не второй журнал:
## только обратная связь о старте, цели и награде.

@export var hold_seconds := 2.4
@export var fade_seconds := 0.3

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	if theme == null:
		theme = RpgMenuTheme.build()
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests == null:
		return
	quests.quest_started.connect(_on_quest_started)
	quests.quest_completed.connect(_on_quest_completed)
	quests.reward_granted.connect(_on_reward_granted)
	quests.message_requested.connect(show_toast)


func show_toast(message: String, tone: StringName = &"info") -> void:
	var value := message.strip_edges()
	if value.is_empty():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	text = value
	var color := RpgMenuTheme.TEXT_BRIGHT
	match tone:
		&"success", &"quest":
			color = RpgMenuTheme.SUCCESS
		&"warning":
			color = RpgMenuTheme.RUST
		&"reward":
			color = RpgMenuTheme.BRONZE_BRIGHT
	add_theme_color_override("font_color", color)
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_seconds)
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	_tween.tween_callback(func() -> void: visible = false)


func _on_quest_started(quest: QuestDefinition) -> void:
	if quest != null:
		show_toast("Задание: %s" % quest.title, &"quest")


func _on_quest_completed(quest: QuestDefinition) -> void:
	if quest != null:
		show_toast("Задание завершено: %s" % quest.title, &"success")


func _on_reward_granted(_quest: QuestDefinition, reward: QuestReward) -> void:
	if reward == null:
		return
	var description := reward.describe()
	if not description.is_empty():
		show_toast("Награда: %s" % description, &"reward")
