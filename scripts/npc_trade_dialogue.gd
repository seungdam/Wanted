class_name NpcTradeDialogue
extends Control

signal closed
signal trade_requested(target_npc)
signal gift_requested(target_npc)
signal talk_requested(target_npc)
var sheet = DialogScriptManager
@onready var bubble: PanelContainer = $Bubble
@onready var speaker: Label = $Bubble/ContentMargin/Content/SpeakerContext/Speaker
@onready var text_label: Label = $Bubble/ContentMargin/Content/DialogueContext/Body
@onready var action: Button = $Bubble/ContentMargin/Content/Actions/Action
@onready var alternate: Button = $Bubble/ContentMargin/Content/Actions/Alternate
@onready var talk: Button = $Bubble/ContentMargin/Content/Actions/Talk
@onready var portrait: ResidentPortrait = $Portrait
var trade_area: VBoxContainer
var offer_item: TradeItemCard
var drop_slot: TradeDropSlot
var lines: Array[String] = []
var line_index := 0
var target
var mode := "intro"

func _ready() -> void:
	sheet.load_file()

func begin(npc) -> void:
	target = npc
	portrait.resident_id = target.resident_id if target != null else "rivet"
	var speaker_lines: Array[String] = sheet.lines("npc.%s.speaker" % target.resident_id) if target != null else []
	speaker.text = speaker_lines.front() if not speaker_lines.is_empty() else (target.resident_name if target != null else sheet.lines("npc.trade_speaker").front())
	var resource_id := "npc_%s" % target.resident_id if target != null else ""
	if target != null and sheet.has_dialogue_resource(resource_id):
		_load_compiled_dialogue(resource_id)
	else:
		lines = target.dialogue_lines(sheet, "intro", _tokens()) if target != null else sheet.lines("npc.trade_intro", {"nickname": GuestSession.nickname})
		line_index = 0
		_show_line()
	_animate_open()

func _load_compiled_dialogue(resource_id: String) -> void:
	var resource = sheet.dialogue_resource(resource_id)
	var states := [{"resident_id": target.resident_id, "nickname": GuestSession.nickname, "item": GuestSession.item_label(target.request_item), "price": target.request_price}]
	var cue := "intro_%s" % target._mood_key()
	var compiled: Array[String] = []
	var dialogue_manager = Engine.get_singleton("DialogueManager")
	var line = await dialogue_manager.get_next_dialogue_line(resource, cue, states)
	var cue_index := 0
	while line != null:
		# Generated intro cues are persona -> mood -> request. Mood is shown
		# only by the BT bubble, never in the SPACE trade interaction.
		if cue_index != 1 and not line.text.is_empty():
			compiled.append(line.text)
		cue_index += 1
		line = await dialogue_manager.get_next_dialogue_line(resource, line.next_id, states)
	if compiled.is_empty():
		compiled = target.dialogue_lines(sheet, "intro", _tokens())
	lines = compiled
	line_index = 0
	_show_line()

func _animate_open() -> void:
	bubble.pivot_offset = bubble.size * 0.5
	bubble.scale = Vector2(0.92, 0.92)
	bubble.modulate.a = 0.0
	portrait.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "modulate:a", 1.0, 0.16)
	tween.tween_property(portrait, "modulate:a", 1.0, 0.16)

func _show_line() -> void:
	_clear_trade_area()
	_prepare_choice_buttons()
	mode = "intro"
	action.disabled = false
	text_label.text = lines[line_index]
	action.text = "다음" if line_index < lines.size() - 1 else ("거래 보기" if target == null or target.can_trade_today() else "대화 마치기")
	alternate.visible = line_index == lines.size() - 1
	alternate.text = "선물 건네기"

	_prepare_choice_buttons()

func _prepare_choice_buttons() -> void:
	var is_choice := line_index == lines.size() - 1
	talk.visible = is_choice
	talk.text = "%s와 대화하기" % (target.resident_name if target != null else "주민")
	if is_choice and target != null:
		action.text = "%s와 거래하기" % target.resident_name
		alternate.text = "%s에게 선물하기" % target.resident_name

func _on_action() -> void:
	if mode == "intro":
		_advance()
	elif mode == "offer":
		_trade()
	elif mode == "success":
		if line_index < lines.size() - 1:
			line_index += 1
			_show_success()
		else:
			_finish()
	else:
		_finish()

func _advance() -> void:
	if line_index < lines.size() - 1:
		line_index += 1
		_show_line()
		return
	if target == null or target.can_trade_today():
		trade_requested.emit(target)
	else:
		_finish()
	queue_free()

func _style_trade_card(card: PanelContainer, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("b88955")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	card.add_theme_stylebox_override("panel", style)

func _on_item_dropped() -> void:
	offer_item.hide()
	var moving := Label.new()
	moving.text = "나무"
	moving.add_theme_font_size_override("font_size", 22)
	moving.add_theme_font_override("font", preload("res://font/Moneygraphy-Pixel.ttf"))
	moving.position = offer_item.get_global_rect().get_center() - Vector2(25, 14)
	add_child(moving)
	var tween := create_tween()
	tween.tween_property(moving, "position", drop_slot.get_global_rect().get_center() - Vector2(25, 14), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(moving, "scale", Vector2(1.25, 1.25), 0.2)
	tween.tween_callback(moving.queue_free)
	tween.tween_callback(func():
		action.disabled = false
		action.text = "12볼트 받고 거래"
	)

func _clear_trade_area() -> void:
	if trade_area != null:
		trade_area.queue_free()
		trade_area = null
		offer_item = null
		drop_slot = null

func _trade() -> void:
	if drop_slot == null or not drop_slot.delivered:
		return
	var result := GuestSession.sell_wood(12, speaker.text)
	if not result.ok:
		text_label.text = result.reason
		mode = "close"
		action.text = "닫기"
		return
	lines = target.dialogue_lines(sheet, "success", _tokens()) if target != null else sheet.lines("npc.trade_success")
	line_index = 0
	_show_success()

func _show_success() -> void:
	_clear_trade_area()
	mode = "success"
	text_label.text = lines[line_index] + "\n\n잔액 %s · 추억 노드 %d개" % [GuestSession.format_nut(GuestSession.nut), GuestSession.blocks]
	action.text = "마을로 돌아가기" if line_index == lines.size() - 1 else "다음"
	alternate.visible = false

func _cancel() -> void:
	if alternate.visible:
		gift_requested.emit(target)
		queue_free()

func _finish() -> void:
	closed.emit()
	queue_free()

func _talk() -> void:
	talk_requested.emit(target)
	queue_free()

func _tokens() -> Dictionary:
	return {"nickname": GuestSession.nickname, "item": GuestSession.item_label(target.request_item) if target != null else "나무", "price": target.request_price if target != null else 12}
