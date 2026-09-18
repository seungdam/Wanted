extends Node2D

const Building = preload("res://scripts/building.gd")
const Terrain = preload("res://scripts/terrain_tiles.gd")
const NPC = preload("res://scenes/npc.tscn")
const NPC_SPAWNS: Array[Vector2i] = [Vector2i(3, 8), Vector2i(5, 9), Vector2i(6, 8), Vector2i(8, 8), Vector2i(11, 5), Vector2i(9, 12)]
@export_group("Map - restart to apply")
@export var map_size := Vector2i(16, 16)
@export_group("NPC Spawn - restart to apply")
@export_range(1, 4) var npc_count := 4
@export var resident_join_days: Array[int] = [1, 2, 3, 4]
const RESIDENT_COLORS: Array[Color] = [Color("60834d"), Color("bb7858"), Color("6e91a0"), Color("c3a151")]
var residents: Array[Node2D] = []
@export_range(0.1, 10.0) var npc_speed := 1.0
@export_group("Assets")
const TILE_SIZE := Vector2i(128, 64)
const ATLAS_TILE_SIZE := Vector2i(64, 32)
const TERRAIN_COLORS = Terrain.BASE
const BLOCKS: Array[Vector2i] = [Vector2i(4, 4), Vector2i(10, 5), Vector2i(10, 10), Vector2i(4, 11)]

@export var terrain_atlas: Texture2D # Six material columns x 16 edge-mask rows, each 64x32.
@export var terrain_normal_atlas: Texture2D
@export var building_texture: Texture2D
@export var building_normal_texture: Texture2D
@export_file("*.json") var layout_path := "res://data/village_layout.json"
var layout: Dictionary = {}
const PROP_TEXTURES := {
	"tree": preload("res://assets/world/ready/tree.png"),
	"rocks": preload("res://assets/world/ready/rocks.png"),
	"flowers": preload("res://assets/world/ready/flowers.png")
}
const PROP_FEET := {"tree": Vector2(32, 68), "rocks": Vector2(24, 30), "flowers": Vector2(20, 22)}
var astar := AStarGrid2D.new()
@onready var ground: TileMapLayer = $Ground
@onready var player = $Objects/Player
@onready var route_line: Line2D = $Route
@onready var status: Label = $HUD/Status

func _ready() -> void:
	map_size = map_size.clamp(Vector2i(16, 16), Vector2i(128, 128))
	layout = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	assert(layout.has("terrain_rows") and layout.has("props"), "Invalid village layout")
	build_ground()
	build_navigation()
	spawn_buildings()
	spawn_props()
	player.ground = ground
	player.advance(0.0)
	player.arrived.connect(_on_arrived)
	spawn_npcs()
	update_residents($WorldClock.day)
	$Camera2D._process(0.0)
	$Camera2D.force_update_scroll()
	$TerrainReveal.setup(ground, player)

func build_navigation() -> void:
	astar.region = Rect2i(Vector2i.ZERO, map_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for cell in ground.get_used_cells():
		if Terrain.water_depth(ground.get_cell_atlas_coords(cell).x) > 0:
			astar.set_point_solid(cell)
	for cell in BLOCKS:
		astar.set_point_solid(cell)
	for entry in layout.props:
		if entry.kind != "flowers":
			astar.set_point_solid(Vector2i(entry.cell[0], entry.cell[1]))

func spawn_props() -> void:
	for entry in layout.props:
		var cell := Vector2i(entry.cell[0], entry.cell[1])
		var prop := Building.new()
		prop.name = "Prop_%s_%d_%d" % [entry.kind, cell.x, cell.y]
		prop.set_meta("ground_cell", cell)
		prop.texture = PROP_TEXTURES[entry.kind]
		prop.sprite_offset = prop.texture.get_size() * 0.5 - PROP_FEET[entry.kind]
		prop.position = ground.to_global(ground.map_to_local(cell))
		prop.scale = ground.scale
		prop.observer = player
		$Objects.add_child(prop)

func spawn_buildings() -> void:
	for cell in BLOCKS:
		var building := Building.new()
		building.name = "Building_%d_%d" % [cell.x, cell.y]
		building.set_meta("ground_cell", cell)
		building.texture = building_texture
		building.normal_texture = building_normal_texture
		building.position = ground.to_global(ground.map_to_local(cell)) + Vector2(0, 24)
		building.scale = Vector2(2, 2)
		building.height = 44.0
		building.observer = player
		$Objects.add_child(building)

func spawn_npcs() -> void:
	var destinations: Array[Vector2i] = []
	for cell in ground.get_used_cells():
		if is_walkable(cell):
			destinations.append(cell)
	var spawn_cells: Array[Vector2i] = NPC_SPAWNS.duplicate()
	for cell in destinations:
		if not spawn_cells.has(cell) and cell != player.current_cell:
			spawn_cells.append(cell)
	for index in range(mini(clampi(npc_count, 1, 4), spawn_cells.size())):
		var cell := spawn_cells[index]
		var npc = NPC.instantiate()
		npc.speed = npc_speed
		npc.name = "NPC_%d_%d" % [cell.x, cell.y]
		npc.current_cell = cell
		npc.grid_position = Vector2(cell)
		npc.ground = ground
		npc.navigation = astar
		npc.body_color = RESIDENT_COLORS[index]
		npc.join_day = clampi(resident_join_days[index], 1, 5) if index < resident_join_days.size() else index + 1
		npc.destinations = destinations
		$Objects.add_child(npc)
		npc.advance(0.0)
		residents.append(npc)

func build_ground() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = ATLAS_TILE_SIZE
	ground.scale = Vector2(TILE_SIZE) / Vector2(ATLAS_TILE_SIZE)
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var atlas := TileSetAtlasSource.new()
	atlas.texture = terrain_atlas if terrain_atlas != null else make_placeholder_atlas()
	if terrain_normal_atlas != null:
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = atlas.texture
		canvas.normal_texture = terrain_normal_atlas
		atlas.texture = canvas
	atlas.texture_region_size = ATLAS_TILE_SIZE
	for index in range(Terrain.CODES.length()):
		for mask in range(16):
			atlas.create_tile(Vector2i(index, mask))
	tiles.add_source(atlas, 0)
	ground.tile_set = tiles
	for x in range(map_size.x):
		for y in range(map_size.y):
			var cell := Vector2i(x, y)
			ground.set_cell(cell, 0, Vector2i(resolved_terrain(cell), 0))
	for cell in ground.get_used_cells():
		var kind := ground.get_cell_atlas_coords(cell).x
		var neighbors: Array[int] = []
		for direction in Terrain.DIRECTIONS:
			neighbors.append(ground.get_cell_atlas_coords(cell + direction).x)
		ground.set_cell(cell, 0, Vector2i(kind, Terrain.edge_mask(kind, neighbors)))

func terrain_kind(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
		return -1
	if cell.y >= layout.terrain_rows.size() or cell.x >= layout.terrain_rows[cell.y].length():
		return Terrain.Kind.GRASS
	var kind := Terrain.CODES.find(layout.terrain_rows[cell.y][cell.x])
	assert(kind >= 0, "Unknown terrain code")
	return kind

func resolved_terrain(cell: Vector2i) -> int:
	var kind := terrain_kind(cell)
	if kind != Terrain.Kind.WATER:
		return kind
	# W is automatic depth; explicit S/D stay authored. The map boundary is open water.
	var shore_distance := 3
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var distance := absi(dx) + absi(dy)
			if distance == 0 or distance > 2:
				continue
			var neighbor := terrain_kind(cell + Vector2i(dx, dy))
			if neighbor >= 0 and Terrain.water_depth(neighbor) == 0:
				shore_distance = mini(shore_distance, distance)
	return [Terrain.Kind.SHALLOW, Terrain.Kind.WATER, Terrain.Kind.DEEP][shore_distance - 1]

func make_placeholder_atlas() -> Texture2D:
	# Native Image drawing: no external artwork or image-generation dependency.
	var image := Image.create(384, 32, false, Image.FORMAT_RGBA8)
	for index in range(Terrain.CODES.length()):
		for x in range(64):
			for y in range(32):
				var edge := absf((x + 0.5 - 32.0) / 32.0) + absf((y + 0.5 - 16.0) / 16.0)
				if edge <= 1.0:
					var color: Color = TERRAIN_COLORS[index]
					var noise := posmod(x * 37 + y * 17 + index * 13, 97)
					if noise < 7:
						color = color.lightened(0.08)
					elif noise > 90:
						color = color.darkened(0.06)
					if Terrain.water_depth(index) > 0 and y % 7 == 0 and x % 13 < 5:
						color = Color("b3d8cb")
					image.set_pixel(index * 64 + x, y, color)
	return ImageTexture.create_from_image(Terrain.make_variants(image))

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

func update_residents(day: int) -> void:
	for npc in residents:
		npc.set_joined(day >= npc.join_day)

func _process(_delta: float) -> void:
	update_residents($WorldClock.day)
	for building in $Objects.get_children():
		if building.has_meta("ground_cell"):
			building.visible = $TerrainReveal.is_landed(building.get_meta("ground_cell"))
	var points := PackedVector2Array()
	if not player.route.is_empty():
		points.append(player.position)
		for cell in player.route:
			points.append(ground.to_global(ground.map_to_local(cell)))
	route_line.points = points

func _on_arrived(cell: Vector2i) -> void:
	status.text = "Arrived at (%d, %d). Click another tile." % [cell.x, cell.y]
