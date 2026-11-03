extends SceneTree
## Audit probe: first-load timing for the audio cue libraries.
## Run: godot --headless --path . --script res://tools/audit/audio_library_probe.gd

func _init() -> void:
	AudioLibrary.clear_cache()
	var start := Time.get_ticks_msec()
	var music := AudioLibrary.music_cues()
	var after_music := Time.get_ticks_msec()
	var sfx := AudioLibrary.sfx_cues()
	var after_sfx := Time.get_ticks_msec()
	var zones := AudioLibrary.ambience_zones()
	var after_zones := Time.get_ticks_msec()
	print("audio probe: music=%d sfx=%d zones=%d" % [music.size(), sfx.size(), zones.size()])
	print("load ms: music=%d sfx=%d ambience=%d" % [after_music - start, after_sfx - after_music, after_zones - after_sfx])
	print("static memory bytes: %d" % OS.get_static_memory_usage())
	quit()
