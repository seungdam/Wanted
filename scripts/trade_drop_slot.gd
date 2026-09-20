class_name TradeDropSlot
extends PanelContainer


signal item_dropped
var delivered := false
var hint: Label
var required_item := "wood"

func _ready() -> void:
	add_theme_stylebox_override("panel", _slot_style(false))
	hint = Label.new()
	hint.text = "여기에\n놓기"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 18)
	add_child(hint)

func _slot_style(delivered_state: bool) -> StyleBoxTexture:
	return CozyUIAtlas.slot_style(delivered_state)

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("item", "") == required_item and not delivered

func _drop_data(_at_position: Vector2, data) -> void:
	if _can_drop_data(Vector2.ZERO, data):
		delivered = true
		add_theme_stylebox_override("panel", _slot_style(true))
		hint.text = "%s\n전달 준비 ✓" % GuestSession.item_label(required_item)
		item_dropped.emit()

func reset(item: String) -> void:
	required_item = item
	delivered = false
	add_theme_stylebox_override("panel", _slot_style(false))
	if hint != null:
		hint.text = "여기에\n놓기"
