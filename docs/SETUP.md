# Mindlings — 개발 환경 설치 가이드 (Windows 11)

> 대상: 비전문가도 따라 할 수 있게 하나하나. 환경: Windows 11, ROG Zephyrus, RTX 5060.
> 좋은 소식: 새로 설치할 핵심은 **Godot 하나**다. Git·GitHub CLI는 이미 깔려 있다(아래 2단계서 확인만).
> 최종 수정: 2026-06-13

---

## 0. 한눈에 — 무엇을 왜 깔까

| 프로그램 | 역할 | 상태 |
|---|---|---|
| **Godot 4.6.3** | 게임을 만들고 실행하는 엔진(가장 중요) | ⬜ 새로 설치 |
| **Git** | 코드 변경 기록·백업 | ✅ 이미 설치됨(Code가 사용함) |
| **GitHub CLI (gh)** | GitHub 저장소 연동 | ✅ 이미 설치·로그인됨 |
| **Claude Code** | 실제 코딩을 맡는 AI(시공) | ✅ 이미 사용 중 |
| **VS Code** | 코드 보기/편집(선택, 추천) | ⬜ 선택 설치 |
| GodotSteam / Steamworks | 스팀 출시용 | ⏳ 지금 아님(M8에서) |

> RTX 5060·Windows 11이면 성능은 차고 넘친다. 우리 게임은 2D라 그래픽 부담이 거의 없다.

---

## 1. Godot 설치 (★ 가장 중요)

Godot은 **설치 과정이 없다.** 압축을 풀고 실행 파일을 더블클릭하면 끝(이걸 "포터블"이라 한다).

### 1-1. 다운로드
1. 브라우저로 **https://godotengine.org/download/windows/** 접속.
2. 두 종류가 보인다:
   - **Godot Engine** ← ✅ **이걸 받는다** (우리는 GDScript 언어를 쓴다)
   - Godot Engine **.NET** ← ❌ 받지 않는다 (이건 C#용)
3. "Godot Engine" 쪽 **Download** 클릭 → `Godot_v4.6.3-stable_win64.exe.zip` 같은 zip 파일이 받아진다.

### 1-2. 압축 풀기 & 자리 잡기
1. 다운로드 폴더에서 받은 zip을 **마우스 우클릭 → "압축 풀기"(Extract All)**.
2. 풀린 폴더 안에 `Godot_v4.6.3-stable_win64.exe` 실행 파일이 있다.
3. 이 파일을 한 군데 잘 둔다. 예: `C:\Program Files\Godot\` 폴더를 만들어 그 안에 넣거나,
   그냥 `문서`나 바탕화면 한쪽에 `Godot` 폴더를 만들어 넣어도 된다. (위치는 자유)
4. 실행 파일을 **우클릭 → "시작 화면에 고정" 또는 "작업 표시줄에 고정"** 해두면 다음부터 켜기 편하다.

### 1-3. 처음 실행
1. 그 `.exe`를 더블클릭.
2. (Windows가 "PC를 보호했습니다" 경고를 띄우면) **추가 정보 → 실행** 을 누른다.
   Godot은 공식 오픈소스라 안전하다. — 이 경고는 서명 안 된 프로그램에 다 뜨는 일반 경고다.
3. **Godot 프로젝트 매니저** 창이 열리면 성공. (게임 목록을 관리하는 첫 화면)

> 참고: 첫 실행 때 언어를 한국어로 바꾸려면 매니저 우상단 톱니/설정에서 Language를 바꿀 수 있다(선택).

---

## 2. Git & GitHub CLI 확인 (이미 설치됨 — 확인만)

Claude Code가 이미 이 둘을 써서 저장소를 만들었으니, 새로 깔 필요 없다. **잘 있는지 확인만** 하자.

1. 시작 메뉴에서 **"Windows Terminal"** 또는 **"PowerShell"** 을 연다.
2. 아래를 한 줄씩 입력하고 Enter:
   ```
   git --version
   gh --version
   gh auth status
   ```
3. 기대 결과:
   - `git version 2.x...` 가 나오면 Git OK.
   - `gh version 2.x...` 가 나오면 GitHub CLI OK.
   - `gh auth status` 에 **Logged in to github.com account MoriochoRadio** 비슷한 문구가 나오면 로그인 OK.
4. 혹시 "명령을 찾을 수 없습니다"가 나오면(드묾) 알려줘 — 그때 설치법을 안내할게.

> 이 셋이 정상이면 GitHub 연동은 끝난 상태다. 앞으로 커밋·푸시는 Claude Code가 알아서 한다.

---

## 3. 프로젝트 열어보기 (M0 실행 확인)

우리 게임 파일은 이미 네 노트북의 이 폴더에 있다:
`C:\Users\neo62\Claude\Projects\Steam게임 제작\`

1. Godot 프로젝트 매니저에서 **Import(가져오기)** 버튼 클릭.
2. 위 폴더 안의 **`project.godot`** 파일을 선택 → **Import & Edit**.
3. (4.4→4.6 변환 안내가 뜨면) 안내대로 진행/열기 누름. 안전하다.
4. Godot 에디터가 열리면, 키보드 **F5**(또는 우상단 ▶ 재생 버튼) 누름.
5. **1280×720 빈 창**이 뜨고, 아래 Output 패널에 `Mindlings — M0 부트스트랩 완료...` 가 보이면
   → **M0 성공! 기초 공사 끝.** 🎉

---

## 4. VS Code 설치 (선택 — 하지만 추천)

코드를 더 편하게 보고, Claude Code를 터미널에서 돌리기 좋다. Godot 자체 편집기로도 되지만 있으면 편하다.

1. **https://code.visualstudio.com/** 접속 → **Download for Windows** → 설치 파일 실행.
2. 설치 중 "PATH에 추가", "코드로 열기 메뉴 추가" 옵션은 체크해두면 편하다.
3. (선택) 설치 후 확장(Extensions, 좌측 네모 아이콘)에서 **"godot-tools"** 검색·설치 →
   GDScript 코드에 색·자동완성이 붙는다.

> GitHub Desktop(클릭식 git 도구)도 있지만, 우리는 Claude Code가 git을 처리하므로 **필수 아님.**

---

## 5. (참고) 지금은 안 깔아도 되는 것

- **Steamworks SDK / GodotSteam** — 스팀 출시 단계(M8)에서. 지금 깔면 헷갈리기만 한다.
- **NVIDIA 드라이버** — 게임이 2D라 특별히 손댈 필요 없다. 다만 평소 GeForce/NVIDIA 앱으로
  드라이버를 최신 유지하면 일반적으로 좋다(선택).

---

## 6. 준비 완료 체크리스트

- [ ] Godot 4.6.3 (일반판, .NET 아님) 다운로드·압축 해제·실행 확인
- [ ] 프로젝트 매니저에서 `project.godot` Import 성공
- [ ] F5로 빈 1280×720 창 + 부트스트랩 로그 확인 (= M0 검증)
- [ ] 터미널에서 `git`, `gh`, `gh auth status` 정상 확인
- [ ] (선택) VS Code 설치
- [ ] 막히는 부분은 Cowork(나)에게 질문

이 체크리스트가 다 ✅ 되면, Claude Code에게 **"ROADMAP.md의 M1 구현해줘"** 를 던지면 된다.
그때부터 화면에 첫 생명체와 먹이가 등장한다.
