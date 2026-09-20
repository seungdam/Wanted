class_name MarketCore
extends RefCounted
## Five-day investment replay. Prices come from curated local history; AI may only choose a valid event card.

const EVENT_PATH := "res://data/events.json"
const PRICE_PATH := "res://data/prices.csv"
const PLAY_DAYS := 5
const FIRST_EVENT_ID := 2 # Python prototype's common diversification tutorial card.
const LISTING_PRICE := 100 * GuestSession.NUTS_PER_VOLT
const SHARE_SCALE := 100 # One point is 0.01 share.
const FEE_RATE := 0.01
const ASSETS := {
	"A": "마을 바구니", "B": "바다 건너 바구니", "C": "나라 채권", "D": "금",
	"E": "프리즘전자", "F": "스카이모빌", "G": "온마을길잡이", "H": "메아리",
	"I": "코일반도체", "J": "네온전력", "K": "외국 돈"
}

var cards: Array[Dictionary] = []
var prices: Dictionary = {} # asset code -> { yyyy-mm-dd: historical close }
var active_card: Dictionary = {}
var replay_dates: Array[String] = []
var replay_index := 0
var price_base: Dictionary = {} # code -> { close, price }
var last_prices: Dictionary = {}
var holdings: Dictionary = {} # code -> { qty, average_price }
var event_ids: Array[int] = []
var action_log: Array[Dictionary] = []
var day_start_value := 0

func load_data() -> bool:
	var event_file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	var price_file := FileAccess.open(PRICE_PATH, FileAccess.READ)
	if event_file == null or price_file == null:
		return false
	var decoded = JSON.parse_string(event_file.get_as_text())
	if not decoded is Array:
		return false
	cards.clear()
	for card in decoded:
		if card is Dictionary:
			cards.append(card)
	prices.clear()
	price_file.get_csv_line() # header
	while not price_file.eof_reached():
		var row := price_file.get_csv_line()
		if row.size() != 3 or row[0].is_empty():
			continue
		if not prices.has(row[0]):
			prices[row[0]] = {}
		prices[row[0]][row[1]] = float(row[2])
	return not cards.is_empty() and not prices.is_empty()

func start_day(day: int, preferred_event_id := -1) -> Dictionary:
	if cards.is_empty() and not load_data():
		return {}
	var card := _valid_card(preferred_event_id)
	if card.is_empty():
		card = choose_next_event()
	if card.is_empty():
		return {}
	active_card = card
	if not event_ids.has(int(card.id)):
		event_ids.append(int(card.id))
	replay_dates = _dates_in_window(str(card.start), str(card.end))
	if replay_dates.is_empty():
		active_card = {}
		return {}
	replay_index = 0
	price_base.clear()
	for code in ASSETS:
		var close := _close_on_or_before(code, replay_dates[0])
		if close > 0.0:
			price_base[code] = {"close": close, "price": int(last_prices.get(code, LISTING_PRICE))}
	_refresh_prices()
	day_start_value = portfolio_value() + GuestSession.nut
	action_log.append({"day": day, "kind": "event_start", "event_id": int(card.id)})
	return public_event("news1")

func advance_to_news2(day: int) -> Dictionary:
	if active_card.is_empty():
		return {}
	var target := str(active_card.news2)
	while replay_index < replay_dates.size() - 1 and replay_dates[replay_index] < target:
		replay_index += 1
	_refresh_prices()
	action_log.append({"day": day, "kind": "news", "stage": "news2", "event_id": int(active_card.id)})
	return public_event("news2")

func close_day(day: int) -> Dictionary:
	if active_card.is_empty():
		return {}
	replay_index = replay_dates.size() - 1
	_refresh_prices()
	var total := GuestSession.nut + portfolio_value()
	var pnl := total - day_start_value
	var result := {"day": day, "event_id": int(active_card.id), "portfolio_value": portfolio_value(), "total_value": total, "investment_pnl": pnl, "focus_moves": focus_moves(), "lesson": str(active_card.learn), "feedback": str(active_card.feedback)}
	action_log.append({"day": day, "kind": "market_close", "event_id": int(active_card.id), "pnl": pnl})
	return result

func current_price(code: String) -> int:
	if not price_base.has(code) or replay_dates.is_empty():
		return 0
	var base: Dictionary = price_base[code]
	var close := _close_on_or_before(code, replay_dates[replay_index])
	if close <= 0.0:
		return 0
	return maxi(1, roundi(int(base.price) * close / float(base.close)))

func buy(code: String, quantity: int, day: int, context := "manual") -> Dictionary:
	if quantity < 1:
		return {"ok": false, "reason": "최소 수량은 1주야."}
	var price := current_price(code)
	if price <= 0:
		return {"ok": false, "reason": "지금은 거래할 수 없는 자산이야."}
	var gross := roundi(price * quantity / float(SHARE_SCALE))
	var fee := ceili(gross * FEE_RATE)
	if GuestSession.nut < gross + fee:
		return {"ok": false, "reason": "볼트가 부족해."}
	GuestSession.nut -= gross + fee
	var holding: Dictionary = holdings.get(code, {"qty": 0, "average_price": 0})
	holding.average_price = roundi((int(holding.average_price) * int(holding.qty) + price * quantity) / float(int(holding.qty) + quantity))
	holding.qty = int(holding.qty) + quantity
	holdings[code] = holding
	var entry := GuestSession.record_transaction("investment_buy", GuestSession.nickname, "마을 거래소", gross + fee, {"asset_id": code, "asset": ASSETS.get(code, code), "quantity_points": quantity, "quantity": quantity / float(SHARE_SCALE), "unit_price": price, "total_amount": gross, "fee": fee, "wallet_delta": -(gross + fee), "event_id": active_card.get("id", 0), "context": context}, true)
	action_log.append({"day": day, "kind": "buy", "asset_id": code, "quantity": quantity, "price": price, "context": context, "transaction_id": entry.id})
	return {"ok": true, "price": price, "gross": gross, "fee": fee, "entry": entry}

func sell(code: String, quantity: int, day: int, context := "manual") -> Dictionary:
	var holding: Dictionary = holdings.get(code, {})
	if quantity < 1 or holding.is_empty() or int(holding.get("qty", 0)) < quantity:
		return {"ok": false, "reason": "보유 수량이 부족해."}
	var price := current_price(code)
	if price <= 0:
		return {"ok": false, "reason": "지금은 거래할 수 없는 자산이야."}
	var gross := roundi(price * quantity / float(SHARE_SCALE))
	var fee := ceili(gross * FEE_RATE)
	GuestSession.nut += gross - fee
	holding.qty = int(holding.qty) - quantity
	if int(holding.qty) == 0:
		holdings.erase(code)
	else:
		holdings[code] = holding
	var entry := GuestSession.record_transaction("investment_sell", "마을 거래소", GuestSession.nickname, gross - fee, {"asset_id": code, "asset": ASSETS.get(code, code), "quantity_points": quantity, "quantity": quantity / float(SHARE_SCALE), "unit_price": price, "total_amount": gross, "fee": fee, "wallet_delta": gross - fee, "realized_pnl": roundi((price - int(holding.average_price)) * quantity / float(SHARE_SCALE)) - fee, "event_id": active_card.get("id", 0), "context": context}, true)
	action_log.append({"day": day, "kind": "sell", "asset_id": code, "quantity": quantity, "price": price, "context": context, "transaction_id": entry.id})
	return {"ok": true, "price": price, "gross": gross, "fee": fee, "entry": entry}

func portfolio_value() -> int:
	var value := 0
	for code in holdings:
		value += roundi(current_price(str(code)) * int(holdings[code].qty) / float(SHARE_SCALE))
	return value

func focus_moves() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for code in active_card.get("focus", []):
		if not price_base.has(code):
			continue
		var base: Dictionary = price_base[code]
		moves.append({"asset_id": code, "asset": ASSETS.get(code, code), "percent": roundi((current_price(code) / float(base.price) - 1.0) * 100.0)})
	return moves

func public_event(stage: String) -> Dictionary:
	if active_card.is_empty():
		return {}
	var is_second := stage == "news2"
	return {"id": int(active_card.id), "news": str(active_card.news2Text if is_second else active_card.news1), "choices": active_card.choices2 if is_second else active_card.choices1, "focus": active_card.focus, "stage": stage}

func choose_next_event() -> Dictionary:
	if cards.is_empty():
		return {}
	var last: Dictionary = _card_by_id(event_ids.back()) if not event_ids.is_empty() else {}
	var candidates: Array[Dictionary] = []
	for card in cards:
		if event_ids.has(int(card.id)) or int(card.id) == FIRST_EVENT_ID:
			continue
		if not last.is_empty() and str(card.start) < str(last.end):
			continue
		if not last.is_empty() and str(card.type) == str(last.type):
			continue
		candidates.append(card)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b): return _event_score(a) > _event_score(b) or (_event_score(a) == _event_score(b) and int(a.era) < int(b.era)))
	return candidates[0]

func select_ai_event(candidate_id: int) -> Dictionary:
	var candidate := _valid_card(candidate_id)
	return candidate if not candidate.is_empty() else choose_next_event()

func _valid_card(candidate_id: int) -> Dictionary:
	var id := FIRST_EVENT_ID if candidate_id < 0 and event_ids.is_empty() else candidate_id
	var candidate := _card_by_id(id)
	if candidate.is_empty() or event_ids.has(int(candidate.id)):
		return {}
	var last: Dictionary = _card_by_id(event_ids.back()) if not event_ids.is_empty() else {}
	if not last.is_empty() and (str(candidate.start) < str(last.end) or str(candidate.type) == str(last.type)):
		return {}
	return candidate

func _event_score(card: Dictionary) -> int:
	var total := maxi(1, GuestSession.nut + portfolio_value())
	var max_share := 0.0
	for code in holdings:
		max_share = maxf(max_share, current_price(str(code)) * int(holdings[code].qty) / float(SHARE_SCALE) / float(total))
	var score := 0
	if max_share > 0.6 and str(card.type) in ["위기", "충격"]:
		score += 3
	if GuestSession.nut / float(total) > 0.7 and str(card.type) == "성장":
		score += 2
	return score

func _card_by_id(id: int) -> Dictionary:
	for card in cards:
		if int(card.id) == id:
			return card
	return {}

func _dates_in_window(start: String, finish: String) -> Array[String]:
	var dates: Array[String] = []
	for date in prices.get("A", {}).keys():
		if str(date) >= start and str(date) <= finish:
			dates.append(str(date))
	dates.sort()
	return dates

func _close_on_or_before(code: String, date: String) -> float:
	var series: Dictionary = prices.get(code, {})
	if series.has(date):
		return float(series[date])
	for index in range(replay_index, -1, -1):
		var earlier := replay_dates[index]
		if series.has(earlier):
			return float(series[earlier])
	return 0.0

func _refresh_prices() -> void:
	for code in price_base:
		last_prices[code] = current_price(code)
