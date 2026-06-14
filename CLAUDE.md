# CLAUDE.md — Mindlings 프로젝트 컨텍스트

> 이 파일은 Claude Code가 매 세션 자동으로 읽는다. 작업 전 반드시 `docs/`의
> 설계 문서를 함께 참고할 것.

## 프로젝트 한 줄 요약
**Mindlings** (작업 제목) — 신(神) 시점 인공생명 샌드박스. NEAT 신경망을 가진 2D
**'작은 사람들'(인간형)**이 먹고·번식하고·학습하고·세대를 거쳐 진화하며 **사회를 이뤄가는**
것을 플레이어가 관찰하고 간섭한다. (인간형은 *출발 표현*이지 진화 결승점이 아님 —
GAME_DESIGN '게임 정체성' 참고.) 목표: 무료 오픈소스 스택으로 만들어 **Steam에 출시**.

## 진실의 원천 (먼저 읽을 것)
- 게임 설계: `docs/GAME_DESIGN.md`
- 기술 스택: `docs/TECH_STACK.md`
- 로드맵 & 작업 명세: `docs/ROADMAP.md`  ← 작업 지시는 보통 "M2 구현" 식으로 들어온다
- 시장 분석 & 차별화 전략: `docs/MARKET_ANALYSIS.md`  ← 기능 결정 시 "차별화 4기둥(8장)을 강화하나?"로 판단
- 가독성 & UX 설계: `docs/LEGIBILITY_UX.md`  ← 뇌 시각화·온보딩·"이해되는 AI"를 만들 때 기준
- 재미 설계: `docs/FUN_DESIGN.md`  ← "기본 루프가 재밌나?"의 기준. M4(권능)·M7(목표)·확장 Acts 설계 시 참고
- 깊이·콘텐츠 로드맵: `docs/DEPTH_ROADMAP.md`  ← "밋밋함" 해소 우선순위(보이는 형질 진화·먹이사슬·가독성). 레퍼런스 기준선

## 기술 스택 (요약)
- 엔진: **Godot 4.4+** / 언어: **GDScript**(성능 병목 시 C# 검토)
- AI: **NEAT** (GDScript 네이티브 라이브러리; Godot-AI-Kit 또는 NEAT_GDScript 평가 후 채택)
- 형상관리: Git + GitHub (github.com/MoriochoRadio)
- Steam: **GodotSteam** (출시 단계 M8에서 통합)

## 디렉토리 구조 (목표)
```
/                 프로젝트 루트 (project.godot)
  CLAUDE.md       이 파일
  README.md
  docs/           설계 문서 (GAME_DESIGN/TECH_STACK/ROADMAP)
  scenes/         .tscn 씬 파일
  scripts/        .gd 스크립트
  assets/         이미지·사운드·폰트 (라이선스는 docs/ASSET_CREDITS.md)
  addons/         서드파티 플러그인 (NEAT 라이브러리, 추후 GodotSteam)
```

## 코드 컨벤션
- GDScript 공식 스타일 가이드 준수(snake_case 변수/함수, PascalCase 클래스/노드).
- 노드 1개 = 책임 1개. 시뮬레이션 로직과 렌더링/UI를 분리.
- 튜닝 파라미터(먹이량·돌연변이율·에너지 등)는 `@export`로 노출해 에디터에서 조절 가능하게.
- 성능 민감: 매 프레임 도는 코드에서 불필요한 할당·노드 탐색 피하기. 고정 timestep 고려.
- 주석·커밋 메시지는 한국어 가능. 커밋은 기능/마일스톤 단위로 작게.

## 작업 방식
- 각 마일스톤은 **실행 가능한 결과물**로 끝낸다. 끝나면 실행 확인 후 커밋.
- 설계가 모호하거나 큰 결정이 필요하면 임의로 정하지 말고, 선택지를 정리해 사용자(또는
  Cowork 리뷰)에게 확인을 요청한다.
- 범위가 커지려 하면 `docs/GAME_DESIGN.md`의 MVP 한계선(5장)을 기준으로 자른다.

## 빌드 / 실행
- Godot 에디터에서 프로젝트 열고 F5로 실행 (메인 씬: `scenes/Main.tscn`).
- 익스포트(Windows)는 M8에서 정리.

## 하지 말 것
- MVP 범위 밖 기능을 미리 구현하지 말 것(멀티 종/3D/멀티플레이 등은 후속).
- 유료·폐쇄 라이선스 의존성 추가 금지(무료 오픈소스 원칙).
- 에셋 추가 시 라이선스 미확인 상태로 커밋 금지.
