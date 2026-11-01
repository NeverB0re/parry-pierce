# 인수인계서 — Parry Pierce

> 기준: v0.130 + 문서 커밋 `f4ce1fc`, 작성 2026-11-01.
> 이전 대화나 에이전트 메모리를 볼 수 없는 AI 에이전트도 이 문서만으로 이어서 작업할 수 있게 썼다.
> 게임 규칙의 기준은 [docs/RULES.md](docs/RULES.md)다. 이 문서와 어긋나면 RULES.md와 코드를 믿고, 이 문서를 고친다.

## 0. 먼저 할 일

1. 이 문서 전체를 읽는다.
2. [docs/RULES.md](docs/RULES.md)를 끝까지 읽는다. 짧고, 모든 콘텐츠 작업의 전제다.
3. `git status -sb`와 `git log --oneline -5`로 상태를 확인한다.
4. 7장의 테스트를 한 번 돌려 환경이 정상인지 본다.
5. **사용자가 요청하기 전에는 새 작업을 시작하지 않는다.** 6장의 대기 항목도 먼저 시작하지 않는다.

## 1. 프로젝트 요약

탄을 패리한 에너지로 거대 병기(콜로서스)에 돌진해 부수는 2D 보스 러시 액션 게임이다. 사거리 무기가 없고, 공격을 받아낸 힘이 곧 공격 수단이다.

| 항목 | 값 |
|---|---|
| 엔진 | Godot 4.7.2, GDScript, 2D, 렌더러 `gl_compatibility`, 기본 1280×720 |
| 작업 폴더 | `C:\AI 작업물\ParryPierce` |
| 저장소 | https://github.com/NeverB0re/parry-pierce (공개), 브랜치는 `main`만 사용 |
| Godot 콘솔 실행 파일 | `C:/Users/JMS/Documents/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe` (앞의 `.exe`까지 폴더 이름이다) |
| butler (itch 업로드) | `C:/butler-windows-amd64/butler.exe` |
| 현재 버전 | `project.godot`의 `config/version="0.130"`, 다음은 0.131 |
| 배포 상태 | GitHub 릴리즈와 itch.io 모두 v0.127이 최신 |
| 저장 위치 | `%APPDATA%\Godot\app_userdata\Parry Pierce (prototype)\` (`profile.cfg`, `settings.cfg`, `tutorial.cfg`, `telemetry/`) |

**스테이지** (`scripts/stages.gd`): 월드맵에는 9칸과 목적지가 있고, 지금까지 6개를 만들었다.

| # | 보스 | 스크립트 | 가르치는 것 | 얻는 코어 |
|---|---|---|---|---|
| 1 | 관측자 | `colossi/observer.gd` | 기본 조작 | 반격 `counter` |
| 2 | 탄막 요새 | `colossi/fortress.gd` | 패리, 돌진패리 | 반사 `reflect` |
| 3 | 크라켄 | `colossi/kraken.gd` | 요격 | 강습 `assault` |
| 4 | 결계 위성 | `colossi/satellite.gd` | 회피, 동조 (플레이어 평가 최고) | 동조 `sync` |
| 5 | 모함 | `colossi/carrier.gd` | 편대 상대 | 호위기 `wingman` |
| 6 | 반응로 (가칭) | `colossi/reactor.gd` | 지형 탄 미로와 드라이브 | 방열 `radiator` (가칭) |

## 2. 사용자와 일하는 규칙

사용자가 직접 정한 것이다. 어기면 지적을 받았던 항목들이다.

### 소통
- **모든 답변과 진행 안내는 한국어로 쓴다.** 코드 주석과 문서는 한국어, 커밋 메시지는 영어가 기존 관례다.
- 새 콘텐츠는 RULES.md 안에서 만든다. **규칙을 벗어나는 예외가 필요하면 구현 전에 사용자에게 알리고 결정을 받는다.** 받은 예외는 RULES.md 9장에 적는다.
- 사용자의 예전 개별 지시와 규칙이 부딪치면 한쪽을 조용히 고르지 말고 짚어서 묻는다.
- 사용자는 직접 플레이하고 로그와 말로 피드백한다. 재미와 체감 판단은 사용자 몫이다.

### 코드
- 상위 폴더의 `C:\AI 작업물\CLAUDE.md` 지침을 따른다. 요지는 네 가지다.
  - 가정을 드러내고, 불명확하면 묻는다.
  - 요청받은 만큼만 가장 단순하게 만든다.
  - 요청과 무관한 코드는 건드리지 않는다.
  - 검증할 수 있는 성공 기준을 세우고 확인한다.
- 주변 코드의 이름, 주석 밀도, 관용구를 따른다. 스크립트 주석은 한국어이고 설계 근거를 짧게 적는다.
- 화면 문구는 모두 `Loc.t("한국어 원문")`으로 감싸고 영어를 `scripts/loc.gd`의 `EN` 표에 넣는다. 누락은 테스트 `_i18n_test`가 잡는다. 영어로 바꿔도 버튼이 화면 밖으로 나가면 안 된다.
- 튜토리얼과 설명문은 간결하게 쓰고, 정확한 피해 수치나 픽셀 범위는 뺀다.
- `config/name="Parry Pierce (prototype)"`은 **바꾸지 않는다.** 저장 폴더 이름이 이 값을 따른다. 창 제목은 코드에서 정한다.
- 모바일은 v0.20 이후 중단 상태다. APK 빌드와 튜닝은 하지 않고, `touch_controls.gd`가 깨지지 않게만 유지한다.

### Godot 실행
- **실험과 테스트는 `--headless`로만 돌린다.** 사용자가 다른 일을 하는 중에 창이 뜨면 방해가 된다. `ParryPierce.exe`를 실행해 보는 것도 안 된다.
- 예외는 그래픽 확인용 짧은 캡처뿐이다. 자동으로 종료되는 `tests/capture/*.gd`만 허용한다.
- 헤드리스에서는 렌더링이 없고 HUD `size`가 0이다. 그리기 코드는 이 경우를 막아 둔다.

### 빌드와 커밋
게임 코드를 수정할 때마다 아래를 차례로 한다. 문서만 고쳤다면 버전 없이 커밋·푸시만 한다.

1. `project.godot`의 `config/version`을 올린다. `export_presets.cfg`의 버전은 올리지 않는다(7장 참고).
2. `tests/run.sh`를 통과시킨다.
3. 프리셋 **"Windows Telemetry"**로 `ParryPierce0.XXX.exe`를 내보낸다.
4. 폴더의 버전 번호 exe는 **최신 2개만** 남긴다. 지금은 0.129와 0.130이다. `logs/`의 기록은 지우지 않는다.
5. 커밋하고 푸시한다. 메시지 형식은 `v0.130: 영어로 변경 요약`, 문서 수정은 `docs: 요약`이다.

- 버전 번호에서 **1.0은 정식 출시용으로 남겨 둔다.** 0.99 다음이 0.101이었고, 점 뒤를 정수로 계속 올린다.
- GitHub 릴리즈는 **큰 변화가 있거나 사용자가 요청할 때만** 만든다. 첨부 파일 이름은 `ParryPierce<버전>.exe`다.
- 커밋에는 공동 작성자 줄을 넣어 왔다. Claude 에이전트는 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`를 썼다. 다른 에이전트는 자기 이름을 쓴다.
- **커밋 금지:** `아이디어노트.txt`, `새 텍스트 문서.txt`, `.claude/`. 이 세 항목은 `.gitignore`에 없으므로 `git add -A`를 쓰지 말고 파일을 지정해서 올린다. exe, `logs/`, `itch/build/`, `itch/*.zip`은 무시 목록에 있다.
- 줄바꿈은 LF다(`.gitattributes`). 편집 스크립트로 앵커를 맞출 때는 CRLF와 탭 깊이에 주의한다.

## 3. 게임 시스템 요약

자세한 내용은 RULES.md에 있다. 코드를 읽기 전에 필요한 용어만 정리했다.

- **동사:** 좌클릭 = 돌진(무적 0.16초), 좌클릭 꾹 = 차지 강습(근접 요격), 우클릭 꾹 = 패리 → 슬로우 조준 → 놓으면 리버스 드라이브(최강 일격). 돌진 직후 아슬아슬하게 스치면 퍼펙트 회피(동조)가 된다.
- **색 언어:** 금 = 패리 가능 주탄, 주황 = 잔탄(회피 또는 흡수, 긁히면 과열), 보라 = 패리 불가(회피, 퍼펙트 회피로 흡수), 진홍 = 근접(요격 또는 위험구간 밖으로), 청백·청록 = 플레이어 쪽, 붉은 선 = 노릴 수 있는 표적.
- **근접 3단계:** 빠른 준비(경고 없음, 요격 불가) → 정지 태세(경고 약 1초 이상, 요격 가능) → 공격(요격 가능). **경고가 보이면 요격된다.**
- **겹침 금지:** 보라+근접, 보라 둘. 동시 패턴은 1~2개. 근접 중 탄이 날아오는 것은 허용한다(2026-10-23 완화).
- **멍때림 금지가 대전제다.** 사용자가 두 번 강조했다. 패턴을 합치거나 규칙을 더할 때 탄막 양이 줄지 않았는지 확인한다. 부위를 부숴도 패턴 차례는 쉬지 않는다.
- **진행할수록 사나워진다:** `pattern_scale`과 `bolt_mult`로 패턴과 탄 속도가 함께 오른다. 뒤 스테이지일수록 `level`이 오른다.
- **보스 구조:** 외부 시스템(부위) → 개방 연출(코어 무적, `core_sealed`) → 동력 코어. 반응로와 일부 보스의 예외는 RULES.md 9장에 있다.
- **체력 표시:** 맞을 때만 약 2초 보이는 게이지 링(`_draw_gauge`)을 쓴다. 피해 숫자는 쓰지 않는다. 모함과 반응로는 링이 없다.

### 설계 원칙

자세한 내용은 [docs/DESIGN_boss_principles.md](docs/DESIGN_boss_principles.md)에 있다.

- **보이는 위협 ≫ 실제 판정:** 빛무리는 넓게, 판정은 가는 중심선으로 둔다.
- 긴장과 해방의 2박자를 둔다. 해방은 타이머가 아니라 플레이어 행동으로 열고, 해방 중에도 위험이 있어야 한다. 적의 공격이 곧 연료가 된다.
- 다만 **모든 보스가 "특정 행동 → 딜타임"을 답습하면 안 된다.** 보스마다 학습 역할과 부목표를 다르게 한다.
- 보스는 화면을 채울 만큼 크고 살아 움직여야 한다. 대기 모션은 그림만 바꾸고 판정, 표적, 발사점은 건드리지 않는다.
- 탄막은 플레이어를 겨누지 않고 파훼 경로가 있는 영역을 채운다. 겨누는 사격은 보스마다 시그니처 하나만 둔다. 유도탄은 따로 쏘지 않고 탄막과 함께 쏜다.
- 호로 긋는 공격은 흐릿한 점선 한 번 긋기(`arc_trace`)와 팔다리 테두리로 예고한다. 진한 빨간 화살표와 잔상식 예고는 사용자가 싫어한다.
- 패턴은 덜어내기보다 같은 자리, 같은 역할끼리 합친다.
- **보스 체력은 클리어 시간으로 정한다.** 일률 배수는 쓰지 않는다. 사용자의 플레이는 1분대 초반, 평균 플레이어는 2~3분이 목표다. 로그의 "딜 측정" 줄로 체력 = 목표 시간 × 측정 딜 속도를 계산한다.
- 폐기된 것: 초기의 "높이 = 진행도, 반동으로 고도 유지" 개념. 다시 제안하지 않는다.
- 보류된 아이디어: 떨어진 부위를 쳐서 방어막을 깨는 기믹. 크라켄에서는 재미가 덜해 뺐고, 나중에 방어형 보스에 쓸 수 있다(v0.63~0.66 커밋의 `kraken.gd`, `CLAW_*`).

## 4. 코드 구조

`scripts/` 전체는 약 18,000줄이다. `tests/test_rules.gd`만 약 150KB다.

| 파일 | 역할 |
|---|---|
| `main.gd` | 게임 루프, 입력, 판정, 피드백. 핵심은 `_physics_process`, `_check_attacks`, `_clash`(요격), `_graze`(잔탄), `_parried_bullet` |
| `player.gd` | 기체. 돌진, 차지, 패리, 리버스 드라이브, 요격 |
| `player_stats.gd`, `data/player_stats.tres` | 코어로 바뀌는 수치 |
| `colossus_base.gd` | 보스 공통 틀. 부위 → 개방 → 코어, 공격 일정, 판정 위임, 게이지 |
| `colossi/*.gd` | 보스 6종. `reactor.gd`가 가장 새것이고 새 탄막 구조의 표본이다 |
| `attacks/attack.gd` | 공격 모듈의 기반 클래스. `attacks/*.gd`가 패턴들이다 |
| `projectiles.gd`, `armored_core.gd`, `ev.gd` | 탄, 장갑+코어, 이벤트 열거형 |
| `melee_warn.gd`, `hud.gd`, `fx.gd`, `hex_shield.gd`, `ground.gd`, `background.gd` | 예고, 화면, 이펙트, 무대 |
| `stages.gd`, `profile.gd`, `upgrades.gd` | 스테이지 목록, 진행 저장, 동력 코어 |
| `world_map.gd`, `ftl.gd`, `title_menu.gd`, `pause_menu.gd`, `tutorial.gd` | 메타와 메뉴 |
| `loc.gd`, `ui_font.gd`, `ui_style.gd` | 번역, 글꼴(웹은 번들 Noto Sans KR), UI 스타일 |
| `sfx.gd`, `music.gd`, `audio_settings.gd` | 소리는 합성이다. 음량 기준은 이 코드에 있다 |
| `telemetry.gd`, `debug.gd` | 플레이 기록, 디버그 키 |

### 새 패턴이나 보스를 만드는 법

- 공격 모듈은 `attack.gd`를 상속한 상태 머신(예고 → 판정 → 회복)이다.
  - 주요 함수: `step`, `draw`, `hitboxes`, `clash_box`, `melee_warning`, `beam_hit`, `strand_width`, `assist_targets`, `unparry_point`, `mark_dodged`, `on_parried`
  - 끝나면 `boss.finish_attack()`을 부른다.
  - 근접 모듈은 `melee_warning()`이 true일 때 `clash_box`도 유효해야 한다.
  - 보라 모듈은 `beam_hit`만 바르게 만들면 흡수 연출이 따라온다. 두께가 `EVADE_CROSS_MAX`(200) 초과면 자동으로 흡수할 수 없다.
- 보스는 `colossus_base.gd`를 상속해 `_choose`(패턴 지휘), `part_*`, `_on_part_broken`, `_step_phase`, `_step_effects` 등을 덮어쓴다. 특수 동작 훅으로 `blocks_strike`, `takes_reflect`, `drive_clears_terrain`, `view_bias`, `wall_x_min/max`, `wall_y_min`, `core_sealed`가 있다.
- 새 보스를 추가하면 함께 손볼 곳은 다음과 같다.
  - `stages.gd`의 `LIST`와 `upgrades.gd`의 `CORES`
  - `loc.gd`
  - `tests/run.sh`의 스테이지 목록과 `tests/audit_rules.gd`의 `for st in 6`
  - `test_rules.gd`, `tests/capture/`
  - `docs/BOSS_*.md`와, 예외가 있으면 RULES.md 9장
- 새 보스의 탄막은 RULES.md 7장의 두 층 구조(지형 탄과 기회 탄, 지휘자 하나)로 설계한다.
- 기획은 코드보다 먼저 `docs/BOSS_*.md`에 쓰고 RULES.md 체크리스트로 점검한다.

### 코드 함정

- `tests/`와 `itch/`에는 `.gdignore`가 있어 Godot가 가져오지 않는다. 그래서 테스트는 `-s <절대 경로>`로 실행한다.
- 테스트와 캡처 스크립트는 사용자의 저장을 건드리지 않도록 `persist=false` Profile을 끼우고 텔레메트리를 끈다. 새 스크립트도 같게 한다.
- 같은 테스트 실행 안에서 앞선 승리로 코어가 남아 있을 수 있다. 필요한 테스트에서는 해당 코어 수치를 직접 끈다.
- 퍼펙트 패리 피드백이 `hitstop` 0.2를 걸고, 셀 파괴 뒤에도 hitstop이 `_check_attacks`를 막는다. 테스트에서는 `main.hitstop`을 0으로 만든다.
- 속도 0인 테스트 탄은 움직이는 기체 진행 방향 앞에 둔다.
- `test_rules.gd`는 FakeStick `touch_ui`를 쓴다. 헤드리스 마우스 (0,0)이 조준을 덮어쓰지 않게 하기 위해서다.
- 트레이스는 결정성을 위해 main의 엔진 물리 틱을 끈다.
- 오디오 버스는 `default_bus_layout.tres`에 둔다. 실행 중에 만들면 웹에서 소리가 안 난다.
- 새 UI 글꼴은 `UiFont.make([...])`로 만든다.

## 5. 현재 작업: 6스테이지 반응로 (v0.129~0.130)

기획서는 [docs/BOSS_capacitor.md](docs/BOSS_capacitor.md)다. 10장의 구현값은 v0.129 기준이라 미로 수치가 낡았다. 미로는 아래 표와 코드를 믿는다.

**사이클**
1. 경기장 맨 위의 에너지 방벽(`BARRIER_Y` -2000)은 이동을 막는 진짜 벽이다.
2. 일반 돌진과 차지는 튕긴다. **리버스 드라이브만** 뚫고 방열판을 친다.
3. 타격하면 보스가 경직되어 패턴이 끊기고 탄이 걷힌다. 플레이어는 하단으로 크게 밀려난다(무적 약 1.4초). 2.4초 뒤 다음 사이클이 시작된다.
4. 과열 `HEAT_N`=5번이면 노심 융해로 클리어된다. 게이지 링 없이 방열판 손상으로 진행을 보여 준다.

**패턴과 조정 후보**

| 패턴 | 파일 | 현재 값 |
|---|---|---|
| 냉각 미로 (잔탄 지형, 6종: snake, zigzag, steps, rooms, fork, braid) | `attacks/reactor_maze.gd` | `CORR_W` 320, `ROOM_W` 720, `NECK_W` 280, `SPEED` 150, `MAX_STEP` 34, 잔탄 간격 40×40, 길이 약 15초, 끝 무렵 금색 주탄 |
| 양분 + 줄넘기 | `attacks/reactor_divide.gd` | 보라 광선 폭 340(흡수 불가), 8.5초 유지, 잔탄 줄 5개, 간격 1.45초, 속도 300 |
| 압착 (근접, 요격하면 그쪽 판만 밀림) | `attacks/reactor_clamp.gd` | 16~22초 간격, 못 쳐내면 13초 박혀 있다가 90px/s로 물러남 |
| 보스 공통 | `colossi/reactor.gd` | 과열 하나마다 패턴 +10%, 탄 +6% |

**이번에 함께 바뀐 전체 규칙**
- 돌진 한 번으로 건널 수 없는 두께(200 초과)의 보라는 흡수할 수 없다. 모함 주포에도 적용했다.
- 잔탄 흡수로는 패리 쿨다운이 돌아오지 않는다. 쿨다운을 없애는 것은 주탄 패리뿐이다.
- 드라이브가 지나간 자리의 지형 잔탄(반경 80)을 지운다. 반응로만 해당한다(`drive_clears_terrain`).

**미로 검증:** 모든 줄이 앞 줄과 200px 이상 겹치는지 `_reactor_test`에서 확인한다. 기체가 관성으로 움직이므로 길이 한 줄에 크게 꺾이면 억울한 피격이 된다.

**v0.130 플레이 기록** (`logs/ParryPierce0.130_log.md`, 2026-10-23, 세 판)

| 결과 | 시간 | 피격 | 코어 피해 |
|---|---|---|---|
| 사망 | 0:45 | 잔탄 8, 양분 1 | 1 / 5 |
| 사망 | 1:22 | 잔탄 14, 양분 1 | 2 / 5 |
| 종료 | 0:02 | 없음 | 0 / 5 |

아직 클리어 기록이 없고, 피격 대부분이 잔탄이다. 사용자의 난이도 평가는 받지 못했다. 이 기록만으로 수치를 바꾸지 말고 피드백을 받아 판단한다.

## 6. 대기 중인 일

**사용자 답을 기다리는 것**
1. 반응로 플레이 피드백: N=5의 클리어 시간, 미로 난이도, 웹판 성능. 잔탄이 약 2,500발이고 PC에서는 프레임당 약 2ms다. 웹판 성능은 숨은 브라우저에서 측정할 수 없어 사용자가 확인해야 한다.
2. 가칭 확정: 이름 "반응로"(Reactor), "방열 코어", N=5.
3. 선택 작업: itch 재업로드(현재 v0.127), 반응로 스크린샷, GitHub 릴리즈.

**사용자 메모** (`아이디어노트.txt`, 커밋 금지). 지시가 아니라 메모이므로 묻기 전에 구현하지 않는다.
- 모함의 잡몹을 죽이면 리필되게 하되 한 방에 죽게 하고, 주 목표를 대장기로 만들기. 현재 `carrier.gd`에는 리필 코드가 없다.
- 연속 패리 성공 때 콤보 표시, 또는 비슷한 연출. 현재 `main.gd`와 `hud.gd`에 콤보 표시가 없다.
- 두꺼운 빔을 진보라색으로 해서 더 위험해 보이게 하기. 현재 `reactor_divide.gd`와 `carrier_cannon.gd`는 일반 보라와 같은 `C_UNPARRY`를 쓴다.

**사용자에게 확인이 필요한 불일치** (이 문서를 쓰며 발견했고, 고치지 않았다)
- RULES.md 7장은 지형 탄 화면 점유 상한을 약 30~40%로 두지만, v0.130 미로는 사용자 지시("지형을 빽빽하게")에 따라 화면을 거의 채운다. 7장을 고칠지 묻거나 9장에 예외로 올려야 한다.
- 2026-10-21의 탄막 구조 결정(Claude 메모리 `project_barrage_layers.md`)에는 지형 탄이 "패리 불가"로 적혀 있지만, RULES.md 3.1과 현재 동작에서 잔탄은 패리로 흡수된다. v0.130 로그에도 `parry_absorb ×31`이 있다. v0.128부터는 쿨다운 때문에 연타로 버틸 수 없다.

**낡았지만 무시해도 되는 문서**
- `README.md`: "최신 빌드 v0.49"이고 조작 설명에도 옛 수치가 있다. 다음 릴리즈 때 갱신 대상이다.
- `docs/DESIGN.md`: v0.1부터의 기록이다. 옛 결정이 많아 현재 규칙으로 읽으면 안 된다.
- `docs/RULES.md` 머리말의 버전은 v0.129이지만 내용은 유효하다.
- `export_presets.cfg`의 파일 버전이 0.49로 멈춰 있다. 게임 내 버전은 `project.godot`를 쓴다.

## 7. 명령어

모두 Git Bash 기준이고, 프로젝트 폴더에서 실행한다.

```bash
GODOT="C:/Users/JMS/Documents/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

# 전체 테스트: 규칙 테스트, 스테이지 0~5 스모크, 터치 스모크, 골든 트레이스
GODOT="$GODOT" bash tests/run.sh

# 동작을 일부러 바꿨을 때만 트레이스 기준 갱신
GODOT="$GODOT" bash tests/run.sh --update-trace

# 규칙 점검: 겹침, 동시 패턴 수, 멍때림 (보스별 150초, 약 2분)
"$GODOT" --headless --path . -s "$(pwd -W)/tests/audit_rules.gd"

# 플레이 테스트용 exe (실행 중인 ParryPierce를 먼저 끈다)
"$GODOT" --headless --path . --export-release "Windows Telemetry" ParryPierce0.131.exe

# 캡처: 창이 잠깐 뜨고 자동 종료된다. 그래픽 확인 때만
"$GODOT" --path . -s "$(pwd -W)/tests/capture/reactor.gd" -- --notutorial --out=<폴더> [--en]

# 새 클론이나 worktree에서 처음 한 번 (안 하면 스프라이트 로드 오류)
"$GODOT" --headless --path . --import
```

**결과 읽는 법** (2026-11-01 이 문서를 쓰며 실행한 결과: `FAILS 0`, 스모크 전부 통과, 트레이스 `같음`)
- `run.sh`는 먼저 게임 로드를 확인하고, 실패하면 바로 멈춘다.
- `[test_rules.gd] FAILS 0`과 `smoke ok`, `stages ok`가 나와야 한다.
- **트레이스가 `달라짐`이어도 종료 코드는 실패가 아니다.** 출력을 직접 봐야 한다. 리팩터링이면 `같음`이어야 하고, 의도한 동작 변경일 때만 `--update-trace`로 갱신한다.
- 내보내기는 종료 코드 2가 나와도 마지막에 DONE이면 성공이다.
- `audit_rules`의 값이 0이 아니면 위반이거나 RULES.md 9장의 예외다.

**배포** (사용자가 요청할 때만. 외부 공개이므로 먼저 확인받는다)

```bash
"$GODOT" --headless --path . --export-release "Windows Desktop" ParryPierce.exe
"$GODOT" --headless --path . --export-release "Web" itch/build/web/index.html
python itch/pack.py <버전>
C:/butler-windows-amd64/butler.exe push itch/build/windows neverb0re/parry-pierce:windows --userversion <버전>
C:/butler-windows-amd64/butler.exe push itch/build/web neverb0re/parry-pierce:html5 --userversion <버전>
gh release create v<버전> ParryPierce<버전>.exe --title "..." --notes "..."
```

- 앞 빌드가 아직 처리 중이면 butler push가 실패한다.
- 배포 빌드에서 디버그 키는 디버그 빌드나 `--debug`로만, 플레이 기록은 `--telemetry`나 Telemetry 프리셋으로만 켜진다.
- itch 자료: `itch/UPLOAD.md`, `itch/STORE_PAGE.md`, `itch/DEVLOG_v0.127.md`. 스프라이트 크레딧(Ravenmore, CC-BY 3.0)은 `art/CREDITS.md`, 타이틀, `itch/pack.py`에 들어 있다.
- 웹판 로컬 미리보기: `python -m http.server 8766 --directory itch/build/web` (`.claude/launch.json`의 `web-build`).

**디버그 키** (디버그 빌드나 `--debug`): F1 오버레이, F2 무적, F3 공격 정지, F4 코어로 건너뛰기, F5 절반 속도, F6 튜토리얼 초기화, F7 코어 전부 획득 후 스테이지 재시작, F8 프로필 초기화.

**플레이 기록:** Telemetry 빌드는 exe 옆 `logs/<exe 이름>_log.md`에 판마다 요약을 쌓는다. 항목은 피격 원인, 딜 측정, 패턴 순서, 행동 횟수다. 수치 조정은 이 기록과 사용자 피드백으로 판단한다. 사용자가 남긴 로그는 지우지 않는다.

## 8. 참고 문서

| 문서 | 내용 |
|---|---|
| [docs/RULES.md](docs/RULES.md) | **기준 문서.** 규칙, 승인된 예외(9장), 점검 방법(10장) |
| [docs/DESIGN_boss_principles.md](docs/DESIGN_boss_principles.md) | 보스 설계 원칙과 회고 |
| `docs/BOSS_observer.md`, `BOSS_fortress.md`, `BOSS_satellite.md`, `BOSS_carrier.md`, `BOSS_capacitor.md` | 보스별 기획. `BOSS_capacitor.md`가 반응로다 |
| [docs/SOUND.md](docs/SOUND.md) | 사운드 갈래. 실제 음량 기준은 `scripts/audio_settings.gd`(기본 마스터 0.8 ≈ -21 LUFS), `music.gd`(-6 dB), `sfx.gd`의 `TRIM` |
| [docs/STORY.md](docs/STORY.md), [docs/GLOSSARY.md](docs/GLOSSARY.md) | 세계관, UI 용어. 문구와 이름은 이 설정에 맞춘다(원거리 무장 상실, 코어 = FTL 연료) |
| [docs/PLAN_colossi.md](docs/PLAN_colossi.md), [docs/PLAN_upgrade.md](docs/PLAN_upgrade.md) | 보스 계획, 코어 체계 |
| [docs/REVIEW_roadmap.md](docs/REVIEW_roadmap.md), [docs/DESIGN.md](docs/DESIGN.md) | 옛 로드맵과 변경 기록. 역사 참고용 |
| `C:\Users\JMS\.claude\projects\C--AI-----ParryPierce\memory\` | Claude Code용 메모리 원본. 핵심 내용은 이 문서로 옮겼다. 다른 에이전트는 읽지 않아도 된다 |
