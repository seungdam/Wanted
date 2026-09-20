class_name EventDirector
extends RefCounted
## Turns an optional AI proposal into one verified historical event and resident-facing effects.

var market: MarketCore

func _init(market_core: MarketCore) -> void:
	market = market_core

func start_day(day: int, ai_proposal = {}) -> Dictionary:
	var requested_id := _requested_id(ai_proposal)
	var is_first_event := market.event_ids.is_empty()
	var selected := market.select_ai_event(MarketCore.FIRST_EVENT_ID if is_first_event else requested_id)
	if selected.is_empty():
		return {"ok": false, "reason": "유효한 사건 후보가 없어."}
	var event := market.start_day(day, int(selected.id))
	if event.is_empty():
		return {"ok": false, "reason": "사건 가격 구간을 준비할 수 없어."}
	var effects := _resident_effects(selected)
	GuestSession.set_market_event("macro-%d" % int(selected.id), effects, _context_text(selected, ai_proposal))
	var accepted := not is_first_event and requested_id == int(selected.id)
	var source := str(ai_proposal.get("source", "ai")) if ai_proposal is Dictionary else "ai"
	return {"ok": true, "event": event, "event_id": int(selected.id), "source": source if accepted else "fallback", "resident_effects": effects, "headline": _headline(selected, ai_proposal), "ai_request": proposal_request(selected)}

func proposal_request(card: Dictionary) -> Dictionary:
	return {"allowed_event_ids": valid_candidate_ids(), "current_event": {"id": int(card.id), "title": str(card.title), "type": str(card.type), "learn": str(card.learn)}, "response_schema": {"event_id": "integer from allowed_event_ids", "headline": "Korean string, 80 characters or fewer"}}

func valid_candidate_ids() -> Array[int]:
	var ids: Array[int] = []
	for card in market.cards:
		var candidate := market.select_ai_event(int(card.id))
		if not candidate.is_empty() and int(candidate.id) == int(card.id):
			ids.append(int(card.id))
	return ids

func _requested_id(proposal) -> int:
	if proposal is Dictionary:
		return int(proposal.get("event_id", -1))
	return int(proposal)

func _headline(card: Dictionary, proposal) -> String:
	if proposal is Dictionary:
		var headline := str(proposal.get("headline", "")).strip_edges()
		if not headline.is_empty() and headline.length() <= 80:
			return headline
	return "%s: %s" % [str(card.title), str(card.news1)]

func _context_text(card: Dictionary, proposal) -> String:
	var headline := _headline(card, proposal)
	return "%s · %s" % [headline, str(card.learn)]

func _resident_effects(card: Dictionary) -> Dictionary:
	var type := str(card.type)
	var bonus := 2 if type in ["위기", "충격"] else 1
	var rivet_item := "copper_ore" if "D" in card.focus or "I" in card.focus else "wood"
	var moa_item := "flower" if type in ["회복", "성장"] else "herb_tea"
	var popo_item := "stone" if type in ["위기", "충격"] else "old_book"
	var bori_item := "wild_honey" if type in ["성장", "과열"] else "wool"
	return {"residents": {"pin": {"item": rivet_item, rivet_item: bonus}, "clip": {"item": moa_item, moa_item: bonus}, "nut": {"item": popo_item, popo_item: bonus}, "screw": {"item": bori_item, bori_item: bonus}}}
