class_name OneShotVfx
extends RefCounted
## Instantiates a short-lived particle scene at a world position.
##
## The helper is deliberately signal-friendly: gameplay code calls it from
## hit/died/interacted handlers, never from a per-frame timer. The node frees
## itself after the longest particle lifetime, so repeated combat events do not
## leak scene nodes.

const DEFAULT_LIFETIME := 2.0


static func spawn(scene_path: String, position: Vector3, rotation_y := 0.0, scale := 1.0) -> Node3D:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("OneShotVfx: missing scene %s" % scene_path)
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return null
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	host.add_child(inst)
	inst.global_position = position
	inst.rotation.y = rotation_y
	inst.scale = Vector3.ONE * scale
	var lifetime := DEFAULT_LIFETIME
	for particle in inst.find_children("*", "GPUParticles3D", true, false):
		var emitter := particle as GPUParticles3D
		if emitter == null:
			continue
		emitter.restart()
		emitter.emitting = true
		lifetime = maxf(lifetime, emitter.lifetime + 0.25)
	var timer := tree.create_timer(lifetime)
	timer.timeout.connect(inst.queue_free)
	return inst


static func spawn_ichor(position: Vector3, rotation_y := 0.0) -> Node3D:
	return spawn("res://scenes/environment/vfx/impact_ichor.tscn", position, rotation_y)


static func spawn_dust(position: Vector3, rotation_y := 0.0) -> Node3D:
	return spawn("res://scenes/environment/vfx/impact_dust.tscn", position, rotation_y)


static func spawn_death(position: Vector3, rotation_y := 0.0) -> Node3D:
	return spawn("res://scenes/environment/vfx/death_carapace.tscn", position, rotation_y)


static func spawn_tide_spray(position: Vector3, rotation_y := 0.0) -> Node3D:
	return spawn("res://scenes/environment/vfx/tide_spray.tscn", position, rotation_y)
