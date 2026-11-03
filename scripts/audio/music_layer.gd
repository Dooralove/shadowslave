class_name MusicLayer
extends Resource
## One vertical layer of a music cue. All layers of a cue are started together.

@export var layer_name: StringName = &"base"
@export var stream: AudioStream
@export var default_db := -12.0
@export var min_db := -60.0
@export var max_db := -6.0
