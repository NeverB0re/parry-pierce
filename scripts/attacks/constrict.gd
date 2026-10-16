extends "res://scripts/attacks/tentacle.gd"
## 조이기 (근접, 회피 불가): 촉수 둘이 플레이어를 둘러싼 고리를 만들고(왼쪽 반원·오른쪽 반원, 위아래에 좁은 틈) 조여 든다.
## 고리가 만들어진 뒤로는 고리에 닿으면 맞는다 → 위아래 틈으로 빠져나가거나, 한쪽 촉수를 요격하면 고리가 통째로 풀린다.
## 촉수를 2개 이상 잃은 뒤(남은 촉수가 화가 났을 때)와 코어 페이즈에서만 쓴다.
## 단계: prep(고리를 만들며 중심이 플레이어를 따라감) → set(고리 완성, 판정) → warn(점멸) → squeeze(조여 듦) → hold → 끝
## 척추: 0~4 마디 = 뿌리에서 고리 윗끝으로 내려오는 곡선, 5~11 = 반원 (판정)

const PREP := 0.8
const PREP_TRACK := 0.7
const SET := 0.35
const WARN := 0.6
const SQUEEZE := 0.9
const HOLD := 0.2
const R0 := 520.0
const R_END := 40.0
const GAP := 0.23                     # 위아래 틈 반각 (라디안, 약 13도씩)
# 반원 각도 (y 아래 = +): 왼쪽은 왼쪽 위 → 왼쪽 아래, 오른쪽은 오른쪽 위 → 오른쪽 아래
const ARCS := [[PI * 1.5 - GAP, PI * 0.5 + GAP], [-PI * 0.5 + GAP, PI * 0.5 - GAP]]

var center := Vector2.ZERO
var r := R0
var _from: Array = []


## a = 왼쪽 반원을 맡을 촉수, b = 오른쪽
func _init(a: int, b: int) -> void:
	kind = "constrict"
	_grab([a, b], "prep")
	hit_from = 5


func _act(_dt: float, ppos: Vector2) -> void:
	var tm: float = _tempo()
	if _from.is_empty():
		for i in tents:
			_from.append(boss.spines[i].duplicate())
		center = ppos
	match phase:
		"prep":
			var k := minf(1.0, t / (PREP * tm))
			if k < PREP_TRACK:
				center = ppos
			r = R0 * lerpf(1.5, 1.0, smoothstep(0.0, 1.0, k))
			for j in 2:
				boss.spines[tents[j]] = blend(_from[j], _pose(j), smoothstep(0.0, 0.7, k))
			if k >= 1.0:
				r = R0
				set_phase("set")
		"set":
			_pose_all()
			if t >= SET * tm:
				set_phase("warn")
		"warn":
			_pose_all()
			if t >= WARN * tm:
				set_phase("squeeze")
				boss.emit(Ev.SWING, center)
		"squeeze":
			var k := minf(1.0, t / SQUEEZE)
			r = lerpf(R0, R_END, k * k)
			_pose_all()
			if k >= 1.0:
				set_phase("hold")
		"hold":
			if t >= HOLD:
				boss.finish_attack()


func _pose_all() -> void:
	for j in 2:
		boss.spines[tents[j]] = _pose(j)


func _pose(j: int) -> PackedVector2Array:
	var root: Vector2 = boss.ROOTS[tents[j]]
	var a0: float = ARCS[j][0]
	var a1: float = ARCS[j][1]
	var e := center + Vector2.from_angle(a0) * r
	var c1 := root + Vector2(0, 320)
	var c2 := e + Vector2.from_angle(a0) * 260.0
	var sp := PackedVector2Array()
	for q in 5:
		sp.append(root.bezier_interpolate(c1, c2, e, q / 5.0))
	for q in 7:
		sp.append(center + Vector2.from_angle(lerpf(a0, a1, q / 6.0)) * r)
	return sp


func _harmful() -> bool:
	return phase == "set" or phase == "warn" or phase == "squeeze"


func _clashable() -> bool:
	return phase == "set" or phase == "warn" or phase == "squeeze"


## 고리 안쪽(중심)으로 조여 드는 방향
func _push(_i: int, ppos: Vector2) -> Vector2:
	var d := center - ppos
	return d.normalized() if d.length() > 1.0 else Vector2.UP


func melee_warning() -> bool:
	return phase == "prep" or phase == "set" or phase == "warn"


## 예고 (잔상식): 고리가 조여 들 안쪽 잔상(반지름 절반) + 안쪽으로 오는 궤적, 두 촉수가 달아오른다. 위아래 틈은 비어 있다
func draw() -> void:
	if not (phase == "prep" or phase == "set" or phase == "warn"):
		return
	var c: CanvasItem = boss
	var k := MeleeWarn.level_k(0 if phase == "prep" else (1 if phase == "set" else 2))
	for j in 2:
		var arc := PackedVector2Array()
		for q in 13:
			arc.append(center + Vector2.from_angle(lerpf(ARCS[j][0], ARCS[j][1], q / 12.0)) * r * 0.45)
		MeleeWarn.ghost(c, arc, 50.0, true, k)
		MeleeWarn.heat(c, boss.spines[tents[j]], hit_from, k)
		for f in [0.25, 0.5, 0.75]:
			var a: float = lerpf(ARCS[j][0], ARCS[j][1], f)
			MeleeWarn.trail_line(c, center + Vector2.from_angle(a) * (r - 40.0), center + Vector2.from_angle(a) * (r * 0.45 + 40.0), k)
