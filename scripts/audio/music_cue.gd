class_name MusicCue
extends Resource
## A music cue made of synchronized vertical layers.

@export var id: StringName = &""
@export var bpm := 0.0
@export var key := ""
@export var layers: Array[MusicLayer] = []
