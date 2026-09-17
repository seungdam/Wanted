extends Control
## Drawn with native UI primitives; CanvasLayer keeps the HUD out of world lighting.
@export var clock_path: NodePath
@onready var clock = get_node(clock_path)
var font: Font = preload("res://font/Moneygraphy-Pixel.ttf")
var panel := StyleBoxFlat.new()

func _ready() -> void:
	panel.bg_color = Color("17222f")
	panel.border_color = Color("465368")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(22)
	panel.shadow_color = Color(0, 0, 0, 0.3)
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0, 5)
	tooltip_text = "1 day = 4 real minutes = 5 world years. Day rolls over at midnight."
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	tooltip_text = "1 day = %.1f real minutes = %.1f world years. Debug speed: %.1fx" % [clock.seconds_per_day / 60.0, clock.years_per_day, clock.time_multiplier]
	queue_redraw()

func _draw() -> void:
	if clock == null:
		return
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var accent := Color("a8caff") if clock.phase == "NIGHT" else Color("f5ce72")
	# Small handle grip and a slim full-day progress rail.
	draw_line(Vector2(size.x / 2 - 16, 8), Vector2(size.x / 2 + 16, 8), Color("566173"), 3.0, true)
	draw_line(Vector2(28, 85), Vector2(size.x - 28, 85), Color("334152"), 3.0, true)
	var progress_x: float = lerpf(28, size.x - 28, clock.hour / 24.0)
	draw_line(Vector2(28, 85), Vector2(progress_x, 85), accent, 3.0, true)
	draw_circle(Vector2(progress_x, 85), 4, accent, true, -1, true)
	var center := Vector2(49, 45)
	draw_circle(center, 27, Color("263647"), true, -1, true)
	if clock.phase == "NIGHT":
		draw_circle(center, 14, accent, true, -1, true)
		draw_circle(center + Vector2(7, -5), 12, Color("263647"), true, -1, true)
		draw_circle(center + Vector2(16, -13), 2, accent, true, -1, true)
	else:
		draw_circle(center, 12, accent, true, -1, true)
		if clock.phase == "DAYTIME":
			for index in range(8):
				var ray := Vector2.from_angle(index * TAU / 8.0)
				draw_line(center + ray * 17, center + ray * 21, accent, 2, true)
		else:
			draw_circle(center + Vector2(-3, -4), 4, Color("ffe7a3"), true, -1, true)
	draw_string(font, Vector2(90, 36), "DAY %03d" % clock.day, HORIZONTAL_ALIGNMENT_LEFT, 135, 21, Color("edf2f5"))
	draw_string(font, Vector2(90, 59), "ELAPSED %d DAYS" % (clock.day - 1), HORIZONTAL_ALIGNMENT_LEFT, 145, 11, Color("92a2b6"))
	draw_line(Vector2(235, 27), Vector2(235, 64), Color("3c4a5a"), 1)
	draw_string(font, Vector2(258, 43), clock.time_text(), HORIZONTAL_ALIGNMENT_LEFT, 130, 29, accent)
	draw_string(font, Vector2(260, 63), clock.phase, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color("a2b1c3"))
	draw_line(Vector2(390, 27), Vector2(390, 64), Color("3c4a5a"), 1)
	draw_string(font, Vector2(412, 36), "+ %.2f YEARS" % clock.years, HORIZONTAL_ALIGNMENT_LEFT, 180, 19, Color("edf2f5"))
	draw_string(font, Vector2(412, 59), "%.1f YEARS / DAY | %.1f MIN" % [clock.years_per_day, clock.seconds_per_day / 60.0], HORIZONTAL_ALIGNMENT_LEFT, 185, 10, Color("92a2b6"))
