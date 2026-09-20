extends Node
## Demo-only wallet and inventory shared from the prologue to the village.
const NUTS_PER_VOLT := 100
const STARTING_NUT := 500 * NUTS_PER_VOLT
const STARTING_ITEMS := {"wood": 30, "stone": 20, "flower": 15, "copper_ore": 3, "herb_tea": 3, "berry_jam": 3, "old_book": 3, "seashell": 3, "wool": 3, "wild_honey": 3}
const GIFT_ITEMS := ["wood", "stone", "flower", "copper_ore", "herb_tea", "berry_jam", "old_book", "seashell", "wool", "wild_honey"]
var nickname := ""
var address := ""
var nut := STARTING_NUT
var inventory: Dictionary = STARTING_ITEMS.duplicate()
var wood := STARTING_ITEMS.wood # Legacy shorthand used by the first tutorial and ring menu.
var blocks := 0 # Meaningful economic actions become memory nodes, not wall blocks.
var ledger: Array[Dictionary] = []
var market_event := {"id": "calm_day", "demand": {}}
var current_day := 1
var game_minute := 0
var transaction_sequence := 0
var offer_sequence := 0
var settled_offer_ids: Dictionary = {}
var collection: Dictionary = {}
var memory_frame: Array[int] = []
var room: Dictionary = {}
var unlocked_actions := {"mock_investment": false, "securities_trading": false}

# Only economic transactions become memories. Conversation, gifts, quests,
# crafting and decoration remain in the ledger without creating a frame node.
const MEMORY_TRANSACTION_TYPES := ["resident_trade", "item_buy", "item_sell", "investment_buy", "investment_sell"]

func begin(player_name: String, wallet_address: String) -> void:
	nickname = player_name
	address = wallet_address
	nut = STARTING_NUT
	inventory = STARTING_ITEMS.duplicate()
	wood = inventory.wood
	blocks = 0
	ledger.clear()
	market_event = {"id": "calm_day", "demand": {}}
	current_day = 1
	game_minute = 0
	transaction_sequence = 0
	offer_sequence = 0
	settled_offer_ids.clear()
	collection.clear()
	memory_frame.clear()
	room.clear()
	unlocked_actions = {"mock_investment": false, "securities_trading": false}

func set_game_day(day: int) -> void:
	current_day = maxi(day, 1)

func set_game_clock(day: int, minute: int) -> void:
	set_game_day(day)
	game_minute = clampi(minute, 0, 1439)

func unlock_action(action_id: String) -> void:
	unlocked_actions[action_id] = true

func is_action_unlocked(action_id: String) -> bool:
	return bool(unlocked_actions.get(action_id, false))

func volt_to_nut(value: int) -> int:
	return value * NUTS_PER_VOLT

func format_nut(value: int) -> String:
	@warning_ignore("integer_division")
	return "%d.%02d볼트" % [value / NUTS_PER_VOLT, abs(value) % NUTS_PER_VOLT]

func item_count(item: String) -> int:
	return int(inventory.get(item, 0))

func item_label(item: String) -> String:
	return {"wood": "나무", "stone": "돌", "flower": "꽃", "copper_ore": "구리 광석", "herb_tea": "허브차", "berry_jam": "베리 잼", "old_book": "낡은 책", "seashell": "조개", "wool": "양털", "wild_honey": "야생 꿀"}.get(item, item)

func set_market_event(event_id: String, demand: Dictionary, context := "") -> void:
	market_event = {"id": event_id, "demand": demand.duplicate(), "context": context}

func create_trade_offer(resident: String, item: String, base_unit_price: int, offered_unit_price: int, counter_limit: int) -> Dictionary:
	offer_sequence += 1
	return {"id": "offer-%03d" % offer_sequence, "day": current_day, "event_id": market_event.id, "resident_id": resident, "item_id": item, "quantity": 1, "base_unit_price": base_unit_price, "offered_unit_price": offered_unit_price, "counter_limit": counter_limit, "state": "ready"}

func record_transaction(type: String, from: String, to: String, amount: int, details := {}, _creates_memory := false) -> Dictionary:
	transaction_sequence += 1
	var block := 0
	var should_create_memory := type in MEMORY_TRANSACTION_TYPES
	if should_create_memory:
		blocks += 1
		block = blocks
	var entry := {"id": transaction_sequence, "transaction_id": "tx-%03d" % transaction_sequence, "day": current_day, "game_minute": game_minute, "type": type, "kind": type, "from": from, "to": to, "player_id": address, "counterparty_id": to, "amount": amount, "wallet_delta": amount, "block": block, "is_memory": block > 0}
	entry.merge(details.duplicate())
	ledger.append(entry)
	return entry

func memory_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in ledger:
		if entry.get("is_memory", false):
			entries.append(entry)
	return entries

func memory_frame_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id in memory_frame:
		for entry in ledger:
			if int(entry.id) == id:
				entries.append(entry)
				break
	return entries

func toggle_memory_frame(transaction_id: int) -> bool:
	if memory_frame.has(transaction_id):
		memory_frame.erase(transaction_id)
		return true
	if memory_frame.size() >= 6:
		return false
	for entry in ledger:
		if int(entry.id) == transaction_id and entry.get("is_memory", false):
			memory_frame.append(transaction_id)
			return true
	return false

func collection_record(item: String) -> Dictionary:
	var sales: Array[Dictionary] = []
	for entry in ledger:
		if entry.get("type") == "resident_trade" and entry.get("item_id") == item:
			sales.append(entry)
	var result: Dictionary = collection.get(item, {}).duplicate()
	result["item_id"] = item
	result["item"] = item_label(item)
	result["sold_count"] = sales.size()
	if not sales.is_empty():
		var high: Dictionary = sales[0]
		var low: Dictionary = sales[0]
		for sale in sales:
			if int(sale.unit_price) > int(high.unit_price):
				high = sale
			if int(sale.unit_price) < int(low.unit_price):
				low = sale
		result["highest_sale"] = high
		result["lowest_sale"] = low
	return result

func achievement_ids() -> Array[String]:
	var result: Array[String] = []
	for entry in ledger:
		if entry.type == "resident_trade":
			result.append("first_sale")
			break
	for entry in ledger:
		if entry.type == "gift":
			result.append("first_gift")
			break
	if collection.size() >= 3:
		result.append("three_discoveries")
	return result

func _register_discovery(item: String, source: String, transaction_id: int) -> void:
	if not collection.has(item):
		collection[item] = {"first_day": current_day, "first_minute": game_minute, "source": source, "transaction_id": transaction_id}

func sell_item(item: String, price_volt: int, resident: String, details := {}) -> Dictionary:
	if item_count(item) < 1:
		return {"ok": false, "reason": "%s이(가) 없어 거래할 수 없어." % item_label(item)}
	if price_volt <= 0:
		return {"ok": false, "reason": "거래 가격은 1볼트 이상이어야 해."}
	inventory[item] = item_count(item) - 1
	wood = item_count("wood")
	var price := volt_to_nut(price_volt)
	nut += price
	var transaction_details := {"item": item_label(item), "item_id": item, "quantity": 1, "event": market_event.id, "event_id": market_event.id, "unit_price": price, "display_unit_price_volt": price_volt, "total_amount": price, "wallet_delta": price}
	transaction_details.merge(details.duplicate())
	var entry := record_transaction("resident_trade", nickname, resident, price, transaction_details, true)
	_register_discovery(item, "sale", entry.id)
	return {"ok": true, "entry": entry}

func settle_resident_trade(offer: Dictionary, resident: String, details := {}) -> Dictionary:
	var offer_id := str(offer.get("id", ""))
	if offer_id.is_empty() or settled_offer_ids.has(offer_id):
		return {"ok": false, "reason": "이미 처리된 거래 제안이야."}
	if int(offer.get("day", current_day)) != current_day or str(offer.get("event_id", market_event.id)) != str(market_event.id):
		return {"ok": false, "reason": "거래 조건이 바뀌었어. 다시 제안해 줘."}
	var item := str(offer.get("item_id", ""))
	var price := int(offer.get("offered_unit_price", 0))
	var transaction_details := {"offer_id": offer_id, "base_unit_price": int(offer.get("base_unit_price", price)), "offered_unit_price": price, "counter_limit": int(offer.get("counter_limit", price)), "negotiation_result": str(offer.get("negotiation_result", "accepted"))}
	transaction_details.merge(details.duplicate())
	var result := sell_item(item, price, resident, transaction_details)
	if result.ok:
		settled_offer_ids[offer_id] = result.entry.id
	return result

func buy_item(item: String, price_volt: int, seller: String, details := {}) -> Dictionary:
	if price_volt <= 0:
		return {"ok": false, "reason": "거래 가격은 1볼트 이상이어야 해."}
	var price := volt_to_nut(price_volt)
	if nut < price:
		return {"ok": false, "reason": "볼트가 부족해."}
	nut -= price
	inventory[item] = item_count(item) + 1
	wood = item_count("wood")
	var transaction_details := {"item": item_label(item), "item_id": item, "quantity": 1, "event": market_event.id, "event_id": market_event.id, "unit_price": price, "display_unit_price_volt": price_volt, "total_amount": price, "wallet_delta": -price}
	transaction_details.merge(details.duplicate())
	var entry := record_transaction("item_buy", nickname, seller, price, transaction_details, false)
	_register_discovery(item, "buy", entry.id)
	return {"ok": true, "entry": entry}

func gift_item(item: String, resident: String, details := {}) -> Dictionary:
	if item_count(item) < 1:
		return {"ok": false, "reason": "%s이(가) 없어 선물할 수 없어." % item_label(item)}
	inventory[item] = item_count(item) - 1
	wood = item_count("wood")
	var transaction_details := {"item": item_label(item), "item_id": item, "quantity": 1, "event": market_event.id, "event_id": market_event.id, "unit_price": 0, "total_amount": 0, "wallet_delta": 0}
	transaction_details.merge(details.duplicate())
	var entry := record_transaction("gift", nickname, resident, 0, transaction_details, true)
	_register_discovery(item, "gift", entry.id)
	return {"ok": true, "entry": entry}

func fulfill_request(item: String, resident: String) -> Dictionary:
	if item_count(item) < 1:
		return {"ok": false, "reason": "%s이(가) 없어 부탁을 도울 수 없어." % item_label(item)}
	inventory[item] = item_count(item) - 1
	wood = item_count("wood")
	var entry := record_transaction("quest", nickname, resident, 0, {"item": item_label(item), "item_id": item, "quantity": 1, "event": market_event.id, "event_id": market_event.id, "unit_price": 0, "total_amount": 0, "wallet_delta": 0}, true)
	_register_discovery(item, "request", entry.id)
	return {"ok": true, "entry": entry}

func sell_wood(price: int, resident: String) -> Dictionary:
	return sell_item("wood", price, resident)
