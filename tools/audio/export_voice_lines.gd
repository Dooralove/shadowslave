extends SceneTree
## Exports prologue/caravan dialogue lines and barks to user://voice_lines.json.
## Run: godot --headless --path . --script res://tools/audio/export_voice_lines.gd

const SEQUENCE_DIRS := [
	"res://resources/dialogue/prologue",
	"res://resources/dialogue/caravan",
]
const BARKS_PATH := "res://data/dialogues/sunny_barks.json"
const OUT_PATH := "user://voice_lines.json"


func _init() -> void:
	var records: Array = []
	for directory in SEQUENCE_DIRS:
		for file_name in DirAccess.get_files_at(directory):
			if not file_name.ends_with(".tres"):
				continue
			var path: String = String(directory) + "/" + String(file_name)
			var sequence := load(path) as DialogueSequence
			if sequence == null:
				push_warning("Cannot load %s" % path)
				continue
			var stem := String(file_name).get_basename()
			for index in sequence.lines.size():
				var line := sequence.lines[index] as DialogueLine
				if line == null or line.text.strip_edges().is_empty():
					continue
				records.append({
					"id": "%s_%03d" % [stem, index],
					"kind": "line",
					"speaker": String(line.speaker),
					"text": line.text,
				})
	var file := FileAccess.open(BARKS_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary and parsed.has("barks"):
			for bark in parsed["barks"]:
				if bark is Dictionary and not String(bark.get("text", "")).strip_edges().is_empty():
					records.append({
						"id": "bark_%s" % String(bark.get("id", "")),
						"kind": "bark",
						"speaker": String(bark.get("speaker", "sunny")),
						"text": String(bark.get("text", "")),
					})
	var output := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write %s" % OUT_PATH)
		quit(1)
		return
	output.store_string(JSON.stringify({"records": records}, "\t"))
	output.close()
	print("Exported %d voice source records to %s" % [records.size(), ProjectSettings.globalize_path(OUT_PATH)])
	quit(0)
