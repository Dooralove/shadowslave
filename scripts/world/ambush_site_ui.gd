class_name AmbushSiteUI
extends Node
## Сообщения Заклятия для эпизода засады.
##
## Контроллер остаётся свободным от UI: он только испускает state_changed.
## Этот узел переводит смену фазы в существующий SpellOverlay и данные из
## SpellMessageCatalog. Реплики Санни по-прежнему идут через DialogueManager.

const DEFAULT_CATALOG := "res://resources/spell/ambush_site_messages.tres"

@export var controller: AmbushController
@export var spell_overlay: SpellOverlay
@export var messages: SpellMessageCatalog


func _ready() -> void:
	if controller == null:
		controller = get_parent() as AmbushController
	if spell_overlay == null:
		spell_overlay = get_node_or_null("../SpellOverlay") as SpellOverlay
	if messages == null:
		messages = load(DEFAULT_CATALOG) as SpellMessageCatalog

	if controller == null:
		push_warning("AmbushSiteUI: не найден AmbushController")
		return

	controller.state_changed.connect(_on_state_changed)
	# Если сцена стартовала уже активной (отладочный режим), не теряем сообщение.
	if controller.get_state() != AmbushController.State.WAITING:
		_on_state_changed(controller.get_state())


func _on_state_changed(new_state: int) -> void:
	match new_state:
		AmbushController.State.AMBUSH_STARTED:
			_show_message(&"ambush_started")
		AmbushController.State.ESCAPE_AVAILABLE:
			_show_message(&"escape_available")
		AmbushController.State.ESCAPED:
			_show_message(&"escaped")


func _show_message(message_id: StringName) -> void:
	if messages == null or spell_overlay == null:
		return
	var message := messages.get_message(message_id)
	if message == null:
		push_warning("AmbushSiteUI: нет сообщения '%s'" % message_id)
		return
	spell_overlay.show_message(message)
