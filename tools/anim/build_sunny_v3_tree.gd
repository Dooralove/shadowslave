extends SceneTree
## Builds the native-clip AnimationTree for the generated Sunny v3 model.
## Run: godot --headless --path . -s tools/anim/build_sunny_v3_tree.gd

const OUT := "res://resources/characters/sunny_v3_animation_tree.tres"


func _initialize() -> void:
	var sm := AnimationNodeStateMachine.new()
	sm.resource_name = "SunnyV3AnimationTree"

	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.resource_name = "Locomotion"
	locomotion.min_space = 0.0
	locomotion.max_space = 1.0
	locomotion.add_blend_point(_anim(&"HumanStandingIdle"), 0.0, -1, &"Idle")
	locomotion.add_blend_point(_anim(&"WalkClean"), 0.4, -1, &"Walk")
	locomotion.add_blend_point(_anim(&"HumanSprintLoop"), 1.0, -1, &"Sprint")
	sm.add_node(&"Locomotion", locomotion, Vector2(0, 0))

	_add_state(sm, &"Jump", &"HumanInplaceJumpL", Vector2(360, -240))
	_add_state(sm, &"Fall", &"HumanInplaceJumpL", Vector2(360, -80))
	_add_state(sm, &"Land", &"HumanLandrollR", Vector2(360, 80))
	_add_state(sm, &"Attack", &"HumanSpBoxing", Vector2(360, 240))
	_add_state(sm, &"Hit", &"HumanSpHeadHit", Vector2(360, 400))
	_add_state(sm, &"Guard", &"HumanStandingIdle", Vector2(720, -240))
	_add_state(sm, &"GuardHit", &"HumanSpHeadHit", Vector2(720, -80))
	_add_state(sm, &"GuardBreak", &"HumanSpHeadHit", Vector2(720, 80))
	_add_state(sm, &"Dodge", &"HumanRoll", Vector2(720, 240))
	_add_state(sm, &"Death", &"HumanDeath", Vector2(720, 400))
	_add_state(sm, &"Interact", &"HumanSit", Vector2(1080, -160))
	_add_state(sm, &"Special", &"HumanSpBoxing", Vector2(1080, 0))

	for state in [&"Jump", &"Fall", &"Land", &"Attack", &"Hit", &"Guard", &"GuardHit", &"GuardBreak",
			&"Dodge", &"Death", &"Interact", &"Special"]:
		_add_transition(sm, &"Locomotion", state, 0.12, AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED)
	_add_transition(sm, &"Jump", &"Fall", 0.15, AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED)
	_add_transition(sm, &"Jump", &"Land", 0.10, AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED)
	_add_transition(sm, &"Fall", &"Land", 0.10, AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED)
	_add_transition(sm, &"Fall", &"Jump", 0.15, AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED)
	_add_transition(sm, &"Land", &"Locomotion", 0.15, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	_add_transition(sm, &"Attack", &"Locomotion", 0.15, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	_add_transition(sm, &"Hit", &"Locomotion", 0.12, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	_add_transition(sm, &"Dodge", &"Locomotion", 0.10, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	_add_transition(sm, &"Interact", &"Locomotion", 0.15, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	_add_transition(sm, &"Special", &"Locomotion", 0.20, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	_add_transition(sm, &"GuardHit", &"Guard", 0.10, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	_add_transition(sm, &"GuardBreak", &"Locomotion", 0.20, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	_add_transition(sm, &"Guard", &"Locomotion", 0.15, AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED)
	_add_transition(sm, &"Death", &"Locomotion", 0.20, AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED)

	for from in sm.get_node_list():
		if from in [&"Start", &"End", &"Death"]:
			continue
		for to in sm.get_node_list():
			if to in [&"Start", &"End"] or from == to or sm.has_transition(from, to):
				continue
			_add_transition(sm, from, to, 0.12, AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED)

	var err := ResourceSaver.save(sm, OUT)
	print("SAVE ", OUT, " err=", err, " states=", sm.get_node_list().size())
	quit(0 if err == OK else 1)


func _anim(name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node


func _add_state(sm: AnimationNodeStateMachine, state: StringName, clip: StringName, pos: Vector2) -> void:
	sm.add_node(state, _anim(clip), pos)


func _add_transition(sm: AnimationNodeStateMachine, from: StringName, to: StringName, fade: float, advance: int) -> void:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = fade
	t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	t.advance_mode = advance
	sm.add_transition(from, to, t)
