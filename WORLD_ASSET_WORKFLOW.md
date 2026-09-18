# World assets v1 — 단계 분리 기록

## Terrain v4 — 길 / 경계 / 수심 확장

- 현재 적용 아틀라스: `assets/world/ready/terrain.png`, `terrain-normal.png`, 각각 **384×512**. 64×32 타일 6열 × 16행 = 96종. 기본 화면 2×2픽셀 표현을 유지한다.
- 열 순서 / 배치 문자: `G` 잔디, `P` 돌길, `W` 물(자동 수심), `R` 일반 흙길, `S` 얕은 물 고정, `D` 깊은 물 고정.
- 행은 경계 비트마스크: grid 왼쪽=1, 위=2, 오른쪽=4, 아래=8. 0은 내부, 15는 네 면 경계. 직선·꺾임·통로·고립 타일을 조합한다. 같은 지형 사이에는 경계를 그리지 않는다.
- `scripts/terrain_tiles.gd`가 준비 도구와 게임의 타일 규격/경계 방향을 공유한다. 각 경계는 원본 픽셀 격자에서 생성되며, 알파는 0/1이고 지형은 23색 팔레트로 제한된다.
- `W`는 육지까지 Manhattan 거리 1이면 얕음, 2이면 중간, 3 이상이면 깊음이다. 맵 바깥은 열린 수역으로 취급한다. 수심 경계는 깊은 쪽에만 표시하고, 해안은 모래/밝은 수면 테두리로 표현한다. 모든 물은 이동 불가다.
- 기존 주도로와 연결길은 `R`, 중앙 광장은 `P`로 배치했다. 남동쪽 기존 수역은 자동 수심으로 얕은 물→중간 물→깊은 물을 보여준다. 물의 외곽 측면에도 수심에 맞는 청색을 적용했다.
- 새 흙길/얕은 물/깊은 물 원본은 built-in imagegen으로 생성한 `assets/world/source/terrain-expansion-v4.png`. 최종 프롬프트는 `assets/world/source/terrain-expansion-v4-prompt.txt`. 생성 결과의 실제 타일 영역 y=384~640을 준비 도구에서 사용한다.
- 재생성: `godot --headless --log-file ./tests/asset-build.log --path . --script res://tools/prepare_world_assets.gd`, 이후 에디터에서 PNG 재가져오기.
- 검증: 96종 픽셀 경계 방향/마름모/팔레트/알파, 인접 지형 자동 선택, 수심 거리 및 S/D 수동 지정, 모든 물 통행 차단, 기존 baseline 전체 통과.
- 실제 적용 화면: `tests/daytime-preview.png`, `tests/shoreline-preview.png`. 기존 타이틀/도입부 배경 누락 오류는 이번 작업과 별개로 남아 있다.

## Pixel v3 — 2026-09-18 적용

- `theme.png`는 색상/컨셉 참고, 첨부 농장 이미지는 픽셀 밀도/경계 참고로만 사용했다.
- built-in imagegen 편집 원본: `assets/world/source/village-atlas-pixel-v3.png`.
- 최종 프롬프트: `assets/world/source/pixel-v3-prompt.txt`.
- 기존 준비 스크립트가 v3 원본을 읽어 ready의 지형/나무/바위/꽃 PNG를 갱신한다. 22색 팔레트, 이진 알파, nearest 샘플링으로 생성본의 잔여 그라데이션/반투명 외곽을 제거한다.
- 지형 64×32, 오브젝트 기존 크기, 기본 2배 표시를 유지한다. 기본 1280×800 / 카메라 zoom 1에서 텍셀은 화면 2×2픽셀이다. 다른 창 크기/줌에서는 화면 픽셀 크기가 달라질 수 있다.
- 낮 ambient `c9c5b5`, 태양 에너지 0.18로 하이라이트 클리핑을 방지한다. 시간 진행/태양 방향 계산은 유지한다.
- 건물과 주민의 기존 코드 기반 픽셀 외형은 유지한다.
- 검증: 준비 단계 마름모/팔레트/알파 검사, baseline 전체 검사 및 낮/밤 실제 렌더 캡처. 최종 확인 화면은 `tests/daytime-preview.png`.
- 에디터 전체 import에는 기존 `assets/ui/arrival_background.png`, `assets/ui/title_background.jpg` 누락 오류가 남아 있다. 마을 씬과 baseline 검사는 통과한다.

아래는 이전 v1 단계 기록이다.

## 재검토 결론

- 첫 번째 첨부는 미술 참고다. 체크무늬가 실제 RGB 픽셀에 포함된 설명 이미지이므로 그대로 타일로 잘라 쓰지 않는다.
- Free ver.png는 기본 타일 32×16의 2:1 투영을 확인하기 위한 규격 참고다. 실제 게임 아트로 복제하지 않았다.
- 현재 월드의 64×32 논리 타일 / 128×64 표시 크기를 유지한다. 높이가 있는 오브젝트의 전체 이미지를 2:1로 압축하지 않는다.
- 원본 두 파일은 수정하지 않았다. 기존 캐릭터·건물·시간·주민 합류 로직도 이번 아트 작업 범위에서 재설계하지 않았다.

## A. 에셋 준비 — 게임 적용과 독립

산출물:
- `assets/world/source/village-atlas-v1.png`: built-in imagegen 생성 원본, 1536×1024. 원본 이미지의 직접 편집본이 아니라 관찰한 스타일/규격을 서술해 생성한 후보.
- `assets/world/source/generation-prompt.txt`: 선택한 생성본의 최종 프롬프트.
- `tools/prepare_world_assets.gd`: 영역 분리·nearest 정수 크기 변환·알파 정리·마름모 정규화와 검사.
- `assets/world/ready/terrain.png`: 192×32, 왼쪽부터 잔디/돌길/물 각 64×32.
- `assets/world/ready/terrain-normal.png`: 동일 크기, 바닥 평면용 normal. 세부 돌출을 표현하는 수작업 normal map이 아니다.
- `assets/world/ready/tree.png`: 64×72, 바닥 기준점 (32,68).
- `assets/world/ready/rocks.png`: 48×33, 바닥 기준점 (24,30).
- `assets/world/ready/flowers.png`: 40×24, 바닥 기준점 (20,22).

검증:
- 정확한 2:1 마름모 안쪽은 불투명, 바깥쪽은 투명.
- 생성본의 흐릿한 알파를 제거한 실행용 cutout을 흰 바탕에서도 시각 확인.
- 지형 내부에 흙 측면을 굽지 않음. 외곽/낙하 측면은 기존 렌더러가 담당.
- 생성본은 규격 완성품으로 간주하지 않음. 정규화 후 파일만 적용 단계로 전달.
- 재생성 없이 준비 단계를 재실행할 수 있음. 생성 이미지에는 반복 무늬가 남으므로 최종 아트에서는 타일 변형본을 추가할 수 있다.

실행:
```powershell
& 'C:\Godot\godot_stable_win64.exe' --headless --path . --script res://tools/prepare_world_assets.gd
```

이 명령은 ready 폴더의 파생 PNG를 갱신하지만 씬이나 배치 데이터는 수정하지 않는다.
생성 원본에는 번짐/불정확한 경계가 있으므로 그대로 직접 참조하지 않는다.

## B. Godot 적용 — 검증된 파일만 소비

- `scenes/village.tscn`의 terrain_atlas/terrain_normal_atlas에 실행용 PNG 연결.
- `data/village_layout.json`은 에셋과 독립된 배치 파일.
- terrain_rows의 G=잔디, P=돌길, W=물. 각 행은 grid y, 문자열 인덱스는 grid x.
- 중앙 4×4 광장, 기존 두 칸 폭 주도로, 네 건물 입구 연결길, 남동쪽 수변을 구성.
- props의 kind/cell로 나무 8개, 바위 2개, 꽃 6개를 배치.
- 나무/바위의 밑동 셀만 A* 장애물. 꽃은 걸어갈 수 있다.
- 셀 중심과 명시한 바닥 기준점으로 배치. Objects의 Y-sort, 기존 가림 반투명 및 타일 착지 후 표시를 재사용.
- 건물 스프라이트는 기존 임시 외형 유지. 장식에 별도 입체 normal map을 만들지는 않았다.
- 기본 16×16 밖으로 맵을 확장하면 추가 셀은 잔디이며, 배치 파일도 별도로 확장해야 한다.
- 배포 시 JSON 배치 파일이 export에 포함되는지 별도 확인해야 한다.

## 검증 절차

1. Stage A 검사 통과 후에만 씬 연결 및 배치 작업 시작.
2. `godot --headless --path . res://tests/baseline_test.tscn`
3. `godot --path . res://tests/baseline_test.tscn -- --capture`
4. `powershell -File tests/mcp_drop_check.ps1`

검증 항목: 실제 아틀라스 연결, Sprite의 그리드 기준점, 꽃/나무/바위 통행, 모든 건물 입구 접근,
기존 8방향 이동·카메라·주민 합류·가림·태양 조명·가장자리 6개 이하 낙하.

화면 결과: `tests/daytime-preview.png`, `tests/day4-preview.png`, `tests/viewport-whole-world-preview.png`.

## 현재 범위와 남은 아트

이번 단계는 월드 아트 배치 baseline이다. 레퍼런스의 전체 에셋 팩을 완성했다는 의미가 아니다.
게시판, 가로등, 울타리, 농작물, 선착장, 전용 건물 아트와 연결형 지형 코너/변형 타일은 별도 제작 대상이다.
에셋 준비와 적용의 파일 경계를 유지하여 후속 아트 교체가 게임 로직 수정으로 이어지지 않게 한다.
