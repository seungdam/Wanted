extends Control
## Manual test scene: deliberately separate from the village's object placement.
var demo = preload("res://scripts/demo_core.gd").new()
var life = preload("res://scripts/life_core.gd").new()
@onready var sheet = get_node("/root/DialogScriptManager")
var residents: Array = []
var body: VBoxContainer
var message := "아침 뉴스 확인 → 도구 선택·채집 → 주민 교류 → 가구 제작·배치 → 오후 뉴스 → 정산"

func _ready() -> void:
	GuestSession.begin("도토리", "life-demo")
	# Start with empty pockets so gathering has a purpose. All tools are loaned in this test scene.
	GuestSession.inventory.clear()
	GuestSession.wood = 0
	sheet.load_file()
	for i in range(4):
		var npc = preload("res://scripts/npc.gd").new()
		npc.configure_trade(i, 1909 + i, 1)
		residents.append(npc)
	demo.begin()
	demo.start_next_day()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	_render()

func _exit_tree() -> void:
	for npc in residents:
		npc.free()

func _process(delta: float) -> void:
	life.tick(delta)
	if not life.pending_catch.is_empty():
		var indicator := body.get_node_or_null("CatchStatus") as Label
		if indicator != null:
			indicator.text = "포획 준비 %.1f초 · 1~2.5초 사이에 잡기!" % life.catch_elapsed

func _text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1000
	body.add_child(label)

func _button(row: Node, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(func():
		var result: Dictionary = action.call()
		message = str(result.get("reason", "완료")) if not result.get("ok", false) else str(result.get("lines", result.get("message", "완료")))
		_render()
	)
	row.add_child(button)

func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	body.add_child(row)
	return row

func _render() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_text("Bit & Bloom · 생활 데모 · %d/5일 · %s" % [demo.day, GuestSession.format_nut(GuestSession.nut)])
	_text(message)
	if demo.stage == "ended":
		var ending: Dictionary = demo.ending_data()
		_text("다섯 날의 추억 · 거래 %d번 · 선물 %d번 · 투자 %d번" % [ending.trades, ending.gifts, ending.investment_actions])
		_text("내 방에 놓은 가구 %d개 · 발견한 물건 %d종 · 전시한 추억 %d개" % [life.room.size(), GuestSession.collection.size(), GuestSession.memory_frame.size()])
		for npc in residents:
			_text("%s · 호감도 %d" % [npc.resident_name, npc.affection])
		return
	_text(str(demo.market.public_event("news2" if demo.stage == "news2" else "news1").news))
	var flow := _row()
	if demo.stage == "news1":
		_button(flow, "오후 소식", demo.advance_news)
	elif demo.stage == "news2":
		_button(flow, "하루 정산·휴식", demo.rest)
	else:
		_button(flow, "다음 날", demo.start_next_day)
		return
	_text("도구 대여 · 현재 " + life.tool)
	var tools_row := _row()
	for tool in ["hand", "axe", "pickaxe", "rod", "net"]:
		_button(tools_row, {"hand": "맨손", "axe": "도끼", "pickaxe": "곡괭이", "rod": "낚싯대", "net": "잠자리채"}[tool], func(): return life.equip(tool))
	var sources := _row()
	for id in life.rules.sources:
		_button(sources, str(life.rules.sources[id].label), func(): return life.harvest(id))
	var catch_status := Label.new()
	catch_status.name = "CatchStatus"
	body.add_child(catch_status)
	_button(body, "잡기!", life.catch_target)
	var inventory_text: Array[String] = []
	for item in GuestSession.inventory:
		inventory_text.append("%s %d개" % [life.label(item), GuestSession.item_count(item)])
	_text("가방 · " + " / ".join(inventory_text))
	for npc in residents:
		npc.refresh_trade_request(demo.day)
		_text("%s · 호감도 %d/20 · 요청 %s · %d볼트" % [npc.resident_name, npc.affection, life.label(npc.request_item), npc.request_price])
		var row := _row()
		_button(row, "일상 대화", func(): return npc.daily_talk(sheet))
		_button(row, "요청 물품 거래", func(): return _trade(npc))
		_button(row, "부탁 전달: " + life.label(npc.request_material), func(): return npc.complete_request(npc.request_material))
		for item in GuestSession.inventory:
			if GuestSession.item_count(item) > 0:
				_button(row, life.label(item) + " 선물", func(): return npc.receive_gift(item))
	_text("공방 · 재료를 판매할지 가구로 만들지 선택하세요")
	for id in life.rules.recipes:
		_button(body, "%s · %s" % [life.label(id), str(life.rules.recipes[id].materials)], func(): return life.craft(id))
	_text("내 방 · 빈 칸의 배치 버튼으로 꾸미고 회수할 수 있어요")
	for slot in range(int(life.rules.room_slots)):
		var row := _row()
		if life.room.has(slot):
			_button(row, "%d: %s 회수" % [slot + 1, life.label(life.room[slot])], func(): return life.remove(slot))
		else:
			for id in life.rules.recipes:
				_button(row, "%d: %s 배치" % [slot + 1, life.label(id)], func(): return life.place(id, slot))
	_text("거래소 · 버튼 한 번에 0.01주 · 투자 없이도 완주 가능")
	var investments := _row()
	for code in ["A", "E", "D"]:
		_button(investments, "%s 매수" % code, func(): return demo.market.buy(code, 1, demo.day))
		_button(investments, "%s 매도" % code, func(): return demo.market.sell(code, 1, demo.day))
	_text("도감 · 판매 최고/최저가는 판매 기록만 집계해요")
	for item in GuestSession.collection:
		var record := GuestSession.collection_record(item)
		_text(life.label(item) + (" · 최고 %s / 최저 %s" % [GuestSession.format_nut(int(record.highest_sale.unit_price)), GuestSession.format_nut(int(record.lowest_sale.unit_price))] if record.has("highest_sale") else " · 판매 기록 없음"))
	_text("추억 액자 · 기록을 선택하면 전시/해제")
	for entry in GuestSession.memory_entries():
		_button(body, "#%d %s %s" % [entry.id, entry.type, "전시 중" if entry.id in GuestSession.memory_frame else ""], func(): return {"ok": GuestSession.toggle_memory_frame(int(entry.id))})

func _trade(npc) -> Dictionary:
	if not npc.can_trade_today():
		return {"ok": false, "reason": "오늘 거래 한도야."}
	var offer := GuestSession.create_trade_offer(npc.resident_name, npc.request_item, npc.base_price, npc.request_price, npc.counter_offer_ceiling())
	var before: int = npc.affection
	var result := GuestSession.settle_resident_trade(offer, npc.resident_name)
	if result.ok:
		npc.complete_trade()
		result.entry.merge({"resident_id": npc.resident_id, "affection_before": before, "affection_after": npc.affection, "affection_delta": npc.affection - before})
	return result
