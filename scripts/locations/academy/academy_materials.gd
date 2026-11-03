class_name AcademyMaterials
extends RefCounted
## Final PBR materials for the standalone Academy locations.
##
## Blender exports the architecture with simple named materials. This factory
## maps those names to Godot StandardMaterial3D resources with the project's
## CC0 texture set, triplanar mapping and a consistent winter palette. It is
## intentionally runtime-only: no .tres proliferation, no changes to the
## existing post-nightmare material library.

const TEX_PLASTER_DIFF := preload("res://assets/environments/park/materials/textures/plaster_grey_04_diff_1k.jpg")
const TEX_PLASTER_ARM := preload("res://assets/environments/park/materials/textures/plaster_grey_04_arm_1k.jpg")
const TEX_PLASTER_NOR := preload("res://assets/environments/park/materials/textures/plaster_grey_04_nor_gl_1k.jpg")

const TEX_CONCRETE_DIFF := preload("res://assets/environments/park/materials/textures/concrete_slab_wall_diff_1k.jpg")
const TEX_CONCRETE_ARM := preload("res://assets/environments/park/materials/textures/concrete_slab_wall_arm_1k.jpg")
const TEX_CONCRETE_NOR := preload("res://assets/environments/park/materials/textures/concrete_slab_wall_nor_gl_1k.jpg")

const TEX_METAL_DIFF := preload("res://assets/environments/park/materials/textures/metal_plate_02_diff_1k.jpg")
const TEX_METAL_ARM := preload("res://assets/environments/park/materials/textures/metal_plate_02_arm_1k.jpg")
const TEX_METAL_NOR := preload("res://assets/environments/park/materials/textures/metal_plate_02_nor_gl_1k.jpg")

const TEX_TILE_DIFF := preload("res://assets/environments/park/materials/textures/granite_tile_04_diff_2k.jpg")
const TEX_TILE_ARM := preload("res://assets/environments/park/materials/textures/granite_tile_04_arm_2k.jpg")
const TEX_TILE_NOR := preload("res://assets/environments/park/materials/textures/granite_tile_04_nor_gl_2k.jpg")

const TEX_FLOOR_DIFF := preload("res://assets/environments/park/materials/textures/worn_tile_floor_diff_1k.jpg")
const TEX_FLOOR_ARM := preload("res://assets/environments/park/materials/textures/worn_tile_floor_arm_1k.jpg")
const TEX_FLOOR_NOR := preload("res://assets/environments/park/materials/textures/worn_tile_floor_nor_gl_1k.jpg")

const TEX_SNOW_DIFF := preload("res://assets/environments/nightmare/materials/textures/nm_snow_albedo_2k.jpg")

const TEX_PAINT_DIFF := preload("res://assets/environments/prologue/materials/textures/pr_paint_albedo_1k.jpg")
const TEX_PAINT_ARM := preload("res://assets/environments/prologue/materials/textures/pr_paint_arm_1k.jpg")
const TEX_PAINT_NOR := preload("res://assets/environments/prologue/materials/textures/pr_paint_nor_gl_1k.jpg")

const TEX_BRUSHED_DIFF := preload("res://assets/environments/prologue/materials/textures/pr_brushed_albedo_1k.jpg")
const TEX_BRUSHED_ARM := preload("res://assets/environments/prologue/materials/textures/pr_brushed_arm_1k.jpg")
const TEX_BRUSHED_NOR := preload("res://assets/environments/prologue/materials/textures/pr_brushed_nor_gl_1k.jpg")

static var _cache: Dictionary = {}


static func get_material(material_name: StringName) -> Material:
	var key := StringName(material_name)
	if _cache.has(key):
		return _cache[key]
	var material := _build(key)
	_cache[key] = material
	return material


static func apply_to_scene(root: Node) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null:
				for surface in mesh_instance.mesh.get_surface_count():
					var source := mesh_instance.get_surface_override_material(surface)
					if source == null:
						source = mesh_instance.mesh.surface_get_material(surface)
					var material_name := _material_name(source)
					if material_name != &"":
						mesh_instance.set_surface_override_material(surface, get_material(material_name))
		for child in node.get_children():
			stack.append(child)


static func _material_name(material: Material) -> StringName:
	if material == null:
		return &""
	if not material.resource_name.strip_edges().is_empty():
		return StringName(material.resource_name)
	var path := material.resource_path
	if not path.is_empty():
		return StringName(path.get_file().get_basename())
	return &""


static func _build(material_name: StringName) -> StandardMaterial3D:
	match material_name:
		&"academy_white":
			return _flat(Color(0.86, 0.89, 0.92), 0.0, 0.46)
		&"academy_white_dirty":
			return _flat(Color(0.66, 0.69, 0.73), 0.0, 0.56)
		&"academy_plaster":
			return _flat(Color(0.77, 0.80, 0.83), 0.0, 0.56)
		&"academy_concrete":
			return _textured(TEX_CONCRETE_DIFF, TEX_CONCRETE_ARM, TEX_CONCRETE_NOR, Color(0.56, 0.60, 0.65), 0.0, 0.80, 0.26)
		&"academy_concrete_dark":
			return _textured(TEX_CONCRETE_DIFF, TEX_CONCRETE_ARM, TEX_CONCRETE_NOR, Color(0.25, 0.28, 0.33), 0.10, 0.72, 0.24)
		&"academy_dark":
			return _textured(TEX_METAL_DIFF, TEX_METAL_ARM, TEX_METAL_NOR, Color(0.10, 0.12, 0.15), 0.45, 0.36, 0.22)
		&"academy_metal":
			return _textured(TEX_METAL_DIFF, TEX_METAL_ARM, TEX_METAL_NOR, Color(0.34, 0.38, 0.44), 0.82, 0.30, 0.28)
		&"academy_metal_light":
			return _textured(TEX_BRUSHED_DIFF, TEX_BRUSHED_ARM, TEX_BRUSHED_NOR, Color(0.70, 0.74, 0.78), 0.72, 0.26, 0.34)
		&"academy_red":
			return _textured(TEX_PAINT_DIFF, TEX_PAINT_ARM, TEX_PAINT_NOR, Color(0.55, 0.055, 0.060), 0.28, 0.40, 0.22)
		&"academy_red_dark":
			return _textured(TEX_PAINT_DIFF, TEX_PAINT_ARM, TEX_PAINT_NOR, Color(0.24, 0.025, 0.030), 0.22, 0.48, 0.20)
		&"academy_glass":
			return _glass(Color(0.012, 0.020, 0.030, 0.52), 0.85, 0.10, 0.46)
		&"academy_glass_clear":
			return _glass(Color(0.20, 0.30, 0.38, 0.18), 0.18, 0.05, 0.25)
		&"academy_snow":
			return _textured(TEX_SNOW_DIFF, null, null, Color(0.88, 0.92, 0.96), 0.0, 0.90, 0.18)
		&"academy_tile":
			return _flat(Color(0.60, 0.63, 0.67), 0.04, 0.36)
		&"academy_tile_wet":
			return _flat(Color(0.25, 0.29, 0.34), 0.14, 0.12)
		&"academy_wood":
			return _flat(Color(0.26, 0.17, 0.10), 0.0, 0.72)
		&"academy_wood_light":
			return _flat(Color(0.48, 0.35, 0.22), 0.0, 0.66)
		&"academy_fabric":
			return _flat(Color(0.13, 0.15, 0.19), 0.0, 0.94)
		&"academy_fabric_blue":
			return _flat(Color(0.10, 0.18, 0.32), 0.0, 0.92)
		&"academy_hollow":
			return _flat(Color(0.62, 0.58, 0.52), 0.0, 0.88)
		&"academy_topiary":
			return _flat(Color(0.070, 0.145, 0.105), 0.0, 0.84)
		&"academy_grid":
			return _flat(Color(0.38, 0.41, 0.44), 0.0, 0.72)
		&"academy_skyline":
			return _emissive(Color(0.040, 0.045, 0.050), Color(0.95, 0.45, 0.18), 0.9)
		&"academy_lamp":
			return _emissive(Color(0.95, 0.84, 0.64), Color(1.0, 0.74, 0.42), 2.4)
		&"academy_lamp_cold":
			return _emissive(Color(0.72, 0.86, 1.0), Color(0.48, 0.76, 1.0), 2.2)
		&"academy_screen":
			return _emissive(Color(0.02, 0.05, 0.08), Color(0.20, 0.58, 0.82), 1.8)
		&"academy_screen_warm":
			return _emissive(Color(0.08, 0.05, 0.03), Color(1.0, 0.58, 0.24), 1.8)
		&"academy_alarm":
			return _emissive(Color(0.22, 0.012, 0.008), Color(0.90, 0.02, 0.01), 2.2)
		&"academy_dome":
			var dome := _glass(Color(0.28, 0.48, 0.70, 0.055), 0.0, 0.10, 0.18)
			dome.emission_enabled = true
			dome.emission = Color(0.18, 0.38, 0.62)
			dome.emission_energy_multiplier = 0.35
			dome.cull_mode = BaseMaterial3D.CULL_DISABLED
			return dome
		_:
			return _flat(Color(0.5, 0.5, 0.5), 0.0, 0.8)


static func _textured(
	diffuse: Texture2D,
	arm: Texture2D,
	normal: Texture2D,
	tint: Color,
	metallic: float,
	roughness: float,
	uv_scale: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "academy_pbr"
	material.albedo_color = tint
	material.albedo_texture = diffuse
	material.metallic = metallic
	material.roughness = roughness
	if arm != null:
		material.metallic_texture = arm
		material.metallic_texture_channel = 2
		material.roughness_texture = arm
		material.roughness_texture_channel = 1
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 0.85
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func _flat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _glass(color: Color, metallic: float, roughness: float, rim: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.metallic = metallic
	material.roughness = roughness
	material.rim_enabled = true
	material.rim = rim
	material.rim_tint = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _emissive(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
