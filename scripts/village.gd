extends Node2D

const NPC = preload("res://scenes/npc.tscn")
const TradeDialogue = preload("res://scenes/ui/npc_trade_dialogue.tscn")
const LifeCoreScript = preload("res://scripts/life_core.gd")
const ResourceNode = preload("res://scripts/resource_node.gd")
const MarketCoreScript = preload("res://scripts/market_core.gd")
const EventDirectorScript = preload("res://scripts/event_director.gd")
const MockEventAIScript = preload("res://scripts/mock_event_ai.gd")
const NPC_SPAWNS: Array[Vector2i] = [Vector2i(3, 8), Vector2i(5, 9), Vector2i(6, 8), Vector2i(8, 8), Vector2i(11, 5), Vector2i(9, 12)]

@export_group("NPC Spawn - restart to apply")
@export_range(1, 4) var npc_count := 4
@export var resident_join_days: Array[int] = [1, 2, 3, 4]
@export_group("Resident Trade Tuning - restart to apply")
@export var resident_trade_seeds: Array[int] = [1909, 2729, 4093, 5711]
@export_range(0, 5) var trade_affection := 1
@export_range(0, 5) var gift_affection := 3
@export_range(0, 5) var quest_affection := 4
@export_range(1, 4) var max_paid_trades_per_day := 2
@export_range(1, 5) var disliked_gift_affection_loss := 3
@export_range(0, 10) var disliked_gift_price_penalty := 2
@export_range(1, 3) var disliked_gift_penalty_days := 1

const INTERACTION_DISTANCE := 42.0
const TRADE_NOTICE_DISTANCE := 240.0
var residents: Array[Node2D] = []
@export_range(0.1, 10.0) var npc_speed := 0.6
@export_node_path("TileMapLayer") var npc_action_area_path: NodePath = NodePath("Ground")
var interaction_target: Node2D
var interaction_open := false
var ring_menu: RingMenu
var resident_day := -1
var astar := AStarGrid2D.new()
var life := LifeCoreScript.new()
var market := MarketCoreScript.new()
var event_director := EventDirectorScript.new(market)
var mock_event_ai := MockEventAIScript.new()
var event_day := -1
var resource_target: Node2D
var interaction_panel: PanelContainer
var interaction_label: Label
var interaction_panel_state := false

@onready var ground: TileMapLayer = $Ground
@onready var npc_action_area: TileMapLayer = get_node_or_null(npc_action_area_path) as TileMapLayer
@onready var player = $Objects/Player
@onready var status: Label = $HUD/Status

func _ready() -> void:
	build_navigation()
	if not is_walkable(player.current_cell):
		player.current_cell = _first_walkable_cell()
		player.grid_position = Vector2(player.current_cell)
	player.ground = ground
	player.advance(0.0)
	spawn_npcs()
	_spawn_resources()
	market.load_data()
	update_residents($WorldClock.day)
	$Camera2D._process(0.0)
	$Camera2D.force_update_scroll()
	$HUD/Instructions.text = "WASD 이동  /  1~5 도구  /  SPACE 상호작용  /  R 방  /  B 상점"
	$HUD/Status.text = "리벳에게 말을 걸어 첫 거래를 배워 보세요."
	_setup_currency()
	_setup_interaction_panel()
	var fade := $HUD/ArrivalFade
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.25)
	tween.tween_callback(fade.queue_free)

func build_navigation() -> void:
	var painted_cells := ground.get_used_cells()
	assert(not painted_cells.is_empty(), "Paint walkable cells on Ground in the editor before running Village.")
	astar.region = ground.get_used_rect().grow(1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for x in range(astar.region.position.x, astar.region.end.x):
		for y in range(astar.region.position.y, astar.region.end.y):
			astar.set_point_solid(Vector2i(x, y), true)
	for cell in painted_cells:
		astar.set_point_solid(cell, false)

func spawn_npcs() -> void:
	var action_area := npc_action_area if npc_action_area != null else ground
	var destinations: Array[Vector2i] = action_area.get_used_cells()
	var spawn_cells: Array[Vector2i] = NPC_SPAWNS.duplicate()
	for cell in destinations:
		if not spawn_cells.has(cell) and cell != player.current_cell:
			spawn_cells.append(cell)
	for index in range(mini(clampi(npc_count, 1, 4), spawn_cells.size())):
		var cell := spawn_cells[index]
		if not is_walkable(cell):
			continue
		var npc = NPC.instantiate()
		npc.speed = npc_speed
		npc.name = "NPC_%d_%d" % [cell.x, cell.y]
		npc.current_cell = cell
		npc.grid_position = Vector2(cell)
		npc.ground = ground
		npc.navigation = astar
		npc.join_day = clampi(resident_join_days[index], 1, 5) if index < resident_join_days.size() else index + 1
		var resident_seed := resident_trade_seeds[index] if index < resident_trade_seeds.size() else 1000 + index
		npc.configure_trade(index, resident_seed, $WorldClock.day, {
			"trade": trade_affection,
			"gift": gift_affection,
			"quest": quest_affection,
			"max_paid_trades": max_paid_trades_per_day,
			"disliked_gift_loss": disliked_gift_affection_loss,
			"disliked_gift_price_penalty": disliked_gift_price_penalty,
			"disliked_gift_penalty_days": disliked_gift_penalty_days
		})
		npc.name = "NPC_%s" % npc.resident_id
		npc.destinations = destinations
		$Objects.add_child(npc)
		npc.advance(0.0)
		residents.append(npc)

func is_walkable(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)

func _first_walkable_cell() -> Vector2i:
	for cell in ground.get_used_cells():
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if is_walkable(cell + direction):
				return cell
	return ground.get_used_cells().front()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and not interaction_open:
			get_tree().change_scene_to_file("res://scenes/room.tscn")
			return
		if event.keycode == KEY_B and not interaction_open:
			get_tree().change_scene_to_file("res://scenes/shop.tscn")
			return
		var tools := {KEY_1: "hand", KEY_2: "axe", KEY_3: "pickaxe", KEY_4: "rod", KEY_5: "net"}
		if tools.has(event.keycode):
			life.equip(tools[event.keycode])
			status.text = "도구 선택: %s" % tools[event.keycode]
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		_toggle_ring_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and not interaction_open:
		if resource_target != null:
			var result: Dictionary = resource_target.harvest()
			status.text = str(result.get("reason", "채집 완료")) if not result.get("ok", false) else "채집 완료 · %s" % result.entry.get("item", "자원")
		elif interaction_target != null:
			_begin_interaction()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if _movement_locked():
		return
	var raw_direction := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var direction := _input_to_grid(raw_direction)
	move_player(direction, raw_direction, delta)

func move_player(direction: Vector2, visual_direction: Vector2, delta: float) -> bool:
	if direction.is_zero_approx() or _movement_locked():
		return false
	# Callers pass a unit vector; clamp again so no future caller can make
	# diagonal input faster than cardinal input.
	var normalized := direction.normalized() if direction.length_squared() > 1.0 else direction
	var next_grid: Vector2 = player.grid_position + player.motion_delta(normalized, delta)
	var destination := Vector2i(roundi(next_grid.x), roundi(next_grid.y))
	if not is_walkable(destination):
		return false
	if normalized.x != 0.0 and normalized.y != 0.0:
		var side_x := Vector2i(roundi(next_grid.x), roundi(player.grid_position.y))
		var side_y := Vector2i(roundi(player.grid_position.x), roundi(next_grid.y))
		if not is_walkable(side_x) or not is_walkable(side_y):
			return false
	player.move_manual(normalized, delta, visual_direction)
	return true

func _input_to_grid(input_direction: Vector2) -> Vector2:
	if input_direction.is_zero_approx():
		return Vector2.ZERO
	var origin := ground.map_to_local(Vector2i.ZERO)
	var basis_x := ground.map_to_local(Vector2i.RIGHT) - origin
	var basis_y := ground.map_to_local(Vector2i.DOWN) - origin
	if input_direction.x != 0.0 and input_direction.y != 0.0:
		# Keep diagonal grid vectors intact; the isometric projection and
		# motion_delta() provide the TileMap angle/speed correction.
		return input_direction.normalized()
	# A single key is screen-cardinal; inverse-project it into grid space.
	var determinant := basis_x.x * basis_y.y - basis_x.y * basis_y.x
	if is_zero_approx(determinant):
		return input_direction.normalized()
	return Vector2(
		(input_direction.x * basis_y.y - input_direction.y * basis_y.x) / determinant,
		(basis_x.x * input_direction.y - basis_x.y * input_direction.x) / determinant
	).normalized()

func _movement_locked() -> bool:
	return interaction_open or (ring_menu != null and ring_menu.detail != null)

func update_residents(day: int) -> void:
	GuestSession.set_game_day(day)
	if resident_day == day:
		return
	resident_day = day
	for npc in residents:
		npc.set_joined(day >= npc.join_day)
		npc.refresh_trade_request(day)

func _process(_delta: float) -> void:
	update_residents($WorldClock.day)
	_update_market_event($WorldClock.day)
	_update_interaction_target()
	_update_interaction_panel()
	$HUD/Currency/Value.text = "%s  ·  추억 %d" % [GuestSession.format_nut(GuestSession.nut), GuestSession.blocks]

func _setup_interaction_panel() -> void:
	interaction_panel = PanelContainer.new()
	interaction_panel.name = "InteractionPanel"
	interaction_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8e8")
	style.border_color = Color("b8824f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	interaction_panel.add_theme_stylebox_override("panel", style)
	interaction_label = Label.new()
	interaction_label.add_theme_color_override("font_color", Color("493b2b"))
	interaction_label.add_theme_font_size_override("font_size", 14)
	interaction_panel.add_child(interaction_label)
	$HUD.add_child(interaction_panel)

func _update_interaction_panel() -> void:
	if interaction_panel == null:
		return
	var visible_prompt := interaction_target != null and not interaction_open and ring_menu == null
	if visible_prompt != interaction_panel_state:
		interaction_panel_state = visible_prompt
		if visible_prompt:
			_show_interaction_panel()
		else:
			_hide_interaction_panel()
	if not visible_prompt:
		return
	interaction_label.text = "SPACE  ·  %s에게 말 걸기" % interaction_target.resident_name
	var viewport_size := get_viewport_rect().size
	var player_screen_position: Vector2 = $Camera2D.get_canvas_transform() * player.global_position
	# Follow the player, but stay fully to the left of the rendered sprite.
	var left_edge := player_screen_position.x - 24.0
	var panel_x := left_edge - interaction_panel.size.x - 24.0
	var panel_y := player_screen_position.y - interaction_panel.size.y * 0.5
	interaction_panel.position = Vector2(clampf(panel_x, 8.0, viewport_size.x - interaction_panel.size.x - 8.0), clampf(panel_y, 8.0, viewport_size.y - interaction_panel.size.y - 8.0))

func _show_interaction_panel() -> void:
	interaction_panel.visible = true
	interaction_panel.pivot_offset = Vector2(interaction_panel.size.x, interaction_panel.size.y * 0.5)
	interaction_panel.scale = Vector2(0.82, 0.82)
	interaction_panel.modulate.a = 0.0
	interaction_label.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(interaction_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(interaction_panel, "modulate:a", 1.0, 0.12)
	tween.tween_property(interaction_label, "modulate:a", 1.0, 0.1).set_delay(0.08)

func _hide_interaction_panel() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(interaction_panel, "scale", Vector2(0.86, 0.86), 0.1)
	tween.tween_property(interaction_panel, "modulate:a", 0.0, 0.08)
	tween.chain().tween_callback(func(): interaction_panel.visible = false)

func _setup_currency() -> void:
	var panel := PanelContainer.new()
	panel.name = "Currency"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-268, 22)
	panel.size = Vector2(246, 54)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("fff8ea")
	paper.border_color = Color("684329")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(9)
	panel.add_theme_stylebox_override("panel", paper)
	$HUD.add_child(panel)
	var value := Label.new()
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_override("font", preload("res://font/Moneygraphy-Pixel.ttf"))
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", Color("527a35"))
	panel.add_child(value)

func _toggle_ring_menu() -> void:
	if interaction_open:
		return
	if ring_menu != null:
		ring_menu.close()
		return
	ring_menu = RingMenu.new()
	$HUD.add_child(ring_menu)
	ring_menu.track(player.get_node("Sprite2D"))
	ring_menu.show_at(player.get_node("Sprite2D").global_position)
	ring_menu.closed.connect(func(): ring_menu = null)

func _update_interaction_target() -> void:
	var nearest: Node2D
	var closest := INF
	for npc in residents:
		if npc.joined:
			var distance: float = player.global_position.distance_to(npc.global_position)
			if distance < closest:
				closest = distance
				nearest = npc
	interaction_target = nearest if closest <= INTERACTION_DISTANCE else null
	resource_target = null
	var resource_distance := INF
	for resource in $Objects/Resources.get_children():
		var distance: float = player.global_position.distance_to(resource.global_position)
		if distance < resource_distance:
			resource_distance = distance
			resource_target = resource
	if resource_distance > INTERACTION_DISTANCE:
		resource_target = null
	for npc in residents:
		var in_notice_range: bool = player.global_position.distance_to(npc.global_position) <= TRADE_NOTICE_DISTANCE
		npc.set_trade_request_visible(npc.joined and npc.can_trade_today() and in_notice_range and not interaction_open)
		npc.set_interaction_available(npc == interaction_target and not interaction_open)
		npc.set_player_nearby(npc == interaction_target and not interaction_open)

func _spawn_resources() -> void:
	var container := Node2D.new()
	container.name = "Resources"
	container.y_sort_enabled = true
	$Objects.add_child(container)
	var placements := [{"cell": Vector2i(2, 8), "source": "grove_0", "label": "나무", "tool": "axe"}, {"cell": Vector2i(10, 8), "source": "quarry_0", "label": "돌", "tool": "pickaxe"}, {"cell": Vector2i(7, 12), "source": "meadow_0", "label": "꽃", "tool": "hand"}]
	for placement in placements:
		var node := ResourceNode.new()
		node.name = str(placement.source)
		node.position = ground.map_to_local(placement.cell)
		node.source_id = str(placement.source)
		node.label = str(placement.label)
		node.tool = str(placement.tool)
		node.life = life
		node.player = player
		container.add_child(node)

func _update_market_event(day: int) -> void:
	if event_day == day or market.cards.is_empty():
		return
	var proposal: Dictionary = mock_event_ai.proposal_for(day, event_director.valid_candidate_ids())
	var result: Dictionary = event_director.start_day(day, proposal)
	if result.get("ok", false):
		event_day = day
		status.text = "오늘의 경제 사건: %s" % result.get("headline", "새 소식")

func _begin_interaction() -> void:
	interaction_open = true
	var active_target := interaction_target
	active_target.set_interacting(true)
	player.route.clear()
	var dialogue := TradeDialogue.instantiate() as NpcTradeDialogue
	$HUD.add_child(dialogue)
	dialogue.begin(active_target)
	dialogue.trade_requested.connect(func(_npc):
		if not active_target.can_trade_today():
			active_target.set_interacting(false)
			interaction_open = false
			status.text = "%s과(와)의 오늘 거래는 모두 마쳤어요." % active_target.resident_name
			return
		var widget := TradeWidget.new()
		widget.configure(active_target)
		$HUD.add_child(widget)
		widget.finished.connect(func(success: bool):
			active_target.set_interacting(false)
			interaction_open = false
			status.text = "추억 액자에 거래 노드 %d개 · 잔액 %s" % [GuestSession.blocks, GuestSession.format_nut(GuestSession.nut)] if success else "거래를 다음에 하기로 했어요."
		)
	)
	dialogue.gift_requested.connect(func(_npc):
		var widget := GiftWidget.new()
		widget.configure(active_target)
		$HUD.add_child(widget)
		widget.finished.connect(func(success: bool):
			active_target.set_interacting(false)
			interaction_open = false
			status.text = "선물의 마음이 추억 액자에 남았어요." if success else "선물은 다음에 건네도 괜찮아요."
		)
	)
	dialogue.talk_requested.connect(func(npc):
		var result: Dictionary = npc.daily_talk(DialogScriptManager)
		npc.set_interacting(false)
		interaction_open = false
		status.text = str(result.get("reason", "%s와 대화했어요." % npc.resident_name)) if not result.get("ok", false) else "%s와 대화했어요." % npc.resident_name
	)
	dialogue.closed.connect(func():
		active_target.set_interacting(false)
		interaction_open = false
		status.text = "추억 액자에 거래 노드 %d개 · 잔액 %s" % [GuestSession.blocks, GuestSession.format_nut(GuestSession.nut)]
	)
