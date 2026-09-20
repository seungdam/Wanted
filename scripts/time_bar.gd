extends Control
## Cream paper / wood frame HUD. The bar separates daytime from afternoon.
@export var clock_path: NodePath
@onready var clock = get_node(clock_path)
var font: Font = preload("res://font/Moneygraphy-Pixel.ttf")
var panel := StyleBoxFlat.new()
const INK := Color("584532")
const MUTED := Color("887153")
const UNLOCKS := [{"hour": 12.0, "id": "mock_investment", "text": "모의 투자 해금"}, {"hour": 14.0, "id": "securities_trading", "text": "증권 거래 해금"}]
var announced := {}

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
	tooltip_text = "08:00~24:00 · 하루 %.1f분 · 정오부터 시작" % (clock.seconds_per_day / 60.0)
	for unlock in UNLOCKS:
		var action_id := str(unlock.id)
		if clock.hour >= float(unlock.hour) and not announced.has(action_id):
			announced[action_id] = true
			GuestSession.unlock_action(action_id)
			_show_unlock(str(unlock.text))
	queue_redraw()

func _show_unlock(message: String) -> void:
	var card := PanelContainer.new()
	card.position = Vector2(size.x * 0.5 - 140.0, 8.0)
	card.size = Vector2(280, 44)
	card.add_theme_stylebox_override("panel", panel)
	add_child(card)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", INK)
	card.add_child(label)
	card.pivot_offset = card.size * 0.5
	card.position.y += 14.0
	card.scale = Vector2(0.82, 0.82)
	card.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position:y", card.position.y - 14.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.12).set_delay(0.05)
	tween.chain().tween_interval(2.2)
	tween.tween_property(card, "modulate:a", 0.0, 0.16)
	tween.tween_callback(card.queue_free)

func _draw() -> void:
	if clock == null:
		return
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var accent := Color("8297b0") if clock.phase == "NIGHT" else (Color("d4894b") if clock.phase == "AFTERNOON" else Color("d69b3e"))
	var bar := Rect2(94, 62, size.x - 118, 12)
	draw_rect(bar, Color("d7c49d"))
	var day_progress := clampf((clock.hour - 8.0) / 16.0, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * day_progress, bar.size.y)), accent)
	draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.25 - 1, -4), Vector2(2, 20)), Color("9c7650"))
	# Pixel sun / moon badge.
	var center := Vector2(49, 45)
	draw_rect(Rect2(23, 19, 52, 52), Color("e0cfaa"))
	for x in range(-7, 8):
		for y in range(-7, 8):
			var p := Vector2(x, y)
			var filled := p.length() < 6.0
			if clock.phase == "NIGHT":
				filled = filled and p.distance_to(Vector2(3, -2)) > 5.0
			else:
				filled = p.length() < 4.5 or ((x == 0 or y == 0 or absi(x) == absi(y)) and p.length() > 5.5 and p.length() < 8.0)
			if filled:
				draw_rect(Rect2(center + p * 3, Vector2(3, 3)), accent)
	draw_string(font, Vector2(94, 35), "DAY %02d" % clock.day, HORIZONTAL_ALIGNMENT_LEFT, 90, 18, INK)
	draw_string(font, Vector2(178, 35), clock.time_text(), HORIZONTAL_ALIGNMENT_LEFT, 100, 22, INK)
	draw_string(font, Vector2(278, 35), "오후" if clock.phase == "AFTERNOON" else "낮", HORIZONTAL_ALIGNMENT_LEFT, 80, 16, accent)
	draw_string(font, Vector2(bar.position.x, 90), "08시", HORIZONTAL_ALIGNMENT_LEFT, 60, 12, MUTED)
	draw_string(font, Vector2(bar.position.x + bar.size.x * 0.25 - 18, 90), "정오", HORIZONTAL_ALIGNMENT_LEFT, 60, 12, MUTED)
	draw_string(font, Vector2(bar.position.x + bar.size.x * 0.62, 90), "오후", HORIZONTAL_ALIGNMENT_LEFT, 60, 12, MUTED)
	draw_string(font, Vector2(bar.end.x - 28, 90), "24시", HORIZONTAL_ALIGNMENT_LEFT, 60, 12, MUTED)
