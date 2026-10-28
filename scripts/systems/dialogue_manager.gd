extends Node
## Центральный реестр коротких внутренних реплик Санни (bark).
## Autoload: DialogueManager.
##
## Данные: data/dialogues/sunny_barks.json. Поддерживаются два формата:
##   1) { "barks": [ { "id", "speaker", "context", "aliases"?, "text" }, … ] }
##   2) старый { "категория": [ "реплика", … ] } — для совместимости.
##
## Ошибки данных не прерывают игру: загрузчик сообщает о них в лог, сохраняет
## прежнюю базу и возвращает пустой результат для неизвестного контекста.

signal bark_requested(bark: BarkLine)
## Реплики скрываются, когда начинается сюжетный диалог.
signal bark_cleared

const BARKS_PATH := "res://data/dialogues/sunny_barks.json"

const CONTEXT_MARCH_START := &"march_start"
const CONTEXT_DANGER := &"danger"
const CONTEXT_AMBUSH := &"ambush"
const CONTEXT_COVER := &"cover"
const CONTEXT_ESCAPE := &"escape"
const CONTEXT_SHRINE_APPROACH := &"shrine_approach"
const CONTEXT_ALTAR := &"altar"

## Все контексты прототипа, включая те, для которых в источнике пока нет реплик.
const GAMEPLAY_CONTEXTS := [
	CONTEXT_MARCH_START,
	CONTEXT_DANGER,
	CONTEXT_AMBUSH,
	CONTEXT_COVER,
	CONTEXT_ESCAPE,
	CONTEXT_SHRINE_APPROACH,
	CONTEXT_ALTAR,
]

## Короткие псевдонимы, чтобы игровые контроллеры могли говорить на своём языке.
const CONTEXT_ALIASES := {
	&"march": &"march_start",
	&"caravan_march": &"march_start",
	&"threat": &"danger",
	&"hiding": &"cover",
	&"run": &"escape",
	&"shrine": &"shrine_approach",
	&"altar_interaction": &"altar",
}

var barks_path := BARKS_PATH

## StringName -> Array[BarkLine]. Один и тот же bark может лежать в нескольких контекстах.
var _barks_by_context: Dictionary = {}
var _barks_by_id: Dictionary = {}
var _all_barks: Array[BarkLine] = []
var _rng := RandomNumberGenerator.new()
var _load_attempted := false
var _barks_suppressed := false
## Последняя выданная реплика. Не повторяем её, пока в контексте есть альтернатива.
var _last_shown_id: StringName = &""


func _ready() -> void:
	_rng.randomize()
	load_barks(barks_path)


## Загружает или перезагружает базу. При ошибке прежние данные сохраняются.
func load_barks(path: String = "") -> bool:
	var source_path := path if not path.is_empty() else barks_path
	_load_attempted = true

	if not FileAccess.file_exists(source_path):
		push_error("DialogueManager: файл реплик не найден: %s" % source_path)
		return false

	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: не удалось открыть %s (код ошибки %d)." % [source_path, FileAccess.get_open_error()])
		return false

	var text := file.get_as_text()
	file.close()

	# Некоторые редакторы сохраняют UTF-8 с BOM, а JSON.parse_string его не принимает.
	if text.begins_with("\uFEFF"):
		text = text.substr(1)

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("DialogueManager: ошибка разбора JSON в %s: %s." % [source_path, _describe_json_error(text)])
		return false

	var records := _parse_document(parsed, source_path)
	if records.is_empty():
		push_error("DialogueManager: в %s нет ни одной валидной реплики." % source_path)
		return false

	_index_records(records)
	print_verbose("DialogueManager: загружено реплик — %d, контекстов — %d." % [_all_barks.size(), _barks_by_context.size()])
	return true


## Возвращает случайную реплику контекста или null. Тот же bark не выдаётся дважды подряд,
## если в контексте есть другой вариант.
func get_bark(context: StringName) -> BarkLine:
	if not _load_attempted:
		load_barks(barks_path)

	var key := _normalize_context(context)
	var lines: Array = _barks_by_context.get(key, [])
	if lines.is_empty():
		return null

	var candidates: Array[BarkLine] = []
	for item in lines:
		var bark := item as BarkLine
		if bark != null and bark.id != _last_shown_id:
			candidates.append(bark)

	# В категории один вариант — повтор допустим.
	if candidates.is_empty():
		for item in lines:
			var bark := item as BarkLine
			if bark != null:
				candidates.append(bark)
	if candidates.is_empty():
		return null

	var chosen: BarkLine = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_last_shown_id = chosen.id
	return chosen


## Совместимый со старым API доступ: только текст реплики.
func get_random_bark(context: StringName) -> String:
	var bark := get_bark(context)
	return bark.text if bark != null else ""


## Выбирает реплику и просит UI показать её. Возвращает null, если контекст пуст
## или сейчас идёт сюжетный диалог. force=true нужен только для отладки/тестов.
func show_bark(context: StringName, force := false) -> BarkLine:
	if _barks_suppressed and not force:
		return null
	var bark := get_bark(context)
	if bark == null:
		return null
	bark_requested.emit(bark)
	return bark


## Синоним show_bark для читаемости в игровых контроллерах.
func request_bark(context: StringName, force := false) -> BarkLine:
	return show_bark(context, force)


func has_context(context: StringName) -> bool:
	var key := _normalize_context(context)
	var lines: Array = _barks_by_context.get(key, [])
	return not lines.is_empty()


func get_bark_count(context: StringName) -> int:
	var key := _normalize_context(context)
	var lines: Array = _barks_by_context.get(key, [])
	return lines.size()


func get_contexts() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _barks_by_context:
		result.append(key)
	result.sort()
	return result


func get_all_barks() -> Array[BarkLine]:
	var copy: Array[BarkLine] = []
	copy.assign(_all_barks)
	return copy


func get_last_shown_id() -> StringName:
	return _last_shown_id


func set_barks_suppressed(value: bool) -> void:
	if _barks_suppressed == value:
		return
	_barks_suppressed = value
	if value:
		bark_cleared.emit()


func is_barks_suppressed() -> bool:
	return _barks_suppressed


func _normalize_context(context: StringName) -> StringName:
	var key := StringName(context)
	return CONTEXT_ALIASES.get(key, key)


func _index_records(records: Array[BarkLine]) -> void:
	var by_context := {}
	var by_id := {}
	for bark in records:
		by_id[bark.id] = bark
		_add_to_index(by_context, bark.context, bark)
		for alias in bark.aliases:
			_add_to_index(by_context, alias, bark)

	_all_barks = records
	_barks_by_context = by_context
	_barks_by_id = by_id
	_last_shown_id = &""


func _add_to_index(index: Dictionary, context: StringName, bark: BarkLine) -> void:
	if context == &"":
		return
	var key := _normalize_context(context)
	var lines: Array = index.get(key, [])
	# Контекст и псевдоним могут указывать на одну и ту же группу — не дублируем запись.
	if not lines.has(bark):
		lines.append(bark)
	index[key] = lines


func _parse_document(parsed: Variant, source_path: String) -> Array[BarkLine]:
	var records: Array[BarkLine] = []
	var seen_ids := {}

	if typeof(parsed) == TYPE_ARRAY:
		_append_entries(parsed, &"", source_path, records, seen_ids)
		return records

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueManager: ожидался объект JSON в %s, получен %s." % [source_path, type_string(typeof(parsed))])
		return records

	var source: Dictionary = parsed
	if source.has("barks"):
		var entries: Variant = source["barks"]
		if typeof(entries) != TYPE_ARRAY:
			push_error("DialogueManager: поле 'barks' в %s должно быть массивом." % source_path)
			return records
		_append_entries(entries, &"", source_path, records, seen_ids)
		return records

	# Старый формат: ключ — категория, значение — массив строк или записей.
	for category in source:
		if typeof(category) != TYPE_STRING:
			push_warning("DialogueManager: ключ категории должен быть строкой, пропущен: %s." % category)
			continue

		var lines: Variant = source[category]
		if typeof(lines) != TYPE_ARRAY:
			push_warning("DialogueManager: категория '%s' должна быть массивом, пропущена." % category)
			continue

		var context := StringName(str(category).strip_edges())
		if context == &"":
			continue
		for index in lines.size():
			var item: Variant = lines[index]
			if typeof(item) == TYPE_STRING:
				var text := str(item).strip_edges()
				if text.is_empty():
					push_warning("DialogueManager: в категории '%s' пропущена пустая реплика." % category)
					continue
				var bark := BarkLine.new()
				bark.id = StringName("%s_%02d" % [context, index + 1])
				bark.speaker = &"sunny"
				bark.context = context
				bark.text = text
				_append_bark(bark, source_path, records, seen_ids)
			elif typeof(item) == TYPE_DICTIONARY:
				var bark := _parse_record(item, context, source_path)
				if bark != null:
					_append_bark(bark, source_path, records, seen_ids)
			else:
				push_warning("DialogueManager: в категории '%s' пропущена запись неверного типа." % category)

	return records


func _append_entries(entries: Array, default_context: StringName, source_path: String, records: Array[BarkLine], seen_ids: Dictionary) -> void:
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			push_warning("DialogueManager: в %s пропущена запись, которая не является объектом." % source_path)
			continue
		var bark := _parse_record(item, default_context, source_path)
		if bark != null:
			_append_bark(bark, source_path, records, seen_ids)


func _parse_record(source: Dictionary, default_context: StringName, source_path: String) -> BarkLine:
	var id := _string_value(source.get("id", ""))
	var text := _string_value(source.get("text", ""))
	var speaker := _string_value(source.get("speaker", ""))
	var context := _string_value(source.get("context", ""))
	if context.is_empty() and default_context != &"":
		context = String(default_context)

	if id.is_empty() or text.is_empty() or speaker.is_empty() or context.is_empty():
		push_warning("DialogueManager: в %s пропущена запись с пустыми id/text/speaker/context." % source_path)
		return null

	var bark := BarkLine.new()
	bark.id = StringName(id)
	bark.speaker = StringName(speaker)
	bark.context = StringName(context)
	bark.text = text
	bark.aliases = _parse_aliases(source.get("aliases", null), source_path)
	return bark


func _append_bark(bark: BarkLine, source_path: String, records: Array[BarkLine], seen_ids: Dictionary) -> void:
	if seen_ids.has(bark.id):
		push_warning("DialogueManager: повторяющийся id '%s' в %s пропущен." % [bark.id, source_path])
		return
	seen_ids[bark.id] = true
	records.append(bark)


func _parse_aliases(value: Variant, source_path: String) -> Array[StringName]:
	var result: Array[StringName] = []
	if value == null:
		return result
	if typeof(value) != TYPE_ARRAY:
		push_warning("DialogueManager: поле 'aliases' в %s должно быть массивом." % source_path)
		return result
	for item in value:
		if typeof(item) != TYPE_STRING:
			push_warning("DialogueManager: в 'aliases' %s пропущен нестроковый контекст." % source_path)
			continue
		var alias := StringName(str(item).strip_edges())
		if alias != &"" and not result.has(alias):
			result.append(alias)
	return result


func _string_value(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		return str(value).strip_edges()
	if typeof(value) == TYPE_STRING_NAME:
		return String(value).strip_edges()
	return ""


## Достаёт из JSON подробности ошибки: JSON.parse_string возвращает только null.
func _describe_json_error(text: String) -> String:
	var json := JSON.new()
	var error := json.parse(text)
	if error == OK:
		return "неизвестная ошибка"
	return "строка %d: %s" % [json.get_error_line() + 1, json.get_error_message()]
