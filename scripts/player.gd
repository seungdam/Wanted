extends Node2D
## Position is the character's feet. Character visuals live in the scene.
signal arrived(cell: Vector2i)
signal facing_changed(direction: Vector2i)

@export var speed: float = 3.5 # Grid units per second; projection keeps world speed uniform.
@export var body_color := Color("60834d")
@export var selection_ring := true
@export var idle_uses_last_direction := true
var current_cell := Vector2i(7, 9)
var facing := Vector2i(0, 1)
var route: Array[Vector2i] = []
var grid_position := Vector2(7, 9)
var external_motion := false
var animation_direction := Vector2.DOWN
var ground: TileMapLayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

func _ready() -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim_tree.active = true
	state_machine = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_set_animation(false)

func follow_path(path: Array[Vector2i]) -> void:
	# Finish the active edge before a new route: never cut through blocked corners.
	route = path.duplicate()

func path_origin() -> Vector2i:
	return route[0] if not route.is_empty() else current_cell

func _physics_process(delta: float) -> void:
	advance(delta)
	_set_animation(external_motion or not route.is_empty())
	external_motion = false

func advance(delta: float) -> void:
	if ground == null:
		return
	var budget := maxf(speed, 0.0) * delta
	while not route.is_empty():
		var target := Vector2(route[0])
		var distance := grid_position.distance_to(target)
		var segment_scale := 1.0
		var segment_budget := budget
		if distance > 0.0001:
			var direction := Vector2i(int(signf(target.x - grid_position.x)), int(signf(target.y - grid_position.y)))
			# Keep animation direction in lockstep with the actual route edge.
			# NPCs use this same path, so their row mapping matches the player.
			animation_direction = _grid_to_visual(direction)
			if direction != facing:
				facing = direction
				facing_changed.emit(facing)
			segment_scale = _grid_motion_scale(Vector2(direction))
			segment_budget = budget * segment_scale
		if distance > segment_budget:
			grid_position = grid_position.move_toward(target, segment_budget)
			break
		grid_position = target
		budget -= distance / maxf(segment_scale, 0.0001)
		current_cell = route.pop_front()
		if route.is_empty():
			arrived.emit(current_cell)
	_sync_world_position()

func move_manual(direction: Vector2, delta: float, visual_direction := Vector2.ZERO) -> void:
	if ground == null or direction.is_zero_approx():
		return
	route.clear()
	var normalized := direction.normalized()
	var next_facing := Vector2i(int(signf(normalized.x)), int(signf(normalized.y)))
	animation_direction = visual_direction if not visual_direction.is_zero_approx() else _grid_to_visual(normalized)
	if next_facing != facing:
		facing = next_facing
		facing_changed.emit(facing)
	var next_grid := grid_position + motion_delta(normalized, delta)
	var next_cell := Vector2i(roundi(next_grid.x), roundi(next_grid.y))
	if ground.get_cell_source_id(next_cell) < 0:
		return
	grid_position = next_grid
	current_cell = Vector2i(roundi(grid_position.x), roundi(grid_position.y))
	_sync_world_position()
	external_motion = true

func motion_delta(direction: Vector2, delta: float) -> Vector2:
	var normalized := direction.normalized()
	var projection_scale := _grid_motion_scale(normalized)
	return normalized * maxf(speed, 0.0) * delta * projection_scale

func _grid_motion_scale(direction: Vector2) -> float:
	if ground == null or direction.is_zero_approx():
		return 1.0
	var origin := ground.map_to_local(Vector2i.ZERO)
	var basis_x := ground.map_to_local(Vector2i.RIGHT) - origin
	var basis_y := ground.map_to_local(Vector2i.DOWN) - origin
	var projected := basis_x * direction.x + basis_y * direction.y
	var cardinal_length := (basis_x.length() + basis_y.length()) * 0.5
	return cardinal_length / maxf(projected.length(), 0.0001)

func _sync_world_position() -> void:
	if ground == null:
		return
	var origin := ground.map_to_local(Vector2i.ZERO)
	global_position = ground.to_global(origin + grid_position.x * (ground.map_to_local(Vector2i.RIGHT) - origin) + grid_position.y * (ground.map_to_local(Vector2i.DOWN) - origin))
	queue_redraw()

func _set_animation(moving: bool) -> void:
	var dir := _direction_point(animation_direction if moving or idle_uses_last_direction else Vector2.DOWN)
	var parameter := "parameters/walk/blend_position" if moving else "parameters/idle/blend_position"
	anim_tree.set(parameter, dir)
	if state_machine != null:
		state_machine.travel("walk" if moving else "idle")

func _direction_point(dir: Vector2) -> Vector2:
	if dir.is_zero_approx():
		return Vector2.DOWN
	var sx := signf(dir.x)
	var sy := signf(dir.y)
	if sx != 0.0 and sy != 0.0:
		return {
			Vector2(-1.0, -1.0): Vector2(-0.7, -0.7),
			Vector2(1.0, -1.0): Vector2(0.7, -0.7),
			Vector2(-1.0, 1.0): Vector2(-0.7, 0.7),
			Vector2(1.0, 1.0): Vector2(0.7, 0.7)
		}[Vector2(sx, sy)]
	return Vector2(sx, sy)

func _grid_to_visual(grid_dir: Vector2) -> Vector2:
	if ground == null:
		return grid_dir
	var origin := ground.map_to_local(Vector2i.ZERO)
	var basis_x := ground.map_to_local(Vector2i.RIGHT) - origin
	var basis_y := ground.map_to_local(Vector2i.DOWN) - origin
	return basis_x * grid_dir.x + basis_y * grid_dir.y

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 12.0, Color(0.19, 0.14, 0.09, 0.3))
	if selection_ring:
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 12, Color("f5d995"), 1.0, false)
