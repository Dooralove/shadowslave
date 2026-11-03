@tool
class_name EnvironmentArtPreview
extends Node3D
## Dev-only wrapper: loads a greybox location and its A07 art scene at runtime.
##
## This exists so A07 can capture/inspect its art before A03 adds the
## ArtOverlay child to the shipping location scene. It is not used by the
## gameplay flow and does not modify A03-owned scenes.

@export_file("*.tscn") var location_scene_path := ""
@export_file("*.tscn") var art_scene_path := ""
@export var location_node_name := "Location"


func _ready() -> void:
	if location_scene_path.is_empty() or art_scene_path.is_empty():
		push_warning("EnvironmentArtPreview: location_scene_path/art_scene_path not set")
		return
	var location_scene := load(location_scene_path) as PackedScene
	var art_scene := load(art_scene_path) as PackedScene
	if location_scene == null or art_scene == null:
		push_warning("EnvironmentArtPreview: failed to load preview scenes")
		return
	var location := location_scene.instantiate() as Node3D
	location.name = location_node_name
	add_child(location)
	var art := art_scene.instantiate() as Node3D
	art.name = "ArtOverlay"
	art.set("host_path", NodePath("../" + location_node_name))
	add_child(art)
