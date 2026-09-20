class_name DemoCore
extends RefCounted
## Scene-independent five-day demo loop. UI only reads the returned dictionaries and sends a choice back.

const EventDirectorScript = preload("res://scripts/event_director.gd")
const MockEventAIScript = preload("res://scripts/mock_event_ai.gd")

const PLAY_DAYS := 5
const STAGE_TUTORIAL := "tutorial"
const STAGE_NEWS1 := "news1"
const STAGE_NEWS2 := "news2"
const STAGE_REST := "rest"
const STAGE_ENDED := "ended"

var market := MarketCore.new()
var event_director = EventDirectorScript.new(market)
var mock_event_ai = MockEventAIScript.new()
var day := 0
var stage := STAGE_TUTORIAL
var day_results: Array[Dictionary] = []

func begin() -> Dictionary:
	if not market.load_data():
		return {"ok": false, "reason": "시장 데이터를 불러올 수 없어."}
	day = 0
	stage = STAGE_TUTORIAL
	day_results.clear()
	return {"ok": true, "stage": stage}

func start_next_day(ai_proposal = {}) -> Dictionary:
	if stage not in [STAGE_TUTORIAL, STAGE_REST]:
		return {"ok": false, "reason": "하루 정산 뒤 다음 날을 시작해 줘."}
	if stage == STAGE_ENDED:
		return {"ok": false, "reason": "데모가 이미 끝났어."}
	if market.cards.is_empty() and not begin().ok:
		return {"ok": false, "reason": "시장 데이터를 불러올 수 없어."}
	day += 1
	GuestSession.set_game_day(day)
	var proposal = ai_proposal
	if proposal is Dictionary and proposal.is_empty():
		proposal = mock_event_ai.proposal_for(day, event_director.valid_candidate_ids())
	var started := event_director.start_day(day, proposal)
	if not started.ok:
		return started
	stage = STAGE_NEWS1
	started["day"] = day
	started["stage"] = stage
	return started

func choose(choice: Dictionary, quantity := MarketCore.SHARE_SCALE) -> Dictionary:
	if stage != STAGE_NEWS1 and stage != STAGE_NEWS2:
		return {"ok": false, "reason": "지금은 선택할 수 없어."}
	var choices: Array = market.active_card.choices1 if stage == STAGE_NEWS1 else market.active_card.choices2
	if not choices.has(choice):
		return {"ok": false, "reason": "이번 소식에 없는 선택이야."}
	var act := str(choice.get("act", "hold"))
	if act == "hold":
		market.action_log.append({"day": day, "kind": "hold", "stage": stage})
		return {"ok": true, "action": "hold"}
	var asset := str(choice.get("asset", ""))
	if asset.is_empty():
		return {"ok": false, "reason": "이 선택은 보유 자산 화면에서 직접 정리해 줘."}
	return market.buy(asset, quantity, day, stage) if act == "buy" else market.sell(asset, quantity, day, stage)

func advance_news() -> Dictionary:
	if stage != STAGE_NEWS1:
		return {"ok": false, "reason": "첫 소식 뒤에만 다음 소식이 와."}
	stage = STAGE_NEWS2
	return {"ok": true, "day": day, "stage": stage, "event": market.advance_to_news2(day)}

func rest() -> Dictionary:
	if stage != STAGE_NEWS2:
		return {"ok": false, "reason": "두 번째 소식까지 본 뒤에 하루를 마칠 수 있어."}
	var summary := market.close_day(day)
	day_results.append(summary)
	if day >= PLAY_DAYS:
		stage = STAGE_ENDED
		return {"ok": true, "stage": stage, "summary": summary, "ending": ending_data()}
	stage = STAGE_REST
	return {"ok": true, "stage": stage, "summary": summary, "next_event_id": int(market.choose_next_event().get("id", -1))}

func ending_data() -> Dictionary:
	var trades := 0
	var gifts := 0
	var investments := 0
	for entry in GuestSession.ledger:
		if entry.type == "resident_trade":
			trades += 1
		elif entry.type == "gift":
			gifts += 1
		elif str(entry.type).begins_with("investment_"):
			investments += 1
	return {"days": day_results.duplicate(), "wallet_nut": GuestSession.nut, "portfolio_nut": market.portfolio_value(), "total_value_nut": GuestSession.nut + market.portfolio_value(), "trades": trades, "gifts": gifts, "investment_actions": investments, "achievements": GuestSession.achievement_ids(), "memories": GuestSession.memory_frame_entries()}
