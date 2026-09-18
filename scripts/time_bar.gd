extends Control
## Cream paper / wood frame HUD. World lighting never changes its readability.
@export var clock_path: NodePath
@onready var clock = get_node(clock_path)
var font: Font = preload("res://font/Moneygraphy-Pixel.ttf")
var panel := StyleBoxFlat.new()
const INK := Color("584532")
const MUTED := Color("887153")

func _ready() -> void:
	panel.bg_color = Color("f2e4c5")
	panel.border_color = Color("94704c")
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(3)
	panel.shadow_color = Color(0.16, 0.12, 0.07, 0.35)
	panel.shadow_size = 3
	panel.shadow_offset = Vector2(0, 4)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	tooltip_text = "A five-day visit. One day: %.1f minutes. Neighbors join on Days 1–4." % (clock.seconds_per_day / 60.0)
	queue_redraw()

func _draw() -> void:
	if clock == null:
		return
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(size.x / 2 - 16, 7, 32, 3), Color("b8a17c"))
	var accent := Color("8297b0") if clock.phase == "NIGHT" else Color("d69b3e")
	draw_rect(Rect2(26, 83, size.x - 52, 4), Color("d7c49d"))
	draw_rect(Rect2(26, 83, (size.x - 52) * clock.hour / 24.0, 4), accent)
	# Pixel sun / moon badge.
	var center := Vector2(49, 45)
	draw_rect(Rect2(23, 19, 52, 52), Color("e0cfaa"))
	for x in range(-7, 8):
		for y in range(-7, 8):
			var p := Vector2(x, y)
			var filled := p.length() < 6.0
			if clock.phase == "NIGHT":
				filled = filled and p.distance_to(Vector2(3, -2)) > 5.0
			elif clock.phase == "DAYTIME":
				filled = p.length() < 4.5 or ((x == 0 or y == 0 or absi(x) == absi(y)) and p.length() > 5.5 and p.length() < 8.0)
			if filled:
				draw_rect(Rect2(center + p * 3, Vector2(3, 3)), accent)
	draw_string(font, Vector2(94, 37), "DAY %02d / 05" % clock.day, HORIZONTAL_ALIGNMENT_LEFT, 150, 20, INK)
	draw_string(font, Vector2(94, 60), "A LITTLE VILLAGE", HORIZONTAL_ALIGNMENT_LEFT, 150, 11, MUTED)
	draw_rect(Rect2(249, 25, 2, 40), Color("d4bd96"))
	draw_string(font, Vector2(271, 43), clock.time_text(), HORIZONTAL_ALIGNMENT_LEFT, 130, 27, INK)
	draw_string(font, Vector2(273, 62), clock.phase, HORIZONTAL_ALIGNMENT_LEFT, 130, 11, MUTED)
	draw_rect(Rect2(409, 25, 2, 40), Color("d4bd96"))
	var village = get_parent().get_parent()
	var count := 0
	for npc in village.residents:
		if npc.joined:
			count += 1
	draw_string(font, Vector2(435, 37), "NEIGHBORS %d / 4" % count, HORIZONTAL_ALIGNMENT_LEFT, 170, 17, INK)
	draw_string(font, Vector2(435, 60), "MAKE YOURSELF AT HOME", HORIZONTAL_ALIGNMENT_LEFT, 170, 10, MUTED)
