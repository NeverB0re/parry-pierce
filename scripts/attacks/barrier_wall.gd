extends "res://scripts/attacks/attack.gd"
## 결계면 (결계 위성, 패리 불가 = 보라): 경기장 한쪽 끝에서 반대쪽으로 화면 높이 전체의 보라 벽이 밀려온다.
## 피할 곳이 없다 → 벽이 지나가는 순간 돌진으로 뚫어야 한다 (완전 동조의 정석 기회). 한 번 뚫으면 그 벽은 더 맞지 않는다 (dodged).
## 플레이어에게서 먼 쪽에서 출발한다. 예고 동안 출발선이 달아오르고 밀려올 방향이 화살표로 보인다

const WIND := 1.0
const MOVE := 3.6                    # 끝에서 끝까지
const HALF := 30.0                   # 판정 반폭 (돌진 무적 0.16초 안에 지나갈 두께)
const WALL := 1150.0
const TOP := -3080.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var x0 := -WALL
var x1 := WALL
var x := -WALL
var x_prev := -WALL


func _init(ppos: Vector2) -> void:
	kind = "wall"
	phase = "wind"
	if ppos.x < 0.0:                     # 플레이어가 왼쪽이면 오른쪽 끝에서 출발
		x0 = WALL
		x1 = -WALL
	x = x0
	x_prev = x0


func step(_dt: float, _ppos: Vector2) -> void:
	match phase:
		"wind":
			if t >= WIND:
				phase = "move"
				t = 0.0
				boss.emit(Ev.BEAM, Vector2(x0, -1500))
		"move":
			x_prev = x
			x = lerpf(x0, x1, minf(1.0, t / MOVE))
			if t >= MOVE:
				boss.finish_attack()


func unparry_point(ppos: Vector2) -> Vector2:
	return Vector2(x, ppos.y)


func beam_hit(p: Vector2, r: float) -> Vector2:
	if phase != "move":
		return Vector2.ZERO
	var lo := minf(x_prev, x) - HALF - r
	var hi := maxf(x_prev, x) + HALF + r
	if p.x < lo or p.x > hi or p.y < TOP or p.y > 0.0:
		return Vector2.ZERO
	return Vector2(signf(x1 - x0), -0.25).normalized()


func draw() -> void:
	var c: CanvasItem = boss
	var dir := signf(x1 - x0)
	if phase == "wind":
		var kk := clampf(t / WIND, 0.0, 1.0)
		var blink := 0.6 + 0.4 * sin(boss.t * 22.0)
		c.draw_rect(Rect2(x0 - HALF, TOP, HALF * 2.0, -TOP), Color(C_UNPARRY, 0.12 + 0.2 * kk))
		c.draw_line(Vector2(x0, TOP), Vector2(x0, 0), Color(C_UNPARRY_CORE, (0.3 + 0.5 * kk) * blink), 3.0 + 5.0 * kk)
		for j in 6:                                       # 밀려올 방향 화살표
			var y := TOP * (j + 0.5) / 6.0
			var tip := Vector2(x0 + dir * (90.0 + 60.0 * kk), y)
			c.draw_colored_polygon(PackedVector2Array([tip, tip - Vector2(dir * 40.0, 22.0), tip - Vector2(dir * 40.0, -22.0)]), Color(C_UNPARRY_CORE, 0.2 + 0.45 * kk))
		return
	var fl := 0.9 + 0.2 * sin(boss.t * 30.0)
	c.draw_rect(Rect2(x - HALF * 3.0, TOP, HALF * 6.0, -TOP), Color(C_UNPARRY, 0.12))
	c.draw_rect(Rect2(x - HALF, TOP, HALF * 2.0, -TOP), Color(C_UNPARRY, 0.6 * fl))
	c.draw_line(Vector2(x, TOP), Vector2(x, 0), Color(C_UNPARRY_CORE, 0.95), 6.0)
	var y := fposmod(boss.t * 400.0, 260.0) + TOP         # 벽을 타고 흐르는 결계 무늬
	while y < 0.0:
		c.draw_line(Vector2(x - HALF, y), Vector2(x + HALF, y + 40.0), Color(1, 0.85, 0.95, 0.35), 3.0)
		y += 260.0
