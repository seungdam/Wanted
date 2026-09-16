extends "res://scripts/player.gd"

@export_range(0.1, 5.0) var fade_seconds: float = 0.35
@export_group("NPC Debug - live")
@export var ai_enabled := true
@export var ignore_vision := false
@export var override_rest_duration := false
@export_range(0.0, 30.0) var rest_min_seconds := 1.0
@export_range(0.0, 30.0) var rest_max_seconds := 3.0
var navigation: AStarGrid2D
var observer: Node2D
var destinations: Array[Vector2i] = []
var random := RandomNumberGenerator.new()
@onready var behavior: BTPlayer = $BTPlayer

func _ready() -> void:
	random.randomize()
	update_visibility(0.0, true)

func _physics_process(delta: float) -> void:
	if ai_enabled:
		if override_rest_duration:
			var rest := behavior.get_bt_instance().get_root_task().get_child(0) as BTRandomWait
			if rest != null:
				rest.min_duration = maxf(rest_min_seconds, 0.0)
				rest.max_duration = maxf(rest_max_seconds, rest.min_duration)
		behavior.update(delta)
	update_visibility(delta)

func choose_destination() -> bool:
	if navigation == null or destinations.is_empty():
		return false
	# Bounded retries avoid pathfinding spikes when a region is disconnected.
	for attempt in range(12):
		var target := destinations[random.randi_range(0, destinations.size() - 1)]
		if target == current_cell or navigation.is_point_solid(target):
			continue
		var path := navigation.get_id_path(current_cell, target)
		if path.size() > 1:
			follow_path(path)
			return true
	return false

func update_visibility(delta: float, instant: bool = false) -> void:
	if observer == null:
		visible = false
		return
	var radius: float = maxf(observer.vision_radius, 0.01)
	var width: float = clampf(observer.vision_fade_width, 0.01, radius)
	var distance: float = grid_position.distance_to(observer.grid_position)
	var target := 1.0 - smoothstep(radius - width, radius, distance)
	if ignore_vision:
		target = 1.0
	var alpha := target if instant else lerpf(modulate.a, target, 1.0 - exp(-delta * 6.0 / maxf(fade_seconds, 0.01)))
	if target == 0.0 and alpha < 0.005:
		alpha = 0.0
	modulate.a = alpha
	visible = alpha > 0.0
