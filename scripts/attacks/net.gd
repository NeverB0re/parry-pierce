extends "res://scripts/attacks/attack.gd"
## 방전 그물 (패리 불가 = 검붉은 보라): 배경의 바깥 다리 둘이 양쪽 벽에 끝을 대고, 그 사이에 이어진 보라 전류선이 경기장을 위→아래(또는 아래→위)로 훑는다.
## 경기장 전체를 가로지르므로 돌진의 무적으로 통과해야 한다. 돌진 직후 스치면 강한 퍼펙트 회피(완전 동조).
## 단계: wind(다리가 벽을 짚고, 출발선이 점멸 + 진행 방향 화살표) → sweep(훑기) → 끝
## boss 에 필요한 것: bg_hold (배경 다리 끝 위치 덮어쓰기)

const WIND := 1.5
const SWEEP := 3.4                   # v0.48: 2.0 → 3.4 (화면이 세로로 짧아 너무 빨리 들이닥쳤다)
const HALF := 30.0                   # 판정 반폭 (v0.48: 16 → 30, 두껍고 압도적으로)
const WALL := 1150.0
const HIGH := -2950.0
const LOW := -150.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var y0 := HIGH
var y1 := LOW
var y := HIGH
var y_prev := HIGH


## down: 위에서 아래로 훑는다 (false 면 아래에서 위로)
func _init(down: bool) -> void:
	kind = "net"
	phase = "wind"
	if not down:
		y0 = LOW
		y1 = HIGH
	y = y0
	y_prev = y0


func step(_dt: float, _ppos: Vector2) -> void:
	match phase:
		"wind":
			boss.bg_hold = [Vector2(-WALL, y), Vector2(WALL, y)]
			if t >= WIND:
				set_phase("sweep")
				boss.emit(Ev.BEAM, Vector2(0, y))
		"sweep":
			var k := minf(1.0, t / SWEEP)
			y_prev = y
			y = lerpf(y0, y1, k * k * (3.0 - 2.0 * k) * 0.3 + k * 0.7)
			boss.bg_hold = [Vector2(-WALL, y), Vector2(WALL, y)]
			if k >= 1.0:
				boss.bg_hold = []
				boss.finish_attack()


## 다가오는 선의 플레이어 쪽 지점 (화면 밖이면 HUD 가 보라 ⚠ + 화살표). 이미 지나갔으면 없음
func unparry_point(ppos: Vector2) -> Vector2:
	if (ppos.y - y) * signf(y1 - y0) < -HALF:
		return Vector2.INF
	return Vector2(ppos.x, y)


## 이번 프레임에 선이 쓸고 지나간 높이 구간 안이면 맞는다 → 훑는 방향으로 밀려난다
func beam_hit(p: Vector2, r: float) -> Vector2:
	if phase != "sweep":
		return Vector2.ZERO
	var lo := minf(y_prev, y) - HALF - r
	var hi := maxf(y_prev, y) + HALF + r
	if p.y < lo or p.y > hi:
		return Vector2.ZERO
	return Vector2(0, signf(y1 - y0))


func draw() -> void:
	var c: CanvasItem = boss
	var bt: float = boss.t
	var dir := signf(y1 - y0)
	if phase == "wind":
		var kk := clampf(t / WIND, 0.0, 1.0)
		var blink := 0.65 + 0.35 * sin(bt * 24.0)
		# 훑고 지나갈 경기장 전체를 옅게 + 출발선 점멸 + 진행 방향 화살표
		c.draw_rect(Rect2(-WALL, minf(y0, y1), WALL * 2.0, absf(y1 - y0)), Color(C_UNPARRY, 0.05 + 0.06 * kk * blink))
		c.draw_line(Vector2(-WALL, y0), Vector2(WALL, y0), Color(C_UNPARRY_CORE, (0.3 + 0.6 * kk) * blink), 3.0 + 7.0 * kk)
		for q in 7:
			var ax := -900.0 + q * 300.0
			var ay := y0 + dir * (160.0 + 60.0 * fmod(bt * 1.5 + q * 0.13, 1.0))
			c.draw_colored_polygon(PackedVector2Array([Vector2(ax, ay + dir * 40.0), Vector2(ax - 30.0, ay - dir * 10.0), Vector2(ax + 30.0, ay - dir * 10.0)]),
				Color(C_UNPARRY_CORE, 0.25 + 0.5 * kk))
		return
	if phase != "sweep":
		return
	# 아직 훑지 않은 쪽을 옅게. 선은 넓은 번짐 + 두꺼운 띠 + 전류 세 가닥 + 튀는 불꽃 (압도적으로)
	var rest_top := minf(y, y1)
	c.draw_rect(Rect2(-WALL, rest_top, WALL * 2.0, absf(y1 - y)), Color(C_UNPARRY, 0.07))
	for g in 4:                                       # 진행 방향 앞쪽으로 번지는 빛
		c.draw_line(Vector2(-WALL, y + dir * (40.0 + g * 45.0)), Vector2(WALL, y + dir * (40.0 + g * 45.0)), Color(C_UNPARRY, 0.12 - g * 0.025), 40.0)
	c.draw_line(Vector2(-WALL, y), Vector2(WALL, y), Color(C_UNPARRY, 0.3), 170.0)
	c.draw_line(Vector2(-WALL, y), Vector2(WALL, y), Color(C_UNPARRY, 0.85), HALF * 2.0)
	for strand in 3:
		var zz := PackedVector2Array()
		for q in 47:
			var x := -WALL + q * (WALL * 2.0 / 46.0)
			zz.append(Vector2(x, y + randf_range(-HALF, HALF) * (0.5 + 0.25 * strand)))
		c.draw_polyline(zz, Color(C_UNPARRY_CORE, 0.95 - strand * 0.25), 6.0 - strand * 1.5)
	for q in 10:                                      # 튀는 불꽃
		var sx := randf_range(-WALL, WALL)
		var sv := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(30.0, 90.0)
		c.draw_line(Vector2(sx, y), Vector2(sx, y) + sv, Color(C_UNPARRY_CORE, 0.8), 3.0)
	c.draw_line(Vector2(-WALL, y + dir * 220.0), Vector2(WALL, y + dir * 220.0), Color(C_UNPARRY, 0.2), 4.0)   # 앞쪽 희미한 예고선
