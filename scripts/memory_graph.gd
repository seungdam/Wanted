class_name MemoryGraph
extends Control

signal memory_selected(entry: Dictionary)
var entries: Array[Dictionary] = []
var slot_points: Array[Vector2] = []

func _draw() -> void:
	var center := size * 0.5
	var stem := center + Vector2(0, 92)
	var path := PackedVector2Array([stem, center + Vector2(-16, 40), center])
	var petal_count := maxi(entries.size(), 6)
	slot_points.clear()
	for index in range(petal_count):
		var angle := -PI * 0.5 + TAU * float(index) / float(maxi(petal_count, 6))
		var point := center + Vector2(cos(angle), sin(angle)) * 66.0
		path.append(point)
		slot_points.append(point)
	draw_polyline(path, Color("684329"), 5.0, true)
	draw_polyline(path, Color("d6a84d"), 2.0, true)
	for index in range(petal_count):
		var angle := -PI * 0.5 + TAU * float(index) / float(maxi(petal_count, 6))
		_draw_block_petal(center + Vector2(cos(angle), sin(angle)) * 66.0, angle, index < entries.size())
	_draw_block_petal(center, 0.0, true)
	draw_line(stem, stem + Vector2(-20, 28), Color("527a35"), 8.0, true)
	draw_line(stem, stem + Vector2(20, 28), Color("527a35"), 8.0, true)
	draw_string(get_theme_default_font(), stem + Vector2(-78, 52), "거래의 추억이 피어나는 중", HORIZONTAL_ALIGNMENT_CENTER, 156, 15, Color("594b3d"))

func _draw_block_petal(point: Vector2, angle: float, filled: bool) -> void:
	draw_set_transform(point, angle, Vector2.ONE)
	draw_rect(Rect2(-18, -12, 36, 24), Color("e7a74d") if filled else Color("f0e5d2"), true)
	draw_rect(Rect2(-18, -12, 36, 24), Color("684329"), false, 3.0)
	draw_line(Vector2(-10, -5), Vector2(10, -5), Color("fff0a7") if filled else Color("c6b392"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for index in range(mini(entries.size(), slot_points.size())):
			if Rect2(slot_points[index] - Vector2(24, 18), Vector2(48, 36)).has_point(event.position):
				memory_selected.emit(entries[index])
				accept_event()
				return
