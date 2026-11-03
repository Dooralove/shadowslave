class_name SceneAudioEvent
extends Resource
## One cue in a scene audio profile.
##
## Positions are local to the scene root. A loop event is materialized as a
## dedicated AudioStreamPlayer3D because SfxPool intentionally rejects loops;
## one-shot events go through AudioDirector.play_sfx().

@export var cue_id: StringName = &""
@export var position := Vector3.ZERO
@export var rotation_y := 0.0
@export var volume_db := 0.0
@export var delay := 0.0
@export var loop := false
@export var max_distance := 0.0
@export var unit_size := 0.0
@export var caption := ""
## Re-apply a flag event when a save loads into the scene with that flag set.
@export var persistent := false
## Optional event filters used by flag_events / trigger_events.
@export var flag: StringName = &""
@export var trigger: StringName = &""
