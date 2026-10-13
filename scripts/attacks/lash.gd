extends "res://scripts/attacks/tentacle.gd"
## 휩쓸기 (근접, 회피 불가): 촉수를 곧게 뻗어 뿌리를 축으로 넓은 부채꼴을 쓸어 간다 (관측자 팔 휘두르기의 촉수판).
## 바깥쪽에서 안쪽으로 쓴다. 부채꼴 밖(뻗은 길이 너머·뿌리 위)으로 피하거나, 위치를 잡고 멈춘 동안(set·warn)·쓰는 중에 차지 강습으로 요격한다.
## 단계: prep(뒤로 젖힘, 앞부분만 조준) → set → warn → swing(판정) → hold → 끝

const PREP := 0.85
const PREP_TRACK := 0.6
const SET := 0.3
const WARN := 0.7
const TIME := 0.7
const HOLD := 0.25
const SPAN := 1.9                    # 휩쓰는 각도 (라디안, 약 110도)
const REACH := 1650.0                # 뿌리 ~ 촉수 끝
const ANG_MIN := -0.3                # 몸 위쪽(배경)을 지나지 않게 각도를 묶는다 (y 아래 = +)
const ANG_MAX := PI + 0.3

var th0 := 0.0
var th1 := 0.0
var th := 0.0
var _from := PackedVector2Array()
var _area := PackedVector2Array()


func _init(tent: int) -> void:
	kind = "sweep"
	_grab([tent], "prep")
	hit_from = 3


## 플레이어 방향을 가운데 두고, 바깥쪽(촉수가 달린 쪽)에서 안쪽으로 SPAN 만큼
func aim_at(ppos: Vector2) -> void:
	var root: Vector2 = boss.ROOTS[tents[0]]
	var phi := (ppos - root).angle()
	if phi < -PI * 0.5:                    # 왼쪽 위는 π 쪽으로 이어 붙인다
		phi += TAU
	phi = clampf(phi, ANG_MIN + SPAN * 0.5, ANG_MAX - SPAN * 0.5)
	if root.x < 0.0:                       # 왼쪽 촉수: 왼쪽(큰 각) → 오른쪽(작은 각)
		th0 = phi + SPAN * 0.5
		th1 = phi - SPAN * 0.5
	else:
		th0 = phi - SPAN * 0.5
		th1 = phi + SPAN * 0.5
	th = th0


func _line(a: float, reach := REACH) -> PackedVector2Array:
	var root: Vector2 = boss.ROOTS[tents[0]]
	var sp := PackedVector2Array()
	var n: int = boss.N
	var d := Vector2.from_angle(a)
	var side := d.orthogonal()
	for q in n:
		var f := float(q) / (n - 1)
		sp.append(root + d * reach * f + side * sin(f * PI) * 30.0 * sin(boss.t * 3.0 + tents[0]))
	return sp


func _act(_dt: float, ppos: Vector2) -> void:
	var tm: float = boss.tempo()
	if _from.is_empty():
		_from = boss.spines[tents[0]].duplicate()
		aim_at(ppos)
	match phase:
		"prep":
			var k := minf(1.0, t / (PREP * tm))
			if k < PREP_TRACK:
				aim_at(ppos)
			var back := (th0 - th1) * 0.18 * sin(k * PI)       # 반대쪽으로 살짝 젖혔다가
			boss.spines[tents[0]] = blend(_from, _line(th0 + back, REACH * lerpf(0.8, 1.0, k)), smoothstep(0.0, 0.5, k))
			if k >= 1.0:
				_area = _sector()
				set_phase("set")
		"set":
			boss.spines[tents[0]] = _line(th0)
			if t >= SET * tm:
				set_phase("warn")
		"warn":
			boss.spines[tents[0]] = _line(th0)
			if t >= WARN * tm:
				set_phase("swing")
				boss.emit(Ev.SWING, boss.spines[tents[0]][boss.N - 1])
		"swing":
			var k := minf(1.0, t / TIME)
			th = lerpf(th0, th1, k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65)
			boss.spines[tents[0]] = _line(th)
			if k >= 1.0:
				set_phase("hold")
		"hold":
			if t >= HOLD:
				boss.finish_attack()


## 쓸고 지나갈 범위 (판정 마디 ~ 끝, 굵기 포함). 위치가 고정되면 한 번만 계산한다
func _sector() -> PackedVector2Array:
	var root: Vector2 = boss.ROOTS[tents[0]]
	var n: int = boss.N
	var r0 := REACH * float(hit_from) / (n - 1)
	var r1: float = REACH + boss.width_at(n - 1) * 0.5 + 10.0
	var pts := PackedVector2Array()
	for q in 21:
		pts.append(root + Vector2.from_angle(lerpf(th0, th1, q / 20.0)) * r1)
	for q in 21:
		pts.append(root + Vector2.from_angle(lerpf(th1, th0, q / 20.0)) * r0)
	return pts


func _harmful() -> bool:
	return phase == "swing"


func _clashable() -> bool:
	return phase == "set" or phase == "warn" or phase == "swing"


## 쓸고 가는 방향으로 밀려난다 (살짝 위로)
func _push(_i: int, _ppos: Vector2) -> Vector2:
	var tangent := Vector2(-sin(th), cos(th)) * signf(th1 - th0)
	return (tangent + Vector2(0, -0.5)).normalized()


func melee_warning() -> bool:
	return phase == "prep" or phase == "set" or phase == "warn"


func draw() -> void:
	if not (phase == "prep" or phase == "set" or phase == "warn"):
		return
	var c: CanvasItem = boss
	var level := 0 if phase == "prep" else (1 if phase == "set" else 2)
	var area := _area if not _area.is_empty() else _sector()
	MeleeWarn.zone(c, area, level, boss.t)
	var root: Vector2 = boss.ROOTS[tents[0]]
	MeleeWarn.tag(c, root + Vector2.from_angle((th0 + th1) * 0.5) * REACH * 0.6, level, boss.t)
