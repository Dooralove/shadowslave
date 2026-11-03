class_name EnemyData
extends Resource
## Описание врага: здоровье, восприятие, движение и выбранная атака.
## Контроллер врага читает ресурс, поэтому новый вид не требует правки кода.

@export var id: StringName = &""
@export var display_name := "Противник"
@export var max_health := 60.0
@export var detection_range := 10.0
@export var lose_range := 15.0
@export var attack_distance := 1.6
@export var move_speed := 2.8
@export var turn_speed := 8.0
@export var telegraph_time := 0.6
@export var recovery_time := 1.0
@export var attack: AttackData


func is_valid() -> bool:
	return id != &"" and max_health > 0.0 and attack != null
