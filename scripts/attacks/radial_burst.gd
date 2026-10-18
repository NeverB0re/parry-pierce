extends "res://scripts/attacks/attack.gd"
## 결계 폭풍 (결계 위성, 패리 불가 = 보라): 결계에서 광선 N 줄기가 사방으로 뻗어 천천히 돈다.
## 겉보기엔 화면을 가득 채우지만(넓고 옅은 빛무리) 실제 판정은 가는 심줄뿐 — 줄기 사이로 피하거나, 다가오는 줄기를 돌진으로 뚫는다 (완전 동조 기회).
## 흡수는 줄기 단위 (퍼펙트 회피로 빨아들인 줄기만 사라진다)
## boss 에 필요한 것: CORE_POS, BARRIER_R, set_glow(i, v), node_toward(a)

const MeleeWarn := preload("res://scripts/melee_warn.gd")
const WIND := 1.1
const TRACE_R := 640.0               # 예고: 줄기마다 돌아갈 길을 이 반지름의 옅은 점선 호로 그린다 (회전 방향)
const ACTIVE := 3.6
const SPIN := 0.3                    # 회전 (rad/s)
const HALF := 14.0                   # 판정 반폭 (보이는 빛무리보다 훨씬 가늘다)
const WALL := 1150.0
const TOP := -3080.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var origin := Vector2.ZERO
var n := 8
var a0 := 0.0
var spin := SPIN
var active := ACTIVE
var rot := 0.0
var rot_prev := 0.0
var dodged_beams: Array[int] = []


func _init(o: Vector2, count := 8) -> void:
	kind = "burst"
	phase = "wind"
	origin = o
	n = count
	a0 = randf() * TAU
	spin = SPIN * (1.0 if randf() < 0.5 else -1.0)


func step(_dt: float, _ppos: Vector2) -> void:
	match phase:
		"wind":
			_wind_glow(minf(1.0, t / WIND))
			if t >= WIND:
				phase = "fire"
				t = 0.0
				boss.emit(Ev.BEAM, origin)
		"fire":
			rot_prev = rot
			rot = spin * t
			if t >= active:
				boss.finish_attack()


## 모으는 동안 발사점이 달아오른다 (하위 모듈이 바꾼다)
func _wind_glow(k: float) -> void:
	for i in n:
		boss.set_glow(boss.node_toward(_angle(i)), k)


## 줄기가 시작되는 반지름 (그 안쪽은 판정 없음)
func _inner() -> float:
	return boss.BARRIER_R


func _angle(i: int, r := INF) -> float:
	return a0 + (rot if r == INF else r) + i * TAU / n


func unparry_point(_ppos: Vector2) -> Vector2:
	return origin


func end_at(a: float) -> Vector2:
	var d := Vector2.from_angle(a)
	var k := 99999.0
	if d.x < -0.001:
		k = minf(k, (-WALL - origin.x) / d.x)
	elif d.x > 0.001:
		k = minf(k, (WALL - origin.x) / d.x)
	if d.y > 0.001:
		k = minf(k, (0.0 - origin.y) / d.y)
	elif d.y < -0.001:
		k = minf(k, (TOP - origin.y) / d.y)
	return origin + d * k


## p 에 닿은 줄기 (이번 프레임에 쓸고 지나간 각도 포함, 회피한 줄기 제외). 없으면 -1
func _beam_at(p: Vector2, r: float) -> int:
	if phase != "fire":
		return -1
	var rel := p - origin
	var dist := rel.length()
	if dist < _inner() - r:
		return -1
	var w := (HALF + r) / maxf(dist, 1.0)
	var a := rel.angle()
	for i in n:
		if dodged_beams.has(i):
			continue
		var lo := minf(_angle(i, rot_prev), _angle(i))
		var hi := maxf(_angle(i, rot_prev), _angle(i))
		var d := wrapf(a - lo, -PI, PI)
		if d < -w or d > (hi - lo) + w:
			continue
		if dist > origin.distance_to(end_at(a)) + r:
			continue
		return i
	return -1


func beam_hit(p: Vector2, r: float) -> Vector2:
	var i := _beam_at(p, r)
	if i < 0:
		return Vector2.ZERO
	return Vector2.from_angle(_angle(i) + signf(spin) * PI * 0.5)


func mark_dodged(p: Vector2, r: float) -> void:
	var i := _beam_at(p, r)
	if i >= 0:
		dodged_beams.append(i)


func draw() -> void:
	var c: CanvasItem = boss
	var br: float = _inner()
	if phase == "wind":
		var kk := clampf(t / WIND, 0.0, 1.0)
		var blink := 0.6 + 0.4 * sin(boss.t * 22.0)
		for i in n:
			var a := _angle(i)
			c.draw_line(origin + Vector2.from_angle(a) * br, end_at(a), Color(C_UNPARRY_CORE, (0.15 + 0.35 * kk) * blink), 2.0 + 2.0 * kk)
			c.draw_line(origin + Vector2.from_angle(a) * br, end_at(a), Color(C_UNPARRY, 0.08 * kk), 90.0 * kk)
			MeleeWarn.arc_trace(c, origin, TRACE_R, a, a + spin * active, t / MeleeWarn.TRACE_TIME)   # 회전 방향: 줄기가 쓸고 갈 길이 한 번 그어지고 끝에 화살표
		return
	var fl := 0.9 + 0.2 * sin(boss.t * 36.0)
	for i in n:
		var a := _angle(i)
		var s := origin + Vector2.from_angle(a) * br
		var e := end_at(a)
		if dodged_beams.has(i):                       # 퍼펙트 회피로 빨아들인 줄기는 사라진다
			continue
		c.draw_line(s, e, Color(C_UNPARRY, 0.08), 180.0 * fl)          # 넓은 빛무리 (판정 없음)
		c.draw_line(s, e, Color(C_UNPARRY, 0.18), 70.0 * fl)
		c.draw_line(s, e, Color(C_UNPARRY, 0.8), 24.0)
		c.draw_line(s, e, Color(C_UNPARRY_CORE, 0.95), 7.0)
		c.draw_circle(e, 40.0 * fl, Color(C_UNPARRY, 0.3))
