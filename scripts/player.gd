extends Node2D
## Position is the character's feet. Assign Sprite2D.texture to replace the shapes.
signal arrived(cell: Vector2i)
signal facing_changed(direction: Vector2i)

@export var speed: float = 3.5 # Grid units per second; projection keeps world speed uniform.
@export var body_color := Color("60834d")
@export var selection_ring := true
var current_cell := Vector2i(7, 9)
var facing := Vector2i(0, 1)
var route: Array[Vector2i] = []
var grid_position := Vector2(7, 9)
var ground: TileMapLayer

func _ready() -> void:
	if $Sprite2D.texture == null:
		$Sprite2D.texture = preload("res://scripts/pixel_art.gd").resident(body_color)
		$Sprite2D.position = Vector2(0, -22)
	$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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
	global_position = ground.to_global(origin + grid_position.x * (ground.map_to_local(Vector2i.RIGHT) - origin) + grid_position.y * (ground.map_to_local(Vector2i.DOWN) - origin))
	$Sprite2D.flip_h = facing.x - facing.y < 0
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 12.0, Color(0.19, 0.14, 0.09, 0.3))
	if selection_ring:
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 12, Color("f5d995"), 1.0, false)
