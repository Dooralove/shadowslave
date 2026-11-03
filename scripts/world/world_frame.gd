@tool
class_name WorldFrame
extends RefCounted
## Reusable distant-world framing kit.
##
## These helpers build cheap, texture-free horizon geometry: ridge rings,
## far-sea planes, city skylines and spire clusters. They are deliberately
## unshaded and fog-disabled, with the atmospheric perspective baked into
## vertex colours or a manual haze mix. This keeps a location from ending in
## an empty horizon without paying for another fog pass or texture set.
##
## The helpers never create collision and never touch gameplay nodes.

const RIDGE_SHADER := preload("res://assets/shaders/world_frame_silhouette.gdshader")
const CITY_SHADER := preload("res://assets/shaders/world_frame_city.gdshader")
const SEA_SHADER := preload("res://assets/shaders/world_frame_sea.gdshader")
const SOLID_SHADER := preload("res://assets/shaders/world_frame_solid.gdshader")


## A 360-degree jagged ridge. The base sits at `base_y`, the top is a
## deterministic noise profile between `height_min` and `height_max`.
## Colours are blended east-to-west, so a single ring can carry the pale
## eastern reef haze and the dark western storm rim.
static func ridge_ring(
	center: Vector3,
	radius: float,
	segments: int,
	base_y: float,
	height_min: float,
	height_max: float,
	east_horizon: Color,
	east_ridge: Color,
	west_horizon: Color,
	west_ridge: Color,
	seed_value: int,
	ring_name := "HorizonRidge"
) -> MeshInstance3D:
	var safe_segments := maxi(12, segments)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var count := safe_segments + 1
	for i in count:
		var angle := TAU * float(i) / float(safe_segments)
		var profile := _ridge_profile(angle, seed_value)
		var height := lerpf(height_min, height_max, profile)
		var x := center.x + cos(angle) * radius
		var z := center.z + sin(angle) * radius
		# 0 at west, 1 at east. The western storm rim gets the darker palette.
		var east_mix := (1.0 - cos(angle - PI)) * 0.5
		# Vertex colours are linear in a custom shader; author the palette in
		# sRGB and convert so the tonemapped result matches the sky.
		var horizon := west_horizon.lerp(east_horizon, east_mix).srgb_to_linear()
		var ridge := west_ridge.lerp(east_ridge, east_mix).srgb_to_linear()
		var inward := Vector3(-cos(angle), 0.0, -sin(angle))
		vertices.append(Vector3(x, base_y, z))
		normals.append(inward)
		colors.append(horizon)
		vertices.append(Vector3(x, base_y + height, z))
		normals.append(inward)
		colors.append(ridge)
	for i in safe_segments:
		var bottom := i * 2
		var top := bottom + 1
		var next_bottom := bottom + 2
		var next_top := bottom + 3
		indices.append_array([bottom, next_bottom, next_top, bottom, next_top, top])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = ring_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = RIDGE_SHADER
	instance.material_override = material
	instance.set_meta(&"world_frame", true)
	return instance


## A large, cheap sea plane that fades from the playable water colour to the
## horizon haze. Put it below the detailed tide plane so it only fills the
## distance.
static func far_sea(
	center: Vector3,
	size: float,
	near_color: Color,
	far_color: Color,
	plane_name := "FarSea",
	fade_start := 180.0,
	fade_end := 1600.0
) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var instance := MeshInstance3D.new()
	instance.name = plane_name
	instance.mesh = plane
	instance.position = center
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SEA_SHADER
	material.set_shader_parameter("near_color", near_color)
	material.set_shader_parameter("far_color", far_color)
	material.set_shader_parameter("fade_start", fade_start)
	material.set_shader_parameter("fade_end", fade_end)
	instance.material_override = material
	instance.set_meta(&"world_frame", true)
	return instance


## A ring of distant building blocks. `gap_center` / `gap_width` leave a
## corridor open for the road or approach axis. Blocks are untextured boxes
## with a world-space window grid and manual distance haze.
static func city_skyline(
	parent: Node3D,
	center: Vector3,
	base_y: float,
	radius_min: float,
	radius_max: float,
	count: int,
	min_height: float,
	max_height: float,
	palette: Array,
	seed_value: int,
	gap_center := 0.0,
	gap_width := 0.0,
	skyline_name := "CitySkyline",
	haze_color := Color(0.42, 0.47, 0.54),
	haze_start := 110.0,
	haze_end := 900.0,
	window_color := Color(1.0, 0.82, 0.55),
	window_density := 0.38,
	window_scale := 3.2,
	min_footprint := 7.0,
	max_footprint := 22.0,
	haze_amount := 0.86,
	cast_shadows := false
) -> MultiMeshInstance3D:
	var safe_count := maxi(1, count)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = safe_count
	var placed := 0
	for i in safe_count:
		var angle := TAU * float(i) / float(safe_count) + _hash01(seed_value + i * 3) * 0.12
		if gap_width > 0.0 and absf(wrapf(angle - gap_center, -PI, PI)) < gap_width * 0.5:
			continue
		var radius := lerpf(radius_min, radius_max, _hash01(seed_value + i * 7 + 1))
		var height := lerpf(min_height, max_height, _hash01(seed_value + i * 11 + 2))
		var footprint := lerpf(min_footprint, max_footprint, _hash01(seed_value + i * 13 + 3))
		var yaw := _hash01(seed_value + i * 17 + 4) * TAU
		var position := Vector3(
			center.x + cos(angle) * radius,
			base_y + height * 0.5,
			center.z + sin(angle) * radius
		)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(footprint, height, footprint))
		multimesh.set_instance_transform(placed, Transform3D(basis, position))
		var tint: Color = palette[i % palette.size()] if not palette.is_empty() else Color(0.07, 0.08, 0.10)
		multimesh.set_instance_color(placed, tint.srgb_to_linear())
		placed += 1
	multimesh.instance_count = placed
	var instance := MultiMeshInstance3D.new()
	instance.name = skyline_name
	instance.multimesh = multimesh
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	var material := ShaderMaterial.new()
	material.shader = CITY_SHADER
	material.set_shader_parameter("building_color", palette[0] if not palette.is_empty() else Color(0.055, 0.065, 0.080))
	material.set_shader_parameter("window_color", window_color)
	material.set_shader_parameter("window_density", window_density)
	material.set_shader_parameter("window_scale", window_scale)
	material.set_shader_parameter("haze_color", haze_color)
	material.set_shader_parameter("haze_start", haze_start)
	material.set_shader_parameter("haze_end", haze_end)
	material.set_shader_parameter("haze_amount", haze_amount)
	instance.material_override = material
	instance.set_meta(&"world_frame", true)
	parent.add_child(instance)
	return instance


## A cluster of tapered spires: distant sea stacks, the Crimson Spire, or a
## far reef crown. Uses a handful of low-poly cones with a flat haze mix.
static func spire_cluster(
	parent: Node3D,
	center: Vector3,
	base_y: float,
	height: float,
	count: int,
	base_color: Color,
	haze_color: Color,
	haze_mix := 0.35,
	seed_value := 1,
	cluster_name := "SpireCluster",
	radius := 18.0
) -> Node3D:
	var root := Node3D.new()
	root.name = cluster_name
	root.position = Vector3.ZERO
	root.set_meta(&"world_frame", true)
	parent.add_child(root)
	var material := ShaderMaterial.new()
	material.shader = SOLID_SHADER
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("haze_color", haze_color)
	material.set_shader_parameter("haze_mix", haze_mix)
	# One MultiMesh for the whole cluster. A distant crown is 4-14 spikes;
	# separate MeshInstances would cost 4-14 draw calls for no visual gain.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 6
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cone
	var spike_count := maxi(1, count)
	multimesh.instance_count = spike_count
	for i in spike_count:
		var angle := TAU * float(i) / float(spike_count) + _hash01(seed_value + i) * 0.9
		var distance := radius * (0.25 + _hash01(seed_value + i * 3) * 0.75)
		var spike_height := height * (0.55 + _hash01(seed_value + i * 5) * 0.65)
		var spike_radius := maxf(2.0, height * (0.06 + _hash01(seed_value + i * 7) * 0.05))
		var basis := Basis(Vector3.UP, _hash01(seed_value + i * 11) * TAU).scaled(
			Vector3(spike_radius, spike_height, spike_radius)
		)
		var position := Vector3(
			center.x + cos(angle) * distance,
			base_y + spike_height * 0.5,
			center.z + sin(angle) * distance
		)
		multimesh.set_instance_transform(i, Transform3D(basis, position))
	var instance := MultiMeshInstance3D.new()
	instance.name = StringName("%sMesh" % cluster_name)
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	return root


## A low, jagged reef band on the north and south horizons. One MultiMesh and
## one material keep it to a single draw call; the east/west corridor is left
## open so the band never sits inside the playable route.
static func reef_band(
	parent: Node3D,
	center: Vector3,
	base_y: float,
	radius_min: float,
	radius_max: float,
	count: int,
	min_height: float,
	max_height: float,
	base_color: Color,
	haze_color: Color,
	haze_mix := 0.45,
	seed_value := 1,
	band_name := "ReefBand"
) -> MultiMeshInstance3D:
	var safe_count := maxi(1, count)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 5
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cone
	multimesh.instance_count = safe_count
	var placed := 0
	for i in safe_count:
		var angle := TAU * float(i) / float(safe_count) + _hash01(seed_value + i * 3) * 0.18
		# North/south sectors only. The playable corridor runs east-west and
		# is ~300 m wide in the west, so keep the band well outside it.
		if absf(sin(angle)) < 0.72:
			continue
		var radius := lerpf(radius_min, radius_max, _hash01(seed_value + i * 7 + 1))
		var height := lerpf(min_height, max_height, _hash01(seed_value + i * 11 + 2))
		var width := height * lerpf(0.12, 0.26, _hash01(seed_value + i * 13 + 3))
		var position := Vector3(
			center.x + cos(angle) * radius,
			base_y + height * 0.5,
			center.z + sin(angle) * radius
		)
		var basis := Basis(Vector3.UP, _hash01(seed_value + i * 17 + 4) * TAU).scaled(Vector3(width, height, width))
		multimesh.set_instance_transform(placed, Transform3D(basis, position))
		placed += 1
	multimesh.instance_count = placed
	var instance := MultiMeshInstance3D.new()
	instance.name = band_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SOLID_SHADER
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("haze_color", haze_color)
	material.set_shader_parameter("haze_mix", haze_mix)
	instance.material_override = material
	instance.set_meta(&"world_frame", true)
	parent.add_child(instance)
	return instance


## A single large silhouette block. Used for the far body masses of the
## headless statue and for distant ruin walls.
static func mass_block(
	parent: Node3D,
	position: Vector3,
	size: Vector3,
	base_color: Color,
	haze_color: Color,
	haze_mix := 0.25,
	block_name := "MassBlock"
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = block_name
	instance.mesh = mesh
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SOLID_SHADER
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("haze_color", haze_color)
	material.set_shader_parameter("haze_mix", haze_mix)
	instance.material_override = material
	instance.set_meta(&"world_frame", true)
	parent.add_child(instance)
	return instance


## A single wide back breaking the water. `position.y` is the waterline; the
## dome is buried below it and only the rounded back shows. Used sparingly in
## the Black Sea to imply the giant creatures that canon mentions without
## modelling one.
static func water_fin(
	parent: Node3D,
	position: Vector3,
	width: float,
	height: float,
	depth: float,
	base_color: Color,
	haze_color: Color,
	haze_mix := 0.25,
	fin_name := "WaterFin"
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance := MeshInstance3D.new()
	instance.name = fin_name
	instance.mesh = mesh
	# Bury a quarter of the dome below the waterline, leave three quarters
	# above it. A scaled sphere reads as a back; a prism reads as a pyramid.
	instance.position = Vector3(position.x, position.y + height * 0.25, position.z)
	instance.scale = Vector3(width * 0.5, height * 0.5, depth * 0.5)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SOLID_SHADER
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("haze_color", haze_color)
	material.set_shader_parameter("haze_mix", haze_mix)
	instance.material_override = material
	instance.set_meta(&"world_frame", true)
	parent.add_child(instance)
	return instance


static func _ridge_profile(angle: float, seed_value: int) -> float:
	var s := float(seed_value)
	var value := 0.52
	value += 0.18 * sin(angle * 2.0 + s * 0.37)
	value += 0.12 * sin(angle * 5.0 - s * 0.71)
	value += 0.08 * sin(angle * 11.0 + s * 1.13)
	value += 0.05 * sin(angle * 23.0 - s * 1.77)
	value = clampf(value, 0.08, 1.0)
	return pow(value, 1.6)


static func _hash01(value: int) -> float:
	var x := sin(float(value) * 127.1 + 311.7) * 43758.5453
	return x - floor(x)
