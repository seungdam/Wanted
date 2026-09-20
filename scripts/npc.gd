extends "res://scripts/player.gd"

@export_range(1, 5) var join_day := 1
var joined := false
@export_enum("rivet", "pin", "nut", "clip", "screw") var resident_id := "pin"
@export_group("NPC Debug - live")
@export var ai_enabled := true
@export var override_rest_duration := false
@export_range(0.0, 30.0) var rest_min_seconds := 2.0
@export_range(0.0, 30.0) var rest_max_seconds := 4.0
var navigation: AStarGrid2D
var destinations: Array[Vector2i] = []
var random := RandomNumberGenerator.new()
@onready var behavior: BTPlayer = $BTPlayer
var interaction_prompt: Label
var request_prompt: Sprite2D
var request_shake: Tween
var resident_name := "리벳"
var preferred_item := "wood"
var base_price := 12
var affection := 0
var mood := "평온"
var request_item := "wood"
var request_price := 12
var mood_seed := 0
var wander_speed := 1.0
var counter_flexibility := 2
var request_day := -1
var request_event := ""
var talked_day := -1
var persona := "fixer"
var personality := "알뜰"
var dialogue_visit := 0
var affection_weights := {"trade": 1, "gift": 3, "quest": 4}
var paid_trade_day := -1
var paid_trade_count := 0
var max_paid_trades_per_day := 2
var disliked_gift_loss := 3
var disliked_gift_price_penalty := 2
var disliked_gift_penalty_days := 1
var trade_penalty_until_day := 0
var mood_bubble_cooldown := 0.0
var mood_bubble_busy := false

const PROFILES := [
	{"id": "pin", "name": "핀", "item": "wood", "likes": ["wood", "copper_ore", "wool"], "disliked": "flower", "request": "wood", "price": 12, "flexibility": 3, "persona": "fixer", "personality": "겁쟁이"},
	{"id": "nut", "name": "너트할머니", "item": "stone", "likes": ["stone", "old_book"], "disliked": "berry_jam", "request": "stone", "price": 10, "flexibility": 1, "persona": "careful", "personality": "알뜰"},
	{"id": "clip", "name": "클립", "item": "flower", "likes": ["flower", "herb_tea", "berry_jam"], "disliked": "stone", "request": "flower", "price": 9, "flexibility": 3, "persona": "gardener", "personality": "호기심"},
	{"id": "screw", "name": "나사", "item": "wood", "likes": ["seashell", "wild_honey"], "disliked": "old_book", "request": "wool", "price": 11, "flexibility": 2, "persona": "merchant", "personality": "호탕"}
]
const PROFILE_SPRITES := {
	"rivet": preload("res://assets/character/size_128x128/raccoon_rivet_walk_128.png"),
	"pin": preload("res://assets/character/size_128x128/cat_pin_walk_128.png"),
	"nut": preload("res://assets/character/size_128x128/squirrel_nut_walk_128.png"),
	"clip": preload("res://assets/character/size_128x128/fox_clip_walk_128.png"),
	"screw": preload("res://assets/character/size_128x128/dog_screw_walk_128.png")
}
const PROFILE_IDLE_SPRITES := {
	"rivet": preload("res://assets/character/size_128x128/raccoon_rivet_idle_128.png"),
	"pin": preload("res://assets/character/size_128x128/cat_pin_idle_128.png"),
	"nut": preload("res://assets/character/size_128x128/squirrel_nut_idle_128.png"),
	"clip": preload("res://assets/character/size_128x128/fox_clip_idle_128.png"),
	"screw": preload("res://assets/character/size_128x128/dog_screw_idle_128.png")
}
var disliked_item := "flower"
var liked_items: Array = ["wood"]
var request_material := "wood"
var request_completed_day := -1
const GARDEN_TRADE_ICON_PATH := "res://Downloaded Assets/Icon&Emoji/Garden cozy icons pack/Assets/Icons/ShoppingCart.png"

func _enter_tree() -> void:
	set_meta("interacting", false)

func _ready() -> void:
	if $AnimationTree.tree_root == null:
		_build_animation_resources()
	super._ready()
	_apply_profile_sprite()
	_apply_profile_animation_textures()
	random.randomize()
	set_joined(false)
	refresh_trade_request(1)

func _build_animation_resources() -> void:
	# Reuse the authored player graph; building blend points at runtime emits a
	# Godot 4.7 deprecation warning because the API has no point-name argument.
	var template := preload("res://scenes/player.tscn").instantiate()
	var template_player := template.get_node("AnimationPlayer") as AnimationPlayer
	var template_tree := template.get_node("AnimationTree") as AnimationTree
	$AnimationPlayer.add_animation_library("", template_player.get_animation_library("").duplicate(true))
	$AnimationTree.tree_root = template_tree.tree_root.duplicate(true)
	$AnimationTree.anim_player = NodePath("../AnimationPlayer")

func _apply_profile_animation_textures() -> void:
	var library = $AnimationPlayer.get_animation_library("") as AnimationLibrary
	for animation_name in library.get_animation_list():
		var animation := library.get_animation(animation_name)
		var track := animation.find_track(NodePath("Sprite2D:texture"), Animation.TYPE_VALUE)
		if track < 0:
			continue
		var texture: Texture2D = PROFILE_IDLE_SPRITES.get(resident_id, PROFILE_SPRITES.get(resident_id, sprite.texture)) if animation_name.begins_with("idle_") else PROFILE_SPRITES.get(resident_id, sprite.texture)
		for key_index in animation.track_get_key_count(track):
			animation.track_set_key_value(track, key_index, texture)

func configure_trade(profile_index: int, seed_value: int, day: int, weights := {}) -> void:
	var profile: Dictionary = PROFILES[profile_index % PROFILES.size()]
	resident_name = profile.name
	resident_id = profile.id
	_apply_profile_sprite()
	preferred_item = profile.item
	disliked_item = profile.disliked
	liked_items = profile.likes
	request_material = profile.request
	base_price = profile.price
	counter_flexibility = profile.flexibility
	persona = profile.persona
	personality = profile.personality
	mood_seed = seed_value
	affection_weights.merge(weights)
	max_paid_trades_per_day = int(weights.get("max_paid_trades", max_paid_trades_per_day))
	disliked_gift_loss = int(weights.get("disliked_gift_loss", disliked_gift_loss))
	disliked_gift_price_penalty = int(weights.get("disliked_gift_price_penalty", disliked_gift_price_penalty))
	disliked_gift_penalty_days = int(weights.get("disliked_gift_penalty_days", disliked_gift_penalty_days))
	wander_speed = speed
	request_day = -1
	refresh_trade_request(day)

func _apply_profile_sprite() -> void:
	if not is_node_ready():
		return
	sprite.texture = PROFILE_SPRITES.get(resident_id, sprite.texture)

func refresh_trade_request(day: int) -> void:
	if request_day == day and request_event == str(GuestSession.market_event.id):
		return
	request_day = day
	request_event = str(GuestSession.market_event.id)
	var mood_rng := RandomNumberGenerator.new()
	mood_rng.seed = mood_seed + day * 7919
	mood = ["기쁨", "평온", "멍함", "슬픔"][mood_rng.randi_range(0, 3)]
	request_item = preferred_item # 1. Usual preference.
	var demand: Dictionary = GuestSession.market_event.get("demand", {})
	var resident_demands = demand.get("residents", {})
	if resident_demands is Dictionary:
		demand = resident_demands.get(resident_id, resident_demands.get(resident_name, demand))
	if demand.has("item"):
		request_item = demand.item # 2. An active event creates an urgent need.
	elif mood == "슬픔":
		request_item = "flower" # Mood can vary a request when no event is active.
	elif mood == "멍함":
		request_item = ["wood", "stone", "flower"][mood_rng.randi_range(0, 2)]
	var event_bonus := int(demand.get(request_item, 0))
	request_price = base_price + event_bonus + affection # 3. Relationship rewards trust last.
	if mood == "기쁨":
		request_price += 1
	elif mood == "슬픔":
		request_price += 2
	if _has_trade_penalty():
		request_price += disliked_gift_price_penalty
	_apply_mood_behavior()

func _apply_mood_behavior() -> void:
	if not is_node_ready():
		return
	var instance := behavior.get_bt_instance()
	if instance == null:
		call_deferred("_apply_mood_behavior")
		return
	var rest := instance.get_root_task().get_child(0) as BTRandomWait
	if rest == null:
		return
	if mood == "기쁨":
		speed = wander_speed * 1.15
		rest.min_duration = 0.8
		rest.max_duration = 1.8
	elif mood == "멍함":
		speed = wander_speed * 0.75
		rest.min_duration = 3.0
		rest.max_duration = 5.0
	elif mood == "슬픔":
		speed = wander_speed * 0.65
		rest.min_duration = 4.0
		rest.max_duration = 6.0
	else:
		speed = wander_speed
		rest.min_duration = 2.0
		rest.max_duration = 4.0

func can_trade_today() -> bool:
	if paid_trade_day != GuestSession.current_day:
		paid_trade_day = GuestSession.current_day
		paid_trade_count = 0
	return paid_trade_count < max_paid_trades_per_day

func complete_trade() -> bool:
	if not can_trade_today():
		return false
	paid_trade_count += 1
	gain_affection("trade")
	return true

func gain_affection(action: String) -> int:
	var before := affection
	affection = clampi(affection + int(affection_weights.get(action, 0)), 0, 20)
	return affection - before

func daily_talk(sheet) -> Dictionary:
	var lines: Array[String] = sheet.lines("npc.%s.intro" % persona, {"nickname": GuestSession.nickname})
	lines.append_array(sheet.lines("npc.mood.%s" % _mood_key()))
	if lines.is_empty():
		return {"ok": false, "reason": "일상 대사 데이터가 없어."}
	var before := affection
	if talked_day != GuestSession.current_day:
		talked_day = GuestSession.current_day
		affection = mini(20, affection + 1)
	var entry := GuestSession.record_transaction("daily_talk", GuestSession.nickname, resident_name, 0, {"resident_id": resident_id, "affection_before": before, "affection_after": affection, "affection_delta": affection - before, "wallet_delta": 0})
	return {"ok": true, "lines": lines, "entry": entry}

func receive_gift(item: String) -> Dictionary:
	var before := affection
	var result: Dictionary = GuestSession.gift_item(item, resident_name, {"taste": gift_taste(item)})
	if not result.ok:
		return result
	var taste := gift_taste(item)
	var affection_change := 0
	if taste == "liked":
		affection_change = gain_affection("gift")
	elif taste == "disliked":
		affection_change = -disliked_gift_loss
		affection = maxi(0, affection + affection_change)
		trade_penalty_until_day = GuestSession.current_day + disliked_gift_penalty_days - 1
		request_price += disliked_gift_price_penalty
	else:
		affection_change = gain_affection("trade")
	affection_change = affection - before
	result.entry.merge({"resident_id": resident_id, "affection_before": before, "affection_after": affection, "affection_delta": affection_change})
	result["taste"] = taste
	result["affection_change"] = affection_change
	result["message"] = gift_reply(taste, affection_change)
	return result

func gift_taste(item: String) -> String:
	if item in liked_items:
		return "liked"
	if item == disliked_item:
		return "disliked"
	return "neutral"

func can_complete_request_today() -> bool:
	return request_completed_day != GuestSession.current_day

func complete_request(item: String) -> Dictionary:
	if not can_complete_request_today():
		return {"ok": false, "reason": "오늘 부탁은 이미 해결됐어."}
	if item != request_material:
		return {"ok": false, "reason": "오늘 부탁에는 %s이(가) 필요해." % GuestSession.item_label(request_material)}
	var result: Dictionary = GuestSession.fulfill_request(item, resident_name)
	if result.ok:
		request_completed_day = GuestSession.current_day
		var before := affection
		result["affection_change"] = gain_affection("quest")
		result.entry.merge({"resident_id": resident_id, "affection_before": before, "affection_after": affection, "affection_delta": affection - before})
		result["message"] = "정말 도움이 됐어! 호감도 +%d" % result.affection_change
	return result

func gift_reply(taste: String, change: int) -> String:
	if taste == "liked":
		return "정말 필요한 선물이야! 호감도 +%d" % change
	if taste == "disliked":
		return "지금은 이 선물이 조금 곤란해… 호감도 %d · 오늘 거래 조건이 까다로워졌어." % change
	return "고마워. 마음을 기억할게. 호감도 +%d" % change

func _has_trade_penalty() -> bool:
	return GuestSession.current_day <= trade_penalty_until_day

func dialogue_lines(sheet, stage: String, tokens: Dictionary = {}) -> Array[String]:
	dialogue_visit += 1
	var stage_lines: Array[String] = []
	match stage:
		"intro":
			stage_lines = [_pick_dialogue(sheet, "npc.%s.intro" % persona, tokens), _pick_dialogue(sheet, "npc.trade_request", tokens)]
		"success":
			stage_lines = [_pick_dialogue(sheet, "npc.%s.success" % persona, tokens)]
		"cancel":
			stage_lines = [_pick_dialogue(sheet, "npc.trade_cancel", tokens)]
	for line in stage_lines:
		if not line.is_empty():
			continue
		return sheet.lines("npc.trade_%s" % stage, tokens)
	return stage_lines

func _pick_dialogue(sheet, code: String, tokens: Dictionary) -> String:
	var options: Array[String] = sheet.lines(code, tokens)
	if options.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = mood_seed + GuestSession.current_day * 7919 + dialogue_visit * 131 + code.hash()
	return options[rng.randi_range(0, options.size() - 1)]

func _mood_key() -> String:
	return {"기쁨": "joy", "평온": "calm", "멍함": "blank", "슬픔": "sad"}.get(mood, "calm")

func counter_offer_ceiling() -> int:
	var mood_bonus: int = 1 if mood == "기쁨" else -1 if mood == "슬픔" else 0
	return request_price + maxi(0, counter_flexibility + mood_bonus + floori(float(affection) / 2.0))

func counter_offer_reply(price: int) -> String:
	if price <= counter_offer_ceiling():
		return "좋아, %d볼트면 괜찮아!" % price
	return "%s인 오늘은 %d볼트까지가 좋아." % [mood, counter_offer_ceiling()]

func request_context() -> String:
	var mood_text: String = {"기쁨": "기분이 좋아 조금 더 여유 있어.", "평온": "천천히 조건을 맞춰 보자.", "멍함": "무엇이 필요한지 다시 살펴보는 중이야.", "슬픔": "오늘은 꼭 필요한 물건이 있어."}.get(mood, "천천히 조건을 맞춰 보자.")
	var event_context := str(GuestSession.market_event.get("context", ""))
	return "%s · %s%s" % [mood, mood_text, "\n" + event_context if not event_context.is_empty() else ""]

func _physics_process(delta: float) -> void:
	if ai_enabled and joined:
		if override_rest_duration:
			var rest := behavior.get_bt_instance().get_root_task().get_child(0) as BTRandomWait
			if rest != null:
				rest.min_duration = maxf(rest_min_seconds, 0.0)
				rest.max_duration = maxf(rest_max_seconds, rest.min_duration)
		behavior.update(delta)
		mood_bubble_cooldown = maxf(0.0, mood_bubble_cooldown - delta)
	_set_animation(not route.is_empty())

func _show_mood_bubble() -> void:
	if not Engine.has_singleton("DialogueManager"):
		return
	var sheet = get_node_or_null("/root/DialogScriptManager")
	var resource = sheet.dialogue_resource("npc_%s" % resident_id) if sheet != null else null
	if resource == null:
		return
	mood_bubble_busy = true
	var states := [{"resident_id": resident_id, "nickname": GuestSession.nickname, "item": GuestSession.item_label(request_item), "price": request_price}]
	var line: Variant = await Engine.get_singleton("DialogueManager").get_next_dialogue_line(resource, "intro_%s" % _mood_key(), states)
	if line == null:
		mood_bubble_busy = false
		return
	# The compiled intro cue is persona -> mood -> request. Consume only mood.
	var mood_line: Variant = await Engine.get_singleton("DialogueManager").get_next_dialogue_line(resource, line.next_id, states)
	if mood_line != null:
		_create_mood_bubble(str(mood_line.text))
	mood_bubble_cooldown = 8.0
	mood_bubble_busy = false

func _create_mood_bubble(text: String) -> void:
	if text.is_empty():
		return
	var tail := Polygon2D.new()
	tail.name = "MoodBubbleTail"
	tail.position = Vector2(0, -76)
	tail.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(0, 10)])
	tail.color = Color("fff8e8")
	tail.z_index = 19
	add_child(tail)
	var bubble := PanelContainer.new()
	bubble.name = "MoodBubble"
	bubble.position = Vector2(-105, -132)
	# NPC scale (0.25) × Camera zoom (4) already produces 1:1 screen pixels.
	# Do not apply another 4x scale here.
	bubble.scale = Vector2.ONE
	bubble.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8e8")
	style.border_color = Color("b8824f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	bubble.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	bubble.add_child(column)
	var speaker := Label.new()
	speaker.text = resident_name
	speaker.add_theme_font_size_override("font_size", 11)
	speaker.add_theme_color_override("font_color", Color("e9c8d4"))
	column.add_child(speaker)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(190, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("493b2b"))
	column.add_child(label)
	add_child(bubble)
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(bubble): bubble.queue_free()
		if is_instance_valid(tail): tail.queue_free()
	)

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

func set_interacting(value: bool) -> void:
	set_meta("interacting", value)
	ai_enabled = not value
	if value:
		route.clear()

func set_interaction_available(value: bool) -> void:
	# Interaction is communicated through the mood/trade bubble; no SPACE badge.
	if interaction_prompt != null:
		interaction_prompt.visible = false

func set_trade_request_visible(value: bool) -> void:
	# Trade availability is communicated by the fixed player-side panel.
	# Do not spawn a floating request/emotion icon above the NPC.
	if request_shake != null:
		request_shake.kill()
		request_shake = null
	if request_prompt != null:
		request_prompt.visible = false

func set_player_nearby(value: bool) -> void:
	if bool(get_meta("interacting", false)):
		return
	ai_enabled = not value
	if value:
		route.clear()
