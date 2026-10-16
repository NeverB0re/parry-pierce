extends "res://scripts/attacks/attack.gd"
## 궤도 광선 (결계 위성, 패리 불가 = 보라): 결계 가장자리에서 뻗은 광선이 위성 아래쪽을 등대처럼 쓸고 지나간다.
## 뚫는 공격: 지나가는 광선을 돌진으로 뚫는다 (돌진 직후 스치면 완전 동조). 시작은 플레이어에게서 먼 쪽, 쓸어 오는 방향은 옅은 점선이 한 번 그어지며 알린다.
## double = 양쪽에서 한 줄기씩 가운데로 모인다 (뒤 스테이지·코어 절반 아래)
## boss 에 필요한 것: CORE_POS, BARRIER_R, node_toward(a), node_pos(i), set_glow(i, v), bolt_mult()

const MeleeWarn := preload("res://scripts/melee_warn.gd")
const WIND := 1.0
const SWEEP := 1.9
const SIDE := 0.15                   # 수평에서 이만큼 아래부터 (양 끝 각도)
const HALF := 16.0                   # 판정 반폭
const WALL := 1150.0
const TOP := -3080.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var beams: Array = []                # [{from, to, th, prev}]
var origin := Vector2.ZERO           # 위성 코어 (광선은 결계 가장자리부터)


func _init(b, ppos: Vector2, double := false) -> void:
	kind = "orbit"
	phase = "wind"
	origin = b.CORE_POS
	var left := PI - SIDE
	var right := SIDE
	if double:
		beams.append({"from": left, "to": PI * 0.5, "th": left, "prev": left})
		beams.append({"from": right, "to": PI * 0.5, "th": right, "prev": right})
	elif ppos.x >= origin.x:             # 플레이어 반대쪽에서 시작해 쓸어 온다
		beams.append({"from": left, "to": right, "th": left, "prev": left})
	else:
		beams.append({"from": right, "to": left, "th": right, "prev": right})


func step(_dt: float, _ppos: Vector2) -> void:
	match phase:
		"wind":
			for bm in beams:
				boss.set_glow(boss.node_toward(bm["from"]), minf(1.0, t / WIND))
			if t >= WIND:
				phase = "sweep"
				t = 0.0
				boss.emit(Ev.BEAM, origin)
		"sweep":
			var k := minf(1.0, t / SWEEP)
			var e := k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65
			for bm in beams:
				bm["prev"] = bm["th"]
				bm["th"] = lerpf(bm["from"], bm["to"], e)
				boss.set_glow(boss.node_toward(bm["th"]), 1.0)
			if k >= 1.0:
				boss.finish_attack()


func unparry_point(_ppos: Vector2) -> Vector2:
	return origin


## 광선 끝점: origin 에서 각도 a 로 쏜 광선이 벽·천장·바닥에 닿는 곳
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


## 이번 프레임에 광선이 쓸고 지나간 부채꼴(결계 바깥) 안이면 맞는다 → 밀려날 방향
func beam_hit(p: Vector2, r: float) -> Vector2:
	if phase != "sweep":
		return Vector2.ZERO
	var rel := p - origin
	var dist := rel.length()
	if dist < boss.BARRIER_R - r:
		return Vector2.ZERO
	for bm in beams:
		var a0: float = bm["prev"]
		var a1: float = bm["th"]
		var lo := minf(a0, a1)
		var hi := maxf(a0, a1)
		var w := (HALF + r) / maxf(dist, 1.0)
		var a := rel.angle()
		if a < -PI * 0.5:                        # 아래 반원 기준으로 각도를 맞춘다 (왼쪽 수평 근처가 -π 로 넘어가지 않게)
			a += TAU
		if a < lo - w or a > hi + w:
			continue
		if dist > origin.distance_to(end_at(a)) + r:
			continue
		var dir := signf(a1 - a0)
		return Vector2.from_angle(a1 + dir * PI * 0.5)   # 쓸고 가는 방향으로 밀려난다
	return Vector2.ZERO


func draw() -> void:
	if dodged:                                   # 퍼펙트 회피로 빨아들였다: 사라진다
		return
	var c: CanvasItem = boss
	var br: float = boss.BARRIER_R
	if phase == "wind":
		var kk := clampf(t / WIND, 0.0, 1.0)
		var blink := 0.65 + 0.35 * sin(boss.t * 24.0)
		for bm in beams:
			var s := origin + Vector2.from_angle(bm["from"]) * br
			c.draw_line(s, end_at(bm["from"]), Color(C_UNPARRY_CORE, (0.25 + 0.55 * kk) * blink), 2.0 + 6.0 * kk)   # 시작선
			MeleeWarn.arc_trace(c, origin, 820.0, bm["from"], bm["to"], t / MeleeWarn.TRACE_TIME)       # 쓸어 오는 방향 (옅은 점선, 한 번)
		return
	for bm in beams:
		var th: float = bm["th"]
		var s := origin + Vector2.from_angle(th) * br
		var e := end_at(th)
		var fl := 0.9 + 0.2 * sin(boss.t * 40.0)
		c.draw_line(s, e, Color(C_UNPARRY, 0.22), 64.0 * fl)
		c.draw_line(s, e, Color(C_UNPARRY, 0.75), 28.0 * fl)
		c.draw_line(s, e, Color(C_UNPARRY_CORE, 0.95), 8.0)
		c.draw_circle(e, 50.0 * fl, Color(C_UNPARRY, 0.35))
		c.draw_circle(e, 22.0, Color(C_UNPARRY_CORE, 0.9))
		var rest := absf(bm["to"] - th)                      # 남은 길 (옅게)
		if rest > 0.02:
			c.draw_arc(origin, 820.0, minf(th, bm["to"]), maxf(th, bm["to"]), 24, Color(C_UNPARRY, 0.18), 3.0)
