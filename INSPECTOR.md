# Inspector 테스트 가이드

현재 기본값: **192×96px 타일, 캐릭터·건물 2배, 32×32 맵, 지형 시야 10타일(+2타일 사전 등장), NPC 시야 9타일, NPC 12명**. 탐색 반경을 늘리지 않고 화면의 대상을 크게 표시합니다.
실행 전에는 Local Inspector, 실행 중에는 Scene 패널의 **Remote** 탭에서 노드를 선택하세요. Remote 변경은 실행 종료 후 저장되지 않습니다.

| 노드 | 필드 | 적용 시점 |
| --- | --- | --- |
| Village | `map_size` (최소 16×16, 최대 128×128), `npc_count`, `npc_speed` | 다음 실행 때 생성에 반영 |
| TerrainReveal | `reveal_radius` (10), `reveal_margin` (2), `exit_margin` (2) | 실시간, 지형 등장/재진입 범위 |
| TerrainReveal | `thickness` (48), `drop_height` (320), `drop_seconds` (1.8), `wave_delay` (0.12), `wave_band_width` (2), `left_soil`, `right_soil` | 실행 전 설정 권장 |
| TerrainReveal | `grid_color`, `grid_width` (1.5px, 0이면 숨김) | 타일 경계 구분감. 실행 전 설정 권장 |
| Objects/Player | `speed`, `vision_radius`, `vision_fade_width`, `show_vision_range` | 실시간 |
| Camera2D | `tracking_enabled`, `tracking_speed` (5), `tracking_offset`, 기본 `zoom` | 실시간 |
| WorldClock | `seconds_per_day` (240), `years_per_day` (5), `time_multiplier`, `clock_paused` | 실시간 |
| WorldClock | `preview_enabled`, `preview_day`, `preview_hour` | HUD·조명 미리보기 |
| Objects/NPC_* | `speed`, `ai_enabled`, `ignore_vision`, `fade_seconds` | 실시간 |
| Objects/NPC_* | `override_rest_duration`, `rest_min_seconds`, `rest_max_seconds` | override 활성화 시 다음 대기 진입부터 반영 |

카메라는 시작 시 플레이어에 정렬하고 이후 `1 - exp(-tracking_speed * delta)` 비율로 lerp합니다. 값이 클수록 빠르게 따라갑니다. HUD는 화면에 고정됩니다.

시간 미리보기 중 진행 시간은 정지·보존되며, 미리보기를 끄면 이전 시점부터 재개합니다. 일시 정지 중의 실제 시간을 나중에 더하지 않습니다. 하루 길이를 변경하면 누적 초를 새 길이로 환산합니다. 시간바 설명도 현재 설정을 따릅니다.

NPC의 AI를 꺼도 시야 페이드는 갱신됩니다. `ignore_vision`을 켜면 해당 NPC가 범위 밖에서도 표시됩니다. 개별 NPC 속도는 Remote Inspector에서, 전체 생성 속도는 Village에서 바꿉니다.

시야선은 이제 TerrainReveal의 지형 시야 반경을 표시합니다. Player의 `vision_radius`는 NPC 거리 페이드 전용이며 별도로 유지합니다. `ignore_vision`을 켜도 받침 타일이 아직 착지하지 않은 NPC는 숨깁니다.
지형은 진입 시 캐릭터 방향을 기준으로 폭 2타일의 띠가 앞쪽·양옆으로 전파됩니다. 시작점 3타일 안쪽과 뒤쪽은 즉시 착지합니다. 범위 밖 2타일을 더 벗어난 뒤 재진입하면 다시 낙하합니다. 건물은 타일 착지 후 나타나며, 아직 표시되지 않은 타일도 이동·길찾기 데이터에는 존재합니다.
높고 느린 연출은 `drop_height`와 `drop_seconds`를 늘립니다. 잔잔한 파동은 `wave_band_width`를 넓히고 `wave_delay`를 줄입니다. 착지 반동은 제거했습니다.
