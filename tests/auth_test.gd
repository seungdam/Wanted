extends Node
const Flow = preload("res://scripts/auth/onboarding.gd")
const Login = preload("res://scripts/auth/google_login.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	var flow = Flow.new()
	check(not flow.arrive_at_office(), "Wallet requires login and nickname")
	check(not flow.authenticate("", "google"), "Empty identity rejected")
	check(flow.authenticate("test-user", "test"), "Test session has explicit provider")
	check(not flow.authenticate("other", "google"), "Duplicate login cannot replace active user")
	for value in ["", " ", "a", "abcdefghijklmn", "ab\ncd"]:
		check(not flow.set_nickname(value), "Invalid nickname rejected")
	check(flow.set_nickname("  도토리  ") and flow.nickname == "도토리", "Nickname trimmed")
	check(flow.arrive_at_office(), "Office creates tutorial wallet")
	var address: String = flow.address
	check(address.length() == 12 and flow.private_key.length() == 24, "Tutorial string lengths")
	check(flow.backup_words.size() == 3, "Three backup words")
	check(not flow.arrive_at_office() and flow.address == address, "Cannot regenerate wallet by double click")
	flow.reveal_backup()
	check(not flow.backup_seen and not flow.confirm_key() and not flow.confirm_backup(), "No skipping acknowledgements")
	flow.reveal_key()
	check(flow.confirm_key(), "Key acknowledgement")
	check(not flow.confirm_backup(), "Backup must be displayed first")
	flow.reveal_backup()
	check(flow.confirm_backup(), "Backup acknowledgement completes tutorial")
	check(not flow.confirm_backup(), "Completion happens once")
	var summary: Dictionary = flow.public_summary()
	check(summary.tutorial_complete and not summary.has("private_key") and not summary.has("backup_words"), "Completion payload excludes secrets")
	# RFC 7636 Appendix B known vector, independent of our implementation.
	check(Login.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "PKCE S256 vector")
	var callback := "GET /callback?app_state=expected&code=one-time-code HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
	check(Login.parse_callback(callback, "expected").get("code") == "one-time-code", "Valid callback")
	check(Login.parse_callback(callback, "wrong").is_empty(), "CSRF state mismatch")
	check(Login.parse_callback(callback, "").is_empty(), "No pending login rejects callback")
	check(Login.parse_callback(callback.replace("GET", "POST"), "expected").is_empty(), "Reject unexpected method")
	check(Login.parse_callback(callback.replace("/callback", "/favicon.ico"), "expected").is_empty(), "Reject unrelated path")
	check(Login.parse_callback(callback.replace("&code=", "&app_state=expected&code="), "expected").is_empty(), "Reject duplicate query keys")
	check(Login.parse_callback(callback.replace("code=one-time-code", "error=access_denied"), "expected").has("error"), "Provider cancellation")
	check(Login.parse_callback("x".repeat(8193), "expected").is_empty(), "Bound callback size")
	var auth = Login.new()
	add_child(auth)
	auth.project_url = ""
	auth.public_key = ""
	check(not auth.configuration_error().is_empty(), "Missing config disables real OAuth")
	var errors: Array[String] = []
	var users: Array[String] = []
	auth.failed.connect(func(message: String): errors.append(message))
	auth.authenticated.connect(func(id: String): users.append(id))
	auth.begin()
	check(errors.size() == 1 and not auth.busy, "Missing config never pretends to log in")
	auth.busy = true
	auth._deadline = Time.get_ticks_msec() - 1
	auth._process(0.0)
	check(not auth.busy and errors.size() == 2, "Login timeout clears pending state")
	auth.busy = true
	auth._phase = "exchange"
	auth._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "[]".to_utf8_buffer(), auth._generation)
	check(not auth.busy and users.is_empty(), "Malformed token response fails closed")
	auth.busy = true
	auth._phase = "user"
	auth.expires_at = Time.get_unix_time_from_system() + 60
	var response := JSON.stringify({"id": "verified-user", "app_metadata": {"providers": ["google"]}}).to_utf8_buffer()
	auth._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), response, auth._generation - 1)
	check(users.is_empty(), "Stale async result ignored")
	auth._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), response, auth._generation)
	check(users == ["verified-user"] and not auth.busy, "Validated user response completes login")
	auth.cancel()
	check(auth.access_token.is_empty() and auth._state.is_empty() and auth._verifier.is_empty(), "Reset clears authentication material")
	auth.queue_free()
	var title = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	await settle(title)
	if "--capture-auth" in OS.get_cmdline_user_args():
		await capture("title")
	title.find_child("TestLogin", true, false).pressed.emit()
	check(title.transitioning and title.fade.visible, "Scene transition blocks input")
	title._reset()
	check(title.progress.stage == Flow.Stage.NICKNAME, "Reset ignored during transition")
	await settle(title)
	check(not title.fade.visible and not title.scenario.input_locked, "Fade releases input")
	check(title.progress.stage == Flow.Stage.NICKNAME, "UI test login")
	title.find_child("Nickname", true, false).text = "도토리"
	title.find_child("SaveNickname", true, false).pressed.emit()
	check(title.scenario.visible and not title.scroll.visible, "Login opens separate story scene")
	title.scenario.advance()
	check(title.scenario.line_index == 0 and title.progress.stage == Flow.Stage.INTRO, "First click completes text without skipping")
	if "--capture-auth" in OS.get_cmdline_user_args():
		await capture("story")
	for index in range(5):
		title.scenario.advance()
		check(title.scenario.line_index == index + 1, "Dialogue advances in order")
		title.scenario.advance()
	check(title.progress.stage == Flow.Stage.INTRO, "Tutorial waits for final choice")
	title.scenario.advance()
	title.scenario.advance()
	await settle(title)
	check(title.progress.stage == Flow.Stage.WALLET and not title.scenario.visible, "Final choice enters tutorial once")
	check(title.find_child("ConfirmKey", true, false).disabled, "UI key gate")
	title.find_child("RevealKey", true, false).pressed.emit()
	title.find_child("ConfirmKey", true, false).pressed.emit()
	check(title.find_child("ConfirmBackup", true, false).disabled, "UI backup gate")
	title.find_child("RevealBackup", true, false).pressed.emit()
	if "--capture-auth" in OS.get_cmdline_user_args():
		await capture("wallet")
	var completed: Array[Dictionary] = []
	title.onboarding_completed.connect(func(profile: Dictionary): completed.append(profile))
	title.find_child("ConfirmBackup", true, false).pressed.emit()
	await settle(title)
	check(completed.size() == 1 and title.progress.stage == Flow.Stage.COMPLETE, "UI complete signal")
	title.find_child("Reset", true, false).pressed.emit()
	await settle(title)
	check(title.progress.stage == Flow.Stage.TITLE and title.progress.address.is_empty(), "UI reset clears progress")
	title._start_test()
	await settle(title)
	await title.scenario.popup_tween.finished
	check(title.scenario.bubble.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(title.scenario.bubble.modulate.a, 1.0), "Bubble popup settles correctly")
	title.scenario.cancelled.emit()
	await settle(title)
	check(title.progress.stage == Flow.Stage.TITLE and not title.scenario.active, "Story cancellation clears session")
	if failures == 0:
		print("AUTH TEST PASS: nickname, wallet gates, PKCE, callback validation, cancel/timeout, response validation, complete/reset UI")
	else:
		push_error("AUTH TEST FAILED: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func capture(label: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://tests/auth-" + label + ".png") == OK, "Capture saved")

func settle(title: Control) -> void:
	while title.transitioning:
		await get_tree().process_frame
