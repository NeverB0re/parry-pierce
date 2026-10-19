extends "res://scripts/attacks/attack.gd"
## 결계 편대 (모함, 보라 = 패리 불가): 셋이 플레이어를 크게 에워싼 삼각형을 이루고, 꼭짓점 사이에 보라 결계선을 친 채 빙글 돌며 조여 든다.
## 빠져나가려면 선 하나를 돌진으로 뚫어야 한다 → 퍼펙트 회피면 그 선의 에너지를 빨아들여(완전 동조) 동조 일격으로 드론을 친다.
## 겉보기는 화면을 가르는 넓은 빛무리, 판정은 가는 심줄 (결계 위성과 같은 색 언어). 선 단위로 흡수된다.
## 둘만 남으면 둘 사이 한 줄, 하나면 그 드론이 양쪽으로 뻗은 한 줄 — 이 줄이 플레이어 쪽을 가로질러 쓸고 지나간다.
## boss 에 필요한 것: squad_alive(s), hold_drone(i, pos), want_drone(i, pos), drone_pos(i), set_drone_glow(i, v), emit

const FORM := 1.1                    # 자리를 잡으며 가는 예고선
const ACTIVE := 3.4                  # 결계선이 살아 조여 드는 시간
const FADE := 0.4
const R0 := 900.0                    # 삼각형 시작 반지름
const R1 := 70.0                     # 끝 반지름 (가운데로 모인다 = 안에 있으면 선에 걸린다)
const SPIN := 0.45
const SWEEP := 760.0                 # 한두 기일 때: 줄이 지나가는 거리 (가운데 양쪽)
const LINE_HALF := 900.0             # 한 기일 때 줄 반길이
const HALF := 14.0                   # 판정 반폭
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var squad := 0
var c := Vector2.ZERO
var a0 := 0.0
var spin := SPIN
var dodged_edges: Array[int] = []


func _init(s: int) -> void:
	kind = "squad_veil"
	phase = "form"
	squad = s
	spin = SPIN * (1.0 if randf() < 0.5 else -1.0)


func _k() -> float:
	if phase == "form":
		return 0.0
	if phase == "fire":
		var u := clampf(t / ACTIVE, 0.0, 1.0)
		return u * u * (3.0 - 2.0 * u)
	return 1.0


## 드론 자리 (편대 수에 따라)
func _slot(n: int, k: int) -> Vector2:
	var f := _k()
	var rot := a0 + spin * (t if phase == "fire" else (ACTIVE if phase == "fade" else 0.0))
	if n >= 3:
		var r := lerpf(R0, R1, f)
		return c + Vector2.from_angle(rot + k * TAU / 3.0) * r
	var d := Vector2.from_angle(a0)
	var m := c + d * lerpf(SWEEP, -SWEEP, f)               # 줄의 가운데가 플레이어 쪽을 가로질러 간다
	if n == 2:
		return m + d.orthogonal() * LINE_HALF * (0.75 if k == 0 else -0.75)
	return m


func step(_dt: float, ppos: Vector2) -> void:
	var ids: Array = boss.squad_alive(squad)
	if ids.is_empty():
		boss.finish_attack()
		return
	if phase == "form" and t < FORM * 0.6:
		c = ppos
		a0 = (boss.squad_center(squad) - ppos).angle()
	for k in ids.size():
		var p := _slot(ids.size(), k)
		if phase == "form":
			boss.want_drone(ids[k], p)
			boss.set_drone_glow(ids[k], minf(1.0, t / FORM))
		else:
			boss.hold_drone(ids[k], p)
	match phase:
		"form":
			if t >= FORM:
				set_phase("fire")
				boss.emit(Ev.BEAM, c)
		"fire":
			if t >= ACTIVE:
				set_phase("fade")
		"fade":
			if t >= FADE:
				boss.finish_attack()


## 결계선들 [[a, b], ...] (드론 위치로)
func _edges() -> Array:
	var ids: Array = boss.squad_alive(squad)
	var out := []
	if ids.size() >= 3:
		for k in 3:
			out.append([boss.drone_pos(ids[k]), boss.drone_pos(ids[(k + 1) % 3])])
	elif ids.size() == 2:
		var a: Vector2 = boss.drone_pos(ids[0])
		var b: Vector2 = boss.drone_pos(ids[1])
		var d := (b - a).normalized()
		out.append([a - d * 400.0, b + d * 400.0])
	elif ids.size() == 1:
		var p: Vector2 = boss.drone_pos(ids[0])
		var d := Vector2.from_angle(a0).orthogonal()
		out.append([p - d * LINE_HALF, p + d * LINE_HALF])
	return out


func _edge_at(p: Vector2, r: float) -> int:
	if phase != "fire":
		return -1
	var es := _edges()
	for k in es.size():
		if dodged_edges.has(k):
			continue
		var q: Vector2 = boss.seg_closest(p, es[k][0], es[k][1])
		if q.distance_to(p) < HALF + r:
			return k
	return -1


func beam_hit(p: Vector2, r: float) -> Vector2:
	var k := _edge_at(p, r)
	if k < 0:
		return Vector2.ZERO
	var e: Array = _edges()[k]
	var n: Vector2 = (e[1] - e[0]).normalized().orthogonal()
	return n if n.dot(p - c) >= 0.0 else -n


func mark_dodged(p: Vector2, r: float) -> void:
	var k := _edge_at(p, r)
	if k >= 0:
		dodged_edges.append(k)


func unparry_point(ppos: Vector2) -> Vector2:
	var best := Vector2.INF
	for e in _edges():
		var q: Vector2 = boss.seg_closest(ppos, e[0], e[1])
		if best == Vector2.INF or q.distance_to(ppos) < best.distance_to(ppos):
			best = q
	return best


func draw() -> void:
	var cv: CanvasItem = boss
	var es := _edges()
	if phase == "form":
		var kk := clampf(t / FORM, 0.0, 1.0)
		var blink := 0.6 + 0.4 * sin(boss.t * 22.0)
		for e in es:
			cv.draw_line(e[0], e[1], Color(C_UNPARRY_CORE, (0.12 + 0.3 * kk) * blink), 2.0 + 2.0 * kk)
			cv.draw_line(e[0], e[1], Color(C_UNPARRY, 0.07 * kk), 90.0 * kk)
		return
	var a := 1.0 if phase == "fire" else 1.0 - clampf(t / FADE, 0.0, 1.0)
	var fl := 0.9 + 0.2 * sin(boss.t * 36.0)
	for k in es.size():
		if dodged_edges.has(k):                       # 퍼펙트 회피로 빨아들인 선은 사라진다
			continue
		var e: Array = es[k]
		cv.draw_line(e[0], e[1], Color(C_UNPARRY, 0.08 * a), 170.0 * fl)    # 넓은 빛무리 (판정 없음)
		cv.draw_line(e[0], e[1], Color(C_UNPARRY, 0.18 * a), 64.0 * fl)
		cv.draw_line(e[0], e[1], Color(C_UNPARRY, 0.8 * a), 22.0)
		cv.draw_line(e[0], e[1], Color(C_UNPARRY_CORE, 0.95 * a), 7.0)
