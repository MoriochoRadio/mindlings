# Mindlings

**신(神) 시점 인공생명 샌드박스.** NEAT 신경망을 가진 2D 생명체들이 먹고·번식하고·
세대를 거쳐 진화하는 것을 플레이어가 관찰하고 간섭한다. 무료 오픈소스 스택(Godot 4 +
GDScript)으로 만들어 **Steam 출시**를 목표로 한다.

## 기술 스택
- 엔진: **Godot 4.4+** / 언어: **GDScript**
- AI: **NEAT** (GDScript 네이티브)
- 형상관리: Git + GitHub
- Steam: **GodotSteam** (출시 단계에서 통합)

## 실행
1. [Godot 4.4+](https://godotengine.org/download) 설치.
2. 이 저장소를 클론한 뒤 Godot 에디터에서 `project.godot`를 연다.
3. F5로 실행 — 메인 씬은 `scenes/Main.tscn`.

## 디렉토리 구조
```
/             프로젝트 루트 (project.godot)
  docs/       설계 문서
  scenes/     .tscn 씬 파일
  scripts/    .gd 스크립트
  assets/     이미지·사운드·폰트
  addons/     서드파티 플러그인 (NEAT, 추후 GodotSteam)
```

## 문서 (진실의 원천)
- 게임 설계: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)
- 기술 스택: [docs/TECH_STACK.md](docs/TECH_STACK.md)
- 로드맵 & 작업 명세: [docs/ROADMAP.md](docs/ROADMAP.md)

## 라이선스
추후 결정 (무료 오픈소스 원칙).
