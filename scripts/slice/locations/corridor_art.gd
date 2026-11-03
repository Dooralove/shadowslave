extends Node3D
## Visual-only overlay for the containment corridor and observation post.
##
## The base `containment_room.tscn` keeps its CSG collision boxes. Imported
## prologue modules bring their own StaticBody3D children; this script disables
## those so the overlay cannot duplicate or alter the original collision.

func _ready() -> void:
	for body in find_children("*", "StaticBody3D", true, false):
		if body is StaticBody3D:
			var static_body := body as StaticBody3D
			static_body.collision_layer = 0
			static_body.collision_mask = 0
			static_body.set_meta(&"art_collision_disabled", true)
