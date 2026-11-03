extends GutTest
## Regression guard for measured attack contact times. Values come from
## tools/audit/combat_timing_probe.gd sampling the actual bone/claw in the clips,
## not from design guesses.

const ARMED := "res://resources/combat/attacks/sunny_light_armed.tres"
const UNARMED := "res://resources/combat/attacks/sunny_light_unarmed.tres"
const UNARMED_P1 := "res://resources/combat/attacks/sunny_light_unarmed_p1.tres"
const CARAPACE := "res://resources/combat/attacks/carapace_claw.tres"
const KING := "res://resources/enemies/mountain_king_attack.tres"
const TEST_ENEMY := "res://resources/enemies/test_enemy_attack.tres"


func test_player_contact_times_match_clips() -> void:
	var armed := load(ARMED) as AttackData
	var unarmed := load(UNARMED) as AttackData
	var unarmed_p1 := load(UNARMED_P1) as AttackData
	assert_almost_eq(armed.contact_time, 0.4, 0.001, "Slice_Diagonal, handslot.r peak ~0.383")
	assert_almost_eq(unarmed.contact_time, 0.18, 0.001, "Punch_Jab, right hand peak")
	assert_almost_eq(unarmed_p1.contact_time, 0.33, 0.001, "HumanSpBoxing, left hand peak")


func test_enemy_contact_times_match_clips() -> void:
	var carapace := load(CARAPACE) as AttackData
	assert_almost_eq(carapace.contact_time, 0.40, 0.001, "Carapace Attack, LeftPincer peak")
	var test_enemy := load(TEST_ENEMY) as AttackStats
	assert_almost_eq(test_enemy.contact_time, 0.717, 0.001, "2H_Melee_Attack_Chop, handslot.r peak")


func test_mountain_king_windup_covers_visible_swipe() -> void:
	var king := load(KING) as AttackStats
	assert_almost_eq(king.contact_time, 0.433, 0.001, "Mountain King Attack, LongHandR peak")
	assert_between(king.contact_time, king.windup_time, king.windup_time + king.active_time,
		"contact inside the hit window, not after the visible swipe")


func test_attack_cycles_are_positive() -> void:
	for path in [ARMED, UNARMED, UNARMED_P1, CARAPACE]:
		var data := load(path) as AttackData
		assert_gt(data.cooldown, data.windup_time + data.active_time - 0.001, path)
