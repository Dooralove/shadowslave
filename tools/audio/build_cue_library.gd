extends SceneTree
## Regenerates the typed .tres cue table from the current library data.
## The runtime loader is scripts/audio/audio_library.gd.
##   godot --headless --path . --script res://tools/audio/build_cue_library.gd

const OUT := "res://resources/audio/audio_cue_library.tres"


func _init() -> void:
	var library := AudioCueLibrary.new()
	var music: Dictionary = AudioLibrary.music_cues()
	for cue_id in music:
		library.music.append(music[cue_id] as MusicCue)
	var sfx: Dictionary = AudioLibrary.sfx_cues()
	for cue_id in sfx:
		library.sfx.append(sfx[cue_id] as SfxCue)
	var zones: Dictionary = AudioLibrary.ambience_zones()
	for zone_id in zones:
		var source: Dictionary = zones[zone_id]
		var zone := AmbienceZone.new()
		zone.id = zone_id
		zone.bed = source.get("bed")
		zone.mid = source.get("mid")
		zone.bed_db = float(source.get("bed_db", -14.0))
		zone.mid_db = float(source.get("mid_db", -20.0))
		zone.detail_db = float(source.get("detail_db", -18.0))
		for stream in source.get("details", []):
			if stream is AudioStream:
				zone.details.append(stream)
		library.ambience.append(zone)
	var error := ResourceSaver.save(library, OUT)
	print("Saved %s: %s (music=%d, sfx=%d, ambience=%d)" % [OUT, error, library.music.size(), library.sfx.size(), library.ambience.size()])
	quit(0 if error == OK else 1)
