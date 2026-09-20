class_name TradeWidget
extends Control

signal finished(success: bool)
const Portrait = preload("res://scripts/resident_portrait.gd")
const CozyTheme = preload("res://assets/ui/themes/cozy_meadow.tres")
var offer_item: TradeItemCard
var offer_cards: Array[TradeItemCard] = []
var offer_items: Array[String] = []
var drop_slot: TradeDropSlot
var prompt: Label
var confirm: Button
var counter_button: Button
var counter_controls: HBoxContainer
var counter_price_label: Label
var counter_slider: HSlider
var offer_section: HBoxContainer
var transfer: HBoxContainer
var wallet_line: Label
var codex_line: Label
var result_card: PanelContainer
var result_text: Label
var actions: HBoxContainer
var cancel: Button
var offered_price := 12
var asking_price := 12
var counter_min := 10
var counter_max := 14
var target_npc
var requested_item := "wood"
var trade_offer: Dictionary = {}
var wallet_before := 0
var codex_high_before := 0

func configure(npc) -> void:
	target_npc = npc
	offer_items = npc.trade_offer_items() if npc.has_method("trade_offer_items") else [npc.request_item, "stone" if npc.request_item != "stone" else "flower"]
	_select_offer(offer_items.front())

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
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
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
	var personality: String = target_npc.trade_personality() if target_npc != null and target_npc.has_method("trade_personality") else "주민"
	var remaining: int = 2 - (int(target_npc.paid_trade_count) if target_npc != null else 0)
	title.text = "%s  [%s]\n오늘 제안 2종 · 남은 거래 %d/2건" % [resident_name, personality, remaining]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("684329"))
	header.add_child(title)
	var speech := PanelContainer.new()
	var speech_style := StyleBoxFlat.new()
	speech_style.bg_color = Color("fff8e8")
	speech_style.border_color = Color("d7c49d")
	speech_style.set_border_width_all(2)
	speech_style.set_corner_radius_all(12)
	speech.add_theme_stylebox_override("panel", speech_style)
	var speech_text := Label.new()
	speech_text.text = target_npc.request_context() if target_npc != null else "천천히 조건을 맞춰 보자."
	speech_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_text.add_theme_font_size_override("font_size", 16)
	speech.add_child(speech_text)
	box.add_child(speech)
	offer_section = HBoxContainer.new()
	offer_section.custom_minimum_size.y = 92
	offer_section.alignment = BoxContainer.ALIGNMENT_CENTER
	offer_section.add_theme_constant_override("separation", 10)
	box.add_child(offer_section)
	for item in offer_items:
		_add_offer_card(item)
	transfer = HBoxContainer.new()
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
	wallet_line = Label.new()
	wallet_line.add_theme_font_size_override("font_size", 16)
	box.add_child(wallet_line)
	codex_line = Label.new()
	codex_line.add_theme_font_size_override("font_size", 14)
	box.add_child(codex_line)
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
	counter_slider = HSlider.new()
	counter_slider.custom_minimum_size = Vector2(210, 48)
	counter_slider.step = 1
	counter_slider.value_changed.connect(func(value): asking_price = roundi(value); _update_counter_price())
	counter_controls.add_child(counter_slider)
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
	var hint := Label.new()
	hint.text = "성격에 따라 수락 확률이 달라져요. 친구(호감 60+)면 +20%p · 거절돼도 호감도는 그대로예요."
	hint.custom_minimum_size.x = 250
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	counter_controls.add_child(hint)
	result_card = PanelContainer.new()
	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color("d6e6b8")
	result_style.border_color = Color("57854d")
	result_style.set_border_width_all(2)
	result_style.set_corner_radius_all(12)
	result_card.add_theme_stylebox_override("panel", result_style)
	result_text = Label.new()
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.add_theme_font_size_override("font_size", 15)
	result_card.add_child(result_text)
	result_card.hide()
	box.add_child(result_card)
	actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	cancel = Button.new()
	cancel.text = "나중에 할게"
	cancel.custom_minimum_size.y = 48
	cancel.pressed.connect(func(): _finish(false))
	actions.add_child(cancel)
	counter_button = Button.new()
	counter_button.text = "조건 바꾸기"
	counter_button.custom_minimum_size.y = 48
	counter_button.pressed.connect(_open_counter_offer)
	actions.add_child(counter_button)
	confirm = Button.new()
	confirm.text = "거래 확인"
	confirm.custom_minimum_size.y = 48
	confirm.disabled = true
	confirm.pressed.connect(_confirm_trade)
	actions.add_child(confirm)
	_refresh_info()

func _add_slot_background(card: PanelContainer, selected: bool) -> void:
	card.add_theme_stylebox_override("panel", _slot_style(selected))

func _slot_style(selected: bool) -> StyleBoxTexture:
	return CozyUIAtlas.slot_style(selected)

func _add_offer_card(item: String) -> void:
	var card := TradeItemCard.new()
	card.item = item
	card.custom_minimum_size = Vector2(88, 88)
	_add_slot_background(card, item == requested_item)
	var icon := ItemIcon.new()
	icon.kind = item
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -22
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	var label := Label.new()
	label.text = "%s\n%d볼트" % [GuestSession.item_label(item), _offer_price(item)]
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -26
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	card.add_child(label)
	card.selected.connect(_select_offer.bind(item))
	offer_section.add_child(card)
	offer_cards.append(card)
	if item == requested_item:
		offer_item = card

func _select_offer(item: String) -> void:
	requested_item = item
	offered_price = _offer_price(item)
	asking_price = offered_price
	counter_min = maxi(1, floori(offered_price * 0.85))
	counter_max = ceili(offered_price * 1.15)
	trade_offer = GuestSession.create_trade_offer(target_npc.resident_name, requested_item, target_npc.base_price, offered_price, counter_max) if target_npc != null else {}
	if drop_slot != null:
		drop_slot.reset(requested_item)
	for card in offer_cards:
		_add_slot_background(card, card.item == requested_item)
		if card.item == requested_item:
			offer_item = card
	if prompt != null:
		prompt.text = "%s을(를) 줄까?" % GuestSession.item_label(requested_item)
	if confirm != null:
		confirm.disabled = true
	_refresh_info()

func _refresh_info() -> void:
	if wallet_line == null:
		return
	var record := GuestSession.collection_record(requested_item)
	wallet_line.text = "내 지갑  %s" % GuestSession.format_nut(GuestSession.nut)
	codex_line.text = "도감: %s 누적 %d개 · 최고가 %s" % [GuestSession.item_label(requested_item), int(record.get("sold_count", 0)), GuestSession.format_nut(int(record.highest_sale.unit_price)) if record.has("highest_sale") else "기록 없음"]

func _offer_price(item: String) -> int:
	if target_npc == null:
		return offered_price
	return int(target_npc.trade_price(item)) if target_npc.has_method("trade_price") else int(target_npc.request_price)

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
	counter_slider.min_value = counter_min
	counter_slider.max_value = counter_max
	counter_slider.value = asking_price
	_update_counter_price()
	counter_button.text = "제안 보내기"
	counter_button.pressed.disconnect(_open_counter_offer)
	counter_button.pressed.connect(_send_counter_offer)
	confirm.disabled = true
	prompt.text = "제안가 %d볼트 · 역제안 범위 %d~%d볼트 (±15%%)" % [offered_price, counter_min, counter_max]

func _change_asking_price(change: int) -> void:
	asking_price = clampi(asking_price + change, counter_min, counter_max)
	counter_slider.value = asking_price
	_update_counter_price()

func _update_counter_price() -> void:
	counter_price_label.text = "%d볼트" % asking_price

func _send_counter_offer() -> void:
	if asking_price < counter_min or asking_price > counter_max:
		prompt.text = "역제안 범위 안에서 골라줘."
		return
	var accepted: bool = bool(target_npc.accepts_counter_offer()) if target_npc != null and target_npc.has_method("accepts_counter_offer") else (asking_price <= target_npc.counter_offer_ceiling() if target_npc != null else true)
	if accepted:
		offered_price = asking_price
		trade_offer["offered_unit_price"] = offered_price
		trade_offer["counter_limit"] = counter_max
		trade_offer["negotiation_result"] = "counter_accepted"
		counter_controls.hide()
		counter_button.hide()
		confirm.disabled = false
		prompt.text = target_npc.counter_dialogue(true, offered_price) if target_npc != null and target_npc.has_method("counter_dialogue") else "좋아, %d볼트에 거래하자!" % offered_price
		return
	trade_offer["negotiation_result"] = "counter_rejected"
	confirm.disabled = false
	prompt.text = target_npc.counter_dialogue(false, asking_price) if target_npc != null and target_npc.has_method("counter_dialogue") else "그 값은 안 돼. 원래 값으로 하자."

func _confirm_trade() -> void:
	if not drop_slot.delivered:
		return
	if target_npc != null and not target_npc.can_trade_today():
		prompt.text = "오늘은 이 주민과 거래를 더 할 수 없어."
		return
	var resident_name: String = target_npc.resident_name if target_npc != null else "리벳"
	var affection_before: int = target_npc.affection if target_npc != null else 0
	wallet_before = GuestSession.nut
	var before_record := GuestSession.collection_record(requested_item)
	codex_high_before = int(before_record.highest_sale.unit_price) if before_record.has("highest_sale") else 0
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
	var after_record := GuestSession.collection_record(requested_item)
	var high_after := int(after_record.highest_sale.unit_price) if after_record.has("highest_sale") else 0
	result_text.text = "거래 완료\n%s 1개 → %d볼트 · 추억 그래프 노드 +1\n호감도  %d → %d  (%+d)\n오늘 이 주민과 거래  %d / 2\n내 지갑  %s → %s\n도감 최고가  %s → %s" % [GuestSession.item_label(requested_item), offered_price, affection_before, target_npc.affection if target_npc != null else affection_before, target_npc.affection - affection_before if target_npc != null else 0, target_npc.paid_trade_count if target_npc != null else 0, GuestSession.format_nut(wallet_before), GuestSession.format_nut(GuestSession.nut), GuestSession.format_nut(codex_high_before), GuestSession.format_nut(high_after)]
	result_card.show()
	offer_section.hide()
	transfer.hide()
	wallet_line.hide()
	codex_line.hide()
	counter_controls.hide()
	prompt.text = target_npc.request_context() if target_npc != null else "거래가 성사됐어."
	cancel.hide()
	counter_button.hide()
	confirm.text = "마을로 돌아가기"
	confirm.disabled = false
	confirm.pressed.disconnect(_confirm_trade)
	confirm.pressed.connect(func(): _finish(true))

func _finish(success: bool) -> void:
	finished.emit(success)
	queue_free()
