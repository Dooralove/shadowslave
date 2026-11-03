extends SceneTree
## Builds the A07 post-nightmare overlay kit: PBR material variants,
## environment profiles, art scenes and preview wrappers.
##
## Run:
##   godot --headless --path <project> --script tools/art/build_environment_art.gd
##
## The script is deterministic and only writes A07-owned paths.

const PROFILE_SCRIPT := preload("res://scenes/environment/common/environment_art_profile.gd")
const SWAP_SCRIPT := preload("res://scenes/environment/common/environment_material_swap.gd")
const OVERLAY_SCRIPT := preload("res://scenes/environment/common/environment_art_overlay.gd")
const PREVIEW_SCRIPT := preload("res://scenes/environment/common/environment_art_preview.gd")

const MAT := "res://resources/locations/post_nightmare/materials/"
const NM := "res://assets/environments/nightmare/materials/"
const NM_ASSET := "res://assets/environments/nightmare/"
const ART_ENV := "res://assets/environments/post_nightmare/environments/"
const PROFILE_DIR := "res://assets/environments/post_nightmare/profiles/"
const ART_SCENE := "res://scenes/environment/post_nightmare/"
const PREVIEW := "res://scenes/environment/post_nightmare/preview/"
const CLEAN_PROP := "res://assets/environments/post_nightmare/props/"
const CLEAN_PROP_ABS := "assets/environments/post_nightmare/props/"
var _clean_props: Dictionary = {}


func _init() -> void:
	_make_dirs()
	_build_materials()
	_build_environments()
	_build_profiles()
	_build_art_scenes()
	_build_previews()
	print("A07 art kit built.")
	quit(0)


func _make_dirs() -> void:
	for path in [ART_ENV, PROFILE_DIR, ART_SCENE, PREVIEW, CLEAN_PROP]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _save(resource: Resource, path: String) -> void:
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		push_error("A07: failed to save %s (%s)" % [path, err])


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

func _build_materials() -> void:
	# Police: cold institutional stone, wet tile, painted board, dark metal.
	_shader_variant(NM + "nm_stone_worked.tres", "art_police_concrete",
		Color(0.58, 0.62, 0.66, 1.0), 1.8, 0.0, 1.0, 0.02, 0.0)
	_shader_variant(NM + "nm_rock.tres", "art_police_concrete_dark",
		Color(0.30, 0.33, 0.37, 1.0), 1.8, 0.0, 1.0, 0.06, 0.0)
	_shader_variant(NM + "nm_stone_worked.tres", "art_police_tile",
		Color(0.42, 0.47, 0.50, 1.0), 0.9, 0.0, 0.82, 0.04, 0.08)
	_shader_variant(NM + "nm_rock.tres", "art_police_asphalt",
		Color(0.18, 0.20, 0.23, 1.0), 2.4, 0.0, 1.0, 0.0, 0.02)
	_shader_variant(NM + "nm_stone_worked.tres", "art_police_paint",
		Color(0.72, 0.75, 0.78, 1.0), 2.0, 0.0, 0.92, 0.0, 0.0)
	_orm_variant(NM + "nm_iron.tres", "art_police_metal",
		Color(0.52, 0.57, 0.63, 1.0), 1.2, 0.55)
	_orm_variant(NM + "nm_linen.tres", "art_police_fabric",
		Color(0.34, 0.39, 0.45, 1.0), 1.4, 0.0)
	_orm_variant(NM + "nm_wood_dark.tres", "art_wood_dark",
		Color(0.58, 0.53, 0.47, 1.0), 1.8, 0.0)
	_orm_variant(NM + "nm_wood.tres", "art_wood_light",
		Color(0.72, 0.67, 0.60, 1.0), 1.8, 0.0)

	# Academy: wet asphalt, snow-dusted stone, red gate, warm windows.
	_shader_variant(NM + "nm_rock.tres", "art_academy_asphalt",
		Color(0.20, 0.23, 0.27, 1.0), 2.2, 0.18, 0.95, 0.0, 0.03)
	_shader_variant(NM + "nm_stone_worked.tres", "art_academy_concrete",
		Color(0.48, 0.52, 0.57, 1.0), 1.8, 0.34, 1.0, 0.0, 0.0)
	_shader_variant(NM + "nm_stone_worked.tres", "art_academy_wall",
		Color(0.44, 0.47, 0.52, 1.0), 2.0, 0.16, 1.0, 0.02, 0.0)
	_shader_variant(NM + "nm_stone_worked.tres", "art_academy_white",
		Color(0.69, 0.72, 0.75, 1.0), 1.6, 0.22, 0.95, 0.0, 0.0)
	_shader_variant(NM + "nm_stone_worked.tres", "art_academy_red",
		Color(0.46, 0.10, 0.12, 1.0), 1.2, 0.10, 1.0, 0.0, 0.0)
	_orm_variant(NM + "nm_iron.tres", "art_academy_metal",
		Color(0.48, 0.52, 0.58, 1.0), 1.1, 0.65)
	_shader_variant(NM + "nm_snow.tres", "art_academy_snow",
		Color(0.82, 0.86, 0.90, 1.0), 3.0, 0.0, 1.0, 0.0, 0.0)
	_standard_material("art_academy_glass", Color(0.055, 0.075, 0.095, 1.0), 0.16, 0.12, 0.35)
	_standard_emissive("art_academy_screen", Color(0.035, 0.070, 0.085, 1.0), Color(0.10, 0.34, 0.44, 1.0), 0.55)
	var mirror := _standard_material("art_police_mirror", Color(0.46, 0.53, 0.62, 1.0), 0.22, 0.0, 0.55)
	mirror.emission_enabled = true
	mirror.emission = Color(0.040, 0.060, 0.090, 1.0)
	mirror.emission_energy_multiplier = 0.8
	_save(mirror, MAT + "art_police_mirror.tres")

	# Sleeper Center: pale tile, soft board, cold steel, blue linen.
	_shader_variant(NM + "nm_stone_worked.tres", "art_sleeper_tile",
		Color(0.55, 0.60, 0.64, 1.0), 1.2, 0.0, 0.44, 0.02, 0.04)
	_shader_variant(NM + "nm_stone_worked.tres", "art_sleeper_wall",
		Color(0.46, 0.51, 0.56, 1.0), 2.2, 0.0, 0.92, 0.0, 0.0)
	_shader_variant(NM + "nm_stone_worked.tres", "art_sleeper_dark",
		Color(0.28, 0.31, 0.35, 1.0), 1.4, 0.0, 0.92, 0.02, 0.0)
	_standard_material("art_sleeper_metal", Color(0.50, 0.57, 0.64, 1.0), 0.32, 0.62, 0.18)
	_standard_material("art_sleeper_glass", Color(0.22, 0.36, 0.46, 1.0), 0.18, 0.20, 0.30)
	var sleeper_glass := load(MAT + "art_sleeper_glass.tres") as StandardMaterial3D
	if sleeper_glass != null:
		sleeper_glass.emission_enabled = true
		sleeper_glass.emission = Color(0.10, 0.28, 0.38, 1.0)
		sleeper_glass.emission_energy_multiplier = 0.75
		_save(sleeper_glass, MAT + "art_sleeper_glass.tres")
	_orm_variant(NM + "nm_linen.tres", "art_sleeper_fabric",
		Color(0.38, 0.49, 0.62, 1.0), 1.3, 0.0)
	_standard_emissive("art_sleeper_ring", Color(0.06, 0.12, 0.16, 1.0), Color(0.30, 0.78, 1.0, 1.0), 2.2)

	# Black Sea: basalt colossus, pale inlay, bronze trim, shroud cloth.
	_shader_variant(NM + "nm_marble_black.tres", "art_b01_stone",
		Color(0.26, 0.30, 0.35, 1.0), 4.0, 0.0, 0.86, 0.0, 0.04)
	_shader_variant(NM + "nm_marble_altar.tres", "art_b01_pale",
		Color(0.58, 0.62, 0.66, 1.0), 3.2, 0.0, 0.78, 0.0, 0.0)
	_shader_variant(NM + "nm_statue_bronze.tres", "art_b01_bronze",
		Color(0.52, 0.43, 0.33, 1.0), 3.6, 0.0, 1.0, 0.02, 0.62)
	var shroud := _standard_material("art_b01_shroud", Color(0.030, 0.048, 0.070, 1.0), 0.52, 0.04, 0.42)
	shroud.cull_mode = BaseMaterial3D.CULL_DISABLED
	shroud.rim_enabled = true
	shroud.rim = 0.55
	shroud.rim_tint = 0.35
	shroud.emission_enabled = true
	shroud.emission = Color(0.008, 0.016, 0.030, 1.0)
	shroud.emission_energy_multiplier = 0.35
	_save(shroud, MAT + "art_b01_shroud.tres")
	_standard_emissive("art_b01_star_glow", Color(0.36, 0.58, 0.92, 1.0), Color(0.42, 0.68, 1.0, 1.0), 2.6)

	# Tide descent: living coral, dressed stone, wet basalt, coral-warm glow.
	_coral_variant(NM + "nm_coral_live.tres", "art_b02_coral_live",
		Color(0.44, 0.15, 0.16, 1.0), Color(0.66, 0.35, 0.30, 1.0), 0.42, 0.26)
	_coral_variant(NM + "nm_coral_ground.tres", "art_b02_coral_pale",
		Color(0.50, 0.40, 0.34, 1.0), Color(0.62, 0.49, 0.40, 1.0), 0.20, 0.18)
	_shader_variant(NM + "nm_stone_worked.tres", "art_b02_wet_stone",
		Color(0.23, 0.25, 0.28, 1.0), 1.5, 0.0, 0.68, 0.10, 0.05)
	_standard_emissive("art_b02_glow", Color(0.20, 0.065, 0.035, 1.0), Color(1.0, 0.42, 0.18, 1.0), 1.15)
	_standard_emissive("art_b02_glow_dim", Color(0.12, 0.04, 0.025, 1.0), Color(0.80, 0.28, 0.10, 1.0), 0.35)


func _shader_variant(
		src_path: String,
		out_name: String,
		tint: Color,
		tile: float,
		snow: float,
		rough_scale: float,
		rough_offset: float,
		metallic: float
	) -> StandardMaterial3D:
	var src := load(src_path) as ShaderMaterial
	if src == null:
		push_error("A07: missing shader material " + src_path)
		return null
	# Greybox boxes have no vertex COLOR layer. The original nm_* shaders
	# multiply albedo by COLOR, which reads black on primitives. Build a
	# StandardMaterial3D with the same maps and world triplanar UVs instead.
	var mat := StandardMaterial3D.new()
	mat.resource_name = out_name
	mat.albedo_texture = src.get_shader_parameter("base_albedo") as Texture2D
	mat.albedo_color = tint
	var normal := src.get_shader_parameter("base_normal") as Texture2D
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = clampf(float(src.get_shader_parameter("base_normal_strength")), 0.0, 2.0)
	var orm := src.get_shader_parameter("base_orm") as Texture2D
	if orm != null:
		mat.roughness_texture = orm
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		mat.roughness = clampf(rough_scale, 0.0, 1.0)
		mat.metallic_texture = orm
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.metallic = clampf(metallic, 0.0, 1.0)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(tile, tile, tile)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Snow coverage is supplied by explicit snow-drift props in this kit; mixing
	# it into every wall made interior locations read as outdoor snowfields.
	if snow > 0.0:
		mat.albedo_color = tint.lerp(Color(0.82, 0.86, 0.90, 1.0), clampf(snow * 0.35, 0.0, 0.35))
	_save(mat, MAT + out_name + ".tres")
	return mat


func _coral_variant(
		src_path: String,
		out_name: String,
		tint: Color,
		tip: Color,
		tip_strength: float,
		sss: float
	) -> StandardMaterial3D:
	return _shader_variant(src_path, out_name, tint, 2.2, 0.0, 1.0, 0.0, 0.0)


func _orm_variant(
		src_path: String,
		out_name: String,
		tint: Color,
		tile: float,
		metallic: float
	) -> ORMMaterial3D:
	var src := load(src_path) as ORMMaterial3D
	if src == null:
		push_error("A07: missing ORM material " + src_path)
		return null
	var copy := src.duplicate(true) as ORMMaterial3D
	copy.resource_name = out_name
	copy.albedo_color = tint
	copy.vertex_color_use_as_albedo = false
	copy.uv1_scale = Vector3(tile, tile, tile)
	copy.metallic = metallic
	_save(copy, MAT + out_name + ".tres")
	return copy


func _standard_material(
		out_name: String,
		albedo: Color,
		roughness: float,
		metallic: float,
		rim: float
	) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = out_name
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = metallic
	mat.rim_enabled = rim > 0.0
	mat.rim = rim
	mat.rim_tint = 0.4
	_save(mat, MAT + out_name + ".tres")
	return mat


func _standard_emissive(
		out_name: String,
		albedo: Color,
		emission: Color,
		energy: float
	) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = out_name
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.45
	_save(mat, MAT + out_name + ".tres")
	return mat


# ---------------------------------------------------------------------------
# Environments
# ---------------------------------------------------------------------------

func _build_environments() -> void:
	_env_variant("env_precinct", "art_p05_env", 1.08, 0.30, 0.010, Color(0.07, 0.085, 0.11, 1.0))
	_env_variant("env_academy_approach", "art_p06_env", 0.96, 0.38, 0.022, Color(0.10, 0.13, 0.18, 1.0))
	_env_variant("env_academy_gate", "art_p07_env", 1.02, 0.42, 0.018, Color(0.10, 0.12, 0.16, 1.0))
	_env_variant("env_academy_gate", "art_p08_env", 0.94, 0.36, 0.016, Color(0.08, 0.10, 0.14, 1.0))
	_env_variant("env_academy_interior", "art_p09_env", 1.04, 0.28, 0.007, Color(0.10, 0.12, 0.15, 1.0))
	_env_variant("env_black_sea", "art_b01_env", 1.12, 0.55, 0.0026, Color(0.018, 0.028, 0.045, 1.0))
	_env_variant("env_tide_descent", "art_b02_env", 1.18, 0.46, 0.008, Color(0.035, 0.045, 0.055, 1.0))


func _env_variant(
		src_name: String,
		out_name: String,
		exposure: float,
		glow: float,
		fog: float,
		fog_color: Color
	) -> void:
	var src := load("res://resources/locations/post_nightmare/environments/%s.tres" % src_name) as Environment
	if src == null:
		push_error("A07: missing environment " + src_name)
		return
	var env := src.duplicate(true) as Environment
	env.resource_name = out_name
	env.tonemap_exposure = exposure
	env.glow_enabled = true
	env.glow_intensity = glow
	env.fog_enabled = true
	env.fog_density = fog
	env.fog_light_color = fog_color
	env.fog_sky_affect = 0.35
	_save(env, ART_ENV + out_name + ".tres")
	if out_name == "art_b02_env":
		env.ambient_light_energy = maxf(env.ambient_light_energy, 0.66)
		env.ambient_light_color = Color(0.22, 0.27, 0.34, 1.0)
		_save(env, ART_ENV + out_name + ".tres")


# ---------------------------------------------------------------------------
# Profiles
# ---------------------------------------------------------------------------

func _build_profiles() -> void:
	var p05 := _new_profile("art_p05_profile", ART_ENV + "art_p05_env.tres")
	p05.material_swaps = [
		_swap("concrete_cold.tres", MAT + "art_police_concrete.tres"),
		_swap("concrete_dark.tres", MAT + "art_police_concrete_dark.tres"),
		_swap("tile_wet.tres", MAT + "art_police_tile.tres"),
		_swap("asphalt.tres", MAT + "art_police_asphalt.tres"),
		_swap("paint_white.tres", MAT + "art_police_paint.tres"),
		_swap("metal_dark.tres", MAT + "art_police_metal.tres"),
		_swap("metal_light.tres", MAT + "art_police_metal.tres"),
		_swap("fabric_grey.tres", MAT + "art_police_fabric.tres"),
		_swap("fabric_blue.tres", MAT + "art_police_fabric.tres"),
		_swap("mirror.tres", MAT + "art_police_mirror.tres"),
		_swap("wood_dark.tres", MAT + "art_wood_dark.tres"),
		_swap("wood_light.tres", MAT + "art_wood_light.tres"),
	]
	p05.override_key_light = true
	p05.key_light_name = "Sun"
	p05.key_light_rotation_degrees = Vector3(-44.0, -30.0, 0.0)
	p05.key_light_color = Color(0.60, 0.71, 0.90, 1.0)
	p05.key_light_energy = 0.66
	p05.glow_intensity = 0.30
	p05.fog_density = 0.010
	_save(p05, PROFILE_DIR + "art_p05_profile.tres")

	var p06 := _new_profile("art_p06_profile", ART_ENV + "art_p06_env.tres")
	p06.material_swaps = _academy_swaps()
	p06.override_key_light = true
	p06.key_light_name = "Moon"
	p06.key_light_rotation_degrees = Vector3(-36.0, -28.0, 0.0)
	p06.key_light_color = Color(0.58, 0.72, 1.0, 1.0)
	p06.key_light_energy = 0.52
	p06.glow_intensity = 0.38
	p06.fog_density = 0.022
	_save(p06, PROFILE_DIR + "art_p06_profile.tres")

	var p07 := _new_profile("art_p07_profile", ART_ENV + "art_p07_env.tres")
	p07.material_swaps = _academy_swaps()
	p07.material_swaps.append(_swap("statue_stone.tres", MAT + "art_academy_red.tres"))
	p07.material_swaps.append(_swap("statue_pale.tres", MAT + "art_academy_concrete.tres"))
	p07.override_key_light = true
	p07.key_light_name = "Sun"
	p07.key_light_rotation_degrees = Vector3(-28.0, -24.0, 0.0)
	p07.key_light_color = Color(1.0, 0.91, 0.80, 1.0)
	p07.key_light_energy = 1.25
	p07.glow_intensity = 0.42
	p07.fog_density = 0.018
	_save(p07, PROFILE_DIR + "art_p07_profile.tres")

	var p08 := _new_profile("art_p08_profile", ART_ENV + "art_p08_env.tres")
	p08.material_swaps = _academy_swaps()
	p08.material_swaps.append(_swap("white.tres", MAT + "art_academy_white.tres"))
	p08.material_swaps.append(_swap("wood_light.tres", MAT + "art_wood_light.tres"))
	p08.hide_name_prefixes = PackedStringArray(["GalleryColumn"])
	p08.override_key_light = true
	p08.key_light_name = "Sun"
	p08.key_light_rotation_degrees = Vector3(-16.0, -40.0, 0.0)
	p08.key_light_color = Color(1.0, 0.82, 0.64, 1.0)
	p08.key_light_energy = 0.92
	p08.glow_intensity = 0.36
	p08.fog_density = 0.016
	_save(p08, PROFILE_DIR + "art_p08_profile.tres")

	var p09 := _new_profile("art_p09_profile", ART_ENV + "art_p09_env.tres")
	p09.material_swaps = [
		_swap("tile.tres", MAT + "art_sleeper_tile.tres"),
		_swap("tile_wet.tres", MAT + "art_sleeper_tile.tres"),
		_swap("paint_white.tres", MAT + "art_sleeper_wall.tres"),
		_swap("white.tres", MAT + "art_sleeper_wall.tres"),
		_swap("concrete_dark.tres", MAT + "art_sleeper_dark.tres"),
		_swap("metal_light.tres", MAT + "art_sleeper_metal.tres"),
		_swap("metal_dark.tres", MAT + "art_sleeper_metal.tres"),
		_swap("fabric_blue.tres", MAT + "art_sleeper_fabric.tres"),
		_swap("fabric_grey.tres", MAT + "art_sleeper_fabric.tres"),
		_swap("wood_light.tres", MAT + "art_wood_light.tres"),
		_swap("glass_blue.tres", MAT + "art_sleeper_glass.tres"),
	]
	p09.glow_intensity = 0.28
	p09.fog_density = 0.007
	_save(p09, PROFILE_DIR + "art_p09_profile.tres")

	var b01 := _new_profile("art_b01_profile", ART_ENV + "art_b01_env.tres")
	b01.material_swaps = [
		_swap("statue_stone.tres", MAT + "art_b01_stone.tres"),
		_swap("statue_pale.tres", MAT + "art_b01_pale.tres"),
		_swap("metal_light.tres", MAT + "art_b01_bronze.tres"),
		_swap("metal_dark.tres", MAT + "art_b01_bronze.tres"),
		_swap("coral.tres", MAT + "art_b02_coral_live.tres"),
		_swap("coral_pale.tres", MAT + "art_b02_coral_pale.tres"),
	]
	b01.override_key_light = true
	b01.key_light_name = "AbyssFill"
	b01.key_light_rotation_degrees = Vector3(-58.0, -18.0, 0.0)
	b01.key_light_color = Color(0.46, 0.62, 0.92, 1.0)
	b01.key_light_energy = 0.85
	b01.water_material = load(MAT + "water_black.tres")
	b01.water_name_contains = PackedStringArray(["BlackWater"])
	b01.glow_intensity = 0.55
	b01.fog_density = 0.0026
	_save(b01, PROFILE_DIR + "art_b01_profile.tres")

	var b02 := _new_profile("art_b02_profile", ART_ENV + "art_b02_env.tres")
	b02.material_swaps = [
		_swap("statue_stone.tres", MAT + "art_b02_wet_stone.tres"),
		_swap("statue_pale.tres", MAT + "art_b02_wet_stone.tres"),
		_swap("concrete_dark.tres", MAT + "art_b02_wet_stone.tres"),
		_swap("tile_wet.tres", MAT + "art_b02_wet_stone.tres"),
		_swap("coral.tres", MAT + "art_b02_coral_live.tres"),
		_swap("coral_pale.tres", MAT + "art_b02_coral_pale.tres"),
		_swap("screen_cyan.tres", MAT + "art_b02_glow.tres"),
		_swap("screen_cyan_dim.tres", MAT + "art_b02_glow_dim.tres"),
	]
	b02.override_key_light = true
	b02.key_light_name = "AbyssFill"
	b02.key_light_rotation_degrees = Vector3(-46.0, -22.0, 0.0)
	b02.key_light_color = Color(0.50, 0.64, 0.86, 1.0)
	b02.key_light_energy = 1.0
	b02.water_material = load(MAT + "water_black.tres")
	b02.water_name_contains = PackedStringArray(["SeaBelow"])
	b02.glow_intensity = 0.46
	b02.fog_density = 0.008
	_save(b02, PROFILE_DIR + "art_b02_profile.tres")


func _academy_swaps() -> Array:
	return [
		_swap("asphalt.tres", MAT + "art_academy_asphalt.tres"),
		_swap("concrete.tres", MAT + "art_academy_concrete.tres"),
		_swap("concrete_dark.tres", MAT + "art_academy_wall.tres"),
		_swap("metal_dark.tres", MAT + "art_academy_metal.tres"),
		_swap("metal_light.tres", MAT + "art_academy_metal.tres"),
		_swap("snow.tres", MAT + "art_academy_snow.tres"),
		_swap("glass_blue.tres", MAT + "art_academy_glass.tres"),
		_swap("screen_cyan_dim.tres", MAT + "art_academy_screen.tres"),
		_swap("fabric_blue.tres", MAT + "art_academy_red.tres"),
	]


func _new_profile(resource_name: String, env_path: String) -> Resource:
	var profile = PROFILE_SCRIPT.new()
	profile.resource_name = resource_name
	var env := load(env_path) as Environment
	profile.environment = env
	profile.apply_environment = true
	return profile


func _swap(suffix: String, material_path: String) -> Resource:
	var swap = SWAP_SCRIPT.new()
	swap.match_path_suffix = suffix
	swap.material = load(material_path)
	return swap


# ---------------------------------------------------------------------------
# Art scenes
# ---------------------------------------------------------------------------

func _build_art_scenes() -> void:
	_build_p05()
	_build_p06()
	_build_p07()
	_build_p08()
	_build_p09()
	_build_b01()
	_build_b02()


func _new_art(name: String, profile_path: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ArtOverlay"
	root.set_script(OVERLAY_SCRIPT)
	root.set("profile", load(profile_path))
	root.set("apply_on_ready", true)
	for group_name in ["Props", "Lights", "Decals"]:
		var group := Node3D.new()
		group.name = group_name
		root.add_child(group)
		group.owner = root
	return root


func _build_p05() -> void:
	var root := _new_art("PolicePrecinctArt", PROFILE_DIR + "art_p05_profile.tres")
	var props := root.get_node("Props") as Node3D
	_add_asset(root, props, "YardSupplyCrate", NM_ASSET + "caravan/crate_supplies_a.glb", Vector3(14.0, 0.0, 8.4), -0.35, 1.0)
	_add_asset(root, props, "YardBarrel", NM_ASSET + "caravan/barrel_water_a.glb", Vector3(-14.4, 0.0, 12.8), 0.3, 1.0)
	_add_asset(root, props, "CellChain", NM_ASSET + "caravan/chain_main_slack.glb", Vector3(6.1, 0.0, -19.0), 1.2, 1.0)
	_add_asset(root, props, "InterrogationShackles", NM_ASSET + "caravan/shackles_pair.glb", Vector3(-16.1, 0.80, -2.05), 0.25, 0.55, false)
	_add_asset(root, props, "EvidenceBones", NM_ASSET + "remains/bones_scatter_a.glb", Vector3(-17.6, 0.02, -4.8), 0.8, 0.72)
	_add_asset(root, props, "CellBones", NM_ASSET + "remains/bones_pile_c.glb", Vector3(3.4, 0.0, -19.2), 0.2, 0.8)
	_add_decal(root, "YardDragMark", "res://assets/environments/nightmare/materials/textures/p3_chain_scrape.png",
		Vector3(9.0, 0.03, 7.0), Vector3(9.0, 1.2, 5.0), 0.4, Color(0.08, 0.10, 0.12, 0.55))
	# A03's blockout mirror sits behind the interrogation west wall. Add a
	# proper art-side mirror face and frame on the visible inner surface.
	_add_box(root, props, "InterrogationMirrorPanel", Vector3(-18.80, 1.8, -2.0), Vector3(0.04, 2.0, 3.0), MAT + "art_police_mirror.tres")
	_add_box(root, props, "InterrogationMirrorFrameTop", Vector3(-18.78, 2.86, -2.0), Vector3(0.06, 0.14, 3.24), MAT + "art_police_metal.tres")
	_add_box(root, props, "InterrogationMirrorFrameBottom", Vector3(-18.78, 0.74, -2.0), Vector3(0.06, 0.14, 3.24), MAT + "art_police_metal.tres")
	_add_box(root, props, "InterrogationMirrorFrameWest", Vector3(-18.78, 1.8, -3.56), Vector3(0.06, 2.26, 0.14), MAT + "art_police_metal.tres")
	_add_box(root, props, "InterrogationMirrorFrameEast", Vector3(-18.78, 1.8, -0.44), Vector3(0.06, 2.26, 0.14), MAT + "art_police_metal.tres")
	_add_decal(root, "MirrorHandprint", "res://assets/environments/nightmare/materials/textures/p3_blood.png",
		Vector3(-18.76, 1.85, -2.0), Vector3(1.8, 2.0, 1.2), PI * 0.5, Color(0.16, 0.42, 0.66, 0.75))
	_add_reflection_probe(root, props, "InterrogationMirrorProbe", Vector3(-17.6, 1.8, -2.0), Vector3(4.2, 3.2, 5.2))
	_add_omni(root, "IntakeFill", Vector3(0.0, 3.7, 0.0), Color(0.62, 0.74, 0.92, 1.0), 1.6, 12.0)
	_add_omni(root, "CellFill", Vector3(0.0, 3.0, -15.0), Color(0.44, 0.58, 0.78, 1.0), 1.0, 11.0)
	_add_omni(root, "YardSodium", Vector3(8.0, 5.2, 12.0), Color(1.0, 0.58, 0.30, 1.0), 2.6, 24.0)
	_add_omni(root, "YardMoonFill", Vector3(8.0, 28.0, 14.0), Color(0.50, 0.66, 0.90, 1.0), 2.2, 40.0)
	_add_omni(root, "MirrorFill", Vector3(-17.0, 2.5, -2.0), Color(0.64, 0.80, 1.0, 1.0), 1.0, 5.0)
	_add_spot(root, "MirrorKey", Vector3(-16.0, 3.0, -2.0), Vector3(-19.5, 1.8, -2.0), Color(0.70, 0.84, 1.0, 1.0), 4.0, 8.0, 24.0)
	_save_scene(root, ART_SCENE + "police_precinct_art.tscn")


func _build_p06() -> void:
	var root := _new_art("AcademyApproachArt", PROFILE_DIR + "art_p06_profile.tres")
	var props := root.get_node("Props") as Node3D
	_add_asset(root, props, "SnowDriftWestA", NM_ASSET + "mountain/snow_drift_low_a.glb", Vector3(-9.3, 0.0, -11.0), 0.1, 1.2)
	_add_asset(root, props, "SnowDriftWestB", NM_ASSET + "mountain/snow_drift_small_d.glb", Vector3(-8.9, 0.0, 5.0), 1.7, 1.0)
	_add_asset(root, props, "SnowDriftEastA", NM_ASSET + "mountain/snow_drift_crest_c.glb", Vector3(9.4, 0.0, 9.0), PI, 1.1)
	_add_asset(root, props, "SnowDriftEastB", NM_ASSET + "mountain/snow_drift_wall_b.glb", Vector3(9.0, 0.0, -4.0), PI, 0.9)
	_add_asset(root, props, "DeadTreeWest", NM_ASSET + "flora/dead_tree_b.glb", Vector3(-12.8, 0.0, -3.0), 0.5, 1.1)
	_add_asset(root, props, "DeadTreeEast", NM_ASSET + "flora/dead_tree_a.glb", Vector3(13.0, 0.0, 8.0), 2.0, 1.0)
	_add_asset(root, props, "CheckpointCrate", NM_ASSET + "caravan/crate_supplies_a.glb", Vector3(9.1, 0.0, -19.2), -0.2, 0.85)
	_add_asset(root, props, "GuardBarrel", NM_ASSET + "caravan/barrel_water_a.glb", Vector3(9.6, 0.0, -15.8), 0.4, 1.0)
	_add_asset(root, props, "RoadDebris", NM_ASSET + "caravan/wagon_debris_a.glb", Vector3(-7.8, 0.0, 12.5), 1.1, 0.8)
	_add_omni(root, "ApproachWarmFill", Vector3(-4.0, 6.2, 8.0), Color(1.0, 0.72, 0.46, 1.0), 1.5, 16.0)
	_add_omni(root, "CheckpointWarmWash", Vector3(5.0, 4.5, -18.0), Color(1.0, 0.76, 0.52, 1.0), 1.2, 9.0)
	_add_omni(root, "CheckpointInterior", Vector3(0.0, 3.1, -20.8), Color(1.0, 0.80, 0.58, 1.0), 2.0, 11.0)
	_add_box(root, props, "CheckpointGuideTop", Vector3(0.0, 4.05, -20.9), Vector3(4.2, 0.07, 0.10), MAT + "art_academy_screen.tres")
	_add_box(root, props, "CheckpointGuideWest", Vector3(-2.15, 2.0, -20.9), Vector3(0.08, 3.4, 0.10), MAT + "art_academy_screen.tres")
	_add_box(root, props, "CheckpointGuideEast", Vector3(2.15, 2.0, -20.9), Vector3(0.08, 3.4, 0.10), MAT + "art_academy_screen.tres")
	_save_scene(root, ART_SCENE + "academy_approach_art.tscn")


func _build_p07() -> void:
	var root := _new_art("AcademyGateArt", PROFILE_DIR + "art_p07_profile.tres")
	var props := root.get_node("Props") as Node3D
	for spec in [
		["GateColumnWestA", Vector3(-15.2, 0.0, 5.5), 0.0, 1.0],
		["GateColumnEastA", Vector3(15.2, 0.0, 5.5), 0.0, 1.0],
		["GateColumnWestB", Vector3(-15.2, 0.0, 18.0), 0.0, 0.92],
		["GateColumnEastB", Vector3(15.2, 0.0, 18.0), 0.0, 0.92],
	]:
		_add_asset(root, props, spec[0], NM_ASSET + "temple/column_intact.glb", spec[1], spec[2], spec[3])
	_add_asset(root, props, "GateRelief", NM_ASSET + "temple/relief_panel_geometric.glb", Vector3(0.0, 5.3, 0.82), 0.0, 1.25, false)
	_add_asset(root, props, "GateReliefSide", NM_ASSET + "temple/relief_panel_figure.glb", Vector3(-3.8, 5.3, 0.82), 0.0, 0.95, false)
	# A07-02b: the gate silhouette is red in the design bible. These visual-only
	# trim pieces catch the warm floodlight even when the stone arch is in shade.
	_add_box(root, props, "GateRedLintel", Vector3(0.0, 5.95, 4.35), Vector3(4.7, 0.52, 0.30), MAT + "art_academy_red.tres")
	_add_box(root, props, "GateRedPostWest", Vector3(-2.25, 3.0, 4.35), Vector3(0.30, 5.6, 0.30), MAT + "art_academy_red.tres")
	_add_box(root, props, "GateRedPostEast", Vector3(2.25, 3.0, 4.35), Vector3(0.30, 5.6, 0.30), MAT + "art_academy_red.tres")
	_add_box(root, props, "GateRedThreshold", Vector3(0.0, 0.12, 4.35), Vector3(4.7, 0.18, 0.38), MAT + "art_academy_red.tres")
	_add_asset(root, props, "PlazaSnowWest", NM_ASSET + "mountain/snow_drift_low_a.glb", Vector3(-12.5, 0.0, 22.0), 0.7, 1.1)
	_add_asset(root, props, "PlazaSnowEast", NM_ASSET + "mountain/snow_drift_small_d.glb", Vector3(12.3, 0.0, 22.3), 2.3, 1.0)
	_add_asset(root, props, "PlazaSupplyCrate", NM_ASSET + "caravan/crate_supplies_a.glb", Vector3(12.2, 0.0, 4.5), 0.35, 0.8)
	_add_asset(root, props, "PlazaBarrel", NM_ASSET + "caravan/barrel_broken_b.glb", Vector3(-11.2, 0.0, 4.8), 1.2, 0.9)
	_add_omni(root, "GateWarmFlood", Vector3(0.0, 9.0, 8.0), Color(1.0, 0.82, 0.62, 1.0), 2.2, 22.0)
	_add_spot(root, "StarHalo", Vector3(0.0, 7.6, 4.0), Vector3(0.0, 7.4, 0.0), Color(0.58, 0.78, 1.0, 1.0), 2.4, 14.0, 30.0)
	_add_omni(root, "GateInnerWarm", Vector3(0.0, 4.0, -8.0), Color(1.0, 0.74, 0.48, 1.0), 1.1, 12.0)
	_save_scene(root, ART_SCENE + "academy_gate_art.tscn")


func _build_p08() -> void:
	var root := _new_art("AcademyCampusArt", PROFILE_DIR + "art_p08_profile.tres")
	var props := root.get_node("Props") as Node3D
	for z in [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]:
		_add_asset(root, props, StringName("StoneGalleryWest%s" % str(z)), NM_ASSET + "temple/column_intact.glb", Vector3(-4.4, 0.0, z), 0.0, 0.62)
		_add_asset(root, props, StringName("StoneGalleryEast%s" % str(z)), NM_ASSET + "temple/column_intact.glb", Vector3(4.4, 0.0, z), 0.0, 0.62)
	_add_asset(root, props, "GalleryReliefWest", NM_ASSET + "temple/relief_panel_figure.glb", Vector3(-7.93, 5.2, -2.0), PI * 0.5, 1.4, false)
	_add_asset(root, props, "GalleryReliefEast", NM_ASSET + "temple/relief_panel_geometric.glb", Vector3(7.93, 5.2, 2.0), -PI * 0.5, 1.4, false)
	_add_asset(root, props, "CampusSnowWest", NM_ASSET + "mountain/snow_drift_low_a.glb", Vector3(-8.5, 0.0, 18.0), 0.3, 1.1)
	_add_asset(root, props, "CampusSnowEast", NM_ASSET + "mountain/snow_drift_small_d.glb", Vector3(8.5, 0.0, -16.0), 1.9, 1.0)
	_add_asset(root, props, "CampusDebris", NM_ASSET + "caravan/wagon_debris_a.glb", Vector3(-6.2, 0.0, 14.5), 0.7, 0.7)
	_add_omni(root, "GalleryWarmA", Vector3(0.0, 3.9, -8.0), Color(1.0, 0.72, 0.46, 1.0), 1.0, 8.0)
	_add_omni(root, "GalleryWarmB", Vector3(0.0, 3.9, 8.0), Color(1.0, 0.72, 0.46, 1.0), 1.0, 8.0)
	_add_spot(root, "EveningSunWash", Vector3(-10.0, 8.0, 18.0), Vector3(0.0, 0.0, 0.0), Color(1.0, 0.80, 0.62, 1.0), 1.2, 30.0, 32.0)
	_save_scene(root, ART_SCENE + "academy_campus_art.tscn")


func _build_p09() -> void:
	var root := _new_art("AcademySleeperCenterArt", PROFILE_DIR + "art_p09_profile.tres")
	var props := root.get_node("Props") as Node3D
	_add_torus(root, props, "InductionRingOuter", Vector3(0.0, 0.08, -25.5), 1.42, 1.58, 0.10, MAT + "art_sleeper_ring.tres")
	_add_torus(root, props, "InductionRingInner", Vector3(0.0, 0.24, -25.5), 0.92, 1.04, 0.07, MAT + "art_sleeper_ring.tres")
	_add_asset(root, props, "DormMedicalBox", NM_ASSET + "caravan/crate_supplies_a.glb", Vector3(-9.8, 0.0, -5.2), 0.3, 0.7)
	_add_asset(root, props, "ShowerSupply", NM_ASSET + "caravan/barrel_water_a.glb", Vector3(22.0, 0.0, 5.0), 0.3, 0.8)
	_add_omni(root, "DormColdWest", Vector3(-8.0, 3.7, 0.0), Color(0.52, 0.74, 1.0, 1.0), 1.15, 12.0)
	_add_omni(root, "DormColdEast", Vector3(8.0, 3.7, 0.0), Color(0.52, 0.74, 1.0, 1.0), 1.15, 12.0)
	_add_spot(root, "InductionKey", Vector3(0.0, 4.2, -25.5), Vector3(0.0, 0.0, -25.5), Color(0.46, 0.78, 1.0, 1.0), 2.0, 11.0, 26.0)
	_add_omni(root, "ObservationColdFill", Vector3(0.0, 3.2, -10.0), Color(0.56, 0.74, 0.96, 1.0), 0.9, 9.0)
	_add_omni(root, "CommonWarmFill", Vector3(-20.0, 3.2, 0.0), Color(1.0, 0.70, 0.44, 1.0), 0.85, 9.0)
	_save_scene(root, ART_SCENE + "academy_sleeper_center_art.tscn")


func _build_b01() -> void:
	var root := _new_art("BlackSeaPlatformArt", PROFILE_DIR + "art_b01_profile.tres")
	var props := root.get_node("Props") as Node3D
	_add_shroud(root, props, "TornShroud", Vector3(-22.0, -2.0, -30.90), 18.0, 38.0, MAT + "art_b01_shroud.tres")
	_add_shroud(root, props, "TornShroudEast", Vector3(21.0, -4.0, -30.98), 10.0, 26.0, MAT + "art_b01_shroud.tres")
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		_add_star(root, props, StringName("EchoStar%d" % i), Vector3(cos(angle) * 15.5, -21.0 + sin(angle) * 15.5, -31.6), 1.2, MAT + "art_b01_star_glow.tres")
	_add_omni(root, "ShroudRim", Vector3(-18.0, -4.0, -24.0), Color(0.38, 0.56, 0.88, 1.0), 2.8, 28.0)
	_add_omni(root, "ShroudFill", Vector3(-20.0, -14.0, -25.0), Color(0.30, 0.46, 0.72, 1.0), 1.6, 24.0)
	_add_omni(root, "SwordColdGlint", Vector3(0.0, -34.0, -38.0), Color(0.50, 0.68, 1.0, 1.0), 2.4, 30.0)
	_add_spot(root, "NeckMoonKey", Vector3(0.0, 12.0, 10.0), Vector3(0.0, 0.0, 0.0), Color(0.54, 0.70, 1.0, 1.0), 3.2, 30.0, 28.0)
	_save_scene(root, ART_SCENE + "black_sea_platform_art.tscn")


func _build_b02() -> void:
	var root := _new_art("TideDescentArt", PROFILE_DIR + "art_b02_profile.tres")
	var props := root.get_node("Props") as Node3D
	_add_asset(root, props, "BottomCoralArch", NM_ASSET + "coral/coral_arch_a.glb", Vector3(0.0, -6.0, -23.4), 0.0, 1.25)
	_add_asset(root, props, "StairCoralWest", NM_ASSET + "coral/coral_blade_a.glb", Vector3(-4.1, -5.8, -20.0), 0.3, 0.8)
	_add_asset(root, props, "StairCoralEast", NM_ASSET + "coral/coral_mass_c.glb", Vector3(4.1, -5.8, -20.0), 1.4, 0.75)
	_add_asset(root, props, "TopWeatheredStone", NM_ASSET + "mountain/boulder_rounded_a.glb", Vector3(-2.4, 0.0, 21.8), 0.6, 0.8)
	_add_asset(root, props, "DescentCoral", NM_ASSET + "coral/coral_mass_b.glb", Vector3(10.8, -1.2, 0.0), 0.8, 0.65)
	_add_omni(root, "TopCoralWarm", Vector3(0.0, 4.0, 19.0), Color(1.0, 0.60, 0.34, 1.0), 3.0, 20.0)
	_add_omni(root, "BottomCoralWarm", Vector3(0.0, -2.4, -20.5), Color(1.0, 0.52, 0.26, 1.0), 2.8, 15.0)
	_add_omni(root, "StairPathHigh", Vector3(0.0, 1.4, 10.0), Color(1.0, 0.58, 0.32, 1.0), 1.8, 11.0)
	_add_omni(root, "StairPathMid", Vector3(0.0, -2.0, -1.0), Color(1.0, 0.55, 0.30, 1.0), 1.7, 11.0)
	_add_omni(root, "StairPathLow", Vector3(0.0, -4.8, -11.0), Color(1.0, 0.52, 0.28, 1.0), 1.8, 10.0)
	_add_box(root, props, "StairGuideHigh", Vector3(0.0, 0.20, 12.0), Vector3(4.6, 0.05, 0.12), MAT + "art_b02_glow_dim.tres")
	_add_box(root, props, "StairGuideMid", Vector3(0.0, -2.90, 0.0), Vector3(4.6, 0.05, 0.12), MAT + "art_b02_glow_dim.tres")
	_add_box(root, props, "StairGuideLow", Vector3(0.0, -5.65, -12.0), Vector3(4.6, 0.05, 0.12), MAT + "art_b02_glow_dim.tres")
	_add_spot(root, "StairWetKey", Vector3(-3.0, 3.0, 6.0), Vector3(0.0, -6.0, -18.0), Color(0.58, 0.74, 1.0, 1.0), 2.6, 26.0, 26.0)
	_save_scene(root, ART_SCENE + "tide_descent_art.tscn")


# ---------------------------------------------------------------------------
# Scene helpers
# ---------------------------------------------------------------------------

func _clean_prop(path: String) -> String:
	if _clean_props.has(path):
		return String(_clean_props[path])
	var file_base := path.get_file().get_basename()
	var clean_path := CLEAN_PROP + "clean_" + file_base + ".tscn"
	if ResourceLoader.exists(clean_path):
		_clean_props[path] = clean_path
		return clean_path
	var packed := load(path) as PackedScene
	if packed == null:
		_clean_props[path] = ""
		return ""
	var source := packed.instantiate()
	var root := Node3D.new()
	root.name = "Prop_" + file_base
	_copy_visual(source, root, Transform3D.IDENTITY)
	if root.get_child_count() == 0:
		root.free()
		source.free()
		_clean_props[path] = ""
		return ""
	_set_owners(root, root)
	var clean := PackedScene.new()
	if clean.pack(root) != OK:
		push_error("A07: failed to pack cleaned prop " + path)
		root.free()
		source.free()
		_clean_props[path] = ""
		return ""
	_save(clean, clean_path)
	root.free()
	source.free()
	_clean_props[path] = clean_path
	return clean_path


func _copy_visual(source: Node, root: Node3D, xform: Transform3D) -> void:
	if source is MeshInstance3D:
		var mesh_instance := source as MeshInstance3D
		if mesh_instance.mesh != null:
			var copy := MeshInstance3D.new()
			copy.name = mesh_instance.name
			copy.mesh = mesh_instance.mesh
			copy.transform = xform
			copy.cast_shadow = mesh_instance.cast_shadow
			if mesh_instance.material_override != null:
				copy.material_override = mesh_instance.material_override
			for surface in mesh_instance.mesh.get_surface_count():
				var surface_material := mesh_instance.get_surface_override_material(surface)
				if surface_material != null:
					copy.set_surface_override_material(surface, surface_material)
			root.add_child(copy)
			copy.owner = root
	for child in source.get_children():
		if child is Node3D:
			_copy_visual(child, root, xform * (child as Node3D).transform)


func _add_asset(
		owner_root: Node3D,
		parent: Node3D,
		node_name: String,
		path: String,
		base: Vector3,
		yaw: float,
		scale_factor: float,
		ground := true
	) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("A07: missing art asset " + path)
		return null
	var clean_path := _clean_prop(path)
	if clean_path.is_empty():
		push_warning("A07: no visual mesh in art asset " + path)
		return null
	var packed := load(clean_path) as PackedScene
	if packed == null:
		push_warning("A07: cannot load clean art asset " + clean_path)
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	node.name = node_name
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale_factor
	parent.add_child(node)
	if ground:
		var bounds := _local_aabb(node)
		node.position = Vector3(base.x, base.y - bounds.position.y * scale_factor, base.z)
	else:
		node.position = base
	_strip_collision(node)
	node.owner = owner_root
	return node


func _add_omni(
		owner_root: Node3D,
		node_name: String,
		position: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> void:
	var lights := owner_root.get_node("Lights") as Node3D
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	lights.add_child(light)
	light.owner = owner_root


func _add_spot(
		owner_root: Node3D,
		node_name: String,
		position: Vector3,
		target: Vector3,
		color: Color,
		energy: float,
		range_value: float,
		angle_degrees: float
	) -> void:
	var lights := owner_root.get_node("Lights") as Node3D
	var light := SpotLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_value
	light.spot_angle = angle_degrees
	light.shadow_enabled = false
	lights.add_child(light)
	var direction := (target - position).normalized()
	var up := Vector3.UP
	if absf(direction.dot(up)) > 0.999:
		up = Vector3.FORWARD
	light.look_at_from_position(position, target, up)
	light.owner = owner_root


func _add_box(
		owner_root: Node3D,
		parent: Node3D,
		node_name: String,
		position: Vector3,
		size: Vector3,
		material_path: String,
		yaw := 0.0
	) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = load(material_path)
	mi.position = position
	mi.rotation.y = yaw
	parent.add_child(mi)
	mi.owner = owner_root
	return mi


func _add_reflection_probe(
		owner_root: Node3D,
		parent: Node3D,
		node_name: String,
		position: Vector3,
		size: Vector3
	) -> ReflectionProbe:
	var probe := ReflectionProbe.new()
	probe.name = node_name
	probe.position = position
	probe.size = size
	probe.interior = true
	probe.box_projection = true
	probe.enable_shadows = true
	probe.intensity = 1.0
	probe.max_distance = 24.0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	parent.add_child(probe)
	probe.owner = owner_root
	return probe


func _add_torus(
		owner_root: Node3D,
		parent: Node3D,
		node_name: String,
		position: Vector3,
		inner_radius: float,
		outer_radius: float,
		height: float,
		material_path: String
	) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = inner_radius
	torus.outer_radius = outer_radius
	torus.rings = 48
	torus.ring_segments = 12
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = torus
	mi.material_override = load(material_path)
	mi.position = position
	mi.scale = Vector3(1.0, height / 0.1, 1.0)
	parent.add_child(mi)
	mi.owner = owner_root


func _add_star(
		owner_root: Node3D,
		parent: Node3D,
		node_name: String,
		position: Vector3,
		radius: float,
		material_path: String
	) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _star_mesh(radius)
	mi.material_override = load(material_path)
	mi.position = position
	parent.add_child(mi)
	mi.owner = owner_root


func _star_mesh(radius: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3(0, 0, 1))
	for i in 10:
		var angle := -PI * 0.5 + TAU * float(i) / 10.0
		var r := radius if i % 2 == 0 else radius * 0.43
		vertices.append(Vector3(cos(angle) * r, sin(angle) * r, 0))
		normals.append(Vector3(0, 0, 1))
	for i in 10:
		indices.append(0)
		indices.append(i + 1)
		indices.append((i + 1) % 10 + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_shroud(
		owner_root: Node3D,
		parent: Node3D,
		node_name: String,
		top: Vector3,
		width: float,
		height: float,
		material_path: String
	) -> void:
	var cols := 14
	var rows := 12
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in rows:
		var v := float(row) / float(rows - 1)
		for col in cols:
			var u := float(col) / float(cols - 1)
			var x := (u - 0.5) * width
			var y := -v * height
			var fold := sin(u * TAU * 3.0 + v * 2.3) * (0.25 + v * 0.55)
			var tatter := 0.0
			if row == rows - 1:
				tatter = sin(u * TAU * 5.0) * 3.0 - 2.0
			var z := fold + tatter * 0.15
			vertices.append(Vector3(x, y + tatter, z))
			var dfu := cos(u * TAU * 3.0 + v * 2.3) * TAU * 3.0 * (0.25 + v * 0.55)
			var dfv := cos(u * TAU * 3.0 + v * 2.3) * 2.3 * (0.25 + v * 0.55) + sin(u * TAU * 3.0 + v * 2.3) * 0.55
			normals.append(Vector3(-dfu / width, dfv / height, 1.0).normalized())
			uvs.append(Vector2(u, v))
	for row in rows - 1:
		for col in cols - 1:
			var a := row * cols + col
			var b := a + 1
			var c := a + cols
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = load(material_path)
	mi.position = top
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	mi.owner = owner_root


func _add_decal(
		owner_root: Node3D,
		node_name: String,
		texture_path: String,
		position: Vector3,
		size: Vector3,
		yaw: float,
		tint: Color
	) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var decals := owner_root.get_node("Decals") as Node3D
	var decal := Decal.new()
	decal.name = node_name
	decal.texture_albedo = texture
	decal.modulate = tint
	decal.albedo_mix = 0.85
	decal.size = size
	decal.position = position
	decal.rotation.y = yaw
	decal.upper_fade = 0.2
	decal.lower_fade = 0.35
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 50.0
	decal.distance_fade_length = 20.0
	decals.add_child(decal)
	decal.owner = owner_root


func _save_scene(root: Node3D, path: String) -> void:
	_set_owners(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		_save(packed, path)
	else:
		push_error("A07: pack failed for %s (%s)" % [path, err])
	root.free()


func _set_owners(root: Node3D, node: Node) -> void:
	for child in node.get_children():
		child.owner = root
		# Do not recurse into an instanced GLB/scene: its internal nodes must
		# stay inside the instance, otherwise PackedScene embeds a full mesh
		# copy and the art scene becomes hundreds of kilobytes.
		if child.scene_file_path.is_empty():
			_set_owners(root, child)


func _local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node3D = entry[0]
		var xform: Transform3D = entry[1] * node.transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var box: AABB = xform * (node as MeshInstance3D).mesh.get_aabb()
			if first:
				out = box
				first = false
			else:
				out = out.merge(box)
		for child in node.get_children():
			if child is Node3D:
				stack.append([child, xform])
	return out


func _strip_collision(root: Node) -> void:
	var to_remove: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is CollisionObject3D or node is CollisionShape3D:
			to_remove.append(node)
	for node in to_remove:
		if not is_instance_valid(node):
			continue
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.free()


# ---------------------------------------------------------------------------
# Preview wrappers
# ---------------------------------------------------------------------------

func _build_previews() -> void:
	_preview("p05_police_precinct", "PolicePrecinct", "res://scenes/locations/post_nightmare/police_precinct.tscn", ART_SCENE + "police_precinct_art.tscn")
	_preview("p06_academy_approach", "AcademyApproach", "res://scenes/locations/post_nightmare/academy_approach.tscn", ART_SCENE + "academy_approach_art.tscn")
	_preview("p07_academy_gate", "AcademyGate", "res://scenes/locations/post_nightmare/academy_gate.tscn", ART_SCENE + "academy_gate_art.tscn")
	_preview("p08_academy_campus", "AcademyCampus", "res://scenes/locations/post_nightmare/academy_campus.tscn", ART_SCENE + "academy_campus_art.tscn")
	_preview("p09_sleeper_center", "AcademySleeperCenter", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", ART_SCENE + "academy_sleeper_center_art.tscn")
	_preview("b01_black_sea_platform", "BlackSeaPlatform", "res://scenes/locations/post_nightmare/black_sea_platform.tscn", ART_SCENE + "black_sea_platform_art.tscn")
	_preview("b02_tide_descent", "TideDescent", "res://scenes/locations/post_nightmare/tide_descent.tscn", ART_SCENE + "tide_descent_art.tscn")


func _preview(file_name: String, node_name: String, location_path: String, art_path: String) -> void:
	var root := Node3D.new()
	root.name = "ArtPreview"
	root.set_script(PREVIEW_SCRIPT)
	root.set("location_scene_path", location_path)
	root.set("art_scene_path", art_path)
	root.set("location_node_name", node_name)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		_save(packed, PREVIEW + file_name + "_preview.tscn")
	else:
		push_error("A07: preview pack failed for %s (%s)" % [file_name, err])
	root.free()
