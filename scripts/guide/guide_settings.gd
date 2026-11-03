class_name GuideSettings
extends Resource
## Настройки системы целей и подсказок. Значения живут в ресурсе, а не в коде:
## resources/campaign/guide/guide_settings.tres.

## Сколько секунд игрок должен простоять без осмысленного действия до первой ступени.
@export var idle_seconds := 8.0
## Через сколько секунд после предыдущей ступени уточнять цель ещё раз.
@export var idle_step_seconds := 10.0
## Максимум ступеней уточнения (2–3 по списку событий v2).
@export var max_idle_steps := 3
## Горизонтальная скорость ниже этого порога считается простоем, м/с.
@export var idle_speed_threshold := 0.2
## Сколько держится мысль Санни, с.
@export var thought_seconds := 5.0
## Мягкое появление и угасание мысли, с.
@export var thought_fade_seconds := 0.35
## Мягкое появление и угасание строки цели, с.
@export var objective_fade_in_seconds := 0.4
@export var objective_fade_out_seconds := 0.6
## Мягкое включение и выключение маяка, с.
@export var beacon_fade_seconds := 0.6


func is_valid() -> bool:
	return idle_seconds > 0.0 and idle_step_seconds > 0.0 and max_idle_steps > 0
