extends Node3D
class_name LabyrinthArt
## Environment-art layer for the Forgotten Shore labyrinth.
##
## The greybox script owns collision, routes, spawns and tide. This layer only
## adds visual geometry on top of it. Structural primitives are hidden (never
## deleted) and replaced by coral-kit modules matched to their bounding boxes.
## Landmarks and set dressing are placed from the same anchors the gameplay
## already uses, so no route or collision changes are required.
##
## Rebuild is triggered by LabyrinthGreybox.layout_built; clearing this node is
## safe because it contains visuals only.

const KIT := "res://assets/environments/nightmare/coral/"
const CAMP_KIT := "res://assets/environments/nightmare/caravan/"
const MAT := "res://resources/locations/forgotten_shore_labyrinth/materials/"
const NM := "res://assets/environments/nightmare/materials/"
const STATUE := "res://assets/environments/nightmare/statue/statue_knight_colossus_lod.tscn"
const WORLD_FRAME := preload("res://scripts/world/world_frame.gd")

const WALL_TALL := ["coral_wall_tall_a", "coral_wall_tall_b", "coral_wall_tall_c"]
const WALL_LOW := ["coral_wall_low_a", "coral_wall_low_b", "coral_wall_low_c"]
const MASSES := ["coral_mass_a", "coral_mass_b", "coral_mass_c", "coral_mass_d", "coral_mass_e"]
const BLADES := ["coral_blade_a", "coral_blade_b", "coral_blade_c", "coral_blade_d"]
const LEDGES := ["coral_ledge_a", "coral_ledge_b", "coral_ledge_c", "coral_ledge_d"]
const ARCHES := ["coral_arch_a", "coral_arch_b", "coral_arch_c"]
const RIBS := ["bone_rib_a", "bone_rib_b", "bone_rib_c"]
const VERTEBRAE := ["bone_vertebra_a", "bone_vertebra_b", "bone_vertebra_c"]
const PILES := ["bone_pile_a", "bone_pile_b", "bone_pile_c"]
const SHELLS := ["bone_shell_a", "bone_shell_b", "bone_shell_c"]
const POOLS := ["mud_pool_a", "mud_pool_b", "mud_pool_c"]
const BANKS := ["mud_bank_a", "mud_bank_b"]

const PRIM_MATERIALS := {
	"coral_red.tres": "nm_coral_live_prim",
	"coral_pale.tres": "nm_coral_ground_prim",
	"mud.tres": "nm_mud_wet_prim",
	"bone.tres": "nm_bone_aged_prim",
	"statue_stone.tres": "nm_statue_stone_prim",
	"statue_pale.tres": "nm_statue_stone_prim",
	"fin_dark.tres": "nm_dark_rock_prim",
	"concrete_dark.tres": "nm_statue_stone_prim",
}

const KIT_MATERIALS := [
	"nm_coral_live",
	"nm_coral_dead",
	"nm_coral_crust",
	"nm_mud_wet",
	"nm_bone_aged",
	"nm_coral_ground",
]

var _location: Node3D
var _rng := RandomNumberGenerator.new()
var _zone_roots: Dictionary = {}
var _kit_mats: Dictionary = {}
var _prim_mats: Dictionary = {}
var _camp_mats: Dictionary = {}
var _shore_mats: Dictionary = {}
var _shore_dressing_instances := 0
var _wet_timer := 0.0
var _assets: Dictionary = {}


func setup(location: Node3D) -> void:
	_location = location
	_rng.seed = 0x5EAF00D
	_load_materials()
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_zone_roots.clear()
	_assets.clear()
	if _location == null:
		return
	_apply_primitive_materials()
	_build_seabed()
	_build_horizon()
	_build_storm_backdrop()
	_replace_walls()
	_replace_masses()
	_support_floating_floors()
	_replace_hero_blades()
	_replace_carcass_placeholders()
	_place_landmarks()
	_place_camp()
	_dress_zones()
	_scatter_shore_dressing()
	_place_decals()
	_update_wet_line()
	set_process(true)


func _process(delta: float) -> void:
	_wet_timer += delta
	if _wet_timer < 0.2:
		return
	_wet_timer = 0.0
	_update_wet_line()


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

func _load_materials() -> void:
	_kit_mats.clear()
	for key in KIT_MATERIALS:
		# Source materials live next to the kit GLBs, not in the location folder.
		var base_path := "res://assets/environments/nightmare/materials/%s.tres" % key
		var mat := load(base_path) as ShaderMaterial
		if mat == null:
			continue
		var copy := mat.duplicate(true) as ShaderMaterial
		copy.resource_name = "lab_" + key
		# The kit was authored for a darker preview; lift the base tint so the
		# reef reads as dark crimson rather than near-black silhouettes.
		match key:
			"nm_coral_live":
				copy.set_shader_parameter("base_tint", Color(0.50, 0.23, 0.24, 1.0))
				copy.set_shader_parameter("tip_color", Color(0.64, 0.40, 0.36, 1.0))
				copy.set_shader_parameter("tip_strength", 0.38)
				copy.set_shader_parameter("sss_strength", 0.24)
			"nm_coral_dead":
				copy.set_shader_parameter("base_tint", Color(0.58, 0.50, 0.46, 1.0))
				copy.set_shader_parameter("tip_strength", 0.22)
			"nm_coral_crust":
				copy.set_shader_parameter("base_tint", Color(0.55, 0.42, 0.39, 1.0))
			"nm_mud_wet":
				copy.set_shader_parameter("base_tint", Color(0.24, 0.25, 0.29, 1.0))
				copy.set_shader_parameter("base_roughness_scale", 1.18)
				copy.set_shader_parameter("base_roughness_offset", 0.12)
				copy.set_shader_parameter("base_normal_strength", 0.62)
				copy.set_shader_parameter("wet_strength", 0.35)
			"nm_coral_ground":
				copy.set_shader_parameter("base_tint", Color(0.48, 0.39, 0.35, 1.0))
			"nm_bone_aged":
				copy.set_shader_parameter("base_tint", Color(0.72, 0.68, 0.60, 1.0))
		_kit_mats[key] = copy
	_prim_mats.clear()
	for value in PRIM_MATERIALS.values():
		if _prim_mats.has(value):
			continue
		var mat := load(MAT + value + ".tres") as StandardMaterial3D
		if mat != null:
			_prim_mats[value] = mat
	_camp_mats.clear()
	var wood := load(NM + "nm_wood_dark.tres") as Material
	var rope := load(NM + "nm_rope.tres") as Material
	var leather := load(NM + "nm_leather.tres") as Material
	if wood != null:
		_camp_mats["wood"] = wood
	if rope != null:
		_camp_mats["rope"] = rope
	if leather != null:
		_camp_mats["leather"] = leather
	var meat := StandardMaterial3D.new()
	meat.resource_name = "lab_camp_meat"
	meat.albedo_color = Color(0.30, 0.075, 0.055, 1.0)
	meat.roughness = 0.58
	meat.metallic = 0.0
	_camp_mats["meat"] = meat
	var bone := load(NM + "nm_bone_aged.tres") as Material
	if bone != null:
		_camp_mats["bone"] = bone
	_shore_mats.clear()
	var seaweed := StandardMaterial3D.new()
	seaweed.resource_name = "lab_seaweed"
	seaweed.albedo_color = Color(0.045, 0.11, 0.075, 1.0)
	seaweed.roughness = 0.72
	seaweed.metallic = 0.0
	seaweed.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shore_mats["seaweed"] = seaweed


func _apply_primitive_materials() -> void:
	var visual := _generated_visual()
	if visual == null:
		return
	for zone in visual.get_children():
		for node in zone.get_children():
			var mi := node as MeshInstance3D
			if mi == null or mi.material_override == null:
				continue
			var path := mi.material_override.resource_path
			for suffix in PRIM_MATERIALS.keys():
				if path.ends_with(suffix):
					var key: String = PRIM_MATERIALS[suffix]
					mi.material_override = _prim_mats.get(key, mi.material_override)
					break


func _apply_kit_materials(root: Node3D) -> void:
	for node in _all_mesh_instances(root):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		if mi.material_override is ShaderMaterial:
			var mat := mi.material_override as ShaderMaterial
			if _kit_mats.has(mat.resource_name.trim_prefix("lab_")):
				mi.material_override = _kit_mats[mat.resource_name.trim_prefix("lab_")]
				continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i)
			if mat == null:
				continue
			var key := mat.resource_name.trim_prefix("lab_")
			if _kit_mats.has(key):
				mi.set_surface_override_material(i, _kit_mats[key])


func _override_material(root: Node3D, material: Material) -> void:
	for node in _all_mesh_instances(root):
		(node as MeshInstance3D).material_override = material


func _apply_skull_materials(root: Node3D) -> void:
	if root == null:
		return
	var bone: Material = _prim_mats.get("nm_bone_aged_prim", null)
	var dark := load(MAT + "nm_skull_dark.tres") as Material
	for node in _all_mesh_instances(root):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			var name := mat.resource_name if mat != null else ""
			if name.contains("dark"):
				if dark != null:
					mi.set_surface_override_material(i, dark)
			elif bone != null:
				mi.set_surface_override_material(i, bone)


func _tint_surfaces(root: Node3D, material_name: String, tint: Color) -> void:
	for node in _all_mesh_instances(root):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i)
			if mat == null or mat.resource_name != material_name:
				continue
			var copy := mat.duplicate() as BaseMaterial3D
			if copy == null:
				continue
			copy.albedo_color = tint
			copy.vertex_color_use_as_albedo = false
			mi.set_surface_override_material(i, copy)


func _update_wet_line() -> void:
	if _location == null:
		return
	var water := _location.get_node_or_null(^"Tide/WaterPlane") as Node3D
	var level := water.position.y + 0.12 if water != null else -8.0
	for key in _kit_mats.keys():
		var mat := _kit_mats[key] as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("wet_height", level)


## Replaces a run of identical static kit props with one MultiMesh. This keeps
## the authored silhouette while cutting draw calls on the seabed and horizon.
func _multi_place(
	asset: String,
	parent: Node3D,
	transforms: Array,
	material: Material,
	node_name: String,
	visibility_end := 0.0,
	cast_shadows := true
) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var src := _asset(asset)
	if src == null:
		return null
	var probe := src.instantiate()
	var mesh: Mesh = null
	for node in _all_mesh_instances(probe):
		var mi := node as MeshInstance3D
		if mi != null and mi.mesh != null:
			mesh = mi.mesh
			break
	probe.free()
	if mesh == null:
		return null
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = multi
	if material != null:
		mmi.material_override = material
	if visibility_end > 0.0:
		mmi.visibility_range_end = visibility_end
		mmi.visibility_range_end_margin = 40.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


func _kit_transform(base: Vector3, yaw: float, scale: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(scale), base)


func _append_group(groups: Dictionary, asset: String, transform: Transform3D) -> void:
	if not groups.has(asset):
		groups[asset] = []
	(groups[asset] as Array).append(transform)


## A07-08b: low-cost seaweed/shell/wet-rock dressing across the shore bands.
## All instances live in three MultiMeshes, so the 300+ props cost only a few
## draw calls and never add collision.
func _scatter_shore_dressing() -> void:
	_shore_dressing_instances = 0
	var root := Node3D.new()
	root.name = "ShoreDressing"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EA0FEED
	var specs := [
		[Vector3(24, 0, 0), Vector2(24, 14), 0.0, 18],
		[Vector3(-18, 0, 4), Vector2(20, 18), 0.0, 18],
		[Vector3(-30, -3, -42), Vector2(26, 16), -3.0, 16],
		[Vector3(-32, 0, 28), Vector2(24, 14), 0.0, 14],
		[Vector3(-49, 6, 47), Vector2(12, 8), 6.0, 6],
		[Vector3(-35, 7, -55), Vector2(30, 10), 7.0, 10],
		[Vector3(-65, 0, 0), Vector2(24, 30), 0.0, 12],
		[Vector3(-122, 18, -24), Vector2(12, 12), 18.0, 10],
		[Vector3(-137, -6, 0), Vector2(24, 40), -6.0, 14],
		[Vector3(-330, 0, 0), Vector2(240, 50), 0.0, 38],
		[Vector3(-860, 0, 0), Vector2(240, 50), 0.0, 26],
		[Vector3(-1140, 8, 0), Vector2(150, 30), 8.0, 16],
		[Vector3(-1408, 35, 0), Vector2(24, 20), 35.0, 10],
	]
	var seaweed: Array = []
	var shells: Array = []
	var rocks: Array = []
	for spec in specs:
		var center: Vector3 = spec[0]
		var size: Vector2 = spec[1]
		var half := size * 0.5
		var floor_y: float = spec[2]
		var count: int = spec[3]
		for i in count:
			var pos := Vector3(
				center.x + rng.randf_range(-half.x, half.x),
				floor_y + 0.02,
				center.z + rng.randf_range(-half.y, half.y)
			)
			var roll := rng.randf()
			if roll < 0.46:
				seaweed.append(_kit_transform(pos, rng.randf_range(0.0, TAU), Vector3(rng.randf_range(0.24, 0.48), rng.randf_range(0.65, 1.25), rng.randf_range(0.24, 0.48))))
				_shore_dressing_instances += 1
			elif roll < 0.77:
				shells.append(_kit_transform(pos, rng.randf_range(0.0, TAU), Vector3(rng.randf_range(0.45, 0.85), rng.randf_range(0.35, 0.65), rng.randf_range(0.45, 0.85))))
				_shore_dressing_instances += 1
			else:
				rocks.append(_kit_transform(pos, rng.randf_range(0.0, TAU), Vector3(rng.randf_range(0.30, 0.62), rng.randf_range(0.18, 0.38), rng.randf_range(0.30, 0.62))))
				_shore_dressing_instances += 1
	_multi_place("coral_blade_a", root, seaweed, _shore_mats.get("seaweed", null), "ShoreSeaweed", 800.0, false)
	_multi_place("bone_shell_a", root, shells, _kit_mats.get("nm_bone_aged", null), "ShoreShells", 700.0, false)
	_multi_place("mud_bank_a", root, rocks, _kit_mats.get("nm_mud_wet", null), "ShoreWetRocks", 700.0, false)


func shore_dressing_stats() -> Dictionary:
	var nodes := 0
	var root := get_node_or_null(^"ShoreDressing")
	if root != null:
		nodes = root.get_child_count()
	return {
		"instances": _shore_dressing_instances,
		"nodes": nodes,
	}


# ---------------------------------------------------------------------------
# Seabed and horizon
# ---------------------------------------------------------------------------

func _build_seabed() -> void:
	# The greybox floors are slabs above a flat water plane. At low tide the
	# sea should expose a mudflat, not a void. This plane sits 0.6 m above the
	# low-water mark and is hidden by the tide at high water.
	var seabed := MeshInstance3D.new()
	seabed.name = "LowTideFlat"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800, 640)
	seabed.mesh = plane
	seabed.material_override = _prim_mats.get("nm_mud_wet_prim", null)
	seabed.position = Vector3(-700, -7.4, 0)
	seabed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seabed)

	# Low silhouettes on the flat so the horizon does not read as graph paper.
	# One MultiMesh per silhouette family keeps this cheap (3 draws instead of
	# 30+); the variants are indistinguishable at seabed distance.
	var root := _zone_node("Seabed")
	var bank_transforms: Array = []
	var mass_transforms: Array = []
	var blade_transforms: Array = []
	for i in 34:
		var x := 40.0 - float(i) * 44.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := side * (72.0 + float(i % 4) * 16.0)
		if x < -120.0 and x > -160.0 and absf(z) < 45.0:
			continue
		if i % 3 == 0:
			bank_transforms.append(_kit_transform(Vector3(x, -7.4, z), float(i) * 0.7, Vector3(2.4, 1.2, 2.4)))
		elif i % 3 == 1:
			mass_transforms.append(_kit_transform(Vector3(x, -7.4, z), float(i) * 0.9, Vector3(1.1, 1.0, 1.1)))
		else:
			blade_transforms.append(_kit_transform(Vector3(x, -7.4, z), float(i) * 0.6, Vector3(1.3, 1.4, 1.3)))
	_multi_place(BANKS[0], root, bank_transforms, _kit_mats.get("nm_coral_ground", null), "SeabedBanks", 1800.0)
	_multi_place(MASSES[0], root, mass_transforms, _kit_mats.get("nm_coral_dead", null), "SeabedMasses", 1800.0)
	_multi_place(BLADES[0], root, blade_transforms, _kit_mats.get("nm_coral_live", null), "SeabedBlades", 1600.0)

	# A low ridge on both horizons prevents the mudflat from ending in a
	# perfectly straight line. One silhouette mesh is enough at this distance.
	var dark: Material = _prim_mats.get("nm_dark_rock_prim", null)
	var ridge_transforms: Array = []
	for i in 12:
		var x := -700.0 - float(i) * 70.0
		var z := -260.0 if i % 2 == 0 else 260.0
		ridge_transforms.append(_kit_transform(Vector3(x, -7.4, z), float(i) * 0.8, Vector3(3.2, 2.4, 3.2)))
	_multi_place(MASSES[2], root, ridge_transforms, dark, "HorizonRidge", 1200.0)
	# Far western horizon: storm cliffs and the silhouette of the next island.
	var cliff_mass_transforms: Array = []
	for i in 4:
		cliff_mass_transforms.append(_kit_transform(Vector3(-1580.0 + float(i) * 18.0, -6.0, -150.0 + float(i) * 100.0), float(i) * 0.8, Vector3(4.0, 3.4, 3.4)))
	var cliff_spire_transforms: Array = []
	for i in 3:
		cliff_spire_transforms.append(_kit_transform(Vector3(-1650.0, -6.0, -110.0 + float(i) * 110.0), float(i) * 0.7, Vector3(2.0, 1.9, 2.0)))
	_multi_place("coral_mass_a", root, cliff_mass_transforms, dark, "FarCliffs", 1000.0)
	_multi_place("coral_spire_west", root, cliff_spire_transforms, dark, "FarSpires", 1000.0)


## The playable fragment is a 1.5 km strip inside a much larger crater. Without
## a horizon it reads as a slab floating in grey fog. This pass builds a
## double ridge ring (near reef rim, far crater wall), a far-sea plane, a
## southern sea-stack line, the distant Crimson Spire, the Dark City on the
## north-east rim, and the western storm cliffs. All of it is visual-only and
## sits outside the playable corridor.
func _build_horizon() -> void:
	var horizon := Node3D.new()
	horizon.name = "Horizon"
	add_child(horizon)

	var sea := WORLD_FRAME.far_sea(
		Vector3(-700.0, -8.15, 0.0),
		5200.0,
		Color(0.045, 0.060, 0.075),
		Color(0.39, 0.42, 0.45),
		"FarSea",
		220.0,
		1900.0
	)
	horizon.add_child(sea)

	# Near rim: reads as the next line of reef beyond the playable coral.
	var near_rim := WORLD_FRAME.ridge_ring(
		Vector3(-700.0, -8.0, 0.0),
		1050.0,
		160,
		-8.0,
		40.0,
		130.0,
		Color(0.70, 0.71, 0.70),
		Color(0.36, 0.40, 0.43),
		Color(0.36, 0.39, 0.42),
		Color(0.15, 0.18, 0.21),
		17,
		"NearRim"
	)
	horizon.add_child(near_rim)

	# Far rim: the crater wall, almost dissolved into the overcast.
	var far_rim := WORLD_FRAME.ridge_ring(
		Vector3(-700.0, -8.0, 0.0),
		1780.0,
		140,
		-8.0,
		80.0,
		230.0,
		Color(0.70, 0.71, 0.70),
		Color(0.52, 0.55, 0.55),
		Color(0.36, 0.39, 0.42),
		Color(0.27, 0.31, 0.34),
		29,
		"FarRim"
	)
	horizon.add_child(far_rim)

	# Low reef bands on the north and south flanks. They sit outside the
	# east-west playable corridor and hide the seam between seabed and rim.
	WORLD_FRAME.reef_band(
		horizon,
		Vector3(-700.0, 0.0, 0.0),
		-7.6,
		340.0,
		780.0,
		64,
		14.0,
		58.0,
		Color(0.15, 0.075, 0.085),
		Color(0.45, 0.47, 0.48),
		0.55,
		41,
		"NorthReefBand"
	)
	WORLD_FRAME.reef_band(
		horizon,
		Vector3(-700.0, 0.0, 0.0),
		-7.6,
		360.0,
		820.0,
		58,
		12.0,
		46.0,
		Color(0.12, 0.065, 0.075),
		Color(0.45, 0.47, 0.48),
		0.62,
		57,
		"SouthReefBand"
	)

	# Southern sea stacks: the reef breaks into the Black Sea here.
	var stack_positions := [
		Vector3(-1180.0, 0.0, 520.0),
		Vector3(-760.0, 0.0, 610.0),
		Vector3(-330.0, 0.0, 560.0),
		Vector3(90.0, 0.0, 640.0),
	]
	for i in stack_positions.size():
		var stack: Node3D = WORLD_FRAME.spire_cluster(
			horizon,
			stack_positions[i],
			-8.0,
			92.0 + float(i % 2) * 34.0,
			4,
			Color(0.11, 0.12, 0.14),
			Color(0.46, 0.49, 0.51),
			0.48,
			70 + i * 13,
			"SeaStack%d" % i,
			26.0
		)
		stack.name = "SeaStack%d" % i

	# The Crimson Spire is the region landmark from the world map. It is not a
	# route anchor in this fragment; it only tells the player the Labyrinth
	# continues far beyond the cliffs.
	var spire := WORLD_FRAME.spire_cluster(
		horizon,
		Vector3(-960.0, 0.0, 760.0),
		-8.0,
		285.0,
		6,
		Color(0.20, 0.065, 0.075),
		Color(0.47, 0.40, 0.40),
		0.58,
		101,
		"CrimsonSpire",
		38.0
	)
	spire.name = "CrimsonSpire"

	# The Dark City sits on the north-east crater rim, far outside the fragment.
	var city_palette := [
		Color(0.055, 0.060, 0.070),
		Color(0.075, 0.080, 0.090),
		Color(0.045, 0.050, 0.060),
	]
	WORLD_FRAME.city_skyline(
		horizon,
		Vector3(-330.0, 0.0, -820.0),
		-6.0,
		280.0,
		700.0,
		36,
		26.0,
		108.0,
		city_palette,
		211,
		0.0,
		0.0,
		"DarkCity",
		Color(0.40, 0.44, 0.48),
		260.0,
		1300.0,
		Color(1.0, 0.72, 0.46),
		0.07,
		5.0,
		4.0,
		12.0,
		0.55
	)
	# Jagged towers break the rectangular skyline so the Dark City reads as a
	# ruin on the crater rim, not a modern skyline.
	WORLD_FRAME.spire_cluster(
		horizon,
		Vector3(-330.0, 0.0, -820.0),
		-6.0,
		175.0,
		14,
		Color(0.055, 0.060, 0.070),
		Color(0.52, 0.55, 0.58),
		0.72,
		260,
		"DarkCitySpires",
		78.0
	)

	# Western storm cliffs, behind the rain curtain. These make the storm act
	# read as a mountain wall rather than a flat backdrop.
	for i in 3:
		WORLD_FRAME.spire_cluster(
			horizon,
			Vector3(-1680.0 - float(i) * 55.0, 0.0, -190.0 + float(i) * 190.0),
			-8.0,
			170.0 + float(i) * 28.0,
			4,
			Color(0.085, 0.095, 0.110),
			Color(0.42, 0.46, 0.50),
			0.40,
			300 + i * 11,
			"StormCliff%d" % i,
			34.0
		)


func _build_storm_backdrop() -> void:
	var mat := load(MAT + "nm_rain_curtain.tres") as ShaderMaterial
	if mat == null:
		return
	var specs := [
		[Vector3(-1340, 26, 0), Vector2(300, 92), 0.42],
		[Vector3(-1490, 30, 0), Vector2(420, 120), 0.28],
	]
	for spec in specs:
		var mi := MeshInstance3D.new()
		mi.name = "RainCurtain"
		var quad := QuadMesh.new()
		quad.size = spec[1]
		mi.mesh = quad
		mi.material_override = mat.duplicate() as ShaderMaterial
		mi.position = spec[0]
		mi.rotation.y = PI * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi.material_override as ShaderMaterial).set_shader_parameter("opacity", spec[2])
		add_child(mi)


# ---------------------------------------------------------------------------
# Structural replacement
# ---------------------------------------------------------------------------

func _is_wall_name(n: String) -> bool:
	# Wall segments are not all named "Wall": the Z13/Z16 parapets use
	# CentralNorth / LowSouth / RidgeInner and would otherwise stay as flat
	# red boxes after the art pass.
	if n.contains("Floor") or n.contains("Ledge") or n.contains("Top"):
		return false
	return (
		n.contains("Wall")
		or n.contains("Divider")
		or n.contains("Parapet")
		or n.contains("CentralNorth")
		or n.contains("CentralSouth")
		or n.contains("LowSouth")
		or n.contains("LowNorth")
		or n.contains("RidgeInner")
		or n.contains("RidgeOuter")
	)


func _replace_walls() -> void:
	var visual := _generated_visual()
	if visual == null:
		return
	for zone in visual.get_children():
		for node in zone.get_children():
			var mi := node as MeshInstance3D
			if mi == null or not mi.visible:
				continue
			var n := String(mi.name)
			if not _is_wall_name(n) or not mi.has_meta(&"art_size"):
				continue
			if n.begins_with("Boundary"):
				continue
			var size: Vector3 = mi.get_meta(&"art_size")
			if size.y < 1.2 or size.x < 3.0:
				continue
			var center: Vector3 = mi.get_meta(&"art_center")
			var yaw: float = mi.get_meta(&"art_rotation_y")
			if size.y < 3.0:
				_replace_low_wall(_zone_node(zone.name), center, size, yaw, n)
				_hide(mi)
				continue
			var target_y := maxf(size.y * 1.05, 1.7)
			var target_x := size.x * 1.04
			var target_z := clampf(size.z * 1.45, 1.2, 3.2)
			var idx: int = abs(hash(n)) % 3
			var asset: String = WALL_TALL[idx] if size.y >= 6.5 else WALL_LOW[idx]
			_stretch(asset, _zone_node(zone.name), center, Vector3(target_x, target_y, target_z), yaw)
			_hide(mi)


func _replace_low_wall(parent: Node3D, center: Vector3, size: Vector3, yaw: float, key: String) -> void:
	# Flattening a 6-8 m coral wall into a 1.5 m parapet erases its silhouette.
	# Use overlapping mud banks plus a few small blades instead; the original
	# collision box remains exactly where it was.
	var count := maxi(2, int(ceil(size.x / 7.0)))
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
	var base_y := center.y - size.y * 0.5
	for i in count:
		var t := float(i) / float(count - 1)
		var offset := (t - 0.5) * size.x * 0.92
		var p := center + basis * Vector3(offset, 0.0, 0.0)
		p.y = base_y
		var bank := _place(BANKS[abs(hash(key + str(i))) % BANKS.size()], parent, p, yaw + float(i % 2) * 0.08, Vector3(1.05, maxf(size.y / 1.6, 0.7), clampf(size.z / 2.2, 0.55, 1.15)))
		if bank == null:
			continue
		if i % 2 == 0:
			_place(BLADES[(i + abs(hash(key))) % BLADES.size()], parent, p + Vector3(0, 0.1, 0), yaw + float(i) * 0.6, Vector3(0.32, 0.45, 0.32))
		if i % 3 == 0:
			_place(PILES[(i + abs(hash(key))) % PILES.size()], parent, p + basis * Vector3(1.5, 0, 0), yaw + 1.0, Vector3(0.55, 0.55, 0.55))


func _replace_masses() -> void:
	var visual := _generated_visual()
	if visual == null:
		return
	var groups: Dictionary = {}
	for zone in visual.get_children():
		for node in zone.get_children():
			var mi := node as MeshInstance3D
			if mi == null or not mi.has_meta(&"art_mass_group"):
				continue
			var group_name: String = mi.get_meta(&"art_mass_group")
			if not groups.has(group_name):
				groups[group_name] = {"zone": zone.name, "base": mi.get_meta(&"art_mass_base"), "size": mi.get_meta(&"art_mass_size"), "parts": []}
			(groups[group_name].parts as Array).append(mi)

	for group_name in groups.keys():
		var group: Dictionary = groups[group_name]
		for part in group.parts:
			_hide(part as MeshInstance3D)
		var size: Vector3 = group.size
		var base: Vector3 = group.base
		if size.y > 25.0 or size.z > 80.0 or size.x > 80.0:
			continue
		var zone_root := _zone_node(String(group.zone))
		var long_x := size.x >= size.z
		var count := 1 if maxf(size.x, size.z) < 10.0 else 3
		for i in count:
			var variant: String = MASSES[(abs(hash(group_name)) + i) % MASSES.size()]
			var offset := Vector3.ZERO
			if count == 3:
				var t := (float(i) - 1.0) * 0.30
				offset = Vector3(t * size.x, 0.0, 0.0) if long_x else Vector3(0.0, 0.0, t * size.z)
			var target := Vector3(
				size.x * (0.78 if count > 1 else 1.04),
				size.y * (0.98 if i == 1 else 0.90),
				size.z * (0.78 if count > 1 else 1.04)
			)
			var center := base + offset + Vector3(0, target.y * 0.5, 0)
			_stretch(variant, zone_root, center, target, _rng.randf_range(-0.2, 0.2))


func _support_floating_floors() -> void:
	# Greybox floors are horizontal slabs hovering over the low-tide flat.
	# Give each one a coral pedestal below the collision surface. Supports are
	# always inside the floor footprint and never reach the walkable top.
	var visual := _generated_visual()
	if visual == null:
		return
	for zone in visual.get_children():
		for node in zone.get_children():
			var mi := node as MeshInstance3D
			if mi == null or not mi.has_meta(&"art_size"):
				continue
			var n := String(mi.name)
			if n.contains("Bridge") or n.contains("Ramp") or n.contains("Stairs"):
				continue
			if mi.has_meta(&"art_role") and String(mi.get_meta(&"art_role")) == "ramp":
				continue
			var size: Vector3 = mi.get_meta(&"art_size")
			if size.y > 1.2 or size.y < 0.15:
				continue
			var area := size.x * size.z
			if area < 50.0:
				continue
			var center: Vector3 = mi.get_meta(&"art_center")
			var top := center.y - size.y * 0.5 - 0.05
			var height := top + 8.0
			if height < 2.2:
				continue
			var zone_root := _zone_node(zone.name)
			var long_x := size.x >= size.z
			var span := maxf(size.x, size.z)
			var count := 1 if span <= 60.0 else clampi(int(ceil(span / 55.0)), 2, 6)
			for i in count:
				var t := 0.5 if count == 1 else float(i) / float(count - 1)
				var long_offset := (t - 0.5) * (span - minf(size.x, size.z) * 0.9)
				var p := center
				if long_x:
					p.x += long_offset
				else:
					p.z += long_offset
				var target_long := (span * 0.78) if count == 1 else (span / float(count)) * 1.55
				var target_short := minf(size.x, size.z) * 0.78
				var target := Vector3(
					target_long if long_x else target_short,
					height,
					target_short if long_x else target_long
				)
				var variant: String = MASSES[(abs(hash(n)) + i) % MASSES.size()]
				_stretch(variant, zone_root, Vector3(p.x, top - height * 0.5, p.z), target, float(i) * 0.7)


func _replace_hero_blades() -> void:
	var visual := _generated_visual()
	if visual == null:
		return
	for zone in visual.get_children():
		for node in zone.get_children():
			var mi := node as MeshInstance3D
			if mi == null or not String(mi.name).contains("HeroBlade") or not mi.has_meta(&"art_center"):
				continue
			var center: Vector3 = mi.get_meta(&"art_center")
			var size: Vector3 = mi.get_meta(&"art_size")
			var yaw: float = mi.get_meta(&"art_rotation_y")
			var target := Vector3(maxf(size.x, 4.0), size.y * 1.10, maxf(size.z, 4.0))
			var c := Vector3(center.x, center.y - size.y * 0.5 + target.y * 0.5, center.z)
			_stretch("coral_blade_hero", _zone_node(zone.name), c, target, yaw)
			_hide(mi)


func _replace_carcass_placeholders() -> void:
	var visual := _generated_visual()
	if visual == null:
		return
	var root := _zone_node("Z02_Carcass")
	# The crab placeholders are nested under Z02_Crab0/1/2 Node3D groups, so a
	# direct-child pass misses Body/Pincer/Leg meshes. Hide the placeholders
	# recursively, but never hide the Z02_Carcass zone itself.
	var generated := _generated_visual()
	if generated != null:
		for zone in generated.get_children():
			if String(zone.name) != "Z02_Carcass":
				continue
			for child in zone.get_children():
				_hide_carcass_placeholders(child)
	# A low, torn carcass mass with a rib cage over it. No collision: the
	# existing greybox carcass box still blocks the player at the same place.
	var base := Vector3(19, -1.5, 26)
	var body := _place("coral_mass_e", root, base, 0.2, Vector3(2.3, 0.55, 1.35))
	var dead: Material = _prim_mats.get("nm_coral_dead_prim", null)
	if body != null and dead != null:
		_override_material(body, dead)
	_place("coral_mass_b", root, Vector3(21.0, -1.15, 25.0), 1.0, Vector3(1.8, 0.35, 1.1))
	for i in 8:
		var x := 13.0 + float(i) * 1.8
		var rib: String = RIBS[i % RIBS.size()]
		var yaw := PI * 0.5 + _rng.randf_range(-0.22, 0.22)
		_place(rib, root, Vector3(x, -0.2, 25.8), yaw, Vector3(1.9, 1.9, 1.4))
	for i in 4:
		_place(SHELLS[i % SHELLS.size()], root, Vector3(14.0 + float(i) * 3.2, -1.1, 29.2), _rng.randf_range(-1.0, 1.0), Vector3(2.2, 1.8, 2.2))
	var carcass_skull := _place("bone_skull", root, Vector3(26.5, 0.2, 26.0), -PI * 0.5, Vector3(2.0, 1.8, 2.0))
	_apply_skull_materials(carcass_skull)
	_place(PILES[0], root, Vector3(12.5, -1.4, 25.0), 0.4, Vector3(1.8, 1.2, 1.8))
	_place(POOLS[0], root, Vector3(15, -1.45, 19), 0.0, Vector3(1.0, 0.14, 0.8))
	_place(POOLS[1], root, Vector3(25, -1.45, 22), 0.7, Vector3(0.8, 0.14, 1.0))


func _hide_carcass_placeholders(node: Node) -> void:
	if node == null:
		return
	var node_name := String(node.name)
	if node is Node3D and (
		node_name.begins_with("Z02_Crab") or node_name == "Z02_Carcass"
	):
		(node as Node3D).visible = false
		return
	for child in node.get_children():
		_hide_carcass_placeholders(child)


# ---------------------------------------------------------------------------
# Decals (azure blood, drag marks)
# ---------------------------------------------------------------------------

func _place_decals() -> void:
	var blood := load("res://assets/environments/nightmare/materials/textures/p3_blood.png") as Texture2D
	var footprint := load("res://assets/environments/nightmare/materials/textures/p3_footprint.png") as Texture2D
	var scrape := load("res://assets/environments/nightmare/materials/textures/p3_chain_scrape.png") as Texture2D
	if blood == null:
		return
	_decal(blood, _zone_node("Z02_Carcass"), Vector3(18.0, 0.8, 26.0), Vector3(9.0, 4.0, 6.0), 0.2, Color(0.22, 0.58, 0.82, 0.85), "AzureBlood")
	_decal(blood, _zone_node("Z03_FirstFork"), Vector3(-1.0, 0.8, 3.0), Vector3(5.0, 3.0, 4.0), 0.7, Color(0.22, 0.58, 0.82, 0.70), "AzureBloodFork")
	_decal(blood, _zone_node("Z13_HuntingGrounds"), Vector3(-360.0, 0.8, -12.0), Vector3(8.0, 3.5, 6.0), 1.1, Color(0.20, 0.52, 0.76, 0.75), "AzureBloodHunt")
	_decal(blood, _zone_node("Z14_BoneBridge"), Vector3(-600.0, 6.8, 0.0), Vector3(5.0, 2.0, 4.0), 0.3, Color(0.20, 0.52, 0.76, 0.65), "AzureBloodBridge")
	if footprint != null:
		_decal(footprint, _zone_node("Z02_Carcass"), Vector3(16.0, 0.05, 22.0), Vector3(6.0, 1.0, 5.0), 0.4, Color(0.06, 0.07, 0.08, 0.65), "Footprints")
		_decal(footprint, _zone_node("Z13_HuntingGrounds"), Vector3(-330.0, 0.05, 10.0), Vector3(7.0, 1.0, 5.0), 1.3, Color(0.06, 0.07, 0.08, 0.60), "FootprintsHunt")
		_decal(footprint, _zone_node("Z14_BoneBridge"), Vector3(-588.0, 6.82, 0.0), Vector3(4.0, 0.8, 3.0), 1.2, Color(0.09, 0.20, 0.30, 0.55), "WetTrail")
	if scrape != null:
		_decal(scrape, _zone_node("Z02_Carcass"), Vector3(22.5, 0.04, 23.0), Vector3(7.0, 1.2, 4.0), 0.9, Color(0.06, 0.08, 0.10, 0.68), "ChainScrape")
		_decal(scrape, _zone_node("Z13_HuntingGrounds"), Vector3(-348.0, 0.04, -18.0), Vector3(10.0, 1.4, 5.0), 0.25, Color(0.06, 0.08, 0.10, 0.62), "ChainScrapeHunt")
		_decal(scrape, _zone_node("Z10_CoralHill"), Vector3(-98.0, 18.05, -10.5), Vector3(4.5, 1.0, 3.0), 0.45, Color(0.05, 0.07, 0.09, 0.55), "WetDrag")
		_decal(scrape, _zone_node("Z08_Clearing"), Vector3(-55.0, 0.04, 19.0), Vector3(5.0, 0.9, 3.0), 1.0, Color(0.05, 0.07, 0.09, 0.55), "ClawMark")


func _decal(texture: Texture2D, parent: Node3D, pos: Vector3, size: Vector3, yaw: float, tint: Color, decal_name := "AzureBlood") -> void:
	var decal := Decal.new()
	decal.name = decal_name
	decal.texture_albedo = texture
	decal.modulate = tint
	decal.albedo_mix = 0.9
	decal.size = size
	decal.position = pos
	decal.rotation.y = yaw
	decal.upper_fade = 0.15
	decal.lower_fade = 0.35
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 55.0
	decal.distance_fade_length = 25.0
	parent.add_child(decal)


# ---------------------------------------------------------------------------
# Landmarks
# ---------------------------------------------------------------------------

func _place_landmarks() -> void:
	_landmark_statue()
	_landmark_camp_pillar()
	_landmark_western_spire()
	_landmark_bone_bridge()
	_landmark_storm_wall()
	_landmark_cliffs()


func _landmark_statue() -> void:
	var anchor := _landmark(&"Statue")
	if anchor == null:
		return
	_hide_landmark_children(anchor)
	var statue := (load(STATUE) as PackedScene).instantiate() as Node3D
	# The hero statue origin is the neck platform; body extends 200 m down.
	statue.position = Vector3(0, 200.0, 0)
	statue.rotation_degrees.y = 90.0
	anchor.add_child(statue)
	_tint_statue_platform(statue)
	# A rocky base joins the square plinth to the low-tide flat.
	_place("coral_mass_c", anchor, Vector3(0, -7.4, 0), 0.0, Vector3(3.8, 0.85, 3.8))
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var p := Vector3(cos(angle) * 24.0, -1.5, sin(angle) * 26.0)
		_place(MASSES[i % MASSES.size()], anchor, p, angle, Vector3(1.15, 0.75, 1.15))
	_place("mud_bank_a", anchor, Vector3(-18, -0.2, 18), 0.6, Vector3(2.0, 0.8, 1.4))
	# A broken rock ring hides the square display plinth.
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_place(MASSES[(i + 1) % MASSES.size()], anchor, Vector3(cos(angle) * 8.5, -2.0, sin(angle) * 8.5), angle, Vector3(0.85, 0.62, 0.85))


func _tint_statue_platform(statue: Node3D) -> void:
	var rock: Material = _prim_mats.get("nm_statue_stone_prim", null)
	if rock == null:
		return
	for node in _all_mesh_instances(statue):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat != null and mat.resource_name == "platform":
				mi.set_surface_override_material(i, rock)


func _landmark_camp_pillar() -> void:
	var anchor := _landmark(&"CampPillar")
	if anchor == null:
		return
	_hide_landmark_children(anchor)
	# A03 moves the camp landmark close to the final camera line. Keep the
	# silhouette but push it behind/right and reduce its bulk so it does not
	# read as a wall between the camera and the campfire.
	_place("coral_pillar_camp", anchor, Vector3.ZERO, 0.15, Vector3(0.12, 0.17, 0.12))
	var camp_pillar := anchor.get_child(anchor.get_child_count() - 1) as Node3D
	if camp_pillar != null:
		var bounds := _local_aabb(camp_pillar)
		camp_pillar.position.y = -bounds.position.y
	_place("coral_blade_b", anchor, Vector3(7, 0, 4), 0.4, Vector3(0.9, 0.85, 0.9))
	_place("coral_blade_c", anchor, Vector3(-6, 0, -3), 1.8, Vector3(0.8, 0.7, 0.8))


func _landmark_western_spire() -> void:
	var anchor := _landmark(&"WesternSpire")
	if anchor == null:
		return
	_hide_landmark_children(anchor)
	_place("coral_spire_west", anchor, Vector3.ZERO, 0.0, Vector3(1.0, 1.0, 1.0))
	_place("coral_blade_a", anchor, Vector3(10, 0, 8), 0.8, Vector3(0.9, 0.8, 0.9))
	_place("coral_blade_d", anchor, Vector3(-9, 0, -7), 2.2, Vector3(0.8, 0.65, 0.8))


func _landmark_bone_bridge() -> void:
	var anchor := _landmark(&"BoneBridge")
	if anchor == null:
		return
	_hide_landmark_children(anchor)
	# The walkable surface is owned by Generated/Visual/Z14. Here we add
	# vertebrae supports and rib guard rails without touching the floor top.
	# The deck and low bone rails live in Generated/Visual/Z14; this anchor
	# only contributes two hero arches and end debris.
	_place(RIBS[2], anchor, Vector3(-46.0, 0.0, 0.0), 1.57, Vector3(1.9, 1.6, 1.6))
	_place(RIBS[1], anchor, Vector3(46.0, 0.0, 0.0), -1.57, Vector3(1.9, 1.6, 1.6))
	for i in 4:
		_place(PILES[i % PILES.size()], anchor, Vector3(-46.0 + float(i) * 31.0, 0.0, 0.0), _rng.randf_range(-1.0, 1.0), Vector3(1.2, 1.0, 1.2))


func _landmark_storm_wall() -> void:
	var anchor := _landmark(&"StormWall")
	if anchor == null:
		return
	_hide_landmark_children(anchor)
	var dark: Material = _prim_mats.get("nm_dark_rock_prim", null)
	# Anchor y=20 was the centre of the old primitive box. The replacement
	# must stand on the storm-run ground, not float 20 m in the air.
	for i in 10:
		var node := _place("coral_wall_tall_" + String("abc"[i % 3]), anchor, Vector3(0, -28.0, -105.0 + float(i) * 23.0), -PI * 0.5, Vector3(1.85, 1.1 + float(i % 3) * 0.15, 1.6))
		if dark != null:
			_override_material(node, dark)
	for i in 4:
		var node := _place("coral_spire_west", anchor, Vector3(-10, -28.0, -80.0 + float(i) * 55.0), 0.2, Vector3(0.9, 1.0, 0.9))
		if dark != null:
			_override_material(node, dark)


func _landmark_cliffs() -> void:
	var anchor := _landmark(&"Cliffs")
	if anchor == null:
		return
	_hide_landmark_children(anchor)
	var dark: Material = _prim_mats.get("nm_dark_rock_prim", null)
	for i in 10:
		var z := -105.0 + float(i) * 23.0
		var node := _place("coral_wall_tall_" + String("abc"[i % 3]), anchor, Vector3(0, -28.0, z), -PI * 0.5, Vector3(1.7, 1.15 + float(i % 3) * 0.12, 1.5))
		if dark != null:
			_override_material(node, dark)
	for i in 5:
		var node := _place("coral_mass_" + String("abcde"[i % 5]), anchor, Vector3(-14, -28.0, -80.0 + float(i) * 40.0), float(i) * 0.7, Vector3(1.8, 0.9, 1.8))
		if dark != null:
			_override_material(node, dark)


# ---------------------------------------------------------------------------
# Camp and hand dressing
# ---------------------------------------------------------------------------

func _place_camp() -> void:
	var root := _zone_node("Z10_CoralHill")
	var visual := _generated_visual()
	if visual != null:
		for zone in visual.get_children():
			for node in zone.get_children():
				var n := String(node.name)
				if n.begins_with("Z10_Campfire_") or n.begins_with("Z10_Bed") or n.begins_with("Z10_Windbreak"):
					if node is MeshInstance3D:
						_hide(node as MeshInstance3D)
	_place("campfire_a", root, Vector3(-100, 18.02, -5), 0.0, Vector3(1.0, 1.0, 1.0))
	_place("bedroll_a", root, Vector3(-103.5, 18.03, -10.2), 1.5, Vector3(1.5, 1.4, 1.4))
	_place("bedroll_b", root, Vector3(-101.5, 18.03, -10.2), 1.7, Vector3(1.5, 1.4, 1.4))
	_place("bedroll_c", root, Vector3(-99.5, 18.03, -10.2), 1.5, Vector3(1.5, 1.4, 1.4))
	var wb_a := _place("windbreak_a", root, Vector3(-96.0, 18.0, -11.2), -0.35, Vector3(1.2, 1.0, 1.0))
	var wb_b := _place("windbreak_b", root, Vector3(-93.8, 18.0, -12.4), 0.25, Vector3(1.0, 0.9, 1.0))
	var wb_c := _place("windbreak_a", root, Vector3(-91.6, 18.0, -11.8), -0.15, Vector3(1.1, 1.0, 1.0))
	for wb in [wb_a, wb_b, wb_c]:
		if wb != null:
			_tint_surfaces(wb, "nm_linen", Color(0.50, 0.43, 0.36, 1.0))
	# Keep the A03 DemoEndZone (sphere r=4 at -100,18.2,-5) visually clear:
	# campfire is the only prop inside it; sleeping/gear props sit outside.
	_place("bone_pile_b", root, Vector3(-105.5, 18.02, -1.0), 0.8, Vector3(1.0, 1.0, 1.0))
	_camp_meat_rack(root, Vector3(-93.2, 18.0, -10.0), 0.32)
	_camp_rope_coil(root, Vector3(-104.4, 18.04, -2.6), 0.45)
	_place("crate_supplies_a", root, Vector3(-96.0, 18.0, -1.0), 0.55, Vector3(1.0, 1.0, 1.0))
	_place("sack_grain_a", root, Vector3(-95.4, 18.0, -0.2), 0.2, Vector3(0.9, 0.9, 0.9))
	_place("firewood_bundle", root, Vector3(-103.6, 18.0, -1.8), 1.1, Vector3(0.9, 0.9, 0.9))
	_place("water_flask", root, Vector3(-95.6, 18.35, -1.0), 0.8, Vector3(1.0, 1.0, 1.0))
	_place("barrel_water_a", root, Vector3(-104.8, 18.0, -7.8), 0.3, Vector3(0.9, 0.9, 0.9))
	_place("coral_mass_e", root, Vector3(-108.0, 11.0, -6.0), 0.6, Vector3(0.75, 1.0, 0.75))
	_place("coral_mass_c", root, Vector3(-95.0, 11.0, -14.0), 1.4, Vector3(0.85, 1.05, 0.85))
	var fill := OmniLight3D.new()
	fill.name = "CampFill"
	fill.position = Vector3(-100.0, 20.0, -5.0)
	fill.light_color = Color(1.0, 0.68, 0.42, 1.0)
	fill.light_energy = 2.2
	fill.omni_range = 10.0
	fill.shadow_enabled = false
	root.add_child(fill)
	_place("coral_mass_a", root, Vector3(-104.0, 12.0, -9.0), 0.3, Vector3(0.65, 0.95, 0.65))
	_place("coral_mass_b", root, Vector3(-112.0, 12.0, -9.0), 1.1, Vector3(0.55, 0.85, 0.55))
	_place("coral_mass_d", root, Vector3(-114.0, 9.0, -11.0), 0.7, Vector3(1.5, 1.25, 1.5))
	_place("coral_mass_e", root, Vector3(-96.0, 9.0, -12.0), 1.6, Vector3(1.2, 1.55, 1.2))
	_place("coral_mass_a", root, Vector3(-110.0, 10.0, -10.0), 0.2, Vector3(1.0, 1.1, 1.0))
	_place("coral_mass_c", root, Vector3(-99.0, 10.0, -11.0), 1.0, Vector3(0.8, 1.05, 0.8))
	_place("coral_mass_e", root, Vector3(-104.0, 10.0, -10.0), 0.6, Vector3(0.95, 1.55, 0.95))
	# Rock bosses under the slab hide its clean rectangular underside.
	_place("coral_mass_b", root, Vector3(-106.0, 15.2, -10.0), 0.4, Vector3(1.35, 0.42, 1.35))
	_place("coral_mass_d", root, Vector3(-103.0, 15.2, -6.0), 1.1, Vector3(1.1, 0.40, 1.1))
	_place("ground_patch_a", root, Vector3(-105.0, 18.03, -10.0), 0.2, Vector3(0.72, 0.035, 0.62))
	# Corner outcrops and causeway supports break the floating-slab silhouette.
	_place("coral_mass_e", root, Vector3(-111.0, 16.5, -4.5), 0.3, Vector3(0.85, 0.55, 0.85))
	_place("coral_mass_c", root, Vector3(-97.0, 16.5, -4.5), 1.4, Vector3(0.7, 0.5, 0.7))
	_place("coral_mass_b", root, Vector3(-111.0, 15.5, -16.0), 0.8, Vector3(0.85, 0.55, 0.85))
	for i in 3:
		_place("coral_mass_d", root, Vector3(-108.0, 8.0 + float(i) * 2.5, 8.8), float(i) * 0.7, Vector3(0.55, 0.9, 0.55))
	# Tall natural pillars flank the camp access bridge (deck top +17.75);
	# they sit outside the 6 m walkway so the route stays visually clear.
	_place("coral_mass_a", root, Vector3(-112.0, 2.0, 0.5), 0.2, Vector3(0.8, 1.58, 0.5))
	_place("coral_mass_a", root, Vector3(-112.0, 2.0, 9.5), 1.2, Vector3(0.8, 1.58, 0.5))
	_place("coral_mass_b", root, Vector3(-100.0, 3.0, 0.5), 2.0, Vector3(0.7, 1.42, 0.5))
	_place("coral_mass_b", root, Vector3(-100.0, 3.0, 9.5), 0.7, Vector3(0.7, 1.42, 0.5))
	# A rock arch under the camp span reads better than a thin floating slab.
	_place("coral_arch_b", root, Vector3(-111.0, 8.0, 5.0), PI * 0.5, Vector3(1.0, 1.30, 1.0))
	_place("coral_arch_c", root, Vector3(-99.0, 8.0, 5.0), -PI * 0.5, Vector3(0.95, 1.30, 0.95))
	var ramp_supports: Array = [
		[Vector3(-90.0, -3.0, 20.0), 0.65],
		[Vector3(-95.0, 0.0, 20.0), 0.80],
		[Vector3(-100.0, 4.0, 20.0), 0.95],
	]
	for spec: Array in ramp_supports:
		_place("coral_mass_a", root, spec[0], 0.3, Vector3(0.6, float(spec[1]), 0.6))
	# Low coral banks frame the rectangular camp slab.
	for i in 4:
		var z := -14.0 + float(i) * 3.0
		_place(BANKS[i % 2], root, Vector3(-114.0, 18.0, z), PI * 0.5, Vector3(0.55, 0.55, 0.55))
		_place(BANKS[(i + 1) % 2], root, Vector3(-96.0, 18.0, z), PI * 0.5, Vector3(0.55, 0.55, 0.55))


func _camp_meat_rack(parent: Node3D, base: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "CampMeatRack"
	root.position = base
	root.rotation.y = yaw
	parent.add_child(root)
	var wood: Material = _camp_mats.get("wood", null)
	var leather: Material = _camp_mats.get("leather", null)
	var meat: Material = _camp_mats.get("meat", null)
	var bone: Material = _camp_mats.get("bone", null)
	_camp_box(root, &"PostWest", Vector3(-2.45, 1.25, 0.0), Vector3(0.16, 2.5, 0.16), wood, 0.02)
	_camp_box(root, &"PostEast", Vector3(2.45, 1.25, 0.0), Vector3(0.16, 2.5, 0.16), wood, -0.03)
	_camp_box(root, &"Crossbar", Vector3(0.0, 2.42, 0.0), Vector3(5.15, 0.15, 0.16), wood)
	_camp_box(root, &"FootWest", Vector3(-2.45, 0.07, 0.0), Vector3(0.9, 0.14, 0.7), wood, 0.15)
	_camp_box(root, &"FootEast", Vector3(2.45, 0.07, 0.0), Vector3(0.9, 0.14, 0.7), wood, -0.1)
	for i in 3:
		var x := -1.45 + 1.45 * float(i)
		_camp_box(root, StringName("Strap%d" % i), Vector3(x, 1.85, 0.0), Vector3(0.045, 0.95, 0.05), leather, float(i - 1) * 0.04)
		var cut := MeshInstance3D.new()
		cut.name = StringName("HangingCut%d" % i)
		var sphere := SphereMesh.new()
		sphere.radius = 0.26
		sphere.height = 0.82
		sphere.radial_segments = 10
		sphere.rings = 6
		cut.mesh = sphere
		cut.material_override = meat
		cut.position = Vector3(x, 1.12 + 0.06 * float(i), 0.0)
		cut.scale = Vector3(0.72, 1.15, 0.58)
		cut.rotation.z = 0.08 * float(i - 1)
		root.add_child(cut)
	_camp_box(root, &"BoneHook", Vector3(1.95, 2.26, 0.0), Vector3(0.07, 0.32, 0.07), bone, 0.1)


func _camp_rope_coil(parent: Node3D, base: Vector3, yaw: float) -> void:
	var rope: Material = _camp_mats.get("rope", null)
	if rope == null:
		return
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.name = StringName("RopeCoil%d" % i)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.34 - 0.055 * float(i)
		torus.outer_radius = 0.48 - 0.055 * float(i)
		torus.rings = 28
		torus.ring_segments = 6
		mi.mesh = torus
		mi.material_override = rope
		mi.position = base + Vector3(0.04 * float(i), 0.035 + 0.045 * float(i), -0.03 * float(i))
		mi.rotation.y = yaw + 0.3 * float(i)
		mi.scale = Vector3(1.0, 0.55, 0.9)
		parent.add_child(mi)


func _camp_box(
	parent: Node3D,
	node_name: StringName,
	position: Vector3,
	size: Vector3,
	material: Material,
	yaw := 0.0
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = position
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


func _dress_zones() -> void:
	_dress_z01()
	_dress_z03()
	_dress_z04()
	_dress_z05()
	_dress_z06()
	_dress_z07()
	_dress_z08()
	_dress_z09()
	_dress_z10()
	_dress_z11()
	_dress_z12()
	_dress_z13()
	_dress_z14()
	_dress_z15()
	_dress_z16()
	_dress_z17()
	_dress_z18()


func _dress_z01() -> void:
	var r := _zone_node("Z01_Threshold")
	_place("coral_arch_a", r, Vector3(12.5, 0.0, 0.0), 0.0, Vector3(1.05, 0.95, 1.0))
	_place(BLADES[2], r, Vector3(20.0, 0.0, -9.5), 0.3, Vector3(0.9, 0.85, 0.9))
	_place(BLADES[0], r, Vector3(24.0, 0.0, 9.5), 2.4, Vector3(0.75, 0.7, 0.75))
	_place(PILES[0], r, Vector3(27.0, 0.0, -7.5), 0.5, Vector3(1.0, 1.0, 1.0))
	_place(SHELLS[2], r, Vector3(31.0, 0.0, 5.0), 1.4, Vector3(2.0, 1.0, 2.0))
	_place("ground_patch_b", r, Vector3(24.0, 0.02, 0.0), 0.3, Vector3(0.9, 0.035, 0.9))
	_place(POOLS[2], r, Vector3(18.0, 0.01, -4.0), 0.4, Vector3(0.7, 0.1, 0.7))


func _dress_z03() -> void:
	var r := _zone_node("Z03_FirstFork")
	_place(ARCHES[1], r, Vector3(-12.0, 0.0, 7.5), PI * 0.5, Vector3(1.0, 0.9, 1.0))
	_place(ARCHES[2], r, Vector3(-12.0, 0.0, -8.5), PI * 0.5, Vector3(1.0, 0.9, 1.0))
	var visual := _generated_visual()
	if visual != null:
		for zone in visual.get_children():
			if String(zone.name) != "Z03_FirstFork":
				continue
			for node in zone.get_children():
				if node is MeshInstance3D and String(node.name).begins_with("Z03_Stump"):
					_hide(node as MeshInstance3D)
	# Keep the 3 m POI radius around (0,0) clear: first fight, Azure Blade
	# and the wounded scavenger marker all sit there.
	_place(PILES[2], r, Vector3(-5.0, 0.0, 4.0), 2.1, Vector3(1.05, 1.0, 1.05))
	_place(RIBS[2], r, Vector3(-4.2, 0.7, 4.0), 0.45, Vector3(0.75, 0.7, 0.75))
	_place(PILES[0], r, Vector3(-3.0, 0.0, 5.0), 2.1, Vector3(0.85, 0.9, 0.85))
	_place(BLADES[3], r, Vector3(5.0, 0.0, -4.0), 0.7, Vector3(0.35, 0.5, 0.35))
	_place(PILES[2], r, Vector3(4.0, 0.0, 4.0), 2.1, Vector3(1.0, 0.9, 1.0))
	_place(SHELLS[1], r, Vector3(-3.0, 0.0, 6.0), 0.2, Vector3(1.8, 1.0, 1.8))
	_place(BLADES[1], r, Vector3(8.0, 0.0, -10.0), 1.4, Vector3(0.7, 0.65, 0.7))
	_place(POOLS[0], r, Vector3(-6.0, 0.01, -2.0), 0.0, Vector3(0.8, 0.12, 0.8))


func _dress_z04() -> void:
	var r := _zone_node("Z04_MudHollow")
	_place(BANKS[0], r, Vector3(-20.0, -3.0, -40.0), 0.3, Vector3(1.0, 1.0, 1.0))
	_place(BANKS[1], r, Vector3(-40.0, -3.0, -36.0), 2.2, Vector3(1.1, 0.9, 1.0))
	_place(POOLS[1], r, Vector3(-30.0, -2.98, -44.0), 0.0, Vector3(1.1, 0.12, 0.9))
	_place(POOLS[2], r, Vector3(-38.0, -2.98, -34.0), 1.2, Vector3(0.8, 0.12, 1.0))
	for i in 4:
		_place(RIBS[i % RIBS.size()], r, Vector3(-22.0 - float(i) * 4.5, -2.7, -38.0 + float(i % 2) * 3.0), 0.8 + float(i) * 0.4, Vector3(1.2, 0.9, 1.2))
	_place(BLADES[3], r, Vector3(-44.0, -3.0, -52.0), 0.4, Vector3(1.1, 0.9, 1.1))
	_place(BLADES[0], r, Vector3(-17.0, -3.0, -53.0), 2.0, Vector3(0.9, 0.8, 0.9))


func _dress_z05() -> void:
	var r := _zone_node("Z05_BonePassage")
	_place(RIBS[2], r, Vector3(-22.0, 0.0, 17.5), PI * 0.5, Vector3(1.5, 1.5, 1.5))
	_place(RIBS[2], r, Vector3(-42.0, 0.0, 24.5), PI * 0.5, Vector3(1.6, 1.6, 1.6))
	_place(PILES[1], r, Vector3(-34.0, 0.0, 26.0), 0.6, Vector3(1.1, 1.0, 1.1))
	_place(PILES[2], r, Vector3(-25.0, 0.0, 34.0), 1.8, Vector3(0.9, 0.9, 0.9))
	_place(SHELLS[0], r, Vector3(-40.0, 0.0, 32.0), 1.0, Vector3(2.2, 1.1, 2.2))
	_place(BLADES[1], r, Vector3(-44.0, 0.0, 37.0), 2.4, Vector3(0.8, 0.8, 0.8))
	_place(POOLS[0], r, Vector3(-30.0, 0.01, 30.0), 0.3, Vector3(0.7, 0.1, 0.7))


func _dress_z06() -> void:
	var r := _zone_node("Z06_DryPocket")
	_place(PILES[0], r, Vector3(-45.0, 6.0, 47.0), 0.4, Vector3(1.3, 1.2, 1.3))
	_place(BLADES[2], r, Vector3(-53.0, 6.0, 50.0), 1.1, Vector3(0.9, 0.9, 0.9))
	_place(BLADES[1], r, Vector3(-41.0, 6.0, 43.0), 2.6, Vector3(0.7, 0.7, 0.7))
	_place(SHELLS[2], r, Vector3(-48.0, 6.0, 43.0), 1.7, Vector3(1.6, 1.0, 1.6))


func _dress_z07() -> void:
	var r := _zone_node("Z07_ScoutRidge")
	for i in 4:
		_place(LEDGES[(i + 1) % LEDGES.size()], r, Vector3(-50.0 + float(i) * 16.0, 7.0, -49.0), 0.0, Vector3(0.75, 0.55, 0.75))
	for i in 3:
		_place(BLADES[(i + 1) % BLADES.size()], r, Vector3(-48.0 + float(i) * 18.0, 7.0, -59.0), 0.5 + float(i) * 0.8, Vector3(0.8, 0.85, 0.8))
	_place(PILES[1], r, Vector3(-25.0, 7.0, -52.0), 1.0, Vector3(1.0, 1.0, 1.0))


func _dress_z08() -> void:
	var r := _zone_node("Z08_Clearing")
	_place(ARCHES[0], r, Vector3(-55.0, 0.0, 19.5), PI * 0.5, Vector3(1.0, 0.92, 1.0))
	_place(BLADES[2], r, Vector3(-60.0, 0.0, -10.0), 0.2, Vector3(1.1, 1.0, 1.1))
	_place(BLADES[3], r, Vector3(-72.0, 0.0, 9.0), 1.7, Vector3(0.95, 0.9, 0.95))
	_place(BLADES[0], r, Vector3(-77.0, 0.0, -7.0), 2.8, Vector3(0.85, 0.8, 0.85))
	_place(PILES[0], r, Vector3(-65.0, 0.35, 0.0), 0.3, Vector3(1.15, 1.0, 1.15))
	_place(BANKS[1], r, Vector3(-58.0, 0.0, -12.0), 1.1, Vector3(1.0, 1.0, 1.0))
	_place(POOLS[1], r, Vector3(-70.0, 0.01, -5.0), 0.5, Vector3(1.0, 0.12, 1.0))


func _dress_z09() -> void:
	var r := _zone_node("Z09_BlindTunnel")
	for i in 4:
		_place("coral_tunnel_shell_" + String("abc"[i % 3]), r, Vector3(-58.0 - float(i) * 8.0, 0.0, 20.0), 0.0, Vector3(0.95, 0.55, 0.85))
	_place(PILES[1], r, Vector3(-76.0, 0.0, 20.0), 0.8, Vector3(0.9, 0.9, 0.9))
	_place(SHELLS[1], r, Vector3(-66.0, 0.0, 21.0), 1.3, Vector3(1.5, 1.0, 1.5))
	_place(POOLS[0], r, Vector3(-72.0, 0.01, 19.0), 0.4, Vector3(0.6, 0.1, 0.6))


func _dress_z10() -> void:
	var r := _zone_node("Z10_CoralHill")
	# The greybox hill core is only 10 m tall while the camp platform sits at
	# +18. Fill the visual gap under the platform without changing collision.
	_place("coral_mass_a", r, Vector3(-105.0, 9.0, -16.0), 0.2, Vector3(2.4, 1.15, 2.4))
	_place("coral_mass_d", r, Vector3(-111.0, 10.0, -24.0), 1.2, Vector3(2.0, 1.1, 2.0))
	_place(BLADES[2], r, Vector3(-92.0, 1.0, -25.0), 0.3, Vector3(0.9, 0.9, 0.9))
	_place(BLADES[1], r, Vector3(-118.0, 1.0, -24.0), 2.2, Vector3(0.8, 0.8, 0.8))
	_place(PILES[2], r, Vector3(-112.0, 1.0, 6.0), 1.4, Vector3(1.1, 1.0, 1.1))
	_place("ground_patch_large_a", r, Vector3(-105.0, 1.03, -5.0), 0.0, Vector3(0.75, 0.035, 0.75))
	_place(POOLS[2], r, Vector3(-96.0, 1.02, 8.0), 0.6, Vector3(0.8, 0.12, 0.8))


func _dress_z11() -> void:
	var r := _zone_node("Z11_TideChannel")
	for i in 4:
		_place(BLADES[(i + 1) % BLADES.size()], r, Vector3(-128.0 - float(i) * 5.0, -6.0, -26.0 + float(i % 2) * 2.0), 0.5 + float(i) * 0.7, Vector3(0.8, 0.9, 0.8))
	_place(BANKS[0], r, Vector3(-132.0, -6.0, -26.0), 0.1, Vector3(1.0, 1.0, 1.0))
	_place(BANKS[1], r, Vector3(-144.0, -6.0, 26.0), 3.0, Vector3(1.1, 0.9, 1.0))
	_place(POOLS[1], r, Vector3(-140.0, -5.98, 12.0), 0.7, Vector3(1.4, 0.12, 1.2))
	_place(PILES[1], r, Vector3(-148.0, -6.0, -12.0), 0.5, Vector3(1.0, 1.0, 1.0))


func _dress_z12() -> void:
	var r := _zone_node("Z12_Isthmus")
	_place(ARCHES[1], r, Vector3(-175.0, 0.0, -12.0), PI * 0.5, Vector3(0.95, 0.9, 0.9))
	_place(ARCHES[2], r, Vector3(-175.0, 0.0, 12.0), PI * 0.5, Vector3(0.95, 0.9, 0.9))
	_place(PILES[0], r, Vector3(-160.0, 0.0, 5.0), 1.2, Vector3(1.0, 1.0, 1.0))
	_place(PILES[2], r, Vector3(-193.0, 0.0, -7.0), 0.3, Vector3(1.0, 1.0, 1.0))
	_place(BLADES[2], r, Vector3(-188.0, 0.0, 17.0), 2.0, Vector3(0.8, 0.8, 0.8))


func _dress_z13() -> void:
	var r := _zone_node("Z13_HuntingGrounds")
	# Half-buried giant skeleton: spine and rib cage off the main lane.
	# The spine sits above the half-buried rib cage so the skeleton reads as
	# one creature from the main lane, not a row of white hoops.
	for i in 13:
		_place(VERTEBRAE[i % VERTEBRAE.size()], r, Vector3(-296.0 - float(i) * 11.0, 3.0, -26.0), float(i) * 0.12, Vector3(3.4, 2.8, 3.4))
	for i in 8:
		_place(RIBS[i % RIBS.size()], r, Vector3(-308.0 - float(i) * 15.0, -0.7, -26.0), 1.57 + _rng.randf_range(-0.2, 0.2), Vector3(3.2, 3.6, 3.2))
	for i in 7:
		var x := -225.0 - float(i) * 35.0
		var z := 8.0 if i % 2 == 0 else -9.0
		_place(RIBS[(i + 1) % RIBS.size()], r, Vector3(x, 0.0, z), float(i) * 0.9, Vector3(0.75, 0.65, 0.75))
		_place(SHELLS[i % SHELLS.size()], r, Vector3(x + 8.0, 0.0, z * 1.2), float(i) * 0.7, Vector3(1.8, 1.0, 1.8))
	_place("coral_mass_b", r, Vector3(-300.0, -0.8, -30.0), 0.5, Vector3(2.5, 0.9, 1.8))
	_place("coral_mass_d", r, Vector3(-440.0, -0.5, -28.0), 1.1, Vector3(1.8, 1.0, 1.4))
	# The skull is implied by a broken bone pile at the head of the spine;
	# a smooth boulder with bone tint read as a potato, not a skull.
	var skull := _place("bone_skull", r, Vector3(-280.0, 5.0, -26.0), PI * 0.5, Vector3(4.0, 4.0, 4.0))
	_apply_skull_materials(skull)
	_place(PILES[0], r, Vector3(-276.0, -0.5, -19.0), 1.2, Vector3(2.2, 1.4, 2.2))
	_place(BANKS[0], r, Vector3(-350.0, 0.0, -26.0), 0.1, Vector3(4.0, 0.7, 0.8))
	# Ground variation on the central flat.
	for i in 4:
		_place("ground_patch_large_a", r, Vector3(-250.0 - float(i) * 80.0, 0.02, 10.0 if i % 2 == 0 else -10.0), float(i) * 0.7, Vector3(1.4, 0.035, 1.1))
	# Rugged shoulders between the low parapets and the high routes.
	for i in 8:
		_place(MASSES[i % MASSES.size()], r, Vector3(-245.0 - float(i) * 40.0, 0.0, -36.0 if i % 2 == 0 else 36.0), float(i) * 0.8, Vector3(0.9, 0.8, 0.9))
	_place(PILES[0], r, Vector3(-420.0, 0.0, -18.0), 0.6, Vector3(1.8, 1.2, 1.8))
	_place(PILES[1], r, Vector3(-250.0, 0.0, 22.0), 2.0, Vector3(1.4, 1.1, 1.4))
	# Lower masses sit near the lane edges (z ±24), leaving a ~40 m central
	# corridor; the existing coral_mass collisions still own the route.
	for i in 8:
		var x := -248.0 - float(i) * 36.0
		var z := -24.0 if i % 2 == 0 else 24.0
		_place(MASSES[(i + 1) % MASSES.size()], r, Vector3(x, 0.0, z), float(i) * 0.7, Vector3(0.68, 0.82, 0.68))
	for i in 6:
		var t := float(i) / 5.0
		var x := -250.0 - t * 270.0
		_place("ground_patch_large_a", r, Vector3(x, 0.02, 0.0), float(i) * 0.8, Vector3(1.0, 0.035, 1.0))
	for i in 8:
		var x := -235.0 - float(i) * 34.0
		var z := 10.0 if i % 2 == 0 else -10.0
		_place(PILES[i % PILES.size()], r, Vector3(x, 0.0, z), float(i) * 1.1, Vector3(0.75, 0.7, 0.75))
		_place(SHELLS[(i + 1) % SHELLS.size()], r, Vector3(x + 7.0, 0.0, z * 1.2), float(i) * 0.5, Vector3(1.3, 0.9, 1.3))
	# Dark puddles and low banks break the large flat lane without adding
	# walk-through masses in the centre.
	for i in 6:
		_place(POOLS[i % POOLS.size()], r, Vector3(-255.0 - float(i) * 45.0, 0.02, 8.0 if i % 2 == 0 else -8.0), float(i) * 0.9, Vector3(1.0, 0.10, 0.85))
	for i in 4:
		_place(BANKS[i % BANKS.size()], r, Vector3(-255.0 - float(i) * 65.0, 0.0, 27.0 if i % 2 == 0 else -27.0), float(i) * 0.7, Vector3(1.3, 0.9, 1.0))
	for i in 4:
		_place(PILES[(i + 1) % PILES.size()], r, Vector3(-258.0 - float(i) * 14.0, 0.0, 5.0 if i % 2 == 0 else -6.0), float(i) * 1.3, Vector3(0.85, 0.75, 0.85))
	for i in 7:
		var x := -245.0 - float(i) * 45.0
		var z := -20.0 if i % 2 == 0 else 20.0
		_place(BLADES[i % BLADES.size()], r, Vector3(x, 0.0, z), float(i) * 0.9, Vector3(1.05, 1.2, 1.05))
	for i in 4:
		_place(BANKS[i % 2], r, Vector3(-330.0 + float(i) * 80.0, 0.0, 30.0), float(i) * 1.2, Vector3(1.2, 1.0, 1.2))
	_place(POOLS[2], r, Vector3(-380.0, 0.01, -10.0), 0.3, Vector3(1.7, 0.1, 1.4))
	_place(POOLS[0], r, Vector3(-300.0, 0.01, 10.0), 1.1, Vector3(1.2, 0.1, 1.0))
	_place(SHELLS[2], r, Vector3(-360.0, 0.0, 18.0), 0.6, Vector3(2.2, 1.2, 2.2))


func _dress_z14() -> void:
	var r := _zone_node("Z14_BoneBridge")
	var vertebrae: Dictionary = {}
	var ribs: Dictionary = {}
	# Hide the placeholder vertebra plates and rib cylinders; keep the
	# walkable floor at y=6 untouched.
	var visual := _generated_visual()
	if visual != null:
		for zone in visual.get_children():
			if String(zone.name) != "Z14_BoneBridge":
				continue
			for node in zone.get_children():
				if node is MeshInstance3D and (String(node.name).begins_with("Z14_Vertebra") or String(node.name).begins_with("Z14_Rib")):
					_hide(node as MeshInstance3D)
	for i in 9:
		_append_group(vertebrae, VERTEBRAE[i % VERTEBRAE.size()], _kit_transform(Vector3(-644.0 + float(i) * 11.0, 6.0, -2.3), 0.0, Vector3(1.3, 1.35, 1.3)))
		_append_group(vertebrae, VERTEBRAE[(i + 1) % VERTEBRAE.size()], _kit_transform(Vector3(-644.0 + float(i) * 11.0, 6.0, 2.3), 0.0, Vector3(1.3, 1.35, 1.3)))
	for i in 8:
		var x := -640.0 + float(i) * 12.0
		# Ribs lie along the deck edge as low bone rails; earlier versions were
		# scaled into giant hoops over the walkway.
		_append_group(ribs, RIBS[i % RIBS.size()], _kit_transform(Vector3(x, 6.05, -3.1), 0.0, Vector3(1.15, 0.72, 0.9)))
		_append_group(ribs, RIBS[(i + 1) % RIBS.size()], _kit_transform(Vector3(x, 6.05, 3.1), PI, Vector3(1.15, 0.72, 0.9)))
	var bone: Material = _kit_mats.get("nm_bone_aged", null)
	for asset in vertebrae.keys():
		_multi_place(String(asset), r, vertebrae[asset], bone, "Z14_Vertebrae_" + String(asset))
	for asset in ribs.keys():
		_multi_place(String(asset), r, ribs[asset], bone, "Z14_Ribs_" + String(asset))
	# Two hero arches frame the ends of the bridge.
	_place(RIBS[2], r, Vector3(-646.0, 6.0, 0.0), 1.57, Vector3(1.8, 1.55, 1.5))
	_place(RIBS[2], r, Vector3(-554.0, 6.0, 0.0), -1.57, Vector3(1.8, 1.55, 1.5))
	for i in 4:
		_place(MASSES[i], r, Vector3(-620.0 + float(i) * 30.0, -2.0, -10.0), float(i) * 0.7, Vector3(0.7, 0.9, 0.7))
	# Visual supports under the deck; they do not change the walkable surface.
	_place("coral_mass_a", r, Vector3(-590.0, -6.0, 0.0), 0.2, Vector3(1.1, 1.0, 1.0))
	_place("coral_mass_d", r, Vector3(-625.0, -6.0, 0.0), 1.2, Vector3(0.95, 0.95, 0.9))


func _dress_z15() -> void:
	var r := _zone_node("Z15_HighRefuge")
	# Hide the greybox cantilever table and posts; the refuge becomes a natural
	# coral shelf with a rock overhang instead.
	var visual := _generated_visual()
	if visual != null:
		for zone in visual.get_children():
			if String(zone.name) != "Z15_HighRefuge":
				continue
			for node in zone.get_children():
				if node is MeshInstance3D and String(node.name).begins_with("Z15_Shelter"):
					_hide(node as MeshInstance3D)
	# Fill the visual gap between the 12 m mound and the +18 refuge ledge.
	_place("coral_mass_c", r, Vector3(-702.0, 11.0, -27.0), 0.4, Vector3(1.7, 0.95, 1.7))
	_place("coral_mass_a", r, Vector3(-704.0, 18.0, -35.0), 0.2, Vector3(0.9, 1.8, 0.9))
	_place("coral_arch_a", r, Vector3(-702.0, 18.0, -28.0), 0.0, Vector3(1.25, 1.2, 1.25))
	_place("coral_mass_e", r, Vector3(-689.0, 18.0, -31.0), 1.1, Vector3(0.65, 0.9, 0.65))
	_place(BLADES[1], r, Vector3(-690.0, 18.0, 2.0), 2.4, Vector3(0.8, 0.9, 0.8))
	_place(PILES[0], r, Vector3(-706.0, 18.02, -22.0), 0.5, Vector3(1.0, 1.0, 1.0))
	_place(POOLS[1], r, Vector3(-695.0, 2.01, -30.0), 0.4, Vector3(1.2, 0.1, 1.0))
	_place("campfire_a", r, Vector3(-699.0, 18.02, -17.0), 0.4, Vector3(0.8, 0.8, 0.8))
	_place("bedroll_b", r, Vector3(-705.0, 18.03, -15.0), 1.2, Vector3(1.3, 1.3, 1.3))
	_place("ground_patch_a", r, Vector3(-700.0, 18.03, -20.0), 0.3, Vector3(0.72, 0.035, 0.72))
	_place("coral_arch_b", r, Vector3(-690.0, 8.0, -20.0), PI * 0.5, Vector3(0.8, 1.0, 0.8))
	for i in 4:
		var z := -28.0 + float(i) * 5.0
		_place(BANKS[i % 2], r, Vector3(-711.0, 18.0, z), PI * 0.5, Vector3(0.55, 0.55, 0.55))
		_place(BANKS[(i + 1) % 2], r, Vector3(-689.0, 18.0, z), PI * 0.5, Vector3(0.55, 0.55, 0.55))
	_place("coral_mass_e", r, Vector3(-714.0, 17.0, -10.0), 0.5, Vector3(0.5, 0.45, 0.5))
	_place("coral_mass_d", r, Vector3(-686.0, 17.0, -8.0), 1.2, Vector3(0.5, 0.45, 0.5))
	# A07-07a1: break the cantilever's clean silhouette at the corners with
	# coral masses instead of a regular ring of small ledges.
	for corner in [Vector3(-710.5, 18.0, -30.4), Vector3(-689.5, 18.0, -30.4), Vector3(-710.5, 18.0, -9.6), Vector3(-689.5, 18.0, -9.6)]:
		_place(MASSES[abs(hash(corner)) % MASSES.size()], r, corner, float(abs(hash(corner)) % 7) * 0.4, Vector3(0.95, 0.72, 0.95))
	_place("coral_mass_e", r, Vector3(-700.0, 19.6, -28.0), 0.4, Vector3(1.25, 0.48, 0.95))
	var fire := OmniLight3D.new()
	fire.name = "RefugeFire"
	fire.position = Vector3(-699.0, 19.2, -17.0)
	fire.light_color = Color(1.0, 0.62, 0.34, 1.0)
	fire.light_energy = 1.4
	fire.omni_range = 7.0
	fire.shadow_enabled = false
	r.add_child(fire)


func _dress_z16() -> void:
	var r := _zone_node("Z16_PackTerritory")
	for i in 5:
		_place(ARCHES[i % ARCHES.size()], r, Vector3(-800.0 - float(i) * 55.0, 0.0, -8.0), PI * 0.5, Vector3(0.9, 0.9, 0.9))
	for i in 8:
		var x := -770.0 - float(i) * 36.0
		var z := -22.0 if i % 2 == 0 else 22.0
		_place(BLADES[(i + 2) % BLADES.size()], r, Vector3(x, 0.0, z), float(i) * 0.8, Vector3(0.9, 1.0, 0.9))
	# Extra visual-only masses are kept out of the low walkable corridor; the
	# collision-bearing coral_mass replacements already provide the labyrinth.
	for i in 5:
		_place(PILES[i % PILES.size()], r, Vector3(-790.0 - float(i) * 60.0, 0.0, 8.0), float(i) * 1.3, Vector3(1.2, 1.0, 1.2))
	for i in 4:
		_place(BANKS[i % 2], r, Vector3(-820.0 - float(i) * 60.0, 0.0, -12.0), float(i) * 0.9, Vector3(1.1, 1.0, 1.1))
	_place(POOLS[2], r, Vector3(-900.0, 0.01, 12.0), 0.2, Vector3(1.6, 0.1, 1.4))
	_place(POOLS[1], r, Vector3(-1000.0, 0.01, -8.0), 1.4, Vector3(1.4, 0.1, 1.2))
	_place(SHELLS[1], r, Vector3(-960.0, 0.0, 20.0), 0.9, Vector3(2.0, 1.0, 2.0))


func _dress_z17() -> void:
	var r := _zone_node("Z17_StormRun")
	var dark: Material = _prim_mats.get("nm_dark_rock_prim", null)
	var visual := _generated_visual()
	if visual != null and dark != null:
		for zone in visual.get_children():
			if String(zone.name) != "Z17_StormRun":
				continue
			for node in zone.get_children():
				if node is MeshInstance3D and String(node.name).begins_with("Z17_High"):
					(node as MeshInstance3D).material_override = dark
	for i in 5:
		var node := _place("coral_mass_" + String("abcde"[i % 5]), r, Vector3(-1080.0 - float(i) * 45.0, -2.0, -16.0), float(i) * 0.5, Vector3(1.4, 1.3, 1.2))
		if dark != null:
			_override_material(node, dark)
	for i in 3:
		var node := _place("coral_wall_tall_" + String("abc"[i % 3]), r, Vector3(-1100.0 - float(i) * 70.0, -2.0, 24.0), 0.2, Vector3(1.1, 1.0, 1.0))
		if dark != null:
			_override_material(node, dark)
	for i in 4:
		_place(RIBS[i % RIBS.size()], r, Vector3(-1090.0 - float(i) * 50.0, -2.0, 12.0), float(i) * 0.9, Vector3(1.8, 1.6, 1.8))
	_place(PILES[2], r, Vector3(-1200.0, -2.0, -10.0), 0.3, Vector3(1.4, 1.1, 1.4))
	# Storm-worn causeway: flanking supports and debris, all below or beside
	# the walkable strip.
	for i in 6:
		var x := -1080.0 - float(i) * 38.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var sup := _place("coral_mass_c", r, Vector3(x, -8.0, side * 6.0), float(i) * 0.6, Vector3(1.6, 1.5, 1.6))
		if dark != null:
			_override_material(sup, dark)
		var debris := _place(MASSES[(i + 2) % MASSES.size()], r, Vector3(x + 12.0, 8.0, side * 8.0), float(i) * 0.8, Vector3(0.45, 0.55, 0.45))
		if dark != null:
			_override_material(debris, dark)
		var rail := _place(RIBS[(i + 1) % RIBS.size()], r, Vector3(x + 8.0, 8.05, side * 5.2), 0.0, Vector3(1.0, 0.8, 0.9))
		if dark != null:
			_override_material(rail, dark)


func _dress_z18() -> void:
	var r := _zone_node("Z18_Cliffs")
	var dark: Material = _prim_mats.get("nm_dark_rock_prim", null)
	for i in 6:
		var node := _place("coral_wall_tall_" + String("abc"[i % 3]), r, Vector3(-1400.0, 0.0, -80.0 + float(i) * 32.0), -PI * 0.5, Vector3(1.25, 1.1, 1.2))
		if dark != null:
			_override_material(node, dark)
	for i in 4:
		var node := _place("coral_blade_" + String("abcd"[i % 4]), r, Vector3(-1410.0, 2.0, -50.0 + float(i) * 34.0), float(i) * 0.9, Vector3(1.4, 1.6, 1.4))
		if dark != null:
			_override_material(node, dark)
	for i in 3:
		var node := _place("coral_mass_" + String("abcde"[i % 5]), r, Vector3(-1422.0, 35.0, -12.0 + float(i) * 12.0), float(i) * 0.6, Vector3(0.55, 0.85, 0.55))
		if dark != null:
			_override_material(node, dark)
	_place("ground_patch_a", r, Vector3(-1410.0, 35.04, 0.0), 0.2, Vector3(0.75, 0.035, 0.75))
	for i in 4:
		var z := -9.0 + float(i) * 6.0
		_place(BANKS[i % 2], r, Vector3(-1419.0, 35.0, z), PI * 0.5, Vector3(0.5, 0.55, 0.5))
		_place(BANKS[(i + 1) % 2], r, Vector3(-1401.0, 35.0, z), PI * 0.5, Vector3(0.5, 0.55, 0.5))
	_place(PILES[1], r, Vector3(-1360.0, 2.0, 10.0), 1.1, Vector3(1.6, 1.2, 1.6))
	# Support the final +35 summit so it reads as a coral mesa, not a table.
	var summit := _place("coral_mass_a", r, Vector3(-1410.0, 0.0, 0.0), 0.2, Vector3(2.0, 3.5, 2.0))
	if dark != null:
		_override_material(summit, dark)
	_place("coral_mass_c", r, Vector3(-1410.0, 34.0, 0.0), 0.7, Vector3(0.9, 0.8, 0.9))
	# A07-07a2: corner masses and sea stacks keep the final summit from
	# reading as a table without a regular ledge ring.
	for corner in [Vector3(-1420.5, 35.0, -10.5), Vector3(-1399.5, 35.0, -10.5), Vector3(-1420.5, 35.0, 10.5), Vector3(-1399.5, 35.0, 10.5)]:
		_place(MASSES[abs(hash(corner)) % MASSES.size()], r, corner, float(abs(hash(corner)) % 7) * 0.4, Vector3(0.9, 0.7, 0.9))
	for i in 3:
		var stack := _place("coral_spire_west", r, Vector3(-1436.0, 18.0, -18.0 + float(i) * 18.0), float(i) * 0.6, Vector3(1.2, 1.8, 1.2))
		if dark != null:
			_override_material(stack, dark)


# ---------------------------------------------------------------------------
# Asset and scene helpers
# ---------------------------------------------------------------------------

func _zone_node(zone: String) -> Node3D:
	if _zone_roots.has(zone):
		return _zone_roots[zone] as Node3D
	var zones := get_node_or_null(^"Zones") as Node3D
	if zones == null:
		zones = Node3D.new()
		zones.name = "Zones"
		add_child(zones)
	var node := Node3D.new()
	node.name = zone
	zones.add_child(node)
	_zone_roots[zone] = node
	return node


func _landmark(landmark_name: StringName) -> Node3D:
	return _location.get_node_or_null(NodePath("Landmarks/%s" % landmark_name)) as Node3D


func _hide_landmark_children(anchor: Node3D) -> void:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
		elif child is CollisionObject3D:
			# Keep landmark collision; only the primitive visual is replaced.
			pass


func _hide(mi: MeshInstance3D) -> void:
	mi.visible = false
	mi.set_meta(&"art_hidden", true)


func _generated_visual() -> Node3D:
	return _location.get_node_or_null(^"Generated/Visual") as Node3D


func _place(asset: String, parent: Node3D, base: Vector3, yaw := 0.0, scale := Vector3.ONE) -> Node3D:
	var src := _asset(asset)
	if src == null:
		return null
	var node := src.instantiate() as Node3D
	parent.add_child(node)
	node.position = base
	node.rotation.y = yaw
	node.scale = scale
	_apply_kit_materials(node)
	return node


func _stretch(asset: String, parent: Node3D, center: Vector3, target_size: Vector3, yaw := 0.0) -> Node3D:
	var src := _asset(asset)
	if src == null:
		return null
	var node := src.instantiate() as Node3D
	parent.add_child(node)
	var bounds := _local_aabb(node)
	if bounds.size.x < 0.001 or bounds.size.y < 0.001 or bounds.size.z < 0.001:
		node.queue_free()
		return null
	var s := Vector3(target_size.x / bounds.size.x, target_size.y / bounds.size.y, target_size.z / bounds.size.z)
	node.scale = s
	node.rotation.y = yaw
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
	node.position = center - basis * (bounds.get_center() * s)
	_apply_kit_materials(node)
	return node


func _asset(name: String) -> PackedScene:
	if _assets.has(name):
		return _assets[name] as PackedScene
	var path := KIT + name + ".glb"
	var src: PackedScene = null
	if ResourceLoader.exists(path):
		src = load(path) as PackedScene
	if src == null:
		# Camp supplies live in the caravan kit; keeping the fallback here lets
		# the labyrinth art layer reuse authored props without duplicating GLBs.
		path = CAMP_KIT + name + ".glb"
		if ResourceLoader.exists(path):
			src = load(path) as PackedScene
	if src == null:
		push_warning("LabyrinthArt: missing kit asset " + path)
		_assets[name] = null
		return null
	_assets[name] = src
	return src


func _local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node3D = entry[0]
		var xform: Transform3D = entry[1] * node.transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var box := xform * (node as MeshInstance3D).mesh.get_aabb()
			if first:
				out = box
				first = false
			else:
				out = out.merge(box)
		for child in node.get_children():
			if child is Node3D:
				stack.append([child, xform])
	return out


func _all_mesh_instances(root: Node) -> Array:
	var result: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			result.append(node)
		for child in node.get_children():
			stack.append(child)
	return result
