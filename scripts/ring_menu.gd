class_name RingMenu
extends Control

signal closed
const RingActionScene = preload("res://scenes/ui/ring_action.tscn")
const InventoryTheme = preload("res://assets/ui/themes/cozy_meadow.tres")
const RING_ICONS := [
	preload("res://assets/ui/icons/cozy_backpack.png"),
	preload("res://assets/ui/icons/cozy_tool.png"),
	preload("res://assets/ui/icons/cozy_book.png")
]
const INVENTORY_TABS := ["전체", "재료", "생활", "선물"]
const MATERIALS := ["wood", "stone", "flower", "copper_ore", "wool"]
var inventory_grid: GridContainer
var inventory_info: Label
var inventory_tabs: Array[Button] = []
var center := Vector2.ZERO
var buttons: Array[Button] = []
var detail: PanelContainer
var tracked_player: Node2D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_STOP
	_make_button("가방", RING_ICONS[0], _show_items)
	_make_button("도구", RING_ICONS[1], _show_tools)
	_make_button("추억", RING_ICONS[2], _show_memory)

func show_at(world_position: Vector2) -> void:
	_set_center(world_position)
	_layout_buttons(true)

func track(player: Node2D) -> void:
	tracked_player = player
	process_priority = 100

func _process(_delta: float) -> void:
	if tracked_player != null and detail == null:
		follow(tracked_player.global_position)

func follow(world_position: Vector2) -> void:
	if detail == null:
		_set_center(world_position)
		_layout_buttons(false)

func _set_center(world_position: Vector2) -> void:
	center = get_viewport().get_canvas_transform() * world_position
	center.x = clampf(center.x, 150.0, size.x - 150.0)
	center.y = clampf(center.y, 160.0, size.y - 160.0)

func _layout_buttons(animated: bool) -> void:
	for index in range(buttons.size()):
		var button := buttons[index]
		var offset: Vector2 = [Vector2(0, -124), Vector2(115, 72), Vector2(-115, 72)][index]
		var target := center + offset - button.custom_minimum_size * 0.5
		if not animated:
			button.position = target
			continue
		button.position = center - button.custom_minimum_size * 0.5
		button.pivot_offset = button.custom_minimum_size * 0.5
		button.scale = Vector2(0.25, 0.25)
		button.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.set_parallel(true)
		tween.tween_property(button, "position", target, 0.24).set_delay(0.06 * index).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE, 0.26).set_delay(0.06 * index).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 1.0, 0.16).set_delay(0.06 * index)
	queue_redraw()

func _draw() -> void:
	draw_circle(center, 18.0, Color(0.18, 0.13, 0.08, 0.55))

func _make_button(label: String, icon: Texture2D, action: Callable) -> void:
	var button := RingActionScene.instantiate() as RingAction
	button.configure(label, icon)
	button.pressed.connect(action)
	button.mouse_entered.connect(func(): _hover(button, true))
	button.mouse_exited.connect(func(): _hover(button, false))
	add_child(button)
	buttons.append(button)

func _hover(button: Button, active: bool) -> void:
	if detail != null:
		return
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.13, 1.13) if active else Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _open_detail(title: String) -> VBoxContainer:
	for button in buttons:
		button.hide()
	_set_world_hud_visible(false)
	detail = PanelContainer.new()
	detail.set_anchors_preset(Control.PRESET_CENTER)
	detail.position = Vector2(-430, -345)
	detail.size = Vector2(860, 690)
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	detail.theme = InventoryTheme
	detail.modulate.a = 0.0
	add_child(detail)
	create_tween().tween_property(detail, "modulate:a", 1.0, 0.18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	detail.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font", preload("res://font/Moneygraphy-Pixel.ttf"))
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("684329"))
	box.add_child(heading)
	var underline := ColorRect.new()
	underline.color = Color("f2d58a")
	underline.custom_minimum_size = Vector2(0, 4)
	box.add_child(underline)
	return box

func _show_items() -> void:
	var box := _open_detail("보관함")
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var group := ButtonGroup.new()
	for index in range(INVENTORY_TABS.size()):
		var tab := Button.new()
		tab.text = INVENTORY_TABS[index]
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = index == 0
		tab.pressed.connect(_filter_inventory.bind(index))
		header.add_child(tab)
		inventory_tabs.append(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var purse := PanelContainer.new()
	purse.add_theme_stylebox_override("panel", InventoryTheme.get_stylebox("normal", "Button"))
	header.add_child(purse)
	var money := Label.new()
	money.text = GuestSession.format_nut(GuestSession.nut)
	money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	purse.add_child(money)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 398
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 10)
	inventory_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(inventory_grid)
	inventory_info = Label.new()
	inventory_info.text = "물건을 선택하면 이름과 보유 수량을 볼 수 있어요."
	box.add_child(inventory_info)
	_filter_inventory(0)
	_add_close(box)

func _filter_inventory(category: int) -> void:
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()
	inventory_info.text = "물건을 선택하면 이름과 보유 수량을 볼 수 있어요."
	var group := ButtonGroup.new()
	for item in GuestSession.inventory:
		if GuestSession.item_count(item) <= 0:
			continue
		if category == 1 and item not in MATERIALS:
			continue
		if category == 2 and item in MATERIALS:
			continue
		if category == 3 and item not in GuestSession.GIFT_ITEMS:
			continue
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(92, 92)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_slot_theme(slot)
		slot.toggle_mode = true
		slot.button_group = group
		slot.set_meta("item_id", item)
		slot.tooltip_text = GuestSession.item_label(item)
		var icon := ItemIcon.new()
		icon.kind = item
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_bottom = -26
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var label := Label.new()
		label.text = "%s ×%d" % [GuestSession.item_label(item), GuestSession.item_count(item)]
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_top = -27
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)
		slot.pressed.connect(func(): inventory_info.text = _collection_text(item))
		inventory_grid.add_child(slot)
	while inventory_grid.get_child_count() < 24:
		var empty := Button.new()
		empty.custom_minimum_size = Vector2(92, 92)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.disabled = true
		empty.focus_mode = Control.FOCUS_NONE
		empty.add_theme_stylebox_override("disabled", CozyUIAtlas.slot_style(false))
		inventory_grid.add_child(empty)

func _apply_slot_theme(slot: Button) -> void:
	slot.add_theme_stylebox_override("normal", CozyUIAtlas.slot_style(false))
	slot.add_theme_stylebox_override("hover", CozyUIAtlas.slot_style(true))
	slot.add_theme_stylebox_override("pressed", CozyUIAtlas.slot_style(true))
	slot.add_theme_stylebox_override("hover_pressed", CozyUIAtlas.slot_style(true))

func _show_tools() -> void:
	var box := _open_detail("도구 주머니")
	var tool := PanelContainer.new()
	tool.custom_minimum_size = Vector2(250, 170)
	var tool_style := StyleBoxFlat.new()
	tool_style.bg_color = Color("e1f0e4")
	tool_style.set_corner_radius_all(24)
	tool.add_theme_stylebox_override("panel", tool_style)
	var icon := ItemIcon.new()
	icon.kind = "tool"
	icon.position = Vector2(26, 40)
	icon.size = Vector2(86, 86)
	tool.add_child(icon)
	var description := Label.new()
	description.text = "도구 주머니\n수렵 상호작용 준비 중"
	description.position = Vector2(118, 55)
	description.add_theme_font_size_override("font_size", 18)
	description.add_theme_color_override("font_color", Color("527a35"))
	tool.add_child(description)
	box.add_child(tool)
	_add_close(box)

func _show_memory() -> void:
	var box := _open_detail("거래의 추억 액자")
	var note := Label.new()
	note.text = "주민과 물건이 만난 거래가 추억 노드로 이어집니다."
	note.add_theme_font_size_override("font_size", 18)
	box.add_child(note)
	var graph := MemoryGraph.new()
	graph.entries = GuestSession.memory_frame_entries()
	graph.custom_minimum_size = Vector2(760, 280)
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(graph)
	var detail_text := Label.new()
	detail_text.text = "기록을 골라 액자의 여섯 홈에 전시하세요."
	detail_text.add_theme_font_size_override("font_size", 17)
	detail_text.add_theme_color_override("font_color", Color("684329"))
	box.add_child(detail_text)
	graph.memory_selected.connect(func(entry: Dictionary):
		detail_text.text = "#%d  %s → %s · %s · %s" % [entry.block, entry.from, entry.to, _memory_subject(entry), GuestSession.format_nut(int(entry.amount))]
	)
	var records := GridContainer.new()
	records.columns = 2
	records.add_theme_constant_override("h_separation", 8)
	records.add_theme_constant_override("v_separation", 6)
	box.add_child(records)
	for entry in GuestSession.memory_entries():
		var choice := Button.new()
		choice.custom_minimum_size.y = 34
		choice.text = _memory_choice_text(entry)
		choice.pressed.connect(func(record = entry, button = choice):
			if GuestSession.toggle_memory_frame(int(record.id)):
				graph.entries = GuestSession.memory_frame_entries()
				graph.queue_redraw()
				button.text = _memory_choice_text(record)
				detail_text.text = "액자에 %d/6개 전시 중" % GuestSession.memory_frame.size()
			else:
				detail_text.text = "액자는 여섯 개의 기록만 전시할 수 있어요."
		)
		records.add_child(choice)
	_add_close(box)

func _collection_text(item: String) -> String:
	var record := GuestSession.collection_record(item)
	if not record.has("highest_sale"):
		return "%s · 보유 %d개 · 판매 기록 없음" % [GuestSession.item_label(item), GuestSession.item_count(item)]
	var high: Dictionary = record.highest_sale
	var low: Dictionary = record.lowest_sale
	return "%s · 보유 %d개 · 최고 %s(%s) · 최저 %s(%s)" % [GuestSession.item_label(item), GuestSession.item_count(item), GuestSession.format_nut(int(high.unit_price)), high.to, GuestSession.format_nut(int(low.unit_price)), low.to]

func _memory_choice_text(entry: Dictionary) -> String:
	var action := "전시 해제" if GuestSession.memory_frame.has(int(entry.id)) else "액자에 전시"
	return "%s · #%d %s" % [action, entry.id, _memory_subject(entry)]

func _memory_subject(entry: Dictionary) -> String:
	return str(entry.get("item", entry.get("asset", entry.get("type", "추억"))))

func _add_close(box: VBoxContainer) -> void:
	var close_button := Button.new()
	close_button.text = "닫기"
	close_button.custom_minimum_size.y = 42
	close_button.pressed.connect(close)
	box.add_child(close_button)

func close() -> void:
	_set_world_hud_visible(true)
	closed.emit()
	queue_free()

func _set_world_hud_visible(shown: bool) -> void:
	for node_name in ["TimeBar", "Currency", "Instructions", "Status", "Hint"]:
		var hud_node := get_parent().get_node_or_null(NodePath(node_name)) as CanvasItem
		if hud_node != null:
			hud_node.visible = shown
