class_name AmbienceZone
extends Resource
## Data-driven ambience zone: two loop layers plus optional random details.

@export var id: StringName = &""
@export var bed: AudioStream
@export var mid: AudioStream
@export var details: Array[AudioStream] = []
@export var bed_db := -14.0
@export var mid_db := -20.0
@export var detail_db := -18.0
