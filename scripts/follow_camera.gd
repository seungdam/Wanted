extends Camera2D

@export var target_path: NodePath = NodePath("../Player")
@export var tracking_enabled := true
@export_range(0.1, 20.0, 0.1) var tracking_speed := 5.0
@export var tracking_offset := Vector2(0, -90)
@onready var target: Node2D = get_node(target_path)
var initialized := false

func _process(delta: float) -> void:
	if not tracking_enabled:
		return
	var destination := target.global_position + tracking_offset
	if not initialized:
		global_position = destination
		initialized = true
	else:
		global_position = global_position.lerp(destination, 1.0 - exp(-maxf(tracking_speed, 0.1) * delta))
