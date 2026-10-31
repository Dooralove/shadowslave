@tool
class_name Mannequin
extends Node3D
## Временный NPC: типовая анимированная модель (MakeHuman + анимации Quaternius UAL) по архетипу.
## Заменяется моделью конкретного персонажа без изменения сценария: постановки двигают этот узел,
## а не модель внутри.

const MODELS := {
	&"townsman": preload("res://assets/characters/placeholders/humans/townsman.glb"),
	&"townswoman": preload("res://assets/characters/placeholders/humans/townswoman.glb"),
	&"police": preload("res://assets/characters/placeholders/humans/police.glb"),
	&"slave": preload("res://assets/characters/placeholders/humans/slave.glb"),
	&"knight": preload("res://assets/characters/placeholders/humans/knight.glb"),
}
const ANIMATIONS := preload("res://assets/characters/sunny_realistic_poc/animations/ual_standard.glb")
## Стойка «Idle» из UAL — полуприсед с широко расставленными ногами; спокойная стойка снята для Санни.
const RELAXED_IDLE := preload("res://assets/characters/sunny_realistic_poc/animations/sunny_idle_relaxed.glb")
const PostureOffset := preload("res://assets/characters/sunny_realistic_poc/posture_offset_modifier.gd")
## Поза -> клип UAL. «dead» и «ride» замирают на последнем кадре / играют сидя.
const POSE_CLIPS := {
	&"idle": &"Idle_Relaxed",
	&"talk": &"Idle_Talking",
	&"walk": &"Walk",
	&"guard": &"Sword_Idle",
	&"torch": &"Idle_Torch",
	&"kneel": &"Fixing_Kneeling",
	&"sit": &"Sitting_Idle",
	&"ride": &"Sitting_Idle",
	&"dead": &"Death01",
}
## Корень всадника стоит на высоте седла (как у прежних заглушек ~0,85–0,9 м над землёй);
## модель опускается так, чтобы таз в сидячей позе лёг на седло лошади-заглушки.
const RIDE_OFFSET := Vector3(0, -0.22, 0.1)

@export_enum("townsman", "townswoman", "police", "slave", "knight") var archetype := "townsman":
	set(value):
		archetype = value
		if is_inside_tree():
			_build()
@export_enum("idle", "talk", "walk", "guard", "torch", "kneel", "sit", "ride", "dead") var pose := "idle":
	set(value):
		pose = value
		if is_inside_tree():
			_play_pose()
## Множитель роста относительно ~1,75 м.
@export var height_scale := 1.0
## Ширина фигуры. Действует вполовину: модель не должна расплываться, как прежняя капсула.
@export var width_scale := 1.0

## Общая для всех заглушек копия библиотеки UAL с зацикленными клипами поз: исходную библиотеку
## делит с ними Санни, её не трогаем.
static var _library: AnimationLibrary

var _model: Node3D
var _player: AnimationPlayer


static func _looped_library() -> AnimationLibrary:
	if _library == null:
		_library = AnimationLibrary.new()
		for clip: StringName in POSE_CLIPS.values():
			if _library.has_animation(clip):
				continue
			var source := RELAXED_IDLE if RELAXED_IDLE.has_animation(clip) else ANIMATIONS
			var animation := (source.get_animation(clip) as Animation).duplicate() as Animation
			if clip != POSE_CLIPS[&"dead"]:
				animation.loop_mode = Animation.LOOP_LINEAR
			_library.add_animation(clip, animation)
	return _library


func _ready() -> void:
	_build()


func _build() -> void:
	if _model:
		_model.free()
	_model = (MODELS[StringName(archetype)] as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	# Модели glTF смотрят в +Z, а сценарии считают лицом -Z (как «Facing» у прежней заглушки).
	_model.rotation.y = PI
	# Рост и ширина — на модели, а не на корне: корень остаётся в распоряжении постановок.
	var width := 1.0 + (width_scale - 1.0) * 0.5
	_model.scale = Vector3(width, height_scale, width)
	add_child(_model, false, Node.INTERNAL_MODE_FRONT)
	# Та же поправка осанки, что у Санни: после ретаргетинга UAL на MakeHuman спина и шея завалены вперёд.
	var skeleton := _model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	skeleton.add_child(PostureOffset.new())
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	_model.add_child(_player)
	_player.root_node = _player.get_path_to(_model)
	_player.add_animation_library(&"", _looped_library())
	_play_pose()


func _play_pose() -> void:
	if _player == null:
		return
	var key := StringName(pose)
	_model.position = RIDE_OFFSET if key == &"ride" else Vector3.ZERO
	var clip: StringName = POSE_CLIPS[key]
	var animation := _player.get_animation(clip)
	if key == &"dead":
		_player.play(clip)
		_player.seek(animation.length - 0.01, true)
		_player.pause()
		return
	# Толпа не должна дышать в такт: случайная фаза и чуть разный темп.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_path()) if is_inside_tree() else 0
	_player.play(clip)
	_player.seek(rng.randf() * animation.length, true)
	_player.speed_scale = rng.randf_range(0.9, 1.1)


## Модель с анимацией; для постановок, которым нужен AnimationPlayer (например, CinematicActor).
func get_animation_player() -> AnimationPlayer:
	return _player
