@tool
class_name EnvironmentMaterialSwap
extends Resource
## One art-directed material replacement for a greybox/blockout material.
##
## Matching is intentionally path based: GreyboxLocation assigns
## material_override from resources/locations/post_nightmare/materials/*.tres,
## so a suffix such as "concrete_cold.tres" is stable across scenes. A node
## name filter is available for GLB props whose imported material path is not
## stable.

@export var match_path_suffix := ""
@export var match_node_name_contains := ""
@export var material: Material


func matches(material_path: String, node_name: String) -> bool:
	if material == null:
		return false
	if not match_path_suffix.is_empty() and not material_path.ends_with(match_path_suffix):
		return false
	if not match_node_name_contains.is_empty() and not node_name.contains(match_node_name_contains):
		return false
	return not match_path_suffix.is_empty() or not match_node_name_contains.is_empty()
