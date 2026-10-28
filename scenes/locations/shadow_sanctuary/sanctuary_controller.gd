class_name SanctuaryController
extends Node3D
## Корневой контроллер Святилища Тени.
## Сцена — блок-аут: контроллер принимает события и отдаёт их наружу.
## Сценарий, бой, камера и UI подключаются к сигналам; внутри них нет.


## Divine — ранг Аспекта, Glorious — итоговая оценка испытания.
## Это разные понятия канона, поэтому они не смешиваются в один текст.
enum Evaluation {
	NONE,
	DIVINE,
	GLORIOUS,
}


## DORMANT — игрок ещё не подошёл к алтарю; ALTAR_READY — зона подхода
## сработала; OFFERING — подношение начато; COMPLETED — финал уже отправлен.
enum NightmareState {
	DORMANT,
	ALTAR_READY,
	OFFERING,
	COMPLETED,
}


signal player_entered_crevice
signal blood_offered_to_altar
## Испытание в храме завершено (подношение и смерть Тирана), но оценка и
## пробуждение ещё впереди. Не путать с first_nightmare_completed.
signal trial_completed
## Игрок впервые вошёл в зону подхода к алтарю. Срабатывает один раз.
signal altar_ready
## Запрос на показ сообщения Заклятия. evaluation — метка для UI.
signal spell_message(text: String, evaluation: Evaluation)


const EVALUATION_LINES := {
	Evaluation.DIVINE: "Ранг Аспекта: Божественный.",
	Evaluation.GLORIOUS: "Итоговая оценка: Славная.",
}


## Если выключено, триггеры не подключены и события вызываются методами вручную.
@export var auto_wire_triggers := true

@onready var crevice_trigger: Area3D = $Triggers/Trigger_CreviceHideout
@onready var altar_trigger: Area3D = $Triggers/Trigger_AltarInteract
@onready var evaluation_trigger: Area3D = $Triggers/Trigger_SpellEvaluation
## Точка взаимодействия у алтаря. В чистом тестовом окружении может отсутствовать.
@onready var altar: Interactable = get_node_or_null("Interactables/AltarOffering") as Interactable

var nightmare_state := NightmareState.DORMANT

var _crevice_entered := false
var _blood_offered := false
var _nightmare_completed := false
var _altar_ready := false


func _ready() -> void:
	var triggers: Array[Area3D] = [crevice_trigger, altar_trigger, evaluation_trigger]
	for trigger in triggers:
		trigger.monitorable = false
	# Зона оценки — задел для сценария: включается после гибели Mountain King,
	# а не при первом приближении к алтарю.
	evaluation_trigger.monitoring = false
	if not auto_wire_triggers:
		return
	crevice_trigger.body_entered.connect(_on_crevice_body_entered)
	altar_trigger.body_entered.connect(_on_altar_body_entered)


## Игрок подошёл к алтарю. Повторные входы в зону игнорируются.
func arm_altar() -> void:
	if _altar_ready or _blood_offered or _nightmare_completed:
		return
	_altar_ready = true
	nightmare_state = NightmareState.ALTAR_READY
	# Нельзя менять monitoring внутри body_entered: Godot блокирует Area3D.
	altar_trigger.set_deferred(&"monitoring", false)
	altar_ready.emit()


## Начинает подношение. Возвращает false, если ритуал уже шёл или завершён.
##
## Временная модель: здоровье, кровь и инвентарь не проверяются. Настоящая
## стоимость подношения подключается в AltarRitual.can_offer() или здесь,
## не меняя сигналы и последовательность сцены.
func begin_offering() -> bool:
	if _blood_offered or _nightmare_completed:
		return false
	_blood_offered = true
	nightmare_state = NightmareState.OFFERING
	if altar != null:
		altar.enabled = false
	# В источнике пока нет реплик для алтаря: менеджер корректно вернёт null.
	DialogueManager.request_bark(DialogueManager.CONTEXT_ALTAR)
	blood_offered_to_altar.emit()
	return true


## Совместимый вход для сценария: то же, что begin_offering().
func offer_blood() -> void:
	begin_offering()


## Завершает испытание в храме. Повторные вызовы игнорируются.
## Оценка, пробуждение и first_nightmare_completed остаются за S14–S15.
func complete_trial() -> bool:
	if _nightmare_completed:
		return false
	_nightmare_completed = true
	nightmare_state = NightmareState.COMPLETED
	if altar != null:
		altar.enabled = false
	trial_completed.emit()
	return true


## Совместимость со старым именем прототипа. Новый код вызывает complete_trial().
func complete_first_nightmare() -> bool:
	return complete_trial()


func enter_crevice() -> void:
	if _crevice_entered:
		return
	_crevice_entered = true
	DialogueManager.request_bark(DialogueManager.CONTEXT_COVER)
	player_entered_crevice.emit()


func is_offering() -> bool:
	return nightmare_state == NightmareState.OFFERING


func is_completed() -> bool:
	return nightmare_state == NightmareState.COMPLETED


## Универсальный вызов сообщения Заклятия. Текст и метку обрабатывает UI.
func announce_spell_message(text: String, evaluation: Evaluation = Evaluation.NONE) -> void:
	spell_message.emit(text, evaluation)


## Короткое каноническое сообщение оценки Заклятия.
func announce_evaluation(evaluation: Evaluation) -> void:
	if not EVALUATION_LINES.has(evaluation):
		push_warning("SanctuaryController: неизвестная оценка %s" % evaluation)
		return
	announce_spell_message(str(EVALUATION_LINES[evaluation]), evaluation)


func _on_crevice_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		enter_crevice()


func _on_altar_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		arm_altar()
