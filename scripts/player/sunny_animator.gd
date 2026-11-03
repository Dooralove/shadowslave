class_name SunnyAnimator
extends Node
## Выбирает анимацию Санни по его фактическому состоянию. Только визуальный слой:
## урон наносит MeleeAttack, здоровье ведёт HealthComponent, передвижение — SunnyController.
## Все клипы проигрывает один AnimationPlayer модели, поэтому кости не делят разные проигрыватели.
##
## Если в сцене назначен AnimationTree (P1/POC-Санни), аниматор использует его state machine
## и blend space. KayKit-арена без tree продолжает работать через прямой AnimationPlayer.

enum State { IDLE, WALK, RUN, JUMP, FALL, LAND, ATTACK, HIT, GUARD, DODGE, DEAD, GUARD_HIT, GUARD_BREAK, ACTION }

@export var body: SunnyController
@export var animation_player: AnimationPlayer
## Необязательный AnimationTree. Если задан, он становится единственным источником позы.
@export var animation_tree: AnimationTree
# Ссылки на компоненты задаются в сцене напрямую: _ready аниматора выполняется раньше,
# чем @onready-поля контроллера.
@export var attack: MeleeAttack
@export var health: HealthComponent
## Необязательный FootGrounder модели (P1/v3). Аниматор выключает его в прыжке/падении/смерти.
@export var foot_grounder: Node
## Необязательный GuardPoseModifier: поднимает руки в блоке поверх Sword_Idle.
@export var guard_pose: Node

@export_group("Clips")
@export var idle_clip: StringName = &"Idle"
@export var walk_clip: StringName = &"Walking_A"
@export var run_clip: StringName = &"Running_A"
@export var jump_clip: StringName = &"Jump_Start"
@export var fall_clip: StringName = &"Jump_Idle"
@export var land_clip: StringName = &"Jump_Land"
@export var attack_clip: StringName = &"1H_Melee_Attack_Slice_Horizontal"
@export var guard_clip: StringName = &"Blocking"
@export var guard_hit_clip: StringName = &"Hit_Head"
## Совместимость с CombatController: block_hit_clip — то же, что guard_hit_clip.
@export var block_hit_clip: StringName = &"Hit_Head"
@export var guard_break_clip: StringName = &"Hit_Chest"
@export var dodge_clip: StringName = &"Dodge_Backward"
@export var hit_clip: StringName = &"Hit_A"
@export var death_clip: StringName = &"Death_A"
@export var interact_clip: StringName = &"Interact"
@export var special_clip: StringName = &"Spell_Simple_Shoot"
## Дополнительные клипы для визуальной серии ударов. Первый удар всегда
## attack_clip; combo_clips[1..] играют, если следующий удар начат в окне.
@export var combo_clips: Array[StringName] = []
@export var combo_window := 0.8

@export_group("Tuning")
## Горизонтальная скорость, ниже которой персонаж считается стоящим, м/с.
@export var move_threshold := 0.3
## Время в воздухе без прыжка, после которого включается падение (сглаживает ступеньки), с.
@export var fall_delay := 0.12
@export var blend_time := 0.15
## Момент контакта в клипе атаки: максимальная скорость кисти с ножом перед корпусом,
## измерена покадрово по позе скелета, с. Клип играет с начала со скоростью, при которой
## этот момент приходится на середину окна попадания MeleeAttack.
@export var attack_contact_time := 0.4
## Через сколько секунд реакцию на урон можно прервать движением, с.
@export var hit_interrupt_time := 0.25
## Сколько держать ATTACK после окна попадания (0 — только cooldown атаки).
@export var attack_hold_time := 0.0
## Сколько держать DODGE-анимацию (0 — всю длину клипа).
@export var dodge_hold_time := 0.0
## Сколько держать LAND-анимацию (0 — всю длину клипа).
@export var land_hold_time := 0.0
## Скорость, на которую рассчитан in-place walk/jog клип. Нужна для подавления foot slide.
@export var walk_authored_speed := 2.5
## Скорость, на которую рассчитан in-place sprint клип.
@export var run_authored_speed := 3.27
## Точка blend space для walk. P1: 0.65 (Jog), v3: 0.4 (WalkClean).
@export var walk_blend := 0.65

var state := State.IDLE
var _state_time := 0.0
var _air_time := 0.0
var _guard := false
var _tree_playback: AnimationNodeStateMachinePlayback
var _tree_ready := false
var _action_clip: StringName = &""
var _action_state: StringName = &""
var _combo_index := 0
var _combo_time_left := 0.0
## Режим постановки: AnimationPlayer управляет CinematicActor, аниматор его не трогает.
## При выходе персонаж возвращается в стойку, дальше состояние выбирается как обычно.
var cinematic := false:
	set(value):
		if cinematic == value:
			return
		cinematic = value
		if animation_tree:
			animation_tree.active = not cinematic
		if not cinematic and state != State.DEAD and animation_player:
			_force(State.IDLE)
			_play(idle_clip)


func _ready() -> void:
	attack.attack_started.connect(_on_attack_started)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if foot_grounder == null and body != null:
		var found := body.find_children("FootGrounder", "Node", true, false)
		if not found.is_empty():
			foot_grounder = found[0]
	if guard_pose == null and body != null:
		var model := body.get_node_or_null("Visual/ModelPoc")
		if model != null and model.has_method(&"get_guard_pose"):
			guard_pose = model.call(&"get_guard_pose") as Node
	_prepare_loop_modes()
	_play(idle_clip)
	if animation_tree:
		_init_animation_tree.call_deferred()


func _prepare_loop_modes() -> void:
	if animation_player == null:
		return
	for clip in [idle_clip, walk_clip, run_clip, fall_clip, guard_clip]:
		if not animation_player.has_animation(clip):
			continue
		var anim := animation_player.get_animation(clip)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
	for clip in [jump_clip, land_clip, attack_clip, hit_clip, guard_hit_clip, block_hit_clip, guard_break_clip,
			dodge_clip, death_clip, interact_clip, special_clip]:
		if not animation_player.has_animation(clip):
			continue
		var anim := animation_player.get_animation(clip)
		if anim:
			anim.loop_mode = Animation.LOOP_NONE


func _init_animation_tree() -> void:
	if animation_tree == null or animation_player == null:
		return
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.active = true
	_tree_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if _tree_playback == null:
		push_warning("SunnyAnimator: AnimationTree has no state-machine playback")
		return
	_tree_playback.start(&"Locomotion")
	_set_locomotion_blend(0.0)
	_tree_ready = true


func _physics_process(delta: float) -> void:
	# Тело с выключенной физикой (диалог, постановка) стоит, где его поставили: is_on_floor()
	# у него не обновляется, и без этой поправки персонаж «падал» бы посреди сцены.
	var grounded := body.is_on_floor() or not body.is_physics_processing()
	update(delta, grounded, body.velocity)


## Переход по фактическому движению тела; вызывается каждый физический кадр.
func update(delta: float, on_floor: bool, velocity: Vector3) -> void:
	if state == State.DEAD or cinematic:
		return
	_state_time += delta
	_combo_time_left = maxf(0.0, _combo_time_left - delta)
	if _combo_time_left <= 0.0:
		_combo_index = 0
	_air_time = 0.0 if on_floor else _air_time + delta
	_update_grounding()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if _guard:
		if state in [State.GUARD_HIT, State.GUARD_BREAK]:
			var guard_reaction := guard_hit_clip if state == State.GUARD_HIT else guard_break_clip
			if _state_time < _clip_length(guard_reaction):
				return
			if state == State.GUARD_BREAK:
				_guard = false
				_enter(_movement_state(on_floor, velocity.y, horizontal_speed))
				return
		if state != State.GUARD:
			_force(State.GUARD)
			_play(guard_clip)
		return
	# Разовые анимации держатся, пока не закончатся или их не прервёт движение.
	match state:
		State.ATTACK:
			# Удар держится ровно столько, сколько идут фазы MeleeAttack.
			if attack.is_attacking():
				return
			if _state_time < attack_hold_time:
				return
		State.HIT:
			var moving := horizontal_speed > move_threshold and _state_time >= hit_interrupt_time
			if _state_time < _clip_length(hit_clip) and not moving:
				return
		State.GUARD:
			# Блок отпущен: следующий кадр выбирает движение.
			pass
		State.GUARD_HIT, State.GUARD_BREAK:
			var guard_reaction := guard_hit_clip if state == State.GUARD_HIT else guard_break_clip
			if _state_time < _clip_length(guard_reaction):
				return
		State.DODGE:
			var dodge_len := _clip_length(dodge_clip)
			if dodge_hold_time > 0.0:
				dodge_len = dodge_hold_time
			if _state_time < dodge_len:
				return
		State.LAND:
			var land_len := _clip_length(land_clip)
			if land_hold_time > 0.0:
				land_len = minf(land_len, land_hold_time)
			if on_floor and horizontal_speed <= move_threshold and _state_time < land_len:
				return
		State.JUMP:
			if not on_floor and velocity.y > 0.0 and _state_time < _clip_length(jump_clip):
				return
		State.ACTION:
			if _state_time < _clip_length(_action_clip):
				return
	_enter(_movement_state(on_floor, velocity.y, horizontal_speed))
	if state == State.WALK:
		animation_player.speed_scale = clampf(horizontal_speed / walk_authored_speed, 0.5, 1.8)
		_set_locomotion_blend(walk_blend)
	elif state == State.RUN:
		animation_player.speed_scale = clampf(horizontal_speed / run_authored_speed, 0.5, 1.8)
		_set_locomotion_blend(1.0)
	elif state == State.IDLE:
		animation_player.speed_scale = 1.0
		_set_locomotion_blend(0.0)


func _movement_state(on_floor: bool, vertical_speed: float, horizontal_speed: float) -> State:
	if not on_floor:
		if state == State.JUMP or state == State.FALL:
			return State.FALL
		if vertical_speed > 0.0 and _air_time <= fall_delay:
			return State.JUMP
		if _air_time >= fall_delay:
			return State.FALL
		# Короткий отрыв от пола (ступенька) — продолжаем наземную анимацию.
	elif state == State.JUMP or state == State.FALL:
		return State.LAND
	if horizontal_speed <= move_threshold:
		return State.IDLE
	var run_threshold := (body.walk_speed + body.sprint_speed) * 0.5
	return State.RUN if horizontal_speed > run_threshold else State.WALK


func _enter(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	_state_time = 0.0
	animation_player.speed_scale = 1.0
	match new_state:
		State.IDLE:
			_play(idle_clip)
		State.WALK:
			_play(walk_clip)
		State.RUN:
			_play(run_clip)
		State.JUMP:
			_play(jump_clip)
		State.FALL:
			_play(fall_clip)
		State.LAND:
			_play(land_clip)


func set_guard(value: bool) -> void:
	if _guard == value:
		return
	_guard = value
	_set_guard_pose(value)
	if state == State.DEAD or cinematic:
		_guard = false
		_set_guard_pose(false)
		return
	if _guard:
		_force(State.GUARD)
		_play(guard_clip)
	elif state == State.GUARD:
		_enter(State.IDLE)


func play_dodge(clip: StringName = &"") -> void:
	if state == State.DEAD or cinematic:
		return
	_guard = false
	_force(State.DODGE)
	_play(clip if clip != &"" else dodge_clip, 0.0, 0.05)


## Реакция на удар в блок: короткий flinch, после которого возвращаемся в стойку.
func play_guard_hit() -> void:
	if state == State.DEAD or cinematic:
		return
	_guard = true
	_force(State.GUARD_HIT)
	_play(_existing_clip(block_hit_clip, hit_clip), 0.0, 0.05)


## Alias, который вызывает CombatController.
func play_block_hit() -> void:
	play_guard_hit()


## Пробитие блока: guard снимается, персонаж входит в stagger-реакцию.
func play_guard_break() -> void:
	if state == State.DEAD or cinematic:
		return
	_guard = false
	_set_guard_pose(false)
	_force(State.GUARD_BREAK)
	_play(_existing_clip(guard_break_clip, hit_clip), 0.0, 0.05)


func set_block_hit_clip(clip: StringName) -> void:
	if animation_player != null and animation_player.has_animation(clip):
		block_hit_clip = clip
		guard_hit_clip = clip


func set_guard_break_clip(clip: StringName) -> void:
	if animation_player != null and animation_player.has_animation(clip):
		guard_break_clip = clip


## Уникальное сюжетное/побочное действие (взаимодействие, подношение, каст).
func play_action(clip: StringName, tree_state: StringName = &"Interact") -> bool:
	if state == State.DEAD or cinematic or not animation_player.has_animation(clip):
		return false
	_guard = false
	_action_clip = clip
	_action_state = tree_state
	_force(State.ACTION)
	_play(clip, 0.0, 0.1)
	return true


func play_interact() -> bool:
	return play_action(interact_clip, &"Interact")


func play_special() -> bool:
	return play_action(special_clip, &"Special")


func set_attack_clip(clip: StringName) -> void:
	if animation_player != null and animation_player.has_animation(clip):
		attack_clip = clip


func set_guard_clip(clip: StringName) -> void:
	if animation_player != null and animation_player.has_animation(clip):
		guard_clip = clip


func set_dodge_clip(clip: StringName) -> void:
	if animation_player != null and animation_player.has_animation(clip):
		dodge_clip = clip


func _on_attack_started() -> void:
	if state == State.DEAD or cinematic:
		return
	_guard = false
	var clip := attack_clip
	if not combo_clips.is_empty():
		if _combo_time_left > 0.0:
			_combo_index = mini(_combo_index + 1, combo_clips.size() - 1)
			var candidate := combo_clips[_combo_index]
			if animation_player.has_animation(candidate):
				clip = candidate
		else:
			_combo_index = 0
		_combo_time_left = combo_window
	_force(State.ATTACK)
	_play_attack(clip)
	animation_player.speed_scale = attack_clip_speed()


func _play_attack(clip: StringName) -> void:
	if _tree_ready and _tree_playback != null:
		_set_state_animation(&"Attack", clip)
		_tree_playback.travel(&"Attack")
		return
	animation_player.play(clip, 0.05)
	animation_player.seek(0.0, true)


## Скорость клипа атаки, при которой контакт совпадает с серединой окна попадания.
## Контакт можно задать для конкретной атаки в AttackData.contact_time; ноль означает
## использовать общий attack_contact_time (старые ресурсы и тесты не ломаются).
func attack_clip_speed() -> float:
	if attack == null or attack.stats == null:
		return 1.0
	var contact_at := attack.stats.windup_time + attack.stats.active_time * 0.5
	var contact := attack_contact_time
	# Не ссылаемся на класс AttackData напрямую: в полном прогоне Godot может
	# анализировать этот скрипт раньше регистрации пользовательского class_name.
	var stats := attack.stats
	if stats != null:
		var value: Variant = stats.get(&"contact_time")
		if value != null and float(value) > 0.0:
			contact = float(value)
	if contact_at <= 0.0:
		return 1.0
	return clampf(contact / contact_at, 0.4, 2.0)


## Сброс после respawn/телепорта: убирает застрявшую death/fall-позу и запускает idle.
## Не меняет боевые тайминги и не вызывается из обычного update().
func reset_to_idle() -> void:
	_guard = false
	_set_guard_pose(false)
	_state_time = 0.0
	_air_time = 0.0
	_combo_index = 0
	_combo_time_left = 0.0
	state = State.IDLE
	animation_player.speed_scale = 1.0
	_play(idle_clip)
	set_physics_process(true)


func _on_damaged(_amount: float) -> void:
	# Реакция не прерывает удар, чтобы анимация оставалась согласованной с окном попадания.
	if state == State.DEAD or state == State.ATTACK or cinematic:
		return
	_force(State.HIT)
	_play(hit_clip, 0.0, 0.05)


func _on_died() -> void:
	_guard = false
	_set_guard_pose(false)
	_force(State.DEAD)
	_play(death_clip, 0.0, 0.1)
	set_physics_process(false)


func _set_guard_pose(value: bool) -> void:
	if guard_pose != null and guard_pose.has_method(&"set_active"):
		guard_pose.call(&"set_active", value)
	elif guard_pose != null:
		guard_pose.set(&"active", value)


## Вход в разовое состояние с перезапуском, даже если оно уже активно.
func _force(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	animation_player.speed_scale = 1.0
	_update_grounding()


func _update_grounding() -> void:
	if foot_grounder == null:
		return
	var grounded := state in [State.IDLE, State.WALK, State.RUN, State.LAND, State.GUARD,
		State.GUARD_HIT, State.GUARD_BREAK, State.HIT, State.ATTACK, State.ACTION]
	if foot_grounder.has_method(&"set_grounded"):
		foot_grounder.call(&"set_grounded", grounded)


func _play(clip: StringName, from := 0.0, blend := -1.0) -> void:
	if _tree_ready and _tree_playback != null:
		var tree_state := _state_for_clip(clip)
		if tree_state == &"Locomotion":
			_set_locomotion_blend(_blend_for_clip(clip))
			_tree_playback.travel(&"Locomotion")
			return
		if tree_state != &"":
			_set_state_animation(tree_state, clip)
			_tree_playback.travel(tree_state)
			return
	animation_player.play(clip, blend_time if blend < 0.0 else blend)
	animation_player.seek(from, true)


func _state_for_clip(clip: StringName) -> StringName:
	if clip == idle_clip or clip == walk_clip or clip == run_clip:
		return &"Locomotion"
	if clip == jump_clip:
		return &"Jump"
	if clip == fall_clip:
		return &"Fall"
	if clip == land_clip:
		return &"Land"
	if clip == attack_clip:
		return &"Attack"
	if clip == guard_hit_clip or clip == block_hit_clip:
		return &"GuardHit"
	if clip == guard_break_clip:
		return &"GuardBreak"
	if clip == hit_clip:
		return &"Hit"
	if clip == guard_clip:
		return &"Guard"
	if clip == dodge_clip:
		return &"Dodge"
	if clip == death_clip:
		return &"Death"
	if clip == _action_clip and _action_state != &"":
		return _action_state
	return &""


func _blend_for_clip(clip: StringName) -> float:
	if clip == idle_clip:
		return 0.0
	if clip == run_clip:
		return 1.0
	return walk_blend


func _set_locomotion_blend(value: float) -> void:
	if _tree_ready and animation_tree:
		animation_tree.set("parameters/Locomotion/blend_position", value)


func _set_state_animation(tree_state: StringName, clip: StringName) -> void:
	if animation_tree == null:
		return
	var machine := animation_tree.tree_root as AnimationNodeStateMachine
	if machine == null:
		return
	var node := machine.get_node(tree_state) as AnimationNodeAnimation
	if node:
		node.animation = clip


func _existing_clip(primary: StringName, fallback: StringName) -> StringName:
	if animation_player != null and animation_player.has_animation(primary):
		return primary
	return fallback


func _clip_length(clip: StringName) -> float:
	if animation_player == null or not animation_player.has_animation(clip):
		return 0.0
	return animation_player.get_animation(clip).length
