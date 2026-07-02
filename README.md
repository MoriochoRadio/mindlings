# Mindlings

**신(神) 시점 인공생명 샌드박스.** NEAT 신경망을 가진 2D **'작은 사람들'**이 먹고·마시고·
번식하며 살아가는 것을, 신이 되어 관찰하고 돌보는 게임. 소수(~10)의 캐릭터를 가까이서
지켜보며 위기(가뭄·한파)에서 구하고 그들의 이야기를 본다.

> **개인 프로젝트**입니다. 혼자 만드는 취미·실험이며, 상업 출시·배포 계획은 없습니다.
> 코드는 자유롭게 구경하셔도 좋습니다.

## 기술 스택
- 엔진: **Godot 4.4+** / 언어: **GDScript**
- AI: **NEAT** (GDScript 네이티브)
- 형상관리: Git + GitHub

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
  addons/     서드파티 플러그인 (NEAT)
```

## 문서 (진실의 원천)
- 게임 설계: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)
- 기술 스택: [docs/TECH_STACK.md](docs/TECH_STACK.md)
- 로드맵 & 작업 명세: [docs/ROADMAP.md](docs/ROADMAP.md)

## 라이선스
개인 프로젝트 — 별도 라이선스 미지정. 학습·참고용으로 자유롭게 봐 주세요.
