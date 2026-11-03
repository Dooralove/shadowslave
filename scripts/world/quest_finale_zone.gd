class_name QuestFinaleZone
extends Area3D
## Одноразовая финальная зона M1 или tech demo.
##
## Узел принадлежит сцене локации (его ставит A03), логика — A04. Зона не
## создаёт второй финальный flow: она ставит canonical flag, очищает внешнюю
## цель, выключает QuestSystem scope и переходит в единственную сцену
## post_nightmare_finale.tscn. Сохранение делает сама финальная карточка.

enum Mode {
	M1,
	TECH_DEMO,
}

signal finale_reached(mode: int, completion_flag: StringName)

@export var mode: Mode = Mode.M1
@export var required_flags: Array[StringName] = []
@export var completion_flag: StringName = &"post_nightmare_demo_completed"
@export_file("*.tscn") var finale_scene := "res://scenes/campaign/post_nightmare_finale.tscn"
@export var one_shot := true
@export var player_group: StringName = &"player"
@export_flags_3d_physics var trigger_mask := 2
@export_range(0.0, 3.0, 0.05) var fade_out_duration := 0.8
@export var fade_layer: FadeLayer

var _inside := false
var _finished := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = trigger_mask
	monitorable = false
	if mode == Mode.M1 and required_flags.is_empty():
		# Безопасный default: M1 не должен завершиться до первого дня и ночи
		# у костра. A03 может явно переопределить список в сцене.
		required_flags = [&"shore_first_day_complete", &"camp_night_seen"]
	if mode == Mode.TECH_DEMO and completion_flag == &"post_nightmare_demo_completed":
		completion_flag = &"post_nightmare_completed"
	if completion_flag != &"" and NightmareRunState.has_flag(completion_flag):
		_finished = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state != null and not run_state.flag_changed.is_connected(_on_flag_changed):
		run_state.flag_changed.connect(_on_flag_changed)
	set_physics_process(true)
	call_deferred(&"_refresh_overlap")


func _physics_process(_delta: float) -> void:
	if _inside and _can_finish():
		_finish()


func _can_finish() -> bool:
	if _finished or completion_flag == &"":
		return false
	if NightmareRunState.has_flag(completion_flag):
		return false
	if mode == Mode.M1 and NightmareRunState.has_flag(&"demo_mode_full"):
		return false
	if mode == Mode.TECH_DEMO and not NightmareRunState.has_flag(&"demo_mode_full"):
		return false
	return NightmareRunState.require(required_flags)


func _finish() -> void:
	if _finished:
		return
	if not _finale_is_valid():
		_finished = true
		push_error("QuestFinaleZone: finale_scene не существует: %s" % finale_scene)
		return
	_finished = true
	QuestSystem.deactivate_scope()
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide != null and guide.has_method(&"clear_external_objective"):
		guide.call(&"clear_external_objective")
	NightmareRunState.set_flag(completion_flag)
	finale_reached.emit(mode, completion_flag)
	call_deferred(&"_enter_finale")


func _finale_is_valid() -> bool:
	return not finale_scene.is_empty() and ResourceLoader.exists(finale_scene)


func _enter_finale() -> void:
	if not _finale_is_valid():
		push_error("QuestFinaleZone: finale_scene не задан или не существует")
		return
	var fade := _resolve_fade_layer()
	if fade != null and fade_out_duration > 0.0:
		await fade.fade_to(1.0, fade_out_duration)
	var error := get_tree().change_scene_to_file(finale_scene)
	if error != OK:
		push_error("QuestFinaleZone: не удалось открыть %s (код %d)" % [finale_scene, error])


func _resolve_fade_layer() -> FadeLayer:
	if fade_layer != null:
		return fade_layer
	var root := get_tree().current_scene
	if root == null:
		root = self
	var found := _find_fade_layer(root)
	if found == null and root != self:
		found = _find_fade_layer(self)
	return found


func _find_fade_layer(node: Node) -> FadeLayer:
	if node is FadeLayer:
		return node
	for child in node.get_children():
		var found := _find_fade_layer(child)
		if found != null:
			return found
	return null


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(player_group):
		_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(player_group):
		_inside = false


func _on_flag_changed(_flag_name: StringName, _value: bool) -> void:
	# _physics_process проверяет flags; сигнал нужен только для пробуждения
	# зоны, если игрок уже стоит внутри неё.
	set_physics_process(true)


func _refresh_overlap() -> void:
	if _finished:
		return
	for body in get_overlapping_bodies():
		if body is Node3D and (body as Node3D).is_in_group(player_group):
			_inside = true
			return


func is_finished() -> bool:
	return _finished
