extends "res://scripts/attacks/attack.gd"
## 격자 (결계 위성, 패리 불가 = 보라): 경기장에 결계선이 네 차례에 걸쳐 늘어난다 — 넓은 세로줄 → 넓은 가로줄 → 세로줄 사이 → 가로줄 사이.
## 한 번 켜진 선은 끝날 때까지 그 자리에 남아(판정 유지) 점점 칸이 좁아진다. 새 선은 WARN 동안 옅게 예고된 뒤 켜진다 (갑자기 내 자리에 생기지 않는다).
## 겉보기엔 화면이 보라 격자로 덮이지만 실제 판정은 가는 선뿐 — 칸 안에 머물거나, 선을 돌진으로 뚫는다 (퍼펙트 회피 = 그 선의 에너지를 빨아들여 선이 사라진다)
## 흡수(dodged)는 선 하나 단위

const ROUNDS := 4
const WARN := 0.7                    # 새 선 예고 (옅게 나타나 짙어진다)
const STEP_T := 0.8                  # 차례 간격 (v0.125: 1.35 → 0.8, 패턴 전체 6.65초 → 4초)
const HOLD := 0.9                    # 마지막 선이 켜진 뒤 이만큼 더 남는다
const STEP := 520.0                  # 마지막 칸 크기 (처음 두 차례는 그 두 배)
const HALF := 14.0
const WALL := 1150.0
const TOP := -3080.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var lines: Array[Dictionary] = []    # {vert, at, round}
var absorbed: Array[int] = []        # 퍼펙트 회피로 빨아들여 사라진 선
var fired := 0


func _init() -> void:
	kind = "lattice"
	var off := Vector2(randf() * STEP * 2.0, randf() * STEP * 2.0)
	for x in _spaced(-WALL, WALL, off.x, STEP * 2.0):
		lines.append({"vert": true, "at": x, "round": 0})
	for y in _spaced(TOP, 0.0, off.y, STEP * 2.0):
		lines.append({"vert": false, "at": y, "round": 1})
	for x in _spaced(-WALL, WALL, off.x + STEP, STEP * 2.0):
		lines.append({"vert": true, "at": x, "round": 2})
	for y in _spaced(TOP, 0.0, off.y + STEP, STEP * 2.0):
		lines.append({"vert": false, "at": y, "round": 3})


static func _spaced(lo: float, hi: float, o: float, gap: float) -> Array[float]:
	var out: Array[float] = []
	var v := lo + fposmod(o, gap)
	while v < hi:
		out.append(v)
		v += gap
	return out


## 선 i 가 켜지는 시각
func _on_at(i: int) -> float:
	return int(lines[i]["round"]) * STEP_T + WARN


func _end_t() -> float:
	return (ROUNDS - 1) * STEP_T + WARN + HOLD


func step(_dt: float, _ppos: Vector2) -> void:
	while fired < ROUNDS and t >= fired * STEP_T + WARN:
		fired += 1
		boss.emit(Ev.BEAM, Vector2(0, -1500))
	if t >= _end_t():
		boss.finish_attack()


## p 에 닿은 켜진 선 (흡수한 선 제외). 없으면 -1
func _line_at(p: Vector2, r: float) -> int:
	for i in lines.size():
		if absorbed.has(i) or t < _on_at(i):
			continue
		var ln: Dictionary = lines[i]
		var d: float = (p.x if ln["vert"] else p.y) - float(ln["at"])
		if absf(d) < HALF + r:
			return i
	return -1


func beam_hit(p: Vector2, r: float) -> Vector2:
	var i := _line_at(p, r)
	if i < 0:
		return Vector2.ZERO
	var ln: Dictionary = lines[i]
	var d: float = (p.x if ln["vert"] else p.y) - float(ln["at"])
	var s := 1.0 if d >= 0.0 else -1.0
	return Vector2(s, -0.3).normalized() if ln["vert"] else Vector2(0, s)


func mark_dodged(p: Vector2, r: float) -> void:
	var i := _line_at(p, r)
	if i >= 0:
		absorbed.append(i)


func unparry_point(ppos: Vector2) -> Vector2:
	return ppos


func draw() -> void:
	var c: CanvasItem = boss
	var fl := 0.9 + 0.1 * sin(boss.t * 30.0)
	for i in lines.size():
		if absorbed.has(i):
			continue
		var ln: Dictionary = lines[i]
		var start: float = int(ln["round"]) * STEP_T
		if t < start:
			continue
		var at: float = ln["at"]
		var a := Vector2(at, TOP) if ln["vert"] else Vector2(-WALL, at)
		var b := Vector2(at, 0) if ln["vert"] else Vector2(WALL, at)
		if t < _on_at(i):                                   # 예고: 옅게 나타나 짙어진다
			var kk := (t - start) / WARN
			c.draw_line(a, b, Color(C_UNPARRY, 0.05 + 0.12 * kk), 60.0 * kk)
			c.draw_line(a, b, Color(C_UNPARRY_CORE, 0.12 + 0.4 * kk), 2.0)
			continue
		var pop := maxf(0.0, 1.0 - (t - _on_at(i)) / 0.25)    # 켜지는 순간 번쩍
		c.draw_line(a, b, Color(C_UNPARRY, 0.1 + 0.15 * pop), 110.0 * fl)    # 넓은 빛무리 (판정 없음)
		c.draw_line(a, b, Color(C_UNPARRY, 0.75), 20.0 + 10.0 * pop)
		c.draw_line(a, b, Color(C_UNPARRY_CORE, 0.95), 5.0 + 3.0 * pop)
