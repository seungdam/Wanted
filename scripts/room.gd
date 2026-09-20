extends Control
const LifeCoreScript = preload("res://scripts/life_core.gd")
var life := LifeCoreScript.new()
var body: VBoxContainer

func _ready() -> void:
	GuestSession.set_game_day(GuestSession.current_day)
	body = VBoxContainer.new()
	body.position = Vector2(40, 40)
	body.size = Vector2(640, 700)
	add_child(body)
	_render()

func _render() -> void:
	for child in body.get_children(): child.queue_free()
	var title := Label.new()
	title.text = "내 방 · R 또는 ESC로 마을로 돌아가기"
	title.add_theme_font_size_override("font_size", 24)
	body.add_child(title)
	for slot in range(int(life.rules.room_slots)):
		var row := HBoxContainer.new()
		body.add_child(row)
		var label := Label.new()
		label.text = "%d번" % (slot + 1)
		label.custom_minimum_size.x = 60
		row.add_child(label)
		if life.room.has(slot):
			var item := str(life.room[slot])
			var placed := Label.new()
			placed.text = life.label(item)
			row.add_child(placed)
			var remove := Button.new()
			remove.text = "회수"
			remove.pressed.connect(func(): life.remove(slot); _render())
			row.add_child(remove)
		else:
			for item in life.rules.recipes:
				var place := Button.new()
				place.text = life.label(item)
				place.disabled = GuestSession.item_count(item) < 1
				place.pressed.connect(func(): life.place(item, slot); _render())
				row.add_child(place)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_R]:
		get_tree().change_scene_to_file("res://scenes/village.tscn")
