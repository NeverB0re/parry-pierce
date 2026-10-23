extends "res://scripts/attacks/attack.gd"
## 압착 (반응로, 근접 = 진홍): 양옆 격벽(방호 셔터)이 밀려 나와 전장을 좁힌다 (2보스 프레스의 옆 방향판).
## 근접 규칙 (RULES 3.3): 빠른 준비 동작(prep, 경고 없음) → 멈춰 경고(set·warn, 요격 가능) → 밀고 들어옴(push, 요격 가능).
## 요격하면 그쪽 격벽이 튕겨 원래 자리로 돌아간다 (양쪽은 따로 계산). 못 쳐내면 격벽이 박힌 채 boss.squeeze_hold 동안 전장을 좁혔다가 천천히 물러난다.
## 밀고 들어오는 격벽에 닿으면 피해 + 가운데 쪽으로 밀려난다. 박힌 격벽은 벽일 뿐 (boss.wall_x_min/max).
## boss 에 필요한 것: squeeze_d[2], hold_squeeze(side, depth), SPAWN_Y, FLOOR_Y, ARENA_X

const MeleeWarn := preload("res://scripts/melee_warn.gd")
const PREP := 0.45
const SET := 0.3
const WARN := 0.8
const PUSH := 0.4
const JAM := 0.45
const DEPTH := 360.0                 # 한쪽이 파고드는 깊이 (양쪽이면 전장 폭 2300 → 1580)
const HIDE := -260.0                 # 준비 전 격벽은 벽 너머에 숨어 있다

var sides: Array = []                # [{side: -1|1, phase, t, jam_from}]


func _init() -> void:
	kind = "clamp"
	for sd in [-1, 1]:
		sides.append({"side": sd, "phase": "prep", "t": 0.0, "jam_from": 0.0})


func _idx(sd: int) -> int:
	return 0 if sd < 0 else 1


func step(dt: float, _ppos: Vector2) -> void:
	var live := 0
	for s in sides:
		s["t"] = float(s["t"]) + dt
		var tt: float = s["t"]
		var i := _idx(int(s["side"]))
		match s["phase"]:
			"prep":
				boss.squeeze_d[i] = lerpf(HIDE, 0.0, smoothstep(0.0, 1.0, minf(1.0, tt / PREP)))
				if tt >= PREP:
					_go(s, "set")
			"set":
				boss.squeeze_d[i] = 0.0
				if tt >= SET:
					_go(s, "warn")
			"warn":
				boss.squeeze_d[i] = 0.0
				if tt >= WARN:
					_go(s, "push")
					boss.emit(Ev.SWING, Vector2(boss.ARENA_X * int(s["side"]), -1200))
			"push":
				var k := minf(1.0, tt / PUSH)
				boss.squeeze_d[i] = DEPTH * k * k
				if k >= 1.0:
					boss.hold_squeeze(i, DEPTH)
					boss.emit(Ev.PRESS, Vector2(boss.ARENA_X * int(s["side"]), -1200))
					_go(s, "done")
			"jam":                                            # 요격당함: 튕겨 원래 자리(벽 너머)로
				var k := minf(1.0, tt / JAM)
				boss.squeeze_d[i] = lerpf(float(s["jam_from"]), HIDE, 1.0 - (1.0 - k) * (1.0 - k))
				if k >= 1.0:
					boss.squeeze_d[i] = 0.0
					_go(s, "done")
		if s["phase"] != "done":
			live += 1
	if live == 0:
		boss.finish_attack()


func _go(s: Dictionary, ph: String) -> void:
	s["phase"] = ph
	s["t"] = 0.0


## 격벽 판의 사각형 (지금 파고든 깊이까지)
func _plate(s: Dictionary) -> Rect2:
	var sd: int = s["side"]
	var d: float = boss.squeeze_d[_idx(sd)]
	var edge: float = boss.ARENA_X * sd                 # 경기장 벽 (±1150)
	var inner: float = edge - sd * d
	var x0 := minf(inner, edge + sd * 400.0)
	var x1 := maxf(inner, edge + sd * 400.0)
	return Rect2(x0, boss.SPAWN_Y, x1 - x0, boss.FLOOR_Y - boss.SPAWN_Y + 80.0)


func _clashable(s: Dictionary) -> bool:
	return s["phase"] == "set" or s["phase"] == "warn" or s["phase"] == "push"


func hitboxes(ppos: Vector2, out: Array[Dictionary]) -> void:
	for s in sides:
		if s["phase"] != "push":
			continue
		var rc := _plate(s)
		out.append({"id": "clamp", "rect": rc, "pos": Vector2(clampf(ppos.x, rc.position.x, rc.end.x), ppos.y),
			"push": Vector2(-float(s["side"]), 0.0), "melee": true, "parry_push": true, "src": self, "plate": s})


func clash_box(ppos: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	for s in sides:
		if not _clashable(s):
			continue
		var rc := _plate(s)
		var face := Vector2(rc.position.x if int(s["side"]) > 0 else rc.end.x, clampf(ppos.y, rc.position.y, rc.end.y))
		var d := face.distance_to(ppos)
		if d < bd:
			bd = d
			best = {"id": "clamp", "rect": rc, "pos": face, "src": self, "plate": s}
	return best


func assist_targets(from: Vector2, out: Array[Dictionary]) -> void:
	for s in sides:
		if _clashable(s):
			var rc := _plate(s)
			var fx: float = rc.position.x if int(s["side"]) > 0 else rc.end.x
			out.append({"pos": Vector2(fx - 30.0 * int(s["side"]), clampf(from.y, boss.SPAWN_Y + 60.0, boss.FLOOR_Y - 60.0)), "r": 60.0, "intercept": true})


func melee_warning() -> bool:
	for s in sides:
		if s["phase"] == "set" or s["phase"] == "warn":
			return true
	return false


## 요격: 그쪽 격벽만 튕겨 돌아간다 (다른 쪽은 그대로)
func on_parried(hb: Dictionary) -> void:
	var s: Dictionary = hb.get("plate", {})
	if s.is_empty() or not _clashable(s):
		return
	s["jam_from"] = boss.squeeze_d[_idx(int(s["side"]))]
	_go(s, "jam")


func draw() -> void:
	var c: CanvasItem = boss
	for s in sides:
		if s["phase"] != "set" and s["phase"] != "warn":
			continue
		var sd: int = s["side"]
		var edge: float = boss.ARENA_X * sd
		var inner := edge - sd * DEPTH
		var level := 1 if s["phase"] == "set" else 2
		var top: float = boss.SPAWN_Y
		var bot: float = boss.FLOOR_Y
		MeleeWarn.zone(c, PackedVector2Array([Vector2(edge, top), Vector2(inner, top), Vector2(inner, bot), Vector2(edge, bot)]), level, boss.t)
		for ty in [-1900.0, -1200.0, -500.0]:
			MeleeWarn.tag(c, Vector2((edge + inner) * 0.5, ty), level, boss.t)
