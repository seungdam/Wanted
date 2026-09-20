# 아이소메트릭 마을 베이스라인

F5는 **Bit & Bloom 게스트 프롤로그·가상 지갑·마을 거래 튜토리얼**을 실행합니다. 로그인과 외부 인증 없이 닉네임·프롤로그·지갑 안내를 마친 뒤 마을에서 리벳과 첫 거래를 진행합니다. 대사는 [scenarios.xlsx](/D:/Projects/Wanted/data/scenarios.xlsx)에 열 단위로 관리합니다.

맵·시야·카메라·시간·NPC 수치 조절은 [Inspector 테스트 가이드](INSPECTOR.md)를 참고하세요.
현재 구현의 구조 평가와 기획 대비 정리·고도화 순서는 [월드 소스 평가](WORLD_REVIEW.md)를 참고하세요.

Godot **4.6 이상 + LimboAI 1.8.1 GDExtension**을 사용하는 GDScript 프로젝트입니다. 설치된 **4.7.1**에서 검증했습니다.
마을에서는 `WASD`로 8방향 등속 이동하며, 주민에게 가까이 가면 `SPACE` 안내가 나타납니다. `I`는 플레이어 주변의 아이템·도구·거래 추억 액자 링 메뉴를 엽니다. 상세 팝업을 열면 이동이 잠깁니다.

## 구현 범위

- 실제 `TileMapLayer`에 192×96 다이아몬드 타일 32×32개 배치: 잔디, 길, 물. 플레이어·NPC·건물도 직전 버전 대비 2배 크기입니다. 맵 크기는 Inspector에서 조절합니다. 외부 아틀라스 원본 규격은 기존 64×32를 유지하고 표시 크기만 확대합니다.
- 2D 아이소메트릭 투영과 발 위치 기준 Y 정렬로 건물 앞뒤 가림 표현.
- 플레이어 1개, 8방향 A* 이동, 클릭한 타일 중심에서 정지.
- `AStarGrid2D`의 octile 비용/휴리스틱, 장애물 양옆이 열려 있을 때만 대각선 이동.
- 건물과 물은 통행 불가. 외부/막힌/도달 불가 타일 클릭 시 기존 이동을 유지하고 안내 표시.
- 이동 중 새 명령은 진행 중인 한 구간을 완료한 다음 새 경로로 연결. 순간이동이나 모서리 가로지르기 방지.
- 속도는 초당 그리드 거리 기준. 아이소메트릭 투영 때문에 화면상의 가로/세로 속도는 다르게 보입니다.

## 소스와 에셋 교체

| 파일 | 역할 / 교체 방법 |
| --- | --- |
| `scenes/village.tscn` | 메인 씬, 지형·경로·Y 정렬 오브젝트·카메라·HUD |
| `scripts/village.gd` | 타일 생성, 통행 정보, A*, 클릭 입력. `terrain_atlas`에 192×32 이미지 지정: 왼쪽부터 잔디/길/물 64×32 타일. 투명 다이아몬드 형태 유지 |
| `scenes/player.tscn` | `Sprite2D.texture` 지정 시 기본 도형 숨김. 이미지 발바닥이 루트 원점에 오도록 Sprite2D 위치 조절 |
| `scripts/player.gd` | 이동, 현재 셀, `facing_changed(direction)` 및 `arrived(cell)` 신호. 방향 신호는 그리드 기준이므로 8방향 애니메이션 연결 시 화면 방향으로 투영 |
| `scripts/building.gd` | 기본 입체 도형 건물. 마을의 `building_texture` 또는 개별 건물의 `texture`/`sprite_offset`으로 Sprite2D 이미지 적용 |

기본 지형·건물 이미지는 Godot `Image`로 생성하고 캐릭터는 기본 그리기 API로 표시합니다. 월드 표시에 외부 이미지는 필요하지 않으며, NPC 행동에는 LimboAI 확장을 사용합니다.
타일 투영은 Godot의 [TileSet DIAMOND_DOWN](https://docs.godotengine.org/en/4.3/classes/class_tileset.html)과 `map_to_local`/`local_to_map`을 사용합니다.

## 검증

Godot 실행 파일을 `godot`으로 사용할 수 있는 환경:

```powershell
godot --headless --path . --scene res://tests/baseline_test.tscn
```

`NPC TEST PASS`, `SOLAR TEST PASS`, `DEBUG TEST PASS`, `CLOCK TEST PASS`, `BASELINE TEST PASS` 출력 확인. 셀 좌표 왕복, 기본 1,024개 타일, 8방향, 장애물·대각 모서리, 재지정, 도착, 같은 셀, 도달 불가 목적지를 검사합니다.
렌더링 캡처는 headless 없이 같은 명령 뒤에 `-- --capture`를 추가하면 `tests/morning-preview.png`, `tests/daytime-preview.png`, `tests/afternoon-preview.png`, `tests/night-preview.png`로 저장합니다.

## 지형 두께와 시야 진입 연출

- `Ground`는 타일·통행 데이터와 좌표 변환을 유지합니다. `TerrainReveal`은 지형과 두께 48px의 좌우 흙 면을 표시합니다. 착지한 인접 타일 사이의 내부 면은 생략합니다.
- 지형 탐색 반경 10타일과 사전 등장 여유 2타일은 유지합니다. 이번 확대는 더 먼 지형을 드러내는 변경이 아니라, 타일·캐릭터·건물을 2배로 크게 보여주는 변경입니다. 카메라 줌은 중복 적용하지 않습니다. 시작점 3타일 이내와 뒤쪽은 즉시 표시합니다.
- 새 타일은 진입 시 플레이어 `facing`을 기준으로 앞쪽으로 전파되고 양옆으로 완만하게 퍼집니다. 폭 2타일의 띠가 0.12초 간격으로 출발하며, 320px 위에서 1.8초 동안 부드럽게 내려옵니다. 착지 반동은 없고, 방향을 바꿔도 진행 중인 연출은 재시작하지 않습니다.
- 기본 지형은 투명한 틈 없이 채우고, 모든 타일에 낮은 대비의 1.5px 경계선을 표시합니다. `grid_color`와 `grid_width`로 구분감을 조절할 수 있습니다. 외부 지형 이미지를 지정하면 기존 텍스처·노멀맵 경로를 사용합니다. 이동 속도는 타일/초이므로 같은 설정에서 화면 이동 거리는 직전 버전 대비 2배입니다.
- 이탈 여유 2타일 밖으로 나갔다 돌아오면 다시 재생합니다. 진행 중인 낙하는 중단하거나 중복 예약하지 않습니다. NPC의 기존 9타일 시야와는 별개입니다.
- 건물과 NPC는 받침 타일이 착지한 뒤 표시합니다. 지형 연출은 A* 장애물이나 캐릭터의 논리 좌표를 바꾸지 않습니다.
- 표시 범위의 타일만 한 Node2D에서 그립니다. 타일마다 Node/Tween을 만들지 않으며, 지형을 다시 그리는 비용은 표시 타일 수에 비례합니다. 최대 설정의 웹 성능은 별도 측정 대상입니다.
- 회귀 검사에 `TERRAIN TEST PASS`가 추가되었습니다. 위 검사 명령을 창 모드로 실행하고 `-- --capture-terrain`을 붙이면 `tests/terrain-drop.png`, `tests/terrain-landed.png`를 저장합니다.

## 시간과 조명

- 상단 중앙 핸들바: 현재 Day, 완료된 일수, HH:MM, 시간대 아이콘, 누적 세계 연수, 하루 진행률. UI 위 클릭은 이동 명령으로 전달되지 않습니다.
- Day 1의 00:00부터 시작. 실제 **240초 = 게임 24시간 = 세계 5년**이며, 240초 시점에 Day 2 / 00:00 / +5.00 YEARS가 됩니다. 연수는 하루 중에도 연속 증가합니다.
- 오전 06:00–09:59는 노란 구체, 낮 10:00–17:59는 태양, 그 외 시간은 초승달입니다. 조명은 아이콘과 별도로 새벽·저녁에 부드럽게 전환됩니다.
- `scripts/world_clock.gd`는 `Time.get_ticks_usec()`를 사용합니다. FPS, 프레임 delta, `Engine.time_scale`, OS 시계 수동 변경에 영향을 받지 않습니다. 실행 세션 중에는 포커스를 잃거나 트리가 일시 정지되어도 시간이 진행합니다. 종료 후 오프라인 경과/저장은 이번 범위에 포함하지 않습니다.
- `WorldClock.seconds_per_day`에서 하루 길이를 조절할 수 있습니다(기본 240초). `years_per_day`는 기본 5년입니다. 이는 현재 베이스라인 값이며 `game_plan.md`의 10분/하루와 아직 통합되지 않았습니다.
- `CanvasModulate` + `DirectionalLight2D`로 밤/낮 색상·광량·방향·높이가 변화합니다. HUD는 별도 CanvasLayer로 밝기를 유지합니다.
- 태양은 보이지 않는 단위 구 위에서 `Vector3.slerp`로 이동합니다: 06시 동쪽 → 12시 천정 → 18시 서쪽 → 00시 지평선 아래 → 다음 06시 동쪽. 동쪽은 그리드 +X(화면 우하향), 서쪽은 그 반대입니다. 이는 2D 조명 공간의 구면 궤도이며 위도/계절 천문 모델은 아닙니다.
- 정반대 벡터를 직접 보간하지 않고 천정/지하점을 거치는 네 구간으로 나눠 각속도와 연결을 유지합니다. 조명 방향과 `height`는 같은 구면 벡터에서 계산합니다. 지평선 아래에서는 직사광을 끄고 환경광만 유지합니다.
- Godot의 [조명 셰이더](https://github.com/godotengine/godot/blob/master/drivers/gles3/shaders/canvas.glsl)가 수평 방향과 수직 방향을 혼합·정규화하는 방식에 맞춰 `height = z / (length(xy) + z)`로 변환합니다.
- 기본 건물은 도형을 한 번 래스터화하고 면별 **실제 노멀맵**을 생성해 `CanvasTexture`에 연결합니다. 표면 음영이며, 바닥에 드리우는 투영 그림자/LightOccluder2D는 아직 없습니다.
- 외부 에셋: 마을의 `building_texture` + `building_normal_texture`, `terrain_atlas` + `terrain_normal_atlas`에 같은 크기의 컬러/노멀 이미지를 지정합니다. 플레이어는 기존 Sprite2D의 Texture를 `CanvasTexture`로 설정하고 Diffuse Texture/Normal Texture를 지정하면 같은 조명에 반응합니다.
- 노멀맵은 Godot의 [CanvasTexture 규약(X+, Y+, Z+)](https://docs.godotengine.org/en/4.2/classes/class_canvastexture.html)을 따릅니다.

기존 자동 테스트에서 시간대 경계, 240초/5년 변환, 여러 날 경과, 시스템 타이머 기반 계산, 기본 건물 노멀맵 연결, UI 클릭 차단도 검증합니다.

## 후속 범위

### NPC와 플레이어 시야

- 기본 NPC 12명이 1~3초 휴식 후 통행 가능한 임의의 목적지로 A* 이동합니다. 속도는 초당 1타일 거리(플레이어 3.5)입니다.
- LimboAI `BTPlayer`가 `ai/trees/npc_wander.tres`를 실행합니다. 트리는 `BTSequence(BTRandomWait, ChooseWanderDestination, WalkToDestination)`이며 완료/실패 후 다음 업데이트에 다시 실행됩니다. 대기는 기본 제공 BTRandomWait, 선택/이동은 `ai/tasks/`의 GDScript BTAction입니다. 선택된 목적지는 Blackboard의 `destination`에도 기록됩니다.
- 각 NPC는 독립된 트리 인스턴스와 Blackboard를 가집니다. BTPlayer는 MANUAL 모드이며 `npc.gd`의 물리 프레임에서 한 번만 업데이트합니다. 시야 렌더링과 AI 실행은 분리되어 있습니다.
- `scenes/npc.tscn`의 Sprite2D에 이미지 또는 CanvasTexture를 지정해 외형/노멀맵을 교체할 수 있습니다. 이동은 기존 player.gd를 상속해 재사용하며, NPC에는 선택 링을 표시하지 않습니다.
- Player의 `vision_radius`는 기본 9타일, `vision_fade_width`는 가장자리 1.5타일입니다. 그리드 거리로 계산하므로 화면에서는 아이소메트릭 타원으로 보입니다. `show_vision_range`로 범위 표시를 끌 수 있습니다.
- 안쪽에서는 불투명, 경계에서는 smoothstep으로 투명해지며, 시간 평활화(`NPC.fade_seconds`, 기본 0.35초)로 범위 변경/재진입도 부드럽게 처리합니다. 범위 밖에서는 페이드가 끝난 후 `visible = false`로 렌더링을 끕니다. NPC AI와 이동은 계속 실행됩니다.
- 현재는 거리 기반 시야입니다. 건물에 의한 시야 차단, 지형 안개, NPC 간 충돌/상호작용은 포함하지 않습니다. NPC는 서로 통과할 수 있습니다.
- 자동 테스트는 BT 대기/실행/완료/실패, 경로와 모서리 통행, 반투명 경계, 시야 이탈·재진입, 보이지 않는 NPC의 지속 이동을 검증합니다.

### LimboAI 설치 및 편집

- [공식 v1.8.1 릴리스](https://github.com/limbonaut/limboai/releases/tag/v1.8.1)의 `limboai+v1.8.1.gdextension-4.6.zip`을 `addons/limboai`에 설치했습니다. 패키지의 플랫폼별 바이너리와 라이선스를 유지했습니다.
- 다운로드 ZIP SHA-256: `0910411F8DBC0DA8920F6C8BBBB6397C347CD9F2F193942468A702DFB11D5F0E`.
- GDExtension이므로 별도 Project Settings → Plugins 체크박스는 필요하지 않습니다. 이미 열려 있던 에디터는 프로젝트를 닫았다가 다시 열어 네이티브 확장을 로드하세요.
- FileSystem에서 `ai/trees/npc_wander.tres`를 더블클릭하면 LimboAI 트리 에디터에서 편집할 수 있습니다. NPC 씬의 BTPlayer → Behavior Tree에도 동일 리소스가 연결되어 있습니다.
- 기존 자체 `scripts/behavior_sequence.gd`는 제거했습니다. 이동·렌더링 코드는 유지하며 AI 실행은 LimboAI로 대체했습니다.

블록체인·지갑·거래, 건축 편집, NPC의 경제 시뮬레이션, 건물 상호작용은 이번 베이스라인 범위에 포함하지 않았습니다.
현재 건물은 정적인 단일 셀 점유입니다. 다중 셀 건물을 도입하면 점유 셀 전체를 A*에 반영하고, 이동 중 장애물 변경 시 경로를 재검증해야 합니다.
이동은 정적 그리드 점유로 제어하며 물리 충돌체는 사용하지 않습니다. 동적 캐릭터 간 충돌이 필요하면 해당 기능을 추가합니다.
건물 상호작용은 건물 인접 통행 가능 셀로 이동한 후 `arrived` 신호에 연결할 수 있습니다.
