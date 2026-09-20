class_name CozyDialogueBalloon
extends CanvasLayer

signal closed

@export var dialogue_resource: DialogueResource
@export var start_from_cue := ""
@export var auto_start := false
@export var will_block_other_input := true
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"

var temporary_game_states: Array = []
var is_waiting_for_input := false
var dialogue_line: DialogueLine:
	set(value):
		dialogue_line = value
		if value:
			_apply_line()
		else:
			closed.emit()
			queue_free()

@onready var balloon: Control = $Balloon
@onready var character_label: Label = $Balloon/Panel/Margin/Row/Column/CharacterTag/CharacterLabel
@onready var dialogue_label: DialogueLabel = $Balloon/Panel/Margin/Row/Column/DialogueLabel
@onready var progress: Control = $Balloon/Panel/Margin/Row/Column/Progress
@onready var portrait: ResidentPortrait = $Balloon/Panel/Margin/Row/Portrait

func _ready() -> void:
	balloon.hide()
	if auto_start:
		start()

func _unhandled_input(_event: InputEvent) -> void:
	if will_block_other_input:
		get_viewport().set_input_as_handled()

func start(with_dialogue_resource: DialogueResource = null, cue := "", extra_game_states: Array = []) -> void:
	temporary_game_states = extra_game_states
	# Dialogue Manager validates every token in a cue before returning its first
	# line. Keep shared tutorial/NPC tokens available even when the caller only
	# supplied a resident id for portrait selection.
	temporary_game_states.append({"nickname": GuestSession.nickname, "item": "", "price": 0})
	for state in extra_game_states:
		if state is Dictionary and state.has("resident_id"):
			portrait.resident_id = str(state.resident_id)
	if with_dialogue_resource != null:
		dialogue_resource = with_dialogue_resource
	if not cue.is_empty():
		start_from_cue = cue
	dialogue_line = await Engine.get_singleton("DialogueManager").get_next_dialogue_line(dialogue_resource, start_from_cue, temporary_game_states)
	balloon.show()
	_pop_in()

func _apply_line() -> void:
	is_waiting_for_input = false
	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = dialogue_line.character
	dialogue_label.dialogue_line = dialogue_line
	dialogue_label.show()
	progress.hide()
	dialogue_label.type_out()
	await dialogue_label.finished_typing
	if not is_instance_valid(dialogue_line):
		return
	is_waiting_for_input = true
	progress.show()

func _next() -> void:
	progress.hide()
	dialogue_line = await Engine.get_singleton("DialogueManager").get_next_dialogue_line(dialogue_resource, dialogue_line.next_id, temporary_game_states)

func _on_balloon_gui_input(event: InputEvent) -> void:
	if dialogue_label.is_typing:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(skip_action):
			dialogue_label.skip_typing()
		return
	if not is_waiting_for_input:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(next_action):
		_next()

func _pop_in() -> void:
	balloon.pivot_offset = balloon.size * 0.5
	balloon.scale = Vector2(0.94, 0.94)
	balloon.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(balloon, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(balloon, "modulate:a", 1.0, 0.14)
