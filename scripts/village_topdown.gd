extends Node2D

const GRID_SIZE := Vector2i(10, 7)
const GRID_ORIGIN := Vector2(144, 120)
const CELL_SIZE := Vector2(96, 96)
const NPC_START_CELLS := {"Pin": Vector2i(2, 2), "Nut": Vector2i(7, 1), "Clip": Vector2i(7, 5), "Screw": Vector2i(1, 5), "Washer": Vector2i(5, 1), "VillagerC": Vector2i(9, 5), "VillagerB": Vector2i(4, 5), "Spanner": Vector2i(8, 3), "Rivet": Vector2i(1, 1), "Gear": Vector2i(6, 5), "Fuse": Vector2i(9, 1), "Diode": Vector2i(5, 3), "Coil": Vector2i(2, 5)}
const TradeDialogue = preload("res://scenes/ui/npc_trade_dialogue.tscn")

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

func _ready() -> void:
	player.position = cell_to_position(player_cell)
	random.randomize()
	_refresh_residents()

func _process(_delta: float) -> void:
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
	if event.keycode == KEY_B:
		get_tree().change_scene_to_file("res://scenes/shop.tscn")
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
	tween.finished.connect(func(): moving = false)

func cell_to_position(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * CELL_SIZE

func _refresh_residents() -> void:
	var clock := get_node_or_null("../WorldClock")
	var day: int = int(clock.get("day")) if clock != null else 1
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
