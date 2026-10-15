# 인수인계서 — Parry Pierce main 브랜치 (리워크 이전 방향)

> 작성 2026-10-16. 다른 세션에서 **main 브랜치(기존 게임)** 작업을 이어 가기 위한 문서.
> 사용자와는 **한국어**로 대화한다. 리워크(`rework` 브랜치)는 별도 세션이 맡으니 이 세션에서는 건드리지 않는다.

## 1. 프로젝트 기본

| 항목 | 값 |
|---|---|
| 엔진 | Godot 4.7.2, GDScript, 2D, 렌더러 `gl_compatibility` |
| 폴더 | `C:\Users\JMS\Downloads\parry` (이 폴더 = `main` 브랜치) |
| 저장소 | GitHub `NeverB0re/parry-pierce`, 브랜치 `main` |
| Godot 콘솔 실행 파일 | `C:\Users\JMS\Documents\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` |
| 프로젝트 이름 | `config/name="Parry Pierce (prototype)"` — **바꾸지 말 것** (저장 폴더 이름이 이것을 따른다). 창 제목은 코드에서 "Parry Pierce" |
| 버전 | `project.godot` 의 `config/version="0.49"` (마지막 릴리즈 v0.49) |

### 리워크 폴더 (건드리지 않음)
- `C:\Users\JMS\Downloads\parry-rework` = git worktree, 브랜치 `rework`. 같은 저장소의 다른 폴더다.
- 자유 비행 · 패리 = 구슬 · 리버스 드라이브만 공격 · 자동 사격 등으로 게임 구조를 바꾸는 실험. 기획서 `parry-rework/docs/PLAN_rework.md`.
- main 에서 `git worktree` 나 `rework` 브랜치를 지우거나 합치지 말 것. 합칠지는 사용자가 정한다.

## 2. 작업 규칙 (사용자 지시)

- **릴리즈는 큰 변화(새 보스·큰 기능) 때만.** 자잘한 수정은 커밋(·푸시)만. 릴리즈할 때는 헤드리스 테스트 통과 → exe 내보내기 → `gh release create`, 첨부 exe 이름은 `ParryPierce<버전>.exe` (예: `ParryPierce0.50.exe`).
- 커밋 메시지 끝에 공동 작성자 줄을 붙인다 (해당 세션의 지시를 따른다).
- **실험은 헤드리스로.** 그래픽 확인용 짧은 창 모드 캡처(`tests/capture/*.gd`, 자동 종료)는 허용.
- 새 한글 UI 문구는 `Loc.t("한국어 원문")` 으로 감싸고 `scripts/loc.gd` 의 `EN` 표에 영어를 같이 넣는다 (테스트 `_i18n_test` 가 누락을 잡는다).
- 튜토리얼·설명문은 **간결하게**, 정확한 피해 수치·픽셀 범위 같은 지엽 정보는 빼기.
- **보스 체력바는 가능한 쓰지 않는다** — 피해는 균열·장갑판 등 시각적 손상으로 보여 준다.
- 메모 파일 `새 텍스트 문서.txt` 가 있으면 커밋에서 제외.
- 모바일(APK)은 v0.20 이후 보류, PC 완성 후 재개.
- 배포 빌드 기본값: 디버그 키는 디버그 빌드 또는 `--debug` 에서만, 플레이 기록은 `--telemetry` 로만.

## 3. 명령

```bash
# 전체 테스트 (규칙 테스트 · 스모크 3스테이지 · 궤적 비교)
GODOT="/c/Users/JMS/Documents/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash tests/run.sh
# 의도한 동작 변경 뒤 궤적 기준 갱신
GODOT="..." bash tests/run.sh --update-trace
# 릴리즈 exe (실행 중인 ParryPierce 를 먼저 끈다)
"$GODOT" --headless --path . --export-release "Windows Desktop" ParryPierce.exe
# 실험용 디버그 exe (F1~F8 디버그 키가 켜짐)
"$GODOT" --headless --path . --export-debug "Windows Desktop" ParryPierce.exe
# 창 모드 캡처 (예: 크라켄)
"$GODOT" --path . -s "$(pwd -W)/tests/capture/kraken.gd" -- --notutorial --notitle --out=<폴더>
```

새 worktree·새 클론에서는 처음에 `--headless --path . --import` 한 번 (안 하면 스프라이트 로드 오류).

## 4. 구조 요약

- `main.gd` 루프·입력·판정·피드백 / `player.gd` 기체(돌진·차지·패리·리버스 드라이브·요격) / `player_stats.gd` + `data/player_stats.tres` 업그레이드 가능한 수치
- `colossus_base.gd` 보스 공통 틀 (부위 → 개방 → 코어, 공격 일정, 탄, 이벤트) + `colossi/observer.gd`·`fortress.gd`·`kraken.gd`
- `attacks/*.gd` 공격 모듈 (예고 → 판정 → 회복). 크라켄 촉수 공통 `tentacle.gd`, 연타 `combo.gd`
- `armored_core.gd` 장갑 + 코어, `projectiles.gd` 탄, `ev.gd` 이벤트
- 메타: `stages.gd`·`profile.gd`(user://profile.cfg)·`upgrades.gd`(동력 코어 3종)·`world_map.gd`·`ftl.gd`·`title_menu.gd`(국기 버튼 언어 전환)·`pause_menu.gd`·`tutorial.gd`·`loc.gd`
- 문서: `README.md`(규칙 전체·변경 요약), `docs/DESIGN.md`·`PLAN_colossi.md`·`PLAN_upgrade.md`·`REVIEW_roadmap.md`·`STORY.md`·`GLOSSARY.md`
- itch.io: `itch/` (cover.png, screenshots/, STORE_PAGE.md, UPLOAD.md, pack.py). exe·zip·build 는 gitignore

## 5. 현재 상태 (v0.49 이후)

### 커밋됐지만 아직 릴리즈·푸시 안 됨
- `0933ba4` 크라켄 개편 (main 이 origin 보다 1커밋 앞섬 — **푸시 전**):
  - 표적은 **방어막에 싸인 외눈(코어) 하나**. 돌진·차지 강습은 방어막에 막히고, 리버스 드라이브·반사탄만 뚫는다.
  - 촉수 요격 = 촉수(2번이면 끊어짐) + 외눈에 피해, 촉수 뿌리 → 외눈 전류 줄기. 누적 피해는 외눈 균열·깜빡임·연기로 표시 (체력바 없음). 방어막 동안 코어 하한 `SHIELD_FLOOR`(180 중 60).
  - 촉수가 모두 떨어지면 방어막이 깨지고, 다시 자란 촉수를 요격하면 외눈에 바로 피해.
  - 연타 3종(소용돌이·행진·난타, `combo.gd`). 근접 패턴 첫 타 예고 1.5배(`tentacle.gd LEAD_K`).
  - 기본 시스템: 요격 성공 → 차지 쿨다운 초기화 + **빠른 차지**(3초, 절반 시간), 차지 완료 순간 0.12초 슬로우.
  - 폴더 정리(안 쓰는 스프라이트·끝난 기획서·일회용 캡처 스크립트 삭제).
- 실험용 빌드 `ParryPierce0.50-test.exe` (디버그 빌드, gitignore) 를 사용자에게 줬다.

### 사용자 피드백 (이 개편 뒤)
- "아무래도 별로 재미가 없다" — 근접(요격) 위주라 탄막 패리의 쾌감이 빠졌다는 진단이 나왔고, 이 방향의 대안이 **리워크 브랜치**다. main 에서 크라켄을 더 다듬을지, 리워크 결과를 기다릴지는 사용자에게 확인할 것.
- 확인 요청해 둔 수치: `SHIELD_FLOOR`, `LEAD_K`(1.5), 연타 간격(0.8~0.95초).

### 보류·대기 중인 일
1. **itch.io 업로드**: 사용자가 더 다듬고 썸네일·스크린샷을 직접 만든 뒤 요청할 예정. 패키지 구조는 `itch/UPLOAD.md`.
2. **웹(HTML5) 빌드**: 보류. 요청이 오면 — `SystemFont` 를 번들 한글 글꼴(Noto Sans KR 서브셋, OFL)로 교체(hud·ftl·pause_menu·title_menu·tutorial·world_map·debug), 웹에서 Quit 버튼 숨김, Web 내보내기 프리셋 추가(스레드 없음), `itch/pack.py`·`UPLOAD.md`·`STORE_PAGE.md` 웹용 갱신, 3스테이지 성능 확인. Windows + 웹 동시 업로드 권장.
3. **itch AI 표기**: 코드·텍스트(튜토리얼·번역·소개문)는 AI 도움 → AI Disclosure 에 표기 권장, 그림(Ravenmore CC-BY)·코드로 그린 보스·합성 효과음은 해당 없음. 설명란용 문장(영/한)을 제안했고 `STORE_PAGE.md` 에 넣을지는 사용자 답 대기.
4. `README.md`·`docs/PLAN_colossi.md` 에 v0.50 크라켄 내용이 일부 반영됨(README 크라켄 절). 릴리즈 시 버전 번호(0.50)·`export_presets.cfg` 버전·README "최신 빌드" 줄을 올릴 것.

## 6. 참고 사실
- 진행 저장: `%APPDATA%\Godot\app_userdata\Parry Pierce (prototype)\` (profile.cfg, settings.cfg, tutorial.cfg)
- 테스트·캡처 스크립트는 진행 저장을 건드리지 않게 `persist=false` Profile 을 끼우고 텔레메트리를 끈다.
- 스프라이트: Ravenmore "Space Rage" (CC-BY 3.0), 크레딧 `art/CREDITS.md`·타이틀·README·pack.py.
