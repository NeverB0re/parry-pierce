extends "res://scripts/attacks/tentacle.gd"
## 내려찍기 (근접, 회피 불가): 촉수가 몸 위로 솟았다가 플레이어 머리 위에서 채찍 끝을 겨누고, 세로 띠를 따라 바닥 근처까지 내리꽂는다.
## 옆으로 비켜 띠 밖으로 나가거나, 겨누고 멈춰 있는 동안(set·warn)·내리꽂히는 동안 차지 강습으로 요격한다. 패리하면 튕겨나기만 한다.
## 단계: prep(솟구치며 플레이어 x 를 따라감) → set(위치 고정) → warn(붉게 점멸) → strike(내리꽂힘, 판정) → lie(누워 있음, 무해) → 끝
## fast: 코어 페이즈 소용돌이용 빠른 박자.
## 척추: 0~5 마디 = 뿌리에서 위로 솟았다가 띠 꼭대기(joint)로 내려오는 곡선, 6~11 = 띠 안의 채찍 (판정)

const PREP := 0.8
const PREP_TRACK := 0.7
const SET := 0.3
const WARN := 0.6
const STRIKE := 0.24
const LIE := 0.35
const ABOVE := 620.0                 # 띠 꼭대기 = 플레이어보다 이만큼 위
const TOP_MIN := -2950.0
const TOP_MAX := -950.0
const BOTTOM := -140.0               # 채찍 끝이 멈추는 높이 (융해 지대 바로 위)
const POISE := 230.0                 # 겨누는 동안 채찍이 띠 꼭대기에서 내려와 있는 길이
const HALF := 46.0                   # 띠 반폭 (채찍 판정 반폭과 같다)

var x := 0.0
var top := -1600.0
var tip_y := 0.0
var _from := PackedVector2Array()
var _tm := 1.0                       # 박자 배율 (촉수를 잃을수록·코어 페이즈일수록 짧게)


func _init(tent: int, fast := false, wait := 0.0) -> void:
	kind = "slam"
	_grab([tent], "prep")
	hit_from = 6
	fixed_half = HALF
	delay = wait
	if fast:
		_tm = 0.6


func _aim(ppos: Vector2) -> void:
	x = clampf(ppos.x, -1080.0, 1080.0)
	top = clampf(ppos.y - ABOVE, TOP_MIN, TOP_MAX)


func _act(_dt: float, ppos: Vector2) -> void:
	var tm: float = _tm * boss.tempo()
	if _from.is_empty():
		_from = boss.spines[tents[0]].duplicate()
		_aim(ppos)
	match phase:
		"prep":
			var k := minf(1.0, t / (PREP * tm))
			if k < PREP_TRACK:
				_aim(ppos)
			tip_y = top + POISE
			boss.spines[tents[0]] = blend(_from, _pose(), smoothstep(0.0, 0.6, k))
			if k >= 1.0:
				set_phase("set")
		"set":
			boss.spines[tents[0]] = _pose()
			if t >= SET * tm:
				set_phase("warn")
		"warn":
			boss.spines[tents[0]] = _pose()
			if t >= WARN * tm:
				set_phase("strike")
				boss.emit(Ev.SWING, Vector2(x, top + POISE))
		"strike":
			var k := minf(1.0, t / STRIKE)
			tip_y = lerpf(top + POISE, BOTTOM, k * k)
			boss.spines[tents[0]] = _pose()
			if k >= 1.0:
				set_phase("lie")
				boss.emit(Ev.STOMP, Vector2(x, BOTTOM + 40.0))
		"lie":
			if t >= LIE * maxf(tm, 0.7):
				boss.finish_attack()


## 지금 척추: 뿌리 → 위로 솟음 → 띠 꼭대기(joint) → 채찍 끝
func _pose() -> PackedVector2Array:
	var i := tents[0]
	var root: Vector2 = boss.ROOTS[i]
	var j := Vector2(x, top)
	var c1 := root + Vector2((x - root.x) * 0.15, -420.0)
	var c2 := j + Vector2(0, -380.0)
	var sp := PackedVector2Array()
	for q in 6:
		var u := q / 5.0
		sp.append(root.bezier_interpolate(c1, c2, j, u))
	for q in range(1, 7):
		sp.append(j.lerp(Vector2(x, tip_y), q / 6.0))
	return sp


func _harmful() -> bool:
	return phase == "strike"


func _clashable() -> bool:
	return phase == "set" or phase == "warn" or phase == "strike"


func _push(_i: int, ppos: Vector2) -> Vector2:
	return Vector2(signf(ppos.x - x) if absf(ppos.x - x) > 1.0 else 1.0, 0.6).normalized()


func melee_warning() -> bool:
	return delay <= 0.0 and (phase == "prep" or phase == "set" or phase == "warn")


## 예고: 내리꽂힐 세로 띠 (띠 꼭대기 ~ 바닥). 준비 중엔 윤곽, 고정되면 빗금, 경고에서 점멸
func draw() -> void:
	if delay > 0.0 or not (phase == "prep" or phase == "set" or phase == "warn"):
		return
	var c: CanvasItem = boss
	var level := 0 if phase == "prep" else (1 if phase == "set" else 2)
	var area := PackedVector2Array([Vector2(x - HALF, top), Vector2(x + HALF, top), Vector2(x + HALF, BOTTOM), Vector2(x - HALF, BOTTOM)])
	MeleeWarn.zone(c, area, level, boss.t)
	MeleeWarn.tag(c, Vector2(x, top + 130.0), level, boss.t)          # 띠 꼭대기 쪽 (플레이어와 겹치지 않게)
