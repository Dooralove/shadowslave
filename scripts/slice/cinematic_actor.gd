class_name CinematicActor
extends Node
## Даёт сценарию логические действия персонажа («сесть», «встать», «бросить») вместо имён клипов.
## На время постановки забирает AnimationPlayer у аниматора передвижения, чтобы кости не делили два источника.

@export var animation_player: AnimationPlayer
@export var clip_map: ActionClipMap
## Аниматор передвижения (свойство `cinematic`); может отсутствовать у простых NPC.
@export var animator: Node
## Части модели, которые нужно скрыть в этой сцене (например, оружие временной модели).
@export var hidden_parts: PackedStringArray = []

var active := false


func _ready() -> void:
	for path in hidden_parts:
		var part := get_node_or_null(NodePath(path)) as Node3D
		if part:
			part.visible = false


func begin() -> void:
	active = true
	if animator:
		animator.cinematic = true


func end() -> void:
	active = false
	if animator:
		animator.cinematic = false


func has_action(action: StringName) -> bool:
	if animation_player == null or clip_map == null:
		return false
	var clip := clip_map.clip_for(action)
	return clip != &"" and animation_player.has_animation(clip)


## Проигрывает действие и возвращает длину клипа (0, если действия нет — сценарий не ломается).
func play(action: StringName, blend := 0.2) -> float:
	if not has_action(action):
		return 0.0
	var clip := clip_map.clip_for(action)
	animation_player.speed_scale = 1.0
	animation_player.play(clip, blend)
	return animation_player.get_animation(clip).length
