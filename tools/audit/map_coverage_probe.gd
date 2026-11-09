extends SceneTree
## Проверяет, что каждая играбельная сцена показа имеет MapDefinition в атласе.
## Запуск: godot --headless --path . -s tools/audit/map_coverage_probe.gd
##
## Список повторяет tests/test_map_system.gd. Если сцена получает карту через
## map_id/get_map_id на корне, для неё всё равно указывается scene_path — так
## атлас остаётся проверяемым без инстанцирования тяжёлых сцен.

const ATLAS_PATH := "res://resources/map/map_atlas.tres"
const PLAYABLE_SCENES := {
	"res://scenes/campaign/campaign_entry.tscn": &"park_street",
	"res://scenes/slice/locations/park/park_street_art.tscn": &"park_street",
	"res://scenes/slice/locations/park/prologue_park_art.tscn": &"park_street",
	"res://scenes/slice/locations/station_lobby_art.tscn": &"station_lobby",
	"res://scenes/slice/locations/containment_room_art.tscn": &"containment_room",
	"res://scenes/slice/locations/mountain_vision_art.tscn": &"mountain_vision",
	"res://scenes/slice/locations/caravan_road_art.tscn": &"caravan_road",
	"res://scenes/campaign/first_nightmare_pass.tscn": &"caravan_road",
	"res://scenes/campaign/caravan_site_arrival.tscn": &"caravan_site",
	"res://scenes/locations/caravan_site/caravan_site_art.tscn": &"caravan_site",
	"res://scenes/campaign/pilgrim_path_arrival.tscn": &"pilgrim_path",
	"res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn": &"pilgrim_path",
	"res://scenes/campaign/sanctuary_arrival.tscn": &"shadow_sanctuary",
	"res://scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn": &"shadow_sanctuary",
	"res://scenes/campaign/caravan_ambush.tscn": &"ambush_site",
	"res://scenes/locations/ambush_site/ambush_site.tscn": &"ambush_site",
	"res://scenes/locations/post_nightmare/police_precinct.tscn": &"police_precinct",
	"res://scenes/locations/post_nightmare/academy_approach.tscn": &"academy_approach",
	"res://scenes/locations/post_nightmare/academy_gate.tscn": &"academy_gate",
	"res://scenes/locations/post_nightmare/academy_campus.tscn": &"academy_campus",
	"res://scenes/locations/post_nightmare/academy_sleeper_center.tscn": &"academy_sleeper_center",
	"res://scenes/locations/post_nightmare/black_sea_platform.tscn": &"black_sea_platform",
	"res://scenes/locations/post_nightmare/tide_descent.tscn": &"tide_descent",
	"res://scenes/locations/academy_playable/academy_grounds_playable.tscn": &"academy_campus",
	"res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn": &"academy_sleeper_center",
	"res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn": &"labyrinth_first_fragment",
	"res://scenes/locations/post_nightmare/coral_labyrinth.tscn": &"coral_labyrinth",
}


func _init() -> void:
	var atlas := load(ATLAS_PATH) as MapAtlas
	if atlas == null:
		push_error("map_coverage_probe: не загрузился %s" % ATLAS_PATH)
		quit(2)
		return

	var fails := 0
	var checked := 0
	for scene_path in PLAYABLE_SCENES:
		checked += 1
		var expected: StringName = PLAYABLE_SCENES[scene_path]
		var missing := not FileAccess.file_exists(scene_path)
		var location := atlas.find_location_for_scene_path(scene_path)
		var ok := not missing and location != null
		if ok:
			ok = location.id == expected and not location.is_fallback
		if not ok:
			fails += 1
		print(
			"%s %-82s expected=%s got=%s%s"
			% [
				"OK  " if ok else "FAIL",
				scene_path,
				expected,
				location.id if location != null else &"<none>",
				" missing_scene" if missing else "",
			]
		)
	print("MAP_COVERAGE_RESULT checked=%d fail=%d" % [checked, fails])
	quit(0 if fails == 0 else 1)
