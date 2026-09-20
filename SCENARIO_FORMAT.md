# 시나리오 대사 관리

공용 대사는 data/scenarios.xlsx의 첫 번째 시트에서 관리한다(현재 248 code).
주민 대사는 data/npc_dialogues.xlsx의 첫 번째 시트에서 별도로 관리한다(현재 89 code).
게임 객체는 두 파일을 직접 열지 않고 DialogScriptManager autoload를 사용한다.

- 각 열의 1행에는 씬 코드 또는 코드 키를 입력한다.
- 같은 열의 2행부터 아래 방향으로 대사 순서를 입력한다.
- 비어 있는 셀은 건너뛰고, 같은 열의 대사는 위에서 아래 순서로 재생한다.
- {nickname}은 게스트가 입력한 이름으로 치환된다.

공용 사용 코드: arrival.nickname, arrival.nickname_error, arrival.intro,
arrival.speaker, wallet.intro, wallet.backup, wallet.complete,
wallet.key_reply, wallet.backup_reply.

주민 workbook의 거래 튜토리얼 코드: npc.trade_speaker, npc.trade_intro, npc.trade_offer,
npc.trade_success, npc.trade_cancel.

주민 역할별 대화 코드: npc.fixer.intro, npc.fixer.success,
npc.gardener.intro, npc.gardener.success, npc.careful.intro,
npc.careful.success, npc.merchant.intro, npc.merchant.success.
첨부된 확장 시트는 역할별 인사·선물·역제안 대사도 제공한다:
npc.{role}.greet.{mood}, npc.{role}.gift.{taste},
npc.{role}.counter.{result}. 이동 주민의 ID와 역할은
npc.pin/nut/clip/screw.speaker 및 .role에서 읽는다.
기분별 대화는 npc.mood.joy, npc.mood.calm, npc.mood.blank,
npc.mood.sad를 사용한다. 역할별 speaker는 npc.fixer.speaker,
npc.gardener.speaker, npc.careful.speaker, npc.merchant.speaker다.

동일한 code를 두 열에 두지 않는다. 첨부된 확장 시트에는
npc.trade_cancel이 AB열에 한 번만 있다. 파서는 열 순서에 따른 덮어쓰기를
정상 동작으로 간주하지 않는다.

Excel에서 수정·저장한 .xlsx를 그대로 읽는다. 지원 범위는 현재 구조처럼
Scenarios 첫 번째 시트의 텍스트 셀이다.
