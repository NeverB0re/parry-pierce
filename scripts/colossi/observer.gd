extends "res://scripts/colossus_base.gd"
## 콜로서스 ① 관측자 (올라운더, 첫 보스). 정면을 보고 서 있는 거대한 인간형.
## 페이즈: 1) 외부 시스템 파괴 — 좌/우 포대, 좌/우 팔꿈치 관절을 부순다 (가슴은 닫혀 있음)
##         2) 개방 연출 — 가슴이 열린다
##         3) 동력 코어 — 심장 모양 장갑에 싸인 코어. 탄은 머리에서 쏜다
## 공격: 융해 지대 분출(바닥) · 팔 휘두르기(요격 가능) · 눈 레이저(패리 불가) · 조준 연사 · 흩뿌리기
## 체력바는 없다: 외부 시스템·장갑 모두 균열·연기·조각 탈락으로 남은 체력을 보여 준다
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const Erupt := preload("res://scripts/attacks/erupt.gd")
const Swing := preload("res://scripts/attacks/swing.gd")
const Beam := preload("res://scripts/attacks/beam.gd")
const Volley := preload("res://scripts/attacks/volley.gd")
const Burst := preload("res://scripts/attacks/burst.gd")

# ── 구조 ───────────────────────────────────────────────
const HEART_POS := Vector2(0, -1900)        # 동력 코어(심장) 중심
const CHEST_RECT := Rect2(-244, -2160, 488, 540)   # 가슴 문 (페이즈 1에 닫혀 있음)
const ARMOR_HP := 160                       # 장갑 체력. 다 부서져도 피해가 코어로 넘어가지 않는다
const PLATE_SITES := 11                     # 장갑을 이루는 불규칙한 강철 판 수
const CORE_R := 62.0                        # 심장 안 코어 반지름
# 심장 외곽선 (HEART_POS 기준, 두 심방·대동맥·폐동맥·좌심실 끝으로 이어지는 해부학적 모양). 한 번 부드럽게 다듬어 쓴다
const HEART_OUTLINE := [
	Vector2(-40, 262), Vector2(-95, 225), Vector2(-150, 165), Vector2(-190, 95), Vector2(-212, 15), Vector2(-212, -55),
	Vector2(-190, -105), Vector2(-150, -130), Vector2(-105, -133), Vector2(-75, -118),
	Vector2(-62, -150), Vector2(-58, -195), Vector2(-40, -232), Vector2(-5, -246), Vector2(30, -236), Vector2(48, -205), Vector2(50, -165), Vector2(58, -140),
	Vector2(78, -160), Vector2(100, -170), Vector2(118, -150), Vector2(112, -125),
	Vector2(135, -130), Vector2(175, -118), Vector2(205, -80), Vector2(218, -25), Vector2(212, 40), Vector2(190, 100), Vector2(150, 160), Vector2(100, 210), Vector2(45, 247),
]
const PLATE_SITE_BOX := Rect2(-215, -245, 430, 505)   # 판 중심을 뿌릴 범위 (HEART_POS 기준)

const HIPS := [Vector2(-210, -1020), Vector2(210, -1020)]
const FOOT_REST := [Vector2(-230, 0), Vector2(230, 0)]
const LEG_SEG := 470.0
const SHOULDERS := [Vector2(-470, -2260), Vector2(470, -2260)]
const FIST_IDLE := [Vector2(-600, -1100), Vector2(600, -1100)]
const ARM_SEG := 620.0
const SWING_L := 1180.0              # 팔 전체를 곧게 뻗었을 때 어깨~주먹 (휩쓰는 반경)
const ELBOW_AT := 0.55               # 곧게 뻗은 팔에서 팔꿈치는 어깨~주먹 선의 이 지점
const UPPER_W := 75.0                # 팔 판정 반폭: 위팔 / 아래팔 / 주먹은 FIST_R
const FORE_W := 62.0
const FIST_R := 105.0
const MUZZLES := [Vector2(-640, -2470), Vector2(640, -2470)]   # 양어깨 포대의 포구
const HEAD_POS := Vector2(0, -2605)                             # 최종 페이즈 탄·레이저 발사점
const EYES := [Vector2(-62, -2605), Vector2(62, -2605)]

# ── 외부 시스템 ────────────────────────────────────────
const PART_HP := 24                         # 0 왼쪽 포대, 1 오른쪽 포대, 2 왼팔 관절, 3 오른팔 관절
const PART_R := [55.0, 55.0, 70.0, 70.0]
const OPEN_TIME := 1.6                      # 가슴이 열리는 연출 시간

# ── 공격 고르기 ────────────────────────────────────────
const LOW_ZONE_Y := -900.0           # 이보다 아래(융해 지대 근처)면 분출 위주

# ── 색 ─────────────────────────────────────────────────
const C_BODY := Color(0.075, 0.08, 0.10)
const C_BODY_DARK := Color(0.045, 0.05, 0.065)
const C_RIM := Color(0.48, 0.52, 0.6)
const C_CLOAK := Color(0.05, 0.045, 0.07)
const C_BONE := Color(0.78, 0.75, 0.68)
const C_EYE := Color(1.0, 0.78, 0.42)
const C_PARRY := Color(1.0, 0.88, 0.35)          # 패리할 수 있는 것 = 금색 (탄, 휩쓰는 팔)
const C_UNPARRY := Color(0.6, 0.08, 0.36)       # 패리 불가 = 검붉은 보라 (회피 돌진으로만 피한다)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var feet: Array[Vector2] = []
var fists: Array[Vector2] = []
var debris: Array[Dictionary] = []   # 부서져 떨어진 부위
var eye_glow := 0.0
var beam_glow := 0.0                 # 레이저 직전·중 눈이 보랏빛으로 달아오름
var cannon_glow: Array[float] = [0.0, 0.0]   # 발사 전 포구가 달아오르는 정도


func _init() -> void:
	open_time = OPEN_TIME


func _ready() -> void:
	core = ArmoredCore.new(self, HEART_POS, HEART_OUTLINE, ARMOR_HP, PLATE_SITE_BOX, PLATE_SITES, 11)
	reset()


func reset() -> void:
	super()
	feet.clear()
	feet.append(FOOT_REST[0])
	feet.append(FOOT_REST[1])
	fists.clear()
	fists.append(FIST_IDLE[0])
	fists.append(FIST_IDLE[1])
	debris.clear()
	eye_glow = 0.0
	beam_glow = 0.0
	cannon_glow = [0.0, 0.0]


# ── 외부 시스템 ────────────────────────────────────────
func part_count() -> int:
	return 4


func part_max_hp(_i: int) -> int:
	return PART_HP


func part_radius(i: int) -> float:
	return PART_R[i]


func cannon_base(c: int) -> Vector2:
	var s := 1.0 if c == 1 else -1.0
	return SHOULDERS[c] + Vector2(s * 60.0, -110.0)


func part_pos(i: int) -> Vector2:
	if i < 2:
		return cannon_base(i).lerp(MUZZLES[i], 0.55)
	return elbow_of(i - 2)


# ── 몸 ─────────────────────────────────────────────────
func foot_rect(i: int) -> Rect2:
	var f := feet[i]
	return Rect2(f.x - 130.0, f.y - 110.0, 260.0, 110.0)


func knee_of(i: int) -> Vector2:
	var ankle := feet[i] + Vector2(0, -100)
	return _joint(HIPS[i], ankle, LEG_SEG, Vector2(1.0 if i == 1 else -1.0, 0))


func _swing_of(a: int):
	if atk is Swing and atk.arm == a:
		return atk
	return null


func elbow_of(a: int) -> Vector2:
	if not part_alive(2 + a):              # 부서진 팔: 위팔만 축 늘어져 있다
		return SHOULDERS[a] + Vector2((1.0 if a == 1 else -1.0) * 90.0, 430.0)
	var bent := _arm_bent(a)
	var sw = _swing_of(a)
	if sw != null:
		var straight: Vector2 = SHOULDERS[a].lerp(fists[a], ELBOW_AT)   # 휩쓰는 동안은 곧은 팔 → 관절 위치를 예측 가능
		match sw.phase:
			"prep":
				return bent.lerp(straight, minf(1.0, sw.t / 0.3))
			"return":
				return straight.lerp(bent, minf(1.0, sw.t / 0.4))
		return straight
	return bent


## 팔꿈치: 항상 팔 진행 방향의 같은 쪽(바깥)으로 굽힌다 → 팔이 돌아도 관절이 반대편으로 튀지 않는다
func _arm_bent(a: int) -> Vector2:
	var sh: Vector2 = SHOULDERS[a]
	var d := fists[a] - sh
	var half := d.length() * 0.5
	var h := sqrt(maxf(0.0, ARM_SEG * ARM_SEG - half * half))
	var perp := d.orthogonal().normalized() * (1.0 if a == 1 else -1.0)
	return sh + d * 0.5 + perp * h


func is_staggered(a: int) -> bool:
	var sw = _swing_of(a)
	return sw != null and sw.phase == "stagger"


## 두 마디 관절 위치. prefer 쪽으로 굽힌다.
static func _joint(a: Vector2, b: Vector2, seg: float, prefer: Vector2) -> Vector2:
	var d := b - a
	var half := d.length() * 0.5
	var h := sqrt(maxf(0.0, seg * seg - half * half))
	var perp := d.orthogonal().normalized()
	if perp.dot(prefer) < 0.0:
		perp = -perp
	return (a + b) * 0.5 + perp * h


## 팔 전체(위팔·아래팔·주먹) 판정 상자. pos = ppos 에 가장 가까운 지점
func arm_box(a: int, ppos: Vector2) -> Dictionary:
	var sh: Vector2 = SHOULDERS[a]
	var el := elbow_of(a)
	var segs := [[sh, el, UPPER_W], [el, fists[a], FORE_W], [fists[a], fists[a], FIST_R]]
	var best := fists[a]
	var best_d := INF
	for sg in segs:
		var q := seg_closest(ppos, sg[0], sg[1])
		var d := q.distance_to(ppos) - float(sg[2])
		if d < best_d:
			best_d = d
			best = q
	return {"id": "arm", "segs": segs, "pos": best}


# ── 진행 ───────────────────────────────────────────────
## 부서진 부위가 떨어져 나간다 (포대 / 팔꿈치 아래 팔)
func _on_part_broken(i: int) -> void:
	var s := 1.0 if i % 2 == 1 else -1.0
	if i < 2:
		var base := cannon_base(i)
		var mz: Vector2 = MUZZLES[i]
		debris.append({"pos": (base + mz) * 0.5, "half": (mz - base) * 0.5, "w": 54.0, "fist": false,
			"vel": Vector2(s * 260.0, -380.0), "rot": 0.0, "rotv": s * 3.5, "rest": false})
	else:
		var a := i - 2
		var el := elbow_of(a)
		debris.append({"pos": (el + fists[a]) * 0.5, "half": (fists[a] - el) * 0.5, "w": 125.0, "fist": true,
			"vel": Vector2(s * 200.0, -250.0), "rot": 0.0, "rotv": s * 2.2, "rest": false})


func _part_highlight(i: int) -> bool:
	return i >= 2 and is_staggered(i - 2)


func _step_effects(dt: float) -> void:
	_step_debris(dt)


func _step_phase(dt: float) -> void:
	eye_glow = move_toward(eye_glow, 0.0, dt * 2.0)
	beam_glow = move_toward(beam_glow, 0.0, dt * 2.0)
	for i in 2:
		cannon_glow[i] = move_toward(cannon_glow[i], 0.0, dt * 2.0)


func _on_attack_finished() -> void:
	if part_alive(2) == false:
		fists[0] = FIST_IDLE[0]
	if part_alive(3) == false:
		fists[1] = FIST_IDLE[1]


func _choose(ppos: Vector2) -> void:
	var roll := randf()
	var can_shoot := phase == 3 or part_alive(0) or part_alive(1)
	var arm := _swing_arm(ppos)
	if ppos.y > LOW_ZONE_Y and roll < 0.6:      # 융해 지대 근처: 아래에서 솟는 덩어리 위주
		start_attack(Erupt.new(ppos))
		return
	if roll < 0.2:
		start_attack(Erupt.new(ppos))
		return
	if roll < 0.36:                               # 패리 불가 눈 레이저
		start_attack(Beam.new(HEAD_POS))
		return
	if arm >= 0 and (roll < 0.64 or not can_shoot):
		var sw := Swing.new(arm, 2 + arm, fists[arm])
		start_attack(sw)
		sw.aim_at(ppos)
	elif can_shoot:
		var c := _shooter(ppos)
		var org: Vector2 = HEAD_POS if c < 0 else MUZZLES[c]
		if roll < 0.86:
			start_attack(Volley.new(c, org, ppos))
		else:
			start_attack(Burst.new(c, org))
	else:
		start_attack(Erupt.new(ppos))


## 휩쓸 수 있는 팔: 플레이어 쪽 팔 우선, 부서졌거나 닿지 않으면 반대 팔
func _swing_arm(ppos: Vector2) -> int:
	var first := 1 if ppos.x >= 0.0 else 0
	for a in [first, 1 - first]:
		if part_alive(2 + a) and ppos.distance_to(SHOULDERS[a]) < SWING_L + 120.0:
			return a
	return -1


## 탄 발사점: 페이즈 1은 플레이어에게서 더 먼(살아있는) 포대, 최종 페이즈는 머리(-1)
func _shooter(ppos: Vector2) -> int:
	if phase == 3:
		return -1
	if part_alive(0) and part_alive(1):
		return 0 if ppos.distance_to(MUZZLES[0]) >= ppos.distance_to(MUZZLES[1]) else 1
	return 0 if part_alive(0) else 1


## 발사 전 발광: -1 = 눈, 0·1 = 포구
func set_glow(c: int, v: float) -> void:
	if c < 0:
		eye_glow = v
	else:
		cannon_glow[c] = v


func glow_of(c: int) -> float:
	return eye_glow if c < 0 else cannon_glow[c]


func _step_debris(dt: float) -> void:
	for d in debris:
		if d["rest"]:
			continue
		var v: Vector2 = d["vel"]
		v.y += 1500.0 * dt
		d["vel"] = v
		var p: Vector2 = d["pos"] + v * dt
		var rot: float = float(d["rot"]) + float(d["rotv"]) * dt
		var half: Vector2 = d["half"]
		var reach := absf(half.rotated(rot).y) + float(d["w"]) * 0.5
		if bool(d["fist"]):
			reach = maxf(reach, absf(half.rotated(rot).y) + FIST_R)
		if p.y + reach >= 0.0:                   # 바닥에 닿으면 그대로 눕는다
			p.y = -reach
			d["rest"] = true
			emit(Ev.DEBRIS_LAND, Vector2(p.x, 0))
		d["pos"] = p
		d["rot"] = rot


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_cloak()
	_draw_legs()
	_draw_torso()
	_draw_chest()
	_draw_arms()
	_draw_head()
	_draw_part_marks()
	_draw_debris()
	_draw_shards()
	if atk != null:
		atk.draw()
	shots.draw(self)


func _draw_cloak() -> void:
	var sw := sin(t * 0.9) * 18.0
	var pts := PackedVector2Array([
		Vector2(-520, -2380), Vector2(520, -2380), Vector2(640, -1700),
		Vector2(700 + sw, -1000), Vector2(640 + sw, -860), Vector2(560 + sw, -1000), Vector2(470, -880),
		Vector2(380, -1010), Vector2(260, -900), Vector2(120, -1030), Vector2(0, -910),
		Vector2(-120, -1030), Vector2(-260, -900), Vector2(-380, -1010), Vector2(-470, -880),
		Vector2(-560 - sw, -1000), Vector2(-640 - sw, -860), Vector2(-700 - sw, -1000), Vector2(-640, -1700),
	])
	draw_colored_polygon(pts, C_CLOAK)


func _draw_legs() -> void:
	for i in 2:
		var s := 1.0 if i == 1 else -1.0
		var hip: Vector2 = HIPS[i]
		var knee := knee_of(i)
		var ankle := feet[i] + Vector2(0, -100)
		_cap(hip, knee, 170.0, C_BODY)
		_cap(knee, ankle, 140.0, C_BODY)
		draw_line(hip + Vector2(-s * 50, 0), knee + Vector2(-s * 50, 0), Color(C_RIM, 0.45), 4.0)
		draw_circle(knee, 80.0, C_BODY_DARK)
		draw_arc(knee, 80.0, PI * 0.75, PI * 2.25, 24, C_RIM, 5.0)
		var r := foot_rect(i)
		var boot := PackedVector2Array([
			Vector2(r.position.x, r.end.y), Vector2(r.position.x + 8, r.position.y + 45),
			Vector2(r.position.x + 60, r.position.y), Vector2(r.end.x - 60, r.position.y),
			Vector2(r.end.x - 8, r.position.y + 45), Vector2(r.end.x, r.end.y)])
		draw_colored_polygon(boot, C_BODY_DARK)
		draw_polyline(PackedVector2Array([boot[1], boot[2], boot[3], boot[4]]), C_RIM, 4.0)
		draw_line(Vector2(r.position.x, r.end.y - 16), Vector2(r.end.x, r.end.y - 16), Color(C_BONE, 0.4), 3.0)


func _draw_torso() -> void:
	var body := PackedVector2Array([
		Vector2(-470, -2350), Vector2(470, -2350), Vector2(500, -2250), Vector2(400, -1700),
		Vector2(310, -1300), Vector2(-310, -1300), Vector2(-400, -1700), Vector2(-500, -2250)])
	draw_colored_polygon(body, C_BODY)
	draw_polyline(PackedVector2Array([Vector2(-500, -2250), Vector2(-470, -2350), Vector2(470, -2350), Vector2(500, -2250)]), C_RIM, 5.0)
	for y in [-1560.0, -1470.0, -1380.0]:
		draw_line(Vector2(-330, y), Vector2(330, y), C_BODY_DARK, 6.0)
		draw_line(Vector2(-330, y + 6), Vector2(330, y + 6), Color(C_RIM, 0.3), 2.0)
	draw_rect(Rect2(-380, -1300, 760, 280), C_BODY_DARK)
	for x in [-250.0, -125.0, 0.0, 125.0, 250.0]:
		draw_line(Vector2(x, -1290), Vector2(x, -1030), C_BODY, 8.0)
	draw_line(Vector2(-380, -1300), Vector2(380, -1300), C_BONE, 5.0)


## 가슴: 페이즈 1은 닫힌 문, 페이즈 2는 열리는 중, 페이즈 3은 장갑에 싸인 심장(동력 코어)
func _draw_chest() -> void:
	var open_k := 0.0 if phase == 1 else (1.0 if phase == 3 else clampf(open_t / OPEN_TIME, 0.0, 1.0))
	if open_k > 0.0:
		_draw_core()
	if open_k >= 1.0:
		return
	var rc := CHEST_RECT
	var half_w := rc.size.x * 0.5
	var slide := ease(open_k, 2.2) * (half_w + 20.0)
	var alpha := 1.0 - maxf(0.0, open_k - 0.7) / 0.3
	for s in [-1.0, 1.0]:
		var x0: float = rc.position.x + (0.0 if s < 0.0 else half_w) + s * slide
		var door := Rect2(x0, rc.position.y, half_w, rc.size.y)
		draw_rect(door, Color(C_BODY_DARK, alpha))
		draw_rect(door, Color(C_RIM, 0.6 * alpha), false, 4.0)
		for k in 4:
			var y := door.position.y + 50.0 + k * (door.size.y - 100.0) / 3.0
			draw_circle(Vector2(door.position.x + door.size.x * 0.5, y), 7.0, Color(C_RIM, 0.5 * alpha))
	if open_k > 0.0:                            # 열리는 틈새로 새어나오는 빛
		var gap := slide * 2.0
		draw_rect(Rect2(HEART_POS.x - gap * 0.5, rc.position.y, gap, rc.size.y), Color(C_HEART, 0.25 * (1.0 - open_k)))
	else:
		draw_line(Vector2(0, rc.position.y), Vector2(0, rc.end.y), Color(C_HEART, 0.18 + 0.1 * sin(t * 3.0)), 3.0)


## 심장: 안쪽은 어두운 붉은 근육 + 맥동하는 코어, 바깥은 불규칙한 강철 판(장갑, armored_core.gd 가 그린다).
## 장갑이 다 사라지면 코어가 오작동하듯 깜빡이며 약점으로 표시된다.
func _draw_core() -> void:
	var hc := HEART_POS
	var f: float = core.frac()
	var beat := 0.5 + 0.5 * sin(t * (4.5 + f * 5.0))          # 많이 부서질수록 빨리 뛴다
	var lit := strike_glow or focus_glow > 0.0               # 공격 돌진 중이거나 방향 지정·차지 중이면 표적이 드러난다
	var shell: PackedVector2Array = core.shell_poly
	if dead:
		draw_colored_polygon(shell, Color(0.2, 0.04, 0.05))
		var k := minf(1.0, death_t / 1.2)
		draw_circle(hc, CORE_R + k * 240.0, Color(C_HEART, 0.5 * (1.0 - k)))
		draw_arc(hc, CORE_R + k * 450.0, 0.0, TAU, 48, Color(1, 0.9, 0.7, 1.0 - k), 6.0)
		return
	# 심장 근육 (안쪽): 두 겹 + 중격선 + 혈관
	draw_colored_polygon(shell, Color(0.2, 0.04, 0.06))
	draw_colored_polygon(core.shell_inner, Color(0.32, 0.06, 0.08).lerp(Color(0.5, 0.1, 0.08), f * 0.6))
	draw_polyline(PackedVector2Array([hc + Vector2(-40, 230), hc + Vector2(-70, 120), hc + Vector2(-60, 10), hc + Vector2(-72, -118)]), Color(0.12, 0.02, 0.03, 0.8), 5.0)
	draw_polyline(PackedVector2Array([hc + Vector2(30, 200), hc + Vector2(80, 110), hc + Vector2(120, 20), hc + Vector2(150, -60)]), Color(0.55, 0.1, 0.12, 0.7), 3.0)
	draw_polyline(PackedVector2Array([hc + Vector2(-30, -240), hc + Vector2(-10, -170), hc + Vector2(30, -110)]), Color(0.55, 0.1, 0.12, 0.7), 4.0)
	# 코어 (맥동). 장갑이 사라질수록 밝고 불안정하게
	var flick := 1.0
	if core.broken:
		flick = 0.55 + 0.45 * float(int(t * 14.0) % 3 != 0)
	var pr := CORE_R * (1.0 + 0.06 * beat)
	var ca := 0.35 + 0.65 * minf(1.0, f * 1.3)
	draw_circle(hc, pr * 2.0, Color(C_HEART, (0.08 + 0.1 * beat) * ca * flick))
	draw_circle(hc, pr * 1.3, Color(C_HEART, 0.35 * ca * flick))
	draw_circle(hc, pr, Color(C_HEART, ca * flick).lerp(Color.WHITE, core.flash * 0.6))
	draw_circle(hc + Vector2(-pr * 0.3, -pr * 0.3), pr * 0.4, Color(1.0, 0.85, 0.6, ca * flick))
	core.draw_plates(self, t, lit, beat)
	# 연기: 손상이 클수록 많이
	var smoke := int(f * 6.0)
	for k in smoke:
		var life := fmod(t * 0.5 + k * 0.17, 1.0)
		var sp := hc + Vector2(sin(k * 2.3 + t * 0.8) * 120.0, -140.0 - life * 190.0)
		draw_circle(sp, 14.0 + life * 30.0, Color(0.3, 0.3, 0.33, 0.35 * (1.0 - life)))
	if core.broken:                                # 장갑이 사라진 코어: 불안정한 불꽃 + 약점 표시
		for k in 6:
			var sa := t * 4.0 + k * 1.1
			var sd := CORE_R + 14.0 + fmod(t * 120.0 + k * 41.0, 80.0)
			draw_circle(hc + Vector2.from_angle(sa) * sd, 3.0, Color(1.0, 0.85, 0.5, 0.9))
		draw_arc(hc, CORE_R + 22.0 + 6.0 * beat, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, 0.55 + 0.4 * beat), 3.0)
	if focus_glow > 0.0:                           # 방향 지정·차지 중: 노릴 수 있는 표적 강조
		var in_reach := hc.distance_to(focus_from) <= focus_reach + 200.0
		draw_arc(hc, 270.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.55, focus_glow * (0.6 if in_reach else 0.25)), 3.0)


func _draw_arms() -> void:
	for a in 2:
		var sh: Vector2 = SHOULDERS[a]
		var el := elbow_of(a)
		_cap(sh, el, 150.0, C_BODY)
		if part_alive(2 + a):
			var f := fists[a]
			_cap(el, f, 125.0, C_BODY)
			draw_circle(el, 70.0, C_BODY_DARK)
			draw_arc(el, 70.0, 0.0, TAU, 20, Color(C_RIM, 0.6), 4.0)
			draw_circle(f, FIST_R, C_BODY_DARK)
			draw_arc(f, FIST_R, -PI * 0.9, -PI * 0.1, 18, C_RIM, 6.0)
			for j in 3:
				var y := f.y - 40.0 + j * 40.0
				draw_line(Vector2(f.x - 55, y), Vector2(f.x + 55, y), Color(C_RIM, 0.35), 3.0)
			var sw = _swing_of(a)
			if sw != null and sw.phase == "swing":
				# 휩쓰는 팔 = 패리할 수 있는 것 → 금색 테두리
				draw_line(sh, el, Color(C_PARRY, 0.7), 5.0)
				draw_line(el, f, Color(C_PARRY, 0.7), 5.0)
				draw_arc(f, FIST_R + 4.0, 0.0, TAU, 24, Color(C_PARRY, 0.8), 5.0)
		else:
			_draw_stump(el, (el - sh).normalized(), 60.0)
		draw_circle(sh, 140.0, C_BODY_DARK)
		draw_arc(sh, 140.0, PI, TAU, 24, Color(C_BONE, 0.8), 7.0)
		# 어깨 포대
		var base := cannon_base(a)
		var mz: Vector2 = MUZZLES[a]
		if part_alive(a):
			_cap(base, mz, 54.0, C_BODY_DARK)
			draw_line(base + Vector2(0, -25), mz + Vector2(0, -22), Color(C_RIM, 0.55), 3.0)
			draw_circle(mz, 34.0, C_BODY)
			draw_arc(mz, 34.0, 0.0, TAU, 20, C_RIM, 4.0)
			var g := cannon_glow[a]
			draw_circle(mz, 18.0 + 22.0 * g, Color(C_EYE, 0.12 + 0.5 * g))
			draw_circle(mz, 9.0 + 6.0 * g, Color(C_EYE, 0.55 + 0.45 * g))
		else:
			var tip := base.lerp(mz, 0.25)
			_cap(base, tip, 54.0, C_BODY_DARK)
			_draw_stump(tip, (mz - base).normalized(), 30.0)


## 부서진 단면: 들쭉날쭉한 끝 + 꺼져가는 불씨
func _draw_stump(p: Vector2, dir: Vector2, r: float) -> void:
	var o := dir.orthogonal()
	var pts := PackedVector2Array([p + o * r, p + dir * r * 0.5 + o * r * 0.5, p + dir * r * 0.2, p + dir * r * 0.7 - o * r * 0.3, p - o * r])
	draw_colored_polygon(pts, C_BODY_DARK)
	draw_circle(p + dir * r * 0.2, r * 0.35, Color(C_HEART, 0.25 + 0.15 * sin(t * 4.0)))


func _draw_debris() -> void:
	for d in debris:
		var p: Vector2 = d["pos"]
		var half: Vector2 = d["half"]
		draw_set_transform(p, float(d["rot"]))
		_cap(-half, half, float(d["w"]), C_BODY_DARK)
		if bool(d["fist"]):
			draw_circle(half, FIST_R, C_BODY_DARK)
			draw_arc(half, FIST_R, 0.0, TAU, 18, Color(C_RIM, 0.4), 4.0)
		else:
			draw_circle(half, 34.0, C_BODY)
		draw_circle(-half, float(d["w"]) * 0.35, Color(C_HEART, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_head() -> void:
	for s in [-1.0, 1.0]:
		_cap(Vector2(s * 120, -2740), Vector2(s * 230, -2900), 40.0, C_BONE)
		_cap(Vector2(s * 230, -2900), Vector2(s * 380, -3000), 26.0, C_BONE)
		_cap(Vector2(s * 380, -3000), Vector2(s * 500, -3015), 14.0, C_BONE)
	draw_rect(Rect2(-90, -2400, 180, 80), C_BODY_DARK)
	var helm := PackedVector2Array([
		Vector2(-170, -2380), Vector2(-195, -2600), Vector2(-135, -2745), Vector2(0, -2795),
		Vector2(135, -2745), Vector2(195, -2600), Vector2(170, -2380), Vector2(80, -2335), Vector2(-80, -2335)])
	draw_colored_polygon(helm, C_BODY)
	var rim := helm.duplicate()
	rim.append(helm[0])
	draw_polyline(rim, C_RIM, 5.0)
	draw_line(Vector2(0, -2790), Vector2(0, -2650), Color(C_RIM, 0.5), 4.0)
	draw_rect(Rect2(-125, -2640, 250, 70), Color(0.02, 0.02, 0.03))
	var glow := 0.55 + 0.45 * eye_glow
	if dead:
		glow = maxf(0.0, 0.55 - death_t * 0.4)
	for e in EYES:
		draw_circle(e, 32.0 + eye_glow * 32.0, Color(C_EYE, 0.16 * glow))
		draw_circle(e, 10.0 + eye_glow * 6.0, Color(C_EYE, glow))
		if beam_glow > 0.0:                          # 레이저: 보랏빛으로 달아오른다
			draw_circle(e, 30.0 + beam_glow * 40.0, Color(C_UNPARRY, 0.35 * beam_glow))
			draw_circle(e, 8.0 + beam_glow * 10.0, Color(C_UNPARRY_CORE, beam_glow))
