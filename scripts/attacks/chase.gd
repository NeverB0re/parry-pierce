extends "res://scripts/attacks/tentacle.gd"
## 추적 감아치기 (근접, 회피 불가): 촉수 끝마디가 플레이어 곁(STANDOFF)을 따라다니며 압박하다가, 멈춰 옆으로 젖힌 뒤 짧고 빠르게 휘감아 친다.
## 따라다니는 동안은 무해(예고 윤곽만). 멈추면 감아칠 부채꼴이 고정된다 → 부채꼴 밖으로 빠지거나, 따라다니는 중·멈춘 동안·감아치는 중에 차지 강습으로 요격.
## 단계: follow(따라다님) → set(젖힘, 위치 고정) → warn(점멸) → whip(감아침, 판정) → hold → 끝
## 척추: 0~4 = 뿌리에서 축(pivot)까지, 5~11 = 끝마디 (판정)

const FOLLOW := 1.8
const SET := 0.3
const WARN := 0.5
const WHIP := 0.3
const HOLD := 0.2
const STANDOFF := 430.0              # 축이 플레이어에게서 떨어져 따라다니는 거리
const REACH := 600.0                 # 끝마디 길이 (감아치는 반경)
const SPAN := 2.4                    # 감아치는 각도
const MAX_FROM_ROOT := 2100.0

var pivot := Vector2.ZERO
var th := 0.0
var th0 := 0.0
var th1 := 0.0
var _area := PackedVector2Array()
var _started := false


func _init(tent: int) -> void:
	kind = "chase"
	_grab([tent], "follow")
	hit_from = 5


func _act(dt: float, ppos: Vector2) -> void:
	var tm: float = _tempo()
	var root: Vector2 = boss.ROOTS[tents[0]]
	if not _started:
		_started = true
		pivot = boss.spines[tents[0]][5]
		th = (ppos - pivot).angle()
	match phase:
		"follow":
			var want := ppos + (root - ppos).normalized() * STANDOFF
			if want.distance_to(root) > MAX_FROM_ROOT:
				want = root + (want - root).normalized() * MAX_FROM_ROOT
			pivot = pivot.lerp(want, 1.0 - exp(-3.0 * dt))
			th = lerp_angle(th, (ppos - pivot).angle(), 1.0 - exp(-6.0 * dt))
			boss.spines[tents[0]] = _pose(th, 0.75)
			if t >= FOLLOW * tm:
				var phi := (ppos - pivot).angle()
				var root_side := signf(boss.ROOTS[tents[0]].x)   # 항상 바깥쪽에서 안쪽(몸 가운데 쪽)으로 감아친다
				var s := 1.0 if Vector2.from_angle(phi).orthogonal().x * root_side < 0.0 else -1.0
				th0 = phi - s * SPAN * 0.5
				th1 = phi + s * SPAN * 0.5
				_area = _sector()
				set_phase("set")
		"set":
			th = lerp_angle(th, th0, minf(1.0, t / (SET * tm)))
			boss.spines[tents[0]] = _pose(th, 1.0)
			if t >= SET * tm:
				th = th0
				set_phase("warn")
		"warn":
			boss.spines[tents[0]] = _pose(th0, 1.0)
			if t >= WARN * tm:
				set_phase("whip")
				boss.emit(Ev.SWING, pivot)
		"whip":
			var k := minf(1.0, t / WHIP)
			th = lerpf(th0, th1, k * k * (3.0 - 2.0 * k))
			boss.spines[tents[0]] = _pose(th, 1.0)
			if k >= 1.0:
				set_phase("hold")
		"hold":
			if t >= HOLD:
				boss.finish_attack()


## 척추: 뿌리 → 축(곡선) → 축에서 a 방향으로 끝마디 (길이 REACH × len_k)
func _pose(a: float, len_k: float) -> PackedVector2Array:
	var root: Vector2 = boss.ROOTS[tents[0]]
	var c1 := root + Vector2(0, 300)
	var c2 := pivot - Vector2.from_angle(a) * 300.0
	var sp := PackedVector2Array()
	for q in 5:
		sp.append(root.bezier_interpolate(c1, c2, pivot, q / 5.0))
	var d := Vector2.from_angle(a)
	for q in 7:
		sp.append(pivot + d * REACH * len_k * (q / 6.0))
	return sp


func _sector() -> PackedVector2Array:
	var r1: float = REACH + boss.width_at(boss.N - 1) * 0.5 + 10.0
	var pts := PackedVector2Array([pivot])
	for q in 25:
		pts.append(pivot + Vector2.from_angle(lerpf(th0, th1, q / 24.0)) * r1)
	return pts


func _harmful() -> bool:
	return phase == "whip"


func _clashable() -> bool:
	return phase == "follow" or phase == "set" or phase == "warn" or phase == "whip"


func _push(_i: int, _ppos: Vector2) -> Vector2:
	return Vector2(-sin(th), cos(th)) * signf(th1 - th0)


func melee_warning() -> bool:
	return phase == "follow" or phase == "set" or phase == "warn"


## 예고 (잔상식): 따라다니는 동안은 닿을 수 있는 원의 옅은 윤곽만, 멈추면 감아친 끝 자세의 잔상 + 호 궤적 + 달아오름
func draw() -> void:
	var c: CanvasItem = boss
	if phase == "follow":
		c.draw_arc(pivot, REACH, 0.0, TAU, 40, Color(MeleeWarn.C_GHOST_NEXT, 0.18), 2.0)
		return
	if phase != "set" and phase != "warn":
		return
	var k := MeleeWarn.level_k(1 if phase == "set" else 2)
	MeleeWarn.ghost(c, _pose(th1, 1.0).slice(hit_from), 50.0, true, k)
	MeleeWarn.heat(c, boss.spines[tents[0]], hit_from, k)
	MeleeWarn.trail_arc(c, pivot, REACH * 0.7, th0 + (th1 - th0) * 0.06, th1 - (th1 - th0) * 0.04, k)
