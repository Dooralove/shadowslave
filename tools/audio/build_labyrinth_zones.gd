extends SceneTree
## Generates the data-driven Labyrinth audio zone set.
## Run: godot --headless --path . --script res://tools/audio/build_labyrinth_zones.gd

const OUT := "res://resources/locations/forgotten_shore_labyrinth/audio_zones.tres"

const DEFINITIONS := [
	{"id": &"labyrinth_z01", "rect": Rect2(12, -12, 33, 24), "intensity": 0.3, "detail": &"", "reverb": &"outdoor"},
	{"id": &"labyrinth_z02", "rect": Rect2(8, 15, 22, 23), "intensity": 0.3, "detail": &"world_bone_creak", "reverb": &"bone_cave"},
	{"id": &"labyrinth_z03", "rect": Rect2(-12, -12, 24, 24), "intensity": 0.35, "detail": &"", "reverb": &"coral_cave"},
	{"id": &"labyrinth_z04", "rect": Rect2(-45, -55, 30, 25), "intensity": 0.35, "detail": &"world_water_drip", "reverb": &"water"},
	{"id": &"labyrinth_z05", "rect": Rect2(-45, 11, 30, 24), "intensity": 0.4, "detail": &"world_bone_creak", "reverb": &"bone_cave"},
	{"id": &"labyrinth_z06", "rect": Rect2(-55, 40, 15, 12), "intensity": 0.35, "detail": &"", "reverb": &"outdoor"},
	{"id": &"labyrinth_z07", "rect": Rect2(-55, -62, 60, 14), "intensity": 0.4, "detail": &"", "reverb": &"outdoor"},
	{"id": &"labyrinth_z08", "rect": Rect2(-80, -18, 30, 36), "intensity": 0.4, "detail": &"", "reverb": &"coral_cave"},
	{"id": &"labyrinth_z09", "rect": Rect2(-85, 18, 30, 4), "intensity": 0.45, "detail": &"", "reverb": &"tunnel"},
	{"id": &"labyrinth_z10", "rect": Rect2(-125, -30, 40, 50), "intensity": 0.45, "detail": &"world_coral_groan", "reverb": &"coral_cave"},
	{"id": &"labyrinth_z11", "rect": Rect2(-150, -30, 25, 60), "intensity": 0.5, "detail": &"world_water_drip", "reverb": &"water"},
	{"id": &"labyrinth_z12", "rect": Rect2(-200, -25, 50, 50), "intensity": 0.55, "detail": &"", "reverb": &"outdoor"},
	{"id": &"labyrinth_z13", "rect": Rect2(-550, -120, 350, 240), "intensity": 0.7, "detail": &"world_storm_rumble", "reverb": &"storm"},
	{"id": &"labyrinth_z14", "rect": Rect2(-650, -40, 100, 80), "intensity": 0.55, "detail": &"world_bone_creak", "reverb": &"bone_cave"},
	{"id": &"labyrinth_z15", "rect": Rect2(-750, -80, 100, 120), "intensity": 0.5, "detail": &"", "reverb": &"refuge"},
	{"id": &"labyrinth_z16", "rect": Rect2(-1050, -150, 300, 300), "intensity": 0.8, "detail": &"world_storm_rumble", "reverb": &"storm"},
	{"id": &"labyrinth_z17", "rect": Rect2(-1300, -80, 250, 160), "intensity": 0.95, "detail": &"world_storm_rumble", "reverb": &"storm"},
	{"id": &"labyrinth_z18", "rect": Rect2(-1450, -100, 150, 200), "intensity": 0.7, "detail": &"world_rockfall", "reverb": &"outdoor"},
]


func _init() -> void:
	var set := LabyrinthAudioZoneSet.new()
	for definition in DEFINITIONS:
		var zone := LabyrinthAudioZone.new()
		zone.id = definition["id"]
		zone.rect = definition["rect"]
		zone.intensity = definition["intensity"]
		zone.detail = definition["detail"]
		zone.reverb_profile = definition["reverb"]
		set.zones.append(zone)
	var error := ResourceSaver.save(set, OUT)
	print("Saved %s: %s (%d zones)" % [OUT, error, set.zones.size()])
	quit(0 if error == OK else 1)
