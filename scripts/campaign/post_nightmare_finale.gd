extends Control
## Конец демонстрационного фрагмента «После Кошмара».
##
## Одна сцена обслуживает два режима: M1 (Z10) и tech demo (Z18). Режим
## выбирается по canonical flags, а не по второй финальной сцене. Карточка
## только фиксирует флаг и возвращает в меню; state и квесты уже сохранены
## финальной зоной.

const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const LABYRINTH_SCENE := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"

@onready var _button: Button = %BackButton
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	RpgMenuTheme.apply_to(self)
	# Safety net for a direct portal launch: the final card always ends the
	# labyrinth scope and removes any external objective.
	QuestSystem.deactivate_scope()
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide != null and guide.has_method(&"clear_external_objective"):
		guide.call(&"clear_external_objective")
	if _button == null:
		push_error("PostNightmareFinale: нет %BackButton")
		return
	NightmareRunState.set_flag(get_completion_flag())
	_refresh_card_text()
	_button.pressed.connect(_return_to_menu)
	if _continue_button != null:
		_continue_button.visible = is_m1()
		_continue_button.pressed.connect(_continue_tech_demo)
	if is_m1() and _continue_button != null:
		_continue_button.grab_focus()
	else:
		_button.grab_focus()
	# current_scene выставляется SceneTree после входа в сцену. Сохраняем
	# отложенно, чтобы в сейв попала именно финальная карточка.
	call_deferred(&"_save_finale")


## M1 имеет приоритет только если tech demo явно не выбран.
func is_m1() -> bool:
	if NightmareRunState.has_flag(&"demo_mode_full"):
		return false
	if NightmareRunState.has_flag(&"demo_mode_m1"):
		return true
	if NightmareRunState.has_flag(&"post_nightmare_demo_completed"):
		return true
	if NightmareRunState.has_flag(&"post_nightmare_completed"):
		return false
	# Прямой запуск без режима сохраняет прежнее tech-demo поведение.
	return false


func get_completion_flag() -> StringName:
	return &"post_nightmare_demo_completed" if is_m1() else &"post_nightmare_completed"


func _refresh_card_text() -> void:
	var kicker := get_node_or_null(^"Center/Column/Kicker") as Label
	var title := get_node_or_null(^"Center/Column/Title") as Label
	var text := get_node_or_null(^"Center/Column/Card/Body/Text") as Label
	var hint := get_node_or_null(^"Center/Column/Card/Body/Hint") as Label
	if is_m1():
		if kicker != null:
			kicker.text = "ПОСЛЕ КОШМАРА · ПЕРВЫЙ ДЕНЬ"
		if title != null:
			title.text = "ПЕРВЫЙ ДЕНЬ"
		if text != null:
			text.text = (
				"Санни добрался до лагеря у кораллового холма. "
				+ "Первый день на Забытом берегу закончен.\n\n"
				+ "Впереди — западный канал, костяной мост и утёсы. "
				+ "Можно продолжить сразу или вернуться в главное меню."
			)
		if hint != null:
			hint.text = "Конец M1. Продолжение открывает технический фрагмент Z11–Z18."
	else:
		if kicker != null:
			kicker.text = "ПОСЛЕ КОШМАРА"
		if title != null:
			title.text = "КОНЕЦ ДЕМОНСТРАЦИОННОГО ФРАГМЕНТА"
		if text != null:
			text.text = (
				"Санни прошёл шею колосса, спустился к кораллам и вошёл "
				+ "в Лабиринт Забытого берега.\n\n"
				+ "Дальше — Академия, Нефис, Кассия, прилив, шторм и "
				+ "Древо Души. Это следующие этапы производства."
			)
		if hint != null:
			hint.text = "Текущий milestone завершён. Полный сюжет реализуется поэтапно."


func _continue_tech_demo() -> void:
	# Continue from the M1 camp into Z11-Z18 without replaying the whole M1.
	_save_finale()
	NightmareRunState.set_flag(&"demo_mode_full")
	NightmareRunState.set_flag(&"post_nightmare_started")
	NightmareRunState.set_current_beat(&"Z11")
	LevelPortal.set_pending_spawn(LABYRINTH_SCENE, &"CampReturn")
	get_tree().change_scene_to_file(LABYRINTH_SCENE)


func _save_finale() -> void:
	if OS.has_feature("headless"):
		return
	var save_system := get_node_or_null(^"/root/SaveSystem")
	if save_system != null and save_system.has_method(&"save_game"):
		save_system.call(&"save_game", "finale")


func _return_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_menu()
