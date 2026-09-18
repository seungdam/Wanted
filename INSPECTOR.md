# Inspector 테스트 가이드

현재 기본값: **16×16 맵, 화면상 128×64px 타일(64×32 원본의 정수 2배), 캐릭터·건물 2배, 생활 주민 최대 4명**.
거리 기반 시야와 NPC 페이드는 제거했습니다. 지형 Drop Animation은 플레이어 반경이 아닌 **실제 카메라 Viewport 진입** 기준으로 유지합니다. 내부 Grid와 A*는 유지합니다.

실행 전에는 Local Inspector, 실행 중에는 Scene 패널의 **Remote** 탭에서 노드를 선택하세요.
Remote 변경은 실행 종료 후 저장되지 않습니다.

| 노드 | 필드 | 적용 시점 |
| --- | --- | --- |
| Village | `map_size` (최소 16×16), `npc_count` (1~4), `npc_speed` | 다음 실행 |
| Village | `resident_join_days` (기본 [1, 2, 3, 4]) | 다음 실행. 주민별 합류일, 1~5일로 제한 |
| TerrainReveal | `drop_enabled` (true) | 실시간. 끄면 모든 지형 즉시 착지 |
| TerrainReveal | `edge_band_pixels` (80), `animated_fraction` (0.3), `max_active_drops` (6) | 화면 가장자리 폭·좌표 기반 대상 비율·동시 낙하 상한. 비대상/상한 초과 타일은 대기 없이 즉시 표시 |
| TerrainReveal | `screen_margin` (32), `exit_margin` (128) | 화면 픽셀 단위. 진입 여유와 재낙하를 위한 이탈 여유 |
| TerrainReveal | `drop_height` (32), `drop_seconds` (0.6) | 낙하 높이·시간. 높이는 로컬 단위이며 기본 배율 2에서 화면상 64px |
| TerrainReveal | `edge_sweep_seconds` (0.22), `tile_stagger_seconds` (0.08) | 화면 가장자리를 따른 연속 지연 + 타일 좌표별 고정 시간차. 기본 시작 지연은 합계 0.3초 이내 |
| TerrainReveal | `thickness` (12), `grid_width` (0) | 타일 흙 측면 두께와 격자선. 로컬 단위 |
| Village | `terrain_atlas`, `terrain_normal_atlas`, `building_texture`, `building_normal_texture` | 다음 실행. 바닥은 64×32 타일 3개를 가로로 배치 |
| Objects/Player | `speed` | 실시간 |
| Objects/Player/Sprite2D | `texture`, `position` | 최종 스프라이트 교체. nearest 필터 유지 |
| Objects/Building_* | `occluded_alpha` (0.35), `fade_speed` (8) | 실시간. 플레이어 뒤쪽 겹침에만 적용 |
| Objects/Building_* | `texture`, `normal_texture`, `sprite_offset` | 다음 실행. 실제 이미지의 투명 영역을 고려하여 가림 판정 |
| Camera2D | `tracking_enabled`, `tracking_speed` (5), `tracking_offset`, `zoom` | 실시간 |
| WorldClock | `seconds_per_day` (240), `time_multiplier`, `clock_paused` | 실시간 |
| WorldClock | `preview_enabled`, `preview_day`, `preview_hour` | 날짜별 주민·HUD·조명 미리보기 |
| Objects/NPC_* | `join_day`, `speed`, `ai_enabled` | 실시간. 미합류 주민은 렌더링·AI 정지 |
| Objects/NPC_* | `override_rest_duration`, `rest_min_seconds`, `rest_max_seconds` | 다음 대기 진입부터 반영 |

## 빠른 확인

1. WorldClock의 preview를 켜고 Day 1→2→3→4→5로 바꾸면 주민 수가 1→2→3→4→4가 됩니다.
2. Day 1로 되돌리면 미합류 주민은 다시 숨겨집니다. 객체는 중복 생성되지 않습니다.
3. 건물 뒤의 열린 타일로 이동하면 건물이 서서히 반투명해지고, 앞으로 나오면 복원됩니다.
4. 합류 주민에는 거리 시야 제한이 없습니다. 지형은 카메라 이동으로 새로 화면에 들어올 때 낙하합니다.
5. preview_hour를 6→12→18로 바꾸면 기존 동→서 조명과 건물 normal map 음영이 유지됩니다.

시간 미리보기 중 진행 시간은 보존됩니다. preview 종료 시 원래 날짜로 돌아오므로 주민 표시도 그 날짜를 따릅니다.
카메라는 프레임률 독립 lerp를 유지합니다. UI는 월드 조명에 영향을 받지 않습니다.

## 구현 범위

캐릭터는 컨셉의 둥근 동물·앞치마·크림/갈색/초록 팔레트를 따른 코드 생성 픽셀 임시 에셋입니다.
주민은 앞치마 색으로 구분하며, 최종 개별 캐릭터 디자인과 8방향 애니메이션 시트는 별도 제작 대상입니다.
건물은 normal map이 포함된 픽셀 임시 에셋이며 실제 서비스 기능은 아직 없습니다.
기존 years_per_day 계산은 호환성을 위해 남겼지만 HUD는 연도 압축을 노출하지 않습니다.
이번 변경은 주민 합류까지이며, Day 5 종료·회고 화면은 아직 구현하지 않았습니다.
처음 보이는 지형은 착지 상태로 시작합니다. 이후 카메라 이동·창 크기·줌 변화로 들어오는 타일에 낙하가 적용됩니다.
낙하는 화면 경계에서 80px 이내인 타일 중 좌표로 선택한 약 30%에만 적용하고, 대기 중인 타일까지 포함해 동시에 최대 6개로 제한합니다.
나머지 타일과 화면 내부 타일은 즉시 표시됩니다. 카메라 이동으로 낙하 타일이 가장자리 띠를 벗어나면 바로 착지합니다.
넓은 2타일 띠와 0.4초 지연 상한으로 묶던 방식은 제거했습니다. 실제 화면 진입 시점에 가장자리 위치와 타일 좌표로 시작 시각을 정하며, 대기열을 누적하지 않습니다.
같은 화면 위치/타일에는 같은 시간차가 적용됩니다. 플레이어의 방향 변경은 예약된 낙하에 영향을 주지 않습니다.
타일이 화면 밖 이탈 여유까지 벗어난 뒤 다시 들어오면 재낙하하며, 진행 중인 낙하는 카메라 방향 변경으로 재시작하지 않습니다.
월드 전체가 Viewport에 들어오는 줌/화면 크기에서는 모든 타일을 바로 착지시킵니다.
플레이어와 합류 주민의 발밑 타일은 즉시 착지시켜 공중에 서는 현상을 방지합니다. 건물은 지지 타일 착지 후 표시됩니다.
이 기능은 시각 연출이며 길찾기·NPC AI·주민 합류 일정을 제한하지 않습니다.

## 검증

`godot --headless --path . res://tests/baseline_test.tscn`

실제 렌더러의 화면 캡처:
`godot --path . res://tests/baseline_test.tscn -- --capture`

날짜 합류/역행/4명 상한, LimboAI 이동, 시야 제거, 건물 가림/복원, A* 모서리 충돌,
마우스 입력, HUD 클릭 차단, 시간·조명·카메라를 검증합니다.

Viewport 낙하 테스트는 화면 진입/재진입, 낙하 중 재시작 방지, 단조 하강, 전체 월드 표시 시 생략, 타일 배율과 길찾기 보존을 검사합니다.

Windows에서 설치된 Godot MCP Runtime을 직접 사용하는 검증:
`powershell -File tests/mcp_drop_check.ps1`

다른 게임이 포트 7777을 사용 중이면 먼저 종료하세요. 테스트는 자체 게임 인스턴스를 실행하고,
로컬 런타임의 씬 조회·카메라 속성 변경·메서드 호출·스크린샷·성능 지표를 확인한 뒤 해당 인스턴스만 종료합니다.
캡처: `tests/viewport-drop-preview.png`, `tests/viewport-landed-preview.png`, `tests/viewport-whole-world-preview.png`.
