class_name SceneAudioProfile
extends Resource
## Data-only description of the audio layer for one location.
##
## M1 post-Nightmare scenes are owned by A03. A09 therefore never edits those
## scenes: SceneAudioDirector applies this profile at runtime, assigns cues to
## the existing Interactable nodes and listens to existing TriggerZone/flag
## signals.

@export var id: StringName = &""
@export var scene_path: String = ""
@export var location_id: StringName = &""
@export var music_id: StringName = &""
@export var ambience_id: StringName = &""
@export var music_intensity := 0.45
@export var reverb_profile: StringName = &"outdoor"
@export var music_fade := 0.5
@export var ambience_fade := 0.7
@export var loops: Array[SceneAudioEvent] = []
@export var enter_events: Array[SceneAudioEvent] = []
@export var flag_events: Array[SceneAudioEvent] = []
@export var trigger_events: Array[SceneAudioEvent] = []
## interaction_id -> cue_id. Interactable owns playback; this only changes data.
@export var interactions: Dictionary = {}
