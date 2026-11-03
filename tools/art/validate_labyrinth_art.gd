extends Node
## A07 Stage 4 audit for the labyrinth-only art layer.

const SCENE := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"


func _ready() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		push_error("A07 labyrinth audit: scene missing")
		get_tree().quit(2)
		return
	var location := packed.instantiate() as Node3D
	add_child(location)
	await get_tree().process_frame
	await get_tree().process_frame
	var art := location.get_node_or_null(^"ArtFinal")
	if art == null:
		push_error("A07 labyrinth audit: ArtFinal missing")
		get_tree().quit(3)
		return
	var stats: Dictionary = art.call(&"shore_dressing_stats") if art.has_method(&"shore_dressing_stats") else {}
	var instances := int(stats.get("instances", 0))
	var nodes := int(stats.get("nodes", 0))
	print("A07_LABYRINTH shore_instances=%d shore_multimesh_nodes=%d" % [instances, nodes])
	var failures: Array[String] = []
	if instances < 200:
		failures.append("shore instances < 200")
	if nodes < 1 or nodes > 3:
		failures.append("shore MultiMesh node count not 1..3")
	print("A07_LABYRINTH_DONE failures=%d" % failures.size())
	for failure in failures:
		print("A07_LABYRINTH_FAIL " + failure)
	location.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)
