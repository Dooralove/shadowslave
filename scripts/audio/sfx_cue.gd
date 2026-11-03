class_name SfxCue
extends Resource
## One sound effect event. Multiple streams are variations of the same sound.

enum Priority { LOW, MEDIUM, HIGH, CRITICAL }

@export var id: StringName = &""
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export var priority: Priority = Priority.MEDIUM
@export var volume_db := 0.0
@export var pitch_min := 0.97
@export var pitch_max := 1.03
@export var cooldown := 0.0
@export var max_instances := 4
@export var spatial := true
@export var max_distance := 60.0
@export var unit_size := 6.0
@export var loop := false
@export var caption := ""
