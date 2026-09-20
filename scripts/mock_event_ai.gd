class_name MockEventAI
extends RefCounted
## Local stand-in for the future Ollama response. It returns only the EventDirector proposal contract.

const DEMO_EVENT_IDS := [2, 3, 4, 6, 7]
const HEADLINES := {
	2: "거래소에 첫 마을 바구니가 도착했어요.",
	3: "마을 금고의 외국 돈이 빠르게 줄고 있어요.",
	4: "조용하던 공장 굴뚝에 다시 연기가 피어올라요.",
	6: "광장에서는 새 기술 이야기가 매일 커지고 있어요.",
	7: "한때 뜨겁던 기술 회사들이 흔들리기 시작했어요."
}

func proposal_for(day: int, allowed_event_ids: Array[int]) -> Dictionary:
	var preferred: int = int(DEMO_EVENT_IDS[clampi(day - 1, 0, DEMO_EVENT_IDS.size() - 1)])
	if not allowed_event_ids.has(preferred):
		preferred = allowed_event_ids.front() if not allowed_event_ids.is_empty() else -1
	return {"event_id": preferred, "headline": str(HEADLINES.get(preferred, "마을에 새로운 경제 소식이 도착했어요.")), "source": "mock"}
