class_name CombatSettings
extends Resource
## Числа боевой основы Санни. Хранятся в .tres, а не в контроллере.

@export_group("Выносливость")
@export var max_stamina := 100.0
@export var stamina_regen_per_second := 18.0
@export var stamina_regen_delay := 0.7

@export_group("Уклонение")
@export var dodge_stamina_cost := 16.0
@export var dodge_duration := 0.42
@export var dodge_iframe_time := 0.22
@export var dodge_speed := 7.5
## Короткая неуязвимость после фактического попадания: не даёт двум врагам
## снять всё здоровье в одном стане. Не отменяет урон, который уже прошёл.
@export var post_hit_iframe_time := 0.25

@export_group("Блок")
@export var block_damage_multiplier := 0.3
@export var block_stamina_per_hit := 15.0
@export var block_stamina_per_second := 10.0
@export var block_move_multiplier := 0.45
## Сколько длится стан после пробоя блока, с.
@export var guard_break_stagger := 0.9

@export_group("Бой")
## Радиус, в котором враг включает боевой контекст.
@export var combat_radius := 8.0
## Сколько секунд бой считается активным после последнего контакта.
@export var combat_grace := 2.0


func is_valid() -> bool:
	return max_stamina > 0.0 and dodge_duration > 0.0 and dodge_iframe_time > 0.0
