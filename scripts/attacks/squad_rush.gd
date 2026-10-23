extends "res://scripts/attacks/attack.gd"
## 돌격 편대 (모함, 진홍 = 근접): 몸통째 들이받는다. 일반 돌진으로는 못 피한다 — 멈춰 겨눈 순간(warn)이나 들이받는 중에 차지 강습으로 요격하면
## 그 드론에 피해 + 튕겨 나간다 (나머지는 계속).
## 모드 — 편대 패턴 둘 + 편대장 패턴 하나
##   line  : 셋이 나란히 한 줄로 늘어서서 플레이어를 겨누고, 다 함께 돌진한다 (줄 끝 밖으로 빠지거나 하나를 요격해 틈을 연다)
##   chain : 셋이 차례로 연달아 돌진한다 (앞 기체가 들이받기 시작하면 다음 기체가 겨눈다. 예고는 겨누는 기체만, 기다리는 기체는 순번만)
##   lance : 편대장이 굵은 몸통으로 관통 돌격 — 플레이어를 꿰뚫고 반대편 끝까지 달려간 뒤, 곧바로 그 자리에서 몸을 돌려 되돌아 꿰뚫는다 (첫 돌격을 쳐내면 두 번째는 끊긴다)
## 겨누는 동안(aim)은 플레이어를 따라간다. 멈춘 뒤(warn)엔 그 줄로.
## boss 에 필요한 것: squad_alive(s), squad_center(s), leader_of(s), want_drone, hold_drone, drone_pos, aim_drone, seg_closest, emit

const MeleeWarn := preload("res://scripts/melee_warn.gd")
const AIM := 0.7
const WARN := 0.45
const AIM_FIRST := 1.15              # 첫 돌진(과 나란히 돌진)은 예고를 길게: 보고 준비할 시간 (v0.106)
const WARN_FIRST := 0.6
const STRIKE := 0.3
const RECOVER := 0.3
const STAND := 520.0                 # 겨누는 자리 = 플레이어에서 이만큼
const REACH := 1100.0                # 들이받는 거리 (플레이어를 지나 반대쪽까지)
const LINE_GAP := 190.0              # 나란히 설 때 간격
const HALF := 46.0                   # 몸통 판정 반폭
const LANCE_STAND := 760.0
const LANCE_REACH := 1500.0
const LANCE_HALF := 80.0             # 편대장 몸통 판정 (굵다)
const AIM_BACK := 0.35               # lance: 되돌아 꿰뚫기 전 겨누기와 멈춤
const WARN_BACK := 0.2
const READY_WAIT := 0.45             # chain: 뒤 기체가 멈춰 서서 기다리는 시간
const KNOCK := 320.0
const KNOCK_TIME := 0.4

var squad := 0
var mode := "chain"
var runs: Array = []                 # 돌진 하나 = {i, phase, t, half, stand, reach, from, to, prev, side}


func _init(s: int, m := "chain") -> void:
	kind = "squad_rush"
	squad = s
	mode = m


func _setup() -> void:
	if mode == "lance":
		var l: int = boss.leader_of(squad)
		if boss.part_alive(l):
			for k in (3 if boss.squad_solo(squad) else 2):          # 혼자 남으면 한 번 더 되돌아 꿰뚫는다
				runs.append({"i": l, "phase": "wait", "t": 0.0, "half": LANCE_HALF, "stand": LANCE_STAND, "reach": LANCE_REACH, "pierce": not runs.is_empty()})
	else:
		var order: Array = boss.squad_alive(squad).duplicate()
		order.reverse()                                   # 편대원 먼저, 편대장 마지막
		for i in order:
			runs.append({"i": i, "phase": "wait", "t": 0.0, "half": HALF, "stand": STAND, "reach": REACH})
	if mode == "line" or mode == "chain":              # 셋이 한꺼번에 겨누기 시작한다 (chain 은 뒤 기체가 먼저 겨누기를 마치고 멈춰 차례를 기다린다)
		for r in runs:
			r["phase"] = "aim"
	elif not runs.is_empty():
		runs[0]["phase"] = "aim"


func step(dt: float, ppos: Vector2) -> void:
	if runs.is_empty():
		_setup()
		if runs.is_empty():
			boss.finish_attack()
			return
	var live := 0
	for k in runs.size():
		var r: Dictionary = runs[k]
		if not boss.part_alive(int(r["i"])):
			r["phase"] = "done"
		if r["phase"] == "done":
			continue
		live += 1
		r["t"] = float(r["t"]) + dt
		_run(r, k, ppos)
	if mode == "lance":                                  # 같은 기체라 앞 돌격이 끝난 뒤 다시 겨눈다
		for k in range(1, runs.size()):
			if runs[k]["phase"] == "wait" and runs[k - 1]["phase"] == "done":
				_go(runs[k], "aim")
	if live == 0:
		boss.finish_attack()


func _go(r: Dictionary, ph: String) -> void:
	r["phase"] = ph
	r["t"] = 0.0


## 돌진 하나 진행
func _run(r: Dictionary, k: int, ppos: Vector2) -> void:
	var i: int = r["i"]
	var tt: float = r["t"]
	match r["phase"]:
		"wait":                                          # 차례를 기다리며 플레이어 둘레에서 노려본다 (lance 의 두 번째는 같은 기체라 그대로 둔다)
			if mode == "lance":
				return
			var a: float = (boss.drone_pos(i) - ppos).angle()
			boss.want_drone(i, ppos + Vector2.from_angle(a) * 720.0)
			boss.aim_drone(i, a + PI)
		"aim":
			_place(r, k, ppos)
			boss.want_drone(i, r["from"])
			boss.aim_drone(i, (Vector2(r["to"]) - Vector2(r["from"])).angle())
			if tt >= _aim_time(k):
				boss.hold_drone(i, r["from"])
				_go(r, "warn")
		"warn":
			boss.hold_drone(i, r["from"])
			var go: bool = _prev_done(k) if mode == "chain" and k > 0 else tt >= _warn_time(k)   # chain 뒤 기체: 멈춰 겨눈 채로 앞 기체의 돌진이 끝나길 기다린다
			if go:
				r["prev"] = r["from"]
				dodged = false                             # 기체마다 새 공격
				_go(r, "strike")
				boss.emit(Ev.SWING, r["from"])
		"strike":
			r["prev"] = boss.drone_pos(i)
			var u := minf(1.0, tt / STRIKE)
			boss.hold_drone(i, Vector2(r["from"]).lerp(r["to"], u * u))
			if u >= 1.0:
				_go(r, "recover")
		"recover":
			boss.want_drone(i, r["to"])
			if tt >= RECOVER:
				_go(r, "done")
		"knocked":
			var u := minf(1.0, tt / KNOCK_TIME)
			boss.hold_drone(i, Vector2(r["knock_from"]) + Vector2(r["knock_dir"]) * KNOCK * (1.0 - (1.0 - u) * (1.0 - u)))
			if u >= 1.0:
				_go(r, "done")


func _aim_time(k: int) -> float:
	if mode == "lance" and k > 0:                        # 되돌아 꿰뚫기: 짧게 겨눈다
		return AIM_BACK
	if mode == "chain" and k > 0:                        # 앞 기체가 들이받기를 마칠 때(첫 돌진 시작 + k×STRIKE)보다 READY_WAIT 앞서 겨누기를 마치고 멈춰 기다린다 (첫 기체만 예고가 길다)
		return AIM_FIRST + WARN_FIRST + k * STRIKE - READY_WAIT
	return AIM_FIRST if k == 0 or mode == "line" else AIM


## 멈춤(warn) 길이 (chain 의 뒤 기체는 시간 대신 앞 기체를 기다린다: _prev_done)
func _warn_time(k: int) -> float:
	if mode == "lance" and k > 0:
		return WARN_BACK
	return WARN_FIRST if k == 0 or mode == "line" else WARN


## chain: 앞 기체의 돌진이 끝났는가 (요격으로 튕겨 나갔다면 잠깐 뒤)
func _prev_done(k: int) -> bool:
	var pr: Dictionary = runs[k - 1]
	var ph: String = pr["phase"]
	return ph == "recover" or ph == "done" or (ph == "knocked" and float(pr["t"]) >= 0.3)


## 겨누는 자리 (겨누기 앞쪽 80% 동안 플레이어를 따라간다). line 은 셋이 같은 쪽에서 나란히
func _place(r: Dictionary, k: int, ppos: Vector2) -> void:
	if float(r["t"]) > _aim_time(k) * 0.8 and r.has("from"):
		return
	var stand: float = r["stand"]
	var reach: float = r["reach"]
	if r.get("pierce", false):                           # 되돌아 꿰뚫기: 선 자리에서 그대로 몸을 돌려 플레이어를 지나 반대편 끝까지
		var cur: Vector2 = boss.drone_pos(int(r["i"]))
		var d: Vector2 = (ppos - cur).normalized()
		if d.length() < 0.1:
			d = Vector2.UP
		r["from"] = cur
		r["to"] = cur + d * (cur.distance_to(ppos) + 900.0)
		return
	if mode == "line":
		var side: Vector2 = (boss.squad_center(squad) - ppos).normalized()
		if side.length() < 0.1:
			side = Vector2.UP
		var off := (k - (runs.size() - 1) * 0.5) * LINE_GAP
		r["from"] = ppos + side * stand + side.orthogonal() * off
		r["to"] = Vector2(r["from"]) - side * reach
		return
	var dir: Vector2 = (boss.drone_pos(int(r["i"])) - ppos).normalized()
	if dir.length() < 0.1:
		dir = Vector2.UP
	r["from"] = ppos + dir * stand
	r["to"] = Vector2(r["from"]) - dir * reach


func _box(r: Dictionary, ppos: Vector2) -> Dictionary:
	var i: int = r["i"]
	var p: Vector2 = boss.drone_pos(i)
	var a: Vector2 = r["prev"] if r["phase"] == "strike" and r.has("prev") else p
	var q: Vector2 = boss.seg_closest(ppos, a, p)
	return {"id": "rush", "segs": [[a, p, float(r["half"])]], "pos": q, "src": self, "drone": i, "run": r}


func hitboxes(ppos: Vector2, out: Array[Dictionary]) -> void:
	for r in runs:
		if r["phase"] != "strike":
			continue
		var hb := _box(r, ppos)
		var nrm := (Vector2(r["to"]) - Vector2(r["from"])).normalized().orthogonal()
		hb["push"] = nrm if nrm.dot(ppos - Vector2(r["from"])) >= 0.0 else -nrm   # 줄 바깥으로 밀려난다
		hb["melee"] = true
		out.append(hb)


## 요격: 겨누고 멈춘(warn)·들이받는 기체 중 플레이어에 가장 가까운 것
func clash_box(ppos: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	for r in runs:
		if not _can_clash(r):
			continue
		var hb := _box(r, ppos)
		var d: float = Vector2(hb["pos"]).distance_to(ppos)
		if d < bd:
			bd = d
			best = hb
	if not best.is_empty():
		best["part"] = best["drone"]                     # 요격 = 그 드론에 피해 (main._clash 가 damage_part)
	return best


## 멈춰 겨눈(warn) 기체와 들이받는(strike) 기체만 요격된다
func _can_clash(r: Dictionary) -> bool:
	return r["phase"] == "warn" or r["phase"] == "strike"


func assist_targets(_from: Vector2, out: Array[Dictionary]) -> void:
	for r in runs:
		if _can_clash(r):
			out.append({"pos": boss.drone_pos(int(r["i"])), "r": 56.0, "intercept": true})


## 요격당함: 그 기체만 부딪힌 방향으로 튕겨 나간다 (나머지는 계속)
func on_parried(hb: Dictionary) -> void:
	var r: Dictionary = hb.get("run", {})
	if r.is_empty() or not _can_clash(r):
		return
	if mode == "lance":                                  # 편대장 한 기체의 두 번 돌격: 첫 돌격을 쳐내면 다음 돌격은 끊긴다
		for o in runs:
			if not is_same(o, r) and (o["phase"] == "wait" or o["phase"] == "aim" or o["phase"] == "warn"):
				o["phase"] = "done"
	r["knock_from"] = boss.drone_pos(int(r["i"]))
	var d: Vector2 = hb.get("dir", Vector2.UP)
	r["knock_dir"] = d.normalized() if d.length() > 0.1 else Vector2.UP
	_go(r, "knocked")


func melee_warning() -> bool:
	for r in runs:
		if r["phase"] == "aim" or r["phase"] == "warn":
			return true
	return false


## 예고: 겨누는 기체의 돌진 줄 (진홍 띠). chain 은 기다리는 기체에 순번만
func draw() -> void:
	var c: CanvasItem = boss
	for k in runs.size():
		var r: Dictionary = runs[k]
		var ph: String = r["phase"]
		if ph == "wait" and mode == "chain":
			MeleeWarn.tag(c, boss.drone_pos(int(r["i"])) + Vector2(0, -90), 0, boss.t, k)
		if (ph != "aim" and ph != "warn") or not r.has("from"):
			continue
		var level := 1 if ph == "aim" else 2
		var from: Vector2 = r["from"]
		var to: Vector2 = r["to"]
		var n := (to - from).normalized().orthogonal() * float(r["half"])
		MeleeWarn.zone(c, PackedVector2Array([from + n, to + n, to - n, from - n]), level, boss.t)
		MeleeWarn.tag(c, boss.drone_pos(int(r["i"])) + Vector2(0, -90), level, boss.t, k if mode == "chain" else -1)
