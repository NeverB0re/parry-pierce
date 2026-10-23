extends "res://scripts/attacks/attack.gd"
## 대검 긋기 (관측자의 근접, docs/BOSS_observer.md 4장): 허공에 떠 있는 대검이 플레이어 옆으로 날아올라 자세를 잡고,
## 회전축(sword_piv)을 중심으로 큰 호를 그으며 벤다. 날에 닿으면 피해 (근접 = 회피 돌진 무적으로 못 피한다).
## 자세를 잡은 뒤(set·warn)와 긋는 중(swing)에는 차지 강습으로 요격할 수 있다 → 쳐낸 대검이 높이 튕겨 올라 돌며 떨어지다가
## 심장(코어)에 꽂힌다 (FLING_DMG: 퍼펙트 리버스 드라이브보다 세다 — 보이는 만큼 아프게).
## 그냥 패리하면(피해 0) 밀려나 잠시 멈췄다 돌아간다.
## 단계: rise → set → warn → swing → hold → return   (요격: → fling → stuck → return, 패리: → recoil → stagger → return)
## boss 에 필요한 것: sword_piv, sword_ang (대검 자세), SWORD_REST, sword_rest_ang(), HILT_GAP, BLADE_L, BLADE_W, core, emit

const MeleeWarn := preload("res://scripts/melee_warn.gd")
const RISE := 0.55                   # 날아올라 자세를 잡는다 (앞부분에서만 플레이어를 따라간다). 빠르게, 경고 없음 (v0.124)
const RISE_TRACK := 0.6
const SET := 0.3
const WARN := 1.0                    # 멈춘 뒤 경고를 충분히 (요격 대비)
const TIME := 0.6                    # 긋기
const HOLD := 0.25
const SPAN := 2.4                    # 긋는 각도 (라디안, 약 140도)
const PIV_D := 560.0                 # 회전축 ~ 플레이어 거리 (플레이어가 날 가운데쯤에 오게)
const RECOIL_ANGLE := 0.5
const RECOIL_TIME := 0.6
const STAGGER_TIME := 0.8
const FLING := 1.25                  # 쳐낸 대검: 높이 튕겨 올랐다가(앞 RISE_K) 돌며 떨어져 심장에 꽂히기까지
const FLING_RISE_K := 0.5
const FLING_UP := 1250.0             # 심장 위로 이만큼까지 튕겨 오른다
const FLING_SPIN := 3.0              # 도는 바퀴 수
const FLING_DMG := 24                # 꽂힐 때 피해 (퍼펙트 리버스 드라이브 16 보다 크게)
const STUCK := 0.9                   # 코어에 꽂힌 채 떨린다
const RETURN_TIME := 1.1
const AREA := Rect2(-950, -2650, 1900, 2150)   # 회전축이 머무는 범위 (경기장 안)

var piv := Vector2.ZERO              # 회전축
var th0 := 0.0
var th1 := 0.0
var th := 0.0
var th_from := 0.0
var from_piv := Vector2.ZERO         # 이번 동작을 시작한 자세
var from_ang := 0.0
var fling_dmg := 0
var trace_t := 0.0


func _init() -> void:
	kind = "sword"
	phase = "rise"


func start() -> void:
	from_piv = boss.sword_piv
	from_ang = boss.sword_ang


## 플레이어 옆(가운데 쪽 위)으로 회전축을 잡고, 플레이어 방향을 가운데 두고 위에서 아래로 긋는 각도 범위를 정한다
func aim_at(ppos: Vector2) -> void:
	var side := -1.0 if ppos.x > 0.0 else 1.0             # 회전축은 플레이어보다 경기장 가운데 쪽
	var p := ppos + Vector2(side * 0.8, -0.6).normalized() * PIV_D
	piv = Vector2(clampf(p.x, AREA.position.x, AREA.end.x), clampf(p.y, AREA.position.y, AREA.end.y))
	var phi := (ppos - piv).angle()
	var s := 1.0 if cos(phi) >= 0.0 else -1.0            # 오른쪽을 겨누면 시계 방향(위 → 아래), 왼쪽이면 반대
	th0 = phi - s * SPAN * 0.5
	th1 = phi + s * SPAN * 0.5
	th = th0


func step(dt: float, ppos: Vector2) -> void:
	if from_piv == Vector2.ZERO:
		start()
	if phase == "set" or phase == "warn":
		trace_t += dt
	match phase:
		"rise":
			var k := minf(1.0, t / RISE)
			if k < RISE_TRACK:
				aim_at(ppos)
			var e := smoothstep(0.0, 1.0, k)
			boss.sword_piv = from_piv.lerp(piv, e) + Vector2(0, -180.0 * sin(k * PI))   # 떠오르며 날아간다
			boss.sword_ang = lerp_angle(from_ang, th0, e)
			if t >= RISE:
				set_phase("set")
		"set", "warn":
			boss.sword_piv = piv
			boss.sword_ang = th0
			if phase == "set" and t >= SET:
				set_phase("warn")
			elif phase == "warn" and t >= WARN:
				set_phase("swing")
				boss.emit(Ev.SWING, tip())
		"swing":
			var k := minf(1.0, t / TIME)
			th = lerpf(th0, th1, k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65)
			boss.sword_ang = th
			if k >= 1.0:
				set_phase("hold")
		"hold":
			if t >= HOLD:
				_begin_return()
		"recoil":
			var k := minf(1.0, t / RECOIL_TIME)
			boss.sword_ang = th_from - signf(th1 - th0) * RECOIL_ANGLE * (1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				set_phase("stagger")
		"stagger":
			if t >= STAGGER_TIME:
				_begin_return()
		"fling":                                   # 높이 튕겨 올라 돌다가, 칼끝을 아래로 세우며 떨어져 심장에 꽂힌다
			var c: Vector2 = boss.core.center
			var down := Vector2.DOWN
			var end_piv: Vector2 = c - down * (boss.HILT_GAP + boss.BLADE_L * 0.85)
			var apex := Vector2(lerpf(from_piv.x, c.x, 0.6), c.y - FLING_UP)
			var k := minf(1.0, t / FLING)
			var pos: Vector2
			if k < FLING_RISE_K:                   # 오른다: 점점 느려진다
				var u := k / FLING_RISE_K
				pos = from_piv.lerp(apex, 1.0 - (1.0 - u) * (1.0 - u))
			else:                                  # 떨어진다: 점점 빨라진다
				var u := (k - FLING_RISE_K) / (1.0 - FLING_RISE_K)
				pos = apex.lerp(end_piv, u * u)
			boss.sword_piv = pos
			var spin := from_ang + FLING_SPIN * TAU * (1.0 - (1.0 - k) * (1.0 - k))   # 돌다가 느려지며
			boss.sword_ang = lerp_angle(spin, down.angle(), smoothstep(0.55, 0.9, k))   # 칼끝을 아래로 세운다
			if k >= 1.0:
				boss.emit(Ev.STOMP, c)
				boss.emit(Ev.REFLECT_HIT, c, {"hit": {"kind": "core", "n": Vector2.UP}, "dmg": float(fling_dmg), "sword": true})
				set_phase("stuck")
		"stuck":
			if t >= STUCK:
				_begin_return()
		"return":
			var k := minf(1.0, t / RETURN_TIME)
			var e := smoothstep(0.0, 1.0, k)
			boss.sword_piv = from_piv.lerp(boss.SWORD_REST, e)
			boss.sword_ang = lerp_angle(from_ang, boss.sword_rest_ang(), e)
			if k >= 1.0:
				boss.finish_attack()


func _begin_return() -> void:
	from_piv = boss.sword_piv
	from_ang = boss.sword_ang
	set_phase("return")


## 날 판정 선분 (날밑 ~ 칼끝)
func seg() -> Array:
	var d := Vector2.from_angle(boss.sword_ang)
	return [boss.sword_piv + d * boss.HILT_GAP, tip(), boss.BLADE_W]


func tip() -> Vector2:
	return boss.sword_piv + Vector2.from_angle(boss.sword_ang) * (boss.HILT_GAP + boss.BLADE_L)


func _box(ppos: Vector2) -> Dictionary:
	var sg := seg()
	return {"id": "arm", "segs": [sg], "pos": boss.seg_closest(ppos, sg[0], sg[1])}   # "arm" = 근접 판정 (그냥 패리하면 튕겨나기만, main.gd)


func hitboxes(ppos: Vector2, out: Array[Dictionary]) -> void:
	if phase != "swing":
		return
	var hb := _box(ppos)
	var d := Vector2.from_angle(boss.sword_ang)
	hb["push"] = (d.orthogonal() * signf(th1 - th0) + Vector2(0, -0.5)).normalized()
	hb["melee"] = true
	hb["src"] = self
	out.append(hb)


func clash_box(ppos: Vector2) -> Dictionary:
	if phase != "set" and phase != "warn" and phase != "swing":
		return {}
	var hb := _box(ppos)
	hb["fling"] = true                        # 요격하면 쳐낸 대검이 코어에 꽂힌다 (main._clash 가 요격 피해를 dmg 로 넣어 준다)
	hb["src"] = self
	return hb


func assist_targets(from: Vector2, out: Array[Dictionary]) -> void:
	if phase == "set" or phase == "warn" or phase == "swing":
		out.append({"pos": _box(from)["pos"], "r": 40.0, "intercept": true})


## 요격(피해 있음) = 코어로 날아가 꽂힌다 / 패리(피해 없음) = 밀려나 멈춘다
func on_parried(hb: Dictionary) -> void:
	if hb.get("id", "") != "arm":
		return
	fling_dmg = FLING_DMG if int(hb.get("dmg", 0)) > 0 else 0
	from_piv = boss.sword_piv
	from_ang = boss.sword_ang
	th_from = boss.sword_ang
	set_phase("fling" if fling_dmg > 0 else "recoil")


func melee_warning() -> bool:
	return phase == "set" or phase == "warn"


func release_stagger() -> void:
	if phase == "recoil" or phase == "stagger":
		_begin_return()


# ── 예고 ───────────────────────────────────────────────
## 날이 쓸고 지나갈 부채꼴 띠 (날밑 ~ 칼끝). 판정과 대략 맞춘 단순한 모양
func area() -> PackedVector2Array:
	var inner: float = boss.HILT_GAP - boss.BLADE_W
	var outer: float = (boss.HILT_GAP + boss.BLADE_L + boss.BLADE_W) / cos(SPAN / 48.0)
	var band := PackedVector2Array()
	for j in 25:
		band.append(piv + Vector2.from_angle(lerpf(th0, th1, j / 24.0)) * outer)
	for j in range(24, -1, -1):
		band.append(piv + Vector2.from_angle(lerpf(th0, th1, j / 24.0)) * inner)
	return band


func draw() -> void:
	if phase != "set" and phase != "warn":                  # 날아오르는 준비 동작(rise) 중엔 경고 없음
		return
	var c: CanvasItem = boss
	var level := 1 if phase == "set" else 2
	MeleeWarn.zone(c, area(), level, boss.t)
	var mid := (th0 + th1) * 0.5
	MeleeWarn.tag(c, piv + Vector2.from_angle(mid) * (boss.HILT_GAP + boss.BLADE_L * 0.55), level, boss.t)
	MeleeWarn.arc_trace(c, piv, (boss.HILT_GAP + boss.BLADE_L) * 0.8, th0, th1, trace_t / MeleeWarn.TRACE_TIME)
