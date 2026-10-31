class_name SpellMessageCatalog
extends Resource
## Набор сообщений Заклятия, отделённый от визуального слоя.
##
## Каталог можно использовать и в игре, и в тестах. UI не знает, откуда
## пришло сообщение, и не хранит сюжетные тексты.

## Элементы — SpellMessage. Массив без строгой типизации, как у DialogueSequence,
## чтобы ресурс оставался простым для ручного редактирования.
@export var messages: Array = []


func get_message(message_id: StringName) -> SpellMessage:
	for message in messages:
		if message is SpellMessage and message.id == message_id:
			return message
	return null


func get_valid_messages() -> Array[SpellMessage]:
	var result: Array[SpellMessage] = []
	for message in messages:
		if message is SpellMessage and message.is_valid():
			result.append(message)
	return result
