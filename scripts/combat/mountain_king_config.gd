class_name MountainKingConfig
extends Resource
## Настройки прототипа AI Горного Короля.
## Отдельный ресурс, чтобы параметры можно было менять в инспекторе без правки кода.

@export_group("Движение")
## Максимальная скорость преследования, м/с.
@export var move_speed := 3.2
## Ускорение и торможение, м/с². Не даёт мгновенно менять скорость.
@export var acceleration := 10.0
## Скорость доворота модели, рад/с (условная, через lerp_angle).
@export var turn_speed := 5.0

@export_group("Обнаружение")
## Радиус, в котором монстр заново замечает цель после потери.
@export var detection_range := 18.0
## Дистанция, после которой цель считается потерянной (больше detection_range).
@export var lose_range := 26.0

@export_group("Атака")
## Дистанция начала подготовки удара по центру цели.
@export var attack_distance := 3.6
## Длительность подготовки (телеграфа) перед ударом, с.
@export var telegraph_time := 1.1
## Длительность восстановления после удара, с.
@export var recovery_time := 1.4
## Минимальное время между началами атак, с. Гарантирует паузу даже при
## коротком восстановлении и не даёт наносить урон каждый кадр.
@export var time_between_attacks := 4.5

@export_group("Блокировка")
## Сколько секунд отсутствия реального продвижения считать блокировкой.
@export var blocked_detect_time := 0.6
## Сколько монстр стоит в BLOCKED перед первой проверкой пути.
@export var blocked_wait_time := 1.5
## Пауза между повторными проверками, если путь всё ещё перекрыт.
@export var blocked_retry_delay := 2.0

@export_group("Отступление")
## Скорость движения в RETREAT, м/с.
@export var retreat_speed := 3.6
## Ограничение длительности отступления, с.
@export var retreat_duration := 4.0
## На каком расстоянии от точки отступления считать его завершённым.
@export var retreat_arrival_distance := 0.8
