extends Control
signal onboarding_completed(profile: Dictionary)
const Onboarding = preload("res://scripts/onboarding.gd")
var progress = Onboarding.new()
var script_sheet = DialogScriptManager
var content: VBoxContainer
var card: PanelContainer
var notice: Label
var right_space: Control
var top_space: Control
var bottom_space: Control
var shade: ColorRect
var scroll: ScrollContainer
var scenario: Control
var transitioning := false
var displayed_screen := -1
var fade: ColorRect
const FADE_SECONDS := 0.25

func _ready() -> void:
	if not script_sheet.load_file():
		push_error("Could not load data/scenarios.xlsx")
	_make_theme()
	var background := TextureRect.new()
	background.texture = preload("res://assets/ui/title_background.jpg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	shade = ColorRect.new()
	shade.color = Color(0.13, 0.19, 0.10, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	top_space = Control.new()
	top_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(top_space)
	var row := HBoxContainer.new()
	center.add_child(row)
	var left_space := Control.new()
	left_space.custom_minimum_size.x = 20
	left_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_space)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	row.add_child(margin)
	right_space = Control.new()
	right_space.custom_minimum_size.x = 20
	row.add_child(right_space)
	bottom_space = Control.new()
	center.add_child(bottom_space)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("fff8ea"), 28))
	margin.add_child(card)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	card.add_child(content)
	scenario = preload("res://scenes/arrival_story.tscn").instantiate()
	scenario.nickname_submitted.connect(_story_nickname)
	scenario.finished.connect(_arrive)
	scenario.cancelled.connect(_reset)
	add_child(scenario)
	fade = ColorRect.new()
	fade.color = Color(0.06, 0.09, 0.07, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.hide()
	add_child(fade)
	resized.connect(_resize)
	_resize()
	_show()

func _resize() -> void:
	if card != null:
		var is_title: bool = progress.stage == Onboarding.Stage.TITLE
		card.custom_minimum_size.x = minf(maxf(size.x - 40, 240), 340 if is_title else 680)
		card.add_theme_stylebox_override("panel", _box(Color("fff8ea"), 16 if is_title else 28))
		content.add_theme_constant_override("separation", 10 if is_title else 14)
		right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_space.size_flags_vertical = Control.SIZE_FILL if is_title else Control.SIZE_EXPAND_FILL
		top_space.custom_minimum_size.y = size.y * 0.46 if is_title else 0
		bottom_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shade.visible = not is_title

func _box(color: Color, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.border_color = Color("684329")
	style.set_border_width_all(2)
	style.shadow_color = Color(0.16, 0.09, 0.04, 0.32)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _make_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 18
	theme.default_font = preload("res://font/Moneygraphy-Pixel.ttf")
	theme.set_color("font_color", "Label", Color("594b3d"))
	theme.set_color("font_color", "LineEdit", Color("463d32"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("837568"))
	theme.set_stylebox("normal", "LineEdit", _box(Color("f0e5d2")))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := Color("527a35")
		if state == "hover": color = Color("648e40")
		if state == "pressed": color = Color("385826")
		if state == "disabled": color = Color("d6c6a1")
		var button_style := _box(color, 13)
		if state == "hover": button_style.border_color = Color("a77b43")
		if state in ["pressed", "disabled"]: button_style.shadow_size = 0
		if state == "disabled": button_style.border_color = Color("a39377")
		theme.set_stylebox(state, "Button", button_style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		theme.set_color(state, "Button", Color("fffbed"))
	theme.set_color("font_disabled_color", "Button", Color("5d6253"))
	var focus := _box(Color(0, 0, 0, 0), 0)
	focus.shadow_size = 0
	focus.border_color = Color("ffd36c")
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(3)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("focus", "LineEdit", focus)

func _label(value: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	content.add_child(label)
	return label

func _button(id: String, value: String, action: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.name = id
	button.text = value
	button.custom_minimum_size.y = 48
	button.disabled = disabled
	button.pressed.connect(func():
		if not transitioning:
			action.call()
	)
	content.add_child(button)
	return button

func _show() -> void:
	if transitioning:
		return
	var target: int = progress.stage
	if target == Onboarding.Stage.INTRO:
		target = Onboarding.Stage.NICKNAME
	if displayed_screen == target:
		_render()
		if scenario.visible:
			scenario.popup()
		return
	transitioning = true
	scenario.input_locked = true
	fade.show()
	if displayed_screen != -1:
		var out_tween := create_tween()
		out_tween.tween_property(fade, "color:a", 1.0, FADE_SECONDS)
		await out_tween.finished
	else:
		fade.color.a = 1.0
	displayed_screen = target
	_render()
	var in_tween := create_tween()
	in_tween.tween_property(fade, "color:a", 0.0, FADE_SECONDS)
	await in_tween.finished
	fade.hide()
	transitioning = false
	scenario.input_locked = false
	if scenario.visible:
		scenario.popup()
	_focus_current()

func _input(event: InputEvent) -> void:
	if transitioning and (event is InputEventKey or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()

func _render() -> void:
	var in_story: bool = progress.stage in [Onboarding.Stage.NICKNAME, Onboarding.Stage.INTRO]
	scroll.visible = not in_story
	scenario.visible = in_story
	if in_story:
		scenario.present(progress)
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_resize()
	if progress.stage != Onboarding.Stage.TITLE:
		_label("Bit & Bloom  ·  작은 마을, 오래 남는 이야기", 16)
		var titles := ["Bit & Bloom", "어떻게 불러줄까?", "리벳의 첫인사", "나의 첫 지갑", "첫 준비를 마쳤어요"]
		_label(titles[progress.stage], 32)
	notice = _label("", 15)
	notice.visible = false
	notice.add_theme_color_override("font_color", Color("8b502d"))
	match progress.stage:
		Onboarding.Stage.TITLE:
			_button("StartGuest", "마을 이야기 시작", _start_guest)
			_label("DEMO · 게스트 진행은 종료 시 초기화", 13)
		Onboarding.Stage.WALLET:
			_label("교육용 가상 지갑 · 실제 계정이나 자산과 무관합니다.", 15)
			_label(script_sheet.lines("wallet.intro").front())
			_label("주소   " + progress.address, 21)
			var key: String = progress.private_key if progress.key_seen and not progress.key_confirmed else progress.private_key.left(4) + " ················ " + progress.private_key.right(4)
			_label("가상 개인키   " + key, 18)
			if not progress.key_confirmed:
				_button("RevealKey", "가상 개인키 보기", func(): progress.reveal_key(); _show())
				_button("ConfirmKey", script_sheet.lines("wallet.key_reply").front(), _confirm_key, not progress.key_seen)
			else:
				_label("개인키 확인 완료 ✓", 16)
				_label(script_sheet.lines("wallet.backup").front())
				_label("이 세 단어는 튜토리얼 전용이며 게스트 진행을 복구하지 않습니다.", 14)
				if progress.backup_seen:
					_label(" · ".join(progress.backup_words), 26)
				else:
					_button("RevealBackup", "가상 백업 구절 보기", func(): progress.reveal_backup(); _show())
				_button("ConfirmBackup", script_sheet.lines("wallet.backup_reply").front(), _confirm_backup, not progress.backup_seen)
		Onboarding.Stage.COMPLETE:
			_label(script_sheet.lines("wallet.complete", {"nickname": progress.nickname}).front(), 23)
			_label("개인키 확인 ✓     백업 구절 확인 ✓")
			_label("가상 지갑 주소   " + progress.address)
			_button("EnterVillage", "마을로 들어가기", _enter_village)
	if progress.stage != Onboarding.Stage.TITLE:
		_button("Reset", "타이틀로 · 임시 진행 초기화", _reset)
	_focus_current.call_deferred()

func _focus_current() -> void:
	if not is_inside_tree():
		return
	if scenario.visible:
		return
	for child in content.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break

func _start_guest() -> void:
	if transitioning:
		return
	if progress.begin_guest():
		_show()

func _story_nickname(value: String) -> void:
	if transitioning:
		return
	if progress.set_nickname(value):
		_show()
	else:
		scenario.show_name_error()

func _arrive() -> void:
	if transitioning:
		return
	if progress.arrive_at_office():
		_show()

func _confirm_key() -> void:
	if progress.confirm_key():
		_show()

func _confirm_backup() -> void:
	if progress.confirm_backup():
		_show()
		onboarding_completed.emit(progress.public_summary())

func _enter_village() -> void:
	if transitioning or progress.stage != Onboarding.Stage.COMPLETE:
		return
	GuestSession.begin(progress.nickname, progress.address)
	transitioning = true
	fade.show()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, FADE_SECONDS)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/village.tscn")

func _reset() -> void:
	if transitioning:
		return
	scenario.stop()
	progress = Onboarding.new()
	_show()
