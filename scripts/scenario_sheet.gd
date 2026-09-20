class_name ScenarioSheet
extends RefCounted

const PATH := "res://data/scenarios.xlsx"
var scenes: Dictionary = {}

func load_file() -> bool:
	return load_path(PATH)

func load_path(path: String) -> bool:
	scenes.clear()
	var archive := ZIPReader.new()
	if archive.open(path) != OK:
		return false
	var xml := archive.read_file("xl/worksheets/sheet1.xml").get_string_from_utf8()
	var shared_xml := archive.read_file("xl/sharedStrings.xml").get_string_from_utf8()
	archive.close()
	var shared: Array[String] = []
	var shared_text := RegEx.new()
	shared_text.compile("(?s)<x:t[^>]*>(.*?)</x:t>")
	for text in shared_text.search_all(shared_xml):
		shared.append(text.get_string(1).xml_unescape())
	var cells := RegEx.new()
	cells.compile("(?s)<x:c\\s([^>/]*)>(.*?)</x:c>")
	var cell_reference := RegEx.new()
	cell_reference.compile("r=\"([A-Z]+)([0-9]+)\"")
	var value_tag := RegEx.new()
	value_tag.compile("(?s)<x:v>(.*?)</x:v>|<x:t[^>]*>(.*?)</x:t>")
	var columns: Dictionary = {}
	for cell in cells.search_all(xml):
		var ref := cell_reference.search(cell.get_string(1))
		if ref == null:
			continue
		var column: String = ref.get_string(1)
		var match := value_tag.search(cell.get_string(2))
		var value := "" if match == null else (match.get_string(1) if not match.get_string(1).is_empty() else match.get_string(2)).xml_unescape()
		if "t=\"s\"" in cell.get_string(1) and value.is_valid_int():
			value = shared[int(value)] if int(value) < shared.size() else ""
		if not value.is_empty():
			if not columns.has(column):
				columns[column] = []
			columns[column].append(value)
	for column in columns:
		var values: Array = columns[column].duplicate()
		if values.is_empty():
			continue
		var code := String(values.pop_front())
		while not values.is_empty() and String(values.back()).is_empty():
			values.pop_back()
		if not code.is_empty():
			scenes[code] = values
	return not scenes.is_empty()

func lines(code: String, tokens: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	for value in scenes.get(code, []):
		var line := str(value)
		for token in tokens.keys():
			line = line.replace("{%s}" % token, str(tokens[token]))
		if not line.is_empty():
			result.append(line)
	return result
