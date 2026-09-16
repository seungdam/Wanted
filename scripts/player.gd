extends Node2D
## Position is the character's feet. Assign Sprite2D.texture to replace the shapes.
signal arrived(cell: Vector2i)
signal facing_changed(direction: Vector2i)

@export var speed: float = 3.5 # Grid units per second; projection keeps world speed uniform.
@export var body_color := Color("399dd9")
@export var selection_ring := true
@export_group("Vision")
@export_range(0.5, 30.0, 0.5) var vision_radius: float = 9.0
@export_range(0.1, 5.0, 0.1) var vision_fade_width: float = 1.5
@export var show_vision_range := true
var current_cell := Vector2i(2, 7)
var facing := Vector2i(0, 1)
var route: Array[Vector2i] = []
var grid_position := Vector2(2, 7)
var ground: TileMapLayer

func follow_path(path: Array[Vector2i]) -> void:
	# Finish the active edge before a new route: never cut through blocked corners.
	route = path.duplicate()

func path_origin() -> Vector2i:
	return route[0] if not route.is_empty() else current_cell

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if ground == null:
		return
	var budget := maxf(speed, 0.0) * delta
	while not route.is_empty():
		var target := Vector2(route[0])
		var distance := grid_position.distance_to(target)
		if distance > 0.0001:
			var direction := Vector2i(signf(target.x - grid_position.x), signf(target.y - grid_position.y))
			if direction != facing:
				facing = direction
				facing_changed.emit(facing)
		if distance > budget:
			grid_position = grid_position.move_toward(target, budget)
			break
		grid_position = target
		budget -= distance
		current_cell = route.pop_front()
		if route.is_empty():
			arrived.emit(current_cell)
	var origin := ground.map_to_local(Vector2i.ZERO)
	position = origin + grid_position.x * (ground.map_to_local(Vector2i.RIGHT) - origin) + grid_position.y * (ground.map_to_local(Vector2i.DOWN) - origin)
	queue_redraw()

func _draw() -> void:
	if $Sprite2D.texture != null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 16.0, Color(0.02, 0.04, 0.06, 0.4))
	if selection_ring:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color("80eaff"), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_style_box(_body_style(), Rect2(-10, -30, 20, 26))
	draw_circle(Vector2(0, -37), 9, Color("f5d8a8"))
	var heading := Vector2(facing.x - facing.y, (facing.x + facing.y) * 0.5).normalized()
	draw_line(Vector2(0, -18), Vector2(0, -18) + heading * 15, Color.WHITE, 3.0, true)

func _body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = body_color
	style.set_corner_radius_all(6)
	return style
