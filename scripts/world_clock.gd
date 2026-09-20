extends Node
## Session time is monotonic real time, independent of FPS and Engine.time_scale.
@export_range(1.0, 3600.0) var seconds_per_day: float = 240.0
@export_range(0.0, 100.0) var years_per_day: float = 5.0
@export_group("Clock Debug - live")
@export var clock_paused := false
@export_range(0.0, 100.0) var time_multiplier: float = 1.0
@export var preview_enabled := false
@export_range(1, 9999) var preview_day := 1
@export_range(0.0, 23.99, 0.01) var preview_hour: float = 12.0
var timeline_seconds := 0.0
# Lighting space: XY follows the screen, Z points above the 2D lighting plane.
# Grid +X is east (screen down-right); west is the opposite direction.
const EAST := Vector3(0.894427191, 0.4472135955, 0.0) # normalized (2, 1, 0)
const ZENITH := Vector3(0.0, 0.0, 1.0)
var sun_direction := ZENITH
var started_usec: int
var elapsed_seconds := 0.0
var day := 1
var hour := 0.0
var years := 0.0
var phase := "NIGHT"
@onready var ambient: CanvasModulate = $Ambient
@onready var sunlight: DirectionalLight2D = $Sunlight

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	started_usec = Time.get_ticks_usec()
	apply_elapsed(0.0)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := maxf((now - started_usec) / 1000000.0, 0.0)
	started_usec = now
	if not clock_paused and not preview_enabled:
		timeline_seconds += real_delta * maxf(time_multiplier, 0.0)
	var shown := ((maxi(preview_day, 1) - 1) + clampf(preview_hour, 0.0, 23.99) / 24.0) * maxf(seconds_per_day, 1.0) if preview_enabled else timeline_seconds
	apply_elapsed(shown)

func apply_elapsed(seconds: float) -> void:
	elapsed_seconds = maxf(seconds, 0.0)
	var days := elapsed_seconds / maxf(seconds_per_day, 1.0)
	day = floori(days) + 1
	hour = fposmod(days, 1.0) * 24.0
	years = days * maxf(years_per_day, 0.0)
	phase = "MORNING" if hour >= 6.0 and hour < 10.0 else ("DAYTIME" if hour >= 10.0 and hour < 18.0 else "NIGHT")
	# Ambient twilight stays smooth; direct sunlight exists only above the horizon.
	var daylight := smoothstep(5.0, 8.0, hour) * (1.0 - smoothstep(17.0, 20.0, hour))
	sun_direction = solar_direction(hour)
	var elevation := maxf(sun_direction.z, 0.0)
	ambient.color = Color("566888").lerp(Color("c9c5b5"), daylight)
	sunlight.color = Color("ffce8d").lerp(Color("fff3da"), elevation)
	# Keep ambient + direct light below white so the asset palette does not clip.
	sunlight.energy = 0.18 * smoothstep(0.0, 0.25, elevation)
	var horizontal := Vector2(sun_direction.x, sun_direction.y)
	# Godot normalizes mix(horizontal_unit, Z, height); invert that blend
	# to preserve the actual SLERP vector, rather than treating height as an angle.
	sunlight.height = elevation / maxf(horizontal.length() + elevation, 0.000001)
	if horizontal.length_squared() > 0.000001:
		# Light emits along local +Y, opposite the direction toward the sun.
		sunlight.rotation = horizontal.angle() + PI / 2.0

func solar_direction(time_of_day: float) -> Vector3:
	# Four quarter arcs avoid ambiguous SLERP between antipodal east/west vectors.
	# 06 east -> 12 zenith -> 18 west -> 00 nadir -> 06 east.
	var arc := fposmod(time_of_day - 6.0, 24.0) / 6.0
	var points := [EAST, ZENITH, -EAST, -ZENITH, EAST]
	var segment := floori(arc)
	return points[segment].slerp(points[segment + 1], arc - segment)

func time_text() -> String:
	var minutes := floori(hour * 60.0)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minutes / 60, minutes % 60]
