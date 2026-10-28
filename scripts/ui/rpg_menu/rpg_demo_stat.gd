class_name RpgDemoStat
extends Resource
## Строка демонстрационной характеристики. fill < 0 — полоса не нужна.

@export var label := ""
@export var value := ""
@export_range(-1.0, 1.0, 0.01) var fill := -1.0
