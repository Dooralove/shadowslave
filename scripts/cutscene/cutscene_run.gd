class_name CutsceneRun
extends RefCounted
## Состояние одного запуска кат-сцены.

@warning_ignore("unused_signal")
signal finished(result: int)

var definition: CutsceneDefinition
var stage: CutsceneStage
var script_node: CutsceneScript
var context: CutsceneContext
var camera: CutsceneCamera3D
var ui: CutsceneUI
var player: SunnyController
var scene: Node

var state := CutsceneTypes.State.PREPARING
var result := -1
var elapsed := 0.0
var current_shot: StringName = &""
var cancelled := false
var finished_emitted := false
var abort_reason := ""

var ui_snapshot: Dictionary = {}
var player_snapshot: Dictionary = {}
var actors: Dictionary = {}
var actor_snapshots: Dictionary = {}
var prop_snapshots: Dictionary = {}
