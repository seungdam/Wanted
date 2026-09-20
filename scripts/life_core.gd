extends RefCounted
## Shared inventory; world objects may call these methods after placement. Limits are demo tuning data.
var rules: Dictionary = {}
var uses: Dictionary = {}
var room: Dictionary:
	get: return GuestSession.room
	set(value): GuestSession.room = value
var tool := "hand"
var pending_catch := ""
var catch_elapsed := 0.0
var catch_day := -1
@export var respawn_seconds := 45.0
var respawn_at: Dictionary = {}

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/life_demo.json"))
	if parsed is Dictionary:
		rules = parsed

func equip(value: String) -> Dictionary:
	if value not in ["hand", "axe", "pickaxe", "rod", "net"]:
		return {"ok": false, "reason": "없는 도구야."}
	tool = value
	pending_catch = ""
	return {"ok": true}

func harvest(source_id: String) -> Dictionary:
	var base_id := source_id.split(":", false)[0]
	var source: Dictionary = rules.get("sources", {}).get(base_id, {})
	if source.is_empty() or source.tool != tool or not pending_catch.is_empty():
		return {"ok": false, "reason": "알맞은 도구를 선택하고 진행 중인 포획을 마쳐 줘."}
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(respawn_at.get(source_id, 0.0)):
		return {"ok": false, "reason": "아직 자원이 자라는 중이야."}
	respawn_at[source_id] = now + respawn_seconds
	if source.kind == "catch":
		pending_catch = source_id
		catch_elapsed = 0.0
		catch_day = GuestSession.current_day
		return {"ok": true, "waiting": true}
	return _grant(str(source.item), int(source.quantity), "gather")

func tick(delta: float) -> void:
	if not pending_catch.is_empty():
		catch_elapsed += maxf(0.0, delta)

func catch_target() -> Dictionary:
	if pending_catch.is_empty():
		return {"ok": false, "reason": "먼저 포획을 시작해 줘."}
	var source: Dictionary = rules.sources[pending_catch]
	pending_catch = ""
	if catch_day != GuestSession.current_day or catch_elapsed < 1.0 or catch_elapsed > 2.5:
		return {"ok": false, "reason": "놓쳤어. 1~2.5초 사이에 다시 시도해 봐."}
	return _grant(str(source.item), int(source.quantity), "catch")

func craft(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = rules.get("recipes", {}).get(recipe_id, {})
	if recipe.is_empty():
		return {"ok": false, "reason": "없는 제작법이야."}
	for item in recipe.materials:
		if GuestSession.item_count(item) < int(recipe.materials[item]):
			return {"ok": false, "reason": "재료가 부족해."}
	for item in recipe.materials:
		GuestSession.inventory[item] -= int(recipe.materials[item])
	return _grant(recipe_id, 1, "crafted_item")

func place(item: String, slot: int) -> Dictionary:
	if not rules.recipes.has(item) or slot < 0 or slot >= int(rules.room_slots) or room.has(slot) or GuestSession.item_count(item) < 1:
		return {"ok": false, "reason": "가구와 빈 자리를 확인해 줘."}
	GuestSession.inventory[item] -= 1
	room[slot] = item
	GuestSession.record_transaction("decorate", GuestSession.nickname, "내 방", 0, {"item_id": item, "item": label(item), "slot": slot, "wallet_delta": 0}, true)
	return {"ok": true}

func remove(slot: int) -> Dictionary:
	if not room.has(slot):
		return {"ok": false, "reason": "빈 자리야."}
	var item := str(room[slot])
	GuestSession.inventory[item] = GuestSession.item_count(item) + 1
	room.erase(slot)
	return {"ok": true}

func label(item: String) -> String:
	if item in ["fish", "butterfly"]:
		return "물고기" if item == "fish" else "나비"
	return str(rules.recipes[item].label) if rules.recipes.has(item) else GuestSession.item_label(item)

func _grant(item: String, quantity: int, kind: String) -> Dictionary:
	GuestSession.inventory[item] = GuestSession.item_count(item) + quantity
	GuestSession.wood = GuestSession.item_count("wood")
	var entry := GuestSession.record_transaction(kind, "마을", GuestSession.nickname, 0, {"item_id": item, "item": label(item), "quantity": quantity, "wallet_delta": 0, "event_id": GuestSession.market_event.id})
	GuestSession._register_discovery(item, kind, int(entry.id))
	return {"ok": true, "entry": entry}
