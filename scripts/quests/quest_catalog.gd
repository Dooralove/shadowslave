class_name QuestCatalog
extends Resource
## Каталог заданий. Один ресурс на демо-фрагмент; QuestSystem строит индекс
## по id и сообщает об ошибках данных, не прерывая игру.

@export var scope: StringName = &"forgotten_shore"
@export var quests: Array = []


func build_index() -> Dictionary:
	var index := {}
	for item in quests:
		var quest := item as QuestDefinition
		if quest == null or not quest.is_valid():
			continue
		if index.has(quest.id):
			push_warning("QuestCatalog: повторный id задания %s" % quest.id)
			continue
		index[quest.id] = quest
	return index
