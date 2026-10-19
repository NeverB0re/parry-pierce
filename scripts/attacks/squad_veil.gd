extends "res://scripts/attacks/attack.gd"
## 결계 편대 (모함, 보라 = 패리 불가): 겉보기는 넓은 빛무리, 판정은 가는 심줄. 퍼펙트 회피로 뚫으면 그 줄기를 빨아들여 사라진다(완전 동조) → 동조 일격으로 드론을 친다.
## 모드 — 편대 패턴 둘 + 편대장 패턴 하나
##   net   : 플레이어 밖에서 셋이 삼각형 그물을 먼저 완성하고(엮이는 예고선, 무해) 그물째 플레이어를 따라가며 조여 든다 (빠져나가려면 선을 뚫어야 한다).
##           둘만 남으면 둘 사이 한 줄, 하나면 그 기체의 한 줄이 플레이어를 가로질러 쓸고 지나간다.
##   cross : 한 기씩 차례로 플레이어를 겨눠(따라오는 가는 예고선) 멈춘 뒤, 플레이어 자리를 꿰뚫는 보라 창을 쏜다. 다음 기체는 앞 기체가 멈출 때 겨누기 시작
##   pulse : 편대장이 다가서서 보라 고리 파동을 두 번 터뜨린다 (고리가 퍼져 나간다)
## boss 에 필요한 것: squad_alive(s), squad_center(s), leader_of(s), want_drone, hold_drone, drone_pos, set_drone_glow, aim_drone, seg_closest, emit

const FORM := 1.2                    # net: 그물을 엮는 시간 (예고)
const ACTIVE := 3.0                  # net: 조여 드는 시간 (판정)
const FADE := 0.4
const R0 := 860.0
const R1 := 60.0
const SPIN := 0.4
const FOLLOW := 2.2                  # net: 그물 가운데가 플레이어를 따라가는 빠르기
const SWEEP := 760.0
const LINE_HALF := 900.0
const HALF := 14.0                   # 판정 반폭
const CROSS_STAND := 640.0
const CROSS_AIM := 0.8
const CROSS_LOCK := 0.25
const CROSS_FIRE := 0.35
const CROSS_LEN := 1700.0
const PULSE_STAND := 480.0
const PULSE_WIND := 0.8
const PULSE_GAP := 1.3
const PULSE_SPEED := 470.0
const PULSE_MAX := 1500.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var squad := 0
var mode := "net"
var c := Vector2.ZERO
var a0 := 0.0
var spin := SPIN
var dodged_edges: Array[int] = []
var lances: Array = []               # cross: {i, phase, t, from, to, dodged}
var pulses: Array = []               # pulse: {o, t0, dodged}
var pulse_n := 0


func _init(s: int, m := "net") -> void:
	kind = "squad_veil"
	phase = "form"
	squad = s
	mode = m
	spin = SPIN * (1.0 if randf() < 0.5 else -1.0)


func step(dt: float, ppos: Vector2) -> void:
	match mode:
		"net":
			_net(dt, ppos)
		"cross":
			_cross(dt, ppos)
		"pulse":
			_pulse(ppos)


# ── net ────────────────────────────────────────────────
func _k() -> float:
	if phase == "form":
		return 0.0
	if phase == "fire":
		var u := clampf(t / ACTIVE, 0.0, 1.0)
		return u * u * (3.0 - 2.0 * u)
	return 1.0


func _slot(n: int, k: int) -> Vector2:
	var f := _k()
	var rot := a0 + spin * (t if phase == "fire" else (ACTIVE if phase == "fade" else 0.0))
	if n >= 3:
		return c + Vector2.from_angle(rot + k * TAU / 3.0) * lerpf(R0, R1, f)
	var d := Vector2.from_angle(a0)
	var m := c + d * lerpf(SWEEP, -SWEEP, f)
	if n == 2:
		return m + d.orthogonal() * LINE_HALF * (0.75 if k == 0 else -0.75)
	return m


func _net(dt: float, ppos: Vector2) -> void:
	var ids: Array = boss.squad_alive(squad)
	if ids.is_empty():
		boss.finish_attack()
		return
	if phase == "form":                                   # 그물을 엮는 동안은 플레이어를 바로 따라간다 (밖에서 에워싼다)
		c = ppos
		if t < 0.05:
			a0 = (boss.squad_center(squad) - ppos).angle()
	elif phase == "fire":                                 # 조여 드는 동안도 그물째 플레이어를 따라간다
		c = c.lerp(ppos, 1.0 - exp(-FOLLOW * dt))
	for k in ids.size():
		var p := _slot(ids.size(), k)
		if phase == "form":
			boss.want_drone(ids[k], p)
			boss.set_drone_glow(ids[k], minf(1.0, t / FORM))
		else:
			boss.hold_drone(ids[k], p)
		boss.aim_drone(ids[k], (c - boss.drone_pos(ids[k])).angle())
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


# ── cross ──────────────────────────────────────────────
func _cross(dt: float, ppos: Vector2) -> void:
	if lances.is_empty():
		var order: Array = boss.squad_alive(squad).duplicate()
		order.reverse()
		for i in order:
			lances.append({"i": i, "phase": "wait", "t": 0.0, "dodged": false})
		if lances.is_empty():
			boss.finish_attack()
			return
		lances[0]["phase"] = "aim"
	var live := 0
	for k in lances.size():
		var l: Dictionary = lances[k]
		var i: int = l["i"]
		if l["phase"] == "done":
			continue
		if not boss.part_alive(i) and l["phase"] != "fire":
			l["phase"] = "done"
			continue
		live += 1
		l["t"] = float(l["t"]) + dt
		var tt: float = l["t"]
		match l["phase"]:
			"aim":                                            # 플레이어 둘레 자리에서 플레이어를 겨눈다 (따라온다)
				var d: Vector2 = (boss.drone_pos(i) - ppos).normalized()
				if d.length() < 0.1:
					d = Vector2.UP
				boss.want_drone(i, ppos + d * CROSS_STAND)
				l["from"] = boss.drone_pos(i)
				l["to"] = Vector2(l["from"]) + (ppos - Vector2(l["from"])).normalized() * CROSS_LEN
				boss.aim_drone(i, (ppos - boss.drone_pos(i)).angle())
				boss.set_drone_glow(i, minf(1.0, tt / CROSS_AIM))
				if tt >= CROSS_AIM:
					l["phase"] = "lock"
					l["t"] = 0.0
			"lock":
				boss.hold_drone(i, l["from"])
				if tt >= CROSS_LOCK:
					l["phase"] = "fire"
					l["t"] = 0.0
					boss.emit(Ev.BEAM, l["from"])
			"fire":
				if boss.part_alive(i):
					boss.hold_drone(i, l["from"])
				if tt >= CROSS_FIRE:
					l["phase"] = "done"
		if k + 1 < lances.size() and lances[k + 1]["phase"] == "wait" and (l["phase"] == "lock" or l["phase"] == "fire" or l["phase"] == "done"):
			lances[k + 1]["phase"] = "aim"
			lances[k + 1]["t"] = 0.0
	if live == 0:
		boss.finish_attack()


# ── pulse ──────────────────────────────────────────────
func _pulse(ppos: Vector2) -> void:
	var l: int = boss.leader_of(squad)
	if boss.part_alive(l):
		var d: Vector2 = (boss.drone_pos(l) - ppos).normalized()
		if d.length() < 0.1:
			d = Vector2.UP
		boss.want_drone(l, ppos + d * PULSE_STAND)
		boss.aim_drone(l, (ppos - boss.drone_pos(l)).angle())
		var next_at := PULSE_WIND + pulse_n * PULSE_GAP
		if pulse_n < 2:
			boss.set_drone_glow(l, clampf(1.0 - (next_at - t) / PULSE_WIND, 0.0, 1.0))
			if t >= next_at:
				pulses.append({"o": boss.drone_pos(l), "t0": t, "dodged": false})
				pulse_n += 1
				boss.emit(Ev.RING, boss.drone_pos(l))
	elif pulses.is_empty():
		boss.finish_attack()
		return
	if pulses.size() >= 2 or not boss.part_alive(l):
		var done := true
		for p in pulses:
			done = done and (t - float(p["t0"])) * PULSE_SPEED > PULSE_MAX
		if done:
			boss.finish_attack()


# ── 판정 ───────────────────────────────────────────────
## 지금 살아 있는 보라 줄기들: [{"a", "b"} 선분] 또는 [{"o", "r"} 고리] 와 식별 번호
func _hit_at(p: Vector2, r: float) -> Dictionary:
	match mode:
		"net":
			if phase != "fire":
				return {}
			var es := _edges()
			for k in es.size():
				if dodged_edges.has(k):
					continue
				var q: Vector2 = boss.seg_closest(p, es[k][0], es[k][1])
				if q.distance_to(p) < HALF + r:
					var n: Vector2 = (es[k][1] - es[k][0]).normalized().orthogonal()
					return {"k": k, "push": n if n.dot(p - c) >= 0.0 else -n}
		"cross":
			for k in lances.size():
				var l: Dictionary = lances[k]
				if l["phase"] != "fire" or l["dodged"]:
					continue
				var q: Vector2 = boss.seg_closest(p, l["from"], l["to"])
				if q.distance_to(p) < HALF + 4.0 + r:
					var n: Vector2 = (Vector2(l["to"]) - Vector2(l["from"])).normalized().orthogonal()
					return {"k": k, "push": n if n.dot(p - q) >= 0.0 else -n}
		"pulse":
			for k in pulses.size():
				var pl: Dictionary = pulses[k]
				if pl["dodged"]:
					continue
				var rr := (t - float(pl["t0"])) * PULSE_SPEED
				var rel: Vector2 = p - Vector2(pl["o"])
				if rr <= PULSE_MAX and absf(rel.length() - rr) < HALF + 6.0 + r:
					return {"k": k, "push": rel.normalized() if rel.length() > 1.0 else Vector2.UP}
	return {}


func beam_hit(p: Vector2, r: float) -> Vector2:
	var h := _hit_at(p, r)
	return Vector2.ZERO if h.is_empty() else h["push"]


func mark_dodged(p: Vector2, r: float) -> void:
	var h := _hit_at(p, r)
	if h.is_empty():
		return
	var k: int = h["k"]
	match mode:
		"net":
			dodged_edges.append(k)
		"cross":
			lances[k]["dodged"] = true
		"pulse":
			pulses[k]["dodged"] = true


func unparry_point(ppos: Vector2) -> Vector2:
	match mode:
		"net":
			var best := Vector2.INF
			for e in _edges():
				var q: Vector2 = boss.seg_closest(ppos, e[0], e[1])
				if best == Vector2.INF or q.distance_to(ppos) < best.distance_to(ppos):
					best = q
			return best
		"cross":
			for l in lances:
				if l["phase"] == "aim" or l["phase"] == "lock" or l["phase"] == "fire":
					return l["from"]
		"pulse":
			var l: int = boss.leader_of(squad)
			return boss.drone_pos(l) if boss.part_alive(l) else Vector2.INF
	return Vector2.INF


# ── 그리기 ─────────────────────────────────────────────
func _line(cv: CanvasItem, a: Vector2, b: Vector2, k: float, fl: float) -> void:
	cv.draw_line(a, b, Color(C_UNPARRY, 0.08 * k), 170.0 * fl)     # 넓은 빛무리 (판정 없음)
	cv.draw_line(a, b, Color(C_UNPARRY, 0.18 * k), 64.0 * fl)
	cv.draw_line(a, b, Color(C_UNPARRY, 0.8 * k), 22.0)
	cv.draw_line(a, b, Color(C_UNPARRY_CORE, 0.95 * k), 7.0)


func draw() -> void:
	var cv: CanvasItem = boss
	var fl := 0.9 + 0.2 * sin(boss.t * 36.0)
	var blink := 0.6 + 0.4 * sin(boss.t * 22.0)
	match mode:
		"net":
			var es := _edges()
			if phase == "form":                                 # 그물을 엮는다: 기체에서 다음 기체 쪽으로 가는 선이 자란다 (무해)
				var kk := clampf(t / FORM, 0.0, 1.0)
				for e in es:
					var b: Vector2 = Vector2(e[0]).lerp(e[1], kk)
					cv.draw_line(e[0], b, Color(C_UNPARRY_CORE, (0.25 + 0.4 * kk) * blink), 3.0)
					cv.draw_line(e[0], b, Color(C_UNPARRY, 0.1 * kk), 60.0 * kk)
				return
			var a := 1.0 if phase == "fire" else 1.0 - clampf(t / FADE, 0.0, 1.0)
			for k in es.size():
				if not dodged_edges.has(k):
					_line(cv, es[k][0], es[k][1], a, fl)
		"cross":
			for l in lances:
				if not l.has("from") or l["dodged"]:
					continue
				match l["phase"]:
					"aim", "lock":                                # 겨누는 가는 선 (따라온다), 멈추면 빠르게 깜빡인다
						var w := 2.0 if l["phase"] == "aim" else 4.0
						cv.draw_line(l["from"], l["to"], Color(C_UNPARRY_CORE, (0.3 if l["phase"] == "aim" else 0.7) * blink), w)
						cv.draw_line(l["from"], l["to"], Color(C_UNPARRY, 0.08), 50.0)
					"fire":
						_line(cv, l["from"], l["to"], 1.0, fl)
		"pulse":
			var l: int = boss.leader_of(squad)
			if boss.part_alive(l) and pulse_n < 2:              # 모으는 고리
				var next_at := PULSE_WIND + pulse_n * PULSE_GAP
				var kk := clampf(1.0 - (next_at - t) / PULSE_WIND, 0.0, 1.0)
				cv.draw_arc(boss.drone_pos(l), 240.0 * (1.0 - kk) + 60.0, 0.0, TAU, 48, Color(C_UNPARRY_CORE, (0.25 + 0.5 * kk) * blink), 4.0)
			for p in pulses:
				if p["dodged"]:
					continue
				var rr := (t - float(p["t0"])) * PULSE_SPEED
				if rr > PULSE_MAX:
					continue
				var fade := 1.0 - maxf(0.0, rr - PULSE_MAX * 0.8) / (PULSE_MAX * 0.2)
				cv.draw_arc(p["o"], rr, 0.0, TAU, 96, Color(C_UNPARRY, 0.08 * fade), 130.0)
				cv.draw_arc(p["o"], rr, 0.0, TAU, 96, Color(C_UNPARRY, 0.75 * fade), 36.0)
				cv.draw_arc(p["o"], rr, 0.0, TAU, 96, Color(C_UNPARRY_CORE, 0.95 * fade), 7.0)
