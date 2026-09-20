extends Node2D
## World resource point. The node owns presentation; LifeCore owns inventory rules.
@export var source_id := "meadow_0"
@export var label := "채집"
@export var tool := "hand"
@export var radius := 18.0
var life: RefCounted
var player: Node2D

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	match tool:
		"axe":
			draw_rect(Rect2(-3, -18, 6, 18), Color("765137"))
			draw_circle(Vector2(0, -22), 13.0, Color("4e864f"))
			draw_circle(Vector2(-9, -17), 9.0, Color("6da45a"))
			draw_circle(Vector2(9, -17), 9.0, Color("5b9650"))
		"pickaxe":
			draw_colored_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(-12, -16), Vector2(2, -21), Vector2(18, -10), Vector2(12, 2)]), Color("777b84"))
			draw_line(Vector2(-12, -8), Vector2(13, -24), Color("765137"), 4.0)
		_:
			draw_line(Vector2(0, 0), Vector2(0, -18), Color("52894b"), 3.0)
			draw_circle(Vector2(-7, -20), 6.0, Color("e38b9b"))
			draw_circle(Vector2(7, -20), 6.0, Color("f2c96b"))
			draw_circle(Vector2(0, -26), 6.0, Color("e58b72"))
			draw_circle(Vector2.ZERO, 3.0, Color("f7e2a1"))
	draw_string(ThemeDB.fallback_font, Vector2(-28, -24), label, HORIZONTAL_ALIGNMENT_CENTER, 56, 10, Color("fff8df"))

func harvest() -> Dictionary:
	if life == null:
		return {"ok": false, "reason": "채집 시스템이 준비되지 않았어."}
	life.equip(tool)
	var result: Dictionary = life.harvest(source_id)
	if result.ok:
		modulate.a = 0.35
		var timer := get_tree().create_timer(float(life.respawn_seconds))
		timer.timeout.connect(func(): modulate.a = 1.0)
	return result
