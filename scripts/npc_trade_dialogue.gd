class_name NpcTradeDialogue
extends Control

signal closed
signal gift_requested(target_npc)

var sheet = DialogScriptManager
var target
var thanks_mode := false

@onready var bubble: PanelContainer = $Bubble
@onready var text_label: Label = $Bubble/ContentMargin/Content/DialogueContext/Body
@onready var action: Button = $Bubble/ContentMargin/Content/Actions/Action
@onready var portrait: ResidentPortrait = $Portrait

func _ready() -> void:
	sheet.load_file()

func begin(npc) -> void:
	target = npc
	thanks_mode = false
	portrait.resident_id = target.resident_id if target != null else "rivet"
	_show_choice_menu()
	_animate_open()

func begin_thanks(npc, taste: String) -> void:
	target = npc
	thanks_mode = true
	portrait.resident_id = target.resident_id if target != null else "rivet"
	text_label.text = target.gift_reply(taste, 0) if target != null else "고마워."
	action.text = "확인"
	if target != null and sheet.has_dialogue_resource("npc_%s" % target.resident_id):
		_load_gift_context(sheet.dialogue_resource("npc_%s" % target.resident_id), taste)
	_animate_open()

func _show_choice_menu() -> void:
	text_label.text = "%s에게 선물을 건넬까요?" % (target.resident_name if target != null else "주민")
	action.text = "선물 고르기"
	action.visible = true
	_stagger_choices()

func _load_gift_context(resource: DialogueResource, taste: String) -> void:
	var states := [{"resident_id": target.resident_id, "nickname": GuestSession.nickname, "item": GuestSession.item_label(target.request_item), "price": target.request_price}]
	var line: Variant = await Engine.get_singleton("DialogueManager").get_next_dialogue_line(resource, "gift_%s" % taste, states)
	if line != null and is_instance_valid(self):
		text_label.text = str(line.text)

func _stagger_choices() -> void:
	var buttons := [action]
	for index in buttons.size():
		var button: Button = buttons[index]
		button.modulate.a = 0.0
		button.scale = Vector2(0.88, 0.88)
		var tween := create_tween()
		tween.tween_interval(index * 0.07)
		tween.set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, 0.12)
		tween.tween_property(button, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_action() -> void:
	if thanks_mode:
		_finish()
		return
	gift_requested.emit(target)
	queue_free()

func _finish() -> void:
	closed.emit()
	queue_free()

func _animate_open() -> void:
	bubble.pivot_offset = bubble.size * 0.5
	bubble.scale = Vector2(0.92, 0.92)
	bubble.modulate.a = 0.0
	portrait.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "modulate:a", 1.0, 0.16)
	tween.tween_property(portrait, "modulate:a", 1.0, 0.16)
