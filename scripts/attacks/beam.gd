extends "res://scripts/attacks/attack.gd"
## 레이저 (패리 불가 = 검붉은 보라): origin 에서 쏜 광선이 from → to 각도로 경기장을 긋는다. 회피 돌진의 무적으로만 통과한다.
## 단계: wind(눈이 달아오르고 지나갈 부채꼴 예고) → sweep(긋기)
## boss 에 필요한 것: beam_glow, EYES (광선이 나가는 눈 위치들)

const WIND := 1.1
const SWEEP := 1.7
const FROM := PI + 0.2               # 시작 각도 (왼쪽, 살짝 위)
const TO := -0.2                     # 끝 각도 (오른쪽, 살짝 위)
const HALF := 16.0                   # 판정 반폭
const WALL := 1150.0                 # 광선이 닿는 벽·천장·바닥
const TOP := -3080.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var origin := Vector2.ZERO
var th := FROM
var th_prev := FROM


func _init(o: Vector2) -> void:
	kind = "beam"
	origin = o
	phase = "wind"


func step(_dt: float, _ppos: Vector2) -> void:
	match phase:
		"wind":
			boss.beam_glow = minf(1.0, t / WIND)
			if t >= WIND:
				set_phase("sweep")
				boss.emit(Ev.BEAM, origin)
		"sweep":
			boss.beam_glow = 1.0
			var k := minf(1.0, t / SWEEP)
			th_prev = th
			th = lerpf(FROM, TO, k * k * (3.0 - 2.0 * k) * 0.3 + k * 0.7)
			if k >= 1.0:
				boss.finish_attack()


func unparry_point(_ppos: Vector2) -> Vector2:
	return origin


## 광선 끝점: origin 에서 쏜 광선이 벽·천장·바닥에 닿는 곳
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


## 이번 프레임에 광선이 쓸고 지나간 부채꼴 안이면 맞는다 → 밀려날 방향, 아니면 ZERO
func beam_hit(p: Vector2, r: float) -> Vector2:
	if phase != "sweep":
		return Vector2.ZERO
	var rel := p - origin
	var dist := rel.length()
	if dist < 1.0:
		return Vector2.ZERO
	var d := wrapf(th_prev - rel.angle(), -PI, PI)      # 광선은 각도가 줄어드는 방향으로 돈다
	var w := (HALF + r) / dist
	if d < -w or d > (th_prev - th) + w:
		return Vector2.ZERO
	if dist > origin.distance_to(end_at(rel.angle())) + r:
		return Vector2.ZERO
	return Vector2.from_angle(th - PI * 0.5)           # 쓸고 가는 방향으로 밀려난다


## 지나갈 부채꼴을 각도 구간별로 칠한다 (a0 → a1 로 옅어짐). 벽·바닥까지 이어져 머리가 안 보여도 보인다
func _fan(from_th: float, to_th: float, a0: float, a1: float, n: int) -> void:
	var c: CanvasItem = boss
	var prev := end_at(from_th)
	for j in range(1, n + 1):
		var cur := end_at(lerpf(from_th, to_th, j / float(n)))
		c.draw_colored_polygon(PackedVector2Array([origin, prev, cur]), Color(C_UNPARRY, lerpf(a0, a1, (j - 0.5) / n)))
		prev = cur


func draw() -> void:
	if dodged:                                   # 퍼펙트 회피로 빨아들였다: 사라진다
		return
	var c: CanvasItem = boss
	var wind := phase == "wind"
	var kk := clampf(t / WIND, 0.0, 1.0)
	var blink := 0.65 + 0.35 * sin(boss.t * 24.0)
	# 지나갈 부채꼴 (남은 구간). 가까운 쪽이 진하다
	if wind:
		_fan(FROM, TO, (0.18 + 0.2 * kk) * blink, 0.04, 48)
	else:
		_fan(th, TO, 0.3, 0.04, maxi(4, int(48.0 * (th - TO) / (FROM - TO))))
	# 벽·바닥을 따라가는 도착 경로 띠 + 일정 간격의 눈금선
	var path := PackedVector2Array()
	var from_th := FROM if wind else th
	for j in 41:
		path.append(end_at(lerpf(from_th, TO, j / 40.0)))
	c.draw_polyline(path, Color(C_UNPARRY_CORE, (0.18 + 0.3 * kk) if wind else 0.5), 10.0)
	for j in 13:
		var tth := lerpf(FROM, TO, j / 12.0)
		if wind or tth < th:
			c.draw_line(origin, end_at(tth), Color(C_UNPARRY, 0.14 + 0.1 * kk), 3.0)
	if wind:
		# 시작선 + 긋는 방향 화살표
		for e in boss.EYES:
			c.draw_line(e, end_at(FROM), Color(C_UNPARRY_CORE, (0.3 + 0.6 * kk) * blink), 3.0 + 7.0 * kk)
		for f in [0.2, 0.4, 0.6, 0.8]:
			var ath: float = lerpf(FROM, TO, f)
			var radial := Vector2.from_angle(ath)
			var tangent := Vector2.from_angle(ath - PI * 0.5)
			var at := origin + radial * 700.0
			c.draw_colored_polygon(PackedVector2Array([at + tangent * 46.0, at - tangent * 14.0 + radial * 28.0, at - tangent * 14.0 - radial * 28.0]), Color(C_UNPARRY_CORE, 0.25 + 0.5 * kk))
		return
	var end := end_at(th)
	var fl := randf_range(0.9, 1.1)
	for e in boss.EYES:
		c.draw_line(e, end, Color(C_UNPARRY, 0.22), 70.0 * fl)
		c.draw_line(e, end, Color(C_UNPARRY, 0.75), 30.0 * fl)
		c.draw_line(e, end, Color(C_UNPARRY_CORE, 0.95), 9.0)
	c.draw_circle(end, 60.0 * fl, Color(C_UNPARRY, 0.35))
	c.draw_circle(end, 26.0, Color(C_UNPARRY_CORE, 0.9))
