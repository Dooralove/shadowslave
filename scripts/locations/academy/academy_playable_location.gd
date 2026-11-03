class_name AcademyPlayableLocation
extends GreyboxLocation
## Playable wrapper for the standalone Academy art locations.
##
## The art scene (Academy Grounds or Sleeper Center) is a child of this node.
## This wrapper adds the player, HUD, fade layer, spawns, portals, NPCs,
## interactables, loot and the academy quest scope. Existing M1 scenes are
## untouched.

@export var academy_scene_kind: StringName = &"grounds"
@export var quest_director_path: NodePath = ^"AcademyGameplayDirector"


func _ready() -> void:
	super._ready()
	call_deferred(&"_focus_player_camera")


func _setup_post_nightmare_demo() -> void:
	if get_tree().current_scene != self:
		return
	NightmareRunState.set_flag(&"academy_chapter_started")
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null:
		quests.call(&"activate_scope", &"academy")
	var director := get_node_or_null(quest_director_path)
	if director != null and director.has_method(&"setup"):
		director.call(&"setup")
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		var cue: StringName = &"m1_academy" if academy_scene_kind == &"grounds" else &"m1_sleeper"
		if audio.has_method(&"play_music"):
			audio.call(&"play_music", cue, 3.0)
		if audio.has_method(&"play_ambience"):
			audio.call(&"play_ambience", cue, 3.0)
		if audio.has_method(&"set_reverb_profile"):
			audio.call(&"set_reverb_profile", &"academy_hall" if academy_scene_kind == &"grounds" else &"sleeper_hall")
	var hud := get_node_or_null(^"GameplayHud") as CanvasLayer
	if hud != null:
		hud.set(&"tutorial_enabled", false)


func _focus_player_camera() -> void:
	var art := get_node_or_null(^"Art")
	if art != null:
		_disable_cameras(art)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var camera := _find_camera(player)
	if camera != null:
		camera.current = true


func _disable_cameras(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Camera3D:
			(node as Camera3D).current = false
		for child in node.get_children():
			stack.append(child)


func _find_camera(root: Node) -> Camera3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Camera3D:
			return node as Camera3D
		for child in node.get_children():
			stack.append(child)
	return null
