extends "res://scripts/attacks/attack.gd"
## 격자 (결계 위성, 패리 불가 = 보라): 경기장 전체에 가로세로 결계선이 그어졌다가(예고) 번쩍인다. 차례마다 반 칸 어긋난다.
## 겉보기엔 화면이 보라 격자로 덮이지만 실제 판정은 번쩍이는 순간의 가는 선뿐 — 칸 안에 머물거나, 번쩍이는 순간 선을 뚫는다.
## 회피 처리는 차례 단위 (뚫은 차례만 더는 맞지 않는다)

const ROUNDS := 3
const WARN := 0.95                   # 예고 (옅은 선이 짙어진다)
const FLASH := 0.3                   # 번쩍 (판정)
const REST := 0.2
const STEP := 430.0                  # 선 간격 (칸 크기)
const HALF := 14.0
const WALL := 1150.0
const TOP := -3080.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var done := 0
var dodged_rounds: Array[int] = []
var off := Vector2.ZERO


func _init() -> void:
	kind = "lattice"
	off = Vector2(randf() * STEP, randf() * STEP)


func _round_t() -> float:
	return WARN + FLASH + REST


func _cur() -> int:
	return int(t / _round_t())


func _local() -> float:
	return fmod(t, _round_t())


func _xs(k: int) -> Array[float]:
	var out: Array[float] = []
	var x := -WALL + fposmod(off.x + (STEP * 0.5 if k % 2 == 1 else 0.0), STEP)
	while x < WALL:
		out.append(x)
		x += STEP
	return out


func _ys(k: int) -> Array[float]:
	var out: Array[float] = []
	var y := TOP + fposmod(off.y + (STEP * 0.5 if k % 2 == 1 else 0.0), STEP)
	while y < 0.0:
		out.append(y)
		y += STEP
	return out


func step(_dt: float, _ppos: Vector2) -> void:
	if _cur() >= ROUNDS:
		boss.finish_attack()
		return
	var k := _cur()
	if done <= k and _local() >= WARN:
		done = k + 1
		boss.emit(Ev.BEAM, Vector2(0, -1500))


func _flashing() -> bool:
	return _cur() < ROUNDS and _local() >= WARN and _local() < WARN + FLASH


func _hit_round(p: Vector2, r: float) -> int:
	if not _flashing():
		return -1
	var k := _cur()
	if dodged_rounds.has(k):
		return -1
	for x in _xs(k):
		if absf(p.x - x) < HALF + r:
			return k
	for y in _ys(k):
		if absf(p.y - y) < HALF + r:
			return k
	return -1


func beam_hit(p: Vector2, r: float) -> Vector2:
	return Vector2.UP if _hit_round(p, r) >= 0 else Vector2.ZERO


func mark_dodged(p: Vector2, r: float) -> void:
	var k := _hit_round(p, r)
	if k >= 0:
		dodged_rounds.append(k)


func unparry_point(ppos: Vector2) -> Vector2:
	return ppos


func draw() -> void:
	if _cur() >= ROUNDS:
		return
	var c: CanvasItem = boss
	var k := _cur()
	var lt := _local()
	var flash := lt >= WARN and lt < WARN + FLASH
	var kk := clampf(lt / WARN, 0.0, 1.0)
	var dim := 0.35 if dodged_rounds.has(k) else 1.0
	for x in _xs(k):
		_line(c, Vector2(x, TOP), Vector2(x, 0), flash, kk, dim)
	for y in _ys(k):
		_line(c, Vector2(-WALL, y), Vector2(WALL, y), flash, kk, dim)


func _line(c: CanvasItem, a: Vector2, b: Vector2, flash: bool, kk: float, dim: float) -> void:
	if flash:
		c.draw_line(a, b, Color(C_UNPARRY, 0.12 * dim), 120.0)          # 넓은 빛무리 (판정 없음)
		c.draw_line(a, b, Color(C_UNPARRY, 0.8 * dim), 22.0)
		c.draw_line(a, b, Color(C_UNPARRY_CORE, 0.95 * dim), 6.0)
	else:
		c.draw_line(a, b, Color(C_UNPARRY, 0.06 + 0.12 * kk), 60.0 * kk)
		c.draw_line(a, b, Color(C_UNPARRY_CORE, 0.12 + 0.4 * kk), 2.0)
