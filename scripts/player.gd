extends Node2D
## 플레이어: 작은 로켓. 머리는 평소 마우스 방향, 노즐 화염 길이가 추진 상태(활공/낙하)를 보여준다.
## 시뮬레이션은 main.gd 가 step() 으로 직접 호출한다(히트스톱/슬로모션 제어 때문).

# ── 튜닝값 ─────────────────────────────────────────────
const RADIUS := 12.0
const GRAVITY := 900.0
const BASE_FALL := 480.0         # 마우스가 수평일 때 낙하 속도 상한
const GLIDE_FALL := 140.0        # 마우스를 위로: 거의 떠 있다 (공격을 기다려 패리). 스스로 상승은 불가
const DIVE_FALL := 1000.0        # 마우스를 아래로: 빨리 떨어진다
const THRUST := 560.0            # 약한 무한 추진(좌우/하강)
const AIR_DRAG := 0.9
const PLATFORM_SPEED := 260.0
const EVADE_SPEED := 2000.0      # 회피 돌진: 공격 판정 없음, 무적. 사거리 약 560px
const EVADE_TIME := 0.28
const DASH_KEEP := 0.5           # 돌진이 끝난 뒤 남기는 속도 비율
const DASH_COOLDOWN := 0.1
const CHARGE_TIME := 0.6         # 좌클릭을 이만큼 누르면 차지 완료 → 떼면 공격 돌진 (짧게 떼면 회피)
const CHARGE_HOVER := 0.15       # 이 시간 이상 누르면 차지 자세(공중 정지)로 들어간다
const CHARGE_AUTO := 0.5         # 차지 완료 후 이 시간이 지나면 자동 발사
const CHARGE_SPEED := 3600.0     # 차지 돌진: 빠르게 꽂힌다. 사거리 약 790px
const CHARGE_DASH_TIME := 0.22
const CHARGE_COOLDOWN := 1.5     # 차지 돌진 후 다시 차지할 수 있을 때까지 (그동안 좌클릭 = 즉시 회피)
const CHARGE_DAMAGE := 1
const CHARGE_GRACE := 0.5        # 차지 돌진이 빗나가 끝난 직후 무적
const GAUGE_MAX := 3             # 회피 1칸, 차지 1칸, 패리 성공 시 가득. 자연 회복 없음
const PERFECT_WINDOW := 0.07     # 패리 누른 뒤 이 시간 안에 막으면 PERFECT
const PARRY_MIN := 0.12          # 짧게 눌러도 이 시간만큼은 패리 유지
const PARRY_HOLD_MAX := 0.28     # 꾹 누르고 있을 때 패리 판정 최대 유지 시간
const PARRY_COOLDOWN := 0.55     # 끝까지 버틴 뒤 재입력 대기 (남발 방지)
const PARRY_RELEASE_CD := 0.25   # 중간에 뗐을 때 재입력 대기
const PARRY_REACH := 30.0        # 패리 판정은 몸보다 이만큼 넓다
const AIM_TIME := 0.84           # 패리 성공 후 방향을 정하는 슬로우 시간(실시간 초)
const AIM_TIME_PERFECT := 1.2
const PARRY_DASH_SPEED := 3600.0 # 패리 돌진: 주력 공격. 월드가 느려져도 플레이어는 실시간
const PARRY_DASH_SPEED_PERFECT := 4000.0
const PARRY_DASH_TIME := 0.22
const POWER_DAMAGE := 3
const POWER_RADIUS := 8.0        # 패리 돌진은 타격 범위도 넓다
const POWER_GRACE := 0.7
const BOUNCE_UP := 1050.0        # 직격 후 위로 튀어오르는 속도
const BOUNCE_SIDE := 250.0       # 들어온 방향의 반대쪽으로 튕기는 가로 속도
const BOUNCE_STEER := 750.0      # 튕길 때 마우스 좌우 방향으로 더하는 가로 속도 (좌우 조종)
const BOUNCE_THRUST := 2.0       # 튕겨나는 동안 좌우 추진 배율
const STRIKE_SHIELD := 0.9       # 직격 후 튕겨나는 동안 무적 시간
const STUN_TIME := 0.9           # 피격(공격/표적 접촉) → 조작 불가
const STUN_INVULN := 0.4         # 스턴이 끝난 뒤 추가 무적
const HURT_PUSH := 500.0
const HURT_POP := 380.0          # 맞으면 살짝 솟구친다
const LAUNCH_SPEED := 1850.0     # 발판에서의 첫 돌진 = 발사 (게이지 소모 없음). 정점 약 y -2400 (어깨 높이)
const LAUNCH_FLOAT := 0.25       # 발사 직후 중력 없음
const LAUNCH_STEER := 0.25       # 발사 방향에 마우스 좌우가 반영되는 정도
const ROT_SPEED := 12.0          # 머리가 마우스를 따라 도는 빠르기
const AIM_DEADZONE := 40.0       # 마우스가 기체에 이만큼 가까우면 방향 유지 (떨림 방지)
const WALL_L := -1150.0
const WALL_R := 1150.0
const CEILING := -3300.0
const PLAT_CENTER := Vector2(650, -40)   # 시작 발판 윗면 중앙
const PLAT_HALF := 90.0

const C_BODY := Color(0.93, 0.94, 0.96)
const C_TRIM := Color(0.45, 0.8, 1.0)
const C_EVADE := Color(0.6, 0.85, 1.0)
const C_ATTACK := Color(1.0, 0.55, 0.2)

var main: Node
var boss: Node

var vel := Vector2.ZERO
var gauge := GAUGE_MAX
var on_platform := false
var dash_t := 0.0
var dash_kind := ""              # "evade" | "charge" | "power"
var dash_total := EVADE_TIME
var perfect_dash := false        # PERFECT 패리 돌진
var charge_cd := 0.0             # 차지 쿨다운
var charging := false            # 좌클릭 누르는 중
var charge_t := 0.0
var charged_notified := false
var dash_cd := 0.0
var parry_active := false
var parry_held := false
var parry_t := 0.0
var parry_cd := 0.0
var aim_phase := false           # 패리 성공 → 슬로우 → 방향 지정
var aim_left := 0.0
var aim_perfect := false
var invuln := 0.0                # 피격 후 무적
var bouncing := false            # 직격 후 튕겨나는 중
var shield_t := 0.0              # 돌진/직격 후 무적
var shield_max := 1.0
var stun := 0.0
var launch_t := 0.0
var aim := Vector2.UP
var facing := -PI * 0.5
var trail: Array[Vector2] = []
var parry_flash := 0.0
var frozen := false              # 승리/용암 연출 중 정지


func reset(pos: Vector2, platform := false) -> void:
	position = pos
	vel = Vector2.ZERO
	gauge = GAUGE_MAX
	on_platform = platform
	dash_t = 0.0
	dash_kind = ""
	perfect_dash = false
	charging = false
	charge_t = 0.0
	bouncing = false
	dash_cd = 0.0
	charge_cd = 0.0
	parry_active = false
	parry_held = false
	parry_cd = 0.0
	aim_phase = false
	invuln = 0.0
	shield_t = 0.0
	stun = 0.0
	launch_t = 0.0
	aim = Vector2.UP
	facing = -PI * 0.5
	frozen = false
	visible = true
	trail.clear()
	queue_redraw()


func is_immune() -> bool:
	return frozen or aim_phase or dash_t > 0.0 or shield_t > 0.0 or invuln > 0.0 or launch_t > 0.0


func is_attacking() -> bool:
	return dash_t > 0.0 and dash_kind != "evade"


func is_charged() -> bool:
	return charging and charge_t >= CHARGE_TIME


func is_hovering_charge() -> bool:
	return charging and charge_t >= CHARGE_HOVER


func can_dash() -> bool:
	return not (frozen or aim_phase or stun > 0.0 or dash_cd > 0.0 or gauge <= 0)


## 좌클릭 누름: 발판 위면 발사, 아니면 게이지 1칸 쓰고 차지 시작 (짧게 떼면 회피, 끝까지 모으면 공격)
func press_dash() -> void:
	if on_platform and not frozen and stun <= 0.0:
		_launch()
		return
	if charging or not can_dash():
		return
	if charge_cd > 0.0:                 # 차지 쿨다운 중엔 바로 회피
		try_dash()
		return
	gauge -= 1
	charging = true
	charge_t = 0.0
	charged_notified = false


## 좌클릭 뗌
func release_dash() -> void:
	if not charging:
		return
	charging = false
	_dash("charge" if charge_t >= CHARGE_TIME else "evade")


## 즉시 회피 돌진 (테스트/키 입력용)
func try_dash() -> void:
	if not can_dash():
		return
	gauge -= 1
	_dash("evade")


## 차지 취소(피격/패리 전환): 소모한 칸을 돌려준다
func cancel_charge() -> void:
	if not charging:
		return
	charging = false
	gauge = mini(GAUGE_MAX, gauge + 1)


func _dash(kind: String) -> void:
	dash_kind = kind
	var spd := EVADE_SPEED
	dash_total = EVADE_TIME
	if kind == "charge":
		spd = CHARGE_SPEED
		dash_total = CHARGE_DASH_TIME
		charge_cd = CHARGE_COOLDOWN
	dash_t = dash_total
	dash_cd = dash_total + DASH_COOLDOWN
	vel = aim * spd
	bouncing = false
	main.on_dash(position, aim, kind)


func _launch() -> void:
	on_platform = false
	launch_t = LAUNCH_FLOAT
	vel = Vector2(aim.x * LAUNCH_STEER, -1.0).normalized() * LAUNCH_SPEED
	main.on_launch(position)


func parry_press() -> void:
	parry_held = true
	cancel_charge()
	if frozen or aim_phase or parry_active or parry_cd > 0.0 or stun > 0.0:
		return
	parry_active = true
	parry_t = 0.0


func parry_release() -> void:
	parry_held = false


func parry_reach() -> float:
	return RADIUS + (PARRY_REACH if parry_active else 0.0)


func on_parry_success(perfect: bool) -> void:
	parry_active = false
	parry_cd = 0.0
	dash_t = 0.0
	_end_dash()
	on_platform = false
	launch_t = 0.0
	vel = Vector2.ZERO
	gauge = GAUGE_MAX              # 패리 성공 = 연료 가득
	aim_phase = true               # 시간이 느려지고 방향을 정한다
	aim_perfect = perfect
	aim_left = AIM_TIME_PERFECT if perfect else AIM_TIME
	parry_flash = 1.0


## 방향 지정 종료 → 마우스 방향으로 패리 돌진(공격 판정, 강한 데미지)
func launch_parry_dash() -> void:
	if not aim_phase:
		return
	aim_phase = false
	dash_kind = "power"
	perfect_dash = aim_perfect
	dash_total = PARRY_DASH_TIME
	dash_t = PARRY_DASH_TIME
	dash_cd = PARRY_DASH_TIME + DASH_COOLDOWN
	vel = aim * (PARRY_DASH_SPEED_PERFECT if aim_perfect else PARRY_DASH_SPEED)
	parry_cd = PARRY_RELEASE_CD
	main.on_parry_launch(position, aim)


## 피격: 잠시 조작 불가(스턴), 살짝 솟구친 뒤 추락
func on_hurt(push: Vector2) -> void:
	cancel_charge()
	var sx := signf(push.x) if absf(push.x) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	vel = Vector2(sx * HURT_PUSH, -HURT_POP)
	stun = STUN_TIME
	invuln = STUN_TIME + STUN_INVULN
	dash_t = 0.0
	dash_kind = ""
	perfect_dash = false
	parry_active = false
	bouncing = false
	on_platform = false
	launch_t = 0.0


func step(dt: float) -> void:
	if frozen:
		queue_redraw()
		return
	var m := get_global_mouse_position() - position
	if m.length() > AIM_DEADZONE:
		aim = m.normalized()
	if aim_phase:
		facing = lerp_angle(facing, aim.angle(), 1.0 - exp(-ROT_SPEED * 2.0 * dt))
		queue_redraw()
		return

	dash_cd = maxf(0.0, dash_cd - dt)
	charge_cd = maxf(0.0, charge_cd - dt)
	parry_cd = maxf(0.0, parry_cd - dt)
	invuln = maxf(0.0, invuln - dt)
	shield_t = maxf(0.0, shield_t - dt)
	if shield_t <= 0.0:
		bouncing = false
	launch_t = maxf(0.0, launch_t - dt)
	parry_flash = maxf(0.0, parry_flash - dt * 4.0)
	if stun > 0.0:
		stun -= dt
		if stun <= 0.0:
			stun = 0.0
			main.on_stun_recover(position)
	if charging:
		charge_t += dt
		if charge_t >= CHARGE_TIME and not charged_notified:
			charged_notified = true
			main.on_charged(position)
		if charge_t >= CHARGE_TIME + CHARGE_AUTO:   # 차지 완료 후 잠시 지나면 자동 발사
			release_dash()
	if parry_active:
		parry_t += dt
		if parry_t > PARRY_HOLD_MAX:
			parry_active = false
			parry_cd = PARRY_COOLDOWN
		elif not parry_held and parry_t >= PARRY_MIN:
			parry_active = false
			parry_cd = PARRY_RELEASE_CD

	if on_platform:
		vel.y = 0.0
		var want := 0.0
		if absf(m.x) > 30.0:
			want = signf(m.x) * PLATFORM_SPEED
		vel.x = move_toward(vel.x, want, 2000.0 * dt)
	elif dash_t > 0.0:
		dash_t -= dt
		if dash_t <= 0.0:
			vel *= DASH_KEEP
			var grace := POWER_GRACE if dash_kind == "power" else (CHARGE_GRACE if dash_kind == "charge" else 0.0)
			if grace > 0.0:                   # 무적 여유는 패리 돌진/차지 돌진만
				shield_max = grace
				shield_t = grace
			_end_dash()
	elif launch_t > 0.0:
		pass                                  # 발사 직후: 중력 없이 곧게 솟는다
	else:
		var fall_cap := BASE_FALL
		if stun > 0.0:
			fall_cap = DIVE_FALL
		elif m.length() > AIM_DEADZONE:
			vel.x += aim.x * THRUST * (BOUNCE_THRUST if bouncing else 1.0) * dt
			if aim.y > 0.0:
				vel.y += aim.y * THRUST * dt
				fall_cap = lerpf(BASE_FALL, DIVE_FALL, aim.y)
			else:
				fall_cap = lerpf(BASE_FALL, GLIDE_FALL, -aim.y)
		if is_hovering_charge():              # 차지 중엔 공중에서 거의 멈춰 조준한다
			vel.y += GRAVITY * 0.2 * dt
			vel.y = move_toward(vel.y, 0.0, 1500.0 * dt)
			vel.x -= vel.x * 4.0 * dt
		else:
			vel.y += GRAVITY * dt
			vel.x -= vel.x * AIR_DRAG * dt
		if vel.y > fall_cap:
			vel.y = move_toward(vel.y, fall_cap, 2500.0 * dt)

	_move(dt)
	if frozen:
		return

	# 머리 방향: 평소엔 마우스, 돌진·발사·튕김 중엔 진행 방향, 스턴 중엔 빙글빙글
	if stun > 0.0:
		facing += 14.0 * dt
	else:
		var tdir := aim
		if (dash_t > 0.0 or launch_t > 0.0 or bouncing) and vel.length() > 60.0:
			tdir = vel.normalized()
		facing = lerp_angle(facing, tdir.angle(), 1.0 - exp(-ROT_SPEED * dt))

	trail.push_front(position)
	if trail.size() > 16:
		trail.pop_back()
	queue_redraw()


func _move(dt: float) -> void:
	var steps := clampi(int(ceil(vel.length() * dt / 6.0)), 1, 12)
	var sdt := dt / steps
	for s in steps:
		var prev_y := position.y
		position += vel * sdt
		if on_platform:
			position.x = clampf(position.x, PLAT_CENTER.x - PLAT_HALF + RADIUS, PLAT_CENTER.x + PLAT_HALF - RADIUS)
			position.y = PLAT_CENTER.y - RADIUS
			continue
		# 표적(부위·갑옷·심장)은 상시 판정: 공격 돌진 중이면 타격, 아니면(회피 돌진 제외) 닿는 순간 스턴
		var hit: Dictionary = boss.strike_hit(position, RADIUS + (POWER_RADIUS if dash_kind == "power" else 0.0))
		if not hit.is_empty():
			if is_attacking():
				_on_strike(hit)
				if frozen:
					return
			elif not is_immune():
				main.touch_hurt(hit, position)
		# 벽/천장
		if position.x < WALL_L + RADIUS:
			position.x = WALL_L + RADIUS
			vel.x = absf(vel.x) * 0.5
		elif position.x > WALL_R - RADIUS:
			position.x = WALL_R - RADIUS
			vel.x = -absf(vel.x) * 0.5
		if position.y < CEILING:
			position.y = CEILING
			vel.y = absf(vel.y) * 0.3
		# 발판 (재출격 직후 등 발판이 떠 있을 때만)
		var top := PLAT_CENTER.y - RADIUS
		if main.plat_on and vel.y >= 0.0 and prev_y <= top + 0.5 and position.y >= top \
				and absf(position.x - PLAT_CENTER.x) <= PLAT_HALF:
			position.y = top
			on_platform = true
			vel = Vector2.ZERO
			dash_t = 0.0
			_end_dash()
			return
		# 용암
		if position.y > -RADIUS * 0.3:
			main.on_lava(position)
			return


## 공격 돌진 종료(적중·빗나감 모두). 패리 돌진이 끝나면 슬로우가 풀리고 밀려난 팔이 돌아간다
func _end_dash() -> void:
	var was_power := dash_kind == "power"
	dash_kind = ""
	perfect_dash = false
	if was_power:
		main.on_power_dash_end()


func _on_strike(hit: Dictionary) -> void:
	if hit["kind"] == "heart":
		main.on_heart_pierced(position)
		return
	var dir := vel.normalized()
	var power := dash_kind == "power"
	gauge = mini(GAUGE_MAX, gauge + 1)           # 타격 성공 → 돌진 연료 1칸 환급
	main.on_strike(hit, POWER_DAMAGE if power else CHARGE_DAMAGE, position, dir, power)
	dash_t = 0.0
	_end_dash()
	bouncing = true
	shield_t = STRIKE_SHIELD                     # 튕겨나는 동안 무적
	shield_max = STRIKE_SHIELD
	var k := 1.24 if power else 1.0
	vel = Vector2(-dir.x * BOUNCE_SIDE + aim.x * BOUNCE_STEER, -BOUNCE_UP * k)  # 직격 → 위로 튀되 좌우는 마우스로 조종


# ── 그리기 ─────────────────────────────────────────────
## 레이저 같은 실선 사거리 표시 (끝으로 갈수록 옅어짐)
func _laser(dir: Vector2, reach: float, c: Color) -> void:
	var n := 14
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var fade := lerpf(1.0, 0.35, t0)
		var p0 := dir * lerpf(40.0, reach, t0)
		var p1 := dir * lerpf(40.0, reach, t1)
		draw_line(p0, p1, Color(c, 0.16 * fade), 8.0)
		draw_line(p0, p1, Color(c, 0.5 * fade), 3.2)
		draw_line(p0, p1, Color(1, 1, 1, 0.9 * fade), 1.3)
	var tip := dir * reach
	draw_circle(tip, 5.0, Color(c, 0.9))
	draw_circle(tip, 3.0, Color(1, 1, 1))
	draw_arc(tip, 12.0, 0.0, TAU, 16, Color(c, 0.7), 2.0)


## 로켓 본체 (기수 +x 방향, 길이 약 56px)
func _draw_rocket(off: Vector2, ang: float, tint: Color) -> void:
	var body := [Vector2(30, 0), Vector2(16, -7), Vector2(-16, -7), Vector2(-21, -5), Vector2(-21, 5), Vector2(-16, 7), Vector2(16, 7)]
	var nose := [Vector2(30, 0), Vector2(16, -7), Vector2(16, 7)]
	var fin_a := [Vector2(-8, -7), Vector2(-25, -16), Vector2(-21, -7)]
	var fin_b := [Vector2(-8, 7), Vector2(-25, 16), Vector2(-21, 7)]
	for poly in [[fin_a, C_TRIM * 0.8], [fin_b, C_TRIM * 0.8], [body, C_BODY], [nose, C_TRIM]]:
		var pts := PackedVector2Array()
		for p in poly[0]:
			pts.append(off + (p as Vector2).rotated(ang))
		var c: Color = poly[1]
		draw_colored_polygon(pts, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, tint.a))
	draw_circle(off + Vector2(4, 0).rotated(ang), 3.6, Color(0.08, 0.1, 0.16, tint.a))
	draw_circle(off + Vector2(4, 0).rotated(ang), 1.6, Color(C_TRIM, tint.a))


## 노즐 화염: 마우스가 위일수록 길고 밝게(활공), 아래면 짧게 + 속도선(낙하)
func _draw_flame(off: Vector2) -> void:
	if stun > 0.0 or frozen:
		return
	var power := 0.35
	if dash_t > 0.0 or launch_t > 0.0:
		power = 1.5
	elif on_platform:
		power = 0.3
	elif is_hovering_charge():
		power = 0.8
	elif aim.y < 0.0:
		power = 0.35 + 0.65 * -aim.y
	else:
		power = 0.35 - 0.2 * aim.y
	var flen := (8.0 + 34.0 * power) * randf_range(0.85, 1.15)
	var w := 4.0 + 4.0 * minf(power, 1.2)
	var back := Vector2(-21, 0)
	var outer := PackedVector2Array([off + (back + Vector2(0, -w)).rotated(facing), off + (back + Vector2(0, w)).rotated(facing), off + (back + Vector2(-flen, 0)).rotated(facing)])
	var inner := PackedVector2Array([off + (back + Vector2(0, -w * 0.5)).rotated(facing), off + (back + Vector2(0, w * 0.5)).rotated(facing), off + (back + Vector2(-flen * 0.6, 0)).rotated(facing)])
	draw_colored_polygon(outer, Color(1.0, 0.55, 0.2, 0.85))
	draw_colored_polygon(inner, Color(1.0, 0.95, 0.7, 0.95))
	# 아래로 향해 낙하 중: 몸 주변 속도선
	if aim.y > 0.3 and dash_t <= 0.0 and vel.y > 200.0:
		var a := clampf((aim.y - 0.3) * 1.4, 0.0, 0.7)
		var vd := vel.normalized()
		for k in [-1.0, 0.0, 1.0]:
			var st: Vector2 = off + vd.orthogonal() * k * 14.0 - vd * 18.0
			draw_line(st, st - vd * (26.0 + 14.0 * absf(float(k))), Color(0.85, 0.92, 1.0, a), 2.0)


func _draw() -> void:
	var jitter := Vector2.ZERO
	if is_hovering_charge():           # 차지 중엔 몸이 떨린다 (완료되면 더)
		var amp := 0.8 if is_charged() else 0.6 + 1.6 * clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
		jitter = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	var evade := dash_t > 0.0 and dash_kind == "evade"
	var attack := is_attacking()

	# 꼬리: 회피는 청백, 공격은 주황
	var tc := C_ATTACK if attack else C_EVADE
	for i in range(trail.size() - 1):
		var a := 1.0 - float(i) / trail.size()
		draw_line(trail[i] - position, trail[i + 1] - position, Color(tc, a * (0.3 if evade else 0.6)), 6.0 * a + 1.0)
	# 회피: 잔상
	if evade:
		for k in [3, 6, 9, 12]:
			if k < trail.size():
				_draw_rocket(trail[k] - position, facing, Color(C_EVADE, 0.28 - k * 0.018))

	# 무적 보호막 (발사·공격 돌진·직격 후·돌진 여유)
	if shield_t > 0.0 or attack or launch_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		draw_circle(Vector2.ZERO, 30.0 + 3.0 * pulse, Color(1.0, 0.85, 0.45, 0.14 + 0.1 * pulse))
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.6, 0.4 + 0.3 * pulse), 2.0)
	if attack:
		draw_circle(Vector2.ZERO, 26.0, Color(C_ATTACK, 0.3))

	_draw_flame(jitter)
	var blink := invuln > 0.0 and stun <= 0.0 and int(invuln * 20.0) % 2 == 0
	var alpha := 0.45 if evade else (0.35 if blink else 1.0)
	var tint := Color(1, 1, 1, alpha)
	if attack:
		tint = Color(1.0, 0.85, 0.65, 1.0)
	_draw_rocket(jitter, facing, tint)

	# 스턴: 연기
	if stun > 0.0:
		var tt := Time.get_ticks_msec() * 0.006
		for k in 3:
			var a := tt + k * TAU / 3.0
			draw_circle(Vector2(cos(a), sin(a)) * 18.0 + Vector2(0, -6), 7.0 + 2.0 * sin(tt * 2.0 + k), Color(0.55, 0.57, 0.62, 0.55))

	# 조준
	if aim_phase:
		var total := AIM_TIME_PERFECT if aim_perfect else AIM_TIME
		var c := Color(0.75, 0.92, 1.0, 0.95)
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 32, Color(c, 0.5), 2.0)
		draw_arc(Vector2.ZERO, 46.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(aim_left / total, 0.0, 1.0), 40, c, 4.0)
		_laser(aim, (PARRY_DASH_SPEED_PERFECT if aim_perfect else PARRY_DASH_SPEED) * PARRY_DASH_TIME, c)
	elif is_hovering_charge():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		if is_charged():               # 차지 완료: 몸이 살짝 빛나고 공격 사거리 레이저. (차지 중엔 떨림만)
			draw_circle(Vector2.ZERO, 30.0, Color(C_ATTACK, 0.12 + 0.1 * pulse))
			draw_circle(Vector2.ZERO, 19.0, Color(1.0, 0.85, 0.6, 0.12 + 0.12 * pulse))
			_laser(aim, CHARGE_SPEED * CHARGE_DASH_TIME, C_ATTACK)

	# 차지 쿨다운: 플레이어 주변 링이 차오른다 (다 차면 다시 차지 가능)
	if charge_cd > 0.0:
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, Color(C_ATTACK, 0.18), 3.0)
		draw_arc(Vector2.ZERO, 36.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - charge_cd / CHARGE_COOLDOWN), 32, Color(C_ATTACK, 0.85), 3.0)

	# 패리 자세
	if parry_active:
		var perfect_phase := parry_t <= PERFECT_WINDOW
		var c2 := Color(1.0, 0.95, 0.75, 0.9) if perfect_phase else Color(0.8, 0.85, 1.0, 0.55)
		draw_arc(Vector2.ZERO, RADIUS + PARRY_REACH, 0.0, TAU, 40, c2, 2.5 if perfect_phase else 1.5)
	if parry_flash > 0.0:
		draw_circle(Vector2.ZERO, 14.0 + (1.0 - parry_flash) * 44.0, Color(1, 1, 1, parry_flash * 0.5))
