extends Control
signal nickname_submitted(value: String)
signal finished
signal cancelled

const LINES := [
	"왔구나, %s. 이 집, 네 거야.",
	"좀 낡았지만 고치면 돼.",
	"그리고 저기 돌무더기 보이지? 저게 성벽이 될 자리야.",
	"마을에서 거래가 하나 성사될 때마다 블록이 하나 올라가.",
	"집도 고치고 성벽도 쌓으려면 이 마을 경제를 알아야 해.",
	"내가 하나씩 알려줄게. 따라와."
]
var line_index := 0
var lines: Array[String] = []
var typing: Tween
var dialogue: RichTextLabel
var next_button: Button
var name_input: LineEdit
var name_button: Button
var speaker: Label
var page: Label
var active := false
var input_locked := false
var bubble: PanelContainer
var popup_tween: Tween

func _ready() -> void:
	var background := TextureRect.new()
	background.texture = preload("res://assets/ui/arrival_background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 36)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "Bit & Bloom  /  프롤로그"
	heading.add_theme_color_override("font_color", Color("fff1d2"))
	heading.add_theme_color_override("font_shadow_color", Color("334f42"))
	heading.add_theme_constant_override("shadow_offset_x", 1)
	heading.add_theme_constant_override("shadow_offset_y", 2)
	heading.add_theme_constant_override("shadow_outline_size", 3)
	column.add_child(heading)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	bubble = PanelContainer.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("fff8ea")
	paper.border_color = Color("684329")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(24)
	paper.content_margin_left = 28
	paper.content_margin_right = 28
	paper.content_margin_top = 22
	paper.content_margin_bottom = 22
	bubble.add_theme_stylebox_override("panel", paper)
	column.add_child(bubble)
	var tail := Polygon2D.new()
	tail.color = Color("fff8ea")
	tail.polygon = PackedVector2Array([Vector2(40, -1), Vector2(64, -1), Vector2(40, 17)])
	bubble.add_child(tail)
	bubble.resized.connect(func(): tail.position.y = bubble.size.y)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	bubble.add_child(body)
	speaker = Label.new()
	speaker.text = "리벳"
	speaker.add_theme_color_override("font_color", Color("527a35"))
	speaker.add_theme_font_size_override("font_size", 22)
	body.add_child(speaker)
	dialogue = RichTextLabel.new()
	dialogue.custom_minimum_size.y = 88
	dialogue.fit_content = true
	dialogue.scroll_active = false
	dialogue.add_theme_font_size_override("normal_font_size", 24)
	dialogue.add_theme_color_override("default_color", Color("594b3d"))
	body.add_child(dialogue)
	name_input = LineEdit.new()
	name_input.name = "Nickname"
	name_input.placeholder_text = "마을에서 사용할 이름 · 2~12자"
	name_input.max_length = 12
	name_input.text_submitted.connect(func(_value: String): _submit_name())
	body.add_child(name_input)
	name_button = Button.new()
	name_button.name = "SaveNickname"
	name_button.text = "이 이름으로 시작"
	name_button.pressed.connect(_submit_name)
	body.add_child(name_button)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	page = Label.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(page)
	next_button = Button.new()
	next_button.name = "FollowRivet"
	next_button.custom_minimum_size = Vector2(180, 48)
	next_button.pressed.connect(advance)
	footer.add_child(next_button)
	var back := Button.new()
	back.text = "타이틀로 돌아가기"
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(func():
		if not input_locked:
			stop()
			cancelled.emit()
	)
	column.add_child(back)

func present(progress) -> void:
	stop()
	active = true
	var naming: bool = progress.nickname.is_empty()
	name_input.visible = naming
	name_button.visible = naming
	next_button.visible = not naming
	if naming:
		name_input.text = ""
		dialogue.text = "마을에 온 걸 환영해! 너를 어떻게 부르면 좋을까?"
		dialogue.visible_characters = -1
		page.text = "새로운 이웃"
		name_input.grab_focus()
	else:
		lines.assign(LINES)
		lines[0] = lines[0] % progress.nickname
		line_index = 0
		_show_line()
		next_button.grab_focus()
	popup()

func popup() -> void:
	if popup_tween:
		popup_tween.kill()
	bubble.pivot_offset = Vector2(48, bubble.size.y)
	bubble.scale = Vector2(0.96, 0.96)
	bubble.modulate.a = 0.0
	popup_tween = create_tween().set_parallel(true)
	popup_tween.tween_property(bubble, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(bubble, "modulate:a", 1.0, 0.18)

func _submit_name() -> void:
	if input_locked:
		return
	nickname_submitted.emit(name_input.text)

func show_name_error() -> void:
	dialogue.text = "이름은 공백을 제외하고 2~12자로 입력해 줘."
	dialogue.visible_characters = -1

func _show_line() -> void:
	dialogue.text = lines[line_index]
	dialogue.visible_characters = 0
	page.text = "%d / %d  ·  눌러서 문장 완성" % [line_index + 1, lines.size()]
	next_button.text = "문장 펼치기"
	typing = create_tween()
	typing.tween_property(dialogue, "visible_characters", dialogue.get_total_character_count(), dialogue.get_total_character_count() / 30.0)
	typing.finished.connect(_line_ready)

func _line_ready() -> void:
	page.text = "%d / %d" % [line_index + 1, lines.size()]
	next_button.text = "튜토리얼 입장" if line_index == lines.size() - 1 else "다음 이야기"

func advance() -> void:
	if input_locked or not active or name_input.visible:
		return
	if typing and typing.is_running():
		typing.kill()
		dialogue.visible_characters = -1
		_line_ready()
	elif line_index < lines.size() - 1:
		line_index += 1
		_show_line()
	else:
		stop()
		finished.emit()

func stop() -> void:
	active = false
	if popup_tween:
		popup_tween.kill()
	if bubble:
		bubble.scale = Vector2.ONE
		bubble.modulate.a = 1.0
	if typing:
		typing.kill()
