extends Node
## Desktop Google OAuth via Supabase PKCE. No tokens are written to disk.
signal authenticated(user_id: String)
signal failed(message: String)
const PORT := 43821
const CALLBACK := "http://127.0.0.1:43821/callback"
var project_url := ""
var public_key := ""
var busy := false
var access_token := ""
var expires_at := 0.0
var _verifier := ""
var _state := ""
var _deadline := 0
var _peer_deadline := 0
var _buffer := ""
var _generation := 0
var _phase := ""
var _server := TCPServer.new()
var _peer: StreamPeerTCP
var _http: HTTPRequest

func _ready() -> void:
	var config := ConfigFile.new()
	config.load("res://auth.local.cfg")
	project_url = OS.get_environment("SUPABASE_URL").strip_edges().trim_suffix("/")
	public_key = OS.get_environment("SUPABASE_PUBLISHABLE_KEY").strip_edges()
	if project_url.is_empty():
		project_url = str(config.get_value("supabase", "url", "")).strip_edges().trim_suffix("/")
	if public_key.is_empty():
		public_key = str(config.get_value("supabase", "publishable_key", "")).strip_edges()

func configuration_error() -> String:
	if OS.has_feature("web"):
		return "현재 실제 로그인은 데스크톱 테스트용입니다. 웹에서는 테스트 입장을 사용하세요."
	var pattern := RegEx.new()
	pattern.compile("^https://[a-z0-9-]+\\.supabase\\.co$")
	if pattern.search(project_url) == null or not public_key.begins_with("sb_publishable_") or public_key.contains("\n") or public_key.contains("\r"):
		return "Google 연결 설정이 없습니다. AUTH_SETUP.md를 참고하거나 테스트로 입장하세요."
	return ""

static func base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")

static func challenge(verifier: String) -> String:
	return base64url(verifier.sha256_buffer())

func begin() -> void:
	if busy:
		return
	var issue := configuration_error()
	if not issue.is_empty():
		failed.emit(issue)
		return
	cancel()
	if _server.listen(PORT, "127.0.0.1") != OK:
		failed.emit("로그인 반환 포트를 사용할 수 없습니다. 다른 로그인 창을 닫고 다시 시도하세요.")
		return
	busy = true
	_phase = "callback"
	_verifier = base64url(Crypto.new().generate_random_bytes(32))
	_state = base64url(Crypto.new().generate_random_bytes(24))
	_deadline = Time.get_ticks_msec() + 120000
	var redirect := CALLBACK + "?app_state=" + _state
	var url := project_url + "/auth/v1/authorize?provider=google&redirect_to=" + redirect.uri_encode()
	url += "&code_challenge_method=s256&code_challenge=" + challenge(_verifier)
	if OS.shell_open(url) != OK:
		_fail("브라우저를 열지 못했습니다. 다시 시도하세요.")

func cancel() -> void:
	_generation += 1
	busy = false
	_phase = ""
	_server.stop()
	_close_peer()
	if is_instance_valid(_http):
		_http.cancel_request()
		_http.queue_free()
	_http = null
	_verifier = ""
	_state = ""
	access_token = ""
	expires_at = 0.0

func _exit_tree() -> void:
	cancel()

func _fail(message: String) -> void:
	cancel()
	failed.emit(message)

func _close_peer() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null
	_buffer = ""

func _process(_delta: float) -> void:
	if not busy:
		return
	if Time.get_ticks_msec() > _deadline:
		_fail("로그인 시간이 초과되었습니다. 다시 시도하세요.")
		return
	if _phase != "callback":
		return
	if _peer == null and _server.is_connection_available():
		_peer = _server.take_connection()
		_peer_deadline = Time.get_ticks_msec() + 3000
	if _peer == null:
		return
	_peer.poll()
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() > _peer_deadline:
		_close_peer()
		return
	var available := _peer.get_available_bytes()
	if available > 0:
		if available + _buffer.length() > 8192:
			_reply(false)
			return
		_buffer += _peer.get_utf8_string(available)
	if not _buffer.contains("\r\n\r\n"):
		return
	var result := parse_callback(_buffer, _state)
	_reply(not result.is_empty())
	if result.is_empty():
		return
	if result.has("error"):
		_fail("Google 로그인이 취소되었거나 거부되었습니다.")
		return
	_server.stop()
	_phase = "exchange"
	_request("/auth/v1/token?grant_type=pkce", HTTPClient.METHOD_POST, {"auth_code": result.code, "code_verifier": _verifier})

static func parse_callback(request: String, expected_state: String) -> Dictionary:
	if expected_state.is_empty() or request.length() > 8192:
		return {}
	var line := request.get_slice("\r\n", 0).split(" ")
	if line.size() != 3 or line[0] != "GET" or line[2] != "HTTP/1.1":
		return {}
	var target := line[1].split("?", true, 1)
	if target.size() != 2 or target[0] != "/callback":
		return {}
	var query := {}
	for pair in target[1].split("&"):
		var parts := pair.split("=", true, 1)
		if parts.size() != 2:
			return {}
		var key := parts[0].uri_decode()
		if query.has(key):
			return {}
		query[key] = parts[1].uri_decode()
	if query.get("app_state", "") != expected_state:
		return {}
	if query.has("error"):
		return {"error": true}
	var code := str(query.get("code", ""))
	return {"code": code} if not code.is_empty() and code.length() <= 2048 else {}

func _reply(ok: bool) -> void:
	var body := "Return to the game to finish signing in." if ok else "Invalid callback. Return to the game and retry."
	var status := "200 OK" if ok else "400 Bad Request"
	_peer.put_data(("HTTP/1.1 " + status + "\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: " + str(body.to_utf8_buffer().size()) + "\r\n\r\n" + body).to_utf8_buffer())
	_close_peer()

func _request(path: String, method: int, body: Dictionary = {}) -> void:
	if is_instance_valid(_http):
		_http.queue_free()
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.body_size_limit = 262144
	_http.max_redirects = 0
	add_child(_http)
	_http.request_completed.connect(_on_response.bind(_generation), CONNECT_ONE_SHOT)
	var headers := PackedStringArray(["apikey: " + public_key, "Content-Type: application/json"])
	if not access_token.is_empty():
		headers.append("Authorization: Bearer " + access_token)
	var payload := "" if body.is_empty() else JSON.stringify(body)
	if _http.request(project_url + path, headers, method, payload) != OK:
		_fail("인증 요청을 시작하지 못했습니다.")

func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, attempt: int) -> void:
	if attempt != _generation or not busy:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail("인증 서버에 연결하지 못했거나 요청이 거부되었습니다. 설정과 네트워크를 확인하세요.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("인증 서버 응답을 확인할 수 없습니다.")
		return
	if _phase == "exchange":
		var lifetime: Variant = parsed.get("expires_in", 0)
		if not parsed.get("access_token") is String or str(parsed.get("access_token", "")).is_empty() or not (lifetime is float or lifetime is int) or float(lifetime) <= 0:
			_fail("인증 토큰을 받지 못했습니다.")
			return
		access_token = parsed.access_token
		if access_token.contains("\r") or access_token.contains("\n"):
			_fail("인증 토큰 형식이 올바르지 않습니다.")
			return
		expires_at = Time.get_unix_time_from_system() + float(lifetime)
		_verifier = ""
		_state = ""
		_phase = "user"
		_request("/auth/v1/user", HTTPClient.METHOD_GET)
	elif _phase == "user":
		var metadata: Variant = parsed.get("app_metadata", {})
		if not parsed.get("id") is String or str(parsed.get("id", "")).is_empty() or not metadata is Dictionary:
			_fail("Google 계정 인증을 확인하지 못했습니다.")
			return
		var providers: Variant = metadata.get("providers", [])
		if not providers is Array or not "google" in providers or expires_at <= Time.get_unix_time_from_system():
			_fail("Google 계정 인증을 확인하지 못했습니다.")
			return
		busy = false
		_phase = ""
		authenticated.emit(parsed.id)
