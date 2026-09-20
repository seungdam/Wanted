# Bit & Bloom 대사 데이터와 공통 DialogScriptManager

## 목적

전역 시나리오와 주민 대사를 분리하고, 게임 객체가 XLSX 파일의 위치나 ZIP/XML 파싱을 직접 알지 않게 한다.

- `data/scenarios.xlsx`: arrival, wallet, tutorial, event, day, ending 등 공용 흐름. 현재 248 code.
- `data/npc_dialogues.xlsx`: `npc.*` 인사·선물·역제안·기분·주민 ID/role/speaker. 현재 89 code.
- `scripts/dialog_script_manager.gd`: 두 파일을 시작 시 읽어 하나의 code registry로 제공한다. 중복 code는 먼저 읽은 전역 시트를 유지한다.
- `scripts/scenario_sheet.gd`: 한 XLSX의 첫 worksheet를 읽는 낮은 수준 파서. 게임 객체가 직접 생성해 쓰는 경로는 테스트·도구용으로만 유지한다.

## 공통 API

```gdscript
DialogScriptManager.lines("npc.pin.greet.intro", {"nickname": GuestSession.nickname})
DialogScriptManager.has_code("tutorial.wallet.action")
DialogScriptManager.reload()
```

토큰 치환은 `{nickname}`, `{item}`, `{price}` 같은 코드 호출자의 명시적 값만 처리한다. 대사 데이터가 가격·호감도·보상을 결정하지 않는다. 보상과 상태 변경은 게임 로직이 담당한다.

## 사용 계층

`Title`, `ArrivalStory`, `NpcTradeDialogue`는 autoload `DialogScriptManager`를 조회한다. 이후 tutorial controller, event board, day summary, ending credit도 같은 API를 사용한다.

이 구조는 Unity ECS 자체가 아니다. 대사에는 엔티티 컴포넌트와 프레임 시스템이 필요하지 않으므로, 이번 데모에는 공유 데이터 서비스가 더 작은 구조다. NPC·튜토리얼·엔딩이 공통 manager를 호출하는 것으로 충분하다. 나중에 대사 진행 상태를 여러 엔티티가 병렬로 관리해야 할 때만 `DialogueState` 컴포넌트와 실행 시스템을 별도로 추가한다.

## 구현 순서

1. 현재 완료: NPC columns 분리, manager autoload, title/prologue/NPC trade 연결.
2. 다음: tutorial controller가 `tutorial.<stage>`, `.speaker`, `.action`을 읽고 완료 조건을 실행 상태와 연결한다.
3. 다음: event/day/ending 화면이 같은 manager로 문장·화자를 읽는다.
4. 검증: 두 workbook의 code 수, 중복 code, 필수 token, 누락 fallback을 시작 테스트에서 검사한다.

## Dialogue Manager 연동

Dialogue Manager 애드온을 실행 계층으로 추가했다. `tools/xlsx_to_dialogue.gd`가 XLSX 원본을 `dialogue/generated/*.dialogue`로 변환하며, `DialogScriptManager.dialogue_resource()`가 해당 산출물을 조회한다. 산출물이 없거나 import되지 않은 환경에서는 기존 `lines()` 경로로 fallback한다.

현재 NPC 거래 대화와 Arrival 대화가 생성 리소스를 우선 사용한다. 거래·선물·호감도·원장 변경은 여전히 게임 코드가 담당한다. 이 경계를 유지해야 대사가 경제 상태를 임의로 변경하지 않는다.

대사 파일을 갱신할 때는 동일 code를 두 workbook에 만들지 않는다. 시트에 없는 code는 UI가 빈 문장을 출력하지 말고 기본 fallback으로 진행한다.
