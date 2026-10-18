extends "res://scripts/attacks/tentacle.gd"
## 조이기 (근접, 회피 불가): 촉수 둘이 플레이어를 칭칭 감는다 (각자 한 바퀴 넘게 나선으로 감아 서로 엇갈린다) → 조여 든다.
## 감긴 뒤로는 고리에 닿으면 맞는다. 촉수 하나만으로도 한 바퀴를 넘게 감으므로, 두 촉수를 모두 요격해야 풀린다
## (하나를 요격하면 그 촉수만 풀려 물러나고, 남은 촉수는 계속 조인다).
## 촉수를 2개 이상 잃은 뒤(남은 촉수가 화가 났을 때)와 코어 페이즈에서만 쓴다.
## 단계: prep(고리를 만들며 중심이 플레이어를 따라감) → set(고리 완성, 판정) → warn(점멸) → squeeze(조여 듦) → hold → 끝
## 척추: 0~3 마디 = 뿌리에서 감기 시작점으로 내려오는 곡선, 4~11 = 나선 (판정)

const PREP := 0.8
const PREP_TRACK := 0.7
const SET := 0.35
const WARN := 0.6
const SQUEEZE := 0.9
const HOLD := 0.2
const R0 := 520.0
const R_END := 40.0
# 나선: 감기 시작 각도와 감는 양. 둘 다 같은 방향으로 감되 반 바퀴 어긋나 서로 엇갈린다
const COIL_START := [PI * 1.5, PI * 0.5]
const COIL_TURN := TAU * 1.15
const COIL_IN := 0.22                 # 감을수록 안쪽으로 (나선) — 두 촉수가 겹쳐 칭칭 감긴 느낌

var center := Vector2.ZERO
var r := R0
var _from: Array = []
var released: Array[int] = []         # 요격당해 먼저 풀린 촉수


## a = 왼쪽 반원을 맡을 촉수, b = 오른쪽
func _init(a: int, b: int) -> void:
	kind = "constrict"
	_grab([a, b], "prep")
	hit_from = 4


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
		if released.has(tents[j]):                    # 먼저 풀린 촉수: 쉬는 자세로 물러난다
			boss.spines[tents[j]] = blend(boss.spines[tents[j]], boss._idle_spine(tents[j]), 0.12)
			continue
		boss.spines[tents[j]] = _pose(j)


func _pose(j: int) -> PackedVector2Array:
	var root: Vector2 = boss.ROOTS[tents[j]]
	var a0: float = COIL_START[j]
	var e := center + Vector2.from_angle(a0) * r * (1.0 + COIL_IN * 0.5)
	var c1 := root + Vector2(0, 320)
	var c2 := e + Vector2.from_angle(a0) * 300.0
	var sp := PackedVector2Array()
	for q in 4:
		sp.append(root.bezier_interpolate(c1, c2, e, q / 4.0))
	for q in 8:
		var f := q / 7.0
		sp.append(center + Vector2.from_angle(a0 + COIL_TURN * f) * r * (1.0 + COIL_IN * (0.5 - f)))
	return sp


func _active_tents() -> Array[int]:
	var out: Array[int] = []
	for i in tents:
		if not released.has(i):
			out.append(i)
	return out


## 요격: 첫 번째는 그 촉수만 풀려 물러나고 (남은 촉수는 계속 조인다), 두 번째에 모두 풀린다
func on_parried(hb: Dictionary) -> void:
	if phase == "recoil" or phase == "stagger" or phase == "end":
		return
	var i := int(hb.get("tent", tents[0]))
	if released.size() + 1 < tents.size() and not released.has(i):
		released.append(i)
		lead = false
		boss.hit_dir = hb.get("dir", Vector2.UP)
		boss.hit_dir_t = boss.t
		return
	super(hb)


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


## 예고: 감길 고리 전체 (원) + 촉수마다 표지 (요격할 곳이 둘)
func draw() -> void:
	if not (phase == "prep" or phase == "set" or phase == "warn"):
		return
	var c: CanvasItem = boss
	var level := 0 if phase == "prep" else (1 if phase == "set" else 2)
	var rr: float = r * (1.0 + COIL_IN * 0.5) + boss.width_at(boss.N - 1) * 0.5
	var pts := PackedVector2Array([center])
	for q in 33:
		pts.append(center + Vector2.from_angle(q * TAU / 32.0) * rr)
	MeleeWarn.zone(c, pts, level, boss.t)
	for j in 2:
		if not released.has(tents[j]):
			MeleeWarn.tag(c, center + Vector2.from_angle(COIL_START[j]) * rr * 0.5, level, boss.t)
