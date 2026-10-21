class_name StatusSheet
extends Resource
## Экран статуса, который Заклинание показывает рунами. Значения — канонические термины (гл. 2).

@export var name_rune := ""
@export var true_name := "—"
@export var rank := ""
@export var soul_core := ""
@export var memories := "—"
@export var echoes := "—"
@export var attributes: PackedStringArray = []
@export var aspect := ""
## Описание Аспекта — пересказ, а не цитата.
@export_multiline var aspect_description := ""
