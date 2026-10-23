extends "res://scripts/attacks/attack.gd"
## 냉각 미로 (반응로, 지형 탄 = 잔탄): 배출구들이 한 박자에 한 줄씩 냉각 플라스마(잔탄)를 **빈틈없이** 뿜어, 화면을 채운 잔탄 벽에 좁은 길을 판다.
## 벽은 빽빽해서(격자 DOT×DY, 기체가 사이로 못 빠진다) 길로만 다닐 수 있다. 길은 천천히 내려오고, 플레이어는 아래에서 길을 따라 올라간다.
## 다음 줄의 길 자리는 배출구가 꺼져 미리 보인다. 길은 한 줄마다 MAX_STEP 이상 옆으로 튀지 않는다 (관성 조작에서 따라갈 수 있게).
## 모드 여섯 (docs/BOSS_capacitor.md 6장):
##   snake  — 한 줄기 길이 크게 굽이친다
##   zigzag — 비스듬한 길이 좌우로 꺾인다
##   steps  — 곧은 길이 내려오다 가로로 트인 방을 지나 옆으로 계단처럼 옮겨 간다
##   rooms  — 넓은 방들이 좁은 목으로 이어지며 좌우로 번갈아 놓인다
##   fork   — 길이 섬을 사이에 두고 두 갈래로 갈라졌다 다시 만난다
##   braid  — 두 길이 꼬아 엮이며 교차할 때마다 하나로 만난다
## 패턴 끝 무렵 길 안에 금색 주탄 하나 (기회 탄): 패리 → 리버스 드라이브로 방벽 너머 방열판을 친다.
## boss 에 필요한 것: SPAWN_Y, vent_open(holes, k), last_gap_x, shots, bolt_mult(), emit

const Projectiles := preload("res://scripts/projectiles.gd")
const SPEED := 150.0                 # 벽이 내려오는 빠르기
const DY := 40.0                     # 줄 간격 (px) — 기체(지름 24)가 줄 사이로 못 끼게
const DOT := 40.0                    # 줄 안의 잔탄 간격
const LEN := 2200.0                  # 패턴 하나의 길이 (px) ≈ 15초
const CORR_W := 320.0                # 길 폭 (탄 중심 사이)
const ROOM_W := 720.0
const NECK_W := 280.0
const MAX_STEP := 34.0               # 한 줄마다 길이 옆으로 옮겨 가는 최대 거리 (기울기 ≈ 40도)
const X0 := -1130.0
const X1 := 1130.0
const EDGE := 60.0                   # 길이 경기장 벽에 붙지 않게
const LIFE := 15.0
const GOLD_BACK := 6                 # 끝에서 이만큼 앞 줄의 길에 금색 주탄
const PREVIEW_ROWS := 6              # 배출구에 미리 보여 주는 줄 수

const MODES := ["snake", "zigzag", "steps", "rooms", "fork", "braid"]

var mode := "snake"
var gold := true
var rows: Array = []                 # 줄마다 열린 구간들 [[x0, x1], ...]
var fired := 0


func _init(m := "snake", with_gold := true) -> void:
	kind = "maze"
	mode = m
	gold = with_gold


func row_count() -> int:
	return int(LEN / DY)


## 길 계획: 모드마다 줄별 목표 중심을 정하고, 한 줄에 MAX_STEP 이상 못 옮겨 가게 다듬어 열린 구간을 만든다
func _plan() -> void:
	var n := row_count()
	var c: float = boss.last_gap_x
	var ph := randf() * TAU
	var sd := 1.0 if randf() < 0.5 else -1.0
	var spread := 0.0
	for k in n:
		var u := float(k) / float(n - 1)
		var holes := []
		match mode:
			"snake":
				c = _toward(c, 680.0 * sin(ph + u * TAU * 1.3))
				holes.append(_iv(c, CORR_W))
			"zigzag":                                      # 14줄마다 꺾이는 비스듬한 길
				var target := sd * 720.0 * (1.0 if (k / 14) % 2 == 0 else -1.0)
				c = _toward(c, target)
				holes.append(_iv(c, CORR_W))
			"steps":                                       # 곧게 내려오다(10줄) 가로로 트인 방(3줄)을 지나 옆으로
				var seg := k % 13
				var step_i := k / 13
				var cx := clampf(float(boss.last_gap_x) + sd * 520.0 * float(step_i % 2 * 2 - 1) * (1.0 if step_i > 0 else 0.0), X0 + 300.0, X1 - 300.0)
				var nx := clampf(float(boss.last_gap_x) + sd * 520.0 * float((step_i + 1) % 2 * 2 - 1), X0 + 300.0, X1 - 300.0)
				if seg >= 10:                              # 방: 지금 길과 다음 길을 다 덮는 가로 구간
					holes.append([minf(cx, nx) - CORR_W * 0.5, maxf(cx, nx) + CORR_W * 0.5])
					c = nx
				else:
					c = cx
					holes.append(_iv(c, CORR_W))
			"rooms":                                       # 방 12줄 + 목 5줄, 방은 좌우 번갈아
				var seg := k % 17
				var side := 1.0 if (k / 17) % 2 == 0 else -1.0
				if seg < 5:
					c = _toward(c, 0.0)
					holes.append(_iv(c, NECK_W))
				else:
					c = _toward(c, side * sd * 330.0)
					holes.append([c - ROOM_W * 0.5, c + ROOM_W * 0.5])
			"fork":                                        # 가운데 섬: 두 갈래로 벌어졌다 모인다
				c = _toward(c, 0.0)
				var want := 430.0 * clampf(sin(PI * clampf((u - 0.15) / 0.7, 0.0, 1.0)), 0.0, 1.0)
				spread = clampf(want, spread - MAX_STEP, spread + MAX_STEP)    # 갈래도 한 줄에 MAX_STEP 이상 벌어지지 않게
				if spread < CORR_W * 0.35 - MAX_STEP:                         # 갈라지고 모이는 줄도 앞 줄과 넉넉히 겹치게
					holes.append(_iv(c, CORR_W))
				else:
					holes.append(_iv(c - spread, CORR_W))
					holes.append(_iv(c + spread, CORR_W))
			"braid":                                       # 두 길이 꼬여 엮인다 (교차하는 곳에서 하나로)
				c = _toward(c, 0.0)
				var a := 560.0 * clampf(u * 4.0, 0.0, 1.0) * sin(ph + u * TAU * 1.5)
				holes.append(_iv(c + a, CORR_W))
				holes.append(_iv(c - a, CORR_W))
		rows.append(holes)
	boss.last_gap_x = c


func _toward(c: float, target: float) -> float:
	return clampf(c + clampf(target - c, -MAX_STEP, MAX_STEP), X0 + EDGE + CORR_W * 0.5, X1 - EDGE - CORR_W * 0.5)


func _iv(c: float, w: float) -> Array:
	return [c - w * 0.5, c + w * 0.5]


func _row_t() -> float:
	return DY / (SPEED * boss.bolt_mult())


func step(_dt: float, _ppos: Vector2) -> void:
	if rows.is_empty():
		_plan()
	var rt := _row_t()
	while fired < rows.size() and t >= fired * rt:
		_fire_row(fired)
		fired += 1
	if fired < rows.size():                             # 다음 줄들의 길이 배출구에 미리 보인다
		boss.vent_open(rows[mini(rows.size() - 1, fired + PREVIEW_ROWS / 2)], 1.0)
	if fired >= rows.size() and t >= rows.size() * rt:
		boss.finish_attack()


func _fire_row(k: int) -> void:
	var holes: Array = rows[k]
	var v := Vector2(0, SPEED * boss.bolt_mult())
	var x := X0
	while x <= X1:
		var open := false
		for h in holes:
			if x > float(h[0]) and x < float(h[1]):
				open = true
				break
		if not open:
			boss.shots.spawn(Vector2(x, boss.SPAWN_Y), v, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
		x += DOT
	if gold and k == rows.size() - GOLD_BACK:          # 끝 무렵 길 안에 금색 주탄 하나 (기회 탄)
		var h: Array = holes[randi() % holes.size()]
		boss.shots.spawn(Vector2((float(h[0]) + float(h[1])) * 0.5, boss.SPAWN_Y), v, LIFE)
	if k % 4 == 0:
		boss.emit(Ev.BOLT, Vector2(0, boss.SPAWN_Y))


## 줄마다 열린 구간 (테스트·점검용)
func lanes() -> Array:
	return rows
