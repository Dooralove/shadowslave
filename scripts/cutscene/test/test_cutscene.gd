extends CutsceneStage
## Демонстрационная сцена для F6.

@export var autostart := true

@onready var npc_animation: AnimationPlayer = $Npc/AnimationPlayer
@onready var npc_actor: CutsceneActor = $Npc/CutsceneActor


func _ready() -> void:
	super._ready()
	_prepare_npc_animation()
	if autostart:
		call_deferred(&"_start_cutscene")


func _prepare_npc_animation() -> void:
	if npc_animation == null or npc_actor == null:
		return
	npc_animation.root_node = NodePath("..")
	var animation := Animation.new()
	animation.length = 1.0
	animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Mesh:position"))
	animation.track_insert_key(track, 0.0, Vector3(0.0, 0.7, 0.0))
	animation.track_insert_key(track, 0.5, Vector3(0.0, 1.2, 0.0))
	animation.track_insert_key(track, 1.0, Vector3(0.0, 0.7, 0.0))
	var library := AnimationLibrary.new()
	library.add_animation(&"Bob", animation)
	npc_animation.add_animation_library(&"", library)

	var clip_map := ActionClipMap.new()
	clip_map.clips = { &"bob": &"Bob" }
	npc_actor.clip_map = clip_map


func _start_cutscene() -> void:
	var director = get_node_or_null(^"/root/CutsceneDirector")
	print("test_cutscene director: ", director)
	if director == null or bool(director.call(&"is_playing")):
		return
	var result: int = await director.call(&"play_stage", self)
	print("test_cutscene result: ", result)


func _unhandled_input(event: InputEvent) -> void:
	var director = get_node_or_null(^"/root/CutsceneDirector")
	if director == null or bool(director.call(&"is_playing")):
		return
	if event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		_start_cutscene()
