extends Node2D

const GRID_SIZE := Vector2i(10, 7)
const GRID_ORIGIN := Vector2(144, 120)
const CELL_SIZE := Vector2(96, 96)
const NPC_START_CELLS := {"Pin": Vector2i(2, 2), "Nut": Vector2i(7, 1), "Clip": Vector2i(7, 5), "Screw": Vector2i(1, 5), "Washer": Vector2i(5, 1), "VillagerC": Vector2i(9, 5), "VillagerB": Vector2i(4, 5), "Spanner": Vector2i(8, 3), "Rivet": Vector2i(1, 1), "Gear": Vector2i(6, 5), "Fuse": Vector2i(9, 1), "Diode": Vector2i(5, 3), "Coil": Vector2i(2, 5)}
const TradeDialogue = preload("res://scenes/ui/npc_trade_dialogue.tscn")
const LifeCoreScript = preload("res://scripts/life_core.gd")
const MarketCoreScript = preload("res://scripts/market_core.gd")
const EventDirectorScript = preload("res://scripts/event_director.gd")
const MockEventAIScript = preload("res://scripts/mock_event_ai.gd")
const MockMarketWidgetScript = preload("res://scripts/mock_market_widget.gd")
const TILE_ACTIONS := {
	Vector2i(0, 0): {"title": "채집", "source": "meadow_0", "color": Color("8fb76a")},
	Vector2i(9, 0): {"title": "수렵", "source": "butterflies_0", "color": Color("85b6c5")},
	Vector2i(0, 6): {"title": "상점", "scene": "res://scenes/shop.tscn", "color": Color("d9a456")},
	Vector2i(9, 6): {"title": "모의 거래", "market": true, "color": Color("b68ac7")},
}

@onready var player: Node2D = $Portraits/Player
var player_cell := Vector2i(4, 3)
var moving := false
var npc_cells: Dictionary = NPC_START_CELLS.duplicate()
var random := RandomNumberGenerator.new()
var wandering := {}
var interaction_open := false
var interaction_latch := ""
var interaction_menu: PanelContainer
var ring_menu: RingMenu
var life = LifeCoreScript.new()
var notice: Label
var market = MarketCoreScript.new()
var event_director = EventDirectorScript.new(market)
var mock_event_ai = MockEventAIScript.new()
var event_day := -1

func _ready() -> void:
	player.position = cell_to_position(player_cell)
	random.randomize()
	_add_action_tiles()
	_add_notice()
	market.load_data()
	_update_market_event($WorldClock.day)
	_refresh_residents()

func _process(delta: float) -> void:
	life.tick(delta)
	_update_market_event($WorldClock.day)
	_refresh_residents()
	_update_interaction()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_I:
		_toggle_ring_menu()
		get_viewport().set_input_as_handled()
		return
	if interaction_open or ring_menu != null or moving:
		return
	if event.keycode == KEY_R:
		get_tree().change_scene_to_file("res://scenes/room.tscn")
		return
	if event.keycode == KEY_SPACE and not life.pending_catch.is_empty():
		_show_result(life.catch_target())
		return
	var tools := {KEY_1: "hand", KEY_2: "axe", KEY_3: "pickaxe", KEY_4: "rod", KEY_5: "net"}
	if tools.has(event.keycode):
		life.equip(tools[event.keycode])
		_show_notice("도구 선택: %s" % tools[event.keycode])
		return
	var direction: Vector2i = {KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN}.get(event.keycode, Vector2i.ZERO)
	if direction != Vector2i.ZERO:
		move_player(direction)
		get_viewport().set_input_as_handled()

func _toggle_ring_menu() -> void:
	if interaction_open or moving:
		return
	if ring_menu != null:
		ring_menu.close()
		return
	ring_menu = RingMenu.new()
	$HUD.add_child(ring_menu)
	ring_menu.track(player)
	ring_menu.show_at(player.global_position)
	ring_menu.closed.connect(func(): ring_menu = null)

func move_player(direction: Vector2i) -> void:
	var next := player_cell + direction
	if next.x < 0 or next.y < 0 or next.x >= GRID_SIZE.x or next.y >= GRID_SIZE.y:
		return
	moving = true
	player_cell = next
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(player, "position", cell_to_position(next), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "scale", Vector2(0.28, 0.28), 0.07)
	tween.chain().tween_property(player, "scale", Vector2(0.25, 0.25), 0.09)
	tween.finished.connect(func():
		moving = false
		_enter_tile(next)
	)

func cell_to_position(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * CELL_SIZE

func _add_action_tiles() -> void:
	for cell in TILE_ACTIONS:
		var action: Dictionary = TILE_ACTIONS[cell]
		var marker := PanelContainer.new()
		marker.position = cell_to_position(cell) - Vector2(42, 42)
		marker.size = Vector2(84, 84)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(action.color, 0.75)
		style.border_color = Color("fff3cf")
		style.set_border_width_all(3)
		style.set_corner_radius_all(12)
		marker.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = str(action.title)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("423222"))
		marker.add_child(label)
		$Slots.add_child(marker)

func _add_notice() -> void:
	notice = Label.new()
	notice.position = Vector2(24, 84)
	notice.size = Vector2(500, 32)
	notice.add_theme_font_size_override("font_size", 16)
	notice.add_theme_color_override("font_color", Color("fff8e8"))
	$HUD.add_child(notice)

func _enter_tile(cell: Vector2i) -> void:
	var action: Dictionary = TILE_ACTIONS.get(cell, {})
	if action.is_empty():
		return
	if action.has("scene"):
		get_tree().change_scene_to_file(str(action.scene))
		return
	if action.has("market"):
		_open_mock_market()
		return
	_show_result(life.harvest(str(action.source)))

func _show_result(result: Dictionary) -> void:
	if result.get("waiting", false):
		_show_notice("포획 준비 완료 · 1~2.5초 뒤 SPACE를 누르세요.")
		return
	_show_notice(str(result.get("reason", "채집 완료")) if not result.get("ok", false) else "채집 완료 · %s" % result.entry.get("item", "자원"))

func _show_notice(message: String) -> void:
	notice.text = message

func _update_market_event(day: int) -> void:
	if event_day == day or market.cards.is_empty():
		return
	var result: Dictionary = event_director.start_day(day, mock_event_ai.proposal_for(day, event_director.valid_candidate_ids()))
	if result.get("ok", false):
		event_day = day

func _open_mock_market() -> void:
	if not GuestSession.is_action_unlocked("mock_investment"):
		_show_player_bubble("아직 모의 거래가 열리지 않았어.")
		return
	if market.active_card.is_empty():
		_show_notice("거래 가격을 준비하지 못했습니다.")
		return
	interaction_open = true
	var widget: Control = MockMarketWidgetScript.new()
	widget.call("configure", market, $WorldClock.day)
	$HUD.add_child(widget)
	widget.connect("finished", func(): interaction_open = false)

func _show_player_bubble(message: String) -> void:
	var previous := player.get_node_or_null("PlayerBubble")
	if previous != null:
		previous.queue_free()
	var bubble := Label.new()
	bubble.name = "PlayerBubble"
	bubble.text = message
	bubble.position = Vector2(-130, -222)
	bubble.size = Vector2(260, 72)
	bubble.scale = Vector2(3, 3)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_font_size_override("font_size", 20)
	bubble.add_theme_color_override("font_color", Color("493b2b"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8e8")
	style.border_color = Color("b8824f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	bubble.add_theme_stylebox_override("normal", style)
	player.add_child(bubble)
	get_tree().create_timer(2.8).timeout.connect(bubble.queue_free)

func _refresh_residents() -> void:
	var day: int = $WorldClock.day
	for npc_name in npc_cells:
		var npc := get_node("Portraits/%s" % npc_name) as VillagePortraitNpc
		npc.visible = day >= npc.join_day
		if npc.visible and not wandering.has(npc_name):
			npc.position = cell_to_position(npc_cells[npc_name])
			wandering[npc_name] = true
			wander(npc)

func _update_interaction() -> void:
	if interaction_open:
		return
	var nearby: VillagePortraitNpc
	for npc_name in npc_cells:
		var npc := get_node("Portraits/%s" % npc_name) as VillagePortraitNpc
		if npc.visible and npc_cells[npc_name].distance_to(player_cell) <= 1.0:
			nearby = npc
			break
	if nearby == null:
		interaction_latch = ""
		_hide_interaction_menu()
	elif interaction_latch != nearby.name:
		interaction_latch = nearby.name
		_show_interaction_menu(nearby)

func _show_interaction_menu(npc: VillagePortraitNpc) -> void:
	_hide_interaction_menu()
	interaction_menu = PanelContainer.new()
	interaction_menu.theme = preload("res://assets/ui/themes/cozy_meadow.tres")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8e8")
	style.border_color = Color("b8824f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	interaction_menu.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	interaction_menu.add_child(content)
	var title := Label.new()
	title.text = "%s에게 무엇을 할까요?" % npc.resident_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	content.add_child(title)
	var gift := Button.new()
	gift.text = "선물하기"
	gift.custom_minimum_size = Vector2(170, 38)
	content.add_child(gift)
	var trade := Button.new()
	trade.text = "거래하기"
	trade.custom_minimum_size = Vector2(170, 38)
	content.add_child(trade)
	var talk := Button.new()
	talk.text = "대화하기"
	talk.custom_minimum_size = Vector2(170, 38)
	content.add_child(talk)
	$HUD.add_child(interaction_menu)
	interaction_menu.position = Vector2(get_viewport_rect().size.x * 0.5 - 85.0, get_viewport_rect().size.y - 255.0)
	interaction_menu.pivot_offset = Vector2(85, 82)
	interaction_menu.scale = Vector2(0.82, 0.82)
	interaction_menu.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(interaction_menu, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(interaction_menu, "modulate:a", 1.0, 0.12).set_delay(0.05)
	gift.pressed.connect(func():
		_hide_interaction_menu()
		_open_interaction(npc)
	)
	trade.pressed.connect(func():
		_hide_interaction_menu()
		_open_trade(npc)
	)
	talk.pressed.connect(func():
		_hide_interaction_menu()
		npc.show_mood_bubble()
	)

func _hide_interaction_menu() -> void:
	if interaction_menu != null and is_instance_valid(interaction_menu):
		interaction_menu.queue_free()
	interaction_menu = null

func _open_interaction(npc: VillagePortraitNpc) -> void:
	interaction_open = true
	var dialogue := TradeDialogue.instantiate() as NpcTradeDialogue
	$HUD.add_child(dialogue)
	dialogue.begin(npc)
	dialogue.gift_requested.connect(func(_npc):
		var widget := GiftWidget.new()
		widget.configure(npc)
		$HUD.add_child(widget)
		widget.finished.connect(func(success: bool):
			if not success:
				interaction_open = false
				return
			var thanks := TradeDialogue.instantiate() as NpcTradeDialogue
			$HUD.add_child(thanks)
			thanks.begin_thanks(npc, widget.last_taste)
			thanks.closed.connect(func(): interaction_open = false)
		)
	)

func _open_trade(npc: VillagePortraitNpc) -> void:
	interaction_open = true
	var widget := TradeWidget.new()
	widget.configure(npc)
	$HUD.add_child(widget)
	widget.finished.connect(func(_success: bool): interaction_open = false)

func wander(npc: VillagePortraitNpc) -> void:
	while is_instance_valid(npc):
		await get_tree().create_timer(random.randf_range(1.2, 2.8)).timeout
		var current: Vector2i = npc_cells[npc.name]
		if interaction_open or not npc.visible or current.distance_to(player_cell) <= 1.0:
			continue
		if random.randf() < 0.35:
			npc.show_mood_bubble()
		var options: Array[Vector2i] = []
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var candidate: Vector2i = current + direction
			if candidate.x >= 0 and candidate.y >= 0 and candidate.x < GRID_SIZE.x and candidate.y < GRID_SIZE.y and candidate != player_cell:
				options.append(candidate)
		if options.is_empty():
			continue
		var destination: Vector2i = options[random.randi_range(0, options.size() - 1)]
		npc_cells[npc.name] = destination
		var tween := create_tween().set_parallel(true)
		tween.tween_property(npc, "position", cell_to_position(destination), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(npc, "scale", Vector2(0.27, 0.27), 0.1)
		tween.chain().tween_property(npc, "scale", Vector2(0.25, 0.25), 0.12)
		await tween.finished
