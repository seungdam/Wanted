extends Node
## Shared dialogue registry for scene, NPC, tutorial, event, day, and ending scripts.

const SOURCE_PATHS := ["res://data/scenarios.xlsx", "res://data/npc_dialogues.xlsx"]
const DIALOGUE_ROOT := "res://dialogue/generated"

var scenes: Dictionary = {}
var loaded := false

func _ready() -> void:
	reload()

func reload() -> bool:
	scenes.clear()
	var loaded_any := false
	for path in SOURCE_PATHS:
		var sheet := ScenarioSheet.new()
		if not sheet.load_path(path):
			continue
		loaded_any = true
		for code in sheet.scenes:
			if not scenes.has(code):
				scenes[code] = sheet.scenes[code]
	loaded = loaded_any
	return loaded

func load_file() -> bool:
	return reload()

func has_code(code: String) -> bool:
	return scenes.has(code)

func lines(code: String, tokens: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	for value in scenes.get(code, []):
		var line := str(value)
		for token in tokens.keys():
			line = line.replace("{%s}" % token, str(tokens[token]))
		if not line.is_empty():
			result.append(line)
	return result

## Returns a compiled Dialogue Manager resource when the XLSX compiler has
## generated one. Legacy callers can continue using lines() during migration.
func dialogue_resource(resource_id: String):
	var path := "%s/%s.dialogue" % [DIALOGUE_ROOT, resource_id]
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func has_dialogue_resource(resource_id: String) -> bool:
	return dialogue_resource(resource_id) != null
