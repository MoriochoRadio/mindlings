# Mindlings — 기술 스택 (Tech Stack)

> 원칙: **무료·오픈소스 우선, 1인 개발 친화, Steam 출시 깔끔.**
> 최종 수정: 2026-06-13

---

## 1. 게임 엔진 — Godot 4 (GDScript)

- **무료·오픈소스 (MIT 라이선스).** 로열티·구독 전혀 없음.
- 2D 다수 에이전트 시뮬레이션에 가볍고 강함.
- 한 파일 단위 노드/씬 구조라 1인 개발에 적합.
- 권장 버전: **Godot 4.4 이상** (GodotSteam GDExtension 호환 기준). 최신 안정판 사용.
- 언어: **GDScript** 기본. 성능 병목 시 일부를 **C#** 또는 GDExtension(C++)로 이전 가능.

> 대안 비교: Unity는 1인 첫 출시엔 과하고 라이선스가 복잡. 순수 웹(JS)은
> 가능하나 Steam 패키징(Electron 등)이 지저분. → Godot이 가장 깔끔.

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

## 4. Steam 출시 — GodotSteam

- **GodotSteam (GDExtension)** — Godot용 Steamworks 연동 플러그인. 무료.
  - 최신: GodotSteam 4.19.1 / Steamworks SDK 1.64 (Godot 4.4+ 대응, 4.5·4.6도 지원).
  - 사이트/문서: https://godotsteam.com
  - 저장소: https://codeberg.org/godotsteam/godotsteam
- 제공 기능: 실적(achievements), 클라우드 세이브, 통계, 친구/오버레이 등.
- **MVP 단계엔 불필요** — 게임이 동작한 뒤 출시 준비 단계에서 통합.

### Steam 출시 비용·절차 (정확)
- **Steam Direct fee: 게임당 $100 (USD).** 매출 $1,000(조정 총매출) 도달 시 환급.
  월 구독료·플랫폼 정기료 없음. 무료게임도 $100은 동일.
- 절차 요약: Steamworks 가입 → 세금/지급 정보 등록 → $100 결제 → 앱 생성 →
  스토어 페이지 작성(스크린샷/트레일러/설명) → 빌드 업로드 → 콘텐츠 검수 →
  출시일 설정. (스토어 페이지 공개 후 최소 대기 기간 등 정책은 출시 임박 시 재확인)

---

## 5. 에셋 (무료·상업 사용 가능)

미니멀 비주얼이라 에셋 부담이 적지만, 필요 시:

- **그래픽/도형**: Godot 내장 도형·셰이더로 대부분 해결. 추가 필요 시 Kenney.nl(CC0).
- **사운드/음악**: freesound.org(라이선스 확인), Kenney 오디오(CC0),
  incompetech(크레딧 조건). 라이선스는 반드시 출시 전 점검.
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
| GodotSteam, NEAT 라이브러리 | 무료 |
| Git / GitHub | 무료 |
| 무료 에셋(CC0 등) | 무료 |
| **Steam Direct fee** | **$100 (환급 가능)** |
| (선택) 도메인·홍보 | 변동 |

→ 실질 필수 현금 비용은 **출시 시점의 $100** 한 번뿐.

---

## 8. 다음 문서
- 게임 기획: [GAME_DESIGN.md](./GAME_DESIGN.md)
- 개발 로드맵 & 작업 명세: [ROADMAP.md](./ROADMAP.md)
