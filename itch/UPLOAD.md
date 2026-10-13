# itch.io 업로드 방법 (Parry Pierce v0.49)

이 폴더(`itch/`)에는 itch.io 에 올리는 데 필요한 것이 모두 들어 있습니다.

| 파일 | 용도 |
|---|---|
| `build/windows/` | **업로드할 게임 폴더** — `ParryPierce.exe` + `README.txt` (butler 로 올릴 때 이 폴더를 통째로) |
| `ParryPierce-v0.49-windows.zip` | 같은 내용의 **zip** (웹 대시보드에서 직접 올릴 때) |
| `cover.png` | 표지 이미지 (1260×1000, itch 권장 630×500 의 2배. 5:4 비율이라 그대로 올리면 된다) |
| `screenshots/01~05_*.png` | 스크린샷 5장 (1280×720, 영어 화면) |
| `STORE_PAGE.md` | 페이지에 붙여 넣을 소개문 (영어 + 한국어), 태그, 설정 값 |

`exe`/`zip` 은 용량이 커서 git 에는 올리지 않습니다 (`.gitignore`). 새 버전을 만들면 아래 "새 버전 만들기"로 다시 만드세요.

---

## 방법 A — 웹 대시보드 (가장 쉬움, 처음 한 번)

1. itch.io 로그인 → 우상단 계정 메뉴 → **Upload new project** (https://itch.io/game/new).
2. **Title** `Parry Pierce` · **Project URL** 원하는 주소 (예: `parry-pierce`).
3. **Kind of project**: `Downloadable` (실행 파일). *Classification*: `Games`.
4. **Release status**: `In development` (또는 `Prototype`).
5. **Pricing**: `$0 or donate`(무료+후원) 권장, 또는 `No payments`.
6. **Uploads** → *Upload files* 에서 `ParryPierce-v0.49-windows.zip` 선택 → 올라간 파일 옆 체크박스 **Windows** 선택.
7. **Description** 에 `STORE_PAGE.md` 의 소개문을 붙여 넣는다.
8. **Cover image** `cover.png`, **Screenshots** 에 `screenshots/` 의 PNG 5장.
9. **Genre** `Action`, **Tags** 는 `STORE_PAGE.md` 참고, **Languages** 에 `English`, `Korean`.
10. **Visibility & access** 를 처음엔 **Draft**(비공개)로 두고 *Save* → 미리보기로 확인 → 문제 없으면 **Public** 으로 바꾸고 저장.

## 방법 B — butler (CLI, 업데이트에 편함 — 이후 버전은 이쪽 권장)

butler 는 바뀐 부분만 올려 줍니다. 한 번만 설치·로그인하면 됩니다.

```bash
# 1) 설치: https://itchio.itch.io/butler 에서 받아 PATH 에 두거나, 압축 푼 폴더에서 실행
# 2) 로그인 (브라우저가 열린다)
butler login

# 3) 업로드: 폴더째 (권장, 다음 버전부터는 변경분만 전송된다)
butler push itch/build/windows  <itch사용자명>/<프로젝트주소>:windows --userversion 0.49

# 예) butler push itch/build/windows neverb0re/parry-pierce:windows --userversion 0.49
```

- 채널 이름 `windows` 는 itch 가 플랫폼(Windows)으로 자동 인식합니다.
- 처음 `push` 할 때 프로젝트가 아직 없으면 오류가 나니, 방법 A 의 1~9 단계로 **프로젝트 페이지부터 만들고** 그 주소를 쓰세요.
- 올린 뒤 상태 확인: `butler status <사용자명>/<프로젝트주소>`.

## 새 버전 만들기 (개발자용)

```bash
# 빌드 (실행 중인 ParryPierce 먼저 종료)
"<Godot 콘솔 exe>" --headless --path . --export-release "Windows Desktop" ParryPierce.exe
# itch 폴더 갱신 + zip
python itch/pack.py 0.50          # build/windows 와 ParryPierce-v0.50-windows.zip 을 다시 만든다
# 올리기
butler push itch/build/windows <사용자명>/<프로젝트주소>:windows --userversion 0.50
```

## 올리기 전에 확인할 것

- **라이선스 표기**: 도트 그림(기체·화염·폭발)은 Ravenmore "Space Rage" — CC-BY 3.0 이라 **출처 표기가 필요**합니다. 게임 메인 화면 아래, `README.txt`, 소개문(`STORE_PAGE.md`)에 이미 넣어 두었습니다. 올리기 전에 원본 배포 페이지(OpenGameArt)의 라이선스를 한 번 더 확인하세요(`art/CREDITS.md`).
- **서명 없는 exe**: Windows SmartScreen 이 "알 수 없는 게시자" 경고를 띄울 수 있습니다. 소개문에 안내를 넣어 두었습니다. (코드 서명 인증서가 없으면 피할 수 없음)
- **AI 사용 표기**: itch.io 는 *Generative AI disclosure* 항목이 있습니다. 코드·문구 작성에 AI 도구를 썼다면 그 항목을 사실대로 체크하세요.
- **저장 데이터**: 진행·언어·튜토리얼 기록은 `%APPDATA%\Godot\app_userdata\Parry Pierce (prototype)\` 에만 저장됩니다 (플레이 기록 폴더는 만들지 않음). 지우면 처음 상태로 돌아갑니다.
- **조작**: 마우스 필수(마우스 방향 = 조준). 게임패드는 지원하지 않습니다.
- **플랫폼**: 지금은 Windows 64비트만 빌드합니다. (웹/Mac/Linux 는 내보내기 템플릿·성능 검증이 필요해 포함하지 않았습니다.)
