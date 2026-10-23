extends "res://scripts/attacks/attack.gd"
## 냉각 미로 (반응로, 지형 탄 = 잔탄): 방벽 아래 배출구들이 한 박자에 한 줄씩 냉각 플라스마(잔탄)를 뿜어 화면 전체에 미로를 짓는다.
## 줄마다 빈틈(통로)이 하나 있고, 줄은 천천히 내려온다. 플레이어는 아래에서 통로를 갈아타며 올라간다 (docs/BOSS_capacitor.md 6·6-b장).
## 관성 조작에서 억울하지 않게: 통로는 돌진 한 번 거리보다 넓고(GAP_W), 줄 사이 통로가 옮겨 가는 거리는 MAX_SHIFT 이하,
## 줄은 한 겹(돌진 무적으로 뚫린다), 다음 줄의 통로는 배출구에 미리 보인다(예고).
## 모드: zigzag(통로가 좌우로 엇갈림) · snake(통로가 물결처럼 휘어짐) · funnel(통로가 좁아졌다 넓어짐)
## 패턴 끝 줄의 통로에 금색 주탄 하나 (기회 탄): 패리 → 리버스 드라이브로 방벽 너머 방열판을 친다.
## boss 에 필요한 것: SPAWN_Y, vent_glow(x, v), last_gap_x, shots, bolt_mult(), emit

const Projectiles := preload("res://scripts/projectiles.gd")
const ROWS := 6
const ROW_T := 2.3                   # 줄 간격 (초)
const PREVIEW := 0.7                 # 다음 줄의 통로가 배출구에 미리 보이는 시간
const SPEED := 175.0                 # 줄이 내려오는 빠르기
const GAP_W := 640.0                 # 통로 폭 (돌진 한 번 ≈ 560px 보다 넓게)
const FUNNEL_MIN := 600.0
const FUNNEL_MAX := 900.0
const MAX_SHIFT := 720.0             # 줄 사이 통로가 옮겨 가는 거리 상한 (경기장 폭의 1/3 이하)
const DOT := 62.0                    # 줄 안의 잔탄 간격
const X0 := -1130.0
const X1 := 1130.0
const LIFE := 16.0
const GOLD_SPEED_K := 1.0            # 주탄은 줄과 같이 내려온다 (통로 안에 머문다)

var mode := "zigzag"
var gold := true
var rows_fired := 0
var gaps: Array[float] = []          # 줄마다 통로 가운데 x
var widths: Array[float] = []


func _init(m := "zigzag", with_gold := true) -> void:
	kind = "maze"
	mode = m
	gold = with_gold


func _plan() -> void:
	var x: float = boss.last_gap_x
	var phase0 := randf() * TAU
	var dirn := 1.0 if randf() < 0.5 else -1.0
	for k in ROWS:
		var w := GAP_W
		var want := x
		match mode:
			"zigzag":                                  # 좌우로 엇갈린다 (끝까지는 안 간다)
				want = x + dirn * randf_range(380.0, MAX_SHIFT)
				dirn = -dirn
			"snake":                                   # 물결처럼 휘어진다
				want = sin(phase0 + k * 0.9) * 700.0
			"funnel":                                  # 가운데로 모였다가 다시 넓어진다
				want = x * 0.5
				w = lerpf(FUNNEL_MAX, FUNNEL_MIN, sin(PI * k / float(ROWS - 1)))
		want = clampf(want, X0 + w * 0.5 + 40.0, X1 - w * 0.5 - 40.0)
		want = clampf(want, x - MAX_SHIFT, x + MAX_SHIFT)
		gaps.append(want)
		widths.append(w)
		x = want
	boss.last_gap_x = x


func step(_dt: float, _ppos: Vector2) -> void:
	if gaps.is_empty():
		_plan()
	while rows_fired < ROWS and t >= rows_fired * ROW_T + PREVIEW:
		_fire_row(rows_fired)
		rows_fired += 1
	if rows_fired < ROWS:                               # 다음 줄의 통로가 배출구에 미리 보인다
		var k := clampf(1.0 - (rows_fired * ROW_T + PREVIEW - t) / PREVIEW, 0.0, 1.0)
		boss.vent_glow_row(gaps[rows_fired], widths[rows_fired], k)
	if rows_fired >= ROWS and t >= (ROWS - 1) * ROW_T + PREVIEW + ROW_T - PREVIEW:   # 다음 패턴의 첫 줄이 같은 간격으로 이어지게
		boss.finish_attack()


func _fire_row(k: int) -> void:
	var g: float = gaps[k]
	var w: float = widths[k]
	var v := Vector2(0, SPEED * boss.bolt_mult())
	var x := X0
	while x <= X1:
		if absf(x - g) > w * 0.5:
			boss.shots.spawn(Vector2(x, boss.SPAWN_Y), v, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
		x += DOT
	if gold and k == ROWS - 1:                          # 마지막 줄의 통로에 금색 주탄 하나 (기회 탄)
		boss.shots.spawn(Vector2(g, boss.SPAWN_Y), v * GOLD_SPEED_K, LIFE)
	boss.emit(Ev.BOLT, Vector2(g, boss.SPAWN_Y))


## 통로 정보 (테스트·점검용): 줄마다 [통로 가운데, 폭]
func lanes() -> Array:
	var out := []
	for k in gaps.size():
		out.append([gaps[k], widths[k]])
	return out
