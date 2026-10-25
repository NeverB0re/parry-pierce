# 인수인계서 (v0.130 기준, 2026-10-24)

새 세션이 이 문서 하나로 이어서 작업할 수 있게 정리했다. 먼저 `docs/RULES.md`를 읽을 것.

## 1. 지켜야 할 규칙

**작업 방식**
- 사용자에게는 **한국어**로 답한다.
- 새 컨텐츠는 `docs/RULES.md` 안에서 만든다. 예외가 필요하면 **만들기 전에** 사용자에게 알린다.
- 사용자의 예전 지시가 규칙과 부딪치면 짚고 물어본다.
- 새 UI 문구는 `Loc.t()`로 넣고 영어를 `scripts/loc.gd`에 추가한다.
- 모바일 작업은 중단 상태다. `config/name`은 바꾸지 않는다.
- Godot 실험은 헤드리스로 돌린다. 자동 종료되는 짧은 창 캡처만 허용된다.

**빌드·커밋**
- 수정마다 `project.godot`의 `config/version`을 올린다. 지금은 0.130이고, 다음은 0.131이다. 1.0은 정식 출시용이다.
- "Windows Telemetry" 프리셋으로 `ParryPierce0.XXX.exe`를 빌드한다. 폴더에는 최신 2개만 남긴다(지금 0.129, 0.130).
- 매번 커밋하고 푸시한다. 커밋 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`를 붙인다.
- `새 텍스트 문서.txt`, `아이디어노트.txt`, `.claude/`는 커밋하지 않는다.
- GitHub 릴리즈는 큰 변화가 있을 때나 요청받았을 때만 만든다.

## 2. 명령어

**테스트** (규칙 테스트, 스테이지 0~5 스모크, 골든 트레이스)
```bash
GODOT="C:/Users/JMS/Documents/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash tests/run.sh
```
- 트레이스를 의도적으로 바꿨을 때만 `--update-trace`를 붙인다.

**규칙 점검:** `tests/audit_rules.gd`
- 6개 스테이지에서 근접+탄, 근접+보라, 보라 2개 동시, 동시 3패턴 이상, 멍때림을 센다.

**캡처:** `tests/capture/reactor.gd` (`-- --notutorial --out=<dir> [--en]`)
- 미로 6종, 양분, 압착, 조준, 과열 3, 융해를 찍는다.

**내보내기**
- "Windows Telemetry" → `ParryPierce0.XXX.exe`
- "Windows Desktop" → `ParryPierce.exe`
- "Web" → `itch/build/web/index.html`
- 그다음 `python itch/pack.py <ver>`로 zip을 만든다.

**itch 업로드** (butler, `--userversion X`)
- `C:/butler-windows-amd64/butler.exe push itch/build/windows neverb0re/parry-pierce:windows`
- `C:/butler-windows-amd64/butler.exe push itch/build/web neverb0re/parry-pierce:html5`
- 앞 빌드가 아직 처리 중이면 push가 실패한다.
- itch에 올라간 최신은 v0.127이다.

## 3. 지금 상태: 6스테이지 반응로 (v0.129~0.130)

기획서는 `docs/BOSS_capacitor.md`다. 이름 "반응로"는 가칭이다.

**보스 구조**
- 맨 위에 진짜 벽인 에너지 방벽이 있다. 위치는 `BARRIER_Y` -2000이다.
- 일반 공격과 차지 공격은 방벽에 막힌다. **리버스 드라이브만** 뚫고 방열판을 친다.
- 타격하면 보스가 경직되고 패턴이 캔슬된다. 탄이 지워지고, 플레이어는 하단으로 크게 날아간다(무적 1.4초).
- 과열 `HEAT_N`=5번이면 노심 융해로 클리어된다. HP바는 없다.

**패턴**
- **냉각 미로**(`scripts/attacks/reactor_maze.gd`): 지형은 잔탄이다.
  - 빽빽한 40×40 잔탄 벽에 좁은 길이 나 있다. 길 폭은 320, 방은 720, 목은 280이다.
  - 벽은 150px/s로 내려온다. 패턴 하나는 약 15초다.
  - 모드는 snake, zigzag, steps, rooms, fork, braid 여섯 개다.
  - 길은 한 줄에 최대 34px만 옆으로 옮겨 간다. 모든 줄은 앞 줄과 200px 이상 겹친다(테스트로 확인).
  - 끝 무렵 금색 주탄이 하나 나온다. 패리한 뒤 드라이브로 방벽을 칠 기회다.
  - 배출구가 다음 줄의 길 자리를 미리 보여 준다.
- **양분**(`reactor_divide.gd`): 가운데에 두께 340짜리 보라 광선이 서고, 그동안 잔탄 줄넘기 줄 5개가 내려온다.
- **압착**(`reactor_clamp.gd`): 좌우 판이 경기장을 좁힌다.
  - 통합 근접 규칙을 따른다. 빠른 준비 뒤 정지 상태에서 경고가 나오고, 이때부터 요격할 수 있다.
  - 요격하면 그쪽 판만 밀려난다.

**공통 규칙 변경**
- 회피 한 번의 무적으로 넘을 수 없는 두께(`EVADE_CROSS_MAX` 200 초과)의 보라 광선은 흡수할 수 없다. 모함 주포도 이 규칙으로 고쳤다.
- 잔탄을 흡수해도 패리 쿨이 돌아오지 않는다(전 보스).
- 리버스 드라이브는 지나간 자리의 지형 잔탄(반경 80)을 지운다. 지금은 반응로만 해당한다(`drive_clears_terrain`).

**보상:** 방열 코어(`radiator`)는 과열 냉각 시간을 절반으로 줄인다.

## 4. 사용자 답을 기다리는 것

1. **반응로 플레이 피드백:**
   - N=5에서 클리어 시간
   - 미로 난이도: 길 폭 320, 속도 150, 옆으로 옮겨 가는 한계 34가 조정 후보
   - 웹판 성능(잔탄 약 2,500발, PC에서는 프레임당 약 2ms)
2. **가칭 확정:** 이름 "반응로", "방열 코어", N=5
3. **선택 작업:** itch 빌드 재업로드(지금은 v0.127), 반응로 스크린샷, GitHub 릴리즈

사용자가 요청하기 전에는 새 작업을 시작하지 않는다.

## 5. 참고 문서

| 문서 | 내용 |
|---|---|
| `docs/RULES.md` | 게임 규칙과 승인된 예외 표 (위성 이중 결계벽, 반응로 예외들) |
| `docs/BOSS_*.md` | 보스별 기획 |
| `docs/SOUND.md` | 사운드 기획. 음량 기준은 코드에 있다: `scripts/audio_settings.gd` (기본 마스터 0.8 ≈ -21 LUFS), `scripts/music.gd` (-6 dB), `scripts/sfx.gd`의 `TRIM` |
| `itch/DEVLOG_v0.127.md`, `itch/STORE_PAGE.md`, `itch/UPLOAD.md` | itch 배포 자료 |
| 메모리 `C:\Users\JMS\.claude\projects\C--AI-----ParryPierce\memory\` | 사용자 선호와 프로젝트 결정 (새 세션에 자동으로 로드됨) |
