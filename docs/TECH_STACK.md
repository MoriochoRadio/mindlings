# Mindlings — 기술 스택 (Tech Stack)

> 원칙: **무료·오픈소스 우선, 1인 개발 친화.** (개인 프로젝트 — 상업 출시·배포 계획 없음)
> 최종 수정: 2026-07-02 (개인 프로젝트 전환: 스팀 출시 관련 내용 제거)

---

## 1. 게임 엔진 — Godot 4 (GDScript)

- **무료·오픈소스 (MIT 라이선스).** 로열티·구독 전혀 없음.
- 2D 다수 에이전트 시뮬레이션에 가볍고 강함.
- 한 파일 단위 노드/씬 구조라 1인 개발에 적합.
- 권장 버전: **Godot 4.4 이상**. 최신 안정판 사용(현재 4.6대).
- 언어: **GDScript** 기본. 성능 병목 시 일부를 **C#** 또는 GDExtension(C++)로 이전 가능.

> 대안 비교: Unity는 1인 취미 개발엔 과하고 라이선스가 복잡. → Godot이 가장 가볍고 깔끔.

---

## 2. AI / 신경망 — NEAT (GDScript 네이티브)

외부 바이너리 의존 없이 GDScript로 돌릴 수 있는 라이브러리가 이미 존재:

- **Godot-AI-Kit** — GDScript 네이티브 AI 알고리즘 모음(NEAT, DQN, QTable 등).
  https://github.com/ryash072007/Godot-AI-Kit
- **neat4godot** — Godot용 NEAT 구현.
  https://github.com/Skynse/neat4godot
- **NEAT_GDScript** — 두 클래스만 상속하면 NEAT 신경망+유전 알고리즘 자동 구성.
  Godot Asset Library asset #987

> 전략: 위 라이브러리 중 하나를 **참고/시작점**으로 채택하되, 핵심 NEAT 로직은
> 우리 시뮬레이션에 맞게 직접 이해·수정할 수 있도록 얇게 감싼다. 작은 MLP 수준이라
> 최악의 경우 직접 구현도 현실적. (Claude Code가 초기 구현/이식 담당)

---

## 3. 버전 관리 — Git + GitHub

- 형상관리: 사용자의 GitHub 레포 (https://github.com/MoriochoRadio).
- `.gitignore`: Godot 임포트 캐시(`.godot/`), 빌드 산출물, OS 파일 제외.
- 커밋 단위: 기능/마일스톤 단위로 작게. Claude Code가 작업 후 의미 있는 커밋 메시지 작성.
- 브랜치: `main`(안정) + 기능 브랜치(`feature/...`) 권장. 1인이라 가볍게 운영.
- **Git LFS**: 큰 바이너리 에셋(오디오/이미지)이 늘면 도입 검토.

---

## 4. 배포 — (개인 프로젝트, 보류)

> **2026-07 개인 프로젝트 전환: 스팀 출시·상업 배포 계획을 제거했다.** 예전엔 GodotSteam 연동과
> 스팀 스토어 출시($100 Direct fee 등)를 계획했으나, 이제 그런 목표는 없다.
> 필요하면 Godot의 Windows 익스포트로 실행 파일을 만들어 개인적으로 나눠 보는 정도.
> 코드는 GitHub 공개로 둔다. (나중에 마음이 바뀌면 GodotSteam은 https://godotsteam.com 참고)

---

## 5. 에셋 (무료 사용 가능)

미니멀 비주얼이라 에셋 부담이 적지만, 필요 시:

- **그래픽/도형**: Godot 내장 도형·셰이더로 대부분 해결. 추가 필요 시 Kenney.nl(CC0).
- **사운드/음악**: freesound.org(라이선스 확인), Kenney 오디오(CC0),
  incompetech(크레딧 조건). 라이선스는 쓰기 전 점검.
- **폰트**: Google Fonts(오픈 라이선스).
- ⚠️ 라이선스 추적: `docs/ASSET_CREDITS.md`에 출처·라이선스를 기록(후속 생성).

---

## 6. 개발 환경 / 도구

- **에디터**: Godot 에디터 + (코드 편집) VS Code 또는 사용자 선호 IDE.
- **AI 에이전트**: Claude Code(시공) + Cowork(설계·리뷰).
- **OS**: Windows 우선 빌드. Godot은 Linux/Mac 크로스 익스포트 지원 → 후속.
- **CI(후속)**: GitHub Actions로 자동 빌드/익스포트 검토 가능(필수 아님).

---

## 7. 비용 요약

| 항목 | 비용 |
|---|---|
| Godot 엔진 | 무료 |
| NEAT 라이브러리 | 무료 |
| Git / GitHub | 무료 |
| 무료 에셋(CC0 등) | 무료 |

→ 개인 프로젝트라 **현금 비용 0**. (상업 출시 계획을 제거해 스팀 $100도 해당 없음)

---

## 8. 다음 문서
- 게임 기획: [GAME_DESIGN.md](./GAME_DESIGN.md)
- 개발 로드맵 & 작업 명세: [ROADMAP.md](./ROADMAP.md)
