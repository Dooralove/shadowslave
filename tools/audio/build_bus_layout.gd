extends SceneTree
## Generates res://default_bus_layout.tres with the project audio buses.
## Run: godot --headless --path . --script res://tools/audio/build_bus_layout.gd

const BUSES := [
	{ "name": &"Music", "send": &"Reverb", "volume_db": 0.0 },
	{ "name": &"Ambience", "send": &"Reverb", "volume_db": 0.0 },
	{ "name": &"SFX", "send": &"Master", "volume_db": 0.0 },
	{ "name": &"Voice", "send": &"Master", "volume_db": 0.0 },
	{ "name": &"UI", "send": &"Master", "volume_db": 0.0 },
	{ "name": &"Reverb", "send": &"Master", "volume_db": 0.0 },
]


func _init() -> void:
	for entry in BUSES:
		var name: StringName = entry["name"]
		var index := AudioServer.get_bus_index(name)
		if index == -1:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, String(name))
		AudioServer.set_bus_send(index, entry["send"])
		AudioServer.set_bus_volume_db(index, entry["volume_db"])

	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index >= 0:
		var has_compressor := false
		var has_limiter := false
		for effect_index in AudioServer.get_bus_effect_count(master_index):
			var existing := AudioServer.get_bus_effect(master_index, effect_index)
			has_compressor = has_compressor or existing is AudioEffectCompressor
			has_limiter = has_limiter or existing is AudioEffectLimiter
		if not has_compressor:
			var compressor := AudioEffectCompressor.new()
			compressor.threshold = -18.0
			compressor.ratio = 3.0
			compressor.attack_us = 10000.0
			compressor.release_ms = 200.0
			AudioServer.add_bus_effect(master_index, compressor)
		if not has_limiter:
			var limiter := AudioEffectLimiter.new()
			limiter.ceiling_db = -1.0
			limiter.threshold_db = -3.0
			limiter.soft_clip_db = -3.0
			limiter.soft_clip_ratio = 4.0
			AudioServer.add_bus_effect(master_index, limiter)

	var reverb_index := AudioServer.get_bus_index(&"Reverb")
	if reverb_index >= 0:
		var reverb: AudioEffectReverb
		if AudioServer.get_bus_effect_count(reverb_index) == 0:
			reverb = AudioEffectReverb.new()
			AudioServer.add_bus_effect(reverb_index, reverb)
		else:
			reverb = AudioServer.get_bus_effect(reverb_index, 0) as AudioEffectReverb
		if reverb != null:
			reverb.room_size = 0.55
			reverb.damping = 0.45
			reverb.wet = 0.25
			reverb.dry = 1.0

	var layout := AudioServer.generate_bus_layout()
	var error := ResourceSaver.save(layout, "res://default_bus_layout.tres")
	print("Saved default_bus_layout.tres: ", error)
	quit(0 if error == OK else 1)
