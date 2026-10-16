extends "res://scripts/attacks/attack.gd"
## 팔 휘두르기: 팔 전체를 곧게 뻗어 부채꼴로 휩쓴다. 팔 어디에 닿아도 피해 → 패리하거나 회피 돌진(무적)으로 빠져나간다.
## 위치를 잡고 멈춰 있을 때(set·warn)와 휘두르는 중(swing)에는 차지 강습으로 요격할 수 있다. 들어올리는 중(prep)은 아니다.
## 패리·요격당하면 휩쓸던 반대쪽으로 밀려난 뒤(recoil) 잠시 멈춰(stagger) 관절이 드러난다.
## 단계: prep → set → warn → swing → hold → return  (요격·패리: → recoil → stagger → return)
## boss 에 필요한 것: SHOULDERS, FIST_IDLE, fists, SWING_L, ELBOW_AT, UPPER_W, FORE_W, FIST_R, arm_box(a, ppos)

const MeleeWarn := preload("res://scripts/melee_warn.gd")
const PREP := 0.9                    # 준비 모션: 팔이 뒤로 젖혀졌다 목표 위치로 (앞부분에서만 플레이어를 따라간다)
const PREP_TRACK := 0.6              # 준비 모션의 이 비율까지만 조준. 이후 위치 확정
const SET := 0.3                     # 팔 위치 고정 (예상 범위 윤곽만 표시)
const WARN := 0.8                    # 실제 공격 범위가 붉게 점멸
const TIME := 0.65
const HOLD := 0.25
const SPAN := 2.6                    # 휩쓰는 각도(라디안, 약 150도)
const RECOIL_ANGLE := 0.5            # 패리당하면 휩쓸던 반대쪽으로 이만큼(라디안) 밀려난다
const RECOIL_TIME := 0.7
const STAGGER_TIME := 1.0            # 밀려난 뒤 팔이 멈춰 관절이 드러나는 시간
const RETURN_TIME := 1.4
const C_WARN := Color(1.0, 0.3, 0.25)

var arm := 0
var from := Vector2.ZERO             # 준비 모션을 시작한 주먹 위치
var th0 := 0.0                       # 휩쓰는 각도 범위 (팔 방향 = (s*cos, sin), s = 오른팔 +1 / 왼팔 -1)
var th1 := 0.0
var th := 0.0
var th_from := 0.0                   # 밀려나기 시작한 각도
var trace_t := 0.0                   # 방향 점선이 그어진 시간
var _area_key := Vector3.INF          # 예고 범위 캐시 (위치가 고정된 뒤엔 다시 계산하지 않는다)
var _area := PackedVector2Array()


func _init(a: int, part_idx: int, from_fist: Vector2) -> void:
	kind = "swing"
	arm = a
	part = part_idx
	from = from_fist
	phase = "prep"


## 플레이어 방향을 가운데 두고 SPAN 만큼 휩쓰는 각도 범위를 정한다
func aim_at(ppos: Vector2) -> void:
	var sh: Vector2 = boss.SHOULDERS[arm]
	var s := 1.0 if arm == 1 else -1.0
	var d := ppos - sh
	var phi := atan2(d.y, d.x * s)
	th0 = clampf(phi - SPAN * 0.5, -3.0, 0.4)
	th1 = th0 + SPAN
	th = th0


func fist_at(a: float) -> Vector2:
	var s := 1.0 if arm == 1 else -1.0
	return boss.SHOULDERS[arm] + Vector2(s * cos(a), sin(a)) * boss.SWING_L


func step(dt: float, ppos: Vector2) -> void:
	if phase == "set" or phase == "warn":
		trace_t += dt
	match phase:
		"prep":
			var k := minf(1.0, t / PREP)
			if k < PREP_TRACK:
				aim_at(ppos)
			var pre_th := th0 - 0.35 * sin(k * PI)
			th = pre_th
			boss.fists[arm] = from.lerp(fist_at(pre_th), smoothstep(0.0, 0.4, k))
			if t >= PREP:
				set_phase("set")
		"set":                                     # 팔 고정 (이후 플레이어가 움직여도 경로는 바뀌지 않는다)
			th = th0
			boss.fists[arm] = fist_at(th0)
			if t >= SET:
				set_phase("warn")
		"warn":                                    # 실제 공격 범위가 붉게 점멸
			th = th0
			boss.fists[arm] = fist_at(th0)
			if t >= WARN:
				set_phase("swing")
				boss.emit(Ev.SWING, boss.fists[arm])
		"swing":
			var k := minf(1.0, t / TIME)
			th = lerpf(th0, th1, k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65)   # 거의 등속, 시작만 살짝 느리게
			boss.fists[arm] = fist_at(th)
			if k >= 1.0:
				set_phase("hold")
		"hold":
			if t >= HOLD:
				set_phase("return")
		"recoil":
			var k := minf(1.0, t / RECOIL_TIME)
			th = th_from - RECOIL_ANGLE * (1.0 - (1.0 - k) * (1.0 - k))   # 감속하며 반대쪽으로
			boss.fists[arm] = fist_at(th)
			if k >= 1.0:
				set_phase("stagger")
		"stagger":
			if t >= STAGGER_TIME:
				set_phase("return")
		"return":                                  # 천천히 제자리로 (팔꿈치가 튀지 않게)
			boss.fists[arm] = boss.fists[arm].lerp(boss.FIST_IDLE[arm], minf(1.0, dt * 3.0))
			if t >= RETURN_TIME:
				boss.fists[arm] = boss.FIST_IDLE[arm]
				boss.finish_attack()


func hitboxes(ppos: Vector2, out: Array[Dictionary]) -> void:
	if phase != "swing":
		return
	var s := 1.0 if arm == 1 else -1.0
	var tangent := Vector2(-s * sin(th), cos(th))
	var hb: Dictionary = boss.arm_box(arm, ppos)
	hb["push"] = (tangent + Vector2(0, -0.5)).normalized()
	hb["melee"] = true                         # 근접공격 = 회피 불가
	hb["src"] = self
	out.append(hb)


func clash_box(ppos: Vector2) -> Dictionary:
	if phase != "set" and phase != "warn" and phase != "swing":
		return {}
	var hb: Dictionary = boss.arm_box(arm, ppos)
	hb["part"] = part
	return hb


## 요격할 수 있는 동안 팔에서 플레이어에게 가장 가까운 지점을 어시스트 우선 표적으로
func assist_targets(from: Vector2, out: Array[Dictionary]) -> void:
	if phase == "set" or phase == "warn" or phase == "swing":
		out.append({"pos": boss.arm_box(arm, from)["pos"], "r": 40.0, "intercept": true})


func on_parried(hb: Dictionary) -> void:
	if hb["id"] == "arm":
		th_from = th
		set_phase("recoil")


## 리버스 드라이브가 끝나면 경직을 풀고 바로 제자리로
func melee_warning() -> bool:
	return phase == "prep" or phase == "set" or phase == "warn"


func release_stagger() -> void:
	if phase == "recoil" or phase == "stagger":
		set_phase("return")


# ── 예고 ───────────────────────────────────────────────
## 실제 판정과 같은 범위: 준비 중엔 옅은 윤곽, 고정되면 또렷한 윤곽, 경고에서는 붉게 점멸
func draw() -> void:
	if phase != "prep" and phase != "set" and phase != "warn":
		return
	var c: CanvasItem = boss
	var s := 1.0 if arm == 1 else -1.0
	var sh: Vector2 = boss.SHOULDERS[arm]
	var area := area_cached()
	var level := 0 if phase == "prep" else (1 if phase == "set" else 2)
	MeleeWarn.zone(c, area, level, boss.t)                 # 모든 근접공격이 같은 예고 모양(빗금 위험구간 + ⚠)을 쓴다
	var mid := (th0 + th1) * 0.5
	MeleeWarn.tag(c, sh + Vector2(s * cos(mid), sin(mid)) * boss.SWING_L * 0.55, level, boss.t)
	MeleeWarn.limb(c, PackedVector2Array([sh, boss.elbow_of(arm), boss.fists[arm]]), level, boss.t)   # 어느 팔이 치는지
	var a0: float = th0 if s > 0.0 else PI - th0            # 휩쓰는 방향: 호를 따라 흐르는 큰 화살표 (팔 각도 → 화면 각도)
	var a1: float = th1 if s > 0.0 else PI - th1
	MeleeWarn.arc_trace(c, sh, boss.SWING_L * 0.8, a0, a1, trace_t / MeleeWarn.TRACE_TIME)


## 같은 각도면 계산을 재사용한다 (예고 중 매 프레임 다각형 합치기를 하지 않게)
func area_cached() -> PackedVector2Array:
	var key := Vector3(arm, snappedf(th0, 0.001), snappedf(th1, 0.001))
	if key != _area_key:
		_area_key = key
		_area = area()
	return _area


## 휩쓸기가 실제로 닿는 영역 (판정과 동일: 위팔/아래팔/주먹이 th0~th1 을 쓸고 지나가는 합집합)
func area() -> PackedVector2Array:
	var s := 1.0 if arm == 1 else -1.0
	var sh: Vector2 = boss.SHOULDERS[arm]
	var reach: float = boss.SWING_L
	var upper_w: float = boss.UPPER_W
	var fore_w: float = boss.FORE_W
	var fist_r: float = boss.FIST_R
	var pieces: Array[PackedVector2Array] = []
	var wedge := PackedVector2Array([sh])
	for j in 25:
		var a := lerpf(th0, th1, j / 24.0)
		wedge.append(sh + Vector2(s * cos(a), sin(a)) * ((reach + fist_r) / cos(SPAN / 48.0)))   # 현 근사가 판정 안쪽으로 파고들지 않게 약간 바깥
	pieces.append(wedge)
	for ti in 2:
		var a := th0 if ti == 0 else th1
		var d := Vector2(s * cos(a), sin(a))
		var n := d.orthogonal()
		var el: Vector2 = sh + d * reach * boss.ELBOW_AT
		var fist := sh + d * reach
		pieces.append(PackedVector2Array([sh + n * upper_w, el + n * upper_w, el - n * upper_w, sh - n * upper_w]))
		pieces.append(PackedVector2Array([el + n * fore_w, fist + n * fore_w, fist - n * fore_w, el - n * fore_w]))
		pieces.append(_disc(fist, fist_r))
		pieces.append(_disc(el, upper_w))              # 위팔 끝의 둥근 마감
	pieces.append(_disc(sh, upper_w))                  # 어깨 쪽 둥근 마감
	var cur := pieces[0]
	for k in range(1, pieces.size()):
		for r in Geometry2D.merge_polygons(cur, pieces[k]):
			if not Geometry2D.is_polygon_clockwise(r):
				cur = r
				break
	return cur


## 원을 바깥에 접하는 다각형으로 근사 (예고 영역이 판정을 빠뜨리지 않도록)
static func _disc(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in 24:
		out.append(c + Vector2.from_angle(TAU * j / 24.0) * r / cos(PI / 24.0))
	return out
