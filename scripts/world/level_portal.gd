class_name LevelPortal
extends Area3D
## Универсальная точка перехода между сценами.
##
## Это не менеджер уровней и не замена SliceDirector: локальные переключения
## внутри пролога по-прежнему делает режиссёр, а сюжетные оболочки кампании
## остаются владельцами своих переходов. LevelPortal — переиспользуемый узел
## для двери, прохода, лестницы или специальной точки выхода, которым нужно
## загрузить другую сцену и поставить игрока на именованный `Spawns/<name>`.
##
## Физический проход: портал стоит на проходимой стороне двери/лестницы и
## срабатывает по `body_entered` либо по сигналу назначенного Interactable.
## Показ: обязательно через существующий FadeLayer; для постановочного
## перехода можно сначала проиграть `play_cutscene()` у родительской локации.
## Точка назначения читает запрошенный spawn через `take_pending_spawn()`.
##
## Портал не телепортирует игрока внутри текущей сцены. Он ведёт себя как
## обычный триггер: игрок сам входит в зону/нажимает E, затем идёт затемнение
## и загрузка сцены. Это сохраняет причинность перехода.


signal transition_started(destination_scene: String, destination_spawn: StringName)
## Сцена уже запрошена у SceneTree; новая сцена загрузится в конце кадра.
signal transition_finished(destination_scene: String, destination_spawn: StringName)
signal transition_aborted(reason: String)


enum Style {
	FADE,
	## Сначала проиграть постановку у ближайшего родителя с play_cutscene(),
	## затем затемнить и загрузить сцену. Пустой cutscene_id — просто fade.
	CUTSCENE,
}


@export_file("*.tscn") var destination_scene := ""
@export var destination_spawn: StringName = &""
@export_range(0.0, 5.0, 0.05) var fade_out_duration := 0.8

@export var transition_style: Style = Style.FADE
## id постановки для Style.CUTSCENE; должна существовать у родительской локации.
@export var cutscene_id: StringName = &""

## Выключатель портала: удобно для гейтов и отладки.
@export var enabled := true
## Автоматически срабатывать, когда игрок входит в Area3D.
@export var trigger_on_body := true
## Сколько первых физических кадров после появления сцены игнорировать вход.
## Защищает от зацикливания, если spawn назначения оказался внутри триггера.
## 10 кадров — примерно 0.17 с при 60 FPS; при необходимости настраивается.
@export_range(0, 60, 1) var body_trigger_ignore_frames := 10
## Маска Area3D. Слой 2 — слой CharacterBody3D Санни.
@export_flags_3d_physics var trigger_mask := 2
@export var player_group: StringName = &"player"
## Необязательная интерактивная точка для двери с нажатием E.
@export var interactable: Interactable

## Блокировать ввод игрока на время затемнения/загрузки.
@export var lock_player := true
## Не разрешать повторное срабатывание в пределах жизни узла.
@export var one_shot := true
## Дополнительный флаг, который переживает перезагрузку сцены и закрывает портал.
@export var one_shot_flag: StringName = &""
## Какие флаги нужны, чтобы портал сработал.
@export var required_flags: Array[StringName] = []
## Что выставить при успешном переходе (например, открытая дверь).
@export var set_flags_on_use: Array[StringName] = []

## Явный слой затемнения. Если не задан, портал ищет первый FadeLayer в сцене.
@export var fade_layer: FadeLayer

static var _pending_scene := ""
static var _pending_spawn: StringName = &""
## Один запрос смены сцены на кадр/переход. Ссылка слабая: после загрузки
## новая сцена не наследует старый портал, а освобождённый узел перестаёт
## блокировать следующие переходы.
static var _active_portal: WeakRef

var _running := false
var _used := false
var _player: SunnyController
var _player_locked := false
var _saved_input := true
var _saved_forced_velocity := Vector3.ZERO
var _ignore_body_until_frame := 0


func _ready() -> void:
	# Портал — сенсор, а не физическое препятствие.
	collision_layer = 0
	collision_mask = trigger_mask
	monitorable = false
	if trigger_on_body:
		_ignore_body_until_frame = Engine.get_physics_frames() + body_trigger_ignore_frames
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
	if interactable != null and not interactable.interacted.is_connected(_on_interactable_interacted):
		interactable.interacted.connect(_on_interactable_interacted)
	if one_shot_flag != &"" and NightmareRunState.has_flag(one_shot_flag):
		_used = true


func is_available() -> bool:
	if not enabled or _running:
		return false
	if _has_active_transition():
		return false
	if one_shot and _used:
		return false
	if one_shot and one_shot_flag != &"" and NightmareRunState.has_flag(one_shot_flag):
		return false
	for flag in required_flags:
		if not NightmareRunState.has_flag(flag):
			return false
	return true


func is_used() -> bool:
	return _used


func is_running() -> bool:
	return _running


## Публичная точка входа для Interactable, сценарных вызовов и тестов.
## body можно передать явно; иначе игрок ищется по группе.
func activate(body: Node3D = null) -> bool:
	if _running or _has_active_transition():
		return false
	if not is_available():
		return false
	if not _destination_is_valid():
		_abort("destination scene does not exist: %s" % destination_scene, true)
		return false

	var player := _resolve_player(body)
	_lock_player(player)
	_active_portal = weakref(self)
	_running = true
	transition_started.emit(destination_scene, destination_spawn)

	if transition_style == Style.CUTSCENE and cutscene_id != &"":
		var cutscene_ok := await _play_cutscene()
		if not cutscene_ok:
			_abort("no play_cutscene() host for cutscene '%s'" % cutscene_id, true)
			return false

	var fade := _resolve_fade_layer()
	if fade == null:
		_abort("no FadeLayer assigned or found; transition would be an unexplained teleport", true)
		return false
	if fade_out_duration <= 0.0:
		fade.color.a = 1.0
	else:
		await fade.fade_to(1.0, fade_out_duration)

	# Сцену может сменить только сам SceneTree. Запрос spawn кладётся до смены,
	# чтобы оболочка назначения успела применить его в своём _ready().
	set_pending_spawn(destination_scene, destination_spawn)
	var error := _commit_scene_change(destination_scene)
	if error != OK:
		clear_pending_spawn()
		_abort("change_scene_to_file('%s') failed with error %d" % [destination_scene, error], true)
		return false

	if one_shot:
		_used = true
	if one_shot_flag != &"":
		NightmareRunState.set_flag(one_shot_flag)
	for flag in set_flags_on_use:
		NightmareRunState.set_flag(flag)
	transition_finished.emit(destination_scene, destination_spawn)
	return true


## Виртуальная точка для тестов и нестандартных загрузчиков.
## Возвращает код ошибки Godot; OK означает, что смена сцены запрошена.
func _commit_scene_change(scene_path: String) -> int:
	return get_tree().change_scene_to_file(scene_path)


func _destination_is_valid() -> bool:
	return not destination_scene.is_empty() and ResourceLoader.exists(destination_scene)


func _resolve_player(body: Node3D) -> SunnyController:
	if body is SunnyController and body.is_in_group(player_group):
		return body
	for node in get_tree().get_nodes_in_group(player_group):
		if node is SunnyController:
			return node
	return null


func _lock_player(player: SunnyController) -> void:
	if not lock_player or player == null:
		return
	_player = player
	_saved_input = player.input_enabled
	_saved_forced_velocity = player.forced_velocity
	player.input_enabled = false
	player.forced_velocity = Vector3.ZERO
	_player_locked = true


func _restore_player() -> void:
	if not _player_locked:
		return
	if is_instance_valid(_player) and _player is SunnyController:
		_player.input_enabled = _saved_input
		_player.forced_velocity = _saved_forced_velocity
	_player = null
	_player_locked = false


func _abort(reason: String, report_as_error := false) -> void:
	_running = false
	_restore_player()
	if _active_portal != null and _active_portal.get_ref() == self:
		clear_active_transition()
	if report_as_error:
		_report_error(reason)
	transition_aborted.emit(reason)


## Виртуальная диагностика: тесты подменяют её, чтобы ожидаемая ошибка
## конфигурации не считалась необработанной ошибкой GUT.
func _report_error(message: String) -> void:
	push_error("LevelPortal: " + message)


func _on_body_entered(body: Node3D) -> void:
	if not trigger_on_body or not body.is_in_group(player_group):
		return
	# Первые кадры после загрузки сцены: если игрок появился внутри прохода,
	# не отправляем его обратно тем же переходом. После выхода/повторного
	# входа body_entered сработает снова и портал будет доступен.
	if Engine.get_physics_frames() < _ignore_body_until_frame:
		return
	activate(body)


func _on_interactable_interacted(_id: StringName) -> void:
	activate()


func _play_cutscene() -> bool:
	var host := _find_cutscene_host()
	if host == null or not host.has_method("play_cutscene"):
		return false
	@warning_ignore("redundant_await")
	await host.call("play_cutscene", cutscene_id, false)
	return true


func _find_cutscene_host() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("play_cutscene"):
			return node
		node = node.get_parent()
	return null


func _resolve_fade_layer() -> FadeLayer:
	if fade_layer != null:
		return fade_layer
	var tree := get_tree()
	var root: Node = tree.current_scene if tree != null and tree.current_scene != null else self
	if root == null:
		return null
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


## Снимает глобальную блокировку перехода. Нужно тестам и сценарным
## загрузчикам, которые не освобождают старый портал.
static func clear_active_transition() -> void:
	_active_portal = null


static func _has_active_transition() -> bool:
	if _active_portal == null:
		return false
	var owner: Object = _active_portal.get_ref()
	if owner == null or not is_instance_valid(owner):
		_active_portal = null
		return false
	return true


## Запрос spawn для следующей сцены. Живёт в статическом поле, потому что
## SceneTree не умеет передавать параметры в change_scene_to_file().
static func set_pending_spawn(scene_path: String, spawn: StringName) -> void:
	_pending_scene = scene_path
	_pending_spawn = spawn


static func peek_pending_spawn(scene_path := "") -> StringName:
	if _pending_scene.is_empty():
		return &""
	if not scene_path.is_empty() and _pending_scene != scene_path:
		return &""
	return _pending_spawn


## Читает запрос только для своей сцены и сразу очищает его. Если запрос
## адресован другой сцене, он остаётся нетронутым.
static func take_pending_spawn(scene_path: String) -> StringName:
	if _pending_scene != scene_path:
		return &""
	var spawn: StringName = _pending_spawn
	clear_pending_spawn()
	return spawn


static func clear_pending_spawn() -> void:
	_pending_scene = ""
	_pending_spawn = &""


## Ищет `Spawns/<spawn_name>` у переданной локации. При отсутствии запрошенной
## точки использует fallback и пишет предупреждение, а не оставляет игрока
## в случайной позиции.
static func resolve_spawn(root: Node, spawn_name: StringName, fallback: StringName = &"") -> Node3D:
	if root == null:
		return null
	var marker := _find_spawn(root, spawn_name)
	if marker != null:
		return marker
	if fallback != &"" and fallback != spawn_name:
		marker = _find_spawn(root, fallback)
		if marker != null:
			# Пустой запрос — это обычный вход по умолчанию, а не ошибка.
			if spawn_name != &"":
				push_warning("LevelPortal: spawn '%s' not found in %s; using '%s'" % [
					spawn_name, root.name, fallback
				])
			return marker
	return null


static func _find_spawn(root: Node, spawn_name: StringName) -> Node3D:
	if spawn_name == &"":
		return null
	return root.get_node_or_null(NodePath("Spawns/%s" % spawn_name)) as Node3D
