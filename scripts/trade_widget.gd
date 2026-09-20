class_name TradeWidget
extends Control

signal finished(success: bool)
const Portrait = preload("res://scripts/resident_portrait.gd")
const CozyTheme = preload("res://assets/ui/themes/cozy_meadow.tres")
var offer_item: TradeItemCard
var drop_slot: TradeDropSlot
var prompt: Label
var confirm: Button
var counter_button: Button
var counter_controls: HBoxContainer
var counter_price_label: Label
var offered_price := 12
var asking_price := 12
var target_npc
var requested_item := "wood"
var trade_offer: Dictionary = {}

func configure(npc) -> void:
	target_npc = npc
	requested_item = npc.request_item
	offered_price = npc.request_price
	asking_price = offered_price
	trade_offer = GuestSession.create_trade_offer(npc.resident_name, requested_item, npc.base_price, offered_price, npc.counter_offer_ceiling())

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.10, 0.07, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-430, -250)
	panel.size = Vector2(860, 500)
	panel.theme = CozyTheme
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 76)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_right", 76)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 72
	box.add_child(header)
	var portrait := Portrait.new()
	portrait.resident_id = target_npc.resident_id if target_npc != null else "rivet"
	portrait.custom_minimum_size = Vector2(72, 72)
	header.add_child(portrait)
	var title := Label.new()
	var resident_name: String = target_npc.resident_name if target_npc != null else "리벳"
	var context: String = target_npc.request_context() if target_npc != null else "평온 · 천천히 조건을 맞춰 보자."
	title.text = "%s과 거래하기\n%s 1개를 %d볼트에 살게.\n%s" % [resident_name, GuestSession.item_label(requested_item), offered_price, context]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("684329"))
	header.add_child(title)
	var inventory := HBoxContainer.new()
	inventory.custom_minimum_size.y = 100
	box.add_child(inventory)
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 10)
	inventory.add_child(choices)
	offer_item = TradeItemCard.new()
	offer_item.item = requested_item
	offer_item.custom_minimum_size = Vector2(88, 88)
	_add_slot_background(offer_item, true)
	var item_icon := ItemIcon.new()
	item_icon.kind = requested_item
	item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offer_item.add_child(item_icon)
	var amount := Label.new()
	amount.text = "×%d" % GuestSession.item_count(requested_item)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.add_theme_color_override("font_color", Color("684329"))
	amount.add_theme_font_size_override("font_size", 14)
	offer_item.add_child(amount)
	choices.add_child(offer_item)
	for unused in range(4):
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(88, 88)
		empty.add_theme_stylebox_override("panel", _slot_style(false))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choices.add_child(empty)
	var transfer := HBoxContainer.new()
	transfer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(transfer)
	var arrow := Label.new()
	arrow.text = "선택한 아이템   →"
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 18)
	transfer.add_child(arrow)
	drop_slot = TradeDropSlot.new()
	drop_slot.required_item = requested_item
	drop_slot.custom_minimum_size = Vector2(88, 88)
	drop_slot.item_dropped.connect(_on_item_dropped)
	transfer.add_child(drop_slot)
	prompt = Label.new()
	prompt.text = "무엇을 줄까?"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 28)
	prompt.add_theme_color_override("font_color", Color("594b3d"))
	box.add_child(prompt)
	counter_controls = HBoxContainer.new()
	counter_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_controls.add_theme_constant_override("separation", 8)
	counter_controls.hide()
	box.add_child(counter_controls)
	var lower := Button.new()
	lower.text = "−"
	lower.pressed.connect(func(): _change_asking_price(-1))
	counter_controls.add_child(lower)
	counter_price_label = Label.new()
	counter_price_label.custom_minimum_size.x = 130
	counter_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counter_price_label.add_theme_font_size_override("font_size", 18)
	counter_controls.add_child(counter_price_label)
	var higher := Button.new()
	higher.text = "+"
	higher.pressed.connect(func(): _change_asking_price(1))
	counter_controls.add_child(higher)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var cancel := Button.new()
	cancel.text = "나중에 할게"
	cancel.pressed.connect(func(): _finish(false))
	actions.add_child(cancel)
	counter_button = Button.new()
	counter_button.text = "조건 바꾸기"
	counter_button.pressed.connect(_open_counter_offer)
	actions.add_child(counter_button)
	confirm = Button.new()
	confirm.text = "거래 확인"
	confirm.disabled = true
	confirm.pressed.connect(_confirm_trade)
	actions.add_child(confirm)

func _add_slot_background(card: PanelContainer, selected: bool) -> void:
	card.add_theme_stylebox_override("panel", _slot_style(selected))

func _slot_style(selected: bool) -> StyleBoxTexture:
	return CozyUIAtlas.slot_style(selected)

func _on_item_dropped() -> void:
	offer_item.hide()
	var moving := Label.new()
	moving.text = GuestSession.item_label(requested_item)
	moving.add_theme_font_override("font", preload("res://font/Moneygraphy-Pixel.ttf"))
	moving.add_theme_font_size_override("font_size", 22)
	moving.position = offer_item.get_global_rect().get_center() - Vector2(24, 14)
	add_child(moving)
	var tween := create_tween()
	tween.tween_property(moving, "position", drop_slot.get_global_rect().get_center() - Vector2(24, 14), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(moving, "scale", Vector2(1.25, 1.25), 0.2)
	tween.tween_callback(moving.queue_free)
	tween.tween_callback(func():
		prompt.text = "%s %d볼트 제안을 수락할까?" % [GuestSession.item_label(requested_item), offered_price]
		confirm.disabled = false
	)

func _open_counter_offer() -> void:
	if not drop_slot.delivered:
		prompt.text = "먼저 줄 아이템을 골라줘."
		return
	counter_controls.show()
	asking_price = offered_price
	_update_counter_price()
	counter_button.text = "제안 보내기"
	counter_button.pressed.disconnect(_open_counter_offer)
	counter_button.pressed.connect(_send_counter_offer)
	confirm.disabled = true
	prompt.text = "얼마를 받고 싶어?"

func _change_asking_price(change: int) -> void:
	asking_price = clampi(asking_price + change, 10, 18)
	_update_counter_price()

func _update_counter_price() -> void:
	counter_price_label.text = "%d볼트" % asking_price

func _send_counter_offer() -> void:
	var maximum: int = target_npc.counter_offer_ceiling() if target_npc != null else offered_price + 2
	if asking_price <= maximum:
		offered_price = asking_price
		trade_offer["offered_unit_price"] = offered_price
		trade_offer["counter_limit"] = maximum
		trade_offer["negotiation_result"] = "counter_accepted"
		counter_controls.hide()
		counter_button.hide()
		confirm.disabled = false
		prompt.text = target_npc.counter_offer_reply(offered_price) if target_npc != null else "좋아, %d볼트에 거래하자!" % offered_price
		return
	prompt.text = target_npc.counter_offer_reply(asking_price) if target_npc != null else "음… %d볼트까지는 괜찮아. 다시 골라볼래?" % maximum

func _confirm_trade() -> void:
	if not drop_slot.delivered:
		return
	if target_npc != null and not target_npc.can_trade_today():
		prompt.text = "오늘은 이 주민과 거래를 더 할 수 없어."
		return
	var resident_name: String = target_npc.resident_name if target_npc != null else "리벳"
	var affection_before: int = target_npc.affection if target_npc != null else 0
	trade_offer["offered_unit_price"] = offered_price
	var result := GuestSession.settle_resident_trade(trade_offer, resident_name, {"mood": target_npc.mood if target_npc != null else "평온", "event": GuestSession.market_event.id})
	if not result.ok:
		prompt.text = result.reason
		return
	if target_npc != null:
		target_npc.complete_trade()
		result.entry["affection_before"] = affection_before
		result.entry["affection_after"] = target_npc.affection
		result.entry["affection_delta"] = target_npc.affection - affection_before
	prompt.text = "거래 완료 · %d볼트와 추억 노드 1개를 얻었어!" % offered_price
	confirm.text = "마을로 돌아가기"
	confirm.disabled = false
	confirm.pressed.disconnect(_confirm_trade)
	confirm.pressed.connect(func(): _finish(true))

func _finish(success: bool) -> void:
	finished.emit(success)
	queue_free()
