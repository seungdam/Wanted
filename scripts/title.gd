extends Control
signal onboarding_completed(profile: Dictionary)
const Onboarding = preload("res://scripts/auth/onboarding.gd")
const GoogleLogin = preload("res://scripts/auth/google_login.gd")
var progress = Onboarding.new()
var auth = GoogleLogin.new()
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
	add_child(auth)
	auth.authenticated.connect(_google_authenticated)
	auth.failed.connect(_auth_failed)
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
			_button("GoogleLogin", "Google로 로그인", _start_google, auth.busy or not auth.configuration_error().is_empty())
			_button("TestLogin", "마을 이야기 시작 · 체험하기", _start_test, auth.busy)
			if auth.busy:
				_label("브라우저에서 로그인을 마치면 이 화면으로 돌아옵니다.")
				_button("CancelLogin", "로그인 취소", _cancel_login)
			else:
				if not auth.configuration_error().is_empty():
					_label("Google 연결 준비 중 · 테스트 입장 가능", 13)
			_label("DEMO · 종료 시 진행 초기화", 13)
		Onboarding.Stage.WALLET:
			_label("교육용 가상 지갑 · 실제 계정이나 자산과 무관합니다.", 15)
			_label("리벳: 먼저 네 지갑. 위의 주소는 남에게 알려줘도 돼. 아래 개인키는 나한테도 알려주면 안 돼.")
			_label("주소   " + progress.address, 21)
			var key: String = progress.private_key if progress.key_seen and not progress.key_confirmed else progress.private_key.left(4) + " ················ " + progress.private_key.right(4)
			_label("가상 개인키   " + key, 18)
			if not progress.key_confirmed:
				_button("RevealKey", "가상 개인키 보기", func(): progress.reveal_key(); _show())
				_button("ConfirmKey", "개인키 확인했어", _confirm_key, not progress.key_seen)
			else:
				_label("개인키 확인 완료 ✓", 16)
				_label("리벳: 가상 백업 구절 세 단어야. 잃어버린 지갑을 되찾는 연습에 쓸 거야. 이것도 비밀이야.")
				_label("이 세 단어는 튜토리얼 전용이며 Google 계정을 복구하지 않습니다.", 14)
				if progress.backup_seen:
					_label(" · ".join(progress.backup_words), 26)
				else:
					_button("RevealBackup", "가상 백업 구절 보기", func(): progress.reveal_backup(); _show())
				_button("ConfirmBackup", "외웠어", _confirm_backup, not progress.backup_seen)
		Onboarding.Stage.COMPLETE:
			_label("%s, 이제 첫 거래를 배울 준비가 됐어." % progress.nickname, 23)
			_label("개인키 확인 ✓     백업 구절 확인 ✓")
			_label("거래 시스템은 다음 단계입니다. 현재 씬에서는 지갑 안내 완료까지 검증합니다.")
			_label("가상 지갑 주소   " + progress.address)
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

func _start_google() -> void:
	if transitioning:
		return
	auth.begin()
	if auth.busy:
		_show()

func _start_test() -> void:
	if auth.busy or transitioning:
		return
	if progress.authenticate("local-test", "test"):
		_show()

func _google_authenticated(id: String) -> void:
	if progress.authenticate(id, "google"):
		_show()

func _auth_failed(message: String) -> void:
	_show()
	notice.text = message
	notice.show()

func _cancel_login() -> void:
	auth.cancel()
	_show()
	notice.text = "로그인을 취소했습니다. 다시 시작할 수 있습니다."
	notice.show()

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

func _reset() -> void:
	if transitioning:
		return
	scenario.stop()
	auth.cancel()
	progress = Onboarding.new()
	_show()
