class_name SliceLocation
extends Node3D
## Локация среза. Режиссёр работает с ней только через этот интерфейс:
## точки появления (Spawns/*), ракурсы (Shots/*), Interactable, TriggerZone и постановки play_cutscene().
## Как постановка сделана внутри (твины сейчас, AnimationPlayer позже) — дело локации.

signal interacted(id: StringName)
signal triggered(id: StringName)

var director: SliceDirector
var _interactables := {}
var _triggers := {}


func _ready() -> void:
	for node in _descendants(self):
		if node is Interactable:
			_interactables[node.interaction_id] = node
			node.interacted.connect(interacted.emit)
		elif node is TriggerZone:
			_triggers[node.trigger_id] = node
			node.triggered.connect(triggered.emit)
	# Ракурс смотрит на свой маркер LookAt, чтобы не считать базисы вручную.
	var shots := get_node_or_null(^"Shots")
	if shots:
		for camera in shots.get_children():
			var target := camera.get_node_or_null(^"LookAt") as Node3D
			if camera is Camera3D and target:
				var look_target := target.global_position
				camera.look_at(look_target)
				target.global_position = look_target


## Вызывается режиссёром сразу после загрузки локации.
func setup(slice_director: SliceDirector) -> void:
	director = slice_director


func get_spawn(spawn: StringName) -> Node3D:
	return get_node_or_null(NodePath("Spawns/%s" % spawn)) as Node3D


func get_interactable(id: StringName) -> Interactable:
	return _interactables.get(id)


func set_interactable_enabled(id: StringName, on: bool) -> void:
	var interactable := get_interactable(id)
	if interactable:
		interactable.enabled = on


func get_trigger(id: StringName) -> TriggerZone:
	return _triggers.get(id)


func set_trigger_enabled(id: StringName, on: bool) -> void:
	var trigger := get_trigger(id)
	if trigger:
		trigger.enabled = on


func shot(shot_name: StringName) -> Camera3D:
	return get_node_or_null(NodePath("Shots/%s" % shot_name)) as Camera3D


func use_shot(shot_name: StringName) -> void:
	var camera := shot(shot_name)
	if camera:
		camera.make_current()


## Постановка с id. Базовая локация постановок не имеет; наследники переопределяют.
func play_cutscene(id: StringName, _fast: bool) -> void:
	push_warning("%s: no cutscene '%s'" % [name, id])


## Шаг каравана (направление × темп); локации без марша возвращают ноль.
func march_velocity() -> Vector3:
	return Vector3.ZERO


func start_march() -> void:
	pass


func stop_march() -> void:
	pass


## Плавно меняет свойство; в быстром режиме (тесты) сразу ставит итоговое значение.
func animate(target: Object, property: NodePath, value: Variant, duration: float, fast: bool) -> void:
	if fast or duration <= 0.0:
		target.set_indexed(property, value)
		return
	var tween := create_tween()
	tween.tween_property(target, property, value, duration)
	await tween.finished


func pause(seconds: float, fast: bool) -> void:
	if fast or seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
