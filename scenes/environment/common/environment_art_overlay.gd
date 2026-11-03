@tool
class_name EnvironmentArtOverlay
extends Node3D
## Applies an EnvironmentArtProfile to a GreyboxLocation after its runtime
## layout exists. This node is safe to instance as a child of the location
## (A03 integration) or in an A07 preview wrapper via host_path.
##
## The overlay changes visuals only. It does not add, remove or move collision,
## Spawns, Portals, Markers, Gameplay, TideController or Generated/Collision.

@export var profile: EnvironmentArtProfile
## Optional path to the GreyboxLocation when the overlay is not its direct
## child (preview wrappers). Empty means get_parent().
@export var host_path: NodePath
@export var apply_on_ready := true

var _host: Node3D
var _applied := false
var _waiting_for_layout := false


func _ready() -> void:
	if apply_on_ready:
		call_deferred(&"_begin")


func _begin() -> void:
	if _applied:
		return
	_host = _resolve_host()
	if _host == null:
		push_warning("EnvironmentArtOverlay: no host location for %s" % get_path())
		return
	if _host.has_signal(&"layout_built"):
		if not _host.is_connected(&"layout_built", _on_layout_built):
			_host.connect(&"layout_built", _on_layout_built)
		var generated := _host.get_node_or_null(^"Generated") as Node3D
		if generated != null:
			_apply()
		else:
			_waiting_for_layout = true
		return
	# Fallback for a host that builds synchronously but has no signal.
	_apply()


func _on_layout_built() -> void:
	if _waiting_for_layout:
		_waiting_for_layout = false
	_apply()


func _resolve_host() -> Node3D:
	if not host_path.is_empty():
		return get_node_or_null(host_path) as Node3D
	var parent := get_parent()
	while parent != null:
		if parent.has_signal(&"layout_built") or parent.has_node(^"Generated"):
			return parent as Node3D
		parent = parent.get_parent()
	return get_parent() as Node3D


func _apply() -> void:
	if _applied or _host == null or profile == null:
		return
	if _host.get_node_or_null(^"Generated") == null:
		return
	_applied = true
	_apply_environment()
	_apply_key_light()
	_hide_generated_visuals()
	_apply_material_swaps()
	_apply_water()
	set_meta(&"art_profile_applied", true)


func _apply_environment() -> void:
	if not profile.apply_environment or profile.environment == null:
		return
	var world_env := _host.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if world_env == null:
		return
	var env := profile.environment.duplicate(true) as Environment
	if env == null:
		return
	if profile.exposure >= 0.0:
		env.tonemap_exposure = profile.exposure
	if profile.glow_intensity >= 0.0:
		env.glow_enabled = true
		env.glow_intensity = profile.glow_intensity
	if profile.fog_density >= 0.0:
		env.fog_enabled = true
		env.fog_density = profile.fog_density
	if profile.fog_light_color.a > 0.0:
		env.fog_light_color = profile.fog_light_color
	if profile.fog_light_energy >= 0.0:
		env.fog_light_energy = profile.fog_light_energy
	world_env.environment = env


func _apply_key_light() -> void:
	if not profile.override_key_light:
		return
	var light := _host.get_node_or_null(NodePath(profile.key_light_name)) as DirectionalLight3D
	if light == null:
		return
	light.rotation_degrees = profile.key_light_rotation_degrees
	light.light_color = profile.key_light_color
	light.light_energy = profile.key_light_energy
	light.shadow_enabled = profile.key_light_shadow


func _hide_generated_visuals() -> void:
	if profile.hide_original_lights:
		var generated_lights := _host.get_node_or_null(^"Generated/Lights") as Node3D
		if generated_lights != null:
			generated_lights.visible = false
	for prefix in profile.hide_name_prefixes:
		if prefix.is_empty():
			continue
		for node in _visual_nodes():
			if String(node.name).begins_with(prefix):
				node.visible = false
	for fragment in profile.hide_name_contains:
		if fragment.is_empty():
			continue
		for node in _visual_nodes():
			if String(node.name).contains(fragment):
				node.visible = false


func _visual_nodes() -> Array[VisualInstance3D]:
	var result: Array[VisualInstance3D] = []
	for root_path in [^"Generated/Structure", ^"Generated/Props", ^"Generated/Visual", ^"Generated/Lights"]:
		var root := _host.get_node_or_null(root_path)
		if root == null:
			continue
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is VisualInstance3D:
				result.append(node as VisualInstance3D)
			for child in node.get_children():
				stack.append(child)
	return result


func _apply_material_swaps() -> void:
	if profile.material_swaps.is_empty():
		return
	for node in _all_mesh_instances(_host):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null:
			continue
		var override := mesh_instance.material_override
		if override != null:
			var swapped := _material_for(override.resource_path, String(mesh_instance.name))
			if swapped != null:
				mesh_instance.material_override = swapped
				continue
			# A ShaderMaterial override can still carry a stable resource_name.
			if override.resource_name != "":
				swapped = _material_for(override.resource_name, String(mesh_instance.name))
				if swapped != null:
					mesh_instance.material_override = swapped
					continue
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var surface_material := mesh_instance.get_surface_override_material(surface)
			if surface_material == null:
				surface_material = mesh_instance.mesh.surface_get_material(surface)
			if surface_material == null:
				continue
			var swapped := _material_for(surface_material.resource_path, String(mesh_instance.name))
			if swapped == null and surface_material.resource_name != "":
				swapped = _material_for(surface_material.resource_name, String(mesh_instance.name))
			if swapped != null:
				mesh_instance.set_surface_override_material(surface, swapped)


func _material_for(material_key: String, node_name: String) -> Material:
	for swap in profile.material_swaps:
		if swap != null and swap.matches(material_key, node_name):
			return swap.material
	return null


func _apply_water() -> void:
	if profile.water_material == null:
		return
	for node in _all_mesh_instances(_host):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null:
			continue
		var node_name := String(mesh_instance.name)
		var matches := false
		for fragment in profile.water_name_contains:
			if not fragment.is_empty() and node_name.contains(fragment):
				matches = true
				break
		if matches:
			mesh_instance.material_override = profile.water_material


func _all_mesh_instances(root: Node) -> Array:
	var result: Array = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			result.append(node)
		for child in node.get_children():
			stack.append(child)
	return result
