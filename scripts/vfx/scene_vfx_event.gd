class_name SceneVfxEvent
extends Resource
## One particle scene instance in a SceneVfxProfile.
##
## Positions are local to the active scene. A loop stays alive until the scene
## changes; a one-shot is released after the longest particle lifetime.

@export var scene: PackedScene
@export var position := Vector3.ZERO
@export var rotation_y := 0.0
@export var scale := 1.0
@export var delay := 0.0
@export var loop := false
@export var attach_to: NodePath
## Re-apply a persistent visual state when loading a save in this scene.
@export var persistent := false
## Optional event filters used by flag_effects / trigger_effects.
@export var flag: StringName = &""
@export var trigger: StringName = &""
