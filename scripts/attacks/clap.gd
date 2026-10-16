extends "res://scripts/attacks/tentacle.gd"
## 압착 (근접, 회피 불가): 촉수 둘이 양쪽 벽 가까이에 몸통을 세로로 세우고(플레이어 높이, 약 660px), 손뼉 치듯 플레이어 쪽으로 닫는다.
## 가운데에서 맞부딪히므로 안전한 틈이 없다 → 세운 몸통 위나 아래로 빠져나가거나, 한쪽을 요격하면 둘 다 풀린다.
## 단계: prep(벽 쪽에 세우며 플레이어 높이·위치를 따라감) → set → warn → close(닫힘, 판정) → hold → 끝
## 척추: 0~3 = 뿌리에서 세운 몸통 위끝으로 오는 연결부, 4~11 = 세로 몸통 (판정)

const PREP := 0.8
const PREP_TRACK := 0.7
const SET := 0.3
const WARN := 0.6
const CLOSE := 0.45
const HOLD := 0.25
const HALF_H := 330.0                # 세운 몸통 반높이
const START_X := 1060.0              # 닫기 전 몸통 위치 (벽 가까이)
const MEET := 30.0                   # 가운데에서 이만큼 남기고 맞부딪힌다 (틈 없음)
const HALF := 44.0

var cx := 0.0
var cy := -1300.0
var x := [-START_X, START_X]
var _from: Array = []


## a = 왼쪽 몸통, b = 오른쪽 몸통
func _init(a: int, b: int) -> void:
	kind = "clap"
	_grab([a, b], "prep")
	hit_from = 4
	fixed_half = HALF


func _aim(ppos: Vector2) -> void:
	cx = clampf(ppos.x, -700.0, 700.0)
	cy = clampf(ppos.y, -2600.0, -500.0)


func _act(_dt: float, ppos: Vector2) -> void:
	var tm: float = _tempo()
	if _from.is_empty():
		for i in tents:
			_from.append(boss.spines[i].duplicate())
		_aim(ppos)
	match phase:
		"prep":
			var k := minf(1.0, t / (PREP * tm))
			if k < PREP_TRACK:
				_aim(ppos)
			for j in 2:
				boss.spines[tents[j]] = blend(_from[j], _pose(j), smoothstep(0.0, 0.7, k))
			if k >= 1.0:
				set_phase("set")
		"set":
			_pose_all()
			if t >= SET * tm:
				set_phase("warn")
		"warn":
			_pose_all()
			if t >= WARN * tm:
				set_phase("close")
		"close":
			var k := minf(1.0, t / CLOSE)
			var e := k * k
			x = [lerpf(-START_X, cx - MEET, e), lerpf(START_X, cx + MEET, e)]
			_pose_all()
			if k >= 1.0:
				set_phase("hold")
				boss.emit(Ev.SWING, Vector2(cx, cy))
		"hold":
			if t >= HOLD:
				boss.finish_attack()


func _pose_all() -> void:
	for j in 2:
		boss.spines[tents[j]] = _pose(j)


func _pose(j: int) -> PackedVector2Array:
	var root: Vector2 = boss.ROOTS[tents[j]]
	var top := Vector2(x[j], cy - HALF_H)
	var bot := Vector2(x[j], cy + HALF_H)
	var c1 := root + Vector2((x[j] - root.x) * 0.3, 260.0)
	var c2 := top + Vector2(0, -320.0)
	var sp := PackedVector2Array()
	for q in 4:
		sp.append(root.bezier_interpolate(c1, c2, top, q / 4.0))
	for q in 8:
		sp.append(top.lerp(bot, q / 7.0))
	return sp


func _harmful() -> bool:
	return phase == "close"


func _clashable() -> bool:
	return phase == "set" or phase == "warn" or phase == "close"


## 맞부딪히는 몸통 사이에서 위아래로 짜내진다
func _push(_i: int, ppos: Vector2) -> Vector2:
	return Vector2(0, 1.0 if ppos.y >= cy else -1.0)


func melee_warning() -> bool:
	return phase == "prep" or phase == "set" or phase == "warn"


## 예고 (잔상식): 두 몸통이 맞부딪힐 가운데 자리의 잔상 + 벽 쪽에서 가운데로 오는 궤적, 두 몸통이 달아오른다
func draw() -> void:
	if not (phase == "prep" or phase == "set" or phase == "warn"):
		return
	var c: CanvasItem = boss
	var k := MeleeWarn.level_k(0 if phase == "prep" else (1 if phase == "set" else 2))
	var keep: Array = x
	x = [cx - MEET, cx + MEET]
	for j in 2:
		MeleeWarn.ghost(c, _pose(j).slice(hit_from), HALF * 2.0, true, k)
	x = keep
	for j in 2:
		MeleeWarn.heat(c, boss.spines[tents[j]], hit_from, k)
		var sx: float = signf(cx - x[j])
		for dy in [-0.6, 0.0, 0.6]:
			var y: float = cy + HALF_H * dy
			MeleeWarn.trail_line(c, Vector2(x[j] + sx * HALF, y), Vector2(cx - sx * (MEET + HALF), y), k)
