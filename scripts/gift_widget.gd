class_name GiftWidget
extends Control

signal finished(success: bool)

const CozyTheme = preload("res://assets/ui/themes/cozy_meadow.tres")

var target_npc
var message: Label
var close_button: Button
var gift_completed := false
var mode := "gift"

func configure(npc) -> void:
	target_npc = npc

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.10, 0.07, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.theme = CozyTheme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-380, -250)
	panel.size = Vector2(760, 500)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 62)
	margin.add_theme_constant_override("margin_right", 62)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var title := Label.new()
	title.text = "%s에게 선물하기" % (target_npc.resident_name if target_npc != null else "주민")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("684329"))
	box.add_child(title)
	message = Label.new()
	message.text = "선물은 주민의 취향에 따라 관계와 오늘의 거래 조건을 바꿔요."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 16)
	message.add_theme_color_override("font_color", Color("594b3d"))
	box.add_child(message)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(modes)
	for entry in [["선물", "gift"], ["부탁 돕기", "request"]]:
		var mode_button := Button.new()
		mode_button.text = entry[0]
		mode_button.pressed.connect(func(): _set_mode(entry[1]))
		modes.add_child(mode_button)
	var choices := GridContainer.new()
	choices.columns = 5
	choices.add_theme_constant_override("h_separation", 10)
	choices.add_theme_constant_override("v_separation", 8)
	box.add_child(choices)
	for item in GuestSession.GIFT_ITEMS:
		choices.add_child(_make_item_button(item))
	close_button = Button.new()
	close_button.text = "나중에 할게"
	close_button.custom_minimum_size.y = 40
	close_button.pressed.connect(func(): _finish(gift_completed))
	box.add_child(close_button)

func _make_item_button(item: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(116, 100)
	button.tooltip_text = "%s %d개" % [GuestSession.item_label(item), GuestSession.item_count(item)]
	button.disabled = GuestSession.item_count(item) < 1
	var icon := ItemIcon.new()
	icon.kind = item
	icon.position = Vector2(28, 6)
	icon.size = Vector2(60, 60)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var label := Label.new()
	label.text = "%s\n×%d" % [GuestSession.item_label(item), GuestSession.item_count(item)]
	label.position = Vector2(0, 64)
	label.size = Vector2(116, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	button.add_child(label)
	button.pressed.connect(func(): _give(item))
	return button

func _give(item: String) -> void:
	if target_npc == null or gift_completed:
		return
	var result: Dictionary = target_npc.receive_gift(item) if mode == "gift" else target_npc.complete_request(item)
	message.text = result.message if result.ok else result.reason
	if result.ok:
		gift_completed = true
	close_button.text = "마을로 돌아가기"

func _set_mode(next_mode: String) -> void:
	if gift_completed:
		return
	mode = next_mode
	message.text = "부탁: %s 1개를 전달하면 호감도 +%d" % [GuestSession.item_label(target_npc.request_material), target_npc.affection_weights.quest] if mode == "request" else "선물은 주민의 취향에 따라 관계와 오늘의 거래 조건을 바꿔요."

func _finish(success: bool) -> void:
	finished.emit(success)
	queue_free()
