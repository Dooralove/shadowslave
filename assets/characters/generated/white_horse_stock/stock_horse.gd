class_name StockHorse
extends Node3D
## Clean static horse from the Sketchfab "Horse Rig" source, re-materialled
## white. No clips: it is a background/riding prop for the caravan.

@export var coat_color := Color(0.92, 0.90, 0.86, 1):
	set(value):
		coat_color = value
		if is_inside_tree():
			_apply_coat()

var _materials: Array[BaseMaterial3D] = []


func _ready() -> void:
	_apply_coat()


func _apply_coat() -> void:
	if _materials.is_empty():
		for node in find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.mesh == null:
				continue
			for surface in mesh.mesh.get_surface_count():
				var source := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
				if source == null:
					continue
				var mat := source.duplicate() as BaseMaterial3D
				mesh.set_surface_override_material(surface, mat)
				_materials.append(mat)
	for mat in _materials:
		mat.albedo_color = coat_color
		mat.roughness = 0.82
