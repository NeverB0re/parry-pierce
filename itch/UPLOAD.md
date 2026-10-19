# itch.io 업로드 방법 (Parry Pierce v0.102)

이 폴더(`itch/`)에는 itch.io 에 올리는 데 필요한 것이 모두 들어 있습니다.

| 파일 | 용도 |
|---|---|
| `build/windows/` | **업로드할 게임 폴더** — `ParryPierce.exe` + `README.txt` (butler 로 올릴 때 이 폴더를 통째로) |
| `ParryPierce-v0.102-windows.zip` | 같은 내용의 **zip** (웹 대시보드에서 직접 올릴 때) |
| `build/web/`, `ParryPierce-v0.102-web.zip` | **브라우저 실행판** (HTML5) — `index.html` 이 zip 맨 위에 있다 |
| `cover.png` | 표지 이미지 (게임 커버 그림, 1408×1117 — itch 권장 630×500 과 같은 비율이라 그대로 올리면 된다) |
| `screenshots/01~08_*.png` | 스크린샷 8장 (1280×720, 영어 화면: 메인 화면, 보스 넷, 항로도, 동력 코어) |
| `DEVLOG_v0.102.md` | 개발 로그 글 (영어 + 한국어, 이미지 넣을 자리 표시) |
| `STORE_PAGE.md` | 페이지에 붙여 넣을 소개문 (영어 + 한국어), 태그, 설정 값 |

`exe`/`zip` 은 용량이 커서 git 에는 올리지 않습니다 (`.gitignore`). 새 버전을 만들면 아래 "새 버전 만들기"로 다시 만드세요.

---

## 방법 A — 웹 대시보드 (가장 쉬움, 처음 한 번)

1. itch.io 로그인 → 우상단 계정 메뉴 → **Upload new project** (https://itch.io/game/new).
2. **Title** `Parry Pierce` · **Project URL** 원하는 주소 (예: `parry-pierce`).
3. **Kind of project**: `Downloadable` (실행 파일). *Classification*: `Games`.
4. **Release status**: `In development` (또는 `Prototype`).
5. **Pricing**: `$0 or donate`(무료+후원) 권장, 또는 `No payments`.
6. **Uploads** → *Upload files* 에서 `ParryPierce-v0.102-windows.zip` 선택 → 올라간 파일 옆 체크박스 **Windows** 선택.
7. **Description** 에 `STORE_PAGE.md` 의 소개문을 붙여 넣는다.
8. **Cover image** `cover.png`, **Screenshots** 에 `screenshots/` 의 PNG 8장.
9. **Genre** `Action`, **Tags** 는 `STORE_PAGE.md` 참고, **Languages** 에 `English`, `Korean`.
10. **Visibility & access** 를 처음엔 **Draft**(비공개)로 두고 *Save* → 미리보기로 확인 → 문제 없으면 **Public** 으로 바꾸고 저장.

## 이미 올린 페이지 업데이트 (→ v0.102)

1. 대시보드 *Edit game* → **Uploads** 에서 예전 `ParryPierce-v0.xx-windows.zip`·`-web.zip` 을 지우고(또는 *Replace*) `ParryPierce-v0.102-windows.zip`·`ParryPierce-v0.102-web.zip` 을 올린 뒤 **Windows** 체크. (butler 를 쓰면 아래 방법 B 한 줄)
   웹 zip 은 **This file will be played in the browser** 체크.
2. **Description** 을 `STORE_PAGE.md` 의 새 소개문(보스 설명·마우스 전용 조작·글꼴 출처가 바뀜)으로 통째로 바꾼다.
3. **Cover image** 를 새 `cover.png` 로, **Screenshots** 를 지우고 새 8장으로 교체.
4. 저장 후 *Devlog* → *Create new post* 에 `DEVLOG_v0.102.md` 를 붙여 넣는다 (`[이미지: ...]` 줄 자리에 그 스크린샷을 넣는다). 팔로워에게 알림이 간다.

## 브라우저에서 바로 실행 (웹판 추가)

Windows 다운로드는 그대로 두고, 같은 페이지에 웹판을 하나 더 올린다.

1. *Edit game* → **Kind of project** 를 `HTML` 로 바꾼다 (다운로드 파일은 그대로 남는다).
2. **Uploads** → `ParryPierce-v0.102-web.zip` 올리기 → 그 파일에 **This file will be played in the browser** 체크.
   (Windows zip 은 체크하지 않고 **Windows** 표시만 그대로.)
3. **Embed options**
   - *Viewport dimensions*: `1280 × 720`
   - *Fullscreen button* 켜기 · *Automatically start on page load* 끄기 (첫 클릭이 소리 재생 허용도 겸한다)
   - *SharedArrayBuffer support* 는 **끈다** (스레드 없는 빌드라 필요 없음)
   - *Mobile friendly* 끄기 (마우스 필수)
4. 저장 → 페이지에서 *Run game* 으로 확인. 진행·설정은 브라우저 저장소에 남는다 (사이트 데이터를 지우면 처음부터).

butler 로는 `butler push itch/build/web <사용자명>/<프로젝트주소>:html5 --userversion 0.102` 후 대시보드에서 그 업로드에 *played in the browser* 체크.

**웹판에서 달라지는 점**: 종료 버튼이 없다 · 마우스를 창 안에 가두지 못한다 (조준은 화면 안에서) · 글꼴은 데스크톱과 같은 갈무리11 · 처음 로딩이 수십 MB.

## 방법 B — butler (CLI, 업데이트에 편함 — 이후 버전은 이쪽 권장)

butler 는 바뀐 부분만 올려 줍니다. 한 번만 설치·로그인하면 됩니다.

```bash
# 1) 설치: https://itchio.itch.io/butler 에서 받아 PATH 에 두거나, 압축 푼 폴더에서 실행
# 2) 로그인 (브라우저가 열린다)
butler login

# 3) 업로드: 폴더째 (권장, 다음 버전부터는 변경분만 전송된다)
butler push itch/build/windows  <itch사용자명>/<프로젝트주소>:windows --userversion 0.102

# 예) butler push itch/build/windows neverb0re/parry-pierce:windows --userversion 0.102
```

- 채널 이름 `windows` 는 itch 가 플랫폼(Windows)으로 자동 인식합니다.
- 처음 `push` 할 때 프로젝트가 아직 없으면 오류가 나니, 방법 A 의 1~9 단계로 **프로젝트 페이지부터 만들고** 그 주소를 쓰세요.
- 올린 뒤 상태 확인: `butler status <사용자명>/<프로젝트주소>`.

## 새 버전 만들기 (개발자용)

```bash
# 빌드 (실행 중인 ParryPierce 먼저 종료)
"<Godot 콘솔 exe>" --headless --path . --export-release "Windows Desktop" ParryPierce.exe
# itch 폴더 갱신 + zip
"<Godot 콘솔 exe>" --headless --path . --export-release "Web" itch/build/web/index.html
python itch/pack.py 0.63          # build/windows 와 Windows·웹 zip 을 다시 만든다
# 올리기
butler push itch/build/windows <사용자명>/<프로젝트주소>:windows --userversion 0.63
```

## 올리기 전에 확인할 것

- **라이선스 표기**: 도트 그림(기체·화염·폭발)은 Ravenmore "Space Rage" — CC-BY 3.0 이라 **출처 표기가 필요**합니다. 게임 메인 화면 아래, `README.txt`, 소개문(`STORE_PAGE.md`)에 이미 넣어 두었습니다. 올리기 전에 원본 배포 페이지(OpenGameArt)의 라이선스를 한 번 더 확인하세요(`art/CREDITS.md`).
- **서명 없는 exe**: Windows SmartScreen 이 "알 수 없는 게시자" 경고를 띄울 수 있습니다. 소개문에 안내를 넣어 두었습니다. (코드 서명 인증서가 없으면 피할 수 없음)
- **AI 사용 표기**: itch.io 는 *Generative AI disclosure* 항목이 있습니다. 코드·문구 작성에 AI 도구를 썼다면 그 항목을 사실대로 체크하세요.
- **저장 데이터**: 진행·언어·튜토리얼 기록은 `%APPDATA%\Godot\app_userdata\Parry Pierce (prototype)\` 에만 저장됩니다 (플레이 기록 폴더는 만들지 않음). 지우면 처음 상태로 돌아갑니다.
- **조작**: 마우스 필수(마우스 방향 = 조준). 게임패드는 지원하지 않습니다.
- **플랫폼**: Windows 64비트 + 웹(HTML5, 스레드 없음). Mac/Linux 는 빌드하지 않습니다.
- **웹 성능**: 탄이 많은 장면은 브라우저·PC 에 따라 느려질 수 있습니다. 올리기 전에 *Draft* 상태로 3·4스테이지를 한 번 해 보세요.
