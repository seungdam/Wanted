extends Node2D

const Building = preload("res://scripts/building.gd")
const NPC = preload("res://scenes/npc.tscn")
const NPC_SPAWNS: Array[Vector2i] = [Vector2i(3, 8), Vector2i(5, 9), Vector2i(6, 8), Vector2i(8, 8), Vector2i(11, 5), Vector2i(9, 12)]
@export_group("Map - restart to apply")
@export var map_size := Vector2i(32, 32)
@export_group("NPC Spawn - restart to apply")
@export_range(0, 128) var npc_count := 12
@export_range(0.1, 10.0) var npc_speed := 1.0
@export_group("Assets")
const TILE_SIZE := Vector2i(64, 32)
const BLOCKS: Array[Vector2i] = [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6), Vector2i(10, 9), Vector2i(10, 10), Vector2i(11, 10), Vector2i(3, 11), Vector2i(12, 3)]

@export var terrain_atlas: Texture2D # Three 64x32 tiles: grass, path, water.
@export var terrain_normal_atlas: Texture2D
@export var building_texture: Texture2D
@export var building_normal_texture: Texture2D
var astar := AStarGrid2D.new()
@onready var ground: TileMapLayer = $Ground
@onready var player = $Objects/Player
@onready var route_line: Line2D = $Route
@onready var status: Label = $HUD/Status

func _ready() -> void:
	map_size = map_size.clamp(Vector2i(16, 16), Vector2i(128, 128))
	build_ground()
	astar.region = Rect2i(Vector2i.ZERO, map_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for cell in ground.get_used_cells():
		if ground.get_cell_atlas_coords(cell).x == 2:
			astar.set_point_solid(cell)
	for cell in BLOCKS:
		astar.set_point_solid(cell)
		var building := Building.new()
		building.name = "Building_%d_%d" % [cell.x, cell.y]
		building.texture = building_texture
		building.normal_texture = building_normal_texture
		building.position = ground.map_to_local(cell) + Vector2(0, 14)
		building.height = 36.0 + (cell.x % 3) * 12.0
		$Objects.add_child(building)
	player.ground = ground
	player.advance(0.0)
	player.arrived.connect(_on_arrived)
	var destinations: Array[Vector2i] = []
	for cell in ground.get_used_cells():
		if is_walkable(cell):
			destinations.append(cell)
	var spawn_cells: Array[Vector2i] = NPC_SPAWNS.duplicate()
	for cell in destinations:
		if not spawn_cells.has(cell) and cell != player.current_cell:
			spawn_cells.append(cell)
	for index in range(mini(npc_count, spawn_cells.size())):
		var cell := spawn_cells[index]
		var npc = NPC.instantiate()
		npc.speed = npc_speed
		npc.name = "NPC_%d_%d" % [cell.x, cell.y]
		npc.current_cell = cell
		npc.grid_position = Vector2(cell)
		npc.ground = ground
		npc.navigation = astar
		npc.observer = player
		npc.destinations = destinations
		$Objects.add_child(npc)
		npc.advance(0.0)

func build_ground() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = TILE_SIZE
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var atlas := TileSetAtlasSource.new()
	atlas.texture = terrain_atlas if terrain_atlas != null else make_placeholder_atlas()
	if terrain_normal_atlas != null:
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = atlas.texture
		canvas.normal_texture = terrain_normal_atlas
		atlas.texture = canvas
	atlas.texture_region_size = TILE_SIZE
	for index in range(3):
		atlas.create_tile(Vector2i(index, 0))
	tiles.add_source(atlas, 0)
	ground.tile_set = tiles
	for x in range(map_size.x):
		for y in range(map_size.y):
			var kind := 0
			if x == 7 or x == 8 or y == 7 or y == 8:
				kind = 1
			if x >= 12 and x <= 15 and y >= 12 and y <= 15:
				kind = 2
			ground.set_cell(Vector2i(x, y), 0, Vector2i(kind, 0))

func make_placeholder_atlas() -> Texture2D:
	# Native Image drawing: no external artwork or image-generation dependency.
	var image := Image.create(192, 32, false, Image.FORMAT_RGBA8)
	var colors := [Color("548675"), Color("b7a783"), Color("397caa")]
	for index in range(3):
		for x in range(64):
			for y in range(32):
				var edge := absf((x + 0.5 - 32.0) / 32.0) + absf((y + 0.5 - 16.0) / 16.0)
				if edge <= 1.0:
					var color: Color = colors[index]
					image.set_pixel(index * 64 + x, y, color.darkened(0.17) if edge > 0.91 else color)
	return ImageTexture.create_from_image(image)

func is_walkable(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)

func request_move(cell: Vector2i) -> bool:
	if not is_walkable(cell):
		status.text = "Blocked tile or outside village. Choose open ground."
		return false
	var origin: Vector2i = player.path_origin()
	var path := astar.get_id_path(origin, cell)
	if path.is_empty():
		status.text = "No reachable route."
		return false
	player.follow_path(path)
	status.text = "Moving to (%d, %d) / 8-direction A*" % [cell.x, cell.y]
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var local_click: Vector2 = ground.get_global_transform_with_canvas().affine_inverse() * event.position
		request_move(ground.local_to_map(local_click))
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	$VisionRange.visible = player.show_vision_range
	$VisionRange.position = player.position
	var outline := PackedVector2Array()
	var origin := ground.map_to_local(Vector2i.ZERO)
	for index in range(65):
		var offset := Vector2.from_angle(index * TAU / 64.0) * float(player.vision_radius)
		outline.append(offset.x * (ground.map_to_local(Vector2i.RIGHT) - origin) + offset.y * (ground.map_to_local(Vector2i.DOWN) - origin))
	$VisionRange.points = outline
	var points := PackedVector2Array()
	if not player.route.is_empty():
		points.append(player.position)
		for cell in player.route:
			points.append(ground.map_to_local(cell))
	route_line.points = points

func _on_arrived(cell: Vector2i) -> void:
	status.text = "Arrived at (%d, %d). Click another tile." % [cell.x, cell.y]
