extends GutTest
## Real playback tests using the headless dummy audio driver.
## They opt into AudioLibrary.force_playback_for_tests, then always stop/clear.

var _director: Node


func before_each() -> void:
	AudioLibrary.force_playback_for_tests = true
	_director = get_node_or_null(^"/root/AudioDirector")
	assert_not_null(_director, "AudioDirector autoload")
	if _director != null:
		_director.call(&"stop_all")
		_director.call(&"set_reverb_profile", &"outdoor")


func after_each() -> void:
	if _director != null and is_instance_valid(_director):
		_director.call(&"stop_all")
	AudioLibrary.force_playback_for_tests = false


func _find_3d_player(cue_id: StringName) -> AudioStreamPlayer3D:
	for child in _director.get("sfx").get_children():
		if child is AudioStreamPlayer3D and child.playing and child.get_meta(&"cue_id", &"") == cue_id:
			return child
	return null


func test_sfx_actually_plays_and_sets_volume() -> void:
	assert_true(_director.call(&"play_sfx", &"combat_hit_flesh", Vector3(1, 0, 0), -3.0))
	var player := _find_3d_player(&"combat_hit_flesh")
	assert_not_null(player, "3D SFX player is active")
	assert_true(player.playing, "player is playing")
	assert_almost_eq(player.volume_db, -5.0, 0.01, "cue -2 dB plus -3 dB offset")
	assert_not_null(player.stream)


func test_sfx_cooldown_blocks_second_play() -> void:
	assert_true(_director.call(&"play_sfx", &"world_pickup", Vector3(2, 0, 0)))
	assert_false(_director.call(&"play_sfx", &"world_pickup", Vector3(2, 0, 0)), "cooldown blocks")
	await get_tree().create_timer(0.2).timeout
	assert_true(_director.call(&"play_sfx", &"world_pickup", Vector3(2, 0, 0)), "cooldown expires")


func test_sfx_max_instances_is_enforced() -> void:
	_director.get("sfx").get("_last_played").clear()
	for i in 3:
		assert_true(_director.call(&"play_sfx", &"world_pickup", Vector3(i, 0, 0)), "instance %d" % i)
		_director.get("sfx").get("_last_played").clear()
	assert_false(_director.call(&"play_sfx", &"world_pickup", Vector3(4, 0, 0)), "fourth instance rejected")


func test_music_stop_does_not_kill_new_cue_during_fade() -> void:
	_director.call(&"play_music", &"menu", 0.0)
	await get_tree().process_frame
	_director.call(&"stop_music", 0.1)
	_director.call(&"play_music", &"park", 0.1)
	await get_tree().create_timer(0.35).timeout
	assert_eq(_director.get("music").call(&"current_cue_id"), &"park")
	assert_true(_director.get("music").call(&"is_playing"), "new cue survived the old stop")


func test_voice_ducks_music_and_ambience_then_releases() -> void:
	_director.call(&"play_music", &"menu", 0.0)
	_director.call(&"play_ambience", &"menu", 0.0)
	await get_tree().process_frame
	assert_true(_director.call(&"play_voice", &"sip_1_000"), "prologue voice file exists")
	await get_tree().process_frame
	var voice_player := _director.get("voice").get("_player") as AudioStreamPlayer
	assert_not_null(voice_player)
	assert_true(voice_player.playing, "voice stream is playing")
	assert_almost_eq(float(_director.get("music").get("_duck_db")), -8.0, 0.01)
	assert_almost_eq(float(_director.get("ambience").get("_duck_db")), -4.0, 0.01)
	_director.get("voice").call(&"stop")
	await get_tree().process_frame
	assert_almost_eq(float(_director.get("music").get("_duck_db")), 0.0, 0.01)
	assert_almost_eq(float(_director.get("ambience").get("_duck_db")), 0.0, 0.01)


func test_occlusion_raycast_lowers_cutoff_and_gain() -> void:
	var listener := Node3D.new()
	listener.add_to_group(&"player")
	add_child_autofree(listener)
	listener.global_position = Vector3.ZERO
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.0, 2.0)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = Vector3(1, 0, 0)
	await get_tree().physics_frame
	assert_true(_director.call(&"play_sfx", &"combat_hit_flesh", Vector3(2, 0, 0)))
	var player := _find_3d_player(&"combat_hit_flesh")
	assert_not_null(player)
	assert_lt(player.attenuation_filter_cutoff_hz, AudioOcclusion.CLEAR_CUTOFF)
	assert_lt(player.attenuation_filter_db, 0.0)


func test_prologue_and_caravan_voice_files_are_wired() -> void:
	for line_id in [&"sip_1_000", &"desk_000", &"caravan_000"]:
		assert_true(_director.get("voice").call(&"has_line", line_id), "%s is wired" % line_id)
	assert_true(_director.get("voice").call(&"has_line", &"bark_CARAVAN_AURO_01"))
