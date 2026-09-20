# Cozyland UI 적용 맵

> 2026-09-19 갱신: 일반 인벤토리, NPC 대화, 거래·선물 위젯은 `cozy_meadow.tres` 및 새 잎 장식 패널을 사용한다. 최신 원안·적용 결과는 [UI_DESIGN.md](UI_DESIGN.md)를 따른다. 아래는 이전 Cozyland/Doboui 적용 기록이다.

9-slice 픽셀 마진과 시트별 사용 가능 여부는 [UI_ASSET_9SLICE_ANALYSIS.md](UI_ASSET_9SLICE_ANALYSIS.md)에 별도로 기록한다.

## 2026-09-19 재평가

`Dialogue boxes.png`의 `16,20,48,76` 셀은 외곽선과 중앙 본문 사이에 별도의 장식 띠가 있다. 따라서 고정 크기의 프레임으로는 읽히지만, 긴 대화창의 중앙 Body를 늘리는 9-slice에는 부적합하다. 중앙을 Stretch하면 장식 띠의 비율도 함께 바뀐다.

대화창은 [npc_trade_dialogue.tscn](scenes/ui/npc_trade_dialogue.tscn)에서 `StyleBoxFlat`과 `MarginContainer`로 구성한다. 크기·여백·라벨 위치·버튼 상태를 Inspector에서 직접 조정한다. 이 선택은 에셋 팩의 모든 셀이 9-slice 소스라는 가정을 하지 않기 위한 것이다.

원본은 `Downloaded Assets/GUI/Cozyland UI`의 시트이며, 프로젝트에는 아래 두 파일만 이동했다.

| 시트 | 선택 영역 | 역할 | 적용 규칙 |
|---|---:|---|---|
| `cozyland_dialogue.png` | `16,20,48,76` | 고정 크기 장식 참고 | **대형 패널 9-slice에는 사용하지 않는다.** |
| `cozyland_ui.png` | `80,16,48,48` | Ring 기본 버튼 | 한 개의 독립 버튼 셀만 사용한다. |
| `cozyland_ui.png` | `128,16,48,48` | Ring hover/pressed 버튼 | 기본 셀과 같은 크기의 상태 셀만 사용한다. |
| `Garden cozy icons pack` | `G_Backpack`, `G_Tool`, `G_Book`, `G_Gift` | Ring·보관함의 메뉴 의미 전달 | 각 PNG가 독립된 96px 아이콘이다. 늘리지 않고 `TextureRect`의 Keep Aspect로 표시한다. |
| `DEMO_Cozy_UI_Pack_doboui` | `WoodenContainer1` | 인벤토리 배경 | 중앙 본문이 비어 있고 Edge가 분리되어 `StyleBoxTexture` 9-slice로 사용한다. |
| `DEMO_Cozy_UI_Pack_doboui` | `ItemSlot1`, `ItemSlotSelected1` | 인벤토리 분류·아이템 슬롯 | 독립 정사각형 에셋으로만 사용한다. |
| `DEMO_Cozy_UI_Pack_doboui` | `NoteContainerSimple` | 대화 화자 컨텍스트 | 종이 태그로 고정 비율 표시한다. 천공·찢어진 가장자리가 소스 전체에 걸쳐 있어 본문 9-slice로 쓰지 않는다. |

제외한 영역:

- `Dialogue boxes.png` 하단의 청회색 블록은 분리된 프레임이 아니라 목록·장식 조각과 연결되어 있어 큰 패널의 9-slice Body로 쓰지 않는다.
- `UI.png`의 수평 목록·게이지·화살표 묶음은 개별 Control에 직접 배치할 때만 사용한다. 일반 패널이나 버튼 스킨으로 자르지 않는다.
- Ring에는 `UI.png`의 사각 버튼을 늘려 쓰지 않는다. 원래 비율이 유지되는 독립 Garden 아이콘을 사용한다.
- 인벤토리에는 Garden의 보라·연두 아이콘을 쓰지 않는다. 목재 컨테이너와 Doboui 슬롯으로 팔레트와 Edge 언어를 통일한다.

대화 본문은 `StyleBoxFlat`으로 처리한다. 종이 태그의 천공·불규칙한 위아래 Edge는 3×3 영역으로 분리할 수 없어, 가변 폭 본문에 적용하면 중앙이 반복·왜곡된다. 거래 위젯도 같은 목재 컨테이너와 독립 정사각형 슬롯만 사용한다.
