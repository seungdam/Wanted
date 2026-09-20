# UI 에셋 9-slice 판정

## 결론

모든 시트를 9-slice로 등록하면 안 된다. `StyleBoxTexture`는 소스의 `texture_margin_*` 안쪽을 고정하고, 남은 중앙/변을 늘리거나 반복한다. 이것은 비트마스크를 자동으로 만들어 주는 기능이 아니며, 모서리 장식이 마진 밖으로 새면 장식이 찌그러진다. 따라서 프레임과 본문을 분리할 수 있는 에셋만 9-slice로 사용하고, 천공·찢김·아이콘이 섞인 에셋은 고정 `TextureRect` 또는 `StyleBoxFlat`로 둔다.

## 에셋별 판정

| 에셋 | 원본 | 판정 | 적용 |
|---|---:|---|---|
| `assets/ui/skins/cozy_panel.png` | 1254×1254 | **정사각형 패널에 한해 9-slice 가능** | 잎 장식이 모서리마다 약 228px을 차지한다. `texture_margin_* = 228`이면 236px 높이의 얕은 대화창에서 세로 마진이 겹치므로 대화창에는 사용하지 않는다. 보관함·거래창처럼 높이가 충분한 패널에서만 중앙을 확장한다. |
| `assets/ui/inventory/wooden_container.png` | 1511×384 | **가로 9-slice 가능** | 둥근 좌우 모서리와 목재 본문이 분리되어 있다. 좌우는 약 72px 고정, 위·아래는 32px 고정으로 둔다. 세로를 과도하게 늘리면 얼룩 장식이 늘어나므로 인벤토리 높이는 내용에 맞춘다. |
| `assets/ui/cozy_source/button_*.png` | 128×128 | **소형 버튼에만 가능** | 한 칸짜리 버튼 프레임이다. 약 24px 모서리를 고정하고 아이콘은 별도 `TextureRect`로 둔다. 큰 패널로 재사용하지 않는다. |
| `assets/ui/skins/cozyland_ui.png` | 572×508 | **시트 절단 후 제한적 가능** | 셀 단위로 분리된 버튼/슬롯만 `AtlasTexture`로 사용한다. 셀 경계를 넘어 9-slice하면 인접 색상·장식이 섞인다. |
| `assets/ui/skins/cozyland_dialogue.png` | 256×192 | **본문 9-slice 불가** | 패널·목록·장식 조각이 한 시트에 붙어 있고 내부 띠가 있다. 대화 본문은 `StyleBoxFlat` 또는 `cozy_panel`을 쓴다. |
| `assets/ui/dialog/speaker_note.png` | 1090×330 | **9-slice 불가** | 왼쪽 천공과 위·아래의 불규칙한 종이 경계가 본문 영역 전체에 걸친다. 화자 라벨 뒤에 고정 비율 `TextureRect`로 둔다. |
| `assets/ui/inventory/item_slot*.png` | 정사각형 | **고정 슬롯** | 슬롯 자체를 늘리지 않고 아이콘과 함께 정사각형으로 배치한다. 선택 상태는 별도 텍스처로 교체한다. |
| `assets/ui/portraits/portrait_*_256.png` | 256×256 개별 Portrait | **고정 Sprite2D** | 제공된 클리핑 에셋을 주민 ID별로 직접 선택한다. 시트 프레임과 런타임 crop은 사용하지 않는다. |

## 현재 수정 기준

- `assets/ui/themes/cozy_meadow.tres`의 패널 소스를 `wooden_container.png`로 교체했다. 좌우 72px·상하 32px 마진으로 거래·인벤토리 패널을 확장한다. `cozy_panel.png`의 228px 모서리 프레임은 가변 패널에서 반복되므로 이 테마의 본문 소스로 사용하지 않는다.
- `scenes/ui/npc_trade_dialogue.tscn`과 `scenes/ui/cozy_dialogue_balloon.tscn`의 얕은 대화 본문은 `StyleBoxFlat`으로 분리했다. 초상화는 고정 크기로 본문 영역과 분리했다.
- 모든 대화·거래 경로는 공통 `ResidentPortrait`를 사용하며, 주민 ID가 제공된 개별 256px Portrait를 선택한다.
- 이름표·화자 노트는 본문 패널과 별도 레이어다. 이름표를 본문 9-slice에 넣지 않아 라벨 길이에 따라 모서리가 변하지 않는다.

## 검수 규칙

1. `texture_margin_*` 안에 모서리 장식 전체가 들어가는지 원본 픽셀로 확인한다.
2. `content_margin_*`는 텍스트가 들어갈 내부 테두리 안쪽으로 지정한다. 텍스처 마진과 같은 값일 필요는 없다.
3. 반복이 필요한 픽셀 아트 띠만 `axis_stretch_* = TILE(1)`; 그림·잎·종이 질감은 `STRETCH(0)`로 중앙만 확장한다. 현재 Cozy 패널과 목재 컨테이너는 모두 `0`으로 고정했다.
4. 시트 에셋은 먼저 `AtlasTexture.region`으로 셀을 고정한 뒤 9-slice 여부를 판단한다. 시트 전체를 StyleBoxTexture에 직접 연결하지 않는다.
5. 대화창·거래창·인벤토리창의 본문 폭을 넓혀도 모서리 잎, 초상화, 천공, 아이콘의 픽셀 비율이 변하지 않아야 한다.

## 캡처 검토 결과

`tests/skin_preview_capture.tscn`을 창 모드로 실행해 다음 캡처를 확인했다.

- `tests/npc_trade_skin_preview.png`: 얕은 대화창은 단일 `StyleBoxFlat`로 이어지고 초상화·화자 태그·버튼이 겹치지 않는다.
- `tests/cozy_balloon_skin_preview.png`: Dialogue Manager Custom Balloon도 같은 본문 규칙으로 렌더링된다.
- `tests/inventory_skin_preview.png`: `wooden_container.png`의 좌우 모서리와 중앙 목재 본문이 한 패널로 이어진다.
- `tests/trade_widget_skin_preview.png`: 거래 패널의 슬롯과 초상화가 목재 컨테이너 안에 정렬된다.
- `tests/ring_skin_preview.png`: Ring Menu 아이콘은 플레이어 중심에서 시계 방향으로 분리되어 표시된다.
- `tests/resident_portraits_skin_preview.png`: 네 주민 Portrait가 서로 다른 시트 영역으로 표시되고 인접 셀 픽셀이 섞이지 않는다.

첫 캡처에서는 `cozy_panel.png`를 모든 패널에 적용해 3×3 조각 반복이 발생했다. 해당 에셋을 고정 장식용으로 제한하고, 가변 패널은 `wooden_container.png` 또는 `StyleBoxFlat`으로 교체한 뒤 재검수했다.
