extends "res://scripts/attacks/attack.gd"
## 방전 그물 (패리 불가 = 검붉은 보라): 배경의 바깥 다리 둘이 경기장 위·아래 끝에 끝을 대고, 그 사이에 이어진 보라 전류 띠가
## 경기장을 왼쪽→오른쪽(또는 오른쪽→왼쪽)으로 훑는다. (v0.49: 아래→위로 올라오던 방향은 없앴다 — 낙하·아래 위치와 겹쳐 너무 어려웠다)
## 경기장 높이 전체를 가로지르므로 돌진의 무적으로 통과해야 한다. 돌진 직후 스치면 강한 퍼펙트 회피(완전 동조).
## 그림은 판정과 같은 폭만 칠한다: 맞는 범위 = 그려진 밝은 띠 (그 밖의 보라 번짐·예고 영역은 없다)
## 단계: wind(다리가 출발선에 자리 잡고 그 띠가 점멸 + 진행 방향 화살표) → sweep(훑기) → 끝
## boss 에 필요한 것: bg_hold (배경 다리 끝 위치 덮어쓰기)

const WIND := 1.5
const SWEEP := 3.2
const HALF := 30.0                   # 판정 반폭 (그림의 띠와 같다)
const WALL := 1150.0
const HIGH := -3100.0                # 띠의 위·아래 끝 (천장 ~ 융해 지대)
const LOW := 0.0
const LEG_TOP := -2880.0             # 다리 끝이 닿는 높이
const LEG_BOTTOM := -180.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var x0 := -WALL - 60.0
var x1 := WALL + 60.0
var x := 0.0
var x_prev := 0.0


## to_right: 왼쪽에서 오른쪽으로 훑는다 (false 면 반대)
func _init(to_right: bool) -> void:
	kind = "net"
	phase = "wind"
	if not to_right:
		x0 = WALL + 60.0
		x1 = -WALL - 60.0
	x = x0
	x_prev = x0


func _hold() -> void:
	boss.bg_hold = [Vector2(x, LEG_TOP), Vector2(x, LEG_BOTTOM)]


func step(_dt: float, _ppos: Vector2) -> void:
	match phase:
		"wind":
			_hold()
			if t >= WIND:
				set_phase("sweep")
				boss.emit(Ev.BEAM, Vector2(x, -1500.0))
		"sweep":
			var k := minf(1.0, t / SWEEP)
			x_prev = x
			x = lerpf(x0, x1, k * k * (3.0 - 2.0 * k) * 0.3 + k * 0.7)
			_hold()
			if k >= 1.0:
				boss.bg_hold = []
				boss.finish_attack()


## 다가오는 띠의 플레이어 쪽 지점 (화면 밖이면 HUD 가 보라 ⚠ + 화살표). 이미 지나갔으면 없음
func unparry_point(ppos: Vector2) -> Vector2:
	if (ppos.x - x) * signf(x1 - x0) < -HALF:
		return Vector2.INF
	return Vector2(x, ppos.y)


## 이번 프레임에 띠가 쓸고 지나간 가로 구간 안이면 맞는다 → 훑는 방향으로 밀려난다
func beam_hit(p: Vector2, r: float) -> Vector2:
	if phase != "sweep":
		return Vector2.ZERO
	var lo := minf(x_prev, x) - HALF - r
	var hi := maxf(x_prev, x) + HALF + r
	if p.x < lo or p.x > hi:
		return Vector2.ZERO
	return Vector2(signf(x1 - x0), -0.25).normalized()


func draw() -> void:
	var c: CanvasItem = boss
	var bt: float = boss.t
	var dir := signf(x1 - x0)
	var blink := 0.65 + 0.35 * sin(bt * 24.0)
	if phase == "wind":
		var kk := clampf(t / WIND, 0.0, 1.0)
		# 출발선: 맞게 될 바로 그 폭의 띠가 점멸 (위·아래 끝 눈금 + 진행 방향 화살표)
		c.draw_rect(Rect2(x - HALF, HIGH, HALF * 2.0, LOW - HIGH), Color(C_UNPARRY, (0.18 + 0.3 * kk) * blink))
		c.draw_line(Vector2(x - HALF, HIGH), Vector2(x - HALF, LOW), Color(C_UNPARRY_CORE, 0.5 + 0.4 * kk), 3.0)
		c.draw_line(Vector2(x + HALF, HIGH), Vector2(x + HALF, LOW), Color(C_UNPARRY_CORE, 0.5 + 0.4 * kk), 3.0)
		for q in 7:
			var ay := -2700.0 + q * 400.0
			var ax := x + dir * (170.0 + 60.0 * fmod(bt * 1.5 + q * 0.13, 1.0))
			c.draw_colored_polygon(PackedVector2Array([Vector2(ax + dir * 40.0, ay), Vector2(ax - dir * 10.0, ay - 30.0), Vector2(ax - dir * 10.0, ay + 30.0)]),
				Color(C_UNPARRY_CORE, 0.25 + 0.5 * kk))
		return
	if phase != "sweep":
		return
	# 띠: 판정과 같은 폭(±HALF)의 단단한 보라 + 밝은 가장자리 + 안쪽 전류 세 가닥 + 띠 안에서만 튀는 불꽃
	c.draw_rect(Rect2(x - HALF, HIGH, HALF * 2.0, LOW - HIGH), Color(C_UNPARRY, 0.9))
	c.draw_line(Vector2(x - HALF, HIGH), Vector2(x - HALF, LOW), Color(C_UNPARRY_CORE, 0.95), 4.0)
	c.draw_line(Vector2(x + HALF, HIGH), Vector2(x + HALF, LOW), Color(C_UNPARRY_CORE, 0.95), 4.0)
	for strand in 3:
		var zz := PackedVector2Array()
		var ox := x + (strand - 1) * HALF * 0.5
		for q in 48:
			var y := HIGH + q * ((LOW - HIGH) / 47.0)
			zz.append(Vector2(ox + randf_range(-HALF * 0.35, HALF * 0.35), y))
		c.draw_polyline(zz, Color(C_UNPARRY_CORE, 0.9 - strand * 0.15), 4.0)
	for q in 14:
		var sy := randf_range(HIGH, LOW)
		var sx := x + randf_range(-HALF, HALF)
		c.draw_line(Vector2(sx, sy), Vector2(sx + randf_range(-HALF, HALF) * 0.6, sy + randf_range(-40.0, 40.0)), Color(1, 1, 1, 0.8), 2.5)
