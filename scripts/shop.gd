extends Control
const ITEMS := {"wood": 8, "stone": 10, "flower": 6, "copper_ore": 18, "herb_tea": 24}
var body: VBoxContainer

func _ready() -> void:
	body = VBoxContainer.new()
	body.position = Vector2(40, 40)
	add_child(body)
	_render()

func _render() -> void:
	for child in body.get_children(): child.queue_free()
	var title := Label.new()
	title.text = "마을 상점 · R 또는 ESC로 마을로 돌아가기"
	body.add_child(title)
	for item in ITEMS:
		var button := Button.new()
		button.text = "%s · %d볼트" % [GuestSession.item_label(item), ITEMS[item]]
		button.pressed.connect(func(): GuestSession.buy_item(item, ITEMS[item], "마을 상점"); _render())
		body.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_R]:
	get_tree().change_scene_to_file("res://scenes/village.tscn")
