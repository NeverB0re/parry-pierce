extends Node2D
## 플레이어: 거인에 비해 아주 작은 '살아있는 창'.
## 시뮬레이션은 main.gd 가 step() 으로 직접 호출한다(히트스톱/슬로모션 제어 때문).

# ── 튜닝값 ─────────────────────────────────────────────
const RADIUS := 9.0
const GRAVITY := 1000.0
const MAX_FALL := 1100.0
const GLIDE_FALL := 230.0        # 마우스를 위로 두면 낙하속도 상한이 여기까지 줄어든다(활공). 스스로 상승은 불가.
const THRUST := 560.0            # 약한 무한 추진(좌우/하강)
const AIR_DRAG := 0.9
const GROUND_SPEED := 300.0
const DASH_SPEED := 2400.0       # 돌진 = 공격. 기본 사거리 = 2400 x 0.3 = 720px (패리 돌진과 동일). 돌진 중에만 갑옷에 타격
const DASH_TIME := 0.3
const DASH_KEEP := 0.6           # 돌진이 끝난 뒤 남기는 속도 비율
const DASH_COOLDOWN := 0.1
const CHARGE_STEP := 0.8         # 좌클릭을 누르고 있으면 이 간격마다 게이지 1칸을 더 소모해 단계가 오른다 (느릴수록 위험)
const CHARGE_MAX := 3            # 최대 단계 (= 최대 구슬 3개 소모)
const CHARGE_AUTO := 0.5         # 최대 차지에 도달한 뒤 이 시간이 지나면 자동 발사
const CHARGE_SPEED_GAIN := 0.15  # 단계당 속도 +15%
const CHARGE_TIME_GAIN := 0.25   # 단계당 지속시간 +25% → 3단계 약 1400px. 피해 = 단계
const CHARGE_GRACE := 0.5        # 차지 돌진(2단계 이상)이 빗나가 끝난 직후 무적. 기본 돌진은 없음
const POWER_GRACE := 0.7         # 패리 돌진은 더 길게
const GAUGE_MAX := 5
const GAUGE_START := 3
const GROUND_REGEN := 1.0        # 바닥에 있을 때 게이지 1칸 회복 시간(초) - 소프트락 방지
const PERFECT_WINDOW := 0.07     # 패리 누른 뒤 이 시간 안에 막으면 PERFECT
const PARRY_MIN := 0.12          # 짧게 눌러도 이 시간만큼은 패리 유지
const PARRY_HOLD_MAX := 0.28     # 꾹 누르고 있을 때 패리 판정 최대 유지 시간
const PARRY_COOLDOWN := 0.55     # 끝까지 버틴 뒤 재입력 대기 (남발 방지)
const PARRY_RELEASE_CD := 0.25   # 중간에 뗐을 때 재입력 대기
const PARRY_REACH := 30.0        # 패리 판정은 몸보다 이만큼 넓다
const AIM_TIME := 0.7            # 패리 성공 후 방향을 정하는 슬로우 시간(실시간 초)
const AIM_TIME_PERFECT := 1.0
const PARRY_DASH_SPEED := DASH_SPEED  # 패리 돌진: 공격 판정 + 강한 데미지. 일반 돌진과 같은 사거리
const PARRY_DASH_SPEED_PERFECT := 2700.0
const PARRY_DASH_TIME := DASH_TIME
const POWER_DAMAGE := 3
const POWER_RADIUS := 8.0        # 패리 돌진은 타격 범위도 넓다
const BOUNCE_UP := 1050.0        # 돌진 직격 후 위로 튀어오르는 속도
const BOUNCE_SIDE := 250.0       # 들어온 방향의 반대쪽으로 튕기는 가로 속도
const BOUNCE_STEER := 750.0      # 튕길 때 마우스 좌우 방향으로 더하는 가로 속도 (좌우 조종)
const BOUNCE_THRUST := 2.0       # 튕겨나는 동안 좌우 추진 배율
const STRIKE_SHIELD := 0.9       # 직격 후 튕겨나는 동안 무적 시간
const HP_MAX := 3
const INVULN_TIME := 1.2
const STUN_TIME := 0.35
const WALL_L := -1150.0
const WALL_R := 1150.0
const CEILING := -3300.0

var main: Node
var boss: Node

var vel := Vector2.ZERO
var hp := HP_MAX
var gauge := GAUGE_START
var grounded := false
var dash_t := 0.0
var power_dash := false          # 패리 직후의 강한 돌진
var charging := false            # 좌클릭 차지 중
var charge_level := 0
var charge_t := 0.0
var dash_level := 1              # 현재/직전 돌진의 단계
var dash_total := DASH_TIME      # 현재 돌진의 총 지속시간(무적 링 표시용)
var dash_cd := 0.0
var parry_active := false
var parry_held := false
var parry_t := 0.0
var parry_cd := 0.0
var aim_phase := false           # 패리 성공 → 슬로우 → 방향 지정
var aim_left := 0.0
var aim_perfect := false
var invuln := 0.0                # 피격 후 무적
var bouncing := false            # 직격 후 튕겨나는 중 (카메라 줌아웃용)
var shield_t := 0.0              # 돌진/직격 후 무적
var shield_max := 1.0
var stun := 0.0
var empowered := 0.0             # PERFECT 직후: 일반 돌진 피해 2배
var regen_t := 0.0
var peak_y := 0.0                # 마지막 착지 이후 가장 높았던 위치(추락 판정용)
var aim := Vector2.UP
var trail: Array[Vector2] = []
var parry_flash := 0.0
var frozen := false              # 승리 연출 중 정지


func reset(pos: Vector2) -> void:
	position = pos
	vel = Vector2.ZERO
	hp = HP_MAX
	gauge = GAUGE_START
	grounded = pos.y >= -RADIUS - 1.0
	dash_t = 0.0
	power_dash = false
	charging = false
	charge_level = 0
	dash_level = 1
	bouncing = false
	dash_cd = 0.0
	parry_active = false
	parry_held = false
	parry_cd = 0.0
	aim_phase = false
	invuln = 0.0
	shield_t = 0.0
	stun = 0.0
	empowered = 0.0
	frozen = false
	peak_y = pos.y
	trail.clear()
	queue_redraw()


func is_immune() -> bool:
	return frozen or aim_phase or dash_t > 0.0 or shield_t > 0.0 or invuln > 0.0


func can_dash() -> bool:
	return not (frozen or aim_phase or stun > 0.0 or dash_cd > 0.0 or gauge <= 0)


## 즉시 돌진 (1단계)
func try_dash() -> void:
	if not can_dash():
		return
	gauge -= 1
	_dash(1)


## 좌클릭 누름: 차지 시작(1칸 소모). 누르고 있으면 단계가 오르며 칸을 더 소모
func charge_start() -> void:
	if charging or not can_dash():
		return
	gauge -= 1
	charging = true
	charge_level = 1
	charge_t = 0.0


func charge_at_cap() -> bool:
	return charge_level >= CHARGE_MAX or gauge <= 0


## 좌클릭 뗌: 모은 단계만큼 강하게 돌진
func charge_release() -> void:
	if not charging:
		return
	charging = false
	_dash(charge_level)
	charge_level = 0


## 차지 취소(피격/패리 전환): 소모한 칸을 돌려준다
func cancel_charge() -> void:
	if not charging:
		return
	charging = false
	gauge = mini(GAUGE_MAX, gauge + charge_level)
	charge_level = 0


func _dash(level: int) -> void:
	dash_level = level
	dash_total = DASH_TIME * (1.0 + CHARGE_TIME_GAIN * (level - 1))
	dash_t = dash_total
	dash_cd = dash_total + DASH_COOLDOWN
	vel = aim * DASH_SPEED * (1.0 + CHARGE_SPEED_GAIN * (level - 1))
	grounded = false
	main.on_dash(position, aim, level)


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
	power_dash = false
	grounded = false
	vel = Vector2.ZERO
	gauge = GAUGE_MAX              # 패리 성공 = 연료 가득
	aim_phase = true               # 시간이 느려지고 방향을 정한다
	aim_perfect = perfect
	aim_left = AIM_TIME_PERFECT if perfect else AIM_TIME
	if perfect:
		empowered = 1.0
	parry_flash = 1.0


## 방향 지정 종료 → 마우스 방향으로 패리 돌진(공격 판정, 강한 데미지)
func launch_parry_dash() -> void:
	if not aim_phase:
		return
	aim_phase = false
	var speed := PARRY_DASH_SPEED_PERFECT if aim_perfect else PARRY_DASH_SPEED
	power_dash = true
	dash_total = PARRY_DASH_TIME
	dash_t = PARRY_DASH_TIME
	dash_cd = PARRY_DASH_TIME + DASH_COOLDOWN
	vel = aim * speed
	parry_cd = PARRY_RELEASE_CD
	main.on_parry_launch(position, aim)


func on_hurt(push: Vector2) -> void:
	cancel_charge()
	hp -= 1
	vel = push.normalized() * 550.0 + Vector2(0, -200)
	grounded = false
	stun = STUN_TIME
	invuln = INVULN_TIME
	dash_t = 0.0
	power_dash = false
	parry_active = false


func step(dt: float) -> void:
	if frozen:
		queue_redraw()
		return
	var m := get_global_mouse_position() - position
	if m.length() > 1.0:
		aim = m.normalized()
	if aim_phase:
		queue_redraw()
		return

	dash_cd = maxf(0.0, dash_cd - dt)
	parry_cd = maxf(0.0, parry_cd - dt)
	invuln = maxf(0.0, invuln - dt)
	shield_t = maxf(0.0, shield_t - dt)
	if shield_t <= 0.0:
		bouncing = false
	stun = maxf(0.0, stun - dt)
	empowered = maxf(0.0, empowered - dt)
	parry_flash = maxf(0.0, parry_flash - dt * 4.0)
	if charging:
		charge_t += dt
		if charge_at_cap():
			if charge_t >= CHARGE_AUTO:       # 최대 차지: 잠시 후 자동 발사
				charge_release()
		elif charge_t >= CHARGE_STEP:
			charge_t = 0.0
			gauge -= 1
			charge_level += 1
			main.on_charge_tick(position, charge_level)
			if charge_at_cap():
				charge_t = 0.0
	if parry_active:
		parry_t += dt
		if parry_t > PARRY_HOLD_MAX:
			parry_active = false
			parry_cd = PARRY_COOLDOWN
		elif not parry_held and parry_t >= PARRY_MIN:
			parry_active = false
			parry_cd = PARRY_RELEASE_CD

	if grounded:
		if position.y < -RADIUS - 2.0:
			grounded = false
		vel.y = 0.0
		var want := 0.0
		if stun <= 0.0 and absf(m.x) > 30.0:
			want = signf(m.x) * GROUND_SPEED
		vel.x = move_toward(vel.x, want, 2000.0 * dt)
		if gauge < GAUGE_MAX:
			regen_t += dt
			if regen_t >= GROUND_REGEN:
				regen_t = 0.0
				gauge += 1
	elif dash_t > 0.0:
		dash_t -= dt
		if dash_t <= 0.0:
			vel *= DASH_KEEP
			var grace := POWER_GRACE if power_dash else (CHARGE_GRACE if dash_level >= 2 else 0.0)
			if grace > 0.0:                   # 무적 여유는 패리 돌진/차지 돌진만
				shield_max = grace
				shield_t = grace
			power_dash = false
	else:
		var fall_cap := MAX_FALL
		if stun <= 0.0 and m.length() > 40.0:
			vel.x += aim.x * THRUST * (BOUNCE_THRUST if bouncing else 1.0) * dt
			if aim.y > 0.0:
				vel.y += aim.y * THRUST * dt
			else:
				fall_cap = lerpf(MAX_FALL, GLIDE_FALL, -aim.y)
		if charging:                  # 차지 중엔 공중에서 거의 멈춰 조준한다
			vel.y += GRAVITY * 0.2 * dt
			vel.y = move_toward(vel.y, 0.0, 1500.0 * dt)
			vel.x -= vel.x * 4.0 * dt
		else:
			vel.y += GRAVITY * dt
			vel.x -= vel.x * AIR_DRAG * dt
		if vel.y > fall_cap:
			vel.y = move_toward(vel.y, fall_cap, 2500.0 * dt)

	_move(dt)

	trail.push_front(position)
	if trail.size() > 16:
		trail.pop_back()
	queue_redraw()


func _move(dt: float) -> void:
	var steps := clampi(int(ceil(vel.length() * dt / 6.0)), 1, 10)
	var sdt := dt / steps
	for s in steps:
		position += vel * sdt
		# 갑옷/심장은 상시 판정: 돌진 중이면 타격, 아니면 닿는 순간 피해
		var hit: Dictionary = boss.strike_hit(position, RADIUS + (POWER_RADIUS if power_dash else 0.0))
		if not hit.is_empty():
			if dash_t > 0.0:
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
		# 바닥
		if position.y > -RADIUS:
			position.y = -RADIUS
			if not grounded:
				grounded = true
				vel = Vector2(vel.x * 0.3, 0.0)
				dash_t = 0.0
				power_dash = false
				main.on_landed(peak_y)
			peak_y = position.y
	if not grounded:
		peak_y = minf(peak_y, position.y)


func _on_strike(hit: Dictionary) -> void:
	if hit["kind"] == "heart":
		main.on_heart_pierced(position)
		return
	var dir := vel.normalized()
	var power := power_dash
	var dmg := POWER_DAMAGE if power else dash_level + (1 if empowered > 0.0 else 0)
	gauge = mini(GAUGE_MAX, gauge + 1)           # 타격 성공 → 돌진 연료 1칸 환급
	main.on_strike(hit, dmg, position, dir, power or dash_level >= 3)
	var lv := 3 if power else dash_level
	dash_t = 0.0
	power_dash = false
	bouncing = true
	shield_t = STRIKE_SHIELD                     # 튕겨나는 동안 무적
	shield_max = STRIKE_SHIELD
	var k := 1.0 + 0.12 * (lv - 1)               # 강하게 모을수록 더 크게 튕김
	vel = Vector2(-dir.x * BOUNCE_SIDE + aim.x * BOUNCE_STEER, -BOUNCE_UP * k)  # 직격 → 위로 튀되 좌우는 마우스로 조종


## 레이저 같은 실선 사거리 표시 (끝으로 갈수록 옅어짐)
func _laser(dir: Vector2, reach: float, c: Color) -> void:
	var n := 14
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var fade := lerpf(1.0, 0.35, t0)
		var p0 := dir * lerpf(30.0, reach, t0)
		var p1 := dir * lerpf(30.0, reach, t1)
		draw_line(p0, p1, Color(c, 0.16 * fade), 8.0)
		draw_line(p0, p1, Color(c, 0.5 * fade), 3.2)
		draw_line(p0, p1, Color(1, 1, 1, 0.9 * fade), 1.3)
	var tip := dir * reach
	draw_circle(tip, 5.0, Color(c, 0.9))
	draw_circle(tip, 3.0, Color(1, 1, 1))
	draw_arc(tip, 12.0, 0.0, TAU, 16, Color(c, 0.7), 2.0)


func _draw() -> void:
	if charging:                       # 차지 중엔 몸이 떨린다 (단계가 오를수록 더)
		var amp := 0.8 + 1.4 * charge_level
		draw_set_transform(Vector2(randf_range(-amp, amp), randf_range(-amp, amp)))
	# 붉은 리본 꼬리
	for i in range(trail.size() - 1):
		var a := 1.0 - float(i) / trail.size()
		var w := 5.0 * a + 1.0
		draw_line(trail[i] - position, trail[i + 1] - position, Color(0.85, 0.1, 0.14, a * 0.85), w)

	var dir := aim
	if (dash_t > 0.0 or vel.length() > 60.0) and not aim_phase:
		dir = vel.normalized()
	var blink := invuln > 0.0 and int(invuln * 20.0) % 2 == 0
	var body_col := Color(0.95, 0.94, 0.9) if not blink else Color(0.95, 0.94, 0.9, 0.3)
	if empowered > 0.0 or power_dash:
		body_col = Color(1.0, 0.85, 0.55)
	if power_dash:
		draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.55, 0.15, 0.35))
	elif dash_t > 0.0:
		draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.8, 0.5, 0.35))

	# 무적 표시: 맥동하는 금빛 보호막
	if dash_t > 0.0 or shield_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		draw_circle(Vector2.ZERO, 20.0 + 3.0 * pulse, Color(1.0, 0.85, 0.45, 0.16 + 0.12 * pulse))
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.6, 0.45 + 0.3 * pulse), 2.0)

	# 바늘 몸통
	var shape := [Vector2(17, 0), Vector2(3, -4), Vector2(-8, -4), Vector2(-12, 0), Vector2(-8, 4), Vector2(3, 4)]
	var pts := PackedVector2Array()
	for p in shape:
		pts.append((p as Vector2).rotated(dir.angle()))
	draw_colored_polygon(pts, body_col)
	# 가면의 눈
	var side := dir.orthogonal()
	draw_circle(dir * -3.0 + side * 2.0, 1.4, Color(0.05, 0.05, 0.08))
	draw_circle(dir * -3.0 - side * 2.0, 1.4, Color(0.05, 0.05, 0.08))

	# 조준 화살표
	if aim_phase:
		var total := AIM_TIME_PERFECT if aim_perfect else AIM_TIME
		var c := Color(0.75, 0.92, 1.0, 0.95)
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color(c, 0.5), 2.0)
		draw_arc(Vector2.ZERO, 36.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(aim_left / total, 0.0, 1.0), 40, c, 4.0)
		_laser(aim, (PARRY_DASH_SPEED_PERFECT if aim_perfect else PARRY_DASH_SPEED) * PARRY_DASH_TIME, c)
	elif charging:
		# 차지: 단계가 오를수록 붉어지는 링 + 예상 돌진 거리 표시
		var heat := float(charge_level - 1) / (CHARGE_MAX - 1)
		var cc := Color(1.0, 0.85, 0.45).lerp(Color(1.0, 0.25, 0.15), heat)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		draw_circle(Vector2.ZERO, 16.0 + charge_level * 5.0, Color(cc, 0.12 + 0.12 * pulse))
		draw_arc(Vector2.ZERO, 16.0 + charge_level * 5.0, 0.0, TAU, 32, Color(cc, 0.8), 2.5)
		if not charge_at_cap():        # 최대 차지에선 게이지 링을 없앤다 (곧 자동 발사)
			draw_arc(Vector2.ZERO, 26.0 + charge_level * 5.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(charge_t / CHARGE_STEP, 0.0, 1.0), 32, cc, 3.5)
		var reach := DASH_SPEED * (1.0 + CHARGE_SPEED_GAIN * (charge_level - 1)) * DASH_TIME * (1.0 + CHARGE_TIME_GAIN * (charge_level - 1))
		_laser(aim, reach, cc)
	else:
		var tip := aim * 30.0
		draw_line(tip - aim * 6.0 + aim.orthogonal() * 4.0, tip, Color(1, 1, 1, 0.35), 1.5)
		draw_line(tip - aim * 6.0 - aim.orthogonal() * 4.0, tip, Color(1, 1, 1, 0.35), 1.5)

	# 패리 자세
	if parry_active:
		var perfect_phase := parry_t <= PERFECT_WINDOW
		var c2 := Color(1.0, 0.95, 0.75, 0.9) if perfect_phase else Color(0.8, 0.85, 1.0, 0.55)
		draw_arc(Vector2.ZERO, RADIUS + PARRY_REACH, 0.0, TAU, 40, c2, 2.5 if perfect_phase else 1.5)
		draw_arc(Vector2.ZERO, RADIUS + PARRY_REACH + 6.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(1.0 - parry_t / PARRY_HOLD_MAX, 0.0, 1.0), 40, Color(c2, 0.4), 2.0)
	if parry_flash > 0.0:
		draw_circle(Vector2.ZERO, 10.0 + (1.0 - parry_flash) * 40.0, Color(1, 1, 1, parry_flash * 0.5))
