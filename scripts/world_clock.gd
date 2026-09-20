extends Node
## Session time is monotonic real time, independent of FPS and Engine.time_scale.
const DAY_START_HOUR := 8.0
const DAY_END_HOUR := 24.0
@export_range(1.0, 3600.0) var seconds_per_day: float = 240.0
@export_range(0.0, 100.0) var years_per_day: float = 5.0
@export_group("Clock Debug - live")
@export var clock_paused := false
@export_range(0.0, 100.0) var time_multiplier: float = 1.0
@export var preview_enabled := false
@export_range(1, 9999) var preview_day := 1
@export_range(0.0, 23.99, 0.01) var preview_hour: float = 12.0
var timeline_seconds := 0.0
var started_usec: int
var elapsed_seconds := 0.0
var day := 1
var hour := 0.0
var years := 0.0
var phase := "NIGHT"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	timeline_seconds = 0.0 # 08:00~24:00 day: begin at 08:00.
	started_usec = Time.get_ticks_usec()
	apply_elapsed(timeline_seconds)

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
	hour = DAY_START_HOUR + fposmod(days, 1.0) * (DAY_END_HOUR - DAY_START_HOUR)
	years = days * maxf(years_per_day, 0.0)
	phase = "DAYTIME" if hour >= 6.0 and hour < 12.0 else ("AFTERNOON" if hour >= 12.0 and hour < 18.0 else "NIGHT")
	GuestSession.set_game_clock(day, floori(hour * 60.0))
func time_text() -> String:
	var minutes := floori(hour * 60.0)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minutes / 60, minutes % 60]
