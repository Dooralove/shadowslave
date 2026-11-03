class_name SceneVfxProfile
extends Resource
## Data-only VFX layer for one location. No gameplay scene is edited by A09.

@export var id: StringName = &""
@export var scene_path: String = ""
@export var location_id: StringName = &""
@export var loops: Array[SceneVfxEvent] = []
@export var enter_effects: Array[SceneVfxEvent] = []
@export var flag_effects: Array[SceneVfxEvent] = []
@export var trigger_effects: Array[SceneVfxEvent] = []
