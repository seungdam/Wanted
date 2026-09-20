class_name VillagePortraitNpc
extends Sprite2D

@export var resident_id := "pin"
@export var resident_name := "핀"
@export_range(1, 13) var join_day := 1
@export var liked_item := "wood"
@export var mood_line := "오늘은 천천히 걷고 싶어."
@export var request_item := "wood"
@export var request_price := 12
@export var base_price := 12
var mood := "평온"
var affection := 0
var paid_trade_day := -1
var paid_trade_count := 0

func receive_gift(item: String) -> Dictionary:
	var result: Dictionary = GuestSession.gift_item(item, resident_name, {"resident_id": resident_id})
	if not result.ok:
		return result
	var taste := "liked" if item == liked_item else "neutral"
	var change := 3 if taste == "liked" else 1
	affection = mini(20, affection + change)
	result["taste"] = taste
	result["affection_change"] = change
	result["message"] = gift_reply(taste, change)
	return result

func gift_reply(taste: String, change: int) -> String:
	if taste == "liked":
		return "정말 필요한 선물이야! 호감도 +%d" % change
	return "고마워. 마음을 기억할게. 호감도 +%d" % change

func can_trade_today() -> bool:
	if paid_trade_day != GuestSession.current_day:
		paid_trade_day = GuestSession.current_day
		paid_trade_count = 0
	return paid_trade_count < 2

func complete_trade() -> bool:
	if not can_trade_today():
		return false
	paid_trade_count += 1
	affection = mini(20, affection + 1)
	return true

func request_context() -> String:
	return "%s · %s" % [mood, mood_line]

func counter_offer_ceiling() -> int:
	return request_price + 2 + floori(float(affection) / 2.0)

func counter_offer_reply(price: int) -> String:
	return "좋아, %d볼트면 괜찮아!" % price if price <= counter_offer_ceiling() else "오늘은 %d볼트까지가 좋아." % counter_offer_ceiling()

func show_mood_bubble() -> void:
	if get_node_or_null("MoodBubble") != null:
		return
	var bubble := Label.new()
	bubble.name = "MoodBubble"
	bubble.text = mood_line
	bubble.position = Vector2(-220, -180)
	bubble.size = Vector2(440, 64)
	bubble.scale = Vector2(4, 4)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_font_size_override("font_size", 12)
	bubble.add_theme_color_override("font_color", Color("493b2b"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8e8")
	style.border_color = Color("b8824f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	bubble.add_theme_stylebox_override("normal", style)
	add_child(bubble)
	get_tree().create_timer(2.8).timeout.connect(bubble.queue_free)
