class_name AttackStats
extends Resource
## Балансные параметры одной атаки ближнего боя.

@export var damage := 10.0
## Время от начала одной атаки до возможности начать следующую, с.
@export var cooldown := 0.5
## Длительность окна попадания, с.
@export var active_time := 0.15
## Смещение центра зоны поражения вперёд от владельца, м.
@export var reach := 1.0
## Радиус сферической зоны поражения, м.
@export var radius := 0.8
