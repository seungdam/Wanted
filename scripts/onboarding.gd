extends RefCounted
## Disposable guest tutorial data. These values are NOT account or blockchain secrets.
enum Stage { TITLE, NICKNAME, INTRO, WALLET, COMPLETE }
var stage := Stage.TITLE
var nickname := ""
var address := ""
var private_key := ""
var backup_words: Array[String] = []
var key_seen := false
var key_confirmed := false
var backup_seen := false
var backup_confirmed := false

func begin_guest() -> bool:
	if stage != Stage.TITLE:
		return false
	stage = Stage.NICKNAME
	return true

func set_nickname(value: String) -> bool:
	var clean := value.strip_edges()
	if stage != Stage.NICKNAME or clean.length() < 2 or clean.length() > 12:
		return false
	for character in clean:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127:
			return false
	nickname = clean
	stage = Stage.INTRO
	return true

func arrive_at_office() -> bool:
	if stage != Stage.INTRO:
		return false
	var crypto := Crypto.new()
	address = crypto.generate_random_bytes(6).hex_encode()
	private_key = crypto.generate_random_bytes(12).hex_encode()
	var words: Array[String] = ["망치", "구름", "사과", "바다", "나무", "별빛", "마당", "바람"]
	for index in range(3):
		var selected := int(crypto.generate_random_bytes(1)[0]) % words.size()
		backup_words.append(words.pop_at(selected))
	stage = Stage.WALLET
	return true

func reveal_key() -> void:
	if stage == Stage.WALLET:
		key_seen = true

func confirm_key() -> bool:
	if stage != Stage.WALLET or not key_seen:
		return false
	key_confirmed = true
	return true

func reveal_backup() -> void:
	if stage == Stage.WALLET and key_confirmed:
		backup_seen = true

func confirm_backup() -> bool:
	if stage != Stage.WALLET or not key_confirmed or not backup_seen:
		return false
	backup_confirmed = true
	stage = Stage.COMPLETE
	return true

func public_summary() -> Dictionary:
	return {"nickname": nickname, "address": address, "tutorial_complete": stage == Stage.COMPLETE}
