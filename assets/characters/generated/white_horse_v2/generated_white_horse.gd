class_name GeneratedWhiteHorse
extends Node3D
## Rigged Image-to-3D white horse. Plays the native LeanHooved clips and lets
## the caravan scene tint the same mesh for the Veteran's dark horse.

const POSE_CLIPS := {
	&"idle": &"LeanHoovedIdle",
	&"walk": &"LeanHoovedWalk",
	&"trot": &"LeanHoovedTrot",
	&"run": &"LeanHoovedRun",
}
const LOOPS: Array[StringName] = [
	&"LeanHoovedIdle",
	&"LeanHoovedWalk",
	&"LeanHoovedTrot",
	&"LeanHoovedRun",
]

@export_enum("idle", "walk", "trot", "run") var pose := "idle":
	set(value):
		pose = value
		if is_inside_tree():
			_play_pose()
## Multiplied over the generated coat texture. White for the Hero's horse,
## dark brown for the Veteran's horse in caravan_site.tscn.
@export var coat_color := Color(0.86, 0.84, 0.8, 1.0):
	set(value):
		coat_color = value
		if is_inside_tree():
			_apply_coat()

var _player: AnimationPlayer
var _mesh: MeshInstance3D
var _coat_material: BaseMaterial3D


func _ready() -> void:
	_player = get_node_or_null(^"Model/AnimationPlayer") as AnimationPlayer
	_mesh = _find_mesh(self)
	_apply_coat()
	_play_pose()


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


func _apply_coat() -> void:
	if _mesh == null or _mesh.mesh == null or _mesh.mesh.get_surface_count() == 0:
		return
	if _coat_material == null:
		var source := _mesh.mesh.surface_get_material(0) as BaseMaterial3D
		if source == null:
			return
		_coat_material = source.duplicate() as BaseMaterial3D
		_mesh.set_surface_override_material(0, _coat_material)
	_coat_material.albedo_color = coat_color
	_coat_material.roughness = 0.82


func _play_pose() -> void:
	if _player == null:
		return
	for clip in LOOPS:
		var animation := _player.get_animation(clip)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
	var clip: StringName = POSE_CLIPS.get(StringName(pose), POSE_CLIPS[&"idle"])
	if not _player.has_animation(clip):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_path())
	_player.play(clip)
	_player.seek(rng.randf() * _player.current_animation_length, true)
