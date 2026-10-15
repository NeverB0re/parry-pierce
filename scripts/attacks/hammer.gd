extends "res://scripts/attacks/tentacle.gd"
## 몸통 내려치기 (근접, 회피 불가): 촉수가 플레이어 위에서 몸통을 가로로 길게(약 1040px) 눕혀 들었다가, 도끼질하듯 통째로 내려친다.
## 화면이 가로로 넓으므로 옆으로 막대 끝 밖까지 빠지거나, 막대가 멈추는 선 아래로 내려가야 한다. 막대가 들려 멈춘 동안(set·warn)·내려오는 동안 몸통 어디든 차지 강습으로 요격.
## 단계: prep(들어 올리며 플레이어를 따라감) → set → warn → strike(내려침, 판정) → lie(무해) → 끝. fast: 코어 페이즈 소용돌이용
## 척추: 0~3 = 뿌리에서 막대 한쪽 끝으로 오는 연결부, 4~11 = 가로 막대 (판정)

const PREP := 0.9
const PREP_TRACK := 0.7
const SET := 0.3
const WARN := 0.6
const STRIKE := 0.3
const LIE := 0.4
const HALF_LEN := 520.0              # 막대 반길이
const ABOVE := 520.0                 # 들어 올리는 높이 = 플레이어보다 이만큼 위
const BELOW := 380.0                 # 내려치고 멈추는 선 = 플레이어보다 이만큼 아래
const TOP_MIN := -2950.0
const STOP_MAX := -150.0
const HALF := 46.0                   # 막대 판정 반폭

var cx := 0.0
var y_top := -1600.0
var y_stop := -800.0
var y_bar := -1600.0
var _from := PackedVector2Array()
var pin_x := NAN                      # 정해진 x 에 내려친다 (행진 연타). NAN = 플레이어를 따라감


func _init(tent: int, fast := false, wait := 0.0, at_x := NAN) -> void:
	kind = "hammer"
	_grab([tent], "prep")
	hit_from = 4
	fixed_half = HALF
	delay = wait
	pin_x = at_x
	if fast:
		pace = 0.65


func _aim(ppos: Vector2) -> void:
	cx = clampf(ppos.x if is_nan(pin_x) else pin_x, -900.0, 900.0)
	y_top = clampf(ppos.y - ABOVE, TOP_MIN, -900.0)
	y_stop = minf(ppos.y + BELOW, STOP_MAX)
	y_bar = y_top


func _act(_dt: float, ppos: Vector2) -> void:
	var tm: float = _tempo()
	if _from.is_empty():
		_from = boss.spines[tents[0]].duplicate()
		_aim(ppos)
	match phase:
		"prep":
			var k := minf(1.0, t / (PREP * tm))
			if k < PREP_TRACK:
				_aim(ppos)
			boss.spines[tents[0]] = blend(_from, _pose(), smoothstep(0.0, 0.7, k))
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
				boss.emit(Ev.SWING, Vector2(cx, y_top))
		"strike":
			var k := minf(1.0, t / STRIKE)
			y_bar = lerpf(y_top, y_stop, k * k)
			boss.spines[tents[0]] = _pose()
			if k >= 1.0:
				set_phase("lie")
				boss.emit(Ev.STOMP, Vector2(cx, y_stop))
		"lie":
			if t >= LIE * maxf(tm, 0.7):
				boss.finish_attack()


func _pose() -> PackedVector2Array:
	var root: Vector2 = boss.ROOTS[tents[0]]
	var s := -1.0 if root.x < cx else 1.0              # 뿌리 쪽 끝 = 막대의 시작
	var e := Vector2(cx + s * HALF_LEN, y_bar)
	var f := Vector2(cx - s * HALF_LEN, y_bar)
	var c1 := root.lerp(e, 0.33) + Vector2(0, -220)
	var c2 := e + Vector2(s * 260.0, -160.0)
	var sp := PackedVector2Array()
	for q in 4:
		sp.append(root.bezier_interpolate(c1, c2, e, q / 4.0))
	for j in 8:
		sp.append(e.lerp(f, j / 7.0))
	return sp


func _track(ppos: Vector2) -> void:
	if is_nan(pin_x):
		_aim(ppos)


func _harmful() -> bool:
	return phase == "strike"


func _clashable() -> bool:
	return phase == "set" or phase == "warn" or phase == "strike"


func _push(_i: int, ppos: Vector2) -> Vector2:
	return Vector2(signf(ppos.x - cx) * 0.4, 1.0).normalized()


func melee_warning() -> bool:
	return delay <= 0.0 and (phase == "prep" or phase == "set" or phase == "warn")


## 예고: 막대가 내려치며 쓸고 갈 직사각형 (막대 위치 ~ 멈추는 선)
func draw() -> void:
	if delay > 0.0 or not (phase == "prep" or phase == "set" or phase == "warn"):
		return
	var c: CanvasItem = boss
	var level := _warn_level(0 if phase == "prep" else (1 if phase == "set" else 2))
	var x0 := cx - HALF_LEN - HALF
	var x1 := cx + HALF_LEN + HALF
	var area := PackedVector2Array([Vector2(x0, y_top - HALF), Vector2(x1, y_top - HALF), Vector2(x1, y_stop + HALF), Vector2(x0, y_stop + HALF)])
	MeleeWarn.zone(c, area, level, boss.t)
	for sx in [-0.6, 0.6]:
		MeleeWarn.tag(c, Vector2(cx + sx * HALF_LEN, y_top + 120.0), level, boss.t, order)
