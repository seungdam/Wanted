extends Node2D
## Visual-only blocks. Ground remains the authoritative tile map for movement.
@export_range(1.0, 30.0, 0.5) var reveal_radius := 10.0
@export_range(0.0, 5.0, 0.5) var reveal_margin := 2.0
@export_range(0.5, 5.0, 0.5) var exit_margin := 2.0
@export_range(4.0, 96.0) var thickness := 48.0
@export_range(0.0, 800.0) var drop_height := 320.0
@export_range(0.1, 5.0, 0.05) var drop_seconds := 1.8
@export_range(0.0, 0.3, 0.01) var wave_delay := 0.12
@export_range(1.0, 4.0, 0.5) var wave_band_width := 2.0
@export var left_soil := Color("ae8059")
@export var right_soil := Color("8b6047")
@export var grid_color := Color(0.12, 0.23, 0.18, 0.32)
@export_range(0.0, 4.0, 0.25) var grid_width := 1.5
var ground: TileMapLayer
var observer: Node2D
var ages: Dictionary = {}
var cells: Array[Vector2i] = []
var atlas: TileSetAtlasSource
var flat_colors: Array[Color] = []
var last_center := Vector2.INF
var last_radius := -1.0

func setup(map: TileMapLayer, player: Node2D, colors: Array[Color] = []) -> void:
	ground = map
	observer = player
	flat_colors = colors
	atlas = ground.tile_set.get_source(0) as TileSetAtlasSource
	ground.hide()
	update_reveal(0.0, true)

func _process(delta: float) -> void:
	if ground != null:
		update_reveal(delta)

func update_reveal(delta: float, initial: bool = false) -> void:
	var center: Vector2 = observer.grid_position
	var radius := reveal_radius + reveal_margin
	var changed := false
	var membership_changed := false
	for cell: Vector2i in ages.keys():
		if ages[cell] < drop_seconds:
			ages[cell] = minf(ages[cell] + maxf(delta, 0.0), drop_seconds)
			changed = true
		# Finish active drops before retiring them; the wider exit band prevents flicker.
		if ages[cell] >= drop_seconds and Vector2(cell).distance_to(center) > radius + exit_margin:
			ages.erase(cell)
			membership_changed = true
	if center != last_center or radius != last_radius or initial:
		# ponytail: scan only the reveal square; use spatial chunks if radii exceed 30 tiles.
		var bounds := ground.get_used_rect()
		for x in range(maxi(bounds.position.x, floori(center.x - radius)), mini(bounds.end.x, ceili(center.x + radius) + 1)):
			for y in range(maxi(bounds.position.y, floori(center.y - radius)), mini(bounds.end.y, ceili(center.y + radius) + 1)):
				var cell := Vector2i(x, y)
				var distance := Vector2(cell).distance_to(center)
				if distance > radius or ages.has(cell) or ground.get_cell_source_id(cell) == -1:
					continue
				# Capture heading at entry: turning never restarts an existing drop.
				var relative := Vector2(cell) - center
				var heading := Vector2(observer.facing)
				var start_settled := initial and (distance <= 3.0 or relative.dot(heading) <= 0.0)
				ages[cell] = drop_seconds if start_settled else -entry_delay(relative, heading)
				membership_changed = true
		last_center = center
		last_radius = radius
	if membership_changed:
		cells.assign(ages.keys())
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x + a.y < b.x + b.y if a.x + a.y != b.x + b.y else a.x < b.x)
	if changed or membership_changed:
		queue_redraw()

func is_landed(cell: Vector2i) -> bool:
	return ages.has(cell) and ages[cell] >= drop_seconds

func entry_delay(relative: Vector2, heading: Vector2) -> float:
	var forward := heading.normalized() if not heading.is_zero_approx() else Vector2.DOWN
	# Broad, symmetric fan: travel direction leads; sideways spread follows gently.
	var travel := maxf(relative.dot(forward), 0.0) + absf(relative.cross(forward)) * 0.35
	return floorf(travel / maxf(wave_band_width, 1.0)) * wave_delay

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
		_draw_face(center + Vector2(-half.x, 0), bottom, exposed_depth(cell, cell + Vector2i.DOWN), left_soil)
		_draw_face(bottom, center + Vector2(half.x, 0), exposed_depth(cell, cell + Vector2i.RIGHT), right_soil)
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
	if depth <= 0.0:
		return
	var down := Vector2(0, depth)
	draw_colored_polygon(PackedVector2Array([a, b, b + down, a + down]), color)
	var lip := Vector2(0, minf(depth, 3.0))
	draw_colored_polygon(PackedVector2Array([a, b, b + lip, a + lip]), color.lightened(0.18))
