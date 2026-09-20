class_name ItemIcon
extends Control

@export var kind := "empty"

func _draw() -> void:
	var c := size * 0.5
	if kind == "wood":
		draw_circle(c + Vector2(-10, 4), 13, Color("9a613d"))
		draw_circle(c + Vector2(10, -4), 13, Color("b87a4c"))
		draw_line(c + Vector2(-15, 9), c + Vector2(17, -8), Color("684329"), 3)
		draw_circle(c + Vector2(-12, 6), 4, Color("f2cd88"))
	elif kind == "stone" or kind == "copper_ore":
		var points := PackedVector2Array([c + Vector2(-20, 9), c + Vector2(-14, -13), c + Vector2(6, -20), c + Vector2(21, -4), c + Vector2(15, 16), c + Vector2(-6, 20)])
		draw_colored_polygon(points, Color("a9b5ad") if kind == "stone" else Color("bd8054"))
		points.append(points[0])
		draw_polyline(points, Color("716450"), 2, true)
		draw_line(c + Vector2(-11, -10), c + Vector2(4, -14), Color("e8d6ab"), 4, true)
	elif kind == "flower":
		for i in range(5):
			draw_circle(c + Vector2.from_angle(i * TAU / 5) * 13, 10, Color("fff5db"))
		draw_circle(c, 8, Color("efbc50"))
	elif kind == "herb_tea":
		draw_arc(c + Vector2(15, 0), 11, -PI / 2, PI / 2, 16, Color("799064"), 5, true)
		draw_style_box(_shape(Color("a4bd87")), Rect2(c - Vector2(19, 14), Vector2(34, 31)))
		draw_line(c + Vector2(-8, -21), c + Vector2(-4, -28), Color("c7c2ac"), 2, true)
	elif kind == "berry_jam" or kind == "wild_honey":
		draw_style_box(_shape(Color("ba6972") if kind == "berry_jam" else Color("e3ad45")), Rect2(c - Vector2(17, 17), Vector2(34, 37)))
		draw_style_box(_shape(Color("8c7250")), Rect2(c - Vector2(19, 23), Vector2(38, 10)))
		draw_circle(c + Vector2(0, 3), 9, Color("fff1ce"))
	elif kind == "old_book":
		draw_style_box(_shape(Color("819c85")), Rect2(c - Vector2(18, 22), Vector2(36, 44)))
		draw_line(c + Vector2(-11, -19), c + Vector2(-11, 18), Color("e6d7ab"), 3, true)
		draw_line(c + Vector2(-4, -7), c + Vector2(12, -7), Color("e6d7ab"), 3, true)
	elif kind == "seashell":
		draw_circle(c, 21, Color("e6bcab"))
		for i in range(5):
			draw_line(c + Vector2(0, 17), c + Vector2.from_angle(-PI + (i + 1) * PI / 6) * 19, Color("b58f79"), 2, true)
	elif kind == "wool":
		for offset in [Vector2(-12, 3), Vector2(0, -8), Vector2(12, 3), Vector2(0, 10)]:
			draw_circle(c + offset, 13, Color("eee3d2"))
		draw_arc(c, 15, 0, PI, 16, Color("c3b39b"), 2, true)
	elif kind == "tool":
		draw_line(c + Vector2(-13, 15), c + Vector2(11, -13), Color("a46b3c"), 8)
		draw_circle(c + Vector2(14, -16), 12, Color("a8bac0"))
		draw_arc(c + Vector2(14, -16), 12, 0.2, PI + 0.8, 10, Color("684329"), 3)
	elif kind == "memory":
		draw_circle(c, 18, Color("efa951"))
		for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
			draw_circle(c + Vector2(cos(angle), sin(angle)) * 16, 10, Color("f4c85c"))
		draw_circle(c, 8, Color("fff0a7"))
	else:
		draw_circle(c, 18, Color("e7dcc8"))
		draw_arc(c, 18, 0, TAU, 12, Color("d1bd9e"), 2)

func _shape(color: Color) -> StyleBoxFlat:
	var shape := StyleBoxFlat.new()
	shape.bg_color = color
	shape.set_corner_radius_all(6)
	return shape
