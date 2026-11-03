class_name AudioOcclusion
extends RefCounted
## Single-ray occlusion approximation for 3D SFX. The listener and source
## positions are world-space. A hit between them applies a low-pass and gain.

const CLEAR_CUTOFF := 20000.0
const CLEAR_DB := 0.0


static func evaluate(
	world: World3D,
	listener: Vector3,
	source: Vector3,
	mask: int = 1,
	exclude: Array[RID] = []
) -> Dictionary:
	if world == null:
		return _clear()
	var distance := listener.distance_to(source)
	if distance < 0.05:
		return _clear()
	var query := PhysicsRayQueryParameters3D.create(listener, source, mask)
	query.exclude = exclude
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return _clear()
	var hit_position: Vector3 = hit["position"]
	var fraction := listener.distance_to(hit_position) / distance
	var severity := clampf(1.0 - fraction, 0.25, 1.0)
	return {
		"occluded": true,
		"cutoff": lerpf(9000.0, 2200.0, severity),
		"filter_db": -14.0 * severity,
		"hit": hit,
	}


static func _clear() -> Dictionary:
	return {
		"occluded": false,
		"cutoff": CLEAR_CUTOFF,
		"filter_db": CLEAR_DB,
		"hit": {},
	}
