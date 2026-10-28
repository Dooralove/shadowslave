class_name RpgDemoSkillTree
extends Resource
## Демонстрационное дерево навыков. Отдельный ресурс, не связанный с
## сохранениями, боевой системой или характеристиками персонажа.

@export var id: StringName = &"demo_aspect_tree"
@export var title := "DEMO · ДЕРЕВО НАВЫКОВ"
@export_multiline var note := ""
@export var starting_points := 3
@export var nodes: Array[RpgDemoSkill] = []
