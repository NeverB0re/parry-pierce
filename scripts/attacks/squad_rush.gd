extends "res://scripts/attacks/attack.gd"
## 돌격 편대 (모함, 진홍 = 근접): 한 기씩 차례로 플레이어 곁으로 날아와 겨누고(진홍 예고 띠) 멈췄다가, 그 줄을 따라 몸통째 들이받는다.
## 근접이라 일반 돌진으로 피할 수 없다 — 겨누고 멈춘 순간(warn)이나 들이받는 중에 차지 강습으로 요격하면 그 드론에 피해 + 튕겨 나가 순서가 넘어간다.
## 순서: 편대원 → 편대장 (마지막이 가장 단단하다). 예고는 지금 차례 한 기만 또렷하게 (다음 기는 순번 표시만).
## boss 에 필요한 것: squad_alive(s), want_drone(i, pos), hold_drone(i, pos), drone_pos(i), is_leader(i), DRONE_R

const MeleeWarn := preload("res://scripts/melee_warn.gd")
const AIM := 0.75                    # 플레이어 곁 자리로 날아오며 겨눈다 (앞쪽은 플레이어를 따라감)
const AIM_TRACK := 0.55
const WARN := 0.5                    # 멈춰 겨눈다 (요격 기회)
const STRIKE := 0.26                 # 들이받기 (판정)
const RECOVER := 0.35
const STAND := 470.0                 # 겨누는 자리 = 플레이어에서 이만큼
const REACH := 980.0                 # 들이받는 거리 (플레이어를 지나 반대쪽까지)
const HALF := 40.0                   # 몸통 판정 반폭
const KNOCK := 300.0                 # 요격당하면 튕겨 나가는 거리
const KNOCK_TIME := 0.4

var squad := 0
var order: Array = []                # 들이받을 차례 (드론 번호)
var cur := 0                         # order 안의 지금 차례
var from := Vector2.ZERO             # 겨눈 자리 (들이받기 시작점)
var to := Vector2.ZERO               # 들이받기 끝점
var prev := Vector2.ZERO             # 지난 프레임 드론 위치 (판정 = 그 사이를 쓴 몸통)
var knock_from := Vector2.ZERO
var knock_dir := Vector2.ZERO


func _init(s: int) -> void:
	kind = "squad_rush"
	phase = "aim"
	squad = s


func _drone() -> int:
	return int(order[cur]) if cur < order.size() else -1


func step(_dt: float, ppos: Vector2) -> void:
	if order.is_empty():
		var ids: Array = boss.squad_alive(squad)
		for i in ids:                                  # 편대원 먼저, 편대장이 마지막
			if not boss.is_leader(i):
				order.append(i)
		for i in ids:
			if boss.is_leader(i):
				order.append(i)
		if order.is_empty():
			boss.finish_attack()
			return
	while cur < order.size() and not boss.part_alive(_drone()):   # 이미 부서진 드론은 건너뛴다
		_next()
	if cur >= order.size():
		boss.finish_attack()
		return
	var i := _drone()
	for k in range(cur + 1, order.size()):              # 기다리는 기체는 플레이어 둘레에서 순서를 기다린다
		var j: int = order[k]
		if boss.part_alive(j):
			var a: float = (boss.drone_pos(j) - ppos).angle()
			boss.want_drone(j, ppos + Vector2.from_angle(a) * 760.0)
	match phase:
		"aim":
			if t < AIM_TRACK or from == Vector2.ZERO:
				var side: Vector2 = (boss.drone_pos(i) - ppos).normalized()
				if side.length() < 0.1:
					side = Vector2.UP
				from = ppos + side * STAND
				to = from + (ppos - from).normalized() * REACH
			boss.want_drone(i, from)
			if t >= AIM:
				boss.hold_drone(i, from)
				set_phase("warn")
		"warn":
			boss.hold_drone(i, from)
			if t >= WARN:
				prev = from
				dodged = false                         # 차례마다 새 공격 (앞 기체를 무적으로 지났다고 이번 것까지 통과하지 않게)
				set_phase("strike")
				boss.emit(Ev.SWING, from)
		"strike":
			prev = boss.drone_pos(i)
			var k := minf(1.0, t / STRIKE)
			boss.hold_drone(i, from.lerp(to, k * k))
			if k >= 1.0:
				set_phase("recover")
		"recover":
			boss.want_drone(i, to)
			if t >= RECOVER:
				_next()
		"knocked":
			var k := minf(1.0, t / KNOCK_TIME)
			boss.hold_drone(i, knock_from + knock_dir * KNOCK * (1.0 - (1.0 - k) * (1.0 - k)))
			if k >= 1.0:
				_next()


func _next() -> void:
	cur += 1
	from = Vector2.ZERO
	set_phase("aim")


func _box(ppos: Vector2) -> Dictionary:
	var i := _drone()
	var p: Vector2 = boss.drone_pos(i)
	var a := prev if phase == "strike" else p
	var q: Vector2 = boss.seg_closest(ppos, a, p)
	return {"id": "rush", "segs": [[a, p, HALF]], "pos": q, "src": self, "drone": i}


func hitboxes(ppos: Vector2, out: Array[Dictionary]) -> void:
	if phase != "strike" or _drone() < 0:
		return
	var hb := _box(ppos)
	var nrm := (to - from).normalized().orthogonal()
	hb["push"] = nrm if nrm.dot(ppos - from) >= 0.0 else -nrm      # 줄 바깥으로 밀려난다
	hb["melee"] = true
	out.append(hb)


func clash_box(ppos: Vector2) -> Dictionary:
	if (phase != "warn" and phase != "strike") or _drone() < 0:
		return {}
	var hb := _box(ppos)
	hb["part"] = _drone()                              # 요격 = 그 드론에 피해 (main._clash 가 damage_part)
	return hb


func assist_targets(_from: Vector2, out: Array[Dictionary]) -> void:
	if (phase == "warn" or phase == "strike") and _drone() >= 0:
		out.append({"pos": boss.drone_pos(_drone()), "r": 50.0, "intercept": true})


## 요격당함: 그 드론이 부딪힌 방향으로 튕겨 나가고, 다음 차례로 넘어간다
func on_parried(hb: Dictionary) -> void:
	if phase != "warn" and phase != "strike":
		return
	knock_from = boss.drone_pos(_drone())
	knock_dir = hb.get("dir", Vector2.UP)
	if knock_dir.length() < 0.1:
		knock_dir = Vector2.UP
	knock_dir = knock_dir.normalized()
	set_phase("knocked")


func melee_warning() -> bool:
	return phase == "aim" or phase == "warn"


## 예고: 지금 차례의 들이받을 줄 (진홍 띠) + 순번 표시. 기다리는 기체는 순번만
func draw() -> void:
	var i := _drone()
	if i < 0:
		return
	var c: CanvasItem = boss
	for k in range(cur, order.size()):
		var j: int = order[k]
		if boss.part_alive(j):
			MeleeWarn.tag(c, boss.drone_pos(j) + Vector2(0, -78), 2 if k == cur and phase == "warn" else (1 if k == cur else 0), boss.t, k - cur)
	if phase != "aim" and phase != "warn":
		return
	if from == Vector2.ZERO:
		return
	var level := 1 if phase == "aim" else 2
	var d := (to - from).normalized()
	var n := d.orthogonal() * HALF
	var area := PackedVector2Array([from + n, to + n, to - n, from - n])
	MeleeWarn.zone(c, area, level, boss.t)
