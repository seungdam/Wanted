extends Node2D
const Terrain = preload("res://scripts/terrain_tiles.gd")
## Visual-only blocks. Ground remains the authoritative tile map for movement.
@export var drop_enabled := true
@export_range(16.0, 200.0, 8.0) var edge_band_pixels := 80.0
@export_range(0.0, 1.0, 0.05) var animated_fraction := 0.3
@export_range(0, 24) var max_active_drops := 6
@export_range(0.0, 256.0, 8.0) var screen_margin := 32.0
@export_range(0.0, 512.0, 8.0) var exit_margin := 128.0
@export_range(4.0, 96.0) var thickness := 12.0
@export_range(0.0, 800.0) var drop_height := 32.0
@export_range(0.1, 5.0, 0.05) var drop_seconds := 0.6
@export_range(0.0, 0.5, 0.01) var edge_sweep_seconds := 0.22
@export_range(0.0, 0.2, 0.01) var tile_stagger_seconds := 0.08
@export var left_soil := Color("ae8059")
@export var right_soil := Color("8b6047")
@export var grid_color := Color(0.12, 0.23, 0.18, 0.32)
@export_range(0.0, 4.0, 0.25) var grid_width := 0.0
var ground: TileMapLayer
var observer: Node2D
var ages: Dictionary = {}
var cells: Array[Vector2i] = []
var atlas: TileSetAtlasSource
var flat_colors: Array[Color] = []
var all_cells: Array[Vector2i] = []
var whole_world_visible := false

func setup(map: TileMapLayer, player: Node2D, colors: Array[Color] = []) -> void:
	ground = map
	observer = player
	flat_colors = colors
	atlas = ground.tile_set.get_source(0) as TileSetAtlasSource
	global_transform = ground.global_transform
	process_priority = 10 # Evaluate after camera tracking, including lerp and zoom.
	all_cells = ground.get_used_cells()
	ground.hide()
	update_reveal(0.0, true)

func _process(delta: float) -> void:
	if ground != null:
		update_reveal(delta)

func tile_screen_rect(cell: Vector2i) -> Rect2:
	var half := Vector2(ground.tile_set.tile_size) * 0.5
	return ground.get_global_transform_with_canvas() * Rect2(ground.map_to_local(cell) - half, half * 2.0)

func update_reveal(delta: float, initial: bool = false) -> void:
	var view := get_viewport_rect()
	var world_rect := Rect2()
	for index in range(all_cells.size()):
		var rect := tile_screen_rect(all_cells[index])
		world_rect = rect if index == 0 else world_rect.merge(rect)
	whole_world_visible = view.encloses(world_rect)
	var enter := view.grow(maxf(screen_margin, 0.0))
	var leave := enter.grow(maxf(exit_margin, 0.0))
	var changed := false
	var membership_changed := false
	var active_count := 0
	for age in ages.values():
		if age < drop_seconds:
			active_count += 1
	# ponytail: one scan is sufficient for this 256-tile demo; chunk for much larger maps.
	for cell in all_cells:
		var screen_rect := tile_screen_rect(cell)
		if not drop_enabled or whole_world_visible:
			if not is_landed(cell):
				ages[cell] = drop_seconds
				changed = true
				membership_changed = true
			continue
		if ages.has(cell):
			if ages[cell] < drop_seconds:
				ages[cell] = minf(ages[cell] + maxf(delta, 0.0), drop_seconds) if is_edge_tile(screen_rect, view) else drop_seconds
				changed = true
			if is_landed(cell) and not leave.intersects(screen_rect):
				ages.erase(cell)
				membership_changed = true
		elif enter.intersects(screen_rect):
			var animate := not initial and active_count < max_active_drops and is_edge_tile(screen_rect, view) and tile_variation(cell) < animated_fraction
			ages[cell] = -entry_delay(cell, screen_rect, view) if animate else drop_seconds
			if animate:
				active_count += 1
			membership_changed = true
	if membership_changed:
		cells.assign(ages.keys())
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x + a.y < b.x + b.y if a.x + a.y != b.x + b.y else a.x < b.x)
	# Never leave an actor standing over a falling support tile. NPC AI/visibility is unchanged.
	settle_support(observer)
	for resident in get_parent().residents:
		if resident.joined:
			settle_support(resident)
	if changed or membership_changed:
		queue_redraw()

func settle_support(actor: Node2D) -> void:
	var cell := Vector2i(actor.grid_position.round())
	if ages.has(cell) and not is_landed(cell):
		ages[cell] = drop_seconds
		queue_redraw()

func is_landed(cell: Vector2i) -> bool:
	return ages.has(cell) and ages[cell] >= drop_seconds

func is_edge_tile(screen_rect: Rect2, view: Rect2) -> bool:
	var center := screen_rect.get_center()
	var distance := minf(minf(absf(center.x - view.position.x), absf(center.x - view.end.x)), minf(absf(center.y - view.position.y), absf(center.y - view.end.y)))
	return view.grow(screen_margin).intersects(screen_rect) and distance <= edge_band_pixels

func tile_variation(cell: Vector2i) -> float:
	return float(posmod(cell.x * 73856093 ^ cell.y * 19349663, 1009)) / 1009.0

func entry_delay(cell: Vector2i, screen_rect: Rect2, view: Rect2) -> float:
	# Actual viewport entry determines the batch; sweep continuously along its nearest edge.
	# No distance bands, capped delays, or queue that can grow during rapid camera travel.
	var center := screen_rect.get_center()
	var horizontal_edge := minf(absf(center.y - view.position.y), absf(center.y - view.end.y))
	var vertical_edge := minf(absf(center.x - view.position.x), absf(center.x - view.end.x))
	var along := (center.x - view.position.x) / maxf(view.size.x, 1.0) if horizontal_edge < vertical_edge else (center.y - view.position.y) / maxf(view.size.y, 1.0)
	# Stable coordinate hash decorrelates neighbors without changing global RNG or re-entry style.
	var variation := tile_variation(cell)
	return clampf(along, 0.0, 1.0) * edge_sweep_seconds + variation * tile_stagger_seconds

func is_shown(cell: Vector2i) -> bool:
	return ages.has(cell) and ages[cell] >= 0.0

func drop_offset(cell: Vector2i) -> float:
	var progress := clampf(float(ages.get(cell, 0.0)) / drop_seconds, 0.0, 1.0)
	# One smooth descent, without the repeated bobbing of a landing bounce.
	return -drop_height * (1.0 - smoothstep(0.0, 1.0, progress))

func exposed_depth(cell: Vector2i, neighbor: Vector2i) -> float:
	return thickness if not is_shown(neighbor) else clampf(drop_offset(neighbor) - drop_offset(cell), 0.0, thickness)

func _draw() -> void:
	if ground == null:
		return
	var half := Vector2(ground.tile_set.tile_size) * 0.5
	for cell in cells:
		if not is_shown(cell):
			continue
		var center := ground.map_to_local(cell) + Vector2(0, drop_offset(cell))
		var bottom := center + Vector2(0, half.y)
		var kind := ground.get_cell_atlas_coords(cell).x
		var water := Terrain.water_depth(kind) > 0
		var left: Color = Terrain.BASE[kind].darkened(0.15) if water else left_soil
		var right: Color = Terrain.BASE[kind].darkened(0.3) if water else right_soil
		_draw_face(center + Vector2(-half.x, 0), bottom, exposed_depth(cell, cell + Vector2i.DOWN), left)
		_draw_face(bottom, center + Vector2(half.x, 0), exposed_depth(cell, cell + Vector2i.RIGHT), right)
		if not flat_colors.is_empty():
			# Exact shared edges avoid transparent atlas seams when enlarging placeholder tiles.
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -half.y), center + Vector2(half.x, 0), bottom, center + Vector2(-half.x, 0)]), flat_colors[ground.get_cell_atlas_coords(cell).x])
		else:
			var source := Rect2(Vector2(ground.get_cell_atlas_coords(cell)) * Vector2(atlas.texture_region_size), Vector2(atlas.texture_region_size))
			draw_texture_rect_region(atlas.texture, Rect2(center - half, half * 2.0), source)
		if grid_width > 0.0:
			var top := center + Vector2(0, -half.y)
			draw_polyline(PackedVector2Array([top, center + Vector2(half.x, 0), bottom, center + Vector2(-half.x, 0), top]), grid_color, grid_width, true)

func _draw_face(a: Vector2, b: Vector2, depth: float, color: Color) -> void:
	if depth < 0.01:
		return
	var down := Vector2(0, depth)
	draw_colored_polygon(PackedVector2Array([a, b, b + down, a + down]), color)
	var lip := Vector2(0, minf(depth, 3.0))
	draw_colored_polygon(PackedVector2Array([a, b, b + lip, a + lip]), color.lightened(0.18))
