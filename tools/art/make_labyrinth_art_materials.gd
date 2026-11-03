extends SceneTree
## Creates StandardMaterial3D resources for procedural greybox primitives.
## The coral kit uses ShaderMaterial with vertex-color masks; primitives have
## no vertex colors, so they need separate simple triplanar PBR materials.
## Run: godot --headless --path . -s tools/art/make_labyrinth_art_materials.gd

const TEX := "res://assets/environments/nightmare/materials/textures/"
const OUT := "res://resources/locations/forgotten_shore_labyrinth/materials/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	_make(
		"nm_coral_live_prim",
		"coral_fort_wall_01_diff_2k.jpg",
		"coral_fort_wall_01_nor_gl_2k.jpg",
		"coral_fort_wall_01_arm_2k.jpg",
		Color(0.50, 0.23, 0.24, 1.0),
		0.44,
		1.35,
		0.94
	)
	_make(
		"nm_coral_dead_prim",
		"coral_fort_wall_02_diff_2k.jpg",
		"coral_fort_wall_02_nor_gl_2k.jpg",
		"coral_fort_wall_02_arm_2k.jpg",
		Color(0.74, 0.64, 0.60, 1.0),
		0.50,
		1.15,
		1.0
	)
	_make(
		"nm_mud_wet_prim",
		"coral_mud_01_diff_2k.jpg",
		"coral_mud_01_nor_gl_2k.jpg",
		"coral_mud_01_arm_2k.jpg",
		Color(0.34, 0.35, 0.40, 1.0),
		0.32,
		0.55,
		1.05
	)
	_make(
		"nm_coral_ground_prim",
		"coral_ground_02_diff_2k.jpg",
		"coral_ground_02_nor_gl_2k.jpg",
		"coral_ground_02_arm_2k.jpg",
		Color(0.52, 0.42, 0.38, 1.0),
		0.34,
		0.82,
		1.04
	)
	_make(
		"nm_bone_aged_prim",
		"nm_bone_aged_diff_1k.jpg",
		"nm_bone_aged_nor_gl_1k.jpg",
		"nm_bone_aged_arm_1k.jpg",
		Color(0.72, 0.68, 0.60, 1.0),
		1.25,
		0.95,
		0.82
	)
	_make(
		"nm_statue_stone_prim",
		"low_tide_rocks_diff_2k.jpg",
		"low_tide_rocks_nor_gl_2k.jpg",
		"low_tide_rocks_arm_2k.jpg",
		Color(0.58, 0.58, 0.60, 1.0),
		0.36,
		1.15,
		0.98
	)
	_make(
		"nm_dark_rock_prim",
		"low_tide_rocks_diff_2k.jpg",
		"low_tide_rocks_nor_gl_2k.jpg",
		"low_tide_rocks_arm_2k.jpg",
		Color(0.30, 0.34, 0.44, 1.0),
		0.30,
		1.1,
		1.0
	)

	print("Labyrinth art materials written to ", OUT)
	quit(0)


func _make(
	mat_name: String,
	albedo_file: String,
	normal_file: String,
	orm_file: String,
	tint: Color,
	world_scale: float,
	normal_scale: float,
	roughness_scale: float
) -> void:
	var mat := StandardMaterial3D.new()
	mat.resource_name = mat_name
	mat.albedo_texture = load(TEX + albedo_file)
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = load(TEX + normal_file)
	mat.normal_scale = normal_scale
	var orm: Texture2D = load(TEX + orm_file)
	mat.ao_enabled = true
	mat.ao_texture = orm
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.ao_light_affect = 0.35
	mat.roughness_texture = orm
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.roughness = roughness_scale
	mat.metallic = 0.0
	mat.metallic_specular = 0.42
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 5.0
	mat.uv1_scale = Vector3(world_scale, world_scale, world_scale)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.texture_repeat = true
	var err := ResourceSaver.save(mat, OUT + mat_name + ".tres")
	if err != OK:
		push_error("Failed to save %s: %s" % [mat_name, err])
