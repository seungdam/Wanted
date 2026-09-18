extends "res://scripts/player.gd"

@export_range(1, 5) var join_day := 1
var joined := false
@export_group("NPC Debug - live")
@export var ai_enabled := true
@export var override_rest_duration := false
@export_range(0.0, 30.0) var rest_min_seconds := 1.0
@export_range(0.0, 30.0) var rest_max_seconds := 3.0
var navigation: AStarGrid2D
var destinations: Array[Vector2i] = []
var random := RandomNumberGenerator.new()
@onready var behavior: BTPlayer = $BTPlayer

func _ready() -> void:
	super._ready()
	random.randomize()
	set_joined(false)

func _physics_process(delta: float) -> void:
	if ai_enabled and joined:
		if override_rest_duration:
			var rest := behavior.get_bt_instance().get_root_task().get_child(0) as BTRandomWait
			if rest != null:
				rest.min_duration = maxf(rest_min_seconds, 0.0)
				rest.max_duration = maxf(rest_max_seconds, rest.min_duration)
		behavior.update(delta)

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

func set_joined(value: bool) -> void:
	joined = value
	visible = value
	set_physics_process(value)
