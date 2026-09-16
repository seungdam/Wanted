# Inspector 테스트 가이드

현재 기본값: **32×32 맵, 시야 반경 9타일, NPC 12명**. 기존 16×16/5타일/6명에서 확장했습니다.
실행 전에는 Local Inspector, 실행 중에는 Scene 패널의 **Remote** 탭에서 노드를 선택하세요. Remote 변경은 실행 종료 후 저장되지 않습니다.

| 노드 | 필드 | 적용 시점 |
| --- | --- | --- |
| Village | `map_size` (최소 16×16, 최대 128×128), `npc_count`, `npc_speed` | 다음 실행 때 생성에 반영 |
| Objects/Player | `speed`, `vision_radius`, `vision_fade_width`, `show_vision_range` | 실시간 |
| Camera2D | `tracking_enabled`, `tracking_speed` (5), `tracking_offset`, 기본 `zoom` | 실시간 |
| WorldClock | `seconds_per_day` (240), `years_per_day` (5), `time_multiplier`, `clock_paused` | 실시간 |
| WorldClock | `preview_enabled`, `preview_day`, `preview_hour` | HUD·조명 미리보기 |
| Objects/NPC_* | `speed`, `ai_enabled`, `ignore_vision`, `fade_seconds` | 실시간 |
| Objects/NPC_* | `override_rest_duration`, `rest_min_seconds`, `rest_max_seconds` | override 활성화 시 다음 대기 진입부터 반영 |

카메라는 시작 시 플레이어에 정렬하고 이후 `1 - exp(-tracking_speed * delta)` 비율로 lerp합니다. 값이 클수록 빠르게 따라갑니다. HUD는 화면에 고정됩니다.

시간 미리보기 중 진행 시간은 정지·보존되며, 미리보기를 끄면 이전 시점부터 재개합니다. 일시 정지 중의 실제 시간을 나중에 더하지 않습니다. 하루 길이를 변경하면 누적 초를 새 길이로 환산합니다. 시간바 설명도 현재 설정을 따릅니다.

NPC의 AI를 꺼도 시야 페이드는 갱신됩니다. `ignore_vision`을 켜면 해당 NPC가 범위 밖에서도 표시됩니다. 개별 NPC 속도는 Remote Inspector에서, 전체 생성 속도는 Village에서 바꿉니다.
